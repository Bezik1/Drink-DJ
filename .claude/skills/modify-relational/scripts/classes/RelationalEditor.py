import json
import re

from classes.RelationalModel import RelationalModel
from const.general import ON_DELETE, PATTERNS, SURROGATE
from utils.naming import constraints_stem, title
from utils.sql import is_sql_type

OPERATIONS = [
    "move", "rename-table", "rename-column", "set-type", "set-null", "set-on-delete", "add-unique", "remove-unique",
    "add-surrogate",
]


class RelationalEditor:
    """
    Changes of the JSON model of a relational model. A change is kept only
    when the changed model is still valid against the UML, so the diagram
    and the UML stay consistent. A rename also changes the names in the
    constraints file of the `relational-constraints` skill, when it exists.

    Args:
        path (Path): Path of the JSON model.
        source (UmlSource): Validated UML.
    """

    def __init__(self, path, source):
        self.path = path
        self.source = source
        self.constraints_path = path.with_name(f"{constraints_stem(path.stem)}.json")

    def __call__(self, operation, *arguments):
        """
        Applies one change.

        Args:
            operation (str): Name of a method of the editor, with "-" for "_".
            *arguments (str): Arguments of the change.

        Returns:
            str: Short description of what changed.
        """
        if operation not in OPERATIONS:
            raise RuntimeError(f"Unknown change: {operation}. Use one of {', '.join(OPERATIONS)}")

        method = getattr(self, operation.replace("-", "_"))

        before = self.path.read_text(encoding="utf-8")
        self.data = json.loads(before)
        self.tables = self.data["tables"]
        self.constraints = None

        if self.constraints_path.is_file():
            self.constraints_before = self.constraints_path.read_text(encoding="utf-8")
            self.constraints = json.loads(self.constraints_before)

        try:
            message = method(*arguments)
        except TypeError:
            raise RuntimeError(f"Wrong arguments of {operation}. See the table of changes in SKILL.md.")

        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        try:
            RelationalModel(self.path, self.source)()
        except RuntimeError:
            self.path.write_text(before, encoding="utf-8")
            raise

        if self.constraints is not None and json.loads(self.constraints_before) != self.constraints:
            self.constraints_path.write_text(
                json.dumps(self.constraints, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            message += f". Changed {self.constraints_path.name} too, so build it again with relational-constraints"

        return message

    def table(self, name):
        if name not in self.tables:
            raise RuntimeError(f"Table not found: {name}")

        return self.tables[name]

    def column(self, table, name):
        found = next((item for item in self.table(table)["columns"] if item["name"] == name), None)

        if found is None:
            raise RuntimeError(f"{table}: column not found: {name}")

        return found

    def columns(self, table, text):
        names = [item.strip() for item in text.split(",") if item.strip()]

        for name in names:
            self.column(table, name)

        return names

    def foreign_key(self, table, text):
        names = self.columns(table, text)
        found = next((item for item in self.table(table)["foreign_keys"] if item["columns"] == names), None)

        if found is None:
            raise RuntimeError(f"{table}: no foreign key ({', '.join(names)})")

        return found

    def move(self, table, column, row):
        """
        Moves a table to another cell.

        Args:
            table (str): Name of the table.
            column (str): Column of the grid, can be a fraction.
            row (str): Row of the grid, can be a fraction.

        Returns:
            str: What changed.
        """
        cell = [float(column), float(row)]
        cell = [int(value) if value.is_integer() else value for value in cell]
        self.table(table)["cell"] = cell

        return f"{table}: moved to {cell}"

    def rename_table(self, table, name):
        """
        Renames a table, every foreign key, that references it, and the
        table in the constraints.

        Args:
            table (str): Name of the table.
            name (str): New name, in Pascal case with `_` (`Order_Item`).

        Returns:
            str: What changed.
        """
        self.table(table)

        if not re.fullmatch(PATTERNS["table"], name):
            raise RuntimeError(f"{name}: the name of a table must be like Order_Item")
        if name in self.tables:
            raise RuntimeError(f"{name}: the table exists already")

        self.data["tables"] = {(name if key == table else key): value for key, value in self.tables.items()}
        self.tables = self.data["tables"]

        for item in self.tables.values():
            for key in item.get("foreign_keys", []):
                if key["references"] == table:
                    key["references"] = name

        for item in self.constraint_items():
            item["tables"] = [name if value == table else value for value in item.get("tables", [])]

            if "columns" in item:
                item["columns"] = [re.sub(rf"^{re.escape(table)}\.", f"{name}.", value) for value in item["columns"]]

            item["text"] = self.replace_word(item["text"], table, name)
            item["text"] = self.replace_word(item["text"], title(table), title(name))

        if self.constraints is not None:
            self.constraints["covered"] = {
                key: self.replace_word(value, table, name) for key, value in self.constraints.get("covered", {}).items()
            }

        return f"{table}: renamed to {name}"

    def rename_column(self, table, column, name):
        """
        Renames a column, that does not come from the UML (a foreign key
        column or an assumed one), in its keys, in the foreign keys, that
        reference it, and in the constraints. A column of another table, that
        references it and has the same name, is renamed too, so one name is
        kept in every table, for example `start_stop` of Route_Sequence,
        Comment and Likes.

        Args:
            table (str): Name of the table.
            column (str): Name of the column.
            name (str): New name, in snake case.

        Returns:
            str: What changed.
        """
        found = self.column(table, column)

        if found.get("uml"):
            raise RuntimeError(f"{table}.{column}: it has the name of the UML attribute {found['uml']}. Rename it in the UML.")
        if not re.fullmatch(PATTERNS["snake"], name):
            raise RuntimeError(f"{name}: the name of a column must be in snake_case")

        renamed, pending = [], [(table, column)]

        while pending:
            owner, old = pending.pop(0)

            if any(item["name"] == name for item in self.table(owner)["columns"]):
                raise RuntimeError(f"{owner}.{name}: the column exists already")

            self.rename_one(owner, old, name)
            renamed.append(f"{owner}.{old}")

            for other, item in self.tables.items():
                for key in item.get("foreign_keys", []):
                    if key["references"] == owner and name in key["to"]:
                        own = key["columns"][key["to"].index(name)]

                        if own == old and (other, own) not in pending:
                            pending.append((other, own))

        for entry in self.constraint_items():
            entry["text"] = self.replace_word(entry["text"], column, name)

        return f"{', '.join(renamed)}: renamed to {name}"

    def rename_one(self, table, column, name):
        item = self.table(table)
        self.column(table, column)["name"] = name
        item["primary_key"] = self.swap(item["primary_key"], column, name)

        if "unique" in item:
            item["unique"] = [self.swap(group, column, name) for group in item["unique"]]

        for key in item.get("foreign_keys", []):
            key["columns"] = self.swap(key["columns"], column, name)

        for other in self.tables.values():
            for key in other.get("foreign_keys", []):
                if key["references"] == table:
                    key["to"] = self.swap(key["to"], column, name)

        for entry in self.constraint_items():
            if "columns" in entry:
                entry["columns"] = [f"{table}.{name}" if value == f"{table}.{column}" else value for value in entry["columns"]]

    def set_type(self, table, column, kind):
        """
        Changes the SQL type of a column, and of every foreign key column,
        that references it, so their types stay equal.

        Args:
            table (str): Name of the table.
            column (str): Name of the column.
            kind (str): SQL type, for example "VARCHAR(60)".

        Returns:
            str: What changed.
        """
        if not is_sql_type(kind):
            raise RuntimeError(f"'{kind}' is not a SQL type")

        changed, pending = [], [(table, column)]

        while pending:
            owner, name = pending.pop()
            self.column(owner, name)["type"] = kind
            changed.append(f"{owner}.{name}")

            for other, item in self.tables.items():
                for key in item.get("foreign_keys", []):
                    if key["references"] == owner and name in key["to"]:
                        pending.append((other, key["columns"][key["to"].index(name)]))

        return f"{', '.join(dict.fromkeys(changed))}: type {kind}"

    def set_null(self, table, column, value):
        """
        Says, whether a column can be NULL.

        Args:
            table (str): Name of the table.
            column (str): Name of the column.
            value (str): "true" for NULL, "false" for NOT NULL.

        Returns:
            str: What changed.
        """
        if value not in ("true", "false"):
            raise RuntimeError("The value must be true or false")

        self.column(table, column)["null"] = value == "true"

        return f"{table}.{column}: {'NULL' if value == 'true' else 'NOT NULL'}"

    def set_on_delete(self, table, columns, action):
        """
        Changes the ON DELETE action of a foreign key.

        Args:
            table (str): Name of the table with the foreign key.
            columns (str): Its columns, separated by commas.
            action (str): NO ACTION, CASCADE, SET NULL or RESTRICT (with "_" for a space).

        Returns:
            str: What changed.
        """
        action = action.replace("_", " ").upper()

        if action not in ON_DELETE:
            raise RuntimeError(f"The action must be one of {ON_DELETE}")

        self.foreign_key(table, columns)["on_delete"] = action

        return f"{table} FK ({columns}): ON DELETE {action}"

    def add_unique(self, table, columns):
        """
        Adds a UNIQUE set of columns.

        Args:
            table (str): Name of the table.
            columns (str): Columns, separated by commas.

        Returns:
            str: What changed.
        """
        names = self.columns(table, columns)
        groups = self.table(table).setdefault("unique", [])

        if names in groups:
            raise RuntimeError(f"{table}: UNIQUE ({', '.join(names)}) exists already")

        groups.append(names)
        self.order(table)

        return f"{table}: UNIQUE ({', '.join(names)}). Add its uniqueness constraint with relational-constraints"

    def remove_unique(self, table, columns):
        """
        Removes a UNIQUE set of columns.

        Args:
            table (str): Name of the table.
            columns (str): Columns, separated by commas.

        Returns:
            str: What changed.
        """
        names = self.columns(table, columns)
        groups = self.table(table).get("unique", [])

        if names not in groups:
            raise RuntimeError(f"{table}: no UNIQUE ({', '.join(names)})")

        groups.remove(names)

        if not groups:
            del self.table(table)["unique"]

        return f"{table}: UNIQUE ({', '.join(names)}) removed. Remove its constraint with relational-constraints"

    def add_surrogate(self, table):
        """
        Replaces the composite primary key of a table with a surrogate key
        `<table>_id`, and points every foreign key, that references it, to
        the new single column.

        Rules:
        - The old key columns stay, NOT NULL, as a UNIQUE set.
        - In a referencing table the columns of the old foreign key become one
          column `<table>_id` (with the name of the association in front, when
          the name is taken). It replaces them in the primary key and the
          UNIQUE sets of that table, and a replaced column without a UML
          attribute and without another key is removed.
        - A table of a many to many association keeps its key.

        Args:
            table (str): Name of the table.

        Returns:
            str: What changed.
        """
        item = self.table(table)
        key = list(item["primary_key"])

        if len(key) < 2:
            raise RuntimeError(f"{table}: the primary key has one column, so it needs no surrogate key")
        if item.get("association"):
            raise RuntimeError(f"{table}: a junction table keeps the key of its foreign keys")

        name = f"{table.lower()}{SURROGATE['suffix']}"

        if any(column["name"] == name for column in item["columns"]):
            raise RuntimeError(f"{table}.{name}: the column exists already")

        item["columns"].insert(0, {
            "name": name, "type": SURROGATE["type"], "null": False,
            "assumed": f"Surrogate key of {table}. The natural key ({', '.join(key)}) is UNIQUE",
        })
        item["primary_key"] = [name]
        item.setdefault("unique", []).insert(0, key)
        changed = []

        for other, owner in self.tables.items():
            for foreign in owner.get("foreign_keys", []):
                if foreign["references"] == table and foreign["to"] == key:
                    self.point_to_surrogate(other, foreign, name)
                    changed.append(other)

        self.order(table)

        return (
            f"{table}: surrogate key {name}, UNIQUE ({', '.join(key)}); foreign keys of "
            f"{', '.join(dict.fromkeys(changed)) or 'no table'} reference it. Build the constraints again"
        )

    def point_to_surrogate(self, table, foreign, name):
        """
        Makes one foreign key reference a surrogate key.

        Args:
            table (str): Name of the table with the foreign key.
            foreign (dict[]): The foreign key.
            name (str): Name of the surrogate column.
        """
        owner = self.table(table)
        old = list(foreign["columns"])
        taken = {column["name"] for column in owner["columns"]} - set(old)
        column_name = name if name not in taken else f"{foreign.get('association', 'ref').split(':')[0].replace(' ', '_')}_{name}"
        nullable = any(self.column(table, column)["null"] for column in old)
        position = min(owner["columns"].index(self.column(table, column)) for column in old)

        foreign["columns"], foreign["to"] = [column_name], [name]
        owner["columns"].insert(position, {"name": column_name, "type": SURROGATE["type"], "null": nullable})

        def replace(group):
            if not set(old) & set(group):
                return group

            result = [column for column in group if column not in old]
            result.insert(min(group.index(column) for column in old if column in group), column_name)

            return result

        owner["primary_key"] = replace(owner["primary_key"])

        if "unique" in owner:
            owner["unique"] = [replace(group) for group in owner["unique"]]

        used = {column for key in owner.get("foreign_keys", []) for column in key["columns"]}
        used |= set(owner["primary_key"]) | {column for group in owner.get("unique", []) for column in group}
        owner["columns"] = [
            column for column in owner["columns"]
            if column["name"] not in old or column.get("uml") or column["name"] in used
        ]

    def order(self, table):
        order = ["class", "association", "attribute", "cell", "columns", "primary_key",
                 "foreign_keys", "unique", "omitted", "assumed"]
        item = self.tables[table]
        self.tables[table] = {key: item[key] for key in order if key in item}

    def constraint_items(self):
        return self.constraints.get("constraints", []) if self.constraints is not None else []

    @staticmethod
    def swap(names, old, new):
        return [new if value == old else value for value in names]

    @staticmethod
    def replace_word(text, old, new):
        return re.sub(rf"(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])", new, text)
