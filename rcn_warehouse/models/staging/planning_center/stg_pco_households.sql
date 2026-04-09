with source as (
    select * from {{ source('planning_center', 'households') }}
),

parsed as (
    select
        id as pco_household_id,
        cast(json_value(attributes, '$.name') as string) as household_name,
        cast(json_value(attributes, '$.member_count') as int64) as member_count,
        cast(json_value(attributes, '$.primary_contact_id') as string) as primary_contact_id,
        cast(json_value(attributes, '$.primary_contact_name') as string) as primary_contact_name,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
