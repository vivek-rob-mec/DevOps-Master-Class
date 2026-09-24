# Serverless Media Pipeline - LLD

- `POST /jobs` requires `Idempotency-Key`, `bucket`, and a relative object `key`.
- A SHA-256-derived job ID plus DynamoDB conditional write makes duplicate intake stable; intake may enqueue duplicates so a queue-send failure can be safely retried.
- The worker conditionally claims only `queued` or `failed` jobs, marks failures retryable, and ignores completed/in-flight duplicates.
- SQS visibility timeout is six times the worker timeout; the event source reports partial batch failures.
- Worker concurrency is bounded at the Lambda and event-source mapping.
- Every state transition updates `updatedAt`; reconciliation can compare queued/processing age with SQS and object state.
- Never log object contents, signed URLs, credentials, or unbounded customer identifiers.

Before production, add authenticated resource authorization, input ownership proof, a job-status read route, schema versioning, TTL/retention policy, KMS keys where required, alarms wired to an owned destination, dashboards, canary deployment, and end-to-end tracing propagation.
