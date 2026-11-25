import json
import re

from const.general import ON_DELETE, PATTERNS, RESERVED
from utils.multiplicity import classify
from utils.sql import enumeration_length, is_compatible, is_sql_type, marker, type_length


class RelationalModel:
    """
    Relational model, described in a JSON file, and its check against the UML
    class diagram, that it was made from.

    Args:
        path (Path): Path of the JSON file.
        source (UmlSource): Validated UML.
    """

    def __init__(self, path, source):
        self.path = path
        self.source = source
        self.errors = []
        self.warnings = []

        self.data = json.loads(path.read_text(encoding="utf-8"))
        self.tables = self.data.get("tables", {})

    def __call__(self):
        """
        Validates the model.

        Returns:
            RelationalModel: Validated model.
        """
        self.check_source()
        self.check_tables()
        self.check_foreign_keys()

        if not self.errors:
            self.check_classes()
            self.check_attributes()
            self.check_associations()

        if self.errors:
            raise RuntimeError("Invalid relational model:\n- " + "\n- ".join(self.errors))

        return self

    def save(self):
        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def check_source(self):
        if self.data.get("uml", {}).get("sha256") != self.source.sha256:
            self.errors.append(
                f"uml.sha256 does not match {self.source.file}. The UML changed, "
                "so make the relational model again with the uml-to-relational skill."
            )

    def column(self, table, name):
        return next((item for item in self.tables[table].get("columns", []) if item.get("name") == name), None)

    def foreign_columns(self, table):
        return {name for item in self.tables[table].get("foreign_keys", []) for name in item.get("columns", [])}

    def marker(self, table, name):
        """
        Finds the key marker of a column, as the diagram shows it.

        Args:
            table (str): Name of the table.
            name (str): Name of the column.

        Returns:
            str: "<PK>", "<FK>", "<PK,FK>" or "".
        """
        return marker(name in self.tables[table].get("primary_key", []), name in self.foreign_columns(table))

    def check_tables(self):
        """
        Rules:
        - A table has a name in Pascal case with words separated by `_`
          (`Order_Item`), a free cell [column, row], columns
          and a primary key, and comes from a class, an association or a
          multivalued attribute of the UML, or has the reason in `assumed`.
        - A column has a unique name in snake case, a SQL type and `null`.
          It comes from an attribute of the UML, belongs to a foreign key or has
          the reason in `assumed`.
        - The columns of the primary key exist and are NOT NULL.
        """
        cells = set()

        if not self.tables:
            self.errors.append("The model has no tables")

        for name, table in self.tables.items():
            cell = table.get("cell")

            if not re.fullmatch(PATTERNS["table"], name):
                self.errors.append(f"{name}: the name of a table must be like Order_Item")
            if not isinstance(cell, list) or len(cell) != 2 or not all(isinstance(v, (int, float)) for v in cell):
                self.errors.append(f"{name}: cell [column, row] is required")
            elif tuple(cell) in cells:
                self.errors.append(f"{name}: cell {cell} is already taken")
            else:
                cells.add(tuple(cell))

            self.check_origin(name, table)
            self.check_columns(name, table)

            if name.casefold() in RESERVED:
                self.warnings.append(f"{name}: a reserved word in SQL, so it must be quoted")

    def check_origin(self, name, table):
        origins = [key for key in ("class", "association", "attribute") if table.get(key)]

        if not origins and not table.get("assumed"):
            self.errors.append(f"{name}: give its 'class', 'association' or 'attribute', or the reason in 'assumed'")
        if table.get("class") and (
            table["class"] not in self.source.classes or self.source.classes[table["class"]].get("stereotype")
        ):
            self.errors.append(f"{name}: {table['class']} is not a class of the UML")
        if table.get("association") and table["association"] not in self.source.associations:
            self.errors.append(f"{name}: {table['association']} is not an association of the UML")
        if table.get("attribute"):
            attribute = self.source.attribute(table["attribute"])

            if attribute is None or not self.source.is_multivalued(attribute):
                self.errors.append(f"{name}: {table['attribute']} is not a multivalued attribute of the UML")

    def check_columns(self, name, table):
        names = set()
        foreign = self.foreign_columns(name)

        if not table.get("columns"):
            self.errors.append(f"{name}: the table has no columns")

        for column in table.get("columns", []):
            label = f"{name}.{column.get('name')}"

            if not re.fullmatch(PATTERNS["snake"], str(column.get("name"))):
                self.errors.append(f"{label}: the name of a column must be in snake_case")
            if column.get("name") in names:
                self.errors.append(f"{label}: the column is drawn twice")
            if not is_sql_type(column.get("type")):
                self.errors.append(f"{label}: '{column.get('type')}' is not a SQL type")
            if not isinstance(column.get("null"), bool):
                self.errors.append(f"{label}: 'null' must be true or false")
            if column.get("uml") and self.source.attribute(column["uml"]) is None:
                self.errors.append(f"{label}: {column['uml']} is not an attribute of the UML")
            if not column.get("uml") and column.get("name") not in foreign and not column.get("assumed"):
                self.errors.append(f"{label}: give its UML attribute in 'uml', or the reason in 'assumed'")
            if column.get("name") in RESERVED:
                self.warnings.append(f"{label}: a reserved word in SQL, so it must be quoted")

            names.add(column.get("name"))

        key = table.get("primary_key", [])

        if not key:
            self.errors.append(f"{name}: the table has no primary key")

        for column in key:
            found = self.column(name, column)

            if found is None:
                self.errors.append(f"{name}: the primary key column {column} does not exist")
            elif found.get("null"):
                self.errors.append(f"{name}.{column}: a column of the primary key is NOT NULL")

        for group in table.get("unique", []):
            for column in group:
                if self.column(name, column) is None:
                    self.errors.append(f"{name}: the unique column {column} does not exist")

        for item in table.get("omitted", []):
            attribute = self.source.attribute(item.get("uml", ""))

            if attribute is None or attribute.get("kind") != "derived":
                self.errors.append(f"{name}: only a derived attribute of the UML can be omitted, not {item.get('uml')}")
            if not item.get("reason"):
                self.errors.append(f"{name}: give the reason, why {item.get('uml')} is not stored")

    def check_foreign_keys(self):
        """
        Rules:
        - A foreign key references the primary key or a unique set of an
          existing table, with as many columns of the same types.
        - It has a multiplicity, that says how many rows of its table reference
          one row of the other table, and ON DELETE NO ACTION, CASCADE,
          SET NULL or RESTRICT. SET NULL needs NULL columns.
        - It comes from an association of the UML, from a multivalued attribute,
          or has the reason in `assumed`.
        """
        for name, table in self.tables.items():
            for item in table.get("foreign_keys", []):
                label = f"{name} FK ({', '.join(item.get('columns', []))})"
                target = item.get("references")

                if target not in self.tables:
                    self.errors.append(f"{label}: the referenced table {target} does not exist")
                    continue

                keys = [self.tables[target].get("primary_key", [])] + self.tables[target].get("unique", [])

                if item.get("to") not in keys:
                    self.errors.append(f"{label}: it must reference the primary key of {target}")
                if len(item.get("columns", [])) != len(item.get("to", [])):
                    self.errors.append(f"{label}: it has {len(item.get('to', []))} referenced columns")

                for own, other in zip(item.get("columns", []), item.get("to", [])):
                    first, second = self.column(name, own), self.column(target, other)

                    if first is None or second is None:
                        self.errors.append(f"{label}: column {own} or {target}.{other} does not exist")
                    elif first.get("type") != second.get("type"):
                        self.errors.append(f"{label}: {own} must have the type {second.get('type')}")

                if item.get("on_delete") not in ON_DELETE:
                    self.errors.append(f"{label}: on_delete must be one of {ON_DELETE}")
                if item.get("on_delete") == "SET NULL" and not all(
                    (self.column(name, own) or {}).get("null") for own in item.get("columns", [])
                ):
                    self.errors.append(f"{label}: SET NULL needs NULL columns")
                if not re.fullmatch(PATTERNS["multiplicity"], str(item.get("multiplicity"))):
                    self.errors.append(f"{label}: give its multiplicity, for example 0..*")
                if item.get("association") and item["association"] not in self.source.associations:
                    self.errors.append(f"{label}: {item['association']} is not an association of the UML")
                if not item.get("association") and not table.get("attribute") and not item.get("assumed"):
                    self.errors.append(f"{label}: give its UML 'association', or the reason in 'assumed'")

    def line_pair(self, name, item):
        """
        Chooses the pair of columns, that a line of a foreign key joins: the
        first column of the key, that no other foreign key of the table uses,
        with the column of the primary key, that it references. So two keys of
        one table, that start with the same column, do not share a line.

        Args:
            name (str): Name of the table with the foreign key.
            item (dict[]): The foreign key.

        Returns:
            tuple[str, str]: Column of the foreign key and the referenced column.
        """
        table = self.tables[name]
        others = {
            column for other in table.get("foreign_keys", []) if other is not item for column in other["columns"]
        }
        pairs = list(zip(item["columns"], item["to"]))

        return next((pair for pair in pairs if pair[0] not in others), pairs[0])

    def table_of(self, key):
        return next((name for name, table in self.tables.items() if table.get("class") == key), None)

    def check_classes(self):
        """
        Rules:
        - Every class of the UML, that is not an enumeration or a data type, is
          exactly one table. The class of a many to many association is its
          junction table, and the class of another association is only columns.
        """
        for key, item in self.source.classes.items():
            kind = self.source.kind_of(key)
            found = [name for name, table in self.tables.items() if table.get("class") == key]

            if kind in ("table", "junction") and len(found) != 1:
                self.errors.append(f"{item['name']}: the class is {len(found)} tables instead of 1")
            if kind not in ("table", "junction") and found:
                self.errors.append(f"{item['name']}: a {kind} class is not a table")

    def check_attributes(self):
        """
        Rules:
        - Every attribute of a class is one column, a field of a data type is
          one column, and a multivalued attribute is a table of its own.
        - Only a derived attribute can be omitted, with the reason.
        - The type of the column can store the UML type, and the VARCHAR of an
          enumeration is long enough for its values.
        - A key attribute is in the primary key or a unique set of its table,
          and a partial key is in the primary key.
        """
        columns, omitted = {}, set()

        for name, table in self.tables.items():
            omitted.update(item.get("uml") for item in table.get("omitted", []))

            for column in table.get("columns", []):
                if column.get("uml"):
                    columns.setdefault(column["uml"], []).append((name, column))

        for key, item in self.source.classes.items():
            if self.source.kind_of(key) not in ("table", "junction", "columns"):
                continue

            for attribute in item.get("attributes", []):
                path = f"{key}.{attribute['name']}"
                data_type = self.source.data_type(attribute["type"])
                paths = [f"{path}.{field['name']}" for field in data_type["attributes"]] if data_type else [path]

                for expected in paths:
                    found = columns.get(expected, [])

                    if path in omitted:
                        continue
                    if len(found) != 1:
                        self.errors.append(f"{expected}: the attribute is {len(found)} columns instead of 1")
                        continue

                    self.check_type(expected, found[0][1], self.source.attribute(expected))
                    self.check_key(expected, found[0], attribute)

    def check_type(self, path, column, attribute):
        enumeration = self.source.enumeration(attribute["type"])
        expected = "enumeration" if enumeration else attribute["type"]

        if not is_compatible(column["type"], expected):
            self.errors.append(f"{path}: {column['type']} cannot store {attribute['type']}")
        elif enumeration and type_length(column["type"]) < max(len(value) for value in enumeration["values"]):
            self.errors.append(
                f"{path}: {column['type']} is too short for {attribute['type']}, "
                f"use at least VARCHAR({enumeration_length(enumeration['values'])})"
            )

    def check_key(self, path, found, attribute):
        name, column = found
        table = self.tables[name]
        unique = [table.get("primary_key", [])] + table.get("unique", [])

        if attribute.get("kind") == "key" and not any(column["name"] in group for group in unique):
            self.errors.append(f"{path}: a key attribute must be in the primary key of {name}")
        if attribute.get("kind") == "partial" and not any(column["name"] in group for group in unique):
            self.errors.append(f"{path}: a partial key must be in the primary key or a unique set of {name}")

    def check_associations(self):
        """
        Rules:
        - An association with the upper bound 1 at one end is one foreign key
          in the table of the other end, that references the table of that end.
        - The foreign key is NULL, when the lower bound of the referenced end
          is 0 (at least one column is NULL), and NOT NULL otherwise.
        - Its multiplicity is the one of the UML at its own end. A one to one
          association has a unique foreign key.
        - A many to many association is a junction table with 2 foreign keys,
          that are its primary key. When one end has an exact multiplicity k,
          it can instead be k foreign keys in the table of the other end, that
          reference the table of the exact end and are NOT NULL.
        - The foreign key of a composition should use ON DELETE CASCADE.
        """
        for identifier, association in self.source.associations.items():
            link = classify(association)
            found = [
                (name, item) for name, table in self.tables.items()
                for item in table.get("foreign_keys", []) if item.get("association") == identifier
            ]

            if link["kind"] == "junction" and link.get("exact") and found and all(
                name == self.table_of(link["other"]) for name, _ in found
            ):
                self.check_exact(identifier, association, link, found)
                continue
            if link["kind"] == "junction":
                self.check_junction(identifier, association, found)
                continue

            child, parent = self.table_of(link["child"]), self.table_of(link["parent"])

            if len(found) != 1:
                self.errors.append(f"{identifier}: the association is {len(found)} foreign keys instead of 1")
                continue

            name, item = found[0]
            label = f"{name} FK ({', '.join(item['columns'])})"
            nulls = [self.column(name, own)["null"] for own in item["columns"]]

            if (name, item["references"]) != (child, parent):
                self.errors.append(f"{identifier}: the foreign key must be in {child} and reference {parent}")
            if link["nullable"] and not any(nulls):
                self.errors.append(f"{label}: '{association['name']}' is optional, so a column must be NULL")
            if not link["nullable"] and any(nulls):
                self.errors.append(f"{label}: '{association['name']}' is required, so its columns are NOT NULL")
            if item.get("multiplicity") != link["multiplicity"]:
                self.errors.append(f"{label}: multiplicity must be {link['multiplicity']}, as in the UML")
            if link["one_to_one"] and not any(
                set(group) == set(item["columns"])
                for group in [self.tables[name].get("primary_key", [])] + self.tables[name].get("unique", [])
            ):
                self.errors.append(f"{label}: one to one, so the columns must be the primary key or unique")
            if association.get("kind") == "composition" and item.get("on_delete") != "CASCADE":
                self.warnings.append(f"{label}: '{association['name']}' is a composition, but not ON DELETE CASCADE")

    def check_exact(self, identifier, association, link, found):
        """
        Checks k foreign keys, that replace the junction table of a many to
        many association with an exact multiplicity k at one end.

        Args:
            identifier (str): Id of the association.
            association (dict[]): Association of the UML model.
            link (dict[]): Result of `classify`.
            found (tuple[str, dict][]): Table and foreign key of the association.
        """
        parent = self.table_of(link["exact"])

        if len(found) != link["count"]:
            self.errors.append(f"{identifier}: exactly {link['count']} foreign keys, one for each {parent}")

        for name, item in found:
            label = f"{name} FK ({', '.join(item['columns'])})"

            if item["references"] != parent:
                self.errors.append(f"{label}: it must reference {parent}")
            if any(self.column(name, own)["null"] for own in item["columns"]):
                self.errors.append(f"{label}: '{association['name']}' is required, so its columns are NOT NULL")
            if item.get("multiplicity") != association["ends"][link["other"]]:
                self.errors.append(
                    f"{label}: multiplicity must be {association['ends'][link['other']]}, as in the UML"
                )

    def check_junction(self, identifier, association, found):
        tables = {name for name, _ in found}
        first, second = association["ends"]
        expected = {self.table_of(first), self.table_of(second)}

        if len(tables) != 1 or len(found) != 2:
            self.errors.append(f"{identifier}: many to many, so one junction table with 2 foreign keys")
            return

        name = tables.pop()
        key = set(self.tables[name].get("primary_key", []))

        if self.tables[name].get("association") != identifier:
            self.errors.append(f"{name}: a junction table needs 'association': '{identifier}'")
        if {item["references"] for _, item in found} != expected:
            self.errors.append(f"{name}: the junction table must reference {sorted(expected)}")
        sets = [key] + [set(group) for group in self.tables[name].get("unique", [])]
        if not all(any(set(item["columns"]) <= group for group in sets) for _, item in found):
            self.errors.append(f"{name}: both foreign keys of a junction table are in its primary key or a unique set")

        for _, item in found:
            other = first if item["references"] == self.table_of(second) else second

            if item.get("multiplicity") != association["ends"][other]:
                self.errors.append(
                    f"{name} FK ({', '.join(item['columns'])}): multiplicity must be "
                    f"{association['ends'][other]}, as in the UML"
                )

    def names(self):
        """
        Lists every name, that the diagram must show.

        Returns:
            str[]: Names of the tables and of the columns.
        """
        result = []

        for name, table in self.tables.items():
            result.append(name)
            result.extend(column["name"] for column in table.get("columns", []))

        return result
