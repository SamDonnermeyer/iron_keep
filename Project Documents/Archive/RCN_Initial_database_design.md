# Resonate Collegiate Network Data Warehouse

## Star Schema Starter Spec (v0.2)

> **Changelog v0.2:** Added `dim_fund`, `dim_person_source_priority`; enhanced `bridge_person_identity`, `fact_giving_transaction`, `fact_experience_participation`; removed T3 from v1 scope; added BigQuery considerations.

---

## Purpose

Create a single, **person-centric database** that supports reporting at four levels:

| Level | Scope |
|-------|-------|
| Village Leader | One village |
| Village Coach | Multiple villages |
| Local Pastor | One church |
| Network/CBE | All churches |

> **Core idea:** Church health rolls up from person story + participation over time.

---

## Source Systems

| System | Code | Priority | Auth Type |
|--------|------|----------|-----------|
| Planning Center Online | `pco` | **Primary** | OAuth2 |
| Pushpay | `pushpay` | **Primary** | OAuth2 |
| ServiceReef | `servicereef` | **Primary** | API Key |
| Engage Spaces | `engage_spaces` | **Primary** | API Key |
| Subsplash | `subsplash` | Secondary | OAuth |
| Pathwright | `pathwright` | *Deferred (v1.1)* | OAuth/Zapier |

> **Note:** T3 Account has been removed from v1 scope. Pathwright deferred due to limited API access (primarily Zapier-based).

---

## Guiding Principles

1. **Everything is time-based** — Facts have an `occurred_at` date and often a `loaded_at` date
2. **Everything is church-scoped** — Facts tie back to a `church_sk`
3. **Identity resolution is explicit** — Don't pretend email alone is always enough
4. **Prefer event facts + (optional) monthly snapshots** — For speed

---

## A. Conformed Dimensions

### dim_church

| Property | Value |
|----------|-------|
| **Grain** | 1 row per local church (site) |
| **PK** | `church_sk` (surrogate int) |
| **Natural Key** | `church_code` (stable short code) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `church_sk` | INT | PK |
| `church_code` | STRING | Unique |
| `church_name` | STRING | |
| `city` | STRING | |
| `state` | STRING | |
| `region` | STRING | Optional |
| `active_flag` | BOOL | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

---

### dim_person (PII-aware)

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person (canonical) |
| **PK** | `person_sk` (surrogate int) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `person_sk` | INT | PK |
| `full_name` | STRING | Or split: `first_name`, `last_name` |
| `primary_email` | STRING | Nullable |
| `primary_phone` | STRING | Nullable, normalized E164 if possible |
| `dob` | DATE | Nullable; **restrict access** |
| `gender` | STRING | Nullable |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

> **Note:** If you need historical attributes ("as of"), use a separate SCD table later. Start simple.

---

### bridge_person_identity

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per source-system identifier |
| **PK** | `(person_sk, source_system_sk, source_person_id)` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `person_sk` | INT64 | FK → `dim_person` |
| `source_system_sk` | INT64 | FK → `dim_source_system` |
| `source_person_id` | STRING | |
| `match_confidence` | INT64 | 0–100 |
| `match_method` | STRING | `email_exact` / `phone_exact` / `dob_name` / `manual` / etc. |
| `is_primary_source` | BOOL | **NEW:** TRUE if this source created the person record |
| `merge_candidate_person_sk` | INT64 | **NEW:** Nullable; flags potential duplicate for review |
| `active_flag` | BOOL | |
| `first_seen_at` | TIMESTAMP | |
| `last_seen_at` | TIMESTAMP | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Required Behavior:**
- A person can have many source IDs
- A source ID should map to one `person_sk` (unless re-linked by manual override)
- Exactly one source per person should have `is_primary_source = TRUE`
- `merge_candidate_person_sk` is populated during ETL when a potential duplicate is detected but not auto-merged

---

### dim_person_source_priority *(NEW)*

