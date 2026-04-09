# Source Systems

Details on each platform we're integrating into the data warehouse.

---

## Planning Center Online (PCO)

- **Website:** https://www.planningcenter.com/
- **Purpose:** Church management -- people, groups, services, giving, check-ins
- **API Type:** REST (JSON API 1.0 specification)
- **Auth:** OAuth2
- **Rate Limit:** 100 requests/minute per app
- **Docs:** https://developer.planning.center/docs/
- **Python Library:** [pypco](https://github.com/billdeitrick/pypco) -- full API support, auto-pagination, rate limiting
- **Priority:** Primary
- **Modules:** People, Services, Groups, Giving, Check-Ins, Calendar

---

## Pushpay

- **Website:** https://pushpay.com
- **Purpose:** Donations and recurring giving
- **API Type:** REST (HAL+JSON)
- **Auth:** OAuth2 (Client Flow or Code Flow)
- **Docs:** https://pushpay.io/docs/api
- **Swagger:** https://api.pushpay.com/swagger
- **Priority:** Primary
- **Note:** Sandbox testing required before production credentials. Contact: api@pushpay.com

---

## ServiceReef

- **Website:** https://www.servicereef.com/
- **Purpose:** Mission trips, service projects, retreats
- **API Type:** REST (JSON)
- **Auth:** API Key (HTTPS required)
- **Docs:** https://api.servicereef.com/docs
- **Priority:** Primary
- **Key Feature:** `externalId` field supports linking records to other systems

---

## Engage Spaces

- **Website:** https://engagespaces.com/
- **Purpose:** Training and member engagement
- **API Type:** REST
- **Auth:** API Key (URL parameter `?apikey=YOUR_API_KEY`)
- **Base URL:** `YOURDOMAIN.engagespaces.com/get` (or `/gets` for all locations)
- **Formats:** JSON, CSV
- **Priority:** Primary
- **Contact:** daniel.trafford@engagespaces.com
- **Integrations:** Zapier, Airtable, Stripe, Tableau, Mailchimp, Power BI, Salesforce, Google Sheets

---

## Subsplash

- **Website:** https://www.subsplash.com/
- **Purpose:** Church app, giving, groups, media
- **Data Flow:** Subsplash loads data into our **Snowflake** instance. Airbyte extracts from Snowflake into BigQuery (not directly from API).
- **Auth:** N/A (Snowflake connector, not direct API)
- **Docs:** https://developer.subsplash.com/
- **Priority:** Secondary
- **Pre-built Integrations:** Planning Center, Rock RMS, Ministry Platform, Breeze

---

## Pathwright (Deferred to v1.1)

- **Website:** https://www.pathwright.com/
- **Purpose:** Online courses and training
- **API Type:** Limited REST + Zapier
- **Auth:** OAuth
- **Docs:** https://developer.pathwright.com/
- **Priority:** Deferred
- **Limitation:** Primarily Zapier-based triggers; not suitable for bulk historical data extraction

---

## Connector Availability

No major ELT platform has pre-built connectors for these church management systems. Custom connectors will be built using Airbyte's Connector Builder.

| Platform | Airbyte Connector | Notes |
|----------|-------------------|-------|
| Planning Center | Custom (to build) | pypco library available as reference |
| Pushpay | Custom (to build) | OAuth2 flow |
| ServiceReef | Custom (to build) | Simple API key auth |
| Engage Spaces | Custom (to build) | Simple API key auth |
| Subsplash | Native Snowflake source | Data loaded into Snowflake by Subsplash, then pulled to BigQuery |
| BigQuery (destination) | Native | Built-in Airbyte destination |
