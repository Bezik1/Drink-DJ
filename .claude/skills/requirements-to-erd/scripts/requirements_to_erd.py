"""
Reading of the requirements matrix, from which the model of an ERD is made.
The diagram itself is made by the modify-erd skill.
"""
import argparse
import subprocess
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-erd" / "scripts"))

from classes.RequirementsMatrix import RequirementsMatrix


class RequirementsToErd:
    """
    Source of the model of an ERD, which is the requirements matrix.

    Args:
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, matrix=None):
        self.matrix = RequirementsMatrix(ROOT, matrix)()

    def __call__(self):
        """
        Prints everything, that is needed to write the model: the path,
        checksum, ids and text of the matrix.
        """
        print(f"file: {self.matrix.file}")
        print(f"sha256: {self.matrix.sha256}")
        print(f"ids: {', '.join(self.matrix.ids)}")
        print("text:")
        print("\n".join(self.matrix.lines))


def parse_args():
    parser = argparse.ArgumentParser(description="Read the matrix for the model of an ERD.")
    parser.add_argument("command", choices=["source"])
    parser.add_argument("--matrix")

    return parser.parse_args()


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        RequirementsToErd(args.matrix)()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
