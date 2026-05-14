-- Team consistency analysis. One record per team and season.
-- Granularity: team + season + league.
-- Measures goal-scoring variance using STDDEV to classify teams
-- as consistent (low std dev) or erratic (high std dev).
-- Source: fct_match_result unpivoted into one row per team per match.

-- Unpivot home and away into one row per team per match
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

-- Aggregate to team + season + league grain
-- STDDEV: low value = predictable scorer, high value = erratic scorer
-- HAVING >= 10 ensures a statistically reliable sample size
team_consistency AS (

    SELECT
        team_sk,
        season_sk,
        league_sk,
        COUNT(*)                           AS matches_played,
        ROUND(AVG(goals_scored), 2)        AS avg_goals_per_match,
        ROUND(STDDEV(goals_scored), 2)     AS stddev_goals,
        MIN(goals_scored)                  AS min_goals_in_a_match,
        MAX(goals_scored)                  AS max_goals_in_a_match
    FROM goals_per_match
    GROUP BY
        team_sk,
        season_sk,
        league_sk
    HAVING COUNT(*) >= 10

),

-- Enrich with dimension names and add dual rankings per league + season
-- rank_most_consistent: 1 = lowest std dev (most regular)
-- rank_most_erratic:    1 = highest std dev (most unpredictable)
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
    FROM team_consistency tc
    LEFT JOIN {{ ref('dim_team') }}   t  ON tc.team_sk   = t.team_sk
    LEFT JOIN {{ ref('dim_league') }} l  ON tc.league_sk = l.league_sk
    LEFT JOIN {{ ref('dim_season') }} s  ON tc.season_sk = s.season_sk

)

-- Final output ordered by league, season, consistency rank
-- To filter top 3 most consistent: WHERE rank_most_consistent <= 3
-- To filter top 3 most erratic:    WHERE rank_most_erratic    <= 3
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