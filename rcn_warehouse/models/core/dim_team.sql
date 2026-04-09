-- Teams dimension from Engage Spaces

with teams as (
    select
        es_team_id,
        team_name,
        team_type_name,
        team_type,
        team_tags,
        description,
        leader,
        weekday,
        sites,
        parent_team,
        visibility,
        disabled,
        created,
        last_updated
    from {{ ref('stg_es_teams') }}
)

select * from teams
