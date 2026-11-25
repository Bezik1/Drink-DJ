"""
Adding of new business requirements to the requirements matrix and export of its PDF.
"""
import argparse
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

SKILLS = Path(__file__).resolve().parents[2]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))

from docx_to_pdf import DocxToPdfConverter

PATHS = {
    "source": "spec/requirements/artifacts/requirements_matrix.docx",
    "target": "spec/requirements/documents/requirements_matrix.pdf",
}

DOCUMENT = "word/document.xml"
ID_FORMAT = "R{:02d}"
ID_PATTERN = r"R(\d+)"

ROW = re.compile(r"<w:tr[ >].*?</w:tr>", re.S)
CELL = re.compile(r"<w:tc>.*?</w:tc>", re.S)
TEXT = re.compile(r"<w:t(?: [^>]*)?>(.*?)</w:t>", re.S)
RUN_PROPERTIES = re.compile(r"<w:r(?: [^>]*)?>(<w:rPr>.*?</w:rPr>)", re.S)
IDENTITY = re.compile(r' w14:(?:paraId|textId)="[^"]*"')


class RequirementsMatrixEditor:
    """
    Editor of the requirements matrix. It adds rows to the table of the Word
    file and exports the official PDF from it.

    Args:
        root (Path): Root of the repository.
    """

    def __init__(self, root):
        self.source = root / PATHS["source"]
        self.target = root / PATHS["target"]

        if not self.source.is_file():
            raise RuntimeError(f"Requirements matrix not found: {self.source}")

    def __call__(self, texts):
        """
        Adds the requirements as the last rows of the matrix, and replaces
        the official PDF.

        Rules:
            - Ids continue the numbering of the matrix (R19, R20, ...).
            - New rows copy the format of the last row.
            - The Word file and the PDF are replaced only after the PDF
              has been exported, so a failure leaves both unchanged.

        Args:
            texts (str[]): Texts of the new requirements.

        Returns:
            tuple[str, str][]: Id and text of every added requirement.
        """
        texts = [self.clean(text) for text in texts]
        files = self.read_files()
        rows = self.read_rows(files[DOCUMENT])

        self.check(texts, rows)

        added = self.name(texts, rows)
        files[DOCUMENT] = self.insert(files[DOCUMENT], added)

        with tempfile.TemporaryDirectory() as work:
            docx = Path(work, self.source.name)
            pdf = Path(work, self.target.name)

            self.write_files(files, docx)
            DocxToPdfConverter()(docx, pdf)

            self.replace(docx, self.source)
            self.replace(pdf, self.target)

        return added

    def list(self):
        """
        Reads the requirements of the matrix.

        Returns:
            tuple[str, str][]: Id and text of every requirement.
        """
        return self.read_rows(self.read_files()[DOCUMENT])

    def clean(self, text):
        text = re.sub(r"\s+", " ", text).strip()

        if not text:
            raise RuntimeError("A requirement cannot be empty")

        return text

    def read_files(self):
        with zipfile.ZipFile(self.source) as archive:
            files = {info: archive.read(info) for info in archive.infolist()}

        named = {info.filename: data for info, data in files.items()}

        if DOCUMENT not in named:
            raise RuntimeError(f"{self.source} has no {DOCUMENT}")

        self.infos = list(files)

        return named

    def write_files(self, files, path):
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            for info in self.infos:
                archive.writestr(info.filename, files[info.filename])

    def read_rows(self, data):
        """
        Reads the requirements of the matrix.

        Args:
            data (bytes): Content of the Word document.

        Returns:
            tuple[str, str][]: Id and text of every requirement.
        """
        rows = []

        for row in ROW.findall(data.decode("utf-8")):
            cells = [self.read_cell(cell) for cell in CELL.findall(row)]

            if len(cells) == 2 and re.fullmatch(ID_PATTERN, cells[0]):
                rows.append((cells[0], cells[1]))

        if not rows:
            raise RuntimeError(f"No requirement rows (R01, R02, ...) in {self.source}")

        return rows

    def read_cell(self, cell):
        return html.unescape("".join(TEXT.findall(cell))).strip()

    def check(self, texts, rows):
        known = {re.sub(r"\W+", "", text).casefold(): id for id, text in rows}

        for text in texts:
            key = re.sub(r"\W+", "", text).casefold()

            if key in known:
                raise RuntimeError(f"Already in the matrix as {known[key]}: {text}")

        if len(set(re.sub(r"\W+", "", text).casefold() for text in texts)) != len(texts):
            raise RuntimeError("The same requirement was given twice")

    def name(self, texts, rows):
        last = max(int(re.fullmatch(ID_PATTERN, id).group(1)) for id, _ in rows)

        return [(ID_FORMAT.format(last + number), text) for number, text in enumerate(texts, 1)]

    def insert(self, data, added):
        """
        Adds the rows at the end of the table.

        Args:
            data (bytes): Content of the Word document.
            added (tuple[str, str][]): Id and text of the new requirements.

        Returns:
            bytes: Content of the changed Word document.
        """
        document = data.decode("utf-8")
        rows = [
            row for row in ROW.findall(document)
            if len(CELL.findall(row)) == 2
            and re.fullmatch(ID_PATTERN, self.read_cell(CELL.findall(row)[0]))
        ]
        template = rows[-1]
        end = document.rfind("</w:tbl>")

        if end == -1 or document.rfind(template) > end:
            raise RuntimeError("The table of the matrix cannot be read")

        new_rows = "".join(self.build_row(template, id, text) for id, text in added)

        return (document[:end] + new_rows + document[end:]).encode("utf-8")

    def build_row(self, template, identifier, text):
        row = IDENTITY.sub("", template).replace("<w:lastRenderedPageBreak/>", "")
        first, second = CELL.findall(row)

        row = row.replace(second, self.build_cell(second, text))

        return row.replace(first, self.build_cell(first, identifier))

    def build_cell(self, cell, text):
        end = cell.find("</w:pPr>")
        run = RUN_PROPERTIES.search(cell)

        if end == -1 or not run:
            raise RuntimeError("A row of the matrix cannot be used as a template")

        end += len("</w:pPr>")
        run_properties = run.group(1)

        return (
            f"{cell[:end]}<w:r>{run_properties}"
            f"<w:t xml:space=\"preserve\">{escape(text)}</w:t></w:r></w:p></w:tc>"
        )

    def replace(self, path, target):
        """
        Replaces a file with a copy, that is written next to it first.

        Args:
            path (Path): Path of the new file.
            target (Path): Path of the replaced file.
        """
        target.parent.mkdir(parents=True, exist_ok=True)
        staged = target.with_name(f".{target.name}.new")

        try:
            shutil.copyfile(path, staged)
            os.replace(staged, target)
        finally:
            staged.unlink(missing_ok=True)


def parse_args(args):
    parser = argparse.ArgumentParser(description="Add requirements to the requirements matrix.")
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("list", help="print the requirements of the matrix")
    add = commands.add_parser("add", help="add requirements and export the PDF")
    add.add_argument("texts", nargs="+", help="text of a new requirement")

    return parser.parse_args(args)


def run_cli(args):
    """
    Runs the editor from the command line.

    Args:
        args (str[]): Command line arguments.

    Returns:
        int: Exit code.
    """
    sys.stdout.reconfigure(errors="replace")

    arguments = parse_args(args)

    try:
        editor = RequirementsMatrixEditor(ROOT)

        if arguments.command == "list":
            for identifier, text in editor.list():
                print(f"{identifier}\t{text}")
            return 0

        for identifier, text in editor(arguments.texts):
            print(f"{identifier}\t{text}")

        print(f"Matrix: {editor.source}")
        print(f"PDF: {editor.target}")
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(error)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(run_cli(sys.argv[1:]))
