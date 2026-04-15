# Operation Iron Keep — Pipeline Status & Next Steps

**Last Updated:** 2026-04-09

---

## Pipeline Architecture

```
┌─────────────────────┐     ┌─────────────────────┐
│  Planning Center     │     │  Engage Spaces       │
│  (PCO - REST API)    │     │  (ES - REST API)     │
└────────┬────────────┘     └────────┬────────────┘
         │                           │
         │    ┌──────────────┐       │
         └───►│   Airbyte    │◄──────┘
              │  (Cloud)     │
              └──────┬───────┘
                     │
              ┌──────▼───────┐
              │   BigQuery   │
              │  (Raw Data)  │
              │  planning_center, engage_spaces
              └──────┬───────┘
                     │
              ┌──────▼───────┐
              │     dbt      │
              │  (Transform) │
              │  core_staging → core_core → core_marts
              └──────┬───────┘
                     │
              ┌──────▼───────┐
              │  Reporting   │
              │  (TBD)       │
              └──────────────┘
```

**Future additions to Extract/Load:**

```
Pushpay ─────────►  Airbyte  ──► BigQuery    (credentials needed)
ServiceReef ─────►  Airbyte  ──► BigQuery    (credentials needed)
Subsplash ───► Snowflake ──► Airbyte ──► BigQuery  (credentials needed)
```

---

## What Has Been Built

### 1. Extract & Load (Airbyte → BigQuery)

Two Airbyte custom connectors are live and syncing daily to BigQuery:

**Planning Center Online (PCO)** — OAuth2, daily sync at 3:00 AM

| Raw Table | Rows | Description |
|-----------|------|-------------|
| `planning_center.people` | 31,643 | People records (JSON API format) |
| `planning_center.campuses` | 16 | Campus/location records |
| `planning_center.households` | 711 | Household groupings |
| `planning_center.check_ins` | 3,216 | Individual check-in records |
| `planning_center.check_in_events` | 28 | Check-in event definitions |
| `planning_center.headcounts` | 7,944 | Headcount records for services |
| `planning_center.service_types` | 52 | Service type definitions |
| `planning_center.emails` | — | Email addresses per person |
| `planning_center.phone_numbers` | — | Phone numbers per person |
| `planning_center.addresses` | — | Mailing addresses per person |
| `planning_center.field_data` | ~52,000 | Custom field values (long format) |
| `planning_center.field_definitions` | 36 | Custom field definitions |
| `planning_center.plans` | 4,840 | Service plans/worship services |
| `planning_center.service_teams` | 463 | Service team definitions (Band, Tech, etc.) |

**Engage Spaces (ES)** — API Key, daily sync at 3:30 AM

| Raw Table | Rows | Description |
|-----------|------|-------------|
| `engage_spaces.users` | 12,250 | User/member records |
| `engage_spaces.groups` | 273 | Group/village records |
| `engage_spaces.courses` | 19 | Training courses |
| `engage_spaces.events` | 207 | Event records |
| `engage_spaces.teams` | 110 | Team records |
| `engage_spaces.locations` | 20 | Site/location records |

Additionally, Engage Spaces has 3 external tables (`discipleship`, `dtl`, `harvest_report`, `village_attendance`) loaded outside of Airbyte.

**Not yet connected:** Pushpay, ServiceReef, Subsplash (credentials pending).

---

### 2. Transform (dbt → BigQuery)

The dbt project (`rcn_warehouse/`) transforms raw Airbyte data through three layers:

#### Staging Layer — `core_staging` dataset (20 views)

Light transformations: JSON extraction for PCO tables, column renaming for ES tables. No business logic.

| Model | Source | What It Does |
|-------|--------|-------------|
| `stg_pco_people` | PCO | Extracts 20+ fields from `attributes` JSON blob |
| `stg_pco_campuses` | PCO | Extracts campus details (name, city, state, coordinates) |
| `stg_pco_households` | PCO | Extracts household name, member count, primary contact |
| `stg_pco_check_ins` | PCO | Extracts check-in details + person/event IDs from `relationships` JSON |
| `stg_pco_check_in_events` | PCO | Extracts event definitions (name, frequency, integrations) |
| `stg_pco_headcounts` | PCO | Extracts headcount totals + attendance type/event time references |
| `stg_pco_service_types` | PCO | Extracts service type names and scheduling info |
| `stg_pco_emails` | PCO | Extracts email addresses with primary/blocked flags, linked to person |
| `stg_pco_phone_numbers` | PCO | Extracts phone numbers with primary flag, carrier, multiple formats |
| `stg_pco_addresses` | PCO | Extracts mailing addresses with primary flag, linked to person |
| `stg_pco_field_data` | PCO | Extracts custom field values linked to person and field definition |
| `stg_pco_field_definitions` | PCO | Extracts custom field definitions (slug, name, data type) |
| `stg_pco_plans` | PCO | Extracts service plans with dates, people counts, linked to service type |
| `stg_pco_service_teams` | PCO | Extracts service team definitions linked to service types |
| `stg_es_users` | ES | Renames columns to snake_case (already flat) |
| `stg_es_groups` | ES | Renames group columns |
| `stg_es_courses` | ES | Renames course columns |
| `stg_es_events` | ES | Renames event columns |
| `stg_es_teams` | ES | Renames team columns |
| `stg_es_locations` | ES | Renames location columns |

