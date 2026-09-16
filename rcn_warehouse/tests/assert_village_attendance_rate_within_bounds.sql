-- Attendance can never exceed the eligible roster, and a gathering that
-- produced attendee rows must have a non-zero denominator.

select
    village_id,
    gathering_date,
    attendee_count,
    eligible_member_count,
    attendance_rate
from {{ ref('fact_village_gathering') }}
where attendee_count > eligible_member_count
   or (attendee_count > 0 and eligible_member_count = 0)
   or attendance_rate > 1
