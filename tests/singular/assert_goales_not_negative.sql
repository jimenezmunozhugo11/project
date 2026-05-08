-- ============================================================================
-- assert_goals_not_negative
-- ============================================================================
-- Ensures no match has negative goals in either home or away columns.
-- Returns rows that fail the assertion (should return 0 rows).
-- ============================================================================

SELECT
    match_id,
    home_goals,
    away_goals
FROM {{ ref('stg_raw__match') }}
WHERE home_goals < 0
   OR away_goals < 0