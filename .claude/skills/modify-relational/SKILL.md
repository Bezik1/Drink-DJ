---
name: modify-relational
description: Changes an existing relational model through its JSON model (rename a table or a column, change a type, NULL, ON DELETE, UNIQUE or the place of a table), draws it as a draw.io diagram with tables, keys and crow's foot lines, exports the official PDF and validates it with validate-relational. It holds the code of the relational model, that uml-to-relational, relational-constraints and validate-relational use. Use when the user asks for a named change of the relational model, the database schema or its layout. It is also the drawing step of uml-to-relational.
---

# Modify a relational model

The JSON model says **what** is in the relational model. The script decides
**where** it is drawn and refuses a diagram that is unreadable. Every change is
made in the model, and the diagram is built again from it. Never write
coordinates or draw.io XML yourself, and never edit the `.drawio` file directly.

This skill holds the code of the relational model in `scripts/classes`,
`scripts/const` and `scripts/utils`: the source (`UmlSource`), the
transformation (`RelationalDraft`), the model and its check (`RelationalModel`),
the editor (`RelationalEditor`), the layout and the draw.io output. The skills
`uml-to-relational`, `relational-constraints` and `validate-relational` import
it from here and never copy it.

`<skill>` is `.claude/skills/modify-relational`. Use `python3`, or `python` on
Windows. The requirements are Python 3.8+, LibreOffice, the draw.io desktop app,
the draw.io MCP and the `modify-uml`, `modify-erd`, `validate-relational`,
`relational-constraints`, `validate-uml`, `validate-erd` and `docx-to-pdf` skill
folders next to this one.

## Which skill to use

| Task | Skill |
| --- | --- |
| A change named by the user: a name, a type, NULL, ON DELETE, UNIQUE, a layout | `modify-relational` |
| A new relational model, or an update after a change of the UML | `uml-to-relational`, which then uses this skill |
| The rules, that the relational diagram cannot show | `relational-constraints` |
| Only a check | `validate-relational` |
| A change of a class, an attribute or an association | `modify-uml` first, then `uml-to-relational` |

The relational model must stay consistent with the UML. A table of a class, a
column of an attribute and a foreign key of an association cannot be removed
here. Only what the UML does not decide can change: names of tables, names of
foreign key columns, types, NULL, ON DELETE, UNIQUE sets and the layout.

## How the diagram looks

The script guarantees this. Do not work around it:

- A table is a box with its name in the header and a row for every column:
  the key marker (`<PK>`, `<FK>`, `<PK,FK>` or empty), the name and the type
  with `NULL` or `NOT NULL`, as in `INTEGER NOT NULL`. A column of a primary
  key shows only its type (`INTEGER`), because a primary key is never NULL.
- Table names are in Pascal case with `_` (`Route_Sequence`), column names in
  `snake_case`.
- A line goes from the table with the foreign key to the referenced table, with
  right angles only, and never goes through another table. It **joins a key
  with a key**: it leaves the left or the right side of the row of the foreign
  key column and enters the side of the row of the referenced primary key
  column, never the middle of a table. **Every column of a foreign key has its
  own line** to the column, that it references (`line_per_column` in
  `scripts/const/general.py`; `False` draws one line per foreign key instead,
  from the column chosen by `RelationalModel.line_pair`), so every key is joined: a
  foreign key of three columns has three lines. Two foreign keys, that join the
  same two columns, share one line. The lines between two tables leave and
  enter the same sides, so they run side by side.
- A table, whose rows have more ends of lines, than 22 px rows hold, gets
  taller rows, step by step, and only that table.
- A line between two tables in different columns leaves and enters **facing
  sides** (the right side of the left table and the left side of the right
  one). A route around the tables, that leaves and enters the same side, is used
  only when no facing route exists, because it crosses many other lines.
- **Line jumps**: where two lines cross, one hops over the other with a small
  arc (`jumpStyle=arc` in draw.io), so it is clear which line goes on. Crossings
  stay as warnings, because two bundles of lines, that enter the same rows of one
  table from one side, must cross (3 crossings for two keys of 3 columns): put
  one of the tables on the other side of the referenced table to avoid it.
