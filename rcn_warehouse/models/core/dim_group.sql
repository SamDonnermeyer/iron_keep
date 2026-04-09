-- Groups/villages dimension from Engage Spaces

with es_groups as (
    select
        es_group_id,
        group_name,
        group_type,
        group_tags,
        description,
        leader,
        leader_in_training,
        weekday,
        meeting_time,
        sites,
        parent_group,
        leadership_groups,
        visibility,
        disable_registrations,
        created,
        last_updated
    from {{ ref('stg_es_groups') }}
)

select * from es_groups
