# Operation Iron Keep

Data integration project for Resonate Collegiate Network -- building an ELT pipeline to consolidate church management platform data.

## Architecture

**Stack:** Airbyte (extract/load) + BigQuery (warehouse) + dbt (transform)

## Project Structure

- `Project Documents/` - Project documentation
  - `project_overview.md` - High-level project summary and architecture
  - `source_systems.md` - Platform details and API info
  - `Archive/` - Previous research and planning documents
- `Research/` - Platform and data structure research
  - `Platform Research/` - Research on individual platforms
  - `Data Structure Research/` - Data modeling research
- `next_steps.md` - Current action items

## Platforms

| Platform | Purpose | Priority |
|----------|---------|----------|
| Planning Center Online | Church management (people, groups, services, giving) | Primary |
| Pushpay | Donations and recurring giving | Primary |
| ServiceReef | Mission trips and experiences | Primary |
| Engage Spaces | Training and member engagement | Primary |
| Subsplash | Church app, giving, groups | Secondary |
| Pathwright | Online courses | Deferred (v1.1) |
