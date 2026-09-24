# Reliability runbook

Declare an incident from user-facing symptoms, not infrastructure noise. Stabilize writes before failover when split-brain is possible. Preserve evidence, identify last durable transaction, restore into isolation, validate checksums and business invariants, then promote. DNS failover is not database failover. After recovery, calculate budget consumed and block risky releases when policy requires it.
