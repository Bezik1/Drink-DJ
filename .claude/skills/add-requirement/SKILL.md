---
name: add-requirement
description: Adds new business requirements (R19, R20, ...) to the requirements matrix, written in the same style as the existing ones, and then exports the official requirements_matrix.pdf to spec/requirements/documents. Use when the user asks to add, append or write a new requirement in the requirements matrix.
---

# Add requirement

Adds one or more rows to the table of
`spec/requirements/artifacts/requirements_matrix.docx` and replaces
`spec/requirements/documents/requirements_matrix.pdf` with a new export. The
`docx-to-pdf` skill folder must be next to this one, and LibreOffice must be
installed.

## Input

The idea of the requirement in the words of the user. The user can write it
roughly, in any language. The text that goes to the matrix is always in English.

## Steps

1. Read the current matrix. Use `python3`, or `python` on Windows:

   ```
   python3 .claude/skills/add-requirement/scripts/add_requirement.py list
   ```

2. Compare the idea with the listed rows. If the matrix already says it, tell the
   user which id and stop. If it contradicts a row, or the meaning is not clear,
   ask the user before writing.
3. Write the text of every new requirement (see "Style" below). Split an idea
   with several independent facts into several requirements.
4. Show the final texts to the user and ask for approval. The Word file and the
   official PDF are replaced in the next step, so do not skip this.
5. Add them, one text per argument. The ids continue the numbering:

   ```
   python3 .claude/skills/add-requirement/scripts/add_requirement.py add "<text 1>" "<text 2>"
   ```

6. If the script fails, report the printed reason. When LibreOffice is missing,
   give the command for the user's system:
   - macOS: `brew install --cask libreoffice`
   - Windows: `winget install TheDocumentFoundation.LibreOffice`
   - Debian, Ubuntu: `sudo apt install libreoffice`
7. Open the last page of the PDF and check, that the new rows look like the old ones.
8. Report the ids with the texts and the two paths. Tell the user that the ERD
   (`requirements-to-erd`) and the functional requirements can be out of date,
   and offer to update them. Do not run them without being asked.

## Style

The existing rows are the pattern. Read all of them, before writing a new one.

- One or two short sentences in plain business language. No implementation
  words, such as database, table, API, page or button.
- The subject is a concept of the domain, named as in the matrix: Train,
  Schedule, Stop, Schedule Stop, Route, Ticket, Client, Discount, Train Operator,
  Carrier. Reuse these names, and do not invent a synonym.
- Structure and data use `should`: "Carrier should have information about its
  name and contact email." What a client can do uses `can`: "Client can like
  created configuration of routes." Do not use `shall`, because it belongs to the
  functional requirements.
- A list of attributes follows the pattern "X should have information about its
  a, b and c."
- Write in the present tense, in the third person, and end with a full stop.
- Do not put the id in the text, because the script adds it.
- Do not fix the old rows, even when they contain typos. Tell the user instead.

## Notes

- The Word file is changed in place, which is the purpose of this skill. Rows are
  copied from the last row, so the font and the widths stay the same.
- The Word file and the PDF are replaced only after the PDF has been exported
  successfully. A failure leaves both unchanged.
- A text that is already in the matrix is rejected.
