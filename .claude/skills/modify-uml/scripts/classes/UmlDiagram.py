import html
import xml.etree.ElementTree as ET

from const.general import FONT_SIZES, SIZES, STYLES


class UmlDiagram:
    """
    draw.io representation of the UML layout.

    Args:
        layout (UmlLayout): Positioned layout.
    """

    def __init__(self, layout):
        self.layout = layout

    def __call__(self):
        """
        Builds the graph. Lines are drawn first, so they stay under the boxes.

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

        self.ids = {key: f"b{index}" for index, key in enumerate(self.layout.boxes)}

        self.build_links()

        for box in self.layout.boxes.values():
            self.build_class(box)

        return self.model

    def build_links(self):
        for index, link in enumerate(self.layout.links):
            style = STYLES[link.kind] + self.constraints(link)
            attributes = {
                "id": f"l{index}",
                "style": style,
                "edge": "1",
                "parent": "1",
                "source": self.ids[link.source.key],
            }

            if not link.dangling:
                attributes["target"] = self.ids[link.target.key]

            edge = ET.SubElement(self.root, "mxCell", attributes)
            geometry = ET.SubElement(edge, "mxGeometry", {"relative": "1", "as": "geometry"})

            if link.dangling:
                ET.SubElement(geometry, "mxPoint", {
                    "x": f"{link.end[0]:.1f}", "y": f"{link.end[1]:.1f}", "as": "targetPoint",
                })

            bends = link.points[1:-1]

            if bends:
                array = ET.SubElement(geometry, "Array", {"as": "points"})

                for point in bends:
                    ET.SubElement(array, "mxPoint", {"x": f"{point[0]:.1f}", "y": f"{point[1]:.1f}"})

            for number, label in enumerate(link.labels):
                self.build_label(f"l{index}", number, label)

    def constraints(self, link):
        text = self.fraction("exit", link.start, link.source)

        if not link.dangling:
            text += self.fraction("entry", link.end, link.target)

        return text

    @staticmethod
    def fraction(prefix, point, box):
        left, top, right, bottom = box.box()

        return (
            f"{prefix}X={(point[0] - left) / (right - left):.4f};"
            f"{prefix}Y={(point[1] - top) / (bottom - top):.4f};"
            f"{prefix}Dx=0;{prefix}Dy=0;{prefix}Perimeter=0;"
        )

    def build_label(self, parent, number, label):
        cell = ET.SubElement(self.root, "mxCell", {
            "id": f"{parent}_{number}",
            "value": html.escape(label["text"]),
            "style": f"{STYLES['label']}fontSize={FONT_SIZES['label']};",
            "vertex": "1",
            "connectable": "0",
            "parent": parent,
        })
        geometry = ET.SubElement(cell, "mxGeometry", {
            "x": f"{label['fraction'] * 2 - 1:.3f}",
            "relative": "1",
            "as": "geometry",
        })
        ET.SubElement(geometry, "mxPoint", {
            "x": str(round(label["offset"][0])),
            "y": str(round(label["offset"][1])),
            "as": "offset",
        })

    def build_class(self, box):
        identifier = self.ids[box.key]
        title = html.escape(box.title)

        if box.kind != "class":
            title = f'<span style="font-weight:normal">«{box.kind}»</span><br>{title}'

        style = STYLES["class"].replace("startSize=26", f"startSize={box.header}")
        left, top, _, _ = box.box()

        self.add_cell(identifier, title, f"{style}fontSize={FONT_SIZES['class']};", "1", (
            left, top, box.width, box.height,
        ))

        lines_height = max(1, len(box.lines)) * SIZES["line_height"] + 8
        lines = []

        for index, line in enumerate(box.lines):
            text = html.escape(line)

            if box.underlined.get(index) == "key":
                text = f"<u>{text}</u>"
            elif box.underlined.get(index) == "partial":
                text = f'<span style="border-bottom:1px dashed #000000">{text}</span>'

            lines.append(text)

        fonts = f"fontSize={FONT_SIZES['class']};"

        self.add_cell(f"{identifier}_a", "<br>".join(lines), STYLES["attributes"] + fonts, identifier, (
            0, box.header, box.width, lines_height,
        ))
        self.add_cell(f"{identifier}_d", "", STYLES["divider"], identifier, (
            0, box.header + lines_height, box.width, 8,
        ))
        operations = "<br>".join(html.escape(line) for line in box.operations)

        self.add_cell(f"{identifier}_o", operations, STYLES["operations"] + fonts, identifier, (
            0, box.header + lines_height + 8, box.width, box.operations_height or SIZES["operations_height"],
        ))

    def add_cell(self, identifier, value, style, parent, geometry):
        cell = ET.SubElement(self.root, "mxCell", {
            "id": identifier,
            "value": value,
            "style": style,
            "vertex": "1",
            "parent": parent,
        })

        ET.SubElement(cell, "mxGeometry", {
            "x": str(round(geometry[0])),
            "y": str(round(geometry[1])),
            "width": str(round(geometry[2])),
            "height": str(round(geometry[3])),
            "as": "geometry",
        })
