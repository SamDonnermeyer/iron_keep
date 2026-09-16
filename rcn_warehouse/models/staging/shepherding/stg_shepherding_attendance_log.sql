with source as (
    select * from {{ source('shepherding', 'attendance_log') }}
),

renamed as (
    select
        {{ sheet_string('submission_id') }} as submission_id,
        {{ sheet_string('village_id') }} as village_id,
        {{ sheet_string('person_local_id') }} as person_local_id,
        -- Name as it appeared on the form at submission time. Kept for audit;
        -- the current name lives on dim_village_member.
        {{ sheet_string('person_name') }} as person_name_at_submission,
        coalesce({{ sheet_int('attended_flag') }} = 1, false) as attended_flag,
        {{ sheet_timestamp('loaded_at') }} as loaded_at
    from source
    where {{ sheet_string('submission_id') }} is not null
      and {{ sheet_string('person_local_id') }} is not null
)

select * from renamed
