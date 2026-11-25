import re

from const.general import NAMES
from utils.skills import uml_module

UML_NAMING = uml_module("utils.naming")
snake_case = UML_NAMING.snake_case


def table_name(text):
    """
    Writes a name of the UML as a name of a table: every word starts with a
    capital letter, and the words are separated by `_`.

    Args:
        text (str): Name, for example "Order Item" or "consists of".

    Returns:
        str: Name of the table, for example "Order_Item" or "Consists_Of".
    """
    return "_".join(word[:1].upper() + word[1:] for word in re.findall(r"[A-Za-z0-9]+", text))


def association_id(association):
    """
    Identifies an association of the UML model, which has no id.

    Args:
        association (dict[]): Association of the UML model.

    Returns:
        str: Name and sorted class keys, for example "is located in:shelf/warehouse".
    """
    return f"{association['name']}:{'/'.join(sorted(association['ends']))}"


def title(name):
    """
    Writes a name of a table or a column as words for a sentence.

    Args:
        name (str): Name in snake case, for example "shelf_hazard_type".

    Returns:
        str: Name, for example "Shelf Hazard Type".
    """
    return " ".join(word[:1].upper() + word[1:] for word in name.split("_"))


def words(name):
    """
    Writes a name in snake case as a regular expression of its words.

    Args:
        name (str): Name, for example "total_part_weight".

    Returns:
        str: Pattern, for example "total part weight".
    """
    return r"\s+".join(re.escape(word) for word in name.split("_"))


def constraints_stem(stem):
    """
    Finds the name of the constraints file of a relational model.

    Args:
        stem (str): Name of the model, for example "relational_model_diagram".

    Returns:
        str: Name of the constraints, for example "relational_model_constraints".
    """
    if stem.endswith(NAMES["diagram"]):
        stem = stem[:-len(NAMES["diagram"])]

    return f"{stem}{NAMES['constraints']}"
