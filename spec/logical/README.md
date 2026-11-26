# Logical Project Design

Specifies the relational model of the database: tables, columns, types, keys
and the constraints, that the diagram cannot show. It is built from the UML
class diagram of the conceptual design (`spec/conceptual`), and the physical
design (`spec/physical`, `Database/`) implements it in PostgreSQL.

## Folder structure

- `documents/`: official PDF documents of the logical design.
  - `relational_model_diagram.pdf`: tables, keys and crow's foot lines.
  - `relational_model_constraints.pdf`: constraints C01-C42, that the diagram
    cannot show.
- `artifacts/`: working files: the JSON models, the draw.io source and the
  Word file of the constraints.
- `CLAUDE.md` and `README.md`: instructions for AI agents and this description.

## Skills

| Skill                    | Purpose                                                                 |
| ------------------------ | ----------------------------------------------------------------------- |
| `uml-to-relational`      | Builds the whole relational model and its constraints from the UML.     |
| `modify-relational`      | Makes one change in the relational model, such as renaming a table.     |
| `relational-constraints` | Writes down the rules that the relational model diagram cannot show.    |
| `validate-relational`    | Checks that the relational model matches the UML and its constraints.   |
