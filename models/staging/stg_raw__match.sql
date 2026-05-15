{{
    config(
        materialized         = 'incremental',
        unique_key           = 'match_id',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns'
    )
}}

-- ============================================================================
-- stg_raw__match
-- ============================================================================
-- Main fact source of the project. One record per match.
-- Renames and casts the relevant source columns and drops everything
-- outside project scope: XML event columns (goal, card, shoton...),
-- all betting odds (30 columns across 10 bookmakers), player position
-- coordinates (x/y) and the 22 lineup columns (handled separately
-- in stg_raw__match_lineup via UNPIVOT).
--
-- Grain        : one row per match
-- Loaded as    : incremental (merge on match_id)
-- Incremental  : processes only matches with date > MAX(match_date)
--                already present in the target table
-- Schema change: sync_all_columns — new columns are added automatically
-- Sources      : EUROPEAN_SOCCER_DATABASE.match
-- Filter       : matches with NULL home or away team ID are excluded
-- ============================================================================

WITH source AS (

    -- Source: raw match table from the bronze layer.
    -- Pre-filter: matches missing either team ID are excluded upfront —
    -- they cannot produce valid FK references and would fail relationship tests.
    -- Incremental filter: on incremental runs, only matches with a date
    -- strictly greater than the latest match_date already loaded are processed.
    -- On a full refresh all matches passing the NULL filter are loaded.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL

    {% if is_incremental() %}
        AND date::DATE > (SELECT MAX(match_date) FROM {{ this }})
    {% endif %}

),

renamed_casted AS (

    -- Rename and cast source columns to project conventions.
    -- date::DATE    strips the time component — match time is not used downstream.
    -- season        → season_name to distinguish it from the season_id FK
    --                 resolved later in the marts layer via stg_raw__season.
    -- home/away_team_api_id → home/away_team_id to align with FK naming conventions.
    -- home/away_team_goal   → home/away_goals for conciseness.
    SELECT
        id               AS match_id,      -- Natural PK from source
        country_id       AS country_id,    -- FK to stg_raw__country
        league_id        AS league_id,     -- FK to stg_raw__league
        season           AS season_name,   -- Season label (e.g. 2015/2016) — not yet resolved to season_id
        stage            AS stage,         -- Matchday number within the season
        date::DATE       AS match_date,    -- Match date, time component dropped
        home_team_api_id AS home_team_id,  -- FK to stg_raw__team (home side)
        away_team_api_id AS away_team_id,  -- FK to stg_raw__team (away side)
        home_team_goal   AS home_goals,    -- Goals scored by the home team
        away_team_goal   AS away_goals     -- Goals scored by the away team
    FROM source

)

SELECT * FROM renamed_casted