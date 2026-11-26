PATHS = {
    "uml_model": "spec/conceptual/artifacts/uml_class_diagram.json",
    "artifacts": "spec/logical/artifacts",
    "documents": "spec/logical/documents",
    "skills": ".claude/skills",
    "scripts": "scripts",
}

NAMES = {
    "default": "relational_model_diagram",
    "generator": "modify-relational",
    "generators": ["modify-relational", "uml-to-relational"],
    "uml_skill": "modify-uml",
    "validator": "validate-relational",
    "constraints": "_constraints",
    "diagram": "_diagram",
}

SQL_TYPES = {
    "Integer": "INTEGER",
    "Decimal": "DECIMAL(10,2)",
    "Boolean": "BOOLEAN",
    "Date": "DATE",
    "Time": "TIME",
    "DateTime": "TIMESTAMP",
    "String": "VARCHAR({length})",
}

COMPATIBLE = {
    "Integer": r"SMALLINT|INTEGER|BIGINT",
    "Decimal": r"(DECIMAL|NUMERIC)\(\d+,\d+\)",
    "Boolean": r"BOOLEAN",
    "Date": r"DATE",
    "Time": r"TIME|INTERVAL",
    "DateTime": r"TIMESTAMP",
    "String": r"(VARCHAR|CHAR)\(\d+\)|TEXT",
    "enumeration": r"VARCHAR\(\d+\)",
}

LENGTHS = [
    (r"\b(postal|zip)\b", 10),
    (r"\b(phone)\b", 20),
    (r"\b(country|city)\b", 60),
    (r"\b(password|picture|url|path|link)\b", 255),
    (r"\b(description|content|comment|text)\b", 1000),
]
DEFAULT_LENGTH = 100
ENUMERATION_LENGTH = 20

ON_DELETE = ["NO ACTION", "CASCADE", "SET NULL", "RESTRICT"]

SURROGATE = {
    "always_from": 3,
    "referenced_from": 2,
    "type": "INTEGER",
    "suffix": "_id",
}

MARKERS = {"pk": "<PK>", "fk": "<FK>", "both": "<PK,FK>", "none": ""}

ER_ENDS = {
    "one": "ERmandOne",
    "zero_one": "ERzeroToOne",
    "many": "ERzeroToMany",
    "one_many": "ERoneToMany",
}

RESERVED = [
    "order", "user", "group", "table", "index", "key", "check", "default", "references",
    "column", "select", "from", "where", "limit", "value", "values", "desc", "position",
]

PATTERNS = {
    "snake": r"[a-z][a-z0-9]*(_[a-z0-9]+)*",
    "table": r"[A-Z][A-Za-z0-9]*(_[A-Z0-9][A-Za-z0-9]*)*",
    "sql_type": (
        r"SMALLINT|INTEGER|BIGINT|BOOLEAN|DATE|TIME|TIMESTAMP|INTERVAL|TEXT|"
        r"(VARCHAR|CHAR)\(\d+\)|(DECIMAL|NUMERIC)\(\d+,\d+\)"
    ),
    "length": r"\((\d+)\)",
    "multiplicity": r"\d+(\.\.(\d+|\*))?|\*",
    "column_line": r"(.+?) (NOT NULL|NULL)",
    "null_value": r"\b{words} value can be equal to [^.]*?\bnull\b",
    "empty": r"\b{words}\b[^.]*\bcan be (empty|null)\b",
    "not_stored": r"\bnot stored\b",
}

SIZES = {
    "char_width": 7.4,
    "header_height": 28,
    "row_height": 22,
    "end_gap": 14,

    # One line per foreign key (crow's foot convention), or one per column.
    "line_per_column": True,
    "row_step": 6,
    "row_steps": 5,
    "cell_padding": 16,
    "marker_width": 44,
    "gap_x": 130,
    "gap_y": 90,
    "margin": 150,
}

FONT_SIZES = {
    "table": 12,
}

STYLES = {
    "table": (
        "shape=table;startSize={header};container=1;collapsible=0;childLayout=tableLayout;"
        "fixedRows=1;rowLines=1;columnLines=1;fontStyle=0;align=center;resizeLast=1;html=1;"
        "whiteSpace=wrap;strokeColor=#000000;fillColor=#FFFFFF;fontColor=#000000;"
    ),
    "row": (
        "shape=tableRow;horizontal=0;startSize=0;swimlaneHead=0;swimlaneBody=0;fillColor=none;"
        "collapsible=0;dropTarget=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;"
        "top=0;left=0;right=0;bottom=0;html=1;"
    ),
    "cell": (
        "shape=partialRectangle;connectable=0;fillColor=none;top=0;left=0;bottom=0;right=0;"
        "overflow=hidden;whiteSpace=wrap;html=1;align=left;spacingLeft=4;fontColor=#000000;"
    ),
    "foreign_key": (
        "edgeStyle=none;html=1;rounded=0;startArrow={start};endArrow={end};startFill=0;"
        "endFill=0;startSize=10;endSize=10;strokeColor=#000000;jumpStyle=arc;jumpSize=8;"
    ),
}
