-- The AttendanceLog must hold at most one row per person per submission.
-- A duplicate means the Poller double-processed a form response, which would
-- inflate that gathering's headcount.

select
    submission_id,
    person_local_id,
    count(*) as row_count
from {{ ref('stg_shepherding_attendance_log') }}
group by 1, 2
having count(*) > 1
