-- Person-level engagement inside a village.
-- Answers: "How are my 12 people engaging? Who is drifting?"
-- Used by: Village Leaders, Village Coaches
--
-- One row per current village member. Attendance is measured only against the
-- gatherings that member was eligible for, so someone who joined in week six is
-- not penalised for the first five weeks.

with attendance as (
    select * from {{ ref('fact_village_attendance') }}
),

members as (
    select * from {{ ref('dim_village_member') }}
    where is_current
),

-- Consecutive misses counted back from the member's most recent gathering
ranked as (
    select
        person_local_id,
        gathering_date,
        attended_flag,
        row_number() over (
            partition by person_local_id order by gathering_date desc
        ) as recency_rank
    from attendance
),

streaks as (
    select
        person_local_id,
        -- Rank 1 is the most recent gathering. The rank of the last gathering
        -- they attended, minus one, is how many they have missed since. Never
        -- attended -> every eligible gathering is a miss.
        coalesce(
            min(case when attended_flag then recency_rank end) - 1,
            count(*)
        ) as consecutive_misses
    from ranked
    group by 1
),

aggregated as (
    select
        a.person_local_id,
        a.village_id,
        count(*) as gatherings_eligible,
        countif(a.attended_flag) as gatherings_attended,
        countif(not a.attended_flag) as gatherings_missed,
        safe_divide(countif(a.attended_flag), nullif(count(*), 0)) as attendance_rate,
        min(a.gathering_date) as first_eligible_gathering_date,
        max(a.gathering_date) as last_eligible_gathering_date,
        max(case when a.attended_flag then a.gathering_date end) as last_attended_date,

        -- Recent form: last four gatherings they were eligible for
        countif(a.attended_flag and a.gathering_date >= date_sub(current_date('America/Los_Angeles'), interval 28 day)) as attended_last_28_days,
        countif(a.gathering_date >= date_sub(current_date('America/Los_Angeles'), interval 28 day)) as eligible_last_28_days
    from attendance a
    group by 1, 2
),

final as (
    select
        m.person_local_id,
        m.village_id,
        m.village_name,
        m.church_code,
        m.church_name,
        m.academic_year,
        m.pco_campus_id,

        m.display_name,
        m.name_completeness,
        m.has_full_name,

        m.membership_start_date,
        m.membership_end_date,
        m.is_retired,

        coalesce(agg.gatherings_eligible, 0) as gatherings_eligible,
        coalesce(agg.gatherings_attended, 0) as gatherings_attended,
        coalesce(agg.gatherings_missed, 0) as gatherings_missed,
        agg.attendance_rate,
        safe_divide(agg.attended_last_28_days, nullif(agg.eligible_last_28_days, 0)) as attendance_rate_last_28_days,

        agg.first_eligible_gathering_date,
        agg.last_eligible_gathering_date,
        agg.last_attended_date,
        date_diff(current_date('America/Los_Angeles'), agg.last_attended_date, day) as days_since_last_attended,
        coalesce(s.consecutive_misses, 0) as consecutive_misses,

        -- Shepherding signal. Thresholds are deliberately simple and should be
        -- tuned with the team before anything is escalated off them.
        case
            when m.is_retired then 'retired'
            when agg.gatherings_eligible is null or agg.gatherings_eligible = 0 then 'no_data'
            when coalesce(s.consecutive_misses, 0) >= 3 then 'drifting'
            when coalesce(s.consecutive_misses, 0) = 2 then 'watch'
            else 'engaged'
        end as engagement_status,

        -- Best-effort link into the wider warehouse; see dim_village_member
        m.pco_person_id,
        m.pco_match_confidence
    from members m
    left join aggregated agg
        on m.person_local_id = agg.person_local_id
    left join streaks s
        on m.person_local_id = s.person_local_id
)

select * from final
