# Airbyte Integration Plan
## Operation Iron Keep — Resonate Collegiate Network

**Last Updated:** 2026-03-25
**Status:** Active
**Airbyte:** Already deployed
**BigQuery:** Ready

---

## Overview

This document is the step-by-step playbook for building Airbyte custom connectors for each RCN source system, loading raw data into BigQuery staging datasets, and preparing for dbt transformation. All connectors are custom-built using the Airbyte Connector Builder (no pre-built connectors exist for these church management platforms).

**Build Priority:**

| Priority | Platform | Auth | Credentials Status | Airbyte Approach |
|----------|----------|------|--------------------|-----------------|
| 1 | Planning Center Online (PCO) | OAuth2 | ✅ Available | Custom Connector Builder (OAuth2) |
| 2 | Engage Spaces | API Key | ✅ Available | Custom Connector Builder (API Key) |
| 3 | Pushpay | OAuth2 | ❌ Need to request | Custom Connector Builder (OAuth2) |
| 4 | ServiceReef | API Key | ❌ Need to request | Custom Connector Builder (API Key) |
| 5 | Subsplash | OAuth | ❌ Need to request | Custom Connector Builder (OAuth) |

---

## Before You Start — Prerequisites Checklist

### BigQuery Setup (Confirm These Exist)
- [ ] GCP project ID confirmed (e.g., `rcn-data-warehouse`)
- [ ] Service account created for Airbyte with `BigQuery Data Editor` + `BigQuery Job User` roles
- [ ] Service account JSON key downloaded
- [ ] BigQuery dataset created: `staging` (raw Airbyte loads land here)
- [ ] BigQuery dataset created: `core` (for dbt-transformed tables)

### Airbyte Setup (Confirm These Exist)
- [ ] Airbyte is accessible (URL/IP confirmed)
- [ ] BigQuery destination already configured in Airbyte, OR ready to configure

---

## STEP 1 — Configure BigQuery as Airbyte Destination

**In Airbyte UI:** Destinations → + New Destination → BigQuery

| Field | Value |
|-------|-------|
| Destination Name | `BigQuery - RCN Staging` |
| Project ID | Your GCP project ID |
| Dataset Location | `US` (or your region) |
| Default Dataset ID | `staging` |
| Loading Method | `GCS Staging` (recommended for performance) or `Standard Inserts` |
| Credentials JSON | Paste your service account JSON key content |

> **API Keys / Credentials Needed:**
> - GCP Service Account JSON key file

---

## STEP 2 — Connector 1: Planning Center Online (PCO)

### About PCO
- **API Type:** REST (JSON API 1.0 spec)
- **Base URL:** `https://api.planning.center/`
- **Auth:** OAuth2 (Authorization Code Flow)
- **Rate Limit:** 100 requests per minute per OAuth app
- **Docs:** https://developer.planning.center/docs/
- **Python library (reference):** https://github.com/billdeitrick/pypco

### API Keys / Credentials Needed for PCO

You need to create an **OAuth application** in the PCO Developer portal:

1. Go to https://api.planning.center/oauth/applications
2. Click **New Application**
3. Set redirect URI to your Airbyte instance: `https://YOUR-AIRBYTE-URL/auth/callback`
4. Note your:
   - **Client ID**
   - **Client Secret**

> ⚠️ You'll need to complete the OAuth flow once to generate an initial access/refresh token, which Airbyte will manage thereafter.

### PCO Modules & Streams to Build

