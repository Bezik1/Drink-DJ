"""
Transformation of the ERD into the first model of a UML class diagram.
The diagram itself is drawn by the modify-uml skill.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-uml" / "scripts"))

from classes.ErdSource import ErdSource
from classes.UmlDraft import UmlDraft
from const.general import NAMES, PATHS
from utils.validation import run_validation


class ErdToUml:
    """
    Source of the model of a UML class diagram, which is the ERD with the
    requirements matrix.

    Args:
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, erd=None, matrix=None):
        self.erd = erd
        self.matrix = matrix
        self.source = ErdSource(ROOT, erd, matrix)()

    def __call__(self):
        """
        Prints everything, that the UML is made from: the matrix, the ERD
        and what the ERD does not draw.
        """
        erd = self.source.model

        print(f"matrix: {self.source.matrix.file}")
        print(f"erd: {self.source.file} (sha256 {self.source.sha256})")
        print(f"entities: {', '.join(item['name'] for item in erd.entities.values())}")
        print(f"relationships: {len(erd.relationships)}")
        print(f"not drawn: {', '.join(erd.not_drawn) or 'none'}")

    def draft(self, out, force=False):
        """
        Writes the first version of the UML model with the transformation
        rules of `UmlDraft`.

        Args:
            out (Path): Path of the JSON model.
            force (bool, optional): Overwrite an existing model. Default: False.
        """
        if out.exists() and not force:
            raise RuntimeError(f"{out} exists. Use --force, after the user agrees.")

        model = UmlDraft(self.source)()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(model, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(f"Model: {out}")
        print("Types are guesses. Review them, and change them with the modify-uml skill:")

        for item in model["classes"].values():
            for attribute in item.get("attributes", []):
                if "erd" in attribute:
                    print(f"  {item['name']}.{attribute['name']} : {attribute['type']}")

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
    parser = argparse.ArgumentParser(description="Transform the ERD into a UML model.")
    parser.add_argument("command", choices=["source", "draft", "check"])
    parser.add_argument("model", nargs="?", type=Path, default=Path(PATHS["artifacts"]) / f"{NAMES['default']}.json")
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--force", action="store_true")

    return parser.parse_args()


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        generator = ErdToUml(args.erd, args.matrix)

        if args.command == "source":
            generator()
        elif args.command == "draft":
            generator.draft(args.model, args.force)
        else:
            sys.exit(generator.check(args.model, args.pdf))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
