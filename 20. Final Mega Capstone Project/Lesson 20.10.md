# Module 20 — Final Mega Capstone Project

## Lesson 10: Platform Self-service and FinOps Controls

# 20.10.1 Atlas golden path

The internal platform template creates:

```text
source repository and ownership
service catalog entity and docs
CI/SBOM/provenance workflow
container and Kubernetes manifests
GitOps Application/config
workload identity and secret references
metrics/logs/traces, SLO starter, dashboard, alerts
runbook, cost labels, lifecycle metadata
```

An environment claim provisions approved dev or production classes through the documented Terraform/GitOps boundary. Status is durable, operations are idempotent, and deletion protects retained data.

# 20.10.2 Platform product evidence

Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.

# 20.10.3 Cost allocation

Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.

# 20.10.4 Unit economics

```text
cost per successful order
cost per active tenant
platform cost per successful production deployment
observability cost per production service
```

Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.

# 20.10.5 Optimization plan

```text
eliminate orphan/expired resources
schedule safe non-production environments
rightsize Kubernetes requests and databases
improve bin packing/node mix
tier storage/log/trace retention
reduce avoidable transfer
commit stable eligible baseline
use spot for interruption-tolerant work
```

Every action has owner, estimate, confidence, effort, risk, guardrail, due date, and realized-value validation. No cost automation deletes unknown production assets.

# 20.10.6 Budget and anomaly

Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.

# 20.10.7 Acceptance

```text
□ New service reaches dev through self-service
□ Fleet upgrade path exists
□ Cost allocation is reconciled and owned
□ Unit cost supports a business decision
□ Optimization preserves SLO/security/DR
□ Estimated and realized savings are separate
□ Exceptions are approved and expire
```

# 20.10.8 Atlas platform product

The `PavedRoad` capability lets a team request:

```text
Application -> repository/catalog/docs/delivery/runtime intent
Environment -> preview/dev/prod class with lifecycle
Database -> approved capacity/recovery/data class
Observability -> telemetry/SLO/dashboard/alert baseline
```

Portal, CLI, API, and Git use the same governed backend contracts.

# 20.10.9 Product discovery and outcome

Baseline one developer journey and target:

```text
before: 10 days, 12 tickets, missing owner/SLO/secret policy
target: production-ready lab service <1 day,
        90% task completion without privileged ticket,
        all readiness checks evidenced,
        platform-caused failure <defined objective
```

Interview and usability-test; do not assume template completion equals success.

# 20.10.10 Golden-path workflow

```text
validate owner/tier/data/budget
-> create repository and catalog/TechDocs
-> add reusable secure CI
-> create GitOps environment config
-> provision database/identity/secret references
-> onboard observability/SLO/runbook
-> deploy synthetic service
-> status/evidence/cost link
```

Durable workflow ID makes retries idempotent and exposes partial state.

# 20.10.11 Platform security and tenancy

Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.

Run cross-team catalog/API/GitOps/Kubernetes/cloud/secret/backend access tests.

# 20.10.12 Platform SLO and lifecycle

Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence.

Maintain template/API version, consumer inventory, canary compatibility fixtures, migration PRs, support window, and decommission path.

# 20.10.13 Cost allocation model

Reconcile Atlas cloud cost:

```text
direct service resources
+ EKS nodes allocated by request/usage policy
+ storage/load balancer/network/observability direct drivers
+ shared platform/security/support policy
+ explicit idle and unknown
= provider total under stated accounting view
```

Catalog provides ownership; billing and Kubernetes telemetry provide cost/usage facts.

# 20.10.14 Unit economics

```text
unit = 1,000 authoritative successful Atlas orders
unit cost = fully loaded attributable technology cost / order units
```

Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout SLO/correctness/value.

# 20.10.15 Budget and forecast

Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.

Budget crossings never automatically terminate critical checkout without explicit approved policy.

# 20.10.16 Optimization portfolio

Required hypotheses:

```text
Kubernetes request/bin packing/node classes/Spot
preview TTL/scheduling and orphan cleanup
database query/index/capacity
storage/backup lifecycle
telemetry cardinality/volume/retention/sampling
network/CDN/cross-zone/region path
commitment only after normalized stable demand
architecture effect on cost per order
```

Each has baseline, potential range, guardrails, experiment, rollback, and realization.

# 20.10.17 Real hands-on: self-service service

Ask a developer unfamiliar with the platform to create `recommendation-api`, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.

# 20.10.18 Failure lab: provider partial failure

Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.

# 20.10.19 Failure lab: budget and policy abuse

Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.

# 20.10.20 Failure lab: cost anomaly

