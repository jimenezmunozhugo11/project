{{ config(materialized='table') }}

-- Team dimension enriched with tactical attributes.
-- One record per team, using the most recent tactical snapshot available
-- across all seasons (latest season_id in stg_raw__team_attributes).
-- Built from stg_raw__team joined with stg_raw__team_attributes.

WITH teams AS (
    SELECT * FROM {{ ref('stg_raw__team') }}
),

team_attributes AS (
    SELECT * FROM {{ ref('stg_raw__team_attributes') }}
),

-- Keep only the most recent attributes snapshot per team across all seasons
latest_attributes AS (
    SELECT *
    FROM team_attributes
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY team_api_id
        ORDER BY season_id DESC
    ) = 1
),

renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['t.team_api_id']) }}   AS team_sk,
        t.team_api_id                                               AS team_api_id,
        t.team_long_name                                            AS team_long_name,
        t.team_short_name                                           AS team_short_name,
        ta.buildup_play_speed                                       AS buildup_play_speed,
        ta.buildup_play_speed_class                                 AS buildup_play_speed_class,
        ta.buildup_play_passing                                     AS buildup_play_passing,
        ta.buildup_play_passing_class                               AS buildup_play_passing_class,
        ta.chance_creation_passing                                  AS chance_creation_passing,
        ta.chance_creation_passing_class                            AS chance_creation_passing_class,
        ta.chance_creation_shooting                                 AS chance_creation_shooting,
        ta.chance_creation_shooting_class                           AS chance_creation_shooting_class,
        ta.defence_pressure                                         AS defence_pressure,
        ta.defence_pressure_class                                   AS defence_pressure_class,
        ta.defence_aggression                                       AS defence_aggression,
        ta.defence_aggression_class                                 AS defence_aggression_class,
        ta.defence_team_width                                       AS defence_team_width,
        ta.defence_defender_line_class                              AS defence_defender_line_class
    FROM teams t
    LEFT JOIN latest_attributes ta ON t.team_api_id = ta.team_api_id
)

SELECT * FROM renamed_casted