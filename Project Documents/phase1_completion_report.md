# Phase 1 Completion Report — Airbyte & dbt Setup

**Completed:** April 2026 (last updated 2026-04-09)
**Phase:** Extract/Load + Transform (ELT pipeline operational)

---

## Summary

Phase 1 of Operation Iron Keep established the complete ELT pipeline for Resonate Collegiate Network. Data now flows automatically from two church management platforms into BigQuery, is transformed into analytics-ready tables by dbt, and rebuilds daily on a schedule.

The result is a fully operational data warehouse with 41,000+ unified person records, attendance and headcount tracking, village/group metrics, and cross-platform identity resolution — all refreshed daily without manual intervention.

---

## What Was Accomplished

### 1. Airbyte — Extract & Load

Two custom connectors were built from scratch using the Airbyte Connector Builder (no pre-built connectors exist for church management platforms).

#### Planning Center Online (PCO) Connector

- **Auth:** OAuth2 (Authorization Code Flow)
- **Sync Schedule:** Daily at 3:00 AM
- **Sync Mode:** Incremental where supported (using `updated_at` cursor), Full Refresh for small lookup tables

PCO's API follows the JSON API 1.0 specification, which means all data arrives in a nested format with `id`, `type`, `attributes` (JSON blob), and `relationships` (JSON blob) columns. The dbt staging layer handles unpacking this structure.

**Streams configured:**

| Stream | BigQuery Table | Records | What It Contains |
|--------|---------------|---------|-----------------|
| People | `planning_center.people` | 31,643 | Every person in the system — names, birthdate, gender, membership status, grade, graduation year, background check status, active/inactive status |
| Campuses | `planning_center.campuses` | 16 | Each RCN campus location — name, address, city, state, coordinates, time zone, phone, contact email, website |
| Households | `planning_center.households` | 711 | Family/household groupings — household name, member count, primary contact |
| Check-Ins | `planning_center.check_ins` | 3,216 | Individual check-in records at events — person name, check-in kind (Regular/Volunteer), security code, guest flag, timestamps, linked person and event IDs |
| Check-In Events | `planning_center.check_in_events` | 28 | Event definitions for the check-in system — event name, frequency (one-time vs recurring), integration settings |
| Headcounts | `planning_center.headcounts` | 7,944 | Aggregate attendance counts per service time — total count, linked to attendance type and event time |
| Service Types | `planning_center.service_types` | 52 | Categories of services (Sunday morning, Wednesday night, special events, etc.) — name, frequency, scheduling details |
| Emails | `planning_center.emails` | — | Email addresses per person — address, primary flag, blocked flag. Critical for email-based identity matching |
| Phone Numbers | `planning_center.phone_numbers` | — | Phone numbers per person — number (e164, national, international formats), primary flag, carrier |
| Addresses | `planning_center.addresses` | — | Mailing addresses per person — street, city, state, zip, country, primary flag |
| Field Data | `planning_center.field_data` | ~52,000 | Custom field values in long format — field value linked to person and field definition |
| Field Definitions | `planning_center.field_definitions` | 36 | Custom field definitions — slug, name, data type. Used to pivot field_data into named columns |
| Plans | `planning_center.plans` | 4,840 | Service plans/worship services — title, series, dates, people/positions counts |
| Service Teams | `planning_center.service_teams` | 463 | Service team definitions (Band, Tech, Greeters, etc.) — name, type, linked to service type |

#### Engage Spaces Connector

- **Auth:** API Key (query parameter)
- **Base URL:** `resonate.engagespaces.com`
- **Sync Schedule:** Daily at 3:30 AM
- **Sync Mode:** Incremental where supported, Full Refresh for small tables

Engage Spaces data arrives in a flat column format (no JSON unpacking needed), but uses PascalCase column naming and numeric IDs for site references.

**Streams configured:**

