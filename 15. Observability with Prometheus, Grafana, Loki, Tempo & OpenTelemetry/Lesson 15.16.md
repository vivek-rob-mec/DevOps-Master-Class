# Module 15 — Observability

## Lesson 16: Troubleshooting the Observability Stack

# 15.16.1 Work the pipeline

```text
instrumentation → endpoint/exporter → discovery/network
→ collector/ingestion → storage/index → query → visualization/alert
```

State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts erase evidence and rarely repair schema or configuration.

# 15.16.2 Prometheus workflow

```bash
curl -fsS http://application:PORT/metrics | head
promtool check config prometheus.yml
promtool check rules rules.yml
curl -fsS http://prometheus:9090/-/ready
```

Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sample rejection, TSDB/storage, rule evaluation, and query labels. `up == 0` means scrape failure; no `up` series often means discovery or relabeling.

# 15.16.3 Logs and traces

For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collector queue/export errors, tenant, clock, and query scope.

# 15.16.4 Grafana and alerts

Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:

```text
rule state → alert sent → Alertmanager route → receiver attempt → provider result
```

# 15.16.5 Incident lab

Inject five defects:

1. ServiceMonitor label mismatch.
2. Invalid PromQL recording rule.
3. Loki tenant mismatch.
4. OTLP gRPC/HTTP protocol mismatch.
5. Alert route captured by an earlier branch.

For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.

# 15.16.6 Evidence checklist

```text
configuration revision
component version
health/ready endpoints
queue/drop/retry counters
storage status
target/discovery state
exact query and time window
recent deployment/event timeline
```

# 15.16.7 Beginner method: symptom, scope, time, change

Before touching a component, write four facts:

```text
symptom: exact missing/wrong/slow behavior
scope: service, signal, cluster, tenant, users
time: first observed and last known good in UTC
change: deployment, config, credential, topology, load
```

“Grafana is broken” is not a useful symptom. “The `todo-api` request-rate panel is empty in production since 10:05 UTC, while direct application requests succeed” is testable.

# 15.16.8 Preserve evidence before restarting

A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture:

- pod/container state, exit code, restart reason, and events;
- current and previous logs;
- effective configuration/version/checksum;
- queue, drop, reject, retry, and storage metrics;
- DNS/network/TLS/auth errors;
- the exact failing query and response;
- rollout/change timeline.

Restart only when it is an intentional mitigation or diagnostic step with an expected result.

# 15.16.9 Prometheus: absent target versus failed target

These are different branches:

```text
No target/series
  -> discovery object absent?
  -> selectors/namespace policy mismatch?
  -> relabel rule dropped it?
  -> wrong Prometheus instance/tenant?

Target exists but up == 0
  -> DNS/routing/network policy?
  -> wrong port/path/protocol?
  -> TLS/auth failure?
  -> timeout or invalid exposition?
```

Inspect the **discovered labels** before relabeling and final target labels afterward. A ServiceMonitor can exist and still be ignored because the Prometheus custom resource selects different labels.

# 15.16.10 Prometheus: data exists but query is wrong

Work from raw to derived:

```promql
up
up{job="todo-api"}
http_server_requests_total{job="todo-api"}
rate(http_server_requests_total{job="todo-api"}[5m])
sum by (route) (rate(http_server_requests_total{job="todo-api"}[5m]))
```

Check label spelling/value, range-window length, counter resets, vector matching, staleness, recording-rule output, evaluation interval, time range, and whether a deployment renamed the metric. Use the HTTP API or Prometheus expression browser to remove Grafana from the path.

# 15.16.11 Prometheus: rejected samples and storage

Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status, and recent version/storage changes.

Do not delete TSDB/WAL directories as a first response. Preserve evidence and follow the official recovery guidance for the exact failure; destructive recovery may permanently remove data.

# 15.16.12 Alert debugging from expression to provider

Follow one alert instance:

```text
expression produces expected vector
-> pending duration completes
-> rule state becomes firing
-> labels/annotations render correctly
-> Prometheus sends to every intended Alertmanager
-> route matcher selects intended receiver
-> inhibition/silence does not suppress unexpectedly
-> integration returns success
-> provider/account/device actually delivers
```

Use a controlled synthetic alert and receiver. Never create a real urgent page without an agreed test window and clear “TEST” labeling.

# 15.16.13 Loki missing-log decision tree

```text
Application emitted line?
├─ no: application logging/configuration
└─ yes
   Node file contains line?
   ├─ no: runtime/path/rotation
   └─ yes
      Collector read/checkpoint advanced?
      ├─ no: discovery/permissions/parser
      └─ yes
         Export accepted?
         ├─ no: queue/auth/TLS/limit/tenant/timestamp
         └─ yes
            Stored/queryable?
            ├─ no: ingester/object store/retention
            └─ yes: labels, parser, time range, UI
```

Use one synthetic line with timestamp, service, and unique safe marker. A generic search for `error` cannot prove a particular pipeline stage.

# 15.16.14 LogQL troubleshooting

Begin only with stream labels:

```logql
{cluster="prod", app="todo-api"}
```

