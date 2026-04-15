with source as (
    select * from {{ source('planning_center', 'addresses') }}
),

parsed as (
    select
        id as pco_address_id,
        cast(json_value(attributes, '$.street_line_1') as string) as street_line_1,
        cast(json_value(attributes, '$.street_line_2') as string) as street_line_2,
        cast(json_value(attributes, '$.city') as string) as city,
        cast(json_value(attributes, '$.state') as string) as state,
        cast(json_value(attributes, '$.zip') as string) as zip,
        cast(json_value(attributes, '$.country_code') as string) as country_code,
        cast(json_value(attributes, '$.country_name') as string) as country_name,
        cast(json_value(attributes, '$.primary') as bool) as is_primary,
        cast(json_value(attributes, '$.location') as string) as location,
        cast(json_value(relationships, '$.person.data.id') as string) as pco_person_id,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
