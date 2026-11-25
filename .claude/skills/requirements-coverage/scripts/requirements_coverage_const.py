"""
Constants of the coverage of the functional and non-functional requirements.
"""

PATHS = {
    "coverage": "spec/conceptual/artifacts/requirements_coverage.json",
    "functional": "spec/requirements/documents/functional_requirements.pdf",
    "non_functional": "spec/requirements/documents/non_functional_requirements.pdf",
    "functional_text": "spec/requirements/artifacts/functional_requirements.md",
    "non_functional_text": "spec/requirements/artifacts/non_functional_requirements.md",
}

ID_PATTERN = r"\bN?FR\d+\b"

STATUSES = ["covered", "gap", "not_applicable"]

LEVELS = {"erd": "ERD", "uml": "UML", "relational": "relational model"}

SIGNIFICANCES = ["Must", "Should", "Could", "Won't"]

BLOCKING = ["Must"]

PREFIXES = {
    "relationship": "rel:",
    "constraint": "constraint:",
}
