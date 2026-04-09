-- Household dimension from PCO

with households as (
    select
        pco_household_id,
        household_name,
        member_count,
        primary_contact_id,
        primary_contact_name,
        created_at,
        updated_at
    from {{ ref('stg_pco_households') }}
)

select * from households
