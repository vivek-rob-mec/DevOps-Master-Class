# Operations runbook

## DAG failure

1. Identify the failed task and data interval; pause downstream publishing if correctness is uncertain.
2. Check scheduler and DAG processor health, task logs, database saturation, Kafka lag, and source availability.
3. Quarantine invalid records. Do not weaken a contract to make a retry pass.
4. Retry only idempotent tasks. For a backfill, record the source interval, code version, output location, and validation queries.

## Kafka lag or poison events

Throttle producers or scale consumers after confirming partition balance. Preserve the offending offset and payload in a restricted quarantine store, redact it from tickets/logs, then replay through a new consumer group after the fix.

## Recovery

Restore metadata and warehouse databases into isolation, verify checksums and row counts, replay raw events into a new output prefix/schema, compare quality metrics, then switch consumers. Record actual RPO/RTO and follow-up actions.
