{{ config(materialized='view') }}

-- Only preferred_foot and work rates are kept.
-- All FIFA attributes (overall_rating, crossing, finishing...) are dropped.
-- Snapshot applied: one record per player and season
-- using the most recent within each year (ROW_NUMBER).

WITH source AS (
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'player_attributes') }}
),

joined_season AS (
    SELECT
        s.id                        AS player_attr_id,
        s.player_api_id             AS player_api_id,
        ss.season_id                AS season_id,
        s.date::DATE                AS attr_date,
        s.preferred_foot            AS preferred_foot,
        CASE LOWER(TRIM(s.attacking_work_rate))
            WHEN 'high'   THEN 'high'
            WHEN 'medium' THEN 'medium'
            WHEN 'med'    THEN 'medium'
            WHEN 'norm'   THEN 'medium'
            WHEN 'low'    THEN 'low'
            ELSE NULL
        END AS attacking_work_rate,
        CASE LOWER(TRIM(s.defensive_work_rate))
            WHEN 'high'   THEN 'high'
            WHEN 'medium' THEN 'medium'
            WHEN 'med'    THEN 'medium'
            WHEN 'norm'   THEN 'medium'
            WHEN 'low'    THEN 'low'
            ELSE NULL
        END AS defensive_work_rate,
        ROW_NUMBER() OVER (
            PARTITION BY s.player_api_id, ss.season_id
            ORDER BY s.date DESC
        )                           AS rn
    FROM source s
    INNER JOIN {{ ref('stg_raw__season') }} ss
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
    WHERE rn = 1   -- snapshot: most recent record per player and season
)

SELECT * FROM renamed_casted