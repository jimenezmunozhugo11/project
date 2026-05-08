{{ config(materialized='table') }}

-- Player dimension enriched with play style attributes.
-- One record per player and season — player attributes can change
-- across seasons (preferred foot, work rates).
-- FIFA ratings are excluded from this project.
-- Built from stg_raw__player joined with stg_raw__player_attributes and dim_season.

WITH players AS (
    SELECT * FROM {{ ref('stg_raw__player') }}
),

player_attributes AS (
    SELECT * FROM {{ ref('stg_raw__player_attributes') }}
),

seasons AS (
    SELECT * FROM {{ ref('dim_season') }}
),

renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['p.player_api_id', 'pa.season_id']) }}   AS player_sk,
        p.player_api_id                                                                AS player_api_id,
        s.season_sk                                                                    AS season_sk,
        p.player_name                                                                  AS player_name,
        p.birthday                                                                     AS birthday,
        p.age                                                                          AS age,
        p.height                                                                       AS height,
        p.weight                                                                       AS weight,
        pa.preferred_foot                                                              AS preferred_foot,
        pa.attacking_work_rate                                                         AS attacking_work_rate,
        pa.defensive_work_rate                                                         AS defensive_work_rate
    FROM players p
    INNER JOIN player_attributes pa ON p.player_api_id = pa.player_api_id
    INNER JOIN seasons s            ON pa.season_id    = s.season_id
)

SELECT * FROM renamed_casted