# Drink DJ Database

PostgreSQL scripts of the Drink DJ database. They build the relational model
(`spec/logical/documents/relational_model_diagram.pdf`) with every rule of
`spec/logical/documents/relational_model_constraints.pdf`.

Every table, index, function, trigger, view and test starts with a comment
block, that names the requirements it meets and the constraints of
`spec/logical/documents/relational_model_constraints.pdf` (C01-C42) it
enforces or tests:

```sql
--
-- Title:        Flavour_Preferences
-- Description:  Wanted flavour of a User or of a Drink Version: nine levels from 0 to 20.
-- Requirements: R26, R27, R28, R29
-- Constraints:  C06
--
CREATE TABLE Flavour_Preferences (
```

The full mapping is in
`spec/physical/documents/requirements_to_implementation_matrix.pdf`.

They need PostgreSQL 14 or newer with the contrib extensions `pgcrypto` and
`pg_trgm`.

## Tests

`tests/run_tests.sql` runs 153 tests, one for every bullet of "Verification
Needed" in the matrix. An acceptance test passes, when its statements succeed,
and a rejection test, when the database refuses them with the expected error:

```sql
PERFORM accepts('R01', 'register a user, created today', ...);
PERFORM rejects('R01', 'blank username', 'user_username_not_blank', ...);
```

| File | Requirements |
| --- | --- |
| `functional/users_and_passkeys.sql` | R01-R06 |
| `functional/drinks_and_versions.sql` | R07-R16 |
| `functional/ingredients.sql` | R17-R25 |
| `functional/flavour_preferences.sql` | R26-R29 |
| `functional/reviews_and_likes.sql` | R30-R36 |
| `functional/albums.sql` | R37-R47 |
| `non_functional/security.sql` | NFR02, NFR03 |
| `non_functional/performance.sql` | NFR09 |

The tests print a PASS / FAIL table and roll back all of their data, so they
can run on a database with or without the sample data.

## Usage

`install.sql`, `insert_sample_data.sql` and `run_tests.sql` use `psql`
commands (`\ir`, `\set`, `\if`), so they run only with `psql`, not in the SQL
editor of DBeaver. Run the commands from the root of the repository.

1. Start PostgreSQL. With Homebrew on macOS:

   ```bash
   brew services start postgresql@14
   pg_isready            # "localhost:5432 - accepting connections"
   ```

2. Create the database, fill it and test it:

   ```bash
   createdb drink_dj
   psql -d drink_dj -f Database/install.sql
   psql -d drink_dj -f Database/data/insert_sample_data.sql
   psql -d drink_dj -f Database/tests/run_tests.sql   # "All tests passed."
   ```

3. Look at the data: `psql -d drink_dj -f Database/queries/example_queries.sql`,
   or in DBeaver (below).

## Deleting the database

```bash
dropdb drink_dj
```

This deletes the database `drink_dj` with all its tables and data, and cannot
be undone. The PostgreSQL server and other databases stay. `dropdb` fails,
while a program is connected to the database: disconnect DBeaver first
(right click on the connection > Disconnect), or force it with
`dropdb --force drink_dj`.

To build it again from the start, repeat step 2 of Usage. To stop the server,
run `brew services stop postgresql@14`.

## Acting user

The backend calls `set_acting_user('<username>')` at the start of every
transaction of a logged-in User. It decides the author of a new Drink Version,
who may share an Album and which private Albums `Visible_Album` shows. A
transaction without it is a Guest or an administrator script. It lasts only
until the end of the transaction, so in DBeaver run it together with the query,
as the last example of `queries/example_queries.sql` does.
