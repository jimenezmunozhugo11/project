{% snapshot player_attributes_snapshot %}

{{
    config(
        unique_key='player_api_id || \'-\' || date',
        strategy='timestamp',
        updated_at='date'
    )
}}

-- ============================================================================
-- player_attributes_snapshot
-- ============================================================================
-- SCD2 snapshot of player attribute records from the bronze layer.
-- Captures the full history of attribute changes per player per snapshot date.
-- One version row is created each time a player's attributes are updated
-- in the source — previous versions are closed by setting dbt_valid_to.
--
-- Strategy    : timestamp — dbt compares the updated_at field (date) to detect
--               changes; a new version is written when date increases
-- unique_key  : player_api_id + date — composite key to handle players with
--               multiple snapshots on different dates without collision
-- Source      : EUROPEAN_SOCCER_DATABASE.player_attributes (full column scan)
-- Note        : all FIFA rating columns are included here (crossing, finishing...)
--               to preserve the complete raw history. Filtering to project-scope
--               columns only (preferred_foot, work rates) happens downstream
--               in stg_raw__player_attributes.
-- ============================================================================

SELECT
    id,                   -- Natural PK from source
    player_api_id,        -- Main player identifier — FK join key downstream
    date,                 -- Snapshot date — used as updated_at for SCD2 strategy
    preferred_foot,       -- Dominant foot: left / right
    attacking_work_rate,  -- Offensive effort: low / medium / high (contains dirty values — cleaned in staging)
    defensive_work_rate,  -- Defensive effort: low / medium / high (contains dirty values — cleaned in staging)
    crossing,             -- FIFA skill (0–100) — not used downstream, preserved for raw history
    finishing,            -- FIFA skill (0–100) — not used downstream, preserved for raw history
    heading_accuracy,
    short_passing,
    volleys,
    dribbling,
    curve,
    free_kick_accuracy,
    long_passing,
    ball_control,
    acceleration,
    sprint_speed,
    agility,
    reactions,
    balance,
    shot_power,
    jumping,
    stamina,
    strength,
    long_shots,
    aggression,
    interceptions,
    positioning,
    vision,
    penalties,
    marking,
    standing_tackle,
    sliding_tackle,
    gk_diving,
    gk_handling,
    gk_kicking,
    gk_positioning,
    gk_reflexes
FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'player_attributes') }}

{% endsnapshot %}