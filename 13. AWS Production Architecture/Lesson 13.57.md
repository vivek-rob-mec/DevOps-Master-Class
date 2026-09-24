# AWS Masterclass — Phase 3

# Lesson 56: Amazon CloudWatch, CloudTrail, AWS Config and X-Ray Production Observability

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish monitoring, observability, auditing and configuration compliance.
* Design metrics, logs and distributed traces.
* Publish and control custom CloudWatch metrics.
* Choose useful metric dimensions without causing cardinality explosion.
* Build alarms with M-out-of-N evaluation, missing-data handling and anomaly detection.
* Reduce alert noise with composite alarms.
* Write structured application logs.
* Query logs using CloudWatch Logs Insights.
* Select Standard, Infrequent Access and Delivery log classes correctly.
* Centralize telemetry across AWS accounts.
* Use CloudWatch Application Signals and service-level objectives.
* Monitor real users with CloudWatch RUM.
* Test applications with CloudWatch Synthetics.
* Instrument distributed applications with OpenTelemetry.
* Understand the current X-Ray SDK migration direction.
* Audit AWS API activity with CloudTrail.
* Distinguish management, data, network activity and Insights events.
* Build secure organization-wide CloudTrail trails.
* Validate CloudTrail log-file integrity.
* Track resource configuration with AWS Config.
* Use Config rules, conformance packs, aggregators and remediation.
* Investigate production incidents by correlating metrics, logs, traces, audit events and configuration changes.
* Control observability costs.
* Provision observability infrastructure with Terraform.

---

# 2. Monitoring versus observability versus auditing

These terms overlap, but they solve different questions.

## Monitoring

Monitoring asks:

```text
Is the system healthy?
```

Examples:

* CPU is above 90%.
* API error rate is 8%.
* Queue age is increasing.
* Database connections are exhausted.
* Certificate expires soon.

## Observability

Observability asks:

```text
Why is the system unhealthy?
```

It combines:

```text
Metrics
Logs
Traces
Events
Topology
Deployments
Configuration changes
```

## Auditing

Auditing asks:

```text
Who changed the system?
What API was called?
When was it called?
From where?
Was it allowed?
```

## Configuration compliance

Configuration compliance asks:

```text
What does the resource look like now?
How did its configuration change?
Does it comply with policy?
```

---

# 3. The four-service mental model

```text
Amazon CloudWatch
    → Application and infrastructure telemetry

AWS CloudTrail
    → AWS API activity and audit history

AWS Config
    → Resource configuration history and compliance

AWS X-Ray / OpenTelemetry
    → Distributed request tracing
```

## Never-forget trick

```text
CloudWatch:
What is happening?

CloudTrail:
Who did what in AWS?

AWS Config:
What changed in the resource?

Tracing:
Where did this request spend its time?
```

CloudWatch provides metrics, logs, alarms, dashboards, application monitoring and cross-account observability. CloudTrail records AWS API activity. AWS Config records resource configurations and relationships. X-Ray and OpenTelemetry provide distributed request traces. ([AWS Documentation][1])

---

# 4. The observability pillars

The traditional pillars are:

```text
Metrics
Logs
Traces
```

A production AWS system should also correlate:

```text
Deployments
Configuration changes
Audit events
Business outcomes
```

Example TodoApp incident:

```text
Users report:
"Completing a todo is slow."

Metrics:
API p95 latency increased.

Logs:
Database timeout errors.

Trace:
API → Aurora call consumes 4.8 seconds.

CloudTrail:
Security-group rule changed 10 minutes ago.

AWS Config:
Database security-group configuration changed.

Deployment data:
No application deployment occurred.
```

The combined evidence points to infrastructure configuration rather than application code.

---

# Part 1 — Amazon CloudWatch Metrics

# 5. What is a CloudWatch metric?

A metric is a time-ordered series of numerical data points.

```text
Namespace
   |
   v
Metric name
   |
   v
Dimensions
   |
   v
Timestamp + value
```

Example:

```text
Namespace:
AWS/ApplicationELB

Metric:
TargetResponseTime

Dimensions:
LoadBalancer = app/todo-alb/...
TargetGroup  = targetgroup/todo-api/...
```

CloudWatch organizes metrics by namespaces, metric names and dimensions. Each unique dimension combination forms a separate metric time series. ([AWS Documentation][2])

---

# 6. Metric examples

## Infrastructure metrics

```text
CPUUtilization
NetworkIn
FreeStorageSpace
DatabaseConnections
HealthyHostCount
ApproximateAgeOfOldestMessage
```

## Application metrics

```text
Requests
Errors
Latency
TodosCreated
TodosCompleted
CacheHits
CacheMisses
LoginFailures
PaymentFailures
```

## Business metrics

```text
ActiveUsers
NewSubscriptions
CompletedTodos
ReportGenerationSuccess
UserOnboardingCompletion
```

Infrastructure metrics tell you whether components are working.

Business metrics tell you whether the application is delivering value.

---

# 7. Counter, gauge and distribution

## Counter

A counter increases when an event occurs.

```text
Requests
Errors
TodosCreated
MessagesProcessed
```

Typical analysis:

```text
Rate per second
Count per minute
Percentage of total
```

## Gauge

A gauge represents a current level.

```text
Queue depth
Active connections
Memory usage
Running tasks
Current users
```

A gauge can rise and fall.

## Distribution

A distribution represents many observed values.

```text
Request duration
Payload size
Database query duration
Job execution time
```

Useful statistics:

```text
Average
Minimum
Maximum
p50
p90
p95
p99
```

---

# 8. Why averages are dangerous

Suppose request durations are:

```text
90 ms
95 ms
100 ms
105 ms
110 ms
5,000 ms
```

Average latency can hide the experience of the slowest users.

Monitor:

```text
p50:
Typical user

p95:
Slowest 5% boundary

p99:
Tail latency

Maximum:
Extreme case
```

A production API normally needs percentile monitoring, not only average latency.

---

# 9. Metric dimensions

Dimensions identify the context of a metric.

Example:

```text
Metric:
RequestLatency

Dimensions:
Service = todo-api
Environment = production
Route = POST /todos
```

This lets you compare:

```text
todo-api production
todo-api staging
GET /todos
POST /todos
DELETE /todos/{id}
```

---

# 10. High-cardinality danger

Do not use unbounded values as metric dimensions.

Dangerous:

```text
UserId
RequestId
TodoId
EmailAddress
SessionId
Full URL with query string
```

Example:

```text
1,000,000 users
×
10 API routes
=
Potentially 10,000,000 metric combinations
```

Each unique dimension combination can create a distinct custom metric, increasing cost and making dashboards difficult to use.

Use bounded dimensions:

```text
Service
Environment
Region
Route template
Status class
Error category
Tenant tier
```

Put high-cardinality identifiers in logs and traces instead.

---

# 11. Metric granularity

Bad route dimension:

```text
/todos/501
/todos/502
/todos/503
```

Better:

```text
/todos/{todoId}
```

Bad status dimension:

```text
200
201
204
400
401
403
404
429
500
502
503
```

Potentially better for broad metrics:

```text
2xx
4xx
5xx
```

Keep detailed status codes in logs while using bounded status classes for primary metrics.

---

# 12. Standard and high-resolution metrics

AWS service metrics normally use standard resolution. Custom metrics can be published at standard resolution or at one-second high resolution.

CloudWatch metric retention currently works as follows:

```text
Sub-minute high-resolution points:
3 hours

1-minute points:
15 days

5-minute points:
63 days

1-hour points:
455 days
```

CloudWatch aggregates older data as it ages. ([AWS Documentation][2])

Use high-resolution metrics when:

* Sub-minute autoscaling matters.
* Fast incident detection matters.
* Latency spikes last only a few seconds.
* High-frequency trading or industrial telemetry requires it.

Do not enable high resolution for every metric without a clear operational reason.

---

# 13. Publishing a custom metric

CLI example:

```bash
aws cloudwatch put-metric-data \
  --namespace "TodoApp/Production" \
  --metric-data '[
    {
      "MetricName": "TodoCreated",
      "Dimensions": [
        {
          "Name": "Service",
          "Value": "todo-api"
        },
        {
          "Name": "Environment",
          "Value": "production"
        }
      ],
      "Timestamp": "2026-08-02T13:00:00+05:30",
      "Value": 1,
      "Unit": "Count"
    }
  ]' \
  --region ap-south-1
```

Use the application’s IAM role rather than long-lived AWS credentials.

---

# 14. Embedded Metric Format

Embedded Metric Format, or EMF, lets an application write structured log events that CloudWatch automatically converts into metrics.

```text
Application
    |
    | Structured EMF log
    v
CloudWatch Logs
    |
    ├── Detailed log event
    └── Extracted custom metric
```

EMF is useful when you need:

* Searchable high-cardinality log context.
* Aggregated bounded-dimension metrics.
* One emission path for logs and metrics.
* Asynchronous metric extraction.

EMF metrics are generated from structured logs written to CloudWatch Logs. The application needs log-write permissions rather than separate `PutMetricData` permission for that path. ([AWS Documentation][3])

---

# 15. EMF example

```json
{
  "_aws": {
    "Timestamp": 1785657600000,
    "CloudWatchMetrics": [
      {
        "Namespace": "TodoApp/Production",
        "Dimensions": [
          [
            "Service",
            "Environment",
            "Route"
          ]
        ],
        "Metrics": [
          {
            "Name": "RequestLatency",
            "Unit": "Milliseconds"
          },
          {
            "Name": "RequestCount",
            "Unit": "Count"
          }
        ]
      }
    ]
  },
  "Service": "todo-api",
  "Environment": "production",
  "Route": "POST /todos",
  "RequestLatency": 86,
  "RequestCount": 1,
  "requestId": "request-8d9382",
  "tenantId": "tenant-38",
  "statusCode": 201
}
```

CloudWatch creates metrics only from the declared bounded dimensions.

Fields such as `requestId` remain searchable in the log without becoming metric dimensions.

---

# 16. Metric math

Metric math combines metrics into calculated expressions.

Example API error percentage:

```text
100 × 5XXError / RequestCount
```

Example cache-hit percentage:

