# Unit 1 — Modelling Justification and Reflection

## Modelling justification

*400–600 words*

### Primary keys

<!-- The pattern: surrogates on users, movies, ratings, genres.
     Why: stability — display names are editable, titles repeat across remakes.
     The exception: movie_genres uses (movie_id, genre_id).
     Why: the pairing is what must be unique; a surrogate would allow duplicates.
     Minimality: neither column alone is unique. -->

### ON DELETE behaviors

<!-- The pattern: three CASCADE, one SET NULL.
     The line drawn: a rating survives its parent only when the parent is a person.
     SET NULL on ratings.user_id — what is preserved, what is lost, why.
     CASCADE elsewhere — name the cost (deleting a movie destroys every rating on it). -->

### Rules enforced in the schema

<!-- CHECK on score — holds regardless of which client writes the row.
     UNIQUE on genre_name — prevents a split-genre bug.
     What was deliberately NOT enforced: release status derived from release_date,
     not stored as a flag. -->

---

## Reflection

*150–250 words*

<!-- The decision: surrogate genre_id vs natural genre_name as primary key.
     Acknowledge the alternative is reasonable — one-to-one, small closed list.
     Defend in terms of read and write patterns:
       reads — movie_genres is the highest-volume join; INTEGER is narrower than VARCHAR(50)
       writes — genres change rarely, so surrogate maintenance cost is near zero
     Alternative topic if preferred: UNIQUE on user_display_name. -->
