# AWS Masterclass — Phase 3

# Lesson 38: CloudWatch, CloudTrail, AWS Config, X-Ray and OpenTelemetry

## 1. Lesson objectives

By the end of this lesson, you will be able to:

* Distinguish monitoring, observability, auditing and compliance.
* Design metrics, logs and distributed traces.
* Build meaningful CloudWatch dashboards and alarms.
* Collect operating-system and application telemetry.
* Use CloudWatch Logs Insights for production troubleshooting.
* Understand CloudWatch Application Signals, SLOs, RUM and Synthetics.
* Use CloudTrail for AWS API and security auditing.
* Record management, data and network activity events.
* Use AWS Config for configuration history and compliance.
* Automate remediation using Config and Systems Manager.
* Instrument applications using OpenTelemetry.
* Understand the current AWS X-Ray SDK support position.
* Centralize observability across AWS accounts.
* Troubleshoot missing metrics, logs, traces and audit events.
* Implement observability resources using Terraform.

---

# 2. Monitoring versus observability

## Monitoring

Monitoring answers questions that you already know to ask.

```text
Is CPU greater than 80%?
Is the ALB returning 5xx errors?
Is the disk almost full?
Is the application endpoint unavailable?
```

## Observability

Observability helps you investigate unknown problems using system outputs.

```text
Why are checkout requests slow only for some users?

Which downstream service caused the latency?

Did the problem begin after a deployment?

Which customer requests were affected?

Was the failure caused by code, network, database or AWS configuration?
```

## Audit

Audit answers:

```text
Who performed the action?
What action was performed?
When was it performed?
From which identity and IP address?
Which resource was changed?
```

## Compliance

Compliance answers:

```text
Does the resource match the required configuration?

Is encryption enabled?

Is public access blocked?

Is CloudTrail enabled?

Does the security group violate policy?
```

## AWS service mapping

```text
CloudWatch:
Performance and operational observability

CloudTrail:
AWS API and account activity auditing

AWS Config:
Resource configuration history and compliance

X-Ray/OpenTelemetry:
Distributed request tracing
```

CloudWatch concentrates on metrics, logs, traces and operational behavior, while CloudTrail records AWS account and API activity. AWS Config records resource configurations, relationships and changes over time. ([AWS Documentation][1])

---

# 3. The three pillars of observability

The traditional observability pillars are:

```text
Metrics
Logs
Traces
```

## Metrics

Numerical measurements over time.

```text
CPUUtilization = 72%
RequestCount = 4,500
ErrorRate = 2.1%
ResponseTimeP95 = 820 ms
```

## Logs

Detailed event records.

```json
{
  "timestamp": "2026-07-28T01:15:02+05:30",
  "level": "ERROR",
  "service": "todo-api",
  "requestId": "req-104",
  "message": "Database connection timed out"
}
```

## Traces

The complete path of one request through distributed services.

```text
Browser
  ↓ 20 ms
CloudFront
  ↓ 15 ms
ALB
  ↓ 40 ms
Todo API
  ↓ 700 ms
PostgreSQL
```

CloudWatch now provides native OpenTelemetry Protocol endpoints for metrics, logs and traces, allowing OpenTelemetry-compatible SDKs and collectors to send telemetry using open standards. ([AWS Documentation][2])

---

# 4. Production observability architecture

```text
Users
  |
  v
CloudFront
  |
  v
Application Load Balancer
  |
  v
ECS / EC2 / EKS / Lambda
  |
  ├── Metrics ────────> CloudWatch Metrics
  |
  ├── Logs ───────────> CloudWatch Logs
  |
  └── OTLP traces ────> CloudWatch / X-Ray
                           |
                           v
                   Application Signals
                           |
          ┌────────────────┼────────────────┐
          |                |                |
          v                v                v
      Dashboards        Alarms           SLOs
          |                |                |
          └────────────────┼────────────────┘
                           v
                SNS / Incident Manager
```

Security and compliance telemetry follows a separate path:

```text
AWS API activity
      |
      v
CloudTrail organization trail
      |
      v
Log Archive S3 bucket

Resource configuration changes
      |
      v
AWS Config
      |
      v
Organization aggregator
      |
      v
Security/Audit account
```

---

# 5. Amazon CloudWatch

Amazon CloudWatch is AWS’s monitoring and observability service.

It includes capabilities such as:

* Metrics.
* Alarms.
* Dashboards.
* Logs.
* Logs Insights.
* Application Signals.
* Container Insights.
* Database Insights.
* Synthetics.
* Real User Monitoring.
* Service-level objectives.
* Cross-account observability.
* OpenTelemetry ingestion.

CloudWatch provides managed monitoring infrastructure without requiring you to operate your own metrics, logging and tracing backends. ([AWS Documentation][3])

---

# 6. CloudWatch metric anatomy

A CloudWatch metric is identified by several properties.

```text
Namespace
Metric name
Dimensions
Timestamp
Value
Unit
Resolution
```

Example:

```text
Namespace:
AWS/EC2

Metric:
CPUUtilization

Dimension:
InstanceId=i-0123456789abcdef0

Unit:
Percent
```

## Namespace

A logical container for metrics.

AWS namespaces:

```text
AWS/EC2
AWS/RDS
AWS/ApplicationELB
AWS/Lambda
AWS/ECS
```

Custom namespace:

```text
TodoApp/Production
```

## Dimensions

Dimensions identify the resource or context to which the metric belongs.

```text
InstanceId = i-123
LoadBalancer = app/todo-alb/123
ServiceName = todo-api
Environment = production
```

Each unique metric name and dimension combination is treated as a separate metric identity. ([AWS Documentation][4])

---

# 7. Metric cardinality

Cardinality means the number of unique dimension combinations.

Low-cardinality dimensions:

```text
Environment:
production, staging, development

Operation:
CreateTodo, GetTodos, DeleteTodo

Status:
success, failure
```

High-cardinality dimensions:

```text
RequestId
UserId
SessionId
OrderId
Timestamp
```

Bad custom metric:

```text
Metric:
RequestLatency

Dimension:
RequestId=req-000001
```

Every request can create a separate billable metric identity.

Better:

```text
Metric:
RequestLatency

Dimensions:
Service=todo-api
Operation=GetTodos
Environment=production
```

Keep request IDs and user IDs in logs or traces, not as normal metric dimensions. AWS warns that Embedded Metric Format and custom metrics can generate a separate metric for every unique high-cardinality dimension combination. ([AWS Documentation][5])

---

# 8. Metric statistics

Common statistics include:

```text
Average
Minimum
Maximum
Sum
SampleCount
Percentiles
```

## Average

Useful for general utilization:

```text
Average CPU over five minutes
```

But average can hide spikes.

```text
Requests:
100 ms
100 ms
100 ms
5,000 ms

Average:
1,325 ms
```

Most users were fast, but one request was extremely slow.

## Percentiles

```text
p50:
50% of requests completed at or below this value

p95:
95% completed at or below this value

p99:
99% completed at or below this value
```

For customer-facing latency, p95 and p99 are often more useful than average.

---

# 9. Period and evaluation window

A metric period is the interval used to aggregate data.

```text
Period:
1 minute

Statistic:
Average
```

An alarm might evaluate:

```text
CPUUtilization > 80%
for 3 of the last 5 periods
```

Mental model:

```text
Period:
Size of each measurement window

Evaluation periods:
How many recent windows are examined

Datapoints to alarm:
How many must breach
```

Example:

