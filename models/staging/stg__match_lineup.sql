{{ config(materialized='view') }}

-- Tabla puente entre jugadores y equipos.
-- Se genera haciendo UNPIVOT de las 22 columnas de alineación de match
-- (home_player_1..11 y away_player_1..11) para convertirlas en filas.
-- Sin esta tabla no es posible relacionar stg_player con stg_team.

WITH source AS (
    SELECT * FROM {{ source('raw', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL
),

home_players AS (
    SELECT
        id               AS match_id,
        home_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        TRUE             AS is_home,
        position_number  AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_number IN (
        home_player_1  AS 1,
        home_player_2  AS 2,
        home_player_3  AS 3,
        home_player_4  AS 4,
        home_player_5  AS 5,
        home_player_6  AS 6,
        home_player_7  AS 7,
        home_player_8  AS 8,
        home_player_9  AS 9,
        home_player_10 AS 10,
        home_player_11 AS 11
    ))
),

away_players AS (
    SELECT
        id               AS match_id,
        away_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        FALSE            AS is_home,
        position_number  AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_number IN (
        away_player_1  AS 1,
        away_player_2  AS 2,
        away_player_3  AS 3,
        away_player_4  AS 4,
        away_player_5  AS 5,
        away_player_6  AS 6,
        away_player_7  AS 7,
        away_player_8  AS 8,
        away_player_9  AS 9,
        away_player_10 AS 10,
        away_player_11 AS 11
    ))
),

combined AS (
    SELECT * FROM home_players
    UNION ALL
    SELECT * FROM away_players
),

renamed_casted AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY match_id, is_home DESC, position_number
        )               AS lineup_id,
        match_id        AS match_id,
        team_api_id     AS team_api_id,
        player_api_id   AS player_api_id,
        is_home         AS is_home,
        position_number AS position_number
    FROM combined
    WHERE player_api_id IS NOT NULL
)

SELECT * FROM renamed_casted