| Stream | BigQuery Table | Records | What It Contains |
|--------|---------------|---------|-----------------|
| Users | `engage_spaces.users` | 12,250 | Members/participants — name, email (username), phone, address, site assignments, tags, belief status, relational status, discipleship context/generation, current groups and teams, group leader, last activity dates |
| Groups | `engage_spaces.groups` | 273 | Villages and small groups — name, type, tags, leader, leader-in-training, meeting day/time, site assignments, parent group, registration/automation settings |
| Courses | `engage_spaces.courses` | 19 | Training/discipleship courses — name, type, module counts, enrollment count, visibility, moderators |
| Events | `engage_spaces.events` | 207 | Events with attendance data — name, date, time, location, leaders, attendance counts, roster info, RSVP data |
| Teams | `engage_spaces.teams` | 110 | Serving/ministry teams — name, type, leader, meeting schedule, site assignments, parent team |
| Locations | `engage_spaces.locations` | 20 | Campus/site definitions — name, full name, address, parent locations (maps to PCO campuses by name) |

Additionally, 3 external tables exist in the `engage_spaces` dataset (`discipleship`, `dtl`, `harvest_report`, `village_attendance`) that were loaded outside of Airbyte.

#### BigQuery Destination

- **GCP Project:** `resonate-data-warehouse-442601`
- **Service Account:** `dbt-cloud@resonate-data-warehouse-442601.iam.gserviceaccount.com`
- **Airbyte metadata columns** added to every table: `_airbyte_raw_id` (unique row ID), `_airbyte_extracted_at` (sync timestamp), `_airbyte_meta` (sync metadata), `_airbyte_generation_id` (sync run)
- **Partitioning:** All tables are day-partitioned on `_airbyte_extracted_at`

---

### 2. dbt — Transform

The dbt project (`rcn_warehouse/`) reads from the raw Airbyte tables and produces analytics-ready tables through three layers. Each layer builds on the one below it.

**dbt Cloud project:** "Iron Keep" on `wz475.us1.dbt.com`
**Daily Build job:** Runs `dbt build` (all models + all tests) in the Production environment
**Git repo:** `github.com/SamDonnermeyer/iron_keep` (main branch)
**Project subdirectory:** `rcn_warehouse`

#### What Happens During a Daily Build

When the Daily Build job triggers, dbt Cloud executes these steps in order:

1. **Clone git repository** — Pulls the latest `main` branch from GitHub
2. **Create profile from connection** — Generates a BigQuery connection profile using the service account configured in dbt Cloud
3. **`dbt deps`** — Installs any dbt packages (none currently, but the step runs regardless)
4. **`dbt build`** — Runs all models in dependency order, then runs all tests

The model execution order follows the DAG (directed acyclic graph) — staging views first, then core tables, then marts:

```
Staging (20 views) → Core (15 tables) → Marts (4 tables) → Tests (33)
```

---

#### Staging Layer — `core_staging` dataset

**Materialization:** Views (no data stored; queries pass through to raw tables)
**Purpose:** Create a clean, consistently-named interface on top of the raw Airbyte data. This is the only layer that touches the source tables directly — everything downstream references staging views.

##### Planning Center staging models (14 views)

These models extract fields from PCO's nested JSON structure (`attributes` and `relationships` columns) into flat, typed columns.

**`stg_pco_people`** — Extracts person fields from the `attributes` JSON blob.
- Outputs: `pco_person_id`, `first_name`, `last_name`, `full_name`, `nickname`, `gender`, `membership`, `status` (active/inactive), `birthdate`, `anniversary`, `grade`, `graduation_year`, `school_type`, `is_child`, `directory_status`, `passed_background_check`, `created_at`, `updated_at`
- This is the largest and most critical staging model — it's the foundation for the unified person dimension

**`stg_pco_campuses`** — Extracts campus/location details.
- Outputs: `pco_campus_id`, `campus_name`, `city`, `state`, `country`, `street`, `zip`, `phone_number`, `contact_email`, `website`, `time_zone`, `latitude`, `longitude`, `church_center_enabled`

**`stg_pco_households`** — Extracts household groupings.
- Outputs: `pco_household_id`, `household_name`, `member_count`, `primary_contact_id`, `primary_contact_name`

**`stg_pco_check_ins`** — Extracts check-in details and parses relationship IDs from the `relationships` JSON to link each check-in to a person and event.
- Outputs: `pco_check_in_id`, `first_name`, `last_name`, `kind` (Regular/Volunteer), `check_in_number`, `is_one_time_guest`, `confirmed_at`, `checked_out_at`, `pco_person_id`, `pco_event_id`, `pco_event_period_id`