```text
Period = 1 minute
Evaluation periods = 5
Datapoints to alarm = 3
```

Meaning:

```text
Alarm when at least 3 of the latest 5
one-minute datapoints breach the threshold.
```

---

# 10. CloudWatch alarm states

A metric alarm has three main states:

```text
OK
ALARM
INSUFFICIENT_DATA
```

## `OK`

The alarm condition is not currently breached.

## `ALARM`

The configured threshold logic is breached.

## `INSUFFICIENT_DATA`

CloudWatch does not have enough appropriate datapoints to determine the state.

Do not assume:

```text
INSUFFICIENT_DATA = healthy
```

It may mean:

* The application stopped publishing metrics.
* The resource was deleted.
* The agent failed.
* Dimensions changed.
* The metric is delayed.
* The alarm is newly created.

---

# 11. Missing data behavior

CloudWatch alarms can treat missing datapoints as:

```text
Breaching
Not breaching
Ignore
Missing
```

Choose based on metric semantics.

## Endpoint heartbeat

```text
Metric:
ApplicationHeartbeat

Missing data:
Breaching
```

If heartbeat publishing stops, alert.

## Error count

```text
Metric:
FatalErrorCount

Missing data:
Not breaching
```

No error metric may mean no errors occurred.

Incorrect missing-data configuration causes false alarms or hidden outages.

---

# 12. Static alarms

A static alarm compares a metric with a fixed threshold.

```text
ALB TargetResponseTime p95 > 1 second
```

Suitable when:

* The threshold has business meaning.
* The metric has a predictable safe range.
* Capacity limits are known.

Examples:

```text
Disk usage > 85%
Database connections > 90% of limit
ALB unhealthy hosts > 0
SQS oldest message age > 300 seconds
```

---

# 13. Anomaly detection

CloudWatch anomaly detection builds a model of expected metric behavior and identifies values outside the expected band.

Useful for:

* Seasonal traffic.
* Day/night request patterns.
* Weekly workload changes.
* Metrics without one useful fixed threshold.

Example:

```text
Normal Monday traffic:
10,000 requests/minute

Normal Sunday traffic:
1,000 requests/minute
```

A fixed threshold may alert unnecessarily or miss important deviations.

Anomaly detection can be used on metrics from linked source accounts in a CloudWatch cross-account monitoring account. ([AWS Documentation][6])

---

# 14. Composite alarms

A composite alarm combines other alarm states.

Example:

```text
ApplicationUnavailable =
ALBUnhealthyHosts
AND
High5xxRate
AND NOT
DeploymentInProgress
```

Advantages:

* Reduces notification noise.
* Groups related symptoms.
* Avoids paging during approved maintenance.
* Separates component alarms from incident alarms.

Composite alarms can send notifications and trigger operational incident workflows, while the underlying alarms continue tracking individual conditions. ([AWS Documentation][7])

---

# 15. Symptom alarms versus cause alarms

## Cause alarm

```text
EC2 CPU > 90%
```

## Symptom alarm

```text
Todo API successful-request rate < 99%
```

Cause metrics do not always indicate customer impact.

For example:

```text
CPU = 95%
Application latency = normal
```

Paging on CPU may be unnecessary.

Better paging strategy:

```text
Page:
Customer-facing symptoms

Create ticket:
Infrastructure-warning conditions
```

---

# 16. The RED and USE methods

## RED method for services

```text
Rate
Errors
Duration
```

For an API:

```text
Rate:
Requests per second

Errors:
Failed request percentage

Duration:
p50, p95 and p99 latency
```

## USE method for infrastructure

```text
Utilization
Saturation
Errors
```

For EBS:

```text
Utilization:
Consumed throughput

Saturation:
Queue depth

Errors:
Failed I/O
```

For CPU:

```text
Utilization:
CPU percentage

Saturation:
Run queue or throttling

Errors:
Hardware or kernel errors
```

---

# 17. Custom metrics

Applications can publish custom metrics using:

* `PutMetricData`.
* Embedded Metric Format.
* OpenTelemetry.
* CloudWatch Agent.
* StatsD.
* Prometheus-compatible collection.

CLI example:

```bash
aws cloudwatch put-metric-data \
  --namespace TodoApp/Production \
  --metric-name TodoCreated \
  --dimensions Service=todo-api,Environment=production \
  --value 1 \
  --unit Count \
  --region ap-south-1
```

Use custom metrics for business and application signals such as:

```text
TodosCreated
PaymentFailures
ActiveUsers
QueueProcessingLatency
FailedLogins
DocumentProcessingDuration
```

---

# 18. Embedded Metric Format

Embedded Metric Format, or EMF, lets an application send structured JSON logs containing metric definitions.

Example:

```json
{
  "_aws": {
    "Timestamp": 1785181502000,
    "CloudWatchMetrics": [
      {
        "Namespace": "TodoApp/Production",
        "Dimensions": [
          ["Service", "Operation"]
        ],
        "Metrics": [
          {
            "Name": "Latency",
            "Unit": "Milliseconds"
          },
          {
            "Name": "Errors",
            "Unit": "Count"
          }
        ]
      }
    ]
  },
  "Service": "todo-api",
  "Operation": "GetTodos",
  "Latency": 182,
  "Errors": 0,
  "requestId": "req-104"
}
```

CloudWatch extracts the defined metrics while retaining detailed contextual fields such as `requestId` in the log event. This lets you alarm on low-cardinality metrics while querying high-cardinality context in logs. ([AWS Documentation][8])

---

# 19. CloudWatch Agent

The CloudWatch Agent can collect:

* Memory usage.
* Disk usage.
* Swap.
* Processes.
* Network metrics.
* Log files.
* OpenTelemetry metrics.
* OpenTelemetry traces.
* X-Ray-compatible traces.

Default EC2 metrics do not include detailed guest-operating-system information such as memory and filesystem utilization, so an agent or another telemetry collector is required for those measurements. The current CloudWatch Agent can collect metrics, logs and traces and is built around OpenTelemetry Collector capabilities. ([AWS Documentation][9])

## Architecture

```text
EC2 operating system
       |
       | Host metrics and logs
       v
CloudWatch Agent
       |
       ├── CloudWatch Metrics
       ├── CloudWatch Logs
       └── X-Ray/OTLP trace destination
```

---

# 20. CloudWatch Agent configuration example

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "TodoApp/Host",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "resources": [
          "/"
        ]
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/todoapp/application.log",
            "log_group_name": "/production/todoapp/application",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
          }
        ]
      }
    }
  }
}
```

Store configuration in Systems Manager Parameter Store so fleets receive a consistent version.

---

# 21. CloudWatch Logs structure

CloudWatch Logs uses:

```text
Log group
Log stream
Log event
```

Example:

```text
Log group:
/production/todoapp/api

Log stream:
ecs/todo-api/task-104

Log event:
2026-07-28 ERROR Database timeout
```

## Log group

Represents an application, component or log category.

## Log stream

Represents one source, process, task, instance or container.

## Log event

One timestamped record.

CloudWatch Logs supports Standard and Infrequent Access classes for general log storage, plus a specialized Delivery class for supported Lambda log-delivery workflows. ([AWS Documentation][10])

---

# 22. Log-class selection

## Standard

Use for:

* Production application logs.
* Live troubleshooting.
* Metric filters.
* Subscription filters.
* Frequent Logs Insights queries.
* Logs requiring the full feature set.

## Infrequent Access

Use for:

* Compliance logs rarely queried.
* Historical operational logs.
* Logs retained mainly for investigation.

The Infrequent Access class has lower ingestion costs but supports a subset of Standard features. Some Logs Insights commands are not supported for IA log groups. ([AWS Documentation][10])

## Intelligent Tiering

CloudWatch Logs Intelligent Tiering can automatically classify log data among Standard, Infrequent Access and Archive Instant Access tiers according to access patterns. Current documentation describes movement to IA after 30 days without access and Archive Instant Access after 90 days without access. ([AWS Documentation][11])

---

# 23. Log retention

Never leave retention undefined accidentally.

Potential policy:

```text
Development application logs:
14 days

