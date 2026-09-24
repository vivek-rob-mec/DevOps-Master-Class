param([switch]$WhatIfMode)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$builders=@(
    '01-python.ps1','02-java.ps1','03-node.ps1','04-php.ps1','05-cpp.ps1',
    '06-node-monolith.ps1','07-python-monolith.ps1','08-java-monolith.ps1',
    '09-mern.ps1','10-go.ps1','11-serverless.ps1','12-typescript.ps1',
    '13-dotnet.ps1','14-django.ps1','15-rails.ps1','16-data-platform.ps1',
    '17-rust.ps1','18-kotlin.ps1','19-platform.ps1','20-observability.ps1',
    '21-mlops.ps1','22-secure-factory.ps1','23-operator.ps1','24-azure.ps1',
    '25-gcp.ps1','26-reliability.ps1','27-llmops.ps1','28-mesh.ps1',
    '29-finops.ps1','30-database.ps1','31-progressive.ps1',
    '32-security-ops.ps1','33-temporal.ps1'
)
$results=foreach($builder in $builders){
    & (Join-Path $PSScriptRoot $builder) -WhatIfMode:$WhatIfMode
}

. (Join-Path $PSScriptRoot 'Common.ps1')
$moduleRoot=Join-Path $script:WorkspaceRoot '20. Final Mega Capstone Project'
$catalog=@'
# Module 20 - Industry DevOps Project Portfolio

This folder contains thirty-three runnable, production-shaped capstone templates. The portfolio compares microservices with modular monoliths, then adds enterprise application stacks, systems programming, event-driven services, serverless and data engineering, internal platforms, observability, governed ML/LLM delivery, software-supply-chain security, Kubernetes API engineering, multi-cloud foundations, measurable resilience, zero-trust networking, FinOps, database operations, progressive delivery, detection engineering, and durable execution.

> These are learning and portfolio baselines, not a claim that one template can satisfy every company's compliance, scale, or cloud requirements unchanged. Replace all placeholder domains, registries, credentials, repository URLs, state backends, and capacity assumptions before deployment.

## Project matrix

