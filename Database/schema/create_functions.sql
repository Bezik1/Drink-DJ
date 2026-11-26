--
-- Title:        acting_user()
-- Description:  The logged-in User of the current transaction, set by the backend. NULL
--               for a Guest.
-- Requirements: R06, R15, R45
-- Constraints:  C18, C24
--
CREATE FUNCTION acting_user() RETURNS VARCHAR
LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('drink_dj.acting_user', TRUE), '')::VARCHAR
$$;


--
-- Title:        set_acting_user(username)
-- Description:  Sets the acting user of the current transaction. NULL means a Guest.
-- Requirements: R06
-- Constraints:  C25
--
CREATE FUNCTION set_acting_user(p_username VARCHAR) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF p_username IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "User" WHERE username = p_username) THEN
        RAISE EXCEPTION 'User "%" does not exist.', p_username USING ERRCODE = 'foreign_key_violation';
    END IF;
    PERFORM set_config('drink_dj.acting_user', COALESCE(p_username, ''), TRUE);
END
$$;


--
-- Title:        is_open_version(drink_version_id)
-- Description:  Whether a Drink Version was saved in the current transaction, so that its
--               Ingredients can still change.
-- Requirements: R16
-- Constraints:  C18
--
CREATE FUNCTION is_open_version(p_drink_version_id INTEGER) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
    SELECT position(',' || p_drink_version_id || ','
                    IN COALESCE(current_setting('drink_dj.open_versions', TRUE), '')) > 0
$$;


--
-- Title:        open_version(drink_version_id)
-- Description:  Marks a Drink Version as saved in the current transaction.
-- Requirements: R16
-- Constraints:  C18
--
CREATE FUNCTION open_version(p_drink_version_id INTEGER) RETURNS VOID
LANGUAGE sql AS $$
    SELECT set_config(
        'drink_dj.open_versions',
        COALESCE(NULLIF(current_setting('drink_dj.open_versions', TRUE), ''), ',')
            || p_drink_version_id || ',',
        TRUE
    );
$$;


--
-- Title:        unit_to_ml(unit)
-- Description:  Millilitres in one unit. Countable units (leaves, pieces, portion) add no
--               volume.
-- Requirements: R21
-- Constraints:  C29
--
CREATE FUNCTION unit_to_ml(p_unit VARCHAR) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT CASE p_unit
        WHEN 'ml'      THEN 1
        WHEN 'cl'      THEN 10
        WHEN 'oz'      THEN 29.57
        WHEN 'tsp'     THEN 4.93
        WHEN 'tbsp'    THEN 14.79
        WHEN 'dashes'  THEN 0.92
        ELSE 0
    END::NUMERIC
$$;


