# Module 15 — Observability

## Lesson 2: Prometheus Architecture and Installation

Prometheus discovers targets, pulls metrics over HTTP, stores labeled time series locally, evaluates rules, and sends alerts to Alertmanager. Its pull model makes target health visible through the `up` metric. ([Prometheus][1])

# 15.2.1 Architecture

```text
applications/exporters ──scrape──► Prometheus TSDB
service discovery ──────────────────────┘
rules ──evaluate──► recording series + alerts
alerts ───────────► Alertmanager ──► receivers
PromQL ◄────────── Grafana / API / humans
```

Prometheus is not a general event store. Samples are numeric values identified by a metric name and label set. Every unique label set is a time series.

# 15.2.2 Kubernetes deployment choice

For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm show values prometheus-community/kube-prometheus-stack > reviewed-values.yaml
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version REPLACE_WITH_REVIEWED_VERSION \
  --values reviewed-values.yaml
```

Production values should define retention, persistent volume, requests/limits, topology spread, PodDisruptionBudgets, ingress/authentication, rule selection, and remote storage if required.

# 15.2.3 Discovery objects

With Prometheus Operator:

```text
ServiceMonitor → selects Services and named ports
PodMonitor     → selects Pods directly
Probe          → models black-box probing
PrometheusRule → recording and alerting rules
```

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: todo-api
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: [todo-prod]
  selector:
    matchLabels:
      app.kubernetes.io/name: todo-api
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

# 15.2.4 Validation lab

```bash
kubectl -n monitoring get pods,pvc
kubectl -n monitoring get prometheus,alertmanager
kubectl -n monitoring get servicemonitor
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Query `up`, inspect **Status → Targets**, then deliberately change `port: metrics` to a nonexistent port. Diagnose selection, discovery, network policy, endpoint, and TLS before reverting Git.

# 15.2.5 Production checklist

```text
□ Pinned versions and Git-managed values
□ Persistent storage and retention sized
□ Prometheus itself monitored
□ Rule files validated with promtool
□ Authentication and network boundaries defined
□ Backup/remote durability decision documented
□ Upgrade and rollback rehearsed
```

# Beginner Level

# 15.2.6 Prometheus in layman language

Imagine a school teacher who checks every classroom every 30 seconds:

```text
How many students are present?
How many computers are working?
How many assignments failed?
How long did the last activity take?
```

Each classroom displays a small status sheet outside its door. The teacher reads the sheet and records the numbers with a timestamp.

Prometheus works similarly:

```text
Prometheus                    Application
    │                             │
    ├──── GET /metrics ──────────►│
    │◄── metric text response ────┤
    │                             │
    └── stores timestamped samples
```

Important words:

```text
target        system exposing metrics
scrape        one metrics collection request
scrape interval time between collection attempts
time series   metric name + label set over time
sample        one value at one timestamp
PromQL        Prometheus Query Language
rule          query evaluated automatically on a schedule
```

Prometheus is designed primarily for numerical time-series monitoring and alerting. It is not a replacement for application logs, distributed traces, transactional databases, or long-term business analytics.

---

# 15.2.7 Prometheus components step by step

## Prometheus server

The server performs three central jobs:

```text
retrieve metric samples
store time series
evaluate PromQL and rules
```

## Service discovery

Discovery finds possible targets from sources such as:

```text
static configuration
Kubernetes API
cloud provider APIs
file-based discovery
```

Discovery does not guarantee that a target is healthy. It tells Prometheus what may be scraped.

## Exporter

An exporter converts another system's information into Prometheus metrics.

Examples:

```text
node_exporter       Linux host metrics
blackbox_exporter   probes HTTP, TCP, DNS and related endpoints
database exporters  database-specific metrics
```

Prefer direct application instrumentation for business and application behavior. Use exporters when you cannot modify the observed system or when a mature exporter already models it well.

## Alertmanager

Prometheus evaluates alert conditions and sends firing alerts to Alertmanager. Alertmanager groups, routes, inhibits, silences, and delivers notifications. It does not calculate the PromQL condition.

## Grafana

Grafana queries Prometheus and visualizes the results. Prometheus does not require Grafana, and Grafana does not replace Prometheus.

---

# 15.2.8 What happens during one scrape

```text
1. Discovery provides target address and metadata.
2. Relabeling decides whether and how to keep the target.
3. Prometheus sends HTTP request to the metrics path.
4. Target returns exposition-format metrics.
5. Prometheus parses and validates samples.
6. Metric relabeling may transform or drop samples.
7. Accepted samples enter the time-series database.
8. Prometheus records scrape health and duration.
```

Prometheus automatically provides useful scrape evidence such as:

```text
up
scrape_duration_seconds
scrape_samples_scraped
scrape_samples_post_metric_relabeling
```

Interpretation:

```text
up == 1  last scrape succeeded
up == 0  target was discovered, but last scrape failed
no up series target may not have been discovered/retained at all
```

This distinction is essential during troubleshooting.

---

# 15.2.9 Prometheus data locality and limitations

Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data.

Professional limitations to understand:

```text
one server has finite CPU, memory and disk
local storage is not a clustered durable database
very high cardinality consumes resources
Prometheus prioritizes availability over perfect sample delivery
long-term/global query normally needs an additional architecture
logs and traces belong in appropriate backends
```

Do not call Prometheus “broken” because it does not provide a feature outside its design. Choose federation, remote write/read, or a compatible long-term metrics system when requirements justify it.

---

# Intermediate Level

# 15.2.10 Static scrape configuration

Minimal configuration:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: order-api
    metrics_path: /metrics
    static_configs:
      - targets:
          - host.docker.internal:8000
        labels:
          environment: development
          team: order
```

Meaning:

```text
scrape_interval     collect every 15 seconds
evaluation_interval evaluate rules every 15 seconds
job_name            logical scrape job
metrics_path        HTTP path containing metrics
targets             host and port
static labels       controlled context added to target
```

On Linux, a Prometheus container may need an explicit host-gateway mapping to reach an application on the host. Alternatively, put both containers on the same Docker network and scrape the application service name.

---

# 15.2.11 Service discovery and relabeling mental model

Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations.

Relabeling then performs target selection and label construction:

```text
discovered target metadata
        ↓
keep/drop rules
        ↓
address, scheme and path selection
        ↓
stable target labels
        ↓
scrape
```

Metric relabeling happens after scraping and operates on samples.

```text
relabel_configs        → target before scrape
metric_relabel_configs → samples after scrape
```

Confusing these two is a common certification and production mistake.

---

# 15.2.12 Real-world installation choices

## Local binary

Best for learning and quick diagnostics.

## Docker/Compose

Best for reproducible local labs.

## Kubernetes manifests

Useful for understanding individual resources but creates maintenance work.

## Prometheus Operator stack

Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor, Probe and PrometheusRule.

## Managed metrics service

Useful when the organization wants provider-operated scaling and durability, while still considering ingestion, compatibility, security, data residency and cost.

The correct choice depends on:

```text
scale
operational skill
retention
tenant isolation
HA
compliance
cost
query compatibility
```

---

# Real-world Hands-on Tutorial

# 15.2.13 Lab 1 — run Prometheus with Docker

Continue with the observable API from Lesson 15.1.

Create directories:

```bash
mkdir -p module-15/15.2-prometheus/prometheus
cd module-15/15.2-prometheus
```

Create `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: order-api
    metrics_path: /metrics
    static_configs:
      - targets: ["host.docker.internal:8000"]
        labels:
          environment: development
          team: order
