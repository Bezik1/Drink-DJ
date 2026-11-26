DO $tests$
BEGIN

--
-- Title:        Levels 0 and 20
-- Description:  Test: set the Flavour Preferences of a User to the levels 0 and 20.
-- Requirements: R26
-- Constraints:  C06
--
PERFORM accepts('R26', 'levels 0 and 20',
    $$UPDATE Flavour_Preferences SET sweetness = 0, intensity = 20 WHERE identifier =
          (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice')$$);

--
-- Title:        Level 21
-- Description:  Test: set sweetness of Flavour Preferences to 21. The database must refuse
--               it.
-- Requirements: R26
-- Constraints:  C06
--
PERFORM rejects('R26', 'level 21', 'flavour_preferences_levels_range',
    $$UPDATE Flavour_Preferences SET sweetness = 21 WHERE identifier =
          (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice')$$);

--
-- Title:        Level -1
-- Description:  Test: set intensity of Flavour Preferences to -1. The database must refuse
--               it.
-- Requirements: R26
-- Constraints:  C06
--
PERFORM rejects('R26', 'level -1', 'flavour_preferences_levels_range',
    $$UPDATE Flavour_Preferences SET intensity = -1 WHERE identifier =
          (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice')$$);

--
-- Title:        Blank level
-- Description:  Test: set fizziness of Flavour Preferences to blank. The database must
--               refuse it.
-- Requirements: R26
-- Constraints:  -
--
PERFORM rejects('R26', 'blank level', 'not-null',
    $$UPDATE Flavour_Preferences SET fizziness = NULL WHERE identifier =
          (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice')$$);

--
-- Title:        New user has its own preferences
-- Description:  Test: register a User, after which it has its own Flavour Preferences.
-- Requirements: R27
-- Constraints:  C12, C20
--
PERFORM accepts('R27', 'new user has its own preferences',
    $$SELECT expect(EXISTS (SELECT 1 FROM "User" u JOIN Flavour_Preferences fp
          ON fp.identifier = u.flavour_preferences_identifier WHERE u.username = 't_carol'), 'preferences exist')$$);

--
-- Title:        Preferences of another user
-- Description:  Test: insert a User with the Flavour Preferences of another User. The
--               database must refuse it.
-- Requirements: R27
-- Constraints:  C12, C20
--
PERFORM rejects('R27', 'preferences of another user', 'user_flavour_preferences_unique',
    $$INSERT INTO "User" (username, email, password, flavour_preferences_identifier)
      VALUES ('t_copy', 't_copy@example.com', crypt('Copy-Test-1', gen_salt('bf', 4)),
              (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice'))$$);

--
-- Title:        Replace the preferences of a user
-- Description:  Test: update flavour_preferences_identifier of a User. The database must
--               refuse it.
-- Requirements: R27
-- Constraints:  C12, C20
--
PERFORM rejects('R27', 'replace the preferences of a user', 'cannot be changed',
    $$UPDATE "User" SET flavour_preferences_identifier = (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_bob')
      WHERE username = 't_alice'$$);

--
-- Title:        New version copies the wanted flavour of its base
-- Description:  Test: add a version without a wanted flavour, after which it has a new
--               Flavour Preferences row with the levels of its base version.
-- Requirements: R28
-- Constraints:  C11, C20
--
PERFORM accepts('R28', 'new version copies the wanted flavour of its base',
    $$SELECT set_acting_user('t_bob')$$,
    $$SELECT add_version(version_id('T Exact', 1), 'T Exact 2', 'main', NULL, '[{"name": "T Gin", "amount": 50}]')$$,
    $$SELECT expect((
          SELECT a.identifier <> b.identifier
             AND (a.sweetness, a.sourness, a.spiciness, a.bitterness, a.fruitiness, a.herbalness, a.smokiness, a.fizziness, a.intensity)
               = (b.sweetness, b.sourness, b.spiciness, b.bitterness, b.fruitiness, b.herbalness, b.smokiness, b.fizziness, b.intensity)
          FROM Flavour_Preferences a, Flavour_Preferences b
          WHERE a.identifier = (SELECT flavour_preferences_identifier FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 2))
            AND b.identifier = (SELECT flavour_preferences_identifier FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 1))), 'copied')$$);

--
-- Title:        Preferences of another version
-- Description:  Test: insert a Drink Version with the Flavour Preferences of another Drink
--               Version. The database must refuse it.
-- Requirements: R28
-- Constraints:  C11, C20
--
PERFORM rejects('R28', 'preferences of another version', 'drink_version_flavour_preferences_unique',
    $$SELECT insert_raw_version(drink_id('T Gin Sour'), version_id('T Gin Sour', 1), 'copy', NULL, NULL, 0, 0,
          (SELECT flavour_preferences_identifier FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 1)))$$);

--
-- Title:        Deleting a version deletes its preferences
-- Description:  Test: delete a Drink Version, after which its Flavour Preferences are
--               deleted.
-- Requirements: R29
-- Constraints:  C20
--
PERFORM accepts('R29', 'deleting a version deletes its preferences',
    $$CREATE TEMP TABLE r29_fp AS SELECT flavour_preferences_identifier AS identifier FROM Drink_Version
          WHERE drink_version_id = version_id('T Exact', 2)$$,
    $$DELETE FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 2)$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Flavour_Preferences WHERE identifier = (SELECT identifier FROM r29_fp)), 'preferences deleted')$$);

--
-- Title:        Version with the preferences of a user
-- Description:  Test: insert a Drink Version with the Flavour Preferences of a User. The
--               database must refuse it.
-- Requirements: R29
-- Constraints:  C20
--
PERFORM rejects('R29', 'version with the preferences of a user', 'already belong to a User',
    $$SELECT insert_raw_version(drink_id('T Gin Sour'), version_id('T Gin Sour', 1), 'copy', NULL, NULL, 0, 0,
          (SELECT flavour_preferences_identifier FROM "User" WHERE username = 't_alice'))$$);

--
-- Title:        Preferences without an owner
-- Description:  Test: insert Flavour Preferences without an owner and commit. The database
--               must refuse it.
-- Requirements: R29
-- Constraints:  C20
--
PERFORM rejects('R29', 'preferences without an owner', 'belong neither',
    $$INSERT INTO Flavour_Preferences DEFAULT VALUES$$);

END
$tests$;
