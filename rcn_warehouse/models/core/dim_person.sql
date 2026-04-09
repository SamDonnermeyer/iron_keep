-- Unified person dimension
-- Includes all PCO people + ES-only people (not in PCO)
-- Uses bridge_person_identity for cross-platform matching
-- When multiple ES matches exist, takes the highest-confidence match

with pco_people as (
    select * from {{ ref('stg_pco_people') }}
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

-- Pick best ES match per PCO person (exact > likely > ambiguous, then most recent)
bridge_ranked as (
    select
        *,
        row_number() over (
            partition by pco_person_id
            order by
                case match_confidence
                    when 'exact' then 1
                    when 'likely' then 2
                    when 'ambiguous' then 3
                end,
                es_user_id desc
        ) as rn
    from {{ ref('bridge_person_identity') }}
),

best_match as (
    select * from bridge_ranked where rn = 1
),

-- PCO people enriched with best ES match
pco_enriched as (
    select
        pco.pco_person_id,
        bm.es_user_id,
        bm.match_confidence as es_match_confidence,
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
),

-- ES-only people (no PCO match at all)
es_matched_ids as (
    select distinct es_user_id from {{ ref('bridge_person_identity') }}
),

es_only as (
    select
        cast(null as string) as pco_person_id,
        es.es_user_id,
        cast(null as string) as es_match_confidence,
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
