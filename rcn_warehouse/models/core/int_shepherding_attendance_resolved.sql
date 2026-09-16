-- Attendance at the grain the business actually means: one row per person per
-- village gathering, regardless of how many times the form was submitted.
--
-- Two source quirks are resolved here:
--
--  1. Re-submissions. 19 of 152 village-dates have two or three submissions.
--     Per the agreed rule a person counts as present if ANY submission for that
--     village-date lists them. Taking only the latest submission would be wrong:
--     several follow-ups are partial re-entries that would zero out a gathering
--     (MOS-26-V06 on 2026-09-01 goes 38 attendees -> 1; MSL-26-V13 on 2026-09-09
--     goes 25 -> 0).
--
--  2. Superseded ids. Attendance logged before a name correction points at the
--     retired person_local_id, so ids are mapped forward before de-duplicating.
--
-- Every array_agg uses IGNORE NULLS and SAFE_OFFSET: BigQuery's ARRAY_AGG raises
-- "Array cannot have a null element" rather than skipping nulls.

with attendance as (
    select * from {{ ref('stg_shepherding_attendance_log') }}
),

submissions as (
    select * from {{ ref('stg_shepherding_submissions') }}
    where status = 'processed'
      and gathering_date is not null
),

roster as (
    select * from {{ ref('int_shepherding_roster_resolved') }}
),

joined as (
    select
        s.village_id,
        s.church_code,
        s.gathering_date,
        coalesce(r.current_person_local_id, a.person_local_id) as person_local_id,
        a.person_local_id as submitted_person_local_id,
        a.person_name_at_submission,
        a.submission_id,
        s.submitted_at
    from attendance a
    inner join submissions s
        on a.submission_id = s.submission_id
    left join roster r
        on a.person_local_id = r.person_local_id
    where a.attended_flag
),

-- One row per person per village-date. Where a person appears in more than one
-- submission for the same gathering, keep the earliest as the attribution and
-- carry the submission count for auditability.
deduplicated as (
    select
        village_id,
        church_code,
        gathering_date,
        person_local_id,
        count(distinct submission_id) as source_submission_count,
        min(submitted_at) as first_submitted_at,
        array_agg(submitted_person_local_id ignore nulls order by submitted_at limit 1)[safe_offset(0)] as submitted_person_local_id,
        array_agg(person_name_at_submission ignore nulls order by submitted_at desc limit 1)[safe_offset(0)] as person_name_at_submission,
        array_agg(submission_id ignore nulls order by submitted_at limit 1)[safe_offset(0)] as first_submission_id
    from joined
    group by 1, 2, 3, 4
)

select * from deduplicated
