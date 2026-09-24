# AWS Masterclass — Lesson 32 Part 1

# Amazon CloudWatch from First Principles

## Metrics, Dimensions, Percentiles, Logs, Alarms, Anomaly Detection, Dashboards, Agents & Production Monitoring

We have now finished the major AWS security architecture layer.

Lesson 32 begins a new question:

```text
"Our system is running.

But HOW do we know
whether it is healthy?"
```

That is the job of:

# Observability

A production system should continuously answer:

```text
Is it UP?

Is it FAST?

Is it CORRECT?

Is it overloaded?

Are users receiving errors?

Which component is failing?

When did it start?

What changed?

What should wake us up?
```

And AWS's central observability service is:

# Amazon CloudWatch

CloudWatch today covers infrastructure metrics, application metrics, logs, alarms, dashboards, OpenTelemetry telemetry, anomaly detection, application monitoring, network monitoring, cross-account observability, and more. ([AWS Documentation][1])

---

# 1. First — Monitoring vs Observability

These terms are related but not identical.

### Monitoring

You already know what to watch.

Example:

```text
CPU > 80%
Disk > 85%
5xx > 10
```

You create dashboards and alarms.

### Observability

You want enough telemetry to investigate problems you did **not necessarily predict**.

Example:

```text
User says:

"Checkout became slow
only for customers in one Region
after 10:42 AM."

Can we determine WHY?
```

That requires correlating:

```text
Metrics
Logs
Traces
Events
Configuration
```

So:

```text
Monitoring
=
"Is known condition X happening?"


Observability
=
"Can I understand
what the system is doing
from its telemetry?"
```

---

# 2. Four Telemetry Types

For this AWS course, use this mental model:

```text
                         OBSERVABILITY
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
       METRICS               LOGS               TRACES
          │                   │                   │
       numbers             events             request path
       over time          /details           across services

                              +

                           EVENTS
                              │
                              ▼
                         state changes
```

Example:

### Metric

```text
CPU = 93%
```

### Log

```text
2026-08-14T10:03:12Z ERROR
database connection timeout
```

### Trace

```text
Browser
  ↓ 25ms
API
  ↓ 30ms
Service A
  ↓ 2200ms
Database
```

### Event

```text
Auto Scaling instance terminated
```

Different telemetry answers different questions.

---

# 3. The Golden Production Question

Suppose:

```text
Website is slow.
```

A beginner immediately checks:

```text
CPU
```

An experienced engineer checks the whole path:

```text
                         USER
                           │
                           ▼
                      CloudFront
                           │
                     latency/errors
                           │
                           ▼
                          ALB
                    ┌──────┴──────┐
                    ▼             ▼
                RequestCount   TargetResponseTime
                4xx/5xx        HealthyHostCount
                    │
                    ▼
                     Application
                    ┌────┴────┐
                    ▼         ▼
                  CPU       Memory
                  Disk      Threads
                  Errors    GC
                    │
                    ▼
                     Database
                    │
             connections/latency
                    │
                    ▼
                  Storage
```

Because:

```text
"Slow"
```

does **not** automatically mean:

```text
"High CPU."
```

---

# 4. CloudWatch Architecture

At a high level:

```text
                     AWS SERVICES
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
           EC2           ALB           RDS
            │             │             │
            └─────────────┼─────────────┘
                          ▼
                        METRICS
                          │
                          ▼
                      CloudWatch
                          │
         ┌────────────────┼─────────────────┐
         ▼                ▼                 ▼
      Graphs            Alarms          Dashboards
                                            

               APPLICATION / OPERATING SYSTEM
                          │
                          ▼
                   CloudWatch Agent
                          │
                  ┌───────┼───────┐
                  ▼       ▼       ▼
               Metrics   Logs   Traces
                          │
                          ▼
                      CloudWatch
```

Many AWS services publish metrics automatically, while your applications can publish custom metrics through CloudWatch APIs, Embedded Metric Format, the CloudWatch agent, or modern OpenTelemetry paths. ([AWS Documentation][1])

---

# PART A — CLOUDWATCH METRICS

# 5. What Is a Metric?

A metric is:

```text
a numerical measurement
recorded over time.
```

Examples:

```text
CPUUtilization = 72%

RequestCount = 1500

TargetResponseTime = 0.482 seconds

DatabaseConnections = 84

DiskUsedPercent = 78%

OrdersProcessed = 325
```

Think:

```text
Metric Name
+
Timestamp
+
Value
```

Example:

```text
10:00 CPUUtilization 35
10:01 CPUUtilization 41
10:02 CPUUtilization 82
10:03 CPUUtilization 94
```

Now you have a:

```text
TIME SERIES
```

---

# 6. Namespace

CloudWatch organizes traditional metrics into:

# Namespaces

Think:

```text
Namespace
=
metric container / category
```

Examples:

```text
AWS/EC2

AWS/ApplicationELB

AWS/RDS

AWS/EBS

AWS/Lambda
```

Custom application:

```text
TodoApp/Production
```

Metrics in separate namespaces are isolated from one another, preventing unrelated metrics with identical names from being accidentally aggregated. ([AWS Documentation][2])

---

# 7. Metric Identity

For traditional CloudWatch metrics, the identity is essentially:

```text
Namespace
+
Metric Name
+
Dimensions
```

Example:

```text
Namespace:
AWS/EC2

Metric:
CPUUtilization

Dimension:
InstanceId=i-0123456789
```

Another instance:

```text
InstanceId=i-9876543210
```

is a **different metric time series**, even though the metric name is still:

```text
CPUUtilization
```

CloudWatch traditional metrics support up to 30 dimensions per metric identity. ([AWS Documentation][2])

---

# 8. Dimensions

A:

# Dimension

is a name/value pair that identifies or categorizes a metric.

Example:

```text
InstanceId
=
i-abc123
```

Or for an ALB:

```text
LoadBalancer
=
app/prod-alb/abc123
```

For a target group:

```text
TargetGroup
=
targetgroup/prod/xyz
```

This means CloudWatch can answer:

```text
CPU for WHICH instance?

Latency for WHICH ALB?

Connections for WHICH database?

Errors for WHICH Lambda?
```

---

# 9. Dimension Explosion

Suppose your application publishes:

```text
RequestLatency
```

with dimension:

```text
UserId=123
```

and you have:

```text
10 million users.
```

You may accidentally create enormous metric cardinality.

Bad metric design:

```text
RequestLatency
  UserId=user1

RequestLatency
  UserId=user2

RequestLatency
  UserId=user3

...
```

Better dimensions are usually bounded operational categories:

```text
Service=Checkout

Environment=Production

Region=ap-south-1

Endpoint=/orders
```

High-cardinality identifiers often belong in:

```text
logs
traces
```

rather than conventional CloudWatch metric dimensions.

---

# 10. 2026 CloudWatch Has Two Metric Models

Modern CloudWatch now supports both:

```text
Traditional CloudWatch metrics
```

and:

```text
OpenTelemetry metrics
```

Traditional CloudWatch metrics use:

```text
namespace
metric name
up to 30 dimensions
```

while OpenTelemetry metrics use metric names plus as many as 150 labels, are ingested using OTLP, and can be queried with PromQL in CloudWatch Query Studio. CloudWatch can also create PromQL-based alarms on OTel metrics. ([AWS Documentation][2])

This matters because modern AWS observability is becoming much more:

```text
OpenTelemetry-aware.
```

---

# 11. AWS Metrics vs Custom Metrics

There are two major categories.

### AWS service metrics

Generated by AWS.

Example:

```text
AWS/EC2
CPUUtilization
```

### Custom metrics

Generated by you.

Example:

```text
TodoApp/Production
OrdersCreated
```

or:

```text
CheckoutFailures
```

You can publish custom metrics using `PutMetricData`, the AWS CLI/SDK, Embedded Metric Format, agents, StatsD, OpenTelemetry, and related collection mechanisms. ([AWS Documentation][3])

---

# 12. Why Custom Metrics Matter

Imagine:

```text
CPU = 20%

Memory = 35%

Database healthy
```

Yet:

```text
customers cannot place orders.
```

