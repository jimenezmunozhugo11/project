{{ config(materialized='table') }}

-- ============================================================================
-- dim_season
-- ============================================================================
-- Season dimension with a surrogate key added on top of the staging layer.
-- No joins required — all attributes are available in stg_raw__season.
--
-- Grain      : one row per season
-- Row count  : 8 seasons (2008/2009 → 2015/2016)
-- Loaded as  : table (full refresh on every dbt run)
-- Sources    : stg_raw__season
-- ============================================================================

WITH seasons AS (

    -- Source: all seasons from the staging layer.
    SELECT * FROM {{ ref('stg_raw__season') }}

),

renamed_casted AS (

    -- Add surrogate key. No transformations needed beyond that —
    -- stg_raw__season already delivers clean, typed attributes.
    SELECT
        {{ dbt_utils.generate_surrogate_key(['season_id']) }}   AS season_sk,    -- Surrogate PK
        season_id                                               AS season_id,    -- Natural key from source
        season_name                                             AS season_name,  -- Season label (e.g. 2015/2016)
        start_year                                              AS start_year,   -- Four-digit start year (e.g. 2015)
        end_year                                                AS end_year      -- Four-digit end year (e.g. 2016)
    FROM seasons

)

SELECT * FROM renamed_casted