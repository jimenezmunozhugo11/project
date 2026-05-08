{{ config(materialized='view') }}
 
-- stg_raw__season does not exist as a table in RAW.
-- It is derived from the unique values of the season field in match.
 
WITH source AS (
    SELECT DISTINCT season
    FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'match') }}
    WHERE season IS NOT NULL
),
 
renamed_casted AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY season)         AS season_id,
        season                                      AS season_name,
        SPLIT_PART(season, '/', 1)::INTEGER         AS start_year,
        SPLIT_PART(season, '/', 2)::INTEGER         AS end_year
    FROM source
)
 
SELECT * FROM renamed_casted
 
 