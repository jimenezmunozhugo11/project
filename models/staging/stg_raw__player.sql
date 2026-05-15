{{ config(materialized='view') }}

-- ============================================================================
-- stg_raw__player
-- ============================================================================
-- Player biographical data. One record per player.
-- Renames, casts and derives biographical attributes from the source.
-- Play style attributes (preferred_foot, work rates) are stored separately
-- in stg_raw__player_attributes. FIFA ratings are excluded from this project.
--
-- Grain      : one row per player
-- Loaded as  : view (source is static — no storage cost justified)
-- Sources    : EUROPEAN_SOCCER_DATABASE.player
-- Filters    : records with NULL player_name are excluded
-- Dropped    : player_fifa_api_id (out of project scope)
-- ============================================================================

WITH source AS (

    -- Source: raw player table from the bronze layer.
    SELECT * FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'player') }}

),

renamed_casted AS (

    -- Rename, cast and derive all player attributes.
    -- birthday   : cast from string to DATE, then reformatted as 'DD-MM-YYYY'
    --              for display consistency across the project.
    -- age        : derived at query time via DATEDIFF — reflects the player's
    --              current age, not their age at a specific season. Accepted
    --              simplification given the project scope.
    -- height_cm  : source stores height as a float — ROUND + INT cast removes
    --              the decimal without changing the unit (already in cm).
    -- weight_kg  : source stores weight in pounds (Anglo-Saxon origin) —
    --              converted to kilograms by multiplying by 0.453592, then
    --              rounded to the nearest integer.
    -- Post-filter: players with NULL player_name are excluded — they cannot
    --              be meaningfully identified in any downstream model.
    SELECT
        id                                                        AS player_id,      -- Internal surrogate PK (not used as join key)
        player_api_id                                             AS player_api_id,  -- Main player identifier — FK join key downstream
        player_name                                               AS player_name,    -- Full player name
        TO_VARCHAR(birthday::DATE, 'DD-MM-YYYY')                  AS birthday,       -- Date of birth formatted as DD-MM-YYYY
        DATEDIFF('year', birthday::DATE, CURRENT_DATE())          AS age,            -- Current age in full years
        ROUND(height)::INT                                        AS height_cm,      -- Height in centimetres (float → integer)
        ROUND(weight * 0.453592)::INT                             AS weight_kg       -- Weight in kilograms (converted from pounds)
        -- player_fifa_api_id: dropped — FIFA IDs are out of project scope
    FROM source
    WHERE player_name IS NOT NULL

)

SELECT * FROM renamed_casted