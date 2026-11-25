"""
Constants of the constraints of a relational model.
"""

TITLE = "Relational model: constraints"

KINDS = ["domain", "uniqueness", "rule", "derivation", "referential"]

HEADER = ["ID", "Applies to", "Constraint", "Requirements"]
WIDTHS = [1, 4, 11, 3]

ID_PREFIX = "C"
FIRST_NUMBER = 1
ID_PATTERN = r"C(\d{2,})"

ALL_TABLES = "*"

TEXTS = {
    "all_tables": "All tables",
    "domain": "{names} can be equal only to {values}.",
    "stored": "It is set by the database and cannot be changed directly.",
    "derived": "{column} of {table} is set by the database and cannot be changed directly.",
    "unique_one": "{columns} of {table} is unique.",
    "unique_many": "The combination of {columns} of {table} is unique.",
    "cascade": "Deleting a {parents} deletes every row of {child}, that references it.",
    "set_null": "Deleting a {parent} sets {columns} of {child} to NULL.",
    "restrict": "A {parent} cannot be deleted, while a row of {child} references it.",
    "no_action_other": "All other foreign keys use ON DELETE NO ACTION.",
    "no_action_all": "All foreign keys use ON DELETE NO ACTION.",
    "covered": "The primary key of {tables} shows it.",
    "at_least": "Every {parent} has at least {number} {child}.",
    "at_most": "Every {parent} has at most {number} {child}.",
    "between": "Every {parent} has from {low} to {high} {child}.",
}

REASONS = {
    "enumeration": "Values of the enumeration {name} of the UML",
    "derived": "The UML does not say, how it is calculated. Write the formula.",
    "unique": "The UML association '{name}' is one to one",
    "referential": "Referential action chosen in the transformation from the UML",
    "multiplicity": "The multiplicity of the UML, that the diagram of the relational model cannot show",
}

MARKER = "NO ACTION"