```text
100 × CacheHits / (CacheHits + CacheMisses)
```

Example SQS processing deficit:

```text
MessagesSent - MessagesDeleted
```

Use metric math to alert on outcomes rather than isolated component values.

A raw error count of 100 may be severe at 200 requests and harmless at 10 million requests.

---

# 17. CloudWatch Metrics Insights

Metrics Insights provides SQL-like queries over CloudWatch metrics.

Conceptual query:

```sql
SELECT AVG(CPUUtilization)
FROM SCHEMA("AWS/ECS", ClusterName, ServiceName)
WHERE ClusterName = 'production'
GROUP BY ServiceName
ORDER BY AVG() DESC
LIMIT 20
```

This is useful for fleet-wide and dynamic dashboards where resource membership changes frequently.

---

# Part 2 — CloudWatch Alarms

# 18. Alarm states

A CloudWatch alarm has three states:

```text
OK
ALARM
INSUFFICIENT_DATA
```

## OK

The evaluated metric is within the desired condition.

## ALARM

The metric breached the configured condition.

## INSUFFICIENT_DATA

CloudWatch does not have enough usable data to evaluate the condition.

CloudWatch alarms monitor metrics and can notify or trigger supported automated actions when their state changes. ([AWS Documentation][4])

---

# 19. M-out-of-N evaluation

Instead of alarming on one data point:

```text
1 of 1:
Alarm immediately
```

you can use:

```text
3 of 5:
Alarm if three of the last five periods breach
```

Example:

```text
Period:
1 minute

Evaluation periods:
5

Datapoints to alarm:
3
```

This allows short transient spikes without ignoring sustained problems.

---

# 20. Choosing alarm evaluation windows

Fast operational failure:

```text
ALB HealthyHostCount = 0

Period:
1 minute

Evaluation:
1 of 1
```

Noisy CPU metric:

```text
CPUUtilization > 85%

Period:
1 minute

Evaluation:
5 of 10
```

Business SLO:

```text
Success rate < 99.9%

Period:
5 minutes

Evaluation:
3 of 3
```

The window should match the speed and impact of the failure.

---

# 21. Missing-data handling

CloudWatch alarms can treat missing data as:

```text
breaching
notBreaching
ignore
missing
```

The correct choice depends on the metric.

## Heartbeat metric

```text
ApplicationAlive = 1 every minute
```

Missing should probably be treated as breaching.

## Error metric

```text
ApplicationErrors
```

Missing might mean zero errors or might mean telemetry stopped.

A safer design is often:

```text
Alarm A:
Error rate high

Alarm B:
Telemetry heartbeat missing
```

CloudWatch provides explicit missing-data evaluation behavior for standard and Metrics Insights alarms. ([AWS Documentation][5])

---

# 22. Static alarms

Example:

```text
CPUUtilization > 85%
for 5 of 10 minutes
```

Good for:

* Capacity ceilings.
* Disk-space boundaries.
* Queue-age SLOs.
* Known service limits.
* Certificate-expiry thresholds.
* Error-budget burn thresholds.

---

# 23. Anomaly-detection alarms

Anomaly detection learns the expected range of a metric based on historical behavior, including recurring hourly, daily and weekly patterns.

```text
Expected requests at 03:00:
100–200/minute

Expected requests at 15:00:
8,000–10,000/minute
```

A fixed alarm may not work well across both periods.

CloudWatch anomaly detection creates a model of expected metric values and can alarm when the observed value moves outside the expected band. ([AWS Documentation][6])

Strong candidates:

* Request volume.
* Login failures.
* Daily job duration.
* Data ingestion.
* Network traffic.
* Error counts with predictable patterns.

Poor candidates:

* Newly created metrics with no useful history.
* Metrics intentionally changing after a launch.
* Sparse binary metrics.
* Metrics where one fixed boundary is the actual safety limit.

---

# 24. Composite alarms

A composite alarm combines other alarm states.

Example:

```text
ALB5xxHigh
AND
ApiLatencyHigh
AND
NOT DeploymentInProgress
```

Another example:

```text
DatabaseCPUHigh
AND
DatabaseConnectionsHigh
```

Composite alarms reduce duplicate notifications when several low-level alarms represent one incident. They can notify or create operational investigation items, but they do not support every resource action that a normal metric alarm supports. ([AWS Documentation][4])

---

# 25. Symptom alarms versus cause alarms

Suppose Aurora is slow.

Possible alarms:

```text
API latency high
API 5xx high
Lambda duration high
Database connections high
Database CPU high
Queue age high
```

Sending six pages creates alert fatigue.

Better:

```text
Page:
User-facing API SLO breached

Dashboard and investigation:
Show all possible cause alarms
```

Page operators for customer impact.

Use cause metrics to accelerate diagnosis.

---

# 26. Alarm severity model

Example:

```text
P1:
Complete customer outage
Data-loss risk
Security incident

P2:
Major degradation
SLO burning rapidly

P3:
Capacity warning
Noncritical component failure

Ticket:
Long-term optimization
```

Do not send every warning to the same urgent notification channel.

---

# 27. Alarm actions

Possible actions include:

* SNS notification.
* Auto Scaling action.
* EC2 action for supported alarms.
* Systems Manager OpsItem.
* Incident workflow.
* CloudWatch investigation.
* Automated remediation.

Use automated remediation only when the action is:

* Safe.
* Bounded.
* Idempotent.
* Tested under failure.
* Easy to audit.
* Protected against loops.

---

# Part 3 — CloudWatch Dashboards

# 28. Dashboard design

A dashboard should answer questions in this order:

```text
1. Are users affected?

2. Which service is affected?

3. What changed?

4. What resource is constrained?

5. Is the incident improving?
```

Recommended layout:

```text
Top:
Business health and SLOs

Second:
Traffic, errors, latency, saturation

Third:
Dependency health

Fourth:
Deployment and configuration markers

Bottom:
Cost and capacity trends
```

---

# 29. RED method

For request-driven services, monitor:

```text
Rate
Errors
Duration
```

Example:

```text
Request rate
5xx percentage
p50/p95/p99 latency
```

---

# 30. USE method

For infrastructure resources, monitor:

```text
Utilization
Saturation
Errors
```

Example database:

```text
Utilization:
CPU percentage

Saturation:
Connections near limit
Storage queue depth

Errors:
Failed connections
Deadlocks
```

---

# 31. TodoApp dashboard

```text
Business:
Todos created/min
Todos completed/min
Active users
Login success rate

API:
Request rate
4xx rate
5xx rate
p50/p95/p99 latency

Compute:
ECS task count
CPU
Memory
ALB healthy targets

Database:
CPU
Connections
Read/write latency
Free storage

Cache:
Hit rate
Evictions
Connections

Messaging:
SQS depth
Oldest message age
DLQ depth

Deployments:
Current application version
Last deployment time
```

---

# Part 4 — CloudWatch Logs

# 32. Log-group mental model

```text
Log group
    |
    ├── Log stream A
    ├── Log stream B
    └── Log stream C
```

Example:

```text
Log group:
/aws/ecs/production/todo-api

Log streams:
task-1/container-1
task-2/container-1
task-3/container-1
```

CloudWatch Logs centralizes application, infrastructure and AWS service logs for storage, searching, filtering and analysis. ([AWS Documentation][7])

---

# 33. Structured logging

Bad log:

```text
Something went wrong
```

Better:

```json
{
  "timestamp": "2026-08-02T13:05:23.123+05:30",
  "level": "ERROR",
  "service": "todo-api",
  "environment": "production",
  "message": "Failed to create todo",
  "requestId": "request-8d9382",
  "traceId": "1-...",
  "userIdHash": "sha256:...",
  "tenantId": "tenant-38",
  "route": "POST /todos",
  "statusCode": 500,
  "errorType": "DatabaseTimeout",
  "durationMs": 5031
}
```

Benefits:

* Machine-readable queries.
* Reliable metric filters.
* Trace correlation.
* Faster incident investigation.
* Consistent dashboards.

---

# 34. Fields every application log should consider

```text
timestamp
level
service
environment
region
applicationVersion
requestId
traceId
spanId
correlationId
route
statusCode
durationMs
errorType
tenantId where safe
```

Do not log:

```text
Passwords
Access tokens
Refresh tokens
Session cookies
API keys
Credit-card data
Full secret values
Private encryption keys
```

---

# 35. Winston example for your Node.js TodoApp

```javascript
import winston from "winston";

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? "info",

  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({
      stack: true
    }),
    winston.format.json()
  ),

  defaultMeta: {
    service: "todo-api",
    environment: process.env.NODE_ENV ?? "development",
    version: process.env.APP_VERSION ?? "unknown"
  },

  transports: [
    new winston.transports.Console()
  ]
});
```

Request logging:

```javascript
logger.info("Todo created", {
  requestId: req.id,
  correlationId: req.headers["x-correlation-id"],
  traceId: req.traceId,
  tenantId: req.authenticatedTenantId,
  todoId: todo.id,
  durationMs
});
```

In containers, writing structured logs to standard output is usually simpler than managing rotating local files.

---

# 36. Log retention

CloudWatch Logs stores log data indefinitely by default unless you configure retention.

This can create uncontrolled cost and unnecessary retention of sensitive operational data. ([AWS Documentation][8])

Example policy:

```text
Development:
7–14 days

Staging:
30 days

Production application:
30–90 days

Security operations:
1 year or central archive

Regulatory audit:
According to compliance requirement
```

Set retention explicitly for every log group.

---

# 37. CloudWatch Logs classes

CloudWatch Logs currently provides:

```text
Standard
Infrequent Access
```

and a special:

```text
Delivery
```

class for delivering Lambda logs to S3 or Data Firehose.

## Standard

Use for logs requiring:

* Frequent queries.
* Real-time monitoring.
* Metric filters.
* Subscription filters.
* Live operational workflows.
* Full CloudWatch Logs capabilities.

## Infrequent Access

Use for logs:

* Queried occasionally.
* Retained mainly for investigation.
* Needing lower ingestion cost.
* Not requiring every Standard feature.

Infrequent Access supports Logs Insights with some command limitations. ([AWS Documentation][9])

## Delivery

