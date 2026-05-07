{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'league') }}
),

renamed_casted AS (
    SELECT
        id         AS league_id,
        country_id AS country_id,
        name       AS league_name
    FROM source
)

SELECT * FROM renamed_casted