**`stg_pco_check_in_events`** — Extracts event definitions for the check-in system.
- Outputs: `pco_check_in_event_id`, `event_name`, `frequency`, `enable_services_integration`, `pre_select_enabled`, `location_times_enabled`, `integration_key`, `archived_at`

**`stg_pco_headcounts`** — Extracts headcount totals and parses relationship references.
- Outputs: `pco_headcount_id`, `total`, `pco_attendance_type_id`, `pco_event_time_id`

**`stg_pco_service_types`** — Extracts service type definitions.
- Outputs: `pco_service_type_id`, `service_type_name`, `frequency`, `sequence`, `last_plan_from`, `archived_at`, `deleted_at`

**`stg_pco_emails`** — Extracts email addresses linked to people via relationships JSON.
- Outputs: `pco_email_id`, `email_address`, `is_primary`, `is_blocked`, `pco_person_id`, `created_at`, `updated_at`
- Critical for email-based identity resolution in `bridge_person_identity`

**`stg_pco_phone_numbers`** — Extracts phone numbers with multiple format fields.
- Outputs: `pco_phone_id`, `phone_number`, `carrier`, `is_primary`, `e164`, `national`, `international`, `pco_person_id`, `created_at`, `updated_at`

**`stg_pco_addresses`** — Extracts mailing addresses linked to people.
- Outputs: `pco_address_id`, `street_line_1`, `street_line_2`, `city`, `state`, `zip`, `country_name`, `is_primary`, `pco_person_id`, `created_at`, `updated_at`

**`stg_pco_field_data`** — Extracts custom field values from long-format table, linked to person and field definition via relationships JSON.
- Outputs: `pco_field_data_id`, `field_value`, `pco_person_id`, `pco_field_definition_id`, `created_at`, `updated_at`

**`stg_pco_field_definitions`** — Extracts custom field definitions (36 total).
- Outputs: `pco_field_definition_id`, `slug`, `field_name`, `data_type`, `config`, `sequence`, `deleted_at`, `created_at`, `updated_at`

**`stg_pco_plans`** — Extracts service plans/worship services linked to service types.
- Outputs: `pco_plan_id`, `pco_service_type_id`, `title`, `series_title`, `dates`, `sort_date`, `last_time_at`, `items_count`, `plan_people_count`, `needed_positions_count`, `service_time_count`, `total_length`, `is_multi_day`, `is_public`, `planning_center_url`, `created_at`, `updated_at`

**`stg_pco_service_teams`** — Extracts service team definitions linked to service types.
- Outputs: `pco_service_team_id`, `pco_service_type_id`, `team_name`, `is_rehearsal_team`, `sequence`, `schedule_to`, `default_status`, `is_secure_team`, `assigned_directly`, `archived_at`, `deleted_at`, `created_at`, `updated_at`

##### Engage Spaces staging models

These models rename PascalCase columns to snake_case and cast ID fields to strings for consistency. No JSON parsing needed — ES data is already flat.

**`stg_es_users`** — Renames and standardizes the user/member table.
- Outputs: `es_user_id`, `first_name`, `last_name`, `username` (email), `user_type`, `phone`, `city`, `state_province`, `country`, `address_line_1/2`, `zip_postal_code`, `site`, `tags`, `demographic`, `belief_status`, `relational_status`, `marital_status`, `discipleship_context`, `discipleship_generation`, `current_groups`, `current_teams`, `group_id`, `group_leader`, `last_village_activity`, `last_discipleship_activity`

**`stg_es_groups`** — Renames the groups/villages table.
- Outputs: `es_group_id`, `group_name`, `group_type`, `group_tags`, `description`, `leader`, `leader_in_training`, `weekday`, `meeting_time`, `sites`, `parent_group`, `leadership_groups`, `visibility`

**`stg_es_courses`** — Renames the training courses table.
- Outputs: `es_course_id`, `course_name`, `course_type`, `tags`, `number_of_modules`, `number_of_enrollments`, `course_visibility`, `disabled`

**`stg_es_events`** — Renames the events table.
- Outputs: `es_event_id`, `event_name`, `event_date`, `start_time`, `tags`, `sites`, `event_leaders`, `attendance`, `attendance_counts`, `roster_size`, `visibility`

