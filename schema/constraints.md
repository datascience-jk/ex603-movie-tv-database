# Reelist Integrity Constraints

## Primary keys

| Relation | Primary key | Justification |
|---|---|---|
| users | `user_id` | Regardless of any business rule about duplicate display names, we need a unique id for each user. Display names are editable, so a name-based key would force updates through every referencing row. |
| movies | `movie_id` | Many movies share a title, or have remakes and live-action versions. We need a unique identifier independent of the title. |
| ratings | `rating_id` | Depending on business rules, we may allow a user to leave multiple ratings or edit previous ratings on subsequent watches. |
| genres | `genre_id` | `genre_name` is arguably a viable natural key — the list is small and stable. A surrogate is used for consistency with the other relations and to keep the junction's foreign key narrow. |
| movie_genres | `(movie_id, genre_id)` | A movie belongs to a genre or it does not; there is no third state, and recording the pairing twice is meaningless. The composite key rejects duplicate pairings directly. Neither column alone is unique, so the key is minimal. |

## Foreign keys

### ratings.user_id → users.user_id

- **ON DELETE:** SET NULL
- **Why:** Even if a user deletes their account, the rating itself is preserved so the movie's aggregate score is unaffected. Severing the link satisfies a deletion request without discarding the data the platform depends on.

### ratings.movie_id → movies.movie_id

- **ON DELETE:** CASCADE
- **Why:** Ratings can only live on movies that are on our database.  This decision will delete every single rating on a movie if the movie is also deleted.  A decision to remove a movie would only be for legal reasons, fraud reasons, or social pressuring.  IN which we case we would want ot remove the movie and all of'ts ratings with it.

### movie_genres.movie_id → movies.movie_id

- **ON DELETE:** CASCADE
- **Why:** Movie has to exist for their to be an associated genre

### movie_genres.genre_id → genres.genre_id

- **ON DELETE:** CASCADE
- **Why:** Genre has to exist to have an associated movie.

## Column constraints

| Attribute | Constraints | Justification |
|---|---|---|
| Attribute | Constraints | Justification |
|---|---|---|
| `users.user_display_name` | NOT NULL, UNIQUE | The display name is how a user appears on every rating in the interface, so a row without one has nothing to render. UNIQUE makes users distinguishable to each other on a social platform. The cost is a signup rejection path when a name is taken, which is accepted. This also enforces the uniqueness that was only assumed when `user_display_name` was rejected as a primary key — editability, not uniqueness, is what disqualifies it. |
| `users.joined_at` | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Every account has a creation moment, and it is known at insert time. The default removes any path by which the application could omit it. |
| `users.last_active` | Nullable | A user who has not returned since signup has no last-active value. NULL here means "has not returned", which is a real state rather than missing data. |
| `users.is_active` | NOT NULL, DEFAULT TRUE | Accounts are active on creation. NOT NULL keeps the flag two-valued: without it, `WHERE is_active = FALSE` would silently skip NULL rows and under-report deactivated accounts. |
| `movies.movie_title` | NOT NULL | A catalog entry with no title cannot be browsed or searched. Deliberately not UNIQUE — distinct films genuinely share titles, and remakes are common, which is why `movie_id` is a surrogate. |
| `movies.runtime_minutes` | CHECK (runtime_minutes > 0) | Nullable, because an announced film may have no confirmed runtime. The CHECK blocks zero and negative values, which are impossible rather than merely unknown. This is the filtering attribute for later units, so bad values would corrupt range queries. |
| `movies.release_date` | Nullable | An announced title may have no confirmed release date. Release status is derived by comparing this to the current date rather than stored as a separate flag. |
| `movies.is_active` | NOT NULL, DEFAULT TRUE | Titles are listed on creation. Delisting sets this false rather than deleting the row, which preserves the ratings that reference it. |
| `ratings.score` | NOT NULL, CHECK (score BETWEEN 0 AND 10) | A rating with no score is not a rating. The CHECK is the schema-level rule that matters most here: score drives every aggregate the platform reports, and an out-of-range value would silently distort averages rather than fail loudly. Enforcing it in the database rather than the application means it holds regardless of which client writes the row. |
| `ratings.posted_at` | NOT NULL, DEFAULT CURRENT_TIMESTAMP | Window functions in later units order ratings by time, so a missing timestamp would make a row unorderable. Known at insert time, so the default guarantees it. |
| `ratings.user_id` | Nullable, FK to `users` | The only intentionally nullable foreign key in the schema. NULL means the rating was preserved after its author's account was deleted — the score still counts toward the movie's average, but attribution is severed. |
| `ratings.movie_id` | NOT NULL, FK to `movies` | The inverse case. A score attached to no movie is meaningless and permanently unqueryable, so the reference is mandatory and deletion cascades. |
