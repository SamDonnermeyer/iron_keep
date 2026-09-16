with source as (
    select * from {{ source('shepherding', 'villages') }}
),

renamed as (
    select
        {{ sheet_string('village_id') }} as village_id,
        {{ sheet_string('church_code') }} as church_code,
        {{ sheet_string('village_name') }} as village_name,
        {{ sheet_string('tab_name') }} as tab_name,
        {{ sheet_string('leader_names') }} as leader_names,
        -- Google Forms item IDs; operational plumbing, kept for traceability
        {{ sheet_string('page_item_id') }} as page_item_id,
        {{ sheet_string('checkbox_item_id') }} as checkbox_item_id,
        {{ sheet_string('correction_item_id') }} as correction_item_id,
        {{ sheet_string('newnames_item_id') }} as newnames_item_id,
        lower({{ sheet_string('status') }}) as status,
        {{ sheet_date('created_at') }} as created_date,
        {{ sheet_string('academic_year') }} as academic_year
    from source
    where {{ sheet_string('village_id') }} is not null
)

select * from renamed
