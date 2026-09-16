# Village Attendance in BigQuery — Reporting Guide

Instructions for building reports, dashboards, or analyses on Resonate Collegiate Network village attendance data.

**Project:** `resonate-data-warehouse-442601` (BigQuery, location `US`)
**Source of truth:** the Shepherding Tool control spreadsheet, exposed as live external tables
**Build:** dbt Cloud job "Daily Build" (`dbt build`, full project)

If you only read one thing: **query `core_marts.mart_village_attendance` for village trends and `core_marts.mart_village_member_engagement` for person-level engagement.** Both are pre-joined and dashboard-ready. Everything below is for when those don't answer the question.

---

## 1. Where the data lives

Four datasets, in dependency order:

| Dataset | What | Materialization | Freshness |
|---|---|---|---|
| `shepherding` | Raw tabs of the Google Sheet | **External** (Sheets-backed) | Live, every query |
| `core_staging` | Typed/cleaned one-per-tab | Views | Live, every query |
| `core_core` | Dimensions and facts | Tables | As of last dbt run |
| `core_marts` | Reporting models | Tables | As of last dbt run |

Two consequences you must design around:

**Staging is live; marts are a snapshot.** `shepherding.*` and `core_staging.stg_shepherding_*` read the spreadsheet at query time — a form submitted five minutes ago is already visible. `core_core.*` and `core_marts.*` reflect the last Daily Build. A dashboard on the marts lags by up to a day. That is expected, not a broken pipeline.

**Every query against `shepherding.*` or `core_staging.*` needs Drive access.** These are Sheets-backed external tables. The querying principal must be able to read the workbook, or the query fails with `Access Denied: BigQuery: Permission denied while getting Drive credentials`. The dbt Cloud service account has this. A human on the `resonate.net` domain has this. `core_core` and `core_marts` are ordinary tables with no such requirement — **prefer them for anything user-facing.**

---

## 2. What the grain is

Getting the grain wrong is the single most likely way to produce incorrect numbers here.

| Table | One row per | Rows (2026-09-16) |
|---|---|---|
| `core_core.dim_village` | village | 70 |
| `core_core.dim_village_member` | roster entry (incl. superseded) | 1,771 (1,687 current) |
| `core_core.fact_village_submission` | **form submission** | 157 |
| `core_core.fact_village_gathering` | **village × date** | 136 |
| `core_core.fact_village_attendance` | **member × gathering, present OR absent** | 3,727 (2,708 present) |
| `core_marts.mart_village_attendance` | village × date | 136 |
| `core_marts.mart_village_member_engagement` | current member | 1,687 |

Note that submissions (157) exceed gatherings (136). That is not an error — see rule 1.

---

## 3. Five rules that will make you wrong if you ignore them

### Rule 1 — A gathering is not a submission

Leaders re-submit the form. 19 village-dates have two or three submissions. `fact_village_gathering` collapses these: a person counts as present if **any** submission for that village-date lists them.

Do **not** compute attendance from `shepherding.attendance_log` or `fact_village_submission`. You will double-count people and inflate gathering counts. Use `fact_village_gathering` or `fact_village_attendance`.

`fact_village_submission` exists only for audit — "who submitted what, when". Filter `is_resubmission` or `submission_seq` if you need that story.

### Rule 2 — Absence is a row here, but not in the source

The spreadsheet records attendance only; an absence is simply the absence of a row. `fact_village_attendance` **materialises absences** by pairing each gathering with the members eligible for it. So:

```sql
-- CORRECT attendance rate
select countif(attended_flag) / count(*) from core_core.fact_village_attendance;

-- WRONG: every row in the raw log is a presence, so this is always 1.0
select count(*) from shepherding.attendance_log;
```

`attended_flag` is a `BOOL`. Rows where it is `false` are real absences, not missing data.

### Rule 3 — The denominator is a membership window, not the whole roster

A member only counts toward a gathering they were eligible for. The window opens at `least(first_seen_at, first gathering attended)` and closes at `greatest(retired_at, last gathering attended)`.

This matters because **`first_seen_at` in the source is when the script wrote the roster row, not when the person joined** — 45% of source attendance rows predate their own `first_seen_at`. Never window on `first_seen_date` yourself. Use `membership_start_date` / `membership_end_date` on `dim_village_member`, or just use the pre-computed `eligible_member_count` on `fact_village_gathering`.

Someone who joined in week six is not counted absent for weeks one to five.

### Rule 4 — `person_local_id` is the identity; `pco_person_id` is best-effort

