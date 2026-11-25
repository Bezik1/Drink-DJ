"""
Creation and reading of Word (.docx) files, that are described in a JSON file.
The look is the one of the requirements matrix: landscape A4, Arial, black text
and bordered tables with a bold header. Only the standard library is used, so
it works on macOS, Windows and Linux.
"""
import argparse
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape, unescape

sys.dont_write_bytecode = True

CREATOR = "modify-word"
NAMESPACE = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
PAGE = {"portrait": (11906, 16838), "landscape": (16838, 11906)}
MARGIN = 1440
FONT = "Arial"
FONT_SIZE = 12
WIDE_TABLE_FONT_SIZE = 10
WIDE_TABLE_COLUMNS = 5
BLOCKS = ["heading", "paragraph", "bullets", "table"]

CONTENT_TYPES = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '</Types>'
)

ROOT_RELATIONSHIPS = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '</Relationships>'
)

DOCUMENT_RELATIONSHIPS = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
    '</Relationships>'
)

CORE = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>{title}</dc:title>'
    f'<dc:creator>{CREATOR}</dc:creator></cp:coreProperties>'
)

NUMBERING = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<w:numbering {NAMESPACE}>'
    '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/>'
    '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/>'
    '<w:lvlJc w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="283"/></w:pPr></w:lvl></w:abstractNum>'
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>'
)


def style(identifier, name, size, bold=False, before=0, after=120):
    weight = "<w:b/><w:bCs/>" if bold else ""

    return (
        f'<w:style w:type="paragraph" w:styleId="{identifier}"><w:name w:val="{name}"/>'
        f'<w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/>'
        f'<w:spacing w:before="{before}" w:after="{after}"/></w:pPr>'
        f'<w:rPr>{weight}<w:sz w:val="{size}"/><w:szCs w:val="{size}"/></w:rPr></w:style>'
    )


STYLES = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<w:styles {NAMESPACE}>'
    f'<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}" w:cs="{FONT}"/>'
    f'<w:color w:val="000000"/><w:sz w:val="{2 * FONT_SIZE}"/><w:szCs w:val="{2 * FONT_SIZE}"/></w:rPr></w:rPrDefault></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="120"/></w:pPr></w:style>'
    + style("Title", "Title", 40, True, 0, 240)
    + style("Heading1", "heading 1", 32, True, 360, 120)
    + style("Heading2", "heading 2", 28, True, 240, 100)
    + style("Heading3", "heading 3", 24, True, 200, 80)
    + '</w:styles>'
)


