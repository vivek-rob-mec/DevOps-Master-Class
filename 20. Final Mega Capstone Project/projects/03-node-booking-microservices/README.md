# Node.js Booking Microservices Platform

Production-oriented **Microservices** capstone using **Node.js 24 LTS / Express 5** with **Next.js 16 / React 19**.

```mermaid
flowchart LR
    User --> Next["Next.js frontend"] --> Gateway["Node gateway"]
    Gateway --> Booking["Booking service"]
    Booking --> Notify["Notification service"]
    Booking --> BookingDB[("Booking state")]
    Notify --> Provider["Delivery provider"]
    Gateway --> Observe["Prometheus metrics"]
```

## Workloads

| Workload | Responsibility | Port | Health |
|---|---|---:|---|
| `gateway` | Public API and routing | 3000 | `/health` |
| `booking` | Idempotent booking lifecycle | 3001 | `/health` |
| `notification` | Notification delivery abstraction | 3002 | `/health` |
| `frontend` | Next.js traveler experience | 3000 | `/health` |

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
curl http://localhost:8083/health
```

Open `http://localhost:8083`. Stop with `docker compose down`; add `--volumes` only for disposable local data.

## Validate

```bash
bash scripts/test.sh
docker compose build
docker compose up -d
bash scripts/smoke-test.sh http://localhost:8083
docker compose down
```

Windows: `./scripts/validate.ps1`.

## Kubernetes, Helm, and GitOps

Replace image names and example secrets first.

```bash
kubectl apply -k k8s/overlays/dev
helm lint helm
helm template booking helm --namespace booking-node
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
