# ETL Tool Comparison for RCN Data Warehouse

**Date:** 2024-12-23
**Purpose:** Evaluate ETL/ELT tools for extracting data from church management platforms and loading into BigQuery
**BI Tool:** Looker (confirmed)
**Refresh Frequency:** Daily batch

---

## Executive Summary

After researching ETL options, I recommend a **tiered approach**:

| Recommendation | Tool | Why |
|---------------|------|-----|
| **Primary (Best Value)** | Airbyte (self-hosted) + dbt | Open source, custom connectors, no per-row costs |
| **Alternative (Easier Setup)** | Meltano + dbt | Fully open source, Singer ecosystem, CLI-first |
| **Managed Option** | Portable.io | Flat $200/mo, custom connector building included |

**Key Insight:** None of the major ETL platforms have pre-built connectors for your church management systems (Planning Center, Pushpay, ServiceReef, Engage Spaces, Subsplash). You will need **custom connectors** regardless of which tool you choose. This makes open-source options more attractive since you're building connectors anyway.

---

## Source System Connector Availability

| Source System | Fivetran | Stitch | Airbyte | Hevo | Portable | Meltano/Singer |
|--------------|----------|--------|---------|------|----------|----------------|
| Planning Center | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ (pypco library exists) |
| Pushpay | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ |
| ServiceReef | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ |
| Engage Spaces | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ |
| Subsplash | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ |
| Pathwright | ❌ | ❌ | ❌ | ❌ | ❓ | ❌ |
| **BigQuery (destination)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Legend:** ✅ = Native connector | ❌ = Not available | ❓ = May be available (contact vendor)

**Note:** Portable.io claims to build custom connectors for free. Worth inquiring if they have or can build church management connectors.

---

## Tool Comparison Matrix

### Tier 1: Managed ETL Platforms

| Feature | Fivetran | Stitch | Hevo Data | Portable.io |
|---------|----------|--------|-----------|-------------|
| **Pricing Model** | Per MAR (Monthly Active Rows) | Per row | Per event | Flat per flow |
| **Starting Price** | ~$500/mo minimum | $100/mo | Free tier available | $200/mo flat |
| **Custom Connectors** | Paid add-on | Singer taps | Limited | Free (they build) |
| **BigQuery Support** | ✅ Native | ✅ Native | ✅ Native | ✅ Native |
| **Church Platform Connectors** | ❌ None | ❌ None | ❌ None | ❓ Possibly |
| **Best For** | Enterprise, standard SaaS apps | Startups, standard sources | Mid-size, no-code | Long-tail APIs |

#### Pricing Details

**Fivetran:**
- Free tier: 500K MAR, 5 connectors
- Standard: $5 base + usage per connector
- Unpredictable costs as data grows
- 15% discount for annual commitment

**Stitch:**
- Standard: $100/mo for 5M rows
- Advanced: $1,250/mo for 100M rows
- Premium: $2,500/mo for 1B rows

**Hevo Data:**
- Free: 1M events, 50 connectors
- Starter: Pay-as-you-go after free tier
- No open-source option

**Portable.io:**
- Free: Manual runs only, no volume limits
- Standard: $200/mo flat for scheduled flows
- **Key Advantage:** They build custom connectors for free
- Best for organizations with niche data sources

---

### Tier 2: Open Source ETL Platforms

| Feature | Airbyte | Meltano |
|---------|---------|---------|
| **License** | Open source (ELv2) | Open source (MIT) |
| **Self-Hosted Cost** | Infrastructure only | Infrastructure only |
| **Cloud Option** | Airbyte Cloud ($$$) | No cloud offering |
| **Connector Count** | 600+ | 300+ (Singer ecosystem) |
| **Custom Connector Dev** | Low-code Builder + CDK | SDK (Python) |
| **BigQuery Support** | ✅ Native target | ✅ target-bigquery |
| **Learning Curve** | Moderate (UI-based) | Steeper (CLI-first) |
| **Orchestration** | Built-in | Built-in (Airflow-based) |
| **dbt Integration** | Via orchestration | Native |
| **Best For** | Teams wanting UI + flexibility | Technical teams, full control |

