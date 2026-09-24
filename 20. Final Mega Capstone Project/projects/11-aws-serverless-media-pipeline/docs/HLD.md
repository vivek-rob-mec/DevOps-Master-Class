# Serverless Media Pipeline - HLD

The public journey accepts a bounded media reference and an idempotency key. The intake Lambda conditionally creates one DynamoDB job and emits a retry-safe SQS message. Client retries can produce duplicate messages; a conditional worker claim makes completed or in-flight jobs no-ops. Failed records become retryable again and move to the DLQ after five receives.

Initial objectives are 99.9% successful intake, p95 intake below 500 ms, no duplicate job per idempotency key, RTO 60 minutes, RPO 15 minutes, and bounded cost through API throttling, Lambda reserved concurrency, SQS buffering, payload limits, log retention, and billing alarms. Validate these hypotheses with load, duplicate, retry, poison-message, restore, regional dependency, and quota tests.
