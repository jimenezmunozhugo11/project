-- ============================================================================
-- get_match_result — Returns H / D / A from home and away goals
-- ============================================================================
-- Usage:
--   {{ get_match_result('home_goals', 'away_goals') }}
--
-- Returns:
--   'H' — home win
--   'D' — draw
--   'A' — away win
-- ============================================================================

{% macro get_match_result(home_goals, away_goals) %}
    CASE
        WHEN {{ home_goals }} > {{ away_goals }} THEN 'H'
        WHEN {{ home_goals }} < {{ away_goals }} THEN 'A'
        ELSE 'D'
    END
{% endmacro %}