| # | Project | Architecture | Backend | Frontend | Local port |
|---:|---|---|---|---|---:|
| 1 | [Python Commerce](01-python-commerce-microservices/README.md) | Microservices | Python 3.12, FastAPI | React, Vite | 8081 |
| 2 | [Java Banking](02-java-banking-microservices/README.md) | Microservices | Java 21, Spring Boot | Vue 3, Vite | 8082 |
| 3 | [Node Booking](03-node-booking-microservices/README.md) | Microservices | Node.js 24 LTS, Express | Next.js, React | 8083 |
| 4 | [PHP Inventory](04-php-inventory-monolith/README.md) | Modular monolith | PHP 8.3, Slim, PostgreSQL | Vue 3, Vite | 8084 |
| 5 | [C++ Telemetry](05-cpp-telemetry-monolith/README.md) | Modular monolith | C++20, SQLite | React, Vite | 8085 |
| 6 | [Node Helpdesk](06-node-helpdesk-monolith/README.md) | Modular monolith | Node.js 24, Express, PostgreSQL | React, Vite | 8086 |
| 7 | [Python Learning](07-python-learning-monolith/README.md) | Modular monolith | Python 3.12, FastAPI, PostgreSQL | Server-rendered/progressive web | 8087 |
| 8 | [Java Supply Chain](08-java-supply-chain-monolith/README.md) | Modular monolith | Java 21, Spring Boot, PostgreSQL | Spring static web app | 8088 |
| 9 | [MERN Collaboration](09-mern-team-collaboration/README.md) | Full-stack two-tier | MongoDB, Express, Node.js | React, Vite | 8089 |
| 10 | [Go URL Shortener](10-go-url-shortener/README.md) | Cloud-native service | Go, pgx, PostgreSQL | Embedded web UI | 8090 |
| 11 | [AWS Media Pipeline](11-aws-serverless-media-pipeline/README.md) | Serverless/event-driven | Lambda, API Gateway, SQS, DynamoDB, S3 | HTTP API | n/a |
| 12 | [TypeScript B2B SaaS](12-typescript-nestjs-angular-saas/README.md) | Enterprise two-tier | Node.js 24, NestJS 11, PostgreSQL | Angular 22 | 8091 |
| 13 | [.NET Insurance Claims](13-dotnet-insurance-monolith/README.md) | Modular monolith | .NET 10 LTS, ASP.NET Core, PostgreSQL | ASP.NET static web | 8092 |
| 14 | [Django Logistics](14-django-logistics-workers/README.md) | Web plus async workers | Django 5.2 LTS, Celery, Redis, PostgreSQL | Django progressive web | 8093 |
| 15 | [Rails Subscription Billing](15-rails-subscription-billing/README.md) | Convention-driven monolith | Ruby 3.4, Rails 8.1, PostgreSQL | Rails views, Hotwire | 8094 |
| 16 | [Modern Data Platform](16-modern-data-platform/README.md) | Batch and streaming platform | Airflow 3, Spark 4, dbt, Kafka 4, PostgreSQL | Airflow UI / data products | 8095 |
| 17 | [Rust Payment Risk](17-rust-payment-risk-service/README.md) | Event-driven service | Rust 1.97, Axum, PostgreSQL, NATS | HTTP API | 8097 |
| 18 | [Kotlin Energy Trading](18-kotlin-energy-trading-api/README.md) | Reactive enterprise service | Kotlin 2.4, Spring Boot 4.1, R2DBC, PostgreSQL | HTTP API | 8098 |
| 19 | [Internal Developer Platform](19-internal-developer-platform/README.md) | Platform control plane | Backstage 1.49, Crossplane 2, Argo CD, Kyverno | Developer portal / platform APIs | n/a |
| 20 | [OpenTelemetry Observability](20-opentelemetry-observability-platform/README.md) | Observability platform | OpenTelemetry Collector, Prometheus, Loki, Tempo | Grafana 13 | 8101 |
| 21 | [MLOps Model Delivery](21-mlops-model-delivery-platform/README.md) | ML delivery platform | MLflow 3.15, scikit-learn, PostgreSQL, MinIO | FastAPI / MLflow UI | 8102 / 8103 |
| 22 | [Secure Software Factory](22-secure-software-factory/README.md) | Software supply chain | SLSA 1.2, Sigstore, Syft, Grype, Kyverno | Evidence and policy APIs | 8105 |
| 23 | [Go Kubernetes Operator](23-go-kubernetes-operator/README.md) | Kubernetes control loop | Go 1.26, controller-runtime 0.24, Kubernetes 1.36 | Custom Kubernetes API | n/a |
| 24 | [Azure Enterprise Platform](24-azure-enterprise-platform/README.md) | Azure landing zone | Bicep, private AKS, Entra Workload Identity, Key Vault | Platform APIs | n/a |
| 25 | [GCP Enterprise Platform](25-gcp-enterprise-platform/README.md) | Google Cloud landing zone | Terraform, private GKE, Workload Identity, Binary Authorization | Platform APIs | n/a |
| 26 | [Reliability and DR Lab](26-reliability-disaster-recovery-lab/README.md) | Resilience laboratory | Chaos Mesh, Toxiproxy, k6, Velero, PostgreSQL | FastAPI / evidence scoring | 8106 |
| 27 | [LLMOps RAG Platform](27-llmops-rag-platform/README.md) | Generative-AI delivery platform | vLLM, KServe, Qdrant, FastAPI | Governed RAG API | 8107 |
| 28 | [Istio Zero-Trust Mesh](28-istio-zero-trust-multicluster-mesh/README.md) | Multi-cluster service mesh | Istio ambient, Gateway API, ztunnel, waypoints | Platform networking APIs | n/a |
| 29 | [FinOps Governance](29-finops-opencost-focus-governance/README.md) | Cloud cost control plane | OpenCost, FOCUS, Prometheus, policy as code | Showback and unit economics | n/a |
| 30 | [Cloud-Native PostgreSQL](30-cloudnative-postgresql-database-platform/README.md) | Database platform | PostgreSQL 18, CloudNativePG, PgBouncer, Barman | SQL / database services | 5432 |
| 31 | [Progressive Delivery](31-progressive-delivery-openfeature-platform/README.md) | Release control plane | Argo Rollouts, OpenFeature, flagd, Prometheus | Checkout feature API | 8131 / 8013 |
| 32 | [Detection and Response](32-cloud-native-detection-response-platform/README.md) | Security operations platform | Falco, Tetragon, audit logs, Sigma | Findings and incident evidence | n/a |
| 33 | [Temporal Durable Workflows](33-temporal-durable-workflow-platform/README.md) | Durable execution platform | Temporal 1.31, Python SDK, PostgreSQL | Temporal gRPC / UI | 7233 / 8233 |

