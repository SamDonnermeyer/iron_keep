with source as (
    select * from {{ source('planning_center', 'phone_numbers') }}
),

parsed as (
    select
        id as pco_phone_id,
        cast(json_value(attributes, '$.number') as string) as phone_number,
        cast(json_value(attributes, '$.e164') as string) as phone_e164,
        cast(json_value(attributes, '$.national') as string) as phone_national,
        cast(json_value(attributes, '$.international') as string) as phone_international,
        cast(json_value(attributes, '$.primary') as bool) as is_primary,
        cast(json_value(attributes, '$.location') as string) as location,
        cast(json_value(attributes, '$.carrier') as string) as carrier,
        cast(json_value(attributes, '$.country_code') as string) as country_code,
        cast(json_value(relationships, '$.person.data.id') as string) as pco_person_id,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
