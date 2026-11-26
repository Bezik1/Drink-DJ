--
-- Title:        trg_flavour_preferences_single_owner
-- Description:  Flavour Preferences belong to a User or to a Drink Version, never to both.
-- Requirements: R29
-- Constraints:  C20
--
CREATE FUNCTION trg_flavour_preferences_single_owner() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_TABLE_NAME = 'User' THEN
        IF EXISTS (SELECT 1 FROM Drink_Version
                   WHERE flavour_preferences_identifier = NEW.flavour_preferences_identifier) THEN
            RAISE EXCEPTION 'Flavour Preferences % already belong to a Drink Version.',
                NEW.flavour_preferences_identifier USING ERRCODE = 'unique_violation';
        END IF;
    ELSIF EXISTS (SELECT 1 FROM "User"
                  WHERE flavour_preferences_identifier = NEW.flavour_preferences_identifier) THEN
        RAISE EXCEPTION 'Flavour Preferences % already belong to a User.',
            NEW.flavour_preferences_identifier USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END
$$;


--
-- Title:        trg_flavour_preferences_has_owner
-- Description:  At COMMIT every Flavour Preferences row has an owner.
-- Requirements: R29
-- Constraints:  C20
--
CREATE FUNCTION trg_flavour_preferences_has_owner() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Flavour_Preferences WHERE identifier = NEW.identifier)
       AND NOT EXISTS (SELECT 1 FROM "User" WHERE flavour_preferences_identifier = NEW.identifier)
       AND NOT EXISTS (SELECT 1 FROM Drink_Version WHERE flavour_preferences_identifier = NEW.identifier) THEN
        RAISE EXCEPTION 'Flavour Preferences % belong neither to a User nor to a Drink Version.',
            NEW.identifier USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER flavour_preferences_has_owner
    AFTER INSERT ON Flavour_Preferences
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_flavour_preferences_has_owner();


--
-- Title:        trg_flavour_preferences_before_update
-- Description:  The wanted flavour of a saved Drink Version cannot change.
-- Requirements: R16, R28
-- Constraints:  C18
--
CREATE FUNCTION trg_flavour_preferences_before_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_version INTEGER;
BEGIN
    IF NEW.identifier <> OLD.identifier THEN
        RAISE EXCEPTION 'identifier of Flavour Preferences cannot be changed.' USING ERRCODE = 'check_violation';
    END IF;
    SELECT drink_version_id INTO v_version FROM Drink_Version
    WHERE flavour_preferences_identifier = OLD.identifier;
    IF FOUND AND pg_trigger_depth() <= 1 AND NOT is_open_version(v_version) THEN
        RAISE EXCEPTION 'The wanted flavour of the saved Drink Version % cannot be changed. Save a new Drink Version.',
            v_version USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER flavour_preferences_before_update
    BEFORE UPDATE ON Flavour_Preferences
    FOR EACH ROW EXECUTE FUNCTION trg_flavour_preferences_before_update();


--
-- Title:        trg_flavour_preferences_after_update
-- Description:  Recalculates the estimated match, when the wanted flavour of a version
--               changes, while the version is being saved.
-- Requirements: R25
-- Constraints:  C32
--
CREATE FUNCTION trg_flavour_preferences_after_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM refresh_drink_version(drink_version_id)
    FROM Drink_Version WHERE flavour_preferences_identifier = NEW.identifier;
    RETURN NULL;
END
$$;

CREATE TRIGGER flavour_preferences_after_update
    AFTER UPDATE ON Flavour_Preferences
    FOR EACH ROW EXECUTE FUNCTION trg_flavour_preferences_after_update();


--
-- Title:        user_flavour_preferences_single_owner
-- Description:  Runs trg_flavour_preferences_single_owner for a new User.
-- Requirements: R29
-- Constraints:  C20
--
CREATE TRIGGER user_flavour_preferences_single_owner
    BEFORE INSERT ON "User"
    FOR EACH ROW EXECUTE FUNCTION trg_flavour_preferences_single_owner();