```

Create `compose.yaml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:REPLACE_WITH_REVIEWED_VERSION
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=2d
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  prometheus-data:
```

Replace the image placeholder with a reviewed version before running.

Validate Compose:

```bash
docker compose config
```

Start:

```bash
docker compose up -d
docker compose ps
docker compose logs prometheus
```

---

# 15.2.14 Lab 2 — inspect health and targets

```bash
curl -fsS http://localhost:9090/-/healthy
curl -fsS http://localhost:9090/-/ready
```

Open:

```text
http://localhost:9090/targets
```

Expected:

```text
prometheus → UP
order-api  → UP
```

If the API is `DOWN`, check:

```text
Is Lesson 15.1 application running on port 8000?
Does /metrics work from the host?
Can the container resolve/reach host.docker.internal?
Is the port/path correct?
What exact scrape error is shown?
```

---

# 15.2.15 Lab 3 — first PromQL queries

In the Prometheus expression browser, query:

```promql
up
```

Then:

```promql
up{job="order-api"}
```

Generate requests against the Lesson 15.1 application, then query:

```promql
order_api_http_requests_total
```

Request rate:

```promql
sum by (route, status_class) (
  rate(order_api_http_requests_total[1m])
)
```

Scrape duration:

```promql
scrape_duration_seconds{job="order-api"}
```

Do not memorize PromQL yet. Learn the relationship:

```text
application emits
→ Prometheus scrapes
→ TSDB stores
→ PromQL selects/calculates
```

---

# Break It and Debug It

# 15.2.16 Failure lab — wrong metrics path

Change:

```yaml
metrics_path: /wrong-metrics
```

Reload by restarting the lab container:

```bash
docker compose restart prometheus
```

Expected:

```text
order-api target DOWN
HTTP 404 scrape error
up{job="order-api"} == 0
```

Repair the path and confirm `up` becomes `1`.

Do not stop after the target page turns green. Query the application metric to prove samples are arriving.

---

# 15.2.17 Failure lab — invalid configuration

Introduce invalid YAML indentation in a disposable copy.

Use the Prometheus image to validate before restart:

```bash
docker run --rm \
  -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  prom/prometheus:REPLACE_WITH_REVIEWED_VERSION \
  promtool check config /etc/prometheus/prometheus.yml
```

Expected:

```text
configuration validation fails
```

Repair it and rerun `promtool`.

Professional lesson:

```text
configuration should fail in CI
before it reaches a production server
```

---

# Expert and Professional Level

# 15.2.18 Kubernetes ServiceMonitor pattern

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: order-api
  namespace: monitoring
  labels:
    monitoring-stack: platform
spec:
  namespaceSelector:
    matchNames: [orders-prod]
  selector:
    matchLabels:
      app.kubernetes.io/name: order-api
  endpoints:
    - port: metrics
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

The Service must expose a **named** port matching `metrics`.

Three selectors must align:

```text
Prometheus selects ServiceMonitor
ServiceMonitor selects Service
Service selects ready Pods/endpoints
```

When metrics are missing, inspect every selector rather than randomly restarting Prometheus.

---

# 15.2.19 Production values checklist

Before a Helm installation, review values for:

```text
exact chart and image versions
storage class, size and retention
Prometheus replicas
Alertmanager replicas
requests and limits
topology spread/anti-affinity
PodDisruptionBudgets
security contexts
ServiceAccount and RBAC
network policies
ingress/authentication
rule and monitor selectors
external labels
remote write if required
backup/recovery decision
```

Never blindly use the newest chart in production.

Render and inspect:

```bash
helm template monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version REPLACE_WITH_REVIEWED_VERSION \
  --values reviewed-values.yaml > rendered.yaml
```

---

# 15.2.20 High availability mental model

Two Prometheus replicas can scrape the same targets independently.

```text
Target
├── scraped by Prometheus A
└── scraped by Prometheus B
```

This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries or storage deduplicate using appropriate external labels.

Local persistent volume loss can still remove local history. Define whether remote durable storage, backup, or acceptable recent-data loss matches the requirement.

HA questions:

```text
Can rules continue during one replica loss?
How are duplicate alerts handled?
Can queries reach a healthy replica?
Are replicas spread across nodes/zones?
Does storage survive the expected failure?
```

---

# 15.2.21 Security hardening

Metrics can reveal topology, versions, tenant names and business volume.

Production controls:

```text
private network paths
TLS and authenticated scrape where required
least-privilege discovery RBAC
restricted UI/API
SSO through an approved access layer
read-only configuration mounts
non-root containers
controlled admin lifecycle endpoints
audit of configuration changes
secret delivery outside Git plaintext
```

Do not place credentials in URL query parameters or ordinary labels.

Do not publicly expose `/metrics` simply because the data is “only monitoring.”

---

# Certification Preparation

# 15.2.22 PCA mapping

This lesson maps primarily to:

```text
Observability Concepts
→ push vs pull
→ service discovery

Prometheus Fundamentals
→ architecture
→ configuration and scraping
→ limitations
→ data model
→ exposition flow
```

Practice question:

```text
A target has no up series at all.
What should be checked first?

