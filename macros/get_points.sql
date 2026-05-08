-- ============================================================================
-- get_points — Returns points earned by a team based on match result
-- ============================================================================
-- Usage:
--   {{ get_points('home_goals', 'away_goals', 'home') }}
--   {{ get_points('home_goals', 'away_goals', 'away') }}
--
-- Returns:
--   3 — win
--   1 — draw
--   0 — loss
-- ============================================================================

{% macro get_points(home_goals, away_goals, side) %}
    CASE
        {% if side == 'home' %}
            WHEN {{ home_goals }} > {{ away_goals }} THEN 3
            WHEN {{ home_goals }} = {{ away_goals }} THEN 1
            ELSE 0
        {% elif side == 'away' %}
            WHEN {{ away_goals }} > {{ home_goals }} THEN 3
            WHEN {{ home_goals }} = {{ away_goals }} THEN 1
            ELSE 0
        {% endif %}
    END
{% endmacro %}