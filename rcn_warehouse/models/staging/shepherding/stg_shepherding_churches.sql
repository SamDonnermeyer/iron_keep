with source as (
    select * from {{ source('shepherding', 'churches') }}
),

renamed as (
    select
        {{ sheet_string('church_code') }} as church_code,
        {{ sheet_string('church_name') }} as church_name,
        {{ sheet_int('church_sk') }} as church_sk,
        {{ sheet_string('workbook_id') }} as workbook_id,
        {{ sheet_string('form_id') }} as form_id,
        {{ sheet_string('form_url') }} as form_url,
        {{ sheet_string('church_email') }} as church_email,
        {{ sheet_string('church_pastor_email') }} as church_pastor_email,
        {{ sheet_string('church_manager_email') }} as church_manager_email,
        {{ sheet_date('school_year_start_date') }} as school_year_start_date,
        {{ sheet_string('template_version') }} as template_version,
        {{ sheet_timestamp('last_response_at') }} as last_response_at,
        lower({{ sheet_string('status') }}) as status,
        {{ sheet_timestamp('created_at') }} as created_at
    from source
    -- The Churches tab is padded to 1,000 blank rows in the workbook
    where {{ sheet_string('church_code') }} is not null
)

select * from renamed
