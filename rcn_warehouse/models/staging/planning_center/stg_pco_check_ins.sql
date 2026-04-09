with source as (
    select * from {{ source('planning_center', 'check_ins') }}
),

parsed as (
    select
        id as pco_check_in_id,
        cast(json_value(attributes, '$.first_name') as string) as first_name,
        cast(json_value(attributes, '$.last_name') as string) as last_name,
        cast(json_value(attributes, '$.kind') as string) as kind,
        cast(json_value(attributes, '$.number') as int64) as check_in_number,
        cast(json_value(attributes, '$.security_code') as string) as security_code,
        cast(json_value(attributes, '$.one_time_guest') as bool) as is_one_time_guest,
        cast(json_value(attributes, '$.emergency_contact_name') as string) as emergency_contact_name,
        cast(json_value(attributes, '$.emergency_contact_phone_number') as string) as emergency_contact_phone,
        timestamp(json_value(attributes, '$.confirmed_at')) as confirmed_at,
        timestamp(json_value(attributes, '$.checked_out_at')) as checked_out_at,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        -- Extract person and event IDs from relationships
        cast(json_value(relationships, '$.person.data.id') as string) as pco_person_id,
        cast(json_value(relationships, '$.event.data.id') as string) as pco_event_id,
        cast(json_value(relationships, '$.event_period.data.id') as string) as pco_event_period_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
