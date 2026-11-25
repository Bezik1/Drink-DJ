"""
Coverage of the functional and non-functional requirements by the conceptual
design: its draft and its summary. The validators of the ERD, the UML and the
relational model check it.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-erd" / "scripts"))
sys.path.insert(1, str(SCRIPTS))

from classes.ErdModel import ErdModel
from classes.RequirementsMatrix import RequirementsMatrix, read_pdf_pages
from const.general import PATHS as ERD_PATHS
from requirements_coverage_const import PATHS
from requirements_coverage_draft import CoverageDraft
from requirements_coverage_model import RequirementsCoverage, erd_elements


class RequirementsCoverageTool:
    """
    Writer and reader of the coverage of the requirements.

    Args:
        path (Path, optional): Coverage file. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, path=None, matrix=None):
        self.path = Path(path or ROOT / PATHS["coverage"]).resolve()
        self.coverage = RequirementsCoverage(ROOT, read_pdf_pages, self.path)()
        matrix = RequirementsMatrix(ROOT, matrix)()
        self.erd = ErdModel(ROOT / ERD_PATHS["artifacts"] / f"{ERD_PATHS['erd_name']}.json", matrix)()

    def draft(self, force=False):
        """
        Writes the candidates of the coverage. Every entry needs a review.

        Args:
            force (bool, optional): Overwrite an existing file. Default: False.
        """
        if self.path.exists() and not force:
            raise RuntimeError(f"{self.path} exists. Use --force, after the user agrees.")

        data = CoverageDraft(self.coverage, self.erd.entities)()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(f"Coverage: {self.path}")
        print(f"Requirements: {len(data['requirements'])}. Review every entry, its status is 'review'.")

    def show(self):
        """
        Prints every requirement with its status, and checks the file
        against the documents and the ERD.

        Returns:
            int: 0 when the file is valid for the ERD, 1 otherwise.
        """
        for item in self.coverage.items:
            detail = item.get("reason") or ", ".join(item.get("elements", []))

            print(f"{item.get('id')} [{item.get('significance')}] {item.get('status')}: {detail}")

            for gap in item.get("gaps", []):
                print(f"    gap ({gap.get('level')}): {gap.get('text')}")

        errors, warnings, notes = self.coverage.check(
            "erd", erd_elements(self.erd.entities, self.erd.relationships)
        )

        for label, items in (("Error", errors), ("Warning", warnings), ("Note", notes)):
            for item in items:
                print(f"{label}: {item}")

        return 1 if errors else 0


def parse_args():
    parser = argparse.ArgumentParser(description="Draft or show the coverage of the requirements.")
    parser.add_argument("command", choices=["draft", "show"])
    parser.add_argument("file", nargs="?", type=Path, help="Coverage file")
    parser.add_argument("--matrix")
    parser.add_argument("--force", action="store_true")

    return parser.parse_args()


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        tool = RequirementsCoverageTool(args.file, args.matrix)

        if args.command == "draft":
            tool.draft(args.force)
        else:
            sys.exit(tool.show())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
