---
name: modify-word
description: Creates a Word (.docx) file from a JSON description with headings, paragraphs, bullet lists and tables, or reads the text of a .docx file. Works on macOS, Windows and Linux without Word. Use when the user asks to create, write or regenerate a Word document, for example the constraints of a UML diagram, and then use docx-to-pdf to export its PDF.
---

# Create a Word document

`modify_word.py` builds a `.docx` from a JSON description, so the document is
always made again from its description and never edited by hand. It uses only
the Python standard library and needs no Word.

`<skill>` is `.claude/skills/modify-word`. Use `python3`, or `python` on Windows.

## How the document looks

The look is the one of the other Word and PDF documents of the project, for
example `requirements_matrix`: landscape A4 with 2.54 cm margins, Arial 12 pt,
black text, and bordered tables with a bold header and no colour. A table with 5
or more columns has 10 pt text. The header of a table repeats on every page and
a row does not split between pages. Do not add colours, shading or other fonts.

## Which skill to use

| Task | Skill |
| --- | --- |
| A new Word file, or a change of the text of one made by this skill | `modify-word` |
| The PDF of a Word file | `docx-to-pdf` |
| The constraints, that a UML diagram cannot show | `uml-constraints`, which uses this skill |

## 1. Write the description

```json
{
  "title": "Title of the document",
  "blocks": [
    {"type": "heading", "level": 1, "text": "Section"},
    {"type": "paragraph", "text": "Text, with a line break\nin the middle.", "bold": false},
    {"type": "bullets", "items": ["First", "Second"]},
    {"type": "table", "header": ["Name", "Value"], "widths": [1, 3], "rows": [["a", "b"]]}
  ]
}
```

- `title` is required, and it is the first line of the document. With
  `"show_title": false` it is only in the properties of the file, and the
  document starts with its first block, as `requirements_matrix` does.
  The page is landscape. `"landscape": false` is for a
  document, that has no wide table.
- Block types are `heading` (level 1 to 3), `paragraph`, `bullets` and `table`.
  Every row of a table has as many cells as its header, and `widths` are
  relative.
- Write the description to a temporary folder, not to the repository.

## 2. Create the file

```
python3 <skill>/scripts/modify_word.py create <description.json> --out <path/name.docx>
```

- A file made by this skill is replaced. A file made by someone else is not,
  unless the user agrees to `--force`.
- The name is lowercase, with words separated by underscores. A Word file of
  the specification goes to the `artifacts/` folder of its design level, for
  example `spec/conceptual/artifacts/`.

## 3. Export the PDF

Use the `docx-to-pdf` skill on the new file:

```
python3 .claude/skills/docx-to-pdf/scripts/docx_to_pdf.py <path/name.docx>
```

The official PDF goes to the `documents/` folder of the same design level, as
the `drawio-to-pdf` flow does. Open it and look at it.

## 4. Check

```
python3 <skill>/scripts/modify_word.py text <path/name.docx>
```

It prints the text of every paragraph and table cell, so that the content can be
checked without opening Word.