Infrastructure appears healthy.

But business metric:

```text
OrdersSucceeded
```

fell from:

```text
500/min
```

to:

```text
0/min.
```

That is the difference between:

```text
INFRASTRUCTURE MONITORING
```

and:

```text
BUSINESS / APPLICATION MONITORING.
```

Production observability needs both.

---

# 13. Important Application Metrics

For an API, good custom signals include:

```text
Requests

Errors

Latency

OrdersSucceeded

OrdersFailed

PaymentsSucceeded

PaymentsFailed

QueueDepth

ActiveSessions

CacheHitRate

ExternalAPIErrors
```

Don't publish just:

```text
"Server is alive."
```

Publish metrics that represent what the business service is supposed to accomplish.

---

# 14. RED Method

For request-driven services, remember:

```text
R
=
RATE

How many requests?


E
=
ERRORS

How many requests fail?


D
=
DURATION

How long do requests take?
```

Example:

```text
Checkout API

Rate:
1200 requests/minute

Errors:
2.1%

Duration:
p95 = 420 ms
```

This is much more useful than watching CPU alone.

---

# 15. USE Method

For infrastructure, another useful framework:

```text
U
=
Utilization

S
=
Saturation

E
=
Errors
```

For EC2:

```text
Utilization
→ CPU

Saturation
→ run queue / memory pressure

Errors
→ status/network/disk issues
```

For EBS:

```text
Utilization
→ throughput / IOPS usage

Saturation
→ queue / exceeded checks

Errors
→ stalled I/O/status
```

---

# PART B — RESOLUTION AND PERIOD

# 16. Metric Resolution

Resolution answers:

> How frequently are measurements represented?

Example:

```text
5-minute

1-minute

1-second
```

A standard custom metric has standard resolution.

A high-resolution custom metric can be published with:

```text
StorageResolution = 1
```

and stored at one-second resolution. ([AWS Documentation][3])

---

# 17. EC2 Basic Monitoring

By default, EC2 sends its basic CloudWatch metrics using:

```text
5-minute intervals.
```

Example:

```text
10:00
10:05
10:10
10:15
```

([AWS Documentation][4])

---

# 18. EC2 Detailed Monitoring

Enable:

```text
Detailed Monitoring
```

and supported EC2 metrics are published at:

```text
1-minute intervals.
```

([AWS Documentation][4])

So:

```text
Basic EC2
=
5-minute

Detailed EC2
=
1-minute
```

### Certification rule

```text
Need quicker EC2 CloudWatch metric visibility?
→ Detailed Monitoring
```

---

# 19. Resolution vs Alarm Period

These are different.

Metric resolution:

```text
How frequently metric data exists.
```

Alarm period:

```text
How much time CloudWatch aggregates
into each alarm datapoint.
```

Example:

```text
metric resolution
=
1 minute

alarm period
=
5 minutes
```

CloudWatch might aggregate the five one-minute samples into one five-minute value. Alarm periods should not be configured finer than the source metric resolution for ordinary metrics. ([AWS Documentation][2])

---

# 20. High-Resolution Metrics

For very fast systems you might publish:

```text
1-second custom metrics.
```

CloudWatch can retrieve high-resolution custom metrics using sub-minute periods. ([AWS Documentation][3])

Examples:

```text
trading system latency

high-frequency queue depth

real-time game backend

rapid autoscaling signal
```

But:

```text
more resolution
=
potentially more cost
+
more noise
```

So don't collect every metric every second without purpose.

---

# 21. High-Resolution Alarm Periods

Current CloudWatch high-resolution alarms can use:

```text
10 seconds

20 seconds

30 seconds
```

and those sub-minute alarms are evaluated every ten seconds. ([AWS Documentation][5])

Normal alarms generally use:

```text
60 seconds
or larger periods.
```

---

# PART C — CLOUDWATCH METRIC RETENTION

# 22. Metric Retention

CloudWatch automatically rolls older metric data into coarser resolutions.

Current traditional metric retention is:

| Resolution / Period |             Retained |
| ------------------- | -------------------: |
| Less than 60 sec    |              3 hours |
| 1 minute            |              15 days |
| 5 minutes           |              63 days |
| 1 hour              | 455 days / 15 months |

([AWS Documentation][2])

Mental model:

```text
1-second data
    │
    ▼
3 hours
    │
    ▼
rolled into 1-minute
    │
    ▼
15 days
    │
    ▼
rolled into 5-minute
    │
    ▼
63 days
    │
    ▼
rolled into hourly
    │
    ▼
15 months
```

---

# 23. Why Retention Rollup Matters

Suppose six months later you investigate:

```text
"What was CPU at 10:03:27?"
```

That fine-grained datapoint is no longer available.

You might instead see:

```text
hourly aggregate.
```

CloudWatch keeps long-term trends while reducing the storage required for very fine-grained historical data. ([AWS Documentation][2])

---

# PART D — STATISTICS

# 24. Raw Values Are Not Enough

Suppose during one five-minute window latency values are:

```text
100ms
120ms
130ms
150ms
2000ms
```

CloudWatch must summarize those data points.

That's where:

# Statistics

come in.

CloudWatch statistics are aggregations of datapoints over a selected period. ([AWS Documentation][6])

---

# 25. Core Statistics

You must know these five:

```text
SampleCount

Sum

Average

Minimum

Maximum
```

CloudWatch defines them as: `SampleCount` = number of datapoints, `Sum` = total values, `Average` = `Sum / SampleCount`, and `Minimum`/`Maximum` = lowest/highest observed values. ([AWS Documentation][6])

---

# 26. Choose Statistics Based on Metric Meaning

Suppose:

```text
RequestCount
```

Correct statistic:

```text
SUM
```

because you want:

```text
total requests during period.
```

Suppose:

```text
CPUUtilization
```

Commonly:

```text
AVERAGE
```

Suppose:

```text
FreeStorageSpace
```

you might inspect:

```text
Minimum
```

to detect the lowest free-space point.

The correct statistic is a semantic decision, not just an arbitrary CloudWatch setting.

---

# 27. Why Average Can Lie

Suppose request latency:

```text
99 users:
100 ms

1 user:
10 seconds
```

Average may appear reasonable enough that you miss the outlier.

Users don't experience:

```text
average latency.
```

Each user experiences:

```text
their request latency.
```

That is why percentiles are essential.

---

# PART E — PERCENTILES

# 28. p50

```text
p50
=
50th percentile
=
median-ish experience
```

If:

```text
p50 latency = 120ms
```

approximately half the requests completed below that value and half above it.

---

# 29. p95

```text
p95 = 500 ms
```

means approximately:

```text
95% of observations
were at or below that point

5%
were above it.
```

CloudWatch defines p95 using this percentile interpretation. ([AWS Documentation][7])

---

# 30. p99

If:

```text
p99 = 3 seconds
```

then your slowest ~1% of requests are slower than around three seconds.

This is often where:

```text
customer pain
```

hides.

Example dashboard:

```text
p50 = 110 ms
p95 = 340 ms
p99 = 2300 ms
```

Average might still look:

```text
180 ms
```

and hide the bad tail.

---

# 31. Production Latency Dashboard

Do not show only:

```text
AverageLatency
```

Use something like:

```text
p50

p90

p95

p99

error rate

request volume
```

because:

```text
Average good
```

does not guarantee:

```text
tail latency good.
```

---

# 32. Advanced Statistics

Current CloudWatch also supports statistics such as:

```text
Trimmed Mean

Interquartile Mean

Winsorized Mean

Percentile Rank

Trimmed Count

Trimmed Sum
```

For example, `tm99` calculates an average while ignoring the highest 1% of observations. AWS specifically recommends trimmed mean as a useful latency statistic when you want to reduce the influence of extreme outliers. ([AWS Documentation][6])

This is advanced but increasingly relevant in mature observability systems.

---

# 33. Percentile Trap — Negative Values

CloudWatch cannot calculate percentile statistics for a metric dataset that contains negative values. For custom metrics, percentiles also require raw datapoints unless the published statistic-set data satisfies specific special conditions. ([AWS Documentation][7])

