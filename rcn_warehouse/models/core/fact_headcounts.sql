-- Headcount fact table from PCO
-- Each row is a headcount for a specific attendance type and event time

with headcounts as (
    select
        pco_headcount_id,
        pco_attendance_type_id,
        pco_event_time_id,
        total,
        created_at,
        updated_at
    from {{ ref('stg_pco_headcounts') }}
)

select * from headcounts
