-- ============================================================================
-- assert_points_match_result
-- ============================================================================
-- Ensures home_points + away_points always equals 3 (win) or 2 (draw).
-- A draw gives 1+1=2, a win gives 3+0=3. Any other total is invalid.
-- Returns rows that fail the assertion (should return 0 rows).
-- ============================================================================

SELECT
    match_id,
    match_result,
    home_points,
    away_points,
    home_points + away_points AS total_points
FROM {{ ref('fct_match_result') }}
WHERE home_points + away_points NOT IN (2, 3)