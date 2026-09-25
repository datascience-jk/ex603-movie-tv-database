# Unit 2 — From ERD to DDL

The complete schema is in [`schema/schema.sql`](../schema/schema.sql). This write-up explains the decisions that script encodes but cannot explain on its own.

## Creation order

A table can only be created after every table it references, so I worked out the order from the ERD's arrows before writing any SQL:

| # | Table | References | Why it sits here |
|---|---|---|---|
| 1 | `users` | nothing | No outgoing foreign keys. |
| 2 | `movies` | nothing | No outgoing foreign keys. |
| 3 | `ratings` | `users`, `movies` | Needs both parents to exist first. |
| 4 | `genres` | itself | Its only reference is to its own table, so it can go anywhere before `movie_genres`. |
| 5 | `movie_genres` | `movies`, `genres` | Needs both sides of the many-to-many to exist first. |

The reset block at the top of the script drops the tables in reverse order, children first. I ran the whole file twice in a row on the same database, and both runs completed without errors.

---

## Foreign keys and ON DELETE

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `ratings.user_id → users.user_id` | SET NULL | A deleted account's ratings stay in every movie's average; only the link to the person is removed. |
| `ratings.movie_id → movies.movie_id` | CASCADE | A rating of a movie that no longer exists has no meaning, so it goes with the movie. |
| `genres.parent_genre_id → genres.genre_id` | SET NULL | Deleting a parent genre promotes its subgenres to top level instead of deleting them. |
| `movie_genres.movie_id → movies.movie_id` | CASCADE | A genre tag describes a movie; with the movie gone, there is nothing left to describe. |
| `movie_genres.genre_id → genres.genre_id` | CASCADE | Deleting a genre removes that tag from every movie; the movies themselves are untouched. |

### ratings.user_id — SET NULL

**The event:** a user deletes their account. On a rating platform this happens regularly, and when someone asks to be removed, their identity has to go.

**Who is affected:** the deleted user, whose name disappears from every rating they posted, and everyone else, whose view of each movie's average is unchanged. The rating rows stay and continue to count, but `user_id` becomes NULL.

**Under the alternatives:** with CASCADE, one person leaving would rewrite the history of every movie they rated. A film's average could shift overnight for reasons unrelated to the film, and trend queries over time would show movement that never happened. With RESTRICT, the account could not be deleted until its ratings were removed by hand, so a deletion request would get stuck on data the user no longer controls. SET NULL is the only option that honors the request without damaging the platform's aggregates. It is also why `ratings.user_id` is the one foreign key column left nullable.

### ratings.movie_id — CASCADE

**The event:** a movie is permanently removed from the database. This is rare and deliberate: a legal takedown, a fraudulent listing, or a duplicate entry. Ordinary delisting (a licensing window closing, for example) does not delete anything; it sets `movies.is_active` to false, which hides the title while keeping its ratings.

**Who is affected:** every user who rated the movie loses that rating from their history. That is the intended result, because the thing they rated no longer exists.

**Under the alternatives:** SET NULL is not possible, because `movie_id` is NOT NULL, and a rating with no movie would sit in every aggregate while belonging to no title. With RESTRICT, an administrator would have to delete thousands of ratings before being allowed to remove the movie. Carrying out a legal takedown in two manual steps invites a half-finished removal. CASCADE makes a true removal a single operation.

### genres.parent_genre_id — SET NULL

**The event:** an administrator deletes a genre that has subgenres, for example retiring "Horror" when "Slasher" and "Folk Horror" sit beneath it.

**Who is affected:** the subgenres, which lose their parent and become top-level genres. Every movie tagged with a subgenre keeps that tag.

**Under the alternatives:** CASCADE would delete the subgenres too, and through `movie_genres` it would also strip those tags from every movie that carried them. Deleting one parent could quietly remove hundreds of tags. RESTRICT would block the delete until every child was reassigned by hand, which is safe but tedious for a routine reorganization.

**Why the self-reference is on `genres`:** the assignment allows the recursive key to go wherever it makes sense in the domain. In Reelist, the genre hierarchy is the one place where an entity is naturally a child of another entity of the same kind. Users do not belong to other users, and movies are not structurally part of other movies. Subgenres also serve questions the README already poses: an average score for "Horror" that includes its subgenres needs this hierarchy.

### movie_genres.movie_id — CASCADE

**The event:** a movie is deleted, which is the same rare event described above.

**Who is affected:** only the movie's genre tags. The genres themselves remain.

**Under the alternatives:** a tag pointing at a missing movie is meaningless, and RESTRICT would add a second manual cleanup step to every movie removal. CASCADE keeps the junction table consistent with the catalog automatically.

### movie_genres.genre_id — CASCADE

**The event:** an administrator deletes a genre, most often while merging duplicates (folding "Sci-Fi" into "Science Fiction") or retiring a label nobody uses.

