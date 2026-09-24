# High-level design

GitOps deploys desired artifacts. Argo Rollouts controls replica and traffic progression. Prometheus analysis decides automated promotion or abort. OpenFeature decouples feature exposure from artifact rollout. Audit records connect commit, image digest, rollout revision, flag revision, metric evidence and operator decision.
