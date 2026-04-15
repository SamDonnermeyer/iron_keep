-- Unified person dimension
-- Includes all PCO people + ES-only people (not in PCO)
-- Enriched with: PCO emails, phones, addresses, custom fields, and ES data
-- Uses bridge_person_identity for cross-platform matching (email + name)

with pco_people as (
    select * from {{ ref('stg_pco_people') }}
),

-- Primary email per PCO person
pco_primary_emails as (
    select pco_person_id, email_address as pco_email
    from {{ ref('stg_pco_emails') }}
    where is_primary = true and is_blocked = false
    qualify row_number() over (partition by pco_person_id order by updated_at desc) = 1
),

-- Primary phone per PCO person
pco_primary_phones as (
    select pco_person_id, phone_number as pco_phone, carrier as pco_phone_carrier
    from {{ ref('stg_pco_phone_numbers') }}
    where is_primary = true
    qualify row_number() over (partition by pco_person_id order by updated_at desc) = 1
),

-- Primary address per PCO person
pco_primary_addresses as (
    select
        pco_person_id,
        street_line_1 as pco_street,
        city as pco_city,
        state as pco_state,
        zip as pco_zip,
        country_name as pco_country
    from {{ ref('stg_pco_addresses') }}
    where is_primary = true
    qualify row_number() over (partition by pco_person_id order by updated_at desc) = 1
),

-- Pivoted custom fields
custom_fields as (
    select * from {{ ref('int_pco_person_custom_fields') }}
),

es_users as (
    select
        es_user_id,
        first_name,
        last_name,
        username as es_email,
        site,
        belief_status,
        relational_status,
        discipleship_context,
        discipleship_generation,
        current_groups,
        current_teams,
        group_leader,
        last_village_activity,
        last_discipleship_activity,
        last_updated
    from {{ ref('stg_es_users') }}
),

-- Pick best ES match per PCO person (email > campus-boosted name > name)
bridge_ranked as (
    select
        *,
        row_number() over (
            partition by pco_person_id
            order by
                case match_method when 'email' then 0 else 1 end,
                case match_confidence
                    when 'exact' then 1
                    when 'likely' then 2
                    when 'ambiguous' then 3
                end,
                case when campus_match then 0 else 1 end,
                es_user_id desc
        ) as rn
    from {{ ref('bridge_person_identity') }}
),

best_match as (
    select * from bridge_ranked where rn = 1
),

-- PCO people enriched with all data sources
pco_enriched as (
    select
        pco.pco_person_id,
        bm.es_user_id,
        bm.match_method as es_match_method,
        bm.match_confidence as es_match_confidence,
        bm.campus_match as es_campus_match,
        pco.first_name,
        pco.last_name,
        pco.full_name,
        pco.nickname,
        pco.given_name,
        pco.middle_name,
        pco.gender,
        pco.membership,
        pco.status,
        pco.birthdate,
        pco.anniversary,
        pco.grade,
        pco.graduation_year,
        pco.school_type,
        pco.is_child,
        pco.avatar_url,
        pco.directory_status,
        pco.passed_background_check,
        pco.pco_campus_id,
        -- Contact info from PCO
        pe.pco_email,
        pp.pco_phone,
        pp.pco_phone_carrier,
        pa.pco_street,
        pa.pco_city,
        pa.pco_state,
        pa.pco_zip,
        pa.pco_country,
        -- Custom fields from PCO (pivoted)
        cf.is_baptized,
        cf.baptism_date,
        cf.baptism_details,
        cf.baptism_site,
        cf.school_year,
        cf.demographic,
        cf.major,
        cf.employment,
        cf.vocation,
        cf.ownership_start_date,
        cf.ownership_end_date,
        cf.village_leaders,
        cf.huddle_leader,
        cf.serving,
        cf.skills_interests,
        cf.send_trips,
        cf.affinity_group,
        cf.apest_result_1,
        cf.apest_result_2,
        cf.discipleship_type,
        cf.staff_role,
        cf.archived_campus,
        -- ES fields (when matched)
        es.es_email,
        es.belief_status,
        es.relational_status,
        es.discipleship_context,
        es.discipleship_generation,
        es.current_groups as es_current_groups,
        es.current_teams as es_current_teams,
        es.group_leader as es_group_leader,
        es.last_village_activity,
        es.last_discipleship_activity,
        'pco' as primary_source,
        pco.inactivated_at,
        pco.created_at,
        pco.updated_at
    from pco_people pco
    left join best_match bm on pco.pco_person_id = bm.pco_person_id
    left join es_users es on bm.es_user_id = es.es_user_id
    left join pco_primary_emails pe on pco.pco_person_id = pe.pco_person_id
    left join pco_primary_phones pp on pco.pco_person_id = pp.pco_person_id
    left join pco_primary_addresses pa on pco.pco_person_id = pa.pco_person_id
    left join custom_fields cf on pco.pco_person_id = cf.pco_person_id
),