Production operational logs:
90 days

Security logs:
1 year or compliance requirement

Immutable audit archive:
S3 with long-term lifecycle
```

Without retention configuration, log storage can continue growing.

For long-term economical archival:

```text
CloudWatch Logs
      |
      | Subscription or export pipeline
      v
Amazon S3
      |
      v
Glacier lifecycle
```

---

# 24. Structured logging

Avoid plain unstructured messages:

```text
Database failed
```

Prefer structured JSON:

```json
{
  "timestamp": "2026-07-28T01:15:02+05:30",
  "level": "ERROR",
  "service": "todo-api",
  "environment": "production",
  "operation": "GetTodos",
  "requestId": "req-104",
  "traceId": "1-abcdef",
  "errorType": "DatabaseTimeout",
  "durationMs": 3012,
  "message": "Database query exceeded timeout"
}
```

Structured logs make filtering and aggregation significantly easier.

---

# 25. Sensitive-data logging

Never log:

```text
Passwords
Access keys
Session tokens
Full authorization headers
Database connection strings with passwords
Private keys
Full payment-card data
Unredacted personal information
Secrets Manager values
```

Implement redaction before log emission.

Bad:

```javascript
logger.info({ requestHeaders: req.headers });
```

This may capture:

```text
Authorization: Bearer ...
Cookie: ...
```

Better:

```javascript
const safeHeaders = {
  "user-agent": req.headers["user-agent"],
  "content-type": req.headers["content-type"]
};

logger.info({ requestId, headers: safeHeaders });
```

---

# 26. CloudWatch Logs Insights

Logs Insights provides an interactive query language for analyzing CloudWatch Logs.

Example:

```sql
fields @timestamp, level, operation, durationMs, message
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

Find slow operations:

```sql
fields operation, durationMs
| filter durationMs > 1000
| stats count(*) as requests,
        avg(durationMs) as average,
        pct(durationMs, 95) as p95
  by operation
| sort p95 desc
```

Find error rate over time:

```sql
filter level = "ERROR"
| stats count(*) as errors by bin(5m)
```

---

# 27. Correlating logs

Use shared correlation fields across services:

```text
requestId
traceId
userSessionId
operation
deploymentVersion
```

Example:

```text
Frontend log:
requestId=req-104

API log:
requestId=req-104

Worker log:
requestId=req-104

Trace:
traceId=abc-123
```

This lets engineers follow one business request across multiple systems.

---

# 28. Metric filters and log alarms

A metric filter converts matching log events into a CloudWatch metric.

Example pattern:

```text
"DatabaseTimeout"
```

Metric:

```text
TodoApp/Errors
DatabaseTimeoutCount
```

CloudWatch can graph and alarm on the extracted metric. High-cardinality dimensions must be avoided because every unique dimension set creates another metric identity. ([AWS Documentation][12])

CloudWatch also supports log alarms that evaluate Logs Insights queries directly on a schedule, avoiding the need to create an intermediate metric filter for every use case. ([AWS Documentation][13])

---

# 29. Logs subscription pipeline

CloudWatch Logs subscription filters can stream events to destinations such as:

```text
Lambda
Kinesis Data Streams
Amazon Data Firehose
```

Example:

```text
Application accounts
       |
       v
CloudWatch Logs
       |
       | Subscription
       v
Data Firehose
       |
       ├── Central S3 archive
       └── OpenSearch analytics
```

Use subscriptions for centralized security analysis, log transformation and long-term archival.

---

# 30. Container Insights

CloudWatch Container Insights collects and aggregates container-level telemetry.

For Kubernetes environments it can provide metrics at:

```text
Cluster
Node
Namespace
Workload
Pod
Container
```

For ECS it provides task- and service-related views.

Container Insights uses CloudWatch agents or containerized collectors to discover and collect container telemetry. ([AWS Documentation][14])

Monitor:

```text
CPU and memory utilization
Pod restarts
Pending pods
Node capacity
Network activity
Task counts
Container failures
```

---

# 31. Application Signals

CloudWatch Application Signals provides an application-centric view of:

* Services.
* Operations.
* Dependencies.
* Request volume.
* Faults.
* Errors.
* Latency.
* Service maps.
* Service-level objectives.

It can automatically collect application telemetry for supported workloads on services such as EC2, ECS, EKS and Lambda using OpenTelemetry-based instrumentation. ([AWS Documentation][15])

```text
Application
├── Web client
├── Todo API
├── Authentication service
├── PostgreSQL dependency
└── External email provider
```

Application Signals turns infrastructure telemetry into a service-oriented operational view.

---

# 32. Service maps

A service map shows relationships between services and dependencies.

```text
CloudWatch Synthetics
        |
        v
CloudFront
        |
        v
Todo API
   |         |
   v         v
PostgreSQL  SQS
              |
              v
           Worker
```

A service map can reveal:

* Which dependency is failing.
* Which services call one another.
* Where latency is introduced.
* Which downstream failure affects customers.

Application Signals integrates service topology with Synthetics, RUM, traces and SLO status. ([AWS Documentation][16])

---

# 33. Service-level indicators and objectives

## SLI

A Service-Level Indicator is the measured reliability value.

Examples:

```text
Availability:
Successful requests / total requests

Latency:
Percentage of requests below 500 ms
```

## SLO

A Service-Level Objective is the desired target.

```text
99.9% successful requests
over a rolling 30-day period
```

## Error budget

```text
Error budget =
100% - SLO
```

For a `99.9%` availability SLO:

```text
Allowed failure:
0.1%
```

CloudWatch SLOs can be based on Application Signals services, RUM monitors, Synthetics canaries and suitable CloudWatch metrics. ([AWS Documentation][17])

---

# 34. Burn-rate alerting

An error-budget burn rate tells you how quickly the allowed failure budget is being consumed.

Example:

```text
Monthly error budget:
43 minutes

Current outage:
Consuming budget at 20 times expected rate
```

Use multiple windows:

```text
Fast burn:
Page immediately

Slow burn:
Create investigation or ticket
```

This is often more meaningful than alerting on every temporary error spike.

---

# 35. CloudWatch Synthetics

CloudWatch Synthetics uses scripted canaries to test endpoints and user workflows.

Examples:

```text
GET homepage
Call health API
Log in
Create a todo
Verify page content
Check TLS certificate behavior
```

A canary runs on a schedule even when no real user is active.

Architecture:

```text
Synthetics canary
      |
      v
CloudFront / API / Website
      |
      v
Availability and latency results
```

CloudWatch Synthetics canaries proactively detect endpoint and API availability or performance degradation and can integrate with Application Signals and SLOs. ([AWS Documentation][18])

---

# 36. Real User Monitoring

CloudWatch RUM collects client-side performance information from actual users.

It can measure:

* Page-load performance.
* JavaScript errors.
* HTTP errors.
* User sessions.
* Browser and device characteristics.
* Geographic performance.
* Core web experience data.
* Client-to-service traces.

