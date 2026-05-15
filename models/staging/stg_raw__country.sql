{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__country
-- ============================================================================
-- Country reference table. One record per country.
-- Minimal staging model — only renames columns to project conventions.
-- No casting, filtering or deduplication required.
--
-- Grain      : one row per country
-- Loaded as  : view (no storage cost — source is static and small)
-- Sources    : EUROPEAN_SOCCER_DATABASE.country
-- ============================================================================

WITH source AS (

    -- Source: raw country table from the bronze layer.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'country') }}

),

renamed_casted AS (

    -- Rename source columns to project naming conventions.
    -- id   → country_id  (explicit, avoids ambiguity in downstream joins)
    -- name → country_name (avoids collision with reserved word NAME in Snowflake)
    SELECT
        id   AS country_id,
        name AS country_name
    FROM source

)

SELECT * FROM renamed_casted