## What projects 1-10, 12-15, and 17-18 contain

| Area | Ready-to-adapt assets |
|---|---|
| Application | Backend source, frontend source, health endpoint, metrics endpoint, example API, structured logging, validation, idempotency pattern |
| Architecture | `docs/HLD.md`, `docs/LLD.md`, dependency register, threat model, incident runbook, Mermaid diagrams |
| Containers | Hardened Dockerfiles, non-root runtime where supported, health checks, multi-stage builds, `docker-compose.yml` |
| Kubernetes | Namespace, ServiceAccount, ConfigMap, placeholder Secret, Deployments, Services, Ingress, HPA, PDB, probes, resources, security contexts, NetworkPolicy |
| Packaging | Kustomize base plus dev/prod overlays; reusable Helm chart and environment values |
| CI/CD | GitHub Actions workflow, Jenkins declarative pipeline, build/test/smoke/scan/publish/deploy gates |
| GitOps | Argo CD Application with prune, self-heal, retry, and production overlay |
| Infrastructure | Terraform AWS VPC, EKS, ECR, optional encrypted RDS PostgreSQL, variables and outputs |
| Configuration | Ansible inventory example, pinned collection range, rolling Docker Compose deployment, Vault-variable placeholders |
| Operations | ServiceMonitor, PrometheusRule, smoke test, SLO/runbook guidance, Kyverno baseline policy |

Project 11 uses the controls appropriate to serverless workloads instead: Terraform, AWS SAM, least-privilege IAM, SQS/DLQ redrive, Lambda partial-batch failure, DynamoDB idempotency, CloudWatch alarms, tests, threat model, and incident runbook.

Project 16 uses data-platform equivalents: Airflow DAGs, Kafka events, a versioned JSON Schema contract, idempotent ingestion, Spark/Parquet processing, dbt models and tests, Kubernetes batch workloads, an encrypted S3/Glue Terraform baseline, CI, threat model, and data-incident runbook.

Projects 19-21 focus on shared platforms. Project 19 supplies a Backstage software template, Crossplane composite API, Argo CD fleet delivery, Kyverno guardrails, and an EKS foundation. Project 20 correlates metrics, traces, and logs through an OpenTelemetry Collector into Prometheus, Tempo, Loki, and Grafana, with recording rules and an SLO runbook. Project 21 joins repeatable model training, MLflow experiment and registry metadata, object storage, a production inference service, model-card governance, drift guidance, and an Argo Rollouts canary.

Projects 22-27 complete the platform-capability path. Project 22 creates and verifies SBOM, provenance, signature, scan, and admission evidence. Project 23 implements a Kubernetes API, leader-elected controller, status conditions, drift repair, and finalizer. Projects 24-25 provide governed Azure and Google Cloud landing-zone baselines alongside the AWS-heavy projects. Project 26 turns reliability and recovery into measured game-day evidence. Project 27 adds tenant-filtered RAG, evaluation, prompt/model governance, and GPU-serving contracts.

Projects 28-33 complete the advanced operations path. Project 28 builds ambient zero-trust and multi-cluster service networking. Project 29 connects OpenCost allocations, FOCUS-shaped billing, budgets, showback, rightsizing, and unit economics. Project 30 treats PostgreSQL as a managed platform with HA, pooling, migration, backup, PITR and restore evidence. Project 31 separates deployment, traffic progression and feature exposure with automated analysis. Project 32 turns runtime and audit signals into tested detections and response evidence. Project 33 adds deterministic durable workflows, activities, compensation, history replay and safe worker/server upgrades.

## Fast start

Choose a containerized project and run from its folder:

```bash
cp .env.example .env
docker compose config
docker compose up --build -d
bash scripts/smoke-test.sh http://localhost:8081 # use the project's port
docker compose down --volumes
```

Validate Kubernetes without applying anything:

```bash
kubectl kustomize k8s/overlays/dev
kubectl apply --dry-run=client -k k8s/overlays/dev
```

