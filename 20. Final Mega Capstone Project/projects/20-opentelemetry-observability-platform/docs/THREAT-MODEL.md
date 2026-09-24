# Threat model

Telemetry can contain credentials, customer data, topology, source code fragments, and incident evidence. Threats include unauthenticated ingestion, tenant spoofing, query abuse, cardinality denial of service, malicious dashboard links, log injection, trace baggage leakage, and retention-policy bypass. Use mTLS, workload identity, tenant authorization, attribute allowlists/redaction, quotas, query limits, private networks, immutable dashboards, audit logs, encrypted stores, and deletion workflows.
