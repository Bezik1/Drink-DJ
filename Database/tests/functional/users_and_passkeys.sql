DO $tests$
BEGIN

--
-- Title:        Register a user, created today
-- Description:  Test: register a new User with a unique username, e-mail and password,
--               after which date_of_account_creation is today.
-- Requirements: R01
-- Constraints:  -
--
PERFORM accepts('R01', 'register a user, created today',
    $$SELECT register_user('t_carol', 't_carol@example.com', 'Carol-Test-1')$$,
    $$SELECT expect((SELECT date_of_account_creation FROM "User" WHERE username = 't_carol') = CURRENT_DATE, 'date is today')$$);

--
-- Title:        Blank username
-- Description:  Test: insert a new User with a blank username. The database must refuse
--               it.
-- Requirements: R01
-- Constraints:  -
--
PERFORM rejects('R01', 'blank username', 'user_username_not_blank',
    $$SELECT register_user('  ', 't_blank@example.com', 'Blank-Test-1')$$);

--
-- Title:        Missing e-mail
-- Description:  Test: insert a new User without an e-mail. The database must refuse it.
-- Requirements: R01
-- Constraints:  -
--
PERFORM rejects('R01', 'missing e-mail', 'not-null',
    $$SELECT register_user('t_nomail', NULL, 'NoMail-Test-1')$$);

--
-- Title:        Two users with different usernames and e-mails
-- Description:  Test: register two Users with different usernames and e-mails.
-- Requirements: R02
-- Constraints:  C09
--
PERFORM accepts('R02', 'two users with different usernames and e-mails',
    $$SELECT register_user('t_dave', 't_dave@example.com', 'Dave-Test-1')$$,
    $$SELECT register_user('t_erin', 't_erin@example.com', 'Erin-Test-1')$$);

--
-- Title:        Rename a user, albums and passkeys follow
-- Description:  Test: rename a User, after which its Albums and Passkeys belong to the new
--               username.
-- Requirements: R02
-- Constraints:  -
--
PERFORM accepts('R02', 'rename a user, albums and passkeys follow',
    $$SELECT register_user('t_frank', 't_frank@example.com', 'Frank-Test-1')$$,
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES ('cred-t-frank', 'pk-frank', 't_frank')$$,
    $$UPDATE "User" SET username = 't_franky' WHERE username = 't_frank'$$,
    $$SELECT expect((SELECT count(*) FROM Album WHERE username = 't_franky') = 3, 'albums renamed')$$,
    $$SELECT expect((SELECT username FROM Passkey WHERE credential_identifier = 'cred-t-frank') = 't_franky', 'passkey renamed')$$);

--
-- Title:        Duplicate username
-- Description:  Test: register a User with a username, that is already in the database.
--               The database must refuse it.
-- Requirements: R02
-- Constraints:  -
--
PERFORM rejects('R02', 'duplicate username', 'user_pk',
    $$SELECT register_user('t_alice', 't_other@example.com', 'Other-Test-1')$$);

--
-- Title:        E-mail differing only in letter case
-- Description:  Test: register a User with an e-mail, that differs from an existing one
--               only in letter case. The database must refuse it.
-- Requirements: R02
-- Constraints:  C09
--
PERFORM rejects('R02', 'e-mail differing only in letter case', 'user_email_unique',
    $$SELECT register_user('t_other', 'T_ALICE@example.com', 'Other-Test-1')$$);

--
-- Title:        Invalid e-mail format
-- Description:  Test: register a User with the e-mail t_alice.example.com. The database
--               must refuse it.
-- Requirements: R02
-- Constraints:  -
--
PERFORM rejects('R02', 'invalid e-mail format', 'user_email_format',
    $$SELECT register_user('t_other', 't_alice.example.com', 'Other-Test-1')$$);

--
-- Title:        User without a profile image
-- Description:  Test: register a User without profile_image.
-- Requirements: R03
-- Constraints:  C13
--
PERFORM accepts('R03', 'user without a profile image',
    $$SELECT register_user('t_gina', 't_gina@example.com', 'Gina-Test-1')$$,
    $$SELECT expect((SELECT profile_image IS NULL FROM "User" WHERE username = 't_gina'), 'no image')$$);

--
-- Title:        Two passkeys of one user, created today
-- Description:  Test: insert two Passkeys of one User, after which their date_of_creation
--               is today.
-- Requirements: R04
-- Constraints:  -
--
PERFORM accepts('R04', 'two passkeys of one user, created today',
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES
          ('cred-t-alice-1', 'pk-alice-1', 't_alice'), ('cred-t-alice-2', 'pk-alice-2', 't_alice')$$,
    $$SELECT expect((SELECT count(*) FROM Passkey WHERE username = 't_alice' AND date_of_creation = CURRENT_DATE) = 2, 'two passkeys')$$);

--
-- Title:        Passkey without a public key
-- Description:  Test: insert a Passkey without public_key. The database must refuse it.
-- Requirements: R04
-- Constraints:  -
--
PERFORM rejects('R04', 'passkey without a public key', 'not-null',
    $$INSERT INTO Passkey (credential_identifier, username) VALUES ('cred-t-alice-3', 't_alice')$$);

--
-- Title:        Deleting a user deletes its passkeys
-- Description:  Test: delete a User, after which its Passkeys are deleted.
-- Requirements: R05
-- Constraints:  C37
--
PERFORM accepts('R05', 'deleting a user deletes its passkeys',
    $$SELECT register_user('t_henry', 't_henry@example.com', 'Henry-Test-1')$$,
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES ('cred-t-henry', 'pk-henry', 't_henry')$$,
    $$DELETE FROM "User" WHERE username = 't_henry'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Passkey WHERE credential_identifier = 'cred-t-henry'), 'passkey deleted')$$);

--
-- Title:        Duplicate credential identifier
-- Description:  Test: insert a Passkey with a credential_identifier, that is already in
--               the database. The database must refuse it.
-- Requirements: R05
-- Constraints:  -
--
PERFORM rejects('R05', 'duplicate credential identifier', 'passkey_pk',
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES ('cred-t-alice-1', 'pk-bob', 't_bob')$$);

--
-- Title:        Passkey of an unknown user
-- Description:  Test: insert a Passkey of a username, that is not in the database. The
--               database must refuse it.
-- Requirements: R05
-- Constraints:  -
--
PERFORM rejects('R05', 'passkey of an unknown user', 'passkey_user_fk',
    $$INSERT INTO Passkey (credential_identifier, public_key, username) VALUES ('cred-t-ghost', 'pk', 't_ghost')$$);

--
-- Title:        Passkey without a user
-- Description:  Test: insert a Passkey with a blank username. The database must refuse it.
-- Requirements: R05
-- Constraints:  -
--
PERFORM rejects('R05', 'passkey without a user', 'not-null',
    $$INSERT INTO Passkey (credential_identifier, public_key) VALUES ('cred-t-nobody', 'pk')$$);

--
-- Title:        Guest sees only public albums
-- Description:  Test: without an acting user (a Guest), Visible_Album returns the public
--               Albums and no private one.
-- Requirements: R06
-- Constraints:  C25
--
PERFORM accepts('R06', 'guest sees only public albums',
    $$SELECT set_acting_user('t_alice')$$,
    $$INSERT INTO Album (name, username) VALUES ('T Guest Can See', 't_alice')$$,
    $$SELECT share_album(album_id('t_alice', 'T Guest Can See'))$$,
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT expect(EXISTS (SELECT 1 FROM Visible_Album WHERE name = 'T Guest Can See'), 'public album visible')$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Visible_Album WHERE NOT public_status), 'no private album')$$);

END
$tests$;
