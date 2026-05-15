-- ============================================================================
-- assert_points_match_result
-- ============================================================================
-- Ensures the sum of home_points + away_points is always 2 (draw) or 3 (win)
-- for every match. Any other total indicates a macro logic error in
-- get_points() or an unexpected match_result value in get_match_result().
--
-- Valid states:
--   Home win  : home_points = 3, away_points = 0  → total = 3
--   Away win  : home_points = 0, away_points = 3  → total = 3
--   Draw      : home_points = 1, away_points = 1  → total = 2
--
-- Type       : singular test (dbt assertion)
-- Model      : fct_match_result
-- Passes if  : 0 rows returned
-- Fails if   : 1 or more rows returned
-- Severity   : error — invalid points would corrupt all season-level aggregations
--              in fct_team_season_stats (points, win_rate) and downstream
--              analyses (uc6_team_evolution points_delta, league_position)
-- ============================================================================

SELECT
    match_id,
    match_result,
    home_points,
    away_points,
    home_points + away_points AS total_points
FROM {{ ref('fct_match_result') }}
WHERE home_points + away_points NOT IN (2, 3)
   OR home_points IS NULL
   OR away_points IS NULL