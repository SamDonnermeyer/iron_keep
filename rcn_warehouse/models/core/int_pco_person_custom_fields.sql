-- Intermediate model: pivots PCO custom field data into one row per person
-- Joins field_data to field_definitions to resolve field names

with field_data as (
    select
        pco_person_id,
        pco_field_definition_id,
        field_value
    from {{ ref('stg_pco_field_data') }}
),

field_defs as (
    select
        pco_field_definition_id,
        slug
    from {{ ref('stg_pco_field_definitions') }}
),

joined as (
    select
        fd.pco_person_id,
        fdef.slug,
        fd.field_value
    from field_data fd
    inner join field_defs fdef
        on fd.pco_field_definition_id = fdef.pco_field_definition_id
),

pivoted as (
    select
        pco_person_id,
        max(case when slug = 'baptized' then field_value end) as is_baptized,
        max(case when slug = 'baptism_date' then field_value end) as baptism_date,
        max(case when slug = 'baptism_details' then field_value end) as baptism_details,
        max(case when slug = 'resonate_baptism_site' then field_value end) as baptism_site,
        max(case when slug = 'school_year' then field_value end) as school_year,
        max(case when slug = 'demographic' then field_value end) as demographic,
        max(case when slug = 'major' then field_value end) as major,
        max(case when slug = 'employment' then field_value end) as employment,
        max(case when slug = 'vocation' then field_value end) as vocation,
        max(case when slug = 'ownership_start_date' then field_value end) as ownership_start_date,
        max(case when slug = 'ownership_end_date' then field_value end) as ownership_end_date,
        max(case when slug = 'village_leaders' then field_value end) as village_leaders,
        max(case when slug = 'huddle_leader' then field_value end) as huddle_leader,
        max(case when slug = 'serving' then field_value end) as serving,
        max(case when slug = 'skills_interests' then field_value end) as skills_interests,
        max(case when slug = 'send_trips' then field_value end) as send_trips,
        max(case when slug = 'affinity_group' then field_value end) as affinity_group,
        max(case when slug = '1_apest_result' then field_value end) as apest_result_1,
        max(case when slug = '2_apest_result' then field_value end) as apest_result_2,
        max(case when slug = 'discipleship_type' then field_value end) as discipleship_type,
        max(case when slug = 'staff_role' then field_value end) as staff_role,
        max(case when slug = 'archived_campus' then field_value end) as archived_campus
    from joined
    group by pco_person_id
)

select * from pivoted
