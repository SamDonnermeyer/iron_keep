-- fact_village_attendance is one row per member per village gathering.
-- A duplicate here would double-count a person, most likely because a
-- name-correction chain failed to resolve to a single current identity.

select
    village_gathering_sk,
    person_local_id,
    count(*) as row_count
from {{ ref('fact_village_attendance') }}
group by 1, 2
having count(*) > 1