A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.

# 20.10.21 Realized-savings evidence

Choose one optimization and report:

```text
normalized baseline at actual comparable demand
implemented Git/PR/release
post-change cost and unit cost
SLO/security/DR guardrails
price/volume/mix/allocation adjustments
overlap/rebound/migrated cost
confidence and review window
```

# 20.10.22 Acceptance checklist

- Golden path improves measured user task and readiness.
- Capability APIs are versioned, secure, idempotent, observable.
- Partial failure/upgrade/control outage/deletion are tested.
- Tenant and supply-chain boundaries pass attacks.
- Cost reconciles with transparent shared/idle/unknown.
- Forecast/anomaly/unit cost connect to owners and product value.
- Optimization is implemented and realized with SLO guardrails.
- Budgets/policies/exceptions are proportional and auditable.
- Platform and FinOps have support/decision cadences.

# 20.10.23 Certification and interview preparation

This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams.

**Beginner: How does a platform help FinOps?**  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and safe automation at the point of creation.

**Intermediate: Why catalog for allocation?**  It maps technical entities to maintained owner/product/lifecycle, but billing/runtime facts still come from authoritative systems.

**Intermediate: Unit cost for Atlas?**  Fully loaded attributable cost divided by authoritative successful order units, under a versioned policy.

**Senior: How do you prevent cost guardrails harming reliability?**  Risk-tiered deny/approve/warn, SLO/RTO/RPO guardrails, exact owner/context, staged actions, exceptions, and post-change validation.

**Senior: How do you measure platform ROI?**  Developer task/lead-time/readiness/support/toil improvement plus platform cost and business delivery/value—not only portal adoption.

**Expert: How automate preview cleanup?**  Owner/TTL/data/IaC/dependency checks, warning/renewal, exact idempotent deletion, batch/rate/audit, retention block, orphan/cost verification.

**Architect: How do platform and FinOps teams collaborate?**  FinOps supplies cost/value data/policy; platform encodes timely developer guardrails/interfaces; product/engineering own business/reliability decisions; finance governs plans/contracts.

**Never-forget answer:** move cost decisions into the developer journey with ownership, safe defaults, transparent unit value, and verified outcomes—not surprise invoices.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 20.10.24 Professional Mastery Workbook

This workbook expands **Platform Self-service and FinOps Controls** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 23 lesson-specific anchors.
- Progression: beginner, intermediate, expert, professional, industry-ready, certification review, and interview defense.
- Safety: use synthetic data, disposable resources, explicit placeholders, least privilege, and bounded failure experiments.
- Completion: retain commands or configuration, observations, screenshots or query output, decisions, rollback evidence, and a short reflection.
- Quality rule: a passing answer states assumptions, protects a user or business outcome, names ownership, and validates the final result end to end.
- Currency rule: verify current official documentation, versions, limits, pricing, and certification objectives before relying on changing product behavior.

## Seven-stage progression

| Stage | Learner must demonstrate |
|---|---|
| Beginner | Explain the concept in plain language and give one safe example. |
| Intermediate | Connect components, data, control flow, and normal operating behavior. |
| Expert | Analyze trade-offs, edge cases, scaling pressure, and correlated failures. |
| Professional | Make a reviewed decision with owner, evidence, rollout, and rollback. |
| Industry-ready | Operate the design under security, failure, recovery, cost, and compliance constraints. |
| Certification review | Map durable concepts to the latest official objectives without relying on stale wording. |
| Interview defense | Answer concisely, clarify assumptions, draw the model, and defend alternatives. |

## Concept mastery cards

### Concept card 1 - Atlas golden path

- Lesson anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Beginner explanation: Restate **Atlas golden path** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Atlas golden path** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Atlas golden path**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Atlas golden path**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Atlas golden path** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Platform product evidence

- Lesson anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Beginner explanation: Restate **Platform product evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Platform product evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Platform product evidence**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Platform product evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Platform product evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Cost allocation

- Lesson anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Beginner explanation: Restate **Cost allocation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cost allocation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Cost allocation**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Cost allocation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Cost allocation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Unit economics

- Lesson anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Beginner explanation: Restate **Unit economics** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Unit economics** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Unit economics**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Unit economics**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Unit economics** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Optimization plan

- Lesson anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Beginner explanation: Restate **Optimization plan** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Optimization plan** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Optimization plan**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Optimization plan**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Optimization plan** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Budget and anomaly

- Lesson anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Beginner explanation: Restate **Budget and anomaly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Budget and anomaly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Budget and anomaly**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Budget and anomaly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Budget and anomaly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Acceptance

