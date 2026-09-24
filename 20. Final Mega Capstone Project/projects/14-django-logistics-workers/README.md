# Django Logistics and Background Jobs Platform

Production-oriented **Web application with asynchronous workers** capstone using **Python 3.12 / Django 5.2 LTS / Celery / Redis / PostgreSQL** with **Django templates / progressive JavaScript**.

```mermaid
flowchart LR
    Operator --> Web["Django logistics portal"]
    Web --> PG[(PostgreSQL)]
    Web --> Redis[(Redis broker)]
    Redis --> Worker["Celery worker"]
    Worker --> Carrier["Carrier adapter"]
    Worker --> PG
    Web --> Metrics["Health and metrics"]
    Worker --> WorkerHealth["Worker health endpoint"]
```

## Workloads

| Workload | Responsibility | Port | Health |
|---|---|---:|---|
| `web` | Django portal, shipment API, persistence, and queue producer | 8000 | `/health` |
| `worker` | Celery shipment processor and worker health endpoint | 8001 | `/health` |

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
curl http://localhost:8093/health
```

Open `http://localhost:8093`. Stop with `docker compose down`; add `--volumes` only for disposable local data.

## Validate

```bash
bash scripts/test.sh
docker compose build
docker compose up -d
bash scripts/smoke-test.sh http://localhost:8093
docker compose down
```

Windows: `./scripts/validate.ps1`.

## Kubernetes, Helm, and GitOps

Replace image names and example secrets first.

```bash
kubectl apply -k k8s/overlays/dev
helm lint helm
helm template logistics helm --namespace logistics-django
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
