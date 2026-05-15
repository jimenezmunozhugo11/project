{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__team_attributes
-- ============================================================================
-- Team tactical attributes at team-season grain. One record per team
-- per season. The source logs a new snapshot each time a team changes
-- its tactical setup — deduplication is applied via ROW_NUMBER() to
-- retain only the most recent record within each season (ORDER BY date DESC).
-- All source column names are renamed from concatenated lowercase
-- (e.g. buildupplayspeed) to snake_case (e.g. buildup_play_speed).
--
-- Grain      : one row per team per season
-- Loaded as  : view (deduplication handled at query time)
-- Sources    : EUROPEAN_SOCCER_DATABASE.team_attributes, stg_raw__season
-- Filters    : rn > 1 rows are excluded (WHERE on renamed_casted)
-- Dropped    : team_fifa_api_id (out of project scope)
--              buildupplaydribbling (out of project scope)
--              chancecreationcrossing (out of project scope)
-- ============================================================================

WITH source AS (

    -- Source: raw team attributes from the bronze layer.
    -- Column names arrive as concatenated lowercase strings (Snowflake default
    -- for SQLite sources) — all renaming to snake_case happens in joined_season.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'team_attributes') }}

),

joined_season AS (

    -- Join attributes to stg_raw__season to resolve the season_id FK.
    -- The join condition matches the calendar year of the snapshot date
    -- to the start_year of the season (e.g. a snapshot dated 2014-09-18
    -- maps to the 2014/2015 season via start_year = 2014).
    -- INNER JOIN is intentional — snapshots that fall outside any known
    -- season (e.g. dates before 2008 or after 2016) are excluded.
    --
    -- ROW_NUMBER() ranks snapshots within each team + season window by
    -- date DESC — rn = 1 is the most recent snapshot and the one retained.
    --
    -- Dropped columns (not selected):
    --   team_fifa_api_id        — FIFA team ID, out of project scope
    --   buildupplaydribbling    — tactical attribute, out of project scope
    --   chancecreationcrossing  — tactical attribute, out of project scope
    SELECT
        s.id                            AS team_attr_id,                 -- Natural PK from source
        s.team_api_id                   AS team_api_id,                  -- FK to stg_raw__team
        ss.season_id                    AS season_id,                    -- FK to stg_raw__season (resolved via start_year)
        s.date::DATE                    AS attr_date,                    -- Snapshot date (used for ROW_NUMBER ordering only)
        s.buildupplayspeed              AS buildup_play_speed,           -- Build-up speed score (0–100)
        s.buildupplayspeedclass         AS buildup_play_speed_class,     -- Slow / Balanced / Fast
        s.buildupplaypassing            AS buildup_play_passing,         -- Passing length score (0–100)
        s.buildupplaypassingclass       AS buildup_play_passing_class,   -- Short / Mixed / Long
        s.chancecreationpassing         AS chance_creation_passing,      -- Creative pass aggression (0–100)
        s.chancecreationpassingclass    AS chance_creation_passing_class,-- Safe / Normal / Risky
        s.chancecreationshooting        AS chance_creation_shooting,     -- Shooting tendency (0–100)
        s.chancecreationshootingclass   AS chance_creation_shooting_class,-- Little / Normal / Lots
        s.defencepressure               AS defence_pressure,             -- Pressure height (0–100)
        s.defencepressureclass          AS defence_pressure_class,       -- Deep / Medium / High
        s.defenceaggression             AS defence_aggression,           -- Challenge intensity (0–100)
        s.defenceaggressionclass        AS defence_aggression_class,     -- Contain / Double / Press
        s.defenceteamwidth              AS defence_team_width,           -- Defensive width (0–100)
        s.defencedefenderlineclass      AS defence_defender_line_class,  -- Cover / Offside Trap
        ROW_NUMBER() OVER (
            PARTITION BY s.team_api_id, ss.season_id
            ORDER BY s.date DESC        -- most recent snapshot per team + season ranks first
        )                               AS rn
    FROM source s
    INNER JOIN {{ ref('stg_raw__season') }} ss
        ON YEAR(s.date::DATE) = ss.start_year

),

renamed_casted AS (

    -- Apply the seasonal snapshot: keep only rn = 1 (most recent record
    -- per team per season) and drop the helper columns attr_date and rn
    -- which were only needed for the deduplication logic above.
    SELECT
        team_attr_id,
        team_api_id,
        season_id,
        buildup_play_speed,
        buildup_play_speed_class,
        buildup_play_passing,
        buildup_play_passing_class,
        chance_creation_passing,
        chance_creation_passing_class,
        chance_creation_shooting,
        chance_creation_shooting_class,
        defence_pressure,
        defence_pressure_class,
        defence_aggression,
        defence_aggression_class,
        defence_team_width,
        defence_defender_line_class
    FROM joined_season
    WHERE rn = 1    -- snapshot: keep only the most recent record per team + season

)

SELECT * FROM renamed_casted