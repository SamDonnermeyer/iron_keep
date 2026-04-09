-- Unified campus dimension from PCO campuses and ES locations
-- PCO is the primary source; ES locations are mapped via name matching

with pco_campuses as (
    select
        pco_campus_id,
        campus_name,
        city,
        state,
        country,
        street,
        zip,
        phone_number,
        contact_email,
        website,
        time_zone,
        latitude,
        longitude,
        church_center_enabled,
        created_at,
        updated_at
    from {{ ref('stg_pco_campuses') }}
),

es_locations as (
    select
        es_location_id,
        location_name,
        full_name
    from {{ ref('stg_es_locations') }}
),

joined as (
    select
        pco.pco_campus_id,
        es.es_location_id,
        pco.campus_name,
        pco.city,
        pco.state,
        pco.country,
        pco.street,
        pco.zip,
        pco.phone_number,
        pco.contact_email,
        pco.website,
        pco.time_zone,
        pco.latitude,
        pco.longitude,
        pco.church_center_enabled,
        pco.created_at,
        pco.updated_at
    from pco_campuses pco
    left join es_locations es
        on lower(pco.campus_name) = lower(es.location_name)
)

select * from joined
