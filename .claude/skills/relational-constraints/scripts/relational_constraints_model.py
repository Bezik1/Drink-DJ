"""
Model of the constraints of a relational model, with its check.
"""
import json
import re

from relational_constraints_const import ALL_TABLES, FIRST_NUMBER, ID_PATTERN, ID_PREFIX, KINDS, MARKER
from utils.multiplicity import bounds


def output_paths(path):
    """
    Finds the Word file and the PDF of a constraints file.

    Rules:
    - The Word file stands next to the JSON file.
    - The PDF goes to the `documents` folder next to `artifacts`, when the
      JSON file is in `artifacts`, and next to the JSON file otherwise.

    Args:
        path (Path): Path of the JSON file of the constraints.

    Returns:
        Path[2]: Paths of the Word file and of the PDF.
    """
    folder = path.parent.parent / "documents" if path.parent.name == "artifacts" else path.parent

    return path.with_suffix(".docx"), folder / f"{path.stem}.pdf"


class RelationalConstraintsModel:
    """
    The JSON file with the constraints of a relational model and its check
    against the relational model, the UML constraints and the requirements matrix.

    Rules:
    - The file belongs to the current UML constraints (checksum).
    - The ids are `C01`, `C02`, ... from one, without gaps. Every constraint has a known kind, a text, tables of the
      model (or "*" for all), columns as "table.column", and the requirements
      it comes from, or the reason in `assumed`.
    - Every UML constraint is carried over (`uml`) or explained in `covered`.
    - Every multiplicity of a foreign key, that the crow's foot of the diagram
      cannot show (a lower bound above 1, or a finite upper bound above 1), has
      a constraint with its `foreign_key`, as "Table (column, column)".
    - Every column of an enumeration has a `domain` constraint, every stored
      derived column a `derivation`, every UNIQUE set a `uniqueness`, and
      every ON DELETE action a `referential` constraint.

    Args:
        path (Path): Path of the JSON file.
        source (UmlSource): Validated UML with its constraints.
        model (RelationalModel): Validated relational model.
    """

    def __init__(self, path, source, model):
        self.path = path
        self.source = source
        self.model = model
        self.errors = []

        self.data = json.loads(path.read_text(encoding="utf-8"))
        self.items = self.data.get("constraints", [])
        self.covered = self.data.get("covered", {})

    def __call__(self):
        """
        Validates the file.

        Returns:
            RelationalConstraintsModel: Validated model.
        """
        self.check_sources()
        self.check_items()
        self.check_uml()
        self.check_columns()
        self.check_multiplicities()
        self.check_referential()

        if self.errors:
            raise RuntimeError("Invalid relational constraints:\n- " + "\n- ".join(self.errors))

        return self

    def check_sources(self):
        if self.data.get("uml_constraints", {}).get("sha256") != self.source.constraints_sha256:
            self.errors.append(
                "uml_constraints.sha256 does not match the UML constraints. Write the constraints again."
            )

    def check_items(self):
        identifiers = set()
        known = {item["id"] for item in self.source.constraints}
        first = FIRST_NUMBER
        expected = [f"{ID_PREFIX}{number:02d}" for number in range(first, first + len(self.items))]

        if [item.get("id") for item in self.items] != expected:
            self.errors.append(
                f"The ids must be {expected[0] if expected else ''} ... {expected[-1] if expected else ''} in order, "
                "after the last id of the UML constraints"
            )

        for item in self.items:
            name = item.get("id", "?")

            if not re.fullmatch(ID_PATTERN, name) or name in identifiers:
                self.errors.append(f"{name}: the id must be unique in this document, like C01")

            identifiers.add(name)

            if item.get("kind") not in KINDS:
                self.errors.append(f"{name}: kind must be one of {KINDS}")
            if not item.get("text"):
                self.errors.append(f"{name}: the text is empty")
            if not item.get("tables"):
                self.errors.append(f"{name}: give the tables, that it applies to")

            for table in item.get("tables", []):
                if table != ALL_TABLES and table not in self.model.tables:
                    self.errors.append(f"{name}: {table} is not a table of the relational model")
            for column in item.get("columns", []):
                table, _, field = column.partition(".")

                if table not in self.model.tables or self.model.column(table, field) is None:
                    self.errors.append(f"{name}: {column} is not a column of the relational model")
            for requirement in item.get("from", []):
                if requirement not in self.source.matrix.ids:
                    self.errors.append(f"{name}: {requirement} is not in the matrix")
            for constraint in item.get("uml", []):
                if constraint not in known:
                    self.errors.append(f"{name}: {constraint} is not a UML constraint")
            if not item.get("from") and not item.get("assumed"):
                self.errors.append(f"{name}: give 'from' or the reason in 'assumed'")

    def check_uml(self):
        carried = {constraint for item in self.items for constraint in item.get("uml", [])}

        for item in self.source.constraints:
            if item["id"] not in carried and not self.covered.get(item["id"]):
                self.errors.append(
                    f"UML constraint {item['id']} is not carried over. Add a constraint with "
                    f"'uml': ['{item['id']}'], or explain in 'covered', how the model shows it."
                )

        for key in self.covered:
            if key not in {item["id"] for item in self.source.constraints}:
                self.errors.append(f"covered: {key} is not a UML constraint")

    def columns_of(self, kind):
        return {column for item in self.items if item.get("kind") == kind for column in item.get("columns", [])}

    def check_columns(self):
        domains, derivations = self.columns_of("domain"), self.columns_of("derivation")
        uniques = [set(item.get("columns", [])) for item in self.items if item.get("kind") == "uniqueness"]

        for name, table in self.model.tables.items():
            for column in table["columns"]:
                attribute = self.source.attribute(column.get("uml", ""))
                path = f"{name}.{column['name']}"

                if attribute is None:
                    continue
                if self.source.enumeration(attribute["type"]) and path not in domains:
                    self.errors.append(f"{path}: give the values of {attribute['type']} in a domain constraint")
                if attribute.get("kind") == "derived" and path not in derivations:
                    self.errors.append(f"{path}: a stored derived column needs a derivation constraint")

            for group in table.get("unique", []):
                if {f"{name}.{column}" for column in group} not in uniques:
                    self.errors.append(f"{name} UNIQUE ({', '.join(group)}): give it a uniqueness constraint")

    def check_multiplicities(self):
        given = {item.get("foreign_key") for item in self.items}

        for name, table in self.model.tables.items():
            for item in table.get("foreign_keys", []):
                low, high = bounds(item["multiplicity"])
                label = f"{name} ({', '.join(item['columns'])})"

                if (low > 1 or 1 < high < float("inf")) and label not in given:
                    self.errors.append(
                        f"{label}: the multiplicity {item['multiplicity']} cannot be shown by the diagram. "
                        f"Give a rule with \"foreign_key\": \"{label}\""
                    )

    def check_referential(self):
        """
        Rule: every foreign key with ON DELETE CASCADE, SET NULL or RESTRICT is
        named by a referential constraint. NO ACTION is the default of SQL, so
        the document does not need to say it.
        """
        referential = [item for item in self.items if item.get("kind") == "referential"]

        for name, table in self.model.tables.items():
            for item in table.get("foreign_keys", []):
                if item["on_delete"] != "NO ACTION" and not any(name in found.get("tables", []) for found in referential):
                    self.errors.append(
                        f"{name} FK ({', '.join(item['columns'])}): ON DELETE {item['on_delete']} "
                        "needs a referential constraint"
                    )

    def save(self):
        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
