{{ config(materialized='view') }}
 
WITH source AS (
    SELECT * FROM {{ source('raw', 'team') }}
),
 
renamed_casted AS (
    SELECT
        id              AS team_id,
        team_api_id     AS team_api_id,
        team_long_name  AS team_long_name,
        team_short_name AS team_short_name
    FROM source
)
 
SELECT * FROM renamed_casted