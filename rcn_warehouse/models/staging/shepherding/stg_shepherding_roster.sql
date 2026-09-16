with source as (
    select * from {{ source('shepherding', 'roster') }}
),

renamed as (
    select
        {{ sheet_string('person_local_id') }} as person_local_id,
        {{ sheet_string('village_id') }} as village_id,
        {{ sheet_string('display_name') }} as display_name,
        -- The exact string shown in the form checkbox; unique within a village
        {{ sheet_string('choice_label') }} as choice_label,
        lower({{ sheet_string('completeness') }}) as name_completeness,
        -- NOTE: first_seen_at is when the roster row was written by the script,
        -- not when the person joined. It frequently lands a day or two AFTER a
        -- gathering the person actually attended, because the form is processed
        -- on a sweep. Do not use it alone as a membership start date — see
        -- int_shepherding_membership_window.
        {{ sheet_date('first_seen_at') }} as first_seen_date,
        {{ sheet_date('retired_at') }} as retired_date,
        {{ sheet_string('superseded_by') }} as superseded_by
    from source
    where {{ sheet_string('person_local_id') }} is not null
)

select * from renamed