This is a subtle troubleshooting point.

---

# PART F — METRIC MATH

# 34. Metrics Become More Powerful When Combined

Suppose Lambda publishes:

```text
Invocations
Errors
```

You want:

```text
ErrorRate%
```

Metric math:

```text
Errors
──────────── × 100
Invocations
```

CloudWatch metric math can create new time series from arithmetic and functions applied to other metrics. ([AWS Documentation][8])

---

# 35. Error Rate Example

Suppose:

```text
Invocations = 10,000

Errors = 300
```

Then:

```text
ErrorRate =
300 / 10000 × 100
=
3%
```

Alerting directly on:

```text
Errors > 100
```

can be misleading because:

```text
100 errors out of 100 requests
=
catastrophic

100 errors out of 100 million
=
very different.
```

Rate-based signals are often more meaningful.

---

# 36. ALB Error Rate Example

You might calculate:

```text
HTTPCode_Target_5XX_Count
──────────────────────────── × 100
RequestCount
```

to produce:

```text
Backend5XXRate
```

Then alarm:

```text
5xx rate > 2%
```

instead of:

```text
5xx count > 100
```

which doesn't adapt well to traffic volume.

---

# 37. CPU Across Fleet Example

Suppose Auto Scaling Group contains:

```text
20 instances.
```

Individual instance CPU:

```text
45%
52%
47%
92%
44%
```

You might care about:

```text
fleet average
```

and:

```text
maximum per-instance CPU
```

because average alone can hide one unhealthy/hot host.

The lesson:

```text
Aggregation can hide outliers.
```

---

# PART G — CLOUDWATCH AGENT

# 38. EC2 Does Not Know Everything Automatically

By default, EC2 exposes infrastructure metrics such as:

```text
CPUUtilization

NetworkIn

NetworkOut
```

and other service-level EC2 metrics.

But OS-level telemetry requires additional collection. AWS recommends the CloudWatch agent for additional metrics beyond EC2's default monitoring. ([AWS Documentation][9])

---

# 39. The Famous Memory Question

Certification/interview question:

> Where is EC2 memory utilization in default CloudWatch metrics?

Answer:

```text
It isn't a standard default EC2 metric
you should assume is automatically published.

Use the CloudWatch agent
or another monitoring agent.
```

The CloudWatch agent adds guest/OS-level metrics on top of EC2's default metrics. ([AWS Documentation][10])

---

# 40. Same for Filesystem Usage

You might want:

```text
/
72% used

/var
91% used
```

CloudWatch cannot infer guest filesystem free space merely from the EC2 hypervisor-level metrics.

Use:

```text
CloudWatch Agent
```

to publish operating-system filesystem metrics. ([AWS Documentation][10])

---

# 41. CloudWatch Agent Architecture

```text
                   EC2 / On-Prem Server
                          │
                          ▼
                   CloudWatch Agent
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
      Metrics            Logs            Traces
         │                │                │
         └────────────────┼────────────────┘
                          ▼
                      CloudWatch
```

The current unified CloudWatch agent can collect metrics, logs, and traces from EC2, on-premises servers, and containerized applications. ([AWS Documentation][11])

---

# 42. Agent Metric Examples

On Linux you might collect:

```text
cpu

mem

disk

diskio

swap

net

processes

procstat
```

depending on configuration and platform.

The agent can also collect application telemetry through mechanisms including StatsD, collectd, JMX, OpenTelemetry, and related integrations. ([AWS Documentation][12])

---

# 43. Agent High-Resolution Metrics

The agent's:

```json
"metrics_collection_interval": 10
```

means those metrics are collected at a sub-minute interval and therefore treated as high-resolution metrics.

AWS documents that setting the agent collection interval below 60 seconds produces high-resolution metrics. ([AWS Documentation][13])

---

# 44. CloudWatch Agent and IAM

On EC2:

```text
CloudWatch Agent
       │
       ▼
EC2 Instance Role
       │
       ▼
CloudWatch APIs
```

Prefer:

```text
IAM role
```

instead of storing:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

inside the server.

AWS's CloudWatch agent guidance supports using an attached instance role as the credential provider. ([AWS Documentation][13])

---

# 45. Example Agent Config

Simplified Linux example:

```json
{
  "agent": {
    "metrics_collection_interval": 60
  },

  "metrics": {
    "namespace": "TodoApp/System",

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
          "used_percent"
        ],
        "resources": [
          "/"
        ]
      }
    }
  }
}
```

Now you can build:

```text
Memory > 85%

Disk / > 90%
```

alarms.

---

# 46. Agent Aggregation Dimensions

Suppose 30 EC2 instances belong to:

```text
AutoScalingGroupName=todo-prod
```

The agent can roll up selected metrics by dimensions such as Auto Scaling group rather than requiring every dashboard to enumerate individual hosts. AWS supports `aggregation_dimensions` for this purpose. ([AWS Documentation][13])

---

# 47. OpenTelemetry and CloudWatch Agent

Modern CloudWatch agent functionality is built on OpenTelemetry Collector technology and can accept OTLP telemetry from applications. AWS currently recommends the CloudWatch agent as a primary method for many customers sending OpenTelemetry data to CloudWatch because one agent can also participate in features such as Application Signals and enhanced Container Insights. ([AWS Documentation][14])

Architecture:

```text
Node.js / Java / Python App
          │
          │ OTLP
          ▼
    CloudWatch Agent
          │
      ┌───┴────┐
      ▼        ▼
   Metrics    Traces
      │        │
      ▼        ▼
CloudWatch    X-Ray/
              CloudWatch
```

---

# PART H — SERVICE-SPECIFIC METRICS

# 48. EC2 Monitoring

Good EC2 starting metrics:

```text
CPUUtilization

NetworkIn

NetworkOut

Status checks
```

plus agent metrics:

```text
memory

disk space

process health
```

EC2 basic monitoring publishes at five-minute intervals; detailed monitoring increases EC2 metric frequency to one minute. ([AWS Documentation][15])

---

# 49. CPU Does Not Equal Server Health

Example:

```text
CPU = 5%
```

Could mean:

```text
healthy idle server
```

or:

```text
application process crashed.
```

Therefore pair infrastructure metrics with:

```text
request count

healthy hosts

application errors

process health

synthetic checks
```

Never define health with one metric.

---

# 50. Application Load Balancer Monitoring

For ALB, important operational categories include:

```text
traffic volume

target health

response latency

ALB-generated errors

target-generated errors
```

Typical ALB metrics therefore include request counts, target response time, healthy/unhealthy target counts, and HTTP error counts.

A useful mental model:

```text
                    ALB
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
    TRAFFIC        LATENCY        ERRORS
       │             │             │
RequestCount   TargetResponse  ELB 5xx
                Time          Target 5xx
```

---

# 51. ALB 5xx vs Target 5xx

Very important troubleshooting distinction:

```text
HTTPCode_ELB_5XX
```

means roughly:

```text
load-balancer-side failures.
```

while:

```text
HTTPCode_Target_5XX
```

means:

```text
your backend targets returned 5xx.
```

Therefore:

```text
Target 5xx high
→ inspect application


ELB 5xx high
→ inspect ALB/backend connectivity/capacity behavior
```

Do not treat all HTTP 500-class metrics as the same root cause.

---

# 52. RDS Monitoring

RDS publishes CloudWatch metrics in:

```text
AWS/RDS
```

and sends standard instance metrics to CloudWatch at one-minute periods. ([AWS Documentation][16])

Useful starting metrics include:

```text
CPUUtilization

DatabaseConnections

FreeableMemory

FreeStorageSpace

ReadLatency

WriteLatency

ReplicaLag
```

depending on engine/deployment. AWS specifically recommends monitoring resource capacity indicators such as CPU, memory, replica lag, and storage. ([AWS Documentation][17])

---

# 53. RDS Connection Problem Example

Suppose:

```text
CPU = 30%

Free memory = healthy

DatabaseConnections = maxed out
```

Application reports:

```text
timeout getting DB connection
```

Scaling CPU won't necessarily fix it.

Root cause might be:

```text
connection pool exhaustion.
```

This is why:

```text
monitor the bottleneck
before scaling the resource.
```

---

# 54. EBS Monitoring

EBS automatically publishes one-minute CloudWatch metrics for attached volumes. The `AWS/EBS` namespace provides metrics around I/O, throughput, queueing, and volume health. ([AWS Documentation][18])

Modern EBS monitoring can include signals such as:

```text
VolumeReadOps

VolumeWriteOps

VolumeQueueLength

VolumeAvgReadLatency

VolumeAvgWriteLatency

VolumeIOPSExceededCheck

VolumeThroughputExceededCheck
```

for applicable volumes/environments. ([AWS Documentation][19])

---

# 55. EBS Micro-Burst Trap

Suppose gp3 provides enough average throughput.

Dashboard shows:

```text
average IOPS
<
provisioned IOPS
```

Yet application experiences latency.

Why?

You might have:

```text
sub-minute bursts
```

that exceed the provisioned capability even though the one-minute average looks lower.

AWS specifically provides exceeded-check metrics to help identify this type of behavior. ([AWS Documentation][19])

Never rely on average alone.

---

# PART I — CLOUDWATCH LOGS

# 56. Metrics Tell You That Something Is Wrong

Example:

```text
5xx rate = 14%
```

Great.

Now the engineer asks:

```text
WHY?
```

That's where:

# Logs

become important.

---

# 57. CloudWatch Logs Data Model

The hierarchy:

```text
LOG GROUP
    │
    ├── LOG STREAM
    │      │
    │      ├── LOG EVENT
    │      ├── LOG EVENT
    │      └── LOG EVENT
    │
    └── LOG STREAM
           │
           └── ...
```

CloudWatch Logs defines a log event as a timestamp plus raw message, a log stream as events from a common source, and a log group as streams sharing settings such as retention, access controls, and monitoring configuration. ([AWS Documentation][20])

---

# 58. Example

Application:

```text
Todo API
```

Log group:

```text
/prod/todo-api
```

Streams:

```text
instance-i-abc

instance-i-def

instance-i-xyz
```

Events:

```text
10:12 INFO request started

10:12 ERROR MongoDB timeout

10:13 INFO retry successful
```

Now logs from an Auto Scaling fleet can be investigated centrally.

---

# 59. Log Group Is the Main Administrative Boundary

Retention is configured at:

```text
Log Group
```

not individually per event.

Example:

```text
/prod/application
Retention: 30 days

/security/audit
Retention: 365 days
```

CloudWatch applies log-group retention to the log streams belonging to that group. ([AWS Documentation][20])

---

# 60. Set Retention

One of the easiest ways to waste money:

```text
create log group
+
never configure retention
```

Production logging should deliberately answer:

```text
How long do we need this log?

7 days?

30 days?

90 days?

1 year?

Compliance archive?
```

Retention should reflect:

```text
operational value

incident response

compliance

cost
```

not accidental defaults.

---

# 61. CloudWatch Log Classes

CloudWatch Logs currently supports two log-group classes:

```text
STANDARD

INFREQUENT ACCESS
```

Standard provides the full feature set for frequently used operational logs, while Infrequent Access reduces ingestion cost for logs queried less often but supports a subset of features. A log group's class cannot currently be changed after creation. ([AWS Documentation][21])

Use:

```text
Standard
→ production app logs actively queried


Infrequent Access
→ low-touch historical/forensic logs
```

after reviewing feature requirements.

---

# 62. Deletion Protection

Current CloudWatch Logs also supports deletion protection for log groups. When enabled, it prevents deletion of the log group until protection is explicitly disabled. ([AWS Documentation][20])

This can be valuable for:

```text
critical audit logs

production incident evidence

security logs
```

where accidental deletion would be expensive.

---

# 63. Structured Logging Beats Random Strings

Bad:

```text
Something bad happened!!
```

Better:

```json
{
  "timestamp": "2026-08-14T10:10:00Z",
  "level": "ERROR",
  "service": "todo-api",
  "requestId": "abc123",
  "route": "/add-todo",
  "error": "MongoTimeout",
  "durationMs": 3200
}
```

Why?

Because now you can search:

```text
level = ERROR

route = /add-todo

durationMs > 2000
```

Structured JSON makes logs substantially easier to query and correlate.

---

# 64. Never Log Secrets

Do not log:

```text
passwords

Authorization headers

JWT tokens

AWS credentials

API keys

database passwords
```

CloudWatch Logs also supports data-protection policies that can detect and mask sensitive log data using managed identifiers. ([AWS Documentation][22])

Logging should improve security, not create a new secret database.

---

# PART J — CLOUDWATCH LOGS INSIGHTS

# 65. Logs Insights

Instead of:

```text
grep through 100 EC2 servers
```

you can query centralized CloudWatch Logs.

Current CloudWatch Logs Insights supports **three query languages**:

```text
Logs Insights QL

OpenSearch PPL

OpenSearch SQL
```

([AWS Documentation][23])

This is a significant modern capability.

---

# 66. Logs Insights QL Example

Find latest errors:

```text
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

This reads roughly like:

```text
select fields
then filter
then sort
then limit
```

---

# 67. JSON Log Query

Suppose events contain:

```json
{
  "level": "ERROR",
  "route": "/checkout",
  "durationMs": 2300
}
```

Query:

```text
fields @timestamp, route, durationMs
| filter level = "ERROR"
| sort durationMs desc
| limit 20
```

Now instead of:

```text
"I think checkout is slow."
```

you get:

```text
which requests
when
how slow
```

---

# 68. Aggregate Error Counts

```text
fields @timestamp, level
| filter level = "ERROR"
| stats count() as errors by bin(5m)
```

Now logs become:

```text
5-minute error trend
```

This is extremely useful during incidents.

---

# 69. SQL Query Support

CloudWatch Logs now also supports OpenSearch SQL syntax with concepts such as:

```sql
SELECT
FROM
WHERE
GROUP BY
HAVING
```

and can perform richer analysis including joins across log groups for supported queries. ([AWS Documentation][23])

This is useful for engineers already comfortable with SQL.

---

# 70. PPL

PPL feels similar to Unix pipelines:

```text
source=...
| where ...
| stats ...
| sort ...
```

It gives another expressive option for log analytics. ([AWS Documentation][24])

You do not need to master all three immediately.

Start with:

```text
Logs Insights QL
```

because it is simple and heavily used in AWS troubleshooting.

---

# 71. Live Tail

During an active incident:

```text
deployment just happened

errors starting now

need to see incoming logs
```

use:

# CloudWatch Logs Live Tail

It streams newly ingested log events in near real time and supports interactive filtering/highlighting. ([AWS Documentation][25])

Think:

```text
tail -f
```

but across centralized CloudWatch log sources.

---

# 72. Metric Filters

Logs can become metrics.

Suppose application logs:

```text
PAYMENT_FAILED
```

You create:

```text
CloudWatch Logs Metric Filter
```

that counts every matching event.

Now:

```text
log message
      │
      ▼
metric filter
      │
      ▼
PaymentFailures metric
      │
      ▼
CloudWatch Alarm
```

CloudWatch metric filters transform matching log events into CloudWatch metric datapoints. ([AWS Documentation][20])

---

# 73. Example Metric Filter

Logs:

```text
2026 ERROR PaymentFailed order=123

2026 ERROR PaymentFailed order=124
```

Metric:

```text
TodoApp/Production
PaymentFailures
```

Then:

```text
PaymentFailures > 5
within 5 minutes
```

→ alarm.

This is a classic production pattern.

---

# 74. Modern Log Alarms

CloudWatch now also supports **log alarms** based directly on Logs Insights queries, which can be useful when the detection logic is richer than a simple metric filter. The query executes over selected log groups on a configured schedule/window and can drive CloudWatch alarm behavior. ([AWS Documentation][26])

This gives you:

```text
logs
  │
  ▼
Logs Insights query
  │
  ▼