Use only for Lambda-log delivery to S3 or Firehose. Delivery-class events remain in CloudWatch Logs for a fixed two days and do not provide rich capabilities such as Logs Insights. ([AWS Documentation][9])

---

# 38. Logs Insights

CloudWatch Logs Insights supports interactive log analysis.

Current query-language options include:

```text
Logs Insights QL
OpenSearch PPL
OpenSearch SQL
```

depending on the query interface and log selection. ([AWS Documentation][10])

---

# 39. Find errors

```text
fields @timestamp, service, route, requestId, errorType, @message
| filter level = "ERROR"
| sort @timestamp desc
| limit 100
```

---

# 40. Error count by route

```text
filter level = "ERROR"
| stats count() as errors by route
| sort errors desc
```

---

# 41. p95 latency by route

```text
filter ispresent(durationMs)
| stats
    count() as requests,
    avg(durationMs) as averageMs,
    pct(durationMs, 95) as p95Ms,
    pct(durationMs, 99) as p99Ms
  by route
| sort p95Ms desc
```

---

# 42. Follow one request

```text
filter requestId = "request-8d9382"
| sort @timestamp asc
| display @timestamp, service, level, message, traceId, durationMs
```

This is why consistent correlation IDs are important.

---

# 43. Detect new errors after deployment

```text
filter level = "ERROR"
| stats count() by errorType, bin(5m)
| sort @timestamp desc
```

Compare:

```text
Before deployment
versus
After deployment
```

CloudWatch Logs Insights also supports analysis patterns such as `diff` in supported log classes.

---

# 44. Field indexes

Field indexes improve equality-based searches and can reduce the amount of scanned log data.

Strong index candidates:

```text
requestId
traceId
tenantId
sessionIdHash
orderId
deploymentId
```

Example query:

```text
filter requestId = "request-8d9382"
```

CloudWatch can skip log events known not to contain the indexed value, improving performance and reducing scanned volume. ([AWS Documentation][11])

Do not index every field blindly.

Choose fields frequently used for exact-match investigations.

---

# 45. Metric filters

A metric filter converts matching logs into a metric.

Example filter pattern:

```text
{ $.level = "ERROR" }
```

Result:

```text
TodoApp/Production
ApplicationErrors
```

Metric filters are useful for:

* Authentication failures.
* Root-account activity.
* Security-group changes.
* Application error categories.
* Data-processing failures.
* Rotation failures.

---

# 46. Log alarms

CloudWatch currently supports two broad approaches:

```text
Scheduled Logs Insights query alarm
Metric filter + metric alarm
```

A query alarm evaluates aggregated Logs Insights results directly. A metric filter continuously turns matching logs into a standard metric. ([AWS Documentation][12])

Use metric filters for:

* Simple known patterns.
* Frequent real-time alarms.
* Stable structured fields.

Use Logs Insights query alarms for:

* More complex aggregations.
* Queries across several fields.
* Conditions difficult to express as one filter.

---

# 47. Subscription filters

Subscription filters stream matching log events in near real time to destinations such as:

* Lambda.
* Kinesis Data Streams.
* Data Firehose.
* OpenSearch pipelines.

CloudWatch Logs supports account-level and log-group-level subscriptions. A log group can currently have up to five subscription filters. Retryable delivery failures are retried for up to 24 hours. ([AWS Documentation][13])

Example:

```text
CloudWatch Logs
       |
       v
Subscription filter
       |
       v
Data Firehose
       |
       v
Central S3 log archive
```

---

# 48. Avoid log-subscription loops

Dangerous:

```text
CloudWatch Logs
    |
    v
Lambda processor
    |
    v
Writes processor logs
to the same subscribed log group
    |
    v
Lambda invoked again
```

This creates recursion and cost.

Use:

* Separate processor log groups.
* Selection criteria.
* Exclusion filters.
* Dedicated logging accounts.
* Rate and concurrency protection.

---

# Part 5 — CloudWatch Agent and OpenTelemetry

# 49. CloudWatch Agent

The unified CloudWatch agent can collect:

```text
Host metrics
Process metrics
Memory
Disk
Network
GPU metrics
Application logs
Traces
StatsD metrics
collectd metrics
```

from EC2, on-premises and supported containerized environments. ([AWS Documentation][1])

Default EC2 metrics do not include every operating-system metric.

For example, memory and disk usage commonly require an agent.

---

# 50. Agent architecture

```text
EC2 / on-premises host
        |
        v
CloudWatch Agent
        |
        ├── Metrics → CloudWatch Metrics
        ├── Logs    → CloudWatch Logs
        └── Traces  → CloudWatch/X-Ray path
```

Use Systems Manager to distribute and manage the agent configuration across fleets.

---

# 51. OpenTelemetry

OpenTelemetry is a vendor-neutral observability standard for:

```text
Traces
Metrics
Logs
Context propagation
```

Architecture:

```text
Application
    |
    | OTLP
    v
OpenTelemetry Collector
    |
    ├── CloudWatch
    ├── X-Ray trace backend
    ├── Prometheus-compatible backend
    └── Other observability platform
```

AWS supports OTLP-based trace ingestion and ADOT—the AWS Distro for OpenTelemetry—for AWS integrations. ([AWS Documentation][14])

---

# 52. Recommended 2026 tracing direction

**Important current guidance:** AWS states that the X-Ray SDKs and daemon entered maintenance mode on **February 25, 2026**. AWS recommends migrating application instrumentation to OpenTelemetry. Existing X-Ray traces and AWS integrations remain useful, but new application instrumentation should normally start with OpenTelemetry or ADOT rather than a new direct dependency on an X-Ray SDK. ([AWS Documentation][15])

```text
Old direction:
Application → X-Ray SDK → X-Ray daemon

Recommended direction:
Application → OpenTelemetry → ADOT/collector → CloudWatch/X-Ray
```

---

# 53. OpenTelemetry environment example

```bash
export OTEL_SERVICE_NAME="todo-api"

export OTEL_RESOURCE_ATTRIBUTES="\
deployment.environment=production,\
service.version=${APP_VERSION},\
cloud.region=ap-south-1"

export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4317"

export OTEL_TRACES_EXPORTER="otlp"
export OTEL_METRICS_EXPORTER="otlp"
```

The exact auto-instrumentation package depends on your language and runtime.

---

# Part 6 — Distributed Tracing

# 54. Trace mental model

A trace represents one distributed request.

```text
Trace:
POST /todos
    |
    ├── API Gateway span
    ├── Todo API span
    ├── Redis span
    ├── Aurora span
    └── EventBridge publish span
```

Each operation is represented by a span or, in X-Ray terminology, a segment or subsegment.

---

# 55. Trace hierarchy

```text
Trace ID:
Entire request

Span ID:
One operation

Parent span:
Caller

Child span:
Downstream work
```

Example:

```text
Trace ID:
abc123

API span:
span-1

Database span:
span-2
parent = span-1
```

Context propagation allows the tracing system to reconstruct the dependency chain.

---

# 56. Trace propagation

Service A must pass trace context to Service B.

```text
Browser
   |
   | Trace headers
   v
API Gateway
   |
   | Trace headers
   v
Todo API
   |
   | Trace headers
   v
Notification service
```

Without context propagation:

```text
Three unrelated traces
```

With propagation:

```text
One complete distributed trace
```

---

# 57. Sampling

Capturing every trace may be expensive at high traffic.

Sampling decides which requests receive full trace recording.

Example strategy:

```text
Always sample:
Errors
High-latency requests
Critical admin operations

Sample percentage:
Normal successful requests
```

Sampling must retain enough representative traffic to diagnose problems.

Do not sample only successful requests and accidentally omit every failure.

---

# 58. Annotations versus metadata

In X-Ray terminology:

## Annotation

Indexed and searchable.

Examples:

```text
tenantTier = premium
route = POST /todos
errorType = DatabaseTimeout
```

## Metadata

Stored with the trace but not indexed for trace-filter searching.

Examples:

```text
Detailed internal object
Debug information
Non-searchable diagnostics
```

Annotations and metadata can be added to trace segments, but annotations should use bounded, non-sensitive values because they are intended for searching. ([AWS Documentation][16])

---

# 59. Never put secrets into traces

Do not trace:

```text
Authorization header
Access token
Database password
Session cookie
Full request body containing sensitive data
Private customer documents
```

Trace tags, annotations and error messages can be visible to broad operational roles.

Use redaction at instrumentation boundaries.

---

# 60. Trace-to-log correlation

Add:

```text
traceId
spanId
requestId
```

to structured application logs.

Then:

```text
Trace:
Shows slow database span

Associated logs:
Show timeout and query category
```

CloudWatch Application Signals supports trace-to-log correlation and can inject trace and span identifiers into relevant logs for supported instrumentation. ([AWS Documentation][17])

---

# Part 7 — CloudWatch Application Signals

# 61. What is Application Signals?

Application Signals provides an application-centric view of:

```text
Services
Operations
Dependencies
Availability
Latency
Faults
SLOs
Traces
Topology
```

It can automatically collect telemetry from supported workloads running on services such as EC2, ECS, EKS, Kubernetes and Lambda through supported instrumentation paths. ([AWS Documentation][18])

---

# 62. Service map

```text
Frontend
   |
   v
Todo API
   |
   ├── Aurora
   ├── ElastiCache
   ├── EventBridge
   └── OpenSearch
```

Application Signals maps discovered services and dependencies, helping you identify:

* Which service is unhealthy.
* Which operation is failing.
* Which downstream dependency is slow.
* Whether the failure is localized or widespread.

---

# 63. SLI and SLO

## Service-level indicator

A measured behavior.

Examples:

```text
Availability
Latency
Successful-job percentage
Freshness
Durability
```

## Service-level objective

The desired target.

Examples:

```text
99.9% successful API requests
over a rolling 28-day period

99% of requests below 500 ms
```

Application Signals can automatically collect service availability and latency metrics and use them as SLI sources for SLO tracking. ([AWS Documentation][18])

---

# 64. Error budget

If an SLO is:

```text
99.9% success
```

the error budget is:

```text
0.1% unsuccessful
```

The error budget answers:

```text
How much unreliability can we tolerate
before the objective is missed?
```

Use error-budget burn to guide:

