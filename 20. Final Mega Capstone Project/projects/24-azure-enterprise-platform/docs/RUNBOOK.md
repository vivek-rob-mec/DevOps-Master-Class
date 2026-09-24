# Azure platform runbook

For cluster access failure, distinguish Entra/RBAC, private DNS, network and API availability. For workload identity failures, validate issuer, subject, audience, service-account label and federated credential before changing roles. Test node-image and Kubernetes upgrades in a non-production ring. Restore Kubernetes state and persistent data separately; record measured regional RTO/RPO and validate DNS/certificate dependencies.
