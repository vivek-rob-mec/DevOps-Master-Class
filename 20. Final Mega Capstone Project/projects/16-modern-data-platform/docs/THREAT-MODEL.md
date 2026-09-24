# Threat model

Protected assets include customer identifiers, order values, Kafka credentials, orchestration metadata, warehouse data, object-store history, logs, and infrastructure state.

Primary threats are schema abuse, oversized events, sensitive-data leakage, topic or bucket over-permission, DAG code execution, dependency compromise, cross-tenant data access, replay storms, poisoned records, public dashboards, and destructive backfills.

Controls include strict versioned contracts, payload and rate limits, TLS/SASL in production, private networking, least-privilege workload identities, encrypted storage, secrets managers, signed/scanned images, protected DAG delivery, immutable raw retention, audit logs, isolated quarantine, bounded retries, egress restrictions, and restore drills. The local credentials and plaintext Kafka listener are development-only.
