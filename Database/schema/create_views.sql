--
-- Title:        Visible_Album
-- Description:  Albums visible to the acting user: the public ones and its own. An Album
--               without an icon shows the default icon.
-- Requirements: R06, R40, R46
-- Constraints:  C22, C25
--
CREATE VIEW Visible_Album AS
SELECT a.identifier,
       a.name,
       COALESCE(a.icon, 'square.stack.3d.up') AS icon,
       a.photo,
       a.kind,
       a.public_status,
       a.date_of_creation,
       a.number_of_drinks,
       a.username
FROM Album a
WHERE a.public_status OR a.username = acting_user();


--
-- Title:        Visible_Album_Entry
-- Description:  Drinks of the visible Albums.
-- Requirements: R46
-- Constraints:  C25
--
CREATE VIEW Visible_Album_Entry AS
SELECT e.album_identifier, e.drink_identifier, e.date_of_adding
FROM Album_Entry e
JOIN Visible_Album a ON a.identifier = e.album_identifier;


--
-- Title:        Drink_Version_Details
-- Description:  Drink Versions with the mocktail flag.
-- Requirements: R23
-- Constraints:  C19
--
CREATE VIEW Drink_Version_Details AS
SELECT v.*,
       v.total_alcohol_percentage = 0 AS is_mocktail
FROM Drink_Version v;


--
-- Title:        Library_Drink
-- Description:  Each Drink with its latest Drink Version, for the Library.
-- Requirements: R23, NFR09
-- Constraints:  C19
--
CREATE VIEW Library_Drink AS
SELECT d.identifier,
       d.name,
       d.description,
       d.photo,
       d.base_spirit,
       d.date_of_creation,
       d.popularity,
       d.average_rating,
       latest.drink_version_id AS latest_drink_version_id,
       latest.version_number   AS latest_version_number,
       latest.total_volume,
       latest.total_alcohol_percentage,
       latest.total_alcohol_percentage = 0 AS is_mocktail,
       latest.flavour_distribution
FROM Drink d
JOIN LATERAL (SELECT v.* FROM Drink_Version v
              WHERE v.drink_identifier = d.identifier
              ORDER BY v.version_number DESC
              LIMIT 1) latest ON TRUE;


--
-- Title:        search_drinks(text)
-- Description:  Drinks found by a part of the name, the base spirit or an Ingredient.
-- Requirements: NFR09
-- Constraints:  -
--
CREATE FUNCTION search_drinks(p_text VARCHAR) RETURNS SETOF Library_Drink
LANGUAGE sql STABLE AS $$
    SELECT l.* FROM Library_Drink l
    WHERE lower(l.name) LIKE '%' || lower(p_text) || '%'
       OR l.base_spirit = lower(p_text)
       OR EXISTS (SELECT 1 FROM Version_Ingredient vi
                  WHERE vi.drink_version_id = l.latest_drink_version_id
                    AND lower(vi.ingredient_name) LIKE '%' || lower(p_text) || '%')
    ORDER BY l.popularity DESC, l.name
$$;


--
-- Title:        drinks_made_only_from(ingredients)
-- Description:  Drinks, that need only the given Ingredients (the ingredients matcher).
-- Requirements: FR14
-- Constraints:  -
--
CREATE FUNCTION drinks_made_only_from(p_ingredients VARCHAR[]) RETURNS SETOF Library_Drink
LANGUAGE sql STABLE AS $$
    SELECT l.* FROM Library_Drink l
    WHERE NOT EXISTS (
        SELECT 1 FROM Version_Ingredient vi
        WHERE vi.drink_version_id = l.latest_drink_version_id
          AND lower(vi.ingredient_name) <> ALL (SELECT lower(x) FROM unnest(p_ingredients) AS x))
    ORDER BY l.popularity DESC, l.name
$$;