alarm
```

without always creating a permanent intermediate metric.

---

# PART K — CLOUDWATCH ALARMS

# 75. What Is an Alarm?

An alarm continuously evaluates:

```text
Metric
or
Metric expression
```

against:

```text
Condition.
```

Example:

```text
CPUUtilization
>
80%
```

for:

```text
3 of last 5 minutes.
```

CloudWatch supports alarms on metrics and expressions and can trigger notifications or automated actions. ([AWS Documentation][27])

---

# 76. Alarm States

Metric alarms have three main states:

```text
OK

ALARM

INSUFFICIENT_DATA
```

`OK` means the metric/expression is within the configured threshold, `ALARM` means it is breaching, and `INSUFFICIENT_DATA` means CloudWatch cannot currently determine the condition from available data. ([AWS Documentation][5])

---

# 77. Period

Example:

```text
Period = 60 seconds
```

Each alarm datapoint represents one minute.

---

# 78. Evaluation Periods

```text
EvaluationPeriods = 5
```

CloudWatch examines:

```text
last 5 periods.
```

---

# 79. Datapoints to Alarm

```text
DatapointsToAlarm = 3
```

Means:

```text
3 out of the last 5
must breach.
```

This is called:

# M out of N

CloudWatch does not require those M datapoints to be consecutive; they need to fall within the N recent evaluation periods. ([AWS Documentation][5])

---

# 80. Why M-of-N Is Better

Bad alarm:

```text
CPU > 80%
for one minute
```

One temporary spike:

```text
81%
```

wakes you at 3 AM.

Better:

```text
CPU > 80%

3 of 5 datapoints
```

This filters:

```text
short spikes
```

while detecting:

```text
sustained pressure.
```

---

# 81. Alarm Detection Timeline

Example:

```text
Period = 1 minute

EvaluationPeriods = 5

DatapointsToAlarm = 3
```

Data:

```text
10:00   60%  OK
10:01   85%  breach
10:02   90%  breach
10:03   70%  OK
10:04   88%  breach
```

Result:

```text
3 of 5 breached
→ ALARM
```

---

# 82. Missing Data Is a Design Decision

CloudWatch lets alarms treat missing data as:

```text
missing

ignore

breaching

notBreaching
```

If all relevant datapoints are absent, these choices can lead respectively to `INSUFFICIENT_DATA`, retaining the current state, `ALARM`, or `OK`. ([AWS Documentation][28])

This is extremely important.

---

# 83. Error Counter Missing Data Example

Suppose your application emits metric:

```text
PaymentFailureCount
```

only when an error occurs.

No errors:

```text
no metric datapoint.
```

If you configure:

```text
missing = breaching
```

you might alarm continuously.

Better:

```text
TreatMissingData = notBreaching
```

for this sparse error metric pattern. AWS gives the same guidance for sparse log/error signals. ([AWS Documentation][26])

---

# 84. Heartbeat Metric Is the Opposite

Suppose application publishes:

```text
Heartbeat=1
```

every minute.

Missing heartbeat:

```text
VERY BAD.
```

Now:

```text
TreatMissingData = breaching
```

can make sense.

So:

```text
Missing data
```

does not inherently mean:

```text
healthy
```

or:

```text
unhealthy.
```

It depends on metric semantics.

---

# 85. Alarm Actions

Alarm transitions can trigger:

```text
SNS notifications

Auto Scaling actions

EC2 actions

EventBridge workflows
```

depending on alarm type/action configuration. CloudWatch also publishes alarm state-change events to EventBridge and guarantees delivery of alarm state-change events to EventBridge. ([AWS Documentation][29])

Architecture:

```text
CloudWatch Alarm
       │
       ▼
EventBridge
       │
  ┌────┼─────────┐
  ▼    ▼         ▼
Lambda SNS   Step Functions
```

---

# 86. Alarm on Symptoms, Not Every Metric

Bad monitoring:

```text
alarm on every available metric
```

Result:

```text
alert storm
```

Better:

```text
Page on user impact

Ticket on capacity trend

Dashboard low-priority diagnostics
```

Examples:

```text
Page:
checkout errors > SLO threshold

Ticket:
disk predicted to fill in 5 days

Dashboard:
CPU information
```

An alert should imply:

```text
Someone needs to act.
```

---

# PART L — COMPOSITE ALARMS

# 87. The Alert Storm Problem

One database outage causes:

```text
API latency alarm

API error alarm

ALB 5xx alarm

Lambda alarm

DB connection alarm

queue alarm
```

Six pages for:

```text
one root cause.
```

Composite alarms help combine existing alarms into higher-level logic. ([AWS Documentation][30])

---

# 88. Composite Alarm Example

Create:

```text
ALARM("High5xx")
AND
ALARM("HighLatency")
```

Then notify only when:

```text
users are receiving errors
AND
latency is degraded.
```

Or:

```text
ALARM("DatabaseConnections")
OR
ALARM("DatabaseStorage")
```

---

# 89. Production Page Alarm

You might have:

```text
Diagnostic alarms:
CPUHigh
MemoryHigh
DBConnectionsHigh
Target5xxHigh
LatencyHigh
```

but page only on:

```text
Composite:
Target5xxHigh
AND
LatencyHigh
```

This reduces alarm fatigue.

---

# PART M — ANOMALY DETECTION

# 90. Static Threshold Problem

Suppose traffic:

```text
2 AM:
100 requests/min

12 PM:
20,000 requests/min
```

Static alarm:

```text
RequestCount < 500
```

would page every night.

Static alarm:

```text
RequestCount < 50
```

would miss a major daytime traffic collapse.

Solution:

# Anomaly Detection

---

# 91. CloudWatch Anomaly Detection

CloudWatch anomaly detection uses historical metric behavior to build an expected-value band that accounts for patterns such as:

```text
hourly patterns

daily patterns

weekly patterns
```

and can alarm when the metric moves outside that expected range. ([AWS Documentation][31])

Concept:

```text
Expected range
   ┌─────────────────────┐
   │    normal metric    │
   └─────────────────────┘

                 X
                 │
                 ▼
            anomaly
```

---

# 92. Anomaly Detection Example

Normal traffic:

```text
Monday lunch:
12k–16k req/min
```

Today:

```text
2k req/min
```

Static threshold:

```text
> 1000
```

says:

```text
OK.
```

Anomaly detection says:

```text
This is abnormal
for Monday lunch.
```

Much better signal.

---

# 93. Where Anomaly Detection Helps

Good candidates:

```text
request volume

latency

error count

CPU with predictable daily pattern

queue volume

orders/min

login rate
```

Less useful where metrics have:

```text
no stable pattern
```

or:

```text
expected chaotic behavior.
```

---

# PART N — DASHBOARDS

# 94. Dashboard Is Not a Wallpaper

Bad dashboard:

```text
50 random graphs
```

Good dashboard tells a story.

For an application:

```text
┌──────────────────────────────────────┐
│              USER HEALTH             │
│ Requests | p95 Latency | 5xx Rate    │
├──────────────────────────────────────┤
│           APPLICATION HEALTH         │
│ CPU | Memory | Process Errors        │
├──────────────────────────────────────┤
│            DEPENDENCY HEALTH         │
│ DB Connections | DB Latency | Queue  │
├──────────────────────────────────────┤
│              CAPACITY                │
│ ASG Size | Disk | EBS | Storage      │
└──────────────────────────────────────┘
```

---

# 95. Dashboard Top Row

Your first row should often answer:

```text
ARE CUSTOMERS OK?
```

Example:

```text
Request rate

Success rate

p95 latency

p99 latency

5xx rate
```

Infrastructure details belong below that.

---

# 96. Why User Signals First?

Imagine:

```text
CPU = 90%
```

but:

```text
latency good

errors zero

autoscaling working
```

This may not be an incident.

Conversely:

```text
CPU = 20%
```

but:

```text
orders = zero
```

is probably an incident.

Always prefer:

```text
user/business symptoms
```

over:

```text
resource anxiety.
```

---

# PART O — CLI HANDS-ON

Use:

```bash
export AWS_REGION=ap-south-1
```

Check identity:

```bash
aws sts get-caller-identity
```

---

# 97. List EC2 Metrics

```bash
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --region "$AWS_REGION"
```

You can filter further:

```bash
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --region "$AWS_REGION"
```

---

# 98. Retrieve CPU Data

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0123456789abcdef0 \
  --statistics Average Maximum \
  --period 300 \
  --start-time 2026-08-14T03:30:00Z \
  --end-time 2026-08-14T04:30:00Z \
  --region "$AWS_REGION"
```

