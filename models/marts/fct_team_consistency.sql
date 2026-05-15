-- ============================================================================
-- fct_team_consistency
-- ============================================================================
-- Team consistency fact table based on goal-scoring variance.
-- One record per team per season per league.
-- Uses STDDEV() to measure how predictable a team's scoring output is —
-- low standard deviation = consistent scorer, high = erratic scorer.
--
-- Grain        : one row per team + season + league
-- Sources      : fct_match_result, dim_team, dim_league, dim_season
-- Filter       : teams with fewer than 10 matches in a season are excluded
--                (HAVING clause) to ensure a statistically reliable sample
-- Window funcs : RANK() OVER (PARTITION BY season + league) — dual ranking
--                by stddev_goals ASC (most consistent) and DESC (most erratic)
-- ============================================================================

-- Unpivot home and away into one row per team per match.
-- fct_match_result stores each match as a single row with both teams —
-- UNION ALL flattens it so every team appearance becomes its own row,
-- enabling aggregation at team grain regardless of home/away role.
WITH goals_per_match AS (

    SELECT
        home_team_sk    AS team_sk,
        season_sk,
        league_sk,
        home_goals      AS goals_scored
    FROM {{ ref('fct_match_result') }}

    UNION ALL

    SELECT
        away_team_sk    AS team_sk,
        season_sk,
        league_sk,
        away_goals      AS goals_scored
    FROM {{ ref('fct_match_result') }}

),

-- Aggregate to team + season + league grain and compute variance metrics.
-- STDDEV(): low value = predictable scoring output, high value = erratic.
-- HAVING COUNT(*) >= 10 ensures the standard deviation is computed over
-- a minimum statistically meaningful sample — seasons with fewer matches
-- (e.g. cup stages or incomplete data) are silently excluded.
team_consistency AS (

    SELECT
        team_sk,
        season_sk,
        league_sk,
        COUNT(*)                           AS matches_played,       -- Total matches in sample
        ROUND(AVG(goals_scored), 2)        AS avg_goals_per_match,  -- Mean goals per match
        ROUND(STDDEV(goals_scored), 2)     AS stddev_goals,         -- Scoring variance (key metric)
        MIN(goals_scored)                  AS min_goals_in_a_match, -- Best defensive performance
        MAX(goals_scored)                  AS max_goals_in_a_match  -- Best offensive performance
    FROM goals_per_match
    GROUP BY
        team_sk,
        season_sk,
        league_sk
    HAVING COUNT(*) >= 10

),

-- Enrich with dimension labels and add dual rankings scoped to league + season.
-- LEFT JOINs are used here — dimension keys are already validated upstream
-- in fct_match_result; NULLs at this stage would only affect display names,
-- not the consistency metrics themselves.
--   rank_most_consistent : 1 = lowest stddev (most regular scorer)
--   rank_most_erratic    : 1 = highest stddev (most unpredictable scorer)
ranked AS (

    SELECT
        tc.team_sk,
        tc.season_sk,
        tc.league_sk,
        t.team_long_name,
        l.league_name,
        s.season_name                                           AS season,
        tc.matches_played,
        tc.avg_goals_per_match,
        tc.min_goals_in_a_match,
        tc.max_goals_in_a_match,
        tc.stddev_goals,
        RANK() OVER (
            PARTITION BY tc.season_sk, tc.league_sk
            ORDER BY tc.stddev_goals ASC            -- lowest dispersion = most consistent
        )                                           AS rank_most_consistent,
        RANK() OVER (
            PARTITION BY tc.season_sk, tc.league_sk
            ORDER BY tc.stddev_goals DESC           -- highest dispersion = most erratic
        )                                           AS rank_most_erratic
    FROM team_consistency           tc
    LEFT JOIN {{ ref('dim_team') }}   t  ON tc.team_sk   = t.team_sk
    LEFT JOIN {{ ref('dim_league') }} l  ON tc.league_sk = l.league_sk
    LEFT JOIN {{ ref('dim_season') }} s  ON tc.season_sk = s.season_sk

)

-- Final output ordered by league → season → consistency rank.
-- Common downstream filters:
--   WHERE rank_most_consistent <= 3  →  top 3 most consistent teams per league + season
--   WHERE rank_most_erratic    <= 3  →  top 3 most erratic teams per league + season
SELECT
    league_name,
    season,
    team_long_name,
    matches_played,
    avg_goals_per_match,
    stddev_goals,
    min_goals_in_a_match,
    max_goals_in_a_match,
    rank_most_consistent,
    rank_most_erratic
FROM ranked
ORDER BY
    league_name           ASC,
    season                ASC,
    rank_most_consistent  ASC