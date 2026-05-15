-- ============================================================================
-- fct_team_evolution
-- ============================================================================
-- Team season-over-season evolution fact table.
-- One record per team per season per league.
-- Uses LAG() to compute year-over-year deltas in points, goals scored,
-- goals conceded and league position — all scoped to the same team + league
-- to avoid cross-league comparisons when a team plays in multiple competitions.
--
-- Grain        : one row per team + season + league
-- Sources      : fct_team_season_stats, dim_team, dim_league, dim_season
-- Window funcs : RANK() for league position, LAG() for all delta columns
-- NULL deltas  : expected and valid for a team's first season in the dataset —
--                no prior season exists to compare against
-- Note         : the final SELECT includes a hardcoded WHERE clause for
--                development/exploration — remove or parameterise for production
-- ============================================================================

-- Enrich team season stats with readable dimension labels.
-- start_year is carried through exclusively to drive ORDER BY
-- in the LAG() window functions defined in with_deltas.
-- LEFT JOINs are intentional — FK integrity is guaranteed upstream
-- in fct_team_season_stats; NULLs here would only affect display names.
WITH base AS (

    SELECT
        fts.team_sk,
        fts.season_sk,
        fts.league_sk,
        t.team_long_name,
        l.league_name,
        s.season_name                                       AS season,
        s.start_year,                                       -- used for ORDER BY in window functions only
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

-- Assign final league position per team within each league + season.
-- RANK() is used instead of ROW_NUMBER() to handle tied teams correctly —
-- two teams level on points and goal difference share the same position.
-- Tiebreaker follows standard league rules: points DESC, goal_difference DESC.
with_position AS (

    SELECT
        *,
        RANK() OVER (
            PARTITION BY league_sk, season_sk
            ORDER BY points DESC, goal_difference DESC      -- standard league tiebreaker
        )                                                   AS league_position
    FROM base

),

-- Compute season-over-season deltas for the four key performance indicators.
-- All LAG() calls use the same PARTITION BY (team + league) and ORDER BY (start_year)
-- to ensure comparisons are made within the same team's history in the same league.
-- A team relegated and then promoted would produce a NULL delta on return —
-- this is correct behaviour, not a data issue.
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

        -- Positive = more points than previous season (improvement)
        -- Negative = fewer points (decline) — NULL on first season
        points - LAG(points) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS points_delta,

        -- Positive = more goals scored (improvement) — NULL on first season
        goals_for - LAG(goals_for) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS goals_for_delta,

        -- Negative = fewer goals conceded (defensive improvement) — NULL on first season
        goals_against - LAG(goals_against) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS goals_against_delta,

        -- Negative = climbed the table (improvement)
        -- Positive = dropped down the table (decline) — NULL on first season
        league_position - LAG(league_position) OVER (
            PARTITION BY team_sk, league_sk
            ORDER BY start_year
        )                                                   AS position_delta

    FROM with_position

)

-- Final output ordered by league → team → season for chronological reading.
-- Common downstream filters:
--   WHERE team_long_name = 'FC Barcelona'  →  single team deep-dive
--   WHERE points_delta   < 0               →  teams that regressed
--   WHERE position_delta < 0               →  teams that climbed the table
--   WHERE position_delta = 1               →  teams that finished 1st (champions)
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