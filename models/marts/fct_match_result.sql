{{
    config(
        materialized         = 'incremental',
        unique_key           = 'match_sk',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns'
    )
}}

-- ============================================================================
-- fct_match_result
-- ============================================================================
-- Match results fact table. One record per match.
-- Pre-calculates all match-level metrics: total goals, goal difference,
-- match result (H/D/A) and points for both teams — all via macros.
--
-- Grain        : one row per match
-- Loaded as    : incremental (merge on match_sk)
-- Incremental  : processes only matches with match_date > MAX(match_date)
--                already present in the target table
-- Schema change: sync_all_columns — new columns are added automatically
-- Sources      : stg_raw__match, dim_date, dim_team, dim_league, dim_season
-- Macros used  : get_match_result(), get_points()
-- ============================================================================

WITH matches AS (

    -- Source: raw match data from the staging layer.
    -- In incremental runs, only matches newer than the latest match_date
    -- already loaded into fct_match_result are processed.
    -- On a full refresh, all matches are loaded.
    SELECT * FROM {{ ref('stg_raw__match') }}

    {% if is_incremental() %}
        WHERE match_date > (SELECT MAX(match_date) FROM {{ this }})
    {% endif %}

),

dim_date AS (

    -- Used to resolve match_date into date_id (YYYYMMDD integer FK).
    SELECT * FROM {{ ref('dim_date') }}

),

dim_team AS (

    -- Used twice: once for the home team, once for the away team.
    -- Both joins produce a team_sk FK resolved from team_api_id.
    SELECT * FROM {{ ref('dim_team') }}

),

dim_league AS (

    -- Used to resolve league_id into league_sk.
    SELECT * FROM {{ ref('dim_league') }}

),

dim_season AS (

    -- Used to resolve season_name into season_sk.
    SELECT * FROM {{ ref('dim_season') }}

),

joined AS (

    -- Core logic: join matches to all dimensions and compute derived metrics.
    -- dim_team is aliased twice (ht = home team, at = away team) to resolve
    -- both team FKs in a single pass without duplicating the CTE.
    -- All JOINs are INNER — a match with an unresolvable dimension key
    -- would indicate a data quality issue and should not pass through silently.
    SELECT
        {{ dbt_utils.generate_surrogate_key(['m.match_id']) }}   AS match_sk,      -- Surrogate PK
        m.match_id                                               AS match_id,      -- Natural key from source
        d.date_id                                                AS date_id,       -- FK to dim_date (YYYYMMDD)
        ht.team_sk                                               AS home_team_sk,  -- FK to dim_team — home side
        at.team_sk                                               AS away_team_sk,  -- FK to dim_team — away side
        l.league_sk                                              AS league_sk,     -- FK to dim_league
        s.season_sk                                              AS season_sk,     -- FK to dim_season
        m.stage                                                  AS stage,         -- Matchday number within the season
        m.match_date                                             AS match_date,    -- Calendar date of the match
        m.home_goals                                             AS home_goals,    -- Goals scored by the home team
        m.away_goals                                             AS away_goals,    -- Goals scored by the away team
        m.home_goals + m.away_goals                              AS total_goals,   -- Total goals in the match
        m.home_goals - m.away_goals                              AS goal_diff,     -- Goal diff (home perspective)
        {{ get_match_result('m.home_goals', 'm.away_goals') }}   AS match_result,  -- H / D / A via macro
        {{ get_points('m.home_goals', 'm.away_goals', 'home') }} AS home_points,   -- 3 / 1 / 0 via macro
        {{ get_points('m.home_goals', 'm.away_goals', 'away') }} AS away_points    -- 3 / 1 / 0 via macro
    FROM matches        m
    INNER JOIN dim_date   d  ON TO_NUMBER(TO_CHAR(m.match_date, 'YYYYMMDD')) = d.date_id
    INNER JOIN dim_team   ht ON m.home_team_id = ht.team_api_id
    INNER JOIN dim_team   at ON m.away_team_id = at.team_api_id
    INNER JOIN dim_league l  ON m.league_id    = l.league_id
    INNER JOIN dim_season s  ON m.season_name  = s.season_name

)

SELECT * FROM joined