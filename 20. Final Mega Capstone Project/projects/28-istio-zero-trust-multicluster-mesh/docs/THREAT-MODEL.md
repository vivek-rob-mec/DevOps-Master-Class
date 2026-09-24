# Threat model

Threats include workload-identity theft, permissive trust aliases, namespace-label tampering, L7 bypass, compromised gateways, uncontrolled egress and cross-cluster lateral movement. Controls include short-lived certificates, admission-protected labels, explicit principals, restricted gateway attachment, egress allowlists, audit telemetry and independent Kubernetes NetworkPolicy.
