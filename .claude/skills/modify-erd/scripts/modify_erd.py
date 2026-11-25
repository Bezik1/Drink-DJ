"""
Drawing, saving and checking of a Chen ERD, that is described in a JSON model.
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

from classes.ChenLayout import ChenLayout
from classes.DrawioDiagram import DrawioDiagram, is_unchanged, read_page_size, save_diagram
from classes.ErdModel import ErdModel
from classes.RequirementsMatrix import RequirementsMatrix, read_pdf_pages, read_pdf_size
from const.general import PATHS, PDF_PAGE


class ErdEditor:
    """
    Editor of a Chen ERD. The diagram is always built again from its model,
    so a change of the model is the only way to change the diagram.

    Args:
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, matrix=None):
        self.matrix = RequirementsMatrix(ROOT, matrix)()

    def __call__(self, path):
        """
        Builds the diagram from a model.

        Args:
            path (Path): Path of the JSON model.

        Returns:
            Element: mxGraphModel element.
        """
        self.model = ErdModel(path, self.matrix)()
        self.layout = ChenLayout(self.model)()

        return DrawioDiagram(self.layout)()

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
        print(f"Smallest text on {self.layout.paper}: {self.layout.printed_font:.1f} pt")

    def save(self, path, force=False):
        """
        Saves the diagram to the artifacts of the conceptual design.

        Args:
            path (Path): Path of the JSON model.
            force (bool, optional): Whether a diagram edited by someone else
                can be replaced. Default: False.
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

        Rules:
            - The PDF has one page.
            - A name is in the PDF as many times as in the model.
            - The page is as big as in the diagram, so the padding is not cropped.

        Args:
            path (Path): Path of the JSON model.
            pdf (Path): Path of the exported PDF.
        """
        model = ErdModel(path, self.matrix)()
        pages = read_pdf_pages(pdf)
        content = self.compact("".join(line for page in pages for line in page))
        names = [self.compact(name) for name in model.names()]
        missing = [
            name for name in dict.fromkeys(model.names())
            if content.count(self.compact(name)) < sum(
                other.count(self.compact(name)) for other in names
            )
        ]

        if len(pages) != 1:
            raise RuntimeError(f"PDF has {len(pages)} pages instead of 1")
        if missing:
            raise RuntimeError(f"Missing in the PDF: {', '.join(missing)}")

        self.check_padding(ROOT / PATHS["artifacts"] / f"{path.stem}.drawio", pdf)

        print(f"Verified: 1 page with padding, all {len(names)} names are present")

    def compact(self, text):
        return re.sub(r"\s+", "", text).casefold()

    def check_padding(self, diagram, pdf):
        """
        Compares the page of the PDF with the page of the diagram.

        Args:
            diagram (Path): Path of the saved draw.io file.
            pdf (Path): Path of the exported PDF.

        Raises:
            RuntimeError: The pages differ, so the padding was lost.
        """
        expected = [side * PDF_PAGE["px_to_pt"] for side in read_page_size(diagram)]

        for wanted, actual in zip(expected, read_pdf_size(pdf)):
            if abs(wanted - actual) > wanted * PDF_PAGE["tolerance"]:
                raise RuntimeError(
                    "The PDF does not have the page and padding of the diagram. "
                    "Export it again without --crop."
                )


def parse_args():
    parser = argparse.ArgumentParser(description="Draw, save and check an ERD from its model.")
    parser.add_argument("command", choices=["render", "save", "verify"])
    parser.add_argument("model", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--force", action="store_true")

    args = parser.parse_args()

    if args.command == "render" and args.out is None:
        parser.error("--out is required")
    if args.command == "verify" and args.pdf is None:
        parser.error("--pdf is required")

    return args


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        editor = ErdEditor(args.matrix)

        if args.command == "render":
            editor.render(args.model, args.out)
        elif args.command == "save":
            editor.save(args.model, args.force)
        else:
            editor.verify(args.model, args.pdf)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
