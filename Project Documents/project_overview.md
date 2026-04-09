# Operation Iron Keep - Project Overview

**Project:** Data Integration Initiative for Resonate Collegiate Network
**Status:** Architecture Decided, Implementation Planning
**Last Updated:** 2026-03-25

---

## Mission

Build a centralized data platform that consolidates data from multiple church management systems into a single, person-centric view. This enables reporting at four leadership levels:

| Level | Scope | Example Question |
|-------|-------|------------------|
| Village Leader | One village/small group | "How are my 12 people engaging?" |
| Village Coach | Multiple villages | "Which villages need attention?" |
| Local Pastor | One church | "What's our giving trend? Who's serving?" |
| Network/CBE | All churches | "Network-wide baptisms this year?" |

> **Core philosophy:** Church health rolls up from person story + participation over time.

---

## Architecture Decision

We are building an **ELT (Extract, Load, Transform) pipeline** using:

```
Source Systems (APIs)          Subsplash
       |                          |
       |                   [ Snowflake ]    -- Subsplash loads data here
       |                          |
   [ Airbyte ]  <-----------------+         -- Extract & Load
       |
   [ BigQuery ]                             -- Cloud Data Warehouse (Google Cloud)
       |
   [ dbt ]                                  -- Transform (SQL models, testing, docs)
       |
   [ Reporting ]                            -- BI/dashboards (TBD)
```

**Note:** Most sources flow directly from APIs into BigQuery via Airbyte. The exception is **Subsplash**, which loads data into our Snowflake instance. Airbyte then extracts from Snowflake into BigQuery, where dbt transforms it alongside everything else.

### Why This Stack

| Component | Role | Why We Chose It |
|-----------|------|-----------------|
| **Airbyte** | Extract & Load | Open-source, custom connector builder for church APIs, no per-row costs |
| **BigQuery** | Data Warehouse | Cost-effective, scales well, native Google Cloud integration |
| **Snowflake** | Subsplash data staging | Subsplash loads their data here; Airbyte pulls from Snowflake to BigQuery |
| **dbt** | Transform | Industry standard for in-warehouse transforms, version-controlled SQL, built-in testing |

### Key Considerations

- **Custom connectors required:** No major ELT platform has pre-built connectors for church management systems. Airbyte's Connector Builder lets us create these without heavy coding.
- **Daily batch refresh** is sufficient for v1 -- no need for real-time streaming.
- **dbt Core (free)** is the starting point; dbt Cloud can be added later if needed.

---

## Source Systems

| Platform | Purpose | Priority | Auth |
|----------|---------|----------|------|
| **Planning Center Online** | Church management (people, groups, services, giving) | Primary | OAuth2 |
| **Pushpay** | Donations and recurring giving | Primary | OAuth2 |
| **ServiceReef** | Mission trips and experiences | Primary | API Key |
| **Engage Spaces** | Training and member engagement | Primary | API Key |
| **Subsplash** | Church app, giving, groups | Secondary | OAuth |
| **Pathwright** | Online courses | Deferred (v1.1) | OAuth/Zapier |

See `source_systems.md` for detailed platform information.

---

## What Success Looks Like

1. **Single source of truth** for person data across all platforms
2. **Daily refreshed data** in BigQuery available for reporting
3. **Self-service reporting** for leaders at each level
4. **Historical trend analysis** for giving, attendance, and engagement
5. **Spiritual journey tracking** from first visit through leadership development

---

## Project Documents

| Document | Purpose |
|----------|---------|
| `project_overview.md` | This file -- high-level project summary |
| `source_systems.md` | Detailed platform and API information |
| `next_steps.md` | Current action items and priorities |
| `Archive/` | Previous research and planning documents |

---

## Glossary

| Term | Definition |
|------|------------|
| **Village** | Small group / community group in RCN terminology |
| **Joshua** | Leadership role within a village |
| **PCO** | Planning Center Online |
| **ELT** | Extract, Load, Transform -- data is loaded raw then transformed in the warehouse |
| **dbt** | Data build tool -- SQL-based transformation framework |
