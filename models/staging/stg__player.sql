{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'player') }}
),

renamed_casted AS (
    SELECT
        id                                                       AS player_id,
        player_api_id                                            AS player_api_id,
        player_name                                              AS player_name,
        birthday::DATE                                           AS birthday,
        DATEDIFF('year', birthday::DATE, CURRENT_DATE())         AS age,
        height                                                   AS height,
        weight                                                   AS weight
    FROM source
    WHERE player_name IS NOT NULL
)

SELECT * FROM renamed_casted