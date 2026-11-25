class Box:
    """
    Box of the diagram: a class, an enumeration, a data type or a note.

    Args:
        key (str): Key of the element in the model.
        kind (str): class, enumeration, dataType or note.
        title (str): Name of the class, or text of the note.
        lines (str[]): Lines of the attributes, of the values or of the note.
        size (float[2]): Width and height.
        header (float): Height of the header.
    """

    def __init__(self, key, kind, title, lines, size, header=0):
        self.key = key
        self.kind = kind
        self.title = title
        self.lines = lines
        self.width, self.height = size
        self.header = header
        self.underlined = {}
        self.operations = []
        self.operations_height = 0
        self.x = 0
        self.y = 0

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