- Lesson anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Beginner explanation: Restate **Acceptance** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Acceptance** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Acceptance**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Acceptance**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Acceptance** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Atlas platform product

- Lesson anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Beginner explanation: Restate **Atlas platform product** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Atlas platform product** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Atlas platform product**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Atlas platform product**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Atlas platform product** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Product discovery and outcome

- Lesson anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Beginner explanation: Restate **Product discovery and outcome** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Product discovery and outcome** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Product discovery and outcome**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Product discovery and outcome**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Product discovery and outcome** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Golden-path workflow

- Lesson anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Beginner explanation: Restate **Golden-path workflow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Golden-path workflow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Golden-path workflow**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Golden-path workflow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Golden-path workflow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Platform security and tenancy

- Lesson anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Beginner explanation: Restate **Platform security and tenancy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Platform security and tenancy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Platform security and tenancy**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Platform security and tenancy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Platform security and tenancy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Platform SLO and lifecycle

- Lesson anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Beginner explanation: Restate **Platform SLO and lifecycle** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Platform SLO and lifecycle** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Platform SLO and lifecycle**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Platform SLO and lifecycle**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Platform SLO and lifecycle** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Cost allocation model

- Lesson anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Beginner explanation: Restate **Cost allocation model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cost allocation model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Cost allocation model**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Cost allocation model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Cost allocation model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Unit economics

- Lesson anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Beginner explanation: Restate **Unit economics** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Unit economics** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Unit economics**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Unit economics**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Unit economics** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Budget and forecast

- Lesson anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Beginner explanation: Restate **Budget and forecast** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Budget and forecast** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Budget and forecast**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Budget and forecast**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Budget and forecast** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Optimization portfolio

- Lesson anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Beginner explanation: Restate **Optimization portfolio** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Optimization portfolio** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Optimization portfolio**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Optimization portfolio**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Optimization portfolio** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Real hands-on: self-service service

- Lesson anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Beginner explanation: Restate **Real hands-on: self-service service** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real hands-on: self-service service** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Real hands-on: self-service service**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Real hands-on: self-service service**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Real hands-on: self-service service** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Failure lab: provider partial failure

- Lesson anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Beginner explanation: Restate **Failure lab: provider partial failure** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure lab: provider partial failure** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Failure lab: provider partial failure**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Failure lab: provider partial failure**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Failure lab: provider partial failure** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Failure lab: budget and policy abuse

- Lesson anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Beginner explanation: Restate **Failure lab: budget and policy abuse** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure lab: budget and policy abuse** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Failure lab: budget and policy abuse**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Failure lab: budget and policy abuse**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Failure lab: budget and policy abuse** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Failure lab: cost anomaly

- Lesson anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Beginner explanation: Restate **Failure lab: cost anomaly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure lab: cost anomaly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Failure lab: cost anomaly**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Failure lab: cost anomaly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Failure lab: cost anomaly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Realized-savings evidence

- Lesson anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Beginner explanation: Restate **Realized-savings evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Realized-savings evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Realized-savings evidence**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Realized-savings evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Realized-savings evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Acceptance checklist

- Lesson anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Beginner explanation: Restate **Acceptance checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Acceptance checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Acceptance checklist**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Acceptance checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Acceptance checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Certification and interview preparation

