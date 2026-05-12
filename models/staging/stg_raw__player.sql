{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'player') }}
),

renamed_casted AS (
    SELECT
        id                                                        AS player_id,
        player_api_id                                             AS player_api_id,
        player_name                                               AS player_name,
        TO_VARCHAR(birthday::DATE, 'DD-MM-YYYY')                  AS birthday,
        DATEDIFF('year', birthday::DATE, CURRENT_DATE())          AS age,
        ROUND(height)::INT                                        AS height_cm,
        ROUND(weight * 0.453592)::INT                             AS weight_kg
        -- player_fifa_api_id dropped: not used in silver
    FROM source
    WHERE player_name IS NOT NULL
)

SELECT * FROM renamed_casted