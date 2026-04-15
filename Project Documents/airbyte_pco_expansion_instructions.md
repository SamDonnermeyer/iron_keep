# Airbyte PCO Connector Expansion — Computer Use Instructions

**Purpose:** Add new streams to the existing Planning Center Online connector in Airbyte to expand data coverage. These instructions are for Claude operating via computer use (screen control).

**What already exists:** The PCO connector is live with 7 streams: `people`, `campuses`, `households`, `check_ins`, `check_in_events`, `headcounts`, `service_types`. These are syncing daily to BigQuery.

**What to add:** 3 modules with ~12 new streams covering emails, groups, and services. **Do NOT add giving streams — RCN does not use PCO giving.**

---

## Before You Start

- The Airbyte instance is already running and accessible
- The PCO connector already exists with OAuth2 authentication configured
- The BigQuery destination is already configured
- You are adding new streams to the **existing** PCO connector, not creating a new one
- All PCO API endpoints follow JSON API 1.0 spec with the same pagination and auth pattern

### PCO API Conventions (same for all streams)

- **Base URL:** `https://api.planning.center`
- **Auth:** OAuth2 (already configured on the connector)
- **Pagination:** Offset-based. Parameters: `per_page=100` (max), `offset=N`. Response includes `meta.total_count`.
- **Rate Limit:** 100 requests/minute (Airbyte handles backoff)
- **Response format:** JSON API — each record has `id`, `type`, `attributes` (JSON object), `relationships` (JSON object)
- **Primary Key:** Always `id`
- **Incremental cursor:** `updated_at` inside `attributes` (where available)

---

## Step-by-Step: Adding Streams

Open the Airbyte UI and navigate to **Builder** (or **Sources** → find the PCO connector → **Edit**).

For each stream below, add it to the connector with these settings. After adding all streams, save the connector, update the connection, and enable the new streams.

---

### Module 1: People (sub-resources)

These are nested endpoints under `/people/v2/`. They require fetching per-person, but Airbyte's connector builder can handle parent-child stream relationships.

#### Stream: `emails`

This is the highest-priority new stream — it enables email-based identity matching.

| Setting | Value |
|---------|-------|
| Stream Name | `emails` |
| URL Path | `/people/v2/emails` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` if available, otherwise Full Refresh |

**Expected fields in `attributes`:** `address`, `primary`, `location`, `blocked`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `person` (contains `person.data.id` — the link back to the people table)

**Why this matters:** Currently the only way to match PCO people to Engage Spaces users is by name. Email matching will be far more reliable and will resolve most "likely" and "ambiguous" matches in the identity bridge.

> **Note:** The endpoint `/people/v2/emails` returns ALL emails across all people (not nested per-person). This is the preferred approach — simpler pagination, no parent-child stream needed.

#### Stream: `phone_numbers`

| Setting | Value |
|---------|-------|
| Stream Name | `phone_numbers` |
| URL Path | `/people/v2/phone_numbers` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` if available, otherwise Full Refresh |

**Expected fields in `attributes`:** `number`, `carrier`, `location`, `primary`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `person` (contains `person.data.id`)

#### Stream: `addresses`

| Setting | Value |
|---------|-------|
| Stream Name | `addresses` |
| URL Path | `/people/v2/addresses` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` if available, otherwise Full Refresh |

**Expected fields in `attributes`:** `street`, `city`, `state`, `zip`, `location`, `primary`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `person` (contains `person.data.id`)

#### Stream: `field_data`

Custom field values (campus assignments, membership dates, custom attributes defined by RCN).

| Setting | Value |
|---------|-------|
| Stream Name | `field_data` |
| URL Path | `/people/v2/field_data` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Full Refresh (custom fields change unpredictably) |

**Expected fields in `attributes`:** `value`, `file`, `file_size`, `file_content_type`, `file_name`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `person` (contains `person.data.id`), `field_definition` (contains `field_definition.data.id`)

#### Stream: `field_definitions`

Lookup table for what each custom field means (needed to interpret `field_data`).

| Setting | Value |
|---------|-------|
| Stream Name | `field_definitions` |
| URL Path | `/people/v2/field_definitions` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Full Refresh (small table, rarely changes) |

**Expected fields in `attributes`:** `data_type`, `name`, `sequence`, `slug`, `config`, `deleted_at`, `tab_id`

---

### Module 2: Groups

These endpoints provide village/small group data from PCO's Groups module. This is separate from (and complementary to) the group data already coming from Engage Spaces.

#### Stream: `groups`

| Setting | Value |
|---------|-------|
| Stream Name | `groups` |
| URL Path | `/groups/v2/groups` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` cursor |

