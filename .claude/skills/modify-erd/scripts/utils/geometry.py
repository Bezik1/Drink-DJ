import math


def text_width(text, size, bold=False):
    width = sum(
        0.28 if char in "iljtfI.,:;!|'()[]-/ " else
        0.36 if char == "r" else
        0.85 if char in "mwMW@%" else
        0.68 if char.isupper() else
        0.56
        for char in text
    )

    return width * size * (1.08 if bold else 1)


def boxes_overlap(first, second):
    return (
        first[0] < second[2] and second[0] < first[2] and
        first[1] < second[3] and second[1] < first[3]
    )


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
    if (
        max(start[0], end[0]) <= box[0] or min(start[0], end[0]) >= box[2] or
        max(start[1], end[1]) <= box[1] or min(start[1], end[1]) >= box[3]
    ):
        return False

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


def path_hits_box(points, box):
    """
    Checks, whether a path of straight pieces goes through a box.

    Args:
        points (float[2][]): Points of the path.
        box (float[4]): Left, top, right and bottom side of the box.

    Returns:
        bool: True, if a piece of the path goes through the box.
    """
    return any(
        segment_hits_box(start, end, box) for start, end in zip(points, points[1:])
    )


def paths_cross(first, second):
    """
    Checks, whether two paths of straight pieces cross each other.

    Args:
        first (float[2][]): Points of the first path.
        second (float[2][]): Points of the second path.

    Returns:
        bool: True, if two of their pieces cross.
    """
    if not boxes_overlap(points_box(first), points_box(second)):
        return False

    return any(
        segments_cross(a, b, c, d)
        for a, b in zip(first, first[1:])
        for c, d in zip(second, second[1:])
    )


def points_box(points):
    return (
        min(x for x, _ in points) - 1e-6,
        min(y for _, y in points) - 1e-6,
        max(x for x, _ in points) + 1e-6,
        max(y for _, y in points) + 1e-6,
    )


def union_box(boxes):
    boxes = list(boxes)

    return (
        min(box[0] for box in boxes),
        min(box[1] for box in boxes),
        max(box[2] for box in boxes),
        max(box[3] for box in boxes),
    )


def angle_difference(first, second):
    return abs((first - second + 180) % 360 - 180)


def angle_between(center, first, second):
    first_angle = math.atan2(first[1] - center[1], first[0] - center[0])
    second_angle = math.atan2(second[1] - center[1], second[0] - center[0])
    difference = abs(math.degrees(first_angle - second_angle)) % 360

    return min(difference, 360 - difference)