**`stg_es_teams`** — Renames the teams table.
- Outputs: `es_team_id`, `team_name`, `team_type`, `team_tags`, `leader`, `weekday`, `sites`, `parent_team`, `visibility`, `disabled`

**`stg_es_locations`** — Renames the locations/sites table. These location IDs are referenced by users, groups, events, and teams via their `sites` column.
- Outputs: `es_location_id`, `location_name`, `full_name`, `address`, `hidden`, `disabled`, `restricted`, `parent_locations`

---

#### Core Layer — `core_core` dataset

**Materialization:** Tables (data is stored and rebuilt on each run)
**Purpose:** Business logic, cross-platform joins, and dimensional modeling. This is where identity resolution happens and where raw platform data becomes a unified data model.

##### Dimension tables

**`dim_person`** (~41,700 rows) — The unified person dimension. This is the central table of the entire warehouse.
- Combines all PCO people with ES users into a single table
- PCO people are enriched with: primary email, phone, and address from PCO; 22 pivoted custom fields (baptism, school year, demographic, ownership dates, leadership assignments, etc.); ES data (belief status, discipleship context, group info) when matched
- ES-only people (no PCO match) are included with `primary_source = 'es_only'`
- Each record includes `es_match_method` (email/name) and `es_match_confidence` (exact/likely/ambiguous/null)
- See `identity_resolution.md` for full details on how matching works

**`dim_campus`** (16 rows) — Campus dimension joining PCO campuses with ES locations.
- PCO campuses are the primary source (they have full address, coordinates, contact info)
- ES locations are matched by campus name (e.g., PCO "Pullman" ↔ ES location ID `145553` "Pullman")
- Outputs both `pco_campus_id` and `es_location_id` for cross-referencing

**`dim_group`** (273 rows) — Villages and small groups from Engage Spaces.
- Includes group type, tags, leader, leader-in-training, meeting schedule, site assignments
- Used by `mart_village_summary` for village-level reporting

**`dim_team`** (110 rows) — Serving and ministry teams from Engage Spaces.
- Includes team type, leader, schedule, site assignments, parent team hierarchy

**`dim_course`** (19 rows) — Training/discipleship courses from Engage Spaces.
- Includes module counts, enrollment counts, moderators, course type

**`dim_household`** (711 rows) — Household/family groupings from PCO.
- Includes household name, member count, and primary contact reference

**`dim_check_in_event`** (28 rows) — Check-in event definitions from PCO.
- Includes event name, frequency (one-time vs recurring), integration settings

**`dim_service_type`** (52 rows) — Service type definitions from PCO.
- Includes service type name, scheduling frequency, archive/delete status

**`dim_plan`** (4,840 rows) — Service plans/worship services from PCO.
- Includes title, series title, dates, people/positions counts, linked to service type
- Staging for future serving analysis when `plan_people` stream is added

**`dim_service_team`** (463 rows) — Service team definitions from PCO.
- Team definitions within the services module (Band, Tech, Greeters, etc.)
- Includes rehearsal/secure flags, scheduling settings, linked to service type

##### Fact tables

**`fact_check_ins`** (3,216 rows) — Individual check-in records from PCO.
- Each row is one person checking in at one event
- Includes `kind` (Regular or Volunteer), `is_one_time_guest` flag, confirmation and checkout timestamps
- Links to `dim_person` via `pco_person_id` and to `dim_check_in_event` via `pco_event_id`

**`fact_headcounts`** (7,944 rows) — Aggregate headcount records from PCO.
- Each row is a headcount total for a specific attendance type at a specific event time
- Used by `mart_attendance_trends` for weekly attendance reporting
- Links to attendance types and event times via relationship IDs

**`fact_es_events`** (207 rows) — Event records with attendance from Engage Spaces.
- Each row is an event with attendance counts, roster size, and leader info
- Includes event date, time, location, and tags

##### Intermediate tables

**`int_pco_person_custom_fields`** (~24,800 rows) — Pivots PCO's long-format custom field data into one row per person with 22 named columns.
- Joins `stg_pco_field_data` to `stg_pco_field_definitions` on slug
- Uses `max(case when slug = 'X' then field_value end)` pattern to pivot
- Fields include: `is_baptized`, `baptism_date`, `baptism_site`, `school_year`, `demographic`, `major`, `ownership_start_date`, `ownership_end_date`, `village_leaders`, `huddle_leader`, `serving`, `discipleship_type`, `staff_role`, and more

