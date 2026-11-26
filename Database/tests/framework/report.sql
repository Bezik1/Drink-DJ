SELECT requirement,
       kind,
       CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS result,
       test,
       CASE WHEN passed AND kind = 'rejection' THEN 'refused: ' || detail ELSE detail END AS detail
FROM tests.result
ORDER BY id;

SELECT count(*) FILTER (WHERE passed)     AS passed,
       count(*) FILTER (WHERE NOT passed) AS failed,
       count(*)                           AS total
FROM tests.result;

SELECT count(*) FILTER (WHERE NOT passed) > 0 AS has_failures FROM tests.result \gset

ROLLBACK;

\if :has_failures
    \echo 'Some tests FAILED.'
    DO $$ BEGIN RAISE EXCEPTION 'Drink DJ database tests failed.'; END $$;
\else
    \echo 'All tests passed. The test data was rolled back.'
\endif