* Release speed.
* Incident urgency.
* Reliability investment.
* Risky deployment freezes.

---

# 65. Fast and slow burn alarms

Example:

```text
Fast burn:
Large error-budget consumption in one hour
→ Page immediately

Slow burn:
Sustained moderate degradation over several days
→ Create investigation or ticket
```

This is more useful than paging on every brief 5xx spike.

---

# 66. CloudWatch RUM

CloudWatch Real User Monitoring captures client-side experience such as:

```text
Page-load performance
JavaScript errors
HTTP errors
User sessions
Browser/device information
Geographic performance
```

RUM can integrate with Application Signals and traces to connect frontend experience to backend service health. ([AWS Documentation][19])

Use sampling and privacy controls carefully because client telemetry can contain:

* URLs.
* User-agent details.
* Session metadata.
* User interactions.

---

# 67. CloudWatch Synthetics

Synthetics canaries run scripted tests against an application.

```text
Canary
   |
   v
Open login page
   |
   v
Authenticate test user
   |
   v
Create todo
   |
   v
Validate response
```

Use for:

* External availability checks.
* Certificate and DNS validation.
* Login-flow validation.
* API contract tests.
* Critical user journey monitoring.

Synthetics can integrate with Application Signals and tracing for correlated troubleshooting. ([AWS Documentation][20])

---

# 68. Real users versus canaries

## RUM

```text
What are real users experiencing?
```

## Synthetics

```text
Can a controlled test complete the journey now?
```

Use both.

A real-user monitor may have no data at 03:00 when few users are active.

A canary can test continuously.

---

# Part 8 — AWS CloudTrail

# 69. What is CloudTrail?

CloudTrail records AWS account activity performed through:

```text
AWS Management Console
AWS CLI
AWS SDKs
AWS service APIs
Actions performed by AWS services
```

CloudTrail answers:

```text
Who?
What action?
Which resource?
When?
From which IP?
Using which client?
Was it successful?
```

CloudTrail event history is enabled by default and provides a searchable, immutable view of the previous 90 days of management events within each Region. ([AWS Documentation][21])

---

# 70. CloudTrail is not application logging

CloudTrail records:

```text
CreateBucket
RunInstances
PutRolePolicy
DeleteSecret
UpdateSecurityGroupRule
AssumeRole
```

It does not normally record:

```text
User clicked "Complete Todo"
Application validation failed
Database query took 3 seconds
```

Those belong in application metrics, logs and traces.

---

# 71. CloudTrail event types

CloudTrail currently defines four broad event categories:

```text
Management events
Data events
Network activity events
Insights events
```

Trails and event data stores log management events by default, but do not automatically include data, network activity or Insights events unless configured. ([AWS Documentation][22])

---

# 72. Management events

Management events represent control-plane operations.

Examples:

```text
Create an EC2 instance
Update an IAM role
Create an S3 bucket
Change an RDS instance
Delete a KMS key
Update a security group
```

Management events can be:

```text
Read-only
Write-only
Both
```

For security auditing, write management events are particularly important, but production trails should commonly retain both.

---

# 73. Data events

Data events represent high-volume resource-level operations.

Examples:

```text
S3 GetObject and PutObject
Lambda Invoke
DynamoDB item operations
SQS message data activity for supported selectors
```

Data events can be numerous and are not included by default because they can create significant event volume and cost. Configure advanced event selectors to include only the resources and operations needed. ([AWS Documentation][23])

Example:

```text
Log S3 object writes
for:
production-audit-bucket

Do not log:
Every read from every bucket
```

unless compliance requires it.

---

# 74. Network activity events

Network activity events record supported AWS API calls made through VPC endpoints.

Use cases:

* Determine which identity called a service through an endpoint.
* Detect credentials from outside the expected organization.
* Investigate VPC endpoint access denials.
* Audit private service access.

CloudTrail documents network activity events as a method for VPC endpoint owners to inspect AWS API activity through supported endpoints. ([AWS Documentation][24])

---

# 75. CloudTrail Insights

CloudTrail Insights detects unusual API activity by comparing current behavior to normal usage patterns.

Potential examples:

```text
Unusual spike in RunInstances
Unexpected increase in AccessDenied
Large burst of resource deletion calls
Abnormal management API error rate
```

Insights events require explicit configuration and incur additional costs. ([AWS Documentation][25])

Insights is not a replacement for:

* GuardDuty.
* IAM Access Analyzer.
* Security Hub.
* Custom CloudWatch alarms.
* Human investigation.

---

# 76. Event history versus trail

## Event history

```text
Automatically available
90 days
Management events
Per Region
Basic search and download
```

## Trail

```text
Explicitly configured
Delivers selected events to S3
Can cover all Regions
Can cover an organization
Can send to CloudWatch Logs
Can enable integrity validation
Long-term retention controlled through S3
```

Create a production trail even though event history exists.

---

# 77. Multi-Region trail

A multi-Region trail records applicable activity from all enabled AWS Regions and sends log files to the configured S3 destination. ([AWS Documentation][26])

This protects against an attacker or administrator creating resources in an unexpected Region that your primary-region-only trail would miss.

Recommended:

```text
is_multi_region_trail = true
include_global_service_events = true
```

---

# 78. Organization trail

An organization trail records activity across AWS Organizations accounts.

```text
Management account
or delegated administrator
        |
        v
Organization trail
        |
        v
Central security S3 bucket
        |
        ├── Account A
        ├── Account B
        └── Account C
```

New member accounts are automatically included in the organization trail, and member accounts cannot remove or modify it. ([AWS Documentation][27])

Use a dedicated log-archive or security account for the S3 destination.

---

# 79. Protecting CloudTrail S3 logs

Recommended controls:

```text
Dedicated logging account
Bucket Block Public Access
KMS encryption
Versioning
Object Lock where required
Restricted delete permissions
Lifecycle to archival storage
Access logging
CloudTrail integrity validation
```

Do not allow ordinary application administrators to delete central audit logs.

---

# 80. Log-file integrity validation

CloudTrail integrity validation uses:

```text
SHA-256 hashes
RSA digital signatures
Hourly digest files
Digest chaining
```

This lets you detect whether CloudTrail log or digest files were modified or deleted after delivery. ([AWS Documentation][28])

Enable:

```bash
aws cloudtrail update-trail \
  --name organization-security-trail \
  --enable-log-file-validation
```

Validation:

```bash
aws cloudtrail validate-logs \
  --trail-arn "$TRAIL_ARN" \
  --start-time "2026-08-01T00:00:00Z" \
  --end-time "2026-08-02T00:00:00Z"
```

The CLI uses the delivered digest files to validate referenced log files. ([AWS Documentation][29])

---

# 81. CloudTrail to CloudWatch Logs

A trail can deliver events to:

```text
Amazon S3
and optionally
CloudWatch Logs
```

S3 is the durable audit archive.

CloudWatch Logs enables:

* Near-real-time metric filters.
* Alarms.
* Logs Insights queries.
* Subscription to a security platform.

Example alerts:

```text
Root account use
Console login without MFA
Security-group changes
KMS key disable
CloudTrail stop logging
IAM policy changes
Secret deletion
```

CloudTrail provides examples of creating metric filters and CloudWatch alarms from audit events. ([AWS Documentation][30])

---

# 82. CloudTrail Lake current availability

**Important update as of August 2, 2026:** AWS documentation states that **CloudTrail Lake stopped accepting new customers on May 31, 2026**. Existing CloudTrail Lake customers can continue using it. ([AWS Documentation][31])

For a new environment that does not already have CloudTrail Lake access, design around:

```text
Organization trail
    |
    v
Central S3 bucket
    |
    ├── Athena queries
    ├── Security data lake
    ├── OpenSearch/SIEM pipeline
    └── Long-term archive
```

Do not design a new 2026 architecture assuming every account can newly enable CloudTrail Lake.

---

# 83. CloudTrail Athena query concept

Example investigation:

```sql
SELECT
    eventtime,
    eventname,
    useridentity.arn,
    sourceipaddress,
    errorcode
FROM cloudtrail_logs
WHERE eventname = 'ScheduleKeyDeletion'
ORDER BY eventtime DESC;
```

Use partitioned S3 layouts and bounded time ranges to reduce scanned data.

---

# Part 9 — AWS Config

# 84. What is AWS Config?

AWS Config records resource configuration details and relationships.

Example EC2 configuration item:

```text
Instance type
AMI
Security groups
Subnet
IAM instance profile
Tags
Public IP
Related resources
Capture time
```

AWS Config provides historical and current configuration views, including how resources relate to each other. ([AWS Documentation][32])

---

# 85. Configuration item

A configuration item is a point-in-time representation of a resource.

```text
Resource:
Security group sg-123

09:00:
Port 22 open from corporate CIDR

11:00:
Port 22 open from 0.0.0.0/0

13:00:
Port 22 restricted again
```

AWS Config records these states as configuration items when the resource is within the recorder’s scope. ([AWS Documentation][33])

---

# 86. CloudTrail versus AWS Config

Suppose port 22 was opened publicly.

## CloudTrail tells you:

```text
Who called AuthorizeSecurityGroupIngress?
When?
From which IP?
Using which role?
```

## AWS Config tells you:

```text
What was the security group configuration before?
What was it after?
Which resources are related?
Is it currently compliant?
```

Use both for investigation.

---

# 87. Configuration recorder

AWS Config uses a configuration recorder to select which resource types and changes are recorded.

You can record:

```text
All supported resource types
Selected resource types
Global resource types where applicable
Continuous changes
Daily snapshots for supported recorder choices
```

AWS Config supports configuring recording frequency, including daily recording to reduce configuration-item volume for suitable resources. ([AWS Documentation][34])

---

# 88. Continuous versus daily recording

## Continuous

Records configuration changes as they occur.

Use for:

* IAM.
* Security groups.
* KMS.
* S3 security.
* Network resources.
* Production databases.
* Critical compliance resources.

## Daily

Records a configuration item once per day when applicable.

Use for:

* Lower-risk resources.
* Highly ephemeral workloads where every change is unnecessary.
* Cost-sensitive inventory.

Do not use daily recording for a resource where a dangerous change lasting two hours must be detected immediately.

---

