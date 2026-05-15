-- ============================================================================
-- assert_goals_not_negative
-- ============================================================================
-- Ensures no match record contains negative goal values in either
-- home_goals or away_goals. Negative goals are physically impossible
-- and would indicate a casting or ingestion error in the bronze layer.
--
-- Type       : singular test (dbt assertion)
-- Model      : stg_raw__match
-- Passes if  : 0 rows returned
-- Fails if   : 1 or more rows returned
-- Severity   : error — negative goals would corrupt all downstream metrics
--              (total_goals, goal_diff, points, win_rate, goal_difference)
-- ============================================================================

SELECT
    match_id,
    home_goals,
    away_goals
FROM {{ ref('stg_raw__match') }}
WHERE home_goals < 0
   OR away_goals < 0