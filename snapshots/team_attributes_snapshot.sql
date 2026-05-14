{% snapshot team_attributes_snapshot %}

{{
    config(
        unique_key='team_api_id',
        strategy='timestamp',
        updated_at='date'
    )
}}

-- Deduplicate source rows before snapshotting.
-- The source table contains multiple rows per team_api_id (one per date).
-- QUALIFY keeps only the most recent record per team to satisfy the
-- unique_key constraint required by the merge strategy.
WITH deduplicated AS (
    SELECT
        id,
        team_fifa_api_id,
        team_api_id,
        date,
        buildupplayspeed,
        buildupplayspeedclass,
        buildupplaydribbling,
        buildupplaydribblingclass,
        buildupplaypassing,
        buildupplaypassingclass,
        buildupplaypositioningclass,
        chancecreationpassing,
        chancecreationpassingclass,
        chancecreationcrossing,
        chancecreationcrossingclass,
        chancecreationshooting,
        chancecreationshootingclass,
        chancecreationpositioningclass,
        defencepressure,
        defencepressureclass,
        defenceaggression,
        defenceaggressionclass,
        defenceteamwidth,
        defenceteamwidthclass,
        defencedefenderlineclass
    FROM {{ source('EUROPEAN_SOCCER_DATABASE', 'team_attributes') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY team_api_id
        ORDER BY date DESC          -- most recent attributes win
    ) = 1
)

SELECT * FROM deduplicated

{% endsnapshot %}