Notice:

```text
Namespace
Metric
Dimension
Statistic
Period
Time Range
```

Those six concepts form most CloudWatch metric queries.

---

# 99. Publish Custom Metric

```bash
aws cloudwatch put-metric-data \
  --namespace "TodoApp/Production" \
  --metric-name OrdersCreated \
  --value 1 \
  --unit Count \
  --dimensions Environment=Production \
  --region "$AWS_REGION"
```

CloudWatch `PutMetricData` is the native API for publishing traditional custom metrics. ([AWS Documentation][3])

---

# 100. Publish High-Resolution Metric

```bash
aws cloudwatch put-metric-data \
  --namespace "TodoApp/Production" \
  --metric-name CheckoutLatency \
  --value 0.245 \
  --unit Seconds \
  --storage-resolution 1 \
  --dimensions Environment=Production \
  --region "$AWS_REGION"
```

Here:

```text
StorageResolution=1
```

makes the custom metric high-resolution. ([AWS Documentation][3])

---

# 101. List Alarms

```bash
aws cloudwatch describe-alarms \
  --region "$AWS_REGION"
```

Filter active alarms:

```bash
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --region "$AWS_REGION"
```

During an incident this is often one of the fastest ways to ask:

```text
"What is currently alarming?"
```

---

# 102. Inspect Log Groups

```bash
aws logs describe-log-groups \
  --region "$AWS_REGION"
```

Look for:

```text
logGroupName

retentionInDays

storedBytes
```

This is useful for finding:

```text
unexpectedly large log groups

missing retention

wrong environments
```

---

# 103. Tail Logs

AWS CLI also supports log tailing:

```bash
aws logs tail /prod/todo-api \
  --follow \
  --region "$AWS_REGION"
```

For richer centralized near-real-time investigation, CloudWatch Logs Live Tail provides dedicated filtering/highlighting functionality. ([AWS Documentation][25])

---

# PART P — TERRAFORM

Current HashiCorp AWS provider 6.58.0 exposes CloudWatch resources including `aws_cloudwatch_log_group`, `aws_cloudwatch_metric_alarm`, `aws_cloudwatch_dashboard`, and log metric filters. ([Terraform Registry][32])

---

# 104. Terraform Log Group

```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/prod/todo-api"
  retention_in_days = 30

  tags = {
    Environment = "production"
    Application = "todo-api"
    ManagedBy   = "terraform"
  }
}
```

The production rule:

```text
Do not create production log groups
without deliberately choosing retention.
```

---

# 105. Terraform CPU Alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "prod-todo-ec2-cpu-high"
  alarm_description   = "Sustained EC2 CPU utilization is high"

  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"

  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3

  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "missing"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  ok_actions = [
    aws_sns_topic.operations.arn
  ]
}
```

For a one-minute EC2 alarm like this, the instance must provide data at compatible resolution—for EC2 that generally means detailed monitoring rather than five-minute basic monitoring. ([AWS Documentation][2])

---

# 106. Better Autoscaling Alarm Thinking

For an Auto Scaling Group, don't normally create:

```text
one hardcoded alarm
per ephemeral EC2 InstanceId
```

if the operational question is:

```text
"Is the service fleet overloaded?"
```

Use:

```text
ASG-level metrics

ALB metrics

target tracking

application metrics
```

because individual instances are replaceable.

Observability architecture should follow resource lifecycle.

---

# 107. Terraform Metric Filter

Suppose app logs contain:

```text
PaymentFailed
```

Terraform:

```hcl
resource "aws_cloudwatch_log_metric_filter" "payment_failure" {
  name           = "payment-failure"
  log_group_name = aws_cloudwatch_log_group.app.name

  pattern = "\"PaymentFailed\""

  metric_transformation {
    name      = "PaymentFailures"
    namespace = "TodoApp/Production"
    value     = "1"
  }
}
```

The provider's current log metric-filter resource converts matching CloudWatch Logs events into metrics. ([Terraform Registry][33])

---

# 108. Alarm on Log-Derived Metric

```hcl
resource "aws_cloudwatch_metric_alarm" "payment_failure" {
  alarm_name = "prod-payment-failures"

  namespace   = "TodoApp/Production"
  metric_name = "PaymentFailures"

  statistic = "Sum"

  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  threshold = 5

  comparison_operator =
    "GreaterThanThreshold"

  treat_missing_data =
    "notBreaching"

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]
}
```

Because the metric is sparse:

```text
no PaymentFailed logs
=
good
```

`notBreaching` is usually the sensible missing-data semantics. ([AWS Documentation][26])

---

# 109. Terraform Dashboard

```hcl
resource "aws_cloudwatch_dashboard" "production" {
  dashboard_name = "todo-production"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"

        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "EC2 CPU"
          view   = "timeSeries"
          region = "ap-south-1"
          period = 60

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              aws_instance.app.id
            ]
          ]
        }
      }
    ]
  })
}
```

HashiCorp's current AWS provider exposes `aws_cloudwatch_dashboard` for managing CloudWatch dashboards as code. ([Terraform Registry][34])

---

# PART Q — PRODUCTION MONITORING ARCHITECTURE

# 110. Complete Web Application Monitoring

```text
                           USERS
                             │
                             ▼
                         CloudFront
                             │
                             ▼
                            ALB
                             │
                  ┌──────────┼──────────┐
                  ▼          ▼          ▼
               Request    Latency      5xx
                  │          │          │
                  └──────────┼──────────┘
                             ▼
                        CloudWatch
                             │
                             ▼
                           ALARMS


                       EC2 / ECS APP
                             │
                   CloudWatch Agent
                             │
                 ┌───────────┼─────────────┐
                 ▼           ▼             ▼
               CPU         Memory          Logs
               Disk       Process          Errors
                 │           │             │
                 └───────────┼─────────────┘
                             ▼
                        CloudWatch


                            RDS
                             │
              ┌──────────────┼───────────────┐
              ▼              ▼               ▼
             CPU         Connections       Latency
                                            Storage
                             │
                             ▼
                        CloudWatch


                        CloudWatch
                             │
                 ┌───────────┼───────────┐
                 ▼           ▼           ▼
              Dashboard    Alarms      Logs Insights
                             │
                             ▼
                       EventBridge/SNS
                             │
                             ▼
                         ENGINEER
```

---

# 111. Production Dashboard Layout

I recommend thinking in this order:

```text
ROW 1
USER EXPERIENCE

Request Rate
Success Rate
p95 Latency
p99 Latency


ROW 2
SERVICE HEALTH

ALB Target 5xx
Healthy Hosts
App Errors
Queue Depth


ROW 3
COMPUTE

CPU
Memory
Disk
ASG Desired/InService


ROW 4
DATABASE

Connections
CPU
Memory
Read/Write Latency
Storage


ROW 5
DEPENDENCIES

External API Errors
Cache Hit Rate
SQS backlog
Lambda Errors
```

When an incident occurs, this tells a story from the user downward.

---

# PART R — TROUBLESHOOTING SCENARIOS

# 112. Scenario — CPU Alarm Never Fires

Configuration:

```text
EC2 basic monitoring
=
5-minute data
```

Alarm:

```text
Period = 60 seconds
```

Problem:

```text
metric resolution
does not match alarm expectation.
```

Fix:

```text
Enable detailed monitoring

or

use compatible period.
```

AWS specifically requires alarm periods at least as large as the metric's resolution. ([AWS Documentation][2])

---

# 113. Scenario — Memory Metric Missing

You search:

```text
AWS/EC2
MemoryUtilization
```

nothing exists.

Reason:

```text
guest memory usage
is not a normal EC2 default metric.
```

Fix:

```text
install/configure CloudWatch Agent.
```

([AWS Documentation][35])

---

# 114. Scenario — Disk Is Full but CloudWatch Looks Fine

You watched:

```text
EBS VolumeReadOps
```

but not:

```text
filesystem used %
```

Those are different layers.

```text
EBS metrics
=
block device performance