For project 11, run `python -m unittest discover -s tests -v`, `sam validate --lint`, and `terraform -chdir=terraform validate` before considering an AWS plan. For project 16, validate contracts/tests first, then bring up Airflow/Kafka and run the producer, Spark, and dbt profiles independently. Projects 19-33 have specialized quick starts in their own READMEs. In particular, never apply admission, operator-finalizer, landing-zone, chaos, recovery, GPU-serving, mesh-trust, database, progressive-delivery, runtime-sensor, or workflow-persistence resources before reviewing their blast radius, identity, cost, data, and deletion behavior.

Provisioning is intentionally not automatic. Review cost, IAM, network exposure, supported runtime/platform versions, remote state, backups, DNS/TLS, secrets integration, and organizational controls before running `terraform apply`.

## Suggested learning order

1. Start with Python Learning or Node Helpdesk to understand module boundaries, transactions, and one-unit deployment.
2. Compare Node Helpdesk with Node Booking, Python Learning with Python Commerce, and Java Supply Chain with Java Banking. Explain when distribution is worth its operational cost.
3. Run MERN Collaboration to learn document modeling, a separate API/UI release boundary, and managed MongoDB operations.
4. Run Go URL Shortener to study small binaries, graceful shutdown, connection pools, redirect hot paths, and low-cardinality metrics.
5. Compare NestJS/Angular with MERN, then compare ASP.NET Core, Django/Celery, and Rails/Hotwire for team structure, background work, framework conventions, and release boundaries.
6. Compare Rust/Axum with Kotlin/WebFlux for throughput, memory safety, reactive I/O, transactional boundaries, outbox delivery, and team-operability trade-offs.
7. Render Kustomize and Helm; trace a request from Ingress to Service to Pod, then promote an immutable image through GitOps.
8. Run the serverless pipeline tests and trace duplicate intake, SQS retry, partial batch failure, DLQ isolation, and bounded Lambda concurrency.
9. Run the data platform contract tests, trace an order from Kafka/raw ingestion through dbt and Spark outputs, then design a safe replay and backfill.
10. Use the internal developer platform to follow a golden path from catalog template to a governed cloud resource and fleet deployment.
11. Correlate one failure across metrics, traces, and logs; burn an error budget and use the observability runbook to triage it.
12. Train, evaluate, register, approve, canary, monitor, and roll back a model while preserving lineage and governance evidence.
13. Rehearse latency, crash-loop, dependency, poison-message, data-quality, drift, restore, and rollback incidents with the runbooks.
14. Defend every HLD/LLD and architecture trade-off as if presenting in a senior DevOps/SRE, platform, or ML/data interview.
15. Produce a signed release by digest, independently verify its SLSA/SBOM evidence, then prove admission rejects an untrusted artifact.
16. Implement and operate the Environment custom resource; demonstrate idempotent reconciliation, drift repair, leader election, status and safe finalization.
17. Compare AWS, Azure and Google Cloud foundations across hierarchy, identity, networking, policy, secrets, Kubernetes and audit models without forcing false portability.
18. Run the reliability game days and submit measured detection, RTO, RPO, availability, checksum and error-budget evidence.
19. Release the RAG stack as one model/prompt/embedding/vector-schema unit; evaluate retrieval, grounding, citations, injection resistance, latency and cost before canary promotion.
20. Build the ambient mesh and prove identity, strict mTLS, L4/L7 default deny, bounded traffic behavior, telemetry and multi-cluster recovery.
21. Reconcile OpenCost allocation to FOCUS-shaped billing, defend shared-cost policy, and connect optimization to business unit economics.
22. Operate the PostgreSQL platform through connection saturation, failover, online migration, backup and point-in-time recovery evidence.
23. Separate artifact deployment, canary traffic and feature exposure; use metric analysis and governed flags to promote or restore safely.
24. Replay cloud-native security events against tested detections, preserve evidence, and execute scoped containment with accountable ownership.
25. Run a durable Temporal workflow through worker failure, activity retry, compensation, history replay and compatible worker migration.
26. Use projects 22-33 as the final platform-engineering defense: explain supply-chain trust, control loops, cloud ownership, service identity, cost accountability, data recovery, safe delivery, security response, durable execution, and AI governance.

## Production adoption gate

