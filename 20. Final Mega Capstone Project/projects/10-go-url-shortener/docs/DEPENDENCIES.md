# Go Cloud-Native URL Shortener - Dependencies

| Area | Template | Production requirement |
|---|---|---|
| Backend | Go 1.25 / net/http / pgx / PostgreSQL | Patch pin, lockfile, license/provenance/vulnerability review |
| Frontend | Embedded responsive web interface | Lockfile, CSP, browser policy, scanning |
| Containers | Docker/OCI | Non-root, SBOM, scan, signature, digest |
| Kubernetes | Kustomize/Helm | Supported APIs, policy, upgrade test |
| CI/CD | GitHub/Jenkins/Argo CD | One authority and protected identity |
| Infrastructure | Terraform/AWS | Remote encrypted locked state, reviewed plan |

Record owner, purpose, version strategy, source, license, provenance, transitive risk, failure behavior, observability, upgrade, and replacement for every dependency.
