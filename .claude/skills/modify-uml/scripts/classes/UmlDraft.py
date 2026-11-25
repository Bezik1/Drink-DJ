import re

from const.general import (
    DEFAULT_TYPE, PATTERNS, TYPE_RULES
)
from utils.naming import signature, snake_case, title_case, uml_multiplicity


class UmlDraft:
    """
    Transformation of the ERD into a first version of the UML model.

    Rules:
    - Entity becomes a class and its attribute becomes an attribute `+ name : Type`.
    - Key attribute is underlined, derived attribute has a slash (`/name`),
      multivalued attribute has multiplicity `[1..*]`.
    - Relationship becomes an association with the same name. Cardinality `N`
      and `M` become `*`.
    - Identifying relationship, whose owner has multiplicity 1 or 0..1,
      becomes a composition. The relationship with the owner, that must exist
      (weak side `1..N`), has priority.
    - Relationship with attributes also gets an association class.
    - The constraints, that UML cannot show, are not in the diagram. The
      `uml-constraints` skill writes them to a separate file.
    - Value lists of the matrix ("value can be equal to ...") become
      enumerations and composite values ("consists of ...") become data types.

    Args:
        source (ErdSource): ERD and matrix.
    """

    def __init__(self, source):
        self.source = source
        self.erd = source.model
        self.matrix = source.matrix
        self.enumerations = {}
        self.data_types = {}

    def __call__(self):
        """
        Builds the model. The types of attributes are guesses, that the agent
        must review, and the cells are the ones of the ERD.

        Returns:
            dict[]: UML model, ready to be saved as JSON.
        """
        self.find_enumerations()
        self.classes = {}
        self.taken = set()
        self.associations = []

        self.build_classes()
        self.build_associations()
        self.build_extras()

        return {
            "erd": {"file": self.source.file, "sha256": self.source.sha256},
            "matrix": {"file": self.matrix.file, "sha256": self.matrix.sha256},
            "classes": self.classes,
            "associations": self.associations,
        }

    def find_enumerations(self):
        """
        Finds the enumerations: the lists "X value can be equal to ..." of the
        matrix and the attributes of the ERD, that have `values`.
        """
        for entity in self.erd.entities.values():
            for attribute in entity.get("attributes", []):
                if attribute.get("values"):
                    self.enumerations[title_case(attribute["name"].casefold())] = {
                        "values": [snake_case(value) for value in attribute["values"]],
                        "from": attribute.get("from", []),
                        "assumed": attribute.get("assumed"),
                    }

        text = self.matrix.text

        for match in re.finditer(PATTERNS["enumeration"], text):
            values = [
                snake_case(value)
                for value in re.findall(PATTERNS["enumeration_value"], match.group(2))
            ]
            values = [value for value in values if value != "null"]

            if values:
                self.enumerations[title_case(match.group(1))] = {
                    "values": values,
                    "from": self.requirement_before(match.start()),
                }

    def requirement_before(self, position):
        found = re.findall(PATTERNS["requirement"], self.matrix.text[:position].upper())

        return [found[-1]] if found else []

    def guess_type(self, name):
        title = title_case(name.casefold())

        if title in self.enumerations:
            return title

        composite = re.search(
            PATTERNS["composite"].replace("{name}", re.escape(name.casefold())),
            self.matrix.text,
        )

        if composite:
            self.build_data_type(title, composite.group(1))

            return title

        for pattern, kind in TYPE_RULES:
            if re.search(pattern, name.casefold()):
                return kind

        return DEFAULT_TYPE

    def build_data_type(self, title, parts):
        names = [
            part.strip()
            for part in re.split(r",| and ", parts)
            if 0 < len(part.split()) <= 3
        ]

        if names:
            self.data_types[title] = [
                {"name": snake_case(name), "type": self.guess_type_of_part(name)}
                for name in names
            ]

    def guess_type_of_part(self, name):
        for pattern, kind in TYPE_RULES:
            if re.search(pattern, name.casefold()):
                return kind

        return DEFAULT_TYPE

    def build_classes(self):
        for key, entity in self.erd.entities.items():
            attributes = []

            for attribute in entity.get("attributes", []):
                attributes.append(self.build_attribute(attribute))

            self.classes[key] = {
                "name": entity["name"],
                "entity": key,
                "cell": list(entity["cell"]),
                "attributes": attributes,
                "from": entity.get("from", []),
            }

    def build_attribute(self, attribute):
        kind = attribute.get("kind", "simple")
        result = {
            "name": snake_case(attribute["name"]),
            "type": self.guess_type(attribute["name"]),
            "erd": attribute["name"],
        }

        if kind != "simple":
            result["kind"] = kind
        if kind == "multivalued":
            result["multiplicity"] = "1..*"

        return self.copy_evidence(result, attribute)

    def copy_evidence(self, target, element):
        if element.get("from"):
            target["from"] = element["from"]
        if element.get("assumed"):
            target["assumed"] = element["assumed"]

        return target

    def build_associations(self):
        compositions = self.choose_compositions()

        for relation in self.erd.relationships:
            if len(relation["ends"]) != 2:
                raise RuntimeError(
                    f"{relation['name']}: only binary relationships can be drawn. "
                    "Split it in the ERD, or add the class and associations by hand."
                )

            identifier = signature(relation)
            association = {
                "name": relation["name"],
                "erd": identifier,
                "kind": "association",
                "ends": {
                    key: uml_multiplicity(value) for key, value in relation["ends"].items()
                },
            }

            if identifier in compositions:
                association["kind"] = "composition"
                association["whole"] = compositions[identifier]

            if relation.get("attributes"):
                association["class"] = snake_case(relation["name"])

            self.associations.append(self.copy_evidence(association, relation))

    def find_owners(self):
        """
        Finds, which end of an identifying relationship is the weak entity.

        Rules:
        - Strong entity is identified from the start.
        - A weak entity is identified, when a relationship joins it with an
          identified entity. That entity is its owner.

        Returns:
            dict[]: Signature of the relationship and the tuple (owner, weak).
        """
        entities = self.erd.entities
        rank = {key: 0 for key, item in entities.items() if not item.get("weak")}
        relations = [item for item in self.erd.relationships if item.get("identifying")]
        owners = {}
        step = 0

        while len(owners) < len(relations) and step < len(entities):
            step += 1

            for relation in relations:
                first, second = list(relation["ends"])

                if signature(relation) in owners:
                    continue
                if (first in rank) != (second in rank):
                    owner, weak = (first, second) if first in rank else (second, first)
                    rank[weak] = step
                    owners[signature(relation)] = (owner, weak)

        for relation in relations:
            first, second = sorted(relation["ends"], key=lambda key: rank.get(key, 99))

            owners.setdefault(signature(relation), (first, second))

        return owners

    def choose_compositions(self):
        """
        Chooses the composition of every weak entity.

        Returns:
            dict[]: Signature of the relationship and the key of its whole.
        """
        chosen = {}
        owners = self.find_owners()

        for key, entity in self.erd.entities.items():
            if not entity.get("weak"):
                continue

            candidates = [
                (relation, owners[signature(relation)][0])
                for relation in self.erd.relationships
                if relation.get("identifying") and owners[signature(relation)][1] == key
                and self.upper(relation["ends"][owners[signature(relation)][0]]) == 1
            ]
            candidates.sort(key=lambda item: self.lower(item[0]["ends"][key]) == 0)

            if candidates:
                chosen[signature(candidates[0][0])] = candidates[0][1]

        return chosen

    @staticmethod
    def upper(cardinality):
        last = str(cardinality).split("..")[-1]

        return int(last) if last.isdigit() else 99

    @staticmethod
    def lower(cardinality):
        first = str(cardinality).split("..")[0]

        return int(first) if first.isdigit() else 0

    def build_extras(self):
        """
        Adds the enumerations, data types and association classes.
        An enumeration has no cell, because the layout puts it in the top right
        corner. Data types stand in a column on the right of the diagram.
        """
        column = max(entity["cell"][0] for entity in self.erd.entities.values()) + 1
        row = 0
        self.taken = {tuple(item["cell"]) for item in self.classes.values()}

        for name, enumeration in self.enumerations.items():
            users = [
                item for item in self.classes.values()
                if any(attribute["type"] == name for attribute in item.get("attributes", []))
            ]

            if not users:
                continue

            item = {
                "name": name,
                "stereotype": "enumeration",
                "values": enumeration["values"],
                "from": enumeration["from"],
            }

            if enumeration.get("assumed"):
                item["assumed"] = enumeration["assumed"]

            self.classes[snake_case(name)] = item

        for name, attributes in self.data_types.items():
            self.classes[snake_case(name)] = {
                "name": name,
                "stereotype": "dataType",
                "attributes": attributes,
                "cell": [column, row],
                "assumed": "Composite value, that the matrix lists with its parts",
            }
            row += 1

        for relation in self.erd.relationships:
            if not relation.get("attributes"):
                continue

            key = snake_case(relation["name"])
            self.classes[key] = {
                "name": title_case(relation["name"]),
                "relationship": signature(relation),
                "cell": self.between_cell(relation),
                "attributes": [self.build_attribute(item) for item in relation["attributes"]],
                "from": relation.get("from", []),
            }
            row += 1

    def between_cell(self, relation):
        """
        Finds a cell for an association class: halfway between the classes of
        its association, and half a row or a column aside, where no line runs.

        Args:
            relation (dict[]): Relationship of the ERD.

        Returns:
            float[2]: Column and row, that can be fractions.
        """
        (c1, r1), (c2, r2) = (self.classes[key]["cell"] for key in relation["ends"])
        column, row = (c1 + c2) / 2, (r1 + r2) / 2

        if r1 == r2:
            row += 0.5
        elif c1 == c2:
            column += 0.5

        while (column, row) in self.taken:
            row += 0.25

        self.taken.add((column, row))

        return [column, row]

    def first_mentioned(self, text):
        """
        Finds the class, that a text speaks about, by the first name of an
        entity or of its attribute.

        Args:
            text (str): Text of a note.

        Returns:
            str: Key of the class, or None.
        """
        best = None

        for key, entity in self.erd.entities.items():
            names = [entity["name"]] + [item["name"] for item in entity.get("attributes", [])]

            for name in names:
                found = re.search(rf"\b{re.escape(name)}", text, re.I)
                rank = (found.start(), -len(name)) if found else None

                if found and (best is None or rank < best[0]):
                    best = (rank, key)

        return best[1] if best else None

    def keys_of(self, key):
        entity = self.erd.entities[key]
        keys = [item["name"] for item in entity.get("attributes", []) if item.get("kind") == "key"]

        return keys or [entity["name"]]