#### Airbyte Details

**Self-Hosted (Recommended for RCN):**
- Deploy on GCP Compute Engine or Cloud Run
- Estimated infrastructure cost: $50-150/mo
- No per-row or per-connector fees
- Full control over data

**Custom Connector Building:**
- No-code Connector Builder for simple REST APIs
- Low-code CDK (Python) for complex cases
- Community connectors available

**Airbyte Cloud:**
- Starting at $300/mo
- Per-credit pricing (unpredictable)
- Not recommended for cost-sensitive orgs

#### Meltano Details

**Architecture:**
- Built on Singer taps/targets
- Integrates Airflow for orchestration
- Native dbt integration

**Custom Connector Building:**
- Meltano SDK (Python)
- Build Singer taps for any REST API
- Well-documented, active community

**Infrastructure:**
- Run on any Linux server
- Recommended: Cloud Run or Compute Engine
- Estimated cost: $30-100/mo

---

### Tier 3: Custom Development

| Feature | Cloud Functions + dbt | Cloud Composer (Airflow) |
|---------|----------------------|--------------------------|
| **Type** | Serverless ETL | Managed orchestration |
| **Monthly Cost** | $10-50 | $300-500 minimum |
| **Flexibility** | Maximum | Maximum |
| **Maintenance** | You build everything | Managed Airflow |
| **Learning Curve** | Moderate (Python) | Steep (Airflow) |
| **Best For** | Simple, low-volume pipelines | Complex, enterprise pipelines |

#### Cloud Functions Approach

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

**Cost Breakdown:**
| Component | Monthly Cost |
|-----------|-------------|
| Cloud Scheduler | ~$0.10 (6 jobs) |
| Cloud Functions | ~$5-20 (daily runs) |
| Cloud Storage | ~$1-5 (staging) |
| BigQuery Storage | ~$5-20 |
| BigQuery Compute | Free tier (1TB/mo) |
| **Total** | **~$15-50/mo** |

**Pros:**
- Lowest cost option
- Full control over extraction logic
- No vendor lock-in
- Pay only for what you use

**Cons:**
- Must write all extraction code
- No built-in monitoring/alerting (add Cloud Monitoring)
- Manual retry/error handling

#### Cloud Composer (Managed Airflow)

**Not Recommended for RCN** due to:
- Minimum ~$300/mo for smallest environment
- Complex to configure
- Overkill for 6-7 source systems with daily batch

---

## Python Libraries for Source Systems

Since custom development is likely needed, here are available libraries:

