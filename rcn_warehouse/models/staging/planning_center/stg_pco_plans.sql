with source as (
    select * from {{ source('planning_center', 'plans') }}
),

parsed as (
    select
        id as pco_plan_id,
        cast(json_value(attributes, '$.title') as string) as title,
        cast(json_value(attributes, '$.series_title') as string) as series_title,
        cast(json_value(attributes, '$.dates') as string) as dates,
        cast(json_value(attributes, '$.short_dates') as string) as short_dates,
        timestamp(json_value(attributes, '$.sort_date')) as sort_date,
        timestamp(json_value(attributes, '$.last_time_at')) as last_time_at,
        cast(json_value(attributes, '$.items_count') as int64) as items_count,
        cast(json_value(attributes, '$.plan_people_count') as int64) as plan_people_count,
        cast(json_value(attributes, '$.needed_positions_count') as int64) as needed_positions_count,
        cast(json_value(attributes, '$.plan_notes_count') as int64) as plan_notes_count,
        cast(json_value(attributes, '$.service_time_count') as int64) as service_time_count,
        cast(json_value(attributes, '$.rehearsal_time_count') as int64) as rehearsal_time_count,
        cast(json_value(attributes, '$.total_length') as int64) as total_length,
        cast(json_value(attributes, '$.multi_day') as bool) as is_multi_day,
        cast(json_value(attributes, '$.public') as bool) as is_public,
        cast(json_value(attributes, '$.planning_center_url') as string) as planning_center_url,
        cast(json_value(relationships, '$.service_type.data.id') as string) as pco_service_type_id,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