class WordDocument:
    """
    Word document, that is built from a JSON description.

    Rules:
    - `title` is the title of the document, written in its properties and, unless
      `"show_title": false`, as its first line. The page is landscape, as in the
      other documents of the project, unless `"landscape": false`.
    - A table with 5 or more columns has text of 10 pt, a smaller one of 12 pt.
    - `blocks` is a list of: `{"type": "heading", "level": 1, "text": ""}`,
      `{"type": "paragraph", "text": ""}`, `{"type": "bullets", "items": []}`
      and `{"type": "table", "header": [], "rows": [[]]}`.
    - A text can have a line break `\\n`. A paragraph can be `"bold": true`.

    Args:
        spec (dict[]): Description of the document.
    """

    def __init__(self, spec):
        self.spec = spec

    def __call__(self, target, force=False):
        """
        Writes the .docx file.

        Args:
            target (Path): Path of the new file.
            force (bool, optional): Overwrite a file, that was not made by this
                skill. Default: False.

        Returns:
            Path: Path of the written file.
        """
        self.check()

        if target.exists() and not force and not self.is_own(target):
            raise RuntimeError(
                f"{target} was not made by modify-word. Ask the user, before using --force."
            )

        title = self.spec["title"]
        landscape = self.spec.get("landscape", True)
        width, height = PAGE["landscape" if landscape else "portrait"]
        self.width = width - 2 * MARGIN
        body = [self.paragraph(title, "Title")] if self.spec.get("show_title", True) else []

        for block in self.spec.get("blocks", []):
            body.extend(getattr(self, f"build_{block['type']}")(block))

        orientation = ' w:orient="landscape"' if landscape else ""
        section = (
            f'<w:sectPr><w:pgSz w:w="{width}" w:h="{height}"{orientation}/>'
            f'<w:pgMar w:top="{MARGIN}" w:right="{MARGIN}" w:bottom="{MARGIN}" w:left="{MARGIN}" '
            'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
        )
        document = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<w:document {NAMESPACE}><w:body>{"".join(body)}{section}</w:body></w:document>'
        )

        target.parent.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("[Content_Types].xml", CONTENT_TYPES)
            archive.writestr("_rels/.rels", ROOT_RELATIONSHIPS)
            archive.writestr("docProps/core.xml", CORE.format(title=escape(title)))
            archive.writestr("word/document.xml", document)
            archive.writestr("word/_rels/document.xml.rels", DOCUMENT_RELATIONSHIPS)
            archive.writestr("word/styles.xml", STYLES)
            archive.writestr("word/numbering.xml", NUMBERING)

        return target

    def check(self):
        if not self.spec.get("title"):
            raise RuntimeError("The description needs a 'title'")

        for block in self.spec.get("blocks", []):
            if block.get("type") not in BLOCKS:
                raise RuntimeError(f"Unknown block type: {block.get('type')}. Use {BLOCKS}")
            if block["type"] == "table" and not block.get("header"):
                raise RuntimeError("A table needs a 'header'")
            if block["type"] == "table" and any(
                len(row) != len(block["header"]) for row in block.get("rows", [])
            ):
                raise RuntimeError("Every row of a table needs as many cells as its header")

    @staticmethod
    def is_own(path):
        try:
            with zipfile.ZipFile(path) as archive:
                return CREATOR in archive.read("docProps/core.xml").decode("utf-8")
        except (OSError, KeyError, zipfile.BadZipFile):
            return False

    @staticmethod
    def runs(text, bold=False, size=None):
        weight = ("<w:b/><w:bCs/>" if bold else "") + (
            f'<w:sz w:val="{2 * size}"/><w:szCs w:val="{2 * size}"/>' if size else ""
        )
        weight = f"<w:rPr>{weight}</w:rPr>" if weight else ""
        parts = str(text).split("\n")

        return "".join(
            f'<w:r>{weight}{"<w:br/>" if index else ""}<w:t xml:space="preserve">{escape(part)}</w:t></w:r>'
            for index, part in enumerate(parts)
        )

    def paragraph(self, text, style_id=None, bold=False, extra="", size=None):
        properties = f'<w:pStyle w:val="{style_id}"/>' if style_id else ""

        return f"<w:p><w:pPr>{properties}{extra}</w:pPr>{self.runs(text, bold, size)}</w:p>"

    def build_heading(self, block):
        return [self.paragraph(block["text"], f"Heading{min(3, max(1, int(block.get('level', 1))))}")]

    def build_paragraph(self, block):
        return [self.paragraph(block["text"], bold=block.get("bold", False))]

    def build_bullets(self, block):
        numbering = '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>'

        return [self.paragraph(item, extra=numbering) for item in block["items"]]

    def build_table(self, block):
        """
        Builds a table of the look of the requirements matrix: borders, a bold
        header, that repeats on every page, and rows, that do not split.

        Args:
            block (dict[]): Block with `header`, `rows` and optional `widths`.

        Returns:
            str[]: The table and an empty paragraph after it.
        """
        columns = len(block["header"])
        size = FONT_SIZE if columns < WIDE_TABLE_COLUMNS else WIDE_TABLE_FONT_SIZE
        borders = "".join(
            f'<w:{side} w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
            for side in ("top", "left", "bottom", "right", "insideH", "insideV")
        )
        weights = block.get("widths") or [1] * columns
        widths = [round(self.width * weight / sum(weights)) for weight in weights]
        grid = "".join(f'<w:gridCol w:w="{width}"/>' for width in widths)
        rows = [self.row(block["header"], widths, size, header=True)]
        rows.extend(self.row(row, widths, size) for row in block.get("rows", []))

        return [
            f'<w:tbl><w:tblPr><w:tblW w:w="{sum(widths)}" w:type="dxa"/><w:jc w:val="center"/>'
            f'<w:tblBorders>{borders}</w:tblBorders><w:tblLayout w:type="fixed"/>'
            f'<w:tblCellMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/>'
            f'</w:tblCellMar></w:tblPr><w:tblGrid>{grid}</w:tblGrid>{"".join(rows)}</w:tbl>',
            self.paragraph(""),
        ]

    def row(self, cells, widths, size, header=False):
        marks = "<w:trPr><w:cantSplit/>" + ("<w:tblHeader/>" if header else "") + "</w:trPr>"
        spacing = '<w:spacing w:before="0" w:after="0"/>'
        content = "".join(
            f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/></w:tcPr>'
            f'{self.paragraph(cell, bold=header, extra=spacing, size=size)}</w:tc>'
            for cell, width in zip(cells, widths)
        )

        return f"<w:tr>{marks}{content}</w:tr>"


def read_text(path):
    """
    Reads the text of a .docx file.

    Args:
        path (Path): Path of the file.

    Returns:
        str[]: Text of every paragraph.
    """
    try:
        with zipfile.ZipFile(path) as archive:
            document = archive.read("word/document.xml").decode("utf-8")
    except (OSError, KeyError, zipfile.BadZipFile):
        raise RuntimeError(f"{path} is not a Word document")

    lines = []

    for paragraph in re.findall(r"<w:p[ >].*?</w:p>", document, re.S):
        parts = re.findall(r"<w:t[^>]*>(.*?)</w:t>|(<w:br/>)", paragraph, re.S)
        text = "".join("\n" if br else unescape(value) for value, br in parts)

        lines.append(text)

    return lines


def parse_args():
    parser = argparse.ArgumentParser(description="Create and read Word documents.")
    parser.add_argument("command", choices=["create", "text"])
    parser.add_argument("file", type=Path, help="JSON description for create, .docx for text")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--force", action="store_true")

    args = parser.parse_args()

    if args.command == "create" and args.out is None:
        parser.error("--out is required")

    return args


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        if args.command == "create":
            spec = json.loads(args.file.read_text(encoding="utf-8"))

            print(f"Document: {WordDocument(spec)(args.out, args.force)}")
        else:
            print("\n".join(read_text(args.file)))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(1)
