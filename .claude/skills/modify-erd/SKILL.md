---
name: modify-erd
description: Changes an existing Chen-notation ERD through its JSON model, then draws it with padding, exports the official PDF and validates it. Use when the user asks to rename, add, remove, move or fix an entity, attribute, relationship, key or cardinality of the ERD, or to improve its layout and readability. It is also the drawing step of requirements-to-erd.
---

# Modify an ERD

The JSON model says **what** is in the ERD. The script decides **where** it is
drawn and refuses a diagram that is unreadable. Every change is made in the
model, and the diagram is built again from it. Never write coordinates or
draw.io XML yourself, and never edit the `.drawio` file directly.

`<skill>` is `.claude/skills/modify-erd`. Use `python3`, or `python` on Windows.
The requirements are Python 3.8+, LibreOffice, the draw.io desktop app, the
draw.io MCP and the `docx-to-pdf` skill folder next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| A change named by the user: a name, attribute, key, cardinality, layout | `modify-erd` |
| A new ERD, or an update after a change of the requirements matrix | `requirements-to-erd`, which then uses this skill |
| Only a check of an ERD | `validate-erd` |

When `requirements-to-erd` sent you here, the model is already written, so start
at step 3.

## How the diagram looks

The script guarantees this. Do not work around it:

- Padding of 150 px between the diagram and each side of the page. The PDF is
  exported without cropping, so it has the same padding.
- Gaps between entities and relationships. Rows and columns are moved apart
  only as much as the attributes need, and the smallest such diagram is used.
- The attributes of one entity stand together, in one row above or below it or
  in one column next to it. Many attributes can stand in a staggered row, where
  every second attribute is one row further, or on an arc around the entity.
  Only an entity with no room for that gets two or three groups, and never
  attributes all around it.
- The most crowded entity gets its attributes first. Cardinalities are placed
  after the attributes, on the free side of their line, in the middle of the
  line, where they are best seen. A cardinality moves toward an end of its
  line only, when the middle is taken.
- **Only smooth lines.** Every diagonal line, of a relationship and of an
  attribute, is a gentle curve, that turns softly like a rounded corner. Lines
  of attributes bend less. Only a horizontal or vertical line stays straight,
  because it has no corner. Never add bends to make a diagram fit.
- **Attributes stand close to their entity.** The distance between an entity and
  its attributes is as small as the diagram allows, and the attributes are only
  moved further away, when there is no free place near the entity. An attribute
  is always closer to its entity than any relationship of the entity.
- Entities and relationships stand far apart, so that the diagram is easy to
  follow.
- No text at the bottom, no legend and no marks like `*`. Everything that is
  not from the matrix goes only to the report, see step 8.
- Text of at least 6 pt, when the whole page with the padding is printed on A2
  at most.

## 1. Find the model

The model is `spec/conceptual/artifacts/<name>.json`, next to the diagram. The
default name is `erd`.

- No model and no diagram: use `requirements-to-erd`.
- A diagram without a model: it was made by a person. Ask the user, before
  making a model that would replace it.
- The script says that `matrix.sha256` does not match: the matrix has changed.
  Use `requirements-to-erd`. Never only replace the checksum.

## 2. Change the model

Change only what was asked, and keep all other names, cells and assumptions.

| Change | In the model |
| --- | --- |
| Rename | `name`. The id of an entity can stay. Update the texts of `assumptions` that use the old name |
| Add an entity | `entities`, with a free `cell`, a key and at least one relationship |
| Remove an entity | The entity and every relationship with it in `ends` |
| Attribute of an entity or a relationship | `attributes` of its owner |
| Key | `"kind": "key"`, or `"partial"` in a weak entity |
| Calculated or repeated value | `"kind": "derived"` or `"multivalued"` |
| Attribute with a fixed list of values | `"values": ["price", "total time"]`. It is not drawn in the ERD, but the UML makes an enumeration of it |
| Weak entity | `"weak": true`, and `"identifying": true` in the relationship with its owner |
| Cardinality | The value in `ends` |
| Move | `cell` |

Every element needs evidence:

- It is in the matrix: `"from": ["R12"]`.
- It is not in the matrix: `"assumed"` with the reason, for example a decision
  of the user. Offer `add-requirement`, but do not change the matrix unasked.
- It contradicts the matrix: ask the user before the change.
- A requirement, that is no longer drawn, needs a reason in `not_drawn`.