**Who is affected:** movies carrying that genre lose the tag. Each movie remains and keeps its other genres.

**Under the alternative:** RESTRICT would be the more cautious choice, because it blocks the delete while any movie still uses the genre, which would catch an accidental deletion. I chose CASCADE because the genre list is small, managed only by administrators, and changed rarely and on purpose. In a merge, the administrator re-tags the movies first and then deletes the old genre, and CASCADE cleans up any stragglers. The cost is that a mistaken delete removes tags silently. For a platform with many administrators, I would switch this key to RESTRICT.

---

## CHECK constraints

### `chk_ratings_score_range` — `score BETWEEN 0.5 AND 5.0`

**Blocks:** a score outside the star scale, such as 0, 7 or −1.

**How it could arise:** a client written for a different scale (an older 0–10 design, say), a bug that sends a percentage, or an import that confuses columns. Score feeds every average the platform reports, so a single out-of-range value would distort a movie's rating without raising an error anywhere. Enforcing the range in the database means it holds no matter which client writes the row.

### `chk_ratings_score_half_step` — `score * 2 = FLOOR(score * 2)`

**Blocks:** scores between half steps, such as 3.47 or 4.2.

**How it could arise:** `NUMERIC(3,2)` stores two decimal places, so the type alone accepts values no user could select in a half-star interface. They could come from averaging code that writes back into the table, a script that generates test data, or rounding in a client. Rejecting them keeps every stored score one of the ten values the interface can actually produce.

### `chk_movies_runtime_positive` — `runtime_minutes > 0`

**Blocks:** a runtime of zero or a negative runtime.

**How it could arise:** a zero used as a placeholder for "unknown" instead of NULL, or a sign error in an import. The column stays nullable, because an announced film may not have a runtime yet, but zero means something different from "unknown": it is simply wrong. Runtime is the filtering attribute for range queries in later units, and zeros would pollute every "films under 90 minutes" result.

### `chk_movies_release_date` — `release_date >= DATE '1888-01-01'`

**Blocks:** release dates before cinema existed.

**How it could arise:** a two-digit year typed as `0019` instead of `2019`, or a date-parsing bug in a data import. `DATE` already rejects dates that cannot exist, such as February 30, but it happily stores the year 19. Future dates remain valid because announced titles belong in the catalog, and NULL remains valid for titles without a confirmed date.

### `chk_users_email_format` — regex on `email_address`

**Blocks:** addresses that are structurally malformed: no `@`, two `@`s, spaces, or no top-level domain.

**How it could arise:** a typo on a signup form, or a client that skips validation. The check is deliberately structural rather than complete. No regex fully captures the email standard, and only a verification email can prove that an inbox exists. The database's job is to refuse data that cannot possibly be an address; confirming that the address works is the application's job.

### `chk_genres_not_own_parent` — `parent_genre_id IS DISTINCT FROM genre_id`

**Blocks:** a genre listed as its own parent.

**How it could arise:** an administrator editing the hierarchy who selects the same genre in both fields, or an import that fills the parent from the wrong column. A genre that is its own parent would send any recursive query walking the hierarchy into an infinite loop. `IS DISTINCT FROM` is used instead of `<>` so that NULL, which marks a top-level genre, is compared as a normal value. The check only catches direct self-reference; a longer cycle (A → B → A) would need a trigger, which is beyond this unit.

---

## What changed since Unit 1

Building the DDL exposed several places where the Unit 1 design was incomplete. The ERD, [`schema-definition.md`](../schema/schema-definition.md) and [`constraints.md`](../schema/constraints.md) have been updated to match.

- **Removed `users.last_active`.** The schema records only one kind of user activity, ratings, so the value would have been exactly `MAX(ratings.posted_at)`. Storing it would duplicate the fact table on a dimension table and require an update on every new rating. It is now computed at query time.
- **Added `users.email_address`.** Every account needs a login and recovery address. It is unique case-insensitively through an index on `LOWER(email_address)`, and it is not used as a key because users can change it.
- **Changed `ratings.score` from `SMALLINT` 0–10 to `NUMERIC(3,2)` 0.5–5.0 in half steps.** Unit 1 stored a 0–10 value and displayed it as stars; the score is now stored the way users enter it. The course type map specifies `NUMERIC(3,2)` for scores, and that type cannot hold 10.00, so the scale had to change regardless.
- **Added `UNIQUE (user_id, movie_id)` on `ratings`.** The README already said "one row per user-title pair," but nothing enforced it. This also replaced the Unit 1 justification for `rating_id`, which had allowed for multiple ratings per movie.
- **Added `genres.parent_genre_id`**, the self-referencing key for subgenres, justified above.
- **Added CHECK constraints** on `release_date` and on the score's half steps.
- **Named every constraint**, so errors identify the rule that failed (for example `chk_ratings_score_range` rather than an auto-generated `ratings_score_check1`).