#### Module: People (`/people/v2/`)

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pco_people` | `GET /people/v2/people` | id, first_name, last_name, birthdate, anniversary, gender, grade, graduation_year, created_at, updated_at, status (active/inactive/prospect) | `dim_person`, `bridge_person_identity` |
| `pco_households` | `GET /people/v2/households` | id, name, member_count, created_at | Reference for family grouping |
| `pco_emails` | `GET /people/v2/people/{id}/emails` | id, address, primary, blocked | `dim_person.primary_email` |
| `pco_phone_numbers` | `GET /people/v2/people/{id}/phone_numbers` | id, number, primary, carrier | `dim_person.primary_phone` |
| `pco_addresses` | `GET /people/v2/people/{id}/addresses` | id, street, city, state, zip | `dim_person` |
| `pco_field_data` | `GET /people/v2/people/{id}/field_data` | id, value, field_definition_id | Custom fields (campus, membership date, etc.) |
| `pco_campus` | `GET /people/v2/campuses` | id, name, city, state | `dim_church` |

#### Module: Groups (`/groups/v2/`)

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pco_groups` | `GET /groups/v2/groups` | id, name, group_type_id, location, enrollment_strategy, created_at | `dim_village` |
| `pco_group_types` | `GET /groups/v2/group_types` | id, name, default_group_settings | Village type classification |
| `pco_memberships` | `GET /groups/v2/groups/{id}/memberships` | id, person_id, group_id, role (member/leader), joined_at, departed_at | `bridge_person_village_membership` |
| `pco_group_events` | `GET /groups/v2/groups/{id}/events` | id, name, starts_at, attendance_requests_enabled, group_id | `fact_village_attendance` |
| `pco_attendances` | `GET /groups/v2/events/{id}/attendances` | id, person_id, attended, created_at | `fact_village_attendance` |

#### Module: Services (`/services/v2/`)

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pco_service_types` | `GET /services/v2/service_types` | id, name, created_at | Reference for service categorization |
| `pco_plans` | `GET /services/v2/service_types/{id}/plans` | id, series_title, title, short_dates, dates, public | `fact_gathering_headcount` |
| `pco_plan_people` | `GET /services/v2/service_types/{id}/plans/{id}/team_members` | id, person_id, status (confirmed/declined/unconfirmed), team_position_name | `fact_serving` |
| `pco_headcounts` | `GET /services/v2/service_types/{id}/plans/{id}/plan_times` | id, serves_at, headcounts | `fact_gathering_headcount` |
| `pco_teams` | `GET /services/v2/service_types/{id}/teams` | id, name, team_positions, schedule_to_str | `fact_serving` reference |

#### Module: Giving (`/giving/v2/`)

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pco_donations` | `GET /giving/v2/donations` | id, amount_cents, amount_currency, received_at, payment_method, payment_status, person_id, campus_id, created_at | `fact_giving_transaction` |
| `pco_designation_refunds` | `GET /giving/v2/donations/{id}/designations` | id, amount_cents, fund_id, donation_id | `fact_giving_transaction` fund breakdown |
| `pco_funds` | `GET /giving/v2/funds` | id, name, color, deletable, default_payment_source | `dim_fund` |
| `pco_recurring_donations` | `GET /giving/v2/recurring_donations` | id, amount_cents, status, schedule, person_id, created_at | Recurring giving tracking |

#### Module: Check-Ins (`/check-ins/v2/`)

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pco_check_ins` | `GET /check-ins/v2/check_ins` | id, first_name, last_name, kind (Regular/Volunteer), created_at, event_id, event_period_id, person_id | `fact_gathering_headcount`, `fact_village_attendance` |
| `pco_events` | `GET /check-ins/v2/events` | id, name, frequency (once/recurs), created_at | Event reference |
| `pco_event_periods` | `GET /check-ins/v2/event_periods` | id, starts_at, ends_at, total_count, event_id | Attendance aggregation |

### Building the PCO Connector in Airbyte Connector Builder

**In Airbyte UI:** Builder → + New Connector → Start from Scratch

**Step-by-step connector config:**

**1. Global Config**
- Connector Name: `Planning Center Online`
- Base URL: `https://api.planning.center`

**2. Authentication**
- Type: `OAuth 2.0`
- Auth URL: `https://api.planning.center/oauth/authorize`
- Token URL: `https://api.planning.center/oauth/token`
- Client ID: *(your PCO OAuth app client ID)*
- Client Secret: *(your PCO OAuth app client secret)*
- Scopes: `people groups services giving check_ins`
- Grant Type: `authorization_code`
- Token Refresh: Use `refresh_token` grant after initial auth

