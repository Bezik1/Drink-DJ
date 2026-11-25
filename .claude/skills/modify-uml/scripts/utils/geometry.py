import math


def boxes_overlap(first, second, margin=0):
    return (
        first[0] - margin < second[2] and second[0] - margin < first[2] and
        first[1] - margin < second[3] and second[1] - margin < first[3]
    )


def clip_to_box(inside, toward, box):
    """
    Finds the point, where a line leaves a rectangle.

    Args:
        inside (float[2]): Point inside the box.
        toward (float[2]): Point, to which the line goes.
        box (float[4]): Left, top, right and bottom side of the rectangle.

    Returns:
        float[2]: Point on the border of the rectangle.
    """
    dx, dy = toward[0] - inside[0], toward[1] - inside[1]
    scales = []

    if dx:
        scales.append(((box[2] if dx > 0 else box[0]) - inside[0]) / dx)
    if dy:
        scales.append(((box[3] if dy > 0 else box[1]) - inside[1]) / dy)
    if not scales:
        return inside

    scale = min(scales)

    return inside[0] + dx * scale, inside[1] + dy * scale


def segment_hits_box(start, end, box):
    """
    Checks, whether a segment goes through a box.

    Args:
        start (float[2]): Start point of the segment.
        end (float[2]): End point of the segment.
        box (float[4]): Left, top, right and bottom side of the box.

    Returns:
        bool: True, if the segment goes through the box.
    """
    low, high = 0, 1

    for axis in range(2):
        delta = end[axis] - start[axis]

        if abs(delta) < 1e-9:
            if not box[axis] < start[axis] < box[axis + 2]:
                return False
            continue

        first = (box[axis] - start[axis]) / delta
        second = (box[axis + 2] - start[axis]) / delta

        low = max(low, min(first, second))
        high = min(high, max(first, second))

        if low >= high:
            return False

    return True


def orientation(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def segments_cross(a, b, c, d):
    return (
        orientation(a, b, c) * orientation(a, b, d) < -1e-6 and
        orientation(c, d, a) * orientation(c, d, b) < -1e-6
    )


def midpoint(first, second, fraction=0.5):
    return (
        first[0] + (second[0] - first[0]) * fraction,
        first[1] + (second[1] - first[1]) * fraction,
    )


def normal(start, end):
    """
    Finds the unit vector perpendicular to a line, pointing to its left.

    Args:
        start (float[2]): Start of the line.
        end (float[2]): End of the line.

    Returns:
        float[2]: Unit vector.
    """
    length = math.dist(start, end) or 1

    return (start[1] - end[1]) / length, (end[0] - start[0]) / length


def point_segment_distance(point, start, end):
    """
    Measures the distance between a point and a segment.

    Args:
        point (float[2]): The point.
        start (float[2]): Start of the segment.
        end (float[2]): End of the segment.

    Returns:
        float: Shortest distance.
    """
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = dx * dx + dy * dy
    fraction = 0 if not length else max(0, min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / length))

    return math.dist(point, (start[0] + dx * fraction, start[1] + dy * fraction))


def polyline_length(points):
    return sum(math.dist(first, second) for first, second in zip(points, points[1:]))


def point_along(points, distance):
    """
    Finds the point at a distance from the start of a polyline.

    Args:
        points (float[2][]): Corners of the polyline.
        distance (float): Distance along the line from its start.

    Returns:
        float[2]: The point.
    """
    for first, second in zip(points, points[1:]):
        length = math.dist(first, second)

        if distance <= length and length:
            return midpoint(first, second, distance / length)

        distance -= length

    return points[-1]


def polyline_hits_box(points, box):
    return any(segment_hits_box(first, second, box) for first, second in zip(points, points[1:]))


def collinear_overlap(first, second, third, fourth):
    """
    Measures how long two axis-parallel segments lie on one line.

    Args:
        first (float[2]): Start of the first segment.
        second (float[2]): End of the first segment.
        third (float[2]): Start of the second segment.
        fourth (float[2]): End of the second segment.

    Returns:
        float: Length of the common part, 0 when they are apart.
    """
    for axis in (0, 1):
        other = 1 - axis

        if (
            abs(first[axis] - second[axis]) < 1e-6 and abs(third[axis] - fourth[axis]) < 1e-6
            and abs(first[axis] - third[axis]) < 2
        ):
            low = max(min(first[other], second[other]), min(third[other], fourth[other]))
            high = min(max(first[other], second[other]), max(third[other], fourth[other]))

            return max(0, high - low)

    return 0


def rectangles_overlap(first, second):
    return (
        first[0] < second[2] and second[0] < first[2] and
        first[1] < second[3] and second[1] < first[3]
    )