Then add an exact substring, parser, and field condition one at a time. Inspect `__error__` after parsing or `unwrap`. Confirm tenant identity, label names through the backend, time zone, ingestion delay, and retention. Expensive regex and broad range should come last, if at all.

# 15.16.15 Missing/partial trace decision tree

```text
SDK/provider initialized?
-> operation instrumented and sampler retained it?
-> context injected/extracted at every boundary?
-> batch processor flushed?
-> correct OTLP protocol/endpoint/TLS/auth?
-> Collector receiver accepted it?
-> processor filtered/tail-sampled it?
-> exporter/backend accepted it?
-> correct tenant/time/search attributes?
```

A downstream trace with a different trace ID suggests propagation failure. A trace missing its last spans may suggest exporter/shutdown, late spans, or partial delivery. A completely absent trace can be intentional sampling.

# 15.16.16 Collector troubleshooting

Validate layers in order:

```text
binary contains configured components
configuration parses
component referenced by service pipeline
receiver binds expected interface/port
client and receiver protocol match
processors behave on synthetic data
sending queue/retry remain within budget
exporter authenticates and backend accepts
```

Temporarily use a debug exporter only in a safe environment with synthetic telemetry. Do not expose production payloads merely to simplify diagnosis.

# 15.16.17 Grafana: isolate presentation from data

Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect:

```text
template variable expansion
transformations and field overrides
instant versus range mode
minimum interval/step
null and unit handling
time shift/time zone
folder/data-source permissions
provisioned UID or dashboard migration
```

If the data source query fails, stop editing panel colors and troubleshoot the backend path.

# 15.16.18 Real hands-on fault lab

Create a disposable environment and inject one defect at a time:

| Defect | Expected primary symptom | Correct boundary |
|---|---|---|
| ServiceMonitor selector mismatch | target absent | discovery/selection |
| Wrong metrics path | target present, scrape 404 | endpoint configuration |
| Invalid rule expression | rule validation/load error | rules |
| Loki wrong tenant | export reject or empty tenant query | identity/ingestion |
| Invalid JSON logs | parser `__error__` | schema/parsing |
| OTLP HTTP to gRPC port | client/protocol error | transport |
| Removed trace propagation | split traces | service boundary |
| Alert route order error | wrong receiver/no intended delivery | routing |
| Grafana variable wrong | only panel empty | presentation/query rendering |

For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.

# 15.16.19 Incident worksheet

```markdown
## User impact and urgency
## Exact symptom, scope, and UTC window
## Last known good and recent changes
## Pipeline boundary currently suspected
## Evidence supporting/refuting hypothesis
## Safe mitigation and expected signal
## Authoritative fix
## End-to-end recovery proof
## Data gap/duplicate assessment
## Follow-up prevention/test/runbook change
```

Record falsified hypotheses too. They prevent the next responder from repeating dead ends.

# 15.16.20 Low-dependency emergency access

Prepare paths that do not all depend on Grafana and the same SSO/network layer:

```text
read-only backend/API access with audited emergency procedure
kubectl/API access to component health and logs
promtool and config validation in a trusted toolbox
notification provider delivery/status view
Git history for dashboards, rules, and Collector config
offline architecture and recovery runbooks
```

Emergency access must still be controlled, time-bounded where possible, audited, and regularly tested.

# 15.16.21 Troubleshooting anti-patterns

- Restart everything and destroy evidence.
- Change several layers simultaneously.
- Widen network access to `0.0.0.0/0` as a permanent “fix.”
- Disable TLS or authentication without a controlled lab boundary.
- Raise cardinality/ingestion/query limits before identifying the source.
- Delete storage or checkpoints without backup and exact target verification.
- Trust the dashboard title instead of the rendered query.
- Treat absent sampled traces as automatic pipeline loss.
- Validate recovery from pod health rather than the original user signal.

# 15.16.22 Certification and interview preparation

Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries.

**Beginner: Difference between no `up` series and `up == 0`?**  No series usually points to discovery/relabel/query scope; zero means Prometheus has a target but the scrape failed.

**Intermediate: First step when a Grafana panel is empty?**  Capture its rendered query, variables, data source, and time, then run the exact query directly against the backend.

**Intermediate: Logs exist on the node but not Loki?**  Check collector discovery/checkpoint/parser, queue/export response, tenant/limits/timestamp, backend storage, then query labels/time.

**Senior: Why might a trace be partial?**  Propagation, per-service sampling, late spans, exporter queue/shutdown, filtering, trace routing, or backend ingestion may affect only part of the trace.

**Senior: Why not restart first?**  It can erase transient evidence and queue/checkpoint state; capture evidence and have an expected diagnostic or mitigation outcome.

**Expert: How do you distinguish silent telemetry loss?**  Reconcile a safe end-to-end canary with component accepted/sent/rejected/dropped counters and backend query freshness.

**Architect: What is a resilient diagnostic plane?**  Controlled low-dependency access to APIs, config, runtime evidence, provider status, and runbooks that remains usable when the primary UI or identity path fails.

**Never-forget answer:** name the symptom and walk one signal across one boundary at a time. Preserve evidence, change one authoritative cause, and validate with the original user-facing signal.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 15.16.23 Professional Mastery Workbook

