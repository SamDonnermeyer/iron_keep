# Next Steps

## Immediate Priorities

1. **Set up Airbyte**
   - Decide: Airbyte Cloud vs. self-hosted on GCP Compute Engine
   - Deploy and configure BigQuery as destination

2. **Set up dbt project**
   - Initialize dbt project structure
   - Configure BigQuery connection
   - Set up Git repository for version control

3. **Build first Airbyte connector (Planning Center)**
   - Use Airbyte Connector Builder
   - Start with People module, then expand to Groups, Services, Giving
   - Reference: pypco library for API patterns

4. **Set up BigQuery**
   - Create or identify GCP project
   - Set up dataset organization (staging, transformed, marts)
   - Configure IAM permissions

## Next Wave

5. Build Pushpay connector (giving data -- high ROI)
6. Build ServiceReef connector
7. Build Engage Spaces connector
8. Build Subsplash connector
9. Design and implement dbt transformation models

## Open Questions

- Airbyte Cloud vs. self-hosted?
- Which churches to pilot first?
- GCP project -- existing or new?
- Who are the primary report consumers and what dashboards are highest priority?
- How far back do we need historical data? (1 year? 3 years? All available?)

## Contacts

- **Engage Spaces:** daniel.trafford@engagespaces.com
- **Pushpay API access:** api@pushpay.com
