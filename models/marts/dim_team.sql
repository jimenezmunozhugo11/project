{{ config(materialized='table') }}

-- ============================================================================
-- dim_team
-- ============================================================================
-- Team dimension enriched with tactical attributes from
-- stg_raw__team_attributes. One record per team, using the most recent
-- tactical snapshot available — identified by the highest season_id
-- in stg_raw__team_attributes via ROW_NUMBER() + QUALIFY.
-- Teams with no tactical data are retained (LEFT JOIN) with NULL attributes.
--
-- Grain      : one row per team
-- Loaded as  : table (full refresh on every dbt run)
-- Sources    : stg_raw__team, stg_raw__team_attributes
-- ============================================================================

WITH teams AS (

    -- Source: core team data (name, short name, natural key).
    SELECT * FROM {{ ref('stg_raw__team') }}

),

team_attributes AS (

    -- Source: tactical attribute snapshots — multiple rows per team,
    -- one per season the attributes were recorded.
    SELECT * FROM {{ ref('stg_raw__team_attributes') }}

),

latest_attributes AS (

    -- Deduplicate to one row per team by keeping only the most recent
    -- tactical snapshot (highest season_id). QUALIFY with ROW_NUMBER()
    -- is used instead of a subquery for readability and Snowflake performance.
    SELECT *
    FROM team_attributes
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY team_api_id
        ORDER BY season_id DESC
    ) = 1

),

renamed_casted AS (

    -- Join teams with their latest tactical snapshot.
    -- LEFT JOIN is intentional — teams with no recorded attributes
    -- (e.g. teams that never appeared in team_attributes) are kept
    -- with NULL tactical columns rather than being silently dropped.
    SELECT
        {{ dbt_utils.generate_surrogate_key(['t.team_api_id']) }}   AS team_sk,                       -- Surrogate PK
        t.team_api_id                                               AS team_api_id,                   -- Natural key from source
        t.team_long_name                                            AS team_long_name,                -- Full team name (e.g. Real Madrid CF)
        t.team_short_name                                           AS team_short_name,               -- 3-letter abbreviation (e.g. RMA)
        ta.buildup_play_speed                                       AS buildup_play_speed,            -- Build-up speed score (0–100)
        ta.buildup_play_speed_class                                 AS buildup_play_speed_class,      -- Slow / Balanced / Fast
        ta.buildup_play_passing                                     AS buildup_play_passing,          -- Passing style score (0–100)
        ta.buildup_play_passing_class                               AS buildup_play_passing_class,    -- Short / Mixed / Long
        ta.chance_creation_passing                                  AS chance_creation_passing,       -- Creative pass aggression (0–100)
        ta.chance_creation_passing_class                            AS chance_creation_passing_class, -- Safe / Normal / Risky
        ta.chance_creation_shooting                                 AS chance_creation_shooting,      -- Shooting tendency (0–100)
        ta.chance_creation_shooting_class                           AS chance_creation_shooting_class,-- Little / Normal / Lots
        ta.defence_pressure                                         AS defence_pressure,              -- Defensive pressure height (0–100)
        ta.defence_pressure_class                                   AS defence_pressure_class,        -- Deep / Medium / High
        ta.defence_aggression                                       AS defence_aggression,            -- Challenge intensity (0–100)
        ta.defence_aggression_class                                 AS defence_aggression_class,      -- Contain / Double / Press
        ta.defence_team_width                                       AS defence_team_width,            -- Defensive width (0–100)
        ta.defence_defender_line_class                              AS defence_defender_line_class    -- Cover / Offside Trap
    FROM teams              t
    LEFT JOIN latest_attributes ta ON t.team_api_id = ta.team_api_id

)

SELECT * FROM renamed_casted