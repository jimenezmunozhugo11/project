{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'country') }}
),

renamed_casted AS (
    SELECT
        id as country_id,
        name as country_name
    FROM source
)

SELECT * FROM renamed_casted