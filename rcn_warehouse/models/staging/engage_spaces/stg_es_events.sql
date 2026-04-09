with source as (
    select * from {{ source('engage_spaces', 'events') }}
),

renamed as (
    select
        cast(ID as string) as es_event_id,
        Name as event_name,
        Date as event_date,
        StartTime as start_time,
        Tags as tags,
        Sites as sites,
        Address as address,
        EventLeaders as event_leaders,
        Attendance as attendance,
        AttendenceCounts as attendance_counts,
        RosterSize as roster_size,
        RosterPercent as roster_percent,
        cast(Visibility as int64) as visibility,
        ExternalLink as external_link,
        LinkDescription as link_description,
        DisplayOnHomeScreen as display_on_home_screen,
        IncludeEventTimeInDisplay as include_event_time_in_display,
        Created as created,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
