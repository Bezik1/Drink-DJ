---
name: validate-erd
description: Validates a Chen-notation ERD (.drawio) against the requirements matrix from spec/requirements/documents. Checks the notation, the layout, the model, the official PDF and the coverage of the requirements. Use when the user asks to validate, check or review an ERD, and as the last step of modify-erd and requirements-to-erd.
---

# Validate an ERD against the requirements matrix

`validate_erd.py` reads the finished `.drawio` file, not the model, so it also
finds changes made by hand. It does not change any file.

`<skill>` is `.claude/skills/validate-erd`. Use `python3`, or `python` on
Windows. It needs the `modify-erd`, `requirements-coverage` and `docx-to-pdf` skills, LibreOffice and
Python 3.8+.

## Run

```
python3 <skill>/scripts/validate_erd.py [diagram.drawio] [--model model.json] [--pdf official.pdf] [--matrix file]
```

Without arguments it checks `spec/conceptual/artifacts/erd.drawio`.
The model and the PDF with the same name are found in the same way, in
`artifacts/` and `spec/conceptual/documents/`. The matrix is always
`spec/requirements/documents/requirements_matrix.*`. Add
`--matrix` only when it does not exist, and then ask the user for it.

Exit code: `0` valid, `1` the diagram has errors, `2` the check could not run.

## What is checked

Errors, which make the diagram invalid:

- Every line joins two shapes, has no arrow, and joins an entity with a
  relationship or an attribute with its owner. Entities are never joined
  directly.
- An attribute has exactly one owner. A relationship joins at least 2 entities,
  and each of its ends has a cardinality like `1`, `0..1`, `1..N`, `0..M`.
- An entity has a relationship. A strong entity has a key, which is an
  underlined attribute. A weak entity has an identifying relationship, and an
  identifying relationship has a weak entity.
- No entity is drawn twice and no shapes overlap.
- With a model: the model is valid for the current matrix (checksum, every
  requirement drawn or explained in `not_drawn`), and the diagram has exactly
  the names of the model.
- With a PDF: it has 1 page and contains every name of the diagram.
- **Functional and non-functional requirements** (with a model): the file
  `spec/conceptual/artifacts/requirements_coverage.json` of the
  `requirements-coverage` skill belongs to the current
  `functional_requirements.pdf` and `non_functional_requirements.pdf` and has
  an entry for every id. Every element, that it names, exists in the ERD model (entities, attributes and relationships). A gap
  of the ERD in a **Must** requirement is an error, so the design does not meet
  that requirement yet.

Warnings and notes, which need a human decision:

- A name with a word, that is not in the matrix.
- Everything the model marks `assumed`, with its reason.
- Requirements in `not_drawn`.
- Without a model: a requirement, whose text has no word of any drawn name.
- A gap of the ERD in a Should or Could requirement, and the number of
  covered, gap and not applicable requirements.

## Report to the user

Give the result (`VALID` or `INVALID`), every error with the fix, and the
warnings that matter, mainly the assumptions and the requirement gaps. A gap
is fixed in the design, see the `requirements-coverage` skill. For a wrong diagram, that has a
model, use the `modify-erd` skill to fix the model and draw it again. Never edit
the `.drawio` file by hand to pass the check.

If the matrix has no ids like `R01`, or it is a scan, the script says so. Ask the
user for a text version.
