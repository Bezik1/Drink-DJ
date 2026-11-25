import json
import re

from const.general import PATTERNS, PRIMITIVES, STEREOTYPES
from utils.naming import (
    end_class, is_multiplicity, signature, snake_case, title_case, uml_multiplicity, with_role
)


class UmlModel:
    """
    Model of the UML class diagram, described in a JSON file, and its check
    against the ERD and the requirements matrix.

    Args:
        path (Path): Path of the JSON file.
        source (ErdSource): ERD and matrix, from which the UML comes.
    """

    def __init__(self, path, source):
        self.path = path
        self.source = source
        self.erd = source.model
        self.matrix = source.matrix
        self.errors = []
        self.used = set()

        self.data = json.loads(path.read_text(encoding="utf-8"))

        self.classes = self.data.get("classes", {})
        self.associations = self.data.get("associations", [])

    def __call__(self):
        """
        Validates the model against the ERD and the matrix.

        Returns:
            UmlModel: Validated model.
        """
        self.check_sources()
        self.check_classes()
        self.check_associations()
        self.check_entities()
        self.check_relationships()
        self.check_enumerations()
        self.check_coverage()

        if self.errors:
            raise RuntimeError("Invalid UML model:\n- " + "\n- ".join(self.errors))

        return self

    def save(self):
        self.path.write_text(
            json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    def check_sources(self):
        erd = self.data.get("erd", {})
        matrix = self.data.get("matrix", {})

        if erd.get("sha256") != self.source.sha256:
            self.errors.append(
                f"erd.sha256 does not match {self.source.file}. "
                "The ERD changed, so make the UML model again."
            )
        if matrix.get("file") != self.matrix.file or matrix.get("sha256") != self.matrix.sha256:
            self.errors.append("matrix does not match the current requirements matrix")

    def type_names(self):
        return [
            *PRIMITIVES,
            *(item["name"] for item in self.classes.values() if item.get("stereotype")),
        ]

    def check_classes(self):
        """
        Rules:
        - Class has a name, a free cell and a kind: entity, relationship,
          enumeration, data type, or a UML-only class with the reason `assumed`.
        - Enumeration needs no cell, because it always stands in the top right
          corner of the diagram. Its cell is ignored.
        - Attribute names are in snake case, unique in the class, and every type
          is a primitive type, an enumeration or a data type.
        - Enumeration has values in snake case and no attributes.
        """
        cells, names = set(), set()
        types = self.type_names()

        if not self.classes:
            self.errors.append("The model has no classes")

        for key, item in self.classes.items():
            name, cell = item.get("name"), item.get("cell")
            stereotype = item.get("stereotype")

            if stereotype == "enumeration":
                cell = None
            if not name or (stereotype != "enumeration" and (not isinstance(cell, list) or len(cell) != 2)):
                self.errors.append(f"{key}: name and cell [column, row] are required")
                continue
            if name in names:
                self.errors.append(f"{name}: the class is drawn twice")
            if cell is not None and tuple(cell) in cells:
                self.errors.append(f"{name}: cell {cell} is already taken")

            names.add(name)

            if cell is not None:
                cells.add(tuple(cell))

            self.check_evidence(name, item, mapped=bool(item.get("entity") or item.get("relationship")))

            if stereotype is not None and stereotype not in STEREOTYPES:
                self.errors.append(f"{name}: stereotype must be one of {STEREOTYPES}")
            if stereotype == "enumeration":
                self.check_values(name, item)
                continue

            self.check_attributes(name, item, types)
            self.check_operations(name, item, types)

    def check_operations(self, owner, item, types):
        """
        Rules:
        - Only a class has operations, not an enumeration or a data type.
        - An operation has a name in snake case, unique in the class.
        - Its parameters have names in snake case, and its parameters and its
          return type are primitive types, enumerations or data types.
        - An operation is not in the ERD, so it needs `from` or the reason in
          `assumed`.

        Args:
            owner (str): Name of the class.
            item (dict[]): The class of the model.
            types (str[]): Names of the types, that can be used.
        """
        names = set()

        if item.get("operations") and item.get("stereotype"):
            self.errors.append(f"{owner}: only a class has operations")

        for operation in item.get("operations", []):
            name = operation.get("name", "")
            label = f"{owner}.{name}()"

            if not re.fullmatch(PATTERNS["snake"], name):
                self.errors.append(f"{owner}: operation '{name}' must be in snake_case")
            if name in names:
                self.errors.append(f"{label}: the operation is drawn twice")

            names.add(name)

            for parameter in operation.get("parameters", []):
                if not re.fullmatch(PATTERNS["snake"], parameter.get("name", "")) or parameter.get("type") not in types:
                    self.errors.append(f"{label}: a parameter needs a name in snake_case and a known type")
            if operation.get("returns") is not None and operation["returns"] not in types:
                self.errors.append(f"{label}: return type '{operation['returns']}' is not a known type")

            self.check_evidence(label, operation, mapped=False)

    def check_values(self, name, item):
        values = item.get("values", [])

        if not values:
            self.errors.append(f"{name}: enumeration needs values")
        if item.get("attributes"):
            self.errors.append(f"{name}: enumeration has values, not attributes")

        for value in values:
            if not re.fullmatch(PATTERNS["snake"], value):
                self.errors.append(f"{name}.{value}: value must be in snake_case")

    def check_attributes(self, owner, item, types):
        names = set()

        for attribute in item.get("attributes", []):
            name = attribute.get("name", "")

            if not re.fullmatch(PATTERNS["snake"], name):
                self.errors.append(f"{owner}: attribute '{name}' must be in snake_case")
            if name in names:
                self.errors.append(f"{owner}.{name}: attribute is drawn twice")
            if attribute.get("type") not in types:
                self.errors.append(
                    f"{owner}.{name}: type '{attribute.get('type')}' is not a primitive type, "
                    "an enumeration or a data type"
                )
            if attribute.get("multiplicity") and not is_multiplicity(attribute["multiplicity"]):
                self.errors.append(f"{owner}.{name}: wrong multiplicity")

            names.add(name)
            self.check_evidence(f"{owner}.{name}", attribute, mapped=bool(attribute.get("erd")) or bool(item.get("stereotype")))

    def check_evidence(self, name, element, mapped):
        """
        Every element comes from the ERD, or has the reason in `assumed`.

        Args:
            name (str): Name of the element.
            element (dict): Element of the model.
            mapped (bool): Whether the element is a part of the ERD.
        """
        sources = element.get("from", [])

        self.used.update(sources)

        for source in sources:
            if source not in self.matrix.ids:
                self.errors.append(f"{name}: {source} is not in the matrix")

        if not mapped and not element.get("assumed") and not sources:
            self.errors.append(
                f"{name}: it is not in the ERD. Give 'from' or the reason in 'assumed'."
            )

    def check_associations(self):
        """
        Rules:
        - Association has 2 ends and multiplicities. An association of a
          class with itself names the class twice, at least once with a role
          (`drink_version:base`), and is not a composition.
        - Composition has a whole, that is one of its ends, with multiplicity 1 or 0..1.
        - Association class exists and is not a type.
        """
        for item in self.associations:
            name = item.get("name", "?")
            ends = item.get("ends", {})

            if len(ends) != 2:
                self.errors.append(f"{name}: an association joins exactly 2 ends")

            for key, multiplicity in ends.items():
                if end_class(key) not in self.classes or self.classes[end_class(key)].get("stereotype"):
                    self.errors.append(f"{name}: {end_class(key)} is not a class")
                if not is_multiplicity(multiplicity):
                    self.errors.append(f"{name}: wrong multiplicity {multiplicity}")

            if item.get("kind", "association") not in ("association", "composition"):
                self.errors.append(f"{name}: kind must be association or composition")
            if item.get("kind") == "composition":
                whole = item.get("whole")

                if whole not in ends:
                    self.errors.append(f"{name}: the whole of a composition must be one of its ends")
                elif ends[whole] not in ("1", "0..1"):
                    self.errors.append(f"{name}: the whole of a composition has multiplicity 1 or 0..1")
            if item.get("kind") == "composition" and len({end_class(key) for key in ends}) < len(ends):
                self.errors.append(f"{name}: an association of a class with itself cannot be a composition")
            if item.get("class") and item["class"] not in self.classes:
                self.errors.append(f"{name}: association class {item['class']} does not exist")

            self.check_evidence(name, item, mapped=bool(item.get("erd")))

    def check_entities(self):
        """
        Rules:
        - Every entity of the ERD is exactly one class.
        - Every attribute of the entity is exactly one attribute of the class,
          with the same kind.
        """
        by_entity = {}

        for key, item in self.classes.items():
            if item.get("entity"):
                by_entity.setdefault(item["entity"], []).append(key)

        for key, entity in self.erd.entities.items():
            found = by_entity.get(key, [])

            if len(found) != 1:
                self.errors.append(f"{entity['name']}: the ERD entity is {len(found)} classes instead of 1")
                continue

            item = self.classes[found[0]]

            self.compare_attributes(item["name"], entity.get("attributes", []), item)

        for key in by_entity:
            if key not in self.erd.entities:
                self.errors.append(f"{key}: class refers to an entity, that is not in the ERD")

    def compare_attributes(self, owner, expected, item):
        found = {}

        for attribute in item.get("attributes", []):
            if attribute.get("erd"):
                found.setdefault(attribute["erd"], []).append(attribute)

        for erd_attribute in expected:
            items = found.pop(erd_attribute["name"], [])

            if len(items) != 1:
                self.errors.append(f"{owner}.{erd_attribute['name']}: the ERD attribute is missing in the class")
                continue

            kind = erd_attribute.get("kind", "simple")

            if items[0].get("kind", "simple") != kind:
                self.errors.append(f"{owner}.{items[0]['name']}: kind must be {kind}, as in the ERD")
            if kind == "multivalued" and not items[0].get("multiplicity"):
                self.errors.append(f"{owner}.{items[0]['name']}: multivalued attribute needs a multiplicity")

        for name in found:
            self.errors.append(f"{owner}: attribute refers to '{name}', that is not in the ERD")

    def check_relationships(self):
        """
        Rules:
        - Every relationship of the ERD is exactly one association between the
          classes of its entities, with the same name and multiplicities.
        - Only an identifying relationship can be a composition.
        - A relationship with attributes has an association class with them.
        """
        entities = {
            item["entity"]: key for key, item in self.classes.items() if item.get("entity")
        }
        found = {}

        for item in self.associations:
            if item.get("erd"):
                found.setdefault(item["erd"], []).append(item)

        for relation in self.erd.relationships:
            identifier = signature(relation)
            items = found.pop(identifier, [])

            if len(items) != 1:
                self.errors.append(f"{identifier}: the ERD relationship is {len(items)} associations instead of 1")
                continue

            item = items[0]
            expected = {
                with_role(entities.get(end_class(key)), key): uml_multiplicity(value)
                for key, value in relation["ends"].items()
            }

            if item.get("name") != relation["name"]:
                self.errors.append(f"{identifier}: association must be named '{relation['name']}'")
            if item.get("ends") != expected:
                self.errors.append(
                    f"{identifier}: multiplicities must be {expected}, as in the ERD, not {item.get('ends')}"
                )
            if item.get("kind") == "composition" and not relation.get("identifying"):
                self.errors.append(f"{identifier}: only an identifying relationship can be a composition")

            self.check_association_class(relation, item)

        for identifier in found:
            self.errors.append(f"{identifier}: association refers to a relationship, that is not in the ERD")

    def check_association_class(self, relation, association):
        attributes = relation.get("attributes", [])
        key = association.get("class")

        if not attributes:
            if key:
                self.errors.append(f"{relation['name']}: it has no attributes, so no association class")
            return
        if not key or key not in self.classes:
            self.errors.append(f"{relation['name']}: its attributes need an association class")
            return

        self.compare_attributes(self.classes[key]["name"], attributes, self.classes[key])

    def check_enumerations(self):
        """
        Rule: every list "X value can be equal to ..." of the matrix is an
        enumeration with the same values.
        """
        enumerations = {
            item["name"].casefold(): set(item.get("values", []))
            for item in self.classes.values() if item.get("stereotype") == "enumeration"
        }

        for match in re.finditer(PATTERNS["enumeration"], self.matrix.text):
            name = title_case(match.group(1)).casefold()
            values = {
                snake_case(value)
                for value in re.findall(PATTERNS["enumeration_value"], match.group(2))
            } - {"null"}

            if values and enumerations.get(name) != values:
                self.errors.append(
                    f"Enumeration '{title_case(match.group(1))}' must have the values "
                    f"{sorted(values)} from the matrix"
                )

    def check_coverage(self):
        not_drawn = set(self.erd.not_drawn)

        for requirement in self.matrix.ids:
            if requirement not in self.used and requirement not in not_drawn:
                self.errors.append(f"{requirement}: it is not used in the UML and not explained in the ERD")

    def names(self):
        """
        Lists every name, that the diagram must show.

        Returns:
            str[]: Names of classes, attributes, values and associations.
        """
        names = []

        for item in self.classes.values():
            names.append(item["name"])
            names.extend(item.get("values", []))
            names.extend(attribute["name"] for attribute in item.get("attributes", []))
            names.extend(operation["name"] for operation in item.get("operations", []))

        names.extend(item["name"] for item in self.associations)

        return names
