import math

from classes.Box import Box
from classes.Link import Link
from classes.UmlRouter import UmlRouter
from const.general import FONT_SIZES, LABELS, SIZES
from utils.naming import end_class
from utils.geometry import (
    polyline_hits_box, polyline_length, rectangles_overlap, segments_cross
)


def attribute_line(attribute):
    """
    Writes an attribute of a class as a line of the diagram.

    Args:
        attribute (dict[]): Attribute of the UML model.

    Returns:
        str: Line like "+ /total_weight : Decimal".
    """
    slash = "/" if attribute.get("kind") == "derived" else ""
    multiplicity = f" [{attribute['multiplicity']}]" if attribute.get("multiplicity") else ""

    return f"+ {slash}{attribute['name']} : {attribute['type']}{multiplicity}"


def operation_line(operation):
    """
    Writes an operation of a class as a line of the diagram.

    Args:
        operation (dict[]): Operation of the UML model, with optional
            `parameters` (name and type) and `returns` (a type).

    Returns:
        str: Line like "+ share()" or "+ find(stop : String) : Integer".
    """
    parameters = ", ".join(f"{item['name']} : {item['type']}" for item in operation.get("parameters", []))
    returns = f" : {operation['returns']}" if operation.get("returns") else ""

    return f"+ {operation['name']}({parameters}){returns}"


def label_width(text):
    return len(text) * SIZES["char_width"] * FONT_SIZES["label"] / 12 + 8


def label_box(center, text):
    width = label_width(text)

    return (center[0] - width / 2, center[1] - 8, center[0] + width / 2, center[1] + 8)


