# Module 20 — Final Mega Capstone Project

## Lesson 8: End-to-end Observability and SLO Evidence

# 20.8.1 Telemetry architecture

```text
applications/exporters → Prometheus
container logs → OTel/log agents → Loki
OTLP traces → OTel gateways → Tempo
all backends → Grafana
SLO/rules → Alertmanager → on-call
```

Use consistent service, environment, cluster, namespace, region, version, and tenant-safe attributes. Put trace IDs in structured logs and link histogram exemplars to traces.

# 20.8.2 Atlas SLOs

```text
order-create availability = good committed outcomes / valid attempts
order-read latency        = valid reads below 300 ms / valid reads
fulfillment freshness     = events processed within 2m / eligible events
payment correctness       = correctly classified outcomes / attempts
```

Specify eligibility, data source, missing data, late events, exclusions, window, target, owner, and error-budget policy. Create multi-window burn alerts and rule tests.

# 20.8.3 Dashboards

```text
executive/user journey: SLO and business throughput
service: RED, dependencies, saturation, versions
Kubernetes: nodes, replicas, restarts, scheduling, storage
delivery: commit → artifact → Argo → Rollout → healthy
telemetry: scrape/export/ingest/query/delivery health
FinOps: spend, units, anomaly, allocation
```

Every page links owner, runbook, change, logs, and traces. Show missing data explicitly.

# 20.8.4 Alert policy

Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence is scoped, owned, linked, and expiring.

# 20.8.5 Data protection

Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.

# 20.8.6 Acceptance journey

Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes in the exercise.

# 20.8.7 Atlas telemetry contract

```text
RESOURCE
service.name, service.version, deployment.environment.name,
k8s.cluster.name, region, owner through governed mapping

METRICS
HTTP RED, dependency outcomes, queue age/depth, order business outcomes,
DB/worker/Kubernetes/telemetry-pipeline saturation

LOGS
structured completion/error, safe event/result/duration, trace/span ID

TRACES
edge/API/DB/inventory/outbox/broker/worker/provider propagation
```

Define allowed attributes and cardinality/privacy budgets.

# 20.8.8 User SLI specifications

Checkout availability:

```text
good = eligible checkout produces one durable authoritative order
valid = authenticated, valid, in-stock synthetic checkout attempt
exclude = explicit load/maintenance markers by policy
window/target = 30d / 99.95% example
source = authoritative server/business events reconciled with edge
missing = invalid coverage alert and policy response
owner = orders team
```

Create similarly exact latency and worker freshness specifications.

# 20.8.9 Instrumentation implementation

Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.

Test duplicate checkout, async context, error status, logs correlation, shutdown flush, and synthetic forbidden fields.

# 20.8.10 Collection architecture

```text
Prometheus HA per cluster/region for metrics/rules
OTel agent/DaemonSet for node/log/local collection
OTel gateway for policy/routing/tail sampling as designed
Loki/Tempo distributed or suitable managed/lab modes
Grafana with provisioned data sources/dashboards/links
Alertmanager HA and independent delivery canary
durable storage/retention per signal
```

Version and observe every component.

# 20.8.11 SLO recording and alerts

Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes.

Route fast/slow burn pages/tickets under error-budget policy with owner, impact, dashboard, runbook, and safe first action.

# 20.8.12 Dashboard hierarchy

```text
Executive/user journey: SLO, budget, traffic, regions, releases
Service: RED, route/version/dependency, saturation
Data/events: DB, outbox, queue age, duplicates, DLQ
Kubernetes: desired/runtime/resource/node/zone
Delivery: artifact/config/Argo/rollout/customer signal
Telemetry platform: targets, queues, rejects/drops, storage/query/page
Cost: signal volume and owner/unit
```

# 20.8.13 Correlation golden path

```text
SLO alert -> service dashboard and release marker
-> histogram exemplar -> Tempo trace
-> critical span -> trace-correlated Loki logs
-> service.version -> artifact digest/config revision/build/source
-> runbook/owner -> mitigation
-> original SLI -> recovery
```

Prove every arrow after a deployment.

# 20.8.14 Real hands-on: controlled slow checkout

Inject 500 ms inventory delay on canary version only. Expected:

```text
latency SLI/burn shows version/route/time
exemplar opens correct trace
inventory span is critical path
log classifies timeout without sensitive payload
release annotation shows digest/config
rollout analysis pauses/aborts
stable traffic restores SLI
```

# 20.8.15 Telemetry failure tests

