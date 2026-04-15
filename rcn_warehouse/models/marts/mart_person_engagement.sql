-- Person-level engagement summary
-- Answers: "How is this person engaging across all touchpoints?"
-- Used by: Village Leaders, Village Coaches

with person as (
    select * from {{ ref('dim_person') }}
),

check_ins as (
    select
        pco_person_id,
        count(*) as total_check_ins,
        count(distinct date(created_at)) as check_in_days,
        min(created_at) as first_check_in_at,
        max(created_at) as last_check_in_at,
        countif(kind = 'Regular') as regular_check_ins,
        countif(kind = 'Volunteer') as volunteer_check_ins
    from {{ ref('fact_check_ins') }}
    where pco_person_id is not null
    group by 1
),

final as (
    select
        coalesce(p.pco_person_id, p.es_user_id) as person_id,
        p.pco_person_id,
        p.es_user_id,
        p.primary_source,
        p.es_match_method,
        p.es_match_confidence,
        p.first_name,
        p.last_name,
        p.full_name,
        p.status,
        p.membership,
        p.is_child,
        -- Contact info
        p.pco_email,
        p.pco_phone,
        p.pco_city,
        p.pco_state,
        -- PCO custom fields
        p.is_baptized,
        p.baptism_date,
        p.baptism_site,
        p.school_year,
        p.demographic,
        p.major,
        p.ownership_start_date,
        p.ownership_end_date,
        p.village_leaders,
        p.huddle_leader,
        p.serving,
        p.discipleship_type,
        p.staff_role,
        -- ES fields
        p.belief_status,
        p.relational_status,
        p.discipleship_context,
        p.discipleship_generation,
        p.es_group_leader,
        p.es_current_groups,
        p.es_current_teams,
        p.es_email,
        -- Check-in metrics
        coalesce(ci.total_check_ins, 0) as total_check_ins,
        coalesce(ci.check_in_days, 0) as check_in_days,
        coalesce(ci.regular_check_ins, 0) as regular_check_ins,
        coalesce(ci.volunteer_check_ins, 0) as volunteer_check_ins,
        ci.first_check_in_at,
        ci.last_check_in_at,
        -- ES activity
        p.last_village_activity,
        p.last_discipleship_activity,
        -- Recency
        date_diff(current_date(), date(ci.last_check_in_at), day) as days_since_last_check_in,
        p.created_at as pco_created_at
    from person p
    left join check_ins ci on p.pco_person_id = ci.pco_person_id
)

select * from final
