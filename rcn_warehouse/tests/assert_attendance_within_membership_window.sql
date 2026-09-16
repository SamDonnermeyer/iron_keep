-- Every recorded attendance must fall inside its own member's membership
-- window. If this fails, the denominator in fact_village_gathering is smaller
-- than the numerator and attendance rates go above 100%.
--
-- This is the assertion that makes int_shepherding_membership_window's
-- least(first_seen, first_attended) rule load-bearing rather than incidental:
-- windowing on first_seen_at alone breaks this test on 45% of source rows.

with attendance as (
    select * from {{ ref('int_shepherding_attendance_resolved') }}
),

windows as (
    select * from {{ ref('int_shepherding_membership_window') }}
)

select
    a.village_id,
    a.gathering_date,
    a.person_local_id,
    w.membership_start_date,
    w.membership_end_date
from attendance a
left join windows w
    on a.person_local_id = w.person_local_id
where w.person_local_id is null
   or a.gathering_date < w.membership_start_date
   or (w.membership_end_date is not null and a.gathering_date > w.membership_end_date)
