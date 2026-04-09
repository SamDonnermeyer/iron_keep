# Operation Iron Keep - Session Notes

> **Purpose:** This document captures decisions, progress, and context from working sessions to maintain continuity across conversations.

---

## Session: 2024-12-23

### Overview

Initial project setup and data warehouse design review for Resonate Collegiate Network (RCN). The goal is to build a person-centric data warehouse that consolidates data from multiple church management platforms into BigQuery for reporting via Looker.

---

### 1. Project Initialization

**Action:** Ran `claude init` to set up project memory.

**Created:**
- `.claude/CLAUDE.md` - Project memory file with structure and platform information

**Project Structure:**
```
Operation Iron Keep/
├── .claude/
│   └── CLAUDE.md
├── Project Documents/
│   ├── project_overview.md
│   ├── source_systems.md
│   ├── etl_tool_comparison.md
│   └── session_notes.md (this file)
└── Research/
    ├── Data Structure Research/
    │   ├── RCN_Initial_database_design.md
    │   └── data_warehouse_analysis.md
    └── Platform Research/
        ├── BigQuery/
        ├── EngagedSpaces/
        ├── Planning Center Online/
        ├── Pushpay/
        └── Subsplash/
```

---

### 2. Database Design Document Reformatting

**Action:** Reformatted `RCN_Initial_database_design.md` from plain text to proper markdown.

**Improvements Made:**
- Added proper heading hierarchy (`#`, `##`, `###`)
- Converted all column definitions to markdown tables
- Added section dividers and visual structure
- Organized into lettered sections (A-G)
- Added Appendix with quick reference table
- Used code formatting for column names and SQL

**File:** `Research/Data Structure Research/RCN_Initial_database_design.md`

---

### 3. Source System API Research

**Action:** Researched each source system's API capabilities to validate the data warehouse design.

#### Findings by System:

| System | API Type | Auth | Connectors Available | Key Endpoints |
|--------|----------|------|---------------------|---------------|
| **Planning Center** | REST (JSON API 1.0) | OAuth2 | pypco Python library | People, Services, Groups, Giving, Check-Ins, Calendar |
| **Pushpay** | REST (HAL+JSON) | OAuth2 | None pre-built | Payments, Merchants, Batches, Recurring |
| **ServiceReef** | REST | API Key | None pre-built | Members, Events, Payments, Positions, Groups, Forms |
| **Engage Spaces** | REST | API Key | None pre-built | Members, Training, Events, Communications |
| **Subsplash** | REST | OAuth | None pre-built | Giving, Groups, SSO, Media |
| **Pathwright** | Limited REST + Zapier | OAuth | None pre-built | Courses, Registrations (via Zapier triggers) |

**Key Insight:** No major ETL platform has pre-built connectors for these church management systems. Custom connector development is required regardless of ETL tool choice.

**File Created:** `Research/Data Structure Research/data_warehouse_analysis.md`

---

### 4. Key Decisions Made

Through interactive questions, the following decisions were captured:

#### Identity Resolution
- **Decision:** Multiple sources own authoritative person data
- **Implication:** PCO is not the single source of truth; need `dim_person_source_priority` to define which system wins for each field
- **Example:** PCO owns email/phone, ServiceReef owns mission participation, Engage Spaces owns training status

#### Attendance Tracking
- **Decision:** Aggregated headcount per service is sufficient
- **Implication:** No need for individual check-in fact table; `fact_gathering_headcount` at service level is correct
- **Rationale:** Simpler, less storage, meets reporting needs

#### Training/Discipleship Tracking
- **Decision:** Nice to have, not essential for v1
- **Implication:** Defer `dim_course` and `fact_course_completion` to v1.1
- **Rationale:** Pathwright has limited API (Zapier-based), adds complexity

#### T3 Account
- **Decision:** Defer to later phase
- **Implication:** Removed from v1 source system scope
- **Note:** User to provide details if needed in future

#### Multi-Site/Campus
- **Decision:** Church-level reporting only
- **Implication:** No `dim_campus` needed; each church is one entity

#### Data Refresh Frequency
- **Decision:** Daily batch processing
- **Implication:** Nightly ETL is sufficient; no need for real-time webhooks in v1

#### Data Warehouse Platform
- **Decision:** Google BigQuery
- **Implication:** Use BigQuery-native types (INT64, NUMERIC), partitioning, clustering

#### Reporting Tool
- **Decision:** Looker
- **Implication:** dbt + BigQuery + Looker is the target stack

---

### 5. ETL Tool Analysis

**Action:** Researched and compared ETL tools for the RCN use case.

#### Recommendation Tiers:

| Rank | Tool | Monthly Cost | Rationale |
|------|------|-------------|-----------|
| 1 | **Airbyte (self-hosted) + dbt** | ~$56 | Best balance of cost, features, custom connector support |
| 2 | **Custom Cloud Functions + dbt** | ~$25 | Lowest cost, maximum flexibility, requires more development |
| 3 | **Portable.io** | $200 flat | Fully managed, they build custom connectors, predictable pricing |

#### Why Airbyte (Recommended):
- No per-row costs (critical as data grows)
- No-code Connector Builder for REST APIs
- UI for pipeline monitoring
- Native dbt integration
- Active community

#### Key Resource Discovered:
- **pypco** - Python library for Planning Center API with auto-pagination and rate limiting
- GitHub: https://github.com/billdeitrick/pypco

