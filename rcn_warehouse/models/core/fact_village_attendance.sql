-- One row per member per village gathering, PRESENT OR ABSENT.
--
-- The source records attendance only — an absence is the absence of a row — so
-- absences are materialised here by pairing each gathering with the members
-- whose membership window covers that date. Without this, every downstream
-- attendance rate has no denominator and "who has stopped showing up" is
-- unanswerable, which is the whole point of a shepherding tool.
--
-- The universe is built as a UNION of (eligible members x gatherings) and
-- (people actually recorded present) rather than from the window alone. The
-- window is constructed to cover every observed attendance row, but a union
-- makes that structural: if the source ever drifts, a present person is still
-- counted present instead of being silently dropped from the fact.

with gatherings as (
    select
        village_gathering_sk,
        village_id,
        church_code,
        gathering_date,
        gathering_week_start_date,
        gathering_type,
        academic_year
    from {{ ref('fact_village_gathering') }}
),

presence as (
    select * from {{ ref('int_shepherding_attendance_resolved') }}
),

windows as (
    select * from {{ ref('int_shepherding_membership_window') }}
),

eligible as (
    select
        g.village_gathering_sk,
        g.village_id,
        g.gathering_date,
        w.person_local_id
    from gatherings g
    inner join windows w
        on g.village_id = w.village_id
        and w.membership_start_date <= g.gathering_date
        and (w.membership_end_date is null or w.membership_end_date >= g.gathering_date)
),

present as (
    select
        g.village_gathering_sk,
        g.village_id,
        g.gathering_date,
        p.person_local_id
    from presence p
    inner join gatherings g
        on p.village_id = g.village_id
        and p.gathering_date = g.gathering_date
),

universe as (
    select * from eligible
    union distinct
    select * from present
),

members as (
    select
        person_local_id,
        display_name,
        choice_label,
        name_completeness,
        has_full_name,
        pco_person_id,
        pco_match_confidence,
        is_retired
    from {{ ref('dim_village_member') }}
    where is_current
),

villages as (
    select
        village_id,
        church_sk,
        church_name,
        village_name,
        leader_names,
        pco_campus_id,
        campus_name
    from {{ ref('dim_village') }}
),

final as (
    select
        u.village_gathering_sk,
        to_hex(md5(concat(u.village_gathering_sk, '|', u.person_local_id))) as village_attendance_sk,

        u.village_id,
        g.church_code,
        v.church_sk,
        v.church_name,
        v.village_name,
        v.leader_names,
        v.pco_campus_id,
        v.campus_name,
        g.academic_year,

        u.gathering_date,
        g.gathering_week_start_date,
        g.gathering_type,

        u.person_local_id,
        m.display_name,
        m.choice_label,
        m.name_completeness,
        m.has_full_name,
        m.is_retired as member_is_retired,

        -- Present if any submission for this village-date listed them
        p.person_local_id is not null as attended_flag,
        coalesce(p.source_submission_count, 0) as source_submission_count,
        p.person_name_at_submission,

        -- Best-effort link; see dim_village_member for confidence semantics
        m.pco_person_id,
        coalesce(m.pco_match_confidence, 'unmatched') as pco_match_confidence
    from universe u
    inner join gatherings g
        on u.village_gathering_sk = g.village_gathering_sk
    left join presence p
        on u.village_id = p.village_id
        and u.gathering_date = p.gathering_date
        and u.person_local_id = p.person_local_id
    left join members m
        on u.person_local_id = m.person_local_id
    left join villages v
        on u.village_id = v.village_id
)

select * from final
