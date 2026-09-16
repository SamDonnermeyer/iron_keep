-- Village health over time.
-- Answers: "Which villages are meeting? Which are shrinking? Who hasn't met in weeks?"
-- Used by: Village Coaches, Local Pastors, Campus Directors
--
-- One row per village per gathering date, carrying both the point-in-time
-- numbers and the trend context a coach needs to tell a bad week from a decline.
--
-- Unlike mart_village_summary (Engage Spaces groups, membership inferred from a
-- name substring match), this is keyed on the Shepherding village_id and counts
-- real recorded attendance.

with gatherings as (
    select * from {{ ref('fact_village_gathering') }}
),

sequenced as (
    select
        g.*,
        row_number() over (
            partition by g.village_id order by g.gathering_date
        ) as gathering_number,
        lag(g.gathering_date) over (
            partition by g.village_id order by g.gathering_date
        ) as previous_gathering_date,
        lag(g.attendee_count) over (
            partition by g.village_id order by g.gathering_date
        ) as previous_attendee_count,

        -- Trailing average over the last four gatherings, inclusive
        avg(g.attendee_count) over (
            partition by g.village_id
            order by g.gathering_date
            rows between 3 preceding and current row
        ) as attendee_count_4_gathering_avg,

        max(g.gathering_date) over (partition by g.village_id) as village_last_gathering_date
    from gatherings g
),

final as (
    select
        s.village_gathering_sk,
        s.village_id,
        s.church_code,
        s.church_sk,
        s.church_name,
        s.campus_name,
        s.pco_campus_id,
        s.village_name,
        s.leader_names,
        s.academic_year,
        s.village_status,

        s.gathering_date,
        s.gathering_week_start_date,
        s.gathering_iso_year,
        s.gathering_iso_week,
        s.gathering_type,
        s.activity_label,
        s.gathering_number,

        s.attendee_count,
        s.eligible_member_count,
        s.absent_count,
        s.attendance_rate,
        s.guest_count,

        s.previous_gathering_date,
        date_diff(s.gathering_date, s.previous_gathering_date, day) as days_since_previous_gathering,
        s.previous_attendee_count,
        s.attendee_count - s.previous_attendee_count as attendee_count_change,
        round(s.attendee_count_4_gathering_avg, 1) as attendee_count_4_gathering_avg,

        -- Is this the village's most recent gathering? Lets a dashboard filter
        -- to a current-state view without a correlated subquery.
        s.gathering_date = s.village_last_gathering_date as is_latest_gathering,
        date_diff(current_date('America/Los_Angeles'), s.village_last_gathering_date, day) as days_since_village_last_gathering,

        -- Data-quality context, so a coach can tell a real number from a messy one
        s.submission_count,
        s.is_resubmitted,
        s.max_reported_attendee_count,
        s.attendee_count != coalesce(s.max_reported_attendee_count, s.attendee_count) as differs_from_reported_headcount,
        s.last_submitted_by,
        s.last_submitted_at
    from sequenced s
)

select * from final
