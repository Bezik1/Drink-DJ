"""
Changing, drawing, saving and checking of a UML class diagram, that is described in a JSON model.
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

from classes.ErdSource import ErdSource
from classes.UmlDiagram import UmlDiagram
from classes.UmlEditor import UmlEditor
from classes.UmlLayout import UmlLayout, attribute_line, operation_line
from classes.UmlModel import UmlModel
from const.general import PATHS
from utils.drawio_file import is_unchanged, save_diagram
from utils.validation import run_validation


class UmlWorkbench:
    """
    Editor of a UML class diagram. The diagram is always built again from its
    model, so a change of the model is the only way to change the diagram.

    Args:
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, erd=None, matrix=None):
        self.erd = erd
        self.matrix = matrix
        self.source = ErdSource(ROOT, erd, matrix)()

    def __call__(self, path):
        """
        Builds the diagram from a model.

        Args:
            path (Path): Path of the JSON model of the UML.

        Returns:
            Element: mxGraphModel element.
        """
        self.model = UmlModel(path, self.source)()
        self.layout = UmlLayout(self.model)()

        return UmlDiagram(self.layout)()

    def show(self, path):
        """
        Prints the model as text, with the cells, so a change can be planned.

        Args:
            path (Path): Path of the JSON model of the UML.
        """
        model = UmlModel(path, self.source)()

        for key, item in model.classes.items():
            kind = f" «{item['stereotype']}»" if item.get("stereotype") else ""

            place = "top right corner" if item.get("stereotype") == "enumeration" else f"cell {item['cell']}"

            print(f"{item['name']}{kind}  [{key}]  {place}")

            for value in item.get("values", []):
                print(f"    {value}")
            for attribute in item.get("attributes", []):
                print(f"    {attribute_line(attribute)}")
            for operation in item.get("operations", []):
                print(f"    {operation_line(operation)}")

        for item in model.associations:
            ends = ", ".join(
                f"{model.classes[key.split(':')[0]]['name']}{' (' + key.split(':')[1] + ')' if ':' in key else ''} {value}"
                for key, value in item["ends"].items()
            )

            print(f"{item['name']} ({item.get('kind', 'association')}): {ends}")

    def edit(self, path, operation, arguments, reason=None):
        print(UmlEditor(path, self.source)(operation, *arguments, reason=reason))

    def render(self, path, out):
        """
        Writes the XML of the diagram for the draw.io MCP.

        Args:
            path (Path): Path of the JSON model of the UML.
            out (Path): Path of the created XML file.
        """
        diagram = self(path)
        out.write_bytes(ET.tostring(diagram))

        print(f"XML: {out}")
        print(f"Size: {self.layout.width} x {self.layout.height} px")

        for warning in self.layout.warnings:
            print(f"Warning: {warning}")

    def save(self, path, force=False):
        """
        Writes the .drawio file in `spec/conceptual/artifacts`.

        Args:
            path (Path): Path of the JSON model of the UML.
            force (bool, optional): Overwrite a file edited by someone else. Default: False.
        """
        if not re.fullmatch(r"[a-z0-9_]+", path.stem):
            raise RuntimeError("Name must be lowercase, with words separated by underscores")

        diagram = self(path)
        target = ROOT / PATHS["artifacts"] / f"{path.stem}.drawio"

        if target.exists() and not force and not is_unchanged(target):
            raise RuntimeError(
                f"{target} was created or edited by someone else. "
                "Ask the user, before using --force."
            )

        save_diagram(diagram, target, path.stem)
        (ROOT / PATHS["documents"]).mkdir(parents=True, exist_ok=True)

        print(f"Diagram: {target}")

    def verify(self, path, pdf):
        """
        Checks the exported PDF.

        Args:
            path (Path): Path of the JSON model of the UML.
            pdf (Path): Path of the exported PDF.
        """
        model = UmlModel(path, self.source)()
        pages = self.source.read_pdf_pages(pdf)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        missing = [
            name for name in model.names()
            if re.sub(r"\s+", "", name).casefold() not in content
        ]

        if len(pages) != 1:
            raise RuntimeError(f"PDF has {len(pages)} pages instead of 1")
        if missing:
            raise RuntimeError(f"Missing in the PDF: {', '.join(missing)}")

        print(f"Verified: 1 page, all {len(model.names())} names are present")

    def check(self, path, pdf=None):
        """
        Validates the saved diagram with the `validate-uml` skill.

        Args:
            path (Path): Path of the JSON model of the UML.
            pdf (Path, optional): Official PDF of the diagram.

        Returns:
            int: Exit code of the validation.
        """
        return run_validation(ROOT, path, self.erd, self.matrix, pdf)


def parse_args():
    parser = argparse.ArgumentParser(description="Change, draw and check a UML class diagram.")
    parser.add_argument("command", choices=["show", "edit", "render", "save", "verify", "check"])
    parser.add_argument("model", type=Path)
    parser.add_argument("arguments", nargs="*")
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--reason")
    parser.add_argument("--force", action="store_true")

    args = parser.parse_args()

    if args.command == "edit" and not args.arguments:
        parser.error("edit needs an operation, for example: edit uml.json move Train 3 2")
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
        workbench = UmlWorkbench(args.erd, args.matrix)

        if args.command == "show":
            workbench.show(args.model)
        elif args.command == "edit":
            workbench.edit(args.model, args.arguments[0], args.arguments[1:], args.reason)
        elif args.command == "render":
            workbench.render(args.model, args.out)
        elif args.command == "save":
            workbench.save(args.model, args.force)
        elif args.command == "verify":
            workbench.verify(args.model, args.pdf)
        else:
            sys.exit(workbench.check(args.model, args.pdf))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
