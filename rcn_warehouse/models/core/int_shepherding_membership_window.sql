-- The date range over which each village member should be counted in the
-- attendance denominator.
--
-- This cannot be driven by first_seen_at alone. That column records when the
-- Apps Script wrote the roster row, not when the person joined the village, and
-- because the form is processed on a sweep it commonly lands one or two days
-- AFTER a gathering the person demonstrably attended — 1,252 of 2,810 source
-- attendance rows (45%) sit before their own first_seen_at. Windowing on it
-- would mark those people ineligible for gatherings they were present at and
-- quietly understate every attendance rate.
--
-- So the window opens at the earlier of (roster row created, first gathering
-- attended) and closes at the later of (retired, last gathering attended). That
-- guarantees no attendance row ever falls outside its own member's window,
-- while still not counting anyone absent from gatherings held before they
-- first appeared.

with roster as (
    select * from {{ ref('int_shepherding_roster_resolved') }}
),

attendance as (
    select * from {{ ref('int_shepherding_attendance_resolved') }}
),

-- Predecessors carry their own first_seen_date; the current identity should
-- inherit the earliest one in the chain.
seen_dates as (
    select
        current_person_local_id as person_local_id,
        min(first_seen_date) as first_seen_date
    from roster
    group by 1
),

attended_dates as (
    select
        person_local_id,
        min(gathering_date) as first_attended_date,
        max(gathering_date) as last_attended_date,
        count(*) as gatherings_attended
    from attendance
    group by 1
),

current_members as (
    select
        person_local_id,
        village_id,
        retired_date
    from roster
    where is_current
),

final as (
    select
        m.person_local_id,
        m.village_id,
        s.first_seen_date,
        a.first_attended_date,
        a.last_attended_date,
        coalesce(a.gatherings_attended, 0) as gatherings_attended,

        -- least()/greatest() return NULL if any argument is NULL, so each side is
        -- backfilled with the other before comparing.
        least(
            coalesce(s.first_seen_date, a.first_attended_date),
            coalesce(a.first_attended_date, s.first_seen_date)
        ) as membership_start_date,

        -- An open window (NULL) means the member is still active.
        case
            when m.retired_date is null then null
            else greatest(m.retired_date, coalesce(a.last_attended_date, m.retired_date))
        end as membership_end_date,

        m.retired_date is not null as is_retired
    from current_members m
    left join seen_dates s
        on m.person_local_id = s.person_local_id
    left join attended_dates a
        on m.person_local_id = a.person_local_id
)

select * from final
