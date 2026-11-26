--
-- Title:        Schema tests
-- Description:  Holds the helpers and the results. The final ROLLBACK removes it with all
--               test data.
-- Requirements: -
-- Constraints:  -
--
CREATE SCHEMA tests;
SET LOCAL search_path = tests, public;

CREATE TABLE tests.result (
    id          SERIAL,
    requirement TEXT,
    kind        TEXT,
    test        TEXT,
    passed      BOOLEAN,
    detail      TEXT
);


--
-- Title:        expect(condition, label)
-- Description:  Assertion inside a test. Fails the test with the label, when the condition
--               is not true.
-- Requirements: -
-- Constraints:  -
--
CREATE FUNCTION tests.expect(p_condition BOOLEAN, p_label TEXT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF p_condition IS NOT TRUE THEN
        RAISE EXCEPTION 'expected: %', p_label;
    END IF;
END
$$;


--
-- Title:        accepts(requirement, test, statements...)
-- Description:  Acceptance test. Passes, when the statements and the checks at COMMIT
--               succeed.
-- Requirements: -
-- Constraints:  -
--
CREATE FUNCTION tests.accepts(p_requirement TEXT, p_test TEXT, VARIADIC p_statements TEXT[])
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_statement TEXT;
BEGIN
    BEGIN
        FOREACH v_statement IN ARRAY p_statements LOOP
            EXECUTE v_statement;
        END LOOP;
        SET CONSTRAINTS ALL IMMEDIATE;
        SET CONSTRAINTS ALL DEFERRED;
        INSERT INTO tests.result (requirement, kind, test, passed)
        VALUES (p_requirement, 'acceptance', p_test, TRUE);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO tests.result (requirement, kind, test, passed, detail)
        VALUES (p_requirement, 'acceptance', p_test, FALSE, SQLERRM);
    END;
    SET CONSTRAINTS ALL DEFERRED;
END
$$;


--
-- Title:        rejects(requirement, test, expected, statements...)
-- Description:  Rejection test. Passes, when the statements fail with an error, that
--               contains the expected text.
-- Requirements: -
-- Constraints:  -
--
CREATE FUNCTION tests.rejects(p_requirement TEXT, p_test TEXT, p_expected TEXT, VARIADIC p_statements TEXT[])
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_statement TEXT;
BEGIN
    BEGIN
        FOREACH v_statement IN ARRAY p_statements LOOP
            EXECUTE v_statement;
        END LOOP;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION USING ERRCODE = 'P0999', MESSAGE = 'accepted';
    EXCEPTION
        WHEN SQLSTATE 'P0999' THEN
            INSERT INTO tests.result (requirement, kind, test, passed, detail)
            VALUES (p_requirement, 'rejection', p_test, FALSE, 'the statements were accepted');
        WHEN OTHERS THEN
            INSERT INTO tests.result (requirement, kind, test, passed, detail)
            VALUES (p_requirement, 'rejection', p_test, SQLERRM ILIKE '%' || p_expected || '%', SQLERRM);
    END;
    SET CONSTRAINTS ALL DEFERRED;
END
$$;


--
-- Title:        Lookups
-- Description:  drink_id, version_id, album_id and system_album_id find a row by its name.
-- Requirements: -
-- Constraints:  -
--
CREATE FUNCTION tests.drink_id(p_name TEXT) RETURNS INTEGER
LANGUAGE sql AS $$
    SELECT identifier FROM Drink WHERE name = p_name
$$;

CREATE FUNCTION tests.version_id(p_drink TEXT, p_number INTEGER) RETURNS INTEGER
LANGUAGE sql AS $$
    SELECT v.drink_version_id
    FROM Drink_Version v
    JOIN Drink d ON d.identifier = v.drink_identifier
    WHERE d.name = p_drink AND v.version_number = p_number
$$;

CREATE FUNCTION tests.album_id(p_username TEXT, p_name TEXT) RETURNS INTEGER
LANGUAGE sql AS $$
    SELECT identifier FROM Album WHERE username = p_username AND name = p_name
$$;

CREATE FUNCTION tests.system_album_id(p_username TEXT, p_kind TEXT) RETURNS INTEGER
LANGUAGE sql AS $$
    SELECT identifier FROM Album WHERE username = p_username AND kind = p_kind
$$;


--
-- Title:        new_transaction()
-- Description:  Closes the Drink Versions saved so far, as a COMMIT does, without ending
--               the transaction.
-- Requirements: R16
-- Constraints:  -
--
CREATE FUNCTION tests.new_transaction() RETURNS TEXT
LANGUAGE sql AS $$
    SELECT set_config('drink_dj.open_versions', '', TRUE)
$$;


--
-- Title:        insert_raw_version(...)
-- Description:  Inserts a Drink Version directly, as a client could, without
--               save_version().
-- Requirements: -
-- Constraints:  -
--
CREATE FUNCTION tests.insert_raw_version(
    p_drink           INTEGER,
    p_base            INTEGER,
    p_branch          TEXT,
    p_version_number  INTEGER DEFAULT NULL,
    p_author          TEXT    DEFAULT NULL,
    p_total_volume    NUMERIC DEFAULT 0,
    p_estimated_match INTEGER DEFAULT 0,
    p_preferences     INTEGER DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_preferences INTEGER := p_preferences;
    v_id          INTEGER;
BEGIN
    IF v_preferences IS NULL THEN
        INSERT INTO Flavour_Preferences DEFAULT VALUES RETURNING identifier INTO v_preferences;
    END IF;

    INSERT INTO Drink_Version (version_number, name, branch, drink_identifier, author_username,
                               flavour_preferences_identifier, base_drink_version_id,
                               total_volume, estimated_match)
    VALUES (p_version_number, 'T Raw Version', p_branch, p_drink, p_author,
            v_preferences, p_base, p_total_volume, p_estimated_match)
    RETURNING drink_version_id INTO v_id;

    RETURN v_id;
END
$$;