**Expected fields in `attributes`:** `name`, `description`, `schedule`, `contact_email`, `header_image`, `location_type_preference`, `enrollment_strategy`, `enrollment_open`, `events_visibility`, `archive_status`, `archived_at`, `church_center_visible`, `church_center_map_visible`, `membership_count`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `group_type`, `location`

#### Stream: `group_types`

Lookup table for group categorization.

| Setting | Value |
|---------|-------|
| Stream Name | `group_types` |
| URL Path | `/groups/v2/group_types` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Full Refresh (small lookup table) |

**Expected fields in `attributes`:** `name`, `description`, `church_center_visible`, `church_center_map_visible`, `color`, `default_group_settings`, `position`, `created_at`

#### Stream: `group_memberships`

Who is in each group, with their role (member vs leader) and join/departure dates.

| Setting | Value |
|---------|-------|
| Stream Name | `group_memberships` |
| URL Path | `/groups/v2/memberships` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` cursor |

**Expected fields in `attributes`:** `account_center_identifier`, `color_identifier`, `first_name`, `last_name`, `avatar_url`, `joined_at`, `role`, `email_address`, `phone_number`
**Expected fields in `relationships`:** `group` (contains `group.data.id`), `person` (contains `person.data.id`)

> **Note:** The flat endpoint `/groups/v2/memberships` returns ALL memberships. This is preferred over the nested `/groups/v2/groups/{id}/memberships` because it avoids per-group API calls.

#### Stream: `group_events`

Events/meetings associated with groups.

| Setting | Value |
|---------|-------|
| Stream Name | `group_events` |
| URL Path | `/groups/v2/events` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` cursor |

**Expected fields in `attributes`:** `name`, `description`, `starts_at`, `ends_at`, `location`, `multi_day`, `repeating`, `attendance_requests_enabled`, `canceled`, `canceled_at`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `group` (contains `group.data.id`)

#### Stream: `group_attendance`

Individual attendance records for group events.

| Setting | Value |
|---------|-------|
| Stream Name | `group_attendance` |
| URL Path | `/groups/v2/attendances` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `created_at` cursor |

**Expected fields in `attributes`:** `attended`, `role`, `created_at`, `updated_at`
**Expected fields in `relationships`:** `person` (contains `person.data.id`), `event` (contains `event.data.id`)

> **Note:** If the flat endpoint `/groups/v2/attendances` does not exist or returns an error, use the nested endpoint `/groups/v2/events/{event_id}/attendances` instead with a parent stream reference to `group_events`.

---

### Module 3: Services

These endpoints provide worship service planning data — who is scheduled to serve, service plans, and team structures. `service_types` is already synced; these add the detail underneath.

#### Stream: `plans`

Service plans (individual worship services/events).

| Setting | Value |
|---------|-------|
| Stream Name | `plans` |
| URL Path | `/services/v2/service_types/{service_type_id}/plans` |
| HTTP Method | GET |
| Primary Key | `id` |
| Parent Stream | `service_types` (use `id` as `service_type_id`) |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Use `updated_at` cursor |

**Expected fields in `attributes`:** `title`, `series_title`, `short_dates`, `dates`, `sort_date`, `plan_notes_count`, `other_time_count`, `rehearsal_time_count`, `service_time_count`, `items_count`, `total_length`, `multi_day`, `public`, `created_at`, `updated_at`

> **Important:** This is a nested endpoint that requires iterating over each `service_type_id`. In Airbyte Connector Builder, configure this as a substream with `service_types` as the parent stream. The `service_type_id` path parameter should be populated from the parent stream's `id` field.

#### Stream: `plan_team_members`

Who is scheduled to serve in each plan (volunteers, band members, tech crew, etc.).

