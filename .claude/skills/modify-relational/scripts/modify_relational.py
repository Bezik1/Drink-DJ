"""
Changing, drawing, saving and checking of a relational model, that is described in a JSON model.
"""
import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SCRIPTS))

from classes.RelationalDiagram import RelationalDiagram
from classes.RelationalEditor import OPERATIONS, RelationalEditor
from classes.RelationalLayout import RelationalLayout
from classes.RelationalModel import RelationalModel
from classes.UmlSource import UmlSource
from const.general import NAMES, PATHS
from utils.drawio_file import is_unchanged, save_diagram
from utils.sql import column_text
from utils.validation import run_validation


class RelationalWorkbench:
    """
    Editor of a relational model. The diagram is always built again from its
    JSON model, so a change of the model is the only way to change the diagram.

    Args:
        uml (Path, optional): JSON model of the UML. Default: the official one.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, uml=None, erd=None, matrix=None):
        self.uml = uml
        self.erd = erd
        self.matrix = matrix
        self.source = UmlSource(ROOT, uml, erd, matrix)()

    def __call__(self, path):
        """
        Builds the diagram from a model.

        Args:
            path (Path): Path of the JSON model of the relational model.

        Returns:
            Element: mxGraphModel element.
        """
        self.model = RelationalModel(path, self.source)()
        self.layout = RelationalLayout(self.model)()

        return RelationalDiagram(self.layout)()

    def show(self, path):
        """
        Prints the model as text, with the cells, so a change can be planned.

        Args:
            path (Path): Path of the JSON model.
        """
        model = RelationalModel(path, self.source)()

        for name, table in model.tables.items():
            origin = table.get("class") or table.get("association") or table.get("attribute") or "assumed"

            print(f"{name}  [{origin}]  cell {table['cell']}")

            for column in table["columns"]:
                key = "PK" in model.marker(name, column["name"])
                print(f"    {model.marker(name, column['name']):8} {column['name']:28} {column_text(column, key)}")
            for item in table.get("foreign_keys", []):
                print(
                    f"    FK ({', '.join(item['columns'])}) -> {item['references']} "
                    f"({', '.join(item['to'])}) {item['multiplicity']} ON DELETE {item['on_delete']}"
                )
            for group in table.get("unique", []):
                print(f"    UNIQUE ({', '.join(group)})")
            for item in table.get("omitted", []):
                print(f"    not stored: {item['uml']}")

        for warning in model.warnings:
            print(f"Warning: {warning}")

    def edit(self, path, operation, arguments):
        """
        Applies one change of the model with `RelationalEditor`.

        Args:
            path (Path): Path of the JSON model.
            operation (str): Name of the change, for example "rename-table".
            arguments (str[]): Arguments of the change.
        """
        print(RelationalEditor(path, self.source)(operation, *arguments))

    def render(self, path, out):
        """
        Writes the XML of the diagram for the draw.io MCP.

        Args:
            path (Path): Path of the JSON model.
            out (Path): Path of the created XML file.
        """
        diagram = self(path)
        out.write_bytes(ET.tostring(diagram))

        print(f"XML: {out}")
        print(f"Size: {self.layout.width} x {self.layout.height} px")

        for warning in self.model.warnings + self.layout.warnings:
            print(f"Warning: {warning}")

    def save(self, path, force=False):
        """
        Writes the .drawio file in `spec/logical/artifacts`.

        Args:
            path (Path): Path of the JSON model.
            force (bool, optional): Overwrite a file edited by someone else. Default: False.
        """
        if not re.fullmatch(r"[a-z0-9_]+", path.stem):
            raise RuntimeError("Name must be lowercase, with words separated by underscores")

        diagram = self(path)
        target = ROOT / PATHS["artifacts"] / f"{path.stem}.drawio"

        if target.exists() and not force and not is_unchanged(target):
            raise RuntimeError(
                f"{target} was created or edited by someone else. Ask the user, before using --force."
            )

        save_diagram(diagram, target, path.stem)
        (ROOT / PATHS["documents"]).mkdir(parents=True, exist_ok=True)

        print(f"Diagram: {target}")

    def verify(self, path, pdf):
        """
        Checks the exported PDF: 1 page with every name of the diagram.

        Args:
            path (Path): Path of the JSON model.
            pdf (Path): Path of the exported PDF.
        """
        model = RelationalModel(path, self.source)()
        pages = self.source.read_pdf_pages(pdf)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        missing = [name for name in model.names() if re.sub(r"\s+", "", name).casefold() not in content]

        if len(pages) != 1:
            raise RuntimeError(f"PDF has {len(pages)} pages instead of 1")
        if missing:
            raise RuntimeError(f"Missing in the PDF: {', '.join(missing)}")

        print(f"Verified: 1 page, all {len(model.names())} names are present")

    def check(self, path, pdf=None):
        """
        Validates the saved diagram with the `validate-relational` skill.

        Args:
            path (Path): Path of the JSON model.
            pdf (Path, optional): Official PDF of the diagram.

        Returns:
            int: Exit code of the validation.
        """
        return run_validation(ROOT, path, self.uml, self.erd, self.matrix, pdf)


def parse_args():
    parser = argparse.ArgumentParser(description="Change, draw and check a relational model.")
    parser.add_argument("command", choices=["show", "edit", "render", "save", "verify", "check"])
    parser.add_argument("model", type=Path)
    parser.add_argument("arguments", nargs="*")
    parser.add_argument("--uml", type=Path)
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--force", action="store_true")

    args = parser.parse_args()

    if args.command == "edit" and not args.arguments:
        parser.error(f"edit needs a change: {', '.join(OPERATIONS)}")
    if args.command != "edit" and args.arguments:
        parser.error(f"unexpected arguments: {' '.join(args.arguments)}")
    if args.command == "render" and args.out is None:
        parser.error("--out is required")
    if args.command == "verify" and args.pdf is None:
        parser.error("--pdf is required")

    return args


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        workbench = RelationalWorkbench(args.uml, args.erd, args.matrix)
        model = args.model.resolve()

        if args.command == "show":
            workbench.show(model)
        elif args.command == "edit":
            workbench.edit(model, args.arguments[0], args.arguments[1:])
        elif args.command == "render":
            workbench.render(model, args.out)
        elif args.command == "save":
            workbench.save(model, args.force)
        elif args.command == "verify":
            workbench.verify(model, args.pdf)
        else:
            sys.exit(workbench.check(model, args.pdf))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
