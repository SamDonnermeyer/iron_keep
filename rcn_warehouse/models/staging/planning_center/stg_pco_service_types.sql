with source as (
    select * from {{ source('planning_center', 'service_types') }}
),

parsed as (
    select
        id as pco_service_type_id,
        cast(json_value(attributes, '$.name') as string) as service_type_name,
        cast(json_value(attributes, '$.frequency') as string) as frequency,
        cast(json_value(attributes, '$.sequence') as int64) as sequence,
        cast(json_value(attributes, '$.last_plan_from') as string) as last_plan_from,
        timestamp(json_value(attributes, '$.archived_at')) as archived_at,
        timestamp(json_value(attributes, '$.deleted_at')) as deleted_at,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
