-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: Movies / TV (Reelist)
-- Author: Jonathan Kahng
-- Target: PostgreSQL 14+
-- =================================================================


-- ------------------------
-- Code to reset the table to test table creation
-- ------------------------

DROP TABLE IF EXISTS ratings, movie_genres, movies, genres, users CASCADE;

-- ----------------------------------------------------------------
-- 1. users — first, because it references nothing.
-- ----------------------------------------------------------------

CREATE TABLE users (
    user_id           INTEGER GENERATED ALWAYS AS IDENTITY
                          CONSTRAINT pk_users PRIMARY KEY,
    user_display_name VARCHAR(50) NOT NULL
                          CONSTRAINT uq_users_display_name UNIQUE,
    email_address     VARCHAR(254) NOT NULL
                          CONSTRAINT chk_users_email_format
                          CHECK (email_address ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$'),
    joined_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active         BOOLEAN   NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX uq_users_email_lower ON users (LOWER(email_address));

-- ----------------------------------------------------------------
-- 2. movies — next, because it also references nothing.
-- Could have chosen to do movies table first too.
-- ----------------------------------------------------------------

CREATE TABLE movies (
    movie_id        INTEGER GENERATED ALWAYS AS IDENTITY
                        CONSTRAINT pk_movies PRIMARY KEY,
    movie_title     VARCHAR(200) NOT NULL,
    runtime_minutes INTEGER
                        CONSTRAINT chk_movies_runtime_positive
                        CHECK (runtime_minutes > 0),
    release_date    DATE
                        CONSTRAINT chk_movies_release_date
                        CHECK (release_date >= DATE '1888-01-01'),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------
-- 3. ratings — because it references both the user table (user_id) 
-- and the movies table (movie_id).  Can only be made after creating
-- those two tables first.
-- ----------------------------------------------------------------

CREATE TABLE ratings (
    rating_id INTEGER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_ratings PRIMARY KEY,
    user_id   INTEGER
                  CONSTRAINT fk_ratings_user
                  REFERENCES users (user_id) ON DELETE SET NULL,
    movie_id  INTEGER NOT NULL
                  CONSTRAINT fk_ratings_movie
                  REFERENCES movies (movie_id) ON DELETE CASCADE,
    score     NUMERIC(3,2) NOT NULL
                  CONSTRAINT chk_ratings_score_range
                  CHECK (score BETWEEN 0.5 AND 5.0)
                  CONSTRAINT chk_ratings_score_half_step
                  CHECK (score * 2 = FLOOR(score * 2)),
    posted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ratings_user_movie UNIQUE (user_id, movie_id)
);

-- ----------------------------------------------------------------
-- 4. genres — next, because it references nothing but itself.
-- Could have chosen to do this first, second, or third as well - 
-- so long as it is made before movie_genres
-- ----------------------------------------------------------------

CREATE TABLE genres (
    genre_id        INTEGER GENERATED ALWAYS AS IDENTITY
                        CONSTRAINT pk_genres PRIMARY KEY,
    genre_name      VARCHAR(50) NOT NULL
                        CONSTRAINT uq_genres_name UNIQUE,
    parent_genre_id INTEGER
                        CONSTRAINT fk_genres_parent
                        REFERENCES genres (genre_id) ON DELETE SET NULL,

    CONSTRAINT chk_genres_not_own_parent
        CHECK (parent_genre_id IS DISTINCT FROM genre_id)
);

-- ----------------------------------------------------------------
-- 5. movie_genres — junction table that resolves the M:N
-- relationship between movies and genres. Last, because it
-- references both. The primary key is the pair of foreign keys,
-- not a new id.
-- ----------------------------------------------------------------

CREATE TABLE movie_genres (
    movie_id INTEGER NOT NULL
                CONSTRAINT fk_movie_genres_movie
                REFERENCES movies (movie_id) ON DELETE CASCADE,
    genre_id INTEGER NOT NULL
                CONSTRAINT fk_movie_genres_genre
                REFERENCES genres (genre_id) ON DELETE CASCADE,

    CONSTRAINT pk_movie_genres PRIMARY KEY (movie_id, genre_id)
);