| Property | Value |
|----------|-------|
| **Grain** | 1 row per source system |
| **PK** | `priority_sk` |
| **Purpose** | Defines which source system is authoritative for each person field |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `priority_sk` | INT64 | PK |
| `source_system_sk` | INT64 | FK → `dim_source_system` |
| `priority_rank` | INT64 | 1 = highest priority |
| `authoritative_fields` | ARRAY<STRING> | Fields this source is trusted for |
| `notes` | STRING | Nullable |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Suggested Starter Rows:**

| source_system | priority_rank | authoritative_fields | notes |
|---------------|---------------|---------------------|-------|
| `pco` | 1 | `[email, phone, address, membership_status]` | PCO is primary CRM |
| `engage_spaces` | 2 | `[training_status]` | Owns training data |
| `servicereef` | 3 | `[mission_participation]` | Owns mission trip data |
| `pushpay` | 4 | `[]` | Giving only, no person authority |
| `subsplash` | 5 | `[]` | App engagement only |

> **Purpose:** When merging person records from multiple sources, this table determines which source's data "wins" for each field.

---

### dim_date

| Property | Value |
|----------|-------|
| **Grain** | 1 row per calendar day |
| **PK** | `date_sk` = `YYYYMMDD` (int) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `date_sk` | INT | PK (format: YYYYMMDD) |
| `date` | DATE | |
| `day_of_week` | STRING | |
| `week_start_date` | DATE | |
| `month` | INT | |
| `quarter` | INT | |
| `year` | INT | |
| `school_year` | STRING | Optional |

---

### dim_village

| Property | Value |
|----------|-------|
| **Grain** | 1 row per village/group |
| **PK** | `village_sk` |
| **FK** | `church_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `village_sk` | INT | PK |
| `church_sk` | INT | FK → `dim_church` |
| `village_source_id` | STRING | Nullable, per-system ID if needed |
| `village_name` | STRING | |
| `village_type` | STRING | |
| `active_flag` | BOOL | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

---

### bridge_person_village_membership

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per village membership period |
| **PK** | `(person_sk, village_sk, start_date_sk)` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `person_sk` | INT | FK → `dim_person` |
| `village_sk` | INT | FK → `dim_village` |
| `church_sk` | INT | FK (redundant but useful) |
| `start_date_sk` | INT | FK → `dim_date` |
| `end_date_sk` | INT | FK → `dim_date`, nullable if current |
| `role_in_village` | STRING | `member` / `leader` / `joshua` / `coach` |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

> **Purpose:** Answer: "Who was in this village at that time?"

---

### dim_milestone_type

| Property | Value |
|----------|-------|
| **Grain** | 1 row per milestone category |
| **PK** | `milestone_type_sk` |

**Suggested Rows:**

| Milestone |
|-----------|
| `first_met` |
| `first_attended_gathering` |
| `joined_village` |
| `decided_to_follow_jesus` |
| `baptized` |
| `became_member` (or owner) |
| `entered_discipleship_path` |
| `completed_discipleship_path` |
| `leadership_step` (optional) |

---

### dim_source_system

| Property | Value |
|----------|-------|
| **Grain** | 1 row per source system (and optionally per module) |
| **PK** | `source_system_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `source_system_sk` | INT | PK |
| `source_system_code` | STRING | Unique. Examples: `pco`, `engage_spaces`, `pushpay`, `subsplash`, `pathwright`, `servicereef`, `t3` |
| `source_system_name` | STRING | Examples: "Planning Center Online" |
| `source_module` | STRING | Nullable. Examples: `services`, `groups`, `people`, `giving` |
| `vendor` | STRING | Nullable |
| `api_base_url` | STRING | Nullable |
| `active_flag` | BOOL | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Suggested Starter Rows:**