--
-- Title:        ingredient_has_taste(...)
-- Description:  Whether an Ingredient adds a sweet, sour, bitter or strong taste, like in
--               the iOS app.
-- Requirements: R24
-- Constraints:  C31
--
CREATE FUNCTION ingredient_has_taste(
    p_name VARCHAR, p_category VARCHAR, p_alcohol_percentage NUMERIC, p_taste VARCHAR
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE p_taste
        WHEN 'sweet'  THEN p_name ~* '(syrup|liqueur|cura[cç]ao|honey|agave|juice|ginger beer)'
                           AND p_name !~* '(lime|lemon)'
        WHEN 'sour'   THEN p_name ~* '(lime|lemon|grapefruit|citrus)'
        WHEN 'bitter' THEN p_name ~* '(campari|aperol|bitters|tonic|coffee|espresso)'
        WHEN 'strong' THEN p_category = 'alcohol' AND p_alcohol_percentage >= 30
        ELSE FALSE
    END
$$;


--
-- Title:        version_taste(drink_version_id)
-- Description:  Estimated sweet, sour, bitter and strong taste of a Drink Version, each
--               from 0 to 1.
-- Requirements: R24
-- Constraints:  C31, C32
--
CREATE FUNCTION version_taste(p_drink_version_id INTEGER)
RETURNS TABLE (sweet NUMERIC, sour NUMERIC, bitter NUMERIC, strong NUMERIC)
LANGUAGE sql STABLE AS $$
    WITH item AS (
        SELECT vi.amount * unit_to_ml(vi.unit) AS ml, i.name, i.category, i.alcohol_percentage
        FROM Version_Ingredient vi
        JOIN Ingredient i ON i.name = vi.ingredient_name
        WHERE vi.drink_version_id = p_drink_version_id
    )
    -- least() skips NULL, so COALESCE comes first.
    SELECT
        least(1, COALESCE(2.0 * sum(ml) FILTER (WHERE ingredient_has_taste(name, category, alcohol_percentage, 'sweet'))  / NULLIF(sum(ml), 0), 0)),
        least(1, COALESCE(2.0 * sum(ml) FILTER (WHERE ingredient_has_taste(name, category, alcohol_percentage, 'sour'))   / NULLIF(sum(ml), 0), 0)),
        least(1, COALESCE(2.0 * sum(ml) FILTER (WHERE ingredient_has_taste(name, category, alcohol_percentage, 'bitter')) / NULLIF(sum(ml), 0), 0)),
        least(1, COALESCE(1.3 * sum(ml) FILTER (WHERE ingredient_has_taste(name, category, alcohol_percentage, 'strong')) / NULLIF(sum(ml), 0), 0))
    FROM item
$$;


--
-- Title:        taste_match(...)
-- Description:  Match from 0 to 1 between a taste and Flavour Preferences.
-- Requirements: R25
-- Constraints:  C32
--
CREATE FUNCTION taste_match(
    p_sweet NUMERIC, p_sour NUMERIC, p_bitter NUMERIC, p_strong NUMERIC,
    p_flavour_preferences_identifier INTEGER
) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
    SELECT greatest(0, least(1, 1 - (
               abs(p_sweet  - fp.sweetness  / 20.0) +
               abs(p_sour   - fp.sourness   / 20.0) +
               abs(p_bitter - fp.bitterness / 20.0) +
               abs(p_strong - fp.intensity  / 20.0)
           ) / 4))
    FROM Flavour_Preferences fp
    WHERE fp.identifier = p_flavour_preferences_identifier
$$;


--
-- Title:        refresh_drink_version(drink_version_id)
-- Description:  Recalculates the total volume, the total alcohol, the flavour distribution
--               and the estimated match of a Drink Version.
-- Requirements: R21, R22, R24, R25
-- Constraints:  C29, C30, C31, C32
--
CREATE FUNCTION refresh_drink_version(p_drink_version_id INTEGER) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_volume  NUMERIC;
    v_alcohol NUMERIC;
    v_taste   RECORD;
    v_fp      INTEGER;
    v_match   INTEGER;
BEGIN
    SELECT flavour_preferences_identifier INTO v_fp
    FROM Drink_Version WHERE drink_version_id = p_drink_version_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(vi.amount * unit_to_ml(vi.unit)), 0),
           COALESCE(sum(vi.amount * unit_to_ml(vi.unit) * i.alcohol_percentage)
                    / NULLIF(sum(vi.amount * unit_to_ml(vi.unit)), 0), 0)
      INTO v_volume, v_alcohol
      FROM Version_Ingredient vi
      JOIN Ingredient i ON i.name = vi.ingredient_name
     WHERE vi.drink_version_id = p_drink_version_id;

    SELECT * INTO v_taste FROM version_taste(p_drink_version_id);

    v_match := CASE WHEN v_volume > 0
                    THEN round(100 * taste_match(v_taste.sweet, v_taste.sour, v_taste.bitter, v_taste.strong, v_fp))
                    ELSE 0 END;

    UPDATE Drink_Version
       SET total_volume             = round(v_volume, 2),
           total_alcohol_percentage = round(v_alcohol, 2),
           flavour_distribution     = jsonb_build_object(
                                          'sweet',  round(100 * v_taste.sweet),
                                          'sour',   round(100 * v_taste.sour),
                                          'bitter', round(100 * v_taste.bitter),
                                          'strong', round(100 * v_taste.strong))::TEXT,
           estimated_match          = v_match
     WHERE drink_version_id = p_drink_version_id;
END
$$;


--
-- Title:        refresh_drink_stats(drink_identifier)
-- Description:  Recalculates the average rating and the popularity of a Drink.
-- Requirements: R34, R35
-- Constraints:  C27, C28
--
CREATE FUNCTION refresh_drink_stats(p_drink_identifier INTEGER) RETURNS VOID
LANGUAGE sql AS $$
    UPDATE Drink
       SET average_rating = COALESCE((
               SELECT round(avg(r.number_of_stars), 2)
               FROM Review r
               JOIN Drink_Version v ON v.drink_version_id = r.drink_version_id
               WHERE v.drink_identifier = p_drink_identifier), 0),
           popularity = (
               SELECT count(*)
               FROM Review r
               JOIN Drink_Version v ON v.drink_version_id = r.drink_version_id
               WHERE v.drink_identifier = p_drink_identifier)
             + (SELECT count(*) FROM Album_Entry e WHERE e.drink_identifier = p_drink_identifier)
     WHERE identifier = p_drink_identifier;
$$;


--
-- Title:        refresh_album_count(album_identifier)
-- Description:  Recalculates the number of Drinks of an Album.
-- Requirements: R43
-- Constraints:  C33
--
CREATE FUNCTION refresh_album_count(p_album_identifier INTEGER) RETURNS VOID
LANGUAGE sql AS $$
    UPDATE Album
       SET number_of_drinks = (SELECT count(*) FROM Album_Entry e WHERE e.album_identifier = p_album_identifier)
     WHERE identifier = p_album_identifier;