# 89. Ephemeral-resource cost

Highly dynamic resources can create many configuration items.

Examples:

```text
Short-lived EC2 Spot instances
EMR jobs
Auto Scaling instances
Ephemeral container-related resources
```

AWS recommends excluding unnecessary ephemeral resource types or using appropriate recording frequency when the detailed history is not needed. ([AWS Documentation][35])

Cost optimization must not disable recording for security-critical resources merely because they change frequently.

---

# 90. Delivery channel

AWS Config can deliver:

```text
Configuration history
Configuration snapshots
Compliance notifications
```

to:

```text
Amazon S3
Amazon SNS where configured
```

Use a central S3 bucket with lifecycle and access controls for durable history.

---

# 91. AWS Config rule

A Config rule evaluates whether a resource complies with a condition.

Example:

```text
Rule:
S3 buckets must have server-side encryption

Resource:
production-todo-uploads

Evaluation:
COMPLIANT
or
NON_COMPLIANT
```

Rules can be:

```text
AWS managed rules
Custom Lambda rules
Custom Guard policy rules
```

AWS Config supports Lambda- and Guard-based custom rules. ([AWS Documentation][36])

---

# 92. Change-triggered versus periodic evaluation

## Change-triggered

Evaluate when relevant configuration changes.

Example:

```text
Security group changes
    |
    v
Evaluate public SSH rule
```

## Periodic

Evaluate on a schedule.

Example:

```text
Every 24 hours:
Check certificate expiry
```

Choose evaluation mode according to the rule’s data source and urgency.

---

# 93. Useful Config rules

Examples:

```text
S3 public access blocked
S3 encryption enabled
CloudTrail enabled
Root account MFA enabled
Security groups do not expose SSH
RDS storage encrypted
EBS encryption enabled
IAM access keys rotated
ACM certificates not nearing expiry
VPC flow logs enabled
```

Do not enable hundreds of rules without:

* Ownership.
* Remediation process.
* Exception handling.
* Cost review.
* Severity classification.

---

# 94. Remediation

AWS Config remediation uses Systems Manager Automation documents.

```text
AWS Config rule
      |
      v
NON_COMPLIANT
      |
      v
SSM Automation
      |
      v
Repair resource
```

AWS Config supports manual and automatic remediation through Systems Manager Automation. ([AWS Documentation][37])

---

# 95. Automatic remediation risks

Example rule:

```text
Security group exposes port 22 publicly
```

Automatic remediation:

```text
Remove 0.0.0.0/0 ingress
```

Potential risk:

* Emergency access intentionally enabled.
* Automation removes a newer approved configuration.
* Rule evaluates stale configuration.
* Remediation loops with another system.
* Shared resource affects several teams.

Use:

```text
Maximum attempts
Retry interval
Resource-specific controls
Change approval
Exception tags
Idempotent automation
```

Start with manual remediation or notification before enabling automatic changes.

---

# 96. Conformance packs

A conformance pack is a collection of:

```text
AWS Config rules
Remediation actions
Input parameters
```

deployed as one compliance package.

Examples:

```text
Production baseline
PCI-oriented controls
Encryption baseline
Public-access prevention
Organizational tagging policy
```

Conformance packs can be deployed to one account and Region or organization-wide through AWS Organizations. ([AWS Documentation][38])

---

# 97. Configuration aggregator

An aggregator collects configuration and compliance data from:

```text
Multiple accounts
Multiple Regions
AWS Organizations
```

into a central view. ([AWS Documentation][39])

Architecture:

```text
Account A / Mumbai ─────┐
Account A / Singapore ──┤
Account B / Mumbai ─────┼──> Central Config aggregator
Account C / Frankfurt ──┘
```

An aggregator does not replace enabling AWS Config in source accounts and Regions.

It centralizes recorded data.

---

# 98. Advanced Config queries

AWS Config advanced queries let you search current resource configuration.

Conceptual examples:

```sql
SELECT
  resourceId,
  resourceName,
  configuration.instanceType
WHERE
  resourceType = 'AWS::EC2::Instance'
```

Find publicly addressed EC2 instances:

```sql
SELECT
  resourceId,
  configuration.publicIpAddress
WHERE
  resourceType = 'AWS::EC2::Instance'
```

Use an aggregator to run inventory queries across accounts and Regions.

---

# Part 10 — Multi-account Observability

# 99. Central monitoring architecture

```text
Workload accounts
├── Development
├── Staging
├── Production A
└── Production B
        |
        v
CloudWatch cross-account observability
        |
        v
Monitoring account
        |
        ├── Dashboards
        ├── Logs Insights
        ├── Traces
        ├── Application Signals
        └── SLOs
```

CloudWatch cross-account observability uses a monitoring account and source accounts to view telemetry across accounts within a Region. Shared data can include metrics, logs, traces, Application Signals services and SLOs. ([AWS Documentation][40])

---

# 100. Observability Access Manager

Observability Access Manager, or OAM, creates:

```text
Sink:
Monitoring account destination

Link:
Source account connection
```

```text
Source account
    |
    | OAM link
    v
Monitoring-account sink
```

Use AWS Organizations policies or automated infrastructure to onboard accounts consistently.

---

# 101. Cross-Region centralization

Cross-account observability commonly operates within a Region.

For wider centralization, CloudWatch also supports cross-account and cross-Region centralization patterns for metrics and logs. ([AWS Documentation][41])

Possible architecture:

```text
Regional telemetry
      |
      v
Central monitoring/security account
      |
      ├── Central dashboards
      ├── Central log groups
      └── S3 security archive
```

Consider:

* Data-transfer cost.
* Regional outage isolation.
* Data residency.
* Query latency.
* IAM boundaries.

---

# 102. Metric streams

Metric streams continuously deliver CloudWatch metric updates with low latency to destinations through Data Firehose.

Use cases:

* Central S3 metric archive.
* Third-party observability platform.
* Organization-wide analytics.
* Near-real-time external monitoring.

CloudWatch metric streams provide continuous near-real-time metric delivery. ([AWS Documentation][42])

Avoid repeatedly polling every metric through `GetMetricData` when a stream is the appropriate architecture.

---

# Part 11 — Incident Investigation

# 103. Incident workflow

```text
1. Confirm customer impact.

2. Identify affected service and Region.

3. Check deployments.

4. Inspect RED and USE metrics.

5. Find correlated logs.

6. Open slow or failed traces.

7. Check CloudTrail activity.

8. Check AWS Config changes.

9. Mitigate safely.

10. Validate recovery.

11. Document timeline and root cause.
```

---

# 104. Example incident: API 5xx increase

Alert:

```text
Todo API 5xx rate > 5%
```

## Step 1: Dashboard

```text
Traffic:
Normal

Latency:
High

5xx:
High

Healthy targets:
All healthy
```

## Step 2: Logs

```text
errorType:
DatabaseAuthenticationFailed
```

## Step 3: Traces

```text
API:
40 ms

Aurora connection:
Failure
```

## Step 4: CloudTrail

```text
PutSecretValue
occurred 10 minutes before incident
```

## Step 5: Secrets Manager

```text
AWSCURRENT:
New password

Database:
Old password
```

Root cause:

```text
Secret changed without rotating actual database credential
```

---

# 105. Example incident: application latency

Metrics:

```text
ALB p95 latency:
5 seconds

ECS CPU:
35%

Aurora CPU:
40%

Redis hit rate:
Dropped from 95% to 5%
```

Trace:

```text
Cache lookup:
Fast miss

Database query:
4.5 seconds
```

Logs:

```text
Cache key prefix changed after deployment
```

Root cause:

```text
Deployment changed cache-key format
causing a cache-miss storm
```

---

# 106. Example incident: public SSH

AWS Config:

```text
NON_COMPLIANT:
Security group allows 0.0.0.0/0 on port 22
```

CloudTrail:

```text
AuthorizeSecurityGroupIngress

Principal:
TemporaryAdminRole

Source IP:
Corporate VPN

Time:
12:42 IST
```

Deployment data:

```text
No Terraform apply
```

Conclusion:

```text
Manual console change
outside approved infrastructure workflow
```

Response:

```text
Remove rule
Investigate role session
Review approval
Prevent drift
```

---

# Part 12 — Cost Control

# 107. Main CloudWatch cost drivers

```text
Custom metrics
High-cardinality dimensions
High-resolution metrics
Log ingestion
Log storage
Logs Insights scanned data
Dashboards
Alarms
Metric streams
Synthetics
RUM
Application Signals
Trace ingestion and retrieval
```

---

# 108. Custom-metric cost control

Avoid:

```text
Metric dimension = requestId
Metric dimension = userId
Metric dimension = full URL
```

Prefer:

```text
Bounded metric dimensions
+
High-cardinality structured logs
```

Review custom namespaces regularly:

```text
TodoApp/Production
TodoApp/Workers
TodoApp/Business
```

Delete obsolete alarms and dashboards.

---

# 109. Log-cost control

Use:

* Explicit retention.
* Structured concise events.
* Appropriate log levels.
* Sampling for noisy debug logs.
* Infrequent Access for rarely queried logs.
* Delivery class for supported Lambda-to-S3/Firehose patterns.
* Field indexes for frequent exact searches.
* Narrow query time ranges.
* Central S3 archive for long retention.

EMF can generate both log-ingestion and custom-metric costs, so its dimension design must be reviewed carefully. ([AWS Documentation][43])

---

# 110. Avoid duplicate telemetry

Common duplication:

```text
Application logs to CloudWatch
and
Same logs to Firehose
and
Same logs to OpenSearch
and
Same logs retained indefinitely in all destinations
```

Document the purpose of each destination:

```text
CloudWatch:
Operational hot search

S3:
Long-term archive

OpenSearch:
Security or interactive analytics
```

Set independent retention according to that purpose.

---

# 111. Trace-cost control

Use:

* Sampling.
* Higher sampling for failures.
* Lower sampling for routine success.
* Bounded annotations.
* Avoid very large span attributes.
* Instrument meaningful dependencies.
* Exclude health-check noise where appropriate.

Do not disable tracing completely because the application is busy.

Sample intelligently.

---

# 112. CloudTrail cost control

CloudTrail management-event trails are foundational.