**3. Per-Stream Config (example: `pco_people`)**
- Stream Name: `pco_people`
- URL Path: `/people/v2/people`
- HTTP Method: `GET`
- Pagination:
  - Type: `offset` (JSON API spec uses `offset` and `per_page`)
  - Offset: `offset[page]` or `offset`
  - Page size param: `per_page`
  - Page size: `100` (max allowed)
  - Total count path: `meta.total_count`
- Primary Key: `id`
- Incremental sync field: `updated_at` (use cursor-based incremental)
- Rate Limiting: Set max 100 req/min (Airbyte handles with sleep)

**4. Stream Schema (auto-detect recommended)**
- Run a test read to auto-generate the schema from the API response
- Confirm fields match the data warehouse design mapping table above

### PCO Sync Schedule
- **Frequency:** Daily at 3:00 AM (off-peak)
- **Sync Mode per stream:** Incremental (use `updated_at` cursor) where supported, Full Refresh for small lookup tables (campuses, funds, group_types)

---

## STEP 3 — Connector 2: Engage Spaces

### About Engage Spaces
- **API Type:** REST
- **Base URL:** `https://YOURDOMAIN.engagespaces.com`
- **Auth:** API Key passed as URL query parameter `?apikey=YOUR_API_KEY`
- **Endpoints:** `/get` (single record) and `/gets` (list/multiple records)
- **Response Formats:** JSON or CSV
- **Docs:** Contact daniel.trafford@engagespaces.com for full API documentation
- **Contact:** daniel.trafford@engagespaces.com

### API Keys / Credentials Needed for Engage Spaces

- **Your subdomain** (e.g., `resonatecn.engagespaces.com`)
- **API Key** — request from Engage Spaces admin settings or from daniel.trafford@engagespaces.com

> ⚠️ **Action Required:** Confirm the full list of available API endpoints with your Engage Spaces admin or by contacting daniel.trafford@engagespaces.com. The API is not publicly documented — you may need to request endpoint documentation directly.

### Engage Spaces Streams to Build

| Stream | Endpoint Pattern | Key Fields | Maps To |
|--------|-----------------|------------|---------|
| `es_members` | `GET /gets/members?apikey=KEY` | id, first_name, last_name, email, phone, campus, status, created_at | `dim_person`, `bridge_person_identity` |
| `es_training` | `GET /gets/training?apikey=KEY` | id, person_id, course_name, completion_date, status, score | Training completion tracking (future `fact_course_completion`) |
| `es_events` | `GET /gets/events?apikey=KEY` | id, name, date, location, type | Event reference |
| `es_event_participants` | `GET /gets/event_participants?apikey=KEY` | id, event_id, person_id, registered_at, attended | `fact_experience_participation` |
| `es_communications` | `GET /gets/communications?apikey=KEY` | id, person_id, type, sent_at, opened | Engagement tracking |

> ⚠️ **Note:** Exact endpoint paths must be confirmed with Engage Spaces. The above are based on the documented capabilities — the actual paths may differ.

### Building the Engage Spaces Connector in Airbyte Connector Builder

**1. Global Config**
- Connector Name: `Engage Spaces`
- Base URL: `https://YOURDOMAIN.engagespaces.com`

**2. Authentication**
- Type: `API Key`
- Inject Into: `Request Parameter`
- Parameter Name: `apikey`
- API Key Value: *(your Engage Spaces API key)*

**3. Per-Stream Config (example: `es_members`)**
- Stream Name: `es_members`
- URL Path: `/gets/members`
- HTTP Method: `GET`
- Pagination: Confirm with Engage Spaces docs (likely offset or cursor)
- Primary Key: `id`
- Incremental field: `created_at` or `updated_at` if available

### Engage Spaces Sync Schedule
- **Frequency:** Daily at 3:30 AM
- **Sync Mode:** Incremental where supported, Full Refresh for small tables

---

## STEP 4 — Future Connectors (Credentials Needed)

### Pushpay

**Status:** Credentials not yet obtained — contact api@pushpay.com to request sandbox/production access

