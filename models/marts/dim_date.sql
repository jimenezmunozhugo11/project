{{ config(materialized='table') }}

-- ============================================================================
-- dim_date
-- ============================================================================
-- Date dimension covering the full dataset range (2008–2016).
-- Generated entirely in dbt using Snowflake's GENERATOR function —
-- no seed file or external source required.
--
-- Grain      : one row per calendar day
-- Row count  : 3,288 days (2008-01-01 → 2016-12-31)
-- Loaded as  : table (full refresh on every dbt run)
-- ============================================================================

WITH date_spine AS (

    -- Generate one row per day starting from 2008-01-01.
    -- SEQ4() produces a sequential integer (0, 1, 2 …) that is added
    -- as days to the anchor date via DATEADD.
    -- The WHERE clause ensures the spine stops at 2016-12-31.
    SELECT
        DATEADD(day, SEQ4(), '2008-01-01'::DATE) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 3288))
    WHERE full_date <= '2016-12-31'::DATE

),

renamed_casted AS (

    -- Cast and derive all date attributes from the raw full_date.
    -- date_id is stored as an integer in YYYYMMDD format (e.g. 20150831)
    -- to serve as a compact, join-friendly surrogate key.
    SELECT
        TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD'))   AS date_id,     -- PK: YYYYMMDD integer
        full_date                                    AS full_date,   -- Full calendar date
        DAY(full_date)                               AS day,         -- Day of month (1–31)
        MONTH(full_date)                             AS month,       -- Month number (1–12)
        MONTHNAME(full_date)                         AS month_name,  -- Month name (e.g. January)
        QUARTER(full_date)                           AS quarter,     -- Quarter (1–4)
        YEAR(full_date)                              AS year,        -- Four-digit year
        DAYNAME(full_date)                           AS day_name,    -- Day name (e.g. Monday)
        IFF(DAYOFWEEK(full_date) IN (0, 6),
            TRUE, FALSE)                             AS is_weekend   -- TRUE = Saturday or Sunday
    FROM date_spine

)

SELECT * FROM renamed_casted