{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'country') }}
),

renamed_casted AS (
    SELECT
        id as country_id,
        name as country_name
    FROM src_promos
)

SELECT * FROM renamed_casted