RUM complements Synthetics:

```text
Synthetics:
Controlled simulated users

RUM:
Actual user sessions
```

CloudWatch RUM collects near-real-time client-side data and integrates with Application Signals and X-Ray tracing for end-to-end investigation. ([AWS Documentation][19])

---

# 37. AWS X-Ray concepts

Distributed tracing uses:

```text
Trace
Span
Parent-child relationship
Attributes
Events
Status
```

## Trace

The complete lifecycle of one request.

## Span

One unit of work.

```text
HTTP request
Database query
AWS SDK operation
Queue publication
```

Example:

```text
Trace: CreateTodo
│
├── Span: ALB request
├── Span: Express handler
├── Span: Validate request
├── Span: MongoDB insert
└── Span: Publish event
```

AWS X-Ray continues to receive, process and display trace data from instrumented applications and integrated AWS services. ([AWS Documentation][20])

---

# 38. Current X-Ray SDK status

As of July 2026, the legacy AWS X-Ray SDKs and X-Ray daemon are in maintenance mode.

AWS entered maintenance mode on **February 25, 2026**. Security fixes continue, but new feature development is focused on OpenTelemetry-based instrumentation. AWS recommends migrating application instrumentation to OpenTelemetry. ([AWS Documentation][21])

## Recommended direction

```text
Legacy:
X-Ray SDK + X-Ray daemon

Preferred:
OpenTelemetry SDK or automatic instrumentation
        +
CloudWatch Agent or OpenTelemetry Collector
        +
CloudWatch/X-Ray backend
```

Existing X-Ray-instrumented applications continue to work, but new applications should generally begin with OpenTelemetry.

---

# 39. OpenTelemetry

OpenTelemetry is a vendor-neutral collection of:

* APIs.
* SDKs.
* Semantic conventions.
* Instrumentation libraries.
* Collector components.
* OTLP telemetry protocol.

It supports:

```text
Metrics
Logs
Traces
```

AWS Distro for OpenTelemetry, or ADOT, provides AWS-supported OpenTelemetry components for collecting and exporting telemetry to AWS and other observability systems. ([GitHub][22])

---

# 40. OpenTelemetry architecture

```text
Application
    |
    | OpenTelemetry SDK
    v
Instrumentation
    |
    | OTLP
    v
Collector / CloudWatch Agent
    |
    ├── CloudWatch Metrics
    ├── CloudWatch Logs
    ├── AWS X-Ray
    ├── Managed Prometheus
    └── Third-party platform
```

Using OpenTelemetry reduces dependency on proprietary application instrumentation.

You can change or add telemetry backends without fully rewriting application instrumentation.

---

# 41. Collector versus collector-less

## Collector-based

```text
Application
   |
   v
Local or sidecar Collector
   |
   v
AWS telemetry endpoints
```

Advantages:

* Batching.
* Retries.
* Filtering.
* Attribute enrichment.
* Sampling.
* Multiple exporters.
* Credential separation.

## Collector-less

```text
Application ADOT SDK
   |
   v
CloudWatch OTLP endpoint
```

This reduces infrastructure components but places more export responsibility inside the application.

AWS supports collector-less telemetry through ADOT SDKs as well as upstream or AWS-supported collectors. ([AWS Documentation][23])

---

# 42. Trace-context propagation

Every service must propagate trace context.

```text
Frontend
   |
   | traceparent header
   v
API
   |
   | trace context
   v
Worker / database / downstream API
```

If one service drops the context:

```text
One logical request
        ↓
Several disconnected traces
```

For asynchronous queues, propagate trace information in:

* Message attributes.
* Event metadata.
* Supported OpenTelemetry propagation fields.

---

# 43. Sampling

Recording every trace can be expensive and unnecessary at high request volume.

## Head sampling

Decision occurs when the trace begins.

```text
Sample 5% of all requests
```

Simple and low overhead, but rare failures may be missed.

## Tail sampling

Decision occurs after trace information has been collected.

```text
Keep:
100% errors
100% slow requests
5% normal requests
```

More intelligent but requires collector capacity to retain spans while deciding.

The current CloudWatch Agent’s OpenTelemetry-based pipeline supports processors such as probabilistic and tail sampling. ([AWS Documentation][24])

---

# 44. OpenTelemetry Node.js example

Install:

```bash
npm install \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http
```

Instrumentation file:

```javascript
// instrumentation.mjs
import { NodeSDK } from "@opentelemetry/sdk-node";
import {
  getNodeAutoInstrumentations
} from "@opentelemetry/auto-instrumentations-node";
import {
  OTLPTraceExporter
} from "@opentelemetry/exporter-trace-otlp-http";
import { resourceFromAttributes } from "@opentelemetry/resources";

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    "service.name": "todo-api",
    "service.version": process.env.APP_VERSION ?? "unknown",
    "deployment.environment.name":
      process.env.NODE_ENV ?? "development"
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
  }),
  instrumentations: [
    getNodeAutoInstrumentations()
  ]
});

sdk.start();

async function shutdown() {
  await sdk.shutdown();
  process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
```

Start application:

```bash
node --import ./instrumentation.mjs start.js
```

Configure the endpoint toward the CloudWatch Agent, ADOT Collector or a supported CloudWatch OTLP endpoint.

---

# 45. CloudTrail

CloudTrail records AWS account activity generated through:

* AWS Management Console.
* AWS CLI.
* AWS SDKs.
* AWS APIs.
* AWS service actions.

CloudTrail helps answer:

```text
Who deleted the instance?
Who changed the security group?
Who attached AdministratorAccess?
Who disabled logging?
Which IP address performed the action?
```

CloudTrail is enabled by default for account Event History, which provides the latest 90 days of management events on a per-Region basis. For an ongoing record, create a trail. ([AWS Documentation][25])

---

# 46. CloudTrail event categories

Important event categories include:

```text
Management events
Data events
Network activity events
Insights events
```

## Management events

Control-plane operations.

Examples:

```text
RunInstances
CreateBucket
PutRolePolicy
ModifyDBInstance
CreateSecurityGroup
```

## Data events

High-volume resource-level operations.

Examples:

```text
S3 GetObject
S3 PutObject
Lambda Invoke
DynamoDB PutItem
```

## Network activity events

Records supported AWS API activity traversing VPC endpoints, helping investigate whether API calls were allowed or denied through the private network path.

## Insights events

Identify unusual API-call or API-error activity compared with established behavior. ([AWS Documentation][26])

---

# 47. CloudTrail Event History limitations

Event History:

* Contains management events.
* Covers the most recent 90 days.
* Is viewed separately per Region.
* Does not show data events.
* Does not show network activity events.
* Does not show Insights events.

Create a trail for durable delivery to S3 and optional CloudWatch Logs. ([AWS Documentation][25])

---

# 48. Organization trail

In an AWS Organizations environment, create an organization trail.

```text
Management account or delegated setup
        |
        v
Organization trail
        |
        ├── Management account events
        ├── Production accounts
        ├── Development accounts
        └── Security accounts
                |
                v
        Central Log Archive S3 bucket
```

A multi-Region organization trail provides centralized delivery for member-account activity across enabled Regions. Opt-in Region behavior depends on the trail’s home Region and whether member accounts have enabled the relevant Region. ([AWS Documentation][27])

---

# 49. CloudTrail data-event cost control

Data events can be extremely high volume.

Bad configuration:

```text
Log every GetObject operation
for every S3 bucket
in every account
```