| Detail | Value |
|--------|-------|
| Auth | OAuth2 (Client Credentials or Authorization Code Flow) |
| Base URL | `https://api.pushpay.com` |
| Docs | https://pushpay.io/docs/api |
| Swagger | https://api.pushpay.com/swagger |
| Auth URL | `https://auth.pushpay.com/pushpay/oauth/authorize` |
| Token URL | `https://auth.pushpay.com/pushpay/oauth/token` |

**Key endpoints:**

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `pp_payments` | `GET /v1/merchant/{merchantKey}/payments` | id, amount, currency, status, fund, payer, payment_method, created_on | `fact_giving_transaction` |
| `pp_recurring_payments` | `GET /v1/merchant/{merchantKey}/recurringpaymentcontracts` | id, amount, frequency, status, payer, fund, created_on | Recurring giving |
| `pp_funds` | `GET /v1/merchant/{merchantKey}/funds` | id, name, code, tax_deductible | `dim_fund` |
| `pp_batches` | `GET /v1/merchant/{merchantKey}/batches` | id, total_amount, payment_count, status, created_on | Batch reconciliation |
| `pp_people` | Embedded in payment payer objects | id, first_name, last_name, email, mobile | `bridge_person_identity` (giving-only people) |

**API Keys needed:**
- OAuth2 Client ID
- OAuth2 Client Secret
- Merchant Key (per campus/organization)

---

### ServiceReef

**Status:** Credentials not yet obtained — request API key from ServiceReef admin dashboard or support

| Detail | Value |
|--------|-------|
| Auth | API Key (header or query param) |
| Base URL | `https://api.servicereef.com` |
| Docs | https://api.servicereef.com/docs |

**Key endpoints:**

| Stream | Endpoint | Key Fields | Maps To |
|--------|----------|------------|---------|
| `sr_members` | `GET /v1/members` | id, externalId, first_name, last_name, email, phone, campus | `bridge_person_identity` |
| `sr_events` | `GET /v1/events` | id, name, type, start_date, end_date, destination_country, destination_city, status | `fact_experience_participation` |
| `sr_participants` | `GET /v1/events/{id}/participants` | id, person_id, event_id, status, team_name, created_at | `fact_experience_participation` |
| `sr_payments` | `GET /v1/events/{id}/payments` | id, person_id, amount, status, created_at | Fundraising tracking |
| `sr_groups` | `GET /v1/groups` | id, name, type, church | Reference |
| `sr_positions` | `GET /v1/positions` | id, name, event_id, person_id, filled_at | Leadership roles |

**API Key needed:**
- ServiceReef API Key (from admin settings)

---

### Subsplash

**Status:** Credentials not yet obtained

| Detail | Value |
|--------|-------|
| Auth | OAuth |
| Base URL | `https://api.subsplash.com` |
| Docs | https://developer.subsplash.com/ |
| Note | Has pre-built PCO sync — may reduce what we need to pull |

**Streams to consider:**

| Stream | Purpose | Maps To |
|--------|---------|---------|
| `ss_giving` | App-based donations | `fact_giving_transaction` |
| `ss_groups` | App-based small groups | `dim_village` |
| `ss_users` | App users and engagement | `bridge_person_identity` |

> **Note:** Because Subsplash has a native PCO integration, check whether people data already flows through PCO before building a separate person identity pipeline.

---

## STEP 5 — BigQuery Destination Dataset Structure

All Airbyte connectors write to the `staging` BigQuery dataset. dbt reads from `staging` and writes to `core`, `marts`, and `reporting`.

```
rcn-data-warehouse (GCP Project)
├── staging/                    ← Airbyte writes raw data here
│   ├── pco_people
│   ├── pco_households
│   ├── pco_groups
│   ├── pco_memberships
│   ├── pco_donations
│   ├── pco_funds
│   ├── pco_check_ins
│   ├── pco_plans (services)
│   ├── es_members
│   ├── es_training
│   ├── es_events
│   ├── es_event_participants
│   ├── pp_payments (future)
│   ├── sr_events (future)
│   └── sr_participants (future)
│
├── core/                       ← dbt transforms (dims + facts)
├── identity/                   ← Person identity resolution tables
├── pii/                        ← Restricted PII fields
├── marts/                      ← Aggregated/derived tables
└── reporting/                  ← Looker-facing views
```

