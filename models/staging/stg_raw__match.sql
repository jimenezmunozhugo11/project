{{
    config(
        materialized         = 'incremental',
        unique_key           = 'match_id',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns'
    )
}}

-- Main table of the project. Materialized as incremental (merge)
-- to simulate the weekly ingestion of new matches.
-- Dropped: XML columns (goal, card, shoton...), betting odds,
-- position coordinates (x/y) and lineup columns (handled in stg_raw__match_lineup).

WITH source AS (
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL

    {% if is_incremental() %}
        -- Incremental loads only process matches newer than the
        -- latest match_date already loaded in the table
        AND date::DATE > (SELECT MAX(match_date) FROM {{ this }})
    {% endif %}
),

renamed_casted AS (
    SELECT
        id               AS match_id,
        country_id       AS country_id,
        league_id        AS league_id,
        season           AS season_name,
        stage            AS stage,
        date::DATE       AS match_date,
        home_team_api_id AS home_team_id,
        away_team_api_id AS away_team_id,
        home_team_goal   AS home_goals,
        away_team_goal   AS away_goals
    FROM source
)

SELECT * FROM renamed_casted