-- Bridge table linking person records across PCO and Engage Spaces
-- Matches on email (highest confidence), then normalized name
-- Uses campus/site as a disambiguator to boost name-match confidence
-- Provides match quality signals for downstream consumption

with pco_people as (
    select
        pco_person_id,
        lower(trim(first_name)) as first_name_norm,
        lower(trim(last_name)) as last_name_norm,
        first_name,
        last_name,
        pco_campus_id
    from {{ ref('stg_pco_people') }}
),

-- Get primary email per PCO person
pco_emails as (
    select
        pco_person_id,
        lower(trim(email_address)) as pco_email
    from {{ ref('stg_pco_emails') }}
    where is_primary = true
      and is_blocked = false
      and email_address is not null
),

es_users as (
    select
        es_user_id,
        lower(trim(first_name)) as first_name_norm,
        lower(trim(last_name)) as last_name_norm,
        first_name,
        last_name,
        lower(trim(username)) as es_email,
        site as es_site_ids
    from {{ ref('stg_es_users') }}
),

-- Campus mapping: PCO campus ID → ES location ID
campus_map as (
    select
        pco_campus_id,
        es_location_id
    from {{ ref('dim_campus') }}
    where es_location_id is not null
),

-- Match 1: Email-based (highest confidence)
email_matches as (
    select
        pco.pco_person_id,
        es.es_user_id,
        pco_p.first_name as pco_first_name,
        pco_p.last_name as pco_last_name,
        es.first_name as es_first_name,
        es.last_name as es_last_name,
        pco.pco_email,
        es.es_email,
        es.es_site_ids,
        'email' as match_method,
        'exact' as match_confidence,
        cast(null as bool) as campus_match
    from pco_emails pco
    inner join es_users es
        on pco.pco_email = es.es_email
        and pco.pco_email != ''
    inner join pco_people pco_p
        on pco.pco_person_id = pco_p.pco_person_id
),

-- Track which pairs were already matched by email
email_matched_pco as (
    select distinct pco_person_id from email_matches
),
email_matched_es as (
    select distinct es_user_id from email_matches
),

-- Count name occurrences for confidence scoring on name matches
pco_name_counts as (
    select first_name_norm, last_name_norm, count(*) as pco_count
    from pco_people
    group by 1, 2
),

es_name_counts as (
    select first_name_norm, last_name_norm, count(*) as es_count
    from es_users
    group by 1, 2
),

-- Match 2: Name-based (only for people not already matched by email)
-- Campus is used to boost confidence: ambiguous+campus → likely, likely+campus → exact
name_matches as (
    select
        pco.pco_person_id,
        es.es_user_id,
        pco.first_name as pco_first_name,
        pco.last_name as pco_last_name,
        es.first_name as es_first_name,
        es.last_name as es_last_name,
        cast(null as string) as pco_email,
        es.es_email,
        es.es_site_ids,
        'name' as match_method,
        -- Base confidence from name uniqueness, boosted by campus match
        case
            when pco_nc.pco_count = 1 and es_nc.es_count = 1 then 'exact'
            when (pco_nc.pco_count = 1 or es_nc.es_count = 1)
                then case
                    when cm.es_location_id is not null
                        and es.es_site_ids like concat('%', cm.es_location_id, '%')
                        then 'exact'   -- likely + campus match → exact
                    else 'likely'
                end
            else case
                when cm.es_location_id is not null
                    and es.es_site_ids like concat('%', cm.es_location_id, '%')
                    then 'likely'      -- ambiguous + campus match → likely
                else 'ambiguous'
            end
        end as match_confidence,
        case
            when cm.es_location_id is not null
                and es.es_site_ids like concat('%', cm.es_location_id, '%')
                then true
            else false
        end as campus_match
    from pco_people pco
    inner join es_users es
        on pco.first_name_norm = es.first_name_norm
        and pco.last_name_norm = es.last_name_norm
    left join pco_name_counts pco_nc
        on pco.first_name_norm = pco_nc.first_name_norm
        and pco.last_name_norm = pco_nc.last_name_norm
    left join es_name_counts es_nc
        on es.first_name_norm = es_nc.first_name_norm
        and es.last_name_norm = es_nc.last_name_norm
    left join campus_map cm
        on pco.pco_campus_id = cm.pco_campus_id
    where pco.pco_person_id not in (select pco_person_id from email_matched_pco)
      and es.es_user_id not in (select es_user_id from email_matched_es)
),

combined as (
    select * from email_matches
    union all
    select * from name_matches
)

select * from combined