Control costs mainly by carefully selecting high-volume:

```text
Data events
Network activity events
Insights events
```

Use advanced event selectors to include only required:

* Resources.
* Event names.
* Read/write categories.
* Account or service patterns.

Do not disable critical audit logging purely to reduce cost.

---

# 113. AWS Config cost control

Review:

```text
Recorded resource types
Continuous versus daily recording
Ephemeral resources
Number of rule evaluations
Conformance-pack scope
Number of Regions
Duplicate rules
```

Use a separate ephemeral-workload account or narrower recorder scope when detailed configuration history is unnecessary, while preserving full recording for security-critical resources. ([AWS Documentation][35])

---

# Part 13 — Terraform Implementation

# 114. CloudWatch log group

```hcl
resource "aws_cloudwatch_log_group" "todo_api" {
  name = "/aws/ecs/production/todo-api"

  retention_in_days = 30

  kms_key_id = aws_kms_key.logs.arn

  log_group_class = "STANDARD"

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

Use `INFREQUENT_ACCESS` only after confirming that the required CloudWatch Logs features are supported for that group.

---

# 115. Application-error metric filter

```hcl
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name = "production-todo-api-errors"

  log_group_name = aws_cloudwatch_log_group.todo_api.name

  pattern = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "TodoApp/Production"
    value     = "1"

    default_value = "0"

    dimensions = {
      Service     = "$.service"
      Environment = "$.environment"
    }
  }
}
```

Do not extract `requestId` or `userId` as metric dimensions.

---

# 116. Error alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name = "production-todo-api-errors"

  namespace   = "TodoApp/Production"
  metric_name = "ApplicationErrors"

  dimensions = {
    Service     = "todo-api"
    Environment = "production"
  }

  statistic = "Sum"

  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  ok_actions = [
    aws_sns_topic.operations.arn
  ]

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Use a separate telemetry-heartbeat alarm if missing logs would indicate collector failure.

---

# 117. ALB 5xx-percentage alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx_percentage" {
  alarm_name = "production-todo-alb-5xx-percentage"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  threshold = 5

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests>0,100*errors/requests,0)"
    label       = "ALB 5xx percentage"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.todo.arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.todo.arn_suffix
      }
    }
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]
}
```

An error percentage is generally more meaningful than only an absolute 5xx count.

---

# 118. Composite alarm

```hcl
resource "aws_cloudwatch_composite_alarm" "todo_api_incident" {
  alarm_name = "production-todo-api-customer-impact"

  alarm_rule = join(" AND ", [
    "ALARM(${aws_cloudwatch_metric_alarm.alb_5xx_percentage.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.api_latency.alarm_name})"
  ])

  alarm_actions = [
    aws_sns_topic.critical_incidents.arn
  ]

  actions_enabled = true
}
```

Use component alarms for investigation and the composite alarm for paging.

---

# 119. CloudWatch dashboard

```hcl
resource "aws_cloudwatch_dashboard" "todoapp" {
  dashboard_name = "production-todoapp"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width  = 12
        height = 6

        properties = {
          title  = "API request and 5xx rate"
          region = "ap-south-1"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.todo.arn_suffix
            ],
            [
              ".",
              "HTTPCode_Target_5XX_Count",
              ".",
              "."
            ]
          ]
        }
      },
      {
        type = "metric"
        x    = 12
        y    = 0
        width  = 12
        height = 6

        properties = {
          title  = "SQS oldest message age"
          region = "ap-south-1"
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60

          metrics = [
            [
              "AWS/SQS",
              "ApproximateAgeOfOldestMessage",
              "QueueName",
              aws_sqs_queue.todo_processing.name
            ]
          ]
        }
      }
    ]
  })
}
```

---

# 120. CloudTrail S3 bucket

```hcl
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "company-central-cloudtrail-${data.aws_caller_identity.current.account_id}"

  force_destroy = false

  tags = {
    Purpose   = "security-audit"
    ManagedBy = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

A CloudTrail-specific bucket policy is also required to permit CloudTrail delivery while denying unauthorized writes.

---

# 121. Multi-Region CloudTrail trail

```hcl
resource "aws_cloudtrail" "organization" {
  name = "organization-security-trail"

  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  is_multi_region_trail         = true
  include_global_service_events = true

  enable_log_file_validation = true

  enable_logging = true

  cloud_watch_logs_group_arn = (
    "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  )

  cloud_watch_logs_role_arn = (
    aws_iam_role.cloudtrail_cloudwatch.arn
  )

  event_selector {
    include_management_events = true
    read_write_type           = "All"
  }

  tags = {
    Purpose   = "security-audit"
    ManagedBy = "Terraform"
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail
  ]
}
```

For an AWS Organizations trail, add the organization-trail setting and configure it from the management or delegated-administrator account.

---

# 122. CloudTrail metric filter for KMS deletion

```hcl
resource "aws_cloudwatch_log_metric_filter" "kms_deletion" {
  name = "kms-key-deletion-scheduled"

  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  pattern = <<PATTERN
{ ($.eventSource = "kms.amazonaws.com") &&
  ($.eventName = "ScheduleKeyDeletion") }
PATTERN

  metric_transformation {
    name      = "KmsKeyDeletionScheduled"
    namespace = "Security/CloudTrail"
    value     = "1"
  }
}
```

Alarm:

```hcl
resource "aws_cloudwatch_metric_alarm" "kms_deletion" {
  alarm_name = "security-kms-key-deletion-scheduled"

  namespace   = "Security/CloudTrail"
  metric_name = "KmsKeyDeletionScheduled"

  statistic = "Sum"
  period    = 60

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_sns_topic.security.arn
  ]
}
```

---

# 123. AWS Config recorder

```hcl
resource "aws_iam_role" "config" {
  name = "aws-config-recorder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "config.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name     = "production-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}
```

Attach the AWS managed service-role policy or an equivalent least-privilege policy required by AWS Config.

---

# 124. AWS Config delivery channel

```hcl
resource "aws_config_delivery_channel" "main" {
  name = "production-delivery"

  s3_bucket_name = aws_s3_bucket.config.id

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [
    aws_config_configuration_recorder.main
  ]
}
```

Enable the recorder only after the delivery channel exists.

```hcl
resource "aws_config_configuration_recorder_status" "main" {
  name = aws_config_configuration_recorder.main.name

  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.main
  ]
}
```

---

# 125. Managed Config rule

```hcl
resource "aws_config_config_rule" "s3_encryption" {
  name = "s3-bucket-server-side-encryption-enabled"

  description = "Checks whether S3 buckets have server-side encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.main
  ]

  tags = {
    Environment = "production"
    Control     = "encryption"
  }
}
```

---

# Part 14 — Hands-on Lab

# 126. Lab goal

Build a minimal operational signal:

```text
Structured log
    |
    v
CloudWatch Logs
    |
    v
Metric filter
    |
    v
Custom metric
    |
    v
Alarm
```

Then verify the management API activity through CloudTrail event history.

Region:

```text
ap-south-1
```

Estimated focused time:

```text
30–45 minutes
```

---

# 127. Create a log group

```bash
LOG_GROUP="/lab/todoapp/observability"
LOG_STREAM="manual-test"

aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --region ap-south-1

aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 7 \
  --region ap-south-1

aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --region ap-south-1
```

---

# 128. Create a metric filter

```bash
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "TodoAppLabErrors" \
  --filter-pattern '{ $.level = "ERROR" }' \
  --metric-transformations \
    metricName=ApplicationErrors,metricNamespace=TodoApp/Lab,metricValue=1,defaultValue=0 \
  --region ap-south-1
```

---

# 129. Publish test logs

```bash
TIMESTAMP=$(date +%s000)

aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events \
    timestamp=$TIMESTAMP,message='{"level":"INFO","service":"todo-api","message":"Request completed","requestId":"lab-001","durationMs":42}' \
    timestamp=$((TIMESTAMP + 1)),message='{"level":"ERROR","service":"todo-api","message":"Database timeout","requestId":"lab-002","errorType":"DatabaseTimeout","durationMs":5000}' \
  --region ap-south-1
```

---

# 130. Create an alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "todoapp-lab-application-errors" \
  --namespace "TodoApp/Lab" \
  --metric-name "ApplicationErrors" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --region ap-south-1
```

Wait for metric extraction, then inspect:

```bash
aws cloudwatch describe-alarms \
  --alarm-names "todoapp-lab-application-errors" \
  --region ap-south-1
```

---

# 131. Query logs

```bash
QUERY_ID=$(
  aws logs start-query \
    --log-group-name "$LOG_GROUP" \
    --start-time $(( $(date +%s) - 3600 )) \
    --end-time $(date +%s) \
    --query-string '
      fields @timestamp, level, message, requestId, errorType, durationMs
      | filter level = "ERROR"
      | sort @timestamp desc
    ' \
    --region ap-south-1 \
    --query queryId \
    --output text
)

sleep 3

aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --region ap-south-1
```

---

# 132. Find the alarm API call in CloudTrail

CloudTrail event history records management events automatically.

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=PutMetricAlarm \
  --max-results 10 \
  --region ap-south-1
```

Inspect:

```text
Username or assumed role
Source IP
Event time
Request parameters
AWS Region
```

---

# 133. Optional Config check

When AWS Config is already enabled in the account:

```bash
aws configservice describe-configuration-recorder-status \
  --region ap-south-1

aws configservice describe-compliance-by-config-rule \
  --region ap-south-1
```

Do not enable AWS Config casually in a large account without reviewing recorder scope and cost.

---

# 134. Cleanup

```bash
aws cloudwatch delete-alarms \
  --alarm-names "todoapp-lab-application-errors" \
  --region ap-south-1

aws logs delete-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "TodoAppLabErrors" \
  --region ap-south-1

aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region ap-south-1
```

The CloudTrail event-history records remain available according to CloudTrail’s normal event-history retention.

---

# Part 15 — Troubleshooting

# 135. Alarm remains `INSUFFICIENT_DATA`

Check:

```text
Metric namespace
Metric name
Dimensions
Period
Statistic
Region
Metric publication timestamp
Missing-data setting
Delayed metric extraction
```

Common failure:

```text
Published metric dimensions:
Service=todo-api
Environment=production

