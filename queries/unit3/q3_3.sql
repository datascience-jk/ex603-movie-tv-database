-- =====================================================
-- Task 3.3 — Hand the team a corrected query
-- Question: Which users submitted at least one disputed
-- rating (flagged or withdrawn)?
-- Step 1: find the disputed ratings.
-- Step 2: find the users who wrote them.
-- =====================================================

-- 3.3a Form 1 — subquery with IN.
--    Requirement: subquery using IN.
SELECT user_id, user_name
FROM users
WHERE user_id IN (
    SELECT user_id
    FROM ratings
    WHERE rating_status IN ('flagged', 'withdrawn')
)
ORDER BY user_id;
-- Result: 24 users.

-- 3.3b Form 2 — Common Table Expression.
--    Requirement: CTE using WITH.
WITH disputed_users AS (
    SELECT DISTINCT user_id
    FROM ratings
    WHERE rating_status IN ('flagged', 'withdrawn')
)
SELECT u.user_id, u.user_name
FROM users u
JOIN disputed_users d ON d.user_id = u.user_id
ORDER BY u.user_id;
-- Result: 24 users, the same list as 3.3a.

-- 3.3c Form 3 — correlated subquery with EXISTS.
--    Requirement: a third, distinct construction.
SELECT u.user_id, u.user_name
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.user_id = u.user_id
      AND r.rating_status IN ('flagged', 'withdrawn')
)
ORDER BY u.user_id;
-- Result: 24 users, the same list as 3.3a and 3.3b.

-- 3.3d Proof that the three result sets are identical, row for row.
--    EXCEPT returns rows in one set that are missing from the other.
--    Checking both directions for each pair means any difference in
--    either set would show up. Zero everywhere = identical rows.
--    Requirement: show the rows match, not just the counts.
WITH form_in AS (
    SELECT user_id, user_name
    FROM users
    WHERE user_id IN (
        SELECT user_id FROM ratings
        WHERE rating_status IN ('flagged', 'withdrawn')
    )
),
disputed_users AS (
    SELECT DISTINCT user_id
    FROM ratings
    WHERE rating_status IN ('flagged', 'withdrawn')
),
form_cte AS (
    SELECT u.user_id, u.user_name
    FROM users u
    JOIN disputed_users d ON d.user_id = u.user_id
),
form_exists AS (
    SELECT u.user_id, u.user_name
    FROM users u
    WHERE EXISTS (
        SELECT 1 FROM ratings r
        WHERE r.user_id = u.user_id
          AND r.rating_status IN ('flagged', 'withdrawn')
    )
)
SELECT 'IN vs CTE' AS comparison,
       (SELECT COUNT(*) FROM (SELECT * FROM form_in EXCEPT SELECT * FROM form_cte) x)
     + (SELECT COUNT(*) FROM (SELECT * FROM form_cte EXCEPT SELECT * FROM form_in) x)
       AS mismatched_rows
UNION ALL
SELECT 'IN vs EXISTS',
       (SELECT COUNT(*) FROM (SELECT * FROM form_in EXCEPT SELECT * FROM form_exists) x)
     + (SELECT COUNT(*) FROM (SELECT * FROM form_exists EXCEPT SELECT * FROM form_in) x)
UNION ALL
SELECT 'CTE vs EXISTS',
       (SELECT COUNT(*) FROM (SELECT * FROM form_cte EXCEPT SELECT * FROM form_exists) x)
     + (SELECT COUNT(*) FROM (SELECT * FROM form_exists EXCEPT SELECT * FROM form_cte) x);
-- Result: 0 mismatched rows for all three pairs. Each form returns
--         the same 24 (user_id, user_name) rows.

-- 3.3e Where equivalence breaks: duplicates.
--    The CTE form only matches because of DISTINCT. Remove it, and
--    the JOIN returns one row per disputed RATING, not per user.
--    IN and EXISTS never duplicate outer rows, so they still return 24.
--    Requirement: name an input condition that breaks equivalence.
WITH disputed_users AS (
    SELECT user_id                 -- DISTINCT removed
    FROM ratings
    WHERE rating_status IN ('flagged', 'withdrawn')
)
SELECT u.user_id, u.user_name
FROM users u
JOIN disputed_users d ON d.user_id = u.user_id
ORDER BY u.user_id;
-- Result: 44 rows instead of 24. Users with several disputed ratings
--         appear repeatedly (User_16 five times, User_08 four times).
--         The three forms are only equivalent when the CTE deduplicates.
--         A second breaking case: NOT IN. If the question were "users
--         with NO disputed ratings" and the subquery returned a NULL
--         user_id, NOT IN would return zero rows while NOT EXISTS would
--         still return the correct users (see the 3.2 NULL behavior).