with source as (
    select * from {{ source('planning_center', 'field_definitions') }}
),

parsed as (
    select
        id as pco_field_definition_id,
        cast(json_value(attributes, '$.name') as string) as field_name,
        cast(json_value(attributes, '$.slug') as string) as slug,
        cast(json_value(attributes, '$.data_type') as string) as data_type,
        cast(json_value(attributes, '$.sequence') as int64) as sequence,
        cast(json_value(attributes, '$.tab_id') as string) as tab_id,
        cast(json_value(attributes, '$.deleted_at') as string) as deleted_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
