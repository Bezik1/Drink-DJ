"""
First version of the coverage of the requirements, with elements of the ERD
suggested from the words of every requirement.
"""
import re

from requirements_coverage_const import PATHS
from requirements_coverage_model import snake


def read_table(path):
    """
    Reads the rows of the Markdown table of a requirements document.

    Args:
        path (Path): Path of the Markdown file.

    Returns:
        dict[]: Id of the requirement and its description and significance.
    """
    rows = {}

    if not path.is_file():
        return rows

    for line in path.read_text(encoding="utf-8").splitlines():
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]

        if len(cells) > 3 and re.fullmatch(r"N?FR\d+", cells[0]):
            rows[cells[0]] = {"text": cells[2], "significance": cells[3]}

    return rows


def mentions(text, name):
    words = r"\s+".join(re.escape(word) for word in name.split())

    return re.search(rf"\b{words}(e?s)?\b", text, re.I) is not None


class CoverageDraft:
    """
    Candidates of the coverage of every requirement. Every entry has the status
    `review`, which the check refuses, so the agent decides each of them.

    Rules:
    - An entity is suggested, when its name is in the text of the requirement.
    - An attribute is suggested, when its name and the name of its entity are
      in the text.
    - The significance comes from the Markdown version of the document.

    Args:
        coverage (RequirementsCoverage): Coverage with the read documents.
        entities (dict[]): Entities of the ERD model.
    """

    def __init__(self, coverage, entities):
        self.coverage = coverage
        self.entities = entities

    def __call__(self):
        """
        Builds the candidates.

        Returns:
            dict[]: The coverage file.
        """
        root = self.coverage.root
        rows = {**read_table(root / PATHS["functional_text"]), **read_table(root / PATHS["non_functional_text"])}
        items = []

        for identifier in self.coverage.ids:
            row = rows.get(identifier, {"text": "", "significance": "Must"})
            items.append({
                "id": identifier,
                "significance": row["significance"],
                "status": "review",
                "text": row["text"],
                "elements": self.suggest(row["text"]),
            })

        return {
            "sources": {
                kind: {"file": source["file"], "sha256": source["sha256"]}
                for kind, source in self.coverage.sources.items()
            },
            "requirements": items,
        }

    def suggest(self, text):
        found = []

        for key, entity in self.entities.items():
            if not mentions(text, entity["name"]):
                continue

            found.append(key)
            found.extend(
                f"{key}.{snake(item['name'])}" for item in entity.get("attributes", [])
                if mentions(text, item["name"])
            )

        return found
