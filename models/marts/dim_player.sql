{{ config(materialized='table') }}

-- ============================================================================
-- dim_player
-- ============================================================================
-- Player dimension enriched with play style attributes from
-- stg_raw__player_attributes. One record per player per season —
-- attributes such as preferred foot and work rates can evolve
-- across seasons and are therefore snapshotted at season grain.
-- FIFA ratings (overall_rating, potential, player_fifa_api_id)
-- are explicitly excluded from this project.
--
-- Grain      : one row per player per season (player_api_id + season_id)
-- Loaded as  : table (full refresh on every dbt run)
-- Sources    : stg_raw__player, stg_raw__player_attributes, dim_season
-- ============================================================================

WITH players AS (

    -- Source: biographical player data (name, birthday, height, weight).
    SELECT * FROM {{ ref('stg_raw__player') }}

),

player_attributes AS (

    -- Source: season-level play style attributes (foot, work rates).
    -- One row per player per season — FIFA rating columns excluded upstream.
    SELECT * FROM {{ ref('stg_raw__player_attributes') }}

),

seasons AS (

    -- Source: season dimension used to resolve season_id into season_sk.
    SELECT * FROM {{ ref('dim_season') }}

),

renamed_casted AS (

    -- Join players with their seasonal attributes and resolve the season SK.
    -- Both JOINs are INNER — a player attribute row with no matching player
    -- or no matching season would indicate a referential integrity issue
    -- in the source and should not silently produce NULL keys.
    SELECT
        {{ dbt_utils.generate_surrogate_key(['p.player_api_id', 'pa.season_id']) }}   AS player_sk,           -- Surrogate PK (player + season)
        p.player_api_id                                                                AS player_api_id,       -- Natural key from source
        s.season_sk                                                                    AS season_sk,           -- FK to dim_season
        p.player_name                                                                  AS player_name,         -- Full player name
        p.birthday                                                                     AS birthday,            -- Date of birth
        p.age                                                                          AS age,                 -- Age derived from birthday
        p.height_cm                                                                    AS height,              -- Height in centimetres
        p.weight_kg                                                                    AS weight,              -- Weight in kilograms
        pa.preferred_foot                                                              AS preferred_foot,      -- Dominant foot: left / right
        pa.attacking_work_rate                                                         AS attacking_work_rate, -- Offensive effort: low / medium / high
        pa.defensive_work_rate                                                         AS defensive_work_rate  -- Defensive effort: low / medium / high
    FROM players            p
    INNER JOIN player_attributes pa ON p.player_api_id = pa.player_api_id
    INNER JOIN seasons           s  ON pa.season_id    = s.season_id

)

SELECT * FROM renamed_casted