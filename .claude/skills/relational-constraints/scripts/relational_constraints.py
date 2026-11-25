"""
Constraints of a relational model, that its diagram cannot show, as a Word file and a PDF.
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
sys.path.insert(0, str(SKILLS / "modify-relational" / "scripts"))
sys.path.insert(1, str(SCRIPTS))

from classes.RelationalModel import RelationalModel
from classes.UmlSource import UmlSource
from const.general import NAMES, PATHS
from docx_to_pdf import DocxToPdfConverter
from modify_word import WordDocument
from relational_constraints_document import RelationalConstraintsDocument
from relational_constraints_draft import RelationalConstraintsDraft
from relational_constraints_model import RelationalConstraintsModel, output_paths
from utils.naming import constraints_stem


class RelationalConstraints:
    """
    Writer of the file with the constraints of a relational model.

    Args:
        model (Path, optional): JSON file of the relational model. Default: the official one.
        uml (Path, optional): JSON model of the UML. Default: the official one.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, model=None, uml=None, erd=None, matrix=None):
        self.source = UmlSource(ROOT, uml, erd, matrix)()
        path = Path(model or ROOT / PATHS["artifacts"] / f"{NAMES['default']}.json").resolve()

        if not path.is_file():
            raise RuntimeError(f"Relational model not found: {path}. Create it with the uml-to-relational skill.")
        if not self.source.constraints_path.is_file():
            raise RuntimeError("The UML has no constraints. Write them with the uml-constraints skill first.")

        self.model = RelationalModel(path, self.source)()

    def default_path(self):
        return self.model.path.with_name(f"{constraints_stem(self.model.path.stem)}.json")

    def read(self, path):
        return RelationalConstraintsModel(path, self.source, self.model)()

    def draft(self, out=None, force=False):
        """
        Writes the candidates of the constraints. They need a review.

        Args:
            out (Path, optional): Path of the JSON file. Default: next to the relational model.
            force (bool, optional): Overwrite an existing file. Default: False.
        """
        out = out or self.default_path()

        if out.exists() and not force:
            raise RuntimeError(f"{out} exists. Use --force, after the user agrees.")

        data = RelationalConstraintsDraft(self.source, self.model)()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(f"Constraints: {out}")

        for item in data["constraints"]:
            print(f"  {item['id']} [{item['kind']}] {item['text']}")
        for key, reason in data["covered"].items():
            print(f"  covered {key}: {reason}")

    def show(self, path):
        model = self.read(path)

        for item in model.items:
            print(f"{item['id']} [{item['kind']}] ({', '.join(item['tables'])}) {item['text']}")
        for key, reason in model.covered.items():
            print(f"covered {key}: {reason}")

    def build(self, path, force=False):
        """
        Writes the Word file and its PDF.

        Args:
            path (Path): Path of the JSON file of the constraints.
            force (bool, optional): Overwrite a Word file made by someone else. Default: False.

        Returns:
            Path: Path of the PDF.
        """
        model = self.read(path)
        document, pdf = output_paths(path)

        WordDocument(RelationalConstraintsDocument(model)())(document, force)
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
        model = self.read(path)
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
    parser = argparse.ArgumentParser(description="Write the constraints, that a relational model cannot show.")
    parser.add_argument("command", choices=["draft", "show", "build", "verify"])
    parser.add_argument("file", nargs="?", type=Path, help="JSON file of the constraints")
    parser.add_argument("--model", type=Path, help="JSON file of the relational model")
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
        tool = RelationalConstraints(args.model, args.uml, args.erd, args.matrix)
        file = args.file.resolve() if args.file else None

        if args.command == "draft":
            tool.draft(file, args.force)
        elif args.command == "show":
            tool.show(file)
        elif args.command == "build":
            tool.build(file, args.force)
        else:
            tool.verify(file, args.pdf)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
