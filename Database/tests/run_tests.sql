\set ON_ERROR_STOP on
\pset footer off

BEGIN;

\ir framework/setup.sql
\ir framework/fixtures.sql

\echo 'Running the tests ...'

\ir functional/users_and_passkeys.sql
\ir functional/drinks_and_versions.sql
\ir functional/ingredients.sql
\ir functional/flavour_preferences.sql
\ir functional/reviews_and_likes.sql
\ir functional/albums.sql

\ir non_functional/security.sql
\ir non_functional/performance.sql

\ir framework/report.sql
