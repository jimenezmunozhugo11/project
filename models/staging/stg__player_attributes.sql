{{ config(materialized='view') }}

-- Se conservan solo preferred_foot y work rates.
-- Los atributos FIFA (overall_rating, crossing, finishing...) se descartan.
-- Se aplica un snapshot: un registro por jugador y temporada
-- usando el más reciente dentro de cada año (ROW_NUMBER).

WITH source AS (
    SELECT * FROM {{ source('raw', 'player_attributes') }}
),

joined_season AS (
    SELECT
        s.id                        AS player_attr_id,
        s.player_api_id             AS player_api_id,
        ss.season_id                AS season_id,
        s.date::DATE                AS attr_date,
        s.preferred_foot            AS preferred_foot,
        s.attacking_work_rate       AS attacking_work_rate,
        s.defensive_work_rate       AS defensive_work_rate,
        ROW_NUMBER() OVER (
            PARTITION BY s.player_api_id, ss.season_id
            ORDER BY s.date DESC
        )                           AS rn
    FROM source s
    INNER JOIN {{ ref('stg__season') }} ss
        ON YEAR(s.date::DATE) = ss.start_year
    WHERE s.preferred_foot IS NOT NULL
),

renamed_casted AS (
    SELECT
        player_attr_id,
        player_api_id,
        season_id,
        preferred_foot,
        attacking_work_rate,
        defensive_work_rate
    FROM joined_season
    WHERE rn = 1   -- snapshot: registro más reciente por jugador y temporada
)

SELECT * FROM renamed_casted