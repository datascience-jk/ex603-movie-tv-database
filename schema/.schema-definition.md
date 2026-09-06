# Reelist Schema Definition


## users

The actor role. Record of every user on Reelist, active and inactive.

| Attribute | Domain | Notes |
|---|---|---|
| user_id | INTEGER | Surrogate key, auto-generated |
| user_display_name | VARCHAR(50) | User-generated display name to be displayed across the platform, e.g. "User_123" |
| joined_at | TIMESTAMP | When user joined Reelist |
| last_active | TIMESTAMP | When the user last logged into Reelist |
| is_active | BOOLEAN | True = Customer has not deactivated the account; this is set to true by default for every new entry. False = User has deactivated account |

**Primary key:** `user_id`


## movies

The producer role. Records every movie, both listed and non-listed, on Reelist.

| Attribute | Domain | Notes |
|---|---|---|
| movie_id | INTEGER | Surrogate key, auto-generated |
| movie_title | VARCHAR(200) | Title of the Movie which will serve as the display name across the platform, e.g. "Inception" |
| runtime_minutes | INTEGER | Total movie runtime in minutes |
| release_date | DATE | When the movie was or will be released |
| is_active | BOOLEAN | True = The movie is listed on the site/app experience; False = Not listed in the catalog. Can be set ot false by admin or delisted for licensing reasons. Defaults to true. |

**Primary key:** `movie_id`


## ratings

The event role. Records each rating a user places on a movie.

| Attribute | Domain | Notes |
|---|---|---|
| rating_id | INTEGER | Surrogate key, auto-generated |
| user_id | INTEGER | Foreign Key to "users" |
| movie_id | INTEGER | Foreign Key to "movies" |
| score | SMALLINT | 0–10, displayed to users as 0–5 stars, half-star increments |
| posted_at | TIMESTAMP | When user placed the rating|

**Primary key:** `ratings_id`

## genres

The catalog role. Classifies titles into named categories.

| Attribute | Domain | Notes |
|---|---|---|
| genre_id | INTEGER | Surrogate key, auto-generated |
| genre_name | VARCHAR(50) | Genre label, e.g. "Thriller" |

**Primary key:** `genre_id`

## movie_genres

The junction role. The many-to-many link between movies and genres. 

| Attribute | Domain | Notes |
|---|---|---|
| movie_id | INTEGER | Foreign key to 'movies' |
| genre_id | INTEGER | Foreign key to 'genres' |

**Primary key:** `(movie_id, genre_id)`
