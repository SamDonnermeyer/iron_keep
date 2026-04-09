with source as (
    select * from {{ source('engage_spaces', 'courses') }}
),

renamed as (
    select
        cast(ID as string) as es_course_id,
        Name as course_name,
        Body as body,
        CourseType as course_type,
        Tags as tags,
        Sites as sites,
        Moderators as moderators,
        cast(NumberOfModules as int64) as number_of_modules,
        cast(NumberOfTotalModules as int64) as number_of_total_modules,
        cast(NumberOfOptionalModules as int64) as number_of_optional_modules,
        cast(NumberOfEnrollments as int64) as number_of_enrollments,
        cast(CourseVisibility as int64) as course_visibility,
        SequenceModules as sequence_modules,
        Disabled as disabled,
        HidePreview as hide_preview,
        DisableAutoComplete as disable_auto_complete,
        DisableCourseNotifications as disable_course_notifications,
        HighlightCourseOnHomePage as highlight_on_home_page,
        StartDate as start_date,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
