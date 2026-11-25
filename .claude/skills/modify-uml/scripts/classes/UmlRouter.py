import math

from const.general import ROUTING
from utils.geometry import (
    collinear_overlap, point_along, polyline_hits_box, polyline_length, segments_cross
)

NORMALS = {"L": (-1, 0), "R": (1, 0), "T": (0, -1), "B": (0, 1)}


class UmlRouter:
    """
    Routing of the associations as polylines of right angles, in the style of
    a hand-made UML diagram: lines leave the middle of a side of a class,
    run straight or bend once or twice in the gaps between the classes, and
    never go through a class.

    Rules:
    - A route is straight, an L, a Z or a U. Fewer bends are better.
    - A route does not touch a class, that it does not join.
    - Routes avoid crossing and running on each other.
    - When several lines use one side of a class, they leave it side by side.
    - A line between two facing sides is straight, when the port alone on its
      side can move to the height of the other one.
    - An association of a class with itself is a loop: it leaves one side,
      turns around the corner between this side and a neighbouring one, and
      enters the neighbouring side.

    Args:
        boxes (Box[]): Boxes of the classes.
        links (Link[]): Associations to route.
        gaps (dict[]): Positions of the free channels: `x` and `y` lists.
    """

    SIDES = "LRTB"
    """Sides of a box, that a line can leave or enter. A subclass can allow fewer."""

    SHIFTS = ROUTING["shifts"]
    """Positions of the parallel lines in a gap, from its middle. A subclass can allow more."""

    def __init__(self, boxes, links, gaps):
        self.boxes = boxes
        self.links = links
        self.gaps = gaps
        self.routed = []
        self.usage = {}

    def __call__(self):
        """
        Routes every link.

        Returns:
            UmlRouter: Router, whose links have their points and sides.
        """
        ordered = sorted(self.links, key=self.distance)

        for link in ordered:
            self.choose(link)

        self.spread_ports()

        return self

    @staticmethod
    def distance(link):
        return (
            abs(link.source.x - link.target.x) + abs(link.source.y - link.target.y),
            link.source.key, link.target.key,
        )

    def port(self, box, side):
        return {
            "L": (box.box()[0], box.y), "R": (box.box()[2], box.y),
            "T": (box.x, box.box()[1]), "B": (box.x, box.box()[3]),
        }[side]

    def choose(self, link):
        """
        Chooses the sides and the channel with the lowest cost.

        Args:
            link (Link): Link to route.
        """
        best = None

        for first in self.SIDES:
            for second in self.SIDES:
                start, end = self.port(link.source, first), self.port(link.target, second)
                routes = (
                    self.loop(start, first, end, second) if link.source is link.target
                    else self.candidates(start, first, end, second)
                )

                for points, channel in routes:
                    cost = self.cost(link, points, first, second)

                    if cost is not None and (best is None or cost < best[0]):
                        best = (cost, points, first, second, channel)

        if best is None:
            raise RuntimeError(
                f"No route for '{link.name}' ({link.source.title} - {link.target.title}). "
                "Change the cells of the classes, so that there is a free gap between them."
            )

        _, link.points, first, second, link.channel = best
        link.sides = (first, second)
        self.routed.append(link)

        for box, side in ((link.source, first), (link.target, second)):
            self.usage[(box.key, side)] = self.usage.get((box.key, side), 0) + 1

    def candidates(self, start, first, end, second):
        """
        Builds the routes between two ports.

        Args:
            start (float[2]): Port on the first box.
            first (str): Side of the first box: L, R, T or B.
            end (float[2]): Port on the second box.
            second (str): Side of the second box.

        Yields:
            tuple[]: Points of the route and its channel, that is the x or y of
                the middle segment, or None.
        """
        a, b = NORMALS[first], NORMALS[second]
        horizontal = first in "LR"

        if horizontal != (second in "LR"):
            corner = (end[0], start[1]) if horizontal else (start[0], end[1])

            if self.leaves(start, a, corner) and self.leaves(end, b, corner):
                yield [start, corner, end], None
            return

        axis = 0 if horizontal else 1
        other = 1 - axis

        if a == (-b[0], -b[1]):
            if (end[axis] - start[axis]) * a[axis] <= ROUTING["stub"]:
                return
            if abs(start[other] - end[other]) < 1:
                yield [start, end], None
                return

            for channel in self.channels(axis, start[axis], end[axis]):
                yield self.bridge(start, end, axis, channel), channel
        elif a == b:
            edge = max(start[axis], end[axis]) if a[axis] > 0 else min(start[axis], end[axis])

            for channel in self.channels(axis, edge, edge + a[axis] * 10 ** 5):
                if (channel - edge) * a[axis] > ROUTING["stub"]:
                    yield self.bridge(start, end, axis, channel), channel
                    break
            else:
                yield self.bridge(start, end, axis, edge + a[axis] * ROUTING["outer"]), None

    @staticmethod
    def loop(start, first, end, second):
        """
        Builds the loop of an association of a class with itself.

        Rules:
        - Two neighbouring sides (one vertical and one horizontal) give a
          loop around one corner of the class.
        - The same side twice gives a U next to that side, for example from
          one row of a table to another row of the same table.
        - Both ends leave their side straight for `ROUTING["loop"]`.

        Args:
            start (float[2]): Port on the first side.
            first (str): First side: L, R, T or B.
            end (float[2]): Port on the second side.
            second (str): Second side.

        Yields:
            tuple[]: Points of the loop and no channel.
        """
        a, b = NORMALS[first], NORMALS[second]
        out = ROUTING["loop"]

        if first == second and start != end:
            axis = 0 if first in "LR" else 1
            edge = start[axis] + a[axis] * out
            leave = (edge, start[1]) if axis == 0 else (start[0], edge)
            enter = (edge, end[1]) if axis == 0 else (end[0], edge)

            yield [start, leave, enter, end], None
            return
        if (first in "LR") == (second in "LR"):
            return

        leave = (start[0] + a[0] * out, start[1] + a[1] * out)
        enter = (end[0] + b[0] * out, end[1] + b[1] * out)
        corner = (leave[0], enter[1]) if first in "LR" else (enter[0], leave[1])

        yield [start, leave, corner, enter, end], None

    @staticmethod
    def leaves(port, normal, corner):
        return (corner[0] - port[0]) * normal[0] + (corner[1] - port[1]) * normal[1] > ROUTING["stub"] / 2

    @staticmethod
    def bridge(start, end, axis, channel):
        if axis == 0:
            return [start, (channel, start[1]), (channel, end[1]), end]

        return [start, (start[0], channel), (end[0], channel), end]

    def channels(self, axis, first, second):
        """
        Lists the free channels between two coordinates, nearest to the middle first.

        Args:
            axis (int): 0 for vertical channels (x), 1 for horizontal ones (y).
            first (float): One coordinate.
            second (float): The other coordinate.

        Returns:
            float[]: Coordinates of channels, with small shifts of each.
        """
        low, high = sorted((first, second))
        middle = (low + high) / 2
        found = []

        for center in self.gaps["xy"[axis]]:
            for shift in self.SHIFTS:
                if low + ROUTING["stub"] < center + shift < high - ROUTING["stub"]:
                    found.append(center + shift)

        return sorted(found, key=lambda value: abs(value - middle))

    def cost(self, link, points, first, second):
        """
        Rates a route.

        Rules:
        - It does not go through a box, except at its own ports.
        - Every bend, every crossing and every shared stretch costs.
        - A side, that already has lines, costs a little.

        Args:
            link (Link): Link, that is routed.
            points (float[2][]): The route.
            first (str): Side of the source.
            second (str): Side of the target.

        Returns:
            float: Cost, or None when the route is not allowed.
        """
        for box in self.boxes.values():
            own = box in (link.source, link.target)
            margin = -ROUTING["own_margin"] if own else ROUTING["clearance"]

            if polyline_hits_box(points, box.box(margin)):
                return None

        cost = (len(points) - 2) * ROUTING["bend"] + polyline_length(points) * ROUTING["length"]
        cost += ROUTING["side"] * (
            self.usage.get((link.source.key, first), 0) + self.usage.get((link.target.key, second), 0)
        )

        for other in self.routed:
            cost += self.interference(points, other.points)

        return cost

    @staticmethod
    def interference(points, other):
        cost = 0

        for index, (a, b) in enumerate(zip(points, points[1:])):
            for number, (c, d) in enumerate(zip(other, other[1:])):
                if segments_cross(a, b, c, d):
                    cost += ROUTING["crossing"]

                inner = 0 < index < len(points) - 2 or 0 < number < len(other) - 2
                overlap = collinear_overlap(a, b, c, d)

                if overlap > 1 and inner:
                    cost += ROUTING["overlap"]

        return cost

    def spread_ports(self):
        """
        Moves the lines, that share a side of a class, side by side along it,
        and builds their routes again with the new ports.
        """
        groups = {}

        for link in self.links:
            for end, (box, side) in enumerate(((link.source, link.sides[0]), (link.target, link.sides[1]))):
                other = link.target if end == 0 else link.source
                groups.setdefault((box.key, side), []).append((link, end, other))

        ports = {}

        for (key, side), items in groups.items():
            box = self.boxes[key]
            across = 1 if side in "LR" else 0
            items.sort(key=lambda item: (self.anchor(item, across), self.links.index(item[0]), item[1]))
            length = box.height if side in "LR" else box.width
            step = min(ROUTING["port_step"], (length - 2 * ROUTING["corner"]) / max(1, len(items)))

            for index, (link, end, _) in enumerate(items):
                shift = (index - (len(items) - 1) / 2) * step
                x, y = self.port(box, side)

                ports[(id(link), end)] = (x, y + shift) if side in "LR" else (x + shift, y)

        self.align_ports(groups, ports)

        for link in self.links:
            self.rebuild(link, ports[(id(link), 0)], ports[(id(link), 1)])

    @staticmethod
    def anchor(item, across):
        """
        Finds the point, toward which an end of a line goes, to order the ends
        on one side of a class.

        Rules:
        - An end goes toward the other class of its line.
        - An end of a loop goes toward the corner, around which the loop
          turns, so it stands at that end of the side and does not cross the
          other lines of the side.

        Args:
            item (tuple[Link, int, Box]): The line, its end and the other box.
            across (int): Coordinate along the side: 1 for a left or right
                side, 0 for a top or bottom side.

        Returns:
            float: The coordinate.
        """
        link, _, other = item

        if link.source is link.target and len(link.points) == 5:
            return link.points[2][across]

        return other.center[across]

    def align_ports(self, groups, ports):
        """
        Makes a line straight, when its ports on two facing sides are only a
        little apart, by moving one of its ports along its side.

        Rules:
        - Only a line between two facing sides (left and right, or top and
          bottom) is aligned.
        - The moved port stays on its side, at least `corner` from its ends,
          and at least `side` from every other port on that side.
        - The straight line must not go through another class.
        - The lines are aligned again, until no port moves, because one moved
          port can make room for another.

        Args:
            groups (dict[]): Lines on every side of a class.
            ports (dict[]): Port of every end of a line, changed in place.
        """
        for _ in range(len(self.links)):
            moved = False

            for link in self.links:
                first, second = link.sides

                if not first or not second or NORMALS[first] != tuple(-v for v in NORMALS[second]):
                    continue

                across = 1 if first in "LR" else 0
                start, end = ports[(id(link), 0)], ports[(id(link), 1)]

                if abs(start[across] - end[across]) < 1:
                    continue

                for index, box, side, target in ((1, link.target, second, start), (0, link.source, first, end)):
                    if self.can_align(groups, ports, link, index, (box, side), target[across], across):
                        port = list(ports[(id(link), index)])
                        port[across] = target[across]
                        ports[(id(link), index)] = tuple(port)
                        moved = True
                        break

            if not moved:
                return

    def can_align(self, groups, ports, link, end, place, value, across):
        """
        Checks, whether a port can move to a value along its side.

        Args:
            groups (dict[]): Lines on every side of a class.
            ports (dict[]): Port of every end of a line.
            link (Link): The line.
            end (int): 0 for its source port, 1 for its target port.
            place (tuple[Box, str]): Box and side of the port.
            value (float): New coordinate along the side.
            across (int): 1 for a left or right side, 0 for a top or bottom side.

        Returns:
            bool: True, when the port can move there.
        """
        box, side = place
        low, high = (box.box()[1], box.box()[3]) if across else (box.box()[0], box.box()[2])

        if not low + ROUTING["corner"] <= value <= high - ROUTING["corner"]:
            return False

        for other, other_end, _ in groups[(box.key, side)]:
            if (other is not link or other_end != end) and abs(ports[(id(other), other_end)][across] - value) < ROUTING["side"]:
                return False

        points = [list(ports[(id(link), 0)]), list(ports[(id(link), 1)])]
        points[end][across] = value

        return not any(
            polyline_hits_box(points, other.box(ROUTING["clearance"]))
            for other in self.boxes.values() if other not in (link.source, link.target)
        )

    def rebuild(self, link, start, end):
        if link.source is link.target:
            loops = list(self.loop(start, link.sides[0], end, link.sides[1]))
            link.points = self.simplify(loops[0][0] if loops else [start, *link.points[1:-1], end])
            return

        options = list(self.candidates(start, link.sides[0], end, link.sides[1]))
        same = [item for item in options if link.channel is None or (
            item[1] is not None and abs(item[1] - link.channel) < 1
        )]
        options = same or options

        if options:
            points = options[0][0]
        else:
            points = [start, *link.points[1:-1], end]

        link.points = self.simplify(points)

    @staticmethod
    def simplify(points):
        result = [points[0]]

        for index in range(1, len(points) - 1):
            a, b, c = result[-1], points[index], points[index + 1]

            if (abs(a[0] - b[0]) < 0.5 and abs(b[0] - c[0]) < 0.5) or (
                abs(a[1] - b[1]) < 0.5 and abs(b[1] - c[1]) < 0.5
            ):
                continue

            result.append(b)

        result.append(points[-1])

        return result

    @staticmethod
    def middle(link):
        return point_along(link.points, polyline_length(link.points) / 2)

    @staticmethod
    def length(link):
        return math.fsum(math.dist(a, b) for a, b in zip(link.points, link.points[1:]))