A. Alertmanager grouping
B. Discovery and target relabeling
C. Grafana theme
D. Log retention
```

Answer:

```text
B. Discovery and target relabeling
```

If the target existed with `up == 0`, then connectivity, path, TLS, authentication or response format would be stronger next checks.

---

# Interview Preparation

# 15.2.23 Beginner interview answers

## What is Prometheus?

> **Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.**

## What is scraping?

> **Scraping is Prometheus requesting an endpoint such as `/metrics`, parsing the exposition response, and storing accepted samples with timestamps and target labels.**

## Prometheus vs Grafana?

> **Prometheus collects, stores and queries metrics and evaluates rules. Grafana is a visualization and exploration layer that can query Prometheus and other data sources.**

---

# 15.2.24 Expert interview answers

## How do you run Prometheus highly available?

> **I run independent replicas that scrape and evaluate the same desired configuration, spread them across failure domains, route queries to healthy replicas, and let Alertmanager coordinate notification deduplication. For global or long-term storage I attach unique external labels and use a compatible deduplicating query/storage architecture. I still define local-storage loss and restore behavior.**

## A Kubernetes ServiceMonitor exists but no target appears. What do you check?

> **I check whether Prometheus selects the ServiceMonitor, whether its namespaceSelector and selector find the intended Service, whether the endpoint port name matches the Service port, whether the Service selects ready Pods, and whether target relabeling drops it. Only after discovery exists do I debug network, TLS, path and exposition errors.**

## Why not use one central Prometheus to scrape every private cluster?

> **It can create network, failure-domain, scale and security coupling. I choose per-cluster or regional collectors when it contains failures and keeps scrape traffic local, then use remote/global query where needed. The architecture follows latency, isolation, cardinality, retention and operational requirements.**

---

# 15.2.25 Cleanup and final checklist

```bash
docker compose down
```

To remove the disposable metrics volume as well:

```bash
docker compose down --volumes
```

Removing the volume deletes local lab metrics history. Use it only for this explicitly disposable lab.

Final checklist:

```text
□ I can explain pull-based scraping
□ I know target vs sample relabeling
□ I can distinguish no target from up == 0
□ I can run and validate Prometheus locally
□ I can query target and application metrics
□ I can break and repair scrape configuration
□ I understand ServiceMonitor selector layers
□ I know Prometheus local-storage limitations
□ I can describe HA without claiming clustered local TSDB
□ I can explain security and production values
```

Next:

```text
Lesson 15.3
metric types
label design
PromQL
cardinality
histograms
production query correctness
```

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 15.2.26 Professional Mastery Workbook

This workbook expands **Prometheus Architecture and Installation** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 25 lesson-specific anchors.
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

### Concept card 1 - Architecture

- Lesson anchor: applications/exporters ──scrape──► Prometheus TSDB service discovery ──────────────────────┘ rules ──evaluate──► recording series + alerts alerts ───────────► Alertmanager ──► receivers PromQL ◄────────── Grafana / API / humans
- Beginner explanation: Restate **Architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Architecture**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Kubernetes deployment choice

- Lesson anchor: For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.
- Beginner explanation: Restate **Kubernetes deployment choice** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes deployment choice** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **Kubernetes deployment choice**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **Kubernetes deployment choice**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Kubernetes deployment choice** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Discovery objects

- Lesson anchor: With Prometheus Operator: ServiceMonitor → selects Services and named ports PodMonitor     → selects Pods directly Probe          → models black-box probing PrometheusRule → recording and alerting rules apiVersion: monitoring.coreos.com/v1
- Beginner explanation: Restate **Discovery objects** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Discovery objects** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Discovery objects**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Discovery objects**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Discovery objects** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Validation lab

- Lesson anchor: kubectl -n monitoring get pods,pvc kubectl -n monitoring get prometheus,alertmanager kubectl -n monitoring get servicemonitor kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 Query up, inspect Status → Targets, then del...
- Beginner explanation: Restate **Validation lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Validation lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Validation lab**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Validation lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Validation lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Production checklist

- Lesson anchor: □ Pinned versions and Git-managed values □ Persistent storage and retention sized □ Prometheus itself monitored □ Rule files validated with promtool □ Authentication and network boundaries defined □ Backup/remote durability decision documented
- Beginner explanation: Restate **Production checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Production checklist**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Production checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Production checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Prometheus in layman language

- Lesson anchor: Imagine a school teacher who checks every classroom every 30 seconds: How many students are present? How many computers are working? How many assignments failed? How long did the last activity take? Each classroom displays a small status sheet outside its d...
- Beginner explanation: Restate **Prometheus in layman language** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus in layman language** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Prometheus in layman language**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Prometheus in layman language**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus in layman language** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Prometheus components step by step

- Lesson anchor: The server performs three central jobs: retrieve metric samples store time series evaluate PromQL and rules Discovery finds possible targets from sources such as: static configuration Kubernetes API cloud provider APIs file-based discovery
- Beginner explanation: Restate **Prometheus components step by step** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus components step by step** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Prometheus components step by step**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Prometheus components step by step**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus components step by step** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - What happens during one scrape

- Lesson anchor: Prometheus automatically provides useful scrape evidence such as: up scrapedurationseconds scrapesamplesscraped scrapesamplespostmetricrelabeling Interpretation: up == 1  last scrape succeeded up == 0  target was discovered, but last scrape failed
- Beginner explanation: Restate **What happens during one scrape** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What happens during one scrape** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **What happens during one scrape**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **What happens during one scrape**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **What happens during one scrape** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Prometheus data locality and limitations

- Lesson anchor: Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data. Professional limitations to understand: one server has finite CPU, memory and disk
- Beginner explanation: Restate **Prometheus data locality and limitations** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prometheus data locality and limitations** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Prometheus data locality and limitations**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Prometheus data locality and limitations**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Prometheus data locality and limitations** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Static scrape configuration

- Lesson anchor: Minimal configuration: global: scrapeinterval: 15s evaluationinterval: 15s scrapeconfigs: metricspath: /metrics staticconfigs: labels: environment: development team: order Meaning: scrapeinterval     collect every 15 seconds
- Beginner explanation: Restate **Static scrape configuration** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Static scrape configuration** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Static scrape configuration**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Static scrape configuration**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Static scrape configuration** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Service discovery and relabeling mental model

- Lesson anchor: Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations. Relabeling then performs target selection and label construction:
- Beginner explanation: Restate **Service discovery and relabeling mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Service discovery and relabeling mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Service discovery and relabeling mental model**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Service discovery and relabeling mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Service discovery and relabeling mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Real-world installation choices

- Lesson anchor: Best for learning and quick diagnostics. Best for reproducible local labs. Useful for understanding individual resources but creates maintenance work. Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor,...
- Beginner explanation: Restate **Real-world installation choices** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real-world installation choices** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Real-world installation choices**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Real-world installation choices**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Real-world installation choices** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Lab 1 — run Prometheus with Docker

- Lesson anchor: Continue with the observable API from Lesson 15.1. Create directories: mkdir -p module-15/15.2-prometheus/prometheus cd module-15/15.2-prometheus Create prometheus/prometheus.yml: global: scrapeinterval: 5s evaluationinterval: 5s
- Beginner explanation: Restate **Lab 1 — run Prometheus with Docker** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab 1 — run Prometheus with Docker** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Lab 1 — run Prometheus with Docker**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Lab 1 — run Prometheus with Docker**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Lab 1 — run Prometheus with Docker** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Lab 2 — inspect health and targets

- Lesson anchor: curl -fsS http://localhost:9090/-/healthy curl -fsS http://localhost:9090/-/ready Open: http://localhost:9090/targets Expected: prometheus → UP order-api  → UP If the API is DOWN, check: Is Lesson 15.1 application running on port 8000?
- Beginner explanation: Restate **Lab 2 — inspect health and targets** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab 2 — inspect health and targets** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **Lab 2 — inspect health and targets**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **Lab 2 — inspect health and targets**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Lab 2 — inspect health and targets** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Lab 3 — first PromQL queries

- Lesson anchor: In the Prometheus expression browser, query: up Then: up{job="order-api"} Generate requests against the Lesson 15.1 application, then query: orderapihttprequeststotal Request rate: sum by (route, statusclass) ( rate(orderapihttprequeststotal[1m])
- Beginner explanation: Restate **Lab 3 — first PromQL queries** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab 3 — first PromQL queries** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Lab 3 — first PromQL queries**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Lab 3 — first PromQL queries**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Lab 3 — first PromQL queries** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Failure lab — wrong metrics path

- Lesson anchor: Change: metricspath: /wrong-metrics Reload by restarting the lab container: docker compose restart prometheus Expected: order-api target DOWN HTTP 404 scrape error up{job="order-api"} == 0 Repair the path and confirm up becomes 1.
- Beginner explanation: Restate **Failure lab — wrong metrics path** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure lab — wrong metrics path** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **Failure lab — wrong metrics path**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **Failure lab — wrong metrics path**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Failure lab — wrong metrics path** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Failure lab — invalid configuration

- Lesson anchor: Introduce invalid YAML indentation in a disposable copy. Use the Prometheus image to validate before restart: docker run --rm \ -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \ prom/prometheus:REPLACEWITHREVIEWEDVERSION \
- Beginner explanation: Restate **Failure lab — invalid configuration** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure lab — invalid configuration** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Failure lab — invalid configuration**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Failure lab — invalid configuration**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Failure lab — invalid configuration** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Kubernetes ServiceMonitor pattern

- Lesson anchor: apiVersion: monitoring.coreos.com/v1 kind: ServiceMonitor metadata: name: order-api namespace: monitoring labels: monitoring-stack: platform spec: namespaceSelector: matchNames: [orders-prod] selector: matchLabels: app.kubernetes.io/name: order-api
- Beginner explanation: Restate **Kubernetes ServiceMonitor pattern** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes ServiceMonitor pattern** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Kubernetes ServiceMonitor pattern**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Kubernetes ServiceMonitor pattern**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Kubernetes ServiceMonitor pattern** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Production values checklist

- Lesson anchor: Before a Helm installation, review values for: exact chart and image versions storage class, size and retention Prometheus replicas Alertmanager replicas requests and limits topology spread/anti-affinity PodDisruptionBudgets
- Beginner explanation: Restate **Production values checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production values checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Production values checklist**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Production values checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Production values checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - High availability mental model

- Lesson anchor: Two Prometheus replicas can scrape the same targets independently. Target ├── scraped by Prometheus A └── scraped by Prometheus B This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries...
- Beginner explanation: Restate **High availability mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **High availability mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an OpenTelemetry Collector pipeline and validation report focused on **High availability mental model**.
- Failure exercise: In an isolated environment, block a telemetry exporter and observe the bounded queue while observing the boundaries around **High availability mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **High availability mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Security hardening

- Lesson anchor: Metrics can reveal topology, versions, tenant names and business volume. Production controls: private network paths TLS and authenticated scrape where required least-privilege discovery RBAC restricted UI/API SSO through an approved access layer
- Beginner explanation: Restate **Security hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Security hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a dashboard, recording rule, alert, and runbook focused on **Security hardening**.
- Failure exercise: In an isolated environment, introduce malformed or high-cardinality telemetry while observing the boundaries around **Security hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Security hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - PCA mapping

- Lesson anchor: This lesson maps primarily to: Observability Concepts → push vs pull → service discovery Prometheus Fundamentals → architecture → configuration and scraping → limitations → data model → exposition flow Practice question:
- Beginner explanation: Restate **PCA mapping** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PCA mapping** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a telemetry schema and cardinality budget focused on **PCA mapping**.
- Failure exercise: In an isolated environment, remove trace-context propagation at one boundary while observing the boundaries around **PCA mapping**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **PCA mapping** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Beginner interview answers

- Lesson anchor: Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.
- Beginner explanation: Restate **Beginner interview answers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Beginner interview answers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an end-to-end signal and notification canary focused on **Beginner interview answers**.
- Failure exercise: In an isolated environment, delay storage or query availability while observing the boundaries around **Beginner interview answers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Beginner interview answers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Expert interview answers

- Lesson anchor: I run independent replicas that scrape and evaluate the same desired configuration, spread them across failure domains, route queries to healthy replicas, and let Alertmanager coordinate notification deduplication. For global or long-term storage I attach u...
- Beginner explanation: Restate **Expert interview answers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Expert interview answers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a metrics-to-trace-to-log correlation record focused on **Expert interview answers**.
- Failure exercise: In an isolated environment, make the notification receiver reject a synthetic test while observing the boundaries around **Expert interview answers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Expert interview answers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Cleanup and final checklist

- Lesson anchor: docker compose down To remove the disposable metrics volume as well: docker compose down --volumes Removing the volume deletes local lab metrics history. Use it only for this explicitly disposable lab. Final checklist: □ I can explain pull-based scraping
- Beginner explanation: Restate **Cleanup and final checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cleanup and final checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a PromQL, LogQL, or TraceQL investigation focused on **Cleanup and final checklist**.
- Failure exercise: In an isolated environment, inject a scrape, discovery, or label mismatch while observing the boundaries around **Cleanup and final checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.
- Interview prompt: Explain **Cleanup and final checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Architecture x latency

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Architecture** while a change involving **Validation lab** places **latency** at risk.
- Plain-language question: What problem does **Architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters ──scrape──► Prometheus TSDB service discovery ──────────────────────┘ rules ──evaluate──► recording series + alerts alerts ───────────► Alertmanager ──► receivers PromQL ◄────────── Grafana / API / humans
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Architecture** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Kubernetes deployment choice x privacy

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Kubernetes deployment choice** while a change involving **Service discovery and relabeling mental model** places **privacy** at risk.
- Plain-language question: What problem does **Kubernetes deployment choice** solve here, and who notices first when it fails?
- Lesson evidence anchor: For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes deployment choice** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Discovery objects x operability

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Discovery objects** while a change involving **Kubernetes ServiceMonitor pattern** places **operability** at risk.
- Plain-language question: What problem does **Discovery objects** solve here, and who notices first when it fails?
- Lesson evidence anchor: With Prometheus Operator: ServiceMonitor → selects Services and named ports PodMonitor     → selects Pods directly Probe          → models black-box probing PrometheusRule → recording and alerting rules apiVersion: monitoring.coreos.com/v1
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Discovery objects** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Validation lab x data integrity

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Validation lab** while a change involving **Cleanup and final checklist** places **data integrity** at risk.
- Plain-language question: What problem does **Validation lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: kubectl -n monitoring get pods,pvc kubectl -n monitoring get prometheus,alertmanager kubectl -n monitoring get servicemonitor kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 Query up, inspect Status → Targets, then del...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Validation lab** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Production checklist x automation safety

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Production checklist** while a change involving **Prometheus components step by step** places **automation safety** at risk.
- Plain-language question: What problem does **Production checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ Pinned versions and Git-managed values □ Persistent storage and retention sized □ Prometheus itself monitored □ Rule files validated with promtool □ Authentication and network boundaries defined □ Backup/remote durability decision documented
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Production checklist** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Prometheus in layman language x governance

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus in layman language** while a change involving **Lab 2 — inspect health and targets** places **governance** at risk.
- Plain-language question: What problem does **Prometheus in layman language** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine a school teacher who checks every classroom every 30 seconds: How many students are present? How many computers are working? How many assignments failed? How long did the last activity take? Each classroom displays a small status sheet outside its d...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus in layman language** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Prometheus components step by step x correctness

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus components step by step** while a change involving **Security hardening** places **correctness** at risk.
- Plain-language question: What problem does **Prometheus components step by step** solve here, and who notices first when it fails?
- Lesson evidence anchor: The server performs three central jobs: retrieve metric samples store time series evaluate PromQL and rules Discovery finds possible targets from sources such as: static configuration Kubernetes API cloud provider APIs file-based discovery
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus components step by step** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - What happens during one scrape x capacity

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **What happens during one scrape** while a change involving **Discovery objects** places **capacity** at risk.
- Plain-language question: What problem does **What happens during one scrape** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus automatically provides useful scrape evidence such as: up scrapedurationseconds scrapesamplesscraped scrapesamplespostmetricrelabeling Interpretation: up == 1  last scrape succeeded up == 0  target was discovered, but last scrape failed
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **What happens during one scrape** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Prometheus data locality and limitations x cost efficiency

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus data locality and limitations** while a change involving **Static scrape configuration** places **cost efficiency** at risk.
- Plain-language question: What problem does **Prometheus data locality and limitations** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data. Professional limitations to understand: one server has finite CPU, memory and disk
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus data locality and limitations** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Static scrape configuration x recovery

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Static scrape configuration** while a change involving **Failure lab — invalid configuration** places **recovery** at risk.
- Plain-language question: What problem does **Static scrape configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Minimal configuration: global: scrapeinterval: 15s evaluationinterval: 15s scrapeconfigs: metricspath: /metrics staticconfigs: labels: environment: development team: order Meaning: scrapeinterval     collect every 15 seconds
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Static scrape configuration** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Service discovery and relabeling mental model x change management

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Service discovery and relabeling mental model** while a change involving **Expert interview answers** places **change management** at risk.
- Plain-language question: What problem does **Service discovery and relabeling mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations. Relabeling then performs target selection and label construction:
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Service discovery and relabeling mental model** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Real-world installation choices x dependency failure

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Real-world installation choices** while a change involving **Prometheus in layman language** places **dependency failure** at risk.
- Plain-language question: What problem does **Real-world installation choices** solve here, and who notices first when it fails?
- Lesson evidence anchor: Best for learning and quick diagnostics. Best for reproducible local labs. Useful for understanding individual resources but creates maintenance work. Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor,...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Real-world installation choices** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Lab 1 — run Prometheus with Docker x developer experience

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 1 — run Prometheus with Docker** while a change involving **Lab 2 — inspect health and targets** places **developer experience** at risk.
- Plain-language question: What problem does **Lab 1 — run Prometheus with Docker** solve here, and who notices first when it fails?
- Lesson evidence anchor: Continue with the observable API from Lesson 15.1. Create directories: mkdir -p module-15/15.2-prometheus/prometheus cd module-15/15.2-prometheus Create prometheus/prometheus.yml: global: scrapeinterval: 5s evaluationinterval: 5s
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 1 — run Prometheus with Docker** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Lab 2 — inspect health and targets x availability

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 2 — inspect health and targets** while a change involving **High availability mental model** places **availability** at risk.
- Plain-language question: What problem does **Lab 2 — inspect health and targets** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://localhost:9090/-/healthy curl -fsS http://localhost:9090/-/ready Open: http://localhost:9090/targets Expected: prometheus → UP order-api  → UP If the API is DOWN, check: Is Lesson 15.1 application running on port 8000?
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 2 — inspect health and targets** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Lab 3 — first PromQL queries x security

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 3 — first PromQL queries** while a change involving **Kubernetes deployment choice** places **security** at risk.
- Plain-language question: What problem does **Lab 3 — first PromQL queries** solve here, and who notices first when it fails?
- Lesson evidence anchor: In the Prometheus expression browser, query: up Then: up{job="order-api"} Generate requests against the Lesson 15.1 application, then query: orderapihttprequeststotal Request rate: sum by (route, statusclass) ( rate(orderapihttprequeststotal[1m])
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 3 — first PromQL queries** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Failure lab — wrong metrics path x delivery safety

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure lab — wrong metrics path** while a change involving **Prometheus data locality and limitations** places **delivery safety** at risk.
- Plain-language question: What problem does **Failure lab — wrong metrics path** solve here, and who notices first when it fails?
- Lesson evidence anchor: Change: metricspath: /wrong-metrics Reload by restarting the lab container: docker compose restart prometheus Expected: order-api target DOWN HTTP 404 scrape error up{job="order-api"} == 0 Repair the path and confirm up becomes 1.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — wrong metrics path** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Failure lab — invalid configuration x multi-tenancy

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure lab — invalid configuration** while a change involving **Failure lab — wrong metrics path** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Failure lab — invalid configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Introduce invalid YAML indentation in a disposable copy. Use the Prometheus image to validate before restart: docker run --rm \ -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \ prom/prometheus:REPLACEWITHREVIEWEDVERSION \
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — invalid configuration** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Kubernetes ServiceMonitor pattern x observability

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Kubernetes ServiceMonitor pattern** while a change involving **Beginner interview answers** places **observability** at risk.
- Plain-language question: What problem does **Kubernetes ServiceMonitor pattern** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: monitoring.coreos.com/v1 kind: ServiceMonitor metadata: name: order-api namespace: monitoring labels: monitoring-stack: platform spec: namespaceSelector: matchNames: [orders-prod] selector: matchLabels: app.kubernetes.io/name: order-api
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes ServiceMonitor pattern** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Production values checklist x regional resilience

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Production values checklist** while a change involving **Production checklist** places **regional resilience** at risk.
- Plain-language question: What problem does **Production values checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before a Helm installation, review values for: exact chart and image versions storage class, size and retention Prometheus replicas Alertmanager replicas requests and limits topology spread/anti-affinity PodDisruptionBudgets
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Production values checklist** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - High availability mental model x business value

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **High availability mental model** while a change involving **Real-world installation choices** places **business value** at risk.
- Plain-language question: What problem does **High availability mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two Prometheus replicas can scrape the same targets independently. Target ├── scraped by Prometheus A └── scraped by Prometheus B This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **High availability mental model** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Security hardening x latency

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Security hardening** while a change involving **Production values checklist** places **latency** at risk.
- Plain-language question: What problem does **Security hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Metrics can reveal topology, versions, tenant names and business volume. Production controls: private network paths TLS and authenticated scrape where required least-privilege discovery RBAC restricted UI/API SSO through an approved access layer
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Security hardening** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - PCA mapping x privacy

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **PCA mapping** while a change involving **Architecture** places **privacy** at risk.
- Plain-language question: What problem does **PCA mapping** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson maps primarily to: Observability Concepts → push vs pull → service discovery Prometheus Fundamentals → architecture → configuration and scraping → limitations → data model → exposition flow Practice question:
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **PCA mapping** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Beginner interview answers x operability

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Beginner interview answers** while a change involving **What happens during one scrape** places **operability** at risk.
- Plain-language question: What problem does **Beginner interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Beginner interview answers** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Expert interview answers x data integrity

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Expert interview answers** while a change involving **Lab 3 — first PromQL queries** places **data integrity** at risk.
- Plain-language question: What problem does **Expert interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: I run independent replicas that scrape and evaluate the same desired configuration, spread them across failure domains, route queries to healthy replicas, and let Alertmanager coordinate notification deduplication. For global or long-term storage I attach u...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Expert interview answers** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Cleanup and final checklist x automation safety

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Cleanup and final checklist** while a change involving **PCA mapping** places **automation safety** at risk.
- Plain-language question: What problem does **Cleanup and final checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: docker compose down To remove the disposable metrics volume as well: docker compose down --volumes Removing the volume deletes local lab metrics history. Use it only for this explicitly disposable lab. Final checklist: □ I can explain pull-based scraping
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Cleanup and final checklist** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Architecture x governance

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Architecture** while a change involving **Validation lab** places **governance** at risk.
- Plain-language question: What problem does **Architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters ──scrape──► Prometheus TSDB service discovery ──────────────────────┘ rules ──evaluate──► recording series + alerts alerts ───────────► Alertmanager ──► receivers PromQL ◄────────── Grafana / API / humans
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Architecture** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Kubernetes deployment choice x correctness

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Kubernetes deployment choice** while a change involving **Service discovery and relabeling mental model** places **correctness** at risk.
- Plain-language question: What problem does **Kubernetes deployment choice** solve here, and who notices first when it fails?
- Lesson evidence anchor: For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes deployment choice** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Discovery objects x capacity

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Discovery objects** while a change involving **Kubernetes ServiceMonitor pattern** places **capacity** at risk.
- Plain-language question: What problem does **Discovery objects** solve here, and who notices first when it fails?
- Lesson evidence anchor: With Prometheus Operator: ServiceMonitor → selects Services and named ports PodMonitor     → selects Pods directly Probe          → models black-box probing PrometheusRule → recording and alerting rules apiVersion: monitoring.coreos.com/v1
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Discovery objects** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Validation lab x cost efficiency

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Validation lab** while a change involving **Cleanup and final checklist** places **cost efficiency** at risk.
- Plain-language question: What problem does **Validation lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: kubectl -n monitoring get pods,pvc kubectl -n monitoring get prometheus,alertmanager kubectl -n monitoring get servicemonitor kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 Query up, inspect Status → Targets, then del...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Validation lab** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Production checklist x recovery

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production checklist** while a change involving **Prometheus components step by step** places **recovery** at risk.
- Plain-language question: What problem does **Production checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ Pinned versions and Git-managed values □ Persistent storage and retention sized □ Prometheus itself monitored □ Rule files validated with promtool □ Authentication and network boundaries defined □ Backup/remote durability decision documented
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Production checklist** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Prometheus in layman language x change management

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus in layman language** while a change involving **Lab 2 — inspect health and targets** places **change management** at risk.
- Plain-language question: What problem does **Prometheus in layman language** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine a school teacher who checks every classroom every 30 seconds: How many students are present? How many computers are working? How many assignments failed? How long did the last activity take? Each classroom displays a small status sheet outside its d...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus in layman language** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Prometheus components step by step x dependency failure

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus components step by step** while a change involving **Security hardening** places **dependency failure** at risk.
- Plain-language question: What problem does **Prometheus components step by step** solve here, and who notices first when it fails?
- Lesson evidence anchor: The server performs three central jobs: retrieve metric samples store time series evaluate PromQL and rules Discovery finds possible targets from sources such as: static configuration Kubernetes API cloud provider APIs file-based discovery
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus components step by step** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - What happens during one scrape x developer experience

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **What happens during one scrape** while a change involving **Discovery objects** places **developer experience** at risk.
- Plain-language question: What problem does **What happens during one scrape** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus automatically provides useful scrape evidence such as: up scrapedurationseconds scrapesamplesscraped scrapesamplespostmetricrelabeling Interpretation: up == 1  last scrape succeeded up == 0  target was discovered, but last scrape failed
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **What happens during one scrape** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Prometheus data locality and limitations x availability

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus data locality and limitations** while a change involving **Static scrape configuration** places **availability** at risk.
- Plain-language question: What problem does **Prometheus data locality and limitations** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data. Professional limitations to understand: one server has finite CPU, memory and disk
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus data locality and limitations** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Static scrape configuration x security

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Static scrape configuration** while a change involving **Failure lab — invalid configuration** places **security** at risk.
- Plain-language question: What problem does **Static scrape configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Minimal configuration: global: scrapeinterval: 15s evaluationinterval: 15s scrapeconfigs: metricspath: /metrics staticconfigs: labels: environment: development team: order Meaning: scrapeinterval     collect every 15 seconds
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Static scrape configuration** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Service discovery and relabeling mental model x delivery safety

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service discovery and relabeling mental model** while a change involving **Expert interview answers** places **delivery safety** at risk.
- Plain-language question: What problem does **Service discovery and relabeling mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations. Relabeling then performs target selection and label construction:
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Service discovery and relabeling mental model** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Real-world installation choices x multi-tenancy

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Real-world installation choices** while a change involving **Prometheus in layman language** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Real-world installation choices** solve here, and who notices first when it fails?
- Lesson evidence anchor: Best for learning and quick diagnostics. Best for reproducible local labs. Useful for understanding individual resources but creates maintenance work. Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor,...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Real-world installation choices** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Lab 1 — run Prometheus with Docker x observability

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 1 — run Prometheus with Docker** while a change involving **Lab 2 — inspect health and targets** places **observability** at risk.
- Plain-language question: What problem does **Lab 1 — run Prometheus with Docker** solve here, and who notices first when it fails?
- Lesson evidence anchor: Continue with the observable API from Lesson 15.1. Create directories: mkdir -p module-15/15.2-prometheus/prometheus cd module-15/15.2-prometheus Create prometheus/prometheus.yml: global: scrapeinterval: 5s evaluationinterval: 5s
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 1 — run Prometheus with Docker** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Lab 2 — inspect health and targets x regional resilience

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 2 — inspect health and targets** while a change involving **High availability mental model** places **regional resilience** at risk.
- Plain-language question: What problem does **Lab 2 — inspect health and targets** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://localhost:9090/-/healthy curl -fsS http://localhost:9090/-/ready Open: http://localhost:9090/targets Expected: prometheus → UP order-api  → UP If the API is DOWN, check: Is Lesson 15.1 application running on port 8000?
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 2 — inspect health and targets** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Lab 3 — first PromQL queries x business value

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 3 — first PromQL queries** while a change involving **Kubernetes deployment choice** places **business value** at risk.
- Plain-language question: What problem does **Lab 3 — first PromQL queries** solve here, and who notices first when it fails?
- Lesson evidence anchor: In the Prometheus expression browser, query: up Then: up{job="order-api"} Generate requests against the Lesson 15.1 application, then query: orderapihttprequeststotal Request rate: sum by (route, statusclass) ( rate(orderapihttprequeststotal[1m])
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 3 — first PromQL queries** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Failure lab — wrong metrics path x latency

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure lab — wrong metrics path** while a change involving **Prometheus data locality and limitations** places **latency** at risk.
- Plain-language question: What problem does **Failure lab — wrong metrics path** solve here, and who notices first when it fails?
- Lesson evidence anchor: Change: metricspath: /wrong-metrics Reload by restarting the lab container: docker compose restart prometheus Expected: order-api target DOWN HTTP 404 scrape error up{job="order-api"} == 0 Repair the path and confirm up becomes 1.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — wrong metrics path** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Failure lab — invalid configuration x privacy

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure lab — invalid configuration** while a change involving **Failure lab — wrong metrics path** places **privacy** at risk.
- Plain-language question: What problem does **Failure lab — invalid configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Introduce invalid YAML indentation in a disposable copy. Use the Prometheus image to validate before restart: docker run --rm \ -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \ prom/prometheus:REPLACEWITHREVIEWEDVERSION \
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — invalid configuration** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Kubernetes ServiceMonitor pattern x operability

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Kubernetes ServiceMonitor pattern** while a change involving **Beginner interview answers** places **operability** at risk.
- Plain-language question: What problem does **Kubernetes ServiceMonitor pattern** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: monitoring.coreos.com/v1 kind: ServiceMonitor metadata: name: order-api namespace: monitoring labels: monitoring-stack: platform spec: namespaceSelector: matchNames: [orders-prod] selector: matchLabels: app.kubernetes.io/name: order-api
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes ServiceMonitor pattern** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Production values checklist x data integrity

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production values checklist** while a change involving **Production checklist** places **data integrity** at risk.
- Plain-language question: What problem does **Production values checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before a Helm installation, review values for: exact chart and image versions storage class, size and retention Prometheus replicas Alertmanager replicas requests and limits topology spread/anti-affinity PodDisruptionBudgets
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Production values checklist** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - High availability mental model x automation safety

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **High availability mental model** while a change involving **Real-world installation choices** places **automation safety** at risk.
- Plain-language question: What problem does **High availability mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two Prometheus replicas can scrape the same targets independently. Target ├── scraped by Prometheus A └── scraped by Prometheus B This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **High availability mental model** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Security hardening x governance

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Security hardening** while a change involving **Production values checklist** places **governance** at risk.
- Plain-language question: What problem does **Security hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Metrics can reveal topology, versions, tenant names and business volume. Production controls: private network paths TLS and authenticated scrape where required least-privilege discovery RBAC restricted UI/API SSO through an approved access layer
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Security hardening** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - PCA mapping x correctness

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **PCA mapping** while a change involving **Architecture** places **correctness** at risk.
- Plain-language question: What problem does **PCA mapping** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson maps primarily to: Observability Concepts → push vs pull → service discovery Prometheus Fundamentals → architecture → configuration and scraping → limitations → data model → exposition flow Practice question:
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **PCA mapping** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Beginner interview answers x capacity

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner interview answers** while a change involving **What happens during one scrape** places **capacity** at risk.
- Plain-language question: What problem does **Beginner interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Beginner interview answers** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Expert interview answers x cost efficiency

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Expert interview answers** while a change involving **Lab 3 — first PromQL queries** places **cost efficiency** at risk.
- Plain-language question: What problem does **Expert interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: I run independent replicas that scrape and evaluate the same desired configuration, spread them across failure domains, route queries to healthy replicas, and let Alertmanager coordinate notification deduplication. For global or long-term storage I attach u...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Expert interview answers** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Cleanup and final checklist x recovery

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Cleanup and final checklist** while a change involving **PCA mapping** places **recovery** at risk.
- Plain-language question: What problem does **Cleanup and final checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: docker compose down To remove the disposable metrics volume as well: docker compose down --volumes Removing the volume deletes local lab metrics history. Use it only for this explicitly disposable lab. Final checklist: □ I can explain pull-based scraping
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Cleanup and final checklist** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Architecture x change management

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Architecture** while a change involving **Validation lab** places **change management** at risk.
- Plain-language question: What problem does **Architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters ──scrape──► Prometheus TSDB service discovery ──────────────────────┘ rules ──evaluate──► recording series + alerts alerts ───────────► Alertmanager ──► receivers PromQL ◄────────── Grafana / API / humans
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Architecture** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Kubernetes deployment choice x dependency failure

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Kubernetes deployment choice** while a change involving **Service discovery and relabeling mental model** places **dependency failure** at risk.
- Plain-language question: What problem does **Kubernetes deployment choice** solve here, and who notices first when it fails?
- Lesson evidence anchor: For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes deployment choice** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Discovery objects x developer experience

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Discovery objects** while a change involving **Kubernetes ServiceMonitor pattern** places **developer experience** at risk.
- Plain-language question: What problem does **Discovery objects** solve here, and who notices first when it fails?
- Lesson evidence anchor: With Prometheus Operator: ServiceMonitor → selects Services and named ports PodMonitor     → selects Pods directly Probe          → models black-box probing PrometheusRule → recording and alerting rules apiVersion: monitoring.coreos.com/v1
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Discovery objects** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Validation lab x availability

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Validation lab** while a change involving **Cleanup and final checklist** places **availability** at risk.
- Plain-language question: What problem does **Validation lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: kubectl -n monitoring get pods,pvc kubectl -n monitoring get prometheus,alertmanager kubectl -n monitoring get servicemonitor kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 Query up, inspect Status → Targets, then del...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Validation lab** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Production checklist x security

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Production checklist** while a change involving **Prometheus components step by step** places **security** at risk.
- Plain-language question: What problem does **Production checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ Pinned versions and Git-managed values □ Persistent storage and retention sized □ Prometheus itself monitored □ Rule files validated with promtool □ Authentication and network boundaries defined □ Backup/remote durability decision documented
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Production checklist** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Prometheus in layman language x delivery safety

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus in layman language** while a change involving **Lab 2 — inspect health and targets** places **delivery safety** at risk.
- Plain-language question: What problem does **Prometheus in layman language** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine a school teacher who checks every classroom every 30 seconds: How many students are present? How many computers are working? How many assignments failed? How long did the last activity take? Each classroom displays a small status sheet outside its d...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus in layman language** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Prometheus components step by step x multi-tenancy

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus components step by step** while a change involving **Security hardening** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Prometheus components step by step** solve here, and who notices first when it fails?
- Lesson evidence anchor: The server performs three central jobs: retrieve metric samples store time series evaluate PromQL and rules Discovery finds possible targets from sources such as: static configuration Kubernetes API cloud provider APIs file-based discovery
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus components step by step** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - What happens during one scrape x observability

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **What happens during one scrape** while a change involving **Discovery objects** places **observability** at risk.
- Plain-language question: What problem does **What happens during one scrape** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus automatically provides useful scrape evidence such as: up scrapedurationseconds scrapesamplesscraped scrapesamplespostmetricrelabeling Interpretation: up == 1  last scrape succeeded up == 0  target was discovered, but last scrape failed
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **What happens during one scrape** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Prometheus data locality and limitations x regional resilience

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus data locality and limitations** while a change involving **Static scrape configuration** places **regional resilience** at risk.
- Plain-language question: What problem does **Prometheus data locality and limitations** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data. Professional limitations to understand: one server has finite CPU, memory and disk
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus data locality and limitations** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Static scrape configuration x business value

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Static scrape configuration** while a change involving **Failure lab — invalid configuration** places **business value** at risk.
- Plain-language question: What problem does **Static scrape configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Minimal configuration: global: scrapeinterval: 15s evaluationinterval: 15s scrapeconfigs: metricspath: /metrics staticconfigs: labels: environment: development team: order Meaning: scrapeinterval     collect every 15 seconds
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Static scrape configuration** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Service discovery and relabeling mental model x latency

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Service discovery and relabeling mental model** while a change involving **Expert interview answers** places **latency** at risk.
- Plain-language question: What problem does **Service discovery and relabeling mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations. Relabeling then performs target selection and label construction:
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Service discovery and relabeling mental model** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Real-world installation choices x privacy

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Real-world installation choices** while a change involving **Prometheus in layman language** places **privacy** at risk.
- Plain-language question: What problem does **Real-world installation choices** solve here, and who notices first when it fails?
- Lesson evidence anchor: Best for learning and quick diagnostics. Best for reproducible local labs. Useful for understanding individual resources but creates maintenance work. Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor,...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Real-world installation choices** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Lab 1 — run Prometheus with Docker x operability

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 1 — run Prometheus with Docker** while a change involving **Lab 2 — inspect health and targets** places **operability** at risk.
- Plain-language question: What problem does **Lab 1 — run Prometheus with Docker** solve here, and who notices first when it fails?
- Lesson evidence anchor: Continue with the observable API from Lesson 15.1. Create directories: mkdir -p module-15/15.2-prometheus/prometheus cd module-15/15.2-prometheus Create prometheus/prometheus.yml: global: scrapeinterval: 5s evaluationinterval: 5s
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 1 — run Prometheus with Docker** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Lab 2 — inspect health and targets x data integrity

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 2 — inspect health and targets** while a change involving **High availability mental model** places **data integrity** at risk.
- Plain-language question: What problem does **Lab 2 — inspect health and targets** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://localhost:9090/-/healthy curl -fsS http://localhost:9090/-/ready Open: http://localhost:9090/targets Expected: prometheus → UP order-api  → UP If the API is DOWN, check: Is Lesson 15.1 application running on port 8000?
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 2 — inspect health and targets** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Lab 3 — first PromQL queries x automation safety

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 3 — first PromQL queries** while a change involving **Kubernetes deployment choice** places **automation safety** at risk.
- Plain-language question: What problem does **Lab 3 — first PromQL queries** solve here, and who notices first when it fails?
- Lesson evidence anchor: In the Prometheus expression browser, query: up Then: up{job="order-api"} Generate requests against the Lesson 15.1 application, then query: orderapihttprequeststotal Request rate: sum by (route, statusclass) ( rate(orderapihttprequeststotal[1m])
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 3 — first PromQL queries** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Failure lab — wrong metrics path x governance

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure lab — wrong metrics path** while a change involving **Prometheus data locality and limitations** places **governance** at risk.
- Plain-language question: What problem does **Failure lab — wrong metrics path** solve here, and who notices first when it fails?
- Lesson evidence anchor: Change: metricspath: /wrong-metrics Reload by restarting the lab container: docker compose restart prometheus Expected: order-api target DOWN HTTP 404 scrape error up{job="order-api"} == 0 Repair the path and confirm up becomes 1.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — wrong metrics path** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Failure lab — invalid configuration x correctness

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure lab — invalid configuration** while a change involving **Failure lab — wrong metrics path** places **correctness** at risk.
- Plain-language question: What problem does **Failure lab — invalid configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Introduce invalid YAML indentation in a disposable copy. Use the Prometheus image to validate before restart: docker run --rm \ -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \ prom/prometheus:REPLACEWITHREVIEWEDVERSION \
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — invalid configuration** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - Kubernetes ServiceMonitor pattern x capacity

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Kubernetes ServiceMonitor pattern** while a change involving **Beginner interview answers** places **capacity** at risk.
- Plain-language question: What problem does **Kubernetes ServiceMonitor pattern** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: monitoring.coreos.com/v1 kind: ServiceMonitor metadata: name: order-api namespace: monitoring labels: monitoring-stack: platform spec: namespaceSelector: matchNames: [orders-prod] selector: matchLabels: app.kubernetes.io/name: order-api
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes ServiceMonitor pattern** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - Production values checklist x cost efficiency

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Production values checklist** while a change involving **Production checklist** places **cost efficiency** at risk.
- Plain-language question: What problem does **Production values checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before a Helm installation, review values for: exact chart and image versions storage class, size and retention Prometheus replicas Alertmanager replicas requests and limits topology spread/anti-affinity PodDisruptionBudgets
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Production values checklist** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - High availability mental model x recovery

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **High availability mental model** while a change involving **Real-world installation choices** places **recovery** at risk.
- Plain-language question: What problem does **High availability mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two Prometheus replicas can scrape the same targets independently. Target ├── scraped by Prometheus A └── scraped by Prometheus B This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **High availability mental model** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - Security hardening x change management

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Security hardening** while a change involving **Production values checklist** places **change management** at risk.
- Plain-language question: What problem does **Security hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Metrics can reveal topology, versions, tenant names and business volume. Production controls: private network paths TLS and authenticated scrape where required least-privilege discovery RBAC restricted UI/API SSO through an approved access layer
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Security hardening** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - PCA mapping x dependency failure

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **PCA mapping** while a change involving **Architecture** places **dependency failure** at risk.
- Plain-language question: What problem does **PCA mapping** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson maps primarily to: Observability Concepts → push vs pull → service discovery Prometheus Fundamentals → architecture → configuration and scraping → limitations → data model → exposition flow Practice question:
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **PCA mapping** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Beginner interview answers x developer experience

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Beginner interview answers** while a change involving **What happens during one scrape** places **developer experience** at risk.
- Plain-language question: What problem does **Beginner interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Beginner interview answers** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Expert interview answers x availability

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Expert interview answers** while a change involving **Lab 3 — first PromQL queries** places **availability** at risk.
- Plain-language question: What problem does **Expert interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: I run independent replicas that scrape and evaluate the same desired configuration, spread them across failure domains, route queries to healthy replicas, and let Alertmanager coordinate notification deduplication. For global or long-term storage I attach u...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Expert interview answers** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Cleanup and final checklist x security

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Cleanup and final checklist** while a change involving **PCA mapping** places **security** at risk.
- Plain-language question: What problem does **Cleanup and final checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: docker compose down To remove the disposable metrics volume as well: docker compose down --volumes Removing the volume deletes local lab metrics history. Use it only for this explicitly disposable lab. Final checklist: □ I can explain pull-based scraping
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Cleanup and final checklist** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Architecture x delivery safety

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Architecture** while a change involving **Validation lab** places **delivery safety** at risk.
- Plain-language question: What problem does **Architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: applications/exporters ──scrape──► Prometheus TSDB service discovery ──────────────────────┘ rules ──evaluate──► recording series + alerts alerts ───────────► Alertmanager ──► receivers PromQL ◄────────── Grafana / API / humans
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Architecture** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Kubernetes deployment choice x multi-tenancy

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Kubernetes deployment choice** while a change involving **Service discovery and relabeling mental model** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Kubernetes deployment choice** solve here, and who notices first when it fails?
- Lesson evidence anchor: For production Kubernetes, a maintained monitoring stack normally supplies Prometheus Operator resources, Prometheus, Alertmanager, exporters, and Grafana. Pin a reviewed chart and image digest; do not paste an unversioned install command into production.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes deployment choice** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Discovery objects x observability

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Discovery objects** while a change involving **Kubernetes ServiceMonitor pattern** places **observability** at risk.
- Plain-language question: What problem does **Discovery objects** solve here, and who notices first when it fails?
- Lesson evidence anchor: With Prometheus Operator: ServiceMonitor → selects Services and named ports PodMonitor     → selects Pods directly Probe          → models black-box probing PrometheusRule → recording and alerting rules apiVersion: monitoring.coreos.com/v1
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Discovery objects** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Validation lab x regional resilience

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Validation lab** while a change involving **Cleanup and final checklist** places **regional resilience** at risk.
- Plain-language question: What problem does **Validation lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: kubectl -n monitoring get pods,pvc kubectl -n monitoring get prometheus,alertmanager kubectl -n monitoring get servicemonitor kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 Query up, inspect Status → Targets, then del...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Validation lab** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - Production checklist x business value

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production checklist** while a change involving **Prometheus components step by step** places **business value** at risk.
- Plain-language question: What problem does **Production checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ Pinned versions and Git-managed values □ Persistent storage and retention sized □ Prometheus itself monitored □ Rule files validated with promtool □ Authentication and network boundaries defined □ Backup/remote durability decision documented
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Production checklist** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Prometheus in layman language x latency

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Prometheus in layman language** while a change involving **Lab 2 — inspect health and targets** places **latency** at risk.
- Plain-language question: What problem does **Prometheus in layman language** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine a school teacher who checks every classroom every 30 seconds: How many students are present? How many computers are working? How many assignments failed? How long did the last activity take? Each classroom displays a small status sheet outside its d...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus in layman language** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Prometheus components step by step x privacy

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus components step by step** while a change involving **Security hardening** places **privacy** at risk.
- Plain-language question: What problem does **Prometheus components step by step** solve here, and who notices first when it fails?
- Lesson evidence anchor: The server performs three central jobs: retrieve metric samples store time series evaluate PromQL and rules Discovery finds possible targets from sources such as: static configuration Kubernetes API cloud provider APIs file-based discovery
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus components step by step** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - What happens during one scrape x operability

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **What happens during one scrape** while a change involving **Discovery objects** places **operability** at risk.
- Plain-language question: What problem does **What happens during one scrape** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus automatically provides useful scrape evidence such as: up scrapedurationseconds scrapesamplesscraped scrapesamplespostmetricrelabeling Interpretation: up == 1  last scrape succeeded up == 0  target was discovered, but last scrape failed
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **What happens during one scrape** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Prometheus data locality and limitations x data integrity

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Prometheus data locality and limitations** while a change involving **Static scrape configuration** places **data integrity** at risk.
- Plain-language question: What problem does **Prometheus data locality and limitations** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus stores data locally in its time-series database by default. This makes one server operationally simple and keeps queries close to recent data. Professional limitations to understand: one server has finite CPU, memory and disk
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Prometheus data locality and limitations** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Static scrape configuration x automation safety

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Static scrape configuration** while a change involving **Failure lab — invalid configuration** places **automation safety** at risk.
- Plain-language question: What problem does **Static scrape configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Minimal configuration: global: scrapeinterval: 15s evaluationinterval: 15s scrapeconfigs: metricspath: /metrics staticconfigs: labels: environment: development team: order Meaning: scrapeinterval     collect every 15 seconds
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Static scrape configuration** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Service discovery and relabeling mental model x governance

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service discovery and relabeling mental model** while a change involving **Expert interview answers** places **governance** at risk.
- Plain-language question: What problem does **Service discovery and relabeling mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Kubernetes can create thousands of possible endpoints. Prometheus service discovery attaches metadata labels such as namespace, Service, Pod, node and annotations. Relabeling then performs target selection and label construction:
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Service discovery and relabeling mental model** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - Real-world installation choices x correctness

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Real-world installation choices** while a change involving **Prometheus in layman language** places **correctness** at risk.
- Plain-language question: What problem does **Real-world installation choices** solve here, and who notices first when it fails?
- Lesson evidence anchor: Best for learning and quick diagnostics. Best for reproducible local labs. Useful for understanding individual resources but creates maintenance work. Common in Kubernetes because custom resources model Prometheus, Alertmanager, ServiceMonitor, PodMonitor,...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Real-world installation choices** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - Lab 1 — run Prometheus with Docker x capacity

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 1 — run Prometheus with Docker** while a change involving **Lab 2 — inspect health and targets** places **capacity** at risk.
- Plain-language question: What problem does **Lab 1 — run Prometheus with Docker** solve here, and who notices first when it fails?
- Lesson evidence anchor: Continue with the observable API from Lesson 15.1. Create directories: mkdir -p module-15/15.2-prometheus/prometheus cd module-15/15.2-prometheus Create prometheus/prometheus.yml: global: scrapeinterval: 5s evaluationinterval: 5s
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 1 — run Prometheus with Docker** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Lab 2 — inspect health and targets x cost efficiency

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab 2 — inspect health and targets** while a change involving **High availability mental model** places **cost efficiency** at risk.
- Plain-language question: What problem does **Lab 2 — inspect health and targets** solve here, and who notices first when it fails?
- Lesson evidence anchor: curl -fsS http://localhost:9090/-/healthy curl -fsS http://localhost:9090/-/ready Open: http://localhost:9090/targets Expected: prometheus → UP order-api  → UP If the API is DOWN, check: Is Lesson 15.1 application running on port 8000?
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 2 — inspect health and targets** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Lab 3 — first PromQL queries x recovery

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab 3 — first PromQL queries** while a change involving **Kubernetes deployment choice** places **recovery** at risk.
- Plain-language question: What problem does **Lab 3 — first PromQL queries** solve here, and who notices first when it fails?
- Lesson evidence anchor: In the Prometheus expression browser, query: up Then: up{job="order-api"} Generate requests against the Lesson 15.1 application, then query: orderapihttprequeststotal Request rate: sum by (route, statusclass) ( rate(orderapihttprequeststotal[1m])
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Lab 3 — first PromQL queries** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - Failure lab — wrong metrics path x change management

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure lab — wrong metrics path** while a change involving **Prometheus data locality and limitations** places **change management** at risk.
- Plain-language question: What problem does **Failure lab — wrong metrics path** solve here, and who notices first when it fails?
- Lesson evidence anchor: Change: metricspath: /wrong-metrics Reload by restarting the lab container: docker compose restart prometheus Expected: order-api target DOWN HTTP 404 scrape error up{job="order-api"} == 0 Repair the path and confirm up becomes 1.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — wrong metrics path** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Failure lab — invalid configuration x dependency failure

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure lab — invalid configuration** while a change involving **Failure lab — wrong metrics path** places **dependency failure** at risk.
- Plain-language question: What problem does **Failure lab — invalid configuration** solve here, and who notices first when it fails?
- Lesson evidence anchor: Introduce invalid YAML indentation in a disposable copy. Use the Prometheus image to validate before restart: docker run --rm \ -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \ prom/prometheus:REPLACEWITHREVIEWEDVERSION \
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Failure lab — invalid configuration** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Kubernetes ServiceMonitor pattern x developer experience

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Kubernetes ServiceMonitor pattern** while a change involving **Beginner interview answers** places **developer experience** at risk.
- Plain-language question: What problem does **Kubernetes ServiceMonitor pattern** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: monitoring.coreos.com/v1 kind: ServiceMonitor metadata: name: order-api namespace: monitoring labels: monitoring-stack: platform spec: namespaceSelector: matchNames: [orders-prod] selector: matchLabels: app.kubernetes.io/name: order-api
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes ServiceMonitor pattern** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Production values checklist x availability

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production values checklist** while a change involving **Production checklist** places **availability** at risk.
- Plain-language question: What problem does **Production values checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before a Helm installation, review values for: exact chart and image versions storage class, size and retention Prometheus replicas Alertmanager replicas requests and limits topology spread/anti-affinity PodDisruptionBudgets
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **Production values checklist** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - High availability mental model x security

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **High availability mental model** while a change involving **Real-world installation choices** places **security** at risk.
- Plain-language question: What problem does **High availability mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two Prometheus replicas can scrape the same targets independently. Target ├── scraped by Prometheus A └── scraped by Prometheus B This provides redundant collection/query instances, but also creates duplicate series in a global/remote system unless queries...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **High availability mental model** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Security hardening x delivery safety

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Security hardening** while a change involving **Production values checklist** places **delivery safety** at risk.
- Plain-language question: What problem does **Security hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Metrics can reveal topology, versions, tenant names and business volume. Production controls: private network paths TLS and authenticated scrape where required least-privilege discovery RBAC restricted UI/API SSO through an approved access layer
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a PromQL, LogQL, or TraceQL investigation and link it to this practice case ID.
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
- Interview prompt: Defend **Security hardening** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - PCA mapping x multi-tenancy

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **PCA mapping** while a change involving **Architecture** places **multi-tenancy** at risk.
- Plain-language question: What problem does **PCA mapping** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson maps primarily to: Observability Concepts → push vs pull → service discovery Prometheus Fundamentals → architecture → configuration and scraping → limitations → data model → exposition flow Practice question:
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a dashboard, recording rule, alert, and runbook and link it to this practice case ID.
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
- Interview prompt: Defend **PCA mapping** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Beginner interview answers x observability

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner interview answers** while a change involving **What happens during one scrape** places **observability** at risk.
- Plain-language question: What problem does **Beginner interview answers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prometheus is a time-series monitoring and alerting system. It discovers targets, normally pulls metrics over HTTP, stores labeled samples, evaluates PromQL and recording/alerting rules, and sends alerts to Alertmanager.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an end-to-end signal and notification canary and link it to this practice case ID.
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
- Interview prompt: Defend **Beginner interview answers** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 98.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://prometheus.io/docs/introduction/overview/ "Prometheus Overview"
[2]: https://prometheus.io/docs/prometheus/latest/getting_started/ "Getting Started with Prometheus"
[3]: https://prometheus.io/docs/prometheus/latest/configuration/configuration/ "Prometheus Configuration"
[4]: https://prometheus.io/docs/prometheus/latest/storage/ "Prometheus Storage"
[5]: https://prometheus-operator.dev/docs/getting-started/introduction/ "Prometheus Operator Introduction"
