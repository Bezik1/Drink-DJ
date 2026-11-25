---
name: modify-uml
description: Changes an existing UML class diagram through its JSON model, draws it in draw.io format with neat right-angle lines, exports the official PDF and validates it with validate-uml. Use when the user asks to rename, add, remove, retype or move a class, attribute, enumeration, association, multiplicity or layout of the UML, or to improve its layout. It is also the drawing step of erd-to-uml.
---

# Modify a UML class diagram

The JSON model says **what** is in the UML. The script decides **where** it is
drawn and refuses a diagram that is unreadable. Every change is made in the
model, and the diagram is built again from it. Never write coordinates or
draw.io XML yourself, and never edit the `.drawio` file directly.

`<skill>` is `.claude/skills/modify-uml`. Use `python3`, or `python` on Windows.
The requirements are Python 3.8+, LibreOffice, the draw.io desktop app, the
draw.io MCP and the `modify-erd`, `uml-constraints`, `validate-uml` and
`docx-to-pdf` skill folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| A change named by the user: a type, a name, a multiplicity, a layout | `modify-uml` |
| A new UML, or an update after a change of the ERD or the matrix | `erd-to-uml`, which then uses this skill |
| Only a check of a UML | `validate-uml` |
| A rule, that UML cannot show (a constraint) | `uml-constraints` |
| A change of an entity, a key or a cardinality | `modify-erd` first, then `erd-to-uml` |

The UML must stay consistent with the ERD. A class, an attribute and an
association of the ERD cannot be removed or reshaped here. Only what the ERD
does not decide can change: types, enumerations, extra attributes and the
layout. A constraint, that UML cannot show, is not drawn. It goes to the
`uml-constraints` skill.

## How the diagram looks

The script guarantees this. Do not work around it, and do not move a line by hand:

- Classes with a name, the attributes `+ name : Type` and a compartment for
  operations, that is empty, when the class has none. An operation is
  `+ name()`, or `+ name(parameter : Type) : Type`. Keys are underlined,
  partial keys have a dashed underline and derived attributes start with `/`.
- Enumerations (`«enumeration»`) and data types (`«dataType»`) as boxes, that
  are used as types and are not joined by lines.
- Every enumeration stands in the top right corner of the diagram, inside the
  150 px padding: the first one touches the top and the right padding, and the
  others stand under it, aligned to the right. They are a gap away from the
  other classes, so no line runs near them.
- Lines with right angles only, as in a hand-made UML. A line leaves the middle
  of a side of a class, runs straight or bends once or twice in the free gaps
  between the classes, and enters the middle of a side of the other class.
  When several lines use one side, they leave it side by side. A line between
  two facing sides is **straight**, when one of its ends can move along its
  side to the height of the other one, so two classes joined by several lines
  have several straight lines, not small steps. An association of a class
  with itself (an end `class:role` in `ends`, for example
  `drink_version:base`) is a loop, that leaves one side and enters a
  neighbouring side around a corner of the class. A line never goes
  through a class, never runs on another line, and crosses another line only
  when there is no other way (a warning).
- The name of an association stands next to its longest stretch, and a
  multiplicity near each end. The two multiplicities of a line stand on
  opposite sides of it: when the one at the left end is below the line, the
  one at the right end is above it (and so on for a vertical or bent line).
  A composition has a filled diamond at the whole.
  No label touches a class, a line or another label, when there is room.
- A dashed line at a right angle joins an association class with its association.
- **No notes or comments in the diagram.** A constraint, that UML cannot show,
  goes to the Word file of `uml-constraints`, see step 7.
- Padding of 150 px between the diagram and each side of the page. The PDF is
  exported without cropping, so it has the same padding.

## 1. Find the model

The model is `spec/conceptual/artifacts/<name>.json`, next to the diagram. The
default name is `uml_class_diagram`.

- No model: use `erd-to-uml`.
- A diagram without a model: it was made by a person. Ask the user, before
  making a model that would replace it.
- The script says that `erd.sha256` or `matrix.sha256` does not match: the ERD
  or the matrix has changed. Use `erd-to-uml`. Never only replace the checksum.

Read it as text, with the cells:

```
python3 <skill>/scripts/modify_uml.py show <model.json>
```

## 2. Change the model

Change only what was asked, and keep all other names, cells and notes.

Small changes have a command. It applies the change, validates the model and
puts the old file back, when the new one is invalid:

```
python3 <skill>/scripts/modify_uml.py edit <model.json> <operation> <arguments> [--reason "..."]
```

| Operation | Arguments |
| --- | --- |
| `move` | `<class> <column> <row>`. Not for an enumeration |
| `set-type` | `<class> <attribute> <type>` |
| `rename-attribute` | `<class> <attribute> <new_name>` |
| `add-attribute` | `<class> <name> <type> --reason "..."` |
| `remove-attribute` | `<class> <attribute>`. Not for an attribute of the ERD |
| `add-operation` | `<class> <name> --reason "..."`. An operation without parameters, for example `share`. One with parameters or a return type is written in the JSON |
| `remove-operation` | `<class> <operation>` |
| `add-enumeration` | `<Name> <value> <value> ... --reason "..."` |
| `set-multiplicity` | `<association> <class> <class> <multiplicity> <class of the end>`. It must match the ERD |

