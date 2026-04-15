with source as (
    select * from {{ source('planning_center', 'field_data') }}
),

parsed as (
    select
        id as pco_field_data_id,
        cast(json_value(attributes, '$.value') as string) as field_value,
        cast(json_value(attributes, '$.file_name') as string) as file_name,
        cast(json_value(relationships, '$.customizable.data.id') as string) as pco_person_id,
        cast(json_value(relationships, '$.field_definition.data.id') as string) as pco_field_definition_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
