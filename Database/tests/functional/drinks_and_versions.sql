DO $tests$
BEGIN

--
-- Title:        Create a drink with all its data
-- Description:  Test: create a Drink with name, description, photo and base spirit with
--               create_drink().
-- Requirements: R07
-- Constraints:  C01
--
PERFORM accepts('R07', 'create a drink with all its data',
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT create_drink('T Martini', 'Gin and nothing else.', 'martini.jpg', 'gin', '[{"name": "T Gin", "amount": 60}]')$$,
    $$SELECT expect((SELECT photo = 'martini.jpg' AND date_of_creation = CURRENT_DATE FROM Drink WHERE name = 'T Martini'), 'drink saved')$$);

--
-- Title:        Drink without a name
-- Description:  Test: insert a Drink without a name. The database must refuse it.
-- Requirements: R07
-- Constraints:  -
--
PERFORM rejects('R07', 'drink without a name', 'not-null',
    $$INSERT INTO Drink (description) VALUES ('No name.')$$);

--
-- Title:        Drink without a description
-- Description:  Test: insert a Drink without a description. The database must refuse it.
-- Requirements: R07
-- Constraints:  -
--
PERFORM rejects('R07', 'drink without a description', 'not-null',
    $$INSERT INTO Drink (name) VALUES ('T No Description')$$);

--
-- Title:        Drink is created with version 1
-- Description:  Test: create a Drink together with its first Drink Version in one
--               transaction.
-- Requirements: R08
-- Constraints:  C14
--
PERFORM accepts('R08', 'drink is created with version 1',
    $$SELECT create_drink('T Collins', 'Gin, lime, sugar and soda.', NULL, 'gin',
          '[{"name": "T Gin", "amount": 50}, {"name": "T Lime Juice", "amount": 25}, {"name": "T Soda Water", "amount": 60}]')$$,
    $$SELECT expect(version_id('T Collins', 1) IS NOT NULL, 'version 1 exists')$$);

--
-- Title:        Deleting a drink deletes its versions
-- Description:  Test: delete a Drink, after which its Drink Versions are deleted.
-- Requirements: R08
-- Constraints:  C36
--
PERFORM accepts('R08', 'deleting a drink deletes its versions',
    $$SELECT create_drink('T Delete Me', 'Temporary.', NULL, 'vodka', '[{"name": "T Vodka", "amount": 50}]')$$,
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Delete Me', 1), 'T Delete Me 2', 'main', NULL, '[{"name": "T Vodka", "amount": 40}]')$$,
    $$SELECT set_acting_user(NULL)$$,
    $$DELETE FROM Drink WHERE name = 'T Delete Me'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Drink_Version WHERE name LIKE 'T Delete Me%'), 'versions deleted')$$);

--
-- Title:        Drink without a version
-- Description:  Test: insert a Drink without a Drink Version and commit. The database must
--               refuse it.
-- Requirements: R08
-- Constraints:  C14
--
PERFORM rejects('R08', 'drink without a version', 'has no Drink Version',
    $$INSERT INTO Drink (name, description) VALUES ('T Empty', 'No versions.')$$);

--
-- Title:        Deleting the only version of a drink
-- Description:  Test: delete the only Drink Version of a Drink and commit. The database
--               must refuse it.
-- Requirements: R08
-- Constraints:  C14
--
PERFORM rejects('R08', 'deleting the only version of a drink', 'has no Drink Version',
    $$DELETE FROM Drink_Version WHERE drink_version_id = version_id('T Martini', 1)$$);

--
-- Title:        Saved version has all its columns
-- Description:  Test: save a Drink Version, after which it has a version number, a name,
--               the branch main, the date of today, a total volume and a total alcohol
--               percentage.
-- Requirements: R09
-- Constraints:  C14, C29, C30
--
PERFORM accepts('R09', 'saved version has all its columns',
    $$SELECT expect((SELECT version_number = 1 AND name = 'T Gin Sour' AND branch = 'main'
          AND date_of_creation = CURRENT_DATE AND total_volume = 100 AND total_alcohol_percentage = 20
          FROM Drink_Version WHERE drink_version_id = version_id('T Gin Sour', 1)), 'columns set')$$);

