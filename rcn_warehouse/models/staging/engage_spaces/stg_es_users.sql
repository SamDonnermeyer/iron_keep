with source as (
    select * from {{ source('engage_spaces', 'users') }}
),

renamed as (
    select
        cast(ID as string) as es_user_id,
        FirstName as first_name,
        LastName as last_name,
        UserName as username,
        cast(UserType as int64) as user_type,
        Phone as phone,
        City as city,
        State_Province as state_province,
        Country as country,
        Address_Line_1 as address_line_1,
        Address_Line_2 as address_line_2,
        Zip_Postal_Code as zip_postal_code,
        Site as site,
        Tags as tags,
        Demographic as demographic,
        Belief_Status as belief_status,
        Relational_Status as relational_status,
        Marital_Status as marital_status,
        Discipleship_Context as discipleship_context,
        Discipleship_Generation as discipleship_generation,
        CurrentGroups as current_groups,
        CurrentTeams as current_teams,
        Group_ID as group_id,
        Group_Leader as group_leader,
        Last_Village_Activity as last_village_activity,
        Last_Discipleship_Activity as last_discipleship_activity,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
