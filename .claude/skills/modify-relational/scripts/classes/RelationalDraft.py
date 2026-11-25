from const.general import RESERVED, SURROGATE
from utils.multiplicity import classify
from utils.naming import association_id, snake_case, table_name
from utils.sql import enumeration_length, sql_type

OFFSETS = [(0, 0.5), (0.5, 0), (0, -0.5), (-0.5, 0), (0.5, 0.5), (-0.5, 0.5), (0.5, -0.5), (-0.5, -0.5)]


class RelationalDraft:
    """
    First relational model of a UML class diagram.

    Rules:
    - A class is a table with the name of the class in Pascal case, with the
      words separated by `_` ("Order Item" is `Order_Item`). An
      enumeration and a data type are not tables.
    - An attribute is a column. A data type gives a column for each of its
      attributes, and an enumeration is a VARCHAR column. Its values are a
      constraint of the `relational-constraints` skill.
    - A multivalued attribute is a table with the primary key of its class and the value.
    - A derived attribute is a column, unless a UML constraint says, that it is not stored.
    - The key attributes are the primary key. A class without them takes the
      primary key of its owners through its identifying associations, with its
      partial keys. A class without any key gets a surrogate key, as an assumption.
    - A composite primary key of a class is replaced by a surrogate key
      `<table>_id`, when it is large or other tables reference it (see
      `surrogate_reason`). Its old columns become a UNIQUE set, so the
      identity of the UML is kept, and foreign keys reference the single
      surrogate column.
    - An association with the upper bound 1 at one end is a foreign key in the
      table of the other end. A many to many association is a junction table,
      whose primary key are both foreign keys.
    - A foreign key column has the name of the referenced column. When the table
      has that column already, and both come from the same column of the same
      table, the column is shared. Otherwise, and when 2 foreign keys reference
      the same table, the name starts with the name of the association.
    - A foreign key to its own table (an association of a class with itself)
      has columns, that start with the role of its end, for example
      `base_drink_version_id`. It is NULL, when the role end starts at 0.
    - Composition, junction table and multivalued attribute use ON DELETE
      CASCADE, other foreign keys NO ACTION.

    Args:
        source (UmlSource): Validated UML.
    """

    def __init__(self, source):
        self.source = source
        self.classes = source.classes
        self.tables = {}
        self.table_of = {}
        self.roots = {}
        self.review = []

    def __call__(self):
        """
        Builds the model. The agent reviews it before the diagram is drawn.

        Returns:
            dict[]: The relational model.
        """
        self.links = {key: classify(item) for key, item in self.source.associations.items()}

        self.build_class_tables()
        self.build_keys()
        self.build_foreign_keys()
        self.build_junctions()
        self.build_multivalued()
        self.build_unique()
        self.check_names()

        return {
            "uml": {"file": self.source.file, "sha256": self.source.sha256},
            "tables": {name: self.finish(table) for name, table in self.tables.items()},
        }

    def build_class_tables(self):
        for key in self.source.table_classes():
            name = table_name(self.classes[key]["name"])
            table = self.new_table(name, {"class": key}, self.classes[key].get("cell"))
            self.table_of[key] = name

            for attribute in self.classes[key].get("attributes", []):
                self.add_attribute(table, key, attribute)

        for association, link in self.links.items():
            item = self.source.associations[association]

            if item.get("class") and link["kind"] == "foreign_key":
                table = self.tables[self.table_of[link["child"]]]

                for attribute in self.classes[item["class"]].get("attributes", []):
                    self.add_attribute(table, item["class"], attribute)

                self.review.append(
                    f"{table['name']}: has the attributes of the association class "
                    f"{self.classes[item['class']]['name']}"
                )

    def new_table(self, name, origin, cell):
        if name in self.tables:
            raise RuntimeError(f"Two tables are named {name}. Rename a class of the UML.")

        table = {
            "name": name, **origin, "cell": list(cell) if cell else None,
            "columns": [], "primary_key": [], "foreign_keys": [], "unique": [], "omitted": [],
        }
        self.tables[name] = table

        return table

    def add_attribute(self, table, key, attribute):
        """
        Adds the columns of an attribute to a table.

        Args:
            table (dict[]): The table.
            key (str): Key of the class of the attribute.
            attribute (dict[]): Attribute of the UML model.
        """
        path = f"{key}.{attribute['name']}"

        if attribute.get("kind") == "derived":
            constraint = self.source.not_stored(key, attribute["name"])

            if constraint:
                table["omitted"].append({"uml": path, "reason": f"{constraint['id']}: {constraint['text']}"})
                self.review.append(f"{table['name']}: {attribute['name']} is not stored ({constraint['id']})")
                return

            self.review.append(f"{table['name']}: derived {attribute['name']} is stored and set by the database")

        if self.source.is_multivalued(attribute):
            table.setdefault("multivalued", []).append((key, attribute))
            return

        nullable = self.source.is_nullable(attribute)

        if nullable and self.source.data_type(attribute["type"]) is None:
            self.review.append(f"{table['name']}.{attribute['name']}: NULL")

        data_type = self.source.data_type(attribute["type"])

        if data_type is None:
            kind = self.column_type(attribute, table["name"])
            self.add_column(table, attribute["name"], kind, nullable, path, attribute.get("kind"))
            return

        for field in data_type.get("attributes", []):
            name = field["name"]

            if self.column(table, name):
                name = f"{attribute['name']}_{name}"

            self.add_column(table, name, self.column_type(field, table["name"]), nullable, f"{path}.{field['name']}")

        if nullable:
            self.review.append(f"{table['name']}: the columns of {attribute['name']} are NULL")

    def column_type(self, attribute, table):
        enumeration = self.source.enumeration(attribute["type"])

        if enumeration is not None:
            return f"VARCHAR({enumeration_length(enumeration.get('values', []))})"

        result = sql_type(attribute["type"], attribute["name"])

        if attribute["type"] == "String":
            self.review.append(f"{table}.{attribute['name']}: {result} is a guessed length")

        return result

    def add_column(self, table, name, kind, nullable, path=None, role=None):
        if self.column(table, name):
            raise RuntimeError(f"{table['name']}.{name}: two columns have the same name. Rename one in the UML.")

        column = {"name": name, "type": kind, "null": bool(nullable)}

        if path:
            column["uml"] = path

        column["role"] = role
        table["columns"].append(column)
        self.roots[(table["name"], name)] = (table["name"], name)

        return column

    @staticmethod
    def column(table, name):
        return next((item for item in table["columns"] if item["name"] == name), None)

    def build_keys(self):
        """
        Finds the primary key of every table of a class. A table, that is
        identified by another one, waits until that one has its key.
        """
        pending = list(self.table_of)

        while pending:
            ready = [key for key in pending if all(
                self.table_of[parent] not in [self.table_of[item] for item in pending]
                for parent, _ in self.identifying_parents(key)
            )]

            if not ready:
                names = ", ".join(self.classes[key]["name"] for key in pending)

                raise RuntimeError(f"Identifying associations form a cycle: {names}. Change the UML.")

            for key in ready:
                self.build_key(key)
                pending.remove(key)

    def identifying_parents(self, key):
        """
        Lists the owners, that identify a class, the whole of a composition first.

        Args:
            key (str): Key of the class.

        Returns:
            tuple[str, str][]: Key of the owner and the id of the association.
        """
        found = []

        for association, link in self.links.items():
            item = self.source.associations[association]

            if self.source.identifying_child(item) != key:
                continue
            if link["kind"] == "junction":
                self.review.append(
                    f"{self.table_of[key]}: it is identified through the many to many association "
                    f"'{item['name']}', which is a junction table. Choose its primary key by hand. "
                    "When one end has an exact multiplicity, it can be that many foreign keys instead."
                )
                continue
            if link["child"] == key:
                found.append((link["parent"], association, item.get("kind") != "composition"))

        return [(parent, association) for parent, association, _ in sorted(found, key=lambda item: item[2])]

    def build_key(self, key):
        table = self.tables[self.table_of[key]]
        own = [item["name"] for item in table["columns"] if item.get("role") == "key"]

        if own:
            table["primary_key"] = self.surrogate(key, table, own)
            return

        key_columns = []

        for parent, association in self.identifying_parents(key):
            columns = self.add_foreign_key(table, self.table_of[parent], association, self.links[association])
            key_columns.extend(column for column in columns if column not in key_columns)

        key_columns.extend(item["name"] for item in table["columns"] if item.get("role") == "partial")

        for column in table["columns"]:
            column.pop("role", None)

        if not key_columns:
            name = f"{table['name'].lower()}_id"
            column = self.add_column(table, name, "INTEGER", False)
            column.pop("role")
            column["assumed"] = f"The UML gives no key of {self.classes[key]['name']}, so it has a surrogate key"
            key_columns = [name]
            self.review.append(f"{table['name']}: surrogate key {name}, because the UML has no key")

        for name in key_columns:
            self.column(table, name)["null"] = False

        table["primary_key"] = self.surrogate(key, table, key_columns)

    def surrogate_reason(self, key, columns):
        """
        Decides, whether a composite primary key is better replaced by a
        surrogate key.

        Criterion:
        - A key of `SURROGATE["always_from"]` or more columns always gets a
          surrogate key, because every foreign key and index would repeat all
          of them.
        - A key of `SURROGATE["referenced_from"]` or more columns gets one, when
          another table references the class, because each referencing table
          would copy all key columns and join on all of them.
        - A key of one column stays as it is.

        Args:
            key (str): Key of the class.
            columns (str[]): Columns of the natural primary key.

        Returns:
            str: The reason, or None, when the natural key stays.
        """
        if len(columns) >= SURROGATE["always_from"]:
            return f"its key has {len(columns)} columns"
        if len(columns) >= SURROGATE["referenced_from"] and self.is_referenced(key):
            return f"its key has {len(columns)} columns and other tables reference it"

        return None

    def is_referenced(self, key):
        """
        Checks, whether a foreign key of another table will reference a class.

        Args:
            key (str): Key of the class.

        Returns:
            bool: True for the parent of a foreign key, an end of a many to
                many association or the owner of a multivalued attribute.
        """
        for link in self.links.values():
            if link["kind"] == "foreign_key" and link["parent"] == key and link["child"] != key:
                return True
            if link["kind"] == "junction" and key in link["ends"]:
                return True

        return any(self.source.is_multivalued(item) for item in self.classes[key].get("attributes", []))

    def surrogate(self, key, table, columns):
        """
        Gives a table its primary key, with a surrogate key instead of a
        large composite one.

        Args:
            key (str): Key of the class.
            table (dict[]): The table.
            columns (str[]): Columns of the natural primary key.

        Returns:
            str[]: Columns of the primary key.
        """
        reason = self.surrogate_reason(key, columns)

        if reason is None:
            return columns

        name = f"{table['name'].lower()}{SURROGATE['suffix']}"
        column = self.add_column(table, name, SURROGATE["type"], False)
        column.pop("role")
        column["assumed"] = (
            f"Surrogate key of {self.classes[key]['name']}, because {reason}. "
            f"The natural key ({', '.join(columns)}) is UNIQUE"
        )
        table["unique"].append(list(columns))
        self.review.append(
            f"{table['name']}: surrogate key {name}, because {reason}. "
            f"UNIQUE ({', '.join(columns)}) keeps the natural key"
        )

        return [name]

    def build_foreign_keys(self):
        for association, link in self.links.items():
            if link["kind"] != "foreign_key":
                continue

            table = self.tables[self.table_of[link["child"]]]

            if any(item["association"] == association for item in table["foreign_keys"]):
                continue

            self.add_foreign_key(table, self.table_of[link["parent"]], association, link)

    def add_foreign_key(self, table, parent, association, link, cascade=False):
        """
        Adds a foreign key, that references the primary key of another table.

        Args:
            table (dict[]): Table with the foreign key.
            parent (str): Name of the referenced table.
            association (str): Id of the UML association.
            link (dict[]): Result of `classify`, or the junction end.
            cascade (bool, optional): ON DELETE CASCADE. Default: False, but a
                composition always cascades.

        Returns:
            str[]: Names of the columns of the foreign key.
        """
        item = self.source.associations[association]
        target = self.tables[parent]
        if link.get("recursive"):
            prefix = link["role"]
        else:
            prefix = snake_case(item["name"]) if self.has_twin(table, parent, association) else None
        columns = []

        for referenced in target["primary_key"]:
            columns.append(self.reference_column(table, target, referenced, prefix, link["nullable"]))

        if link["nullable"] and all(not self.column(table, name)["null"] for name in columns):
            self.review.append(
                f"{table['name']}: the foreign key of '{item['name']}' is optional, "
                "but all its columns are NOT NULL"
            )

        cascade = cascade or (item.get("kind") == "composition" and self.table_of.get(item["whole"]) == parent)
        table["foreign_keys"].append({
            "columns": columns,
            "references": parent,
            "to": list(target["primary_key"]),
            "association": association,
            "multiplicity": link["multiplicity"],
            "on_delete": "CASCADE" if cascade else "NO ACTION",
        })

        return columns

    def has_twin(self, table, parent, association):
        """
        Checks, whether another association joins the same 2 tables in the same way.

        Args:
            table (dict[]): Table with the foreign key.
            parent (str): Name of the referenced table.
            association (str): Id of the UML association.

        Returns:
            bool: True, if the columns need the name of the association.
        """
        if table.get("association"):
            return False

        return any(
            key != association and link["kind"] == "foreign_key"
            and self.table_of.get(link["child"]) == table["name"]
            and self.table_of.get(link["parent"]) == parent
            for key, link in self.links.items()
        )

    def reference_column(self, table, target, referenced, prefix, nullable):
        """
        Finds or adds the column, that references one column of a primary key.

        Args:
            table (dict[]): Table with the foreign key.
            target (dict[]): Referenced table.
            referenced (str): Referenced column.
            prefix (str): Name of the association, or None.
            nullable (bool): Whether the foreign key is optional.

        Returns:
            str: Name of the column.
        """
        root = self.roots[(target["name"], referenced)]
        source = self.column(target, referenced)
        name = f"{prefix}_{referenced}" if prefix else referenced
        existing = self.column(table, name)

        if existing is not None and not prefix:
            same_target = any(
                name in item["columns"] and item["references"] == target["name"] for item in table["foreign_keys"]
            )

            if self.roots.get((table["name"], name)) == root and not same_target:
                existing["null"] = existing["null"] and nullable
                self.review.append(
                    f"{table['name']}.{name}: shared by 2 foreign keys, because both come from "
                    f"{root[0]}.{root[1]}. Keep it only, when they must be equal."
                )
                return name

            name = f"{target['name'].lower()}_{referenced}"

        number = 2

        while self.column(table, name):
            name = f"{target['name'].lower()}_{referenced}_{number}"
            number += 1

        column = self.add_column(table, name, source["type"], nullable)
        column.pop("role")
        self.roots[(table["name"], name)] = root

        return name

    def build_junctions(self):
        names = [item["name"] for item in self.source.associations.values()]

        for association, link in self.links.items():
            if link["kind"] != "junction":
                continue

            item = self.source.associations[association]
            first, second = link["ends"]
            name = self.junction_name(item, names, first, second)
            cell = self.classes[item["class"]].get("cell") if item.get("class") else None
            origin = {"association": association, **({"class": item["class"]} if item.get("class") else {})}
            table = self.new_table(name, origin, cell or self.between(first, second))
            key = []

            for parent, other in ((first, second), (second, first)):
                end = {"nullable": False, "multiplicity": item["ends"][other]}
                key.extend(self.add_foreign_key(table, self.table_of[parent], association, end, cascade=True))

            for attribute in self.classes[item["class"]].get("attributes", []) if item.get("class") else []:
                self.add_attribute(table, item["class"], attribute)

            for column in table["columns"]:
                column.pop("role", None)

            table["primary_key"] = key
            self.review.append(
                f"{name}: junction table of '{item['name']}', ON DELETE CASCADE. When its name is a verb, "
                "rename it to a noun, that says what one row is, for example Route_To_Sequence_Assignment"
            )

    def junction_name(self, item, names, first, second):
        if item.get("class"):
            return table_name(self.classes[item["class"]]["name"])

        name = table_name(item["name"])

        if names.count(item["name"]) > 1 or name in self.tables:
            name = f"{self.table_of[first]}_{self.table_of[second]}"

        return name

    def between(self, first, second):
        """
        Finds a cell for a junction table near both of its tables.

        Rules:
        - The table stands halfway between them.
        - When they share a column or a row, it moves half a cell to the
          side, so it does not stand on the line of another association
          between them.

        Args:
            first (str): Key of the first class.
            second (str): Key of the second class.

        Returns:
            float[2]: The cell.
        """
        one = self.tables[self.table_of[first]]["cell"]
        two = self.tables[self.table_of[second]]["cell"]
        middle = [(one[0] + two[0]) / 2, (one[1] + two[1]) / 2]

        if one[0] == two[0]:
            middle[0] += 0.5
        elif one[1] == two[1]:
            middle[1] += 0.5

        return self.free_cell(middle)

    def free_cell(self, cell):
        taken = {tuple(item["cell"]) for item in self.tables.values() if item["cell"]}

        if tuple(cell) not in taken:
            return cell

        for dx, dy in OFFSETS:
            candidate = [cell[0] + dx, cell[1] + dy]

            if tuple(candidate) not in taken:
                return candidate

        return [max(item[0] for item in taken) + 1, cell[1]]

    def build_multivalued(self):
        for table in list(self.tables.values()):
            for key, attribute in table.pop("multivalued", []):
                name = table_name(f"{table['name']} {attribute['name']}")
                new = self.new_table(name, {"attribute": f"{key}.{attribute['name']}"}, self.free_cell(table["cell"]))
                columns = [self.reference_column(new, table, column, None, False) for column in table["primary_key"]]
                value = attribute["name"] if not self.column(new, attribute["name"]) else f"{attribute['name']}_value"
                kind = self.column_type(attribute, name)
                self.add_column(new, value, kind, False, f"{key}.{attribute['name']}").pop("role")
                new["foreign_keys"].append({
                    "columns": columns, "references": table["name"], "to": list(table["primary_key"]),
                    "multiplicity": attribute["multiplicity"], "on_delete": "CASCADE",
                })
                new["primary_key"] = columns + [value]
                self.review.append(f"{name}: table of the multivalued attribute {attribute['name']}")

    def build_unique(self):
        for table in self.tables.values():
            for item in table["foreign_keys"]:
                link = self.links.get(item.get("association"))

                if link and link["kind"] == "foreign_key" and link["one_to_one"]:
                    if set(item["columns"]) != set(table["primary_key"]):
                        table["unique"].append(list(item["columns"]))

    def check_names(self):
        for table in self.tables.values():
            names = [table["name"]] + [item["name"] for item in table["columns"]]

            for name in names:
                if name.casefold() in RESERVED:
                    self.review.append(f"{table['name']}: '{name}' is a reserved word in SQL, so quote it")

    @staticmethod
    def finish(table):
        """
        Puts the columns in order: the primary key, the attributes and then the
        other foreign key columns, and drops the empty lists.

        Args:
            table (dict[]): Table of the draft.

        Returns:
            dict[]: Table of the model.
        """
        foreign = {name for item in table["foreign_keys"] for name in item["columns"]}
        primary = [next(item for item in table["columns"] if item["name"] == name) for name in table["primary_key"]]
        rest = [item for item in table["columns"] if item["name"] not in table["primary_key"]]
        rest.sort(key=lambda item: item["name"] in foreign)
        result = {name: value for name, value in table.items() if name not in ("name", "columns")}
        result["columns"] = [
            {name: value for name, value in item.items() if name != "role"} for item in primary + rest
        ]

        for name in ("unique", "omitted"):
            if not result[name]:
                del result[name]

        order = ["class", "association", "attribute", "cell", "columns", "primary_key",
                 "foreign_keys", "unique", "omitted"]

        return {name: result[name] for name in order if name in result}
