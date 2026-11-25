"""
Constraints of a UML class diagram, that UML cannot show, as a Word file and a PDF.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-word" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-uml" / "scripts"))
sys.path.insert(1, str(SCRIPTS))

from classes.ErdSource import ErdSource
from classes.UmlModel import UmlModel
from constraints_const import PATHS, SUFFIX
from constraints_document import ConstraintsDocument
from constraints_draft import ConstraintsDraft
from constraints_model import ConstraintsModel
from docx_to_pdf import DocxToPdfConverter
from modify_word import WordDocument


class UmlConstraints:
    """
    Writer of the file with the constraints of a UML class diagram.

    Args:
        uml (Path): JSON model of the UML. Default: the official one.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, uml=None, erd=None, matrix=None):
        self.source = ErdSource(ROOT, erd, matrix)()
        self.uml = UmlModel(Path(uml or ROOT / PATHS["uml"]).resolve(), self.source)()

    def default_path(self):
        return ROOT / PATHS["artifacts"] / f"{self.uml.path.stem}{SUFFIX}.json"

    def draft(self, out=None, force=False):
        """
        Writes the candidates of the constraints. They need a review.

        Args:
            out (Path, optional): Path of the JSON file. Default: next to the UML model.
            force (bool, optional): Overwrite an existing file. Default: False.
        """
        out = out or self.default_path()

        if out.exists() and not force:
            raise RuntimeError(f"{out} exists. Use --force, after the user agrees.")

        data = ConstraintsDraft(self.source, self.uml)()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(f"Constraints: {out}")

        for item in data["constraints"]:
            print(f"  {item['id']} [{item['kind']}] {item['text']}")

    def show(self, path):
        model = ConstraintsModel(path, self.source, self.uml)()

        for item in model.items:
            classes = ", ".join(self.uml.classes[key]["name"] for key in item["classes"])

            print(f"{item['id']} [{item['kind']}] ({classes}) {item['text']}")

    def build(self, path, force=False):
        """
        Writes the Word file in `artifacts` and its PDF in `documents`.

        Args:
            path (Path): Path of the JSON file of the constraints.
            force (bool, optional): Overwrite a Word file made by someone else. Default: False.

        Returns:
            Path: Path of the PDF.
        """
        model = ConstraintsModel(path, self.source, self.uml)()
        document = ROOT / PATHS["artifacts"] / f"{path.stem}.docx"
        pdf = ROOT / PATHS["documents"] / f"{path.stem}.pdf"

        WordDocument(ConstraintsDocument(model, self.uml)())(document, force)
        pdf.parent.mkdir(parents=True, exist_ok=True)
        DocxToPdfConverter()(document, pdf)

        print(f"Word: {document}")
        print(f"PDF: {pdf}")

        return pdf

    def verify(self, path, pdf):
        """
        Checks the PDF: every constraint is in it.

        Args:
            path (Path): Path of the JSON file of the constraints.
            pdf (Path): Path of the PDF.
        """
        model = ConstraintsModel(path, self.source, self.uml)()
        pages = self.source.read_pdf_pages(pdf)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        missing = [
            item["id"] for item in model.items
            if re.sub(r"\s+", "", item["text"]).casefold() not in content
        ]

        if missing:
            raise RuntimeError(f"Missing in the PDF: {', '.join(missing)}")

        print(f"Verified: {len(pages)} page(s), all {len(model.items)} constraints are present")


def parse_args():
    parser = argparse.ArgumentParser(description="Write the constraints, that UML cannot show.")
    parser.add_argument("command", choices=["draft", "show", "build", "verify"])
    parser.add_argument("file", nargs="?", type=Path, help="JSON file of the constraints")
    parser.add_argument("--uml", type=Path)
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--force", action="store_true")

    args = parser.parse_args()

    if args.command in ("show", "build", "verify") and args.file is None:
        parser.error("the JSON file of the constraints is required")
    if args.command == "verify" and args.pdf is None:
        parser.error("--pdf is required")

    return args


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        tool = UmlConstraints(args.uml, args.erd, args.matrix)

        if args.command == "draft":
            tool.draft(args.file, args.force)
        elif args.command == "show":
            tool.show(args.file)
        elif args.command == "build":
            tool.build(args.file, args.force)
        else:
            tool.verify(args.file, args.pdf)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
