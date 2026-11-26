--
-- Title:        Row counts
-- Description:  Number of rows in every table.
-- Requirements: -
-- Constraints:  -
--
SELECT 'User' AS table_name, count(*) AS row_count FROM "User"
UNION ALL SELECT 'Passkey',             count(*) FROM Passkey
UNION ALL SELECT 'Flavour_Preferences', count(*) FROM Flavour_Preferences
UNION ALL SELECT 'Ingredient',          count(*) FROM Ingredient
UNION ALL SELECT 'Drink',               count(*) FROM Drink
UNION ALL SELECT 'Drink_Version',       count(*) FROM Drink_Version
UNION ALL SELECT 'Version_Ingredient',  count(*) FROM Version_Ingredient
UNION ALL SELECT 'Review',              count(*) FROM Review
UNION ALL SELECT 'Liked_Ingredient',    count(*) FROM Liked_Ingredient
UNION ALL SELECT 'Album',               count(*) FROM Album
UNION ALL SELECT 'Album_Entry',         count(*) FROM Album_Entry;


--
-- Title:        Library
-- Description:  Every Drink with its latest version and the values, that the triggers
--               calculate.
-- Requirements: R21, R22, R23, R34, R35
-- Constraints:  C19, C27, C28, C29, C30
--
SELECT name, base_spirit, latest_version_number, total_volume,
       total_alcohol_percentage, is_mocktail, popularity, average_rating
FROM Library_Drink
ORDER BY popularity DESC, name;


--
-- Title:        Version history
-- Description:  Every Drink Version with its branch, author and base version.
-- Requirements: R09, R10, R11, R12, R15
-- Constraints:  C14, C15, C16
--
SELECT d.name AS drink, v.version_number, v.name AS version_name, v.branch,
       v.message, v.author_username, base.version_number AS based_on_version
FROM Drink_Version v
JOIN Drink d ON d.identifier = v.drink_identifier
LEFT JOIN Drink_Version base ON base.drink_version_id = v.base_drink_version_id
ORDER BY d.name, v.version_number;


--
-- Title:        Recipes
-- Description:  Ingredients of the latest version of every Drink.
-- Requirements: R19
-- Constraints:  -
--
SELECT l.name AS drink, vi.ingredient_name, vi.amount, vi.unit, i.category
FROM Library_Drink l
JOIN Version_Ingredient vi ON vi.drink_version_id = l.latest_drink_version_id
JOIN Ingredient i ON i.name = vi.ingredient_name
ORDER BY l.name, vi.ingredient_name;


--
-- Title:        Search
-- Description:  Drinks found by a part of the name, the base spirit or an Ingredient.
-- Requirements: NFR09
-- Constraints:  -
--
SELECT name, base_spirit, is_mocktail FROM search_drinks('lime');


--
-- Title:        Ingredients matcher
-- Description:  Drinks, that can be made only from the Ingredients at hand.
-- Requirements: FR14
-- Constraints:  -
--
SELECT name, total_alcohol_percentage
FROM drinks_made_only_from(ARRAY['Vodka', 'Lime Juice', 'Ginger Beer', 'Coffee Liqueur', 'Espresso']);


--
-- Title:        Reviews
-- Description:  Reviews with their Drink and author.
-- Requirements: R30, R31, R32
-- Constraints:  C04, C07
--
SELECT d.name AS drink, v.version_number, r.username, r.number_of_stars, r.notes,
       r.sourness_perception, r.strength_perception, r.date_of_creation
FROM Review r
JOIN Drink_Version v ON v.drink_version_id = r.drink_version_id
JOIN Drink d ON d.identifier = v.drink_identifier
ORDER BY d.name, r.date_of_creation;


--
-- Title:        Taste match
-- Description:  How well the latest version of each Drink matches the taste of alice, from
--               0 to 100.
-- Requirements: R25
-- Constraints:  C32
--
SELECT name, estimated_match_for_user(latest_drink_version_id, 'alice') AS match_for_alice
FROM Library_Drink
ORDER BY match_for_alice DESC NULLS LAST, name;


--
-- Title:        Login
-- Description:  The username for the right password and NULL for a wrong one. Passwords
--               are stored only as bcrypt hashes.
-- Requirements: NFR02
-- Constraints:  -
--
SELECT authenticate_user('alice@example.com', 'Alice-Password-1') AS correct_password,
       authenticate_user('alice@example.com', 'wrong')            AS wrong_password;


--
-- Title:        Visible Albums
-- Description:  Albums seen by bob: the public ones and his own. The acting user lasts
--               only one transaction, so run these four lines together as a script
--               (DBeaver: Alt+X).
-- Requirements: R45, R46
-- Constraints:  C24, C25
--
BEGIN;
SELECT set_acting_user('bob');
SELECT name, kind, public_status, number_of_drinks, username FROM Visible_Album ORDER BY username, name;
ROLLBACK;
