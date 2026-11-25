import math
from collections import defaultdict

from classes.ErdModel import end_entity, is_recursive
from classes.Shape import Line, Shape
from const.general import (
    CLEARANCE, FONT_SIZES, MIN_PRINTED_FONT, PAPERS, PX_TO_PT, SEARCH, SIZES
)
from utils.geometry import (
    angle_between, angle_difference, boxes_overlap,
    path_hits_box, paths_cross, text_width, union_box
)


class ChenLayout:
    """
    Layout problem: Place a Chen ERD, so that nothing overlaps or crosses,
    attributes stay next to their owner and the text is readable.

    Args:
        model (ErdModel): Validated model of the ERD.
    """

    def __init__(self, model):
        self.model = model
        self.build_sizes()

    def __call__(self):
        """
        Criterion: Minimize the area of the diagram, that has enough space.
        The rows and columns are moved apart separately, because attributes
        need more room in one direction than in the other.

        Rules:
        - Spreads are tried from the smallest area.
        - Attributes are placed before the cardinalities, which then take
          the free side of their line.
        - Attributes only make a diagram larger, so a spread is skipped, when
          its entities and relationships alone are unreadable or larger than
          the best diagram found.

        Returns:
            ChenLayout: Layout with positioned shapes and lines.
        """
        best = None
        errors = []

        for spread in self.spreads():
            self.shapes = []
            self.lines = []
            self.errors = []

            self.build_entities(spread)
            self.build_relationships(spread)
            self.check_skeleton()

            if not self.errors:
                width, height = self.page_size()

                if not self.fits(width, height):
                    errors.append(f"text would be smaller than {MIN_PRINTED_FONT} pt")
                    continue
                if best is not None and width * height >= best[0]:
                    continue

                self.build_attributes()

            if not self.errors:
                self.build_cardinalities()

            if self.errors:
                errors.extend(self.errors)
                continue

            self.build_page()

            if not self.is_readable():
                errors.append(f"text would be smaller than {MIN_PRINTED_FONT} pt")
                continue

            if best is None or self.width * self.height < best[0]:
                best = self.width * self.height, self.snapshot()

        if best is None:
            raise RuntimeError(
                "The diagram is not readable. Change the cells of the entities:\n- "
                + "\n- ".join(dict.fromkeys(errors))
            )

        self.restore(best[1])
        self.is_readable()

        return self

    def spreads(self):
        return sorted(
            (
                (horizontal, vertical)
                for horizontal in SEARCH["spreads_x"]
                for vertical in SEARCH["spreads_y"]
            ),
            key=lambda spread: spread[0] * spread[1]
        )

    def snapshot(self):
        return self.shapes, self.lines, self.entities, self.relations, self.width, self.height

    def restore(self, state):
        self.shapes, self.lines, self.entities, self.relations, self.width, self.height = state

    def build_sizes(self):
        entities = self.model.entities.values()
        relations = self.model.relationships

        self.entity_width = max([SIZES["entity_width"]] + [
            text_width(item["name"], FONT_SIZES["entity"], True) + 40
            for item in entities
        ])

        names = [relation["name"] for relation in relations]
        self.relation_width = max([SIZES["relationship_width"]] + [
            min(self.diamond_width(lines) for lines in self.line_options(name))
            for name in names
        ])
        self.relation_texts = [self.wrap_relationship(name) for name in names]

        self.gap_x = SIZES["gap_x"] + max([30] + [
            text_width(str(value), FONT_SIZES["cardinality"])
            for relation in relations
            for value in relation["ends"].values()
        ])

    def line_options(self, name):
        words = name.split()

        return [[name]] + [
            [" ".join(words[:i]), " ".join(words[i:])] for i in range(1, len(words))
        ]

    def diamond_width(self, lines):
        size = FONT_SIZES["relationship"]
        free = 1 - len(lines) * 1.2 * size / SIZES["relationship_height"]

        return max(text_width(line, size) for line in lines) / free + 10

    def wrap_relationship(self, name):
        """
        Breaks the name only, when it does not fit in one line.

        Args:
            name (str): Name of the relationship.

        Returns:
            str: Text of the diamond with line breaks.
        """
        if self.diamond_width([name]) <= self.relation_width:
            return name

        return "\n".join(min(self.line_options(name), key=self.diamond_width))

    def cell_center(self, cell, spread):
        column = self.entity_width + self.relation_width + 2 * self.gap_x
        row = SIZES["entity_height"] + SIZES["relationship_height"] + 2 * SIZES["gap_y"]

        return cell[0] * column * spread[0], cell[1] * row * spread[1]

    def build_entities(self, spread):
        self.entities = {}

        for key, entity in self.model.entities.items():
            shape = Shape(
                "entity",
                entity["name"],
                self.cell_center(entity["cell"], spread),
                (self.entity_width, SIZES["entity_height"]),
                "weak_entity" if entity.get("weak") else "entity"
            )

            self.entities[key] = shape
            self.shapes.append(shape)

    def build_relationships(self, spread):
        """
        Relationship rules:
        - Diamond is in the middle between entities from one row or column.
        - Diamond with its own cell is in line with all of its entities,
          unless the relationship has "free": true, which allows diagonal lines.
        - Parallel relationships are placed on opposite sides of the axis.
        - A recursive relationship (an entity with itself) stands in its own
          cell diagonal to the entity. Its two lines go around the two
          opposite corners between them, so they form a loop and leave the
          entity on two different sides.
        """
        groups = defaultdict(list)
        self.relations = []

        for index, relation in enumerate(self.model.relationships):
            if "cell" not in relation:
                groups[frozenset(relation["ends"])].append(index)

        for index, relation in enumerate(self.model.relationships):
            ends = [self.entities[end_entity(key)] for key in relation["ends"]]
            x, y = self.relation_center(relation, ends, spread)
            side = (0, 0)

            if "cell" not in relation:
                group = groups[frozenset(relation["ends"])]
                position = group.index(index) - (len(group) - 1) / 2
                horizontal = ends[0].y == ends[1].y
                extent = SIZES["relationship_height"] if horizontal else self.relation_width
                offset = position * (extent + SIZES["parallel_gap"]) * spread[1 if horizontal else 0]

                side = (0, offset) if horizontal else (offset, 0)

            shape = Shape(
                "relationship",
                self.relation_texts[index],
                (x + side[0], y + side[1]),
                (self.relation_width, SIZES["relationship_height"]),
                "identifying" if relation.get("identifying") else "relationship"
            )
            shape.side = side

            self.relations.append(shape)
            self.shapes.append(shape)

            if is_recursive(relation):
                entity = ends[0]
                corners = [(entity.x, shape.y), (shape.x, entity.y)]

                for corner, cardinality in zip(corners, relation["ends"].values()):
                    self.lines.append(Line(
                        entity, shape, str(cardinality), SEARCH["recursive_curve"],
                        SEARCH["straight_angle"], SEARCH["curve_pieces"], via=corner
                    ))
                continue

            for end, cardinality in zip(ends, relation["ends"].values()):
                self.lines.append(self.line(end, shape, str(cardinality)))

    def relation_center(self, relation, ends, spread):
        if "cell" in relation:
            center = self.cell_center(relation["cell"], spread)
        else:
            center = (
                sum(end.x for end in ends) / len(ends),
                sum(end.y for end in ends) / len(ends)
            )

            if len(ends) > 2:
                self.errors.append(f"{relation['name']}: n-ary relationship needs a cell")

        if is_recursive(relation):
            if any(math.isclose(a, b, abs_tol=1e-6) for a, b in zip(ends[0].center, center)):
                self.errors.append(
                    f"{relation['name']}: a recursive relationship stands diagonal to {ends[0].text}"
                )

            return center

        for end in ends:
            if relation.get("free"):
                break

            if not any(math.isclose(a, b, abs_tol=1e-6) for a, b in zip(end.center, center)):
                self.errors.append(
                    f"{relation['name']}: is not in the same row or column as {end.text}"
                )

        return center

    def check_skeleton(self):
        """
        Constraints:
        - Shapes do not overlap.
        - Lines do not go through shapes.
        - Lines do not cross and do not lie on each other.
        """
        for i, first in enumerate(self.shapes):
            for second in self.shapes[i + 1:]:
                if boxes_overlap(first.box(CLEARANCE["line"]), second.box()):
                    self.errors.append(f"{first.text} overlaps {second.text}")

        for i, line in enumerate(self.lines):
            name = f"{line.source.text} - {line.target.text}"

            for shape in self.shapes:
                if shape not in line.shapes and path_hits_box(
                    line.points, shape.box(CLEARANCE["line"])
                ):
                    self.errors.append(f"{name} goes through {shape.text}")

            for other in self.lines[i + 1:]:
                other_name = f"{other.source.text} - {other.target.text}"

                if paths_cross(line.points, other.points):
                    self.errors.append(f"{name} crosses {other_name}")
                elif self.lines_merge(line, other, CLEARANCE["relationship_angle"]):
                    self.errors.append(f"{name} lies on {other_name}")

    def line(self, source, target, cardinality=None, curve=None):
        """
        Every diagonal line is a gentle curve. A line of an attribute bends
        less, because it is short and stands in a fan with other lines.

        Args:
            source (Shape): First shape.
            target (Shape): Second shape.
            cardinality (str, optional): Cardinality of a relationship line.
                Default: none.
            curve (float, optional): Strength of the curve. Default: the
                curve of relationship lines.

        Returns:
            Line: The line.
        """
        return Line(
            source, target, cardinality,
            SEARCH["curve"] if curve is None else curve,
            SEARCH["straight_angle"], SEARCH["curve_pieces"]
        )

    def lines_merge(self, line, other, limit):
        if line.via and other.via and set(line.shapes) == set(other.shapes):
            return False

        for shared in line.shapes:
            if shared in other.shapes:
                first = line.target if shared is line.source else line.source
                second = other.target if shared is other.source else other.source

                return angle_between(shared.center, first.center, second.center) < limit

        return False

    def build_cardinalities(self):
        for line in self.lines:
            if line.cardinality is None:
                continue

            if not self.place_cardinality(line):
                self.errors.append(
                    f"no space for {line.cardinality} at {line.source.text} - {line.target.text}"
                )

    def place_cardinality(self, line):
        """
        Places the cardinality next to the line, never on it.

        Rules:
        - The label stands in the middle of its line, where it is best seen,
          and moves toward an end only, when the middle is taken.
        - The label stands next to the drawn curve. Its offset is measured
          from the point, from which draw.io measures it.
        - A relationship of a parallel pair has its label on the outer side,
          so that the labels of the pair stay apart.
        - A curve has its label on the inner side of its bend.

        Args:
            line (Line): Line from an entity to a relationship.

        Returns:
            bool: True, if free space was found.
        """
        size = FONT_SIZES["cardinality"]
        width, height = text_width(line.cardinality, size) + 4, size + 2
        side = line.target.side

        for position in SEARCH["label_positions"]:
            point, (dx, dy) = line.point_at(position)
            normal = dy, -dx

            if any(side):
                preference = normal[0] * side[0] + normal[1] * side[1]
            elif line.control is not None:
                bulge = (
                    line.control[0] - (line.start[0] + line.end[0]) / 2,
                    line.control[1] - (line.start[1] + line.end[1]) / 2,
                )
                preference = -(normal[0] * bulge[0] + normal[1] * bulge[1])
            elif abs(dx) >= abs(dy):
                preference = -normal[1]
            else:
                preference = normal[0]

            if preference < 0:
                normal = -normal[0], -normal[1]

            for nx, ny in (normal, (-normal[0], -normal[1])):
                distance = abs(nx) * width / 2 + abs(ny) * height / 2 + 6
                offset = nx * distance, ny * distance
                label = Shape(
                    "cardinality",
                    line.cardinality,
                    (point[0] + offset[0], point[1] + offset[1]),
                    (width, height)
                )
                box = label.box(CLEARANCE["label"])

                if any(boxes_overlap(box, shape.box()) for shape in self.shapes):
                    continue
                if any(path_hits_box(o.points, box) for o in self.lines):
                    continue

                base = line.label_base(position)
                line.label = label
                line.label_position = 2 * position - 1
                line.label_offset = label.x - base[0], label.y - base[1]
                self.shapes.append(label)
                return True

        return False

    def build_attributes(self):
        """
        Criterion: The most crowded owner is placed first, because it has the
        fewest free places. An owner is crowded by its attributes and lines.

        Constraint: Every attribute stands closer to its owner than the
        nearest relationship of the owner, so that attributes and
        relationships are not mixed up.
        """
        self.reach = {}

        for line in self.lines:
            for shape in line.shapes:
                self.reach[shape] = min(self.reach.get(shape, math.inf), line.length)

        owners = list(zip(self.relations, self.model.relationships))
        owners += list(zip(self.entities.values(), self.model.entities.values()))
        owners.sort(
            key=lambda pair: (
                len(pair[1].get("attributes", []))
                + sum(pair[0] in line.shapes for line in self.lines)
            ),
            reverse=True
        )

        self.center = (
            sum(shape.x for shape in self.entities.values()) / len(self.entities),
            sum(shape.y for shape in self.entities.values()) / len(self.entities)
        )

        for owner, element in owners:
            attributes = element.get("attributes", [])

            if attributes and not self.place_cluster(owner, attributes):
                self.errors.append(f"no space for the attributes of {owner.text}")

    def place_cluster(self, owner, attributes):
        """
        Criterion: Keep all attributes of an owner together in one fan. The
        fan is split into more groups only, when one fan has no free space.
        Each group stands as close to the owner, as its free space allows.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            attributes (dict[]): Attributes from the model.

        Returns:
            bool: True, if free space was found.
        """
        for parts in range(1, min(len(attributes), SEARCH["max_clusters"]) + 1):
            placed = self.place_groups(owner, self.split(attributes, parts))

            if placed:
                for shape, line in placed:
                    self.shapes.append(shape)
                    self.lines.append(line)

                return True

        return False

    def split(self, attributes, parts):
        size, rest = divmod(len(attributes), parts)
        groups, start = [], 0

        for index in range(parts):
            end = start + size + (1 if index < rest else 0)
            groups.append(attributes[start:end])
            start = end

        return groups

    def place_groups(self, owner, groups, placed=()):
        """
        Places the groups one after another, each at the smallest distance
        from the owner, that has a free place.

        Rules:
        - The last group takes its best place.
        - An earlier group tries its few best places, because the best place
          of one group can take the only free place of the next one.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            groups (dict[][]): Attributes split into groups.
            placed (tuple[Shape, Line][], optional): Attributes of the earlier
                groups. Default: none.

        Returns:
            tuple[Shape, Line][]: Placed attributes or None, when a group does not fit.
        """
        if not groups:
            return list(placed)

        shapes = self.shapes + [shape for shape, _ in placed]
        lines = self.lines + [line for _, line in placed]
        choices = 1 if len(groups) == 1 else SEARCH["group_choices"]

        for scale in SEARCH["scales"]:
            fans = self.find_fans(owner, groups[0], scale, shapes, lines, choices)

            for fan in fans:
                result = self.place_groups(owner, groups[1:], (*placed, *fan))

                if result is not None:
                    return result

            if fans and len(groups) > 1:
                return None

        return None

    def find_fans(self, owner, group, scale, shapes, lines, choices):
        """
        Criterion: Put the fan outside of the diagram, where it does not grow
        the diagram much.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            group (dict[]): Attributes placed in this fan.
            scale (float): Multiplier of the distance from the owner.
            shapes (Shape[]): Shapes, that are already placed.
            lines (Line[]): Lines, that are already placed.
            choices (int): Largest number of returned fans.

        Returns:
            tuple[Shape, Line][][]: The best fans in different directions,
                the best first. Empty, when no place is free.
        """
        items = [self.attribute_item(attribute) for attribute in group]
        distance = SIZES["attribute_distance"] * scale

        bounds = union_box(shape.box() for shape in shapes)
        area = self.area(bounds)
        obstacles = [(shape, shape.box(), shape.box(CLEARANCE["line"])) for shape in shapes]
        outward = self.outward(owner)
        found = []

        for angle, ordered, positions, penalty in self.candidates(owner, items, distance):
            fan = self.check_fan(owner, ordered, positions, obstacles, lines)

            if fan is None:
                continue

            growth = self.area(union_box(
                [bounds] + [shape.box() for shape, _ in fan]
            )) - area
            cost = (
                angle_difference(angle, outward) + penalty + growth / SEARCH["growth_weight"]
            )
            middle = (
                sum(shape.x for shape, _ in fan) / len(fan),
                sum(shape.y for shape, _ in fan) / len(fan)
            )
            found.append((cost, middle, fan))

        found.sort(key=lambda entry: entry[0])
        best = []

        for cost, middle, fan in found:
            if all(
                math.dist(middle, other) >= SEARCH["group_separation"] for other, _ in best
            ):
                best.append((middle, fan))

            if len(best) == choices:
                break

        return [fan for _, fan in best]

    def candidates(self, owner, items, distance):
        """
        Rows and columns next to the owner are tidy, so they are preferred.
        Fans around the owner are used, when a row has no free space. Arcs
        on a circle around the owner are used for many attributes, because
        their lines go straight out of the owner and never pass another
        attribute.

        Yields:
            tuple: Direction, attributes in the placement order, their
                centers and the penalty of the candidate.
        """
        yield from self.rows(owner, items, distance)

        for angle in range(0, 360, SEARCH["angle_step"]):
            ordered = items if self.reads_forward(angle) else items[::-1]
            positions = self.fan_positions(owner, ordered, distance, angle)

            if positions is not None:
                yield angle, ordered, positions, SEARCH["fan_penalty"]

        if len(items) < SEARCH["arc_min_items"]:
            return

        for angle in range(0, 360, SEARCH["angle_step"]):
            ordered = items if self.reads_forward(angle) else items[::-1]
            positions = self.arc_positions(owner, ordered, distance, angle)

            if positions is not None:
                yield angle, ordered, positions, SEARCH["arc_penalty"]

    def arc_positions(self, owner, ordered, distance, angle):
        """
        Places the attributes on a circle around the center of the owner,
        as close to each other as they can be without touching. The circle
        grows, until the attributes fit on the largest allowed arc.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            ordered (tuple[]): Attributes in the placement order.
            distance (float): Smallest free distance between the owner and
                an attribute.
            angle (float): Direction of the middle of the arc in degrees.

        Returns:
            float[2][]: Centers of the attributes or None, if they do not fit.
        """
        count = len(ordered)
        largest = max(max(item[1]) for item in ordered)
        smallest = math.hypot(owner.width, owner.height) / 2 + distance + largest / 2

        for radius in range(
            int(smallest), int(smallest + SEARCH["arc_growth"]) + 1, SEARCH["arc_step"]
        ):
            spacing = SEARCH["min_spacing"]

            while spacing * (count - 1) <= SEARCH["arc_span"]:
                positions = []

                for index in range(count):
                    degrees = math.radians(angle + (index - (count - 1) / 2) * spacing)
                    positions.append((
                        owner.x + radius * math.cos(degrees),
                        owner.y + radius * math.sin(degrees)
                    ))

                if not self.touching(ordered, positions):
                    return positions

                spacing += SEARCH["spacing_step"]

        return None

    def rows(self, owner, items, distance):
        """
        Places the attributes in a row above or below the owner, or in a
        column on its sides. The row can be moved along the owner.

        Rules:
        - A plain row has all attributes at the same distance from the owner.
        - A staggered row puts every second attribute one row further, so
          that its line passes between two nearer attributes. It needs about
          half of the length of a plain row and has a small penalty.
        """
        for staggered in (False, True) if len(items) > 2 else (False,):
            for angle, (dx, dy) in SEARCH["sides"].items():
                for positions, shift in self.row_positions(owner, items, distance, dx, dy, staggered):
                    penalty = abs(shift) / SEARCH["shift_weight"]

                    if staggered:
                        penalty += SEARCH["stagger_penalty"]

                    yield angle, items, positions, penalty

    def row_positions(self, owner, items, distance, dx, dy, staggered):
        """
        Yields the centers of one row of attributes for every shift along
        the owner.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            items (tuple[]): Attributes in the placement order.
            distance (float): Distance of the nearest attributes from the owner.
            dx (int): -1 or 1 for a column on the left or right side, else 0.
            dy (int): -1 or 1 for a row above or below, else 0.
            staggered (bool): Whether every second attribute is one row further.

        Yields:
            tuple[float[2][], int]: Centers of the attributes and the shift.
        """
        gap = SEARCH["row_gap"]
        sizes = [item[1] for item in items]
        along = [width if dy else height for width, height in sizes]
        across = max(height if dy else width for width, height in sizes)

        if staggered:
            pitch = (max(along) + SEARCH["stagger_corridor"]) / 2
            starts = [index * pitch for index in range(len(sizes))]
            total = starts[-1] + along[0] / 2 + along[-1] / 2
            starts = [start + along[0] / 2 for start in starts]
        else:
            starts, position = [], 0

            for length in along:
                starts.append(position + length / 2)
                position += length + gap

            total = position - gap

        base = (owner.height if dy else owner.width) / 2 + distance + across / 2
        far = across + gap
        limit = int((total + (owner.width if dy else owner.height)) / 2)

        for shift in range(-limit, limit + 1, SEARCH["row_step"]):
            positions = []

            for index, middle in enumerate(starts):
                offset = base + (far if staggered and index % 2 else 0)
                along_position = (owner.x if dy else owner.y) + shift - total / 2 + middle

                if dy:
                    positions.append((along_position, owner.y + dy * offset))
                else:
                    positions.append((owner.x + dx * offset, along_position))

            yield positions, shift

    def attribute_item(self, attribute):
        """
        Long names are broken into two lines, so the oval stays narrow.

        Returns:
            tuple: Text, size, style and whether the key is partial.
        """
        kind = attribute.get("kind", "simple")
        size = FONT_SIZES["attribute"]
        options = self.line_options(attribute["name"])
        lines = options[0]

        if text_width(lines[0], size) > SIZES["attribute_wrap"] and len(options) > 1:
            lines = min(options[1:], key=lambda item: max(text_width(l, size) for l in item))

        width = max(text_width(line, size) for line in lines) + 40
        height = SIZES["attribute_height"] if len(lines) == 1 else SIZES["attribute_height_wrapped"]
        style = kind if kind in ("key", "derived", "multivalued") else "attribute"

        return "\n".join(lines), (max(SIZES["attribute_width"], width), height), style, kind == "partial"

    def area(self, box):
        return (box[2] - box[0]) * (box[3] - box[1])

    def outward(self, owner):
        dx, dy = owner.x - self.center[0], owner.y - self.center[1]

        if math.hypot(dx, dy) < 1:
            return 0

        return math.degrees(math.atan2(dy, dx)) % 360

    def reads_forward(self, angle):
        """
        Attributes are read from left to right and from top to bottom.
        """
        sine, cosine = math.sin(math.radians(angle)), math.cos(math.radians(angle))

        return not (sine > 0.35 or (abs(sine) <= 0.35 and cosine < 0))

    def fan_positions(self, owner, ordered, distance, angle):
        """
        Places the attributes around the owner at the same distance from its
        edge, as close to each other as they can be without touching.

        Returns:
            float[2][]: Centers of the attributes or None, if they do not fit.
        """
        count = len(ordered)

        if count == 1:
            return [self.ring_point(owner, ordered[0][1], distance, angle)]

        spacing = SEARCH["min_spacing"]

        while spacing <= SEARCH["max_spacing"] and spacing * (count - 1) <= SEARCH["max_span"]:
            positions = [
                self.ring_point(
                    owner, item[1], distance, angle + (index - (count - 1) / 2) * spacing
                )
                for index, item in enumerate(ordered)
            ]

            if not self.touching(ordered, positions):
                return positions

            spacing += SEARCH["spacing_step"]

        return None

    def ring_point(self, owner, size, distance, degrees):
        """
        Finds the center of an attribute on a ray from the owner, so that
        the attribute is exactly the given distance away from the owner.
        """
        cosine, sine = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
        half_width = owner.width / 2 + distance + size[0] / 2
        half_height = owner.height / 2 + distance + size[1] / 2
        length = min(
            half_width / abs(cosine) if abs(cosine) > 1e-9 else math.inf,
            half_height / abs(sine) if abs(sine) > 1e-9 else math.inf
        )

        return owner.x + length * cosine, owner.y + length * sine

    def touching(self, items, positions):
        boxes = [
            (
                x - item[1][0] / 2 - SEARCH["attribute_gap"] / 2,
                y - item[1][1] / 2 - SEARCH["attribute_gap"] / 2,
                x + item[1][0] / 2 + SEARCH["attribute_gap"] / 2,
                y + item[1][1] / 2 + SEARCH["attribute_gap"] / 2,
            )
            for item, (x, y) in zip(items, positions)
        ]

        return any(
            boxes_overlap(first, second)
            for i, first in enumerate(boxes)
            for second in boxes[i + 1:]
        )

    def check_fan(self, owner, ordered, positions, obstacles, lines):
        """
        Checks a candidate fan of attributes, one attribute after another.

        Args:
            owner (Shape): Entity or relationship, that has the attributes.
            ordered (tuple[]): Attributes in the placement order.
            positions (float[2][]): Centers of the attributes.
            obstacles (tuple[Shape, float[4], float[4]][]): Placed shapes with
                their box and their box with the line clearance.
            lines (Line[]): Lines, that are already placed.

        Returns:
            tuple[Shape, Line][]: The fan or None, when it is not free.
        """
        fan = []
        placed_obstacles = list(obstacles)
        placed_lines = list(lines)

        for (text, size, style, partial), position in zip(ordered, positions):
            shape = Shape("attribute", text, position, size, style)
            shape.partial = partial
            line = self.line(owner, shape, curve=SEARCH["attribute_curve"])

            if line.length < CLEARANCE["attribute_line"]:
                return None
            if line.length > self.reach.get(owner, math.inf) * SEARCH["attribute_reach"]:
                return None
            if not self.is_free(shape, line, placed_obstacles, placed_lines):
                return None

            fan.append((shape, line))
            placed_obstacles.append((shape, shape.box(), shape.box(CLEARANCE["line"])))
            placed_lines.append(line)

        if len(fan) > 1:
            group = union_box(shape.box(CLEARANCE["line"]) for shape, _ in fan)

            if any(
                path_hits_box(other.points, group) for other in lines
            ):
                return None

        return fan

    def is_free(self, shape, line, obstacles, lines):
        box = shape.box(CLEARANCE["shape"])

        if any(boxes_overlap(box, other_box) for _, other_box, _ in obstacles):
            return False

        for other, _, clear_box in obstacles:
            if other is not line.source and path_hits_box(line.points, clear_box):
                return False

        box = shape.box(CLEARANCE["line"])

        for other in lines:
            if path_hits_box(other.points, box):
                return False
            if paths_cross(line.points, other.points):
                return False
            if self.lines_merge(line, other, CLEARANCE["attribute_angle"]):
                return False

        return True

    def build_page(self):
        margin = SIZES["margin"]
        left = min(shape.box()[0] for shape in self.shapes) - margin
        top = min(shape.box()[1] for shape in self.shapes) - margin

        for shape in self.shapes:
            shape.x -= left
            shape.y -= top

        for line in self.lines:
            line.move(-left, -top)

        self.width = math.ceil(max(shape.box()[2] for shape in self.shapes) + margin)
        self.height = math.ceil(max(shape.box()[3] for shape in self.shapes) + margin)

    def page_size(self):
        box = union_box(shape.box() for shape in self.shapes)

        return box[2] - box[0] + 2 * SIZES["margin"], box[3] - box[1] + 2 * SIZES["margin"]

    def is_readable(self):
        """
        Text must have at least the minimal size on the smallest paper,
        on which the whole diagram fits.

        Returns:
            bool: True, if the text is readable.
        """
        return self.fits(self.width, self.height)

    def fits(self, page_width, page_height):
        """
        Finds the smallest paper, on which a page of this size has readable text.

        Args:
            page_width (float): Width of the page in px.
            page_height (float): Height of the page in px.

        Returns:
            bool: True, if the text is readable on one of the papers.
        """
        for paper, (width, height) in PAPERS.items():
            scale = min(PX_TO_PT, width / page_width, height / page_height)
            self.printed_font = min(FONT_SIZES.values()) * scale
            self.paper = paper

            if self.printed_font >= MIN_PRINTED_FONT:
                return True

        return False
