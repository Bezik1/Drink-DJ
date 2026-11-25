"""
Position of a row of a table, whose rows can have different heights.
"""


def row_size(box, index):
    """
    Finds the height of one row of a table.

    Args:
        box (Box): Table with `row_heights`.
        index (int): Index of the row.

    Returns:
        float: Height of the row in px.
    """
    return box.row_heights[index]


def row_top(box, index):
    """
    Finds the top of one row, relative to the top of the table.

    Args:
        box (Box): Table with `row_heights` and `header`.
        index (int): Index of the row.

    Returns:
        float: Distance of the row from the top of the table in px.
    """
    return box.header + sum(box.row_heights[:index])


def row_middle(box, index):
    """
    Finds the middle of one row on the page.

    Args:
        box (Box): Table with `row_heights`.
        index (int): Index of the row.

    Returns:
        float: Height of the middle of the row on the page.
    """
    return box.box()[1] + row_top(box, index) + box.row_heights[index] / 2
