class Link:
    """
    Line between two boxes. It is a polyline of right angles.

    Args:
        kind (str): association, composition or attachment.
        source (Box): First box.
        target (Box): Second box.
        name (str, optional): Name of the association.
        ends (str[2], optional): Multiplicities at the source and at the target.
    """

    def __init__(self, kind, source, target, name=None, ends=None):
        self.kind = kind
        self.source = source
        self.target = target
        self.name = name
        self.ends = ends
        self.points = []
        self.sides = ("", "")
        self.channel = None
        self.dangling = False
        self.labels = []

    @property
    def start(self):
        return self.points[0]

    @property
    def end(self):
        return self.points[-1]