| Source | Python Library | Status | Notes |
|--------|---------------|--------|-------|
| Planning Center | [pypco](https://github.com/billdeitrick/pypco) | Active | Full API support, auto-pagination, rate limiting |
| Pushpay | None | — | Use `requests` with OAuth2 |
| ServiceReef | None | — | Use `requests` with API key |
| Engage Spaces | None | — | Use `requests` with API key |
| Subsplash | None | — | Use `requests` with OAuth |
| Pathwright | None | — | Use `requests` or Zapier webhooks |

---

## dbt for Transformation Layer

Regardless of ETL tool choice, **dbt (data build tool)** is recommended for the transformation layer.

### Why dbt?

1. **Looker Integration:** dbt + BigQuery + Looker is a proven, well-documented stack
2. **Open Source:** dbt Core is free
3. **Version Control:** SQL transformations in Git
4. **Testing:** Built-in data quality tests
5. **Documentation:** Auto-generated data lineage

### dbt Pricing

| Option | Cost | Features |
|--------|------|----------|
| dbt Core | Free | CLI, full functionality |
| dbt Cloud (Developer) | Free | 1 seat, 1 project |
| dbt Cloud (Team) | $100/seat/mo | Collaboration, scheduling |

**Recommendation:** Start with dbt Core (free), run via Cloud Scheduler or your ETL orchestrator.

---

## Recommendation for RCN

### Option A: Airbyte Self-Hosted + dbt (Recommended)

**Why:**
- No per-row costs (critical for growing org)
- No-code Connector Builder for church APIs
- UI for non-technical team members
- dbt integration for transformations
- Active community, good documentation

**Estimated Monthly Cost:**
| Component | Cost |
|-----------|------|
| Compute Engine (e2-medium) | ~$35 |
| BigQuery (storage + compute) | ~$20 |
| dbt Core | Free |
| Cloud Scheduler | ~$1 |
| **Total** | **~$56/mo** |

**Implementation Steps:**
1. Deploy Airbyte on Compute Engine
2. Build custom connectors for PCO, Pushpay, ServiceReef using Connector Builder
3. Configure BigQuery destination
4. Set up dbt project for transformations
5. Connect Looker to BigQuery

---

### Option B: Custom Cloud Functions + dbt (Lowest Cost)

**Why:**
- Absolute lowest cost (~$25/mo)
- Maximum flexibility
- No external dependencies
- Leverages existing Python library (pypco)

**Estimated Monthly Cost:**
| Component | Cost |
|-----------|------|
| Cloud Functions | ~$10 |
| Cloud Storage | ~$2 |
| BigQuery | ~$10 |
| dbt Core | Free |
| **Total** | **~$25/mo** |

**Trade-offs:**
- Requires Python development for each source
- Manual monitoring setup
- No UI for pipeline management

---

### Option C: Portable.io (Managed, Predictable)

**Why:**
- Flat $200/mo pricing (predictable)
- They build custom connectors for you
- No infrastructure management
- Good for non-technical teams

**When to Choose:**
- If development resources are limited
- If Portable already has church management connectors
- If predictable billing is priority over lowest cost

**Action Item:** Contact Portable.io to ask:
1. Do you have Planning Center, Pushpay, ServiceReef connectors?
2. What's the timeline to build custom connectors?
3. Is there nonprofit pricing?

---

## Cost Comparison Summary

| Solution | Monthly Cost | Setup Effort | Maintenance |
|----------|-------------|--------------|-------------|
| **Airbyte Self-Hosted + dbt** | ~$56 | Medium | Low |
| **Meltano + dbt** | ~$40 | High | Medium |
| **Cloud Functions + dbt** | ~$25 | High | Medium |
| **Portable.io** | $200 | Low | None |
| **Fivetran** | $500+ | Low | None |
| **Stitch** | $100+ | Low | None |

---

## Architecture Diagram: Recommended Stack

```
┌─────────────────────────────────────────────────────────────┐
│                     SOURCE SYSTEMS                          │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│   PCO    │ Pushpay  │ServiceReef│ Engage  │   Subsplash    │
│  OAuth   │  OAuth2  │  API Key │  API Key │    OAuth       │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴───────┬────────┘
     │          │          │          │             │
     └──────────┴──────────┴──────────┴─────────────┘
                           │
                    ┌──────▼──────┐
                    │   Airbyte   │
                    │ (self-host) │
                    │ Compute Eng │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  BigQuery   │
                    │  (staging)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    dbt      │
                    │ (transform) │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  BigQuery   │
                    │   (marts)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Looker    │
                    │ (reporting) │
                    └─────────────┘
```

---

## Next Steps

1. **Decision:** Choose between Option A (Airbyte), B (Custom), or C (Portable)
2. **If Airbyte:** Deploy on Compute Engine, build first connector (PCO)
3. **If Custom:** Set up Cloud Functions project, start with pypco extraction
4. **If Portable:** Contact sales about church management connectors
5. **All Options:** Set up dbt project structure, define initial models

---

## Sources

- [Fivetran Pricing](https://www.fivetran.com/pricing)
- [Airbyte Open Source](https://airbyte.com/product/airbyte-open-source)
- [Meltano Documentation](https://docs.meltano.com/getting-started/)
- [Portable.io Pricing](https://portable.io/pricing)
- [pypco - Planning Center Python Library](https://github.com/billdeitrick/pypco)
- [Cloud Functions Pricing](https://cloud.google.com/functions/pricing)
- [BigQuery Pricing](https://cloud.google.com/bigquery/pricing)
- [dbt with BigQuery Guide](https://docs.getdbt.com/guides/dbt-python-bigframes)
- [Stitch Pricing](https://www.stitchdata.com/pricing/)
- [Hevo Data](https://hevodata.com/)
