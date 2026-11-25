---
name: docx-to-pdf
description: Converts a Word (.docx) file anywhere in the repository to a PDF that keeps the Word layout, using LibreOffice through the docx_to_pdf.py script. Works on macOS, Windows and Linux. Use when the user asks to export, convert or save a .docx file as PDF.
---

# DOCX to PDF

Converts one `.docx` file to a PDF with the layout of the Word file. The PDF is
written next to the source. The source is never changed or deleted.

## Input

A path to a `.docx` file, for example
`spec/requirements/artifacts/requirements_matrix.docx`.

## Steps

1. Run the script from the project root. Use `python3`, or `python` on Windows:

   ```
   python3 .claude/skills/docx-to-pdf/scripts/docx_to_pdf.py <input.docx>
   ```

   Add `--force` only after the user agrees to overwrite an existing PDF.
2. If the script fails, report the printed reason. It skips launchers, that
   point to a missing LibreOffice. When no working installation is found, give
   the command for the user's system:
   - macOS: `brew install --cask libreoffice`
   - Windows: `winget install TheDocumentFoundation.LibreOffice`
   - Debian, Ubuntu: `sudo apt install libreoffice`
3. Open the PDF and compare the tables and columns with the source. Never use
   pandoc as a replacement, because it loses the Word layout.
4. If the PDF is an official document, move it to the `documents/` folder of its
   level. Ask before replacing a PDF there.
5. Report the two paths to the user.

## Notes

- Fonts can differ slightly, if they are not installed on the machine.
- A `.docx` with a password cannot be converted. Tell the user that.
