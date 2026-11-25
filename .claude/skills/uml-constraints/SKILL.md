---
name: uml-constraints
description: Writes the constraints, that the requirements need but a UML class diagram cannot show, to a Word file in spec/conceptual/artifacts and a PDF in spec/conceptual/documents, in the style of the other project documents. Use after erd-to-uml or modify-uml, when the user asks for the constraints, rules or restrictions of the UML, or when the UML or the ERD changed.
---

# Constraints that UML cannot show

A class diagram shows classes, attributes, keys, types and multiplicities. It
cannot show a rule over several classes, an identifier made of other classes, a
limit of a value or how a derived value is calculated. This skill collects
**only** those constraints, in a Word file and a PDF. The diagram has no notes.

`<skill>` is `.claude/skills/uml-constraints`. Use `python3`, or `python` on
Windows. The requirements are Python 3.8+, LibreOffice and the `modify-uml`,
`modify-erd`, `modify-word` and `docx-to-pdf` skill folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| The constraints of a UML | `uml-constraints` |
| The diagram itself | `erd-to-uml` or `modify-uml` |
| Only a check | `validate-uml`, which also checks these files |

## What is a constraint

| Kind | Meaning |
| --- | --- |
| `identity` | A weak class is identified by attributes of other classes, which the UML does not show |
| `uniqueness` | A combination of values must be unique |
| `domain` | A limit of a value, for example greater than 0 |
| `derivation` | How a derived (`/`) attribute is calculated |
| `rule` | A rule over several classes or states, or about an operation: who may call it, when it works and what it changes (for example `share()` of Route Sequence) |

Keep a constraint only when the UML cannot show it. Remove everything, that the
diagram already says: a multiplicity (`1..*`), a type, a key, an enumeration, a
composition, a derived attribute without a formula.

## 1. Draft

The UML model and the ERD must exist, as `erd-to-uml` makes them.

```
python3 <skill>/scripts/uml_constraints.py draft
```

The files are `spec/conceptual/artifacts/<uml name>_constraints.json`, `.docx`
and `spec/conceptual/documents/<uml name>_constraints.pdf`. The draft takes:

- every assumption of the ERD with "Chen notation cannot show", without that
  sentence,
- an `identity` constraint for a weak entity, whose identifier is not drawn,
- a `derivation` for a derived attribute, that the ERD explains.

It stops when the file exists. Use `--force` only after the user agrees.

## 2. Review

Read the file with `show`, and change the JSON:

```
python3 <skill>/scripts/uml_constraints.py show spec/conceptual/artifacts/<name>_constraints.json
```

```json
{
  "uml": {"file": "spec/conceptual/artifacts/uml_class_diagram.json"},
  "erd": {"file": "spec/conceptual/artifacts/erd.json", "sha256": "<checksum>"},
  "constraints": [
    {
      "id": "C01", "kind": "rule", "classes": ["train", "operator"],
      "text": "The Train and the Train Operator of a Schedule belong to the same Carrier.",
      "from": ["R15"]
    }
  ]
}
```

- Delete a candidate, that the UML shows. Shorten a text to the part, that it
  does not show, for example "A Comment can only be added to a public Route
  Sequence" instead of "A Comment has one author and belongs to one Route
  Sequence, which is public".
- Add a constraint of the matrix, that is missing (for example "Quantity must be
  greater than 0"). Give `from` with the requirement, or the reason in `assumed`.
- `classes` are keys of classes of the UML model, and ids are `C01`, `C02`, ...
- Every assumption of the ERD with "Chen notation cannot show" must keep a
  constraint with its requirement, and the script refuses the file otherwise.
  When the ERD is wrong, change it first.

## 3. Build

```
python3 <skill>/scripts/uml_constraints.py build spec/conceptual/artifacts/<name>_constraints.json
```

It writes the `.docx` with the `modify-word` skill and the PDF with the
`docx-to-pdf` skill. The document has **only one table**, without a title or any other text: id,
classes, constraint and requirements. The kind of a constraint is only in the
JSON file. It has the look of the
requirements matrix: landscape A4, Arial, black text, bordered table with a bold
header. Do not change the style. A `.docx` made by someone else is not replaced,
unless the user agrees to `--force`.

## 4. Verify

```
python3 <skill>/scripts/uml_constraints.py verify <constraints.json> --pdf spec/conceptual/documents/<name>_constraints.pdf
```

Then open the PDF and look at it. Last, validate the whole UML:

```
python3 .claude/skills/modify-uml/scripts/modify_uml.py check <uml model.json> --pdf <diagram pdf>
```

## 5. Report

Give the paths of the three files, and every constraint with its kind and
requirements. Say which candidates you removed, and why.
