-- Village dimension from the Shepherding Tool control workbook.
--
-- These are the real, ID-keyed villages (village_id is assigned at create and
-- never changes, even if the village is renamed or the leaders change), as
-- opposed to dim_group, which carries Engage Spaces groups keyed only by name.
-- Facts should join here, not to dim_group, for anything village-related.
--
-- Campus is resolved by name against dim_campus. The Shepherding church_name
-- values are the same campus names PCO uses, so this is an exact match rather
-- than a fuzzy one — but it is asserted by a test rather than assumed, because
-- an unmatched active church silently strips campus from every downstream row.

with villages as (
    select * from {{ ref('stg_shepherding_villages') }}
),

churches as (
    select * from {{ ref('stg_shepherding_churches') }}
),

campuses as (
    select
        pco_campus_id,
        campus_name,
        city,
        state
    from {{ ref('dim_campus') }}
),

final as (
    select
        v.village_id,
        v.church_code,
        c.church_sk,
        c.church_name,
        v.village_name,
        v.leader_names,
        -- Display only, derived from leader first names. Never key on this.
        v.tab_name,
        v.academic_year,
        v.status as village_status,
        v.created_date as village_created_date,

        -- Campus link into the existing PCO-sourced dimension
        camp.pco_campus_id,
        camp.campus_name,
        camp.city as campus_city,
        camp.state as campus_state,

        c.status as church_status,
        c.school_year_start_date,
        c.church_email,
        c.church_pastor_email,
        c.church_manager_email,
        c.last_response_at as church_last_response_at,

        -- Operational plumbing, kept so a data question can be traced back to
        -- the exact workbook and form that produced it.
        c.workbook_id,
        c.form_id,
        c.form_url,
        v.page_item_id,
        v.checkbox_item_id,
        v.correction_item_id,
        v.newnames_item_id
    from villages v
    left join churches c
        on v.church_code = c.church_code
    left join campuses camp
        on lower(trim(c.church_name)) = lower(trim(camp.campus_name))
)

select * from final
