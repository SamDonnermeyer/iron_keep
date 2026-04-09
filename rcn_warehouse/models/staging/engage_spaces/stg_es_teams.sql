with source as (
    select * from {{ source('engage_spaces', 'teams') }}
),

renamed as (
    select
        cast(ID as string) as es_team_id,
        Name as team_name,
        Type as team_type_name,
        TeamType as team_type,
        TeamTags as team_tags,
        Tags as tags,
        Description as description,
        Leader as leader,
        Address as address,
        WeekDay as weekday,
        Sites as sites,
        ParentTeam as parent_team,
        cast(Visibility as int64) as visibility,
        UserTypeDefault as user_type_default,
        Disabled as disabled,
        DisableReports as disable_reports,
        DisableAutomations as disable_automations,
        DisableRegistrations as disable_registrations,
        DisplayOnHomeScreen as display_on_home_screen,
        SignUpButtonText as sign_up_button_text,
        Created as created,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
