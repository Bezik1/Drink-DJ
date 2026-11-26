DO $tests$
BEGIN

--
-- Title:        New album is private, empty, created today
-- Description:  Test: insert a custom Album with only a name and an owner, after which it
--               is private, has 0 Drinks and the date of today.
-- Requirements: R37
-- Constraints:  C02, C33
--
PERFORM accepts('R37', 'new album is private, empty, created today',
    $$INSERT INTO Album (name, username) VALUES ('T Weekend', 't_alice')$$,
    $$SELECT expect((SELECT kind = 'custom' AND NOT public_status AND number_of_drinks = 0
          AND date_of_creation = CURRENT_DATE FROM Album WHERE identifier = album_id('t_alice', 'T Weekend')), 'defaults')$$);

--
-- Title:        Album without a name
-- Description:  Test: insert an Album without a name. The database must refuse it.
-- Requirements: R37
-- Constraints:  -
--
PERFORM rejects('R37', 'album without a name', 'not-null',
    $$INSERT INTO Album (username) VALUES ('t_alice')$$);

--
-- Title:        Deleting a user deletes its albums
-- Description:  Test: delete a User, after which its Albums are deleted.
-- Requirements: R38
-- Constraints:  C38
--
PERFORM accepts('R38', 'deleting a user deletes its albums',
    $$SELECT register_user('t_jack', 't_jack@example.com', 'Jack-Test-1')$$,
    $$INSERT INTO Album (name, username) VALUES ('T Jack Album', 't_jack')$$,
    $$DELETE FROM "User" WHERE username = 't_jack'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Album WHERE username = 't_jack'), 'albums deleted')$$);

--
-- Title:        Album of an unknown user
-- Description:  Test: insert an Album of a username, that is not in the database. The
--               database must refuse it.
-- Requirements: R38
-- Constraints:  -
--
PERFORM rejects('R38', 'album of an unknown user', 'album_user_fk',
    $$INSERT INTO Album (name, username) VALUES ('T Ghost Album', 't_ghost')$$);

--
-- Title:        Change the owner of an album
-- Description:  Test: change the owner of an Album. The database must refuse it.
-- Requirements: R38
-- Constraints:  -
--
PERFORM rejects('R38', 'change the owner of an album', 'owner of an Album cannot be changed',
    $$UPDATE Album SET username = 't_bob' WHERE identifier = album_id('t_alice', 'T Weekend')$$);

--
-- Title:        New user gets its three system albums
-- Description:  Test: register a User, after which it has exactly one favourites,
--               to_check_out and your_drinks Album.
-- Requirements: R39
-- Constraints:  C21
--
PERFORM accepts('R39', 'new user gets its three system albums',
    $$SELECT expect((SELECT count(*) = 3 AND count(DISTINCT kind) = 3 FROM Album
          WHERE username = 't_carol' AND kind IN ('favourites', 'to_check_out', 'your_drinks')), 'three system albums')$$);

--
-- Title:        Delete a custom album
-- Description:  Test: delete a custom Album.
-- Requirements: R39
-- Constraints:  C21
--
PERFORM accepts('R39', 'delete a custom album',
    $$INSERT INTO Album (name, username) VALUES ('T Temporary', 't_alice')$$,
    $$DELETE FROM Album WHERE identifier = album_id('t_alice', 'T Temporary')$$);

--
-- Title:        Second favourites album
-- Description:  Test: insert a second favourites Album of a User. The database must refuse
--               it.
-- Requirements: R39
-- Constraints:  C21
--
PERFORM rejects('R39', 'second favourites album', 'album_one_system_album_per_kind',
    $$INSERT INTO Album (name, kind, username) VALUES ('T Favourites 2', 'favourites', 't_alice')$$);

--
-- Title:        Delete the favourites album
-- Description:  Test: delete the favourites Album of a User. The database must refuse it.
-- Requirements: R39
-- Constraints:  C21
--
PERFORM rejects('R39', 'delete the favourites album', 'cannot be deleted',
    $$DELETE FROM Album WHERE identifier = system_album_id('t_alice', 'favourites')$$);

