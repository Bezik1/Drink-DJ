---
name: erd-to-uml
description: Transforms the Chen-notation ERD (spec/conceptual/artifacts/erd.json, made by requirements-to-erd) into a UML class diagram in draw.io format, exports the official PDF, writes the constraints, that UML cannot show, with uml-constraints and validates it against the requirements matrix and the ERD with validate-uml. Use when the user asks to create, regenerate or update the UML class diagram from the ERD, or to turn the ERD into UML. For a single named change of an existing UML use modify-uml.
---

# ERD to UML class diagram

The script `erd_to_uml.py` turns the ERD model into the **first** JSON model of
the UML. The diagram is then drawn, saved and checked with the `modify-uml`
skill, and the result is always validated with `validate-uml` as the last step. Never write coordinates
or draw.io XML yourself, and never edit the `.drawio` file directly.

`<skill>` is `.claude/skills/erd-to-uml`. Use `python3`, or `python` on Windows.
The requirements are Python 3.8+, LibreOffice, the draw.io desktop app, the
draw.io MCP and the `modify-erd`, `modify-uml`, `uml-constraints`, `validate-uml`
and `docx-to-pdf` skill folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| A new UML, or an update after a change of the ERD or the matrix | `erd-to-uml` |
| A change named by the user: a type, a name, a multiplicity, a layout | `modify-uml` |
| Only a check of a UML | `validate-uml` |
| The rules, that UML cannot show | `uml-constraints`, which this skill runs as step 5 |
| The ERD is missing or out of date | `requirements-to-erd` first |

## What the transformation does

The ERD is the source. The UML keeps its names, keys and cardinalities, so that
`validate-uml` can compare them.

| In the ERD (Chen) | In the UML class diagram |
| --- | --- |
| Entity | Class, with the name of the entity |
| Attribute | `+ name : Type`, with the name in `snake_case` |
| Key attribute | Underlined attribute |
| Partial key of a weak entity | Attribute with a dashed underline |
| Derived attribute | `+ /name : Type` |
| Multivalued attribute | `+ name : Type [1..*]` |
| Relationship | Association with the same name |
| Recursive relationship (`entity:role` end) | Association of the class with itself, drawn as a loop around one corner, with the role kept in `ends` |
| Cardinality `1`, `0..1`, `1..N`, `0..M` | Multiplicity `1`, `0..1`, `1..*`, `0..*`. The numbers stay |
| Identifying relationship, whose owner has 1 or 0..1 | Composition, with the diamond at the owner |
| Other identifying relationship of a weak entity | Association, and an identity constraint |
| Attributes of a relationship | Association class, joined with a dashed line |
| Attribute of the ERD with `values` | `«enumeration»` with the values in `snake_case`, in the top right corner of the diagram |
| Value list in the matrix ("value can be equal to ...") | `«enumeration»` with values in `snake_case`, used as the type |
| Composite value in the matrix ("X consists of ...") | `«dataType»` |
| Rule in `assumptions` with "Chen notation cannot show" | Not drawn. A constraint of `uml-constraints` |
| Identifier of a weak entity, that a composition does not show | Not drawn. A constraint of `uml-constraints` |
| `not_drawn` | Not drawn. It goes to the report |

The type of an attribute is **not** in the ERD. The script guesses it from the
name (`code` is `Integer`, `price` is `Decimal`, `time` is `Time`, `public` is
`Boolean`, the rest is `String`). Review every guess against the matrix.

## 1. Check the source

```
python3 <skill>/scripts/erd_to_uml.py source
```

It prints the matrix, the ERD model with its checksum and what is not drawn.

- The matrix is always `spec/requirements/documents/requirements_matrix.*`, and
  the ERD model is `spec/conceptual/artifacts/erd.json`. Use `--matrix` or
  `--erd` only when the official file does not exist, and then ask the user.
- If the script says that the ERD is invalid or its matrix changed, stop and use
  `requirements-to-erd`. Do not change the ERD only to make the UML pass.
- A relationship with more than 2 entities cannot be drawn. Tell the user.

## 2. Draft the model

```
python3 <skill>/scripts/erd_to_uml.py draft [spec/conceptual/artifacts/uml_class_diagram.json]
```

The default name is `uml_class_diagram`. It stops, when the model exists. Use
`--force` only after the user agrees, because it throws away earlier changes.

The draft uses the cells of the ERD. It puts an association class halfway
between the classes of its association (cells can be fractions), and the
data types in a column on the right. Enumerations have no cell: `modify-uml`
always draws them in the top right corner, inside the padding. The script prints every
guessed type. There is nothing to place by hand: the diagram has only classes,
enumerations and lines.

## 3. Review the draft

Read the model with `modify-uml`:

```
python3 .claude/skills/modify-uml/scripts/modify_uml.py show <model.json>
```

Then, with `modify-uml`, as it describes (`edit` or the JSON itself):

1. Change every wrong type. Use an enumeration, when the matrix lists the
   values, and a primitive type (`String`, `Integer`, `Decimal`, `Boolean`,
   `Date`, `Time`, `DateTime`) otherwise.
2. The ERD has no operations (behaviour, for example sharing a Route Sequence).
   When a requirement names one and says what it changes, add it to its class
   as an `operations` entry with the requirement in `from` (see `modify-uml`),
   and write its rule (who may call it, what it changes) as a constraint with
   `uml-constraints`.
3. Do not rename, remove or add what is in the ERD. That is a change of the ERD.

## 4. Draw, save, export and check

Continue with steps 3 to 6 of the `modify-uml` skill: render, create the
diagram through the draw.io MCP, save, export the PDF and verify it. Its
validation is step 6 of this skill, so do it only once, at the end.

## 5. Write the constraints

Use the `uml-constraints` skill: `draft`, review the candidates, `build`. It
writes the constraints, that UML cannot show and the requirements need, to a
Word file in `spec/conceptual/artifacts` and a PDF in
`spec/conceptual/documents`.

## 6. Validate (always the last step)

Call the `validate-uml` skill with the Skill tool, and run its script. It reads
the saved diagram, the model, the PDF and the constraints with their Word file
and PDF, and compares them with the ERD and the matrix:

```
python3 <skill>/scripts/erd_to_uml.py check <model.json> [--pdf <official.pdf>]
```

Fix every error in the model (or in the constraints) and repeat steps 4 to 6.
Never skip this step, never edit the `.drawio` file to pass it, and do not
report the UML as finished before the result is `VALID`.

## 7. Report

Give the matrix and the ERD that were used, the paths of the model, the source,
the PDF, the constraints (`.json`, `.docx`, `.pdf`), every type that you chose
(they are decisions, not data of the ERD), every constraint, every assumption of
the ERD that the UML repeats, and everything in `not_drawn`.
