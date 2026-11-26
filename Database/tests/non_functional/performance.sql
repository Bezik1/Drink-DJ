DO $tests$
BEGIN

--
-- Title:        Search 10,000 drinks within 1 second
-- Description:  Test: search 10,000 Drinks by name, base spirit and Ingredient with
--               search_drinks(), within 1 second.
-- Requirements: NFR09
-- Constraints:  -
--
PERFORM accepts('NFR09', 'search 10,000 drinks within 1 second',
    $$SELECT set_acting_user(NULL)$$,
    $$SELECT create_drink('T Bulk ' || n, 'Generated.', NULL, CASE WHEN n % 2 = 0 THEN 'gin' ELSE 'vodka' END,
          CASE WHEN n % 2 = 0 THEN '[{"name": "T Gin", "amount": 50}, {"name": "T Lime Juice", "amount": 20}]'::JSONB
               ELSE '[{"name": "T Vodka", "amount": 50}, {"name": "T Soda Water", "amount": 100}]'::JSONB END)
      FROM generate_series(1, 10000 - (SELECT count(*) FROM Drink)) AS n$$,
    $$ANALYZE$$,
    $$CREATE TEMP TABLE nfr09_start AS SELECT clock_timestamp() AS t$$,
    $$CREATE TEMP TABLE nfr09_found AS
          SELECT (SELECT count(*) FROM search_drinks('bulk 77'))   AS by_name,
                 (SELECT count(*) FROM search_drinks('gin'))       AS by_spirit,
                 (SELECT count(*) FROM search_drinks('soda water')) AS by_ingredient$$,
    $$SELECT expect((SELECT count(*) FROM Drink) >= 10000, '10,000 drinks')$$,
    $$SELECT expect((SELECT by_name > 0 AND by_spirit >= 4900 AND by_ingredient >= 4900 FROM nfr09_found), 'results found')$$,
    $$SELECT expect(clock_timestamp() - (SELECT t FROM nfr09_start) < INTERVAL '1 second',
          'three searches took ' || (clock_timestamp() - (SELECT t FROM nfr09_start))::TEXT)$$);

END
$tests$;
