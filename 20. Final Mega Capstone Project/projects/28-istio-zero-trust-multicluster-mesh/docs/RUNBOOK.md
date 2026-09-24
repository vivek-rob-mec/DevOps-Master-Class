# Mesh runbook

For an outage, separate DNS, CNI capture, ztunnel, waypoint, policy and application failures. Inspect Gateway/HTTPRoute conditions, ztunnel logs, authorization denials and certificate expiry. Prove failover using a controlled regional drain, then verify error rate, locality and recovery time. Never disable mTLS or default-deny globally as a troubleshooting shortcut.
