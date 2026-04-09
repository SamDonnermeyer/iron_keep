with source as (
    select * from {{ source('engage_spaces', 'groups') }}
),

renamed as (
    select
        cast(ID as string) as es_group_id,
        Name as group_name,
        GroupType as group_type,
        GroupTags as group_tags,
        Description as description,
        Leader as leader,
        Leader_in_Training as leader_in_training,
        Address as address,
        WeekDay as weekday,
        Time as meeting_time,
        Sites as sites,
        Emails as emails,
        ParentGroup as parent_group,
        LeadershipGroups as leadership_groups,
        cast(Visibility as int64) as visibility,
        UserTypeDefault as user_type_default,
        DisplayOnHomeScreen as display_on_home_screen,
        DisableRegistrations as disable_registrations,
        DisableAutomations as disable_automations,
        Created as created,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
