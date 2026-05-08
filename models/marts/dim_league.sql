{{ config(materialized='table') }}

-- League dimension enriched with country name.
-- Built from stg_raw__league joined with stg_raw__country.
-- One record per league.

WITH leagues AS (
    SELECT * FROM {{ ref('stg_raw__league') }}
),

countries AS (
    SELECT * FROM {{ ref('stg_raw__country') }}
),

renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['l.league_id']) }}   AS league_sk,
        l.league_id                                               AS league_id,
        l.league_name                                             AS league_name,
        c.country_name                                            AS country_name
    FROM leagues l
    INNER JOIN countries c ON l.country_id = c.country_id
)

SELECT * FROM renamed_casted