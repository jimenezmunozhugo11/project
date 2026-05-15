{% snapshot team_attributes_snapshot %}

{{
    config(
        unique_key='team_api_id',
        strategy='timestamp',
        updated_at='date'
    )
}}

-- ============================================================================
-- team_attributes_snapshot
-- ============================================================================
-- SCD2 snapshot of team tactical attribute records from the bronze layer.
-- Captures the full history of tactical changes per team. One version row
-- is created each time a team's attributes are updated in the source —
-- previous versions are closed by setting dbt_valid_to.
--
-- Strategy    : timestamp — dbt compares the updated_at field (date) to detect
--               changes; a new version is written when date increases
-- unique_key  : team_api_id — unlike player_attributes_snapshot, this snapshot
--               uses a simple unique_key because the deduplication CTE below
--               guarantees at most one row per team_api_id before dbt applies
--               its merge logic
-- Source      : EUROPEAN_SOCCER_DATABASE.team_attributes (full column scan)
-- Note        : all source columns are preserved here (including team_fifa_api_id,
--               buildupplaydribbling, chancecreationcrossing) to maintain a
--               complete raw history. Dropping out-of-scope columns happens
--               downstream in stg_raw__team_attributes.
-- ============================================================================

-- Pre-deduplication is required before snapshotting because the source contains
-- multiple rows per team_api_id (one per snapshot date). dbt's merge strategy
-- requires the unique_key to be unique in the source query — without QUALIFY,
-- the snapshot would raise a duplicate key error on the first run.
-- QUALIFY ROW_NUMBER() keeps only the most recent record per team so that
-- dbt receives exactly one row per team_api_id to compare against the target.
WITH deduplicated AS (
    SELECT
        id,                             -- Natural PK from source
        team_fifa_api_id,               -- FIFA team ID — preserved for raw history, dropped in staging
        team_api_id,                    -- Main team identifier — unique_key for this snapshot
        date,                           -- Snapshot date — used as updated_at for SCD2 strategy
        buildupplayspeed,               -- Build-up speed score (0–100)
        buildupplayspeedclass,          -- Slow / Balanced / Fast
        buildupplaydribbling,           -- Dribbling tendency (0–100) — dropped in staging
        buildupplaydribblingclass,      -- Little / Normal / Lots — dropped in staging
        buildupplaypassing,             -- Passing length score (0–100)
        buildupplaypassingclass,        -- Short / Mixed / Long
        buildupplaypositioningclass,    -- Organised / Free Form
        chancecreationpassing,          -- Creative pass aggression (0–100)
        chancecreationpassingclass,     -- Safe / Normal / Risky
        chancecreationcrossing,         -- Crossing tendency (0–100) — dropped in staging
        chancecreationcrossingclass,    -- Little / Normal / Lots — dropped in staging
        chancecreationshooting,         -- Shooting tendency (0–100)
        chancecreationshootingclass,    -- Little / Normal / Lots
        chancecreationpositioningclass, -- Organised / Free Form
        defencepressure,                -- Pressure height (0–100)
        defencepressureclass,           -- Deep / Medium / High
        defenceaggression,              -- Challenge intensity (0–100)
        defenceaggressionclass,         -- Contain / Double / Press
        defenceteamwidth,               -- Defensive width (0–100)
        defenceteamwidthclass,          -- Narrow / Normal / Wide
        defencedefenderlineclass        -- Cover / Offside Trap
    FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'team_attributes') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY team_api_id
        ORDER BY date DESC              -- most recent attributes per team rank first
    ) = 1
)

SELECT * FROM deduplicated

{% endsnapshot %}