--
-- Title:        trg_user_before_update
-- Description:  The Flavour Preferences of a User cannot be replaced.
-- Requirements: R27
-- Constraints:  C12, C20
--
CREATE FUNCTION trg_user_before_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.flavour_preferences_identifier <> OLD.flavour_preferences_identifier THEN
        RAISE EXCEPTION 'flavour_preferences_identifier of a User cannot be changed. Update its Flavour Preferences instead.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER user_before_update
    BEFORE UPDATE ON "User"
    FOR EACH ROW EXECUTE FUNCTION trg_user_before_update();


--
-- Title:        trg_user_create_system_albums
-- Description:  Every new User gets its favourites, to_check_out and your_drinks Albums.
-- Requirements: R39
-- Constraints:  C21
--
CREATE FUNCTION trg_user_create_system_albums() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO Album (name, icon, kind, username) VALUES
        ('Favourites',   'heart.fill',     'favourites',   NEW.username),
        ('To Check Out', 'bookmark.fill',  'to_check_out', NEW.username),
        ('Your Drinks',  'wineglass.fill', 'your_drinks',  NEW.username);
    RETURN NULL;
END
$$;

CREATE TRIGGER user_create_system_albums
    AFTER INSERT ON "User"
    FOR EACH ROW EXECUTE FUNCTION trg_user_create_system_albums();


--
-- Title:        trg_user_after_delete
-- Description:  Deletes the Flavour Preferences of a deleted User.
-- Requirements: R29, R47
-- Constraints:  C20, C26
--
CREATE FUNCTION trg_user_after_delete() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM Flavour_Preferences WHERE identifier = OLD.flavour_preferences_identifier;
    RETURN NULL;
END
$$;

CREATE TRIGGER user_after_delete
    AFTER DELETE ON "User"
    FOR EACH ROW EXECUTE FUNCTION trg_user_after_delete();


--
-- Title:        trg_drink_protect_derived
-- Description:  popularity and average_rating are set only by the database.
-- Requirements: R34, R35
-- Constraints:  C27, C28
--
CREATE FUNCTION trg_drink_protect_derived() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() <= 1 THEN
        IF TG_OP = 'INSERT' AND (NEW.popularity <> 0 OR NEW.average_rating <> 0) THEN
            RAISE EXCEPTION 'popularity and average_rating are calculated by the database.'
                USING ERRCODE = 'check_violation';
        ELSIF TG_OP = 'UPDATE' AND (NEW.popularity, NEW.average_rating)
                                   IS DISTINCT FROM (OLD.popularity, OLD.average_rating) THEN
            RAISE EXCEPTION 'popularity and average_rating are calculated by the database.'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER drink_protect_derived
    BEFORE INSERT OR UPDATE ON Drink
    FOR EACH ROW EXECUTE FUNCTION trg_drink_protect_derived();


--
-- Title:        trg_drink_has_versions
-- Description:  At COMMIT a Drink has at least one Drink Version.
-- Requirements: R08
-- Constraints:  C14
--
CREATE FUNCTION trg_drink_has_versions() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_drink INTEGER;
BEGIN
    IF TG_TABLE_NAME = 'drink' THEN
        v_drink := NEW.identifier;
    ELSE
        v_drink := OLD.drink_identifier;
    END IF;
    IF EXISTS (SELECT 1 FROM Drink WHERE identifier = v_drink)
       AND NOT EXISTS (SELECT 1 FROM Drink_Version WHERE drink_identifier = v_drink) THEN
        RAISE EXCEPTION 'Drink % has no Drink Version.', v_drink USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER drink_has_versions
    AFTER INSERT ON Drink
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_has_versions();

CREATE CONSTRAINT TRIGGER drink_version_delete_keeps_versions
    AFTER DELETE ON Drink_Version
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_has_versions();


--
-- Title:        trg_drink_base_spirit_matches_alcohol
-- Description:  At COMMIT base_spirit is empty exactly when the latest Drink Version has
--               no alcohol.
-- Requirements: R14
-- Constraints:  C17
--
CREATE FUNCTION trg_drink_base_spirit_matches_alcohol() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_drink       INTEGER;
    v_base_spirit VARCHAR;
    v_alcohol     NUMERIC;
