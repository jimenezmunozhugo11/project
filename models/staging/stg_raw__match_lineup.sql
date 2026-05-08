{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL
),

home_players AS (
    SELECT
        id               AS match_id,
        home_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        TRUE             AS is_home,
        CAST(REPLACE(position_col, 'HOME_PLAYER_', '') AS INTEGER) AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_col IN (
        home_player_1,
        home_player_2,
        home_player_3,
        home_player_4,
        home_player_5,
        home_player_6,
        home_player_7,
        home_player_8,
        home_player_9,
        home_player_10,
        home_player_11
    ))
),

away_players AS (
    SELECT
        id               AS match_id,
        away_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        FALSE            AS is_home,
        CAST(REPLACE(position_col, 'AWAY_PLAYER_', '') AS INTEGER) AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_col IN (
        away_player_1,
        away_player_2,
        away_player_3,
        away_player_4,
        away_player_5,
        away_player_6,
        away_player_7,
        away_player_8,
        away_player_9,
        away_player_10,
        away_player_11
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