`person_local_id` (`{village_id}-P###`) is authoritative and stable. Name corrections are already resolved forward, so a person who was renamed mid-year appears as one member with continuous history.

`pco_person_id` links to `dim_person` but resolves for only **~22%** (377 of 1,687), because 45% of the roster is first-name-only. **Always filter on `pco_match_confidence` before using it:**

| Value | Meaning |
|---|---|
| `exact` | full name, unique within the village's campus |
| `likely` | full name, unique nationally, campus unconfirmed |
| `ambiguous` | multiple candidates — do not use |
| `unmatched` | partial name or no candidate |

Never present a metric that silently drops unmatched people. If you join to PCO, state the coverage.

### Rule 5 — `engagement_status` thresholds are placeholders

`mart_village_member_engagement.engagement_status` is `engaged` / `watch` / `drifting` / `retired` / `no_data`, where `watch` = 2 consecutive misses and `drifting` = 3+. **These numbers were invented as a starting point and have never been agreed with RCN staff.**

Do not build alerting, escalation, or "at-risk" lists on them without confirming the thresholds first. Use the underlying `consecutive_misses`, `attendance_rate`, and `days_since_last_attended` if you need to define your own.

---

## 4. Table reference

### `core_marts.mart_village_attendance` — village health over time
Grain: village × gathering date. Start here for coach/pastor dashboards.

Measures: `attendee_count`, `eligible_member_count`, `absent_count`, `attendance_rate`, `guest_count`
Trend: `attendee_count_4_gathering_avg`, `attendee_count_change`, `previous_attendee_count`, `previous_gathering_date`, `days_since_previous_gathering`, `gathering_number`
Current-state helpers: `is_latest_gathering` (filter to this for a "today" view without a correlated subquery), `days_since_village_last_gathering`
Grouping: `village_id`, `village_name`, `leader_names`, `church_code`, `church_name`, `campus_name`, `pco_campus_id`, `academic_year`, `gathering_week_start_date`, `gathering_iso_year`, `gathering_iso_week`, `gathering_type`
Data quality: `submission_count`, `is_resubmitted`, `max_reported_attendee_count`, `differs_from_reported_headcount`, `last_submitted_by`, `last_submitted_at`

### `core_marts.mart_village_member_engagement` — who is drifting
Grain: one current member.

`gatherings_eligible`, `gatherings_attended`, `gatherings_missed`, `attendance_rate`, `attendance_rate_last_28_days`, `consecutive_misses`, `days_since_last_attended`, `last_attended_date`, `first_eligible_gathering_date`, `last_eligible_gathering_date`, `engagement_status`, `membership_start_date`, `membership_end_date`, `is_retired`, `display_name`, `name_completeness`, `has_full_name`, `pco_person_id`, `pco_match_confidence`

### `core_core.fact_village_attendance` — the flexible one
Grain: member × gathering, present or absent. Use when the marts don't have the cut you need. Already denormalised with village, church, campus and member attributes, so most questions need no joins.

Key: `village_attendance_sk`. Links: `village_gathering_sk`, `village_id`, `person_local_id`.
`attended_flag` BOOL, `source_submission_count`, `person_name_at_submission` (name as shown on the form that day), `gathering_week_start_date`, `member_is_retired`.

### `core_core.fact_village_gathering` — gathering grain
Same measures as `mart_village_attendance` minus the trend columns. The mart is this plus window functions; prefer the mart.

### `core_core.dim_village` (70) / `dim_village_member` (1,771)
`dim_village`: `village_id` (permanent, survives renames), `village_name`, `leader_names`, `church_code`/`church_name`, `pco_campus_id`/`campus_name`, `academic_year`, `village_status`, `church_status`, plus workbook/form IDs for tracing a number back to its source form.

`dim_village_member`: includes superseded rows. **Filter `is_current` unless you are specifically tracing name-correction history.** Facts carry the current id, so `fact.person_local_id = dim.person_local_id` is 1:1.

### `core_core.fact_village_submission` (157) — audit only
One row per form response as sent. `reported_attendee_count` vs `logged_attendee_count`, `has_count_mismatch`, `submission_seq`, `submissions_for_gathering`, `is_resubmission`, `submitted_by`, `status`. Not for reporting.

---

## 5. Worked queries

