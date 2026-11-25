"""
Conversion of a Markdown file to a landscape PDF with bordered tables.
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "docx-to-pdf" / "scripts"))

from docx_to_pdf import TIMEOUT, DocxToPdfConverter, run_cli

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

PANDOC_PATHS = [
    "/opt/homebrew/bin/pandoc",
    "/usr/local/bin/pandoc",
    "/usr/bin/pandoc",
    r"C:\Program Files\Pandoc\pandoc.exe",
    "~/AppData/Local/Pandoc/pandoc.exe",
]

PAGE = {
    "width": 16838,
    "height": 11906,
    "margin": 1440,
}

TEXT_WIDTH = PAGE["width"] - 2 * PAGE["margin"]
CELL_PADDING = 260
MAX_WORD_SHARE = 0.25

FONT = "Arial"
FONT_SIZE = 12
WIDE_TABLE_FONT_SIZE = 10
WIDE_TABLE_COLUMNS = 5

BORDER_SIDES = ["top", "left", "bottom", "right", "insideH", "insideV"]


class MdToPdfConverter(DocxToPdfConverter):
    """
    Converter of Markdown to PDF, that uses the look of the requirements
    matrix: landscape A4, Arial, black text and bordered tables.
    """

    def __init__(self):
        super().__init__()
        self.pandoc = self.find_pandoc()

    def __call__(self, source, target):
        """
        Converts Markdown to PDF through a temporary Word document.

        Args:
            source (Path): Path of the Markdown file.
            target (Path): Path of the created PDF.
        """
        with tempfile.TemporaryDirectory() as work:
            docx = Path(work, f"{source.stem}.docx")

            self.build_docx(source, docx)
            self.build_style(docx)
            self.export(docx, target, "pdf")

    def find_pandoc(self):
        candidates = [shutil.which("pandoc")]
        candidates.extend(os.path.expanduser(path) for path in PANDOC_PATHS)

        for path in candidates:
            if path and os.path.isfile(path):
                return path

        raise RuntimeError("pandoc not found. Install it from https://pandoc.org/")

    def run_pandoc(self, args, cwd, data=None):
        result = subprocess.run(
            [self.pandoc, *args],
            input=data,
            capture_output=True,
            cwd=str(cwd),
            timeout=TIMEOUT
        )
        errors = result.stderr.decode("utf-8", "replace").strip()

        if result.returncode != 0 or "Could not fetch resource" in errors:
            raise RuntimeError(f"pandoc failed: {errors}")

        return result.stdout

    def build_docx(self, source, docx):
        """
        Builds the Word document. Paths of images are relative to the
        Markdown file and HTML line breaks are kept.

        Args:
            source (Path): Path of the Markdown file.
            docx (Path): Path of the created Word document.
        """
        tree = json.loads(
            self.run_pandoc([str(source), "-t", "json"], source.parent)
        )
        tree = self.keep_line_breaks(tree)

        self.run_pandoc(
            ["-f", "json", "-o", str(docx)],
            source.parent,
            json.dumps(tree).encode("utf-8")
        )

    def keep_line_breaks(self, node):
        if isinstance(node, list):
            return [self.keep_line_breaks(item) for item in node]
        if not isinstance(node, dict):
            return node

        if node.get("t") == "RawInline":
            file_format, text = node["c"]

            if file_format == "html" and re.fullmatch(r"<br\s*/?>", text, re.I):
                return {"t": "LineBreak"}

        return {key: self.keep_line_breaks(value) for key, value in node.items()}

    def build_style(self, docx):
        with zipfile.ZipFile(docx) as archive:
            files = {name: archive.read(name) for name in archive.namelist()}

        document = self.parse(files["word/document.xml"])
        styles = self.parse(files["word/styles.xml"])

        self.build_page(document)
        self.build_fonts(styles)

        for table in document.iter(f"{W}tbl"):
            self.build_table(table)

        files["word/document.xml"] = ET.tostring(document, encoding="utf-8")
        files["word/styles.xml"] = ET.tostring(styles, encoding="utf-8")

        with zipfile.ZipFile(docx, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in files.items():
                archive.writestr(name, data)

    def parse(self, data):
        for _, (prefix, uri) in ET.iterparse(io.BytesIO(data), ["start-ns"]):
            ET.register_namespace(prefix, uri)

        return ET.fromstring(data)

    def add(self, parent, tag, **attributes):
        return ET.SubElement(
            parent,
            f"{W}{tag}",
            {f"{W}{key}": str(value) for key, value in attributes.items()}
        )

    def child(self, parent, tag):
        element = parent.find(f"{W}{tag}")

        if element is None:
            element = ET.Element(f"{W}{tag}")
            parent.insert(0, element)

        return element

    def build_page(self, document):
        body = document.find(f"{W}body")

        for section in body.findall(f"{W}sectPr"):
            body.remove(section)

        section = self.add(body, "sectPr")
        self.add(section, "pgSz", w=PAGE["width"], h=PAGE["height"], orient="landscape")
        self.add(
            section, "pgMar",
            top=PAGE["margin"], right=PAGE["margin"],
            bottom=PAGE["margin"], left=PAGE["margin"],
            header=708, footer=708, gutter=0
        )

    def build_fonts(self, styles):
        for fonts in styles.iter(f"{W}rFonts"):
            if any(key.lower().endswith("theme") for key in fonts.attrib):
                fonts.attrib.clear()

                for key in ("ascii", "hAnsi", "cs", "eastAsia"):
                    fonts.set(f"{W}{key}", FONT)

        for style in styles.findall(f"{W}style"):
            if style.get(f"{W}type") == "paragraph":
                for color in style.iter(f"{W}color"):
                    color.attrib.clear()
                    color.set(f"{W}val", "000000")

    def build_table(self, table):
        """
        Table rules:
        - Table fills the width of the text and has borders.
        - Header is bold and repeated on every page.
        - Rows are not split between pages.
        - Column is not narrower than its longest word.
        """
        rows = table.findall(f"{W}tr")
        cells = [row.findall(f"{W}tc") for row in rows]
        columns = max((len(row) for row in cells), default=0)

        if not columns:
            return

        size = FONT_SIZE if columns < WIDE_TABLE_COLUMNS else WIDE_TABLE_FONT_SIZE
        properties = self.child(table, "tblPr")
        look = properties.find(f"{W}tblLook")
        has_header = look is not None and look.get(f"{W}firstRow") == "1"

        for element in list(properties):
            if element.tag != f"{W}tblStyle":
                properties.remove(element)

        self.add(properties, "tblW", w=TEXT_WIDTH, type="dxa")
        self.add(properties, "jc", val="center")
        borders = self.add(properties, "tblBorders")

        for side in BORDER_SIDES:
            self.add(borders, side, val="single", sz=4, space=0, color="000000")

        self.add(properties, "tblLayout", type="fixed")

        grid = table.find(f"{W}tblGrid")

        if grid is None:
            grid = ET.Element(f"{W}tblGrid")
            table.insert(1, grid)

        for column in list(grid):
            grid.remove(column)

        for width in self.column_widths(cells, columns, size, has_header):
            self.add(grid, "gridCol", w=width)

        for index, row in enumerate(rows):
            is_header = has_header and index == 0
            row_properties = self.child(row, "trPr")
            self.add(row_properties, "cantSplit")

            if is_header:
                self.add(row_properties, "tblHeader")

            for run in row.iter(f"{W}r"):
                run_properties = self.child(run, "rPr")

                if is_header:
                    self.add(run_properties, "b")

                self.add(run_properties, "sz", val=2 * size)

    def column_widths(self, cells, columns, size, has_header):
        """
        Calculates widths of the columns from their content.

        Args:
            cells (Element[rows][columns]): Cells of the table.
            columns (int): Number of the columns.
            size (int): Font size in points.
            has_header (bool): Whether the first row is a header.

        Returns:
            int[columns]: Widths of the columns in twips.
        """
        minimums = [CELL_PADDING] * columns
        weights = [1] * columns

        for row_index, row in enumerate(cells):
            scale = 1.1 if has_header and row_index == 0 else 1

            for column, cell in enumerate(row):
                text = self.cell_text(cell)
                weights[column] += len(text)

                for word in text.split():
                    width = self.word_width(word) * size * 20 * scale
                    width = min(width, TEXT_WIDTH * MAX_WORD_SHARE) + CELL_PADDING
                    minimums[column] = max(minimums[column], width)

        if sum(minimums) >= TEXT_WIDTH:
            return [round(m * TEXT_WIDTH / sum(minimums)) for m in minimums]

        fixed = set()

        while True:
            space = TEXT_WIDTH - sum(minimums[i] for i in fixed)
            total = sum(weights[i] for i in range(columns) if i not in fixed)
            widths = [
                minimums[i] if i in fixed else space * weights[i] / total
                for i in range(columns)
            ]
            narrow = {i for i in range(columns) if widths[i] < minimums[i]}

            if not narrow:
                return [round(width) for width in widths]

            fixed |= narrow

    def cell_text(self, cell):
        parts = []

        for element in cell.iter():
            if element.tag == f"{W}t":
                parts.append(element.text or "")
            elif element.tag in (f"{W}br", f"{W}p"):
                parts.append(" ")

        return "".join(parts)

    def word_width(self, word):
        return sum(
            0.32 if char in "iljtfrI.,:;!|'()[]-/" else
            0.86 if char in "mwMW@%" else
            0.68 if char.isupper() else
            0.56
            for char in word
        )


if __name__ == "__main__":
    sys.exit(run_cli(sys.argv[1:], MdToPdfConverter, ".md"))
