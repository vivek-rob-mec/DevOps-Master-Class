# Final capstone assignment

## Scenario

A product team needs one repeatable deployment process for services written in different languages. Deliver the same service contract in at least two supplied stacks, promote immutable artifacts, and demonstrate recovery. Then adapt the method to one business application from the portfolio.

## Milestones and evidence

| Milestone | Deliverable | Completion evidence |
|---|---|---|
| Design | Architecture, owner, platform choice, dependency and threat assessment | Explain one rejected alternative and the operational tradeoff |
| Local run | Two stacks using the common Compose contract | HTTP contract output plus non-root/read-only runtime inspection |
| CI | Reviewed application PR, passing builds/tests/scans | Workflow URL, source SHA, SBOM, vulnerability report |
| Artifact | Published image and release record | Digest matches registry and traced source revision |
| Dev | Reviewed desired state and GitOps sync | Deployment digest, pod readiness, API check |
| Staging | Same artifact, environment-specific configuration | Load/business test, logs/metrics, dependency and auth tests where applicable |
| Production simulation | Approved release into the prod lab namespace | Reviewer, sync revision, all-replica and HTTPS verification |
| Recovery | Deliberately failed dev rollout and reviewed rollback | UTC timeline, restored digest, measured detection/recovery, successful user check |
| Extension | One real portfolio app follows the method | Build adapter, persistence/migration plan, meaningful business smoke check |

Use a sanitized `evidence/` directory for local capture and an approved durable destination for submission. Do not submit credentials. The production namespace in this exercise is a simulation unless real platform and operational controls have been established.

## Scoring

| Area | Points |
|---|---:|
| Architecture and platform justification | 15 |
| Runnable multi-stack contract and containers | 20 |
| Tested artifact, scan, evidence, and immutable promotion | 20 |
| Kubernetes/GitOps and environment verification | 20 |
| Observability, incident investigation, and rollback proof | 15 |
| Business application adaptation and documentation | 10 |
| **Total** | **100** |

Target 80/100 with no missing runtime, promotion, or recovery evidence. Explain clearly which checks were local, which ran in CI, and which were demonstrated on a cluster. Passing a configuration render is not a deployed-system test.

## Oral defense

1. What changes by stack, and what remains in the shared deployment contract?
2. Why is an image digest a stronger release identifier than a mutable tag?
3. How do you prove production is running the artifact tested in staging?
4. How do readiness, liveness, startup, and graceful termination interact?
5. Why does a successful Git merge or Argo CD sync not prove user-facing health?
6. How does rollback change after a destructive database migration?
7. Which controls are enforced by this repository, and which require platform configuration?
8. When would a managed container service or a VM be a better choice than Kubernetes?
