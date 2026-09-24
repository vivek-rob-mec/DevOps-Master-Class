# High-level design

The platform separates developer experience, control planes, and workload runtime. Backstage owns discovery and golden-path intent; source control owns desired state and review history; CI owns artifact evidence; Argo CD owns reconciliation; Crossplane owns higher-level platform APIs; Kyverno enforces admission controls. No portal action bypasses Git review or workload identity.

The production design requires HA control planes, private clusters, SSO, managed PostgreSQL, encrypted state, signed artifacts, policy exceptions with expiry, tenant quotas, audit export, backup/restore, and an explicit platform SLO.
