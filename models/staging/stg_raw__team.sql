{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__team
-- ============================================================================
-- Football teams present in the dataset. One record per team.
-- Minimal staging model — only renames columns to project conventions
-- and drops team_fifa_api_id (out of project scope).
-- Contains two identifiers: team_id (internal) and team_api_id
-- (the main join key used across the rest of the project).
--
-- Grain      : one row per team
-- Loaded as  : view (source is static — no storage cost justified)
-- Sources    : EUROPEAN_SOCCER_DATABASE.team
-- Dropped    : team_fifa_api_id (out of project scope)
-- ============================================================================

WITH source AS (

    -- Source: raw team table from the bronze layer.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'team') }}

),

renamed_casted AS (

    -- Rename source columns to project naming conventions.
    -- id          → team_id     (explicit, avoids ambiguity in downstream joins)
    -- team_api_id is kept as-is — already follows project conventions and
    --             is the primary join key for all team-related relationships.
    -- team_fifa_api_id: dropped — FIFA team IDs are out of project scope.
    SELECT
        id              AS team_id,          -- Internal surrogate PK (not used as join key)
        team_api_id     AS team_api_id,      -- Main team identifier — FK join key downstream
        team_long_name  AS team_long_name,   -- Full official team name (e.g. Real Madrid CF)
        team_short_name AS team_short_name   -- Three-letter abbreviation (e.g. RMA)
        -- team_fifa_api_id: dropped — out of project scope
    FROM source

)

SELECT * FROM renamed_casted