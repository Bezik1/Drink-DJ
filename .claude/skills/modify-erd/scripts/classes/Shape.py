import math


class Shape:
    """
    Shape of the diagram, described by its center and size.

    Args:
        kind (str): entity, relationship, attribute, cardinality or note.
        text (str): Text inside the shape.
        center (float[2]): Center of the shape.
        size (float[2]): Width and height of the shape.
        style (str, optional): Name of the style. Default: kind.
    """

    def __init__(self, kind, text, center, size, style=None):
        self.kind = kind
        self.text = text
        self.x, self.y = center
        self.width, self.height = size
        self.style = style or kind
        self.side = (0, 0)
        self.partial = False

    @property
    def center(self):
        return self.x, self.y

    def box(self, margin=0):
        return (
            self.x - self.width / 2 - margin,
            self.y - self.height / 2 - margin,
            self.x + self.width / 2 + margin,
            self.y + self.height / 2 + margin,
        )

    def boundary(self, toward):
        """
        Finds the point, where the line to another point leaves the shape.

        Args:
            toward (float[2]): Point, to which the line goes.

        Returns:
            float[2]: Point on the perimeter of the shape.
        """
        dx, dy = toward[0] - self.x, toward[1] - self.y

        if not dx and not dy:
            return self.center

        x, y = abs(dx) / (self.width / 2), abs(dy) / (self.height / 2)

        if self.kind == "relationship":
            scale = x + y
        elif self.kind == "attribute":
            scale = math.hypot(x, y)
        else:
            scale = max(x, y)

        return self.x + dx / scale, self.y + dy / scale


class Line:
    """
    Line between two shapes. A diagonal line can be a gentle curve, that
    turns softly from the source to the target, like a rounded corner. The
    curve starts and ends at the same points as a straight line.

    Args:
        source (Shape): First shape.
        target (Shape): Second shape.
        cardinality (str, optional): Cardinality next to the line.
        curve (float, optional): Strength of the curve from 0 (straight) to
            1 (a full corner). Default: 0.
        straight_angle (float, optional): Lines closer than this angle in
            degrees to a horizontal or vertical line stay straight. Default: 8.
        pieces (int, optional): Number of straight pieces, that describe the
            curve in the checks. Default: 12.
        via (float[2], optional): Corner, around which the line turns. The
            line leaves the source and enters the target on the sides, that
            face the corner. Two lines of a relationship of an entity with
            itself go around two opposite corners, so they form a loop.
            Default: none.
    """

    def __init__(self, source, target, cardinality=None, curve=0, straight_angle=8, pieces=12, via=None):
        self.source = source
        self.target = target
        self.cardinality = cardinality
        self.via = via
        self.start = source.boundary(via if via else target.center)
        self.end = target.boundary(via if via else source.center)
        self.control = None

        if via:
            middle = (self.start[0] + self.end[0]) / 2, (self.start[1] + self.end[1]) / 2
            self.control = (
                middle[0] + (via[0] - middle[0]) * curve,
                middle[1] + (via[1] - middle[1]) * curve,
            )
        elif curve and self.is_diagonal(straight_angle):
            self.control = self.control_point(curve)

        self.points = self.trace(pieces)
        self.label = None
        self.label_position = 0
        self.label_offset = (0, 0)

    def is_diagonal(self, straight_angle):
        (sx, sy), (tx, ty) = self.source.center, self.target.center
        dx, dy = abs(tx - sx), abs(ty - sy)

        return min(dx, dy) > max(dx, dy) * math.tan(math.radians(straight_angle))

    def control_point(self, curve):
        """
        Rule: The control point lies between the middle of the line and the
        corner, from which the line leaves the source straight along its
        longer direction.

        Args:
            curve (float): Strength of the curve from 0 to 1.

        Returns:
            float[2]: Control point of the curve.
        """
        (sx, sy), (tx, ty) = self.start, self.target.center
        corner = (sx, ty) if abs(ty - sy) >= abs(tx - sx) else (tx, sy)
        middle = (sx + tx) / 2, (sy + ty) / 2

        return (
            middle[0] + (corner[0] - middle[0]) * curve,
            middle[1] + (corner[1] - middle[1]) * curve,
        )

    def trace(self, pieces):
        if self.control is None:
            return [self.start, self.end]

        points = []

        for index in range(pieces + 1):
            t = index / pieces
            a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t ** 2
            points.append((
                a * self.start[0] + b * self.control[0] + c * self.end[0],
                a * self.start[1] + b * self.control[1] + c * self.end[1],
            ))

        return points

    def port(self, shape, point):
        """
        Finds the relative position of an end of the line on a shape, as
        draw.io writes it in exitX, exitY, entryX and entryY.

        Args:
            shape (Shape): Source or target of the line.
            point (float[2]): End of the line on the perimeter of the shape.

        Returns:
            float[2]: Position from 0 to 1 across the width and the height.
        """
        left, top, _, _ = shape.box()

        return (point[0] - left) / shape.width, (point[1] - top) / shape.height

    def move(self, dx, dy):
        self.start = self.start[0] + dx, self.start[1] + dy
        self.end = self.end[0] + dx, self.end[1] + dy
        self.points = [(x + dx, y + dy) for x, y in self.points]

        if self.control is not None:
            self.control = self.control[0] + dx, self.control[1] + dy

    def label_base(self, fraction):
        """
        Finds the point, from which draw.io measures the offset of a label.
        draw.io places labels along the start, the control point and the end.

        Args:
            fraction (float): Position from 0 (start) to 1 (end).

        Returns:
            float[2]: The base point of the label.
        """
        path = [self.start, self.end] if self.control is None else [self.start, self.control, self.end]

        return self.point_at(fraction, path)[0]

    def point_at(self, fraction, path=None):
        """
        Finds a point on the drawn line.

        Args:
            fraction (float): Position from 0 (start) to 1 (end).
            path (float[2][], optional): Other path to measure. Default: the
                drawn line.

        Returns:
            tuple[float[2], float[2]]: The point and the unit direction there.
        """
        path = path or self.points
        pieces = list(zip(path, path[1:]))
        lengths = [math.dist(a, b) for a, b in pieces]
        distance = fraction * sum(lengths)

        for (a, b), length in zip(pieces, lengths):
            if distance <= length or (a, b) == pieces[-1]:
                ratio = distance / length if length else 0
                direction = ((b[0] - a[0]) / length, (b[1] - a[1]) / length) if length else (1, 0)

                return (a[0] + ratio * (b[0] - a[0]), a[1] + ratio * (b[1] - a[1])), direction

            distance -= length

    @property
    def shapes(self):
        return self.source, self.target

    @property
    def length(self):
        return math.dist(self.start, self.end)