| System | Module | v1 Scope |
|--------|--------|----------|
| `pco` | `people` | ✅ |
| `pco` | `services` | ✅ |
| `pco` | `groups` | ✅ |
| `pco` | `giving` | ✅ |
| `engage_spaces` | — | ✅ |
| `pushpay` | — | ✅ |
| `subsplash` | — | ✅ |
| `servicereef` | — | ✅ |
| `pathwright` | — | ⏸️ (v1.1) |

---

### dim_fund *(NEW)*

| Property | Value |
|----------|-------|
| **Grain** | 1 row per fund/designation per church |
| **PK** | `fund_sk` |
| **Purpose** | Track giving by fund (General, Missions, Building, etc.) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `fund_sk` | INT64 | PK |
| `church_sk` | INT64 | FK → `dim_church` |
| `fund_code` | STRING | Unique per church |
| `fund_name` | STRING | Display name |
| `fund_type` | STRING | `General` / `Designated` / `Restricted` / `Building` / `Missions` |
| `is_default` | BOOL | TRUE for the church's primary/general fund |
| `active_flag` | BOOL | |
| `source_system_sk` | INT64 | FK → `dim_source_system` |
| `source_fund_id` | STRING | Original ID from source system |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Example Rows:**

| fund_name | fund_type | is_default |
|-----------|-----------|------------|
| General Fund | General | TRUE |
| Missions | Designated | FALSE |
| Building Campaign | Restricted | FALSE |
| Benevolence | Designated | FALSE |

> **Purpose:** Enable fund-level giving analysis and reporting. Essential for answering "How much went to missions vs. general fund?"

---

## B. Fact Tables (Event-Based)

### fact_gathering_headcount

| Property | Value |
|----------|-------|
| **Grain** | 1 row per church per gathering occurrence (service) |
| **Purpose** | Official Sunday size reporting, trends over time |
| **PK** | `(church_sk, gathering_event_id)` or surrogate `gathering_headcount_sk` |
| **FKs** | `church_sk`, `date_sk` (and optional time dim) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `gathering_headcount_sk` | INT | PK (optional) |
| `church_sk` | INT | FK |
| `date_sk` | INT | FK |
| `occurred_at` | TIMESTAMP | Or `service_date` + `service_time_label` |
| `gathering_type` | STRING | `Sunday` / `WorshipNight` / etc. |
| `service_time_label` | STRING | `9am` / `11am` / etc. (optional) |
| `headcount` | INT | **Primary measure** |
| `gathering_event_id` | STRING | |
| `count_method` | STRING | `manual` / `clicker` / `estimate` / `scanner` / etc. |
| `source_system_sk` | INT | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

**Notes:**
- `gathering_event_id` is generated as: `{church_code}|{YYYY-MM-DD}|{service_time_label}|{gathering_type}` and must be unique per church per gathering occurrence
- `date_sk` represents the calendar date of the gathering; `occurred_at` captures the specific service time when available

**Key Metrics:**
- Weekly attendance by church
- YoY / semester trends
- Avg attendance last 4 weeks

---

### fact_village_attendance

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per village meeting occurrence |
| **FKs** | `church_sk`, `village_sk`, `person_sk`, `date_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `village_attendance_sk` | INT | PK (optional) |
| `church_sk` | INT | FK |
| `village_sk` | INT | FK |
| `person_sk` | INT | FK (or `-1` for unknown) |
| `date_sk` | INT | FK |
| `occurred_at` | TIMESTAMP | |
| `attended_flag` | BOOL | (1) |
| `source_system_sk` | INT | FK → `dim_source_system` |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

---

### fact_serving

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per serving instance (scheduled or served) |
| **FKs** | `church_sk`, `person_sk`, `date_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `serving_sk` | INT | PK (optional) |
| `church_sk` | INT | FK |
| `person_sk` | INT | FK |
| `date_sk` | INT | FK |
| `occurred_at` | TIMESTAMP | |
| `serving_area` | STRING | `Production` / `Welcome` / `Kids` / etc. |
| `role_label` | STRING | Normalize later into `dim_role` |
| `scheduled_flag` | BOOL | 0/1 |
| `served_flag` | BOOL | 0/1 |
| `hours` | FLOAT | Nullable |
| `source_system_sk` | INT | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