- Lesson anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Beginner explanation: Restate **Certification and interview preparation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Certification and interview preparation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Certification and interview preparation**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Certification and interview preparation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Certification and interview preparation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Atlas golden path x multi-tenancy

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Platform product evidence x observability

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **observability** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Cost allocation x regional resilience

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **regional resilience** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Unit economics x business value

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **business value** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Optimization plan x latency

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **latency** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Budget and anomaly x privacy

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Budget and anomaly** while a change involving **Optimization portfolio** places **privacy** at risk.
- Plain-language question: What problem does **Budget and anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and anomaly** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Acceptance x operability

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Acceptance** while a change involving **Certification and interview preparation** places **operability** at risk.
- Plain-language question: What problem does **Acceptance** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Atlas platform product x data integrity

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas platform product** while a change involving **Acceptance** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas platform product** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas platform product** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Product discovery and outcome x automation safety

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Product discovery and outcome** while a change involving **Unit economics** places **automation safety** at risk.
- Plain-language question: What problem does **Product discovery and outcome** solve here, and who notices first when it fails?
- Lesson evidence anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Product discovery and outcome** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Golden-path workflow x governance

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Golden-path workflow** while a change involving **Realized-savings evidence** places **governance** at risk.
- Plain-language question: What problem does **Golden-path workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Golden-path workflow** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Platform security and tenancy x correctness

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform security and tenancy** while a change involving **Optimization plan** places **correctness** at risk.
- Plain-language question: What problem does **Platform security and tenancy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform security and tenancy** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Platform SLO and lifecycle x capacity

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform SLO and lifecycle** while a change involving **Cost allocation model** places **capacity** at risk.
- Plain-language question: What problem does **Platform SLO and lifecycle** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform SLO and lifecycle** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Cost allocation model x cost efficiency

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation model** while a change involving **Failure lab: budget and policy abuse** places **cost efficiency** at risk.
- Plain-language question: What problem does **Cost allocation model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation model** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Unit economics x recovery

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Cost allocation** places **recovery** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Budget and forecast x change management

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Budget and forecast** while a change involving **Golden-path workflow** places **change management** at risk.
- Plain-language question: What problem does **Budget and forecast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and forecast** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Optimization portfolio x dependency failure

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization portfolio** while a change involving **Real hands-on: self-service service** places **dependency failure** at risk.
- Plain-language question: What problem does **Optimization portfolio** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization portfolio** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Real hands-on: self-service service x developer experience

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Real hands-on: self-service service** while a change involving **Atlas golden path** places **developer experience** at risk.
- Plain-language question: What problem does **Real hands-on: self-service service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: self-service service** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Failure lab: provider partial failure x availability

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: provider partial failure** while a change involving **Atlas platform product** places **availability** at risk.
- Plain-language question: What problem does **Failure lab: provider partial failure** solve here, and who notices first when it fails?
- Lesson evidence anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: provider partial failure** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Failure lab: budget and policy abuse x security

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: budget and policy abuse** while a change involving **Budget and forecast** places **security** at risk.
- Plain-language question: What problem does **Failure lab: budget and policy abuse** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: budget and policy abuse** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Failure lab: cost anomaly x delivery safety

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: cost anomaly** while a change involving **Acceptance checklist** places **delivery safety** at risk.
- Plain-language question: What problem does **Failure lab: cost anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: cost anomaly** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Realized-savings evidence x multi-tenancy

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Realized-savings evidence** while a change involving **Budget and anomaly** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Realized-savings evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Realized-savings evidence** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Acceptance checklist x observability

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Cost allocation model** places **observability** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Certification and interview preparation x regional resilience

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Failure lab: cost anomaly** places **regional resilience** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Atlas golden path x business value

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **business value** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Platform product evidence x latency

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **latency** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Cost allocation x privacy

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **privacy** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Unit economics x operability

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **operability** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Optimization plan x data integrity

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **data integrity** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Budget and anomaly x automation safety

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Budget and anomaly** while a change involving **Optimization portfolio** places **automation safety** at risk.
- Plain-language question: What problem does **Budget and anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and anomaly** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Acceptance x governance

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Acceptance** while a change involving **Certification and interview preparation** places **governance** at risk.
- Plain-language question: What problem does **Acceptance** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Atlas platform product x correctness

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Atlas platform product** while a change involving **Acceptance** places **correctness** at risk.
- Plain-language question: What problem does **Atlas platform product** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas platform product** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Product discovery and outcome x capacity

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Product discovery and outcome** while a change involving **Unit economics** places **capacity** at risk.
- Plain-language question: What problem does **Product discovery and outcome** solve here, and who notices first when it fails?
- Lesson evidence anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Product discovery and outcome** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Golden-path workflow x cost efficiency

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Golden-path workflow** while a change involving **Realized-savings evidence** places **cost efficiency** at risk.
- Plain-language question: What problem does **Golden-path workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Golden-path workflow** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Platform security and tenancy x recovery

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform security and tenancy** while a change involving **Optimization plan** places **recovery** at risk.
- Plain-language question: What problem does **Platform security and tenancy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform security and tenancy** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Platform SLO and lifecycle x change management

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform SLO and lifecycle** while a change involving **Cost allocation model** places **change management** at risk.
- Plain-language question: What problem does **Platform SLO and lifecycle** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform SLO and lifecycle** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Cost allocation model x dependency failure

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Cost allocation model** while a change involving **Failure lab: budget and policy abuse** places **dependency failure** at risk.
- Plain-language question: What problem does **Cost allocation model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation model** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Unit economics x developer experience

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Unit economics** while a change involving **Cost allocation** places **developer experience** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Budget and forecast x availability

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Budget and forecast** while a change involving **Golden-path workflow** places **availability** at risk.
- Plain-language question: What problem does **Budget and forecast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and forecast** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Optimization portfolio x security

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Optimization portfolio** while a change involving **Real hands-on: self-service service** places **security** at risk.
- Plain-language question: What problem does **Optimization portfolio** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization portfolio** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Real hands-on: self-service service x delivery safety

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Real hands-on: self-service service** while a change involving **Atlas golden path** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: self-service service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: self-service service** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Failure lab: provider partial failure x multi-tenancy

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: provider partial failure** while a change involving **Atlas platform product** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Failure lab: provider partial failure** solve here, and who notices first when it fails?
- Lesson evidence anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: provider partial failure** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Failure lab: budget and policy abuse x observability

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: budget and policy abuse** while a change involving **Budget and forecast** places **observability** at risk.
- Plain-language question: What problem does **Failure lab: budget and policy abuse** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: budget and policy abuse** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Failure lab: cost anomaly x regional resilience

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: cost anomaly** while a change involving **Acceptance checklist** places **regional resilience** at risk.
- Plain-language question: What problem does **Failure lab: cost anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: cost anomaly** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Realized-savings evidence x business value

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Realized-savings evidence** while a change involving **Budget and anomaly** places **business value** at risk.
- Plain-language question: What problem does **Realized-savings evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Realized-savings evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Acceptance checklist x latency

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Cost allocation model** places **latency** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Certification and interview preparation x privacy

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Failure lab: cost anomaly** places **privacy** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Atlas golden path x operability

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **operability** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Platform product evidence x data integrity

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **data integrity** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Cost allocation x automation safety

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **automation safety** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Unit economics x governance

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **governance** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Optimization plan x correctness

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **correctness** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Budget and anomaly x capacity

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Budget and anomaly** while a change involving **Optimization portfolio** places **capacity** at risk.
- Plain-language question: What problem does **Budget and anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and anomaly** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Acceptance x cost efficiency

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Acceptance** while a change involving **Certification and interview preparation** places **cost efficiency** at risk.
- Plain-language question: What problem does **Acceptance** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Atlas platform product x recovery

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas platform product** while a change involving **Acceptance** places **recovery** at risk.
- Plain-language question: What problem does **Atlas platform product** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas platform product** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Product discovery and outcome x change management

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Product discovery and outcome** while a change involving **Unit economics** places **change management** at risk.
- Plain-language question: What problem does **Product discovery and outcome** solve here, and who notices first when it fails?
- Lesson evidence anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Product discovery and outcome** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Golden-path workflow x dependency failure

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Golden-path workflow** while a change involving **Realized-savings evidence** places **dependency failure** at risk.
- Plain-language question: What problem does **Golden-path workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Golden-path workflow** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Platform security and tenancy x developer experience

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform security and tenancy** while a change involving **Optimization plan** places **developer experience** at risk.
- Plain-language question: What problem does **Platform security and tenancy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform security and tenancy** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - Platform SLO and lifecycle x availability

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform SLO and lifecycle** while a change involving **Cost allocation model** places **availability** at risk.
- Plain-language question: What problem does **Platform SLO and lifecycle** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform SLO and lifecycle** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Cost allocation model x security

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation model** while a change involving **Failure lab: budget and policy abuse** places **security** at risk.
- Plain-language question: What problem does **Cost allocation model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation model** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Unit economics x delivery safety

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Cost allocation** places **delivery safety** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Budget and forecast x multi-tenancy

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Budget and forecast** while a change involving **Golden-path workflow** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Budget and forecast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and forecast** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Optimization portfolio x observability

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization portfolio** while a change involving **Real hands-on: self-service service** places **observability** at risk.
- Plain-language question: What problem does **Optimization portfolio** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization portfolio** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Real hands-on: self-service service x regional resilience

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Real hands-on: self-service service** while a change involving **Atlas golden path** places **regional resilience** at risk.
- Plain-language question: What problem does **Real hands-on: self-service service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: self-service service** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Failure lab: provider partial failure x business value

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: provider partial failure** while a change involving **Atlas platform product** places **business value** at risk.
- Plain-language question: What problem does **Failure lab: provider partial failure** solve here, and who notices first when it fails?
- Lesson evidence anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: provider partial failure** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Failure lab: budget and policy abuse x latency

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: budget and policy abuse** while a change involving **Budget and forecast** places **latency** at risk.
- Plain-language question: What problem does **Failure lab: budget and policy abuse** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: budget and policy abuse** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Failure lab: cost anomaly x privacy

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: cost anomaly** while a change involving **Acceptance checklist** places **privacy** at risk.
- Plain-language question: What problem does **Failure lab: cost anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: cost anomaly** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Realized-savings evidence x operability

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Realized-savings evidence** while a change involving **Budget and anomaly** places **operability** at risk.
- Plain-language question: What problem does **Realized-savings evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Realized-savings evidence** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - Acceptance checklist x data integrity

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Cost allocation model** places **data integrity** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - Certification and interview preparation x automation safety

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Failure lab: cost anomaly** places **automation safety** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - Atlas golden path x governance

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **governance** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - Platform product evidence x correctness

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **correctness** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - Cost allocation x capacity

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **capacity** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Unit economics x cost efficiency

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **cost efficiency** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Optimization plan x recovery

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **recovery** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Budget and anomaly x change management

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Budget and anomaly** while a change involving **Optimization portfolio** places **change management** at risk.
- Plain-language question: What problem does **Budget and anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and anomaly** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Acceptance x dependency failure

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Acceptance** while a change involving **Certification and interview preparation** places **dependency failure** at risk.
- Plain-language question: What problem does **Acceptance** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Atlas platform product x developer experience

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Atlas platform product** while a change involving **Acceptance** places **developer experience** at risk.
- Plain-language question: What problem does **Atlas platform product** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas platform product** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Product discovery and outcome x availability

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Product discovery and outcome** while a change involving **Unit economics** places **availability** at risk.
- Plain-language question: What problem does **Product discovery and outcome** solve here, and who notices first when it fails?
- Lesson evidence anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Product discovery and outcome** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Golden-path workflow x security

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Golden-path workflow** while a change involving **Realized-savings evidence** places **security** at risk.
- Plain-language question: What problem does **Golden-path workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Golden-path workflow** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - Platform security and tenancy x delivery safety

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform security and tenancy** while a change involving **Optimization plan** places **delivery safety** at risk.
- Plain-language question: What problem does **Platform security and tenancy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform security and tenancy** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Platform SLO and lifecycle x multi-tenancy

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform SLO and lifecycle** while a change involving **Cost allocation model** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Platform SLO and lifecycle** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform SLO and lifecycle** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Cost allocation model x observability

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Cost allocation model** while a change involving **Failure lab: budget and policy abuse** places **observability** at risk.
- Plain-language question: What problem does **Cost allocation model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation model** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - Unit economics x regional resilience

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Unit economics** while a change involving **Cost allocation** places **regional resilience** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Budget and forecast x business value

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Budget and forecast** while a change involving **Golden-path workflow** places **business value** at risk.
- Plain-language question: What problem does **Budget and forecast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and forecast** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Optimization portfolio x latency

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Optimization portfolio** while a change involving **Real hands-on: self-service service** places **latency** at risk.
- Plain-language question: What problem does **Optimization portfolio** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization portfolio** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Real hands-on: self-service service x privacy

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Real hands-on: self-service service** while a change involving **Atlas golden path** places **privacy** at risk.
- Plain-language question: What problem does **Real hands-on: self-service service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: self-service service** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - Failure lab: provider partial failure x operability

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: provider partial failure** while a change involving **Atlas platform product** places **operability** at risk.
- Plain-language question: What problem does **Failure lab: provider partial failure** solve here, and who notices first when it fails?
- Lesson evidence anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: provider partial failure** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - Failure lab: budget and policy abuse x data integrity

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: budget and policy abuse** while a change involving **Budget and forecast** places **data integrity** at risk.
- Plain-language question: What problem does **Failure lab: budget and policy abuse** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: budget and policy abuse** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Failure lab: cost anomaly x automation safety

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: cost anomaly** while a change involving **Acceptance checklist** places **automation safety** at risk.
- Plain-language question: What problem does **Failure lab: cost anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: cost anomaly** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Realized-savings evidence x governance

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Realized-savings evidence** while a change involving **Budget and anomaly** places **governance** at risk.
- Plain-language question: What problem does **Realized-savings evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Realized-savings evidence** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - Acceptance checklist x correctness

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Cost allocation model** places **correctness** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Certification and interview preparation x capacity

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Failure lab: cost anomaly** places **capacity** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Atlas golden path x cost efficiency

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Platform product evidence x recovery

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **recovery** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - Cost allocation x change management

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **change management** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Unit economics x dependency failure

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **dependency failure** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - Optimization plan x developer experience

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **developer experience** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Budget and anomaly x availability

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Budget and anomaly** while a change involving **Optimization portfolio** places **availability** at risk.
- Plain-language question: What problem does **Budget and anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create budget, 12-month forecast with launch/growth scenarios, and anomaly routing enriched with service owner, usage driver, recent change, cost delta, and safe action. Include commitment utilization/coverage and expiration.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and anomaly** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 099 - Acceptance x security

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Acceptance** while a change involving **Certification and interview preparation** places **security** at risk.
- Plain-language question: What problem does **Acceptance** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ New service reaches dev through self-service □ Fleet upgrade path exists □ Cost allocation is reconciled and owned □ Unit cost supports a business decision □ Optimization preserves SLO/security/DR □ Estimated and realized savings are separate
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 100 - Atlas platform product x delivery safety

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas platform product** while a change involving **Acceptance** places **delivery safety** at risk.
- Plain-language question: What problem does **Atlas platform product** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PavedRoad capability lets a team request: Application - repository/catalog/docs/delivery/runtime intent Environment - preview/dev/prod class with lifecycle Database - approved capacity/recovery/data class Observability - telemetry/SLO/dashboard/alert ba...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas platform product** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 101 - Product discovery and outcome x multi-tenancy

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Product discovery and outcome** while a change involving **Unit economics** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Product discovery and outcome** solve here, and who notices first when it fails?
- Lesson evidence anchor: Baseline one developer journey and target: before: 10 days, 12 tickets, missing owner/SLO/secret policy target: production-ready lab service <1 day, 90% task completion without privileged ticket, all readiness checks evidenced,
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Product discovery and outcome** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 102 - Golden-path workflow x observability

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Golden-path workflow** while a change involving **Realized-savings evidence** places **observability** at risk.
- Plain-language question: What problem does **Golden-path workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: validate owner/tier/data/budget - create repository and catalog/TechDocs - add reusable secure CI - create GitOps environment config - provision database/identity/secret references - onboard observability/SLO/runbook - deploy synthetic service
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Golden-path workflow** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 103 - Platform security and tenancy x regional resilience

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform security and tenancy** while a change involving **Optimization plan** places **regional resilience** at risk.
- Plain-language question: What problem does **Platform security and tenancy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use server-side authorization, team ownership, least-privilege workload/CI/platform identities, Kubernetes tenant baseline, resource quota, network policy, policy-as-code, secret references, audit, and expiring exceptions.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform security and tenancy** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 104 - Platform SLO and lifecycle x business value

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Platform SLO and lifecycle** while a change involving **Cost allocation model** places **business value** at risk.
- Plain-language question: What problem does **Platform SLO and lifecycle** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure bootstrap/provision/deploy success and duration, status freshness, policy decision, reconciliation, support, upgrades, deletion completeness, and running-workload independence. Maintain template/API version, consumer inventory, canary compatibility...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform SLO and lifecycle** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 105 - Cost allocation model x latency

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Cost allocation model** while a change involving **Failure lab: budget and policy abuse** places **latency** at risk.
- Plain-language question: What problem does **Cost allocation model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Reconcile Atlas cloud cost: direct service resources + EKS nodes allocated by request/usage policy + storage/load balancer/network/observability direct drivers + shared platform/security/support policy + explicit idle and unknown
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation model** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 106 - Unit economics x privacy

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Unit economics** while a change involving **Cost allocation** places **privacy** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: unit = 1,000 authoritative successful Atlas orders unit cost = fully loaded attributable technology cost / order units Version numerator/denominator, deduplicate retries, include fixed/variable/shared, compare region/feature cohorts, and pair with checkout...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 107 - Budget and forecast x operability

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Budget and forecast** while a change involving **Golden-path workflow** places **operability** at risk.
- Plain-language question: What problem does **Budget and forecast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create base/upside/downside forecast from order/user volume, compute/order, data/retention, network/region, observability, planned platform/DR, and rate portfolio. Show budget, actual, data completeness, variance, and decisions.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Budget and forecast** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 108 - Optimization portfolio x data integrity

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization portfolio** while a change involving **Real hands-on: self-service service** places **data integrity** at risk.
- Plain-language question: What problem does **Optimization portfolio** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required hypotheses: Kubernetes request/bin packing/node classes/Spot preview TTL/scheduling and orphan cleanup database query/index/capacity storage/backup lifecycle telemetry cardinality/volume/retention/sampling network/CDN/cross-zone/region path
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization portfolio** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 109 - Real hands-on: self-service service x automation safety

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Real hands-on: self-service service** while a change involving **Atlas golden path** places **automation safety** at risk.
- Plain-language question: What problem does **Real hands-on: self-service service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask a developer unfamiliar with the platform to create recommendation-api, preview it, inspect telemetry/cost, promote or stop at policy, update template, and delete preview. Record task time, errors, help, partial failure, readiness, and orphans.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: self-service service** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 110 - Failure lab: provider partial failure x governance

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: provider partial failure** while a change involving **Atlas platform product** places **governance** at risk.
- Plain-language question: What problem does **Failure lab: provider partial failure** solve here, and who notices first when it fails?
- Lesson evidence anchor: Fail after database resource but before GitOps registration. Platform shows exact created state/owner/cost, retries safely or compensates under policy, never duplicates, and alerts operator. Running resources remain controlled if portal fails.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: provider partial failure** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 111 - Failure lab: budget and policy abuse x correctness

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Failure lab: budget and policy abuse** while a change involving **Budget and forecast** places **correctness** at risk.
- Plain-language question: What problem does **Failure lab: budget and policy abuse** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt an oversized public production database in an unapproved region under another team. Authorization/policy/quota/cost gate rejects before mutation with remediation and safe audit. Exercise a scoped expiring exception separately.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: budget and policy abuse** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 112 - Failure lab: cost anomaly x capacity

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Failure lab: cost anomaly** while a change involving **Acceptance checklist** places **capacity** at risk.
- Plain-language question: What problem does **Failure lab: cost anomaly** solve here, and who notices first when it fails?
- Lesson evidence anchor: A preview load test produces 20× logs and cross-region database calls. Detect through operational proxies and billing anomaly, identify owner/change, stop safely, repair telemetry/routing, validate SLO/security, reforecast, and measure impact.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure lab: cost anomaly** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 113 - Realized-savings evidence x cost efficiency

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Realized-savings evidence** while a change involving **Budget and anomaly** places **cost efficiency** at risk.
- Plain-language question: What problem does **Realized-savings evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose one optimization and report: normalized baseline at actual comparable demand implemented Git/PR/release post-change cost and unit cost SLO/security/DR guardrails price/volume/mix/allocation adjustments overlap/rebound/migrated cost
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Realized-savings evidence** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 114 - Acceptance checklist x recovery

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Cost allocation model** places **recovery** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 115 - Certification and interview preparation x change management

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Failure lab: cost anomaly** places **change management** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson combines platform-engineering and FinOps objectives. Verify current official frameworks/certification guides before exams. Beginner: How does a platform help FinOps?  Encodes efficient classes/defaults, ownership, quota/TTL, cost metadata, and s...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 116 - Atlas golden path x dependency failure

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Atlas golden path** while a change involving **Unit economics** places **dependency failure** at risk.
- Plain-language question: What problem does **Atlas golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: The internal platform template creates: source repository and ownership service catalog entity and docs CI/SBOM/provenance workflow container and Kubernetes manifests GitOps Application/config workload identity and secret references
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Atlas golden path** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 117 - Platform product evidence x developer experience

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Platform product evidence** while a change involving **Platform security and tenancy** places **developer experience** at risk.
- Plain-language question: What problem does **Platform product evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Measure time to first deploy, provisioning success/duration, adoption, support contacts, upgrade completion, platform SLOs, and satisfaction. Run a new-service onboarding with someone who did not build the platform. Record every manual handoff.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Platform product evidence** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 118 - Cost allocation x availability

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Cost allocation** while a change involving **Failure lab: provider partial failure** places **availability** at risk.
- Plain-language question: What problem does **Cost allocation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Allocate by account, service, owner, environment, cluster/namespace, and cost center. Show direct workload, shared platform, observability, network, idle, support, and commitment costs separately. Preserve unallocated cost as a data-quality signal.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost allocation** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 119 - Unit economics x security

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Unit economics** while a change involving **Platform product evidence** places **security** at risk.
- Plain-language question: What problem does **Unit economics** solve here, and who notices first when it fails?
- Lesson evidence anchor: cost per successful order cost per active tenant platform cost per successful production deployment observability cost per production service Normalize comparisons for traffic, environment, price, seasonality, SLO, and product mix.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Unit economics** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 120 - Optimization plan x delivery safety

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Optimization plan** while a change involving **Product discovery and outcome** places **delivery safety** at risk.
- Plain-language question: What problem does **Optimization plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: eliminate orphan/expired resources schedule safe non-production environments rightsize Kubernetes requests and databases improve bin packing/node mix tier storage/log/trace retention reduce avoidable transfer commit stable eligible baseline
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Optimization plan** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 120.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://www.finops.org/framework/ "FinOps Framework"
[2]: https://backstage.io/docs/features/software-templates/ "Backstage Software Templates"
[3]: https://www.finops.org/framework/capabilities/unit-economics/ "FinOps Unit Economics"
