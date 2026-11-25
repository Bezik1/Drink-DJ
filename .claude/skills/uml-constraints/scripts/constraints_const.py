"""
Constants of the constraints of a UML class diagram.
"""

PATHS = {
    "uml": "spec/conceptual/artifacts/uml_class_diagram.json",
    "artifacts": "spec/conceptual/artifacts",
    "documents": "spec/conceptual/documents",
}

SUFFIX = "_constraints"

TITLE = "UML class diagram: constraints"

MARKER = "chen notation cannot show"

KINDS = ["identity", "uniqueness", "domain", "derivation", "rule"]

HEADER = ["ID", "Applies to", "Constraint", "Requirements"]
WIDTHS = [1, 3, 12, 3]

ID_PATTERN = r"C\d{2,}"