BEGIN
    IF TG_TABLE_NAME = 'drink' THEN
        v_drink := NEW.identifier;
    ELSIF TG_OP = 'DELETE' THEN
        v_drink := OLD.drink_identifier;
    ELSE
        v_drink := NEW.drink_identifier;
    END IF;

    SELECT d.base_spirit, latest.total_alcohol_percentage INTO v_base_spirit, v_alcohol
    FROM Drink d
    JOIN LATERAL (SELECT v.total_alcohol_percentage FROM Drink_Version v
                  WHERE v.drink_identifier = d.identifier
                  ORDER BY v.version_number DESC LIMIT 1) latest ON TRUE
    WHERE d.identifier = v_drink;

    IF FOUND AND (v_base_spirit IS NULL) <> (v_alcohol = 0) THEN
        RAISE EXCEPTION 'Drink %: base_spirit must be empty exactly when its latest Drink Version has no alcohol (alcohol % %%, base_spirit %).',
            v_drink, v_alcohol, COALESCE(v_base_spirit, 'empty') USING ERRCODE = 'check_violation';
    END IF;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER drink_base_spirit_matches_alcohol
    AFTER INSERT OR UPDATE OF base_spirit ON Drink
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_base_spirit_matches_alcohol();

CREATE CONSTRAINT TRIGGER drink_version_base_spirit_matches_alcohol
    AFTER INSERT OR DELETE OR UPDATE OF total_alcohol_percentage ON Drink_Version
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_base_spirit_matches_alcohol();


--
-- Title:        drink_version_flavour_preferences_single_owner
-- Description:  Runs trg_flavour_preferences_single_owner for a new Drink Version.
-- Requirements: R29
-- Constraints:  C20
--
CREATE TRIGGER drink_version_flavour_preferences_single_owner
    BEFORE INSERT ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_flavour_preferences_single_owner();


--
-- Title:        trg_drink_version_before_insert
-- Description:  Sets the version number, checks the base, the branch and the author, and
--               protects the calculated columns of a new Drink Version.
-- Requirements: R10, R11, R12, R15, R21, R22, R24, R25
-- Constraints:  C14, C15, C16, C18, C29, C30, C31, C32
--
CREATE FUNCTION trg_drink_version_before_insert() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_next   INTEGER;
    v_base   Drink_Version;
    v_latest INTEGER;
BEGIN
    -- R10: the next version number. The lock serialises versions saved at the same time.
    PERFORM 1 FROM Drink WHERE identifier = NEW.drink_identifier FOR UPDATE;
    SELECT COALESCE(max(version_number), 0) + 1 INTO v_next
    FROM Drink_Version WHERE drink_identifier = NEW.drink_identifier;
    IF NEW.version_number IS NOT NULL AND NEW.version_number <> v_next THEN
        RAISE EXCEPTION 'The next version number of Drink % is %, not %.',
            NEW.drink_identifier, v_next, NEW.version_number USING ERRCODE = 'check_violation';
    END IF;
    NEW.version_number := v_next;

    -- R11: only version 1 has no base, and the base belongs to the same Drink.
    IF NEW.base_drink_version_id IS NULL THEN
        IF v_next <> 1 THEN
            RAISE EXCEPTION 'Version % of Drink % must be based on a Drink Version.',
                v_next, NEW.drink_identifier USING ERRCODE = 'check_violation';
        END IF;
    ELSE
        SELECT * INTO v_base FROM Drink_Version WHERE drink_version_id = NEW.base_drink_version_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Base Drink Version % does not exist.', NEW.base_drink_version_id
                USING ERRCODE = 'foreign_key_violation';
        END IF;
        IF v_base.drink_identifier <> NEW.drink_identifier THEN
            RAISE EXCEPTION 'A Drink Version can be based only on a Drink Version of the same Drink.'
                USING ERRCODE = 'check_violation';
        END IF;

        -- R12: an existing branch continues only from its latest version.
        SELECT max(version_number) INTO v_latest
        FROM Drink_Version WHERE drink_identifier = NEW.drink_identifier AND branch = NEW.branch;
        IF v_latest IS NOT NULL AND v_latest <> v_base.version_number THEN
            RAISE EXCEPTION 'Branch "%" continues only from its latest version %, not from version %.',
                NEW.branch, v_latest, v_base.version_number USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    -- R15: the author is the acting user.
    IF acting_user() IS NOT NULL THEN
        IF NEW.author_username IS NULL THEN
            NEW.author_username := acting_user();
        ELSIF NEW.author_username <> acting_user() THEN
            RAISE EXCEPTION 'User % cannot save a Drink Version authored by %.',
                acting_user(), NEW.author_username USING ERRCODE = 'insufficient_privilege';
        END IF;
    END IF;

    -- R21, R22, R24, R25: the derived columns are set only by the database.
    IF pg_trigger_depth() <= 1 AND (
           NEW.total_volume <> 0 OR NEW.total_alcohol_percentage <> 0 OR NEW.estimated_match <> 0
           OR NEW.flavour_distribution <> '{"sour": 0, "sweet": 0, "bitter": 0, "strong": 0}') THEN
        RAISE EXCEPTION 'total_volume, total_alcohol_percentage, flavour_distribution and estimated_match are calculated by the database.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER drink_version_before_insert
    BEFORE INSERT ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_before_insert();


