-- Campus-level summary metrics
-- Answers: "How is each campus doing overall?"
-- Used by: Local Pastors, Network/CBE leadership

with campuses as (
    select * from {{ ref('dim_campus') }}
),

-- Headcount trends by campus (via check-in events linked to campuses)
headcounts as (
    select
        h.pco_headcount_id,
        h.total,
        h.created_at
    from {{ ref('fact_headcounts') }} h
),

headcount_summary as (
    select
        count(*) as total_headcount_records,
        sum(total) as total_headcount_sum,
        avg(total) as avg_headcount_per_record,
        min(created_at) as first_headcount_at,
        max(created_at) as last_headcount_at
    from headcounts
),

-- Check-in summary (network-wide for now; campus attribution requires event-campus mapping)
check_in_summary as (
    select
        count(*) as total_check_ins,
        count(distinct pco_person_id) as unique_people_checked_in,
        countif(is_one_time_guest = true) as one_time_guests,
        min(created_at) as first_check_in_at,
        max(created_at) as last_check_in_at
    from {{ ref('fact_check_ins') }}
),

-- ES groups by campus (site)
groups_by_site as (
    select
        loc.es_location_id,
        loc.location_name as campus_name,
        count(distinct g.es_group_id) as group_count
    from {{ ref('dim_group') }} g
    cross join unnest(split(g.sites, ',')) as site_id
    inner join {{ ref('stg_es_locations') }} loc
        on trim(site_id) = loc.es_location_id
    group by 1, 2
),

final as (
    select
        c.pco_campus_id,
        c.es_location_id,
        c.campus_name,
        c.city,
        c.state,
        c.phone_number,
        c.contact_email,
        c.website,
        c.time_zone,
        coalesce(gs.group_count, 0) as group_count
    from campuses c
    left join groups_by_site gs on c.es_location_id = gs.es_location_id
)

select * from final