---

## STEP 6 — Sync Schedule Summary

| Connector | Frequency | Start Time | Mode |
|-----------|-----------|------------|------|
| PCO (all modules) | Daily | 3:00 AM | Incremental + Full Refresh (lookups) |
| Engage Spaces | Daily | 3:30 AM | Incremental + Full Refresh |
| Pushpay (future) | Daily | 4:00 AM | Incremental |
| ServiceReef (future) | Daily | 4:30 AM | Incremental |
| Subsplash (future) | Daily | 5:00 AM | Incremental |

---

## API Credentials Summary — What You Need

| Platform | Credential Type | Where to Get It | Status |
|----------|----------------|-----------------|--------|
| **Planning Center** | OAuth2 Client ID + Secret | https://api.planning.center/oauth/applications | ✅ Available |
| **BigQuery** | Service Account JSON key | GCP Console → IAM → Service Accounts | ✅ Available |
| **Engage Spaces** | API Key + Subdomain | Engage Spaces admin settings or daniel.trafford@engagespaces.com | ✅ Available |
| **Pushpay** | OAuth2 Client ID + Secret + Merchant Key | Email api@pushpay.com | ❌ Need to request |
| **ServiceReef** | API Key | ServiceReef admin dashboard or support | ❌ Need to request |
| **Subsplash** | OAuth credentials | developer.subsplash.com or Subsplash support | ❌ Need to request |

---

## Execution Plan — Session Walkthrough

When you give me control of your browser, here's the order of operations:

### Session 1: PCO Connector (Today)
1. **Open Airbyte** → Verify BigQuery destination is configured
2. **Builder** → Create new custom connector → `Planning Center Online`
3. Configure OAuth2 auth (you provide Client ID + Secret)
4. Build `pco_people` stream first (most critical)
5. Test stream → verify data flows to BigQuery `staging.pco_people`
6. Add remaining People module streams
7. Add Groups, Services, Giving, Check-Ins streams
8. Create Connection: PCO → BigQuery, set daily sync schedule
9. Run first full sync, verify row counts in BigQuery

### Session 2: Engage Spaces Connector
1. **Builder** → Create new custom connector → `Engage Spaces`
2. Configure API Key auth (you provide key + subdomain)
3. Build `es_members` stream first
4. Confirm endpoint paths (may need Engage Spaces API docs)
5. Add remaining streams
6. Create Connection → BigQuery, set daily sync schedule

### Session 3: Pushpay (after credentials obtained)
1. Complete OAuth app registration with Pushpay
2. Build connector using Swagger docs
3. Focus on `pp_payments` and `pp_funds` first (high-ROI giving data)

---

## Confirmed Details (2026-03-25)

1. **PCO OAuth App:** ✅ Created — Sam has the public key (Client ID) and private key (Client Secret)
2. **BigQuery Destination:** ✅ Already configured in Airbyte
3. **Engage Spaces subdomain:** ✅ `resonate.engagespaces.com`
4. **Historical data:** Full sync — all available historical data
5. **Number of campuses:** TBD — will discover during first sync
6. **Pushpay merchant key(s):** TBD — not yet needed (future connector)

---

## Reference Links

| Resource | URL |
|----------|-----|
| PCO Developer Docs | https://developer.planning.center/docs/ |
| PCO OAuth Apps | https://api.planning.center/oauth/applications |
| PCO Python Library (pypco) | https://github.com/billdeitrick/pypco |
| Pushpay API Docs | https://pushpay.io/docs/api |
| Pushpay Swagger | https://api.pushpay.com/swagger |
| ServiceReef API Docs | https://api.servicereef.com/docs |
| Engage Spaces Contact | daniel.trafford@engagespaces.com |
| Airbyte Connector Builder Docs | https://docs.airbyte.com/connector-development/connector-builder-ui/overview |
| Airbyte OAuth Docs | https://docs.airbyte.com/connector-development/connector-builder-ui/authentication |
| BigQuery Airbyte Destination | https://docs.airbyte.com/integrations/destinations/bigquery |