--
-- Title:        trg_drink_version_before_update
-- Description:  A saved Drink Version cannot be changed by the client. Save the change
--               with add_version().
-- Requirements: R16, R21, R22, R24, R25
-- Constraints:  C18, C29, C30, C31, C32
--
CREATE FUNCTION trg_drink_version_before_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW IS NOT DISTINCT FROM OLD THEN
        RETURN NEW;
    END IF;
    IF pg_trigger_depth() <= 1 THEN
        RAISE EXCEPTION 'Drink Version % cannot be changed directly. Save the change with add_version().',
            OLD.drink_version_id USING ERRCODE = 'check_violation';
    END IF;
    IF (NEW.drink_identifier, NEW.version_number, NEW.name, NEW.branch, NEW.message,
        NEW.date_of_creation, NEW.flavour_preferences_identifier)
       IS DISTINCT FROM
       (OLD.drink_identifier, OLD.version_number, OLD.name, OLD.branch, OLD.message,
        OLD.date_of_creation, OLD.flavour_preferences_identifier)
       OR (NEW.base_drink_version_id IS NOT NULL
           AND NEW.base_drink_version_id IS DISTINCT FROM OLD.base_drink_version_id) THEN
        RAISE EXCEPTION 'Drink Version % is saved and cannot be changed.', OLD.drink_version_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER drink_version_before_update
    BEFORE UPDATE ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_before_update();


--
-- Title:        trg_drink_version_before_delete
-- Description:  Only the latest Drink Version can be deleted, so that the numbers stay
--               consecutive.
-- Requirements: R10
-- Constraints:  C14
--
CREATE FUNCTION trg_drink_version_before_delete() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Drink WHERE identifier = OLD.drink_identifier)
       AND EXISTS (SELECT 1 FROM Drink_Version
                   WHERE drink_identifier = OLD.drink_identifier AND version_number > OLD.version_number) THEN
        RAISE EXCEPTION 'Only the latest Drink Version of Drink % can be deleted.', OLD.drink_identifier
            USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN OLD;
END
$$;

CREATE TRIGGER drink_version_before_delete
    BEFORE DELETE ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_before_delete();


--
-- Title:        trg_drink_version_after_insert
-- Description:  Opens the new version for its Ingredients and adds its Drink to the
--               your_drinks Album of the author.
-- Requirements: R16, R44
-- Constraints:  C18, C23
--
CREATE FUNCTION trg_drink_version_after_insert() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM open_version(NEW.drink_version_id);
    IF NEW.author_username IS NOT NULL THEN
        INSERT INTO Album_Entry (album_identifier, drink_identifier)
        SELECT a.identifier, NEW.drink_identifier
        FROM Album a
        WHERE a.username = NEW.author_username AND a.kind = 'your_drinks'
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER drink_version_after_insert
    AFTER INSERT ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_after_insert();


--
-- Title:        trg_drink_version_after_delete
-- Description:  Deletes the Flavour Preferences of a deleted version, and updates the
--               statistics of the Drink and the your_drinks Album of the author.
-- Requirements: R29, R34, R44
-- Constraints:  C20, C23, C27, C28
--
CREATE FUNCTION trg_drink_version_after_delete() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM Flavour_Preferences WHERE identifier = OLD.flavour_preferences_identifier;
    PERFORM refresh_drink_stats(OLD.drink_identifier);
    IF OLD.author_username IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Drink_Version
                       WHERE drink_identifier = OLD.drink_identifier
                         AND author_username = OLD.author_username) THEN
        DELETE FROM Album_Entry e
        USING Album a
        WHERE a.identifier = e.album_identifier AND a.kind = 'your_drinks'
          AND a.username = OLD.author_username AND e.drink_identifier = OLD.drink_identifier;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER drink_version_after_delete
    AFTER DELETE ON Drink_Version
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_after_delete();


