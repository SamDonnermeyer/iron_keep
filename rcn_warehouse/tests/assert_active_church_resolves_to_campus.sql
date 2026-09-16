-- Every active or not_built church must resolve to a PCO campus by name.
-- The Shepherding church_name values currently match PCO campus names exactly,
-- but a rename on either side would silently strip campus from every village,
-- gathering and attendance row without failing anything else.
--
-- Closed and paused campuses are exempt: they are kept for historical joins and
-- may legitimately no longer exist in PCO.

select
    v.village_id,
    v.church_code,
    v.church_name,
    v.church_status
from {{ ref('dim_village') }} v
where v.pco_campus_id is null
  and v.church_status in ('active', 'not_built')
