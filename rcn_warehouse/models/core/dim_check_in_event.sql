-- Check-in event dimension from PCO

with events as (
    select
        pco_check_in_event_id,
        event_name,
        frequency,
        enable_services_integration,
        pre_select_enabled,
        location_times_enabled,
        integration_key,
        archived_at,
        created_at,
        updated_at
    from {{ ref('stg_pco_check_in_events') }}
)

select * from events
