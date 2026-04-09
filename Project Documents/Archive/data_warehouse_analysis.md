# RCN Data Warehouse Analysis & Recommendations

**Date:** 2024-12-23
**Version:** 1.0
**Status:** Draft for Review

---

## Executive Summary

This document analyzes the proposed RCN star schema data warehouse design against the available APIs and data structures from the source systems. Based on the analysis, the design is **fundamentally sound** with several recommended enhancements for identity resolution and giving analysis.

### Key Findings

| Area | Assessment | Action |
|------|------------|--------|
| Star schema approach | ✅ Appropriate | No change |
| Person-centric model | ✅ Correct | No change |
| Identity resolution | ⚠️ Needs enhancement | Add source priority table |
| Giving tracking | ⚠️ Missing fund dimension | Add `dim_fund` |
| Attendance granularity | ✅ Aggregated is sufficient | No change |
| Training/courses | ⚠️ Defer to v1.1 | Placeholder structure defined |
| T3 system | ⏸️ Defer | Remove from v1 scope |

---

## Source System API Capabilities

### Planning Center Online (PCO)

**API:** REST (JSON API 1.0 specification)
**Auth:** OAuth2
**Documentation:** [developer.planning.center/docs](https://developer.planning.center/docs/)

| Module | Key Endpoints | Data Available |
|--------|--------------|----------------|
| People | `/people/v2/people` | Profiles, emails, phones, addresses, membership, custom fields |
| Services | `/services/v2/service_types` | Plans, schedules, teams, volunteers, songs |
| Groups | `/groups/v2/groups` | Group info, memberships, attendance |
| Giving | `/giving/v2/donations` | Donations, donors, funds, batches, recurring |
| Check-Ins | `/check-ins/v2/check_ins` | Individual check-in records, events, locations |
| Calendar | `/calendar/v2/events` | Events, resources, conflicts |

**Rate Limits:** 100 requests/minute per app
**Webhooks:** Available for People, Giving, Check-Ins

---

### Engage Spaces

**API:** REST
**Auth:** API Key (URL parameter `?apikey=YOUR_API_KEY`)
**Base URL:** `YOURDOMAIN.engagespaces.com/get` (or `/gets` for all locations)
**Formats:** JSON, CSV

| Data Type | Access Method | Notes |
|-----------|---------------|-------|
| Members | GET request | User profiles, roles, permissions |
| Training | GET request | Course assignments, completions |
| Events | GET request | Event registrations, attendance |
| Communications | GET request | Message history, engagement |

**Integrations:** Zapier, Airtable, Stripe, Tableau, Mailchimp, Power BI, Salesforce, Google Sheets

---

### Pushpay

**API:** REST (HAL+JSON)
**Auth:** OAuth2 (Client Flow or Code Flow)
**Documentation:** [pushpay.io/docs](https://pushpay.io/docs/api)
**Swagger:** [api.pushpay.com/swagger](https://api.pushpay.com/swagger)

| Endpoint | Data Available |
|----------|----------------|
| `/v1/merchant/{merchantKey}/payments` | All payment transactions |
| `/v1/merchant/{merchantKey}/anticipatedpayments` | Recurring/scheduled payments |
| `/v1/merchant/{merchantKey}/batches` | Batch summaries |

**Key Fields:**
- Payment: amount, currency, status, fund, payer info, payment method, timestamps
- Payer: name, email, phone (may be anonymous)

**Important:** Sandbox testing required before production credentials issued. Contact: api@pushpay.com

---

### Subsplash

**API:** REST
**Auth:** OAuth
**Documentation:** [developer.subsplash.com](https://developer.subsplash.com/)

| Feature | Integration Type |
|---------|-----------------|
| Giving | Direct API |
| Groups | Sync with messaging |
| SSO | SAML/OAuth |
| Media | API access |

**Pre-built Integrations:** Planning Center, Rock RMS, Ministry Platform, Breeze

---

### ServiceReef

**API:** REST (JSON)
**Auth:** API Key (HTTPS required)
**Documentation:** [api.servicereef.com/docs](https://api.servicereef.com/docs)

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

**Key Feature:** `externalId` support allows linking to other systems

---

### Pathwright

**API:** Limited REST + Zapier
**Auth:** OAuth
**Documentation:** [developer.pathwright.com](https://developer.pathwright.com/)

| Access Method | Capabilities |
|---------------|-------------|
| Zapier Triggers | Course completion, registration, membership changes |
| Zapier Actions | Send registration invitations, create users |
| REST API | Limited endpoints (not fully public) |

**Recommendation:** Use Zapier webhooks → staging table for data capture. Not suitable for bulk historical data extraction.

---

## Design Analysis

### What's Correct in Current Design

1. **Star Schema Architecture**
   - Appropriate for analytical workloads
   - Conformed dimensions enable cross-source analysis
   - Event-based facts align with API data structures

2. **`bridge_person_identity` Pattern**
   - Essential for multi-system identity resolution
   - `match_confidence` and `match_method` fields are valuable
   - Supports many-to-one source-ID-to-person mapping

3. **Source System Tracking**
   - `source_system_sk` on all facts enables lineage
   - `source_record_id` allows re-processing and debugging

4. **Temporal Design**
   - `occurred_at` + `loaded_at` pattern is correct
   - `date_sk` foreign keys enable efficient date-based analysis

### Gaps Identified

#### Gap 1: Fund Dimension for Giving

**Problem:** `fact_giving_transaction` has `fund_label` as a string, not a proper dimension.

**Impact:** Cannot efficiently:
- Filter/aggregate by fund type
- Track fund changes over time
- Standardize fund names across sources

**Solution:** Add `dim_fund`

```sql
CREATE TABLE dim_fund (
  fund_sk INT64 NOT NULL,
  church_sk INT64 NOT NULL,
  fund_code STRING,
  fund_name STRING NOT NULL,
  fund_type STRING,  -- General / Designated / Restricted / Building / Missions
  is_default BOOL DEFAULT FALSE,
  active_flag BOOL DEFAULT TRUE,
  source_system_sk INT64,
  source_fund_id STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

Update `fact_giving_transaction`:
- Add `fund_sk INT64` (FK → dim_fund)
- Keep `fund_label` for unmapped/new funds

---

#### Gap 2: Identity Source Priority

**Problem:** With multiple authoritative sources, need to define which system "wins" for each field.

**Solution:** Add `dim_person_source_priority`

```sql
CREATE TABLE dim_person_source_priority (
  priority_sk INT64 NOT NULL,
  source_system_sk INT64 NOT NULL,
  priority_rank INT64 NOT NULL,  -- 1 = highest
  authoritative_fields ARRAY<STRING>,  -- ['email', 'phone', 'name']
  notes STRING,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Example data:
INSERT INTO dim_person_source_priority VALUES
(1, 1, 1, ['email', 'phone', 'address', 'membership_status'], 'PCO is primary CRM'),
(2, 2, 2, ['training_status'], 'Engage Spaces owns training data'),
(3, 3, 3, ['mission_participation'], 'ServiceReef owns mission data'),
(4, 4, 4, [], 'Pushpay - giving only, no person authority');
```

---

#### Gap 3: ServiceReef Experience Enhancement

**Problem:** `fact_experience_participation` is generic; ServiceReef provides richer mission trip data.

**Solution:** Add optional columns:

```sql
ALTER TABLE fact_experience_participation ADD COLUMN
  destination_country STRING,
  destination_city STRING,
  trip_type STRING,  -- Mission / Retreat / Camp / LocalServe
  fundraising_goal NUMERIC,
  fundraising_raised NUMERIC,
  team_name STRING;
```

---

## Recommended Schema Changes

### New Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `dim_fund` | Fund/designation tracking for giving | **High** |
| `dim_person_source_priority` | Identity resolution rules | **High** |
| `dim_course` | Pathwright/Engage training (v1.1) | Low |
| `fact_course_completion` | Training progress (v1.1) | Low |

### Modified Tables

| Table | Change | Priority |
|-------|--------|----------|
| `fact_giving_transaction` | Add `fund_sk` FK | **High** |
| `fact_experience_participation` | Add ServiceReef fields | Medium |
| `bridge_person_identity` | Add `is_primary_source`, `merge_candidate_person_sk` | Medium |
| `dim_source_system` | Remove T3, make Pathwright optional | Low |

---

## Implementation Considerations for BigQuery

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
| All facts | `church_sk` | Most queries filter by church |
| `fact_giving_transaction` | `church_sk, fund_sk` | Giving reports by fund |
| `bridge_person_identity` | `person_sk` | Identity lookups |

### BigQuery-Specific Recommendations

1. **Use `INT64` instead of `INT`** - BigQuery standard
2. **Consider nested/repeated fields** for:
   - Person emails (ARRAY<STRUCT>)
   - Person phones (ARRAY<STRUCT>)
3. **Use `DATE` for date_sk** instead of INT - easier querying while still efficient
4. **Scheduled Queries** for daily ETL and mart refreshes

---

## Revised Build Order

```
Phase 1: Foundation (Week 1)
├── dim_date (generate 10 years)
├── dim_church (manual entry or PCO import)
├── dim_source_system (PCO modules, Engage, Pushpay, Subsplash, ServiceReef)
└── dim_fund (Pushpay + PCO Giving)

Phase 2: Identity Core (Week 2)
├── dim_person
├── bridge_person_identity
├── dim_person_source_priority
└── unmatched_people_staging

Phase 3: Groups (Week 3)
├── dim_village (from PCO Groups + Engage Spaces)
└── bridge_person_village_membership

Phase 4: High-Value Facts (Week 4)
├── fact_giving_transaction (Pushpay primary, PCO Giving secondary)
└── fact_gathering_headcount (PCO Services)

Phase 5: Engagement Facts (Week 5)
├── fact_village_attendance (PCO Groups + Engage Spaces)
├── fact_serving (PCO Services)
└── fact_experience_participation (ServiceReef)

Phase 6: Spiritual Journey (Week 6)
├── dim_milestone_type
├── fact_spiritual_milestone
└── fact_membership_event

Phase 7: Performance Layer (Week 7)
└── mart_person_monthly_snapshot

--- FUTURE (v1.1) ---
Phase 8: Training Integration
├── dim_course
└── fact_course_completion
```

---

## Data Flow Architecture

```
                    ┌─────────────────┐
                    │   Source APIs   │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐        ┌─────▼─────┐       ┌─────▼─────┐
    │   PCO   │        │  Pushpay  │       │ServiceReef│
    │  OAuth  │        │  OAuth2   │       │  API Key  │
    └────┬────┘        └─────┬─────┘       └─────┬─────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Staging Layer  │
                    │   (BigQuery)    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Identity Match  │
                    │    Process      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Star Schema    │
                    │  (dims + facts) │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Mart Layer    │
                    │  (aggregates)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Reporting     │
                    │   (Looker/etc)  │
                    └─────────────────┘
```

---

## Open Questions for RCN Team

1. **ETL Tooling:** What will orchestrate the daily batch loads? (Cloud Composer/Airflow, Cloud Functions, dbt, etc.)

2. **Reporting Layer:** What BI tool will consume this warehouse? (Looker, Tableau, Power BI, Metabase)

3. **Historical Data:** How far back does each source system retain data? Need this for initial backfill planning.

4. **Data Retention:** Are there policies for how long to retain PII or detailed transaction data?

5. **Access Control:** Who needs access to which datasets? (Village leaders vs Network leadership)

---

## Appendix: Source System API Quick Reference

| System | Auth | Base URL | Rate Limit |
|--------|------|----------|------------|
| PCO | OAuth2 | `api.planningcenteronline.com` | 100/min |
| Pushpay | OAuth2 | `api.pushpay.com` | Unknown |
| Engage Spaces | API Key | `{org}.engagespaces.com` | Unknown |
| ServiceReef | API Key | `api.servicereef.com` | Unknown |
| Subsplash | OAuth | `developer.subsplash.com` | Unknown |
| Pathwright | OAuth/Zapier | `developer.pathwright.com` | N/A |

---

## Sources

- [Planning Center API Documentation](https://developer.planning.center/docs/)
- [Planning Center API Essentials](https://rollout.com/integration-guides/planning-center/api-essentials)
- [Pushpay Developer Portal](https://pushpay.io/)
- [Pushpay API Introduction](https://pushpay.io/docs/introduction)
- [ServiceReef REST API Docs](https://api.servicereef.com/docs)
- [Subsplash Developer Site](https://developer.subsplash.com/)
- [Subsplash API & Integrations Support](https://support.subsplash.com/en/collections/10317160-api-integrations)
- [Pathwright Developer](https://developer.pathwright.com/)
- [Engage Spaces](https://engagespaces.com/)
