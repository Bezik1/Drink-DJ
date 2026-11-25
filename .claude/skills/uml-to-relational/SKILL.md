---
name: uml-to-relational
description: Transforms the UML class diagram (spec/conceptual/artifacts/uml_class_diagram.json, made by erd-to-uml) into a relational model, draws, saves and exports it with modify-relational, writes the constraints, that the diagram cannot show, with relational-constraints and validates everything with validate-relational. Use when the user asks to create, regenerate or update the relational model, the database schema or the tables from the UML, or to turn the UML into a relational model. For a single named change of an existing relational model use modify-relational.
---

# UML to relational model

The script `uml_to_relational.py` turns the UML model into the **first** JSON
model of the relational model. Everything else is done by the skills, that this
one always runs: `modify-relational` reviews, draws, saves and exports the model
(steps 3 and 4), `relational-constraints` writes the constraints (step 5) and
`validate-relational` checks everything (step 6, the last one). The code of the
transformation is in `modify-relational`, and this script uses it. Never write
coordinates or draw.io XML yourself, and never edit the `.drawio` file directly.

`<skill>` is `.claude/skills/uml-to-relational`. Use `python3`, or `python` on
Windows. The requirements are Python 3.8+, LibreOffice, the draw.io desktop app,
the draw.io MCP and the `modify-relational`, `modify-uml`, `modify-erd`,
`relational-constraints`, `validate-relational`, `validate-uml`, `validate-erd`,
`modify-word` and `docx-to-pdf` skill folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| A new relational model, or an update after a change of the UML | `uml-to-relational` |
| A change named by the user: a name, a type, NULL, ON DELETE, a layout | `modify-relational` |
| The rules, that the relational diagram cannot show | `relational-constraints`, which this skill runs as step 5 |
| Only a check of a relational model | `validate-relational` |
| The UML is missing or out of date | `erd-to-uml` or `modify-uml` first |

## What the transformation does

The UML is the source. The relational model keeps its names, so that
`validate-relational` can compare them. The diagram writes no label on a line:
the `<FK>` and `<PK,FK>` markers of the columns show the foreign keys, and
every line joins the row of a foreign key with the row of its primary key.

| In the UML | In the relational model |
| --- | --- |
| Class | Table, with the name of the class in Pascal case, the words separated by `_` ("Order Item" is `Order_Item`). Columns stay in `snake_case` |
| Attribute | Column with the same name |
| Key attribute (underlined) | `<PK>` column |
| Class without a key, with partial keys | Primary key = the keys of its owners through the identifying associations (composition first) + the partial keys, as `<PK,FK>` and `<PK>` |
| Class without any key | Surrogate key `<table>_id`, as an assumption |
| Class with a composite key (two or more columns) | Surrogate primary key `<table>_id`, chosen by the draft, when the key has 3 or more columns, or 2 or more and another table references the class (see "Surrogate keys" in `modify-relational`). Otherwise the user can add it with `add-surrogate`. The old key columns become a UNIQUE set. A foreign key to such a table uses the single column `<table>_id` (a second reference to the same table gets a role name, for example `start_stop_id` and `end_stop_id`) |
| `«dataType»` attribute | One column for every attribute of the data type (`location` gives `country`, `city`, ...) |
| `«enumeration»` attribute | `VARCHAR(20)` (longer for long values). The values are a constraint |
| Derived attribute (`/`) | Stored column, set by the database. Omitted, when a UML constraint says "not stored" |
| Multivalued attribute (`[1..*]`) | Table `<table>_<attribute>` with the key of the class and the value |
| Association 1 to many | `<FK>` in the table of the many end, that references the primary key of the other end |
| Association of a class with itself (end `class:role`) | `<FK>` in the same table, whose columns start with the role (`base_drink_version_id`), drawn as a U next to one side of the table |
| Association 1 to 1 | `<FK>` with UNIQUE in the part of a composition, or in the table, that must have the other one |
| Association many to many | Junction table, whose primary key are both foreign keys. It has the name of the association class or the association. When that name is a verb ("Consists Of"), rename it in step 3 to a noun, that says what one row is (`Route_To_Sequence_Assignment`) |
| Association many to many with an exact multiplicity `k` at one end (`2`) | The draft makes a junction table. It can be changed by hand to `k` foreign keys in the table of the other end, `NOT NULL`, for example a start and an end Schedule Stop of a Route |
| Association class | Columns of the junction table, or of the table with the foreign key |
| Lower multiplicity `0` at the referenced end | Foreign key `NULL`. Otherwise `NOT NULL` |
| Composition, junction table | `ON DELETE CASCADE`. Every other foreign key `NO ACTION` |
| Operation (`+ share()`) | Not a table or a column. Its rules are UML constraints, that `relational-constraints` carries over |
| UML constraints | Carried over by `relational-constraints` |
| Multiplicity "2 or more", "at most 3" | A rule of `relational-constraints`, because the crow's foot cannot show it |