```text
metrics path missing -> target/coverage alert
Collector exporter blocked -> queue/retry/drop and canary
Loki tenant wrong -> ingestion reject/missing-log path
trace propagation removed -> split traces
cardinality explosion -> limits and source rollback
Grafana unavailable -> rules/pages and low-dependency queries continue
receiver credential invalid -> delivery canary detects
```

# 20.8.16 Data protection

Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenant isolation, TLS, retention/deletion, and audit.

# 20.8.17 Capacity and cost

Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deleting evidence blindly.

# 20.8.18 Acceptance evidence

- SLI specifications and error-budget policy are exact.
- Instrumentation contract tests pass under retries/crash/async.
- Prometheus rules pass syntax and unit tests.
- Logs are structured/redacted with bounded Loki labels.
- Complete cross-service/queue traces and sampling policy work.
- Correlation and deployment links work end to end.
- Pipeline/page failure canaries detect blindness.
- HA/retention/restore/capacity/cost/security are tested.

# 20.8.19 Certification review

Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current official objectives for exact weighting.

# 20.8.20 Interview preparation

**Beginner: Metrics/logs/traces?**  Population measurements, discrete contextual events, and one request's causal path.

**Intermediate: Why exemplars?**  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.

**Intermediate: Why queue age instead of depth only?**  Age maps to freshness/user objective; depth significance varies with processing rate.

**Senior: How do you alert on checkout?**  Exact good/valid authoritative events, multi-window burn/traffic/coverage, owner/runbook, delivery test, and policy.

**Senior: What happens if observability fails?**  Independent canaries and component evidence detect blindness; preserve critical service with bounded queues, alternate signals/queries, and cautious changes.

**Expert: How do you correlate release to incident?**  SLI onset/version, exemplar trace/log context, immutable digest/config/build/source marker, then recovery after authoritative revert/abort.

**Architect: How do you control telemetry at scale?**  Schema/cardinality/privacy contracts, sampling/retention/value tiers, tenant fairness, capacity/cost attribution, pipeline SLO, and safe failure/upgrade tests.

**Never-forget answer:** observe the critical journey, correlate stable safe identity across signals and releases, page on budget symptoms, and prove the telemetry path itself.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 20.8.21 Professional Mastery Workbook

This workbook expands **End-to-end Observability and SLO Evidence** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 20 lesson-specific anchors.
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

### Concept card 1 - Telemetry architecture

- Lesson anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Beginner explanation: Restate **Telemetry architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Telemetry architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Telemetry architecture**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Telemetry architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Telemetry architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Atlas SLOs

- Lesson anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Beginner explanation: Restate **Atlas SLOs** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Atlas SLOs** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Atlas SLOs**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Atlas SLOs**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Atlas SLOs** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Dashboards

- Lesson anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Beginner explanation: Restate **Dashboards** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Dashboards** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Dashboards**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Dashboards**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Dashboards** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Alert policy

- Lesson anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Beginner explanation: Restate **Alert policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Alert policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Alert policy**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Alert policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Alert policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Data protection

- Lesson anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Beginner explanation: Restate **Data protection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Data protection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Data protection**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Data protection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Data protection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Acceptance journey

- Lesson anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Beginner explanation: Restate **Acceptance journey** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Acceptance journey** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Acceptance journey**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Acceptance journey**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Acceptance journey** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Atlas telemetry contract

- Lesson anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Beginner explanation: Restate **Atlas telemetry contract** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Atlas telemetry contract** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Atlas telemetry contract**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Atlas telemetry contract**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Atlas telemetry contract** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - User SLI specifications

- Lesson anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Beginner explanation: Restate **User SLI specifications** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **User SLI specifications** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **User SLI specifications**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **User SLI specifications**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **User SLI specifications** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Instrumentation implementation

- Lesson anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Beginner explanation: Restate **Instrumentation implementation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Instrumentation implementation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Instrumentation implementation**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Instrumentation implementation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Instrumentation implementation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Collection architecture

- Lesson anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Beginner explanation: Restate **Collection architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Collection architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Collection architecture**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Collection architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Collection architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - SLO recording and alerts

- Lesson anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Beginner explanation: Restate **SLO recording and alerts** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SLO recording and alerts** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **SLO recording and alerts**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **SLO recording and alerts**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **SLO recording and alerts** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Dashboard hierarchy

- Lesson anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Beginner explanation: Restate **Dashboard hierarchy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Dashboard hierarchy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Dashboard hierarchy**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Dashboard hierarchy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Dashboard hierarchy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Correlation golden path

