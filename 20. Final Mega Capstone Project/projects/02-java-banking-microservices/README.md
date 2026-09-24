# Java Banking Microservices Platform

Production-oriented **Microservices** capstone using **Java 21 / Spring Boot 4.1** with **Vue 3 / Vite**.

```mermaid
flowchart LR
    User --> Vue["Vue banking portal"] --> Gateway["Spring gateway"]
    Gateway --> Accounts["Account service"]
    Gateway --> Ledger["Ledger service"]
    Ledger --> Accounts
    Accounts --> AccountDB[("Account state")]
    Ledger --> LedgerDB[("Journal state")]
    Gateway --> Observe["Actuator and metrics"]
```

## Workloads

| Workload | Responsibility | Port | Health |
|---|---|---:|---|
| `gateway` | Public API and routing | 8080 | `/actuator/health` |
| `accounts` | Account ownership and queries | 8081 | `/actuator/health` |
| `ledger` | Idempotent transfer journal | 8082 | `/actuator/health` |
| `frontend` | Vue banking portal | 8080 | `/health` |

## Included DevOps assets

- Runnable application and frontend source.
- Non-root multi-stage Dockerfiles and `docker-compose.yml`.
- Kubernetes Deployments, Services, probes, resources, HPA, PDB, Ingress, NetworkPolicy, ConfigMap, Secret example, and Kustomize overlays.
- Helm, Argo CD, Prometheus resources, and Kyverno policy.
- GitHub Actions, Jenkins, Ansible, and Terraform for AWS VPC/EKS/ECR/optional RDS.
- HLD, LLD, dependency register, threat model, and operations runbook.

## Run locally

```bash
cp .env.example .env
docker compose config
docker compose build
docker compose up -d
curl http://localhost:8082/health
```

Open `http://localhost:8082`. Stop with `docker compose down`; add `--volumes` only for disposable local data.

## Validate

```bash
bash scripts/test.sh
docker compose build
docker compose up -d
bash scripts/smoke-test.sh http://localhost:8082
docker compose down
```

Windows: `./scripts/validate.ps1`.

## Kubernetes, Helm, and GitOps

Replace image names and example secrets first.

```bash
kubectl apply -k k8s/overlays/dev
helm lint helm
helm template banking helm --namespace banking-java
kubectl apply -f argocd/application.yaml
```

## Terraform warning

Terraform creates billable AWS resources. Configure encrypted remote state, review account/region/cost and the exact plan, and apply only through an authorized workflow. Never commit credentials.

## Production gates

1. Replace domains, repository, registry, owners, secrets, and cloud placeholders.
2. Use intentionally operated stateful dependencies with backup, restore, RTO, and RPO evidence.
3. Pin/scan dependencies and images, generate SBOM/provenance, sign artifacts, and enforce admission policy.
4. Define SLIs/SLOs, capacity reserve, alerts, rollout abort conditions, and rollback limits.
5. Test authorization, malformed input, duplicate work, dependency timeout, overload, migration, restore, and reconciliation.

See `docs/HLD.md`, `docs/LLD.md`, `docs/DEPENDENCIES.md`, `docs/VERSION-POLICY.md`, `docs/THREAT-MODEL.md`, and `docs/RUNBOOK.md`.
