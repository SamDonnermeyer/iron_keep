with source as (
    select * from {{ source('planning_center', 'campuses') }}
),

parsed as (
    select
        id as pco_campus_id,
        cast(json_value(attributes, '$.name') as string) as campus_name,
        cast(json_value(attributes, '$.city') as string) as city,
        cast(json_value(attributes, '$.state') as string) as state,
        cast(json_value(attributes, '$.country') as string) as country,
        cast(json_value(attributes, '$.street') as string) as street,
        cast(json_value(attributes, '$.zip') as string) as zip,
        cast(json_value(attributes, '$.phone_number') as string) as phone_number,
        cast(json_value(attributes, '$.contact_email_address') as string) as contact_email,
        cast(json_value(attributes, '$.website') as string) as website,
        cast(json_value(attributes, '$.time_zone') as string) as time_zone,
        cast(json_value(attributes, '$.latitude') as float64) as latitude,
        cast(json_value(attributes, '$.longitude') as float64) as longitude,
        cast(json_value(attributes, '$.church_center_enabled') as bool) as church_center_enabled,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
