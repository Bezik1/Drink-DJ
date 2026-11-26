DO $tests$
BEGIN

--
-- Title:        Review with defaults, created today
-- Description:  Test: insert a Review with stars, notes and perceptions, after which its
--               date_of_creation is today and the perceptions not given are not_rated.
-- Requirements: R30
-- Constraints:  C04
--
PERFORM accepts('R30', 'review with defaults, created today',
    $$INSERT INTO Review (number_of_stars, notes, sweetness_perception, strength_perception, drink_version_id, username)
      VALUES (4, 'T review', 'just_right', 'too_much', version_id('T Gin Sour', 1), 't_bob')$$,
    $$SELECT expect((SELECT date_of_creation = CURRENT_DATE AND sourness_perception = 'not_rated'
          AND bitterness_perception = 'not_rated' FROM Review WHERE notes = 'T review'), 'defaults')$$);

--
-- Title:        Review without stars
-- Description:  Test: insert a Review without number_of_stars. The database must refuse
--               it.
-- Requirements: R30
-- Constraints:  -
--
PERFORM rejects('R30', 'review without stars', 'not-null',
    $$INSERT INTO Review (drink_version_id, username) VALUES (version_id('T Gin Sour', 1), 't_bob')$$);

--
-- Title:        1 and 5 stars, all perception levels
-- Description:  Test: insert Reviews with 1 and 5 stars and the perceptions too_little and
--               too_much.
-- Requirements: R31
-- Constraints:  C04, C07
--
PERFORM accepts('R31', '1 and 5 stars, all perception levels',
    $$INSERT INTO Review (number_of_stars, sourness_perception, bitterness_perception, drink_version_id, username) VALUES
          (1, 'too_little', 'too_much', version_id('T Gin Sour', 1), 't_bob'),
          (5, 'too_much', 'too_little', version_id('T Gin Sour', 1), 't_bob')$$);

--
-- Title:        0 stars
-- Description:  Test: insert a Review with 0 stars. The database must refuse it.
-- Requirements: R31
-- Constraints:  C07
--
PERFORM rejects('R31', '0 stars', 'review_stars_range',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (0, version_id('T Gin Sour', 1), 't_bob')$$);

--
-- Title:        6 stars
-- Description:  Test: insert a Review with 6 stars. The database must refuse it.
-- Requirements: R31
-- Constraints:  C07
--
PERFORM rejects('R31', '6 stars', 'review_stars_range',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (6, version_id('T Gin Sour', 1), 't_bob')$$);

--
-- Title:        Unknown perception perfect
-- Description:  Test: insert a Review with sweetness_perception perfect. The database must
--               refuse it.
-- Requirements: R31
-- Constraints:  C04
--
PERFORM rejects('R31', 'unknown perception perfect', 'review_perception_domain',
    $$INSERT INTO Review (number_of_stars, sweetness_perception, drink_version_id, username)
      VALUES (3, 'perfect', version_id('T Gin Sour', 1), 't_bob')$$);

--
-- Title:        Two reviews of one version by one user
-- Description:  Test: insert two Reviews of one User of the same Drink Version.
-- Requirements: R32
-- Constraints:  -
--
PERFORM accepts('R32', 'two reviews of one version by one user',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES
          (3, version_id('T Mule', 1), 't_alice'), (4, version_id('T Mule', 1), 't_alice')$$,
    $$SELECT expect((SELECT count(*) FROM Review WHERE username = 't_alice' AND drink_version_id = version_id('T Mule', 1)) = 2, 'two reviews')$$);

--
-- Title:        Deleting a version deletes its reviews
-- Description:  Test: delete a Drink Version, after which its Reviews are deleted.
-- Requirements: R32
-- Constraints:  C39
--
PERFORM accepts('R32', 'deleting a version deletes its reviews',
    $$INSERT INTO Review (number_of_stars, notes, drink_version_id, username) VALUES (2, 'T doomed review', version_id('T Mule', 6), 't_alice')$$,
    $$DELETE FROM Drink_Version WHERE drink_version_id = version_id('T Mule', 6)$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Review WHERE notes = 'T doomed review'), 'review deleted')$$);

--
-- Title:        Review of an unknown version
-- Description:  Test: insert a Review of a Drink Version, that is not in the database. The
--               database must refuse it.
-- Requirements: R32
-- Constraints:  -
--
PERFORM rejects('R32', 'review of an unknown version', 'review_drink_version_fk',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (3, -1, 't_bob')$$);

--
-- Title:        Review by an unknown user
-- Description:  Test: insert a Review of a User, that is not in the database. The database
--               must refuse it.
-- Requirements: R32
-- Constraints:  -
--
PERFORM rejects('R32', 'review by an unknown user', 'review_user_fk',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (3, version_id('T Gin Sour', 1), 't_ghost')$$);

--
-- Title:        Review without notes
-- Description:  Test: insert a Review without notes.
-- Requirements: R33
-- Constraints:  C13
--
PERFORM accepts('R33', 'review without notes',
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES (4, version_id('T Collins', 1), 't_bob')$$);