--
-- Title:        Version without a name
-- Description:  Test: save a Drink Version without a name. The database must refuse it.
-- Requirements: R09
-- Constraints:  -
--
PERFORM rejects('R09', 'version without a name', 'not-null',
    $$SELECT add_version(version_id('T Gin Sour', 1), NULL, 'main', NULL, '[{"name": "T Gin", "amount": 50}]')$$);

--
-- Title:        Version with a blank branch
-- Description:  Test: save a Drink Version with a blank branch. The database must refuse
--               it.
-- Requirements: R09
-- Constraints:  C16
--
PERFORM rejects('R09', 'version with a blank branch', 'drink_version_branch_not_blank',
    $$SELECT add_version(version_id('T Gin Sour', 1), 'T Blank Branch', ' ', NULL, '[{"name": "T Gin", "amount": 50}]')$$);

--
-- Title:        New versions get the numbers 2 and 3
-- Description:  Test: add two versions to a Drink with one version, after which they have
--               the numbers 2 and 3.
-- Requirements: R10
-- Constraints:  C14
--
PERFORM accepts('R10', 'new versions get the numbers 2 and 3',
    $$SELECT create_drink('T Mule', 'Vodka, lime and soda.', NULL, 'vodka',
          '[{"name": "T Vodka", "amount": 50}, {"name": "T Lime Juice", "amount": 15}, {"name": "T Soda Water", "amount": 100}]')$$,
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Mule', 1), 'T Mule 2', 'main', 'More lime',
          '[{"name": "T Vodka", "amount": 50}, {"name": "T Lime Juice", "amount": 25}, {"name": "T Soda Water", "amount": 100}]')$$,
    $$SELECT add_version(version_id('T Mule', 2), 'T Mule 3', 'main', 'Less soda',
          '[{"name": "T Vodka", "amount": 50}, {"name": "T Lime Juice", "amount": 25}, {"name": "T Soda Water", "amount": 80}]')$$,
    $$SELECT expect((SELECT name FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 3)) = 'T Mule 3', 'numbers 2 and 3')$$);

--
-- Title:        Delete the latest version
-- Description:  Test: delete version 3, the latest Drink Version of the Drink.
-- Requirements: R10
-- Constraints:  C14
--
PERFORM accepts('R10', 'delete the latest version',
    $$DELETE FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 3)$$,
    $$SELECT expect(version_id('T Mule', 3) IS NULL, 'version 3 deleted')$$);

--
-- Title:        Skipped version number
-- Description:  Test: insert a Drink Version with version_number 7, when the next number
--               is 3. The database must refuse it.
-- Requirements: R10
-- Constraints:  C14
--
PERFORM rejects('R10', 'skipped version number', 'next version number',
    $$SELECT insert_raw_version(drink_id('T Mule'), version_id('T Mule', 2), 'main', 7)$$);

--
-- Title:        Delete a version, that is not the latest
-- Description:  Test: delete version 1, while version 2 exists. The database must refuse
--               it.
-- Requirements: R10
-- Constraints:  C14
--
PERFORM rejects('R10', 'delete a version, that is not the latest', 'Only the latest',
    $$DELETE FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 1)$$);

--
-- Title:        Version 2 is based on version 1
-- Description:  Test: add version 2 based on version 1 of the same Drink.
-- Requirements: R11
-- Constraints:  C15
--
PERFORM accepts('R11', 'version 2 is based on version 1',
    $$SELECT expect((SELECT base_drink_version_id FROM Drink_Version
          WHERE drink_version_id = version_id('T Mule', 2)) = version_id('T Mule', 1), 'based on version 1')$$);

