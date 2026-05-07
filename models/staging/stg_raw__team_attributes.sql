{{ config(materialized='view') }}

-- Column names in RAW are all lowercase without underscores
-- (buildupplayspeed, defencepressure...) as loaded by Snowflake.
-- Here they are renamed to snake_case and a seasonal snapshot is applied.

WITH source AS (
    SELECT * FROM {{ source('raw', 'team_attributes') }}
),

joined_season AS (
    SELECT
        s.id                            AS team_attr_id,
        s.team_api_id                   AS team_api_id,
        ss.season_id                    AS season_id,
        s.date::DATE                    AS attr_date,
        s.buildupplayspeed              AS buildup_play_speed,
        s.buildupplayspeedclass         AS buildup_play_speed_class,
        s.buildupplaypassing            AS buildup_play_passing,
        s.buildupplaypassingclass       AS buildup_play_passing_class,
        s.chancecreationpassing         AS chance_creation_passing,
        s.chancecreationpassingclass    AS chance_creation_passing_class,
        s.chancecreationshooting        AS chance_creation_shooting,
        s.chancecreationshootingclass   AS chance_creation_shooting_class,
        s.defencepressure               AS defence_pressure,
        s.defencepressureclass          AS defence_pressure_class,
        s.defenceaggression             AS defence_aggression,
        s.defenceaggressionclass        AS defence_aggression_class,
        s.defenceteamwidth              AS defence_team_width,
        s.defencedefenderlineclass      AS defence_defender_line_class,
        ROW_NUMBER() OVER (
            PARTITION BY s.team_api_id, ss.season_id
            ORDER BY s.date DESC
        )                               AS rn
        -- team_fifa_api_id, buildupplaydribbling and chancecreationcrossing dropped
    FROM source s
    INNER JOIN {{ ref('stg_raw__season') }} ss
        ON YEAR(s.date::DATE) = ss.start_year
),

renamed_casted AS (
    SELECT
        team_attr_id,
        team_api_id,
        season_id,
        buildup_play_speed,
        buildup_play_speed_class,
        buildup_play_passing,
        buildup_play_passing_class,
        chance_creation_passing,
        chance_creation_passing_class,
        chance_creation_shooting,
        chance_creation_shooting_class,
        defence_pressure,
        defence_pressure_class,
        defence_aggression,
        defence_aggression_class,
        defence_team_width,
        defence_defender_line_class
    FROM joined_season
    WHERE rn = 1   -- snapshot: most recent record per team and season
)

SELECT * FROM renamed_casted