- A gap between two columns of tables holds 9 parallel lines, 14 px apart. The
  lines of one key are ordered like the steps of a staircase, so that they do
  not cross each other. Where they must leave and enter the same side of a
  table, a crossing is left as a warning: move one of the tables.
- A line between facing sides is **straight**, when the two key rows overlap
  in height. A small step is left only, where the rows are a whole row apart.
- **Nothing lies on anything else**: ends of lines on one side of a table are
  at least 14 px apart, so their crow's foot marks never touch. An end, that
  has no room on its side, moves to the other side of the table. No two lines
  run on the same stretch. The end at the
  referenced table is "one" (`||`), or "zero or one" for a NULL foreign key. The
  end at the table with the foreign key shows its multiplicity (`o<`, `|<`, ...).
- A line has **no label**. The `<FK>` markers of the columns show the foreign keys.
- Padding of 150 px between the diagram and each side of the page.

## 1. Find the model

The model is `spec/logical/artifacts/<name>.json`, next to the diagram. The
default name is `relational_model_diagram`.

- No model: use `uml-to-relational`.
- The script says, that `uml.sha256` does not match: the UML changed. Use
  `uml-to-relational`. Never only replace the checksum.

Read it as text, with the cells:

```
python3 <skill>/scripts/modify_relational.py show <model.json>
```

## 2. Change the model

Change only what was asked. Small changes have a command. It applies the change,
validates the model against the UML and puts the old file back, when the new
one is invalid:

```
python3 <skill>/scripts/modify_relational.py edit <model.json> <operation> <arguments>
```

| Operation | Arguments |
| --- | --- |
| `move` | `<table> <column> <row>`. The numbers can be fractions |
| `rename-table` | `<table> <New_Name>`. Also every foreign key to it, and the tables, columns and texts of the constraints file |
| `rename-column` | `<table> <column> <new_name>`. Only a column without `uml` (a foreign key column or an assumed one); also its keys, the foreign keys to it, the columns of other tables, that reference it with the same name, and the constraints file. For example `rename-column Route_Sequence starts_at_stop_name start_stop` renames it in Comment, Likes and the others too |
| `set-type` | `<table> <column> <SQL type>`, for example `"VARCHAR(60)"`. Also every foreign key column, that references it |
| `set-null` | `<table> <column> true\|false` |
| `set-on-delete` | `<table> <col,col> <NO_ACTION\|CASCADE\|SET_NULL\|RESTRICT>`. The columns name the foreign key |
| `add-unique` | `<table> <col,col>` |
| `remove-unique` | `<table> <col,col>` |
| `add-surrogate` | `<table>`. Replaces a composite primary key with `<table>_id`, see "Surrogate keys" |

### Surrogate keys

A composite primary key is copied into every table, that references it, and
every join and index repeats all its columns. So the draft of
`uml-to-relational` replaces it with a surrogate key `<table>_id INTEGER`, when
it is more efficient (`SURROGATE` in `scripts/const/general.py`):

- a primary key of 3 or more columns always,
- a primary key of 2 or more columns, when another table references the
  class (a foreign key, a junction table or a multivalued attribute).

The old key columns stay `NOT NULL` as a UNIQUE set, so the identity of the
UML is kept, and every foreign key references the single surrogate column.
A junction table keeps the key of its two foreign keys. For an existing model,
use `add-surrogate <table>` on such a table, when you judge it more efficient,
for example a weak table with a key of two columns, that many tables reference.
The column of the surrogate key is `assumed`, so name it in the report.

After a rename, a surrogate key or a change of UNIQUE or ON DELETE, build the constraints again
with `relational-constraints` (step 6). Anything else (a primary key chosen by
hand, foreign keys instead of a junction table) is changed in the JSON itself:

```json
{
  "uml": {"file": "spec/conceptual/artifacts/uml_class_diagram.json", "sha256": "<checksum of the UML>"},
  "tables": {
    "Stored_Part": {
      "class": "stored_part",
      "cell": [1, 1],
      "columns": [
        {"name": "stored_part_code", "type": "INTEGER", "null": false, "uml": "stored_part.stored_part_code"},
        {"name": "order_code", "type": "INTEGER", "null": true}
      ],
      "primary_key": ["stored_part_code"],
      "foreign_keys": [
        {"columns": ["order_code", "part_name"], "references": "Order_Item", "to": ["order_code", "part_name"],
         "association": "is allocated to:order_item/stored_part", "multiplicity": "0..*", "on_delete": "NO ACTION"}
      ],
      "unique": [["..."]],
      "omitted": [{"uml": "route.price", "reason": "C10: Price, length and time of a Route ... They are not stored."}]
    }
  }
}
```