--
-- Title:        Later version without a base
-- Description:  Test: insert version 3 without a base Drink Version. The database must
--               refuse it.
-- Requirements: R11
-- Constraints:  C15
--
PERFORM rejects('R11', 'later version without a base', 'must be based on',
    $$SELECT insert_raw_version(drink_id('T Mule'), NULL, 'main')$$);

--
-- Title:        Base version of another drink
-- Description:  Test: insert a Drink Version based on a Drink Version of another Drink.
--               The database must refuse it.
-- Requirements: R11
-- Constraints:  C15
--
PERFORM rejects('R11', 'base version of another drink', 'same Drink',
    $$SELECT insert_raw_version(drink_id('T Mule'), version_id('T Gin Sour', 1), 'other')$$);

--
-- Title:        Continue a branch from its latest version
-- Description:  Test: continue the branch main from its latest version.
-- Requirements: R12
-- Constraints:  C16
--
PERFORM accepts('R12', 'continue a branch from its latest version',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Mule', 2), 'T Mule 3', 'main', NULL, '[{"name": "T Vodka", "amount": 60}, {"name": "T Soda Water", "amount": 100}]')$$,
    $$SELECT expect((SELECT branch FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 3)) = 'main', 'main continued')$$);

--
-- Title:        Start a new branch from an older version
-- Description:  Test: start the new branch spicy from version 1.
-- Requirements: R12
-- Constraints:  C16
--
PERFORM accepts('R12', 'start a new branch from an older version',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Mule', 1), 'T Spicy Mule', 'spicy', 'New branch', '[{"name": "T Vodka", "amount": 50}, {"name": "T Lime Juice", "amount": 20}]')$$,
    $$SELECT expect((SELECT branch FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 4)) = 'spicy', 'branch spicy')$$);

--
-- Title:        Continue a branch from an older version
-- Description:  Test: continue the branch main from version 1, while version 3 is its
--               latest. The database must refuse it.
-- Requirements: R12
-- Constraints:  C16
--
PERFORM rejects('R12', 'continue a branch from an older version', 'continues only from its latest',
    $$SELECT add_version(version_id('T Mule', 1), 'T Old Main', 'main', NULL, '[{"name": "T Vodka", "amount": 50}]')$$);

--
-- Title:        Version without a message
-- Description:  Test: add a version without a message.
-- Requirements: R13
-- Constraints:  C13
--
PERFORM accepts('R13', 'version without a message',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Mule', 4), 'T Spicy Mule 2', 'spicy', NULL, '[{"name": "T Vodka", "amount": 55}, {"name": "T Lime Juice", "amount": 20}]')$$,
    $$SELECT expect((SELECT message IS NULL FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 5)), 'no message')$$);

--
-- Title:        Drink with the base spirit gin
-- Description:  Test: create a Drink with the base spirit gin.
-- Requirements: R14
-- Constraints:  C01
--
PERFORM accepts('R14', 'drink with the base spirit gin',
    $$SELECT create_drink('T Gimlet', 'Gin and lime.', NULL, 'gin', '[{"name": "T Gin", "amount": 60}, {"name": "T Lime Juice", "amount": 20}]')$$);

--
-- Title:        Mocktail without a base spirit
-- Description:  Test: create a mocktail with a blank base_spirit.
-- Requirements: R14
-- Constraints:  C01, C17
--
PERFORM accepts('R14', 'mocktail without a base spirit',
    $$SELECT create_drink('T Lime Soda', 'Lime and soda.', NULL, NULL, '[{"name": "T Lime Juice", "amount": 30}, {"name": "T Soda Water", "amount": 120}]')$$);

--
-- Title:        Version without alcohol clears the base spirit
-- Description:  Test: add a version without alcohol to an alcoholic Drink, after which
--               base_spirit of the Drink is blank.
-- Requirements: R14
-- Constraints:  C17
--
PERFORM accepts('R14', 'version without alcohol clears the base spirit',
    $$SELECT create_drink('T Vodka Soda', 'Vodka and soda.', NULL, 'vodka', '[{"name": "T Vodka", "amount": 50}, {"name": "T Soda Water", "amount": 100}]')$$,
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT add_version(version_id('T Vodka Soda', 1), 'T Soda Only', 'zero', NULL, '[{"name": "T Soda Water", "amount": 150}]')$$,
    $$SELECT expect((SELECT base_spirit IS NULL FROM Drink WHERE name = 'T Vodka Soda'), 'base spirit cleared')$$);

