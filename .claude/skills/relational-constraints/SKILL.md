---
name: relational-constraints
description: Writes the constraints, that the requirements need but a relational model diagram cannot show (enumeration values, derivations, UML rules, UNIQUE sets and ON DELETE actions), to a Word file in spec/conceptual/artifacts and a PDF in spec/conceptual/documents, in the same one-table style as the UML constraints. Use as step 5 of uml-to-relational, after a change with modify-relational, when the user asks for the constraints, rules or restrictions of the relational model, or when the relational model or the UML constraints changed.
---

# Constraints that the relational model cannot show

A relational model diagram shows tables, columns, types, NULL, primary keys and
foreign keys. It cannot show the values of an enumeration, a rule over several
tables, how a derived column is calculated, a UNIQUE set or what happens on
delete. This skill collects **only** those constraints, in a Word file and a PDF,
in the style of `uml_class_diagram_constraints.pdf`.

`<skill>` is `.claude/skills/relational-constraints`. Use `python3`, or `python`
on Windows. The requirements are Python 3.8+, LibreOffice and the
`modify-relational`, `modify-uml`, `modify-erd`, `modify-word` and `docx-to-pdf`
skill folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| The constraints of a relational model | `relational-constraints` |
| The relational model itself | `uml-to-relational`, which runs this skill, or `modify-relational` for one change |
| Only a check | `validate-relational`, which also checks these files |
| The constraints of the UML | `uml-constraints` |

## What is a constraint

| Kind | Meaning |
| --- | --- |
| `domain` | The values of a column, for example of an enumeration, or a limit like greater than 0 |
| `uniqueness` | A column or a combination, that must be unique, besides the primary key |
| `derivation` | How a derived column is calculated, and that the database sets it |
| `rule` | A rule over several tables or states |
| `referential` | What deleting a row does to the rows, that reference it (`ON DELETE`) |

Keep a constraint only when the diagram cannot show it. A primary key, a foreign
key, a type and `NULL` / `NOT NULL` are in the diagram. So is "zero", "one" or
"many" of a multiplicity (the crow's foot), but **not** "two or more" or "at most
3": such a multiplicity of the UML needs a `rule` with its `foreign_key`, for
example "Every Schedule has at least 2 Schedule Stops"
(`"foreign_key": "Schedule_Stop (schedule_identifier)"`). The check refuses a
model without it.

## 1. Draft

The relational model, the UML model and the UML constraints must exist, as
`uml-to-relational` and `uml-constraints` make them.

```
python3 <skill>/scripts/relational_constraints.py draft [--model spec/conceptual/artifacts/relational_model_diagram.json]
```

The files are `spec/conceptual/artifacts/relational_model_constraints.json`,
`.docx` and `spec/conceptual/documents/relational_model_constraints.pdf` (the
name of the model without `_diagram`). The draft takes:

- a `domain` with the values of every enumeration, for all its columns, with
  `NULL` when a column is NULL ("Hazard Type value and Shelf Hazard Type value
  can be equal only to ..."),
- every UML constraint with its kind, its requirements and `"uml": ["C03"]`.
  An `identity` constraint goes to `covered`, because a primary key shows it,
- "It is set by the database and cannot be changed directly." for every
  stored derived column, and a candidate for one without a UML formula,
- a `uniqueness` for every UNIQUE set of the model,
- a `rule` for every multiplicity of a foreign key, that the crow's foot cannot
  show, with its `foreign_key`,
- a `referential` for every `CASCADE`, `SET NULL` and `RESTRICT`, and one
  (NO ACTION is the default of SQL and is not written as a constraint.)

It stops when the file exists. Use `--force` only after the user agrees.

## 2. Review

Read the file with `show`, and change the JSON:

```
python3 <skill>/scripts/relational_constraints.py show spec/conceptual/artifacts/relational_model_constraints.json
```

```json
{
  "relational": {"file": "spec/conceptual/artifacts/relational_model_diagram.json"},
  "uml_constraints": {"file": "spec/conceptual/artifacts/uml_class_diagram_constraints.json", "sha256": "<checksum>"},
  "covered": {"C01": "The primary key of Route_Sequence shows it."},
  "constraints": [
    {
      "id": "C01", "kind": "domain", "tables": ["Part"], "columns": ["Part.part_type"],
      "text": "Part Type value can be equal only to “spare_parts”, “chemicals”, “engine_component” or “other”.",
      "from": ["R02"]
    }
  ]
}
```

- Shorten a text to the part, that the diagram does not show. Write the formula
  of a derived column, that has only a candidate.
- A UML constraint, that the relational model shows completely (for example by
  a primary key or by a shared foreign key column), moves to `covered` with the
  reason. Every UML constraint is in `uml` of a constraint or in `covered`.
- Add a constraint of the matrix, that is missing (for example "Quantity must be
  greater than 0"). Give `from` with the requirement, or the reason in `assumed`.
- `tables` are tables of the model, or `"*"` for all tables. `columns` are
  `"table.column"`, and every enumeration column, stored derived column and
  UNIQUE set must be in `columns` of its constraint.
- Ids are `C01`, `C02`, ... from one, without gaps, in this document. The UML
  constraints keep their own ids (`C01` to `C19` of their document), so the same
  id can name a relational and a UML constraint. `uml` and `covered` always name
  the UML constraints, and the requirements go to `from`, never into the text.
- A text never names a requirement (`FR32`, `NFR15`). Put the requirement in
  `from` (matrix ids) or in `assumed` (the reason).
- The draft sorts the constraints by kind: domain, uniqueness, rule,
  derivation, referential. After adding or removing a constraint, number all
  of them again from the first free number.

## 3. Build

```
python3 <skill>/scripts/relational_constraints.py build spec/conceptual/artifacts/relational_model_constraints.json
```

It writes the `.docx` next to the JSON with the `modify-word` skill and the PDF
in `spec/conceptual/documents` with the `docx-to-pdf` skill. The document has
**only one table**, without a title or any other text: id, tables ("All tables"
for `*`), constraint and requirements. It has the look of the requirements
matrix: landscape A4, Arial, black text, bordered table with a bold header. Do
not change the style. A `.docx` made by someone else is not replaced, unless the
user agrees to `--force`.

## 4. Verify

```
python3 <skill>/scripts/relational_constraints.py verify <constraints.json> --pdf spec/conceptual/documents/relational_model_constraints.pdf
```

Then open the PDF and look at it. The whole relational model is validated by
step 6 of `uml-to-relational`, or step 8 of `modify-relational`.

## 5. Report

Give the paths of the three files, and every constraint with its kind and
requirements. Say which UML constraints are `covered`, and why.
