{#
    Parsing helpers for Google Sheets backed external tables.

    Sheets external tables hand BigQuery whatever the cell currently holds, and
    the same logical column can arrive in several shapes depending on how the
    cell happens to be formatted:

        gathering_date    '2026-08-25'  |  '8/25/2026'  |  '46259'
        first_seen_at     '08/13/26'    |  '2026-08-13' |  '46247'
        submitted_at      '8/25/2026 21:56:03'          |  '46259.914355'
        attendee_count    '35'          |  '35.0'       |  ''

    Rather than pin the pipeline to one formatting choice inside an operational
    spreadsheet that staff edit, these macros accept every observed shape and
    return NULL for anything unrecognised.
#}


{#- Excel/Sheets serial numbers count days from 1899-12-30. -#}
{% macro sheet_date(col) -%}
case
    when {{ col }} is null or trim({{ col }}) = '' then null
    -- ISO: 2026-08-25, optionally with a time component
    when regexp_contains(trim({{ col }}), r'^\d{4}-\d{2}-\d{2}')
        then safe.parse_date('%Y-%m-%d', substr(trim({{ col }}), 1, 10))
    -- US four-digit year: 8/25/2026
    when regexp_contains(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{4}')
        then safe.parse_date('%m/%d/%Y', regexp_extract(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{4}'))
    -- US two-digit year: 08/13/26
    when regexp_contains(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{2}(\s|$)')
        then safe.parse_date('%m/%d/%y', regexp_extract(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{2}'))
    -- Sheets serial: 46259 or 46259.914355
    when regexp_contains(trim({{ col }}), r'^\d+(\.\d+)?$')
        then date_add(date '1899-12-30', interval cast(floor(safe_cast(trim({{ col }}) as float64)) as int64) day)
    else null
end
{%- endmacro %}


{#-
    Naive spreadsheet clock values are interpreted in the workbook's timezone
    (America/Los_Angeles, per the _README) and returned as a UTC TIMESTAMP so
    they sort correctly against Airbyte's _airbyte_extracted_at.
-#}
{% macro sheet_timestamp(col, timezone='America/Los_Angeles') -%}
case
    when {{ col }} is null or trim({{ col }}) = '' then null
    when regexp_contains(trim({{ col }}), r'^\d{4}-\d{2}-\d{2}[T ]\d{1,2}:\d{2}')
        then safe.parse_timestamp('%Y-%m-%d %H:%M:%S', regexp_replace(trim({{ col }}), r'T', ' '), '{{ timezone }}')
    when regexp_contains(trim({{ col }}), r'^\d{4}-\d{2}-\d{2}$')
        then safe.parse_timestamp('%Y-%m-%d', trim({{ col }}), '{{ timezone }}')
    when regexp_contains(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}')
        then safe.parse_timestamp('%m/%d/%Y %H:%M:%S', trim({{ col }}), '{{ timezone }}')
    when regexp_contains(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{4}$')
        then safe.parse_timestamp('%m/%d/%Y', trim({{ col }}), '{{ timezone }}')
    when regexp_contains(trim({{ col }}), r'^\d{1,2}/\d{1,2}/\d{2}$')
        then safe.parse_timestamp('%m/%d/%y', trim({{ col }}), '{{ timezone }}')
    -- Sheets serial with fractional day; round to the nearest second before shifting
    when regexp_contains(trim({{ col }}), r'^\d+(\.\d+)?$')
        then timestamp(
                datetime_add(
                    datetime '1899-12-30 00:00:00',
                    interval cast(round(safe_cast(trim({{ col }}) as float64) * 86400) as int64) second
                ),
                '{{ timezone }}'
             )
    else null
end
{%- endmacro %}


{#- Counts arrive as '35', '35.0' or ''. safe_cast to INT64 fails on '35.0'. -#}
{% macro sheet_int(col) -%}
cast(floor(safe_cast(nullif(trim({{ col }}), '') as float64)) as int64)
{%- endmacro %}


{#- Collapse '' to NULL so downstream coalesce/relationship tests behave. -#}
{% macro sheet_string(col) -%}
nullif(trim({{ col }}), '')
{%- endmacro %}
