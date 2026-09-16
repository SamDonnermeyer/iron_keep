with source as (
    select * from {{ source('shepherding', 'submissions') }}
),

renamed as (
    select
        {{ sheet_string('submission_id') }} as submission_id,
        {{ sheet_string('village_id') }} as village_id,
        {{ sheet_string('church_code') }} as church_code,
        {{ sheet_date('gathering_date') }} as gathering_date,
        {{ sheet_string('gathering_type') }} as gathering_type,
        {{ sheet_string('activity_label') }} as activity_label,
        {{ sheet_int('guest_count') }} as guest_count,
        -- Headcount as reported by the form; reconciled against the detail rows
        -- in fact_village_submission.
        {{ sheet_int('attendee_count') }} as reported_attendee_count,
        lower({{ sheet_string('submitted_by') }}) as submitted_by,
        {{ sheet_timestamp('submitted_at') }} as submitted_at,
        {{ sheet_timestamp('processed_at') }} as processed_at,
        lower({{ sheet_string('status') }}) as status
    from source
    where {{ sheet_string('submission_id') }} is not null
)

select * from renamed
