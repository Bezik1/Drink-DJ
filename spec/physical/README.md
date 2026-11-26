# Physical Project Design

## Folder structure

- `documents/`: official PDF documents of the physical design.
- `artifacts/`: raw working files for the physical design, such as draw.io
  sources and their PDF exports, notes and drafts.
- `CLAUDE.md` and `README.md`: instructions for AI agents and this description.

## Examples

`artifacts/examples/warehouse_session_3` holds the requirements to
implementation matrix, the relational model diagram and the relational model
constraints of the warehouse project of the Database Design course (session
3). They are the example of the format of the documents of this folder and do
not describe Drink DJ.

## Documents

- `documents/requirements_to_implementation_matrix.pdf`: for every requirement
  the tables and columns, the constraint, trigger, view or function that
  enforces it, and its acceptance and rejection tests. Its source is
  `artifacts/requirements_to_implementation_matrix.md`.

## PostgreSQL database

The SQL scripts of the database are in the folder `Database` in the root of
the repository. Its `README.md` describes them and how to run them. The tests
of `Database/tests/run_tests.sql` are the bullets of the matrix.
