-- Service type dimension from PCO

with service_types as (
    select
        pco_service_type_id,
        service_type_name,
        frequency,
        sequence,
        last_plan_from,
        archived_at,
        deleted_at,
        created_at,
        updated_at
    from {{ ref('stg_pco_service_types') }}
)

select * from service_types
