---
name: requirements-to-erd
description: Creates or updates the model of a Chen-notation ERD from the requirements matrix and then uses modify-erd to draw, export and validate it. Always checks spec/requirements/documents for requirements_matrix and must use it when it exists. Use when the user asks to create or regenerate an ERD, to turn requirements into an ERD, or to update the ERD after the requirements changed. For a single named change of the ERD use modify-erd.
---

# Requirements matrix to ERD

This skill decides **what** follows from the requirements and writes it to the
JSON model. The `modify-erd` skill does everything else: the format of the
model, the layout, the draw.io file and the PDF. The `validate-erd` skill is
always the last step, see step 5.

`<skill>` is `.claude/skills/requirements-to-erd`. Use `python3`, or `python` on
Windows. It needs the `modify-erd` and `docx-to-pdf` skill folders, with their
requirements.

## 1. Check the source (always first)

```
python3 <skill>/scripts/requirements_to_erd.py source
```

- If `spec/requirements/documents/requirements_matrix.*` exists, it **must** be
  used. The PDF has priority. Do not replace it with another file, an older
  version from git, an example from the chat or an existing diagram.
- If it does not exist, ask the user for a matrix and add `--matrix <file>` to
  every command, also to those of `modify-erd` and `validate-erd`. Do not invent
  requirements.

The command prints the path, checksum, ids and text. Also open the PDF itself,
because the printed text loses the columns of a table.

Diagrams from other projects or the team's UML show only notation, style and
which objects can exist. Entity and attribute names stay as in the matrix and in
the existing model. Take an object from such a diagram only when the matrix
needs it, give it `assumed` with the reason and name the diagram, and list it in
the report.

## 2. Map the requirements

The matrix can have two forms:

- **With analysis columns** (Candidate Concept(s), Classification, Possible
  Identifier / Key, Constraint or Relationship, Assumptions / Questions): follow
  those columns.
- **Only id and business requirement**: derive the same information from the
  sentences with the table below.

| In the requirements | In Chen notation | In the model |
| --- | --- | --- |
| Thing, about which data is stored | Rectangle | `entities` |
| Thing identified through another one | Double rectangle | `"weak": true` |
| Information about a thing | Oval | `attributes` |
| Unique identifier | Underlined oval | `"kind": "key"` |
| Identifier inside the owner of a weak entity | Dashed underline | `"kind": "partial"` |
| Calculated value | Dashed oval | `"kind": "derived"` |
| Many values of one attribute | Double oval | `"kind": "multivalued"` |
| Verb connecting things | Diamond | `relationships` |
| Relationship identifying a weak entity | Double diamond | `"identifying": true` |
| Thing related to another thing of the same kind, such as a version based on a version | Diamond with a loop of two lines | Recursive relationship: `ends` with a role, `drink_version:base` |
| Reference to another thing, such as carrier name in a train | Relationship, not an attribute | `relationships` |
| Function without stored data | Not drawn | `not_drawn` |
| Rule, that Chen notation cannot show | Not drawn | `assumptions` |

- Use the wording of the matrix. For something it does not state, give the
  reason in `assumed`. `assumed` is not drawn. List the assumed cardinalities
  and interpretations in `assumptions`.
- Do not repeat a relationship, that follows from two others, unless it
  identifies a weak entity.
- Join two relationships between the same entities into one, when the matrix
  describes them as one, for example start and end of a route.

## 3. Write the model

Read "Format of the model" and "Rules for `cell`" in
`.claude/skills/modify-erd/SKILL.md`. The model is
`spec/conceptual/artifacts/<name>.json` and the default name is `erd`.

- **No model**: write a new one with the path and checksum from step 1.
- **The model exists**: update it, and do not write it again from zero. Compare
  each requirement with it and change only what differs. Names, cells and
  assumptions decided earlier stay, unless the matrix now contradicts them. Set
  the new checksum only after every requirement was compared.

## 4. Draw it with modify-erd

Use the `modify-erd` skill on the model, from its step 3 (Render) to its step 6
(Export the official PDF). Do not draw, save or export the diagram in another
way.

## 5. Validate (always the last step)

Call the `validate-erd` skill with the Skill tool, and run its script on the
finished diagram, the model and the PDF:

```
python3 .claude/skills/validate-erd/scripts/validate_erd.py spec/conceptual/artifacts/<name>.drawio
```

(add `--matrix <file>`, when step 1 needed it). Fix every error in the model
and repeat steps 4 and 5. Never skip this step, never edit the `.drawio` file to
pass it, and do not report the ERD as finished before the result is `VALID`.

## 6. Report

Give the matrix that was used, the paths of the source and the PDF, every
assumption (everything marked `assumed`, with its reason) and everything in
`not_drawn`. This is the only place for them, because the diagram has no
legend.