--
-- Title:        trg_drink_version_has_ingredients
-- Description:  At COMMIT a Drink Version has at least one Ingredient.
-- Requirements: R19
-- Constraints:  -
--
CREATE FUNCTION trg_drink_version_has_ingredients() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_version INTEGER := CASE WHEN TG_TABLE_NAME = 'drink_version'
                              THEN NEW.drink_version_id ELSE OLD.drink_version_id END;
BEGIN
    IF EXISTS (SELECT 1 FROM Drink_Version WHERE drink_version_id = v_version)
       AND NOT EXISTS (SELECT 1 FROM Version_Ingredient WHERE drink_version_id = v_version) THEN
        RAISE EXCEPTION 'Drink Version % contains no Ingredient.', v_version
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER drink_version_has_ingredients
    AFTER INSERT ON Drink_Version
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_has_ingredients();

CREATE CONSTRAINT TRIGGER version_ingredient_keeps_ingredients
    AFTER DELETE OR UPDATE ON Version_Ingredient
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION trg_drink_version_has_ingredients();


--
-- Title:        trg_version_ingredient_only_open_version
-- Description:  Ingredients change only in the transaction, that saves their Drink
--               Version.
-- Requirements: R16
-- Constraints:  C18
--
CREATE FUNCTION trg_version_ingredient_only_open_version() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() <= 1 THEN
        IF TG_OP <> 'INSERT' AND NOT is_open_version(OLD.drink_version_id) THEN
            RAISE EXCEPTION 'Drink Version % is saved and its Ingredients cannot be changed. Save the change with add_version().',
                OLD.drink_version_id USING ERRCODE = 'check_violation';
        END IF;
        IF TG_OP <> 'DELETE' AND NOT is_open_version(NEW.drink_version_id) THEN
            RAISE EXCEPTION 'Drink Version % is saved and its Ingredients cannot be changed. Save the change with add_version().',
                NEW.drink_version_id USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER version_ingredient_only_open_version
    BEFORE INSERT OR UPDATE OR DELETE ON Version_Ingredient
    FOR EACH ROW EXECUTE FUNCTION trg_version_ingredient_only_open_version();


--
-- Title:        trg_version_ingredient_refresh
-- Description:  Recalculates a Drink Version after a change of its Ingredients.
-- Requirements: R21, R22, R24, R25
-- Constraints:  C29, C30, C31, C32
--
CREATE FUNCTION trg_version_ingredient_refresh() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM refresh_drink_version(OLD.drink_version_id);
    END IF;
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.drink_version_id <> OLD.drink_version_id) THEN
        PERFORM refresh_drink_version(NEW.drink_version_id);
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER version_ingredient_refresh
    AFTER INSERT OR UPDATE OR DELETE ON Version_Ingredient
    FOR EACH ROW EXECUTE FUNCTION trg_version_ingredient_refresh();


--
-- Title:        trg_ingredient_after_update
-- Description:  A changed alcohol percentage or category updates the Drink Versions, that
--               use the Ingredient.
-- Requirements: R22
-- Constraints:  C30, C31, C32
--
CREATE FUNCTION trg_ingredient_after_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.alcohol_percentage, NEW.category) IS DISTINCT FROM (OLD.alcohol_percentage, OLD.category) THEN
        PERFORM refresh_drink_version(vi.drink_version_id)
        FROM Version_Ingredient vi WHERE vi.ingredient_name = NEW.name;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER ingredient_after_update
    AFTER UPDATE ON Ingredient
    FOR EACH ROW EXECUTE FUNCTION trg_ingredient_after_update();


--
-- Title:        trg_review_refresh_drink
-- Description:  Reviews update the average rating and the popularity of their Drink.
-- Requirements: R34, R35
-- Constraints:  C27, C28
--
CREATE FUNCTION trg_review_refresh_drink() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM refresh_drink_stats(v.drink_identifier)
        FROM Drink_Version v WHERE v.drink_version_id = OLD.drink_version_id;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM refresh_drink_stats(v.drink_identifier)
        FROM Drink_Version v WHERE v.drink_version_id = NEW.drink_version_id;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER review_refresh_drink
    AFTER INSERT OR UPDATE OR DELETE ON Review
    FOR EACH ROW EXECUTE FUNCTION trg_review_refresh_drink();


