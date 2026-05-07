{{
    config(
        materialized         = 'incremental',
        unique_key           = 'match_sk',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns'
    )
}}

-- Match results fact table. One record per match. Granularity: match.
-- Incremental (merge) to stay in sync with stg_raw__match updates.
-- Includes pre-calculated metrics: total_goals, goal_diff,
-- match_result (H/D/A) and points for both teams via macros.

WITH matches AS (
    SELECT * FROM {{ ref('stg_raw__match') }}

    {% if is_incremental() %}
        WHERE match_date > (SELECT MAX(match_date) FROM {{ this }})
    {% endif %}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

dim_team AS (
    SELECT * FROM {{ ref('dim_team') }}
),

dim_league AS (
    SELECT * FROM {{ ref('dim_league') }}
),

dim_season AS (
    SELECT * FROM {{ ref('dim_season') }}
),

joined AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['m.match_id']) }}   AS match_sk,
        m.match_id                                               AS match_id,
        d.date_id                                                AS date_id,
        ht.team_sk                                               AS home_team_sk,
        at.team_sk                                               AS away_team_sk,
        l.league_sk                                              AS league_sk,
        s.season_sk                                              AS season_sk,
        m.stage                                                  AS stage,
        m.match_date                                             AS match_date,
        m.home_goals                                             AS home_goals,
        m.away_goals                                             AS away_goals,
        m.home_goals + m.away_goals                              AS total_goals,
        m.home_goals - m.away_goals                              AS goal_diff,
        {{ get_match_result('m.home_goals', 'm.away_goals') }}   AS match_result,
        {{ get_points('m.home_goals', 'm.away_goals', 'home') }} AS home_points,
        {{ get_points('m.home_goals', 'm.away_goals', 'away') }} AS away_points
    FROM matches m
    INNER JOIN dim_date   d  ON TO_NUMBER(TO_CHAR(m.match_date, 'YYYYMMDD')) = d.date_id
    INNER JOIN dim_team   ht ON m.home_team_id = ht.team_api_id
    INNER JOIN dim_team   at ON m.away_team_id = at.team_api_id
    INNER JOIN dim_league l  ON m.league_id    = l.league_id
    INNER JOIN dim_season s  ON m.season_name  = s.season_name
)

SELECT * FROM joined