---

### fact_experience_participation *(Enhanced for ServiceReef)*

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per experience (or per experience-day if needed later) |
| **FKs** | `church_sk`, `person_sk`, `date_sk` (use `start_date_sk`) |
| **Primary Source** | ServiceReef (mission trips), PCO (retreats/events) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `experience_participation_sk` | INT64 | PK (optional) |
| `church_sk` | INT64 | FK |
| `person_sk` | INT64 | FK |
| `start_date_sk` | INT64 | FK |
| `end_date_sk` | INT64 | Nullable |
| `experience_name` | STRING | |
| `experience_type` | STRING | `Retreat` / `Conference` / `Mission` / `Camp` / `LocalServe` |
| `participation_status` | STRING | `registered` / `attended` / `cancelled` |
| `destination_country` | STRING | **NEW:** For mission trips (e.g., "Guatemala") |
| `destination_city` | STRING | **NEW:** For mission trips |
| `team_name` | STRING | **NEW:** ServiceReef team assignment |
| `fundraising_goal` | NUMERIC | **NEW:** Target amount for trip fundraising |
| `fundraising_raised` | NUMERIC | **NEW:** Amount raised toward goal |
| `source_system_sk` | INT64 | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

> **Note:** ServiceReef-specific fields (`destination_*`, `fundraising_*`, `team_name`) are nullable and only populated for mission trip records.

---

