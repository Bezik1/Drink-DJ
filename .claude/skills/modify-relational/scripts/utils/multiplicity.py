import math

from utils.skills import uml_module

NAMING = uml_module("utils.naming")


def bounds(multiplicity):
    """
    Reads the lower and the upper bound of a UML multiplicity.

    Args:
        multiplicity (str): Multiplicity like "1", "0..1", "1..*" or "*".

    Returns:
        tuple[int, float]: Lower and upper bound. The upper bound of `*` is infinity.
    """
    parts = str(multiplicity).split("..")
    low, high = parts[0], parts[-1]

    return (
        int(low) if low.isdigit() else 0,
        int(high) if high.isdigit() else math.inf,
    )


def classify(association):
    """
    Decides, how an association of the UML becomes a part of the relational model.

    Rules:
    - Both upper bounds above 1: many to many, so a junction table. When one
      end has an exact multiplicity k (for example 2), the result also names
      it, because k foreign keys in the table of the other end are allowed too.
    - One upper bound is 1: a foreign key in the table of the other end
      (the child), that references the end with the upper bound 1 (the parent).
    - Both upper bounds are 1: the part of a composition is the child. Otherwise
      the child is the end, that must have the other one, then the optional
      end, then the second end of the association.
    - The foreign key is NULL, when the lower bound of the parent end is 0.
    - An association of a class with itself names the class twice, once
      with a role (`drink_version:base`). Its foreign key references its own
      table, and its columns start with the role. A many to many association
      of a class with itself is not supported.

    Args:
        association (dict[]): Association of the UML model.

    Returns:
        dict[]: `kind` ("foreign_key" or "junction"), and for a foreign key the
            `child`, the `parent`, `nullable`, `one_to_one` and the
            `multiplicity` of the child end, `recursive` and the `role` of a
            foreign key to its own table. A junction has its `ends`, and the
            `exact` end, the `other` end and the `count`, when one end is exact.
            `child`, `parent` and `ends` are keys of classes, without roles.
    """
    (first, one), (second, two) = list(association["ends"].items())
    low_one, high_one = bounds(one)
    low_two, high_two = bounds(two)

    recursive = NAMING.end_class(first) == NAMING.end_class(second)

    if high_one > 1 and high_two > 1:
        if recursive:
            raise RuntimeError(f"{association['name']}: a many to many association of a class with itself is not supported")

        result = {"kind": "junction", "ends": [first, second]}

        for end, other, low, high in ((first, second, low_one, high_one), (second, first, low_two, high_two)):
            if low == high:
                result.update({"exact": end, "other": other, "count": low})

        return result

    if high_one == 1 and high_two > 1:
        child, parent = second, first
    elif high_two == 1 and high_one > 1:
        child, parent = first, second
    elif association.get("kind") == "composition":
        parent = association["whole"]
        child = second if parent == first else first
    elif low_one != low_two:
        child, parent = (second, first) if low_one == 1 else (first, second)
    else:
        child, parent = second, first

    ends = association["ends"]
    role = NAMING.end_role(parent) or NAMING.end_role(child) if recursive else None

    return {
        "kind": "foreign_key",
        "child": NAMING.end_class(child),
        "parent": NAMING.end_class(parent),
        "nullable": bounds(ends[parent])[0] == 0,
        "one_to_one": bounds(ends[child])[1] == 1,
        "multiplicity": ends[child],
        "recursive": recursive,
        "role": role,
    }
