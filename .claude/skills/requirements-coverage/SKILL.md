---
name: requirements-coverage
description: Writes and shows the coverage of the functional and non-functional requirements (spec/requirements/documents) by the conceptual design, in spec/conceptual/artifacts/requirements_coverage.json, which validate-erd, validate-uml and validate-relational check. Use when the user asks, whether the ERD, the UML or the relational model meets the functional or non-functional requirements, when these requirements changed, or when a validator reports a missing or old coverage or a requirement gap.
---

# Coverage of the functional and non-functional requirements

The requirements matrix is the source of the ERD. The functional and
non-functional requirements say, how the system behaves. This skill keeps one
file, that says for every one of them, how the conceptual design serves it: by
which entities, attributes, relationships and constraints, or what is still
missing. The validators of every level check it:

| Level | Validator | It checks |
| --- | --- | --- |
| ERD | `validate-erd` | entities, attributes, relationships and the gaps of the ERD |
| UML | `validate-uml` | the same in the UML, the UML constraints and the gaps of the UML |
| Relational model | `validate-relational` | the same in the tables, the carried constraints, the `lengths` and the gaps of the relational model |

Each validator also runs the one below it, so a check of the relational model
checks the coverage at every level.

`<skill>` is `.claude/skills/requirements-coverage`. Use `python3`, or `python`
on Windows. The requirements are Python 3.8+, LibreOffice and the `modify-erd`
and `docx-to-pdf` skill folders next to this one.

## The file

`spec/conceptual/artifacts/requirements_coverage.json` has the checksums of
`functional_requirements.pdf` and `non_functional_requirements.pdf` and one
entry for every id in them (`FR01`, `NFR15`, ...), as the documents write it:

```json
{
  "id": "FR10", "significance": "Must", "status": "gap",
  "gaps": [{"level": "erd", "text": "Username is not unique, but FR10 registers with a unique username. Make it unique."}],
  "text": "The system shall allow client to register new account ...",
  "elements": ["user", "user.email", "user.username", "user.password"]
}
```

| Status | Meaning |
| --- | --- |
| `covered` | The design stores everything, that the requirement needs. `elements` name it |
| `gap` | Something is missing. Every gap has the `level`, that must change (`erd`, `uml` or `relational`), and the `text`, that says what to add. `elements` name the part, that exists |
| `not_applicable` | The requirement is not about stored data (a screen, performance, hosting, tests). `reason` says so |

Names of `elements`, the same at every level:

- an entity or a class: its key in the ERD, for example `schedule_stop`,
- an attribute: `entity.attribute` in snake case, for example
  `schedule_stop.arrival_time`, and of a relationship `consists_of.index`,
- a relationship or an association: `rel:<name>:<entity>/<entity>` with sorted
  keys, for example `rel:likes:route_sequence/user`,
- a UML constraint: `constraint:C04`. It is checked from the UML up,
- an operation of a UML class: `route_sequence.share()`. It exists only at the
  UML level, so the ERD and the relational model do not check it.

`lengths` (optional) names columns of the relational model, that must store at
least that many characters, for example `{"User.password": 60}` for a bcrypt
hash of NFR15.

A gap of a **Must** requirement is an error of its level, so that level is
`INVALID` until the design changes. A gap of a Should or Could requirement is a
warning.

## 1. Draft

```
python3 <skill>/scripts/requirements_coverage.py draft
```

It reads the ids from the official PDFs and their texts and significance from
the Markdown files in `spec/requirements/artifacts`, and suggests the entities
and attributes, whose names are in the text. Every entry has the status
`review`, which the validators refuse. It stops, when the file exists. Use
`--force` only after the user agrees.

## 2. Review

Decide every entry, with the matrix, the assumptions of the ERD, the UML and
its constraints:

1. Remove a suggested element, that does not serve the requirement, and add the
   relationships and constraints, that do.
2. A requirement about data, that the design cannot store or enforce, is a
   `gap`. Name the level, where it must be fixed, and what to add. Do not hide a
   gap as `covered`.
3. A requirement about screens, performance, hosting or the code is
   `not_applicable`, with the reason.
4. Ask the user, when a requirement is unclear, or when it contradicts the
   matrix or an assumption of the ERD.

## 3. Show

```
python3 <skill>/scripts/requirements_coverage.py show
```

It prints every requirement with its status and gaps, and checks the file
against the documents and the ERD.

## 4. Fix a gap

A gap is fixed in the design, with the skills of its level, for example
`modify-erd` and then `erd-to-uml` and `uml-to-relational` for a missing
attribute, `uml-constraints` for a missing constraint, or `modify-relational`
for an ON DELETE action. Then change the entry to `covered`, with the new
elements, and validate the levels again.

## 5. Report

Give the number of covered, gap and not applicable requirements, and every gap
with its significance, its level and what must be added.
