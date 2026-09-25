# Reelist Integrity Constraints

Every constraint below is named in [`schema.sql`](schema.sql) using `pk_`, `fk_`, `uq_` and `chk_` prefixes. `NOT NULL` and `DEFAULT` are column properties rather than named constraints, so they appear here without names.

## Primary keys

| Relation | Primary key | Constraint | Justification |
|---|---|---|---|
| users | `user_id` | `pk_users` | Regardless of any business rule about duplicate display names, we need a unique id for each user. Display names and email addresses are both editable, so a key based on either would force updates through every referencing row. |
| movies | `movie_id` | `pk_movies` | Many movies share a title, or have remakes and live-action versions. We need a unique identifier independent of the title. |
| ratings | `rating_id` | `pk_ratings` | `(user_id, movie_id)` is unique (see `uq_ratings_user_movie`) but cannot be the primary key: `user_id` becomes NULL when an account is deleted, and primary key columns cannot be NULL. A surrogate gives every rating a stable identifier that survives the deletion of its author. |
| genres | `genre_id` | `pk_genres` | `genre_name` is arguably a viable natural key — the list is small and stable. A surrogate is used for consistency with the other relations and to keep the junction's foreign key and the `parent_genre_id` self-reference narrow. |
| movie_genres | `(movie_id, genre_id)` | `pk_movie_genres` | A movie belongs to a genre or it does not; there is no third state, and recording the pairing twice is meaningless. The composite key rejects duplicate pairings directly. Neither column alone is unique, so the key is minimal. |

## Foreign keys

### ratings.user_id → users.user_id (`fk_ratings_user`)

- **ON DELETE:** SET NULL
- **Why:** Even if a user deletes their account, the rating itself is preserved so the movie's aggregate score is unaffected. Severing the link satisfies a deletion request without discarding the data the platform depends on. This is why `ratings.user_id` is the one foreign key left nullable.

### ratings.movie_id → movies.movie_id (`fk_ratings_movie`)

- **ON DELETE:** CASCADE
- **Why:** Ratings can only exist on movies that are in the database, so deleting a movie deletes every rating on it. A movie would only be deleted for legal, fraud or public-pressure reasons, and in those cases the movie and all of its ratings should go together. Ordinary delisting sets `movies.is_active` to false instead, which keeps the ratings.

### genres.parent_genre_id → genres.genre_id (`fk_genres_parent`)

- **ON DELETE:** SET NULL
- **Why:** This is the schema's self-referencing key, and it models subgenres (Slasher under Horror). It sits on `genres` because the genre hierarchy is the one place in the domain where an entity is naturally a child of another entity of the same kind. Deleting a parent genre promotes its subgenres to top level instead of deleting them, so the subgenres keep their movie tags.

### movie_genres.movie_id → movies.movie_id (`fk_movie_genres_movie`)

- **ON DELETE:** CASCADE
- **Why:** A genre tag describes a movie. Once the movie is gone, the tag has nothing to describe.

### movie_genres.genre_id → genres.genre_id (`fk_movie_genres_genre`)

- **ON DELETE:** CASCADE
- **Why:** A tag cannot point at a genre that no longer exists. Deleting a genre removes it from every movie that carried it; the movies themselves are untouched.

## Unique constraints

| Constraint | Columns | Justification |
|---|---|---|
| `uq_users_display_name` | `users.user_display_name` | The display name is how a user appears on every rating, so it must distinguish users from each other. The cost is a signup rejection path when a name is taken, which is accepted. This also enforces the uniqueness that was only assumed when `user_display_name` was rejected as a primary key — editability, not uniqueness, is what disqualifies it. |
| `uq_users_email_lower` | `LOWER(users.email_address)` | One account per email address, compared case-insensitively, because `Jon@gmail.com` and `jon@gmail.com` reach the same inbox. This is a unique *index* rather than a UNIQUE constraint because PostgreSQL constraints can only list plain columns, not expressions like `LOWER()`. |
| `uq_ratings_user_movie` | `ratings (user_id, movie_id)` | One rating per user per movie. A second rating replaces the first by UPDATE rather than adding a row, so a single user cannot weight a movie's average. PostgreSQL treats NULLs as distinct in UNIQUE, so ratings orphaned by account deletions never collide with each other. |
| `uq_genres_name` | `genres.genre_name` | Prevents duplicate labels, which would split one genre's movies across two rows and break genre filtering. |

