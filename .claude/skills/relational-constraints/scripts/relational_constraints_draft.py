"""
First version of the constraints of a relational model, written from the UML.
"""
import re

from relational_constraints_const import ALL_TABLES, FIRST_NUMBER, ID_PREFIX, KINDS, REASONS, TEXTS
from utils.multiplicity import bounds
from utils.naming import title, words


def listed(items, last="and"):
    if len(items) < 2:
        return "".join(items)

    return f"{', '.join(items[:-1])} {last} {items[-1]}"


def numbered(items, first):
    """
    Gives every constraint its id.

    Rules:
    - The ids are `C01`, `C02`, ... from one, without gaps, so one id never
      names two constraints.
    - The constraints are sorted by kind: domain, uniqueness, rule,
      derivation and referential, and keep their order within a kind.

    Args:
        items (dict[]): Constraints, with or without ids.
        first (int): Number of the first id.

    Returns:
        dict[]: Constraints with new ids, the id first.
    """
    ordered = sorted(items, key=lambda item: KINDS.index(item["kind"]))

    return [
        {"id": f"{ID_PREFIX}{number:02d}", **{key: value for key, value in item.items() if key != "id"}}
        for number, item in enumerate(ordered, first)
    ]


class RelationalConstraintsDraft:
    """
    Candidates of the constraints, that a relational model diagram cannot show.

    Rules:
    - The values of every enumeration, whose column is a VARCHAR, are a
      `domain` constraint, with NULL when a column can be NULL.
    - Every constraint of the UML is carried over to the tables of its
      classes, with its kind and requirements. An `identity` constraint is
      shown by a primary key, so it goes to `covered` with the reason.
    - A stored derived column is set by the database, so its `derivation`
      says so. A stored derived column without a UML formula gets a candidate.
    - Every UNIQUE set of the model is a `uniqueness` constraint.
    - A multiplicity of a foreign key, that the crow's foot of the diagram
      cannot show (a lower bound above 1, or a finite upper bound above 1), is
      a `rule` with its `foreign_key`, for example "Every Schedule has at
      least 2 Schedule Stops".
    - Every ON DELETE action is a `referential` constraint: CASCADE, SET NULL
      and RESTRICT one by one. NO ACTION is not written.

    Args:
        source (UmlSource): Validated UML with its constraints.
        model (RelationalModel): Validated relational model.
    """

    def __init__(self, source, model):
        self.source = source
        self.model = model
        self.items = []
        self.covered = {}

    def __call__(self):
        """
        Builds the candidates. The agent reviews them.

        Returns:
            dict[]: Description of the constraints.
        """
        self.domains()
        self.carry_over()
        self.multiplicities()
        self.derived()
        self.uniques()
        self.referential()

        constraints = numbered(self.items, FIRST_NUMBER)

        return {
            "relational": {"file": self.source.relative(self.model.path)},
            "uml_constraints": {
                "file": self.source.relative(self.source.constraints_path),
                "sha256": self.source.constraints_sha256,
            },
            "covered": self.covered,
            "constraints": constraints,
        }

    def add(self, kind, tables, text, columns=None, sources=None, assumed=None, uml=None, foreign_key=None):
        item = {"kind": kind, "tables": tables}

        if columns:
            item["columns"] = columns

        item["text"] = text

        if sources:
            item["from"] = sources
        if assumed and not sources:
            item["assumed"] = assumed
        if uml:
            item["uml"] = uml
        if foreign_key:
            item["foreign_key"] = foreign_key

        self.items.append(item)

    def own_columns(self):
        for name, table in self.model.tables.items():
            for column in table["columns"]:
                if column.get("uml"):
                    yield name, column, self.source.attribute(column["uml"])

    @staticmethod
    def class_title(table):
        return title(table)

    def domains(self):
        groups = {}

        for name, column, attribute in self.own_columns():
            enumeration = self.source.enumeration(attribute["type"])

            if enumeration is not None:
                groups.setdefault(enumeration["name"], []).append((name, column))

        for enumeration, found in groups.items():
            item = self.source.enumeration(enumeration)
            names = list(dict.fromkeys(f"{title(column['name'])} value" for _, column in found))
            values = [f"“{value}”" for value in item["values"]]

            if any(column["null"] for _, column in found):
                values.append("NULL")

            self.add(
                "domain",
                list(dict.fromkeys(name for name, _ in found)),
                TEXTS["domain"].format(names=listed(names), values=listed(values, "or")),
                [f"{name}.{column['name']}" for name, column in found],
                item.get("from"),
                REASONS["enumeration"].format(name=enumeration),
            )

    def tables_of(self, classes):
        found = []

        for key in classes:
            for name, table in self.model.tables.items():
                if table.get("class") == key or any(
                    column.get("uml", "").startswith(f"{key}.") for column in table["columns"]
                ):
                    found.append(name)

        return list(dict.fromkeys(found))

    def stored_derived(self, tables):
        return [
            (name, column) for name, column, attribute in self.own_columns()
            if name in tables and attribute.get("kind") == "derived"
        ]

    def carry_over(self):
        for item in self.source.constraints:
            tables = self.tables_of(item.get("classes", []))

            if item.get("kind") == "identity":
                self.covered[item["id"]] = TEXTS["covered"].format(tables=listed(tables))
                continue

            text, columns = item["text"], None

            if item.get("kind") == "derivation":
                stored = [
                    f"{name}.{column['name']}" for name, column in self.stored_derived(tables)
                    if re.search(rf"\b{words(column['name'])}\b", text, re.I)
                ]

                if stored:
                    text, columns = f"{text} {TEXTS['stored']}", stored

            self.add(
                item["kind"], tables, text, columns, item.get("from"), item.get("assumed"), [item["id"]],
            )

    def multiplicities(self):
        """
        Adds a rule for every multiplicity, that the diagram cannot show. The
        crow's foot shows "zero", "one" and "many", but not "two or more".
        """
        for name, table in self.model.tables.items():
            for item in table.get("foreign_keys", []):
                low, high = bounds(item["multiplicity"])

                if low <= 1 and (high == float("inf") or high <= 1):
                    continue

                numbers = {"parent": self.class_title(item["references"]), "child": f"{self.class_title(name)}s"}

                if high == float("inf"):
                    text = TEXTS["at_least"].format(number=low, **numbers)
                elif low == 0 or low == 1:
                    text = TEXTS["at_most"].format(number=high, **numbers)
                else:
                    text = TEXTS["between"].format(low=low, high=high, **numbers)

                association = self.source.associations.get(item.get("association"), {})
                self.add(
                    "rule", [name, item["references"]], text, None, association.get("from"),
                    REASONS["multiplicity"], None, f"{name} ({', '.join(item['columns'])})",
                )

    def derived(self):
        covered = {
            column for item in self.items if item["kind"] == "derivation" for column in item.get("columns", [])
        }

        for name, column in self.stored_derived(list(self.model.tables)):
            path = f"{name}.{column['name']}"

            if path not in covered:
                self.add("derivation", [name], TEXTS["derived"].format(
                    column=title(column["name"]), table=self.class_title(name),
                ), [path], assumed=REASONS["derived"])

    def uniques(self):
        for name, table in self.model.tables.items():
            for group in table.get("unique", []):
                association = next((
                    self.source.associations.get(item.get("association")) for item in table["foreign_keys"]
                    if set(item["columns"]) == set(group)
                ), None)
                columns = listed([title(column) for column in group])
                text = TEXTS["unique_one" if len(group) == 1 else "unique_many"].format(
                    columns=columns, table=self.class_title(name),
                )
                reason = REASONS["unique"].format(name=association["name"]) if association else None

                self.add(
                    "uniqueness", [name], text, [f"{name}.{column}" for column in group],
                    association.get("from") if association else None, reason or "UNIQUE set of the model",
                )

    def referential(self):
        cascades, other = {}, False

        for name, table in self.model.tables.items():
            for item in table.get("foreign_keys", []):
                action = item["on_delete"]
                association = self.source.associations.get(item.get("association"), {})
                sources = association.get("from", [])

                if action == "CASCADE":
                    entry = cascades.setdefault(name, {"parents": [], "from": []})
                    entry["parents"].append(item["references"])
                    entry["from"].extend(sources)
                elif action in ("SET NULL", "RESTRICT"):
                    text = TEXTS["set_null" if action == "SET NULL" else "restrict"].format(
                        parent=self.class_title(item["references"]), child=self.class_title(name),
                        columns=listed([title(column) for column in item["columns"]]),
                    )
                    self.add("referential", [name, item["references"]], text, None,
                             sources, REASONS["referential"])
                else:
                    other = True

        for name, entry in cascades.items():
            parents = list(dict.fromkeys(entry["parents"]))
            text = TEXTS["cascade"].format(
                parents=listed([self.class_title(parent) for parent in parents], "or a"),
                child=self.class_title(name),
            )
            self.add("referential", [name] + parents, text, None,
                     list(dict.fromkeys(entry["from"])), REASONS["referential"])

        # NO ACTION is the default of SQL, so it is not written as a constraint.
