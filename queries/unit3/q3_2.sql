-- =====================================================
-- Task 3.2 — Find the bug
-- =====================================================

-- -----------------------------------------------------
-- Part A: The rows that vanished
-- Column: ratings.withdrawn_reason (nullable by design).
-- No rows were inserted; the dataset already contains
-- 166 NULLs in this column.
-- -----------------------------------------------------

-- 3.2a The broken dashboard query: count every rating that was
--    NOT withdrawn for spam. Looks exhaustive, but is not.
--    Requirement: inequality predicate on a nullable column.
SELECT COUNT(*) AS not_spam_broken
FROM ratings
WHERE withdrawn_reason != 'Spam detected';
-- Result: 22. Far too low: the table has 200 ratings.

-- 3.2b The "opposite" filter: ratings withdrawn for spam.
--    Requirement: the complement of 3.2a.
SELECT COUNT(*) AS spam
FROM ratings
WHERE withdrawn_reason = 'Spam detected';
-- Result: 12.

-- 3.2c The table total, for comparison.
SELECT COUNT(*) AS table_total
FROM ratings;
-- Result: 200. But 22 + 12 = 34, so 166 rows are in neither query.

-- 3.2d The rows both filters silently omitted.
--    Requirement: count what the broken query dropped.
SELECT COUNT(*) AS silently_omitted
FROM ratings
WHERE withdrawn_reason IS NULL;
-- Result: 166. For these rows, NULL != 'Spam detected' evaluates to
--         UNKNOWN, not TRUE, and WHERE keeps only TRUE rows. Every
--         published and flagged rating vanished without an error.
--         22 + 12 + 166 = 200.

-- 3.2e Repair 1: handle NULL explicitly with IS NULL.
--    Requirement: explicit IS NULL condition.
SELECT COUNT(*) AS not_spam_fixed
FROM ratings
WHERE withdrawn_reason != 'Spam detected'
   OR withdrawn_reason IS NULL;
-- Result: 188. Now 188 + 12 = 200, the full table.

-- 3.2f Repair 2: replace NULL with a value before comparing.
--    Requirement: COALESCE.
SELECT COUNT(*) AS not_spam_fixed
FROM ratings
WHERE COALESCE(withdrawn_reason, 'No reason provided') != 'Spam detected';
-- Result: 188. Same answer as 3.2e.

-- -----------------------------------------------------
-- Part B: The alias that did not exist yet
-- -----------------------------------------------------

-- 3.2g The broken query: define an alias in SELECT, use it in WHERE.
--    Requirement: reproduce the error.
SELECT rating_id, score, weight,
       score * weight AS weighted_score
FROM ratings
WHERE weighted_score >= 9;
-- Result: ERROR:  column "weighted_score" does not exist
--         WHERE is evaluated before SELECT, so the alias has not been
--         created yet when the filter runs.

-- 3.2h Rewrite 1: repeat the expression in WHERE.
--    Requirement: repeated expression.
SELECT rating_id, score, weight,
       score * weight AS weighted_score
FROM ratings
WHERE score * weight >= 9
ORDER BY weighted_score DESC, rating_id;
-- Result: 13 rows.

-- 3.2i Rewrite 2: compute the alias in a CTE, then filter on it.
--    Requirement: CTE makes the alias a real column.
WITH weighted AS (
    SELECT rating_id, score, weight,
           score * weight AS weighted_score
    FROM ratings
)
SELECT rating_id, score, weight, weighted_score
FROM weighted
WHERE weighted_score >= 9
ORDER BY weighted_score DESC, rating_id;
-- Result: 13 rows, identical to 3.2h.