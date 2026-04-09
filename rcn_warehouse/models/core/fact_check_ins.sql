-- Check-in fact table from PCO
-- Each row is a single person check-in at an event

with check_ins as (
    select
        pco_check_in_id,
        pco_person_id,
        pco_event_id,
        pco_event_period_id,
        first_name,
        last_name,
        kind,
        check_in_number,
        is_one_time_guest,
        confirmed_at,
        checked_out_at,
        created_at,
        updated_at
    from {{ ref('stg_pco_check_ins') }}
)

select * from check_ins
