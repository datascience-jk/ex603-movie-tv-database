# ex603-movie-tv-database

Name: Jonathan Kahng  
Purpose: Repository to be used for EX 603 Data and Algorithms for Scalable Systems (Fall 2026)  
Theme: Movies / TV  
What This System Does: Stores and Aggregates Ratings of Movies and TV Shows


# Reelist

A relational database and analytics layer for a film and television rating platform, built across the seven units of EX603.

**Theme:** Movie / TV

---

## Domain

Reelist is a catalog-and-rating platform in the mold of Letterboxd or IMDb. Users browse a library of films and television titles, watch them elsewhere, and return to the platform to leave a numeric score. Each title belongs to one or more genres, and those genre associations are what let the platform group, filter, and recommend across an otherwise flat catalog. The platform does not stream anything itself. Its entire value is the rating data its users generate and the structure imposed on that data by the catalog.

The core tension in the model is that ratings arrive continuously and in volume, while the entities being rated change slowly. A title is added once and edited rarely. A genre list is nearly static. But `ratings` grows without bound, one row per user-title pair, each carrying a score and a timestamp. That asymmetry drives most of the design decisions in this project: `ratings` is the fact table, and `users`, `movies`, and `genres` are dimensions that exist to give those facts meaning. The many-to-many link between titles and genres needs its own junction table, since a film can be both a thriller and a comedy and neither attribute is subordinate to the other.

The questions the platform must answer fall into three tiers. The simplest are lookups and filters: which titles were released in a given window, which are currently active in the catalog, which users have rated anything at all. The middle tier requires aggregation across the rating table: what is a title's average score, how many ratings does it have, which genres draw the highest scores, and how do those answers change once you exclude titles with too few ratings to be meaningful. The hardest tier requires ordering and comparison within groups: how a title's score trends over time as more users weigh in, where a title ranks against others in the same genre, and how an individual user's scoring behavior compares to the platform average. That last tier is what makes window functions necessary rather than optional, and it is the reason the `ratings` table carries a timestamp rather than just a score.

---

## Entity-Relationship Diagram

![Reelist ERD](schema/erd.png)

Editable source: [`schema/erd.dbml`](schema/erd.dbml)

---

## Repository Structure

| Path | Contents |
|---|---|
| `schema/` | DDL script, ERD image and source, relation schemas, constraint justifications |
| `queries/` | One subfolder per unit (`unit3`–`unit6`), holding that assignment's `.sql` files |
| `analysis/` | Written notes and reflections, one markdown file per unit |
| `screenshots/` | Execution evidence, named to map to the task it supports |




---

## Schema

The schema is built by [`schema/schema.sql`](schema/schema.sql), a single PostgreSQL 14+ script that creates all five tables from an empty database. It begins with a reset block, so it can be re-run without manual cleanup:

    psql -d reelist -f schema/schema.sql

### Tables

Listed in creation order. A table is created only after every table it references.

| # | Table | Role | References |
|---|---|---|---|
| 1 | `users` | Dimension: everyone who rates | — |
| 2 | `movies` | Dimension: the catalog being rated | — |
| 3 | `ratings` | Fact table: one score per user per movie | `users`, `movies` |
| 4 | `genres` | Dimension: genre labels, with subgenres | itself |
| 5 | `movie_genres` | Junction: many-to-many between movies and genres | `movies`, `genres` |

### Design decisions worth noticing

- **Deleting a person keeps their ratings; deleting a movie removes them.** `ratings.user_id` uses `ON DELETE SET NULL`, so account deletion severs attribution but leaves the score in every average. `ratings.movie_id` uses `ON DELETE CASCADE`, because a score for a movie that no longer exists means nothing. Routine delisting doesn't delete anything: it sets `movies.is_active` to false.
- **One rating per user per movie.** `UNIQUE (user_id, movie_id)` enforces it. The pair can't be the primary key, because `user_id` becomes NULL after account deletion, so `ratings` uses a surrogate `rating_id`.
- **Half-star scores, stored exactly.** `score` is `NUMERIC(3,2)`, bounded to 0.5–5.0 and restricted to half steps by two CHECK constraints. NUMERIC keeps averages free of floating-point error.
- **Subgenres through a self-referencing key.** `genres.parent_genre_id` points to another genre (Slasher → Horror). Deleting a parent promotes its subgenres to top level instead of deleting them.
- **A composite key on the junction.** `movie_genres` uses `(movie_id, genre_id)` as its primary key, so the same tag can't be recorded twice.
- **Case-insensitive email uniqueness.** A unique index on `LOWER(email_address)` treats `Jon@` and `jon@` as the same address, and a CHECK rejects malformed addresses.
- **Derived values aren't stored.** A user's last activity (`MAX(ratings.posted_at)`) and a title's release status (`release_date` compared with today) are computed at query time, so they can't drift out of sync.
- **Every constraint is named** (`pk_`, `fk_`, `uq_`, `chk_`), so violations identify themselves in error messages.

Full justifications for every key and constraint: [`schema/constraints.md`](schema/constraints.md). Column-level definitions: [`schema/schema-definition.md`](schema/schema-definition.md).
