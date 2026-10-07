-- =====================================================
-- Task 3.1 — Establish what the data contains
-- Dataset: movies (producer = movies, event = ratings)
-- =====================================================

-- 3.1a [Q1] Active, highly rated movies — available titles released
--    after 2015, newest first, top ten.
--    Requirement: SELECT, WHERE, ORDER BY, LIMIT.
SELECT movie_id, title, release_year
FROM movies
WHERE is_available = TRUE
  AND release_year > 2015
ORDER BY release_year DESC, title
LIMIT 10;
-- Result: Only 7 movies qualify, so LIMIT 10 returned 7. Title_03 (2023)
--         is excluded because it is unavailable.

-- 3.1b [Q2] Every status a rating can have.
--    Requirement: DISTINCT.
SELECT DISTINCT rating_status
FROM ratings
ORDER BY rating_status;
-- Result: 3 statuses — published (156), withdrawn (34), flagged (10).
--         "Flagged" was unexpected: it is neither live nor removed, so
--         any rate filtered on one status silently drops these rows.

-- 3.1c [Q3] Near-perfect ratings — scores from 4.9 to 5.0.
--    Requirement: numeric range filter (BETWEEN).
SELECT rating_id, movie_id, score
FROM ratings
WHERE score BETWEEN 4.9 AND 5.0
ORDER BY score DESC, rating_id;
-- Result: 38 ratings — 35 perfect 5.0s and 3 at 4.9. Perfect scores are
--         common: almost 1 in 5 ratings is a 5.0.

-- 3.1d [Q3] Ratings not visible to viewers — withdrawn or flagged.
--    Requirement: explicit list of values (IN).
SELECT rating_id, movie_id, rating_status
FROM ratings
WHERE rating_status IN ('withdrawn', 'flagged')
ORDER BY rating_status, rating_id;
-- Result: 44 of 200 ratings (22%) — 10 flagged, 34 withdrawn. Every
--         withdrawn rating has a score of 0.5, a placeholder rather than
--         a real opinion, which would drag down any average that
--         includes them.

-- 3.1e [Q4] Movies whose titles start with "Title_1" (Title_10 to 15).
--    Requirement: text pattern (LIKE).
SELECT movie_id, title
FROM movies
WHERE title LIKE 'Title\_1%';
-- Result: 6 movies, Title_10 to Title_15. The underscore is escaped
--         because "_" is a LIKE wildcard matching any one character.

-- 3.1f [Q4] Ratings with no withdrawal reason recorded (first 15 shown).
--    Requirement: missing values (IS NULL).
SELECT rating_id, rating_status, withdrawn_reason
FROM ratings
WHERE withdrawn_reason IS NULL
ORDER BY rating_id
LIMIT 15;
-- Result: 166 ratings have no reason (first 15 shown) — exactly the
--         published (156) and flagged (10) ratings. The NULLs are by
--         design: only withdrawn ratings have a reason, and all 34 do.

-- 3.1g [Q4] Withdrawal reasons, with missing ones labelled (first 15 shown).
--    Requirement: replace NULL with a label (COALESCE).
SELECT rating_id, rating_status,
       COALESCE(withdrawn_reason, 'No reason provided') AS reason
FROM ratings
ORDER BY rating_id
LIMIT 15;
-- Result: No NULLs remain. Across all 200 ratings, 166 show "No reason
--         provided"; the 34 withdrawals split into Spam detected (12),
--         Policy violation (8), Duplicate rating (7), User request (7).

-- 3.1h [Q5] Ratings described in plain language — when they happened,
--    how good the score was, and the weighted score.
--    Requirement: computed columns, CASE.
SELECT rating_id,
       movie_id,
       score,
       score * weight AS weighted_score,
       ROUND(watch_minutes / 60.0, 2) AS watch_hours,
       CASE
         WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 5 AND 11 THEN 'Morning'
         WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 12 AND 16 THEN 'Afternoon'
         WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 17 AND 21 THEN 'Evening'
         ELSE 'Late night'
       END AS time_of_day,
       CASE
         WHEN score >= 4.0 THEN 'Loved it'
         WHEN score >= 2.5 THEN 'Mixed'
         ELSE 'Disliked'
       END AS score_category
FROM ratings
ORDER BY rating_id
LIMIT 20;
-- Result: 20 rows. Each rating now reads as a sentence: when it was
--         given, a plain verdict, and its weighted score. Note that
--         withdrawn 0.5 placeholders are labelled "Disliked", which
--         overstates dislike unless they are filtered out first.