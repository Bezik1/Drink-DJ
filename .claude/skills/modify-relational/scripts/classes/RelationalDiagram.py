import html
import xml.etree.ElementTree as ET

from const.general import FONT_SIZES, STYLES
from utils.rows import row_size, row_top
from utils.skills import uml_module

UmlDiagram = uml_module("classes.UmlDiagram").UmlDiagram


class RelationalDiagram:
    """
    draw.io representation of the layout of a relational model. A table is a
    draw.io table with 3 columns: the key marker, the name and the type.

    Args:
        layout (RelationalLayout): Positioned layout.
    """

    def __init__(self, layout):
        self.layout = layout

    def __call__(self):
        """
        Builds the graph. Lines are drawn first, so they stay under the tables.

        Returns:
            Element: mxGraphModel element.
        """
        self.model = ET.Element("mxGraphModel", {
            "grid": "0",
            "page": "1",
            "pageScale": "1",
            "pageWidth": str(self.layout.width),
            "pageHeight": str(self.layout.height),
        })
        self.root = ET.SubElement(self.model, "root")

        ET.SubElement(self.root, "mxCell", {"id": "0"})
        ET.SubElement(self.root, "mxCell", {"id": "1", "parent": "0"})

        self.ids = {key: f"t{index}" for index, key in enumerate(self.layout.boxes)}

        for index, link in enumerate(self.layout.links):
            self.build_link(f"l{index}", link)

        for box in self.layout.boxes.values():
            self.build_table(box)

        return self.model

    def build_link(self, identifier, link):
        style = (
            STYLES["foreign_key"].format(start=link.ends[0], end=link.ends[1])
            + UmlDiagram.fraction("exit", link.start, link.source)
            + UmlDiagram.fraction("entry", link.end, link.target)
        )
        edge = ET.SubElement(self.root, "mxCell", {
            "id": identifier,
            "style": style,
            "edge": "1",
            "parent": "1",
            "source": self.ids[link.source.key],
            "target": self.ids[link.target.key],
        })
        geometry = ET.SubElement(edge, "mxGeometry", {"relative": "1", "as": "geometry"})

        if len(link.points) > 2:
            array = ET.SubElement(geometry, "Array", {"as": "points"})

            for point in link.points[1:-1]:
                ET.SubElement(array, "mxPoint", {"x": f"{point[0]:.1f}", "y": f"{point[1]:.1f}"})

    def build_table(self, box):
        identifier = self.ids[box.key]
        left, top, _, _ = box.box()
        font = f"fontSize={FONT_SIZES['table']};"
        self.add_cell(
            identifier, html.escape(box.title), STYLES["table"].format(header=box.header) + font, "1",
            (left, top, box.width, box.height),
        )

        for index, row in enumerate(box.rows):
            row_id = f"{identifier}_r{index}"
            height = row_size(box, index)
            self.add_cell(row_id, "", STYLES["row"], identifier, (0, row_top(box, index), box.width, height))
            x = 0

            for number, (text, width) in enumerate(zip(row, box.widths)):
                self.add_cell(f"{row_id}_c{number}", html.escape(text), STYLES["cell"] + font, row_id, (
                    x, 0, width, height,
                ))
                x += width

    def add_cell(self, identifier, value, style, parent, geometry):
        cell = ET.SubElement(self.root, "mxCell", {
            "id": identifier, "value": value, "style": style, "vertex": "1", "parent": parent,
        })

        ET.SubElement(cell, "mxGeometry", {
            "x": str(round(geometry[0])),
            "y": str(round(geometry[1])),
            "width": str(round(geometry[2])),
            "height": str(round(geometry[3])),
            "as": "geometry",
        })
