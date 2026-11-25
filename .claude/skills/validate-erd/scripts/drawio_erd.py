"""
Reader of an ERD stored in a draw.io file.
"""
import base64
import html
import re
import urllib.parse
import xml.etree.ElementTree as ET
import zlib

CARDINALITY = r"(\d+|[A-Z])(\.\.(\d+|[A-Z]))?"
ATTRIBUTE_STYLES = ("ellipse", "arcsize=50")


class DrawioErd:
    """
    Reads a draw.io file as an ERD in Chen notation. The shapes are classified
    by their style, so the file can come from the skill or be drawn by hand.

    Args:
        path (Path): Path of the .drawio file.
    """

    def __init__(self, path):
        self.path = path

    def __call__(self):
        """
        Reads entities, relationships, attributes and the lines between them.

        Returns:
            DrawioErd: Reader with the elements of the diagram.
        """
        self.cells = self.read_cells()
        self.entities, self.relationships, self.attributes = {}, {}, {}
        self.edges, self.labels = [], {}

        for cell in self.cells.values():
            if cell.get("edge") == "1":
                self.edges.append(cell)
            elif cell.get("vertex") == "1":
                self.read_vertex(cell)

        for cell in self.cells.values():
            parent = self.cells.get(cell.get("parent"))

            if cell.get("vertex") == "1" and parent is not None and parent.get("edge") == "1":
                self.labels[parent.get("id")] = self.text(cell)

        self.links = self.read_links()

        return self

    def read_cells(self):
        root = ET.parse(self.path).getroot()

        if root.tag == "mxfile":
            diagram = root.find("diagram")

            if diagram is None:
                raise RuntimeError("The file has no diagram")
            if diagram.find("mxGraphModel") is not None:
                root = diagram.find("mxGraphModel")
            else:
                root = ET.fromstring(self.inflate(diagram.text or ""))

        return {
            cell.get("id"): cell for cell in root.iter("mxCell")
        }

    def inflate(self, content):
        """
        Decodes a compressed diagram, as the draw.io app saves it.

        Args:
            content (str): Base64 text of the diagram.

        Returns:
            str: XML of the graph.
        """
        raw = zlib.decompress(base64.b64decode(content), -15)

        return urllib.parse.unquote(raw.decode("utf-8"))

    def read_vertex(self, cell):
        parent = self.cells.get(cell.get("parent"))

        if parent is not None and parent.get("edge") == "1":
            return

        style = cell.get("style", "").casefold()
        text = self.text(cell)
        geometry = cell.find("mxGeometry")

        if not text or style.startswith("text;") or geometry is None:
            return

        item = {
            "id": cell.get("id"),
            "name": text,
            "box": tuple(float(geometry.get(key, 0)) for key in ("x", "y", "width", "height")),
            "double": "double=1" in style,
            "dashed": "dashed=1" in style,
            "underlined": self.is_underlined(cell),
            "partial": "border-bottom" in cell.get("value", "") and "dashed" in cell.get("value", ""),
        }

        if "rhombus" in style:
            self.relationships[item["id"]] = item
        elif any(mark in style for mark in ATTRIBUTE_STYLES):
            self.attributes[item["id"]] = item
        else:
            self.entities[item["id"]] = item

    def is_underlined(self, cell):
        match = re.search(r"fontstyle=(\d+)", cell.get("style", "").casefold())
        value = cell.get("value", "").casefold()

        return bool(match and int(match.group(1)) & 4) or "<u>" in value

    def text(self, cell):
        value = re.sub(r"<br\s*/?>", " ", cell.get("value", ""), flags=re.I)

        return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", value))).strip()

    def read_links(self):
        """
        Returns:
            dict: Lines as pairs of ids, with the cardinality they carry.
        """
        links = []

        for edge in self.edges:
            label = self.labels.get(edge.get("id")) or self.text(edge)
            links.append({
                "id": edge.get("id"),
                "source": edge.get("source"),
                "target": edge.get("target"),
                "label": label,
                "arrows": any(
                    f"{side}Arrow=" in edge.get("style", "") and
                    f"{side}Arrow=none" not in edge.get("style", "")
                    for side in ("start", "end")
                ),
            })

        return links

    def kind(self, identifier):
        if identifier in self.entities:
            return "entity"
        if identifier in self.relationships:
            return "relationship"
        if identifier in self.attributes:
            return "attribute"

        return None

    def element(self, identifier):
        for group in (self.entities, self.relationships, self.attributes):
            if identifier in group:
                return group[identifier]

        return None

    def names(self):
        return [
            item["name"]
            for group in (self.entities, self.relationships, self.attributes)
            for item in group.values()
        ]
