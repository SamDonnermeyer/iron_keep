-- Person dimension for the Shepherding Tool, at one row per roster entry.
--
-- Grain is person_local_id, which includes rows retired by a name correction.
-- Facts always carry the CURRENT id, so a fact-to-dimension join on
-- person_local_id is 1:1; the superseded rows sit here for lineage and are
-- identified by is_current = false.
--
-- IDENTITY: person_local_id is authoritative. pco_person_id is a best-effort
-- convenience link and is deliberately not required by anything downstream —
-- 45% of the roster is first-name-only, so a large share will never match. Read
-- pco_match_confidence before using the link for anything that matters:
--   exact      full name, unique within the village's campus
--   likely     full name, unique nationally but campus not confirmed
--   ambiguous  full name, more than one candidate — do not rely on it
--   unmatched  partial name, or no candidate

with roster as (
    select * from {{ ref('int_shepherding_roster_resolved') }}
),

villages as (
    select
        village_id,
        church_code,
        church_name,
        village_name,
        academic_year,
        pco_campus_id
    from {{ ref('dim_village') }}
),

windows as (
    select * from {{ ref('int_shepherding_membership_window') }}
),

-- Split the display name only where the roster says it is a full name.
-- "partial" rows are first-name-only and are never match candidates.
named as (
    select
        r.*,
        case
            when r.name_completeness = 'full' and regexp_contains(trim(r.display_name), r'\s')
                then lower(regexp_extract(trim(r.display_name), r'^(\S+)'))
        end as first_name_norm,
        case
            when r.name_completeness = 'full' and regexp_contains(trim(r.display_name), r'\s')
                then lower(trim(regexp_replace(trim(r.display_name), r'^\S+\s+', '')))
        end as last_name_norm
    from roster r
),

pco_people as (
    select
        pco_person_id,
        pco_campus_id,
        lower(trim(first_name)) as first_name_norm,
        lower(trim(last_name)) as last_name_norm
    from {{ ref('stg_pco_people') }}
    where first_name is not null
      and last_name is not null
),

-- How many PCO people share this name nationally, for confidence scoring
pco_name_counts as (
    select
        first_name_norm,
        last_name_norm,
        count(*) as national_count
    from pco_people
    group by 1, 2
),

candidates as (
    select
        n.person_local_id,
        p.pco_person_id,
        p.pco_campus_id = v.pco_campus_id as campus_match,
        nc.national_count
    from named n
    inner join villages v
        on n.village_id = v.village_id
    inner join pco_people p
        on n.first_name_norm = p.first_name_norm
        and n.last_name_norm = p.last_name_norm
    left join pco_name_counts nc
        on n.first_name_norm = nc.first_name_norm
        and n.last_name_norm = nc.last_name_norm
    where n.is_current
),

-- Prefer a same-campus candidate; only claim "exact" when that campus
-- candidate is the sole one at that campus.
scored as (
    select
        person_local_id,
        countif(campus_match) as campus_candidates,
        count(*) as total_candidates,
        max(national_count) as national_count,
        array_agg(pco_person_id order by case when campus_match then 0 else 1 end, pco_person_id limit 1)[offset(0)] as pco_person_id
    from candidates
    group by 1
),

matched as (
    select
        person_local_id,
        pco_person_id,
        case
            when campus_candidates = 1 then 'exact'
            when campus_candidates = 0 and total_candidates = 1 then 'likely'
            else 'ambiguous'
        end as pco_match_confidence
    from scored
),

final as (
    select
        n.person_local_id,
        n.village_id,
        v.church_code,
        v.church_name,
        v.village_name,
        v.academic_year,
        v.pco_campus_id,

        n.display_name,
        -- The exact string shown in the form checkbox
        n.choice_label,
        n.name_completeness,
        n.name_completeness = 'full' as has_full_name,

        -- Name-correction lineage
        n.current_person_local_id,
        n.is_current,
        n.supersede_hops,
        n.superseded_by,
        n.retired_date,

        -- Membership window, populated for current rows only. See
        -- int_shepherding_membership_window for why this is not first_seen_date.
        n.first_seen_date,
        w.membership_start_date,
        w.membership_end_date,
        w.first_attended_date,
        w.last_attended_date,
        coalesce(w.gatherings_attended, 0) as gatherings_attended,
        coalesce(w.is_retired, n.retired_date is not null) as is_retired,

        -- Best-effort cross-platform link. Always check the confidence column.
        m.pco_person_id,
        coalesce(m.pco_match_confidence, 'unmatched') as pco_match_confidence
    from named n
    left join villages v
        on n.village_id = v.village_id
    left join windows w
        on n.person_local_id = w.person_local_id
    left join matched m
        on n.person_local_id = m.person_local_id
)

select * from final