- The key of a table is its name, in Pascal case with `_` (`Stored_Part`). The
  keys of the UML in `class`, `association` and `uml` stay as in the UML model.
- A table has `class` (a class of the UML), `association` (the id of a many to
  many association, `"<name>:<class>/<class>"` with sorted keys), `attribute`
  (`"class.attribute"` of a multivalued attribute) or the reason in `assumed`.
- A column has `uml` (`"class.attribute"`, or `"class.attribute.field"` of a
  data type), belongs to a foreign key, or has the reason in `assumed`.
- `multiplicity` of a foreign key says, how many rows of its table reference one
  row of the referenced table. It is the UML multiplicity at the end of its table.
- `on_delete` is `NO ACTION`, `CASCADE`, `SET NULL` or `RESTRICT`.
- `cell` is `[column, row]`, as in the UML, and can be a fraction. Two tables
  never share a cell.
- A many to many association, whose one end has an exact multiplicity `k`
  (`2`), can be `k` foreign keys in the table of the other end instead of a
  junction table, `NOT NULL`, for example the start and the end Schedule Stop
  of a Route.

## 3. Render

Write the XML to a temporary folder, not to the repository:

```
python3 <skill>/scripts/modify_relational.py render <model.json> --out <temp>/relational.xml
```

It rejects an invalid model, a line, that goes through a table, a line, that
has no route with right angles between its two rows, ends of lines, that lie
on each other, and lines, that run on each other. Fix the model,
usually the cells with `move`, and run it again. Move tables to remove the
warnings about crossings, when it is possible: a line uses only the left and
the right sides, so tables joined by a line are clearer side by side, or in
columns half a cell apart, than one exactly under the other.

## 4. Create the diagram through the draw.io MCP

Pass the rendered XML unchanged to `create_diagram` of the draw.io MCP as `xml`,
without `postLayout` and `routing`. If the MCP is not connected, stop and tell
the user, as the root `CLAUDE.md` requires. When the XML is too large to pass in
one call, skip this view and say so in the report: step 5 builds the same file
from the model.

## 5. Save

```
python3 <skill>/scripts/modify_relational.py save <model.json>
```

It writes `spec/logical/artifacts/<name>.drawio`. It stops, when the file was
made or edited by someone else (a file of this skill or of the earlier
`uml-to-relational` script is fine). Use `--force` only after the user agrees.

## 6. Export the official PDF

1. Find the draw.io program as the `drawio-to-pdf` skill describes. Export
   **without** `--crop` and `-b`, because they remove the padding:

   ```
   <drawio> -x -f pdf -a -o spec/logical/artifacts/<name>.pdf spec/logical/artifacts/<name>.drawio
   ```

2. Move the PDF to `spec/logical/documents/<name>.pdf`. It can replace a PDF
   made earlier by this skill. Ask before replacing any other PDF.
3. Check it, and then open it and look at it:

   ```
   python3 <skill>/scripts/modify_relational.py verify <model.json> --pdf spec/logical/documents/<name>.pdf
   ```

## 7. Write the constraints

After a change of names, UNIQUE sets or ON DELETE, use the
`relational-constraints` skill: review the constraints file (a rename has
changed it already), `build` and `verify`.

## 8. Validate

Use the `validate-relational` skill on the finished diagram, the model, the PDF
and the constraints. It also runs `validate-uml` and `validate-erd`:

```
python3 <skill>/scripts/modify_relational.py check <model.json> [--pdf <official.pdf>]
```

Fix every error in the model and repeat steps 3 to 8. Do not report the
relational model as finished before the result is `VALID`.

## 9. Report

Give what changed, the paths of the model, the diagram and the PDF, and the
constraints that changed. When `uml-to-relational` sent you here, continue with
its report instead.