Alarm dimensions:
Service=todo-api
```

These are different metric identities.

---

# 136. Alarm never fires

Check:

* Comparison operator.
* Threshold.
* Unit.
* Statistic.
* Period.
* Evaluation window.
* M-out-of-N settings.
* Metric math expression.
* Dimension case.
* Alarm actions enabled.
* Metric delay.
* Anomaly band configuration.

Graph the exact metric query used by the alarm.

Do not debug only from the application logs.

---

# 137. Alarm fires constantly

Possible causes:

* Threshold too close to normal behavior.
* Using average when p95 is required.
* Missing data treated as breaching.
* One short spike causes 1-of-1 alarm.
* No deployment suppression.
* Metric dimensions combine unrelated workloads.
* Alarm evaluates low-traffic percentages incorrectly.

Improve:

```text
M-out-of-N
Minimum request volume
Composite alarms
Anomaly detection
SLO burn-rate alarms
```

---

# 138. No logs from EC2 or container

Check:

* Application writes to expected file or stdout.
* CloudWatch agent or log driver is running.
* IAM role has log permissions.
* Log group and Region.
* Disk/file permissions.
* Agent configuration.
* Network or VPC endpoint access.
* KMS key policy.
* Retention did not delete old data.
* Container log configuration.

For ECS with `awslogs`, inspect the task-definition log configuration and ECS task execution role.

---

# 139. Logs Insights query is expensive or slow

Check:

* Time range too large.
* Too many log groups.
* No early filter.
* Parsing unstructured text.
* No field index for equality search.
* Query scans archive data unnecessarily.
* Duplicate logs across groups.
* Infrequent Access command limitations.

Improve:

```text
Narrow time
Narrow log groups
Filter early
Use structured JSON
Index common exact-match fields
Limit returned columns
```

---

# 140. Log-subscription destination is not receiving

Check:

* Subscription filter enabled.
* Filter matches actual event.
* Destination resource policy.
* IAM role.
* Kinesis or Firehose throttling.
* Lambda concurrency.
* Destination Region.
* KMS permission.
* CloudWatch Logs delivery-error metrics.
* Recursion prevention.

CloudWatch retries retryable subscription failures, but non-retryable authorization or missing-resource failures require configuration repair. ([AWS Documentation][13])

---

# 141. Trace is incomplete

Check:

* Services use compatible context propagation.
* Sampling decision propagated.
* Async messaging passes trace context.
* Collector is reachable.
* OpenTelemetry exporter is configured.
* IAM permits trace export.
* Unsupported library.
* Application exits before flushing.
* Load balancer or gateway tracing configuration.
* Trace header overwritten.

For asynchronous messaging, preserve both:

```text
Trace context:
Technical call relationship

Correlation/causation IDs:
Business workflow relationship
```

---

# 142. Application Signals shows no service

Check:

* Runtime is supported.
* ADOT or agent installed.
* Instrumentation enabled.
* CloudWatch agent running.
* IAM permissions.
* Region support.
* Service name configured.
* Traffic actually reached the service.
* Collector/exporter errors.
* Network access to telemetry endpoints.

Application Signals requires supported instrumentation and telemetry collection for the workload environment. ([AWS Documentation][44])

---

# 143. CloudTrail event not found

Check:

* Correct Region.
* Event occurred within 90 days.
* It was a management event.
* Event history search attribute.
* Read versus write event.
* Event was performed in another account.
* Trail selector includes event type.
* Data events were enabled.
* Trail logging is active.
* Resource uses a global service location.

Event history does not automatically contain every data event.

---

# 144. CloudTrail S3 logs stopped

Check:

* Trail status.
* S3 bucket policy.
* KMS key policy.
* Bucket exists.
* CloudTrail service principal.
* Organization-trail permissions.
* Trail Region.
* CloudTrail delivery errors.
* Service-linked role.
* Object ownership controls.
* Bucket deny statements.

Run:

```bash
aws cloudtrail get-trail-status \
  --name "$TRAIL_NAME" \
  --region ap-south-1
```

Inspect:

```text
IsLogging
LatestDeliveryTime
LatestDeliveryError
LatestCloudWatchLogsDeliveryError
```

---

# 145. CloudTrail integrity validation fails

Possible causes:

* Log or digest file changed.
* File deleted.
* Digest chain incomplete.
* Logs moved from original location.
* Wrong time range.
* Wrong trail ARN.
* Validation files not yet delivered.
* S3 access denied.

Treat unexplained integrity failures as a security investigation, not only an operational warning.

---

# 146. AWS Config shows no resources

Check:

* Recorder exists.
* Recorder is enabled.
* Delivery channel exists.
* IAM role.
* Recorder scope.
* Resource type supported in Region.
* Region is correct.
* Recording frequency.
* Recently enabled recorder.
* Organization deployment status.

Commands:

```bash
aws configservice describe-configuration-recorders \
  --region ap-south-1

aws configservice describe-configuration-recorder-status \
  --region ap-south-1
```

---

# 147. Config rule remains `NOT_APPLICABLE`

Possible reasons:

* Rule does not evaluate that resource type.
* Resource was deleted.
* Evaluation trigger does not apply.
* Required parameter missing.
* Recorder does not record the resource.
* Region does not support the resource/rule combination.

`NOT_APPLICABLE` is different from `COMPLIANT`.

---

# 148. Automatic remediation fails

Check:

* SSM Automation document exists.
* Config remediation role can assume required role.
* Parameters map correctly.
* Resource still exists.
* Automation concurrency.
* Retry settings.
* KMS permissions.
* Cross-account access.
* Exception tags.
* Automation execution logs.

Inspect SSM Automation execution history rather than only the Config compliance result.

---

# 149. Config costs increased unexpectedly

Investigate:

* New ephemeral resources.
* Recorder changed to all resources.
* Continuous recording enabled.
* New Region enabled.
* Organization conformance pack deployed.
* Duplicate rules.
* High-frequency resource updates.
* Auto Scaling or EMR activity.
* Short-lived resources.

Do not stop the recorder immediately.

First identify which resource types generate the configuration-item volume.

---

# 150. Production readiness checklist

```text
[ ] Metrics, logs and traces have documented ownership
[ ] Business SLIs and SLOs are defined
[ ] RED metrics exist for request-driven services
[ ] USE metrics exist for infrastructure resources
[ ] p95 and p99 latency are monitored
[ ] Custom dimensions are bounded
[ ] High-cardinality values remain in logs/traces
[ ] High-resolution metrics are used intentionally
[ ] Metric math calculates rates and percentages
[ ] Alarms use appropriate M-out-of-N settings
[ ] Missing-data treatment is explicit
[ ] Telemetry-heartbeat alarms exist
[ ] Composite alarms reduce page duplication
[ ] Customer-impact alarms page operators
[ ] Cause alarms remain available for diagnosis
[ ] Every alarm has an owner and runbook
[ ] Dashboards begin with customer impact
[ ] Logs are structured JSON
[ ] Logs include request and trace IDs
[ ] Secrets and tokens are redacted
[ ] Every log group has explicit retention
[ ] Log class is intentional
[ ] Logs Insights queries use bounded time ranges
[ ] Field indexes exist for common exact searches
[ ] Subscription filters cannot recurse
[ ] CloudWatch Agent configuration is managed centrally
[ ] New tracing uses OpenTelemetry/ADOT
[ ] Trace context propagates across services
[ ] Async events include correlation and causation IDs
[ ] Trace sampling preserves failures
[ ] Application Signals is enabled where useful
[ ] SLO burn-rate alarms exist
[ ] RUM privacy settings are reviewed
[ ] Synthetics canaries test critical journeys
[ ] Multi-Region CloudTrail is enabled
[ ] Organization trail is stored in a security account
[ ] CloudTrail log-file validation is enabled
[ ] S3 audit logs are protected from deletion
[ ] Management events are recorded
[ ] Data-event selectors are intentional
[ ] Network activity events are evaluated
[ ] CloudTrail stop/delete actions are alarmed
[ ] New architecture does not assume CloudTrail Lake eligibility
[ ] AWS Config records security-critical resources continuously
[ ] Ephemeral resource recording is cost reviewed
[ ] Config rules have owners
[ ] Conformance packs are version controlled
[ ] Automatic remediation is tested and bounded
[ ] Multi-account Config aggregation exists
[ ] OAM central monitoring is configured
[ ] Observability costs are reviewed monthly
[ ] Incident drills correlate all telemetry sources
```

---

# 151. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
CloudWatch:
Metrics, logs, alarms and dashboards

CloudTrail:
AWS API audit activity

AWS Config:
Resource configuration and compliance

X-Ray:
Distributed request tracing
```

## Solutions Architect Associate

Understand:

```text
Custom metrics
CloudWatch alarms
Log groups and retention
Logs Insights
CloudWatch Agent
CloudTrail trails
Management versus data events
Config rules
Config aggregators
X-Ray traces
```

## DevOps Engineer Professional

Understand:

```text
Metric math
Anomaly detection
Composite alarms
Embedded Metric Format
Logs subscriptions
Cross-account observability
OpenTelemetry and ADOT
Application Signals
SLOs and error budgets
Organization trails
Log-file validation
Advanced event selectors
Config conformance packs
Automatic remediation
Incident correlation
Observability cost control
```

---

# 152. Interview questions

## Question 1: What is Amazon CloudWatch?

**Answer:**

CloudWatch is AWS’s monitoring and observability service for metrics, logs, alarms, dashboards, application performance and related telemetry.

## Question 2: What is the difference between CloudWatch and CloudTrail?

**Answer:**

CloudWatch monitors application and infrastructure behavior. CloudTrail records AWS API activity for auditing and investigation.

## Question 3: What is the difference between CloudTrail and AWS Config?

**Answer:**

CloudTrail records the API action and identity that changed a resource. AWS Config records the resulting resource configuration and its historical states.

## Question 4: What is metric cardinality?

**Answer:**

Cardinality is the number of unique metric-series combinations produced by dimensions. Unbounded values such as user IDs can create excessive custom metrics and cost.

## Question 5: What is Embedded Metric Format?

**Answer:**

