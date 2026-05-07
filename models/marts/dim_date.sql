{{ config(materialized='table') }}

-- Date dimension covering the full dataset range (2008-2016).
-- Generated entirely in dbt using Snowflake GENERATOR —
-- no seed or external source needed.

WITH date_spine AS (
    SELECT
        DATEADD(day, SEQ4(), '2008-01-01'::DATE) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 3288))
    WHERE full_date <= '2016-12-31'::DATE
),

renamed_casted AS (
    SELECT
        TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD'))   AS date_id,
        full_date                                    AS full_date,
        DAY(full_date)                               AS day,
        MONTH(full_date)                             AS month,
        MONTHNAME(full_date)                         AS month_name,
        QUARTER(full_date)                           AS quarter,
        YEAR(full_date)                              AS year,
        DAYNAME(full_date)                           AS day_name,
        IFF(DAYOFWEEK(full_date) IN (0, 6),
            TRUE, FALSE)                             AS is_weekend
    FROM date_spine
)

SELECT * FROM renamed_casted