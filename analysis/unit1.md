# Unit 1 — Modelling Justification and Reflection

## Modelling justification

*400–600 words*

### Primary keys

I went with surrogate primary keys for users, movies, ratings, and genres mainly for stability. Take user_display_name—users change their handles all the time. If we used that as a primary key, a simple profile update would force the database to rewrite every single rating that user ever left. movie_title has similar issues. Remakes and shared titles are way too common to rely on them for uniqueness. Surrogate keys keep our relationships locked down even when real-world attributes change.

The one deliberate exception is the movie_genres junction table, where I used a composite key of (movie_id, genre_id). Here, the pairing itself is what needs to be unique. If I added a surrogate key, an application bug could accidentally tag a movie as "Action" three times over. The composite key blocks duplicate pairings right at the door. It’s also minimal—neither ID is unique on its own, making the combination the tightest possible identifier.

### ON DELETE behaviors

The referential integrity rules follow a strict conceptual boundary: a rating survives its parent only when the parent is a person. Consequently, the schema implements one SET NULL constraint and three CASCADE constraints.

SET NULL applies exclusively to ratings.user_id. When users delete their accounts, their identity is scrubbed from the system. However, the rating event itself is preserved with a null author. This design ensures that account deletions do not retroactively alter a movie's historical aggregate score, preserving the accuracy of platform-wide metrics while simultaneously satisfying the deletion request.

### Rules enforced in the schema

Critical business logic is pushed directly into the schema to protect data integrity against upstream application failures. The CHECK (score BETWEEN 0 AND 10) constraint on the ratings table is paramount. Because the platform's core value relies on accurate aggregated scoring, out-of-bounds data would silently distort averages. Enforcing this at the database level ensures the rule holds permanently, regardless of whether a row is written by a well-tested mobile client, a buggy API deployment, or an administrative script.

A UNIQUE constraint is also applied to genres.genre_name to prevent duplicate category creation. This structurally blocks split-genre bugs where titles are fragmented across identically named labels, a flaw that would severely degrade catalog filtering and search functionality.

Finally, we deliberately omitted an explicit boolean flag for a movie's release status. Rather than relying on application logic or scheduled scripts to manually update an is_released flag on release day, the status is derived dynamically by comparing the release_date against the current time. This removes redundant state management and eliminates update anomalies where a release date passes but a manual flag remains unchanged.

---

## Reflection

*150–250 words*

Another designer might challenge the ON DELETE CASCADE rule on the ratings table. Under this design, deleting a movie permanently wipes out every user rating attached to it. A reasonable alternative is a "soft delete"—flipping movies.is_active to false, which hides the film from the catalog but preserves the historical rating data.

I chose cascading hard deletes to aggressively optimize our read patterns. On this platform, read requests will outnumber writes exponentially. If we relied on soft deletes, every query to load a user profile or activity feed would require a mandatory JOIN to the movies table just to check if the film was deactivated. That extra JOIN acts as a permanent speed bump on our most common queries.

Yes, a cascading delete triggers a massive, expensive write operation if a popular movie is removed. However, actually deleting a title is a rare administrative edge case, like a legal takedown. It makes more sense to take a heavy performance hit during a rare admin task than to force millions of daily read operations over a speed bump just to hoard unviewable data.

