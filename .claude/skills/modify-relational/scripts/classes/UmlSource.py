import hashlib
import json
import re
from pathlib import Path

from const.general import NAMES, PATHS, PATTERNS
from utils.multiplicity import bounds, classify
from utils.naming import association_id, words
from utils.skills import uml_module


class UmlSource:
    """
    UML class diagram, from which the relational model is made, with its ERD,
    requirements matrix and constraints. The UML model is validated with the
    code of the `modify-uml` skill, so a changed ERD or matrix stops the work.

    Args:
        root (Path): Root of the repository.
        uml (Path, optional): JSON model of the UML. Default: the official one.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, root, uml=None, erd=None, matrix=None):
        self.root = root
        self.path = Path(uml or root / PATHS["uml_model"]).resolve()
        self.erd = erd
        self.given_matrix = matrix

    def __call__(self):
        """
        Reads and validates the UML model and its constraints.

        Returns:
            UmlSource: Source with the UML, the ERD, the matrix and checksums.
        """
        if not self.path.is_file():
            raise RuntimeError(f"UML model not found: {self.path}. Create it with the erd-to-uml skill.")

        self.erd_source = uml_module("classes.ErdSource").ErdSource(self.root, self.erd, self.given_matrix)()
        self.model = uml_module("classes.UmlModel").UmlModel(self.path, self.erd_source)()
        self.owners = uml_module("classes.UmlDraft").UmlDraft(self.erd_source).find_owners()
        self.matrix = self.erd_source.matrix
        self.read_pdf_pages = self.erd_source.read_pdf_pages
        self.classes = self.model.classes
        self.associations = {association_id(item): item for item in self.model.associations}
        self.sha256 = hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.file = self.relative(self.path)
        self.read_constraints()

        return self

    def relative(self, path):
        if self.root in path.parents:
            return path.relative_to(self.root).as_posix()

        return path.as_posix()

    def read_constraints(self):
        """
        Reads the constraints of the `uml-constraints` skill, when they exist.
        They must belong to the current ERD.
        """
        self.constraints_path = self.path.with_name(f"{self.path.stem}{NAMES['constraints']}.json")
        self.constraints = []
        self.constraints_sha256 = None

        if not self.constraints_path.is_file():
            return

        data = json.loads(self.constraints_path.read_text(encoding="utf-8"))

        if data.get("erd", {}).get("sha256") != self.erd_source.sha256:
            raise RuntimeError(
                f"{self.constraints_path.name} belongs to another ERD. "
                "Write the UML constraints again with the uml-constraints skill."
            )

        self.constraints = data.get("constraints", [])
        self.constraints_sha256 = hashlib.sha256(self.constraints_path.read_bytes()).hexdigest()

    def kind_of(self, key):
        """
        Says, what a class of the UML becomes.

        Args:
            key (str): Key of the class.

        Returns:
            str: "table", "enumeration", "dataType", "junction" (the class of a
                many to many association) or "columns" (the class of another association).
        """
        item = self.classes[key]

        if item.get("stereotype"):
            return item["stereotype"]

        association = self.association_of_class(key)

        if association is None:
            return "table"

        return "junction" if classify(association)["kind"] == "junction" else "columns"

    def association_of_class(self, key):
        return next((item for item in self.associations.values() if item.get("class") == key), None)

    def table_classes(self):
        return [key for key in self.classes if self.kind_of(key) == "table"]

    def attribute(self, path):
        """
        Finds an attribute of the UML by its path.

        Args:
            path (str): "class.attribute", or "class.attribute.field" for a
                field of a data type.

        Returns:
            dict[]: Attribute, or None.
        """
        parts = path.split(".")

        if len(parts) not in (2, 3) or parts[0] not in self.classes:
            return None

        found = next(
            (item for item in self.classes[parts[0]].get("attributes", []) if item["name"] == parts[1]), None
        )

        if found is None or len(parts) == 2:
            return found

        data_type = self.data_type(found["type"])

        if data_type is None:
            return None

        return next((item for item in data_type.get("attributes", []) if item["name"] == parts[2]), None)

    def data_type(self, name):
        return next(
            (item for item in self.classes.values() if item.get("stereotype") == "dataType" and item["name"] == name),
            None,
        )

    def enumeration(self, name):
        return next(
            (item for item in self.classes.values() if item.get("stereotype") == "enumeration" and item["name"] == name),
            None,
        )

    @staticmethod
    def is_multivalued(attribute):
        return attribute.get("multiplicity") is not None and bounds(attribute["multiplicity"])[1] > 1

    def identifying_child(self, association):
        """
        Finds the class, that an association identifies.

        Rules:
        - The part of a composition is identified by its whole.
        - The weak entity of an identifying relationship of the ERD is
          identified by its owner.

        Args:
            association (dict[]): Association of the UML model.

        Returns:
            str: Key of the identified class, or None.
        """
        if association.get("kind") == "composition":
            return next(key for key in association["ends"] if key != association["whole"])

        relation = next(
            (item for item in self.erd_source.model.relationships
             if association.get("erd") == self.signature(item)),
            None,
        )

        if relation is None or not relation.get("identifying"):
            return None

        weak = self.owners[self.signature(relation)][1]

        return next(
            (key for key in association["ends"] if self.classes[key].get("entity") == weak), None
        )

    @staticmethod
    def signature(relation):
        return f"{relation['name']}:{'/'.join(sorted(relation['ends']))}"

    def not_stored(self, key, attribute):
        """
        Finds the UML constraint, that says, that a derived attribute is not stored.

        Args:
            key (str): Key of the class.
            attribute (str): Name of the attribute.

        Returns:
            dict[]: The constraint, or None.
        """
        for item in self.constraints:
            text = item.get("text", "").casefold()

            if (
                key in item.get("classes", [])
                and re.search(PATTERNS["not_stored"], text)
                and re.search(rf"\b{words(attribute)}\b", text)
            ):
                return item

        return None

    def is_nullable(self, attribute):
        """
        Decides, whether a column of an attribute can be NULL.

        Rules:
        - A key and a partial key are never NULL.
        - The multiplicity of the attribute has the lower bound 0.
        - The matrix says "<attribute> value can be equal to ... or NULL", or the
          matrix or an assumption of the ERD says, that it "can be empty".

        Args:
            attribute (dict[]): Attribute of the UML model.

        Returns:
            bool: True, if the column is NULL.
        """
        if attribute.get("kind") in ("key", "partial"):
            return False
        if attribute.get("multiplicity") and bounds(attribute["multiplicity"])[0] == 0:
            return True

        name = words(attribute["name"])
        texts = [self.matrix.text] + [item.casefold() for item in self.erd_source.model.assumptions]

        return any(
            re.search(PATTERNS["null_value"].format(words=name), text)
            or re.search(PATTERNS["empty"].format(words=name), text)
            for text in texts
        )
