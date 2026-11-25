---
name: md-to-pdf
description: Converts a Markdown (.md) file anywhere in the repository to a landscape PDF with bordered tables, in the same look as the requirements matrix, using pandoc and LibreOffice through the md_to_pdf.py script. Works on macOS, Windows and Linux. Use when the user asks to export, convert or save a .md file as PDF.
---

# MD to PDF

Converts one `.md` file to a PDF with the look of `requirements_matrix.pdf`:
landscape A4, Arial, black text and bordered tables with a bold header. The PDF
is written next to the source. The source is never changed, and no `.docx` is
left in the repository.

## Input

A path to a `.md` file, for example
`spec/requirements/artifacts/functional_requirements.md`.

## Steps

1. Run the script from the project root. Use `python3`, or `python` on Windows:

   ```
   python3 .claude/skills/md-to-pdf/scripts/md_to_pdf.py <input.md>
   ```

   Add `--force` only after the user agrees to overwrite an existing PDF.
2. If the script fails, report the printed reason. For a missing program give
   the command for the user's system:

   | System | pandoc | LibreOffice |
   | --- | --- | --- |
   | macOS | `brew install pandoc` | `brew install --cask libreoffice` |
   | Windows | `winget install JohnMacFarlane.Pandoc` | `winget install TheDocumentFoundation.LibreOffice` |
   | Debian, Ubuntu | `sudo apt install pandoc` | `sudo apt install libreoffice` |

3. Open the PDF and check the first and the last page.
4. If the PDF is an official document, move it to the `documents/` folder of its
   level. Ask before replacing a PDF there.
5. Report the two paths to the user.

## What the script handles

- Widths of columns come from the content, so identifiers do not break. Never
  edit the dashes in the Markdown to set widths.
- Tables with 5 or more columns use 10 pt text, smaller ones 12 pt.
- The header repeats on every page, and rows do not split between pages.
- `<br>` is a line break. Paths of images are relative to the `.md` file.

## Notes

- Words already glued in the source, such as `availableWHEN`, stay glued. Tell
  the user instead of changing the content.
- The script needs the `docx-to-pdf` skill folder next to its own folder.
