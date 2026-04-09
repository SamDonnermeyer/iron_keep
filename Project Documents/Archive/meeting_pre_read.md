# Operation Iron Keep
## Meeting Pre-Read Document

**Project:** Data Warehouse Initiative for Resonate Collegiate Network
**Document Version:** 1.0
**Status:** Research Complete, Implementation Planning Phase
**Prepared:** January 2025

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Background & Goals](#project-background--goals)
3. [Current State: What We Learned](#current-state-what-we-learned)
4. [Source Systems Deep Dive](#source-systems-deep-dive)
5. [Database Architecture](#database-architecture)
6. [ETL Tool Analysis](#etl-tool-analysis)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Decision Points for Meeting](#decision-points-for-meeting)
9. [Risks & Mitigations](#risks--mitigations)
10. [Cost Estimates](#cost-estimates)
11. [Open Questions](#open-questions)
12. [Appendix: Technical Reference](#appendix-technical-reference)

---

## Executive Summary

### The Problem

Resonate Collegiate Network's data is currently siloed across 5-6 separate platforms with no unified view of people, giving, attendance, or engagement. This makes network-wide reporting and decision-making difficult, and prevents leadership from having a complete picture of church health and individual spiritual journeys.

### The Solution

Build a centralized data warehouse in Google BigQuery that:
- Consolidates data from all church management platforms
- Creates a single, person-centric view across all systems
- Enables reporting at four leadership levels: Village Leader, Village Coach, Local Pastor, and Network/CBE
- Supports daily batch updates with Looker as the reporting interface

### Research Status

| Area | Status | Key Finding |
|------|--------|-------------|
| Source System APIs | Complete | All APIs accessible; no pre-built ETL connectors exist |
| Database Schema | Complete (v0.2) | Star schema with 20+ tables designed |
| ETL Tooling | Complete | Airbyte recommended; custom connectors required |
| Identity Resolution | Complete | Multi-source priority system designed |
| Implementation Plan | Complete | 8-phase build order defined |

### Key Insight

**No major ETL platform has pre-built connectors for church management systems.** Custom connector development is required regardless of which tool we choose. This makes open-source options more attractive since we're building connectors anyway.

### Bottom Line

The project is technically feasible with an estimated monthly operating cost of **$75-350** depending on tooling choices. The critical path runs through identity resolution (matching people across systems) and the ETL tool decision.

---

## Project Background & Goals

### Why "Operation Iron Keep"?

The name reflects the goal of building a secure, centralized fortress for RCN's data - consolidating scattered information into one protected, well-organized structure.

### Core Objective

Create a single, **person-centric database** that supports reporting at four levels:

| Reporting Level | Scope | Example Use Case |
|-----------------|-------|------------------|
| **Village Leader** | One village/small group | "How are my 12 people engaging?" |
| **Village Coach** | Multiple villages | "Which villages need attention?" |
| **Local Pastor** | One church | "What's our giving trend? Who's serving?" |
| **Network/CBE** | All churches | "Network-wide baptisms this year?" |

### Guiding Philosophy

> **"Church health rolls up from person story + participation over time."**

The warehouse is designed to track individual journeys - from first contact through spiritual milestones - while enabling aggregated reporting at every leadership level.

### What Success Looks Like

1. **Single source of truth** for person data across all platforms
2. **Daily refreshed dashboards** in Looker showing key metrics
3. **Self-service reporting** for leaders at each level
4. **Historical trend analysis** for giving, attendance, and engagement
5. **Spiritual journey tracking** from first visit through leadership development

---

## Current State: What We Learned

### Research Completed

The following research documents have been created:

| Document | Purpose | Location |
|----------|---------|----------|
| `RCN_Initial_database_design.md` | Full star schema specification (v0.2) | Research/Data Structure Research/ |
| `data_warehouse_analysis.md` | API capabilities and design recommendations | Research/Data Structure Research/ |
| `etl_tool_comparison.md` | ETL/ELT tool evaluation | Project Documents/ |
| `session_notes.md` | Decision log and context | Project Documents/ |

### Key Decisions Already Made

These decisions were made during the research phase and are documented in session notes:

| Decision Area | Choice | Rationale |
|---------------|--------|-----------|
| **Data Warehouse** | Google BigQuery | Cost-effective, scales well, integrates with Looker |
| **Reporting Tool** | Looker | Already in use / preferred BI tool |
| **Refresh Frequency** | Daily batch | Real-time not needed; simplifies architecture |
| **Multi-Site Handling** | Church-level only | No campus dimension needed; each church = one entity |
| **Attendance Granularity** | Aggregated headcount | Individual check-ins not required; service-level counts sufficient |
| **Identity Authority** | Multi-source priority | PCO doesn't own all fields; explicit priority rules needed |

### What's Deferred to v1.1

| Item | Reason for Deferral |
|------|---------------------|
| **Pathwright Integration** | Limited API (primarily Zapier-based); not suitable for bulk data |
| **T3 Account** | Details not yet available; defer to later phase |
| **Real-time Webhooks** | Daily batch sufficient for v1 reporting needs |
| **Training/Course Tracking** | Nice-to-have; adds complexity without critical value |

---

## Source Systems Deep Dive

### Platform Overview

| Platform | Primary Purpose | Data We Need | Priority |
|----------|-----------------|--------------|----------|
| **Planning Center Online** | Church management (people, groups, services) | People, Groups, Attendance, Giving | Primary |
| **Pushpay** | Donations and recurring giving | Transactions, Donors, Funds | Primary |
| **ServiceReef** | Mission trips and experiences | Events, Participants, Fundraising | Primary |
| **Engage Spaces** | Training and member engagement | Members, Training, Events | Primary |
| **Subsplash** | Church app and giving | Giving, Groups, Media engagement | Secondary |
| **Pathwright** | Online courses | Course completions | Deferred (v1.1) |

### API Capabilities by Platform

#### Planning Center Online (PCO)

| Attribute | Value |
|-----------|-------|
| **API Type** | REST (JSON API 1.0 specification) |
| **Authentication** | OAuth2 |
| **Rate Limit** | 100 requests/minute per app |
| **Webhooks** | Available for People, Giving, Check-Ins |
| **Documentation** | [developer.planning.center/docs](https://developer.planning.center/docs/) |

**Available Modules:**

| Module | Key Data | Endpoints |
|--------|----------|-----------|
| People | Profiles, emails, phones, addresses, membership, custom fields | `/people/v2/people` |
| Services | Plans, schedules, teams, volunteers, songs | `/services/v2/service_types` |
| Groups | Group info, memberships, attendance | `/groups/v2/groups` |
| Giving | Donations, donors, funds, batches, recurring | `/giving/v2/donations` |
| Check-Ins | Individual check-in records, events, locations | `/check-ins/v2/check_ins` |
| Calendar | Events, resources, conflicts | `/calendar/v2/events` |

**Key Resource:** The `pypco` Python library provides full API support with auto-pagination and rate limiting. GitHub: https://github.com/billdeitrick/pypco

---

#### Pushpay

| Attribute | Value |
|-----------|-------|
| **API Type** | REST (HAL+JSON) |
| **Authentication** | OAuth2 (Client Flow or Code Flow) |
| **Documentation** | [pushpay.io/docs](https://pushpay.io/docs/api) |
| **Swagger** | [api.pushpay.com/swagger](https://api.pushpay.com/swagger) |

**Key Endpoints:**

| Endpoint | Data Available |
|----------|----------------|
| `/v1/merchant/{merchantKey}/payments` | All payment transactions |
| `/v1/merchant/{merchantKey}/anticipatedpayments` | Recurring/scheduled payments |
| `/v1/merchant/{merchantKey}/batches` | Batch summaries |

**Available Fields:**
- Payment: amount, currency, status, fund, payer info, payment method, timestamps
- Payer: name, email, phone (may be anonymous)

**Important:** Sandbox testing required before production credentials. Contact: api@pushpay.com

---

#### ServiceReef

| Attribute | Value |
|-----------|-------|
| **API Type** | REST (JSON) |
| **Authentication** | API Key (HTTPS required) |
| **Documentation** | [api.servicereef.com/docs](https://api.servicereef.com/docs) |

**Key Endpoints:**

| Endpoint | Data Available |
|----------|----------------|
| `GET /v1/members` | User profiles, approval status, external IDs |
| `GET /v1/events` | Mission trips, service projects, retreats |
| `GET /v1/events/{id}/participants` | Registrations, team assignments |
| `GET /v1/events/{id}/payments` | Trip-related donations |
| `GET /v1/payments` | All financial transactions |
| `GET /v1/positions` | Volunteer roles and assignments |
| `GET /v1/groups` | Volunteer groups |
| `GET /v1/forms` | Custom forms and responses |

**Key Feature:** `externalId` field supports linking records to other systems - critical for identity resolution.

---

#### Engage Spaces

| Attribute | Value |
|-----------|-------|
| **API Type** | REST |
| **Authentication** | API Key (URL parameter `?apikey=YOUR_API_KEY`) |
| **Base URL** | `YOURDOMAIN.engagespaces.com/get` (or `/gets` for all locations) |
| **Formats** | JSON, CSV |

**Available Data:**

| Data Type | Notes |
|-----------|-------|
| Members | User profiles, roles, permissions |
| Training | Course assignments, completions |
| Events | Event registrations, attendance |
| Communications | Message history, engagement |

**Pre-built Integrations:** Zapier, Airtable, Stripe, Tableau, Mailchimp, Power BI, Salesforce, Google Sheets

---

#### Subsplash

| Attribute | Value |
|-----------|-------|
| **API Type** | REST |
| **Authentication** | OAuth |
| **Documentation** | [developer.subsplash.com](https://developer.subsplash.com/) |

**Features:**

| Feature | Integration Type |
|---------|-----------------|
| Giving | Direct API |
| Groups | Sync with messaging |
| SSO | SAML/OAuth |
| Media | API access |

**Pre-built Integrations:** Planning Center, Rock RMS, Ministry Platform, Breeze

---

#### Pathwright (Deferred to v1.1)

| Attribute | Value |
|-----------|-------|
| **API Type** | Limited REST + Zapier |
| **Authentication** | OAuth |
| **Documentation** | [developer.pathwright.com](https://developer.pathwright.com/) |

**Limitations:**
- Primarily Zapier-based triggers (course completion, registration)
- No bulk data extraction capability
- Not suitable for historical backfill

**Recommendation:** Use Zapier webhooks → staging table for data capture in v1.1.

---

### Connector Availability Summary

**Critical Finding: No pre-built connectors exist for any church management platform.**

| Source System | Fivetran | Stitch | Airbyte | Hevo | Portable | Meltano |
|--------------|----------|--------|---------|------|----------|---------|
| Planning Center | No | No | No | No | Maybe | No |
| Pushpay | No | No | No | No | Maybe | No |
| ServiceReef | No | No | No | No | Maybe | No |
| Engage Spaces | No | No | No | No | Maybe | No |
| Subsplash | No | No | No | No | Maybe | No |
| **BigQuery (destination)** | Yes | Yes | Yes | Yes | Yes | Yes |

This means **custom connector development is required** regardless of ETL tool choice.

---

## Database Architecture

### Design Philosophy

The warehouse uses a **star schema** - a dimensional modeling pattern with:
- **Dimension Tables:** Descriptive attributes (who, what, where)
- **Fact Tables:** Measurable events (what happened, when, how much)
- **Bridge Tables:** Many-to-many relationships
- **Mart Tables:** Pre-aggregated data for fast dashboards

### Schema Overview (v0.2)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CONFORMED DIMENSIONS                          │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────┤
│ dim_church  │ dim_person  │  dim_date   │ dim_village │  dim_fund   │
│ (churches)  │  (people)   │ (calendar)  │  (groups)   │ (giving)    │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┘
       │             │             │             │             │
       └─────────────┴─────────────┼─────────────┴─────────────┘
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                           FACT TABLES                                │
├─────────────────┬─────────────────┬─────────────────┬───────────────┤
│ fact_giving_    │ fact_gathering_ │ fact_village_   │ fact_serving  │
│ transaction     │ headcount       │ attendance      │               │
├─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ fact_spiritual_ │ fact_membership_│ fact_experience_│               │
│ milestone       │ event           │ participation   │               │
└─────────────────┴─────────────────┴─────────────────┴───────────────┘
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                         IDENTITY LAYER                               │
├────────────────────────┬────────────────────────────────────────────┤
│ bridge_person_identity │ dim_person_source_priority                 │
│ (cross-system links)   │ (field authority rules)                    │
└────────────────────────┴────────────────────────────────────────────┘
```

### All Tables at a Glance

| Type | Table Name | Purpose | Status |
|------|------------|---------|--------|
| **Dimension** | `dim_church` | One row per church/site | v0.1 |
| **Dimension** | `dim_person` | Canonical person records (PII) | v0.1 |
| **Dimension** | `dim_date` | Calendar dimension (10+ years) | v0.1 |
| **Dimension** | `dim_village` | Small groups/communities | v0.1 |
| **Dimension** | `dim_milestone_type` | Life event categories | v0.1 |
| **Dimension** | `dim_source_system` | Source platform metadata | v0.1 |
| **Dimension** | `dim_fund` | Fund/designation tracking | **v0.2 NEW** |
| **Dimension** | `dim_person_source_priority` | Identity resolution rules | **v0.2 NEW** |
| **Bridge** | `bridge_person_identity` | Links person across systems | v0.1 (enhanced v0.2) |
| **Bridge** | `bridge_person_village_membership` | Person-to-village relationships | v0.1 |
| **Fact** | `fact_giving_transaction` | Donation transactions | v0.1 (enhanced v0.2) |
| **Fact** | `fact_gathering_headcount` | Sunday service attendance | v0.1 |
| **Fact** | `fact_village_attendance` | Small group attendance | v0.1 |
| **Fact** | `fact_serving` | Volunteer/staff assignments | v0.1 |
| **Fact** | `fact_experience_participation` | Mission trips, retreats, camps | v0.1 (enhanced v0.2) |
| **Fact** | `fact_membership_event` | Membership status changes | v0.1 |
| **Fact** | `fact_spiritual_milestone` | Baptisms, decisions, etc. | v0.1 |
| **Mart** | `mart_person_monthly_snapshot` | Aggregated monthly metrics | v0.1 |
| **Staging** | `unmatched_people_staging` | Identity resolution queue | v0.1 |
| **Admin** | `person_merge_overrides` | Manual identity corrections | v0.1 |

### Key Table Details

#### dim_person (Person Master)

| Column | Type | Notes |
|--------|------|-------|
| `person_sk` | INT64 | Primary key (surrogate) |
| `full_name` | STRING | Or split: first_name, last_name |
| `primary_email` | STRING | Nullable |
| `primary_phone` | STRING | Normalized E164 format |
| `dob` | DATE | **Restricted access** |
| `gender` | STRING | Nullable |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

#### dim_fund (Giving Designations)

| Column | Type | Notes |
|--------|------|-------|
| `fund_sk` | INT64 | Primary key |
| `church_sk` | INT64 | FK to dim_church |
| `fund_code` | STRING | Unique per church |
| `fund_name` | STRING | "General Fund", "Missions", etc. |
| `fund_type` | STRING | General / Designated / Restricted / Building / Missions |
| `is_default` | BOOL | TRUE for primary fund |
| `active_flag` | BOOL | |

#### fact_giving_transaction

| Column | Type | Notes |
|--------|------|-------|
| `gift_sk` | INT64 | Primary key |
| `church_sk` | INT64 | FK |
| `person_sk` | INT64 | Nullable (anonymous gifts) |
| `fund_sk` | INT64 | FK to dim_fund |
| `date_sk` | INT64 | FK to dim_date |
| `occurred_at` | TIMESTAMP | Transaction timestamp |
| `amount` | NUMERIC | Gift amount |
| `currency` | STRING | Default: USD |
| `payment_method` | STRING | card / ach / cash / check |
| `is_recurring` | BOOL | Part of recurring schedule |
| `recurring_schedule_id` | STRING | Links recurring gifts |

### Identity Resolution Strategy

#### The Challenge

The same person may exist in multiple systems with different IDs:
- PCO ID: 12345
- Pushpay ID: ABC-789
- ServiceReef ID: user_456

We need to link these into a single canonical `person_sk`.

#### The Solution: Priority-Based Matching

**Match Priority Order:**

| Priority | Method | Confidence |
|----------|--------|------------|
| 1 | Exact match on `source_system + source_person_id` | 100% |
| 2 | Exact match on normalized email | 95% |
| 3 | Exact match on normalized phone | 90% |
| 4 | Name + DOB (both required) | 85% |
| 5 | Create new person + link in bridge | N/A |

**Source Authority Table (dim_person_source_priority):**

| Source System | Priority Rank | Authoritative Fields | Notes |
|---------------|---------------|---------------------|-------|
| PCO | 1 | email, phone, address, membership_status | Primary CRM |
| Engage Spaces | 2 | training_status | Owns training data |
| ServiceReef | 3 | mission_participation | Owns mission data |
| Pushpay | 4 | (none) | Giving only |
| Subsplash | 5 | (none) | App engagement only |

**Handling Unmatched People:**
1. Insert fact records with `person_sk = -1` (Unknown Person)
2. Populate `unmatched_people_staging` table with available data
3. Manual review process to resolve and re-key records

---

## ETL Tool Analysis

### Why This Matters

The ETL (Extract, Transform, Load) tool is how we get data from source systems into BigQuery. The choice affects:
- Monthly operating costs
- Development effort required
- Ongoing maintenance burden
- Flexibility for future changes

### Tool Comparison Summary

| Tool | Monthly Cost | Setup Effort | Maintenance | Custom Connectors |
|------|-------------|--------------|-------------|-------------------|
| **Airbyte (self-hosted)** | ~$56 | Medium | Low | No-code builder + SDK |
| **Meltano** | ~$40 | High | Medium | Singer SDK (Python) |
| **Cloud Functions + dbt** | ~$25 | High | Medium | Full custom (Python) |
| **Portable.io** | $200 flat | Low | None | They build for you |
| **Fivetran** | $500+ | Low | None | Paid add-on |
| **Stitch** | $100+ | Low | None | Singer taps |

### Detailed Analysis

#### Option A: Airbyte Self-Hosted + dbt (Recommended)

**What it is:** Open-source data integration platform with a visual UI, deployed on our own infrastructure.

**Why it's recommended:**
- No per-row costs (critical as data grows)
- No-code Connector Builder for REST APIs
- Visual UI for pipeline monitoring (non-technical friendly)
- Native dbt integration for transformations
- Active community and good documentation
- Full control over data (self-hosted)

**Monthly Cost Breakdown:**

| Component | Cost |
|-----------|------|
| Compute Engine (e2-medium) | ~$35 |
| BigQuery (storage + compute) | ~$20 |
| dbt Core | Free |
| Cloud Scheduler | ~$1 |
| **Total** | **~$56/mo** |

**Implementation Steps:**
1. Deploy Airbyte on GCP Compute Engine
2. Build custom connectors for PCO, Pushpay, ServiceReef using Connector Builder
3. Configure BigQuery as destination
4. Set up dbt project for transformations
5. Connect Looker to BigQuery

**Connector Development:**
- No-code Connector Builder for simple REST APIs
- Low-code CDK (Python) for complex cases
- Community connectors available for common patterns

---

#### Option B: Custom Cloud Functions + dbt (Lowest Cost)

**What it is:** Serverless Python functions that extract data on a schedule, with dbt for transformations.

**Architecture:**
```
Cloud Scheduler (cron)
    ↓
Cloud Functions (Python)
    ↓ Extract from APIs
Cloud Storage (staging)
    ↓
BigQuery (load)
    ↓
dbt (transform)
    ↓
Looker (report)
```

**Monthly Cost Breakdown:**

| Component | Cost |
|-----------|------|
| Cloud Scheduler | ~$0.10 |
| Cloud Functions | ~$5-20 |
| Cloud Storage | ~$1-5 |
| BigQuery Storage | ~$5-20 |
| BigQuery Compute | Free tier (1TB/mo) |
| **Total** | **~$25/mo** |

**Pros:**
- Absolute lowest cost
- Maximum flexibility and control
- Leverages existing Python library (pypco)
- No external dependencies or vendor lock-in

**Cons:**
- Must write all extraction code from scratch
- No built-in monitoring/alerting (requires Cloud Monitoring setup)
- Manual retry/error handling implementation
- No visual UI for pipeline management

---

#### Option C: Portable.io (Managed Service)

**What it is:** Managed ETL service that specializes in long-tail data sources and builds custom connectors for you.

**Monthly Cost:** $200 flat (unlimited volume, scheduled flows)

**Why consider it:**
- They build custom connectors for free
- Fully managed - no infrastructure to maintain
- Predictable billing (no usage surprises)
- Good for non-technical teams

**When to choose:**
- If development resources are limited
- If they already have church management connectors (ask!)
- If predictable billing is priority over lowest cost

**Action Item:** Contact Portable.io to ask:
1. Do you have Planning Center, Pushpay, or ServiceReef connectors?
2. What's the timeline to build custom connectors?
3. Is there nonprofit pricing?

---

#### Not Recommended: Fivetran / Stitch

**Why not:**
- No pre-built connectors for our sources
- Per-row/per-MAR pricing becomes expensive at scale
- Custom connector development is a paid add-on
- Paying premium for managed service without getting connector value

---

### Python Libraries Available

| Source | Library | Status | Notes |
|--------|---------|--------|-------|
| Planning Center | [pypco](https://github.com/billdeitrick/pypco) | Active | Full API support, auto-pagination, rate limiting |
| Pushpay | None | — | Use `requests` with OAuth2 |
| ServiceReef | None | — | Use `requests` with API key |
| Engage Spaces | None | — | Use `requests` with API key |
| Subsplash | None | — | Use `requests` with OAuth |

### dbt for Transformation Layer

Regardless of ETL tool choice, **dbt (data build tool)** is recommended for transformations.

**Why dbt?**
- Looker Integration: dbt + BigQuery + Looker is a proven, well-documented stack
- Open Source: dbt Core is free
- Version Control: SQL transformations in Git
- Testing: Built-in data quality tests
- Documentation: Auto-generated data lineage

**dbt Options:**

| Option | Cost | Features |
|--------|------|----------|
| dbt Core | Free | CLI, full functionality |
| dbt Cloud (Developer) | Free | 1 seat, 1 project |
| dbt Cloud (Team) | $100/seat/mo | Collaboration, scheduling |

**Recommendation:** Start with dbt Core (free), run via Cloud Scheduler or ETL orchestrator.

---

## Implementation Roadmap

### 8-Phase Build Order

```
Phase 1: Foundation
├── dim_date (generate 10+ years)
├── dim_church (manual entry or PCO import)
└── dim_source_system (PCO modules, Engage, Pushpay, Subsplash, ServiceReef)

Phase 2: Identity (CRITICAL PATH)
├── dim_person
├── bridge_person_identity
├── dim_person_source_priority
└── unmatched_people_staging

Phase 3: Groups
├── dim_village (from PCO Groups + Engage Spaces)
└── bridge_person_village_membership

Phase 4: Giving (HIGH VALUE - Early ROI)
├── dim_fund
└── fact_giving_transaction

Phase 5: Attendance
├── fact_gathering_headcount (PCO Services)
└── fact_village_attendance (PCO Groups + Engage)

Phase 6: Milestones & Membership
├── dim_milestone_type
├── fact_spiritual_milestone
└── fact_membership_event

Phase 7: Engagement
├── fact_serving (PCO Services)
└── fact_experience_participation (ServiceReef)

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
| 3 | Groups/villages are core to RCN's model and terminology |
| 4 | **Giving provides early ROI** - clean API data from Pushpay, high stakeholder value |
| 5 | Attendance is a core metric for church health reporting |
| 6-7 | Spiritual journey and engagement complete the full picture |
| 8 | Mart layer enables fast, pre-aggregated dashboards |

### Infrastructure Setup (Pre-Phase 1)

Before building tables, the following infrastructure is needed:

1. **GCP Project Setup**
   - Create or identify BigQuery project
   - Enable required APIs
   - Set up IAM permissions

2. **BigQuery Dataset Organization**
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

3. **ETL Tool Deployment**
   - Deploy chosen tool (Airbyte/Cloud Functions/Portable)
   - Configure authentication for each source system
   - Test connectivity

4. **dbt Project Initialization**
   - Create project structure
   - Configure BigQuery connection
   - Set up Git repository

---

## Decision Points for Meeting

### Decision 1: ETL Tool Selection

**Question:** Which approach should we use for data extraction and loading?

| Option | Monthly Cost | Pros | Cons |
|--------|--------------|------|------|
| **A. Airbyte (Self-hosted) + dbt** | ~$56/mo | Visual UI, no per-row costs, flexible | Requires GCP Compute setup |
| **B. Meltano + dbt** | ~$40/mo | Fully open source, CLI-first | Steeper learning curve |
| **C. Cloud Functions + dbt** | ~$25/mo | Lowest cost, maximum control | Most custom development required |
| **D. Portable.io** | $200/mo flat | Managed service, they build connectors | Higher cost, vendor dependency |

**Recommendation:** Option A (Airbyte) for best balance of cost, features, and maintainability.

**Questions to discuss:**
- What is our appetite for infrastructure management vs. higher costs?
- Do we have Python development resources available?
- How important is a visual UI for non-technical team members?

---

### Decision 2: Implementation Approach

**Question:** How should we sequence the work?

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Sequential (Phase by Phase)** | Complete each phase before starting next | Lower risk, clearer milestones | Longer time to full value |
| **B. Parallel Workstreams** | Multiple phases in progress simultaneously | Faster time to value | Higher coordination overhead |
| **C. MVP First** | Build minimal viable Phases 1-4 only, then pause | Fastest to initial value | May need rework later |

**Recommendation:** Option A (Sequential) unless there's pressure for faster delivery.

---

### Decision 3: Identity Resolution Authority

**Question:** Which system should be authoritative for each person field?

**Proposed Configuration:**

| Field | Authoritative Source | Rationale |
|-------|---------------------|-----------|
| Name | PCO | Primary CRM, most likely to be updated |
| Email | PCO | Primary contact management |
| Phone | PCO | Primary contact management |
| Address | PCO | Primary CRM |
| Membership Status | PCO | PCO manages membership workflows |
| Training Status | Engage Spaces | Owns training data |
| Mission Participation | ServiceReef | Owns mission trip data |

**Questions to discuss:**
- Is PCO truly the system of record for contact information?
- Are there scenarios where another system has better data?
- Who handles manual review of unmatched/duplicate people?

---

### Decision 4: Scope Confirmation

**Question:** Should any deferred items be elevated to v1, or any v1 items deferred?

**Currently Deferred (v1.1):**
- [ ] Pathwright integration (training/courses)
- [ ] T3 Account
- [ ] Real-time webhooks
- [x] Pushpay
- [x] ServiceReef

**Currently In Scope (v1):**
- [x] Planning Center (all modules)
- [x] Engage Spaces
- [x] Subsplash
- [X] Campus-level reporting

**Questions to discuss:**
- Are the deferrals still appropriate?
- Is anything missing that should be in v1?
- Are all in-scope items actually needed?

---

### Decision 5: Resource Allocation

**Question:** Who will do this work?

**Roles Needed:**

| Role | Responsibilities | Hours/Week |
|------|------------------|------------|
| **Data Engineer** | Custom connector development, BigQuery setup, ETL pipeline | 15-20 |
| **Analytics Engineer** | dbt models, Looker dashboards, data quality | 10-15 |
| **Project Lead** | Coordination, stakeholder management, decisions | 5-10 |

**Questions to discuss:**
- Are these roles filled internally?
- Should any work be contracted out?
- What is the realistic timeline given available resources?

---

### Decision 6: Pilot Churches

**Question:** Which churches should be included in the initial pilot?

**Considerations:**
- Need at least 2-3 churches to validate cross-church reporting
- Should include churches actively using all source systems
- Ideally mix of church sizes/regions

**Questions to discuss:**
- Which churches are best candidates?
- Do we need buy-in from local pastors?
- How do we handle churches not using all platforms?

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **API Rate Limits** | Medium | Slow initial data loads | Implement exponential backoff, schedule off-peak, request limit increases |
| **Identity Matching Errors** | High | Duplicate or incorrectly merged people | Staging table for manual review, conservative matching thresholds, audit reports |
| **Platform API Changes** | Medium | Broken connectors | Version monitoring, automated test suite, vendor relationship |
| **Scope Creep** | High | Delayed delivery | Clear v1 boundary, change request process, phased approach |
| **Data Quality Issues** | Medium | Unreliable reports | dbt tests, source data validation, data quality dashboards |
| **Resource Availability** | Medium | Timeline slippage | Clear ownership, realistic estimates, buffer time |
| **Security/PII Exposure** | Low | Compliance issues, trust impact | Dataset-level access controls, PII isolation, audit logging |

---

## Cost Estimates

### Monthly Operating Costs

| Scenario | ETL Tool | Infrastructure | Total |
|----------|----------|----------------|-------|
| **Low (Custom Build)** | Cloud Functions | BigQuery, Storage | ~$25-50/mo |
| **Recommended (Airbyte)** | Airbyte self-hosted | Compute Engine, BigQuery | ~$56-100/mo |
| **Managed (Portable)** | Portable.io | BigQuery only | ~$220-250/mo |

### Detailed Breakdown (Recommended Option)

| Component | Monthly Cost |
|-----------|--------------|
| Compute Engine (e2-medium for Airbyte) | $35 |
| BigQuery Storage (estimated 50GB) | $10 |
| BigQuery Compute | Free tier (1TB queries/mo) |
| Cloud Scheduler | $1 |
| Cloud Storage (staging) | $2 |
| dbt Core | Free |
| Looker | (Existing? TBD) |
| **Total** | **~$50-75/mo** |

### One-Time Setup Costs

| Item | Effort | Notes |
|------|--------|-------|
| Infrastructure setup | 8-16 hours | GCP project, datasets, permissions |
| Airbyte deployment | 4-8 hours | Compute Engine setup, configuration |
| Custom connector development | 40-80 hours | 5 connectors @ 8-16 hours each |
| dbt project setup | 8-16 hours | Models, tests, documentation |
| Initial data load | 8-16 hours | Historical backfill, validation |
| **Total** | **70-140 hours** | |

---

## Open Questions

### For This Meeting

1. **Target go-live date:** What is the deadline for initial reporting capabilities?

2. **Pilot churches:** Which 2-3 churches should be included in the pilot?

3. **GCP accounts:** Are there existing GCP/BigQuery accounts to leverage, or do we need new ones?

4. **Report consumers:** Who are the primary report users at each leadership level? What are their technical skills?

5. **Priority reports:** What specific dashboards/reports are highest priority for initial launch?

6. **Data access:** Who should have access to PII? Who reviews the unmatched people queue?

7. **Historical data:** How far back do we need to load data? (1 year? 3 years? All available?)

### For Future Sessions

- Data retention policies
- Disaster recovery requirements
- Training plan for report consumers
- Change management process for schema updates
- SLA expectations for data freshness

---

## Appendix: Technical Reference

### Data Flow Architecture

```
                    ┌─────────────────┐
                    │   Source APIs   │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐        ┌─────▼─────┐       ┌─────▼─────┐
    │   PCO   │        │  Pushpay  │       │ServiceReef│
    │  OAuth2 │        │  OAuth2   │       │  API Key  │
    └────┬────┘        └─────┬─────┘       └─────┬─────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                    ┌────────▼────────┐
                    │     Airbyte     │
                    │  (Extract/Load) │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    BigQuery     │
                    │   (staging)     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Identity Match  │
                    │    Process      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │      dbt        │
                    │  (Transform)    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    BigQuery     │
                    │  (core/marts)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │     Looker      │
                    │   (Reporting)   │
                    └─────────────────┘
```

### API Quick Reference

| System | Auth | Base URL | Rate Limit |
|--------|------|----------|------------|
| PCO | OAuth2 | `api.planningcenteronline.com` | 100/min |
| Pushpay | OAuth2 | `api.pushpay.com` | Unknown |
| Engage Spaces | API Key | `{org}.engagespaces.com` | Unknown |
| ServiceReef | API Key | `api.servicereef.com` | Unknown |
| Subsplash | OAuth | `developer.subsplash.com` | Unknown |

### BigQuery Implementation Notes

**Data Type Mappings:**

| Design Type | BigQuery Type |
|-------------|---------------|
| INT | INT64 |
| DECIMAL | NUMERIC |
| BOOL | BOOL |
| STRING | STRING |
| DATE | DATE |
| TIMESTAMP | TIMESTAMP |
| Array | ARRAY<type> |

**Partitioning Strategy:**

| Table | Partition Column | Rationale |
|-------|-----------------|-----------|
| `fact_giving_transaction` | `date_sk` | Query by date range |
| `fact_gathering_headcount` | `date_sk` | Weekly/monthly reports |
| `fact_village_attendance` | `date_sk` | Attendance trends |
| `mart_person_monthly_snapshot` | `month_date_sk` | Monthly aggregates |

**Clustering Strategy:**

| Table | Cluster Columns | Rationale |
|-------|-----------------|-----------|
| All fact tables | `church_sk` | Most queries filter by church |
| `fact_giving_transaction` | `church_sk, fund_sk` | Giving reports by fund |
| `bridge_person_identity` | `person_sk` | Identity lookups |

### Glossary

| Term | Definition |
|------|------------|
| **Village** | Small group / community group in RCN terminology |
| **Joshua** | Leadership role within a village |
| **PCO** | Planning Center Online |
| **MAR** | Monthly Active Rows (Fivetran pricing metric) |
| **ELT** | Extract, Load, Transform (modern approach vs. traditional ETL) |
| **Star Schema** | Dimensional modeling pattern with fact and dimension tables |
| **Surrogate Key** | System-generated primary key (e.g., `person_sk`) |
| **Natural Key** | Business identifier (e.g., `church_code`) |
| **dbt** | Data build tool - SQL-based transformation framework |

### Source Documents

| Document | Location |
|----------|----------|
| Database Schema (v0.2) | `Research/Data Structure Research/RCN_Initial_database_design.md` |
| API Analysis | `Research/Data Structure Research/data_warehouse_analysis.md` |
| ETL Tool Comparison | `Project Documents/etl_tool_comparison.md` |
| Session Notes | `Project Documents/session_notes.md` |
| Source Systems List | `Project Documents/source_systems.md` |

---

*Document prepared for Operation Iron Keep planning meeting*