--
-- Title:        Turn a custom album into favourites
-- Description:  Test: change kind of a custom Album to favourites. The database must
--               refuse it.
-- Requirements: R39
-- Constraints:  C21
--
PERFORM rejects('R39', 'turn a custom album into favourites', 'kind of an Album cannot be changed',
    $$UPDATE Album SET kind = 'favourites' WHERE identifier = album_id('t_alice', 'T Weekend')$$);

--
-- Title:        Unknown kind shared
-- Description:  Test: insert an Album of the kind shared. The database must refuse it.
-- Requirements: R39
-- Constraints:  C02
--
PERFORM rejects('R39', 'unknown kind shared', 'album_kind_domain',
    $$INSERT INTO Album (name, kind, username) VALUES ('T Shared Kind', 'shared', 't_alice')$$);

--
-- Title:        Album without an icon shows the default one
-- Description:  Test: insert an Album without icon and photo, after which Visible_Album
--               shows the default icon to its owner.
-- Requirements: R40
-- Constraints:  C13, C22
--
PERFORM accepts('R40', 'album without an icon shows the default one',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT expect((SELECT icon = 'square.stack.3d.up' AND photo IS NULL FROM Visible_Album
          WHERE identifier = album_id('t_alice', 'T Weekend')), 'default icon')$$);

--
-- Title:        Add a drink to an album today
-- Description:  Test: add a Drink to an Album, after which date_of_adding is today.
-- Requirements: R41
-- Constraints:  -
--
PERFORM accepts('R41', 'add a drink to an album today',
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (album_id('t_alice', 'T Weekend'), drink_id('T Martini'))$$,
    $$SELECT expect((SELECT date_of_adding FROM Album_Entry WHERE album_identifier = album_id('t_alice', 'T Weekend')
          AND drink_identifier = drink_id('T Martini')) = CURRENT_DATE, 'date today')$$);

--
-- Title:        Deleting a drink removes it from albums
-- Description:  Test: delete a Drink, after which it leaves every Album.
-- Requirements: R41
-- Constraints:  C42
--
PERFORM accepts('R41', 'deleting a drink removes it from albums',
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT create_drink('T Gone', 'x', NULL, 'gin', '[{"name": "T Gin", "amount": 50}]')$$,
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (album_id('t_alice', 'T Weekend'), drink_id('T Gone'))$$,
    $$DELETE FROM Drink WHERE name = 'T Gone'$$,
    $$SELECT expect((SELECT number_of_drinks FROM Album WHERE identifier = album_id('t_alice', 'T Weekend')) = 1, 'entry deleted')$$);

--
-- Title:        Add an unknown drink
-- Description:  Test: add a Drink, that is not in the database, to an Album. The database
--               must refuse it.
-- Requirements: R41
-- Constraints:  -
--
PERFORM rejects('R41', 'add an unknown drink', 'album_entry_drink_fk',
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (album_id('t_alice', 'T Weekend'), -1)$$);

--
-- Title:        Same drink in two albums
-- Description:  Test: add the same Drink to two Albums.
-- Requirements: R42
-- Constraints:  -
--
PERFORM accepts('R42', 'same drink in two albums',
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (system_album_id('t_alice', 'favourites'), drink_id('T Martini'))$$);

--
-- Title:        Same drink twice in one album
-- Description:  Test: add the same Drink to an Album twice. The database must refuse it.
-- Requirements: R42
-- Constraints:  -
--
PERFORM rejects('R42', 'same drink twice in one album', 'album_entry_pk',
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (album_id('t_alice', 'T Weekend'), drink_id('T Martini'))$$);

--
-- Title:        Number_of_drinks follows the entries
-- Description:  Test: add two Drinks to an empty Album, after which number_of_drinks is 2,
--               and remove one, after which it is 1.
-- Requirements: R43
-- Constraints:  C33
--
PERFORM accepts('R43', 'number_of_drinks follows the entries',
    $$INSERT INTO Album (name, username) VALUES ('T Counted', 't_bob')$$,
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES
          (album_id('t_bob', 'T Counted'), drink_id('T Martini')), (album_id('t_bob', 'T Counted'), drink_id('T Collins'))$$,
    $$SELECT expect((SELECT number_of_drinks FROM Album WHERE identifier = album_id('t_bob', 'T Counted')) = 2, 'two drinks')$$,
    $$DELETE FROM Album_Entry WHERE album_identifier = album_id('t_bob', 'T Counted') AND drink_identifier = drink_id('T Martini')$$,
    $$SELECT expect((SELECT number_of_drinks FROM Album WHERE identifier = album_id('t_bob', 'T Counted')) = 1, 'one drink')$$);

