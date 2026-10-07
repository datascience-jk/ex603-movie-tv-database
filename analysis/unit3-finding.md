# Unit 3 Finding: The Ratings Dashboard Is Counting the Wrong Rows

**To:** Dashboard team

**From:** Jonathan Kahng

**Re:** Review of the ratings dashboard queries (Tasks 3.1–3.3)

**Dataset:** `ex603_data` (movies theme): 200 ratings, 15 movies, 30 users

---

## Summary

The dashboard query has two bugs. The first one drops **166 of the 200 ratings (83%)** without any error. The second one stops the query from running at all. Both are fixed below.

There is also a bigger problem with what gets counted. **44 ratings (22%) are not visible to viewers**, and they all have a fake score that pulls the average down by almost half a point.

None of these problems shows a warning. The numbers look normal, but they are wrong.

---

## What is in the data (Task 3.1)

| Rating status | Count | Share | What it means |
|---|---|---|---|
| published | 156 | 78% | Live and visible to viewers |
| withdrawn | 34 | 17% | Removed, always with a reason |
| flagged | 10 | 5% | Under review, not live and not removed |
| **Total** | **200** | **100%** | |

Three things matter for any number calculated from this table:

1. **There are three statuses, not two.** `flagged` is easy to miss. A filter that only thinks about "published" and "withdrawn" will put these 10 ratings in the wrong group.
2. **Every withdrawn rating has a score of exactly 0.5.** That is a placeholder, not a real opinion. The average score across all 200 ratings is **2.85**. Across published ratings only, it is **3.32**.
3. **`withdrawn_reason` is empty (NULL) for 166 ratings, and that is expected.** Only withdrawn ratings have a reason, so every published and flagged rating is NULL here. The data is fine, but it is what causes Bug 1.

---

## Bug 1: 166 ratings disappeared without an error (Task 3.2, Part A)

The dashboard counts "every rating that was not withdrawn for spam":

```sql
WHERE withdrawn_reason != 'Spam detected'
```

| Query | Rows |
|---|---|
| `!= 'Spam detected'` (dashboard) | 22 |
| `= 'Spam detected'` | 12 |
| **The two added together** | **34** |
| Total ratings | 200 |
| `IS NULL` (the ones that were dropped) | 166 |

**Why it happens:** when `withdrawn_reason` is NULL, SQL can't say whether it equals 'Spam detected', so the check comes back as UNKNOWN instead of TRUE. `WHERE` only keeps rows that are TRUE, so all 166 published and flagged ratings get dropped. The filter looks like it covers everything, but it only covers 34 of 200 rows.

**Fix:** tell SQL what to do with NULL. Both versions below return **188**, and 188 + 12 = 200.

```sql
WHERE withdrawn_reason != 'Spam detected'
   OR withdrawn_reason IS NULL
-- or
WHERE COALESCE(withdrawn_reason, 'No reason provided') != 'Spam detected'
```

---

## Bug 2: The name that didn't exist yet (Task 3.2, Part B)

The dashboard filters on a column name it creates in the same query:

```sql
SELECT ..., score * weight AS weighted_score
FROM ratings
WHERE weighted_score >= 9;
```

```
ERROR:  column "weighted_score" does not exist
```

**Why it happens:** SQL is written in the order `SELECT ... FROM ... WHERE`, but it runs in the order `FROM → WHERE → SELECT`. The name `weighted_score` is created in `SELECT`, which runs after `WHERE`. So when `WHERE` runs, the name doesn't exist yet.

**Fix:** either write out the calculation again in `WHERE`, or calculate it first in a CTE. Both return the same **13 rows**.

---

## A query the team can use (Task 3.3)

**Question:** which users have at least one disputed (flagged or withdrawn) rating?

I wrote this three ways: with `IN`, with a CTE and a `JOIN`, and with `EXISTS`. All three return the same **24 users**. I also checked that the rows match, not just the counts. An `EXCEPT` check in both directions found **0 differences** between every pair.

**I recommend the `EXISTS` version:**

```sql
SELECT u.user_id, u.user_name
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.user_id = u.user_id
      AND r.rating_status IN ('flagged', 'withdrawn')
)
ORDER BY u.user_id;
```

It is the hardest of the three to break:

- **Repeated rows:** the CTE version only works because of `DISTINCT`. Without it, the `JOIN` returns **44 rows**, one for each disputed rating instead of one for each user. User_16 shows up five times. `EXISTS` never repeats a user.
- **NULLs:** if the question changes to "users with *no* disputed ratings," `NOT IN` returns **zero rows** as soon as the list it checks against has a single NULL in it. `NOT EXISTS` doesn't have this problem.

---

## Recommendations

1. **Don't use `!=` alone on columns that can be NULL.** Add an `IS NULL` check or use `COALESCE`. Check every dashboard query for this.
2. **Decide which ratings count before calculating anything.** Most viewer-facing numbers should only use `rating_status = 'published'`. Withdrawn ratings have a fake 0.5 score that lowers the average by about 0.48 points.
3. **Decide how to show `flagged` ratings** and label it on the dashboard. They are 5% of the data and don't fit cleanly into either group right now.
4. **Use `EXISTS` / `NOT EXISTS` instead of `IN` / `NOT IN`** when checking whether a related row exists.
5. **Check that the parts add up to the total.** Filters that split the data into groups should add up to the full row count. If they don't, rows are going missing.

---

*Supporting queries: `/queries/unit3/q3_1.sql`, `q3_2.sql`, `q3_3.sql`. Screenshots: `/screenshots/`.*
