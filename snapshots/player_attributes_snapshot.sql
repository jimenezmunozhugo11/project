{% snapshot player_attributes_snapshot %}

{{
    config(
        unique_key='player_api_id || \'-\' || date',
        strategy='timestamp',
        updated_at='date'
    )
}}

select
    id,
    player_api_id,
    date,
    preferred_foot,
    attacking_work_rate,
    defensive_work_rate,
    crossing,
    finishing,
    heading_accuracy,
    short_passing,
    volleys,
    dribbling,
    curve,
    free_kick_accuracy,
    long_passing,
    ball_control,
    acceleration,
    sprint_speed,
    agility,
    reactions,
    balance,
    shot_power,
    jumping,
    stamina,
    strength,
    long_shots,
    aggression,
    interceptions,
    positioning,
    vision,
    penalties,
    marking,
    standing_tackle,
    sliding_tackle,
    gk_diving,
    gk_handling,
    gk_kicking,
    gk_positioning,
    gk_reflexes
from {{ source('EUROPEAN_SOCCER_DATABASE', 'player_attributes') }}

{% endsnapshot %}