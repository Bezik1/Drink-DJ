import subprocess
import sys

from const.general import NAMES, PATHS


def run_validation(root, model, uml=None, erd=None, matrix=None, pdf=None):
    """
    Runs the `validate-relational` skill on the saved diagram of a model.

    Args:
        root (Path): Root of the repository.
        model (Path): Path of the JSON model of the relational model.
        uml (Path, optional): JSON model of the UML.
        erd (Path, optional): JSON model of the ERD.
        matrix (str, optional): Matrix used, when the official one is missing.
        pdf (Path, optional): Official PDF of the diagram.

    Returns:
        int: Exit code of the validation: 0 valid, 1 invalid, 2 could not run.
    """
    script = root / PATHS["skills"] / NAMES["validator"] / PATHS["scripts"] / "validate_relational.py"
    command = [
        sys.executable, str(script),
        str(root / PATHS["artifacts"] / f"{model.stem}.drawio"),
        "--model", str(model),
    ]

    for flag, value in (("--uml", uml), ("--erd", erd), ("--matrix", matrix), ("--pdf", pdf)):
        if value:
            command += [flag, str(value)]

    result = subprocess.run(
        command, stdin=subprocess.DEVNULL, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=600,
    )

    print(result.stdout + result.stderr, end="")

    return result.returncode
