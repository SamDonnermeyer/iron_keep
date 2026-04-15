with source as (
    select * from {{ source('planning_center', 'service_teams') }}
),

parsed as (
    select
        id as pco_service_team_id,
        cast(json_value(attributes, '$.name') as string) as team_name,
        cast(json_value(attributes, '$.rehearsal_team') as bool) as is_rehearsal_team,
        cast(json_value(attributes, '$.sequence') as int64) as sequence,
        cast(json_value(attributes, '$.schedule_to') as string) as schedule_to,
        cast(json_value(attributes, '$.default_status') as string) as default_status,
        cast(json_value(attributes, '$.default_prepare_notifications') as bool) as default_prepare_notifications,
        cast(json_value(attributes, '$.secure_team') as bool) as is_secure_team,
        cast(json_value(attributes, '$.assigned_directly') as bool) as assigned_directly,
        cast(json_value(relationships, '$.service_type.data.id') as string) as pco_service_type_id,
        timestamp(json_value(attributes, '$.archived_at')) as archived_at,
        timestamp(json_value(attributes, '$.deleted_at')) as deleted_at,
        timestamp(json_value(attributes, '$.created_at')) as created_at,
        timestamp(json_value(attributes, '$.updated_at')) as updated_at,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from parsed