filesystem usage
=
guest operating-system state
```

Use:

```text
CloudWatch Agent
```

for filesystem usage.

---

# 115. Scenario — Average Latency Looks Great

Dashboard:

```text
Average:
180 ms
```

Customers complain.

Check:

```text
p95

p99
```

Maybe:

```text
p95 = 400 ms
p99 = 9 seconds
```

Average hides tail latency. CloudWatch percentile statistics are designed specifically to reveal this distribution behavior. ([AWS Documentation][7])

---

# 116. Scenario — 100 Errors Trigger Alarm During Traffic Spike

Old:

```text
Errors > 100
```

Normal load grew 100×.

Better:

```text
ErrorRate
=
Errors / Requests × 100
```

using:

```text
metric math.
```

([AWS Documentation][8])

---

# 117. Scenario — Alarm Goes INSUFFICIENT_DATA Every Night

Ask:

```text
Is metric sparse by design?
```

Example:

```text
ErrorCount
```

emits data only when errors occur.

If yes:

```text
TreatMissingData=notBreaching
```

may fit better. ([AWS Documentation][28])

---

# 118. Scenario — Heartbeat Disappears but Alarm Stays OK

Metric:

```text
Heartbeat=1
every minute.
```

Missing data currently configured:

```text
notBreaching
```

Bad choice.

Consider:

```text
breaching
```

because:

```text
missing heartbeat
=
failure signal.
```

This shows why missing-data settings must reflect metric meaning. ([AWS Documentation][28])

---

# 119. Scenario — 30 Alerts for One Database Outage

Use:

```text
Composite Alarms
```

to combine relevant service-level alarms and reduce alert noise. CloudWatch composite alarms support boolean rule expressions over underlying alarms. ([AWS Documentation][30])

---

# 120. Scenario — Request Traffic Naturally Drops at Night

Static threshold:

```text
RequestCount < 5000
```

is noisy.

Use:

```text
CloudWatch Anomaly Detection
```

if traffic has predictable historical patterns. The anomaly model can account for hourly, daily, and weekly patterns. ([AWS Documentation][36])

---

# 121. Scenario — Logs Are Too Expensive

Investigate:

```text
Which groups ingest the most?

Are debug logs enabled in prod?

Do logs contain huge payloads?

Are we ingesting sparse/binary files?

Retention too long?

Wrong log class?

Duplicate telemetry?
```

AWS specifically warns that sending sparse files through the CloudWatch agent can generate unexpectedly high ingestion because the agent reads their apparent size. ([AWS Documentation][13])

---

# 122. Scenario — Cannot Find Error in 100 Servers

Don't SSH into every node.

Use:

```text
CloudWatch Logs
+
Logs Insights
```

Query across centralized log streams. Logs Insights is designed specifically for interactive analysis of log data across selected log groups. ([AWS Documentation][23])

---

# PART S — EXAM / INTERVIEW TRAPS

# 123. SAA-C03

> Need EC2 memory utilization.

Answer:

```text
CloudWatch Agent
```

not:

```text
EC2 detailed monitoring.
```

Detailed monitoring changes the frequency of built-in EC2 metrics; it does not magically add every guest OS metric. ([AWS Documentation][4])

---

# 124. SAA-C03

> Need EC2 CPU metrics every minute.

Answer:

```text
Enable EC2 Detailed Monitoring.
```

([AWS Documentation][4])

---

# 125. SAA-C03

> Need custom metrics every second.

Answer:

```text
High-resolution custom CloudWatch metric
StorageResolution = 1.
```

([AWS Documentation][3])

---

# 126. SAA-C03

> Want alert only if 3 of the last 5 one-minute datapoints breach.

Use:

```text
Period = 60

EvaluationPeriods = 5

DatapointsToAlarm = 3
```

This is:

```text
M-of-N alarm.
```

([AWS Documentation][5])

---

# 127. DOP-C02

> Need alert based on error percentage, not raw error count.

Use:

```text
CloudWatch Metric Math.
```

([AWS Documentation][8])

---

# 128. DOP-C02

> Need fewer alerts when several low-level alarms represent one outage.

Think:

```text
Composite Alarm.
```

([AWS Documentation][30])

---

# 129. DOP-C02

> Workload has strong daily traffic seasonality. Need dynamic threshold.

Think:

```text
CloudWatch Anomaly Detection.
```

([AWS Documentation][36])

---

# 130. DOP-C02

> Need to query distributed application logs without logging into EC2 instances.

Think:

```text
CloudWatch Logs

CloudWatch Logs Insights
```

---

# 131. Scenario

> Need to watch incoming logs interactively during an incident.

Think:

```text
CloudWatch Logs Live Tail.
```

([AWS Documentation][25])

---

# 132. Scenario

> Need to turn matching ERROR logs into a count metric.

Think:

```text
CloudWatch Logs Metric Filter.
```

([AWS Documentation][20])

---

# 133. Scenario

> Need PromQL-native telemetry from OpenTelemetry SDKs.

Modern CloudWatch supports:

```text
OTLP
+
OpenTelemetry metrics
+
PromQL
+
Query Studio
+
PromQL alarms
```

([AWS Documentation][2])

This is an important 2026-era CloudWatch capability that older CloudWatch courses frequently don't cover.

---

# 134. Never-Forget Metric Formula

```text
                    CLOUDWATCH METRIC

                     Namespace
                         │
                         ▼
                    Metric Name
                         │
                         ▼
                    Dimensions
                         │
                         ▼
                      Values
                         │
                         ▼
                     Timestamp
                         │
                         ▼
                     Statistic
                         │
                         ▼
                       Period
                         │
                         ▼
                      Alarm
```

If CloudWatch metrics ever feel confusing, trace the problem through those fields.

---

# 135. Never-Forget Investigation Flow

```text
                     ALERT FIRES
                         │
                         ▼
                 Is user impacted?
                         │
                         ▼
                     Dashboard
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
          Metrics       Logs        Traces
            │            │            │
            └────────────┼────────────┘
                         ▼
                    Root Cause
                         │
                         ▼
                       Fix
```

Don't jump directly from:

```text
CPU alarm
```

to:

```text
resize instance.
```

Investigate first.

---

# 136. 30 Rules to Burn Into Memory

```text
1. CloudWatch is AWS's central observability service.

2. Metrics are numerical time series.

3. Logs explain detailed events.

4. Traces explain request paths.

5. Namespace groups traditional CloudWatch metrics.

6. Traditional metric identity includes
   namespace + metric name + dimensions.

7. Dimensions identify specific metric series.

8. High-cardinality dimensions can create
   operational and cost problems.

9. EC2 basic monitoring = 5-minute metrics.

10. EC2 detailed monitoring = 1-minute metrics.

11. EC2 detailed monitoring does NOT automatically
    provide guest memory/filesystem metrics.

12. Use CloudWatch Agent for OS-level telemetry.

13. Custom metrics represent application/business health.

14. High-resolution custom metrics can be 1-second.

15. CloudWatch automatically rolls up old metric data.

16. Sum is good for counts.

17. Average is not always enough.

18. p95 tells you tail-user experience.

19. p99 exposes the slowest ~1% behavior.

20. Metric math combines metrics into better signals.

21. CloudWatch Logs use:
    log group → log stream → log event.

22. Structured JSON logs are easier to query.

23. Logs Insights supports QL, PPL and SQL.

24. Metric filters can convert logs into metrics.

25. CloudWatch alarms have
    OK / ALARM / INSUFFICIENT_DATA.

26. M-of-N alarms reduce noise.

27. Missing data treatment must match
    metric semantics.

28. Composite alarms reduce alert storms.

29. Anomaly detection works well for
    predictable dynamic patterns.

30. Monitor USER EXPERIENCE first,
    infrastructure second.
