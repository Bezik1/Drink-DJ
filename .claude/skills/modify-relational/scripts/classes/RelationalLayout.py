from classes.RelationalRouter import RelationalRouter
from const.general import FONT_SIZES, SIZES
from utils.skills import uml_module
from utils.sql import child_end, column_text, parent_end

Box = uml_module("classes.Box").Box
Link = uml_module("classes.Link").Link
UmlLayout = uml_module("classes.UmlLayout").UmlLayout
GEOMETRY = uml_module("utils.geometry")


class RelationalLayout:
    """
    Positions of the tables and the lines of the relational model diagram.
    Tables stand in the grid of the `cell` values, as the classes of the UML,
    and the lines are routed by the router of the `modify-uml` skill.

    Rules:
    - A table has a header with its name and a row for every column: the key
      marker, the name and the type with NULL or NOT NULL.
    - A column of the grid is as wide as its widest table, and a row as high
      as its highest table.
    - A line goes from the table with the foreign key to the referenced table,
      with right angles only, and never through another table. It joins a
      key with a key: it leaves the row of a foreign key column and enters the
      row of the referenced column, on the left or the right side.
    - Every column of a foreign key has its own line to the referenced column
      of the primary key, so every key is joined. Two foreign keys, that
      join the same two columns, share one line.
    - A table, whose rows have more ends of lines, than they hold, gets
      taller rows, step by step, and only that table.
    - The end at the referenced table is "one" or "zero or one" (a NULL
      foreign key). The end at the table with the foreign key shows its multiplicity.
    - A line has no label. The <FK> markers of the columns show the foreign keys.
    - No two ends of lines on one side of a table are closer than `end_gap`,
      and no two lines run on each other, so no mark or stretch hides another.
    - Crossing lines are reported as warnings.

    Args:
        model (RelationalModel): Validated model.
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
            RelationalLayout: Layout with boxes, links, size and warnings.
        """
        self.row_heights = self.minimum_heights()
        self.build_boxes()
        self.place_boxes()
        self.build_links()
        self.check()

        return self

    def minimum_heights(self):
        """
        Gives every table a row height, that holds one line for each connection
        of its busiest row, so no two lines of one row share a line of text.

        Rules:
        - Every connection (a line end) takes `end_gap` px of the row.
        - A row never gets less than the normal row height.

        Returns:
            dict[]: Row height of every table, by name.
        """
        counts = {name: {} for name in self.model.tables}

        for name, table in self.model.tables.items():
            for item in table.get("foreign_keys", []):
                pairs = list(zip(item["columns"], item["to"]))

                if not SIZES["line_per_column"]:
                    pairs = pairs[:1]

                for column, referenced in pairs:
                    own = [c["name"] for c in table["columns"]].index(column)
                    target = [c["name"] for c in self.model.tables[item["references"]]["columns"]].index(referenced)
                    counts[name][own] = counts[name].get(own, 0) + 1
                    counts[item["references"]][target] = counts[item["references"]].get(target, 0) + 1

        return {
            name: [
                max(SIZES["row_height"], SIZES["end_gap"] * counts[name].get(index, 0) + 8)
                for index in range(len(self.model.tables[name]["columns"]))
            ]
            for name in self.model.tables
        }

    def build_boxes(self):
        width = SIZES["char_width"] * FONT_SIZES["table"] / 12
        padding = SIZES["cell_padding"]

        for name, table in self.model.tables.items():
            rows = [
                (self.model.marker(name, column["name"]), column["name"],
                 column_text(column, "PK" in self.model.marker(name, column["name"])))
                for column in table["columns"]
            ]
            widths = [
                max(SIZES["marker_width"], max(len(row[0]) for row in rows) * width + padding),
                max(len(row[1]) for row in rows) * width + padding,
                max(len(row[2]) for row in rows) * width + padding,
            ]
            total = max(sum(widths), len(name) * width * 1.1 + 2 * padding)
            widths[2] = total - widths[0] - widths[1]
            heights = self.row_heights[name]
            box = Box(
                name, "table", name, [row[1] for row in rows],
                (total, SIZES["header_height"] + sum(heights)),
                SIZES["header_height"],
            )
            box.rows, box.widths, box.cell, box.row_heights = rows, widths, table["cell"], heights
            self.boxes[name] = box

    def place_boxes(self):
        columns, rows = {}, {}

        for box in self.boxes.values():
            column, row = box.cell
            columns[column] = max(columns.get(column, 0), box.width)
            rows[row] = max(rows.get(row, 0), box.height)

        left = UmlLayout.stack(columns, SIZES["gap_x"])
        top = UmlLayout.stack(rows, SIZES["gap_y"])

        for box in self.boxes.values():
            column, row = box.cell
            box.x = left[column] + columns[column] / 2
            box.y = top[row] + rows[row] / 2

        self.width = round(max(left[key] + columns[key] for key in left) + SIZES["margin"])
        self.height = round(max(top[key] + rows[key] for key in top) + SIZES["margin"])
        self.gaps = {
            "x": UmlLayout.channels(left, columns, SIZES["gap_x"]),
            "y": UmlLayout.channels(top, rows, SIZES["gap_y"]),
        }

    def build_links(self):
        links, seen = [], set()

        for name, table in self.model.tables.items():
            own = [column["name"] for column in table["columns"]]

            for item in table.get("foreign_keys", []):
                nullable = any(self.model.column(name, column)["null"] for column in item["columns"])
                target = [column["name"] for column in self.model.tables[item["references"]]["columns"]]
                pairs = [self.model.line_pair(name, item)]

                if SIZES["line_per_column"]:
                    pairs = list(zip(item["columns"], item["to"]))

                for column, referenced in pairs:
                    if (name, item["references"], column, referenced) in seen:
                        continue

                    seen.add((name, item["references"], column, referenced))
                    link = Link(
                        "foreign_key", self.boxes[name], self.boxes[item["references"]],
                        f"{name}.{column} -> {item['references']}.{referenced}",
                        (child_end(item["multiplicity"]), parent_end(nullable)),
                    )
                    link.rows = (own.index(column), target.index(referenced))
                    links.append(link)

        self.router = RelationalRouter(self.boxes, links, self.gaps)
        self.links = self.router().links if links else []

    def check(self):
        errors = []

        for link in self.links:
            if any(
                abs(first[0] - second[0]) > 0.5 and abs(first[1] - second[1]) > 0.5
                for first, second in zip(link.points, link.points[1:])
            ):
                errors.append(f"{self.describe(link)} has no route with right angles. Change the cells of the tables.")

            for box in self.boxes.values():
                if box not in (link.source, link.target) and GEOMETRY.polyline_hits_box(link.points, box.box(-2)):
                    errors.append(f"{self.describe(link)} goes through {box.title}. Change the cells of the tables.")

        errors.extend(self.overlaps())

        for number, first in enumerate(self.links):
            for second in self.links[number + 1:]:
                if any(
                    GEOMETRY.segments_cross(a, b, c, d)
                    for a, b in zip(first.points, first.points[1:])
                    for c, d in zip(second.points, second.points[1:])
                ):
                    self.warnings.append(f"{self.describe(first)} crosses {self.describe(second)}")

        if errors:
            raise RuntimeError("Unreadable diagram:\n- " + "\n- ".join(errors))

    def overlaps(self):
        """
        Finds ends of lines, that lie too close on one side of a table, and
        lines, that run on each other.

        Returns:
            str[]: Errors.
        """
        errors, ends = [], {}

        for link in self.links:
            for end, box in enumerate((link.source, link.target)):
                point = link.points[0] if end == 0 else link.points[-1]
                ends.setdefault((box.title, link.sides[end]), []).append((point[1], link))

        for (title, side), items in ends.items():
            items.sort(key=lambda item: item[0])

            for (first, one), (second, two) in zip(items, items[1:]):
                if second - first < SIZES["end_gap"]:
                    errors.append(
                        f"{self.describe(one)} and {self.describe(two)} end too close on the "
                        f"{'left' if side == 'L' else 'right'} side of {title}. Change the cells of the tables."
                    )

        for number, first in enumerate(self.links):
            for second in self.links[number + 1:]:
                if RelationalRouter.trunk(first, second):
                    continue
                if any(
                    GEOMETRY.collinear_overlap(a, b, c, d) > 1
                    for a, b in zip(first.points, first.points[1:])
                    for c, d in zip(second.points, second.points[1:])
                ):
                    errors.append(f"{self.describe(first)} runs on {self.describe(second)}. Change the cells of the tables.")

        return errors

    @staticmethod
    def describe(link):
        return f"'{link.name}' ({link.source.title} - {link.target.title})"
