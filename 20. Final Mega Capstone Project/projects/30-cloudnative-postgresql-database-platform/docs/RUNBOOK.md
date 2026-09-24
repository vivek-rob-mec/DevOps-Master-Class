# Database runbook

Triage client saturation, pool saturation, lock waits, long transactions, storage latency, replication lag and operator health separately. A failover is not complete until writers reconnect and invariants pass. A backup is not trusted until an isolated restore proves WAL continuity, application queries, row counts and logical checksums.
