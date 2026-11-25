"""
Reader of a UML class diagram stored in a draw.io file.
"""
import html
import re
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]

sys.path.insert(0, str(SKILLS / "validate-erd" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-uml" / "scripts"))

from const.general import PATTERNS
from drawio_erd import DrawioErd


class DrawioUml(DrawioErd):
    """
    Reads a draw.io file as a UML class diagram. The shapes are classified
    by their style, so the file can come from the skill or be drawn by hand.

    Args:
        path (Path): Path of the .drawio file.
    """

    def __call__(self):
        """
        Reads classes, notes and associations.

        Returns:
            DrawioUml: Reader with the elements of the diagram.
        """
        self.cells = self.read_cells()
        self.classes, self.notes, self.associations, self.errors = {}, {}, [], []

        for cell in self.cells.values():
            style = cell.get("style", "").casefold()

            if cell.get("vertex") == "1" and cell.get("parent") == "1":
                if "shape=note" in style:
                    self.notes[cell.get("id")] = self.read_note(cell)
                elif style.startswith("swimlane"):
                    self.classes[cell.get("id")] = self.read_class(cell)
            elif cell.get("edge") == "1":
                self.associations.append(self.read_edge(cell))

        return self

    def lines(self, cell):
        value = re.sub(r"<br\s*/?>", "\n", cell.get("value", ""), flags=re.I)

        return [
            re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", line))).strip()
            for line in value.split("\n")
        ]

    def box(self, cell):
        geometry = cell.find("mxGeometry")

        return tuple(float(geometry.get(key, 0)) for key in ("x", "y", "width", "height"))

    def read_note(self, cell):
        return {"id": cell.get("id"), "text": " ".join(self.lines(cell)), "box": self.box(cell)}

    def read_class(self, cell):
        """
        Reads the header and the attribute lines of a class.

        Args:
            cell (Element): Swimlane cell of the class.

        Returns:
            dict[]: Class with name, stereotype, attributes, values and box.
        """
        header = [line for line in self.lines(cell) if line]
        stereotype = None

        if header and header[0].startswith("«"):
            stereotype = header.pop(0).strip("«»")

        item = {
            "id": cell.get("id"),
            "name": " ".join(header),
            "stereotype": stereotype,
            "attributes": [],
            "operations": [],
            "values": [],
            "box": self.box(cell),
        }

        children = [
            child for child in self.cells.values()
            if child.get("parent") == cell.get("id") and child.get("value")
        ]

        for child in children:
            raw = re.sub(r"<br\s*/?>", "\n", child.get("value", ""), flags=re.I).split("\n")

            for fragment, text in zip(raw, self.lines(child)[:len(raw)] if len(raw) == len(self.lines(child)) else self.lines(child)):
                if text:
                    self.read_line(item, fragment, text)

        return item

    def read_line(self, item, fragment, text):
        if item["stereotype"] == "enumeration":
            item["values"].append(text)
            return

        operation = re.fullmatch(PATTERNS["operation"], text)

        if operation:
            item["operations"].append({
                "name": operation.group(2),
                "parameters": [
                    {"name": name.strip(), "type": kind.strip()}
                    for name, _, kind in (part.partition(":") for part in operation.group(3).split(",") if part.strip())
                ],
                "returns": operation.group(5),
            })
            return

        match = re.fullmatch(PATTERNS["attribute"], text)

        if not match:
            self.errors.append(
                f"{item['name']}: '{text}' is not an attribute like '+ name : Type'"
            )
            return

        item["attributes"].append({
            "name": match.group(3),
            "type": match.group(4),
            "derived": match.group(2) == "/",
            "multiplicity": match.group(6),
            "key": "<u>" in fragment.casefold(),
            "partial": "border-bottom" in fragment and "dashed" in fragment,
        })

    def read_edge(self, cell):
        """
        Reads an association, a composition or an attachment of a note.

        Args:
            cell (Element): Edge cell.

        Returns:
            dict[]: Line with its ends, name, kind and multiplicities.
        """
        style = cell.get("style", "").casefold()
        labels = []

        for child in self.cells.values():
            if child.get("parent") == cell.get("id") and child.get("vertex") == "1":
                geometry = child.find("mxGeometry")
                position = float(geometry.get("x", 0)) if geometry is not None else 0
                labels.append((position, " ".join(self.lines(child))))

        item = {
            "id": cell.get("id"),
            "cell": cell,
            "source": cell.get("source"),
            "target": cell.get("target"),
            "dashed": "dashed=1" in style,
            "kind": "composition" if "enddiamond" in style or "diamondthin" in style else "association",
            "arrows": bool(re.search(r"(start|end)arrow=(?!none|diamond)", style)),
            "name": None,
            "source_multiplicity": None,
            "target_multiplicity": None,
        }

        for position, text in sorted(labels):
            if re.fullmatch(PATTERNS["multiplicity"], text) and position != 0:
                key = "source_multiplicity" if position < 0 else "target_multiplicity"
                item[key] = text
            elif text:
                item["name"] = text

        return item

    def route(self, line):
        """
        Builds the polyline of an association from its ports and bends.

        Args:
            line (dict[]): Line read by `read_edge`.

        Returns:
            float[2][]: Points from the source to the target, or an empty list,
                when an end is not on a class.
        """
        cell = line["cell"]
        geometry = cell.find("mxGeometry")
        style = cell.get("style", "")
        points = []

        start = self.port(line["source"], style, "exit")
        end = self.port(line["target"], style, "entry")

        if end is None and geometry is not None:
            target = geometry.find("mxPoint[@as='targetPoint']")

            if target is not None:
                end = (float(target.get("x")), float(target.get("y")))

        if start is None or end is None:
            return points

        bends = geometry.findall("Array/mxPoint") if geometry is not None else []

        return [start, *((float(item.get("x")), float(item.get("y"))) for item in bends), end]

    def port(self, identifier, style, prefix):
        item = self.classes.get(identifier)
        x = re.search(rf"{prefix}X=([-0-9.]+)", style)
        y = re.search(rf"{prefix}Y=([-0-9.]+)", style)

        if item is None or not x or not y:
            return None

        left, top, width, height = item["box"]

        return left + float(x.group(1)) * width, top + float(y.group(1)) * height