- Lesson anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Beginner explanation: Restate **Correlation golden path** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Correlation golden path** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Correlation golden path**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Correlation golden path**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Correlation golden path** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Real hands-on: controlled slow checkout

- Lesson anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Beginner explanation: Restate **Real hands-on: controlled slow checkout** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real hands-on: controlled slow checkout** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Real hands-on: controlled slow checkout**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Real hands-on: controlled slow checkout**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Real hands-on: controlled slow checkout** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Telemetry failure tests

- Lesson anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Beginner explanation: Restate **Telemetry failure tests** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Telemetry failure tests** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Telemetry failure tests**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Telemetry failure tests**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Telemetry failure tests** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Data protection

- Lesson anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Beginner explanation: Restate **Data protection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Data protection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Data protection**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Data protection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Data protection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Capacity and cost

- Lesson anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Beginner explanation: Restate **Capacity and cost** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Capacity and cost** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Capacity and cost**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Capacity and cost**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Capacity and cost** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Acceptance evidence

- Lesson anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Beginner explanation: Restate **Acceptance evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Acceptance evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Acceptance evidence**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Acceptance evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Acceptance evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Certification review

- Lesson anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Beginner explanation: Restate **Certification review** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Certification review** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Certification review**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Certification review**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Certification review** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Interview preparation