#### Core Layer — `core_core` dataset (14 tables)

Dimension and fact tables with business logic, cross-platform joins, and identity resolution.

**Dimensions:**

| Model | Rows | Description |
|-------|------|-------------|
| `dim_person` | ~41,700 | Unified person record across PCO + ES. Enriched with PCO email/phone/address, 22 pivoted custom fields, and ES data. See `identity_resolution.md` for details. |
| `dim_campus` | 16 | Campus dimension joining PCO campuses with ES locations by name |
| `dim_group` | 273 | Villages/groups from Engage Spaces with type, leader, schedule |
| `dim_team` | 110 | Teams from Engage Spaces |
| `dim_course` | 19 | Training courses from Engage Spaces |
| `dim_household` | 711 | Household groupings from PCO |
| `dim_check_in_event` | 28 | Check-in event definitions from PCO |
| `dim_service_type` | 52 | Service type definitions from PCO |
| `dim_plan` | 4,840 | Service plans/worship services from PCO |
| `dim_service_team` | 463 | Service team definitions (Band, Tech, etc.) from PCO |

**Facts:**

| Model | Rows | Description |
|-------|------|-------------|
| `fact_check_ins` | 3,216 | Individual check-in records with person, event, and time references |
| `fact_headcounts` | 7,944 | Headcount totals per attendance type and event time |
| `fact_es_events` | 207 | Engage Spaces events with attendance data |

**Intermediate:**

| Model | Rows | Description |
|-------|------|-------------|
| `int_pco_person_custom_fields` | ~24,800 | Pivoted custom fields — 22 columns (baptism, school year, demographic, ownership dates, leaders, etc.) from PCO's long-format field_data table |

**Identity:**

| Model | Rows | Description |
|-------|------|-------------|
| `bridge_person_identity` | ~2,300 | Cross-platform person matches using email (highest confidence) + name matching with confidence scoring (exact/likely/ambiguous) |

#### Marts Layer — `core_marts` dataset (4 tables)

Aggregated, reporting-ready tables aligned to RCN leadership levels.

| Model | Rows | Audience | Key Metrics |
|-------|------|----------|-------------|
| `mart_person_engagement` | ~41,700 | Village Leaders, Coaches | Total check-ins, check-in days, volunteer vs regular, days since last check-in, discipleship status, group membership, PCO contact info, baptism, school year, demographic, ownership dates, leadership assignments |
| `mart_campus_summary` | 16 | Local Pastors | Group count per campus, contact info, location details |
| `mart_village_summary` | 273 | Village Coaches | Member count, leader, campus, meeting schedule |
| `mart_attendance_trends` | 198 | Pastors, Network/CBE | Weekly headcount totals, unique check-in people, volunteer counts, one-time guests |

#### Tests

33 dbt tests defined and passing:
- `unique` and `not_null` on all primary keys across core and marts models (including new `dim_plan` and `dim_service_team`)

---

### 3. Infrastructure & Tooling

| Component | Status | Details |
|-----------|--------|---------|
| **GCP Project** | Active | `resonate-data-warehouse-442601` |
| **BigQuery** | 6 datasets | `planning_center`, `engage_spaces`, `airbyte_internal`, `core_staging`, `core_core`, `core_marts` |
| **Airbyte** | Running | 2 custom connectors (PCO, ES), daily syncs |
| **dbt Core** | v1.11.7 | Local dev environment in `.venv/`, dbt-bigquery v1.11.1 |
| **dbt Cloud** | Configured | Project "Iron Keep" on `wz475.us1.dbt.com`, account "Resonate Collective". Daily Build job created. **Pending:** set project subdirectory to `rcn_warehouse` to resolve run failure. |
| **Git** | GitHub | `SamDonnermeyer/iron_keep`, `main` branch, 1 commit |
| **Reporting** | Not started | TBD — Looker, Google Sheets, or other BI tool |

---

### 4. Documentation

| Document | Location | Description |
|----------|----------|-------------|
| `project_overview.md` | `Project Documents/` | High-level architecture and mission |
| `source_systems.md` | `Project Documents/` | Platform details, API info, auth methods |
| `airbyte_integration_plan.md` | `Project Documents/` | Step-by-step Airbyte connector playbook |
| `identity_resolution.md` | `Project Documents/` | How cross-platform person matching works |
| `pipeline_status_and_next_steps.md` | `Project Documents/` | This document |
| `CLAUDE.md` | `.claude/` | AI assistant context for this project |
| dbt docs | `rcn_warehouse/target/` | Auto-generated data catalog (run `dbt docs serve` to browse) |

---

## Next Steps

### Immediate — Complete dbt Cloud Deployment

**Priority: High | Effort: Small**

