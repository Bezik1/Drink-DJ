-- Sample data of the Drink DJ database. Run once, after install.sql:
-- psql -d drink_dj -f Database/data/insert_sample_data.sql


\set ON_ERROR_STOP on

BEGIN;


--
-- Title:        Ingredients
-- Description:  21 spirits and additions of the classic Drinks.
-- Requirements: R17, R18
-- Constraints:  C03, C05
--
INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES
    ('Vodka',             'alcohol',  40),
    ('Gin',               'alcohol',  40),
    ('White Rum',         'alcohol',  40),
    ('Tequila',           'alcohol',  40),
    ('Whisky',            'alcohol',  40),
    ('Orange Liqueur',    'alcohol',  40),
    ('Coffee Liqueur',    'alcohol',  20),
    ('Campari',           'alcohol',  25),
    ('Sweet Vermouth',    'alcohol',  16),
    ('Angostura Bitters', 'addition', 44.7),
    ('Lime Juice',        'addition', 0),
    ('Lemon Juice',       'addition', 0),
    ('Simple Syrup',      'addition', 0),
    ('Agave Syrup',       'addition', 0),
    ('Ginger Beer',       'addition', 0),
    ('Soda Water',        'addition', 0),
    ('Tonic Water',       'addition', 0),
    ('Espresso',          'addition', 0),
    ('Cranberry Juice',   'addition', 0),
    ('Mint',              'addition', 0),
    ('Jalapeño',          'addition', 0);


--
-- Title:        Classic Drinks
-- Description:  Six classic Drinks with their first version, without an author. The Virgin
--               Mojito is a mocktail.
-- Requirements: R07, R08, R14, R15, R23
-- Constraints:  C01, C14, C17, C19
--
SELECT create_drink('Margarita', 'Tequila, orange liqueur and lime, shaken and served in a coupe.',
                    NULL, 'tequila',
                    '[{"name": "Tequila", "amount": 50}, {"name": "Orange Liqueur", "amount": 20},
                      {"name": "Lime Juice", "amount": 30}]',
                    '{"sweetness": 8, "sourness": 14, "bitterness": 2, "intensity": 14}');

SELECT create_drink('Mojito', 'White rum, lime, sugar, mint and soda.',
                    NULL, 'rum',
                    '[{"name": "White Rum", "amount": 50}, {"name": "Lime Juice", "amount": 25},
                      {"name": "Simple Syrup", "amount": 20}, {"name": "Soda Water", "amount": 60},
                      {"name": "Mint", "amount": 8, "unit": "leaves"}]',
                    '{"sweetness": 10, "sourness": 10, "herbalness": 14, "fizziness": 14, "intensity": 8}');

SELECT create_drink('Negroni', 'Gin, Campari and sweet vermouth in equal parts.',
                    NULL, 'gin',
                    '[{"name": "Gin", "amount": 30}, {"name": "Campari", "amount": 30},
                      {"name": "Sweet Vermouth", "amount": 30}]',
                    '{"sweetness": 6, "sourness": 2, "bitterness": 16, "intensity": 16}');

SELECT create_drink('Moscow Mule', 'Vodka, lime and ginger beer over ice.',
                    NULL, 'vodka',
                    '[{"name": "Vodka", "amount": 50}, {"name": "Lime Juice", "amount": 15},
                      {"name": "Ginger Beer", "amount": 120}]');

SELECT create_drink('Espresso Martini', 'Vodka, coffee liqueur and a fresh espresso.',
                    NULL, 'vodka',
                    '[{"name": "Vodka", "amount": 50}, {"name": "Coffee Liqueur", "amount": 20},
                      {"name": "Espresso", "amount": 30}, {"name": "Simple Syrup", "amount": 1, "unit": "tsp"}]');

SELECT create_drink('Virgin Mojito', 'A Mojito without rum.',
                    NULL, NULL,
                    '[{"name": "Lime Juice", "amount": 25}, {"name": "Simple Syrup", "amount": 20},
                      {"name": "Soda Water", "amount": 120}, {"name": "Mint", "amount": 8, "unit": "leaves"}]');