Before real use, require owner approval for the architecture decision record, threat model, data classification, IAM and mesh-trust boundaries, secrets source, database migration/restore drill, SLOs, alerts, capacity tests, software/model licenses, SBOM/provenance/signatures, admission and finalizer behavior, disaster recovery, cloud/GPU cost and unit-economics estimate, feature-flag lifecycle, detection ownership, workflow replay compatibility, model/data governance where applicable, and rollback evidence.
'@
Write-TemplateFile $script:ProjectsRoot 'README.md' $catalog -WhatIfMode:$WhatIfMode

$moduleIndex=@'
# Module 20 Project Templates

Module 20 now includes a thirty-three-project, multi-language DevOps, platform-engineering, cloud, security, resilience, observability, and ML/data portfolio in [`projects/`](projects/README.md):

1. Python Commerce Microservices with React
2. Java Banking Microservices with Vue
3. Node.js Booking Microservices with Next.js/React
4. PHP Inventory Modular Monolith with Vue
5. C++ Edge Telemetry Modular Monolith with React
6. Node.js Helpdesk Modular Monolith with React
7. Python Learning Management Modular Monolith
8. Java Supply Chain Modular Monolith
9. MERN Team Collaboration Platform
10. Go Cloud-Native URL Shortener
11. AWS Serverless Media Processing Pipeline
12. TypeScript B2B SaaS with NestJS and Angular
13. .NET Insurance Claims Modular Monolith
14. Django Logistics with Celery Workers
15. Rails Subscription Billing with Hotwire
16. Airflow, Spark, dbt, and Kafka Modern Data Platform
17. Rust Event-Driven Payment Risk Service
18. Kotlin Reactive Energy Trading API
19. Backstage, Crossplane, Argo CD, and Kyverno Internal Developer Platform
20. OpenTelemetry, Prometheus, Loki, Tempo, and Grafana Observability Platform
21. MLflow Model Training, Registry, Inference, and Canary Delivery Platform
22. SLSA, Sigstore, SBOM, and Admission-Control Secure Software Factory
23. Go and controller-runtime Kubernetes Environment Operator
24. Bicep, AKS, Entra, Key Vault, and Azure Policy Enterprise Platform
25. Terraform, GKE, Workload Identity, and Binary Authorization GCP Platform
26. Chaos Mesh, Toxiproxy, k6, Velero, and Multi-Region Recovery Lab
27. vLLM, KServe, Qdrant, Evaluation, and Governed RAG LLMOps Platform
28. Istio Ambient, Gateway API, Zero-Trust, and Multi-Cluster Service Mesh
29. OpenCost, FOCUS, Showback, Budget, and Unit-Economics FinOps Platform
30. PostgreSQL 18, CloudNativePG, PgBouncer, Backup, and PITR Database Platform
31. Argo Rollouts, OpenFeature, flagd, and Prometheus Progressive Delivery Platform
32. Falco, Tetragon, Audit, Detection-as-Code, and Incident Response Platform
33. Temporal Durable Workflows, Activities, Compensation, Replay, and Worker Versioning

Projects 1-10, 12-15, and 17-18 include runnable application source plus Docker, Compose, Kubernetes, Kustomize, Helm, Jenkins, GitHub Actions, Ansible, Terraform, Argo CD, observability, security, HLD, LLD, dependency, threat-model, and runbook templates. Project 11 provides the serverless equivalents with Terraform, AWS SAM, API Gateway, Lambda, SQS/DLQ, DynamoDB, S3, IAM, CloudWatch, tests, and operations documentation. Project 16 provides data-platform equivalents with Airflow, Spark, dbt, Kafka, contracts, quality gates, Kubernetes batch workloads, and an encrypted AWS data-lake baseline. Projects 19-21 add an internal developer platform, correlated telemetry, and governed MLOps. Projects 22-27 add verified supply-chain delivery, Kubernetes controller engineering, Azure/GCP foundations, objective reliability/DR practice, and governed LLM/RAG operations. Projects 28-33 add service-mesh engineering, FinOps, PostgreSQL platform operations, progressive delivery, cloud-native detection/response, and durable workflow orchestration.

Start with the [project catalog](projects/README.md), then follow the README inside the selected project.
'@
Write-TemplateFile $moduleRoot 'PROJECTS.md' $moduleIndex -WhatIfMode:$WhatIfMode

[pscustomobject]@{
    Mode=if($WhatIfMode){'preview'}else{'generated'}
    Projects=$results.Count
    ProjectFiles=($results|Measure-Object -Property Files -Sum).Sum
    CatalogFiles=$script:Generated.Count
}
