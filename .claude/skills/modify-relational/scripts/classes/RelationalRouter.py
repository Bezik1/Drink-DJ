from collections import Counter

from const.general import SIZES
from utils.rows import row_middle as box_row_middle, row_size
from utils.skills import uml_module

UML_ROUTER = uml_module("classes.UmlRouter")
UmlRouter = UML_ROUTER.UmlRouter
NORMALS = UML_ROUTER.NORMALS
ROUTING = uml_module("const.general").ROUTING
GEOMETRY = uml_module("utils.geometry")


class RelationalRouter(UmlRouter):
    """
    Routing of the foreign keys, so that a line joins a key with a key: it
    leaves the row of the foreign key column and enters the row of the
    referenced column. The router of the `modify-uml` skill chooses the sides
    and the channels, and this one only moves the ends to the rows.

    Rules:
    - A line leaves and enters only the left or the right side of a table,
      because a row has no other side.
    - The end of a line is at the middle of the row of its column. Several
      lines, that end at one row on one side, stand side by side inside it.
    - A line, that leaves and enters the same side (two tables in one
      column), may use every channel on that side, the nearest first, and
      not only the farthest one.
    - A gap between two columns holds 9 parallel lines, 14 px apart, because
      a table with a key of several columns has a line for every column.

    Args:
        boxes (Box[]): Boxes of the tables, with `rows`.
        links (Link[]): Foreign keys to route, each with `rows`: the index of
            the row in its table and of the row in the referenced table.
        gaps (dict[]): Positions of the free channels: `x` and `y` lists.
    """

    SIDES = "LR"

    SHIFTS = [0, -14, 14, -28, 28, -42, 42, -56, 56]

    SAME_SIDE_COST = 150

    def cost(self, link, points, first, second):
        """
        Rates a route like the router of the `modify-uml` skill, and adds a
        high cost for a route, that leaves and enters the same side of the
        tables: such a line runs around the tables and crosses many others.

        Args:
            link (Link): Link, that is routed.
            points (float[2][]): The route.
            first (str): Side of the source.
            second (str): Side of the target.

        Returns:
            float: Cost, or None when the route is not allowed.
        """
        cost = super().cost(link, points, first, second)

        if cost is None:
            return None

        return cost + (self.SAME_SIDE_COST if first == second else 0)

    @staticmethod
    def interference(points, other):
        """
        Rates how much a route crosses or runs on another one. Two routes,
        whose boxes do not touch, cannot, so they are not compared.

        Args:
            points (float[2][]): The route.
            other (float[2][]): The other route.

        Returns:
            float: The cost.
        """
        for axis in (0, 1):
            if (
                max(point[axis] for point in points) < min(point[axis] for point in other) - 3
                or max(point[axis] for point in other) < min(point[axis] for point in points) - 3
            ):
                return 0

        return UmlRouter.interference(points, other)

    def candidates(self, start, first, end, second):
        """
        Builds the routes between two ports. For two ports on the same side
        it gives a route through every free channel on that side, and else the
        routes of the `modify-uml` router.

        Args:
            start (float[2]): Port on the first box.
            first (str): Side of the first box: L or R.
            end (float[2]): Port on the second box.
            second (str): Side of the second box.

        Yields:
            tuple[]: Points of the route and its channel, or None.
        """
        if first != second:
            yield from super().candidates(start, first, end, second)
            return

        sign = NORMALS[first][0]
        edge = max(start[0], end[0]) if sign > 0 else min(start[0], end[0])
        channels = sorted(
            (center + shift for center in self.gaps["x"] for shift in self.SHIFTS
             if (center + shift - edge) * sign > ROUTING["stub"]),
            key=lambda value: abs(value - edge),
        )

        for channel in channels:
            yield self.bridge(start, end, 0, channel), channel

        yield self.bridge(start, end, 0, edge + sign * ROUTING["outer"]), None

    def loop(self, start, first, end, second):
        """
        Builds the route of a foreign key, that references its own table. It
        leaves the row of the foreign key and enters the row of the
        referenced column on the same side, through a free channel there.

        Args:
            start (float[2]): Port of the foreign key column.
            first (str): Side of the start: L or R.
            end (float[2]): Port of the referenced column.
            second (str): Side of the end.

        Yields:
            tuple[]: Points of the route and its channel, or None.
        """
        if first == second:
            yield from self.candidates(start, first, end, second)

    def spread_ports(self):
        """
        Moves the ends of every line to the rows of their columns, so that no
        two ends lie on each other, and routes every line again for its ends.

        Rules:
        - Lines between the same two tables take the same sides, when a route
          exists, so the lines of one key run side by side.
        - Ends on one side of a table stand at least `end_gap` apart, inside
          their rows, so their crow's foot marks do not touch.
        - A line between two facing sides is straight, when its two rows
          overlap in height and the common height keeps these gaps.
        - A line of a foreign key of several columns, whose row has no room,
          moves to another pair of its key columns, when that has fewer
          conflicts. Else an end without room moves to the other side of its
          table, when a route exists there.
        - With the ends fixed, every line takes the route, that runs on no
          stretch of the lines routed before it, and of those the one with the
          lowest cost.
        - Then the lines of one key swap their channels, so that they do not
          cross each other (see `nest`).
        """
        self.unify()
        self.separate()
        ports = self.ports()
        self.routed = []

        for link in sorted(self.links, key=self.distance):
            start, end = ports[(id(link), 0)], ports[(id(link), 1)]
            options = [
                ((self.overlap(points), cost), points, channel)
                for points, channel in self.candidates(start, link.sides[0], end, link.sides[1])
                for cost in [self.cost(link, points, *link.sides)] if cost is not None
            ]

            if options:
                _, points, link.channel = min(options, key=lambda option: option[0])
                link.points = self.simplify(points)
            else:
                self.rebuild(link, start, end)

            self.routed.append(link)

        self.nest()

    @staticmethod
    def trunk(first, second):
        """
        Tells, whether two lines leave the same side of the same table, so
        they share a trunk: their first stretch runs together, and they part
        only where they go on to their own tables.

        Args:
            first (Link): One line.
            second (Link): The other line.

        Returns:
            bool: True, when the lines share the trunk.
        """
        return first.source is second.source and first.sides[0] == second.sides[0]

    def bundle(self):
        """
        Groups the lines, that leave one side of a table, into one trunk: they
        use the same channel near the table, so their stretches run together,
        and they split only at the tables, that they go to.

        Rules:
        - Lines of one side use the channel, that most of them use.
        - A line keeps its own route, when the trunk does not fit it.
        - Overlap on the trunk is the intended look and is not an error.
        """
        groups = {}

        for link in self.links:
            groups.setdefault((link.source.key, link.sides[0]), []).append(link)

        for links in groups.values():
            channels = [link.channel for link in links if link.channel is not None]

            if len(links) < 2 or not channels:
                continue

            channel = Counter(channels).most_common(1)[0][0]

            for link in links:
                start, end = link.points[0], link.points[-1]
                facing = link.sides[0] != link.sides[1]

                if facing and not min(start[0], end[0]) < channel < max(start[0], end[0]):
                    continue

                points = self.simplify(self.bridge(start, end, 0, channel))

                if self.cost(link, points, *link.sides) is not None:
                    link.points, link.channel = points, channel

    def nest(self):
        """
        Orders the channels of the lines between the same two tables, so that
        they do not cross each other, like steps of a staircase.

        Rules:
        - Only lines with the same sides, the same direction (down or up) and a
          route of 3 stretches (a Z) are ordered, and only among the channels
          they use already.
        - Lines running down: the higher the start, the farther the channel
          from the source. Lines running up: the lower the start, the farther.
        - The new routes must not go through a table and must not run on each
          other. Otherwise the group stays.
        """
        groups = {}

        for link in self.links:
            points = link.points

            if len(points) != 4 or link.sides[0] == link.sides[1]:
                continue
            if abs(points[0][1] - points[1][1]) > 0.5 or abs(points[1][0] - points[2][0]) > 0.5 or abs(points[2][1] - points[3][1]) > 0.5:
                continue
            if abs(points[0][1] - points[3][1]) < 1:
                continue

            direction = 1 if points[3][1] > points[0][1] else -1
            groups.setdefault((link.source.key, link.target.key, link.sides, direction), []).append(link)

        for (_, _, _, direction), links in groups.items():
            if len(links) < 2:
                continue

            source = links[0].points[0][0]
            channels = sorted((link.points[1][0] for link in links), key=lambda value: -abs(value - source))
            ordered = sorted(links, key=lambda link: link.points[0][1] * direction)
            routes = []

            for link, channel in zip(ordered, channels):
                start, end = link.points[0], link.points[-1]
                points = [start, (channel, start[1]), (channel, end[1]), end]

                if self.cost(link, points, *link.sides) is None:
                    routes = []
                    break

                routes.append((link, points, channel))

            if self.runs_on([points for _, points, _ in routes]):
                continue

            for link, points, channel in routes:
                link.points, link.channel = points, channel

    @staticmethod
    def runs_on(routes):
        """
        Checks, whether two of the routes run on each other.

        Args:
            routes (float[2][][]): The routes.

        Returns:
            bool: True, when two of them share a stretch.
        """
        return any(
            GEOMETRY.collinear_overlap(a, b, c, d) > 1
            for number, first in enumerate(routes)
            for second in routes[number + 1:]
            for a, b in zip(first, first[1:])
            for c, d in zip(second, second[1:])
        )

    def overlap(self, points):
        """
        Measures, how long a route runs on the lines routed before it.

        Args:
            points (float[2][]): The route.

        Returns:
            float: Length of the common stretches.
        """
        return sum(
            GEOMETRY.collinear_overlap(a, b, c, d)
            for other in self.routed
            for a, b in zip(points, points[1:])
            for c, d in zip(other.points, other.points[1:])
        )

    def unify(self):
        """
        Gives the lines between the same two tables the sides, that most of
        them have, when a route exists for each moved line.
        """
        bundles = {}

        for link in self.links:
            bundles.setdefault((link.source.key, link.target.key), []).append(link)

        for links in bundles.values():
            counts = Counter(link.sides for link in links)
            facing = {sides: number for sides, number in counts.items() if sides[0] != sides[1]}
            sides = max((facing or counts).items(), key=lambda item: item[1])[0]

            for link in links:
                if link.sides != sides:
                    self.reside(link, sides)

    def reside(self, link, sides):
        """
        Routes a line again between other sides of its tables.

        Args:
            link (Link): The line.
            sides (tuple[str, str]): Side of the source and of the target.

        Returns:
            bool: True, when a route exists, and the line took it.
        """
        start, finish = self.row_port(link, 0, sides[0]), self.row_port(link, 1, sides[1])
        options = [
            (cost, points, channel)
            for points, channel in self.candidates(start, sides[0], finish, sides[1])
            for cost in [self.cost(link, points, *sides)] if cost is not None
        ]

        if not options:
            return False

        _, link.points, link.channel = min(options, key=lambda option: option[0])
        link.sides = tuple(sides)

        return True

    def sides(self):
        """
        Lists the ends, that lie on every side of every table.

        Returns:
            dict[]: (table, side) and the list of (link, end).
        """
        found = {}

        for link in self.links:
            for end, box in enumerate((link.source, link.target)):
                found.setdefault((box.key, link.sides[end]), []).append((link, end))

        return found

    def separate(self):
        """
        Moves ends, that have no room on their side, to the other side of
        their table, one by one, while a route for the moved line exists.
        """
        for _ in range(len(self.links) * 3):
            crowded = [pair for items in self.sides().values() for pair in self.conflicts(items)]

            if not crowded:
                return
            if not any(self.flip(link, end) for pair in crowded for link, end in reversed(pair)):
                return

    def crowded(self):
        """
        Lists the tables, that have a side with ends of lines without room.

        Returns:
            set[str]: Keys of the tables.
        """
        return {key for (key, _), items in self.sides().items() if self.conflicts(items)}

    def conflicts(self, items):
        placed = self.place(items)

        return [
            (first[1:], second[1:]) for first, second in zip(placed, placed[1:])
            if second[0] - first[0] < SIZES["end_gap"] - 0.5
        ]

    def flip(self, link, end):
        """
        Tries to move one end of a line to the other side of its table, when
        that side has room for it.

        Args:
            link (Link): The line.
            end (int): 0 for its start, 1 for its end.

        Returns:
            bool: True, when the end moved.
        """
        sides = list(link.sides)
        sides[end] = "L" if sides[end] == "R" else "R"
        box = (link.source, link.target)[end]
        others = self.sides().get((box.key, sides[end]), [])

        if self.conflicts(others + [(link, end)]) and not self.conflicts(others):
            return False

        return self.reside(link, sides)

    def row_port(self, link, end, side, y=None):
        box = (link.source, link.target)[end]
        left, top, right, _ = box.box()

        return left if side == "L" else right, self.row_middle(link, end) if y is None else y

    @staticmethod
    def half(link, end):
        """
        Finds how far an end can move from the middle of its row, to stay inside it.

        Args:
            link (Link): The line.
            end (int): 0 for its source, 1 for its target.

        Returns:
            float: Half of the row, less 3 px for the border.
        """
        box = (link.source, link.target)[end]

        return row_size(box, link.rows[end]) / 2 - 3

    def row_middle(self, link, end):
        box = (link.source, link.target)[end]

        return box_row_middle(box, link.rows[end])

    def place(self, items):
        """
        Places the ends on one side of a table.

        Rules:
        - An end starts at the middle of its row and stays inside the row,
          3 px from its borders.
        - Two ends stand at least `end_gap` apart, when the rows have room.

        Args:
            items (tuple[Link, int][]): The lines and their ends on the side.

        Returns:
            tuple[float, Link, int][]: The height of every end, sorted.
        """
        order = sorted(items, key=lambda item: (
            self.row_middle(*item), item[0].target.y if item[1] == 0 else item[0].source.y,
        ))
        middles = [self.row_middle(*item) for item in order]
        halves = [self.half(*item) for item in order]
        heights = list(middles)

        for _ in range(4):
            for index in range(1, len(heights)):
                heights[index] = min(max(heights[index], heights[index - 1] + SIZES["end_gap"]), middles[index] + halves[index])
            for index in range(len(heights) - 2, -1, -1):
                heights[index] = max(min(heights[index], heights[index + 1] - SIZES["end_gap"]), middles[index] - halves[index])

        return [(height, link, end) for height, (link, end) in zip(heights, order)]

    def ports(self):
        """
        Finds the end of every line in the row of its column.

        Returns:
            dict[]: (id of the link, end) and the point.
        """
        ports = {}

        for (key, side), items in self.sides().items():
            for height, link, end in self.place(items):
                ports[(id(link), end)] = self.row_port(link, end, side, height)

        self.straighten(ports)

        return ports

    def straighten(self, ports):
        """
        Gives the two ends of a line between facing sides one common height,
        so the line is straight.

        Rules:
        - The height of one of the two ends is tried first, so only the other
          end moves, and then the height between them.
        - Both ends stay inside their rows, 3 px from the borders.
        - Every other end on those sides stays `end_gap` away.
        - The straight line does not go through another table.

        Args:
            ports (dict[]): Ends of the lines, changed in place.
        """
        sides = self.sides()

        for link in self.links:
            if link.sides[0] == link.sides[1]:
                continue

            start, end = ports[(id(link), 0)], ports[(id(link), 1)]
            half = [row_size(box, link.rows[index]) / 2 - 3 for index, box in enumerate((link.source, link.target))]
            low = max(self.row_middle(link, 0) - half[0], self.row_middle(link, 1) - half[1])
            high = min(self.row_middle(link, 0) + half[0], self.row_middle(link, 1) + half[1])

            if abs(start[1] - end[1]) < 0.5 or low > high:
                continue

            others = [
                ports[(id(other), number)][1]
                for index, box in enumerate((link.source, link.target))
                for other, number in sides[(box.key, link.sides[index])]
                if other is not link
            ]

            for height in (end[1], start[1], (start[1] + end[1]) / 2):
                points = [(start[0], height), (end[0], height)]

                if low <= height <= high and all(abs(value - height) >= SIZES["end_gap"] - 0.01 for value in others) and not any(
                    GEOMETRY.polyline_hits_box(points, box.box(ROUTING["clearance"]))
                    for box in self.boxes.values() if box not in (link.source, link.target)
                ):
                    ports[(id(link), 0)], ports[(id(link), 1)] = points
                    break
