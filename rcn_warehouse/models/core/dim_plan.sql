-- Service plan dimension from PCO
-- Individual worship services/events with scheduling info

with plans as (
    select
        pco_plan_id,
        pco_service_type_id,
        title,
        series_title,
        dates,
        short_dates,
        sort_date,
        last_time_at,
        items_count,
        plan_people_count,
        needed_positions_count,
        service_time_count,
        rehearsal_time_count,
        total_length,
        is_multi_day,
        is_public,
        planning_center_url,
        created_at,
        updated_at
    from {{ ref('stg_pco_plans') }}
)

select * from plans