```sql
-- Village health, most recent gathering per village
select village_name, church_name, gathering_date,
       attendee_count, eligible_member_count, round(attendance_rate, 3) as rate,
       attendee_count_change, days_since_village_last_gathering
from `resonate-data-warehouse-442601.core_marts.mart_village_attendance`
where is_latest_gathering
order by attendance_rate;

-- Weekly attendance trend by campus
select campus_name, gathering_week_start_date,
       count(distinct village_id) as villages_meeting,
       sum(attendee_count) as attendees,
       safe_divide(sum(attendee_count), sum(eligible_member_count)) as attendance_rate
from `resonate-data-warehouse-442601.core_marts.mart_village_attendance`
group by 1, 2
order by 1, 2;

-- Members who have missed 3+ consecutive gatherings
select church_name, village_name, display_name,
       consecutive_misses, days_since_last_attended, round(attendance_rate, 2) as rate
from `resonate-data-warehouse-442601.core_marts.mart_village_member_engagement`
where consecutive_misses >= 3 and not is_retired
order by consecutive_misses desc, days_since_last_attended desc;

-- Villages that have gone quiet (no gathering in 21+ days)
select distinct village_name, church_name, leader_names,
       days_since_village_last_gathering
from `resonate-data-warehouse-442601.core_marts.mart_village_attendance`
where is_latest_gathering and days_since_village_last_gathering >= 21
order by days_since_village_last_gathering desc;

-- Custom cut straight off the person-grain fact
select church_name, gathering_week_start_date,
       countif(attended_flag) as present,
       count(*) as eligible,
       safe_divide(countif(attended_flag), count(*)) as rate
from `resonate-data-warehouse-442601.core_core.fact_village_attendance`
group by 1, 2
order by 1, 2;
```

---

## 6. Things that look like bugs but are not

- **70 villages exist, only ~56 appear in attendance.** The rest have not submitted a form yet. Report against `dim_village` if you need the full denominator including silent villages — that silence is itself the signal.
- **`guest_count` is always NULL.** The field exists in the form schema but has never been filled in. Don't surface it.
- **`attendee_count` ≠ `max_reported_attendee_count` on some rows.** The first is distinct people across all submissions; the second is the largest headcount any one form claimed. `differs_from_reported_headcount` flags these.
- **Some gatherings have 0 attendees.** A leader submitted an empty form. These are kept deliberately — a meeting with nobody recorded is a signal, not a non-event.
- **`tab_name` on `dim_village` looks like a name but isn't one.** It's display-only, derived from leader first names. Never key or group on it. Use `village_id`.
- **`academic_year` is `2026-2027` on every row.** There is only one year of data. Do not assume multi-year history exists.

---

## 7. If you add or change dbt models

- Project lives in `rcn_warehouse/`. Staging → core → marts, one subfolder per source system.
- **dbt Cloud runs dbt Fusion 2.0.4, not dbt-core.** Fusion treats the generic-test `arguments:` deprecation as a **hard parse error**. Any `relationships` or `accepted_values` test must nest `to`/`field`/`values` under `arguments:`. dbt-core only warns, so **this cannot be caught locally** — it will fail the Cloud run.
- Sheet values arrive as STRING by design (dates come through as ISO text, US-formatted text, or Excel serials depending on cell formatting). Parse with the `sheet_date` / `sheet_timestamp` / `sheet_int` macros in `rcn_warehouse/macros/sheet_values.sql`. Do not add typed columns to the external tables.
- Five singular tests in `rcn_warehouse/tests/` guard the invariants above, notably `assert_attendance_within_membership_window` (catches denominator errors that would push rates above 100%) and `assert_village_attendance_grain`.
- Trigger a build: `POST https://wz475.us1.dbt.com/api/v2/accounts/70471823546510/jobs/70471823583192/run/` with `Authorization: Token <token>` from `~/.dbt/dbt_cloud.yml`.

**Do not use `mart_village_summary` for these villages.** It is a separate, older model over Engage Spaces groups that infers membership from a `current_groups LIKE '%group_name%'` substring match. For the 70 Shepherding villages it is superseded by `mart_village_attendance`.

---

## 8. Known fragilities

- The source is a **live, staff-editable spreadsheet**. A renamed tab, deleted header cell, or reordered column breaks the external tables immediately — ranges are pinned by name (`Roster!A:H` etc.).
- **No snapshots exist.** External tables hold no state. If the workbook is reset or rolled over for the 2027-2028 academic year, history disappears from BigQuery. Snapshots on `roster` and `submissions` should be added well before then.
- Drive permissions are a runtime dependency of every staging query, not just a setup step.

Full design rationale, including why the re-submission and membership-window rules are what they are, is in `shepherding_integration.md`.
