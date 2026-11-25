import re

from const.general import PATTERNS


def end_class(end):
    """
    Finds the class of an end of an association. An end is the key of a
    class, or `<class>:<role>` at an association of a class with itself, for
    example `drink_version:base`.

    Args:
        end (str): Key of the end in `ends`.

    Returns:
        str: Key of the class.
    """
    return end.split(":", 1)[0]


def end_role(end):
    return end.split(":", 1)[1] if ":" in end else None


def with_role(key, end):
    """
    Writes the key of a class with the role of an end, so a renamed class
    keeps the role of its end.

    Args:
        key (str): Key of the class.
        end (str): End, whose role is kept.

    Returns:
        str: `key` or `key:role`.
    """
    role = end_role(end)

    return f"{key}:{role}" if role else key


def snake_case(text):
    """
    Writes a name of the ERD as a name of a UML attribute or value.

    Args:
        text (str): Name, for example "Warehouse Code".

    Returns:
        str: Name in snake case, for example "warehouse_code".
    """
    words = re.findall(r"[A-Za-z0-9]+", text)

    return "_".join(word.lower() for word in words)


def title_case(text):
    """
    Writes a phrase with every word capitalized.

    Args:
        text (str): Phrase, for example "part type".

    Returns:
        str: Phrase, for example "Part Type".
    """
    return " ".join(word[:1].upper() + word[1:] for word in text.split())


def key_of(text):
    """
    Writes a name of an entity as the key of a class in the JSON model.

    Args:
        text (str): Name, for example "Stored Part".

    Returns:
        str: Key, for example "stored_part".
    """
    return snake_case(text)


def uml_multiplicity(cardinality):
    """
    Translates a cardinality of the ERD to a multiplicity of the UML.

    Args:
        cardinality (str): Cardinality like "1", "0..N" or "0..M".

    Returns:
        str: Multiplicity like "1", "0..*" or "1..*".
    """
    return re.sub(r"(?<![0-9A-Za-z])[A-Z]\b", "*", str(cardinality))


def is_multiplicity(text):
    return re.fullmatch(PATTERNS["multiplicity"], str(text)) is not None


def signature(relationship):
    """
    Identifies a relationship of the ERD, which has no id.

    Args:
        relationship (dict[]): Relationship of the ERD model.

    Returns:
        str: Name and sorted ends, for example "has:route_sequence/user".
    """
    return f"{relationship['name']}:{'/'.join(sorted(relationship['ends']))}"
