-- Team season-over-season evolution. One record per team and season.
-- Granularity: team + season + league.
-- Uses LAG() to compute year-over-year deltas in points, goals and
-- league position. Only teams present in 2+ consecutive seasons are
-- meaningful — delta columns return NULL for a team's first season.
-- Sources: fct_team_season_stats, dim_team, dim_season, dim_league.

-- Enrich stats with readable names and a sortable season order
WITH base AS (

    SELECT
        fts.team_sk,
        fts.season_sk,
        fts.league_sk,
        t.team_long_name,
        l.league_name,
        s.season_name                                       AS season,
        s.start_year,                                       -- used for ORDER BY in window functions
        fts.matches_played,
        fts.points,
        fts.goals_for,
        fts.goals_against,
        fts.goal_difference,
        fts.wins,
        fts.draws,
        fts.losses
    FROM {{ ref('fct_team_season_stats') }}  fts
    LEFT JOIN {{ ref('dim_team') }}   t  ON fts.team_sk   = t.team_sk
    LEFT JOIN {{ ref('dim_league') }} l  ON fts.league_sk = l.league_sk
    LEFT JOIN {{ ref('dim_season') }} s  ON fts.season_sk = s.season_sk

),

-- Assign league position per season using points and goal difference as tiebreaker
-- Partition by league + season so each league has its own standings
with_position AS (

    SELECT
        *,
        RANK() OVER (
            PARTITION BY league_sk, season_sk
            ORDER BY points DESC, goal_difference DESC      -- standard league tiebreaker
        )                                                   AS league_position
    FROM base

),

-- Compute season-over-season deltas using LAG()
-- LAG looks back 1 season within the same team + league window
-- NULL on the first season a team appears — expected behaviour
with_deltas AS (

    SELECT
        team_long_name,
        league_name,
        season,
        matches_played,
        points,
        goals_for,
        goals_against,
        goal_difference,
        wins,
        draws,
        losses,
        league_position,

        -- Points delta vs previous season (positive = improvement)
        points - LAG(points) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS points_delta,

        -- Goals scored delta vs previous season
        goals_for - LAG(goals_for) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS goals_for_delta,

        -- Goals conceded delta vs previous season (negative = improvement)
        goals_against - LAG(goals_against) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS goals_against_delta,

        -- Position delta vs previous season (negative = moved up the table)
        league_position - LAG(league_position) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS position_delta

    FROM with_position

)

-- Final output ordered by team, league and season
-- To analyse a specific team, add: WHERE team_long_name = 'FC Barcelona'
-- position_delta < 0 means the team climbed the table vs prior season
SELECT
    league_name,
    team_long_name,
    season,
    matches_played,
    points,
    points_delta,
    goals_for,
    goals_for_delta,
    goals_against,
    goals_against_delta,
    goal_difference,
    wins,
    draws,
    losses,
    league_position,
    position_delta
FROM with_deltas
WHERE team_long_name = 'FC Barcelona'
ORDER BY
    league_name     ASC,
    team_long_name  ASC,
    season          ASC