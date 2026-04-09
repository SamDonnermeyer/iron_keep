with source as (
    select * from {{ source('planning_center', 'check_in_events') }}
),

parsed as (
    select
        id as pco_check_in_event_id,
        cast(json_value(attributes, '$.name') as string) as event_name,
        cast(json_value(attributes, '$.frequency') as string) as frequency,
        cast(json_value(attributes, '$.enable_services_integration') as bool) as enable_services_integration,
        cast(json_value(attributes, '$.pre_select_enabled') as bool) as pre_select_enabled,
        cast(json_value(attributes, '$.location_times_enabled') as bool) as location_times_enabled,
        cast(json_value(attributes, '$.integration_key') as string) as integration_key,
        timestamp(json_value(attributes, '$.archived_at')) as archived_at,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
