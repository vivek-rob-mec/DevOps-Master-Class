# Incident runbook

## Interactive shell

Validate identity, change ticket and workload namespace. Preserve the event and surrounding process/network timeline. If unauthorized, isolate the workload, revoke its identity and replace the pod from a trusted image; do not investigate by modifying the suspect container.

## Secret access

Confirm the audit decision and credential target. Revoke/rotate exposed material, preserve audit logs, scope all uses of the identity and review RBAC ancestry.

## Runtime drift

Compare the running image digest and filesystem changes with deployment evidence. Replace rather than repair immutable workloads.
