-- Bridge table linking person records across PCO and Engage Spaces
-- Handles the many-to-many relationship and provides match quality signals
-- This replaces the simple left join in dim_person for identity resolution

with pco_people as (
    select
        pco_person_id,
        lower(trim(first_name)) as first_name_norm,
        lower(trim(last_name)) as last_name_norm,
        first_name,
        last_name,
        status
    from {{ ref('stg_pco_people') }}
),

es_users as (
    select
        es_user_id,
        lower(trim(first_name)) as first_name_norm,
        lower(trim(last_name)) as last_name_norm,
        first_name,
        last_name,
        username as es_email,
        site as es_site_ids
    from {{ ref('stg_es_users') }}
),

-- Count how many PCO records share each name
pco_name_counts as (
    select first_name_norm, last_name_norm, count(*) as pco_count
    from pco_people
    group by 1, 2
),

-- Count how many ES records share each name
es_name_counts as (
    select first_name_norm, last_name_norm, count(*) as es_count
    from es_users
    group by 1, 2
),

-- Join on normalized name and annotate match quality
matched as (
    select
        pco.pco_person_id,
        es.es_user_id,
        pco.first_name as pco_first_name,
        pco.last_name as pco_last_name,
        es.first_name as es_first_name,
        es.last_name as es_last_name,
        es.es_email,
        es.es_site_ids,
        pco_nc.pco_count,
        es_nc.es_count,
        case
            when pco_nc.pco_count = 1 and es_nc.es_count = 1 then 'exact'
            when pco_nc.pco_count = 1 or es_nc.es_count = 1 then 'likely'
            else 'ambiguous'
        end as match_confidence
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
)

select * from matched