--
-- Title:        Set number_of_drinks by hand
-- Description:  Test: update number_of_drinks directly. The database must refuse it.
-- Requirements: R43
-- Constraints:  C33
--
PERFORM rejects('R43', 'set number_of_drinks by hand', 'calculated by the database',
    $$UPDATE Album SET number_of_drinks = 10 WHERE identifier = album_id('t_bob', 'T Counted')$$);

--
-- Title:        Insert number_of_drinks by hand
-- Description:  Test: insert an Album with number_of_drinks 5. The database must refuse
--               it.
-- Requirements: R43
-- Constraints:  C33
--
PERFORM rejects('R43', 'insert number_of_drinks by hand', 'calculated by the database',
    $$INSERT INTO Album (name, number_of_drinks, username) VALUES ('T Fake Count', 5, 't_bob')$$);

--
-- Title:        Own version adds the drink to your_drinks
-- Description:  Test: add a version as t_alice, after which its Drink is in her
--               your_drinks Album.
-- Requirements: R44
-- Constraints:  C23
--
PERFORM accepts('R44', 'own version adds the drink to your_drinks',
    $$SELECT expect(EXISTS (SELECT 1 FROM Album_Entry WHERE album_identifier = system_album_id('t_alice', 'your_drinks')
          AND drink_identifier = drink_id('T Mule')), 'in your drinks')$$);

--
-- Title:        Deleting the own version removes it from your_drinks
-- Description:  Test: delete the only version of t_bob of a Drink, after which the Drink
--               leaves his your_drinks Album.
-- Requirements: R44
-- Constraints:  C23
--
PERFORM accepts('R44', 'deleting the own version removes it from your_drinks',
    $$SELECT set_acting_user('t_bob')$$,
    $$SELECT add_version(version_id('T Collins', 1), 'T Bob Collins', 'bob', NULL, '[{"name": "T Gin", "amount": 50}, {"name": "T Soda Water", "amount": 100}]')$$,
    $$SELECT expect(EXISTS (SELECT 1 FROM Album_Entry WHERE album_identifier = system_album_id('t_bob', 'your_drinks')
          AND drink_identifier = drink_id('T Collins')), 'added')$$,
    $$DELETE FROM Drink_Version WHERE name = 'T Bob Collins'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Album_Entry WHERE album_identifier = system_album_id('t_bob', 'your_drinks')
          AND drink_identifier = drink_id('T Collins')), 'removed')$$);

--
-- Title:        Add to your_drinks by hand
-- Description:  Test: insert a Drink into a your_drinks Album directly. The database must
--               refuse it.
-- Requirements: R44
-- Constraints:  C23
--
PERFORM rejects('R44', 'add to your_drinks by hand', 'filled by the database',
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (system_album_id('t_alice', 'your_drinks'), drink_id('T Martini'))$$);

--
-- Title:        Remove from your_drinks by hand
-- Description:  Test: delete a Drink from a your_drinks Album directly. The database must
--               refuse it.
-- Requirements: R44
-- Constraints:  C23
--
PERFORM rejects('R44', 'remove from your_drinks by hand', 'filled by the database',
    $$DELETE FROM Album_Entry WHERE album_identifier = system_album_id('t_alice', 'your_drinks') AND drink_identifier = drink_id('T Mule')$$);

