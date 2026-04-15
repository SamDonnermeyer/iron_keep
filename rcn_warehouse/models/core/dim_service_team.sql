-- Service team dimension from PCO
-- Team definitions within the services module (band, tech, greeters, etc.)

with service_teams as (
    select
        pco_service_team_id,
        pco_service_type_id,
        team_name,
        is_rehearsal_team,
        sequence,
        schedule_to,
        default_status,
        is_secure_team,
        assigned_directly,
        archived_at,
        deleted_at,
        created_at,
        updated_at
    from {{ ref('stg_pco_service_teams') }}
)

select * from service_teams
