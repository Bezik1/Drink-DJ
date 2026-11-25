"""
Model of the constraints of a UML class diagram, with its check.
"""
import json
import re

from classes.UmlDraft import UmlDraft
from constraints_const import ID_PATTERN, KINDS, MARKER


class ConstraintsModel:
    """
    The JSON file with the constraints of a UML class diagram and its check
    against the UML, the ERD and the requirements matrix.

    Rules:
    - The file belongs to the current ERD (checksum).
    - Every constraint has an id `C01`, a known kind, a text, classes of the
      UML and the requirements it comes from, or the reason in `assumed`.
    - Every assumption of the ERD with "Chen notation cannot show" has a
      constraint with its requirement, and every weak entity, whose identifier the UML does not
      show, has an `identity` constraint.

    Args:
        path (Path): Path of the JSON file.
        source (ErdSource): ERD and matrix.
        uml (UmlModel): Validated model of the UML.
    """

    def __init__(self, path, source, uml):
        self.path = path
        self.source = source
        self.uml = uml
        self.errors = []

        self.data = json.loads(path.read_text(encoding="utf-8"))
        self.items = self.data.get("constraints", [])

    def __call__(self):
        """
        Validates the file.

        Returns:
            ConstraintsModel: Validated model.
        """
        self.check_sources()
        self.check_items()
        self.check_coverage()

        if self.errors:
            raise RuntimeError("Invalid constraints:\n- " + "\n- ".join(self.errors))

        return self

    def check_sources(self):
        if self.data.get("erd", {}).get("sha256") != self.source.sha256:
            self.errors.append("erd.sha256 does not match the ERD. Write the constraints again.")

    def check_items(self):
        identifiers = set()

        for item in self.items:
            name = item.get("id", "?")

            if not re.fullmatch(ID_PATTERN, name) or name in identifiers:
                self.errors.append(f"{name}: the id must be unique and like C01")

            identifiers.add(name)

            if item.get("kind") not in KINDS:
                self.errors.append(f"{name}: kind must be one of {list(KINDS)}")
            if not item.get("text"):
                self.errors.append(f"{name}: the text is empty")

            for key in item.get("classes", []):
                if key not in self.uml.classes:
                    self.errors.append(f"{name}: {key} is not a class of the UML")
            for requirement in item.get("from", []):
                if requirement not in self.source.matrix.ids:
                    self.errors.append(f"{name}: {requirement} is not in the matrix")
            if not item.get("from") and not item.get("assumed"):
                self.errors.append(f"{name}: give 'from' or the reason in 'assumed'")
            if not item.get("classes"):
                self.errors.append(f"{name}: give the classes, that it applies to")

    def check_coverage(self):
        for assumption in self.source.model.assumptions:
            if MARKER not in assumption.casefold():
                continue

            match = re.match(r"((?:R\d+(?:, )?)+): ", assumption)
            sources = set(match.group(1).split(", ")) if match else set()

            if not any(sources & set(item.get("from", [])) for item in self.items):
                self.errors.append(
                    f"The ERD says, that UML cannot show it, but no constraint comes from "
                    f"{', '.join(sorted(sources))}: {assumption}"
                )

        owners = self.owners()

        for key, entity in self.source.model.entities.items():
            if not entity.get("weak") or not self.needs_identity(key, owners):
                continue

            if not any(
                item.get("kind") == "identity" and item.get("text", "").startswith(f"{entity['name']} is identified by")
                for item in self.items
            ):
                self.errors.append(f"{entity['name']}: its identifier is not drawn, so add an identity constraint")

    def owners(self):
        return UmlDraft(self.source).find_owners()

    def needs_identity(self, key, owners):
        relations = [
            item for item in self.source.model.relationships
            if item.get("identifying")
            and owners[f"{item['name']}:{'/'.join(sorted(item['ends']))}"][1] == key
        ]
        composed = any(
            item.get("kind") == "composition" and item.get("whole") != key and key in item["ends"]
            for item in self.uml.associations
        )

        return not composed or len(relations) > 1

    @staticmethod
    def normal(text):
        return re.sub(r"\s+", " ", text).strip().casefold()

    def save(self):
        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def names(self):
        return [item["id"] for item in self.items]