### fact_membership_event

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per membership-status change event |
| **FKs** | `church_sk`, `person_sk`, `date_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `membership_event_sk` | INT | PK (optional) |
| `church_sk` | INT | FK |
| `person_sk` | INT | FK |
| `date_sk` | INT | FK |
| `occurred_at` | TIMESTAMP | |
| `status_from` | STRING | |
| `status_to` | STRING | |
| `source_system_sk` | INT | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

---

### fact_spiritual_milestone

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per milestone occurrence |
| **FKs** | `church_sk`, `person_sk`, `date_sk`, `milestone_type_sk` |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `milestone_sk` | INT | PK (optional) |
| `church_sk` | INT | FK |
| `person_sk` | INT | FK |
| `date_sk` | INT | FK |
| `occurred_at` | TIMESTAMP | |
| `milestone_type_sk` | INT | FK |
| `milestone_notes` | STRING | Nullable; **lock down access** |
| `believer_status_at_time` | STRING | `unknown` / `nonbeliever` / `believer` — optional but very useful |
| `source_system_sk` | INT | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

---

### fact_giving_transaction *(Enhanced)*

| Property | Value |
|----------|-------|
| **Grain** | 1 row per gift transaction |
| **FKs** | `church_sk`, `person_sk` (nullable), `date_sk`, `fund_sk` |
| **Primary Source** | Pushpay (primary), PCO Giving (secondary) |

**Columns:**

| Column | Type | Notes |
|--------|------|-------|
| `gift_sk` | INT64 | PK |
| `church_sk` | INT64 | FK |
| `person_sk` | INT64 | Nullable or `-1` if not matched |
| `fund_sk` | INT64 | **NEW:** FK → `dim_fund` |
| `date_sk` | INT64 | FK |
| `occurred_at` | TIMESTAMP | |
| `amount` | NUMERIC | |
| `currency` | STRING | Default: `USD` |
| `fund_label` | STRING | Original label (kept for unmapped funds) |
| `payment_method` | STRING | `card` / `ach` / `cash` / `check` |
| `is_recurring` | BOOL | **NEW:** Part of recurring giving schedule |
| `recurring_schedule_id` | STRING | **NEW:** Links recurring gifts together |
| `source_system_sk` | INT64 | FK |
| `source_record_id` | STRING | |
| `loaded_at` | TIMESTAMP | |

> **Note:** This is now a **high-priority fact table** given giving data availability from Pushpay and PCO.

---

## C. Performance Layer (Derived Mart Tables)

### mart_person_monthly_snapshot

| Property | Value |
|----------|-------|
| **Grain** | 1 row per person per church per month |
| **FKs** | `church_sk`, `person_sk`, `month_date_sk` |

**Columns (examples):**

| Column | Type | Notes |
|--------|------|-------|
| `church_sk` | INT | FK |
| `person_sk` | INT | FK |
| `month_date_sk` | INT | FK |
| `gathering_attendance_30d` | INT | |
| `village_attendance_30d` | INT | |
| `serving_instances_90d` | INT | |
| `experiences_ytd` | INT | |
| `is_member_asof_month_end` | BOOL | Derived from membership events |
| `has_baptism_asof_month_end` | BOOL | Derived from milestones |
| `loaded_at` | TIMESTAMP | |

> **Purpose:** Fast "health" dashboards without heavy window functions.

---

## D. Unknown People Handling

*Minimum viable approach*

You will have records where the system has "a human happened" but no stable identity.

### Option A (Recommended)

1. Insert facts with `person_sk = -1` ("Unknown Person")
2. Keep `source_record_id` so later resolution can re-key (either via reprocessing or a mapping fix-up process)
3. Maintain an `unmatched_people_staging` table:

| Column | Type |
|--------|------|
| `source_system_sk` | INT |
| `source_person_id` | STRING |
| `source_record_id` | STRING |
| `name` | STRING |
| `email` | STRING |
| `phone` | STRING |
| `dob` | DATE |
| `church_guess` | STRING |
| `created_at` | TIMESTAMP |

> This becomes the **work queue** for identity resolution.

---

## E. Identity Resolution Rules

*Initial implementation*

### Priority Matching (tunable)

| Priority | Method |
|----------|--------|
| 1 | Exact match on `source_system_sk` + `source_person_id` (via bridge) |
| 2 | Exact match on normalized email |
| 3 | Exact match on normalized phone |
| 4 | Name + DOB (if both available and allowed) |
| 5 | Otherwise create new person + link in `bridge_person_identity` |

### Manual Override

You will eventually need a small admin table:

```sql
person_merge_overrides (
    from_person_sk INT,
    to_person_sk INT,
    reason STRING,
    merged_at TIMESTAMP
)
```

---

## F. Security / Access

*Implementation note*

Split into datasets/views:

| Dataset | Description | Access |
|---------|-------------|--------|
| `core_warehouse` | All tables | Restricted |
| `secure_pii` | DOB, phone, email | More restricted |
| `reporting_views` | Row-level filtered views by church and role | Role-based |

---

## G. Build Order

Recommended implementation sequence (updated for v0.2):

```
Phase 1: Foundation
├── dim_date (generate 10+ years)
├── dim_church
└── dim_source_system

Phase 2: Identity (CRITICAL PATH)
├── dim_person
├── bridge_person_identity
├── dim_person_source_priority (NEW)
└── unmatched_people_staging

Phase 3: Groups
├── dim_village
└── bridge_person_village_membership

Phase 4: Giving (HIGH VALUE - Early ROI)
├── dim_fund (NEW)
└── fact_giving_transaction

Phase 5: Attendance
├── fact_gathering_headcount
└── fact_village_attendance

Phase 6: Milestones & Membership
├── dim_milestone_type
├── fact_spiritual_milestone
└── fact_membership_event

Phase 7: Engagement
├── fact_serving
└── fact_experience_participation

Phase 8: Performance Layer
└── mart_person_monthly_snapshot