**File Created:** `Project Documents/etl_tool_comparison.md`

---

### 6. Database Design Updates (v0.1 → v0.2)

**Action:** Updated `RCN_Initial_database_design.md` to incorporate analysis recommendations.

#### New Tables Added:

| Table | Purpose |
|-------|---------|
| `dim_fund` | Track giving by fund (General, Missions, Building, etc.) |
| `dim_person_source_priority` | Define which source is authoritative for each person field |

#### Enhanced Tables:

| Table | Changes |
|-------|---------|
| `bridge_person_identity` | Added `is_primary_source` (BOOL), `merge_candidate_person_sk` (INT64) |
| `fact_giving_transaction` | Added `fund_sk` (FK), `is_recurring`, `recurring_schedule_id`, `currency`; now high-priority (not optional) |
| `fact_experience_participation` | Added ServiceReef fields: `destination_country`, `destination_city`, `team_name`, `fundraising_goal`, `fundraising_raised` |

#### Source System Changes:
- **Removed:** T3 Account (deferred)
- **Deferred:** Pathwright (moved to v1.1 due to limited API)
- **Added:** Auth types and priority levels to source system table

#### New Sections Added:
- **Section H:** BigQuery Implementation Notes
  - Data type mappings (INT → INT64, DECIMAL → NUMERIC)
  - Partitioning strategy (fact tables by date_sk)
  - Clustering strategy (all facts by church_sk)
  - Dataset organization (staging, core, identity, pii, marts, reporting)

#### Updated Build Order:
```
Phase 1: Foundation (dim_date, dim_church, dim_source_system)
Phase 2: Identity (dim_person, bridge_person_identity, dim_person_source_priority)
Phase 3: Groups (dim_village, bridge_person_village_membership)
Phase 4: Giving - HIGH VALUE (dim_fund, fact_giving_transaction)
Phase 5: Attendance (fact_gathering_headcount, fact_village_attendance)
Phase 6: Milestones (dim_milestone_type, fact_spiritual_milestone, fact_membership_event)
Phase 7: Engagement (fact_serving, fact_experience_participation)
Phase 8: Performance (mart_person_monthly_snapshot)
--- v1.1 ---
Phase 9: Training (dim_course, fact_course_completion)
```

**Rationale for Giving in Phase 4:** Pushpay has clean API, provides early ROI for stakeholders.

---

### 7. Documents Created/Modified

| Document | Location | Action |
|----------|----------|--------|
| `CLAUDE.md` | `.claude/` | Created |
| `RCN_Initial_database_design.md` | `Research/Data Structure Research/` | Reformatted, then updated to v0.2 |
| `data_warehouse_analysis.md` | `Research/Data Structure Research/` | Created |
| `etl_tool_comparison.md` | `Project Documents/` | Created |
| `session_notes.md` | `Project Documents/` | Created (this file) |

---

### 8. Open Items / Next Steps

| Priority | Item | Status |
|----------|------|--------|
| 1 | Choose ETL approach (Airbyte vs Custom vs Portable) | **Pending decision** |
| 2 | Set up Airbyte infrastructure on GCP (if chosen) | Not started |
| 3 | Build Planning Center custom connector | Not started |
| 4 | Create dbt project structure | Not started |
| 5 | Generate BigQuery DDL scripts | Not started |
| 6 | Contact Portable.io about church connectors | Optional |

---

### 9. Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                     SOURCE SYSTEMS                          │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│   PCO    │ Pushpay  │ServiceReef│ Engage  │   Subsplash   │
│  OAuth2  │  OAuth2  │  API Key │ API Key │     OAuth     │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴───────┬───────┘
     └──────────┴──────────┴──────────┴─────────────┘
                           │
                    ┌──────▼──────┐
                    │   Airbyte   │  ← Recommended ETL
                    │ (self-host) │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  BigQuery   │  ← Data Warehouse
                    │  (staging)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    dbt      │  ← Transformation
                    │   (core)    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  BigQuery   │
                    │   (marts)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Looker    │  ← Reporting
                    └─────────────┘
```

---

### 10. Useful Links & Resources

| Resource | URL |
|----------|-----|
| Planning Center API Docs | https://developer.planning.center/docs/ |
| pypco Python Library | https://github.com/billdeitrick/pypco |
| Pushpay Developer Portal | https://pushpay.io/ |
| ServiceReef API Docs | https://api.servicereef.com/docs |
| Subsplash Developer | https://developer.subsplash.com/ |
| Airbyte Open Source | https://airbyte.com/product/airbyte-open-source |
| Meltano Docs | https://docs.meltano.com/ |
| dbt with BigQuery | https://docs.getdbt.com/guides/dbt-python-bigframes |

---

### 11. Glossary

| Term | Definition |
|------|------------|
| **Village** | Small group / community group in RCN terminology |
| **Joshua** | Leadership role within a village |
| **PCO** | Planning Center Online |
| **MAR** | Monthly Active Rows (Fivetran pricing metric) |
| **ELT** | Extract, Load, Transform (vs traditional ETL) |
| **Star Schema** | Dimensional modeling pattern with fact and dimension tables |
| **Surrogate Key** | System-generated primary key (e.g., `person_sk`) |
| **Natural Key** | Business identifier (e.g., `church_code`) |

---

*Last updated: 2024-12-23*
