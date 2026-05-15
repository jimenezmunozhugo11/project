{{ config(materialized='table') }}

-- ============================================================================
-- dim_league
-- ============================================================================
-- League dimension enriched with the country name from stg_raw__country.
-- Built by joining stg_raw__league with stg_raw__country on country_id.
--
-- Grain      : one row per league
-- Row count  : 11 leagues across 11 European countries
-- Loaded as  : table (full refresh on every dbt run)
-- ============================================================================

WITH leagues AS (

    -- Source: all leagues from the staging layer.
    SELECT * FROM {{ ref('stg_raw__league') }}

),

countries AS (

    -- Source: country reference table used to resolve country names.
    SELECT * FROM {{ ref('stg_raw__country') }}

),

renamed_casted AS (

    -- Join leagues with countries to enrich each league with its country name.
    -- INNER JOIN is intentional — any league without a matching country_id
    -- would indicate a data quality issue in the source and should not
    -- silently pass through as NULL.
    SELECT
        {{ dbt_utils.generate_surrogate_key(['l.league_id']) }}   AS league_sk,     -- Surrogate PK
        l.league_id                                               AS league_id,     -- Natural key from source
        l.league_name                                             AS league_name,   -- Full league name (e.g. Spain LIGA BBVA)
        c.country_name                                            AS country_name   -- Country where the league is played
    FROM leagues    l
    INNER JOIN countries c ON l.country_id = c.country_id

)

SELECT * FROM renamed_casted