A relationship of an entity with itself (recursive) names the entity twice
in `ends`, once with a role after a colon, for example
`"ends": {"drink_version": "0..N", "drink_version:base": "0..1"}`: a Drink
Version is based on 0..1 base Drink Versions. It needs its own `cell`
diagonal to the entity, and is never identifying. Its two lines go around the
two corners between the entity and the diamond, so they form a loop.

Two owners can have attributes with the same name, for example `Index` of
Schedule Stop and `Index` of the relationship "consists of".

### Format of the model

```json
{
  "matrix": {"file": "<path of the matrix>", "sha256": "<checksum of the matrix>"},
  "entities": {
    "train": {
      "name": "Train", "cell": [0, 0], "from": ["R01"],
      "attributes": [{"name": "Internal code", "kind": "key", "from": ["R02"]}]
    },
    "schedule": {
      "name": "Schedule", "cell": [1, 0], "from": ["R03"],
      "attributes": [{"name": "Schedule identifier", "kind": "key", "from": ["R03"]}]
    }
  },
  "relationships": [
    {"name": "has", "from": ["R03"], "ends": {"train": "1", "schedule": "0..N"}}
  ],
  "not_drawn": {"R09": "Why it stores no data"},
  "assumptions": ["R03: What was assumed and why"]
}
```

Cardinality next to an entity says how many of that entity relate to one
instance of the other one. "Shelf is in exactly 1 Warehouse, Warehouse has 0..N
Shelves" gives `{"warehouse": "1", "shelf": "0..N"}`. Do not use crow's foot.

### Rules for `cell`, which is `[column, row]`

- Put related entities next to each other, in the same row or column.
- Put the most connected entity in the middle.
- Use at most 5 columns and 4 rows, if possible. A fifth row rarely fits on A2.
- Leave one free neighbour cell for an entity with many attributes and
  relationships.
- For a connection around a corner, give the relationship its own free `cell`,
  that is in line with both entities.
- For a crowded entity, the user may allow diagonal lines. Then give the
  relationship its own `cell` and `"free": true`, so it need not be in line
  with its entities. Its lines become gentle curves. Use it only after the user
  agrees.

## 3. Render

Write the XML to a temporary folder, not to the repository:

```
python3 <skill>/scripts/modify_erd.py render <model.json> --out <temp>/erd.xml
```

It can take about a minute. It tries the spacings from the smallest and skips
every spacing, that cannot give a smaller readable diagram. The script rejects
missing requirements, words from another domain, a changed matrix, overlaps,
crossings and text under 6 pt. Fix the model, usually the cells, and run it
again. Do not edit the script, the padding or the limit to get around an error.

## 4. Create the diagram through the draw.io MCP

Pass the rendered XML unchanged to `create_diagram` as `xml`, without
`postLayout` and `routing`. If the MCP is not connected, stop and tell the user,
as the root `CLAUDE.md` requires.

## 5. Save

The MCP cannot write files, so after it accepts the diagram save the same
diagram with:

```
python3 <skill>/scripts/modify_erd.py save <model.json>
```

It creates both folders in `spec/conceptual/` when they are missing. It stops,
when the `.drawio` file was made or edited by someone else. Use `--force` only
after the user agrees.

## 6. Export the official PDF

1. Find the draw.io program as the `drawio-to-pdf` skill describes. Export
   **without** `--crop` and `-b`, because they remove the padding:

   ```
   <drawio> -x -f pdf -a -o spec/conceptual/artifacts/<name>.pdf spec/conceptual/artifacts/<name>.drawio
   ```

2. Move the PDF to `spec/conceptual/documents/<name>.pdf`. It can replace a PDF
   made earlier by this skill. Ask before replacing any other PDF.
3. Check it. The check fails also when the padding was cropped:

   ```
   python3 <skill>/scripts/modify_erd.py verify <model.json> --pdf <official.pdf>
   ```

4. Open the PDF and look at it. Every name and cardinality must be readable
   with the whole page on the screen, and each entity must have its attributes
   next to it. `verify` checks the content and the page, not the look.

## 7. Validate

Use the `validate-erd` skill on the finished diagram, the model and the PDF:

```
python3 .claude/skills/validate-erd/scripts/validate_erd.py spec/conceptual/artifacts/<name>.drawio
```

Fix every error in the model and repeat steps 3 to 7. Do not report the ERD as
finished before the result is `VALID`.

## 8. Report

Give what changed, the smallest size of text, the paths of the source and the
PDF, and every new or changed assumption. When `requirements-to-erd` sent you
here, continue with its report instead.
