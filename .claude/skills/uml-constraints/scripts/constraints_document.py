"""
Word description of the constraints of a UML class diagram.
"""
from constraints_const import HEADER, TITLE, WIDTHS


class ConstraintsDocument:
    """
    The description of the Word file for the `modify-word` skill. The file has
    only one table of the constraints, that UML cannot show, without a title.

    Args:
        model (ConstraintsModel): Validated constraints.
        uml (UmlModel): Validated model of the UML.
    """

    def __init__(self, model, uml):
        self.model = model
        self.uml = uml

    def __call__(self):
        """
        Builds the description.

        Returns:
            dict[]: Description with the title and the table.
        """
        rows = [
            [
                item["id"],
                ", ".join(self.uml.classes[key]["name"] for key in item["classes"]),
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
