{{
    config(
        materialized         = 'incremental',
        unique_key           = 'match_id',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns'
    )
}}

-- Tabla principal del proyecto. Materializada como incremental (merge)
-- para simular la ingesta semanal de nuevos partidos.
-- Se descartan: columnas XML (goal, card, shoton...), cuotas de apuestas
-- y coordenadas de posición (x/y). Las columnas de alineación
-- (home_player_1..11) se gestionan en stg_match_lineup.

WITH source AS (
    SELECT * FROM {{ source('raw', 'match') }}
    WHERE home_team_api_id IS NOT NULL
      AND away_team_api_id IS NOT NULL

    {% if is_incremental() %}
        -- En cargas incrementales solo procesa partidos más recientes
        -- que el último match_date ya cargado en la tabla
        AND date::DATE > (SELECT MAX(match_date) FROM {{ this }})
    {% endif %}
),

renamed_casted AS (
    SELECT
        id               AS match_id,
        country_id       AS country_id,
        league_id        AS league_id,
        season           AS season_name,
        stage            AS stage,
        date::DATE       AS match_date,
        home_team_api_id AS home_team_id,
        away_team_api_id AS away_team_id,
        home_team_goal   AS home_goals,
        away_team_goal   AS away_goals
    FROM source
)

SELECT * FROM renamed_casted