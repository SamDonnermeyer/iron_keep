with source as (
    select * from {{ source('planning_center', 'headcounts') }}
),

parsed as (
    select
        id as pco_headcount_id,
        cast(json_value(attributes, '$.total') as int64) as total,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        -- Extract parent references from relationships
        cast(json_value(relationships, '$.attendance_type.data.id') as string) as pco_attendance_type_id,
        cast(json_value(relationships, '$.event_time.data.id') as string) as pco_event_time_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