-- ES-only people (no PCO match at all)
es_matched_ids as (
    select distinct es_user_id from {{ ref('bridge_person_identity') }}
),

es_only as (
    select
        cast(null as string) as pco_person_id,
        es.es_user_id,
        cast(null as string) as es_match_method,
        cast(null as string) as es_match_confidence,
        cast(null as bool) as es_campus_match,
        es.first_name,
        es.last_name,
        concat(es.first_name, ' ', es.last_name) as full_name,
        cast(null as string) as nickname,
        cast(null as string) as given_name,
        cast(null as string) as middle_name,
        cast(null as string) as gender,
        cast(null as string) as membership,
        cast(null as string) as status,
        cast(null as date) as birthdate,
        cast(null as date) as anniversary,
        cast(null as int64) as grade,
        cast(null as int64) as graduation_year,
        cast(null as string) as school_type,
        cast(null as bool) as is_child,
        cast(null as string) as avatar_url,
        cast(null as string) as directory_status,
        cast(null as bool) as passed_background_check,
        cast(null as string) as pco_campus_id,
        -- No PCO contact info
        cast(null as string) as pco_email,
        cast(null as string) as pco_phone,
        cast(null as string) as pco_phone_carrier,
        cast(null as string) as pco_street,
        cast(null as string) as pco_city,
        cast(null as string) as pco_state,
        cast(null as string) as pco_zip,
        cast(null as string) as pco_country,
        -- No PCO custom fields
        cast(null as string) as is_baptized,
        cast(null as string) as baptism_date,
        cast(null as string) as baptism_details,
        cast(null as string) as baptism_site,
        cast(null as string) as school_year,
        cast(null as string) as demographic,
        cast(null as string) as major,
        cast(null as string) as employment,
        cast(null as string) as vocation,
        cast(null as string) as ownership_start_date,
        cast(null as string) as ownership_end_date,
        cast(null as string) as village_leaders,
        cast(null as string) as huddle_leader,
        cast(null as string) as serving,
        cast(null as string) as skills_interests,
        cast(null as string) as send_trips,
        cast(null as string) as affinity_group,
        cast(null as string) as apest_result_1,
        cast(null as string) as apest_result_2,
        cast(null as string) as discipleship_type,
        cast(null as string) as staff_role,
        cast(null as string) as archived_campus,
        -- ES fields
        es.es_email,
        es.belief_status,
        es.relational_status,
        es.discipleship_context,
        es.discipleship_generation,
        es.current_groups as es_current_groups,
        es.current_teams as es_current_teams,
        es.group_leader as es_group_leader,
        es.last_village_activity,
        es.last_discipleship_activity,
        'es_only' as primary_source,
        cast(null as timestamp) as inactivated_at,
        cast(null as timestamp) as created_at,
        cast(null as timestamp) as updated_at
    from es_users es
    where es.es_user_id not in (select es_user_id from es_matched_ids)
),

unioned as (
    select * from pco_enriched
    union all
    select * from es_only
)

select * from unioned
