import hashlib
import re
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from docx_to_pdf import DocxToPdfConverter

from const.general import PATHS, PDF_PAGE, REQUIREMENT_ID

DRAW = "{urn:oasis:names:tc:opendocument:xmlns:drawing:1.0}"
FO = "{urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0}"
STYLE = "{urn:oasis:names:tc:opendocument:xmlns:style:1.0}"
TEXT = "{urn:oasis:names:tc:opendocument:xmlns:text:1.0}"


class RequirementsMatrix:
    """
    Requirements matrix, that is the source of the ERD. When the official
    matrix exists in the documents, then no other matrix can be used.

    Args:
        root (Path): Root of the repository.
        given (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, root, given=None):
        self.root = root
        self.official = self.find_official()
        self.path = self.choose_source(given)
        self.file = self.path.as_posix()

        if self.root in self.path.parents:
            self.file = self.path.relative_to(self.root).as_posix()

    def __call__(self):
        """
        Reads the matrix.

        Returns:
            RequirementsMatrix: Matrix with its lines, ids and checksum.
        """
        self.sha256 = hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.lines = self.read_lines()
        self.text = re.sub(r"\s+", " ", " ".join(self.lines)).casefold()
        self.ids = sorted(set(re.findall(REQUIREMENT_ID, " ".join(self.lines))))

        if not self.ids:
            raise RuntimeError(
                f"No requirement ids (R01, R02, ...) can be read from {self.file}. "
                "The file may be a scan. Ask the user for a text version."
            )

        return self

    def find_official(self):
        files = sorted(
            (self.root / PATHS["matrix_dir"]).glob(f"{PATHS['matrix_name']}.*"),
            key=lambda path: (path.suffix.lower() != ".pdf", path.name)
        )

        return files[0].resolve() if files else None

    def choose_source(self, given):
        given = Path(given).resolve() if given else None

        if self.official:
            if given and given != self.official:
                raise RuntimeError(
                    f"The official matrix exists, so it must be used: {self.official}"
                )
            return self.official

        if given is None:
            raise RuntimeError(
                f"There is no {PATHS['matrix_name']} in {PATHS['matrix_dir']}. "
                "Ask the user for a matrix and give it with --matrix."
            )
        if not given.is_file():
            raise RuntimeError(f"File not found: {given}")

        return given

    def read_lines(self):
        suffix = self.path.suffix.lower()

        if suffix in (".md", ".txt", ".csv"):
            return self.path.read_text(encoding="utf-8").splitlines()
        if suffix == ".pdf":
            return [line for page in read_pdf_pages(self.path) for line in page]
        if suffix == ".docx":
            with tempfile.TemporaryDirectory() as work:
                pdf = Path(work, "matrix.pdf")
                DocxToPdfConverter()(self.path, pdf)

                return [line for page in read_pdf_pages(pdf) for line in page]

        raise RuntimeError(f"Unsupported format of the matrix: {suffix}")


def read_pdf_pages(path):
    """
    Reads text of a PDF with LibreOffice Draw.

    Args:
        path (Path): Path of the PDF.

    Returns:
        str[pages][lines]: Lines of text of every page.
    """
    pages = []

    for page in read_pdf_tree(path).iter(f"{DRAW}page"):
        lines = ["".join(p.itertext()).strip() for p in page.iter(f"{TEXT}p")]
        pages.append([line for line in lines if line])

    return pages


def read_pdf_size(path):
    """
    Reads the size of the first page of a PDF with LibreOffice Draw.

    Args:
        path (Path): Path of the PDF.

    Returns:
        float[2]: Width and height of the page in points.

    Raises:
        RuntimeError: The PDF has no readable page size.
    """
    for layout in read_pdf_tree(path).iter(f"{STYLE}page-layout-properties"):
        values = [layout.get(f"{FO}page-{side}", "") for side in ("width", "height")]
        found = [re.fullmatch(r"([\d.]+)(cm|mm|in|pt)", value) for value in values]

        if all(found):
            return tuple(
                float(match.group(1)) * PDF_PAGE["units"][match.group(2)] for match in found
            )

    raise RuntimeError(f"The page size of {path} cannot be read")


def read_pdf_tree(path):
    """
    Converts a PDF to the XML of LibreOffice Draw.

    Args:
        path (Path): Path of the PDF.

    Returns:
        Element: Root element of the document.
    """
    with tempfile.TemporaryDirectory() as work:
        drawing = Path(work, "pages.fodg")
        DocxToPdfConverter().export(path, drawing, "fodg")

        return ET.parse(drawing).getroot()
