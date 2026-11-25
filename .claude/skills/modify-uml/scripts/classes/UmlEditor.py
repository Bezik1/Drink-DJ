import json

from classes.UmlModel import UmlModel
from utils.naming import end_class, is_multiplicity


class UmlEditor:
    """
    Changes of the JSON model of a UML diagram. A change is kept only when the
    changed model is still valid, so the diagram and the ERD stay consistent.

    Args:
        path (Path): Path of the JSON model.
        source (ErdSource): ERD and matrix, from which the UML comes.
    """

    def __init__(self, path, source):
        self.path = path
        self.source = source

    def __call__(self, operation, *arguments, reason=None):
        """
        Applies one change.

        Args:
            operation (str): Name of a method of the editor, with "-" for "_".
            *arguments (str): Arguments of the change.
            reason (str, optional): Reason of a thing, that is not in the ERD.

        Returns:
            str: Short description of what changed.
        """
        method = getattr(self, operation.replace("-", "_"), None)

        if method is None or operation.startswith("_"):
            raise RuntimeError(f"Unknown change: {operation}")

        before = self.path.read_text(encoding="utf-8")
        self.data = json.loads(before)
        self.reason = reason

        message = method(*arguments)

        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        try:
            UmlModel(self.path, self.source)()
        except RuntimeError:
            self.path.write_text(before, encoding="utf-8")
            raise

        return message

    def find_class(self, name):
        for key, item in self.data["classes"].items():
            if name in (key, item["name"]):
                return key, item

        raise RuntimeError(f"Class not found: {name}")

    def find_attribute(self, class_name, name):
        key, item = self.find_class(class_name)

        for attribute in item.get("attributes", []):
            if attribute["name"] == name:
                return item, attribute

        raise RuntimeError(f"{item['name']}: attribute not found: {name}")

    def find_association(self, name, first, second):
        keys = {self.find_class(first)[0], self.find_class(second)[0]}

        for item in self.data["associations"]:
            if item["name"] == name and {end_class(end) for end in item["ends"]} == keys:
                return item

        raise RuntimeError(f"Association not found: {first} {name} {second}")

    def move(self, name, column, row):
        """
        Moves a class to another cell of the grid.

        Args:
            name (str): Name or key of the class.
            column (str): New column, a number.
            row (str): New row, a number.
        """
        item = self.find_class(name)[1]

        if item.get("stereotype") == "enumeration":
            raise RuntimeError("An enumeration always stands in the top right corner and cannot be moved")

        item["cell"] = [int(column), int(row)]

        return f"{item['name']} moved to cell {item['cell']}"

    def set_type(self, class_name, attribute, new_type):
        """
        Changes the type of an attribute.

        Args:
            class_name (str): Name or key of the class.
            attribute (str): Name of the attribute.
            new_type (str): Primitive type, enumeration or data type.
        """
        self.find_attribute(class_name, attribute)[1]["type"] = new_type

        return f"{class_name}.{attribute} has type {new_type}"

    def rename_attribute(self, class_name, attribute, new_name):
        """
        Renames an attribute. Its link to the ERD stays.

        Args:
            class_name (str): Name or key of the class.
            attribute (str): Name of the attribute.
            new_name (str): New name in snake_case.
        """
        self.find_attribute(class_name, attribute)[1]["name"] = new_name

        return f"{class_name}.{attribute} is now {new_name}"

    def add_operation(self, class_name, operation):
        """
        Adds an operation without parameters, that is not in the ERD. It needs
        a reason. An operation with parameters or a return type is written in
        the JSON model.

        Args:
            class_name (str): Name or key of the class.
            operation (str): Name in snake_case.
        """
        item = self.find_class(class_name)[1]

        item.setdefault("operations", []).append({"name": operation, "assumed": self.need_reason()})

        return f"{item['name']}.{operation}() added"

    def remove_operation(self, class_name, operation):
        """
        Removes an operation.

        Args:
            class_name (str): Name or key of the class.
            operation (str): Name of the operation.
        """
        item = self.find_class(class_name)[1]
        found = [entry for entry in item.get("operations", []) if entry["name"] == operation]

        if not found:
            raise RuntimeError(f"{item['name']}: operation not found: {operation}")

        item["operations"].remove(found[0])

        if not item["operations"]:
            del item["operations"]

        return f"{item['name']}.{operation}() removed"

    def add_attribute(self, class_name, attribute, attribute_type):
        """
        Adds an attribute, that is not in the ERD. It needs a reason.

        Args:
            class_name (str): Name or key of the class.
            attribute (str): Name in snake_case.
            attribute_type (str): Primitive type, enumeration or data type.
        """
        item = self.find_class(class_name)[1]

        item.setdefault("attributes", []).append({
            "name": attribute,
            "type": attribute_type,
            "assumed": self.need_reason(),
        })

        return f"{item['name']}.{attribute} added"

    def remove_attribute(self, class_name, attribute):
        """
        Removes an attribute. An attribute of the ERD cannot be removed.

        Args:
            class_name (str): Name or key of the class.
            attribute (str): Name of the attribute.
        """
        item, found = self.find_attribute(class_name, attribute)
        item["attributes"].remove(found)

        return f"{item['name']}.{attribute} removed"

    def add_enumeration(self, name, *values):
        """
        Adds an enumeration, that is not in the matrix. It needs a reason. It
        stands in the top right corner of the diagram.

        Args:
            name (str): Name of the enumeration, for example "Part Type".
            *values (str): Values in snake_case.
        """
        key = name.lower().replace(" ", "_")

        self.data["classes"][key] = {
            "name": name,
            "stereotype": "enumeration",
            "values": list(values),
            "assumed": self.need_reason(),
        }

        return f"Enumeration {name} added in the top right corner"

    def set_multiplicity(self, name, first, second, multiplicity, end):
        """
        Changes a multiplicity of an association, which must still match the ERD.

        Args:
            name (str): Name of the association.
            first (str): Name or key of one class.
            second (str): Name or key of the other class.
            multiplicity (str): New multiplicity like "0..*".
            end (str): Name or key of the class, whose end changes.
        """
        item = self.find_association(name, first, second)

        if not is_multiplicity(multiplicity):
            raise RuntimeError(f"Wrong multiplicity: {multiplicity}")

        item["ends"][self.find_class(end)[0]] = multiplicity

        return f"{name}: {end} has multiplicity {multiplicity}"

    def need_reason(self):
        if not self.reason:
            raise RuntimeError("A thing, that is not in the ERD, needs --reason")

        return self.reason