Anything else (a composition, a data type, many changes at once) is
changed in the JSON, as below. Every class is named by its name or its key.

| Change | In the model |
| --- | --- |
| Type of an attribute | `"type"`: `String`, `Integer`, `Decimal`, `Boolean`, `Date`, `Time`, `DateTime`, or the name of an enumeration or a data type |
| Enumeration | A class with `"stereotype": "enumeration"` and `"values"` in `snake_case`, without `cell` |
| Data type | A class with `"stereotype": "dataType"` and `"attributes"` |
| Operation | `"operations": [{"name": "share", "from": ["R22", "R33"]}]` in a class. Optional `"parameters": [{"name": "stop", "type": "String"}]` and `"returns": "Integer"`. The ERD has no operations, so every operation needs `from` or `assumed`. A rule about it (who may call it, what it changes) is a constraint of `uml-constraints` |
| Composition | `"kind": "composition"` and `"whole"`, the key of the whole, with multiplicity `1` or `0..1`. Only for an identifying relationship |
| Move | `cell` |

Every thing, that is not in the ERD, needs evidence:

- It is in the matrix: `"from": ["R12"]`.
- It is a decision of the user or of you: `"assumed"` with the reason, and it
  goes to the report.
- It contradicts the matrix or the ERD: ask the user before the change.

### Format of the model

```json
{
  "erd": {"file": "spec/conceptual/artifacts/erd.json", "sha256": "<checksum of the ERD>"},
  "matrix": {"file": "<path of the matrix>", "sha256": "<checksum of the matrix>"},
  "classes": {
    "train": {
      "name": "Train", "entity": "train", "cell": [0, 0], "from": ["R01"],
      "attributes": [
        {"name": "internal_code", "type": "Integer", "erd": "Internal code", "kind": "key", "from": ["R02"]}
      ]
    },
    "schedule_type": {
      "name": "Schedule Type", "stereotype": "enumeration",
      "values": ["regular", "special"], "from": ["R03"]
    }
  },
  "associations": [
    {
      "name": "has", "erd": "has:schedule/train", "kind": "association",
      "ends": {"train": "1", "schedule": "0..*"}, "from": ["R03"]
    }
  ]
}
```

`entity`, `erd` and `relationship` link a class, an attribute and an
association with the ERD. Keep them. Multiplicity next to a class says how many
of that class relate to one instance of the other one, as in the ERD, with `*`
instead of `N` and `M`.

### Rules for `cell`, which is `[column, row]`

- The numbers can be fractions. An association class stands halfway between the
  classes of its association, for example `[1.5, 1.5]`.
- Keep related classes next to each other, in the same row or column. The
  router bends a line around a corner, but the shortest lines are the clearest.
- Put the most connected class in the middle, and leave a free cell next to a
  class with many lines, so that they have a free side to use.
- An enumeration has no `cell`. It is always drawn in the top right corner,
  and a `cell` of an enumeration is ignored.
- Put a data type in a free column at the side.
- Two classes never share a cell.

## 3. Render

Write the XML to a temporary folder, not to the repository:

```
python3 <skill>/scripts/modify_uml.py render <model.json> --out <temp>/uml.xml
```

The script rejects an invalid model, a changed ERD or matrix, and a class that
has no route to another class. Fix the model, usually the cells, and run it
again. Fix the warnings about crossings and labels, when it is possible by moving
a class, until the diagram is clear.
Do not edit the script to get around an error.

## 4. Create the diagram through the draw.io MCP

Pass the rendered XML unchanged to `create_diagram` as `xml`, without
`postLayout` and `routing`. If the MCP is not connected, stop and tell the user,
as the root `CLAUDE.md` requires.

## 5. Save

The MCP cannot write files, so after it accepts the diagram save the same
diagram with:

```
python3 <skill>/scripts/modify_uml.py save <model.json>
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
3. Check it:

   ```
   python3 <skill>/scripts/modify_uml.py verify <model.json> --pdf <official.pdf>
   ```

4. Open the PDF and look at it. Every class, attribute, multiplicity and note
   must be readable with the whole page on the screen. `verify` checks the
   content and the page count, not the look.

## 7. Write the constraints

Everything, that the diagram cannot show but the requirements need, is a
constraint. It is not drawn. After the diagram is final, use the
`uml-constraints` skill to write the Word file and the PDF of the constraints.
Run it again after a change of the classes.

## 8. Validate

Use the `validate-uml` skill on the finished diagram, the model, the PDF and
the constraints:

```
python3 <skill>/scripts/modify_uml.py check <model.json> [--pdf <official.pdf>]
```

Fix every error in the model and repeat steps 3 to 8. Do not report the UML as
finished before the result is `VALID`.

## 9. Report

Give what changed, the paths of the model, the source and the PDF, and every new
or changed assumption. When `erd-to-uml` sent you here, continue with its report
instead.
