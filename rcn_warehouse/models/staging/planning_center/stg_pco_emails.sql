with source as (
    select * from {{ source('planning_center', 'emails') }}
),

parsed as (
    select
        id as pco_email_id,
        cast(json_value(attributes, '$.address') as string) as email_address,
        cast(json_value(attributes, '$.primary') as bool) as is_primary,
        cast(json_value(attributes, '$.location') as string) as location,
        cast(json_value(attributes, '$.blocked') as bool) as is_blocked,
        cast(json_value(relationships, '$.person.data.id') as string) as pco_person_id,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
