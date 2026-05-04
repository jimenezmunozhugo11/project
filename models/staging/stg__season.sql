{{ config(materialized='view') }}
 
WITH source AS (
    SELECT DISTINCT season
    FROM {{ source('raw', 'match') }}
    WHERE season IS NOT NULL
),
 
renamed_casted AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY season)           AS season_id,
        season                                        AS season_name,
        SPLIT_PART(season, '/', 1)::INTEGER           AS start_year,
        SPLIT_PART(season, '/', 2)::INTEGER           AS end_year
    FROM source
)
 
SELECT * FROM renamed_casted
 