--
-- Title:        trg_album_before_insert
-- Description:  A new Album starts with no Drinks.
-- Requirements: R43
-- Constraints:  C33
--
CREATE FUNCTION trg_album_before_insert() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() <= 1 AND NEW.number_of_drinks <> 0 THEN
        RAISE EXCEPTION 'number_of_drinks is calculated by the database.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER album_before_insert
    BEFORE INSERT ON Album
    FOR EACH ROW EXECUTE FUNCTION trg_album_before_insert();


--
-- Title:        trg_album_before_update
-- Description:  The kind and the owner are fixed, only the owner shares the Album, and
--               number_of_drinks is calculated.
-- Requirements: R38, R39, R43, R45
-- Constraints:  C21, C24, C33, C38
--
CREATE FUNCTION trg_album_before_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.kind <> OLD.kind THEN
        RAISE EXCEPTION 'kind of an Album cannot be changed.' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.username <> OLD.username AND pg_trigger_depth() <= 1 THEN
        RAISE EXCEPTION 'The owner of an Album cannot be changed.' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.public_status <> OLD.public_status AND acting_user() IS DISTINCT FROM OLD.username THEN
        RAISE EXCEPTION 'Only the owner % can share or withdraw Album %.', OLD.username, OLD.identifier
            USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NEW.number_of_drinks <> OLD.number_of_drinks AND pg_trigger_depth() <= 1 THEN
        RAISE EXCEPTION 'number_of_drinks is calculated by the database.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER album_before_update
    BEFORE UPDATE ON Album
    FOR EACH ROW EXECUTE FUNCTION trg_album_before_update();


--
-- Title:        trg_album_before_delete
-- Description:  The system Albums are deleted only together with their owner.
-- Requirements: R39
-- Constraints:  C21
--
CREATE FUNCTION trg_album_before_delete() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.kind <> 'custom' AND EXISTS (SELECT 1 FROM "User" WHERE username = OLD.username) THEN
        RAISE EXCEPTION 'The % album of % cannot be deleted.', OLD.kind, OLD.username
            USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN OLD;
END
$$;

CREATE TRIGGER album_before_delete
    BEFORE DELETE ON Album
    FOR EACH ROW EXECUTE FUNCTION trg_album_before_delete();


--
-- Title:        trg_album_entry_protect_your_drinks
-- Description:  The your_drinks Album is filled only by the database.
-- Requirements: R44
-- Constraints:  C23
--
CREATE FUNCTION trg_album_entry_protect_your_drinks() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() <= 1 AND (
           (TG_OP <> 'DELETE' AND EXISTS (SELECT 1 FROM Album
                WHERE identifier = NEW.album_identifier AND kind = 'your_drinks'))
        OR (TG_OP <> 'INSERT' AND EXISTS (SELECT 1 FROM Album
                WHERE identifier = OLD.album_identifier AND kind = 'your_drinks'))) THEN
        RAISE EXCEPTION 'The your drinks album holds exactly the Drinks authored by its owner and is filled by the database.'
            USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER album_entry_protect_your_drinks
    BEFORE INSERT OR UPDATE OR DELETE ON Album_Entry
    FOR EACH ROW EXECUTE FUNCTION trg_album_entry_protect_your_drinks();


--
-- Title:        trg_album_entry_refresh
-- Description:  Entries update the number of Drinks of the Album and the popularity of the
--               Drink.
-- Requirements: R35, R43
-- Constraints:  C27, C33
--
CREATE FUNCTION trg_album_entry_refresh() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM refresh_album_count(OLD.album_identifier);
        PERFORM refresh_drink_stats(OLD.drink_identifier);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM refresh_album_count(NEW.album_identifier);
        PERFORM refresh_drink_stats(NEW.drink_identifier);
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER album_entry_refresh
    AFTER INSERT OR UPDATE OR DELETE ON Album_Entry
    FOR EACH ROW EXECUTE FUNCTION trg_album_entry_refresh();
