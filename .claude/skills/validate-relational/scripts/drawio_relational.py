"""
Reader of a relational model diagram stored in a draw.io file.
"""
import re
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]

sys.path.insert(0, str(SKILLS / "validate-erd" / "scripts"))

from drawio_erd import DrawioErd

COLUMN_LINE = r"(.+?) (NOT NULL|NULL)"


class DrawioRelational(DrawioErd):
    """
    Reads a draw.io file as a relational model diagram. A table is a draw.io
    table (`shape=table`), whose rows have 3 cells: the key marker, the name
    and the type with NULL or NOT NULL. A line is an edge between two tables.

    Args:
        path (Path): Path of the .drawio file.
    """

    def __call__(self):
        """
        Reads the tables and the lines.

        Returns:
            DrawioRelational: Reader with the elements of the diagram.
        """
        self.cells = self.read_cells()
        self.tables, self.lines, self.errors = {}, [], []
        self.children = {}

        for cell in self.cells.values():
            self.children.setdefault(cell.get("parent"), []).append(cell)

        for cell in self.cells.values():
            style = cell.get("style", "").casefold()

            if cell.get("vertex") == "1" and cell.get("parent") == "1" and "shape=table;" in f"{style};":
                self.tables[cell.get("id")] = self.read_table(cell)

        for cell in self.cells.values():
            if cell.get("edge") == "1":
                self.lines.append(self.read_line(cell))

        return self

    def box(self, cell):
        """
        Reads the box of a cell in absolute coordinates.

        Args:
            cell (Element): Cell, whose parent is the layer.

        Returns:
            tuple[float, float, float, float]: Left, top, right and bottom.
        """
        geometry = cell.find("mxGeometry")
        x, y, width, height = (float(geometry.get(key, 0)) for key in ("x", "y", "width", "height"))

        return x, y, x + width, y + height

    def ordered(self, parent, key):
        cells = [cell for cell in self.children.get(parent, []) if cell.find("mxGeometry") is not None]

        return sorted(cells, key=lambda cell: float(cell.find("mxGeometry").get(key, 0)))

    def read_table(self, cell):
        """
        Reads the name and the columns of a table.

        Args:
            cell (Element): Table cell.

        Returns:
            dict[]: Table with id, name, box and columns. Every column has
                `rows`, the top and the bottom of its row on the page.
        """
        item = {"id": cell.get("id"), "name": self.text(cell), "box": self.box(cell), "columns": []}
        top = item["box"][1]

        for row in self.ordered(cell.get("id"), "y"):
            geometry = row.find("mxGeometry")
            y, height = float(geometry.get("y", 0)), float(geometry.get("height", 0))
            texts = [self.text(part) for part in self.ordered(row.get("id"), "x")]

            if len(texts) != 3:
                self.errors.append(f"{item['name']}: a row has {len(texts)} cells instead of marker, name and type")
                continue

            match = re.fullmatch(COLUMN_LINE, texts[2])
            item["columns"].append({
                "marker": texts[0],
                "name": texts[1],
                "type": match.group(1) if match else texts[2],
                "null": (match.group(2) == "NULL") if match else None,
                "rows": (top + y, top + y + height),
            })

        return item

    def table_of(self, identifier):
        while identifier and identifier not in self.tables:
            cell = self.cells.get(identifier)
            identifier = cell.get("parent") if cell is not None else None

        return identifier

    def read_line(self, cell):
        """
        Reads a line with its ends, crow's foot arrows, points and labels.

        Args:
            cell (Element): Edge cell.

        Returns:
            dict[]: Line.
        """
        style = cell.get("style", "")
        source, target = self.table_of(cell.get("source")), self.table_of(cell.get("target"))
        array = cell.find("mxGeometry/Array")
        middle = [
            (float(point.get("x", 0)), float(point.get("y", 0)))
            for point in (array.findall("mxPoint") if array is not None else [])
        ]
        start = self.port(style, "exit", source)
        end = self.port(style, "entry", target)

        return {
            "id": cell.get("id"),
            "source": source,
            "target": target,
            "start": self.arrow(style, "start"),
            "end": self.arrow(style, "end"),
            "points": [start, *middle, end] if start and end else None,
            "labels": [self.text(child) for child in self.children.get(cell.get("id"), []) if self.text(child)],
        }

    @staticmethod
    def arrow(style, side):
        match = re.search(rf"{side}Arrow=([A-Za-z]+)", style)

        return match.group(1) if match else None

    def port(self, style, prefix, table):
        found = {key: re.search(rf"{prefix}{key}=([-0-9.]+)", style) for key in ("X", "Y")}

        if table is None or not all(found.values()):
            return None

        left, top, right, bottom = self.tables[table]["box"]

        return (
            left + float(found["X"].group(1)) * (right - left),
            top + float(found["Y"].group(1)) * (bottom - top),
        )
