{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__match_lineup
-- ============================================================================
-- Bridge table between matches, teams and players. One record per player
-- appearance in a match lineup. Normalises the 22 wide player columns
-- (home_player_1..11, away_player_1..11) from the source match table
-- into a long format via UNPIVOT — one row per player per match.
-- Without this model it is not possible to relate players to teams directly.
--
-- Grain      : one row per player appearance per match
-- Loaded as  : view (derived entirely from the match source — no extra storage)
-- Sources    : EUROPEAN_SOCCER_DATABASE.match
-- Filters    : matches with NULL home or away team are excluded (WHERE on source)
--              players with NULL player_api_id are excluded (WHERE on combined)
-- ============================================================================

WITH source AS (

    -- Source: raw match table from the bronze layer.
    -- Pre-filter: matches missing either team ID are excluded upfront —
    -- they cannot produce valid lineup records and would generate NULL FKs.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL

),

home_players AS (

    -- Unpivot the 11 home player columns into one row per player.
    -- position_col holds the original column name (e.g. HOME_PLAYER_3) —
    -- the prefix is stripped and cast to INTEGER to produce position_number.
    -- is_home is hardcoded to TRUE for all rows in this CTE.
    SELECT
        id               AS match_id,
        home_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        TRUE             AS is_home,
        CAST(REPLACE(position_col, 'HOME_PLAYER_', '') AS INTEGER) AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_col IN (
        home_player_1,
        home_player_2,
        home_player_3,
        home_player_4,
        home_player_5,
        home_player_6,
        home_player_7,
        home_player_8,
        home_player_9,
        home_player_10,
        home_player_11
    ))

),

away_players AS (

    -- Mirror of home_players for the 11 away player columns.
    -- The only differences are the team FK (away_team_api_id),
    -- the prefix stripped from position_col (AWAY_PLAYER_),
    -- and is_home hardcoded to FALSE.
    SELECT
        id               AS match_id,
        away_team_api_id AS team_api_id,
        player_api_id    AS player_api_id,
        FALSE            AS is_home,
        CAST(REPLACE(position_col, 'AWAY_PLAYER_', '') AS INTEGER) AS position_number
    FROM source
    UNPIVOT (player_api_id FOR position_col IN (
        away_player_1,
        away_player_2,
        away_player_3,
        away_player_4,
        away_player_5,
        away_player_6,
        away_player_7,
        away_player_8,
        away_player_9,
        away_player_10,
        away_player_11
    ))

),

combined AS (

    -- Stack home and away rows into a single flat table.
    -- After this point every row represents one player appearance
    -- in one match, with team and position already resolved.
    SELECT * FROM home_players
    UNION ALL
    SELECT * FROM away_players

),

renamed_casted AS (

    -- Generate the surrogate PK using ROW_NUMBER().
    -- Ordering: match_id ASC → home before away (is_home DESC) →
    -- position 1..11 within each team. This makes the PK stable and
    -- the output predictable when browsing the table directly.
    -- Post-filter: rows where player_api_id IS NULL are excluded —
    -- missing lineup entries in the source are not valid bridge records.
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY match_id, is_home DESC, position_number
        )               AS lineup_id,       -- Surrogate PK
        match_id        AS match_id,        -- FK to stg_raw__match
        team_api_id     AS team_api_id,     -- FK to stg_raw__team
        player_api_id   AS player_api_id,   -- FK to stg_raw__player
        is_home         AS is_home,         -- TRUE = home team, FALSE = away team
        position_number AS position_number  -- Lineup position (1 = GK, 2–11 = outfield)
    FROM combined
    WHERE player_api_id IS NOT NULL

)

SELECT * FROM renamed_casted