| Setting | Value |
|---------|-------|
| Stream Name | `plan_team_members` |
| URL Path | `/services/v2/service_types/{service_type_id}/plans/{plan_id}/team_members` |
| HTTP Method | GET |
| Primary Key | `id` |
| Parent Stream | `plans` (use parent's `service_type_id` and `id` as `plan_id`) |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Full Refresh (status changes frequently) |

**Expected fields in `attributes`:** `name`, `status` (C = confirmed, U = unconfirmed, D = declined), `team_position_name`, `photo_thumbnail`, `created_at`, `updated_at`, `decline_reason`, `can_accept_partial`, `notes`, `prepare_notification`
**Expected fields in `relationships`:** `person` (contains `person.data.id`), `plan` (contains `plan.data.id`), `team` (contains `team.data.id`)

> **Important:** This is a doubly-nested endpoint. In Connector Builder, this needs to be a substream of `plans`, which is itself a substream of `service_types`. The URL template should include both `service_type_id` (from the grandparent) and `plan_id` (from the parent).

> **If double-nesting is not supported in Connector Builder:** An alternative approach is to use the flat endpoint `/services/v2/team_members` if available, or build this as a separate custom connector that flattens the hierarchy.

#### Stream: `teams`

Team definitions within the services module (worship team, tech team, greeting team, etc.).

| Setting | Value |
|---------|-------|
| Stream Name | `service_teams` |
| URL Path | `/services/v2/teams` |
| HTTP Method | GET |
| Primary Key | `id` |
| Pagination | Offset: `per_page=100`, `offset=N` |
| Incremental | Full Refresh (small lookup table) |

**Expected fields in `attributes`:** `name`, `rehearsal_team`, `sequence`, `schedule_to`, `default_status`, `default_prepare_notifications`, `created_at`, `updated_at`, `archived_at`
**Expected fields in `relationships`:** `service_type` (contains `service_type.data.id`)

> **Note:** Name this stream `service_teams` (not `teams`) to avoid collision with the Engage Spaces `teams` table in BigQuery.

---

## After Adding All Streams

### 1. Test each stream

In the Connector Builder, run a test read for each new stream. Verify:
- The stream returns data (check record count)
- The `attributes` JSON contains the expected fields
- Pagination works (if > 100 records exist)
- Parent-child relationships resolve correctly for nested endpoints (`plans`, `plan_team_members`)

### 2. Save and publish the updated connector

Save the connector with all new streams. Airbyte may prompt you to update the connector version.

### 3. Update the connection

- Go to **Connections** → find the PCO → BigQuery connection
- Click **Schema** or **Replication**
- The new streams should appear. **Enable** each one.
- Set sync mode:
  - **Incremental | Append + Dedup** for streams with `updated_at` cursor (`emails`, `groups`, `group_memberships`, `group_events`, `group_attendance`, `plans`)
  - **Full Refresh | Overwrite** for small lookup tables (`field_definitions`, `group_types`, `service_teams`) and tables without reliable cursors (`field_data`, `plan_team_members`, `phone_numbers`, `addresses`)
- Save the connection

### 4. Run an initial sync

Trigger a manual sync to load historical data for all new streams. This may take longer than usual due to the volume of data being pulled for the first time.

### 5. Verify in BigQuery

After the sync completes, confirm the new tables exist in the `planning_center` dataset:

```sql
SELECT table_id, row_count
FROM `planning_center.__TABLES__`
ORDER BY table_id
```

Expected new tables: `addresses`, `emails`, `field_data`, `field_definitions`, `group_attendance`, `group_events`, `group_memberships`, `group_types`, `groups`, `plans`, `plan_team_members`, `service_teams`

---

## Troubleshooting

**Stream returns 404:** The flat endpoint may not exist for that resource. Try the nested version (e.g., `/people/v2/people/{person_id}/emails` instead of `/people/v2/emails`). If using the nested version, configure a parent stream.

**Stream returns 403:** The OAuth app may not have the required scope. Verify the OAuth app includes scopes: `people groups services check_ins`. (Note: `giving` scope is not needed.)

**Rate limiting (429 responses):** Airbyte handles this automatically with exponential backoff. If syncs are very slow, consider scheduling the expanded sync during a lower-traffic window.

**Parent-child stream not working:** If the Connector Builder doesn't support the nesting depth you need (especially for `plan_team_members`), consider:
1. Building it as a separate connector with hardcoded parent iteration
2. Using a custom Python connector instead of the low-code builder
3. Starting with just the simpler streams and adding the complex ones later

---

## Stream Priority Order

If you encounter issues and need to prioritize, add streams in this order:

1. **`emails`** — Highest impact. Unlocks email-based identity resolution.
2. **`groups`** and **`group_memberships`** — Unlocks PCO village/group membership tracking.
3. **`group_events`** and **`group_attendance`** — Unlocks village-level attendance.
4. **`phone_numbers`** and **`addresses`** — Enriches person records.
5. **`field_data`** and **`field_definitions`** — Unlocks custom field data (campus assignments, etc.).
6. **`plans`** and **`plan_team_members`** and **`service_teams`** — Unlocks serving/volunteer tracking. Most complex due to nested endpoints.
