DO $tests$
BEGIN

--
-- Title:        Ingredients of both categories
-- Description:  Test: insert an Ingredient of the category alcohol and one of the category
--               addition.
-- Requirements: R17
-- Constraints:  C03
--
PERFORM accepts('R17', 'ingredients of both categories',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T Rum', 'alcohol', 40), ('T Honey', 'addition', 0)$$);

--
-- Title:        Unknown category spirit
-- Description:  Test: insert an Ingredient of the category spirit. The database must
--               refuse it.
-- Requirements: R17
-- Constraints:  C03
--
PERFORM rejects('R17', 'unknown category spirit', 'ingredient_category_domain',
    $$INSERT INTO Ingredient (name, category) VALUES ('T Brandy', 'spirit')$$);

--
-- Title:        Ingredient without a category
-- Description:  Test: insert an Ingredient without a category. The database must refuse
--               it.
-- Requirements: R17
-- Constraints:  -
--
PERFORM rejects('R17', 'ingredient without a category', 'not-null',
    $$INSERT INTO Ingredient (name) VALUES ('T Unknown')$$);

--
-- Title:        Alcohol percentage 0 and 100
-- Description:  Test: insert Ingredients with alcohol_percentage 0 and 100.
-- Requirements: R18
-- Constraints:  C05
--
PERFORM accepts('R18', 'alcohol percentage 0 and 100',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T Water', 'addition', 0), ('T Pure Alcohol', 'alcohol', 100)$$);

--
-- Title:        Duplicate name in another letter case
-- Description:  Test: insert the Ingredient T VODKA, while T Vodka is in the database. The
--               database must refuse it.
-- Requirements: R18
-- Constraints:  -
--
PERFORM rejects('R18', 'duplicate name in another letter case', 'ingredient_name_unique',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T VODKA', 'alcohol', 40)$$);

--
-- Title:        Alcohol percentage above 100
-- Description:  Test: insert an Ingredient with alcohol_percentage 100.5. The database
--               must refuse it.
-- Requirements: R18
-- Constraints:  C05
--
PERFORM rejects('R18', 'alcohol percentage above 100', 'ingredient_alcohol_range',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T Too Strong', 'alcohol', 100.5)$$);

--
-- Title:        Negative alcohol percentage
-- Description:  Test: insert an Ingredient with alcohol_percentage -1. The database must
--               refuse it.
-- Requirements: R18
-- Constraints:  C05
--
PERFORM rejects('R18', 'negative alcohol percentage', 'ingredient_alcohol_range',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T Negative', 'addition', -1)$$);

--
-- Title:        Version with three ingredients
-- Description:  Test: save a Drink Version with three Ingredients and their amounts and
--               units.
-- Requirements: R19
-- Constraints:  C08
--
PERFORM accepts('R19', 'version with three ingredients',
    $$SELECT create_drink('T Southside', 'Gin, lime and mint.', NULL, 'gin',
          '[{"name": "T Gin", "amount": 50}, {"name": "T Lime Juice", "amount": 2, "unit": "cl"}, {"name": "T Mint", "amount": 6, "unit": "leaves"}]')$$,
    $$SELECT expect((SELECT count(*) FROM Version_Ingredient WHERE drink_version_id = version_id('T Southside', 1)) = 3, 'three ingredients')$$);

--
-- Title:        Deleted ingredient leaves recipes, values recalculated
-- Description:  Test: delete an Ingredient, after which it leaves the Drink Versions, that
--               keep other Ingredients, and their values are recalculated.
-- Requirements: R19
-- Constraints:  C29, C30, C40
--
PERFORM accepts('R19', 'deleted ingredient leaves recipes, values recalculated',
    $$INSERT INTO Ingredient (name, category) VALUES ('T Tonic Water', 'addition')$$,
    $$SELECT create_drink('T Gin Tonic', 'Gin and tonic.', NULL, 'gin', '[{"name": "T Gin", "amount": 50}, {"name": "T Tonic Water", "amount": 150}]')$$,
    $$SELECT new_transaction()$$,
    $$DELETE FROM Ingredient WHERE name = 'T Tonic Water'$$,
    $$SELECT expect((SELECT total_volume = 50 AND total_alcohol_percentage = 40 FROM Drink_Version
          WHERE drink_version_id = version_id('T Gin Tonic', 1)), 'recalculated')$$);

--
-- Title:        Version without ingredients
-- Description:  Test: insert a Drink Version without Ingredients and commit. The database
--               must refuse it.
-- Requirements: R19
-- Constraints:  -
--
PERFORM rejects('R19', 'version without ingredients', 'contains no Ingredient',
    $$SELECT insert_raw_version(drink_id('T Lime Soda'), version_id('T Lime Soda', 1), 'empty')$$);

--
-- Title:        Deleting the only ingredient of a version
-- Description:  Test: delete the only Ingredient of a Drink Version, by deleting the
--               Ingredient, and commit. The database must refuse it.
-- Requirements: R19
-- Constraints:  -
--
PERFORM rejects('R19', 'deleting the only ingredient of a version', 'contains no Ingredient',
    $$INSERT INTO Ingredient (name, category) VALUES ('T Lonely', 'addition')$$,
    $$SELECT create_drink('T Lonely Drink', 'x', NULL, NULL, '[{"name": "T Lonely", "amount": 100}]')$$,
    $$DELETE FROM Ingredient WHERE name = 'T Lonely'$$);

--
-- Title:        Amount 0
-- Description:  Test: insert an Ingredient with amount 0. The database must refuse it.
-- Requirements: R19
-- Constraints:  C08
--
PERFORM rejects('R19', 'amount 0', 'version_ingredient_amount_positive',
    $$SELECT create_drink('T Zero Amount', 'x', NULL, 'gin', '[{"name": "T Gin", "amount": 0}]')$$);

--
-- Title:        Unknown unit gallon
-- Description:  Test: insert an Ingredient with the unit gallon. The database must refuse
--               it.
-- Requirements: R19
-- Constraints:  -
--
PERFORM rejects('R19', 'unknown unit gallon', 'version_ingredient_unit_domain',
    $$SELECT create_drink('T Gallon', 'x', NULL, 'gin', '[{"name": "T Gin", "amount": 1, "unit": "gallon"}]')$$);

--
-- Title:        Same ingredient in two versions
-- Description:  Test: insert the same Ingredient into two Drink Versions.
-- Requirements: R20
-- Constraints:  -
--
PERFORM accepts('R20', 'same ingredient in two versions',
    $$SELECT expect((SELECT count(DISTINCT drink_version_id) FROM Version_Ingredient WHERE ingredient_name = 'T Gin') >= 2, 'gin in two versions')$$);

--
-- Title:        Same ingredient twice in one version
-- Description:  Test: insert the same Ingredient twice into one Drink Version. The
--               database must refuse it.
-- Requirements: R20
-- Constraints:  -
--
PERFORM rejects('R20', 'same ingredient twice in one version', 'version_ingredient_pk',
    $$SELECT create_drink('T Double Gin', 'x', NULL, 'gin', '[{"name": "T Gin", "amount": 50}, {"name": "T Gin", "amount": 20}]')$$);

--
-- Title:        50 ml + 2 cl + 1 oz = 99.57 ml
-- Description:  Test: save a Drink Version with 50 ml, 2 cl and 1 oz, after which
--               total_volume is 99.57.
-- Requirements: R21
-- Constraints:  C29
--
PERFORM accepts('R21', '50 ml + 2 cl + 1 oz = 99.57 ml',
    $$SELECT create_drink('T Volume', 'x', NULL, 'vodka',
          '[{"name": "T Vodka", "amount": 50}, {"name": "T Lime Juice", "amount": 2, "unit": "cl"}, {"name": "T Simple Syrup", "amount": 1, "unit": "oz"}]')$$,
    $$SELECT expect((SELECT total_volume FROM Drink_Version WHERE drink_version_id = version_id('T Volume', 1)) = 99.57, 'volume 99.57')$$);

--
-- Title:        Set total_volume by hand
-- Description:  Test: update total_volume directly. The database must refuse it.
-- Requirements: R21
-- Constraints:  C29
--
PERFORM rejects('R21', 'set total_volume by hand', 'cannot be changed directly',
    $$UPDATE Drink_Version SET total_volume = 1 WHERE drink_version_id = version_id('T Volume', 1)$$);

--
-- Title:        Insert total_volume by hand
-- Description:  Test: insert a Drink Version with total_volume 100. The database must
--               refuse it.
-- Requirements: R21
-- Constraints:  C29
--
PERFORM rejects('R21', 'insert total_volume by hand', 'calculated by the database',
    $$SELECT insert_raw_version(drink_id('T Volume'), version_id('T Volume', 1), 'raw', NULL, NULL, 100)$$);

--
-- Title:        40 % and 0 % in equal parts = 20 %
-- Description:  Test: save a version with 50 ml of a 40 % Ingredient and 50 ml of a 0 %
--               Ingredient, after which total_alcohol_percentage is 20.
-- Requirements: R22
-- Constraints:  C30
--
PERFORM accepts('R22', '40 % and 0 % in equal parts = 20 %',
    $$INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES ('T Strong', 'alcohol', 40)$$,
    $$SELECT create_drink('T Half', 'x', NULL, 'vodka', '[{"name": "T Strong", "amount": 50}, {"name": "T Soda Water", "amount": 50}]')$$,
    $$SELECT expect((SELECT total_alcohol_percentage FROM Drink_Version WHERE drink_version_id = version_id('T Half', 1)) = 20, 'alcohol 20')$$);

--
-- Title:        Changed ingredient updates the alcohol to 25 %
-- Description:  Test: update alcohol_percentage of that Ingredient to 50, after which
--               total_alcohol_percentage is 25.
-- Requirements: R22
-- Constraints:  C30
--
PERFORM accepts('R22', 'changed ingredient updates the alcohol to 25 %',
    $$UPDATE Ingredient SET alcohol_percentage = 50 WHERE name = 'T Strong'$$,
    $$SELECT expect((SELECT total_alcohol_percentage FROM Drink_Version WHERE drink_version_id = version_id('T Half', 1)) = 25, 'alcohol 25')$$);

--
-- Title:        Set total_alcohol_percentage by hand
-- Description:  Test: update total_alcohol_percentage directly. The database must refuse
--               it.
-- Requirements: R22
-- Constraints:  C30
--
PERFORM rejects('R22', 'set total_alcohol_percentage by hand', 'cannot be changed directly',
    $$UPDATE Drink_Version SET total_alcohol_percentage = 5 WHERE drink_version_id = version_id('T Half', 1)$$);

--
-- Title:        Mocktail and alcoholic versions
-- Description:  Test: read a Drink Version without alcohol and one with alcohol, after
--               which is_mocktail is true and false.
-- Requirements: R23
-- Constraints:  C19
--
PERFORM accepts('R23', 'mocktail and alcoholic versions',
    $$SELECT expect((SELECT is_mocktail FROM Drink_Version_Details WHERE drink_version_id = version_id('T Lime Soda', 1)), 'mocktail')$$,
    $$SELECT expect((SELECT NOT is_mocktail FROM Drink_Version_Details WHERE drink_version_id = version_id('T Half', 1)), 'alcoholic')$$,
    $$SELECT expect((SELECT is_mocktail FROM Library_Drink WHERE name = 'T Lime Soda'), 'mocktail in library')$$);

--
-- Title:        Flavour distribution of a gin sour
-- Description:  Test: save a version with 50 ml T Gin, 25 ml T Lime Juice and 25 ml T
--               Simple Syrup, after which flavour_distribution is {"sour": 50, "sweet":
--               50, "bitter": 0, "strong": 65}.
-- Requirements: R24
-- Constraints:  C31
--
PERFORM accepts('R24', 'flavour distribution of a gin sour',
    $$SELECT expect((SELECT flavour_distribution FROM Drink_Version WHERE drink_version_id = version_id('T Gin Sour', 1))
          = '{"sour": 50, "sweet": 50, "bitter": 0, "strong": 65}', 'distribution')$$);

--
-- Title:        Set flavour_distribution by hand
-- Description:  Test: update flavour_distribution directly. The database must refuse it.
-- Requirements: R24
-- Constraints:  C31
--
PERFORM rejects('R24', 'set flavour_distribution by hand', 'cannot be changed directly',
    $$UPDATE Drink_Version SET flavour_distribution = '{}' WHERE drink_version_id = version_id('T Gin Sour', 1)$$);

--
-- Title:        Perfect match is 100
-- Description:  Test: save a version, whose wanted flavour equals its estimated taste,
--               after which estimated_match is 100.
-- Requirements: R25
-- Constraints:  C32
--
PERFORM accepts('R25', 'perfect match is 100',
    $$SELECT create_drink('T Exact', 'x', NULL, 'gin',
          '[{"name": "T Gin", "amount": 50}, {"name": "T Lime Juice", "amount": 25}, {"name": "T Simple Syrup", "amount": 25}]',
          '{"sweetness": 10, "sourness": 10, "bitterness": 0, "intensity": 13}')$$,
    $$SELECT expect((SELECT estimated_match FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 1)) = 100, 'match 100')$$);

--
-- Title:        Match follows the wanted flavour while saving
-- Description:  Test: update the wanted flavour in the transaction, that saves the
--               version, after which estimated_match is recalculated.
-- Requirements: R25
-- Constraints:  C32
--
PERFORM accepts('R25', 'match follows the wanted flavour while saving',
    $$UPDATE Flavour_Preferences SET intensity = 0 WHERE identifier =
          (SELECT flavour_preferences_identifier FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 1))$$,
    $$SELECT expect((SELECT estimated_match FROM Drink_Version WHERE drink_version_id = version_id('T Exact', 1)) = 84, 'match 84')$$);

--
-- Title:        Set estimated_match by hand
-- Description:  Test: update estimated_match directly. The database must refuse it.
-- Requirements: R25
-- Constraints:  C32
--
PERFORM rejects('R25', 'set estimated_match by hand', 'cannot be changed directly',
    $$UPDATE Drink_Version SET estimated_match = 99 WHERE drink_version_id = version_id('T Exact', 1)$$);

--
-- Title:        Insert estimated_match by hand
-- Description:  Test: insert a Drink Version with estimated_match 50. The database must
--               refuse it.
-- Requirements: R25
-- Constraints:  C32
--
PERFORM rejects('R25', 'insert estimated_match by hand', 'calculated by the database',
    $$SELECT insert_raw_version(drink_id('T Exact'), version_id('T Exact', 1), 'raw', NULL, NULL, 0, 50)$$);

END
$tests$;
