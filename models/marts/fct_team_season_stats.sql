{{ config(materialized='table') }}

-- ============================================================================
-- fct_team_season_stats
-- ============================================================================
-- Team season statistics fact table. One record per team per season.
-- Aggregated from fct_match_result — home and away matches are unpivoted
-- into one row per team per match before aggregation, so every team
-- appearance is counted regardless of home/away role.
--
-- Grain      : one row per team + season (+ league as tiebreaker context)
-- Loaded as  : table (full refresh on every dbt run)
-- Sources    : fct_match_result
-- Metrics    : matches_played, wins, draws, losses, goals_for,
--              goals_against, goal_difference, points,
--              avg_goals_for, avg_goals_against, win_rate
-- ============================================================================

WITH match_results AS (

    -- Source: fully resolved match-level fact table.
    -- All dimension FKs and metrics are already validated upstream.
    SELECT * FROM {{ ref('fct_match_result') }}

),

-- Unpivot the home side of each match into one row per team appearance.
-- Goals, points and win/draw/loss flags are all mapped from the home
-- team's perspective — match_result = 'H' means home team won.
home_matches AS (
    SELECT
        home_team_sk    AS team_sk,
        league_sk       AS league_sk,
        season_sk       AS season_sk,
        home_goals      AS goals_for,        -- goals scored by this team
        away_goals      AS goals_against,    -- goals conceded by this team
        home_points     AS points,           -- 3 / 1 / 0
        CASE WHEN match_result = 'H' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN match_result = 'D' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN match_result = 'A' THEN 1 ELSE 0 END AS is_loss
    FROM match_results
),

-- Unpivot the away side of each match into one row per team appearance.
-- Goals, points and flags are mirrored — match_result = 'A' means
-- the away team won, so is_win fires on 'A', is_loss fires on 'H'.
away_matches AS (
    SELECT
        away_team_sk    AS team_sk,
        league_sk       AS league_sk,
        season_sk       AS season_sk,
        away_goals      AS goals_for,        -- goals scored by this team
        home_goals      AS goals_against,    -- goals conceded by this team
        away_points     AS points,           -- 3 / 1 / 0
        CASE WHEN match_result = 'A' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN match_result = 'D' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN match_result = 'H' THEN 1 ELSE 0 END AS is_loss
    FROM match_results
),

-- Stack home and away rows into a single flat table.
-- After this point every row represents one team in one match,
-- with goals, points and result flags already oriented correctly.
all_matches AS (
    SELECT * FROM home_matches
    UNION ALL
    SELECT * FROM away_matches
),

-- Aggregate to team + season + league grain.
-- Integer flags (is_win, is_draw, is_loss) are summed directly — no CASE
-- needed at this stage since the binary encoding was done in the CTEs above.
-- Division by COUNT(*) is safe here: every team has at least one match
-- after the UNION ALL, so no zero-division risk.
renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['team_sk', 'season_sk']) }}    AS stat_sk,           -- Surrogate PK (team + season)
        team_sk                                                              AS team_sk,           -- FK to dim_team
        season_sk                                                            AS season_sk,         -- FK to dim_season
        league_sk                                                            AS league_sk,         -- FK to dim_league
        COUNT(*)                                                             AS matches_played,    -- Total matches (home + away)
        SUM(is_win)                                                          AS wins,              -- Matches won
        SUM(is_draw)                                                         AS draws,             -- Matches drawn
        SUM(is_loss)                                                         AS losses,            -- Matches lost
        SUM(goals_for)                                                       AS goals_for,         -- Total goals scored
        SUM(goals_against)                                                   AS goals_against,     -- Total goals conceded
        SUM(goals_for) - SUM(goals_against)                                  AS goal_difference,   -- Net goal difference
        SUM(points)                                                          AS points,            -- Total points (wins×3 + draws)
        ROUND(SUM(goals_for)     / COUNT(*), 2)                              AS avg_goals_for,     -- Avg goals scored per match
        ROUND(SUM(goals_against) / COUNT(*), 2)                              AS avg_goals_against, -- Avg goals conceded per match
        ROUND(SUM(is_win)        / COUNT(*), 2)                              AS win_rate           -- Share of matches won (0.0–1.0)
    FROM all_matches
    GROUP BY team_sk, season_sk, league_sk
)

SELECT * FROM renamed_casted