## CHECK constraints

| Constraint | Rule | Justification |
|---|---|---|
| `chk_users_email_format` | `email_address ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$'` | Rejects malformed addresses (no `@`, spaces, no top-level domain). It is deliberately a structural check only: no regex fully captures the email standard, and only a verification email can prove an inbox exists. The database stops malformed data; proving the address works is the application's job. |
| `chk_movies_runtime_positive` | `runtime_minutes > 0` | Nullable, because an announced film may have no confirmed runtime. The CHECK blocks zero and negative values, which are impossible rather than merely unknown. This is the filtering attribute for later units, so bad values would corrupt range queries. |
| `chk_movies_release_date` | `release_date >= DATE '1888-01-01'` | Blocks dates before the earliest surviving film, which can only come from typos or bad imports (e.g. `0019` for `2019`). Future dates stay allowed because announced titles are valid catalog entries. NULL passes, for titles with no confirmed date. |
| `chk_ratings_score_range` | `score BETWEEN 0.5 AND 5.0` | Score drives every aggregate the platform reports, so an out-of-range value would silently distort averages rather than fail loudly. Enforcing it in the database means it holds regardless of which client writes the row. |
| `chk_ratings_score_half_step` | `score * 2 = FLOOR(score * 2)` | The interface offers half-star ratings only. Without this check, `NUMERIC(3,2)` would accept values like 3.47 that no user could have entered. |
| `chk_genres_not_own_parent` | `parent_genre_id IS DISTINCT FROM genre_id` | A genre cannot be its own parent. `IS DISTINCT FROM` treats NULL as a normal value, so top-level genres (NULL parent) pass. This check cannot detect longer cycles (A → B → A); that would need a trigger. |

## Column properties

| Attribute | Properties | Justification |
|---|---|---|
| `users.user_display_name` | NOT NULL | A row without a display name has nothing to render next to its ratings. |
| `users.email_address` | NOT NULL, VARCHAR(254) | Every account needs a login and recovery address. 254 is the maximum length of a valid email address. |
| `users.joined_at` | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Every account has a creation moment, and it is known at insert time. The default removes any path by which the application could omit it. |
| `users.is_active` | NOT NULL, DEFAULT TRUE | Accounts are active on creation. NOT NULL keeps the flag two-valued: without it, `WHERE is_active = FALSE` would silently skip NULL rows and under-report deactivated accounts. |
| `movies.movie_title` | NOT NULL, VARCHAR(200) | A catalog entry with no title cannot be browsed or searched. Deliberately not UNIQUE — distinct films genuinely share titles, and remakes are common, which is why `movie_id` is a surrogate. 200 characters leaves room for long real titles with subtitles. |
| `movies.release_date` | Nullable | An announced title may have no confirmed release date. Release status is derived by comparing this to the current date rather than stored as a separate flag. |
| `movies.is_active` | NOT NULL, DEFAULT TRUE | Titles are listed on creation. Delisting sets this false rather than deleting the row, which preserves the ratings that reference it. |
| `ratings.score` | NOT NULL, NUMERIC(3,2) | A rating with no score is not a rating. NUMERIC stores half-stars exactly, where a floating-point type would introduce rounding error into averages. |
| `ratings.posted_at` | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Window functions in later units order ratings by time, so a missing timestamp would make a row unorderable. Known at insert time, so the default guarantees it. |
| `ratings.user_id` | Nullable | Required by `fk_ratings_user`'s SET NULL: NULL means the rating was preserved after its author's account was deleted. The score still counts toward the movie's average, but attribution is severed. |
| `ratings.movie_id` | NOT NULL | A foreign key alone does not block NULLs, so NOT NULL is what makes the movie mandatory. A score attached to no movie is meaningless and permanently unqueryable. |
| `genres.parent_genre_id` | Nullable | NULL marks a top-level genre, and `fk_genres_parent`'s SET NULL depends on it. |

## Derived values

A user's last activity is **not stored**. An earlier draft had `users.last_active`, but the only activity the schema records is ratings, so the value is exactly `MAX(ratings.posted_at)` for that user. Storing it would duplicate the fact table on a dimension table and require an update on every new rating, with a risk of drift if one were missed. It is computed at query time instead.
