DO $tests$
BEGIN

--
-- Title:        Password is stored as a bcrypt hash
-- Description:  Test: register a User, after which its password is a bcrypt hash and not
--               the plain text.
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM accepts('NFR02', 'password is stored as a bcrypt hash',
    $$SELECT expect((SELECT password LIKE '$2a$10$%' AND password <> 'Carol-Test-1' FROM "User" WHERE username = 't_carol'), 'bcrypt hash')$$);

--
-- Title:        Login with the right password
-- Description:  Test: log in with the right e-mail and password, after which
--               authenticate_user() returns the username.
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM accepts('NFR02', 'login with the right password',
    $$SELECT expect(authenticate_user('T_Carol@example.com', 'Carol-Test-1') = 't_carol', 'logged in')$$);

--
-- Title:        Login with a wrong password
-- Description:  Test: log in with a wrong password, after which authenticate_user()
--               returns no user (FR05).
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM accepts('NFR02', 'login with a wrong password',
    $$SELECT expect(authenticate_user('t_carol@example.com', 'wrong') IS NULL, 'refused')$$);

--
-- Title:        Change the password
-- Description:  Test: change the password with the current password, after which only the
--               new password logs in.
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM accepts('NFR02', 'change the password',
    $$SELECT change_password('t_carol', 'Carol-Test-1', 'Carol-Test-2')$$,
    $$SELECT expect(authenticate_user('t_carol@example.com', 'Carol-Test-2') = 't_carol'
          AND authenticate_user('t_carol@example.com', 'Carol-Test-1') IS NULL, 'password changed')$$);

--
-- Title:        Plain text password
-- Description:  Test: insert a User with a plain text password. The database must refuse
--               it.
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM rejects('NFR02', 'plain text password', 'user_password_bcrypt',
    $$WITH fp AS (INSERT INTO Flavour_Preferences DEFAULT VALUES RETURNING identifier)
      INSERT INTO "User" (username, email, password, flavour_preferences_identifier)
      SELECT 't_plain', 't_plain@example.com', 'Plain-Text-1', identifier FROM fp$$);

--
-- Title:        Change the password with a wrong current one
-- Description:  Test: change the password with a wrong current password. The database must
--               refuse it.
-- Requirements: NFR02
-- Constraints:  -
--
PERFORM rejects('NFR02', 'change the password with a wrong current one', 'current password is wrong',
    $$SELECT change_password('t_carol', 'wrong', 'Carol-Test-3')$$);

--
-- Title:        Passkey with a public key
-- Description:  Test: insert a Passkey with a public key.
-- Requirements: NFR03
-- Constraints:  -
--
PERFORM accepts('NFR03', 'passkey with a public key',
    $$INSERT INTO Passkey (credential_identifier, public_key, username)
      VALUES ('cred-t-bob', '-----BEGIN PUBLIC KEY-----MFkwEwYH-----END PUBLIC KEY-----', 't_bob')$$);

--
-- Title:        Passkey with a private key
-- Description:  Test: insert a Passkey, whose public_key holds a private key. The database
--               must refuse it.
-- Requirements: NFR03
-- Constraints:  -
--
PERFORM rejects('NFR03', 'passkey with a private key', 'passkey_public_key_only',
    $$INSERT INTO Passkey (credential_identifier, public_key, username)
      VALUES ('cred-t-leak', '-----BEGIN PRIVATE KEY-----MIGHAgEA-----END PRIVATE KEY-----', 't_bob')$$);

END
$tests$;