- Lesson anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Beginner explanation: Restate **Interview preparation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview preparation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Interview preparation**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Interview preparation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Interview preparation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Telemetry architecture x operability

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Atlas SLOs x data integrity

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Dashboards x automation safety

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Alert policy x governance

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Data protection x correctness

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Acceptance journey x capacity

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Atlas telemetry contract x cost efficiency

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - User SLI specifications x recovery

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Instrumentation implementation x change management

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Collection architecture x dependency failure

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - SLO recording and alerts x developer experience

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Dashboard hierarchy x availability

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Correlation golden path x security

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Telemetry failure tests x multi-tenancy

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Data protection x observability

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Capacity and cost x regional resilience

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Acceptance evidence x business value

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Certification review x latency

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Interview preparation x privacy

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Telemetry architecture x operability

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Atlas SLOs x data integrity

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Dashboards x automation safety

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Alert policy x governance

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Data protection x correctness

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Acceptance journey x capacity

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Atlas telemetry contract x cost efficiency

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - User SLI specifications x recovery

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Instrumentation implementation x change management

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Collection architecture x dependency failure

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - SLO recording and alerts x developer experience

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Dashboard hierarchy x availability

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Correlation golden path x security

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Telemetry failure tests x multi-tenancy

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Data protection x observability

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Capacity and cost x regional resilience

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Acceptance evidence x business value

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Certification review x latency

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Interview preparation x privacy

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Telemetry architecture x operability

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Atlas SLOs x data integrity

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Dashboards x automation safety

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Alert policy x governance

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Data protection x correctness

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Acceptance journey x capacity

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Atlas telemetry contract x cost efficiency

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - User SLI specifications x recovery

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Instrumentation implementation x change management

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Collection architecture x dependency failure

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - SLO recording and alerts x developer experience

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Dashboard hierarchy x availability

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Correlation golden path x security

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Telemetry failure tests x multi-tenancy

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Data protection x observability

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Capacity and cost x regional resilience

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - Acceptance evidence x business value

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Certification review x latency

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Interview preparation x privacy

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Telemetry architecture x operability

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Atlas SLOs x data integrity

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Dashboards x automation safety

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Alert policy x governance

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Data protection x correctness

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Acceptance journey x capacity

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Atlas telemetry contract x cost efficiency

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - User SLI specifications x recovery

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - Instrumentation implementation x change management

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - Collection architecture x dependency failure

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - SLO recording and alerts x developer experience

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - Dashboard hierarchy x availability

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Correlation golden path x security

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Telemetry failure tests x multi-tenancy

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Data protection x observability

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Capacity and cost x regional resilience

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Acceptance evidence x business value

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Certification review x latency

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - Interview preparation x privacy

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Telemetry architecture x operability

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Atlas SLOs x data integrity

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - Dashboards x automation safety

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Alert policy x governance

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Data protection x correctness

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Acceptance journey x capacity

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - Atlas telemetry contract x cost efficiency

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - User SLI specifications x recovery

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Instrumentation implementation x change management

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Collection architecture x dependency failure

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - SLO recording and alerts x developer experience

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Dashboard hierarchy x availability

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Correlation golden path x security

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - Telemetry failure tests x multi-tenancy

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Data protection x observability

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - Capacity and cost x regional resilience

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Acceptance evidence x business value

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 099 - Certification review x latency

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 100 - Interview preparation x privacy

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 101 - Telemetry architecture x operability

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 102 - Atlas SLOs x data integrity

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 103 - Dashboards x automation safety

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 104 - Alert policy x governance

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Alert policy** while a change involving **Data protection** places **governance** at risk.
- Plain-language question: What problem does **Alert policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Page for severe burn, correctness threat, imminent data/capacity loss, or critical telemetry/pager failure. Route by team and environment. Tickets cover slow burns, capacity planning, backup age, certificate/secret expiry, and cost anomalies. Every silence...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Alert policy** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 105 - Data protection x correctness

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Data protection** while a change involving **Dashboard hierarchy** places **correctness** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not record payment secrets, access tokens, full personal payloads, or raw unbounded IDs as labels. Apply collection redaction, tenant access, TLS, retention, deletion, audit, and data residency. Test secret-like events.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 106 - Acceptance journey x capacity

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance journey** while a change involving **Certification review** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance journey** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from a page, identify affected route/version, open exemplar trace, find failing dependency span, pivot to correlated logs, locate Git change, execute runbook, restore service, and confirm SLI/error-budget recovery. Target completion: under 15 minutes...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance journey** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 107 - Atlas telemetry contract x cost efficiency

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Atlas telemetry contract** while a change involving **Acceptance journey** places **cost efficiency** at risk.
- Plain-language question: What problem does **Atlas telemetry contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: RESOURCE service.name, service.version, deployment.environment.name, k8s.cluster.name, region, owner through governed mapping METRICS HTTP RED, dependency outcomes, queue age/depth, order business outcomes, DB/worker/Kubernetes/telemetry-pipeline saturation
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas telemetry contract** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 108 - User SLI specifications x recovery

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **User SLI specifications** while a change involving **Correlation golden path** places **recovery** at risk.
- Plain-language question: What problem does **User SLI specifications** solve here, and who notices first when it fails?
- Lesson evidence anchor: Checkout availability: good = eligible checkout produces one durable authoritative order valid = authenticated, valid, in-stock synthetic checkout attempt exclude = explicit load/maintenance markers by policy window/target = 30d / 99.95% example
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **User SLI specifications** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 109 - Instrumentation implementation x change management

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Instrumentation implementation** while a change involving **Interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Instrumentation implementation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use language SDK/auto-instrumentation plus manual business spans/metrics. Propagate W3C context through HTTP and approved message metadata. Count authoritative order success only after commit; attempts/retries separately.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Instrumentation implementation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 110 - Collection architecture x dependency failure

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Collection architecture** while a change involving **Atlas telemetry contract** places **dependency failure** at risk.
- Plain-language question: What problem does **Collection architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus HA per cluster/region for metrics/rules OTel agent/DaemonSet for node/log/local collection OTel gateway for policy/routing/tail sampling as designed Loki/Tempo distributed or suitable managed/lab modes Grafana with provisioned data sources/dashbo...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Collection architecture** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 111 - SLO recording and alerts x developer experience

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **SLO recording and alerts** while a change involving **Real hands-on: controlled slow checkout** places **developer experience** at risk.
- Plain-language question: What problem does **SLO recording and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create recording rules for valid/bad rates, ratios, burn, coverage, and enough traffic. Unit-test no traffic, high burst, slow burn, scrape missing, counter reset, and label/version changes. Route fast/slow burn pages/tickets under error-budget policy with...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **SLO recording and alerts** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 112 - Dashboard hierarchy x availability

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Dashboard hierarchy** while a change involving **Telemetry architecture** places **availability** at risk.
- Plain-language question: What problem does **Dashboard hierarchy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Executive/user journey: SLO, budget, traffic, regions, releases Service: RED, route/version/dependency, saturation Data/events: DB, outbox, queue age, duplicates, DLQ Kubernetes: desired/runtime/resource/node/zone Delivery: artifact/config/Argo/rollout/cust...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboard hierarchy** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 113 - Correlation golden path x security

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Correlation golden path** while a change involving **User SLI specifications** places **security** at risk.
- Plain-language question: What problem does **Correlation golden path** solve here, and who notices first when it fails?
- Lesson evidence anchor: SLO alert - service dashboard and release marker - histogram exemplar - Tempo trace - critical span - trace-correlated Loki logs - service.version - artifact digest/config revision/build/source - runbook/owner - mitigation
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Correlation golden path** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 114 - Real hands-on: controlled slow checkout x delivery safety

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: controlled slow checkout** while a change involving **Telemetry failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on: controlled slow checkout** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject 500 ms inventory delay on canary version only. Expected: latency SLI/burn shows version/route/time exemplar opens correct trace inventory span is critical path log classifies timeout without sensitive payload release annotation shows digest/config
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Real hands-on: controlled slow checkout** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 115 - Telemetry failure tests x multi-tenancy

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry failure tests** while a change involving **Atlas SLOs** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Telemetry failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: metrics path missing - target/coverage alert Collector exporter blocked - queue/retry/drop and canary Loki tenant wrong - ingestion reject/missing-log path trace propagation removed - split traces cardinality explosion - limits and source rollback
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 116 - Data protection x observability

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Data protection** while a change involving **Instrumentation implementation** places **observability** at risk.
- Plain-language question: What problem does **Data protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use synthetic secret leakage tests across application, Collector debug, Loki, Tempo, Prometheus labels, dashboard variables, alert annotations, and CI artifacts. Apply source minimization, pipeline redaction, least-privilege data-source/folder access, tenan...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Data protection** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 117 - Capacity and cost x regional resilience

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Capacity and cost** while a change involving **Data protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Capacity and cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Calculate active metric series/samples, log bytes/streams, trace spans/sampling, queue outage buffers, retention/storage, query concurrency, and cost per service/environment. Load test 2× peak and backlog recovery. Use signal value tiers rather than deletin...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Capacity and cost** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 118 - Acceptance evidence x business value

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance evidence** while a change involving **Dashboards** places **business value** at risk.
- Plain-language question: What problem does **Acceptance evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance evidence as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Acceptance evidence** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 119 - Certification review x latency

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification review** while a change involving **Collection architecture** places **latency** at risk.
- Plain-language question: What problem does **Certification review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Map evidence to current Prometheus and OpenTelemetry certification objectives: concepts/signals, data model/PromQL, instrumentation/exporters, alerts/dashboards, API/SDK/context, Collector components/pipelines/deployment, security/debugging. Use current off...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Certification review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 120 - Interview preparation x privacy

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Interview preparation** while a change involving **Capacity and cost** places **privacy** at risk.
- Plain-language question: What problem does **Interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: Metrics/logs/traces?  Population measurements, discrete contextual events, and one request's causal path. Intermediate: Why exemplars?  Link selected metric observations to traces without trace ID as a normal high-cardinality metric label.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 121 - Telemetry architecture x operability

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Telemetry architecture** while a change involving **Alert policy** places **operability** at risk.
- Plain-language question: What problem does **Telemetry architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters → Prometheus container logs → OTel/log agents → Loki OTLP traces → OTel gateways → Tempo all backends → Grafana SLO/rules → Alertmanager → on-call Use consistent service, environment, cluster, namespace, region, version, and tenant-sa...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an idempotency, outbox, migration, and data-integrity report and link it to this practice case ID.
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
- Interview prompt: Defend **Telemetry architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 122 - Atlas SLOs x data integrity

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Atlas SLOs** while a change involving **SLO recording and alerts** places **data integrity** at risk.
- Plain-language question: What problem does **Atlas SLOs** solve here, and who notices first when it fails?
- Lesson evidence anchor: order-create availability = good committed outcomes / valid attempts order-read latency        = valid reads below 300 ms / valid reads fulfillment freshness     = events processed within 2m / eligible events payment correctness       = correctly classified...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an SLO investigation, incident, restore, and game-day report and link it to this practice case ID.
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
- Interview prompt: Defend **Atlas SLOs** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 123 - Dashboards x automation safety

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Dashboards** while a change involving **Acceptance evidence** places **automation safety** at risk.
- Plain-language question: What problem does **Dashboards** solve here, and who notices first when it fails?
- Lesson evidence anchor: executive/user journey: SLO and business throughput service: RED, dependencies, saturation, versions Kubernetes: nodes, replicas, restarts, scheduling, storage delivery: commit → artifact → Argo → Rollout → healthy telemetry: scrape/export/ingest/query/deli...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a traceable requirement, ADR, implementation, and test record and link it to this practice case ID.
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
- Interview prompt: Defend **Dashboards** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 123.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://opentelemetry.io/docs/concepts/observability-primer/ "OpenTelemetry Observability Primer"
[2]: https://sre.google/workbook/alerting-on-slos/ "Alerting on SLOs"
[3]: https://prometheus.io/docs/practices/instrumentation/ "Prometheus Instrumentation Practices"
