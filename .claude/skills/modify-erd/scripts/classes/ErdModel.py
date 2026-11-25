import json
import re

from const.general import ATTRIBUTE_KINDS, CARDINALITY

ROLE = re.compile(r"[a-z][a-z0-9]*(_[a-z0-9]+)*")


def end_entity(end):
    """
    Finds the entity of an end of a relationship. An end is the key of an
    entity, or `<entity>:<role>`, when a relationship joins an entity with
    itself, for example `drink_version:base`.

    Args:
        end (str): Key of the end in `ends`.

    Returns:
        str: Key of the entity.
    """
    return end.split(":", 1)[0]


def end_role(end):
    return end.split(":", 1)[1] if ":" in end else None


def is_recursive(relation):
    """
    Checks, whether a relationship joins an entity with itself.

    Args:
        relation (dict[]): Relationship of the model.

    Returns:
        bool: True, when two ends name the same entity.
    """
    entities = [end_entity(end) for end in relation.get("ends", {})]

    return len(entities) != len(set(entities))


class ErdModel:
    """
    Conceptual model of the ERD, described in a JSON file.

    Args:
        path (Path): Path of the JSON file.
        matrix (RequirementsMatrix): Matrix, from which the model comes.
    """

    def __init__(self, path, matrix):
        self.path = path
        self.matrix = matrix
        self.errors = []
        self.used = set()

        data = json.loads(path.read_text(encoding="utf-8"))

        self.source = data.get("matrix", {})
        self.entities = data.get("entities", {})
        self.relationships = data.get("relationships", [])
        self.not_drawn = data.get("not_drawn", {})
        self.assumptions = data.get("assumptions", [])

    def __call__(self):
        """
        Validates the model against the matrix.

        Returns:
            ErdModel: Validated model.
        """
        self.check_source()
        self.check_entities()
        self.check_relationships()
        self.check_coverage()

        if self.errors:
            raise RuntimeError("Invalid model:\n- " + "\n- ".join(self.errors))

        return self

    def check_source(self):
        if self.source.get("file") != self.matrix.file:
            self.errors.append(f"matrix.file must be {self.matrix.file}")
        if self.source.get("sha256") != self.matrix.sha256:
            self.errors.append(
                "matrix.sha256 does not match. Update the model with the requirements-to-erd skill."
            )

    def check_entities(self):
        """
        Rules:
        - Every entity has a name, a cell and a source in the matrix.
        - Strong entity has a key and weak entity has an identifying relationship.
        - Cell holds only one entity.
        """
        cells = set()

        if not self.entities:
            self.errors.append("The model has no entities")

        for key, entity in self.entities.items():
            name = entity.get("name")
            cell = entity.get("cell")

            if not name or not isinstance(cell, list) or len(cell) != 2:
                self.errors.append(f"{key}: name and cell [column, row] are required")
                continue
            if tuple(cell) in cells:
                self.errors.append(f"{name}: cell {cell} is already taken")

            cells.add(tuple(cell))
            self.check_evidence(name, entity)

            attributes = entity.get("attributes", [])
            self.check_attributes(name, attributes)

            if entity.get("weak"):
                if not any(
                    relation.get("identifying") and key in map(end_entity, relation.get("ends", {}))
                    for relation in self.relationships
                ):
                    self.errors.append(f"{name}: weak entity needs an identifying relationship")
            elif not any(item.get("kind") == "key" for item in attributes):
                self.errors.append(f"{name}: strong entity needs a key")

    def check_relationships(self):
        """
        Rules:
        - A relationship has at least 2 ends, each with a known entity and a
          cardinality.
        - A relationship of an entity with itself (recursive) names the
          entity twice, at least once with a role (`drink_version:base`), has
          exactly 2 ends, its own `cell` and is not identifying.
        """
        for relation in self.relationships:
            name = relation.get("name", "?")
            ends = relation.get("ends", {})

            if len(ends) < 2:
                self.errors.append(f"{name}: at least 2 ends are required")

            for key, cardinality in ends.items():
                if end_entity(key) not in self.entities:
                    self.errors.append(f"{name}: unknown entity {end_entity(key)}")
                if end_role(key) is not None and not ROLE.fullmatch(end_role(key)):
                    self.errors.append(f"{name}: the role of {key} must be in snake_case")
                if not re.fullmatch(CARDINALITY, str(cardinality)):
                    self.errors.append(f"{name}: wrong cardinality {cardinality}")

            if is_recursive(relation):
                if len(ends) != 2:
                    self.errors.append(f"{name}: a recursive relationship has exactly 2 ends")
                if "cell" not in relation:
                    self.errors.append(f"{name}: a recursive relationship needs its own cell")
                if relation.get("identifying"):
                    self.errors.append(f"{name}: a recursive relationship cannot be identifying")

            if relation.get("identifying") and not any(
                self.entities.get(end_entity(key), {}).get("weak") for key in ends
            ):
                self.errors.append(f"{name}: identifying relationship needs a weak entity")

            self.check_evidence(name, relation, check_words=False)
            self.check_attributes(name, relation.get("attributes", []))

    def check_attributes(self, owner, attributes):
        for attribute in attributes:
            name = attribute.get("name")

            if not name:
                self.errors.append(f"{owner}: attribute without a name")
                continue
            if attribute.get("kind", "simple") not in ATTRIBUTE_KINDS:
                self.errors.append(f"{owner}.{name}: kind must be one of {ATTRIBUTE_KINDS}")

            self.check_evidence(name, attribute)

    def check_evidence(self, name, element, check_words=True):
        """
        Every element either comes from the matrix or is a marked assumption.

        Args:
            name (str): Name of the element.
            element (dict): Element of the model.
            check_words (bool, optional): Whether words of the name
                must occur in the matrix. Default: True.
        """
        sources = element.get("from", [])

        self.used.update(sources)

        for source in sources:
            if source not in self.matrix.ids:
                self.errors.append(f"{name}: {source} is not in the matrix")

        if element.get("assumed"):
            return
        if not sources:
            self.errors.append(f"{name}: give 'from' or the reason in 'assumed'")
        if not check_words:
            return

        for word in re.findall(r"[^\W\d_]{4,}", name.casefold()):
            if not re.search(rf"\b{re.escape(word[:5])}", self.matrix.text):
                self.errors.append(
                    f"{name}: '{word}' is not in the matrix. "
                    "Use its wording or give the reason in 'assumed'."
                )

    def check_coverage(self):
        for requirement in self.matrix.ids:
            if requirement not in self.used and requirement not in self.not_drawn:
                self.errors.append(f"{requirement}: draw it or explain it in 'not_drawn'")

        for requirement in self.not_drawn:
            if requirement not in self.matrix.ids:
                self.errors.append(f"not_drawn: {requirement} is not in the matrix")

    def names(self):
        names = [entity["name"] for entity in self.entities.values()]
        names.extend(relation["name"] for relation in self.relationships)

        for owner in [*self.entities.values(), *self.relationships]:
            names.extend(item["name"] for item in owner.get("attributes", []))

        return names