--
-- Title:        Owner shares and withdraws an album
-- Description:  Test: as t_alice, share and withdraw her Album.
-- Requirements: R45
-- Constraints:  C24
--
PERFORM accepts('R45', 'owner shares and withdraws an album',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT share_album(album_id('t_alice', 'T Weekend'))$$,
    $$SELECT expect((SELECT public_status FROM Album WHERE identifier = album_id('t_alice', 'T Weekend')), 'shared')$$,
    $$SELECT withdraw_album(album_id('t_alice', 'T Weekend'))$$,
    $$SELECT expect((SELECT NOT public_status FROM Album WHERE identifier = album_id('t_alice', 'T Weekend')), 'withdrawn')$$);

--
-- Title:        Someone else shares an album
-- Description:  Test: as t_bob, share an Album of t_alice. The database must refuse it.
-- Requirements: R45
-- Constraints:  C24
--
PERFORM rejects('R45', 'someone else shares an album', 'Only the owner',
    $$SELECT set_acting_user('t_bob')$$,
    $$SELECT share_album(album_id('t_alice', 'T Weekend'))$$);

--
-- Title:        Guest shares an album
-- Description:  Test: share an Album without an acting user. The database must refuse it.
-- Requirements: R45
-- Constraints:  C24
--
PERFORM rejects('R45', 'guest shares an album', 'Only the owner',
    $$SELECT set_acting_user(NULL)$$,
    $$UPDATE Album SET public_status = TRUE WHERE identifier = album_id('t_alice', 'T Weekend')$$);

--
-- Title:        Others see only public albums
-- Description:  Test: as t_bob, Visible_Album shows the public Albums of t_alice and none
--               of her private Albums.
-- Requirements: R46
-- Constraints:  C25
--
PERFORM accepts('R46', 'others see only public albums',
    $$SELECT set_acting_user('t_bob')$$,
    $$SELECT expect(EXISTS (SELECT 1 FROM Visible_Album WHERE name = 'T Guest Can See'), 'public visible')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Visible_Album WHERE username = 't_alice' AND NOT public_status), 'private hidden')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Visible_Album_Entry WHERE album_identifier = album_id('t_alice', 'T Weekend')), 'entries hidden')$$);

--
-- Title:        Owner sees its private albums
-- Description:  Test: as t_alice, Visible_Album shows her private Albums.
-- Requirements: R46
-- Constraints:  C25
--
PERFORM accepts('R46', 'owner sees its private albums',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT expect(EXISTS (SELECT 1 FROM Visible_Album WHERE identifier = album_id('t_alice', 'T Weekend')), 'own private visible')$$);

--
-- Title:        Deleting a user removes all its data
-- Description:  Test: delete a User with one statement, after which its Passkeys, Flavour
--               Preferences, Reviews, liked Ingredients and Albums are deleted, and its
--               Drink Versions remain with a blank author.
-- Requirements: R47
-- Constraints:  C26
--
PERFORM accepts('R47', 'deleting a user removes all its data',
    $$SELECT register_user('t_kate', 't_kate@example.com', 'Kate-Test-1')$$,
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES ('cred-t-kate', 'pk-kate', 't_kate')$$,
    $$INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES ('t_kate', 'T Gin')$$,
    $$INSERT INTO Album (name, username) VALUES ('T Kate Album', 't_kate')$$,
    $$SELECT set_acting_user('t_kate')$$,
    $$SELECT add_version(version_id('T Classic', 1), 'T Classic Kate', 'kate', NULL, '[{"name": "T Gin", "amount": 45}]')$$,
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (5, version_id('T Classic', 1), 't_kate')$$,
    $$CREATE TEMP TABLE r47_fp AS SELECT flavour_preferences_identifier AS identifier FROM "User" WHERE username = 't_kate'$$,
    $$SELECT set_acting_user(NULL)$$,
    $$DELETE FROM "User" WHERE username = 't_kate'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Passkey WHERE username = 't_kate'), 'passkeys')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Flavour_Preferences WHERE identifier = (SELECT identifier FROM r47_fp)), 'preferences')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Review WHERE username = 't_kate'), 'reviews')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Liked_Ingredient WHERE username = 't_kate'), 'likes')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Album WHERE username = 't_kate'), 'albums')$$,
    $$SELECT expect((SELECT author_username IS NULL FROM Drink_Version WHERE name = 'T Classic Kate'), 'version kept')$$);

END
$tests$;
