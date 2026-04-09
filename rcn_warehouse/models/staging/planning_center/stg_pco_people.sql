with source as (
    select * from {{ source('planning_center', 'people') }}
),

parsed as (
    select
        id as pco_person_id,
        cast(json_value(attributes, '$.first_name') as string) as first_name,
        cast(json_value(attributes, '$.last_name') as string) as last_name,
        cast(json_value(attributes, '$.name') as string) as full_name,
        cast(json_value(attributes, '$.nickname') as string) as nickname,
        cast(json_value(attributes, '$.given_name') as string) as given_name,
        cast(json_value(attributes, '$.middle_name') as string) as middle_name,
        cast(json_value(attributes, '$.gender') as string) as gender,
        cast(json_value(attributes, '$.membership') as string) as membership,
        cast(json_value(attributes, '$.status') as string) as status,
        cast(json_value(attributes, '$.birthdate') as date) as birthdate,
        cast(json_value(attributes, '$.anniversary') as date) as anniversary,
        cast(json_value(attributes, '$.grade') as int64) as grade,
        cast(json_value(attributes, '$.graduation_year') as int64) as graduation_year,
        cast(json_value(attributes, '$.school_type') as string) as school_type,
        cast(json_value(attributes, '$.child') as bool) as is_child,
        cast(json_value(attributes, '$.avatar') as string) as avatar_url,
        cast(json_value(attributes, '$.directory_status') as string) as directory_status,
        cast(json_value(attributes, '$.passed_background_check') as bool) as passed_background_check,
        timestamp(json_value(attributes, '$.inactivated_at')) as inactivated_at,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