--
-- Title:        4 and 5 stars give 4.50
-- Description:  Test: insert Reviews with 4 and 5 stars of two versions of one Drink,
--               after which average_rating is 4.50.
-- Requirements: R34
-- Constraints:  C28
--
PERFORM accepts('R34', '4 and 5 stars give 4.50',
    $$SELECT set_acting_user('t_alice')$$,
    $$SELECT create_drink('T Rated', 'x', NULL, 'gin', '[{"name": "T Gin", "amount": 50}]')$$,
    $$SELECT add_version(version_id('T Rated', 1), 'T Rated 2', 'main', NULL, '[{"name": "T Gin", "amount": 60}]')$$,
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES
          (4, version_id('T Rated', 1), 't_bob'), (5, version_id('T Rated', 2), 't_bob')$$,
    $$SELECT expect((SELECT average_rating FROM Drink WHERE name = 'T Rated') = 4.50, 'rating 4.50')$$);

--
-- Title:        No reviews give 0
-- Description:  Test: delete both Reviews, after which average_rating is 0.
-- Requirements: R34
-- Constraints:  C28
--
PERFORM accepts('R34', 'no reviews give 0',
    $$DELETE FROM Review WHERE drink_version_id IN (version_id('T Rated', 1), version_id('T Rated', 2))$$,
    $$SELECT expect((SELECT average_rating FROM Drink WHERE name = 'T Rated') = 0, 'rating 0')$$);

--
-- Title:        Set average_rating by hand
-- Description:  Test: update average_rating directly. The database must refuse it.
-- Requirements: R34
-- Constraints:  C28
--
PERFORM rejects('R34', 'set average_rating by hand', 'calculated by the database',
    $$UPDATE Drink SET average_rating = 5 WHERE name = 'T Rated'$$);

--
-- Title:        Insert average_rating by hand
-- Description:  Test: insert a Drink with average_rating 3. The database must refuse it.
-- Requirements: R34
-- Constraints:  C28
--
PERFORM rejects('R34', 'insert average_rating by hand', 'calculated by the database',
    $$INSERT INTO Drink (name, description, average_rating) VALUES ('T Fake Rating', 'x', 3)$$);

--
-- Title:        2 reviews + 1 album = popularity 3
-- Description:  Test: insert two Reviews of a Drink and add it to one Album, after which
--               popularity is 3.
-- Requirements: R35
-- Constraints:  C27
--
PERFORM accepts('R35', '2 reviews + 1 album = popularity 3',
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT create_drink('T Popular', 'x', NULL, 'vodka', '[{"name": "T Vodka", "amount": 50}]')$$,
    $$INSERT INTO Review (number_of_stars, drink_version_id, username) VALUES
          (5, version_id('T Popular', 1), 't_alice'), (4, version_id('T Popular', 1), 't_bob')$$,
    $$INSERT INTO Album_Entry (album_identifier, drink_identifier) VALUES (system_album_id('t_bob', 'favourites'), drink_id('T Popular'))$$,
    $$SELECT expect((SELECT popularity FROM Drink WHERE name = 'T Popular') = 3, 'popularity 3')$$);

--
-- Title:        Set popularity by hand
-- Description:  Test: update popularity directly. The database must refuse it.
-- Requirements: R35
-- Constraints:  C27
--
PERFORM rejects('R35', 'set popularity by hand', 'calculated by the database',
    $$UPDATE Drink SET popularity = 100 WHERE name = 'T Popular'$$);

--
-- Title:        Like a spirit and an addition
-- Description:  Test: like a spirit and an addition.
-- Requirements: R36
-- Constraints:  -
--
PERFORM accepts('R36', 'like a spirit and an addition',
    $$INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES ('t_alice', 'T Gin'), ('t_alice', 'T Lime Juice')$$);

--
-- Title:        Deleting an ingredient deletes its likes
-- Description:  Test: delete an Ingredient, after which the likes of it are deleted.
-- Requirements: R36
-- Constraints:  C41
--
PERFORM accepts('R36', 'deleting an ingredient deletes its likes',
    $$INSERT INTO Ingredient (name, category) VALUES ('T Unloved', 'addition')$$,
    $$INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES ('t_bob', 'T Unloved')$$,
    $$DELETE FROM Ingredient WHERE name = 'T Unloved'$$,
    $$SELECT expect(NOT EXISTS (SELECT 1 FROM Liked_Ingredient WHERE ingredient_name = 'T Unloved'), 'likes deleted')$$);

--
-- Title:        Like twice
-- Description:  Test: like the same Ingredient twice. The database must refuse it.
-- Requirements: R36
-- Constraints:  -
--
PERFORM rejects('R36', 'like twice', 'liked_ingredient_pk',
    $$INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES ('t_alice', 'T Gin')$$);

--
-- Title:        Like an unknown ingredient
-- Description:  Test: like an Ingredient, that is not in the database. The database must
--               refuse it.
-- Requirements: R36
-- Constraints:  -
--
PERFORM rejects('R36', 'like an unknown ingredient', 'liked_ingredient_ingredient_fk',
    $$INSERT INTO Liked_Ingredient (username, ingredient_name) VALUES ('t_alice', 'T Unicorn Tears')$$);

END
$tests$;
