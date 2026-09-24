# Platform runbook

For failed scaffolding, preserve the task ID, redact secrets, determine the failed action, and retry only idempotent steps. For Argo drift, inspect desired Git revision, sync waves, health, admission events, and controller logs before forcing synchronization. For Crossplane failures, inspect XR conditions, function pipeline results, composed-resource events, and provider rate limits.

Disable only the affected template or composition during an incident. Never disable global admission controls to unblock one team. Restore control-plane metadata into isolation, validate catalog ownership and desired-state checksums, then reconnect reconcilers gradually.
