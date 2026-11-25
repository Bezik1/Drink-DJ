"""
Transformation of a UML class diagram into the first model of a relational model.
The model is drawn, saved and changed by the modify-relational skill.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-relational" / "scripts"))

from classes.RelationalDraft import RelationalDraft
from classes.RelationalModel import RelationalModel
from classes.UmlSource import UmlSource
from const.general import NAMES, PATHS
from utils.validation import run_validation


class UmlToRelational:
    """
    Source of the relational model, which is the UML class diagram with its
    ERD, requirements matrix and constraints.

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

    def __call__(self):
        """
        Prints everything, that the relational model is made from.
        """
        source = self.source
        tables = source.table_classes()
        constraints = source.constraints_path

        print(f"matrix: {source.matrix.file}")
        print(f"erd: {source.erd_source.file} (sha256 {source.erd_source.sha256})")
        print(f"uml: {source.file} (sha256 {source.sha256})")
        print(f"classes as tables: {', '.join(source.classes[key]['name'] for key in tables)}")
        print(f"associations: {len(source.associations)}")
        print(f"uml constraints: {source.relative(constraints) if constraints.is_file() else 'missing'}")

        if not constraints.is_file():
            print("Write the UML constraints with the uml-constraints skill before the relational model.")

    def draft(self, out, force=False):
        """
        Writes the first version of the relational model with the rules of
        `RelationalDraft` of the `modify-relational` skill.

        Args:
            out (Path): Path of the JSON model.
            force (bool, optional): Overwrite an existing model. Default: False.
        """
        if out.exists() and not force:
            raise RuntimeError(f"{out} exists. Use --force, after the user agrees.")
        if not re.fullmatch(r"[a-z0-9_]+", out.stem):
            raise RuntimeError("Name must be lowercase, with words separated by underscores")

        drafter = RelationalDraft(self.source)
        data = drafter()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(f"Model: {out}")
        print(f"Tables: {', '.join(data['tables'])}")
        print("Review these decisions, and change the model with the modify-relational skill:")

        for line in dict.fromkeys(drafter.review):
            print(f"  {line}")

        try:
            RelationalModel(out, self.source)()
        except RuntimeError as error:
            print(f"The draft is not valid yet. Fix it with the modify-relational skill:\n{error}")

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
    parser = argparse.ArgumentParser(description="Transform the UML into the first relational model.")
    parser.add_argument("command", choices=["source", "draft", "check"])
    parser.add_argument(
        "model", nargs="?", type=Path, default=ROOT / PATHS["artifacts"] / f"{NAMES['default']}.json",
    )
    parser.add_argument("--uml", type=Path)
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--force", action="store_true")

    return parser.parse_args()


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        generator = UmlToRelational(args.uml, args.erd, args.matrix)
        model = args.model.resolve()

        if args.command == "source":
            generator()
        elif args.command == "draft":
            generator.draft(model, args.force)
        else:
            sys.exit(generator.check(model, args.pdf))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
