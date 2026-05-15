{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__player_attributes
-- ============================================================================
-- Reduced player attributes at player-season grain. One record per player
-- per season. The source logs multiple snapshots per player per year —
-- deduplication is applied via ROW_NUMBER() to retain only the most recent
-- record within each season (ORDER BY date DESC).
-- All FIFA rating columns are dropped — only the three play style attributes
-- relevant to this project are retained: preferred_foot, attacking_work_rate,
-- defensive_work_rate.
--
-- Grain        : one row per player per season
-- Loaded as    : view (deduplication handled at query time)
-- Sources      : EUROPEAN_SOCCER_DATABASE.player_attributes, stg_raw__season
-- Filters      : records with NULL preferred_foot are excluded (WHERE on source)
--                rn > 1 rows are excluded (WHERE on renamed_casted)
-- Data quality : attacking_work_rate and defensive_work_rate are normalised —
--                source contains dirty values ('med', 'norm') mapped to 'medium';
--                unrecognised values are coerced to NULL
-- ============================================================================

WITH source AS (

    -- Source: raw player attributes from the bronze layer.
    -- Contains the full FIFA rating profile per player per snapshot date.
    -- Only preferred_foot and work rate columns are used downstream —
    -- all other columns are silently dropped by not selecting them.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'player_attributes') }}

),

joined_season AS (

    -- Join attributes to stg_raw__season to resolve the season_id FK.
    -- The join condition matches the calendar year of the snapshot date
    -- to the start_year of the season (e.g. a snapshot dated 2015-03-10
    -- maps to the 2015/2016 season via start_year = 2015).
    -- INNER JOIN is intentional — snapshots that fall outside any known
    -- season (e.g. dates before 2008 or after 2016) are excluded.
    --
    -- Work rate normalisation: the source contains dirty values alongside
    -- the expected ones ('med' and 'norm' both mean 'medium'). Both are
    -- mapped to 'medium' via CASE LOWER(TRIM(...)). Any unrecognised value
    -- is coerced to NULL rather than passed through as dirty data.
    --
    -- ROW_NUMBER() ranks snapshots within each player + season window by
    -- date DESC — rn = 1 is the most recent snapshot and the one retained.
    -- Pre-filter: records with NULL preferred_foot are excluded here to
    -- avoid carrying incomplete rows into the deduplication window.
    SELECT
        s.id                        AS player_attr_id,  -- Natural PK from source
        s.player_api_id             AS player_api_id,   -- FK to stg_raw__player
        ss.season_id                AS season_id,       -- FK to stg_raw__season (resolved via start_year)
        s.date::DATE                AS attr_date,       -- Snapshot date (used for ROW_NUMBER ordering only)
        s.preferred_foot            AS preferred_foot,  -- Dominant foot: left / right
        CASE LOWER(TRIM(s.attacking_work_rate))
            WHEN 'high'   THEN 'high'
            WHEN 'medium' THEN 'medium'
            WHEN 'med'    THEN 'medium'   -- dirty value → normalised to 'medium'
            WHEN 'norm'   THEN 'medium'   -- dirty value → normalised to 'medium'
            WHEN 'low'    THEN 'low'
            ELSE NULL                     -- unrecognised value → NULL
        END AS attacking_work_rate,
        CASE LOWER(TRIM(s.defensive_work_rate))
            WHEN 'high'   THEN 'high'
            WHEN 'medium' THEN 'medium'
            WHEN 'med'    THEN 'medium'   -- dirty value → normalised to 'medium'
            WHEN 'norm'   THEN 'medium'   -- dirty value → normalised to 'medium'
            WHEN 'low'    THEN 'low'
            ELSE NULL                     -- unrecognised value → NULL
        END AS defensive_work_rate,
        ROW_NUMBER() OVER (
            PARTITION BY s.player_api_id, ss.season_id
            ORDER BY s.date DESC          -- most recent snapshot per player + season ranks first
        )                           AS rn
    FROM source s
    INNER JOIN {{ ref('stg_raw__season') }} ss
        ON YEAR(s.date::DATE) = ss.start_year
    WHERE s.preferred_foot IS NOT NULL

),

renamed_casted AS (

    -- Apply the seasonal snapshot: keep only rn = 1 (most recent record
    -- per player per season) and drop the helper columns attr_date and rn
    -- which were only needed for the deduplication logic above.
    SELECT
        player_attr_id,
        player_api_id,
        season_id,
        preferred_foot,
        attacking_work_rate,
        defensive_work_rate
    FROM joined_season
    WHERE rn = 1

)

SELECT * FROM renamed_casted