Better:

```text
Log:
Write events for production data bucket

Log:
Read and write events for sensitive audit bucket

Exclude:
High-volume internal scanning role
```

Advanced event selectors can filter data events using fields such as resource ARN, event name, read/write status and calling identity, helping control event volume and cost. ([AWS Documentation][28])

---

# 50. CloudTrail event structure

A CloudTrail event can include:

```json
{
  "eventTime": "2026-07-28T00:15:00Z",
  "eventSource": "ec2.amazonaws.com",
  "eventName": "TerminateInstances",
  "awsRegion": "ap-south-1",
  "sourceIPAddress": "203.0.113.10",
  "userAgent": "aws-cli/2.x",
  "userIdentity": {
    "type": "AssumedRole",
    "arn": "arn:aws:sts::123456789012:assumed-role/ProductionAdmin/vivek"
  },
  "requestParameters": {
    "instancesSet": {
      "items": [
        {
          "instanceId": "i-0123456789abcdef0"
        }
      ]
    }
  }
}
```

Important investigation fields:

```text
eventTime
eventSource
eventName
userIdentity
sourceIPAddress
userAgent
requestParameters
responseElements
errorCode
errorMessage
resources
```

CloudTrail event record content differs slightly according to event category, but these fields form the core audit context. ([AWS Documentation][29])

---

# 51. CloudTrail to CloudWatch Logs

A trail can send events to:

```text
Amazon S3:
Long-term durable audit record

CloudWatch Logs:
Near-real-time searching, filters and alarms
```

Example alerts:

```text
Root user login
Unauthorized API calls
CloudTrail stopped
Security group opened to 0.0.0.0/0
IAM policy changed
KMS key scheduled for deletion
AWS account left organization
```

CloudTrail trails can deliver to S3, CloudWatch Logs and SNS-based delivery notifications. ([AWS Documentation][30])

---

# 52. CloudTrail Insights

CloudTrail Insights detects unusual patterns such as:

* Unexpected API call-rate spikes.
* Unexpected API error-rate spikes.

Example:

```text
Normal:
2 RunInstances calls/day

Anomaly:
500 RunInstances calls in 10 minutes
```

Insights uses a baseline of normal activity and generates an event when activity deviates significantly. Data-event Insights are supported on trails, while event-data-store support differs. ([AWS Documentation][31])

---

# 53. CloudTrail Lake availability update

CloudTrail Lake provides SQL-based analysis of event data stores.

However, as of **May 31, 2026**, CloudTrail Lake is no longer open to new customers. Existing CloudTrail Lake customers can continue using it normally. New architectures should not assume that Lake can be newly activated. ([AWS Documentation][32])

For a new environment, evaluate:

```text
CloudTrail trails
       |
       v
Amazon S3
       |
       v
Athena / Glue / security analytics pipeline
```

Existing CloudTrail Lake customers may continue querying their event data stores.

---

# 54. CloudTrail is not an application logger

CloudTrail does not record:

```text
User clicked “Create Todo”
Database query took 800 ms
Node.js process ran out of memory
HTTP response returned 500
```

It records AWS activity such as:

```text
Lambda Invoke
PutObject
RunInstances
CreateRole
```

Use CloudWatch application logs and OpenTelemetry for application behavior.

---

# 55. AWS Config

AWS Config records resource configuration and relationships over time.

Example:

```text
Security group yesterday:
Port 22 allowed from corporate IP

Security group today:
Port 22 allowed from 0.0.0.0/0
```

AWS Config can show:

* Current configuration.
* Historical configuration.
* Resource relationships.
* Compliance state.
* Configuration timeline.

AWS Config provides a detailed view of AWS resource configuration and how relationships and properties changed over time. ([AWS Documentation][33])

---

# 56. CloudTrail versus Config

Suppose a security group changed.

CloudTrail answers:

```text
Who called AuthorizeSecurityGroupIngress?
When?
From which IP?
Using which role?
```

AWS Config answers:

```text
What did the security group look like before?
What does it look like now?
Is the current state compliant?
Which resources are related to it?
```

Use both during investigations.

---

# 57. Configuration recorder

AWS Config uses a configuration recorder to record supported resource types.

Recording strategies can include:

* Continuous recording.
* Daily recording for selected use cases.
* All supported resource types.
* Selected resource types.
* Exclusion of noisy ephemeral resource types.

Continuous recording gives detailed change history, while daily recording may reduce costs where one daily configuration view is sufficient. AWS notes that high-churn ephemeral resources can increase configuration-recording activity and cost. ([AWS Documentation][34])

---

# 58. AWS Config rules

A Config rule evaluates whether resource configurations satisfy a requirement.

Examples:

```text
S3 bucket public access blocked
EBS volume encrypted
Root MFA enabled
Security group does not allow unrestricted SSH
RDS storage encrypted
CloudTrail enabled
Required tags present
```

Rule types:

```text
AWS managed rule
Custom Lambda rule
Custom policy rule using Guard
```

Trigger types:

```text
Configuration change
Periodic evaluation
```

AWS Config supports managed rules and custom rules written with Lambda or Guard. Rules can be triggered by resource changes or periodic schedules. ([AWS Documentation][35])

---

# 59. Config compliance flow

```text
Resource created or changed
        |
        v
AWS Config records configuration
        |
        v
Config rule evaluates resource
        |
        ├── COMPLIANT
        ├── NON_COMPLIANT
        └── NOT_APPLICABLE
```

Example:

```text
EBS volume created without encryption
        ↓
encrypted-volumes rule evaluates
        ↓
NON_COMPLIANT
```

---

# 60. Config remediation

A Config rule can have:

* Manual remediation.
* Automatic remediation.

Remediation commonly invokes an AWS Systems Manager Automation document.

Example:

```text
Public S3 bucket detected
        |
        v
Config rule marks NON_COMPLIANT
        |
        v
SSM Automation enables Block Public Access
        |
        v
Config re-evaluates bucket
```

AWS Config supports remediation actions for noncompliant resources, including automatic remediation where supported and configured. ([AWS Documentation][36])

## Warning

Automatic remediation can be dangerous.

Example:

```text
Rule:
Security group must not allow port 443 publicly

Automatic action:
Remove public rule

Result:
Production website becomes unavailable
```

Test remediation in nonproduction and distinguish intentional public resources from misconfigurations.

---

# 61. Conformance packs

A conformance pack is a collection of:

```text
AWS Config rules
Remediation actions
Parameters
```

Example:

```text
ProductionSecurityBaseline
├── Encrypted EBS
├── Private S3
├── CloudTrail enabled
├── Root MFA
├── RDS encryption
└── Required tags
```

Conformance packs can be deployed to one account and Region or centrally across an AWS Organization. ([AWS Documentation][37])

---

# 62. Config aggregators

A Config aggregator collects configuration and compliance data across:

* Accounts.
* Regions.
* AWS Organizations.

Architecture:

```text
Member accounts and Regions
          |
          v
AWS Config recorders
          |
          v
Organization Config aggregator
          |
          v
Security/Audit account dashboard
```

An organization aggregator can collect data from member accounts and Regions without separate aggregation authorization from each organization member account. ([AWS Documentation][38])

---

# 63. Multi-account observability

A recommended account model is:

```text
Monitoring account:
CloudWatch dashboards, investigations and alarms

Source accounts:
Application telemetry

Log Archive account:
Durable audit and long-term logs

Security Tooling account:
Config aggregation, Security Hub and findings
```