$$;


--
-- Title:        register_user(username, email, password, profile_image)
-- Description:  Creates a User with its own Flavour Preferences and a bcrypt hash of the
--               password.
-- Requirements: R01, R27, NFR02
-- Constraints:  C12, C20
--
CREATE FUNCTION register_user(
    p_username VARCHAR, p_email VARCHAR, p_password TEXT, p_profile_image VARCHAR DEFAULT NULL
) RETURNS VARCHAR
LANGUAGE plpgsql AS $$
DECLARE
    v_fp INTEGER;
BEGIN
    IF p_password IS NULL OR p_password = '' THEN
        RAISE EXCEPTION 'A password is required.' USING ERRCODE = 'not_null_violation';
    END IF;
    INSERT INTO Flavour_Preferences DEFAULT VALUES RETURNING identifier INTO v_fp;
    INSERT INTO "User" (username, email, password, profile_image, flavour_preferences_identifier)
    VALUES (p_username, p_email, crypt(p_password, gen_salt('bf', 10)), p_profile_image, v_fp);
    RETURN p_username;
END
$$;


--
-- Title:        authenticate_user(email, password)
-- Description:  Login. Returns the username for the right e-mail and password, and NULL
--               otherwise.
-- Requirements: NFR02
-- Constraints:  -
--
CREATE FUNCTION authenticate_user(p_email VARCHAR, p_password TEXT) RETURNS VARCHAR
LANGUAGE sql STABLE AS $$
    SELECT username FROM "User"
    WHERE lower(email) = lower(p_email) AND password = crypt(p_password, password)
$$;


--
-- Title:        change_password(username, current, new)
-- Description:  Changes the password, when the current password is right.
-- Requirements: NFR02
-- Constraints:  -
--
CREATE FUNCTION change_password(p_username VARCHAR, p_current TEXT, p_new TEXT) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF p_new IS NULL OR p_new = '' THEN
        RAISE EXCEPTION 'A password is required.' USING ERRCODE = 'not_null_violation';
    END IF;
    UPDATE "User" SET password = crypt(p_new, gen_salt('bf', 10))
    WHERE username = p_username AND password = crypt(p_current, password);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'The current password is wrong.' USING ERRCODE = 'invalid_password';
    END IF;
END
$$;


