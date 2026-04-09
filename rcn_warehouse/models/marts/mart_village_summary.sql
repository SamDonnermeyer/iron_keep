-- Village/group-level summary
-- Answers: "Which villages need attention? How is each village doing?"
-- Used by: Village Coaches, Local Pastors

with es_groups as (
    select * from {{ ref('dim_group') }}
),

-- Get campus name from first site ID
group_campus as (
    select
        g.es_group_id,
        loc.location_name as primary_campus
    from es_groups g
    cross join unnest(split(g.sites, ',')) as site_id with offset as pos
    inner join {{ ref('stg_es_locations') }} loc
        on trim(site_id) = loc.es_location_id
    where pos = 0
),

-- Count members per group from ES users
group_members as (
    select
        g.es_group_id,
        count(distinct u.es_user_id) as member_count
    from es_groups g
    inner join {{ ref('stg_es_users') }} u
        on u.current_groups like concat('%', g.group_name, '%')
    group by 1
),

final as (
    select
        g.es_group_id,
        g.group_name,
        g.group_type,
        g.group_tags,
        g.leader,
        g.leader_in_training,
        g.weekday,
        g.meeting_time,
        gc.primary_campus,
        coalesce(gm.member_count, 0) as member_count,
        g.visibility,
        g.created,
        g.last_updated
    from es_groups g
    left join group_campus gc on g.es_group_id = gc.es_group_id
    left join group_members gm on g.es_group_id = gm.es_group_id
)

select * from final
