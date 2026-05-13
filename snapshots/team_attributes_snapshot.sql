{% snapshot team_attributes_snapshot %}

{{
    config(
        unique_key='team_api_id',
        strategy='timestamp',
        updated_at='date'
    )
}}

select
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
from {{ source('EUROPEAN_SOCCER_DATABASE', 'team_attributes') }}

{% endsnapshot %}