--
-- Title:        Unknown base spirit brandy
-- Description:  Test: create a Drink with the base spirit brandy. The database must refuse
--               it.
-- Requirements: R14
-- Constraints:  C01
--
PERFORM rejects('R14', 'unknown base spirit brandy', 'drink_base_spirit_domain',
    $$SELECT create_drink('T Brandy', 'x', NULL, 'brandy', '[{"name": "T Vodka", "amount": 50}]')$$);

--
-- Title:        Mocktail with a base spirit
-- Description:  Test: create a mocktail with the base spirit rum and commit. The database
--               must refuse it.
-- Requirements: R14
-- Constraints:  C17
--
PERFORM rejects('R14', 'mocktail with a base spirit', 'base_spirit must be empty',
    $$SELECT create_drink('T Fake Rum', 'x', NULL, 'rum', '[{"name": "T Lime Juice", "amount": 30}, {"name": "T Soda Water", "amount": 100}]')$$);

--
-- Title:        Alcoholic drink without a base spirit
-- Description:  Test: create an alcoholic Drink with a blank base_spirit and commit. The
--               database must refuse it.
-- Requirements: R14
-- Constraints:  C17
--
PERFORM rejects('R14', 'alcoholic drink without a base spirit', 'base_spirit must be empty',
    $$SELECT create_drink('T No Spirit', 'x', NULL, NULL, '[{"name": "T Vodka", "amount": 50}, {"name": "T Soda Water", "amount": 100}]')$$);

--
-- Title:        Classic drink has no author
-- Description:  Test: create a classic Drink without an acting user, after which its
--               version has a blank author.
-- Requirements: R15
-- Constraints:  C18
--
PERFORM accepts('R15', 'classic drink has no author',
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT create_drink('T Classic', 'A classic.', NULL, 'gin', '[{"name": "T Gin", "amount": 50}, {"name": "T Simple Syrup", "amount": 10}]')$$,
    $$SELECT expect((SELECT author_username IS NULL FROM Drink_Version WHERE drink_version_id = version_id('T Classic', 1)), 'no author')$$);

--
-- Title:        Acting user is the author
-- Description:  Test: add a version as t_alice, after which its author is t_alice.
-- Requirements: R15
-- Constraints:  C18
--
PERFORM accepts('R15', 'acting user is the author',
    $$SELECT expect((SELECT author_username FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 2)) = 't_alice', 'author t_alice')$$);

--
-- Title:        Versions stay after their author is deleted
-- Description:  Test: delete a User, after which its Drink Versions remain with a blank
--               author.
-- Requirements: R15
-- Constraints:  C34
--
PERFORM accepts('R15', 'versions stay after their author is deleted',
    $$SELECT register_user('t_ivan', 't_ivan@example.com', 'Ivan-Test-1')$$,
    $$SELECT set_acting_user('t_ivan')$$,
    $$SELECT add_version(version_id('T Classic', 1), 'T Classic Ivan', 'ivan', NULL, '[{"name": "T Gin", "amount": 60}]')$$,
    $$SELECT set_acting_user(NULL)$$,
    $$DELETE FROM "User" WHERE username = 't_ivan'$$,
    $$SELECT expect((SELECT author_username IS NULL FROM Drink_Version WHERE name = 'T Classic Ivan'), 'author cleared')$$);

--
-- Title:        Version authored by someone else
-- Description:  Test: as t_alice, insert a Drink Version authored by t_bob. The database
--               must refuse it.
-- Requirements: R15
-- Constraints:  C18
--
PERFORM rejects('R15', 'version authored by someone else', 'cannot save a Drink Version authored',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT insert_raw_version(drink_id('T Classic'), version_id('T Classic', 1), 'bob', NULL, 't_bob')$$);

