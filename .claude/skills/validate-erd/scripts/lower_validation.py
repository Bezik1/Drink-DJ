"""
Validation of a lower design level, that a validator of a higher level runs,
so every validator also checks everything its level is made from.
"""
import subprocess
import sys


class LowerValidation:
    """
    Runs the validator of a lower design level as a separate program and
    reads its result. The chain is ERD, then UML class diagram, then
    relational model: `validate-uml` runs `validate-erd`, and
    `validate-relational` runs `validate-uml`, which runs `validate-erd`.

    Args:
        level (str): Name of the lower level, for example "ERD".
        script (Path): Path of its validation script.
    """

    def __init__(self, level, script):
        self.level = level
        self.script = script

    def __call__(self, arguments=()):
        """
        Runs the validator.

        Rules:
        - Exit code 0 is a valid level, and it gives only a note, with the
          notes of the valid levels below it.
        - Exit code 1 is an invalid level: each of its errors is an error of
          the caller, with the name of the level in front.
        - Any other exit code means, that the check could not run, which is
          also an error of the caller, with the last lines of the output.

        Args:
            arguments (str[], optional): Arguments of the validator. Default: none.

        Returns:
            tuple[str[], str[]]: Errors and notes for the report of the caller.
        """
        skill = self.script.parents[1].name

        if not self.script.is_file():
            return [f"{self.level}: the {skill} skill is missing, so the {self.level} is not validated"], []

        result = subprocess.run(
            [sys.executable, str(self.script), *[str(item) for item in arguments]],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=900,
        )
        lines = (result.stdout + result.stderr).splitlines()

        if result.returncode == 0:
            below = [line[len("Note: "):] for line in lines if line.startswith("Note: ") and ": VALID (" in line]

            return [], [f"{self.level}: VALID ({skill})", *below]

        errors = self.errors(lines)

        if result.returncode != 1 or not errors:
            tail = " | ".join(line for line in lines[-5:] if line.strip())

            return [f"{self.level}: {skill} could not run: {tail}"], []

        return [f"{self.level} ({skill}): {item}" for item in errors], []

    @staticmethod
    def errors(lines):
        """
        Reads the errors of a report in either form of the project:
        "Error: text" lines, or "- text" lines under an "Errors:" header.

        Args:
            lines (str[]): Lines of the report.

        Returns:
            str[]: The errors.
        """
        found, inside = [], False

        for line in lines:
            if line.startswith("Error: "):
                found.append(line[len("Error: "):])
            elif line.rstrip().endswith(":") and not line.startswith("- "):
                inside = line.strip() == "Errors:"
            elif inside and line.startswith("- "):
                found.append(line[2:])

        return found
