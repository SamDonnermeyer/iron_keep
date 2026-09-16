-- Resolves Shepherding name-correction chains to a single current identity.
--
-- The Apps Script never overwrites a roster row. When a leader corrects a name
-- ("Trent" -> "Trent Barlow") the script appends a new person_local_id, then
-- stamps retired_at and superseded_by on the old row. Attendance submitted
-- before the correction still points at the OLD id, so any fact that counts
-- people must first walk the chain forward to the current id, or the same human
-- shows up as two members with half the attendance each.
--
-- Chains observed in the source are at most two hops, but this walks to an
-- arbitrary depth so a second correction cannot silently break counts.

with recursive

roster as (
    select * from {{ ref('stg_shepherding_roster') }}
),

-- Anchor: rows that were never superseded are their own current identity.
-- Walk backwards from those terminals, so each predecessor inherits the
-- terminal id rather than only its immediate successor.
resolved as (
    select
        person_local_id,
        person_local_id as current_person_local_id,
        0 as supersede_hops
    from roster
    where superseded_by is null

    union all

    select
        r.person_local_id,
        c.current_person_local_id,
        c.supersede_hops + 1 as supersede_hops
    from roster r
    inner join resolved c
        on r.superseded_by = c.person_local_id
    where r.superseded_by is not null
),

final as (
    select
        r.person_local_id,
        r.village_id,
        -- A chain whose superseded_by points at a missing row would drop out of
        -- the recursion entirely; fall back to self so the person is never lost.
        coalesce(res.current_person_local_id, r.person_local_id) as current_person_local_id,
        coalesce(res.supersede_hops, 0) as supersede_hops,
        coalesce(res.current_person_local_id, r.person_local_id) = r.person_local_id as is_current,
        r.display_name,
        r.choice_label,
        r.name_completeness,
        r.first_seen_date,
        r.retired_date,
        r.superseded_by
    from roster r
    left join resolved res
        on r.person_local_id = res.person_local_id
)

select * from final
