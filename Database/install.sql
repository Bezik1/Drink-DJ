\set ON_ERROR_STOP on

BEGIN;
\ir schema/create_tables.sql
\ir schema/create_functions.sql
\ir schema/create_triggers.sql
\ir schema/create_views.sql
COMMIT;
