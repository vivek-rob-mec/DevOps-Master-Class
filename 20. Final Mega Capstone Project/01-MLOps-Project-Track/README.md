# Runnable MLOps projects and AIOps, followed by FinOps and FDE

Status: **three runnable local MLOps applications and one runnable AIOps application**. Code, training, serving, persistence, release handling, tests, Compose files, CI, and labs are included inside this track. These projects live here separately from the original 34-project catalog.

**Start with [QUICKSTART.md](QUICKSTART.md)** for installation, one-command demonstrations, tests, and live APIs. Read [VERIFICATION.md](VERIFICATION.md) for executed checks. Every project has an implementation map separating the working local system from the wider HLD/LLD production design.

**All four projects now have working frontend/API/database workflows.** [Demand Desk](01-demand-forecasting/README.md) covers forecast planning and saved inventory reviews. [Risk Desk](02-payment-risk/README.md) adds payment scoring, analyst reviews, and delayed outcome labels. [Fleet Desk](03-predictive-maintenance/README.md) adds sensor histories, inspection reviews, and durable upload status. [Incident Desk](04-aiops-incident-triage/README.md) connects shared telemetry to incident evidence, controlled replays, and human proposal reviews.

Use the [planner walkthrough](01-demand-forecasting/PLANNER-WALKTHROUGH.md), [analyst walkthrough](02-payment-risk/ANALYST-WALKTHROUGH.md), [operator walkthrough](03-predictive-maintenance/OPERATOR-WALKTHROUGH.md), then [triage walkthrough](04-aiops-incident-triage/TRIAGE-WALKTHROUGH.md) to connect browser actions to HLD/LLD, reproduce failures, and practice delayed recall.

The sequence follows your requested direction: complete two or three substantial MLOps projects, then build AIOps, then FinOps, and later explore Forward Deployed Engineering. We propose three because batch, online, and edge systems expose different deployment and system-design problems.

## Selected projects

| Order | Project and industry problem | Distinct learning objective | Design |
|---|---|---|---|
| M1 | Retail demand forecasting and replenishment decision support | Time-aware data pipelines, batch inference, evaluation, forecast uncertainty, business-policy simulation | [HLD](01-demand-forecasting/HLD.md), [LLD](01-demand-forecasting/LLD.md) |
| M2 | Payment-risk scoring with delayed fraud feedback | Online feature consistency, low-latency serving, imbalance, delayed labels, shadow releases | [HLD](02-payment-risk/HLD.md), [LLD](02-payment-risk/LLD.md) |
| M3 | Equipment health and remaining-life estimation with edge serving | Time-series windows, entity isolation, intermittent connectivity, immutable model distribution, fleet recovery | [HLD](03-predictive-maintenance/HLD.md), [LLD](03-predictive-maintenance/LLD.md) |
| A1 | Incident detection and evidence-based triage for the MLOps services | Isolation Forest versus rules, shared telemetry, incident persistence, human review without automatic execution | [Run](04-aiops-incident-triage/README.md), [HLD](04-aiops-incident-triage/HLD.md), [LLD](04-aiops-incident-triage/LLD.md) |

These projects address established industry problems with continuing relevance. The selection is a learning recommendation, not a ranking of market growth rates or a claim that employers require these exact tools.

