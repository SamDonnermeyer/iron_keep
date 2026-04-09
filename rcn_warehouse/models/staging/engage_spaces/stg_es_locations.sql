with source as (
    select * from {{ source('engage_spaces', 'locations') }}
),

renamed as (
    select
        cast(ID as string) as es_location_id,
        Name as location_name,
        FullName as full_name,
        Address as address,
        Color as color,
        Hidden as hidden,
        Disabled as disabled,
        Restricted as restricted,
        ParentLocations as parent_locations,
        LastUpdated as last_updated,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
)

select * from renamed