This workbook expands **Troubleshooting the Observability Stack** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 22 lesson-specific anchors.
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

### Concept card 1 - Work the pipeline

- Lesson anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Beginner explanation: Restate **Work the pipeline** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Work the pipeline** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Work the pipeline**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Work the pipeline**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Work the pipeline** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Prometheus workflow

- Lesson anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Beginner explanation: Restate **Prometheus workflow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus workflow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **Prometheus workflow**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **Prometheus workflow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus workflow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Logs and traces

- Lesson anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Beginner explanation: Restate **Logs and traces** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Logs and traces** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Logs and traces**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Logs and traces**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Logs and traces** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Grafana and alerts

- Lesson anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Beginner explanation: Restate **Grafana and alerts** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Grafana and alerts** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Grafana and alerts**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Grafana and alerts**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Grafana and alerts** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Incident lab

- Lesson anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Beginner explanation: Restate **Incident lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Incident lab**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Incident lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Incident lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Evidence checklist

- Lesson anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Beginner explanation: Restate **Evidence checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Evidence checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Evidence checklist**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Evidence checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Evidence checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Beginner method: symptom, scope, time, change

- Lesson anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Beginner explanation: Restate **Beginner method: symptom, scope, time, change** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Beginner method: symptom, scope, time, change** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Beginner method: symptom, scope, time, change**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Beginner method: symptom, scope, time, change**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Beginner method: symptom, scope, time, change** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Preserve evidence before restarting

- Lesson anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Beginner explanation: Restate **Preserve evidence before restarting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Preserve evidence before restarting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **Preserve evidence before restarting**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **Preserve evidence before restarting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Preserve evidence before restarting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Prometheus: absent target versus failed target

- Lesson anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Beginner explanation: Restate **Prometheus: absent target versus failed target** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus: absent target versus failed target** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Prometheus: absent target versus failed target**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Prometheus: absent target versus failed target**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus: absent target versus failed target** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Prometheus: data exists but query is wrong

- Lesson anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Beginner explanation: Restate **Prometheus: data exists but query is wrong** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus: data exists but query is wrong** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Prometheus: data exists but query is wrong**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Prometheus: data exists but query is wrong**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus: data exists but query is wrong** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Prometheus: rejected samples and storage

- Lesson anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Beginner explanation: Restate **Prometheus: rejected samples and storage** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus: rejected samples and storage** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Prometheus: rejected samples and storage**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Prometheus: rejected samples and storage**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus: rejected samples and storage** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Alert debugging from expression to provider

- Lesson anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Beginner explanation: Restate **Alert debugging from expression to provider** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Alert debugging from expression to provider** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Alert debugging from expression to provider**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Alert debugging from expression to provider**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Alert debugging from expression to provider** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Loki missing-log decision tree

- Lesson anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Beginner explanation: Restate **Loki missing-log decision tree** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Loki missing-log decision tree** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Loki missing-log decision tree**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Loki missing-log decision tree**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Loki missing-log decision tree** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - LogQL troubleshooting

- Lesson anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Beginner explanation: Restate **LogQL troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **LogQL troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **LogQL troubleshooting**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **LogQL troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **LogQL troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Missing/partial trace decision tree

- Lesson anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Beginner explanation: Restate **Missing/partial trace decision tree** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Missing/partial trace decision tree** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Missing/partial trace decision tree**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Missing/partial trace decision tree**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Missing/partial trace decision tree** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Collector troubleshooting

- Lesson anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Beginner explanation: Restate **Collector troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Collector troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Collector troubleshooting**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Collector troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Collector troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Grafana: isolate presentation from data

- Lesson anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Beginner explanation: Restate **Grafana: isolate presentation from data** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Grafana: isolate presentation from data** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Grafana: isolate presentation from data**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Grafana: isolate presentation from data**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Grafana: isolate presentation from data** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Real hands-on fault lab

- Lesson anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Beginner explanation: Restate **Real hands-on fault lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real hands-on fault lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Real hands-on fault lab**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Real hands-on fault lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Real hands-on fault lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Incident worksheet

- Lesson anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Beginner explanation: Restate **Incident worksheet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident worksheet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Incident worksheet**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Incident worksheet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Incident worksheet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Low-dependency emergency access

- Lesson anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Beginner explanation: Restate **Low-dependency emergency access** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Low-dependency emergency access** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **Low-dependency emergency access**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **Low-dependency emergency access**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Low-dependency emergency access** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Troubleshooting anti-patterns

- Lesson anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Beginner explanation: Restate **Troubleshooting anti-patterns** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting anti-patterns** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Troubleshooting anti-patterns**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Troubleshooting anti-patterns**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Troubleshooting anti-patterns** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Certification and interview preparation

