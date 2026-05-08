{{ config(materialized='table') }}

-- Season dimension. One record per season.
-- Built directly from stg_raw__season with a surrogate key.

WITH seasons AS (
    SELECT * FROM {{ ref('stg_raw__season') }}
),

renamed_casted AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['season_id']) }}   AS season_sk,
        season_id                                               AS season_id,
        season_name                                             AS season_name,
        start_year                                              AS start_year,
        end_year                                                AS end_year
    FROM seasons
)

SELECT * FROM renamed_casted