class UmlLayout:
    """
    Positions of the boxes and the lines of the UML diagram. Boxes stand in
    the grid of the `cell` values (the numbers can be fractions), and lines
    are routed by `UmlRouter`.

    Rules:
    - Column is as wide as its widest box, and row is as high as its highest box.
    - Enumerations are not in the grid. They always stand in the top right
      corner, inside the margin of the page, one under another.
    - A line never goes through a class, that it does not join.
    - A label stands next to its line and touches no class, line or label,
      when there is room. Otherwise it is reported as a warning.
    - The two multiplicities of a line stand on opposite sides of it.
    - Crossing lines are reported as warnings.

    Args:
        model (UmlModel): Validated model.
    """

    def __init__(self, model):
        self.model = model
        self.boxes = {}
        self.links = []
        self.warnings = []

    def __call__(self):
        """
        Builds the layout.

        Returns:
            UmlLayout: Layout with boxes, links, size and warnings.
        """
        self.build_boxes()
        self.place_boxes()
        self.build_links()
        self.place_labels()
        self.check()

        return self

    def build_boxes(self):
        for key, item in self.model.classes.items():
            stereotype = item.get("stereotype")

            if stereotype == "enumeration":
                lines = list(item.get("values", []))
            else:
                lines = [attribute_line(attribute) for attribute in item.get("attributes", [])]

            operations = [operation_line(operation) for operation in item.get("operations", [])]
            text_width = max(
                [len(line) for line in lines + operations] + [len(item["name"]) * 1.15],
            ) * SIZES["char_width"]
            header = SIZES["header_height"] + (16 if stereotype else 0)
            body = max(1, len(lines)) * SIZES["line_height"] + 8
            operations_height = len(operations) * SIZES["line_height"] + 8 if operations else SIZES["operations_height"]
            box = Box(
                key, stereotype or "class", item["name"], lines,
                (max(SIZES["min_width"], text_width + SIZES["padding"] * 2),
                 header + body + 8 + operations_height),
                header,
            )
            box.operations, box.operations_height = operations, operations_height

            for index, attribute in enumerate(item.get("attributes", [])):
                if attribute.get("kind") in ("key", "partial"):
                    box.underlined[index] = attribute["kind"]

            box.cell = None if stereotype == "enumeration" else item["cell"]
            self.boxes[key] = box

    def place_boxes(self):
        columns, rows = {}, {}
        grid = [box for box in self.boxes.values() if box.cell is not None]

        for box in grid:
            column, row = box.cell

            columns[column] = max(columns.get(column, 0), box.width)
            rows[row] = max(rows.get(row, 0), box.height)

        left = self.stack(columns, SIZES["gap_x"])
        top = self.stack(rows, SIZES["gap_y"])

        for box in grid:
            column, row = box.cell

            box.x = left[column] + columns[column] / 2
            box.y = top[row] + rows[row] / 2

        right = max(left[key] + columns[key] for key in left)
        bottom = max(top[key] + rows[key] for key in top)
        right, bottom = self.place_enumerations(right, bottom)
        self.width = round(right + SIZES["margin"])
        self.height = round(bottom + SIZES["margin"])
        self.gaps = {
            "x": self.channels(left, columns, SIZES["gap_x"]),
            "y": self.channels(top, rows, SIZES["gap_y"]),
        }

    def place_enumerations(self, right, bottom):
        """
        Puts the enumerations in the top right corner of the diagram.

        Rules:
        - They stand in their own column on the right of the grid, a gap away
          from it, so no line of the grid runs near them.
        - The first one touches the top margin, and the rest stand under it.
        - All are aligned to the right margin of the page.

        Args:
            right (float): Right edge of the grid.
            bottom (float): Bottom edge of the grid.

        Returns:
            tuple[float, float]: Right and bottom edge of the whole diagram.
        """
        enumerations = [box for box in self.boxes.values() if box.cell is None]

        if not enumerations:
            return right, bottom

        right += SIZES["gap_x"] + max(box.width for box in enumerations)
        top = SIZES["margin"]

        for box in enumerations:
            box.x = right - box.width / 2
            box.y = top + box.height / 2
            top += box.height + SIZES["gap_y"]

        return right, max(bottom, top - SIZES["gap_y"])

    @staticmethod
    def stack(sizes, gap):
        """
        Puts the columns or the rows of the grid one after another.

        Args:
            sizes (dict[]): Width or height of every column or row.
            gap (float): Gap between two of them.

        Returns:
            dict[]: Start of every column or row.
        """
        start, result = SIZES["margin"], {}

        for index in sorted(sizes):
            result[index] = start
            start += sizes[index] + gap

        return result

    @staticmethod
    def channels(starts, sizes, gap):
        """
        Finds the middle of every gap between two columns or rows, and one
        free channel outside of the first and the last one.

        Args:
            starts (dict[]): Start of every column or row.
            sizes (dict[]): Width or height of every column or row.
            gap (float): Gap between two of them.

        Returns:
            float[]: Positions of the channels.
        """
        keys = sorted(starts)
        found = [starts[keys[0]] - gap / 2]

        for key in keys:
            found.append(starts[key] + sizes[key] + gap / 2)

        return found

    def build_links(self):
        links = []

        for item in self.model.associations:
            first, second = list(item["ends"])
            kind = item.get("kind", "association")

            if kind == "composition" and item["whole"] == first:
                first, second = second, first

            link = Link(kind, self.boxes[end_class(first)], self.boxes[end_class(second)], item["name"],
                        (item["ends"][first], item["ends"][second]))
            link.item = item
            links.append(link)

        self.links = UmlRouter(self.boxes, links, self.gaps)().links

        for link in list(self.links):
            if link.item.get("class"):
                self.build_association_class(link)

    def build_association_class(self, association):
        """
        Joins an association class with the nearest stretch of its association
        by a dashed line at a right angle.

        Args:
            association (Link): The association.
        """
        box = self.boxes[association.item["class"]]
        best = None

        for first, second in zip(association.points, association.points[1:]):
            horizontal = abs(first[1] - second[1]) < 1
            low, high = sorted((first[0], second[0]) if horizontal else (first[1], second[1]))
            along = min(max(box.x if horizontal else box.y, low + 12), high - 12)
            point = (along, first[1]) if horizontal else (first[0], along)
            distance = math.dist(point, box.center)

            if best is None or distance < best[0]:
                best = (distance, point, horizontal)

        _, point, horizontal = best
        link = Link("attachment", box, association.target)
        link.dangling = True
        link.association = association

        if horizontal:
            side = "B" if box.y < point[1] else "T"
            x = min(max(point[0], box.box()[0] + 14), box.box()[2] - 14)
            start = (x, box.box()[3] if side == "B" else box.box()[1])
            link.points = [start, (x, point[1])] if abs(x - point[0]) < 1 else [start, (x, point[1]), point]
        else:
            side = "R" if box.x < point[0] else "L"
            y = min(max(point[1], box.box()[1] + 14), box.box()[3] - 14)
            start = (box.box()[2] if side == "R" else box.box()[0], y)
            link.points = [start, (point[0], y)] if abs(y - point[1]) < 1 else [start, (point[0], y), point]

        link.sides = (side, "")
        self.links.append(link)

    def place_labels(self):
        """
        Puts the multiplicities near the ends of an association and its name
        on its longest stretch, on the side, where there is room.
        """
        self.placed = []
        lines = [
            (first, second) for link in self.links
            for first, second in zip(link.points, link.points[1:])
        ]

        for link in self.links:
            if link.kind == "attachment":
                continue

            link.labels = self.place_ends(link, lines)

        for link in self.links:
            if link.kind != "attachment":
                link.labels.append(self.place(link, link.name, self.name_candidates(link), lines))

    def place_ends(self, link, lines):
        """
        Puts the two multiplicities of an association on opposite sides of
        its line.

        Rules:
        - Each multiplicity stands on the same hand, seen from its own end
          looking along the line, so the two stand on opposite sides: below
          at the left end and above at the right end, or the other way round.
        - Of the two choices, the one, that touches fewer shapes, wins.

        Args:
            link (Link): The association.
            lines (float[2][2][]): All segments of the diagram.

        Returns:
            dict[]: Labels of the source end and of the target end.
        """
        gap = LABELS["diamond"] if link.kind == "composition" else 0
        best = None

        for hand in (1, -1):
            centers = [self.end_center(link, 0, 0, hand), self.end_center(link, 1, gap, hand)]
            boxes = [label_box(center, text) for center, text in zip(centers, link.ends)]
            hits = sum(self.hits(box, lines) for box in boxes) + rectangles_overlap(*boxes)

            if best is None or hits < best[0]:
                best = (hits, centers)
            if not hits:
                break

        return [
            self.place(link, text, [center], lines)
            for text, center in zip(link.ends, best[1])
        ]

    @staticmethod
    def end_center(link, end, extra, hand):
        """
        Finds the center of a multiplicity next to one end of a line.

        Args:
            link (Link): The association.
            end (int): 0 for the source end, 1 for the target end.
            extra (float): Extra distance from the class, for example for a diamond.
            hand (int): 1 for the right hand and -1 for the left hand, seen
                from the end looking along the line.

        Returns:
            float[2]: Center of the label.
        """
        points = link.points if end == 0 else link.points[::-1]
        port, nxt = points[0], points[1]
        width = label_width(link.ends[end])
        direction = ((nxt[0] > port[0]) - (nxt[0] < port[0]), (nxt[1] > port[1]) - (nxt[1] < port[1]))
        base = LABELS["end"] + extra

        if direction[0]:
            return (port[0] + direction[0] * (base + width / 2), port[1] + hand * direction[0] * LABELS["side"])

        return (
            port[0] - hand * direction[1] * (width / 2 + LABELS["side"] / 2 + 2),
            port[1] + direction[1] * (base + 8),
        )

    def name_candidates(self, link):
        width = label_width(link.name)
        pairs = sorted(
            zip(link.points, link.points[1:]), key=lambda pair: -math.dist(*pair)
        )

        for first, second in pairs:
            middle = ((first[0] + second[0]) / 2, (first[1] + second[1]) / 2)
            horizontal = abs(first[1] - second[1]) < 1

            for sign in (-1, 1):
                if horizontal:
                    yield (middle[0], middle[1] + sign * LABELS["side"])
                else:
                    yield (middle[0] + sign * (width / 2 + LABELS["side"] / 2 + 2), middle[1])

    def place(self, link, text, candidates, lines):
        """
        Takes the first position of a label, that touches nothing.

        Args:
            link (Link): Line of the label.
            text (str): Text of the label.
            candidates (iterator): Centers to try, the best first.
            lines (float[2][2][]): All segments of the diagram.

        Returns:
            dict[]: Label with its text, fraction along the line and offset.
        """
        best = None

        for center in candidates:
            box = label_box(center, text)
            hits = self.hits(box, lines)

            if best is None or hits < best[0]:
                best = (hits, center, box)
            if not hits:
                break

        hits, center, box = best
        self.placed.append(box)

        if hits:
            self.warnings.append(f"Label '{text}' of {self.describe(link)} touches another shape")

        distance, point = self.project(link.points, center)

        return {
            "text": text,
            "fraction": distance / (polyline_length(link.points) or 1),
            "offset": (center[0] - point[0], center[1] - point[1]),
            "box": box,
        }

    def hits(self, box, lines):
        count = sum(rectangles_overlap(box, other) for other in self.placed)
        count += sum(
            rectangles_overlap(box, shape.box(3)) for shape in self.boxes.values()
        )

        for first, second in lines:
            thin = (
                min(first[0], second[0]) - 2, min(first[1], second[1]) - 2,
                max(first[0], second[0]) + 2, max(first[1], second[1]) + 2,
            )
            count += rectangles_overlap(box, thin)

        return count

    @staticmethod
    def project(points, center):
        """
        Finds the nearest point of a polyline.

        Args:
            points (float[2][]): Corners of the polyline.
            center (float[2]): The point.

        Returns:
            tuple[]: Distance along the polyline and the nearest point on it.
        """
        best, walked = None, 0

        for first, second in zip(points, points[1:]):
            length = math.dist(first, second) or 1
            fraction = max(0, min(1, (
                (center[0] - first[0]) * (second[0] - first[0]) +
                (center[1] - first[1]) * (second[1] - first[1])
            ) / length ** 2))
            point = (first[0] + (second[0] - first[0]) * fraction, first[1] + (second[1] - first[1]) * fraction)
            distance = math.dist(point, center)

            if best is None or distance < best[0]:
                best = (distance, walked + length * fraction, point)

            walked += length

        return best[1], best[2]

    def check(self):
        errors = []

        for link in self.links:
            for box in self.boxes.values():
                if link.dangling and box is link.source:
                    continue
                if box in (link.source, link.target) and not link.dangling:
                    continue
                if polyline_hits_box(link.points, box.box(-2)):
                    errors.append(
                        f"{self.describe(link)} goes through {box.title}. "
                        "Change the cells of the classes."
                    )

        for number, first in enumerate(self.links):
            for second in self.links[number + 1:]:
                if first.dangling or second.dangling:
                    continue
                if any(
                    segments_cross(a, b, c, d)
                    for a, b in zip(first.points, first.points[1:])
                    for c, d in zip(second.points, second.points[1:])
                ):
                    self.warnings.append(f"{self.describe(first)} crosses {self.describe(second)}")

        if errors:
            raise RuntimeError("Unreadable diagram:\n- " + "\n- ".join(errors))

    @staticmethod
    def describe(link):
        name = link.name or "attachment"

        return f"'{name}' ({link.source.title} - {link.target.title})"