Recent primary sources show active work on [retail forecasting and inventory decisions](https://business.amazon.com/en/blog/supply-chain-forecasting), [adaptive payment fraud](https://www.eba.europa.eu/publications-and-media/press-releases/joint-eba-ecb-report-payment-fraud-strong-authentication-remains-effective-fraudsters-are-adapting), and [AI measurement and integration for manufacturing](https://www.nist.gov/programs-projects/artificial-intelligence-ai-manufacturing). Each blueprint connects a business problem to an experiment and states the evidence still needed.

## Reuse and deepen existing work

- [Project 21](../projects/21-mlops-model-delivery-platform/README.md): reuse lifecycle ideas for training, registry, inference, and rollout. Its synthetic generic classifier is a foundation; these projects add domain-specific contracts and evaluation.
- [Project 34](../projects/34-standard-multistack-deployment/README.md): reuse artifact promotion and environment verification practices. Extend release identity to include data, features, model, thresholds, and application image.
- [Project 20](../projects/20-opentelemetry-observability-platform/README.md): add telemetry after the application works; deploy only the observability components needed for the current experiment.
- [Project 27](../projects/27-llmops-rag-platform/README.md): keep LLMOps/RAG as a separate extension. None of the three proposed core projects requires a paid model API or a GPU.

## Local-first implementation

Use Python for the first complete implementation, small CPU models, bounded datasets, and one project at a time. Start with scripts, a local artifact directory, and SQLite or DuckDB where appropriate. Introduce PostgreSQL, MLflow, an API, and Compose as their responsibilities become relevant. A model registry need not become a separate fleet of services in the first experiment.

Budget roughly 4–6 GB of lab memory initially on the 16 GB laptop, leaving host headroom. This is an allocation target to measure, not a tested guarantee. Train separately from serving and monitoring, limit parallel workers, and stop inactive profiles. Kubernetes, multiple sites, and cloud adapters follow working local milestones. Avoid large distributed training, full Kafka/Spark clusters, and GPU inference as prerequisites.

No cloud account or paid service is required for the core path. Optional public dataset downloads require internet access and a recorded source/license. Deterministic small fixtures should support offline contract tests; they do not establish real-world model performance.

## Completion standard

Learn the ML prerequisites alongside each first experiment: features versus labels, regression versus classification, training/validation/test separation, leakage, a baseline, and error interpretation. M1 adds time-aware splits and forecast error; M2 adds class imbalance, precision/recall, calibration, and delayed feedback; M3 adds entity-held-out time-series evaluation. You do not need to finish an advanced deep-learning course before beginning these CPU baselines.

Follow [DELIVERY-AND-EVIDENCE.md](DELIVERY-AND-EVIDENCE.md) for all projects. A project is complete only when another learner can reproduce a baseline, train/evaluate a candidate without leakage, release it, observe a controlled failure, recover, and trace the results to its release record.

A model that does not beat the baseline must remain unpromoted. Explaining that result correctly is valid project evidence. Do not write an improvement percentage, loss prevented, or downtime saved before measuring it under a stated evaluation method.

## Track progression, in your requested order

| Track | Proposed continuing project | Relationship to completed work |
|---|---|---|
| AIOps: included | [Incident detection and evidence-based triage](04-aiops-incident-triage/README.md) | Runnable local detector, shared HTTP/release telemetry, fault fixtures, incident ledger, and reviewed proposals. Reviews do not execute remediation. Anomaly correlation does not prove root cause. |
| FinOps: included in a separate track | [Cost Desk: ML platform cost governance](../02-FinOps-Project-Track/README.md) | Working CSV ingestion, exact shared-cost allocation, scoped budgets, linear forecasts, cost per successful workload unit, and reviewed savings hypotheses. Uses synthetic billing/usage; actual resource collectors, provider invoices, and realized savings remain extensions. |
| Forward Deployed Engineering | A customer implementation case using one completed ML product | Work through discovery, messy source-system integration, access boundaries, acceptance criteria, a constrained pilot, user feedback, operational handover, and a measured outcome. Keep simulated customer requirements distinct from real customer validation. |

FinOps for AI has practical relevance: the [FinOps Foundation's 2026 survey](https://data.finops.org/) reports AI-spend management and visibility/value challenges among respondents. That survey describes its participants, not every company.

FDE is a customer-facing engineering mode rather than a mandatory final technology certification. [Palantir's account of its FDE approach](https://community.palantir.com/t/who-are-palantir-fdes/6847/4) is one company's perspective; role scope varies. The later exercise should evaluate problem discovery and adoption as well as technical deployment.

## Start with M1

First explain the difference between recorded sales and actual customer demand. Then create a seasonal-naive baseline on a chronologically split dataset and a decision log. This gives a meaningful comparison before adding MLflow, an API, or Kubernetes. Use the [design worksheet](../00-Deployment-Learning-Path/templates/DESIGN-AND-LAB.md) and [delayed recall routine](../00-Deployment-Learning-Path/RETENTION.md) for every milestone.
