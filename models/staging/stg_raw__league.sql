{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__league
-- ============================================================================
-- League reference table enriched with a country FK. One record per league.
-- Minimal staging model — only renames columns to project conventions.
-- No casting, filtering or deduplication required.
--
-- Grain      : one row per league
-- Loaded as  : view (no storage cost — source is static and small)
-- Sources    : EUROPEAN_SOCCER_DATABASE.league
-- ============================================================================

WITH source AS (

    -- Source: raw league table from the bronze layer.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'league') }}

),

renamed_casted AS (

    -- Rename source columns to project naming conventions.
    -- id         → league_id   (explicit, avoids ambiguity in downstream joins)
    -- name       → league_name (avoids collision with reserved word NAME in Snowflake)
    -- country_id is kept as-is — already follows project conventions.
    SELECT
        id         AS league_id,
        country_id AS country_id,
        name       AS league_name
    FROM source

)

SELECT * FROM renamed_casted