Types: `Integer` is `INTEGER`, `Decimal` is `DECIMAL(10,2)`, `Boolean` is
`BOOLEAN`, `Date` is `DATE`, `Time` is `TIME`, `DateTime` is `TIMESTAMP`, and
`String` is `VARCHAR(n)`. The length `n` is guessed from the name (`postal_code`
10, `phone` 20, `country` and `city` 60, `password` and `picture` 255,
`description` and `content` 1000, the rest 100). A column is `NULL`, when the
matrix says "<attribute> value can be equal to ... or NULL", or that it "can be
empty", or when the UML multiplicity of the attribute starts at 0. Review every guess.

A foreign key column has the name of the referenced column. When the table has
that column already, and both come from the same column, they are **shared**,
for example `part_name` of `Stored_Part` belongs to the foreign key `(part_name)`
and to `(order_code, part_name)`, so an allocated part is always the ordered part.
When 2 foreign keys reference the same table, the columns start with the name
of the association (`starts_at_stop_name`, `ends_at_stop_name`).

## 1. Check the source

```
python3 <skill>/scripts/uml_to_relational.py source
```

It prints the matrix, the ERD, the UML with its checksum and the UML constraints.

- The UML model is `spec/conceptual/artifacts/uml_class_diagram.json`. Use
  `--uml`, `--erd` or `--matrix` only when the official file does not exist, and
  then ask the user.
- If the script says, that the UML is invalid or the ERD or the matrix changed,
  stop and use `erd-to-uml`. Do not change the UML only to make the relational model pass.
- If the UML constraints are missing, write them with `uml-constraints` first.

## 2. Draft the model

```
python3 <skill>/scripts/uml_to_relational.py draft [spec/conceptual/artifacts/relational_model_diagram.json]
```

The default name is `relational_model_diagram`. It stops, when the model exists.
Use `--force` only after the user agrees, because it throws away earlier changes.
The draft copies the cells of the UML and puts a junction table between its
two tables. It prints every decision, that needs a review.

## 3. Review the draft

Call the `modify-relational` skill with the Skill tool. Read the model with its
`show` command and change it with its `edit` command, or in the JSON, as it
describes, for every decision, that the draft printed:

1. A guessed `VARCHAR` length or `NULL`: correct it against the matrix
   (`set-type`, `set-null`).
2. "identified through the many to many association": choose the primary key by
   hand in the JSON, and ask the user, when the matrix and the UML constraints
   do not decide it.
3. A shared column: keep it only, when both foreign keys must point to the same value.
   A surrogate key of the draft: keep it, and report it with the UNIQUE set of
   the natural key. Add one with `add-surrogate`, when another composite key is
   large or referenced often.
4. A junction table named after a verb (`Consists_Of`): rename it to a noun,
   that says what one row is, with `rename-table`
   (`Route_To_Sequence_Assignment`). It keeps `class` and `association`, which
   link it to the UML.
5. Columns of two foreign keys to one table get the name of the association
   (`starts_at_stop_name`). Give them a short name of their role with
   `rename-column`, which renames every copy too, for example `start_stop` and
   `end_stop` of Route_Sequence.
6. A reserved word (`order`, `user`, `index`): keep the name of the UML, and
   say in the report, that it must be quoted in SQL.
7. Do not rename, remove or add what is in the UML. That is a change of the UML.

## 4. Draw, save and export

Continue with steps 3 to 6 of the `modify-relational` skill: render, create the
diagram through the draw.io MCP, save, export the PDF and verify it. Its
validation is step 6 of this skill, so do it only once, at the end.

## 5. Write the constraints

Call the `relational-constraints` skill with the Skill tool and follow it:
`draft`, review the candidates, `build`, `verify`. It writes
`spec/conceptual/artifacts/relational_model_constraints.json` and `.docx`, and
`spec/conceptual/documents/relational_model_constraints.pdf`.

## 6. Validate (always the last step)

Call the `validate-relational` skill with the Skill tool, and run:

```
python3 <skill>/scripts/uml_to_relational.py check <model.json> [--pdf <official.pdf>]
```

It also runs `validate-uml` and `validate-erd`, so every level below is checked.
Fix every error in the model with `modify-relational` (or in the constraints)
and repeat steps 4 to 6.
Never skip this step, never edit the `.drawio` file to pass it, and do not
report the relational model as finished before the result is `VALID`.

## 7. Report

Give the UML that was used, the paths of the model, the diagram, the PDF and the
constraints (`.json`, `.docx`, `.pdf`), every decision of step 3 (lengths, NULL,
primary keys chosen by hand, shared columns, reserved words), every derived
attribute, that is not stored, and every constraint.
