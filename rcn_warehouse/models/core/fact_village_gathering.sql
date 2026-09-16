-- One row per village per gathering date — the grain leaders and coaches mean
-- when they say "a village meeting".
--
-- Re-submissions are collapsed here (see int_shepherding_attendance_resolved
-- for the union rule), so attendee_count is the count of DISTINCT people across
-- every submission for that village-date, not the headcount off any one form.

with gatherings as (
    select
        village_id,
        church_code,
        gathering_date,
        count(distinct person_local_id) as attendee_count,
        min(first_submitted_at) as first_submitted_at
    from {{ ref('int_shepherding_attendance_resolved') }}
    group by 1, 2, 3
),

-- Submission-level attributes, and the village-dates that produced a form but
-- no attendee rows at all (a leader submitting an empty gathering). Those must
-- survive: a meeting with zero recorded attendees is a signal, not a non-event.
submissions as (
    select
        village_id,
        church_code,
        gathering_date,
        count(*) as submission_count,
        countif(gathering_type = 'Other Gathering') > 0 as includes_other_gathering,
        sum(guest_count) as guest_count,
        max(reported_attendee_count) as max_reported_attendee_count,
        min(submitted_at) as first_submitted_at,
        max(submitted_at) as last_submitted_at,
        array_agg(gathering_type ignore nulls order by submitted_at desc limit 1)[safe_offset(0)] as gathering_type,
        array_agg(nullif(activity_label, '') ignore nulls order by submitted_at desc limit 1)[safe_offset(0)] as activity_label,
        array_agg(submitted_by ignore nulls order by submitted_at desc limit 1)[safe_offset(0)] as last_submitted_by
    from {{ ref('stg_shepherding_submissions') }}
    where status = 'processed'
      and gathering_date is not null
    group by 1, 2, 3
),

-- Denominator: members whose membership window covers this gathering date.
eligible as (
    select
        s.village_id,
        s.gathering_date,
        count(*) as eligible_member_count
    from submissions s
    inner join {{ ref('int_shepherding_membership_window') }} w
        on s.village_id = w.village_id
        and w.membership_start_date <= s.gathering_date
        and (w.membership_end_date is null or w.membership_end_date >= s.gathering_date)
    group by 1, 2
),

villages as (
    select
        village_id,
        church_name,
        church_sk,
        village_name,
        leader_names,
        academic_year,
        pco_campus_id,
        campus_name,
        village_status
    from {{ ref('dim_village') }}
),

final as (
    select
        -- Surrogate key at the reporting grain
        to_hex(md5(concat(s.village_id, '|', format_date('%F', s.gathering_date)))) as village_gathering_sk,

        s.village_id,
        s.church_code,
        v.church_sk,
        v.church_name,
        v.village_name,
        v.leader_names,
        v.academic_year,
        v.pco_campus_id,
        v.campus_name,
        v.village_status,

        s.gathering_date,
        extract(isoyear from s.gathering_date) as gathering_iso_year,
        extract(isoweek from s.gathering_date) as gathering_iso_week,
        date_trunc(s.gathering_date, week(monday)) as gathering_week_start_date,
        s.gathering_type,
        s.activity_label,

        coalesce(g.attendee_count, 0) as attendee_count,
        coalesce(e.eligible_member_count, 0) as eligible_member_count,
        coalesce(e.eligible_member_count, 0) - coalesce(g.attendee_count, 0) as absent_count,
        safe_divide(coalesce(g.attendee_count, 0), nullif(e.eligible_member_count, 0)) as attendance_rate,
        s.guest_count,

        -- Audit: the largest headcount any single form reported for this
        -- village-date, against the de-duplicated union actually counted.
        s.max_reported_attendee_count,
        s.submission_count,
        s.submission_count > 1 as is_resubmitted,
        s.first_submitted_at,
        s.last_submitted_at,
        s.last_submitted_by
    from submissions s
    left join gatherings g
        on s.village_id = g.village_id
        and s.gathering_date = g.gathering_date
    left join eligible e
        on s.village_id = e.village_id
        and s.gathering_date = e.gathering_date
    left join villages v
        on s.village_id = v.village_id
)

select * from final
