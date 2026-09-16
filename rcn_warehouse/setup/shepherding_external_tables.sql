-- ============================================================================
-- Shepherding Tool — BigQuery external tables over the control spreadsheet
-- ============================================================================
-- Source workbook: "Shepherding Tool Control Spreadsheet"
--   https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw
--
-- Run once (and again only if a tab gains/loses columns):
--   bq query --use_legacy_sql=false --project_id=resonate-data-warehouse-442601 \
--     < setup/shepherding_external_tables.sql
--
-- PREREQUISITES
--   1. Share the workbook (Viewer) with whichever principal queries BigQuery:
--        dbt-cloud@resonate-data-warehouse-442601.iam.gserviceaccount.com
--      Without this the tables create fine but every query fails with
--      "Permission denied while getting Drive credentials".
--   2. Local runs additionally need Drive scope on your own credentials:
--        gcloud auth login --enable-gdrive-access
--        gcloud auth application-default login --scopes=\
--          https://www.googleapis.com/auth/drive,\
--          https://www.googleapis.com/auth/bigquery,\
--          https://www.googleapis.com/auth/cloud-platform
--
-- WHY EVERY COLUMN IS STRING
--   Sheets-backed external tables surface whatever the cell currently holds.
--   Dates arrive as ISO text, US-formatted text, or an Excel serial number
--   depending on cell formatting, and blank cells break INT64/DATE columns
--   outright (this is what broke the previous engage_spaces.village_attendance
--   table). Everything lands as STRING and is parsed in the staging layer by
--   the sheet_date / sheet_timestamp / sheet_int macros.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS `resonate-data-warehouse-442601.shepherding`
OPTIONS (location = 'US', description = 'Shepherding Tool v1.1 — village attendance collected via Google Forms. Sheets-backed external tables; the workbook is the system of record.');


-- Campus registry. Seeded by hand, right-hand columns written by Builder.gs.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.churches` (
  church_code              STRING,
  church_name              STRING,
  church_sk                STRING,
  workbook_id              STRING,
  form_id                  STRING,
  form_url                 STRING,
  church_email             STRING,
  church_pastor_email      STRING,
  church_manager_email     STRING,
  school_year_start_date   STRING,
  template_version         STRING,
  last_response_at         STRING,
  status                   STRING,
  created_at               STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'Churches!A:N',
  skip_leading_rows = 1,
  description = 'One row per RCN campus. status: not_built | active | paused | closed.'
);


-- Village registry. Written by Builder.gs on create and amend.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.villages` (
  village_id           STRING,
  church_code          STRING,
  village_name         STRING,
  tab_name             STRING,
  leader_names         STRING,
  page_item_id         STRING,
  checkbox_item_id     STRING,
  correction_item_id   STRING,
  newnames_item_id     STRING,
  status               STRING,
  created_at           STRING,
  academic_year        STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'Villages!A:L',
  skip_leading_rows = 1,
  description = 'One row per village per academic year. village_id = {church_code}-{YY}-V##, permanent.'
);


-- Person roster per village. Append-only; corrections supersede rather than overwrite.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.roster` (
  village_id         STRING,
  person_local_id    STRING,
  display_name       STRING,
  choice_label       STRING,
  completeness       STRING,
  first_seen_at      STRING,
  retired_at         STRING,
  superseded_by      STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'Roster!A:H',
  skip_leading_rows = 1,
  description = 'One row per person per village. completeness: full (first+last) | partial (first name only). A name correction retires the old row and points superseded_by at the replacement.'
);


-- One row per submitted attendance form response.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.submissions` (
  submission_id     STRING,
  church_code       STRING,
  village_id        STRING,
  gathering_date    STRING,
  gathering_type    STRING,
  activity_label    STRING,
  guest_count       STRING,
  attendee_count    STRING,
  submitted_by      STRING,
  submitted_at      STRING,
  processed_at      STRING,
  status            STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'Submissions!A:L',
  skip_leading_rows = 1,
  description = 'One row per form response. Leaders sometimes submit two or three times for the same village and date; resolved downstream in fact_village_gathering.'
);


-- One row per attendee per submission. Attendance only — an absence is the absence of a row.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.attendance_log` (
  submission_id      STRING,
  village_id         STRING,
  person_local_id    STRING,
  person_name        STRING,
  attended_flag      STRING,
  loaded_at          STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'AttendanceLog!A:F',
  skip_leading_rows = 1,
  description = 'One row per attendee per gathering. attended_flag is always 1; absences are inferred against the roster in fact_village_attendance.'
);


-- Apps Script operational log. Exposed for pipeline monitoring; no dbt model reads it.
CREATE OR REPLACE EXTERNAL TABLE `resonate-data-warehouse-442601.shepherding.errors` (
  timestamp      STRING,
  severity       STRING,
  context        STRING,
  church_code    STRING,
  village_id     STRING,
  message        STRING,
  payload        STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1lgG1vWZUjX0za-f29ti0j7du8Et7keMU5YVg299hRkw'],
  sheet_range = 'Errors!A:G',
  skip_leading_rows = 1,
  description = 'Builder/FormSync/Poller log. Review weekly for warn and error rows.'
);
