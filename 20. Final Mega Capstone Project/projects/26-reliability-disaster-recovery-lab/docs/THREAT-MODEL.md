# Threat model

Chaos tools and backup credentials are privileged. Threats include production-wide fault injection, forged evidence, backup deletion, restore-time malware, cross-region credential reuse and failover hijacking. Controls include dedicated service accounts, namespace/label allowlists, time-bound approvals, immutable backup copies, separate restore accounts, signed evidence, audit logs and tested kill switches.