--
-- Title:        Remix keeps the original version unchanged
-- Description:  Test: as t_bob, add a version based on a version of t_alice, after which
--               the new version is authored by t_bob and the version of t_alice is
--               unchanged.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM accepts('R16', 'remix keeps the original version unchanged',
    $$CREATE TEMP TABLE r16_before AS
          SELECT v.*, (SELECT string_agg(ingredient_name || amount || unit, ',' ORDER BY ingredient_name)
                       FROM Version_Ingredient WHERE drink_version_id = v.drink_version_id) AS ingredients
          FROM Drink_Version v WHERE drink_version_id = version_id('T Mule', 2)$$,
    $$SELECT set_acting_user('t_bob')$$,
    $$SELECT add_version(version_id('T Mule', 2), 'T Bob Mule', 'bob', 'Remix of t_alice', '[{"name": "T Vodka", "amount": 40}, {"name": "T Soda Water", "amount": 120}]')$$,
    $$SELECT expect((SELECT author_username FROM Drink_Version WHERE name = 'T Bob Mule') = 't_bob', 'author t_bob')$$,
    $$SELECT expect((SELECT b::TEXT FROM r16_before b) =
          (SELECT a::TEXT FROM (SELECT v.*, (SELECT string_agg(ingredient_name || amount || unit, ',' ORDER BY ingredient_name)
                                             FROM Version_Ingredient WHERE drink_version_id = v.drink_version_id) AS ingredients
                                FROM Drink_Version v WHERE drink_version_id = version_id('T Mule', 2)) a), 'base unchanged')$$);

--
-- Title:        Rename a saved version
-- Description:  Test: update the name of a saved Drink Version. The database must refuse
--               it.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM rejects('R16', 'rename a saved version', 'cannot be changed directly',
    $$UPDATE Drink_Version SET name = 'T Renamed' WHERE drink_version_id = version_id('T Gin Sour', 1)$$);

--
-- Title:        Add an ingredient to a saved version
-- Description:  Test: insert an Ingredient into a Drink Version saved in an earlier
--               transaction. The database must refuse it.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM rejects('R16', 'add an ingredient to a saved version', 'Ingredients cannot be changed',
    $$INSERT INTO Version_Ingredient VALUES (version_id('T Gin Sour', 1), 'T Soda Water', 50, 'ml')$$);

--
-- Title:        Change an amount of a saved version
-- Description:  Test: update the amount of an Ingredient of a Drink Version saved in an
--               earlier transaction. The database must refuse it.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM rejects('R16', 'change an amount of a saved version', 'Ingredients cannot be changed',
    $$UPDATE Version_Ingredient SET amount = 60 WHERE drink_version_id = version_id('T Gin Sour', 1) AND ingredient_name = 'T Gin'$$);

--
-- Title:        Remove an ingredient of a saved version
-- Description:  Test: delete an Ingredient of a Drink Version saved in an earlier
--               transaction. The database must refuse it.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM rejects('R16', 'remove an ingredient of a saved version', 'Ingredients cannot be changed',
    $$DELETE FROM Version_Ingredient WHERE drink_version_id = version_id('T Gin Sour', 1) AND ingredient_name = 'T Simple Syrup'$$);

--
-- Title:        Change the wanted flavour of a saved version
-- Description:  Test: update the wanted flavour of a Drink Version saved in an earlier
--               transaction. The database must refuse it.
-- Requirements: R16
-- Constraints:  C18
--
PERFORM rejects('R16', 'change the wanted flavour of a saved version', 'wanted flavour of the saved',
    $$UPDATE Flavour_Preferences SET sweetness = 1 WHERE identifier =
          (SELECT flavour_preferences_identifier FROM Drink_Version WHERE drink_version_id = version_id('T Gin Sour', 1))$$);

END
$tests$;
