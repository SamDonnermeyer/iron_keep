-- Weekly attendance trends from PCO headcounts
-- Answers: "What are our attendance trends over time?"
-- Used by: Local Pastors, Network/CBE leadership

with headcounts as (
    select
        pco_headcount_id,
        total,
        created_at
    from {{ ref('fact_headcounts') }}
    where total > 0
),

weekly as (
    select
        date_trunc(date(created_at), week(monday)) as week_start,
        count(*) as headcount_records,
        sum(total) as total_attendance,
        avg(total) as avg_per_record,
        max(total) as max_single_count,
        min(date(created_at)) as first_date,
        max(date(created_at)) as last_date
    from headcounts
    group by 1
),

-- Check-in trends (individual people)
check_in_weekly as (
    select
        date_trunc(date(created_at), week(monday)) as week_start,
        count(*) as total_check_ins,
        count(distinct pco_person_id) as unique_people,
        countif(kind = 'Regular') as regular_check_ins,
        countif(kind = 'Volunteer') as volunteer_check_ins,
        countif(is_one_time_guest = true) as one_time_guests
    from {{ ref('fact_check_ins') }}
    group by 1
),

final as (
    select
        coalesce(h.week_start, ci.week_start) as week_start,
        h.total_attendance,
        h.avg_per_record as avg_headcount,
        h.headcount_records,
        ci.total_check_ins,
        ci.unique_people as unique_check_in_people,
        ci.regular_check_ins,
        ci.volunteer_check_ins,
        ci.one_time_guests
    from weekly h
    full outer join check_in_weekly ci on h.week_start = ci.week_start
)

select * from final
order by week_start