```

---

# The Most Important CloudWatch Mental Model

Never think:

```text
CloudWatch
=
CPU graphs.
```

Think:

```text
                         CLOUDWATCH

                    USER EXPERIENCE
                          │
                  Rate / Errors / Latency
                          │
                          ▼

                     APPLICATION
                          │
                 Custom Metrics
                 Logs
                 Traces
                          │
                          ▼

                    INFRASTRUCTURE
                          │
            EC2 / ALB / RDS / EBS / Lambda
                          │
                          ▼

                        ALARMS
                          │
                          ▼

                       RESPONSE
```

And especially:

```text
CPU HIGH
≠
APPLICATION BROKEN


CPU LOW
≠
APPLICATION HEALTHY
```

The production question is always:

```text
"Are USERS receiving
the service we promised?"
```

---

# ✅ Lesson 32 Part 1 Complete

You now understand:

```text
✓ observability vs monitoring
✓ metrics / logs / traces / events
✓ CloudWatch architecture

✓ namespaces
✓ metrics
✓ dimensions
✓ metric identity
✓ cardinality

✓ AWS service metrics
✓ custom metrics
✓ business metrics
✓ RED method
✓ USE method

✓ basic monitoring
✓ detailed monitoring
✓ 5-minute vs 1-minute metrics
✓ high-resolution metrics
✓ 1-second resolution
✓ metric retention / rollups

✓ statistics
✓ SampleCount
✓ Sum
✓ Average
✓ Minimum
✓ Maximum
✓ percentiles
✓ p50
✓ p95
✓ p99
✓ trimmed mean

✓ metric math
✓ error-rate calculations

✓ CloudWatch Agent
✓ memory metrics
✓ filesystem metrics
✓ StatsD
✓ collectd
✓ JMX
✓ OpenTelemetry
✓ OTLP
✓ modern PromQL CloudWatch metrics

✓ EC2 monitoring
✓ ALB monitoring
✓ RDS monitoring
✓ EBS monitoring
✓ micro-burst thinking

✓ CloudWatch Logs
✓ log groups
✓ log streams
✓ log events
✓ log classes
✓ deletion protection
✓ structured logging
✓ sensitive-data masking

✓ CloudWatch Logs Insights
✓ Logs Insights QL
✓ PPL
✓ SQL
✓ Live Tail
✓ metric filters
✓ log alarms

✓ CloudWatch alarms
✓ OK / ALARM / INSUFFICIENT_DATA
✓ evaluation periods
✓ datapoints-to-alarm
✓ M-of-N
✓ missing-data handling
✓ EventBridge actions

✓ composite alarms
✓ anomaly detection
✓ dashboards

✓ AWS CLI labs
✓ Terraform log groups
✓ Terraform alarms
✓ Terraform metric filters
✓ Terraform dashboards

✓ production troubleshooting
✓ SAA-C03 traps
✓ DOP-C02 scenarios
```

# Next — Lesson 32 Part 2

# **CloudTrail, AWS Config & EventBridge — Who Changed What, What Changed, and How AWS Reacts**

Part 1 answered:

```text
"HOW IS THE SYSTEM BEHAVING?"
```

Part 2 will answer three very different questions:

```text
CloudWatch
=
"What is happening operationally?"


CloudTrail
=
"WHO called which AWS API,
WHEN, FROM WHERE,
and with WHAT result?"


AWS Config
=
"What did this resource configuration
look like before and after the change?"


EventBridge
=
"What should happen automatically
when an AWS event occurs?"
```

We'll build this incident:

```text
Production security group
suddenly allows:

0.0.0.0/0 :22

        │
        ▼
CloudTrail
WHO changed it?

        │
        ▼
AWS Config
WHAT was the configuration before?

        │
        ▼
EventBridge
detect the event/change

        │
        ▼
Lambda / SSM Automation
remediate

        │
        ▼
SNS
notify security team
```

Then we'll cover **CloudTrail management vs data events, trails vs event history, organization trails, CloudTrail Lake, Insights events, log-file validation, S3/KMS architecture, AWS Config configuration items, configuration history, managed/custom Config rules, conformance packs, aggregators, remediation, EventBridge event buses, rules, patterns, schedules, archive/replay, DLQs, retries, cross-account events, Terraform, and complete production incident forensics.**

[1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html?utm_source=chatgpt.com "What is Amazon CloudWatch? - Amazon CloudWatch"
[2]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html?utm_source=chatgpt.com "Metrics concepts - Amazon CloudWatch"
[3]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html?utm_source=chatgpt.com "Publish custom metrics (PutMetricData / EMF)"
[4]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch-metrics-basic-detailed.html?utm_source=chatgpt.com "Basic monitoring and detailed monitoring in CloudWatch"
[5]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-evaluation.html "Alarm evaluation - Amazon CloudWatch"
[6]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Statistics-definitions.html "CloudWatch statistics definitions - Amazon CloudWatch"
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html "Metrics concepts - Amazon CloudWatch"
[8]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/using-metric-math.html?utm_source=chatgpt.com "Math expressions with metrics - Amazon CloudWatch"
[9]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html?utm_source=chatgpt.com "CloudWatch metrics that are available for your instances"
[10]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/metrics-collected-by-CloudWatch-agent.html?utm_source=chatgpt.com "Metrics collected by the CloudWatch agent"
[11]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html?utm_source=chatgpt.com "Collect metrics, logs, and traces using the CloudWatch agent"
[12]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-custom-metrics-statsd.html?utm_source=chatgpt.com "Retrieve custom metrics with StatsD - Amazon CloudWatch"
[13]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-common-scenarios.html?utm_source=chatgpt.com "Common scenarios with the CloudWatch agent"
[14]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLPCloudWatchAgent.html?utm_source=chatgpt.com "Amazon CloudWatch agent"
[15]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-cloudwatch.html?utm_source=chatgpt.com "Monitor your instances using CloudWatch"
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html?utm_source=chatgpt.com "Amazon CloudWatch metrics for Amazon RDS"
[17]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html?utm_source=chatgpt.com "Best practices for Amazon RDS"
[18]: https://docs.aws.amazon.com/ebs/latest/userguide/using_cloudwatch_ebs.html?utm_source=chatgpt.com "Amazon CloudWatch metrics for Amazon EBS"
[19]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-io-characteristics.html?utm_source=chatgpt.com "Amazon EBS I/O characteristics and monitoring"
[20]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogsConcepts.html?utm_source=chatgpt.com "Amazon CloudWatch Logs concepts"
[21]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatch_Logs_Log_Classes.html?utm_source=chatgpt.com "Log classes - Amazon CloudWatch Logs"
[22]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/mask-sensitive-log-data.html?utm_source=chatgpt.com "Help protect sensitive log data with masking"
[23]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html?utm_source=chatgpt.com "Analyzing log data with CloudWatch Logs Insights"
[24]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData_PPL.html?utm_source=chatgpt.com "OpenSearch Piped Processing Language (PPL)"
[25]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogs_LiveTail.html?utm_source=chatgpt.com "Troubleshoot with CloudWatch Logs Live Tail"
[26]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-log.html?utm_source=chatgpt.com "Log alarms - Amazon CloudWatch"
[27]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html?utm_source=chatgpt.com "Using Amazon CloudWatch alarms"
[28]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html?utm_source=chatgpt.com "Configuring how CloudWatch alarms treat missing data"
[29]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch-and-eventbridge.html?utm_source=chatgpt.com "Alarm events and EventBridge - Amazon CloudWatch"
[30]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm.html?utm_source=chatgpt.com "Create a composite alarm - Amazon CloudWatch"
[31]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html?utm_source=chatgpt.com "Using CloudWatch anomaly detection"
[32]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group?utm_source=chatgpt.com "aws_cloudwatch_log_group | Resources | hashicorp/aws"
[33]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter?utm_source=chatgpt.com "aws_cloudwatch_log_metric_filter | Resources | hashicorp/aws"
[34]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard?utm_source=chatgpt.com "aws_cloudwatch_dashboard | Resources | hashicorp/aws"
[35]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-and-configure-cloudwatch-agent-using-ec2-console.html?utm_source=chatgpt.com "Install and configure the CloudWatch agent using the Amazon ..."
[36]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Anomaly_Detection_Alarm.html?utm_source=chatgpt.com "Create a CloudWatch alarm based on anomaly detection"
