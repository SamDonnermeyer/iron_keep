-- Event fact table from Engage Spaces
-- Each row is an event with attendance data

with events as (
    select
        es_event_id,
        event_name,
        event_date,
        start_time,
        tags,
        sites,
        address,
        event_leaders,
        attendance,
        attendance_counts,
        roster_size,
        roster_percent,
        visibility,
        created,
        last_updated
    from {{ ref('stg_es_events') }}
)

select * from events
