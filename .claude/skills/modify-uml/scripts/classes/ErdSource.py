import hashlib
import sys
from pathlib import Path

from const.general import NAMES, PATHS
from utils.skills import load_module


class ErdSource:
    """
    ERD and requirements matrix, from which the UML is made. The ERD model is
    validated with the code of the ERD skill (`modify-erd`).

    Args:
        root (Path): Root of the repository.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, root, erd=None, matrix=None):
        self.root = root
        self.path = Path(erd or root / PATHS["erd_model"]).resolve()
        self.given_matrix = matrix

    def __call__(self):
        """
        Reads the matrix and the ERD model.

        Returns:
            ErdSource: Source with the matrix, the validated ERD and checksums.
        """
        if not self.path.is_file():
            raise RuntimeError(
                f"ERD model not found: {self.path}. Create it with the requirements-to-erd skill."
            )

        skills = self.root / PATHS["skills"]
        sys.path.insert(0, str(skills / NAMES["pdf_skill"] / PATHS["scripts"]))

        erd_skill = self.find_erd_skill(skills)
        matrix_module = load_module(erd_skill, "classes.RequirementsMatrix")
        model_module = load_module(erd_skill, "classes.ErdModel")

        self.read_pdf_pages = matrix_module.read_pdf_pages
        self.matrix = matrix_module.RequirementsMatrix(self.root, self.given_matrix)()
        self.model = model_module.ErdModel(self.path, self.matrix)()
        self.sha256 = hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.file = self.path.as_posix()

        if self.root in self.path.parents:
            self.file = self.path.relative_to(self.root).as_posix()

        return self

    @staticmethod
    def find_erd_skill(skills):
        for name in NAMES["erd_skills"]:
            scripts = skills / name / PATHS["scripts"]

            if (scripts / "classes" / "ErdModel.py").is_file():
                return scripts

        raise RuntimeError(
            f"Code of the ERD not found in {', '.join(NAMES['erd_skills'])}. "
            "Both skills are needed to read the ERD model."
        )
