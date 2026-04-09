-- Course dimension from Engage Spaces

with courses as (
    select
        es_course_id,
        course_name,
        body,
        course_type,
        tags,
        sites,
        moderators,
        number_of_modules,
        number_of_total_modules,
        number_of_optional_modules,
        number_of_enrollments,
        course_visibility,
        disabled,
        start_date,
        last_updated
    from {{ ref('stg_es_courses') }}
)

select * from courses