##### Identity resolution

**`bridge_person_identity`** (~2,300 rows) — The cross-platform matching table.
- **Pass 1 (email):** Matches PCO people to ES users by email address (PCO primary email = ES username). These get `match_method = 'email'` and `match_confidence = 'exact'`.
- **Pass 2 (name):** For remaining unmatched people, joins on normalized (lowercased, trimmed) first name + last name. Assigns `match_method = 'name'` and confidence: `exact` (unique in both systems), `likely` (unique in one), `ambiguous` (duplicates in both).
- `dim_person` selects the best match per PCO person (preferring email > name, then exact > likely > ambiguous)

---

#### Marts Layer — `core_marts` dataset

**Materialization:** Tables (rebuilt on each run)
**Purpose:** Pre-aggregated, reporting-ready tables designed for specific leadership audiences. These are the tables that dashboards and reports should query.

**`mart_person_engagement`** (~41,700 rows) — Per-person engagement scorecard.
- One row per person (same grain as `dim_person`)
- Combines identity fields with aggregated check-in metrics: `total_check_ins`, `check_in_days`, `regular_check_ins`, `volunteer_check_ins`, `first_check_in_at`, `last_check_in_at`, `days_since_last_check_in`
- Includes PCO contact info (`pco_email`, `pco_phone`, `pco_city`, `pco_state`)
- Includes 22 PCO custom fields: baptism info, school year, demographic, major, ownership dates, village leaders, huddle leader, serving, discipleship type, staff role
- Includes ES engagement data: `belief_status`, `discipleship_context`, `es_current_groups`, `es_group_leader`, `last_village_activity`, `last_discipleship_activity`
- **Audience:** Village Leaders ("How are my 12 people engaging?"), Village Coaches ("Who needs attention?")

**`mart_campus_summary`** (16 rows) — Campus-level overview.
- One row per campus
- Includes location details (city, state, contact info) and a count of ES groups associated with each campus
- Groups are attributed to campuses by matching the group's `sites` field to ES location IDs
- **Audience:** Local Pastors ("How is my campus doing?")

**`mart_village_summary`** (273 rows) — Village/group-level health metrics.
- One row per village/group
- Includes leader, leader-in-training, meeting schedule, primary campus (derived from first site ID), and a member count (derived by matching ES user `current_groups` against group names)
- **Audience:** Village Coaches ("Which villages need attention?"), Local Pastors

**`mart_attendance_trends`** (198 rows) — Weekly attendance time series.
- One row per week (Monday start)
- Combines PCO headcount totals with PCO check-in counts: `total_attendance` (from headcounts), `unique_check_in_people`, `regular_check_ins`, `volunteer_check_ins`, `one_time_guests`
- **Audience:** Local Pastors ("What's our attendance trend?"), Network/CBE leadership ("Network-wide attendance this year?")

---

#### Tests (33 total)

Every primary key across all core and mart models is tested for:
- **`unique`** — No duplicate values (ensures dimensional integrity)
- **`not_null`** — No missing values (ensures every record has an identifier)

The bridge table tests `not_null` on both `pco_person_id` and `es_user_id` (uniqueness is not tested here because it's intentionally many-to-many).

All 33 tests run as part of `dbt build` during the Daily Build. If any test fails, the dbt Cloud run will report an error.

---

## Daily Operation

Once the pipeline is fully operational, the daily cycle is:

| Time | System | Action |
|------|--------|--------|
| 3:00 AM | Airbyte | PCO sync runs — pulls new/updated records into `planning_center.*` |
| 3:30 AM | Airbyte | ES sync runs — pulls new/updated records into `engage_spaces.*` |
| ~4:00 AM | Airbyte | Both syncs complete |
| 6:00 AM | dbt Cloud | Daily Build triggers — rebuilds all staging views, core tables, and mart tables, then runs all 33 tests |
| ~6:02 AM | dbt Cloud | Build completes (~30 seconds of BigQuery processing) |
| Morning | Users | Fresh data available for reporting and analysis |

No manual intervention required. If something fails, dbt Cloud sends a notification.
