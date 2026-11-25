---
name: validate-uml
description: Validates a UML class diagram (.drawio) against the ERD and the requirements matrix from spec/requirements/documents. Checks the notation, the lines, the model, the official PDF, the constraints and the coverage of the ERD and of the requirements. Use when the user asks to validate, check or review a UML class diagram, and as the last step of erd-to-uml and modify-uml.
---

# Validate a UML class diagram

`validate_uml.py` reads the finished `.drawio` file, not the model, so it also
finds changes made by hand. It does not change any file.

`<skill>` is `.claude/skills/validate-uml`. Use `python3`, or `python` on
Windows. It needs the `modify-uml`, `uml-constraints`, `requirements-coverage`, `modify-erd`, `validate-erd`
and `docx-to-pdf` skills, LibreOffice and Python 3.8+.

## Run

```
python3 <skill>/scripts/validate_uml.py [diagram.drawio] [--model model.json] [--pdf official.pdf] [--erd erd.json] [--matrix file]
```

Without arguments it checks `spec/conceptual/artifacts/uml_class_diagram.drawio`.
The model and the PDF with the same name are found in the same way, in
`artifacts/` and `spec/conceptual/documents/`. The ERD is
`spec/conceptual/artifacts/erd.json` and the matrix is
`spec/requirements/documents/requirements_matrix.*`. Add `--erd` or `--matrix`
only when the official file does not exist, and then ask the user.

Exit code: `0` valid, `1` the diagram has errors, `2` the check could not run.

The skills `erd-to-uml` and `modify-uml` run it with their `check` command.

## What is checked

Errors, which make the diagram invalid:

- Every class has a name, drawn once. Every attribute is `+ name : Type`, and
  its type is `String`, `Integer`, `Decimal`, `Boolean`, `Date`, `Time`,
  `DateTime`, or an enumeration or a data type of the diagram.
- An enumeration has values. An association has a name, 2 classes, no arrow and
  a multiplicity at each end like `1`, `0..1`, `1..*`, `*`. The whole of a
  composition has `1` or `0..1`. No class stands without a line, except an
  enumeration or a data type.
- No box overlaps another one. Every line has only horizontal and vertical
  stretches and does not go through a class, that it does not join.
- **ERD**: every entity is a class, every attribute of it is an attribute of the
  class (underlined for a key, dashed underline for a partial key, `/` for a
  derived one, `[1..*]` for a multivalued one), and every relationship is an
  association with the same name and the multiplicities of its cardinalities.
  The diamond of a composition is at the owner.
- **Operations** (with a model): every operation of the model is drawn in the
  operations compartment of its class, with the same parameters and return
  type, and the diagram has no other one.
- **Requirements**: with a model, the model is valid for the current ERD and
  matrix (checksums, every requirement used or explained in `not_drawn`, every
  list "value can be equal to ..." as an enumeration), and the diagram has exactly
  the classes, attributes, types, associations and notes of the model.
- With a PDF: it has 1 page and contains every name of the diagram.
- With a model: the constraints of the `uml-constraints` skill exist and are valid
  for the ERD (`<name>_constraints.json`), every assumption of the ERD with
  "Chen notation cannot show" has a constraint, every weak entity with an
  identifier that UML does not show has an `identity` constraint,
  `<name>_constraints.docx` in `artifacts/` contains every constraint, and
  `<name>_constraints.pdf` is in `documents/`.

- **Functional and non-functional requirements** (with a model): the file
  `spec/conceptual/artifacts/requirements_coverage.json` of the
  `requirements-coverage` skill belongs to the current
  `functional_requirements.pdf` and `non_functional_requirements.pdf` and has
  an entry for every id. Every element, that it names, exists in the UML model, and every `constraint:` in the UML constraints. A gap
  of the UML in a **Must** requirement is an error, so the design does not meet
  that requirement yet.
- **Level below**: it always runs the `validate-erd` skill on `erd.drawio` with
  its model and PDF. Every error of the ERD is an error of the UML, named
  `ERD (validate-erd): ...`. Fix it in the ERD first, with `modify-erd`.
  `validate-relational` runs this skill in the same way, so a check of a
  higher level checks every level below it.

Warnings and notes, which need a human decision:

- A class, an attribute or an association, that is not in the ERD (a thing added
  by `modify-uml`). Without a model it is only a warning.
- Everything the model marks `assumed`, with its reason.
- Requirements in `not_drawn` of the ERD.
- Notes drawn in the diagram (constraints belong to the Word file).
- Crossing lines.
- Without a model: the types of attributes and the notes are not checked.
- A gap of the UML in a Should or Could requirement, and the number of
  covered, gap and not applicable requirements.

## Report to the user

Give the result (`VALID` or `INVALID`), every error with the fix, and the
warnings that matter, mainly the assumptions and the types. For a wrong diagram,
fix the model with `modify-uml` and draw it again. When an ERD element is wrong,
the ERD changes first (`modify-erd`), and the UML is made again with
`erd-to-uml`. Never edit the `.drawio` file by hand to pass the check.