## Important

Centralizing visibility does not always require physically copying every metric or trace.

CloudWatch Observability Access Manager can create links between source accounts and a monitoring account so shared telemetry remains associated with its originating account. ([AWS Documentation][39])

---

# 64. Observability Access Manager

OAM uses:

```text
Sink:
Created in monitoring account

Link:
Created in source account
```

```text
Source account A ─┐
Source account B ─┼──> Monitoring-account sink
Source account C ─┘
```

Shared telemetry can include:

* CloudWatch metrics.
* CloudWatch Logs log groups.
* X-Ray traces.
* Application Signals services.
* SLOs.
* Application Insights applications.
* Internet Monitor monitors.

OAM-based cross-account observability works within a Region, while CloudWatch also provides broader cross-account and cross-Region centralization capabilities for selected telemetry. ([AWS Documentation][40])

---

# 65. Cross-account observability architecture

```text
AWS Organization
│
├── Monitoring account
│   ├── OAM sink
│   ├── Cross-account dashboards
│   ├── Composite alarms
│   └── Incident workflows
│
├── Production account
│   └── OAM link
│
├── Development account
│   └── OAM link
│
└── Shared Services account
    └── OAM link
```

Monitoring teams can investigate several accounts without receiving broad administrator access to those workload accounts.

---

# 66. Terraform log group and alarm

