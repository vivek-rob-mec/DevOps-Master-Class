# Serverless Media Pipeline - Runbook

1. Capture region, UTC start, API symptom, request ID, job ID, object reference, and recent deployment.
2. Check API 4xx/5xx/latency, intake errors/throttles, queue age/depth, worker errors/throttles/duration, DLQ depth, DynamoDB throttles, and S3 access failures.
3. Stop or throttle intake if backlog growth threatens the recovery window. Do not blindly redrive poison messages.
4. Inspect one failed message without exposing sensitive object data; fix code, IAM, schema, quota, or object state.
5. Deploy a reversible function version, test one quarantined message, then redrive a bounded batch while watching age/error/concurrency.

Rollback cannot undo external side effects or incompatible job schemas. Keep old consumers compatible during message retention and reconcile jobs stuck in queued or processing states.
