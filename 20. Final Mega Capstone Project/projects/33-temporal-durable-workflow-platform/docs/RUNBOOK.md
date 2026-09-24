# Temporal runbook

Separate service availability, persistence latency, task-queue backlog, worker capacity, workflow failure and activity dependency failures. Do not blindly reset workflows: first understand history and external side effects. During worker rollout, monitor nondeterminism errors and schedule-to-start latency. Schema upgrades precede server upgrades and require tested backups.
