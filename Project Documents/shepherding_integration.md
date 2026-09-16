# Shepherding Tool Integration

How the Shepherding Tool control spreadsheet becomes village attendance reporting in BigQuery.

**Source:** [Shepherding Tool Control Spreadsheet](https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw)
**Status:** models written, not yet deployed — see [Deploying](#deploying).

---

## Why this matters

The [warehouse gap assessment](warehouse_gap_assessment.md) named village-level engagement as the biggest hole in the warehouse. `mart_village_summary` computes membership with `current_groups LIKE '%group_name%'` — "Village A" matches members of "Village A2", renamed groups break history, and NULL names silently count zero. It was called the weakest join in the project.

The Shepherding Tool closes that gap directly. It is ID-keyed, it records who was present at which gathering, and it already covers 70 villages across 11 active campuses.

This integration does **not** modify `mart_village_summary`. That model still serves Engage Spaces groups. For the 70 Shepherding villages, `mart_village_attendance` supersedes it.

---

## What the source is

An Apps Script pipeline. Each church gets a generated Google Form; leaders submit attendance; a poller writes responses back into one control workbook, which is the system of record.

| Tab | Rows | Grain | Written by |
|---|---|---|---|
| `Churches` | 19 | one per campus | seeded by hand, extended by `Builder.gs` |
| `Villages` | 70 | one per village per academic year | `Builder.gs` |
| `Roster` | 1,746 | one per person per village | `FormSync.gs`, `Poller.gs` — append only |
| `Submissions` | 152 | one per form response | `Poller.gs` |
| `AttendanceLog` | 2,810 | one per attendee per gathering | `Poller.gs` |
| `Errors` | ~4,900 | operational log | every script |

Key conventions from the workbook's own README:

- `church_code` — 3 uppercase letters, stable forever, carried on every fact row
- `village_id` — `{church_code}-{YY}-V##`, assigned at create, never changes even on rename
- `person_local_id` — `{village_id}-P###`, stable until a name correction supersedes it
- `tab_name` — display only, derived from leader first names. Never key on it.
- Timezone is America/Los_Angeles
- **An absence is the absence of a row**

---

## Three decisions that shape the numbers

### 1. Re-submissions are unioned, not overwritten

19 of 152 village-dates have two or three submissions. Leaders re-open the form and send it again.

The obvious rule — latest submission wins — is wrong here. Several follow-ups are partial re-entries rather than corrections:

| Village | Date | Submissions | Latest wins | Union |
|---|---|---|---|---|
| MOS-26-V06 | 2026-09-01 | 38, then 1 | **1** | 38 |
| MSL-26-V13 | 2026-09-09 | 25, then 0 | **0** | 25 |
| MSL-26-V05 | 2026-08-26 | 33, then 1 | **1** | 34 |
| GJT-26-V03 | 2026-09-02 | 2, then 23 | 23 | 25 |

Across the affected dates, "latest wins" would report 248 attendee-records where 496 distinct people were recorded.

**Rule:** a person is present at a village-date if **any** submission for that date lists them. Implemented in `int_shepherding_attendance_resolved`. The raw submission grain is preserved in `fact_village_submission` for audit, and `fact_village_gathering.is_resubmitted` flags the affected rows.

### 2. `first_seen_at` is not a join date

`first_seen_at` records when the Apps Script wrote the roster row, not when the person joined the village. Because forms are processed on a sweep, it frequently lands a day or two *after* a gathering the person demonstrably attended — **1,252 of 2,810 attendance rows (45%) sit before their own `first_seen_at`**.

Using it as the membership start would mark those people ineligible for gatherings they attended, understating every attendance rate and, on some dates, pushing the rate above 100%.

**Rule:** the membership window opens at `least(first_seen_at, first gathering attended)` and closes at `greatest(retired_at, last gathering attended)`. Implemented in `int_shepherding_membership_window` and asserted by `assert_attendance_within_membership_window`.

### 3. Name corrections resolve forward

A correction never overwrites a row. The script appends a new `person_local_id`, then stamps `retired_at` and `superseded_by` on the old one. Attendance submitted before the correction still points at the retired id — 103 rows do.

Without resolution, one human appears as two members with half the attendance each. `int_shepherding_roster_resolved` walks the chain to the current identity with a recursive CTE. Chains are at most two hops today; the recursion handles arbitrary depth so a second correction cannot quietly break counts.

---

## Model layout

```
shepherding.{churches,villages,roster,submissions,attendance_log,errors}   external tables
        |
        v  models/staging/shepherding/
stg_shepherding_*                        typed, one model per tab
        |
        v  models/core/
int_shepherding_roster_resolved          name-correction chains -> current identity
int_shepherding_attendance_resolved      union re-submissions -> person x village-date
int_shepherding_membership_window        the attendance denominator
dim_village                              village + church + campus
dim_village_member                       roster, incl. superseded rows
fact_village_submission                  audit grain: one per form response
fact_village_gathering                   reporting grain: one per village-date
fact_village_attendance                  one per member per gathering, PRESENT OR ABSENT
        |
        v  models/marts/
mart_village_attendance                  village health over time
mart_village_member_engagement           who is drifting
```

### What each mart answers

**`mart_village_attendance`** — Village Coaches, Local Pastors. One row per village per gathering date: `attendance_rate`, `attendee_count_4_gathering_avg`, `attendee_count_change`, `days_since_village_last_gathering`, `is_latest_gathering` for current-state filtering.

**`mart_village_member_engagement`** — Village Leaders. One row per current member: `attendance_rate`, `attendance_rate_last_28_days`, `consecutive_misses`, `days_since_last_attended`, and an `engagement_status` of engaged / watch / drifting / retired / no_data.

> `engagement_status` thresholds (2 misses = watch, 3+ = drifting) are placeholders. They should be set with the team before anything escalates off them.

### Baseline numbers

On the source as of 2026-09-16: 130 village-dates with recorded attendance, 3,506 person-gathering rows, 2,613 present, 893 absences — an overall attendance rate of **74.5%**.

---

## Identity

`person_local_id` is authoritative. Village reporting depends on nothing else.

`dim_village_member.pco_person_id` is a best-effort link into `dim_person`, matched on full name with campus as a disambiguator — the same shape as `bridge_person_identity`. **Always read `pco_match_confidence` first:**

| Value | Meaning |
|---|---|
| `exact` | full name, unique within the village's campus |
| `likely` | full name, unique nationally, campus not confirmed |
| `ambiguous` | more than one candidate — do not rely on it |
| `unmatched` | partial name, or no candidate |

790 of 1,746 roster entries (45%) are first-name-only and will never match. Nothing downstream depends on the link.

---

## Deploying

**1. Share the workbook** (Viewer) with whatever queries BigQuery:

```
dbt-cloud@resonate-data-warehouse-442601.iam.gserviceaccount.com
```

Without this, the external tables create successfully but every query fails with `Permission denied while getting Drive credentials`.

**2. Create the external tables:**

```bash
bq query --use_legacy_sql=false --project_id=resonate-data-warehouse-442601 \
  < rcn_warehouse/setup/shepherding_external_tables.sql
```

For local runs your own credentials also need Drive scope:

```bash
gcloud auth login --enable-gdrive-access
gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/bigquery,https://www.googleapis.com/auth/cloud-platform
```

**3. Build and test:**

```bash
cd rcn_warehouse
dbt build --select +mart_village_attendance +mart_village_member_engagement
```

---

## Operational notes

- **Every external column is STRING by design.** Sheets external tables surface whatever the cell holds; dates arrive as ISO text, US-formatted text, or an Excel serial depending on cell formatting, and blank cells break `INT64`/`DATE` columns outright. This is what broke the previous `engage_spaces.village_attendance` table. Parsing happens in staging via the `sheet_date` / `sheet_timestamp` / `sheet_int` macros in `macros/sheet_values.sql`, which accept all observed shapes.
- **The workbook is live and staff-editable.** External tables read it on every query, so there is no sync to run — but a renamed tab, a deleted header cell or a reordered column silently breaks a model. Tab names and column ranges are pinned in the DDL.
- **Year rollover is unhandled.** `academic_year` is `2026-2027` on all 70 villages. If the workbook is reset or rolled over for 2027-2028, history disappears from the external tables because they hold no state. Add dbt snapshots on `roster` and `submissions` before that happens.
- `guest_count` is present in the schema but empty across all 152 submissions. Carried through as nullable.
- The `errors` external table is created and documented but has no dbt model — it carries no reporting data. Query it directly for pipeline monitoring; the workbook README asks for a weekly review.

---

## Open items

1. Set `engagement_status` thresholds with the team.
2. Decide whether `mart_village_summary` should be retired, or scoped to ES groups that are not Shepherding villages.
3. Add snapshots before the academic-year rollover.
4. 8 of 19 campuses are `closed` and 2 are `not_built`; only 11 are active. Confirm that closed campuses should stay in `dim_village` for historical joins (current behaviour).