--
-- Title:        Users
-- Description:  alice and bob with their system Albums, the taste of alice, liked
--               Ingredients and a Passkey.
-- Requirements: R01, R04, R26, R36, R39
-- Constraints:  C12, C20, C21
--
SELECT register_user('alice', 'alice@example.com', 'Alice-Password-1');
SELECT register_user('bob',   'bob@example.com',   'Bob-Password-1');

UPDATE Flavour_Preferences fp SET sweetness = 8, sourness = 15, bitterness = 4, intensity = 14
FROM "User" u WHERE u.flavour_preferences_identifier = fp.identifier AND u.username = 'alice';

INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES
    ('alice', 'Tequila'), ('alice', 'Lime Juice'), ('bob', 'Gin');

INSERT INTO Passkey (credential_identifier, public_key, username) VALUES
    ('cred-alice-iphone', 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEsampleAlicePublicKey', 'alice');


--
-- Title:        Spicy Margarita
-- Description:  alice saves her own version of the Margarita on the new branch spicy.
-- Requirements: R12, R15, R16, R44
-- Constraints:  C16, C18, C23
--
SELECT set_acting_user('alice');
SELECT add_version(
    (SELECT v.drink_version_id FROM Drink_Version v JOIN Drink d ON d.identifier = v.drink_identifier
     WHERE d.name = 'Margarita' AND v.version_number = 1),
    'Spicy Margarita', 'spicy', 'Agave instead of orange liqueur, with jalapeño',
    '[{"name": "Tequila", "amount": 50}, {"name": "Agave Syrup", "amount": 15},
      {"name": "Lime Juice", "amount": 30}, {"name": "Jalapeño", "amount": 2, "unit": "pieces"}]',
    '{"spiciness": 14}');


--
-- Title:        Albums
-- Description:  alice shares the Album Summer Party and saves the Negroni to her
--               favourites.
-- Requirements: R41, R43, R45
-- Constraints:  C24, C33
--
INSERT INTO Album (name, icon, username) VALUES ('Summer Party', 'sun.max.fill', 'alice');
INSERT INTO Album_Entry (album_identifier, drink_identifier)
SELECT a.identifier, d.identifier FROM Album a, Drink d
WHERE a.username = 'alice' AND a.name = 'Summer Party' AND d.name IN ('Mojito', 'Moscow Mule', 'Virgin Mojito');
SELECT share_album((SELECT identifier FROM Album WHERE username = 'alice' AND name = 'Summer Party'));

INSERT INTO Album_Entry (album_identifier, drink_identifier)
SELECT a.identifier, d.identifier FROM Album a, Drink d
WHERE a.username = 'alice' AND a.kind = 'favourites' AND d.name = 'Negroni';


--
-- Title:        Reviews
-- Description:  bob reviews three Drink Versions, which sets their average rating and
--               popularity.
-- Requirements: R30, R31, R34, R35
-- Constraints:  C04, C07, C27, C28
--
SELECT set_acting_user('bob');
INSERT INTO Review (number_of_stars, notes, sourness_perception, strength_perception, drink_version_id, username)
SELECT 4, 'Fresh, a bit too sour.', 'too_much', 'just_right', v.drink_version_id, 'bob'
FROM Drink_Version v JOIN Drink d ON d.identifier = v.drink_identifier
WHERE d.name = 'Margarita' AND v.version_number = 1;

INSERT INTO Review (number_of_stars, drink_version_id, username)
SELECT 5, v.drink_version_id, 'bob'
FROM Drink_Version v JOIN Drink d ON d.identifier = v.drink_identifier
WHERE d.name = 'Margarita' AND v.version_number = 2;

INSERT INTO Review (number_of_stars, bitterness_perception, drink_version_id, username)
SELECT 3, 'too_much', v.drink_version_id, 'bob'
FROM Drink_Version v JOIN Drink d ON d.identifier = v.drink_identifier
WHERE d.name = 'Negroni';

COMMIT;


--
-- Title:        Result
-- Description:  Shows the Library after the sample data.
-- Requirements: R23, R34, R35
-- Constraints:  C19, C27, C28
--
SELECT name, base_spirit, popularity, average_rating, latest_version_number, total_volume,
       total_alcohol_percentage, is_mocktail
FROM Library_Drink ORDER BY popularity DESC, name;
