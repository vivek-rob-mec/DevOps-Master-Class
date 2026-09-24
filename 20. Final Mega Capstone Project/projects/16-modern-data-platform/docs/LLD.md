# Low-level design

`contracts/order-event.schema.json` is versioned and rejects unknown fields. The producer enables Kafka idempotence and keys records by customer. The Airflow DAG validates the input, upserts by `event_id`, checks row counts, executes `dbt build`, and emits a data-product manifest. Spark supplies a separate partitioned Parquet path to practice distributed backfills. dbt separates source declarations, staging normalization, mart aggregation, and tests.

Retries are bounded. Database writes are idempotent. A backfill must use an isolated Airflow run, immutable source interval, bounded Spark resources, and comparison queries before promoting output. Never edit a published contract incompatibly; add a new topic/schema version and migrate consumers.
