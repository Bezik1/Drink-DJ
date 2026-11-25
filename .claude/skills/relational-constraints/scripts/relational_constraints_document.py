"""
Word description of the constraints of a relational model.
"""
from relational_constraints_const import ALL_TABLES, HEADER, TEXTS, TITLE, WIDTHS


class RelationalConstraintsDocument:
    """
    The description of the Word file for the `modify-word` skill. The file has
    only one table of the constraints, without a title, as the constraints of
    the UML class diagram.

    Args:
        model (RelationalConstraintsModel): Validated constraints.
    """

    def __init__(self, model):
        self.model = model

    def __call__(self):
        """
        Builds the description.

        Returns:
            dict[]: Description with the title and the table.
        """
        rows = [
            [
                item["id"],
                ", ".join(TEXTS["all_tables"] if table == ALL_TABLES else table for table in item["tables"]),
                item["text"],
                ", ".join(item.get("from", [])) or "-",
            ]
            for item in self.model.items
        ]

        return {
            "title": TITLE,
            "show_title": False,
            "blocks": [{"type": "table", "header": HEADER, "rows": rows, "widths": WIDTHS}],
        }