- Lesson anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Beginner explanation: Restate **Certification and interview preparation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Certification and interview preparation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Certification and interview preparation**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Certification and interview preparation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Certification and interview preparation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Work the pipeline x regional resilience

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **regional resilience** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Prometheus workflow x business value

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **business value** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Logs and traces x latency

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **latency** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Grafana and alerts x privacy

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **privacy** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Incident lab x operability

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **operability** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Evidence checklist x data integrity

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **data integrity** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Beginner method: symptom, scope, time, change x automation safety

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **automation safety** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Preserve evidence before restarting x governance

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **governance** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Prometheus: absent target versus failed target x correctness

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: absent target versus failed target** while a change involving **Collector troubleshooting** places **correctness** at risk.
- Plain-language question: What problem does **Prometheus: absent target versus failed target** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: absent target versus failed target** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Prometheus: data exists but query is wrong x capacity

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus: data exists but query is wrong** while a change involving **Work the pipeline** places **capacity** at risk.
- Plain-language question: What problem does **Prometheus: data exists but query is wrong** solve here, and who notices first when it fails?
- Lesson evidence anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: data exists but query is wrong** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Prometheus: rejected samples and storage x cost efficiency

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: rejected samples and storage** while a change involving **Preserve evidence before restarting** places **cost efficiency** at risk.
- Plain-language question: What problem does **Prometheus: rejected samples and storage** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: rejected samples and storage** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Alert debugging from expression to provider x recovery

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Alert debugging from expression to provider** while a change involving **Missing/partial trace decision tree** places **recovery** at risk.
- Plain-language question: What problem does **Alert debugging from expression to provider** solve here, and who notices first when it fails?
- Lesson evidence anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Alert debugging from expression to provider** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Loki missing-log decision tree x change management

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Loki missing-log decision tree** while a change involving **Certification and interview preparation** places **change management** at risk.
- Plain-language question: What problem does **Loki missing-log decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Loki missing-log decision tree** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - LogQL troubleshooting x dependency failure

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **LogQL troubleshooting** while a change involving **Beginner method: symptom, scope, time, change** places **dependency failure** at risk.
- Plain-language question: What problem does **LogQL troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **LogQL troubleshooting** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Missing/partial trace decision tree x developer experience

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Missing/partial trace decision tree** while a change involving **LogQL troubleshooting** places **developer experience** at risk.
- Plain-language question: What problem does **Missing/partial trace decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Missing/partial trace decision tree** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Collector troubleshooting x availability

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Collector troubleshooting** while a change involving **Troubleshooting anti-patterns** places **availability** at risk.
- Plain-language question: What problem does **Collector troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Collector troubleshooting** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Grafana: isolate presentation from data x security

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Grafana: isolate presentation from data** while a change involving **Evidence checklist** places **security** at risk.
- Plain-language question: What problem does **Grafana: isolate presentation from data** solve here, and who notices first when it fails?
- Lesson evidence anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana: isolate presentation from data** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Real hands-on fault lab x delivery safety

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Real hands-on fault lab** while a change involving **Loki missing-log decision tree** places **delivery safety** at risk.
- Plain-language question: What problem does **Real hands-on fault lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Real hands-on fault lab** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Incident worksheet x multi-tenancy

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident worksheet** while a change involving **Low-dependency emergency access** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Incident worksheet** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident worksheet** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Low-dependency emergency access x observability

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Low-dependency emergency access** while a change involving **Incident lab** places **observability** at risk.
- Plain-language question: What problem does **Low-dependency emergency access** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Low-dependency emergency access** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Troubleshooting anti-patterns x regional resilience

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Troubleshooting anti-patterns** while a change involving **Alert debugging from expression to provider** places **regional resilience** at risk.
- Plain-language question: What problem does **Troubleshooting anti-patterns** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Troubleshooting anti-patterns** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Certification and interview preparation x business value

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Incident worksheet** places **business value** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Work the pipeline x latency

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **latency** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Prometheus workflow x privacy

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **privacy** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Logs and traces x operability

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **operability** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Grafana and alerts x data integrity

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **data integrity** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Incident lab x automation safety

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **automation safety** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Evidence checklist x governance

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **governance** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Beginner method: symptom, scope, time, change x correctness

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **correctness** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Preserve evidence before restarting x capacity

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **capacity** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Prometheus: absent target versus failed target x cost efficiency

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: absent target versus failed target** while a change involving **Collector troubleshooting** places **cost efficiency** at risk.
- Plain-language question: What problem does **Prometheus: absent target versus failed target** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: absent target versus failed target** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Prometheus: data exists but query is wrong x recovery

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus: data exists but query is wrong** while a change involving **Work the pipeline** places **recovery** at risk.
- Plain-language question: What problem does **Prometheus: data exists but query is wrong** solve here, and who notices first when it fails?
- Lesson evidence anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: data exists but query is wrong** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Prometheus: rejected samples and storage x change management

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: rejected samples and storage** while a change involving **Preserve evidence before restarting** places **change management** at risk.
- Plain-language question: What problem does **Prometheus: rejected samples and storage** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: rejected samples and storage** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Alert debugging from expression to provider x dependency failure

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Alert debugging from expression to provider** while a change involving **Missing/partial trace decision tree** places **dependency failure** at risk.
- Plain-language question: What problem does **Alert debugging from expression to provider** solve here, and who notices first when it fails?
- Lesson evidence anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Alert debugging from expression to provider** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Loki missing-log decision tree x developer experience

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Loki missing-log decision tree** while a change involving **Certification and interview preparation** places **developer experience** at risk.
- Plain-language question: What problem does **Loki missing-log decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Loki missing-log decision tree** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - LogQL troubleshooting x availability

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **LogQL troubleshooting** while a change involving **Beginner method: symptom, scope, time, change** places **availability** at risk.
- Plain-language question: What problem does **LogQL troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **LogQL troubleshooting** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Missing/partial trace decision tree x security

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Missing/partial trace decision tree** while a change involving **LogQL troubleshooting** places **security** at risk.
- Plain-language question: What problem does **Missing/partial trace decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Missing/partial trace decision tree** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Collector troubleshooting x delivery safety

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Collector troubleshooting** while a change involving **Troubleshooting anti-patterns** places **delivery safety** at risk.
- Plain-language question: What problem does **Collector troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Collector troubleshooting** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Grafana: isolate presentation from data x multi-tenancy

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Grafana: isolate presentation from data** while a change involving **Evidence checklist** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Grafana: isolate presentation from data** solve here, and who notices first when it fails?
- Lesson evidence anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana: isolate presentation from data** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Real hands-on fault lab x observability

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Real hands-on fault lab** while a change involving **Loki missing-log decision tree** places **observability** at risk.
- Plain-language question: What problem does **Real hands-on fault lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Real hands-on fault lab** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Incident worksheet x regional resilience

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident worksheet** while a change involving **Low-dependency emergency access** places **regional resilience** at risk.
- Plain-language question: What problem does **Incident worksheet** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident worksheet** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Low-dependency emergency access x business value

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Low-dependency emergency access** while a change involving **Incident lab** places **business value** at risk.
- Plain-language question: What problem does **Low-dependency emergency access** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Low-dependency emergency access** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Troubleshooting anti-patterns x latency

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Troubleshooting anti-patterns** while a change involving **Alert debugging from expression to provider** places **latency** at risk.
- Plain-language question: What problem does **Troubleshooting anti-patterns** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Troubleshooting anti-patterns** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Certification and interview preparation x privacy

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Incident worksheet** places **privacy** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Work the pipeline x operability

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **operability** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Prometheus workflow x data integrity

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **data integrity** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Logs and traces x automation safety

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **automation safety** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Grafana and alerts x governance

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **governance** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Incident lab x correctness

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **correctness** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Evidence checklist x capacity

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **capacity** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Beginner method: symptom, scope, time, change x cost efficiency

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **cost efficiency** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Preserve evidence before restarting x recovery

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **recovery** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Prometheus: absent target versus failed target x change management

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: absent target versus failed target** while a change involving **Collector troubleshooting** places **change management** at risk.
- Plain-language question: What problem does **Prometheus: absent target versus failed target** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: absent target versus failed target** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Prometheus: data exists but query is wrong x dependency failure

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus: data exists but query is wrong** while a change involving **Work the pipeline** places **dependency failure** at risk.
- Plain-language question: What problem does **Prometheus: data exists but query is wrong** solve here, and who notices first when it fails?
- Lesson evidence anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: data exists but query is wrong** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Prometheus: rejected samples and storage x developer experience

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: rejected samples and storage** while a change involving **Preserve evidence before restarting** places **developer experience** at risk.
- Plain-language question: What problem does **Prometheus: rejected samples and storage** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: rejected samples and storage** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Alert debugging from expression to provider x availability

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Alert debugging from expression to provider** while a change involving **Missing/partial trace decision tree** places **availability** at risk.
- Plain-language question: What problem does **Alert debugging from expression to provider** solve here, and who notices first when it fails?
- Lesson evidence anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Alert debugging from expression to provider** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Loki missing-log decision tree x security

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Loki missing-log decision tree** while a change involving **Certification and interview preparation** places **security** at risk.
- Plain-language question: What problem does **Loki missing-log decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Loki missing-log decision tree** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - LogQL troubleshooting x delivery safety

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **LogQL troubleshooting** while a change involving **Beginner method: symptom, scope, time, change** places **delivery safety** at risk.
- Plain-language question: What problem does **LogQL troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **LogQL troubleshooting** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Missing/partial trace decision tree x multi-tenancy

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Missing/partial trace decision tree** while a change involving **LogQL troubleshooting** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Missing/partial trace decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Missing/partial trace decision tree** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Collector troubleshooting x observability

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Collector troubleshooting** while a change involving **Troubleshooting anti-patterns** places **observability** at risk.
- Plain-language question: What problem does **Collector troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Collector troubleshooting** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Grafana: isolate presentation from data x regional resilience

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Grafana: isolate presentation from data** while a change involving **Evidence checklist** places **regional resilience** at risk.
- Plain-language question: What problem does **Grafana: isolate presentation from data** solve here, and who notices first when it fails?
- Lesson evidence anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana: isolate presentation from data** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Real hands-on fault lab x business value

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Real hands-on fault lab** while a change involving **Loki missing-log decision tree** places **business value** at risk.
- Plain-language question: What problem does **Real hands-on fault lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Real hands-on fault lab** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Incident worksheet x latency

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident worksheet** while a change involving **Low-dependency emergency access** places **latency** at risk.
- Plain-language question: What problem does **Incident worksheet** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident worksheet** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Low-dependency emergency access x privacy

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Low-dependency emergency access** while a change involving **Incident lab** places **privacy** at risk.
- Plain-language question: What problem does **Low-dependency emergency access** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Low-dependency emergency access** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Troubleshooting anti-patterns x operability

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Troubleshooting anti-patterns** while a change involving **Alert debugging from expression to provider** places **operability** at risk.
- Plain-language question: What problem does **Troubleshooting anti-patterns** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Troubleshooting anti-patterns** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Certification and interview preparation x data integrity

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Incident worksheet** places **data integrity** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Work the pipeline x automation safety

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **automation safety** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - Prometheus workflow x governance

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **governance** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - Logs and traces x correctness

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **correctness** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - Grafana and alerts x capacity

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **capacity** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - Incident lab x cost efficiency

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **cost efficiency** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - Evidence checklist x recovery

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **recovery** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Beginner method: symptom, scope, time, change x change management

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **change management** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Preserve evidence before restarting x dependency failure

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **dependency failure** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Prometheus: absent target versus failed target x developer experience

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: absent target versus failed target** while a change involving **Collector troubleshooting** places **developer experience** at risk.
- Plain-language question: What problem does **Prometheus: absent target versus failed target** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: absent target versus failed target** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Prometheus: data exists but query is wrong x availability

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus: data exists but query is wrong** while a change involving **Work the pipeline** places **availability** at risk.
- Plain-language question: What problem does **Prometheus: data exists but query is wrong** solve here, and who notices first when it fails?
- Lesson evidence anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: data exists but query is wrong** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Prometheus: rejected samples and storage x security

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: rejected samples and storage** while a change involving **Preserve evidence before restarting** places **security** at risk.
- Plain-language question: What problem does **Prometheus: rejected samples and storage** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: rejected samples and storage** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Alert debugging from expression to provider x delivery safety

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Alert debugging from expression to provider** while a change involving **Missing/partial trace decision tree** places **delivery safety** at risk.
- Plain-language question: What problem does **Alert debugging from expression to provider** solve here, and who notices first when it fails?
- Lesson evidence anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Alert debugging from expression to provider** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Loki missing-log decision tree x multi-tenancy

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Loki missing-log decision tree** while a change involving **Certification and interview preparation** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Loki missing-log decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Loki missing-log decision tree** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - LogQL troubleshooting x observability

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **LogQL troubleshooting** while a change involving **Beginner method: symptom, scope, time, change** places **observability** at risk.
- Plain-language question: What problem does **LogQL troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **LogQL troubleshooting** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Missing/partial trace decision tree x regional resilience

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Missing/partial trace decision tree** while a change involving **LogQL troubleshooting** places **regional resilience** at risk.
- Plain-language question: What problem does **Missing/partial trace decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Missing/partial trace decision tree** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Collector troubleshooting x business value

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Collector troubleshooting** while a change involving **Troubleshooting anti-patterns** places **business value** at risk.
- Plain-language question: What problem does **Collector troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Collector troubleshooting** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - Grafana: isolate presentation from data x latency

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Grafana: isolate presentation from data** while a change involving **Evidence checklist** places **latency** at risk.
- Plain-language question: What problem does **Grafana: isolate presentation from data** solve here, and who notices first when it fails?
- Lesson evidence anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana: isolate presentation from data** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Real hands-on fault lab x privacy

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Real hands-on fault lab** while a change involving **Loki missing-log decision tree** places **privacy** at risk.
- Plain-language question: What problem does **Real hands-on fault lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Real hands-on fault lab** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Incident worksheet x operability

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident worksheet** while a change involving **Low-dependency emergency access** places **operability** at risk.
- Plain-language question: What problem does **Incident worksheet** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident worksheet** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Low-dependency emergency access x data integrity

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Low-dependency emergency access** while a change involving **Incident lab** places **data integrity** at risk.
- Plain-language question: What problem does **Low-dependency emergency access** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Low-dependency emergency access** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - Troubleshooting anti-patterns x automation safety

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Troubleshooting anti-patterns** while a change involving **Alert debugging from expression to provider** places **automation safety** at risk.
- Plain-language question: What problem does **Troubleshooting anti-patterns** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Troubleshooting anti-patterns** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - Certification and interview preparation x governance

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Incident worksheet** places **governance** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Work the pipeline x correctness

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **correctness** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Prometheus workflow x capacity

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **capacity** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - Logs and traces x cost efficiency

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **cost efficiency** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Grafana and alerts x recovery

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **recovery** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Incident lab x change management

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **change management** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Evidence checklist x dependency failure

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **dependency failure** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - Beginner method: symptom, scope, time, change x developer experience

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **developer experience** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Preserve evidence before restarting x availability

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **availability** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - Prometheus: absent target versus failed target x security

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: absent target versus failed target** while a change involving **Collector troubleshooting** places **security** at risk.
- Plain-language question: What problem does **Prometheus: absent target versus failed target** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are different branches: No target/series - discovery object absent? - selectors/namespace policy mismatch? - relabel rule dropped it? - wrong Prometheus instance/tenant? Target exists but up == 0 - DNS/routing/network policy?
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: absent target versus failed target** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Prometheus: data exists but query is wrong x delivery safety

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus: data exists but query is wrong** while a change involving **Work the pipeline** places **delivery safety** at risk.
- Plain-language question: What problem does **Prometheus: data exists but query is wrong** solve here, and who notices first when it fails?
- Lesson evidence anchor: Work from raw to derived: up up{job="todo-api"} httpserverrequeststotal{job="todo-api"} rate(httpserverrequeststotal{job="todo-api"}[5m]) sum by (route) (rate(httpserverrequeststotal{job="todo-api"}[5m])) Check label spelling/value, range-window length, cou...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: data exists but query is wrong** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 099 - Prometheus: rejected samples and storage x multi-tenancy

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prometheus: rejected samples and storage** while a change involving **Preserve evidence before restarting** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Prometheus: rejected samples and storage** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ingestion can fail because of duplicate/out-of-order timestamps, invalid labels, excessive sample size, disk full, corrupted blocks, or WAL/TSDB problems. Look at Prometheus's own logs and metrics, filesystem space/inodes, readiness, compaction/WAL status,...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus: rejected samples and storage** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 100 - Alert debugging from expression to provider x observability

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Alert debugging from expression to provider** while a change involving **Missing/partial trace decision tree** places **observability** at risk.
- Plain-language question: What problem does **Alert debugging from expression to provider** solve here, and who notices first when it fails?
- Lesson evidence anchor: Follow one alert instance: expression produces expected vector - pending duration completes - rule state becomes firing - labels/annotations render correctly - Prometheus sends to every intended Alertmanager - route matcher selects intended receiver
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Alert debugging from expression to provider** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 101 - Loki missing-log decision tree x regional resilience

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Loki missing-log decision tree** while a change involving **Certification and interview preparation** places **regional resilience** at risk.
- Plain-language question: What problem does **Loki missing-log decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application emitted line? ├─ no: application logging/configuration └─ yes Node file contains line? ├─ no: runtime/path/rotation └─ yes Collector read/checkpoint advanced? ├─ no: discovery/permissions/parser └─ yes Export accepted?
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Loki missing-log decision tree** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 102 - LogQL troubleshooting x business value

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **LogQL troubleshooting** while a change involving **Beginner method: symptom, scope, time, change** places **business value** at risk.
- Plain-language question: What problem does **LogQL troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Begin only with stream labels: {cluster="prod", app="todo-api"} Then add an exact substring, parser, and field condition one at a time. Inspect error after parsing or unwrap. Confirm tenant identity, label names through the backend, time zone, ingestion del...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **LogQL troubleshooting** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 103 - Missing/partial trace decision tree x latency

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Missing/partial trace decision tree** while a change involving **LogQL troubleshooting** places **latency** at risk.
- Plain-language question: What problem does **Missing/partial trace decision tree** solve here, and who notices first when it fails?
- Lesson evidence anchor: SDK/provider initialized? - operation instrumented and sampler retained it? - context injected/extracted at every boundary? - batch processor flushed? - correct OTLP protocol/endpoint/TLS/auth? - Collector receiver accepted it?
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Missing/partial trace decision tree** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 104 - Collector troubleshooting x privacy

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Collector troubleshooting** while a change involving **Troubleshooting anti-patterns** places **privacy** at risk.
- Plain-language question: What problem does **Collector troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: Validate layers in order: binary contains configured components configuration parses component referenced by service pipeline receiver binds expected interface/port client and receiver protocol match processors behave on synthetic data
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Collector troubleshooting** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 105 - Grafana: isolate presentation from data x operability

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Grafana: isolate presentation from data** while a change involving **Evidence checklist** places **operability** at risk.
- Plain-language question: What problem does **Grafana: isolate presentation from data** solve here, and who notices first when it fails?
- Lesson evidence anchor: Copy the panel's rendered query, variable values, data-source UID, and time range. Run it directly against the data source. If direct query succeeds, inspect: template variable expansion transformations and field overrides
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana: isolate presentation from data** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 106 - Real hands-on fault lab x data integrity

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Real hands-on fault lab** while a change involving **Loki missing-log decision tree** places **data integrity** at risk.
- Plain-language question: What problem does **Real hands-on fault lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable environment and inject one defect at a time: For each defect, limit yourself to three initial commands/checks. This trains discriminating evidence rather than tool wandering.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Real hands-on fault lab** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 107 - Incident worksheet x automation safety

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident worksheet** while a change involving **Low-dependency emergency access** places **automation safety** at risk.
- Plain-language question: What problem does **Incident worksheet** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record falsified hypotheses too. They prevent the next responder from repeating dead ends.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident worksheet** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 108 - Low-dependency emergency access x governance

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Low-dependency emergency access** while a change involving **Incident lab** places **governance** at risk.
- Plain-language question: What problem does **Low-dependency emergency access** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prepare paths that do not all depend on Grafana and the same SSO/network layer: read-only backend/API access with audited emergency procedure kubectl/API access to component health and logs promtool and config validation in a trusted toolbox
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Low-dependency emergency access** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 109 - Troubleshooting anti-patterns x correctness

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Troubleshooting anti-patterns** while a change involving **Alert debugging from expression to provider** places **correctness** at risk.
- Plain-language question: What problem does **Troubleshooting anti-patterns** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Troubleshooting anti-patterns as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Troubleshooting anti-patterns** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 110 - Certification and interview preparation x capacity

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Incident worksheet** places **capacity** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Troubleshooting appears throughout Prometheus, OpenTelemetry, Kubernetes, and cloud observability assessment. Exact tools change; the durable skill is following evidence across boundaries. Beginner: Difference between no up series and up == 0?  No series us...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 111 - Work the pipeline x cost efficiency

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Work the pipeline** while a change involving **Grafana and alerts** places **cost efficiency** at risk.
- Plain-language question: What problem does **Work the pipeline** solve here, and who notices first when it fails?
- Lesson evidence anchor: instrumentation → endpoint/exporter → discovery/network → collector/ingestion → storage/index → query → visualization/alert State the missing or incorrect signal, scope, start time, and last known good change. Inspect each boundary once. Random restarts era...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Work the pipeline** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 112 - Prometheus workflow x recovery

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prometheus workflow** while a change involving **Prometheus: rejected samples and storage** places **recovery** at risk.
- Plain-language question: What problem does **Prometheus workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://application:PORT/metrics | head promtool check config prometheus.yml promtool check rules rules.yml curl -fsS http://prometheus:9090/-/ready Then inspect service discovery, target labels, scrape error, network policy, TLS/authentication, sa...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Prometheus workflow** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 113 - Logs and traces x change management

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Logs and traces** while a change involving **Real hands-on fault lab** places **change management** at risk.
- Plain-language question: What problem does **Logs and traces** solve here, and who notices first when it fails?
- Lesson evidence anchor: For missing logs: verify source output, file path, checkpoint, receiver, parse errors, filters, queue, exporter, tenant, labels, time range, and retention. For missing traces: verify SDK enabled, sampler, context propagation, OTLP endpoint/protocol, Collect...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make the notification receiver reject a synthetic test.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Logs and traces** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 114 - Grafana and alerts x dependency failure

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Grafana and alerts** while a change involving **Logs and traces** places **dependency failure** at risk.
- Plain-language question: What problem does **Grafana and alerts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Separate dashboard failure from backend failure. Execute the exact query in the data source. Check variable expansion, time zone/range, null handling, permissions, datasource UID, and query limits. For notifications, follow:
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: delay storage or query availability.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Grafana and alerts** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 115 - Incident lab x developer experience

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Incident lab** while a change involving **Prometheus: data exists but query is wrong** places **developer experience** at risk.
- Plain-language question: What problem does **Incident lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inject five defects: For each, write symptom, evidence, failing boundary, authoritative fix, and validation. Build a runbook that works without UI access.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove trace-context propagation at one boundary.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Incident lab** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 116 - Evidence checklist x availability

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Evidence checklist** while a change involving **Grafana: isolate presentation from data** places **availability** at risk.
- Plain-language question: What problem does **Evidence checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: configuration revision component version health/ready endpoints queue/drop/retry counters storage status target/discovery state exact query and time window recent deployment/event timeline
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce malformed or high-cardinality telemetry.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Evidence checklist** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 117 - Beginner method: symptom, scope, time, change x security

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Beginner method: symptom, scope, time, change** while a change involving **Prometheus workflow** places **security** at risk.
- Plain-language question: What problem does **Beginner method: symptom, scope, time, change** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before touching a component, write four facts: symptom: exact missing/wrong/slow behavior scope: service, signal, cluster, tenant, users time: first observed and last known good in UTC change: deployment, config, credential, topology, load
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: block a telemetry exporter and observe the bounded queue.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Beginner method: symptom, scope, time, change** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 118 - Preserve evidence before restarting x delivery safety

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Preserve evidence before restarting** while a change involving **Prometheus: absent target versus failed target** places **delivery safety** at risk.
- Plain-language question: What problem does **Preserve evidence before restarting** solve here, and who notices first when it fails?
- Lesson evidence anchor: A restart may remove in-memory queues, transient errors, pod logs, and the process state that explains the failure. Capture: Restart only when it is an intentional mitigation or diagnostic step with an expected result.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a scrape, discovery, or label mismatch.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Defend **Preserve evidence before restarting** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 118.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://prometheus.io/docs/prometheus/latest/querying/api/ "Prometheus HTTP API"
[2]: https://opentelemetry.io/docs/collector/troubleshooting/ "Collector Troubleshooting"
[3]: https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/ "Prometheus Rule Unit Testing"
[4]: https://grafana.com/docs/loki/latest/operations/troubleshooting/ "Loki Troubleshooting"
[5]: https://grafana.com/docs/grafana/latest/troubleshooting/ "Grafana Troubleshooting"