```hcl
resource "aws_cloudwatch_log_group" "todo_api" {
  name              = "/production/todoapp/api"
  retention_in_days = 30

  kms_key_id = aws_kms_key.logs.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Metric alarm:

```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name = "production-todoapp-high-5xx"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"

  statistic = "Sum"
  period    = 60

  comparison_operator = "GreaterThanThreshold"
  threshold           = 5

  evaluation_periods  = 5
  datapoints_to_alarm = 3

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.application.arn_suffix
  }

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  ok_actions = [
    aws_sns_topic.operations.arn
  ]
}
```

---

# 67. Terraform composite alarm

```hcl
resource "aws_cloudwatch_composite_alarm" "application_incident" {
  alarm_name = "production-todoapp-incident"

  alarm_rule = join(" ", [
    "ALARM(${aws_cloudwatch_metric_alarm.alb_5xx.alarm_name})",
    "AND",
    "ALARM(${aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name})",
    "AND NOT",
    "ALARM(${aws_cloudwatch_metric_alarm.deployment.alarm_name})"
  ])

  alarm_actions = [
    aws_sns_topic.incidents.arn
  ]
}
```

Use component alarms for diagnostic detail and the composite alarm for paging.

---

# 68. Terraform CloudTrail organization trail

Conceptual configuration:

```hcl
resource "aws_cloudtrail" "organization" {
  name = "organization-security-trail"

  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  is_organization_trail = true
  is_multi_region_trail = true

  include_global_service_events = true
  enable_log_file_validation    = true

  kms_key_id = aws_kms_key.cloudtrail.arn

  cloud_watch_logs_group_arn = (
    "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  )

  cloud_watch_logs_role_arn = (
    aws_iam_role.cloudtrail_logs.arn
  )

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

The S3 bucket policy, KMS key policy and CloudWatch Logs role must explicitly allow CloudTrail delivery.

---

# 69. Terraform AWS Config recorder

```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "organization-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "organization-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  sns_topic_arn  = aws_sns_topic.config.arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [
    aws_config_configuration_recorder.main
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.main
  ]
}
```

Deploy AWS Config across all required accounts and Regions, then aggregate centrally.

---

# 70. Production alarm strategy

Use alarm levels.

## Page immediately

```text
Service unavailable
SLO rapidly burning
Critical queue stalled
Database unavailable
No healthy ALB targets
Security incident
```

## Create urgent ticket

```text
Disk above 85%
Certificate near expiry
Backup failed
Replication lag increasing
Error budget slowly burning
```

## Dashboard only

```text
CPU at 65%
Normal request growth
Memory at 55%
Noncritical development errors
```

Not every metric deserves an alarm.

---

# 71. Alarm message quality

Bad notification:

```text
ALARM: HighCPU
```

Better:

```text
Application:
TodoApp Production

Symptom:
API p95 latency exceeded 1 second

Current value:
1.8 seconds

Affected service:
todo-api

Region:
ap-south-1

Dashboard:
Production TodoApp

Runbook:
Investigate database latency and deployment health
```

An alarm must help the responder decide the next action.

---

# 72. Observability cost controls

Common CloudWatch cost drivers include:

* Custom metric count.
* High-resolution metrics.
* Alarm count.
* Log ingestion.
* Log retention.
* Logs Insights scan volume.
* Container Insights detail.
* RUM events.
* Synthetics runs.
* Trace ingestion.
* High-cardinality EMF dimensions.

AWS recommends using Cost Explorer and Cost and Usage Reports to identify telemetry cost drivers, and specifically warns against high-cardinality custom metric dimensions. ([AWS Documentation][41])

## Cost-control practices

```text
Use retention policies
Avoid debug logs in production
Sample normal traces
Retain all error traces where practical
Use low-cardinality metric dimensions
Use IA or Intelligent Tiering for cold logs
Filter CloudTrail data events
Limit expensive Logs Insights scan ranges
```

---

# 73. Troubleshooting missing CloudWatch metrics

Check:

```text
1. Correct Region.
2. Correct namespace.
3. Correct metric name.
4. Correct dimensions.
5. Resource is actively publishing.
6. Agent process is running.
7. IAM permits cloudwatch:PutMetricData.
8. Agent configuration is valid.
9. Network or VPC endpoint permits CloudWatch.
10. Metric timestamp is valid.
```

Commands:

```bash
sudo systemctl status amazon-cloudwatch-agent

sudo tail -f \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

aws cloudwatch list-metrics \
  --namespace TodoApp/Production \
  --region ap-south-1
```

---

# 74. Troubleshooting missing logs

Check:

```text
Log group Region
Log group name
Log stream
Agent file path
File permissions
IAM permissions
Retention policy
Application stdout configuration
Container logging driver
```

CloudWatch Agent permissions commonly require:

```text
logs:CreateLogGroup
logs:CreateLogStream
logs:PutLogEvents
logs:DescribeLogStreams
```

For ECS:

```text
Application writes stdout/stderr
        ↓
awslogs log driver
        ↓
CloudWatch Logs
```

---

# 75. Troubleshooting missing traces

Check:

```text
1. Application instrumentation loaded before application libraries.
2. OTLP endpoint is correct.
3. Collector is running.
4. Trace exporter is configured.
5. IAM permits trace submission.
6. Security group/network path allows export.
7. Sampling did not discard the trace.
8. Service name is configured.
9. Trace context is propagated.
10. Clock synchronization is correct.
```

Inspect collector logs:

```bash
docker logs adot-collector
```

Enable temporary debug exporter only in a controlled environment, because trace attributes may contain sensitive information.

---

# 76. Troubleshooting disconnected traces

Symptoms:

```text
Frontend trace ends at API call.

API creates a new unrelated trace.
```

Likely causes:

* `traceparent` header not forwarded.
* Reverse proxy strips tracing headers.
* Queue message lacks trace context.
* Unsupported propagation format.
* Application starts a new root span.
* Mixed legacy X-Ray and OpenTelemetry propagation configuration.

Choose a consistent propagation strategy and validate each protocol boundary.

---

# 77. Troubleshooting CloudTrail events

If an expected event is missing:

```text
1. Check the Region where the API call occurred.
2. Determine whether it is management or data activity.
3. Confirm trail event selectors.
4. Confirm organization trail status.
5. Confirm member account enrollment.
6. Check S3 bucket and KMS policies.
7. Check trail logging status.
8. Check whether the event is supported.
```

Event History contains management events only. S3 object reads and similar resource-level activity require data-event configuration. ([AWS Documentation][25])

---

# 78. Troubleshooting AWS Config

If a resource is not recorded:

```text
Recorder enabled?
Correct Region?
Resource type supported?
Resource type included?
Recording frequency appropriate?
Recorder role valid?
Delivery channel configured?
```

If a rule is not evaluating:

```text
Resource recorded?
Rule scope matches?
Trigger type correct?
Required parameters supplied?
Lambda/Guard logic valid?
```

If aggregator data disappears or fails, validate the organization relationship and aggregation role. AWS notes that invalid organization aggregator roles can eventually cause organization data to be removed from the aggregator. ([AWS Documentation][42])

---

# 79. Incident-investigation workflow

Scenario:

```text
Customers report 500 errors.
```

## Step 1: Confirm customer impact

```text
Application Signals
SLO
RUM
Synthetics
ALB metrics
```

## Step 2: Identify affected service

```text
Service map
Error-rate metrics
Latency metrics
```

## Step 3: Inspect traces

```text
Slow database span
Failed downstream API
Queue delay
```

## Step 4: Inspect correlated logs

```text
traceId
requestId
errorType
deploymentVersion
```

## Step 5: Check infrastructure

```text
CPU
Memory
Disk
Database connections
EBS latency
Container restarts
```

## Step 6: Check recent AWS changes

```text
CloudTrail:
Who deployed or modified infrastructure?

AWS Config:
What configuration changed?
```

## Step 7: Remediate and validate

```text
Rollback deployment
Scale service
Restore configuration
Fix dependency
```

---

# 80. Production observability checklist

```text
[ ] Every workload has an owner
[ ] Every critical service has RED metrics
[ ] Infrastructure has USE metrics
[ ] Customer-facing SLOs are defined
[ ] Error-budget alerts exist
[ ] Dashboards are service-oriented
[ ] Paging alarms represent customer impact
[ ] Warning alarms create tickets
[ ] Composite alarms reduce noise
[ ] Missing-data behavior is deliberate
[ ] Application logs are structured JSON
[ ] Secrets are redacted
[ ] Request and trace IDs are logged
[ ] Log retention is explicitly configured
[ ] Cold logs use appropriate storage classes
[ ] Logs Insights queries are documented
[ ] CloudWatch Agent collects host metrics
[ ] Container Insights is enabled where justified
[ ] OpenTelemetry is used for new instrumentation
[ ] Legacy X-Ray SDK migration is planned
[ ] Trace sampling is documented
[ ] Synthetics monitors critical journeys
[ ] RUM monitors real client performance
[ ] OAM centralizes multi-account visibility
[ ] Organization CloudTrail is multi-Region
[ ] Sensitive data events are recorded
[ ] CloudTrail logs are centrally protected
[ ] AWS Config records required resource types
[ ] Organization Config aggregator exists
[ ] Conformance packs are deployed
[ ] Automatic remediation is tested
[ ] Observability cost is reviewed regularly
[ ] Runbooks are linked to alarms
[ ] Incident exercises are performed
```

---

# 81. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
CloudWatch:
Metrics, logs, alarms and dashboards

CloudTrail:
AWS account and API activity

AWS Config:
Resource configuration and compliance

X-Ray/OpenTelemetry:
Distributed tracing
```

## Solutions Architect Associate

Understand:

```text
Custom metrics
CloudWatch Agent
Metric filters
Alarm actions
Composite alarms
CloudTrail trails
Management versus data events
Config rules
Synthetics
Cross-account monitoring
```

## DevOps Engineer Professional

Understand:

```text
SLO and error-budget alerting
Application Signals
OpenTelemetry pipelines
EMF and cardinality
Cross-account OAM
Organization trails
Advanced event selectors
Config aggregators
Conformance packs
Automated remediation
Terraform observability
Incident correlation
```

---

# 82. Interview questions

## Question 1: What is the difference between CloudWatch and CloudTrail?

**Answer:**

CloudWatch monitors application and infrastructure behavior using metrics, logs, alarms and traces. CloudTrail records AWS account and API activity for auditing and investigation.

## Question 2: What is the difference between CloudTrail and AWS Config?

**Answer:**

CloudTrail records who performed an AWS operation and when. AWS Config records what a resource’s configuration was and whether that configuration complies with rules.

## Question 3: What are the three observability pillars?

**Answer:**

Metrics, logs and distributed traces.

## Question 4: What is a CloudWatch dimension?

**Answer:**

A dimension is a name-value attribute that identifies the context or resource associated with a metric.

## Question 5: What is metric cardinality?

**Answer:**

It is the number of unique metric and dimension combinations. High-cardinality dimensions can create many billable custom metrics.

## Question 6: What is a composite alarm?

**Answer:**

It combines the states of several underlying alarms to reduce noise or represent a higher-level service incident.

## Question 7: What is anomaly detection?

**Answer:**

It models expected metric behavior and alerts when current values fall outside an expected range.

## Question 8: What is EMF?

**Answer:**

Embedded Metric Format is structured log JSON from which CloudWatch automatically extracts custom metrics while retaining detailed log context.

## Question 9: What is Application Signals?

**Answer:**

It provides an application-focused view of services, operations, dependencies, latency, faults, errors, service maps and SLOs.

## Question 10: What is the difference between Synthetics and RUM?

**Answer:**

Synthetics runs controlled simulated user journeys. RUM measures the experience of actual application users.

## Question 11: What is an SLO?

**Answer:**

A Service-Level Objective is a reliability target based on an SLI, such as 99.9% successful requests over 30 days.

## Question 12: What is OpenTelemetry?

**Answer:**

It is a vendor-neutral standard and tooling ecosystem for generating, collecting and exporting metrics, logs and traces.

## Question 13: Should new applications use the X-Ray SDK?

**Answer:**

New applications should generally use OpenTelemetry. The legacy X-Ray SDKs and daemon entered maintenance mode in February 2026.

## Question 14: What are CloudTrail management events?

**Answer:**

They are control-plane operations such as creating, modifying or deleting AWS resources.

## Question 15: What are CloudTrail data events?

**Answer:**

They are resource-level operations such as S3 object access or Lambda invocation and must generally be explicitly configured.

## Question 16: What is an organization trail?

**Answer:**

It is a CloudTrail trail configured at the AWS Organizations level to record activity from the management and member accounts.

## Question 17: What is a Config rule?

**Answer:**

It evaluates whether an AWS resource configuration complies with a defined requirement.

## Question 18: What is a conformance pack?

**Answer:**

It is a deployable collection of AWS Config rules, parameters and optional remediation actions.

## Question 19: What is an AWS Config aggregator?

**Answer:**

It centralizes configuration and compliance information from multiple AWS accounts and Regions.

## Question 20: How would you investigate a production slowdown?

**Answer:**

Confirm customer impact using SLOs, RUM or Synthetics; inspect service metrics and maps; use traces to find the slow dependency; correlate logs using trace IDs; check infrastructure metrics; and use CloudTrail and Config to identify recent changes.

---

# 83. Never-forget revision

```text
CloudWatch:
Operational monitoring and observability.

Metric:
Numerical measurement over time.

Dimension:
Metric context or resource identifier.

Alarm:
Evaluates metric or query conditions.

Composite alarm:
Combines other alarm states.

EMF:
Metrics embedded inside structured logs.

CloudWatch Logs:
Central log storage and querying.

Logs Insights:
Interactive log-query language.

Application Signals:
Application services, dependencies and SLOs.

Synthetics:
Simulated user monitoring.

RUM:
Real user monitoring.

Trace:
End-to-end request journey.

Span:
One operation inside a trace.

OpenTelemetry:
Open standard for metrics, logs and traces.

CloudTrail:
AWS API and account audit activity.

Management event:
AWS control-plane action.

Data event:
Resource-level data operation.

AWS Config:
Resource configuration history.

Config rule:
Compliance evaluation.

Conformance pack:
Collection of Config rules and remediations.

Aggregator:
Multi-account and multi-Region Config view.

OAM:
Cross-account CloudWatch observability sharing.
```

## One-line memory trick

```text
Metrics tell you something is wrong.
Logs tell you what happened.
Traces tell you where it happened.
CloudTrail tells you who changed AWS.
Config tells you what changed.
SLOs tell you whether customers should care.
```

## Lesson 38 outcome

You can now design an environment where:

```text
API latency increases
    → CloudWatch alarm identifies the symptom.

Only some users are affected
    → RUM identifies affected sessions and locations.

One dependency is slow
    → Trace exposes the slow database span.

Detailed failure context is needed
    → Structured logs are queried by trace ID.

A security group changed
    → CloudTrail identifies the caller.

The previous configuration is needed
    → AWS Config shows the resource timeline.

Many AWS accounts exist
    → OAM and Config aggregation provide centralized visibility.

Reliability must be measurable
    → Application Signals and SLOs track error-budget consumption.
```

**Next lesson: Lesson 39 — AWS Systems Manager production operations: Session Manager, Patch Manager, Run Command, Automation, Inventory, State Manager, Parameter Store, Fleet Manager and incident remediation.**

[1]: https://docs.aws.amazon.com/pdfs/decision-guides/latest/cloudtrail-or-cloudwatch/cloudtrail-or-cloudwatch.pdf?utm_source=chatgpt.com "AWS CloudTrail or Amazon CloudWatch? - AWS Decision guide"
[2]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html?utm_source=chatgpt.com "What is Amazon CloudWatch? - Amazon CloudWatch"
[3]: https://docs.aws.amazon.com/cloudwatch/?utm_source=chatgpt.com "Amazon CloudWatch Documentation"
[4]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html?utm_source=chatgpt.com "Metrics concepts - Amazon CloudWatch"
[5]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html?utm_source=chatgpt.com "Specification: Embedded metric format - Amazon CloudWatch"
[6]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html?utm_source=chatgpt.com "Using CloudWatch anomaly detection - Amazon CloudWatch"
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-combining.html?utm_source=chatgpt.com "Composite alarms - Amazon CloudWatch"
[8]: https://docs.aws.amazon.com/ru_ru/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html?utm_source=chatgpt.com "Embedding metrics within logs - Amazon CloudWatch"
[9]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html?utm_source=chatgpt.com "Collect metrics, logs, and traces using the CloudWatch agent - Amazon CloudWatch"
[10]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatch_Logs_Log_Classes.html?utm_source=chatgpt.com "Log classes - Amazon CloudWatch Logs"
[11]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cwl_intelligent_tier.html?utm_source=chatgpt.com "Optimize storage costs with Amazon CloudWatch Logs Intelligent Tiering - Amazon CloudWatch Logs"
[12]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html?utm_source=chatgpt.com "Creating metrics from log events using filters - Amazon CloudWatch Logs"
[13]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-log.html?utm_source=chatgpt.com "Log alarms - Amazon CloudWatch"
[14]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html?utm_source=chatgpt.com "Container Insights - Amazon CloudWatch"
[15]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html?utm_source=chatgpt.com "Application Signals - Amazon CloudWatch"
[16]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Services.html?utm_source=chatgpt.com "Monitor the operational health of your applications with Application Signals - Amazon CloudWatch"
[17]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-ServiceLevelObjectives.html?utm_source=chatgpt.com "Service level objectives (SLOs) - Amazon CloudWatch"
[18]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html?utm_source=chatgpt.com "Synthetic monitoring (canaries) - Amazon CloudWatch"
[19]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM.html?utm_source=chatgpt.com "CloudWatch RUM - Amazon CloudWatch"
[20]: https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html?utm_source=chatgpt.com "AWS X-Ray"
[21]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-daemon-timeline.html?utm_source=chatgpt.com "X-Ray SDK and Daemon Support timeline"
[22]: https://github.com/open-telemetry?utm_source=chatgpt.com "OpenTelemetry - CNCF"
[23]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLP-UsingADOT.html?utm_source=chatgpt.com "Exporting collector-less telemetry using AWS Distro for ..."
[24]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLPCloudWatchAgent.html?utm_source=chatgpt.com "Amazon CloudWatch agent - Amazon CloudWatch"
[25]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html?utm_source=chatgpt.com "Working with CloudTrail event history - AWS CloudTrail"
[26]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-events.html?utm_source=chatgpt.com "Understanding CloudTrail events - AWS CloudTrail"
[27]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html?utm_source=chatgpt.com "Creating a trail for an organization - AWS CloudTrail"
[28]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/filtering-data-events.html?utm_source=chatgpt.com "Filtering data events by using advanced event selectors - AWS CloudTrail"
[29]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-record-contents.html?utm_source=chatgpt.com "CloudTrail record contents for management, data, and network activity events - AWS CloudTrail"
[30]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html?utm_source=chatgpt.com "What Is AWS CloudTrail? - AWS CloudTrail"
[31]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-insights-events-with-cloudtrail.html?utm_source=chatgpt.com "Working with CloudTrail Insights"
[32]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/query-event-data-store.html?utm_source=chatgpt.com "CloudTrail Lake event data stores"
[33]: https://docs.aws.amazon.com/config/latest/developerguide/WhatIsConfig.html?utm_source=chatgpt.com "What Is AWS Config? - AWS Config"
[34]: https://docs.aws.amazon.com/config/latest/developerguide/select-resources.html?utm_source=chatgpt.com "Recording AWS Resources with AWS Config - AWS Config"
[35]: https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_add-rules.html?utm_source=chatgpt.com "Adding AWS Config Rules - AWS Config"
[36]: https://docs.aws.amazon.com/config/latest/developerguide/remediation.html?utm_source=chatgpt.com "Remediating Noncompliant Resources with AWS Config - AWS Config"
[37]: https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html?utm_source=chatgpt.com "Conformance Packs for AWS Config"
[38]: https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html?utm_source=chatgpt.com "Multi-Account Multi-Region Data Aggregation for AWS Config - AWS Config"
[39]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Unified-Cross-Account.html?utm_source=chatgpt.com "CloudWatch cross-account observability - Amazon CloudWatch"
[40]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Cross-Account-Methods.html?utm_source=chatgpt.com "Monitor across accounts and Regions - Amazon CloudWatch"
[41]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_billing.html?utm_source=chatgpt.com "Analyzing, optimizing, and reducing CloudWatch costs - Amazon CloudWatch"
[42]: https://docs.aws.amazon.com/config/latest/developerguide/viewing-the-aggregate-dashboard.html?utm_source=chatgpt.com "Viewing Compliance and Inventory Data in the Aggregator Dashboard for AWS Config - AWS Config"