--
-- Title:        save_version(...)
-- Description:  Saves a Drink Version with its Ingredients and its own wanted flavour. A
--               flavour, that is not given, is copied from the base version.
-- Requirements: R19, R28
-- Constraints:  C11, C18, C20
--
CREATE FUNCTION save_version(
    p_drink_identifier INTEGER, p_base_drink_version_id INTEGER,
    p_name VARCHAR, p_branch VARCHAR, p_message VARCHAR,
    p_ingredients JSONB, p_wanted JSONB
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_base   Flavour_Preferences;
    v_wanted Flavour_Preferences;
    v_fp     INTEGER;
    v_id     INTEGER;
BEGIN
    IF p_ingredients IS NULL OR jsonb_typeof(p_ingredients) <> 'array'
       OR jsonb_array_length(p_ingredients) = 0 THEN
        RAISE EXCEPTION 'A Drink Version needs at least one Ingredient.' USING ERRCODE = 'check_violation';
    END IF;

    SELECT fp.* INTO v_base
    FROM Flavour_Preferences fp
    JOIN Drink_Version v ON v.flavour_preferences_identifier = fp.identifier
    WHERE v.drink_version_id = p_base_drink_version_id;
    v_wanted := jsonb_populate_record(NULL::Flavour_Preferences, COALESCE(p_wanted, '{}'::JSONB));

    INSERT INTO Flavour_Preferences
        (sweetness, sourness, spiciness, bitterness, fruitiness, herbalness, smokiness, fizziness, intensity)
    VALUES (
        COALESCE(v_wanted.sweetness,  v_base.sweetness,  10),
        COALESCE(v_wanted.sourness,   v_base.sourness,   10),
        COALESCE(v_wanted.spiciness,  v_base.spiciness,  10),
        COALESCE(v_wanted.bitterness, v_base.bitterness, 10),
        COALESCE(v_wanted.fruitiness, v_base.fruitiness, 10),
        COALESCE(v_wanted.herbalness, v_base.herbalness, 10),
        COALESCE(v_wanted.smokiness,  v_base.smokiness,  10),
        COALESCE(v_wanted.fizziness,  v_base.fizziness,  10),
        COALESCE(v_wanted.intensity,  v_base.intensity,  10))
    RETURNING identifier INTO v_fp;

    INSERT INTO Drink_Version
        (name, branch, message, drink_identifier, author_username,
         flavour_preferences_identifier, base_drink_version_id)
    VALUES (p_name, COALESCE(p_branch, 'main'), p_message, p_drink_identifier, acting_user(),
            v_fp, p_base_drink_version_id)
    RETURNING drink_version_id INTO v_id;

    INSERT INTO Version_Ingredient (drink_version_id, ingredient_name, amount, unit)
    SELECT v_id, x.name, x.amount, COALESCE(x.unit, 'ml')
    FROM jsonb_to_recordset(p_ingredients) AS x(name VARCHAR, amount DECIMAL, unit VARCHAR);

    RETURN v_id;
END
$$;


--
-- Title:        create_drink(...)
-- Description:  Creates a Drink together with its first Drink Version.
-- Requirements: R07, R08
-- Constraints:  C14
--
CREATE FUNCTION create_drink(
    p_name VARCHAR, p_description VARCHAR, p_photo VARCHAR, p_base_spirit VARCHAR,
    p_ingredients JSONB, p_wanted JSONB DEFAULT NULL,
    p_branch VARCHAR DEFAULT 'main', p_message VARCHAR DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_drink INTEGER;
BEGIN
    INSERT INTO Drink (name, description, photo, base_spirit)
    VALUES (p_name, p_description, p_photo, p_base_spirit)
    RETURNING identifier INTO v_drink;
    PERFORM save_version(v_drink, NULL, p_name, p_branch, p_message, p_ingredients, p_wanted);
    RETURN v_drink;
END
$$;


--
-- Title:        add_version(...)
-- Description:  Saves a change as a new Drink Version of the acting user. A version
--               without alcohol clears the base spirit of the Drink.
-- Requirements: R14, R16
-- Constraints:  C17, C18
--
CREATE FUNCTION add_version(
    p_base_drink_version_id INTEGER, p_name VARCHAR, p_branch VARCHAR,
    p_message VARCHAR, p_ingredients JSONB, p_wanted JSONB DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_drink INTEGER;
    v_id    INTEGER;
BEGIN
    SELECT drink_identifier INTO v_drink FROM Drink_Version WHERE drink_version_id = p_base_drink_version_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Drink Version % does not exist.', p_base_drink_version_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;
    v_id := save_version(v_drink, p_base_drink_version_id, p_name, p_branch, p_message, p_ingredients, p_wanted);

    UPDATE Drink SET base_spirit = NULL
    WHERE identifier = v_drink AND base_spirit IS NOT NULL
      AND (SELECT total_alcohol_percentage FROM Drink_Version WHERE drink_version_id = v_id) = 0;
    RETURN v_id;
END
$$;


--
-- Title:        estimated_match_for_user(drink_version_id, username)
-- Description:  Match from 0 to 100 of a Drink Version with the Flavour Preferences and
--               the liked Ingredients of a User, for the suggestions of the Library.
-- Requirements: R25
-- Constraints:  C32
--
CREATE FUNCTION estimated_match_for_user(p_drink_version_id INTEGER, p_username VARCHAR) RETURNS INTEGER
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_taste RECORD;
    v_fp    INTEGER;
    v_match NUMERIC;
BEGIN
    SELECT flavour_preferences_identifier INTO v_fp FROM "User" WHERE username = p_username;
    IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM Version_Ingredient WHERE drink_version_id = p_drink_version_id) THEN
        RETURN NULL;
    END IF;
    SELECT * INTO v_taste FROM version_taste(p_drink_version_id);
    v_match := taste_match(v_taste.sweet, v_taste.sour, v_taste.bitter, v_taste.strong, v_fp);
    IF EXISTS (SELECT 1 FROM Liked_Ingredient WHERE username = p_username) THEN
        v_match := v_match * 0.85 + 0.15 * (EXISTS (
            SELECT 1 FROM Liked_Ingredient l
            JOIN Version_Ingredient vi ON vi.ingredient_name = l.ingredient_name
            WHERE l.username = p_username AND vi.drink_version_id = p_drink_version_id))::INTEGER;
    END IF;
    RETURN round(100 * v_match);
END
$$;


--
-- Title:        share_album(album_identifier)
-- Description:  Makes an Album public. The trigger album_before_update allows it only to
--               the owner.
-- Requirements: R45
-- Constraints:  C24
--
CREATE FUNCTION share_album(p_album_identifier INTEGER) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Album SET public_status = TRUE WHERE identifier = p_album_identifier;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Album % does not exist.', p_album_identifier USING ERRCODE = 'no_data_found';
    END IF;
END
$$;


--
-- Title:        withdraw_album(album_identifier)
-- Description:  Makes an Album private again.
-- Requirements: R45
-- Constraints:  C24
--
CREATE FUNCTION withdraw_album(p_album_identifier INTEGER) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Album SET public_status = FALSE WHERE identifier = p_album_identifier;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Album % does not exist.', p_album_identifier USING ERRCODE = 'no_data_found';
    END IF;
END
$$;