EMF is a structured log format from which CloudWatch automatically extracts custom metrics while retaining detailed log context.

## Question 6: What is an M-out-of-N alarm?

**Answer:**

It alarms when a specified number of data points out of a larger evaluation window breach the threshold, reducing sensitivity to short spikes.

## Question 7: What is a composite alarm?

**Answer:**

It combines the states of several underlying alarms into one higher-level alarm, reducing notification noise and representing broader incident conditions.

## Question 8: What is anomaly detection?

**Answer:**

CloudWatch anomaly detection models expected metric behavior and creates a dynamic expected range based on historical patterns.

## Question 9: What is the difference between Standard and Infrequent Access log classes?

**Answer:**

Standard provides the full CloudWatch Logs feature set. Infrequent Access reduces ingestion cost for rarely queried logs but supports fewer operational features.

## Question 10: Why should logs be structured?

**Answer:**

Structured logs allow reliable field extraction, filtering, aggregation, metric creation and correlation between services.

## Question 11: What is distributed tracing?

**Answer:**

Distributed tracing follows one request across several services and records the time and result of each operation.

## Question 12: What instrumentation should new AWS tracing projects prefer in 2026?

**Answer:**

OpenTelemetry or AWS Distro for OpenTelemetry, because AWS placed the older X-Ray SDKs and daemon into maintenance mode in February 2026.

## Question 13: What is CloudWatch Application Signals?

**Answer:**

It provides an application-centric view of services, operations, dependencies, latency, availability, traces and SLOs.

## Question 14: What is CloudTrail event history?

**Answer:**

It is the automatically available searchable history of the previous 90 days of management events in each AWS Region.

## Question 15: What are CloudTrail data events?

**Answer:**

They are high-volume resource-level operations such as S3 object access and Lambda invocation, and they must normally be explicitly configured.

## Question 16: What is CloudTrail integrity validation?

**Answer:**

It uses signed digest files and cryptographic hashes to detect modification or deletion of delivered CloudTrail log files.

## Question 17: What is an AWS Config configuration item?

**Answer:**

It is a point-in-time representation of a supported resource’s configuration, relationships and metadata.

## Question 18: What is a Config conformance pack?

**Answer:**

It is a deployable collection of Config rules and remediation actions representing a compliance framework.

## Question 19: What is a Config aggregator?

**Answer:**

It collects recorded resource configuration and compliance data from multiple accounts and Regions into a central view.

## Question 20: How would you investigate a production infrastructure change?

**Answer:**

Use CloudWatch to identify impact, logs and traces to find application symptoms, CloudTrail to determine who made the API call and AWS Config to compare resource configuration before and after the change.

---

# 153. Never-forget revision

```text
Metric:
Numerical value over time.

Dimension:
Metric-series identity.

High cardinality:
Too many unique dimension combinations.

Log:
Detailed event record.

Trace:
One request across services.

Alarm:
Evaluates a metric condition.

Composite alarm:
Combines alarm states.

Anomaly detection:
Dynamic expected metric range.

EMF:
Metrics embedded in structured logs.

Application Signals:
Application service health and SLO view.

RUM:
Real-user client experience.

Synthetics:
Scripted user-journey monitoring.

CloudTrail:
AWS API audit history.

Management event:
Control-plane action.

Data event:
Resource-level operation.

Network activity event:
AWS API activity through a VPC endpoint.

Config item:
Point-in-time resource configuration.

Config rule:
Compliance evaluation.

Conformance pack:
Collection of rules and remediation.

Aggregator:
Central multi-account, multi-Region Config view.

OpenTelemetry:
Vendor-neutral telemetry standard.
```

## One-line memory trick

```text
Use metrics to detect.
Use logs to explain.
Use traces to follow.
Use CloudTrail to identify the actor.
Use AWS Config to identify the change.
Use SLOs to measure what users care about.
```

## Lesson 56 outcome

You can now design observability where:

```text
API users experience errors
    → An SLO alarm detects customer impact.

Several component alarms fire together
    → A composite alarm sends one actionable page.

A request is slow
    → A trace identifies the slow dependency.

The trace needs detailed context
    → Structured logs share trace and request IDs.

A metric has millions of users
    → User IDs remain in logs, not dimensions.

A configuration changes unexpectedly
    → CloudTrail identifies the actor.

The previous resource state is needed
    → AWS Config shows configuration history.

A control is violated
    → A Config rule marks the resource noncompliant.

The repair is safe and repeatable
    → SSM Automation performs remediation.

Several AWS accounts need one view
    → OAM and Config aggregators centralize visibility.

A new tracing project begins in 2026
    → OpenTelemetry is selected over new X-Ray SDK instrumentation.
```

**Next lesson: Lesson 57 — Amazon GuardDuty, Security Hub, Inspector, Macie, Detective and IAM Access Analyzer production cloud-security monitoring: threat detection, vulnerability management, sensitive-data discovery, findings aggregation, investigation and automated response.**

[1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html?utm_source=chatgpt.com "What is Amazon CloudWatch? - Amazon CloudWatch"
[2]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html?utm_source=chatgpt.com "Metrics concepts - Amazon CloudWatch"
[3]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html?utm_source=chatgpt.com "Embedding metrics within logs - Amazon CloudWatch"
[4]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html?utm_source=chatgpt.com "Using Amazon CloudWatch alarms"
[5]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html?utm_source=chatgpt.com "Configuring how CloudWatch alarms treat missing data - Amazon CloudWatch"
[6]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html?utm_source=chatgpt.com "Using CloudWatch anomaly detection"
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html?utm_source=chatgpt.com "What is Amazon CloudWatch Logs?"
[8]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html?utm_source=chatgpt.com "Working with log groups and log streams - AWS Documentation"
[9]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatch_Logs_Log_Classes.html?utm_source=chatgpt.com "Log classes - Amazon CloudWatch Logs"
[10]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html?utm_source=chatgpt.com "Analyzing log data with CloudWatch Logs Insights - Amazon CloudWatch Logs"
[11]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogs-Field-Indexing.html?utm_source=chatgpt.com "Create field indexes to improve query performance and ..."
[12]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Alarm-On-Logs.html?utm_source=chatgpt.com "Alarming on logs - Amazon CloudWatch"
[13]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Subscriptions.html?utm_source=chatgpt.com "Real-time processing of log data with subscriptions"
[14]: https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry.html?utm_source=chatgpt.com "OpenTelemetry Protocol (OTLP) Endpoint - AWS X-Ray"
[15]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-migration.html?utm_source=chatgpt.com "Migrating from X-Ray instrumentation to OpenTelemetry ..."
[16]: https://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html?utm_source=chatgpt.com "AWS X-Ray concepts"
[17]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Application-Signals-TraceLogCorrelation.html?utm_source=chatgpt.com "Enable trace to log correlation - Amazon CloudWatch"
[18]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html?utm_source=chatgpt.com "Application Signals - Amazon CloudWatch"
[19]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM.html?utm_source=chatgpt.com "CloudWatch RUM"
[20]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html?utm_source=chatgpt.com "Synthetic monitoring (canaries) - Amazon CloudWatch"
[21]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html?utm_source=chatgpt.com "Working with CloudTrail event history"
[22]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-events.html?utm_source=chatgpt.com "Understanding CloudTrail events"
[23]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html?utm_source=chatgpt.com "Logging data events - AWS CloudTrail"
[24]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-network-events-with-cloudtrail.html?utm_source=chatgpt.com "Logging network activity events - AWS CloudTrail"
[25]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-insights-events-with-cloudtrail.html?utm_source=chatgpt.com "Working with CloudTrail Insights"
[26]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-trails.html?utm_source=chatgpt.com "Working with CloudTrail trails - AWS CloudTrail"
[27]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html?utm_source=chatgpt.com "Creating a trail for an organization - AWS CloudTrail"
[28]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-intro.html?utm_source=chatgpt.com "Validating CloudTrail log file integrity - AWS CloudTrail"
[29]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-cli.html?utm_source=chatgpt.com "Validating CloudTrail log file integrity with the AWS CLI - AWS CloudTrail"
[30]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html?utm_source=chatgpt.com "Creating CloudWatch alarms for CloudTrail events: examples"
[31]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-lake-organizations.html?utm_source=chatgpt.com "Understanding organization event data stores - AWS CloudTrail"
[32]: https://docs.aws.amazon.com/config/latest/developerguide/WhatIsConfig.html?utm_source=chatgpt.com "What Is AWS Config? - AWS Config"
[33]: https://docs.aws.amazon.com/config/latest/developerguide/stop-start-recorder.html?utm_source=chatgpt.com "Working with the configuration recorder - AWS Config"
[34]: https://docs.aws.amazon.com/config/latest/developerguide/managing-recorder_console-change-recording-frequency.html?utm_source=chatgpt.com "Changing the recording frequency for the customer managed configuration recorder - AWS Config"
[35]: https://docs.aws.amazon.com/config/latest/developerguide/select-resources-console.html?utm_source=chatgpt.com "Recording resources in the AWS Config console - AWS Config"
[36]: https://docs.aws.amazon.com/config/latest/developerguide/config-concepts.html?utm_source=chatgpt.com "AWS Config terminology and concepts - AWS Config"
[37]: https://docs.aws.amazon.com/config/latest/developerguide/remediation.html?utm_source=chatgpt.com "Remediating Noncompliant Resources with AWS Config - AWS Config"
[38]: https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html?utm_source=chatgpt.com "Conformance Packs for AWS Config"
[39]: https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html?utm_source=chatgpt.com "Multi-Account Multi-Region Data Aggregation for AWS Config"
[40]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Unified-Cross-Account.html?utm_source=chatgpt.com "CloudWatch cross-account observability - Amazon CloudWatch"
[41]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Cross-Account-Methods.html?utm_source=chatgpt.com "Monitor across accounts and Regions - Amazon CloudWatch"
[42]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Metric-Streams.html?utm_source=chatgpt.com "Use metric streams - Amazon CloudWatch"
[43]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_billing.html?utm_source=chatgpt.com "Analyzing, optimizing, and reducing CloudWatch costs"
[44]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-supportmatrix.html?utm_source=chatgpt.com "Supported systems - Amazon CloudWatch"
