-- Audit fact: one row per form submission, exactly as the leader sent it.
--
-- Reporting should use fact_village_gathering (one row per village per date)
-- and fact_village_attendance (one row per person per gathering). This model
-- exists so a questioned number can be traced back to who submitted what and
-- when, and so re-submissions stay visible instead of being silently merged.

with submissions as (
    select * from {{ ref('stg_shepherding_submissions') }}
),

attendance as (
    select
        submission_id,
        count(*) as logged_attendee_count
    from {{ ref('stg_shepherding_attendance_log') }}
    where attended_flag
    group by 1
),

villages as (
    select
        village_id,
        church_name,
        village_name,
        academic_year,
        pco_campus_id
    from {{ ref('dim_village') }}
),

sequenced as (
    select
        s.*,
        row_number() over (
            partition by s.village_id, s.gathering_date
            order by s.submitted_at, s.submission_id
        ) as submission_seq,
        count(*) over (
            partition by s.village_id, s.gathering_date
        ) as submissions_for_gathering
    from submissions s
),

final as (
    select
        q.submission_id,
        q.village_id,
        q.church_code,
        v.church_name,
        v.village_name,
        v.academic_year,
        v.pco_campus_id,

        q.gathering_date,
        q.gathering_type,
        q.activity_label,

        q.reported_attendee_count,
        coalesce(a.logged_attendee_count, 0) as logged_attendee_count,
        -- Flags a form response whose headcount disagrees with its own detail
        -- rows. Currently clean across the source, so a hit here means the
        -- Apps Script dropped rows on a sweep.
        coalesce(q.reported_attendee_count, 0) != coalesce(a.logged_attendee_count, 0) as has_count_mismatch,
        q.guest_count,

        q.submitted_by,
        q.submitted_at,
        q.processed_at,
        q.status,

        -- Re-submission context
        q.submission_seq,
        q.submissions_for_gathering,
        q.submissions_for_gathering > 1 as is_resubmission
    from sequenced q
    left join attendance a
        on q.submission_id = a.submission_id
    left join villages v
        on q.village_id = v.village_id
)

select * from final
