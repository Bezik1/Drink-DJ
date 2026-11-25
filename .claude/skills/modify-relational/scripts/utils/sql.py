import math
import re

from const.general import (
    COMPATIBLE, DEFAULT_LENGTH, ENUMERATION_LENGTH, ER_ENDS, LENGTHS, MARKERS, PATTERNS, SQL_TYPES
)
from utils.multiplicity import bounds


def string_length(name):
    """
    Guesses the length of a VARCHAR column from its name.

    Args:
        name (str): Name of the column, for example "postal_code".

    Returns:
        int: Length, for example 10.
    """
    text = name.replace("_", " ")

    for pattern, length in LENGTHS:
        if re.search(pattern, text):
            return length

    return DEFAULT_LENGTH


def enumeration_length(values):
    """
    Finds the length of a VARCHAR column, that stores an enumeration.

    Args:
        values (str[]): Values of the enumeration.

    Returns:
        int: At least `ENUMERATION_LENGTH`, rounded up to tens.
    """
    longest = max([len(value) for value in values] + [1])

    return max(ENUMERATION_LENGTH, int(math.ceil(longest / 10.0)) * 10)


def sql_type(uml_type, name):
    """
    Translates a primitive UML type to a SQL type.

    Args:
        uml_type (str): Type like "Integer" or "String".
        name (str): Name of the column, that decides the length of a VARCHAR.

    Returns:
        str: SQL type like "INTEGER" or "VARCHAR(100)".
    """
    return SQL_TYPES[uml_type].format(length=string_length(name))


def is_sql_type(text):
    return re.fullmatch(PATTERNS["sql_type"], str(text)) is not None


def is_compatible(sql, uml_type):
    """
    Checks, whether a SQL type can store a UML type.

    Args:
        sql (str): SQL type of the column.
        uml_type (str): Primitive UML type, or "enumeration".

    Returns:
        bool: True, if the SQL type fits.
    """
    return re.fullmatch(COMPATIBLE[uml_type], sql) is not None


def type_length(sql):
    match = re.search(PATTERNS["length"], sql)

    return int(match.group(1)) if match else None


def column_text(column, primary=False):
    """
    Writes the type and the nullability of a column, as the diagram shows them.
    A column of a primary key is never NULL, so its text is only the type.

    Args:
        column (dict[]): Column of the relational model.
        primary (bool, optional): The column is in the primary key. Default: False.

    Returns:
        str: Text like "INTEGER NOT NULL", or "INTEGER" for a primary key.
    """
    if primary:
        return column["type"]

    return f"{column['type']} {'NULL' if column['null'] else 'NOT NULL'}"


def marker(primary, foreign):
    if primary and foreign:
        return MARKERS["both"]
    if primary:
        return MARKERS["pk"]
    if foreign:
        return MARKERS["fk"]

    return MARKERS["none"]


def child_end(multiplicity):
    """
    Translates the multiplicity of the child end to crow's foot notation.

    Args:
        multiplicity (str): How many rows of the child reference one row of the parent.

    Returns:
        str: draw.io arrow, for example "ERzeroToMany".
    """
    low, high = bounds(multiplicity)

    if high == 1:
        return ER_ENDS["one"] if low >= 1 else ER_ENDS["zero_one"]

    return ER_ENDS["one_many"] if low >= 1 else ER_ENDS["many"]


def parent_end(nullable):
    return ER_ENDS["zero_one"] if nullable else ER_ENDS["one"]