1. Set **Project subdirectory** to `rcn_warehouse` in dbt Cloud project settings
2. Re-run the Daily Build job and confirm all 4 steps pass (clone → profile → deps → build)
3. Verify that the daily schedule triggers correctly after Airbyte syncs complete

### Short-Term — Expand Data Coverage

**Priority: High | Effort: Medium**

4. ~~**Add PCO email/phone/address/field/plan/service_team streams to Airbyte**~~ — **DONE.** 7 new PCO streams added and corresponding staging + core models built.

5. **Add PCO Groups module to Airbyte** — Sync `groups`, `group_types`, `memberships`, `group_events`, and `attendances`. This unlocks village-level attendance and membership tracking directly from PCO, which is critical for Village Leader and Coach reporting. *(Airbyte connectors for Groups scope not yet built.)*

6. ~~**Add PCO Giving module to Airbyte**~~ — **Excluded.** RCN does not use PCO Giving.

7. **Add PCO Services `plan_people` stream to Airbyte** — The `plans` and `service_teams` dimensions are built. Adding `plan_people` would enable serving/volunteer tracking by linking people to service teams and plans.

### Short-Term — Improve Identity Resolution

**Priority: Medium | Effort: Medium**

8. ~~**Email-based matching**~~ — **DONE.** Email matching is now the primary matching method in `bridge_person_identity`, with name matching as a fallback.

9. **Campus as disambiguator** — Use ES `site` IDs and PCO campus assignments to break ties on common names.

10. **Manual override seed** — Create a `seeds/identity_overrides.csv` for staff to manually confirm or reject ambiguous matches.

### Medium-Term — Connect Remaining Source Systems

**Priority: Medium | Effort: Large**

12. **Pushpay** — Request API credentials from `api@pushpay.com`. Build custom Airbyte connector (OAuth2). Key streams: `payments`, `recurring_payments`, `funds`. Adds dedicated giving data.

13. **ServiceReef** — Request API key from admin dashboard. Build custom Airbyte connector (API Key). Key streams: `members`, `events`, `participants`. Adds mission trip and service tracking.

14. **Subsplash** — Request OAuth credentials. Configure Airbyte to pull from Snowflake (where Subsplash loads data). Key streams: `giving`, `groups`, `users`. Adds app-based engagement data.

15. **Build staging, core, and marts models** for each new source as it comes online.

### Medium-Term — Reporting & Dashboards

**Priority: High | Effort: Medium-Large**

16. **Select BI tool** — Evaluate Looker, Looker Studio (free), Google Sheets connected to BigQuery, or Power BI. Decision should factor in who the primary consumers are and their technical comfort level.

17. **Build dashboards for each leadership level:**
    - **Village Leader dashboard** — "My 12 people" view using `mart_person_engagement`, filtered by group
    - **Village Coach dashboard** — Village health overview using `mart_village_summary`
    - **Local Pastor dashboard** — Campus-level giving, attendance, and serving trends using `mart_attendance_trends` and `mart_campus_summary`
    - **Network/CBE dashboard** — Cross-campus comparisons, network-wide KPIs

18. **Define and implement KPIs** — Work with leadership to define what "church health" metrics look like quantitatively (e.g., attendance consistency, giving growth rate, volunteer ratio, discipleship pipeline progression).

### Long-Term — Refinement

**Priority: Low | Effort: Varies**

19. **Incremental models** — Convert high-volume fact tables (`fact_check_ins`, `fact_headcounts`) from full table rebuilds to incremental materialization for faster/cheaper dbt runs.

20. **Snapshot (SCD Type 2) tracking** — Add dbt snapshots for `dim_person` and `dim_group` to track changes over time (e.g., when someone's belief status changes, when a group leader changes).

21. **Fuzzy name matching** — Implement Soundex or Levenshtein-based matching in `bridge_person_identity` to catch spelling variations ("Mike"/"Michael", "MacDonald"/"Mcdonald").

22. **Data quality monitoring** — Add dbt tests for data freshness (source freshness tests), row count anomalies, and referential integrity between facts and dimensions.

23. **Pathwright integration** (v1.1) — Online courses platform. Limited API; may require Zapier-based extraction.

24. **Historical trend analysis** — Build time-series marts for longitudinal reporting: giving trends, attendance trends, spiritual journey tracking from first visit through leadership.

---

## BigQuery Dataset Map

```
resonate-data-warehouse-442601
│
├── planning_center          ← Raw Airbyte loads (PCO API data, JSON columns)
├── engage_spaces            ← Raw Airbyte loads (ES API data, flat columns)
├── airbyte_internal         ← Airbyte system tables
│
├── core_staging             ← dbt staging views (JSON extraction, renaming)
├── core_core                ← dbt core tables (dims, facts, identity bridge)
└── core_marts               ← dbt mart tables (aggregated reporting)
```

---

## Key Contacts

| Role | Contact | Platform |
|------|---------|----------|
| Engage Spaces API support | daniel.trafford@engagespaces.com | Engage Spaces |
| Pushpay API access | api@pushpay.com | Pushpay |
| ServiceReef API access | Admin dashboard or support | ServiceReef |