--- FUTURE (v1.1) ---
Phase 9: Training Integration
├── dim_course
└── fact_course_completion
```

### Phase Rationale

| Phase | Why This Order |
|-------|---------------|
| 1-2 | Foundation tables + identity are prerequisites for everything |
| 3 | Groups/villages are core to RCN's model |
| 4 | Giving provides early ROI and has clean API data (Pushpay) |
| 5 | Attendance is core metric for church health |
| 6-7 | Spiritual journey and engagement complete the picture |
| 8 | Mart layer enables fast dashboards |

---

## H. BigQuery Implementation Notes

### Data Types

Use BigQuery-native types throughout:

| Design Type | BigQuery Type |
|-------------|---------------|
| INT | INT64 |
| DECIMAL | NUMERIC |
| BOOL | BOOL |
| STRING | STRING |
| DATE | DATE |
| TIMESTAMP | TIMESTAMP |
| Array | ARRAY<type> |

### Partitioning Strategy

| Table | Partition Column | Rationale |
|-------|-----------------|-----------|
| `fact_giving_transaction` | `date_sk` or `occurred_at` | Query by date range |
| `fact_gathering_headcount` | `date_sk` | Weekly/monthly reports |
| `fact_village_attendance` | `date_sk` | Attendance trends |
| `mart_person_monthly_snapshot` | `month_date_sk` | Monthly aggregates |

### Clustering Strategy

| Table | Cluster Columns | Rationale |
|-------|-----------------|-----------|
| All fact tables | `church_sk` | Most queries filter by church |
| `fact_giving_transaction` | `church_sk, fund_sk` | Giving reports by fund |
| `bridge_person_identity` | `person_sk` | Identity lookups |

### Dataset Organization

```
project_id: rcn-data-warehouse

Datasets:
├── staging          # Raw data from source systems
├── core             # Dimension and fact tables
├── identity         # Person identity tables (restricted)
├── pii              # PII fields only (highly restricted)
├── marts            # Aggregated/derived tables
└── reporting        # Views for Looker
```

---

## Appendix: Quick Reference

### All Tables

| Type | Table Name | Status |
|------|------------|--------|
| Dimension | `dim_church` | v0.1 |
| Dimension | `dim_person` | v0.1 |
| Dimension | `dim_date` | v0.1 |
| Dimension | `dim_village` | v0.1 |
| Dimension | `dim_milestone_type` | v0.1 |
| Dimension | `dim_source_system` | v0.1 |
| Dimension | `dim_fund` | **v0.2 NEW** |
| Dimension | `dim_person_source_priority` | **v0.2 NEW** |
| Bridge | `bridge_person_identity` | v0.1 (enhanced v0.2) |
| Bridge | `bridge_person_village_membership` | v0.1 |
| Fact | `fact_gathering_headcount` | v0.1 |
| Fact | `fact_village_attendance` | v0.1 |
| Fact | `fact_serving` | v0.1 |
| Fact | `fact_experience_participation` | v0.1 (enhanced v0.2) |
| Fact | `fact_membership_event` | v0.1 |
| Fact | `fact_spiritual_milestone` | v0.1 |
| Fact | `fact_giving_transaction` | v0.1 (enhanced v0.2) |
| Mart | `mart_person_monthly_snapshot` | v0.1 |
| Staging | `unmatched_people_staging` | v0.1 |
| Admin | `person_merge_overrides` | v0.1 |

### v0.2 Changes Summary

| Change Type | Table | Description |
|-------------|-------|-------------|
| **NEW** | `dim_fund` | Fund/designation tracking for giving analysis |
| **NEW** | `dim_person_source_priority` | Multi-source identity resolution rules |
| **ENHANCED** | `bridge_person_identity` | Added `is_primary_source`, `merge_candidate_person_sk` |
| **ENHANCED** | `fact_giving_transaction` | Added `fund_sk`, `is_recurring`, `recurring_schedule_id`, `currency` |
| **ENHANCED** | `fact_experience_participation` | Added ServiceReef fields: `destination_*`, `fundraising_*`, `team_name` |
| **REMOVED** | T3 source system | Deferred from v1 scope |
| **DEFERRED** | Pathwright | Moved to v1.1 due to limited API |
