{{ config(materialized='table') }}

-- Team season statistics fact table. One record per team and season.
-- Granularity: team + season.
-- Aggregated from fct_match_result — both home and away matches
-- are combined to compute full season stats per team.

WITH match_results AS (
    SELECT * FROM {{ ref('fct_match_result') }}
),

-- Unpivot home and away into one row per team per match
home_matches AS (
    SELECT
        home_team_sk    AS team_sk,
        league_sk       AS league_sk,
        season_sk       AS season_sk,
        home_goals      AS goals_for,
        away_goals      AS goals_against,
        home_points     AS points,
        CASE WHEN match_result = 'H' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN match_result = 'D' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN match_result = 'A' THEN 1 ELSE 0 END AS is_loss
    FROM match_results
),

away_matches AS (
    SELECT
        away_team_sk    AS team_sk,
        league_sk       AS league_sk,
        season_sk       AS season_sk,
        away_goals      AS goals_for,
        home_goals      AS goals_against,
        away_points     AS points,
        CASE WHEN match_result = 'A' THEN 1 ELSE 0 END AS is_win,
        CASE WHEN match_result = 'D' THEN 1 ELSE 0 END AS is_draw,
        CASE WHEN match_result = 'H' THEN 1 ELSE 0 END AS is_loss
    FROM match_results
),

all_matches AS (
    SELECT * FROM home_matches
    UNION ALL
    SELECT * FROM away_matches
),

renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['team_sk', 'season_sk']) }}    AS stat_sk,
        team_sk                                                              AS team_sk,
        season_sk                                                            AS season_sk,
        league_sk                                                            AS league_sk,
        COUNT(*)                                                             AS matches_played,
        SUM(is_win)                                                          AS wins,
        SUM(is_draw)                                                         AS draws,
        SUM(is_loss)                                                         AS losses,
        SUM(goals_for)                                                       AS goals_for,
        SUM(goals_against)                                                   AS goals_against,
        SUM(goals_for) - SUM(goals_against)                                  AS goal_difference,
        SUM(points)                                                          AS points,
        ROUND(SUM(goals_for)     / COUNT(*), 2)                              AS avg_goals_for,
        ROUND(SUM(goals_against) / COUNT(*), 2)                              AS avg_goals_against,
        ROUND(SUM(is_win)        / COUNT(*), 2)                              AS win_rate
    FROM all_matches
    GROUP BY team_sk, season_sk, league_sk
)

SELECT * FROM renamed_casted