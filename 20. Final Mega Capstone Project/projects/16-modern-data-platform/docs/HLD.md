# High-level design

The platform exposes two ingestion paths: Kafka for continuously arriving `order-events.v1` records and a replayable raw object/file zone for deterministic batch recovery. Airflow owns orchestration and quality gates, Spark owns larger batch computation, dbt owns SQL transformation and tests, PostgreSQL represents the local warehouse, and the contract is the boundary between producers and consumers.

Production should replace local components with approved managed equivalents, private endpoints, workload identity, centralized secrets, TLS, multi-AZ storage, a schema registry, an object catalog, lineage, and immutable observability. Raw data is append-only; curated tables and Parquet partitions are reproducible from raw events.

## SLO examples

- 99% of daily order marts complete by 06:00 in the business timezone.
- 99.9% of accepted events land in the raw zone within 10 minutes.
- Zero silently discarded contract violations; rejected records enter a quarantined, owned workflow.
