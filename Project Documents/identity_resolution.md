# Identity Resolution — Cross-Platform Person Matching

**Last Updated:** 2026-04-09

## Overview

RCN uses multiple platforms that each maintain their own person records:

- **Planning Center Online (PCO)** — 31,643 people (primary people system)
- **Engage Spaces (ES)** — 12,175 users (discipleship and training)

There is no shared unique identifier between these systems. The identity resolution layer links records across platforms so that a single person's activity can be viewed holistically — their PCO check-ins, ES group participation, discipleship status, and more — all tied to one unified record.

## How It Works

Identity resolution happens in two dbt models:

```
stg_pco_people ──┐
stg_pco_emails ──┤
                 ├──► bridge_person_identity ──► dim_person
stg_es_users ────┘
```

### Step 1: bridge_person_identity (two-pass matching)

This model finds matches between PCO and ES using two methods, applied in priority order:

#### Pass 1: Email Matching (highest confidence)

PCO emails (from `stg_pco_emails`) are matched against ES usernames (which are email addresses). Email matches are assigned `match_method = 'email'` and `match_confidence = 'exact'` because email addresses are unique identifiers.

#### Pass 2: Name Matching (remaining unmatched people only)

For PCO people who were **not** matched by email, the model falls back to joining on **normalized name** (lowercased, trimmed first name + last name). Only ES users who were also not matched by email are considered.

For each name match, a **confidence level** is assigned based on name uniqueness:

| Confidence | Rule | Meaning |
|-----------|------|---------|
| **exact** | Name is unique in both PCO and ES | Only one person with that name in each system — high-confidence match |
| **likely** | Name is unique in one system but not the other | Probably correct, but one side has duplicates |
| **ambiguous** | Name appears multiple times in both systems | Multiple candidates on both sides — manual review recommended |

The model exposes `match_method` ('email' or 'name'), `match_confidence`, and `pco_count`/`es_count` columns for inspection.

**Current match distribution:**

| Method | Confidence | Match Rows |
|--------|-----------|-----------|
| email | exact | ~1,200+ |
| name | exact | varies |
| name | likely | varies |
| name | ambiguous | varies |
| **Total** | | **~2,300** |

*Note: The total match count decreased from ~2,929 (name-only era) to ~2,300 because email-based deduplication is more precise — it eliminates false name matches where different people shared the same name.*

### Step 2: dim_person (unified person record)

This model consumes the bridge table and produces one row per person across all systems:

1. **PCO people with ES match** — For each PCO person, the best ES match is selected (preferring email matches over name matches, then exact > likely > ambiguous). The PCO record is enriched with ES fields and PCO contact info (email, phone, address) and 22 pivoted custom fields.

2. **PCO people without ES match** — Kept as-is with null ES fields but still enriched with PCO contact info and custom fields.

3. **ES-only people** — People in Engage Spaces who have no match in PCO at all. Included with `primary_source = 'es_only'` and null PCO fields.

**Current dim_person:** ~41,700 rows

## Key Fields in dim_person

| Field | Source | Description |
|-------|--------|-------------|
| `pco_person_id` | PCO | Planning Center person ID (null for ES-only) |
| `es_user_id` | ES | Engage Spaces user ID (null if no match) |
| `es_match_method` | Bridge | `email` or `name` (null if no match) |
| `es_match_confidence` | Bridge | exact / likely / ambiguous / null |
| `primary_source` | Derived | `pco` or `es_only` |
| `first_name`, `last_name` | PCO (preferred) | Name fields from primary source |
| **PCO Contact Info** | | |
| `pco_email` | PCO | Primary email from PCO |
| `pco_phone` | PCO | Primary phone from PCO |
| `pco_city`, `pco_state` | PCO | Primary address from PCO |
| **PCO Custom Fields** | | |
| `is_baptized`, `baptism_date`, `baptism_site` | PCO | Baptism tracking |
| `school_year`, `demographic`, `major` | PCO | Student info |
| `ownership_start_date`, `ownership_end_date` | PCO | Ownership tracking |
| `village_leaders`, `huddle_leader` | PCO | Leadership assignments |
| `serving`, `discipleship_type`, `staff_role` | PCO | Ministry involvement |
| **ES Fields** | | |
| `es_email` | ES | Email from Engage Spaces (`username` field) |
| `belief_status` | ES | Believer / Seeker / etc. |
| `discipleship_context` | ES | DT Group / None / etc. |
| `discipleship_generation` | ES | Discipleship generation |
| `es_current_groups` | ES | Comma-separated group names |
| `es_group_leader` | ES | Group leader name |
| `last_village_activity` | ES | Date of last village activity |
| `last_discipleship_activity` | ES | Date of last discipleship activity |

## Limitations and Known Issues

### Name-based matching (Pass 2) is imperfect

- **False positives:** Two different people named "John Smith" in PCO and ES will be matched even if they are different individuals. The `ambiguous` confidence flag helps identify these, but `likely` matches can also be wrong.
- **False negatives:** If a person's name is spelled differently across systems (e.g., "Mike" vs "Michael", "MacDonald" vs "Mcdonald"), they will not match.
- Email matching (Pass 1) largely mitigates these issues for people who have the same email in both systems.

### ES-only people may actually exist in PCO

ES-only people may include PCO people whose names/emails don't match due to spelling variations, nicknames, different email addresses, or data entry differences.

## Future Improvements

1. **Campus/site as a disambiguator** — ES users have `site` (location IDs) and PCO people can be linked to campuses. Using campus as a secondary match signal would improve confidence for common names.

2. **Fuzzy name matching** — Applying techniques like Soundex, Levenshtein distance, or nickname normalization ("Mike" → "Michael") would catch spelling variations. BigQuery supports these functions natively.

3. **Manual override table** — A seed file or lookup table where staff can manually confirm or reject matches for ambiguous cases.

4. **PCO Groups module** — When PCO Groups Airbyte connectors are built, group membership data from PCO could serve as an additional matching signal.

## How to Query

### Find a specific person's cross-platform data
```sql
SELECT *
FROM `resonate-data-warehouse-442601.core_core.dim_person`
WHERE lower(first_name) = 'john' AND lower(last_name) = 'smith'
```

### Review all ambiguous matches for manual resolution
```sql
SELECT
    pco_person_id, es_user_id,
    match_method, match_confidence,
    pco_first_name, pco_last_name,
    es_first_name, es_last_name,
    pco_count, es_count
FROM `resonate-data-warehouse-442601.core_core.bridge_person_identity`
WHERE match_confidence = 'ambiguous'
ORDER BY pco_last_name, pco_first_name
```

### Count matched vs unmatched by source and method
```sql
SELECT
    primary_source,
    es_match_method,
    es_match_confidence,
    COUNT(*) as person_count
FROM `resonate-data-warehouse-442601.core_core.dim_person`
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
```
