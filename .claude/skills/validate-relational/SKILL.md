---
name: validate-relational
description: Validates a relational model diagram (.drawio) against its JSON model, the UML class diagram, the UML constraints and the requirements matrix. Checks the notation of the tables, keys and crow's foot lines, the layout, the transformation of every class, attribute and association, the official PDF and the relational constraints with their Word file and PDF. Use when the user asks to validate, check or review the relational model or the database schema, and as the last step of uml-to-relational and modify-relational.
---

# Validate a relational model diagram

`validate_relational.py` reads the finished `.drawio` file, not only the model,
so it also finds changes made by hand. It does not change any file.

`<skill>` is `.claude/skills/validate-relational`. Use `python3`, or `python` on
Windows. It needs the `modify-relational`, `relational-constraints`, `requirements-coverage`,
`validate-uml`, `uml-constraints`, `modify-uml`, `modify-erd`, `validate-erd` and
`docx-to-pdf` skills, LibreOffice
and Python 3.8+.

## Run

```
python3 <skill>/scripts/validate_relational.py [diagram.drawio] [--model model.json] [--pdf official.pdf] [--uml uml.json] [--erd erd.json] [--matrix file]
```

Without arguments it checks
`spec/logical/artifacts/relational_model_diagram.drawio`. The model with the
same name is found next to it, and the PDF in `spec/logical/documents/`. The
UML is `spec/conceptual/artifacts/uml_class_diagram.json`, with its ERD and the
matrix `spec/requirements/documents/requirements_matrix.*`. Add `--uml`, `--erd`
or `--matrix` only when the official file does not exist, and then ask the user.

Exit code: `0` valid, `1` the diagram has errors, `2` the check could not run.

The skills `uml-to-relational` and `modify-relational` run it with their `check` command.

## What is checked

Errors, which make the diagram invalid:

- **Notation**: every table has a unique name in Pascal case with `_`
  (`Order_Item`) and columns. Every column is a row of 3 cells: marker (`<PK>`,
  `<FK>`, `<PK,FK>` or empty), name in `snake_case` and a SQL type with `NULL` or `NOT NULL`. Every table has a
  primary key, which is `NOT NULL`. Every line joins 2 tables, starts at the
  table with the foreign key and has crow's foot ends, with "one" or "zero or
  one" at the referenced table, and no label. A table with a `<FK>` column has a line.
- **Layout**: no table overlaps another one. Every line has only horizontal and
  vertical stretches and does not go through a table, that it does not join.
  Every line joins a key with a key: it starts at the left or the right side
  of a `<FK>` row and ends at the side of a `<PK>` row, not at a random
  place of the table. With a model, the two rows are a foreign key column and
  exactly the primary key column, that it references, and every column of
  every foreign key has exactly one line (two foreign keys, that join the same
  two columns, share it). No two ends on one side of a table are closer than
  14 px (1 px less is allowed, because draw.io rounds the boxes), and no two
  lines run on the same stretch.
- **UML** (with a model): the model belongs to the current UML (checksum), and
  every class is one table, every attribute one column (a data type one column
  for each field, a multivalued attribute a table), with a type, that can store
  the UML type, and a `VARCHAR` long enough for its enumeration. Only a derived
  attribute can be omitted, with the reason. Key attributes are in the primary
  key. Every association is one foreign key in the right table, `NULL` exactly
  when the referenced end starts at 0, with the multiplicity of the UML and
  UNIQUE for one to one, or a junction table for many to many.
- **Diagram and model**: the diagram has exactly the tables, columns, markers,
  types, `NULL`, lines and crow's foot ends of the model.
- With a PDF: it has 1 page and contains every table and column name.
- With a model: `relational_model_constraints.json` exists and is valid for the
  model, the UML constraints and the matrix, every UML constraint is carried
  over or `covered`, the ids continue after the last UML id (`C14`, `C15`,
  ...) without gaps, every enumeration column has a `domain`, every stored
  derived column a `derivation`, every UNIQUE set a `uniqueness` and every
  `ON DELETE` action a `referential` constraint, the `.docx` contains every
  constraint, and the PDF is in `spec/logical/documents/`.
- **Functional and non-functional requirements** (with a model): the file
  `spec/conceptual/artifacts/requirements_coverage.json` of the
  `requirements-coverage` skill belongs to the current
  `functional_requirements.pdf` and `non_functional_requirements.pdf` and has
  an entry for every id. Every element, that it names, exists in the tables (a derived attribute, that is not stored, counts, because it is calculated), and every `constraint:` is carried over or covered by the relational constraints. Every column in `lengths` stores at least that many characters. A gap
  of the relational model in a **Must** requirement is an error, so the design does not meet
  that requirement yet.
- **Levels below**: it always runs the `validate-uml` skill on
  `uml_class_diagram.drawio` with its model, and `validate-uml` runs
  `validate-erd` on `erd.drawio`. Every error of the UML or of the ERD is an
  error of the relational model, named `UML (validate-uml): ...` or
  `ERD (validate-erd): ...`. Fix it in that level first, with its skills.

Warnings and notes, which need a human decision:

- A table or column named with a reserved word of SQL (`order`, `user`, `index`).
- A composition, whose foreign key does not use `ON DELETE CASCADE`.
- A table without any line, and crossing lines.
- Without a model: the diagram is not compared with the UML.
- A gap of the relational model in a Should or Could requirement, and the number of
  covered, gap and not applicable requirements.

## Report to the user

Give the result (`VALID` or `INVALID`), every error with the fix, and the
warnings that matter. For a wrong diagram, fix the model and draw it again with
`modify-relational`. When a class or an association of the UML is wrong, the UML
changes first (`modify-uml`), and the relational model is made again. Never edit
the `.drawio` file by hand to pass the check.
