# AWS Masterclass — Lesson 32 Part 4

# AWS X-Ray, Application Signals, Synthetics, RUM & End-to-End Observability

## Distributed Tracing, OpenTelemetry, SLOs, Real-User Monitoring, Synthetic Tests, Internet Monitoring & Cross-Account Observability

In Part 1, CloudWatch metrics told us:

```text
p95 latency = 8.7 seconds
```

Logs might tell us:

```text
ERROR checkout request slow
```

But the real production question is:

> **Where did those 8.7 seconds go?**

Consider:

```text
                    USER BROWSER
                         │
                       120 ms
                         ▼
                     CloudFront
                         │
                        30 ms
                         ▼
                         ALB
                         │
                        20 ms
                         ▼
                    Node.js API
                         │
                  ┌──────┴──────┐
                  ▼             ▼
             Inventory       Payment
                80 ms         600 ms
                                  │
                                  ▼
                                SQS
                                  │
                                  ▼
                               Worker
                                  │
                                90 ms
                                  ▼
                              Database
                                  │
                                7.4 sec
                                  ▼

                           ROOT CAUSE
```

CPU graphs alone cannot reconstruct this path.

That is why mature observability combines:

```text
METRICS
   +
LOGS
   +
TRACES
   +
REAL USER DATA
   +
SYNTHETIC TESTS
   +
NETWORK EXPERIENCE
```

CloudWatch's current application-observability stack ties these signals together through Application Signals, X-Ray traces, RUM, Synthetics, OpenTelemetry and related CloudWatch capabilities. ([AWS Documentation][1])

---

# Part A — Distributed Tracing

## 1. What Is a Trace?

A:

# Trace

represents the journey of **one request** through a distributed system.

Example:

```text
Trace ID:
abc-123

Browser
   │
   ▼
API
   │
   ├── Auth
   │
   ├── Inventory
   │
   └── Payment
          │
          ▼
       Database
```

Every component participating in the request contributes timing and contextual information.

AWS X-Ray groups tracing data that shares the same trace ID so the complete path of an individual request can be reconstructed. X-Ray trace and trace-map data are currently retained for 30 days. ([AWS Documentation][2])

---

# 2. Trace vs Metric vs Log

Suppose:

```text
Checkout is slow.
```

### Metric

```text
p99 latency = 8.7 sec
```

Answers:

```text
HOW BAD?
```

### Log

```text
Database timeout after 7000 ms
```

Answers:

```text
WHAT HAPPENED?
```

### Trace

```text
Browser
  ↓
API
  ↓
Payment Service
  ↓
Database  ← 7.4 seconds
```

Answers:

```text
WHERE DID THE TIME GO?
```

The mature model is:

```text
Metrics
→ detect

Traces
→ localize

Logs
→ explain
```

---

# 3. Trace ID

Every distributed trace needs a shared identifier.

Conceptually:

```text
TraceId = T-12345
```

travels:

```text
Client
 │ T-12345
 ▼
API
 │ T-12345
 ▼
Payment
 │ T-12345
 ▼
Database interaction
```

X-Ray defines the trace ID as the identifier connecting all segments and subsegments created for the same client request. ([AWS Documentation][3])

---

# 4. Why Context Propagation Matters

Suppose:

```text
API
```

creates trace:

```text
T-123
```

but the Payment service creates:

```text
T-999
```

instead.

Now your monitoring system sees:

```text
Trace A:
API

Trace B:
Payment
```

rather than:

```text
Trace A:
API → Payment
```

This is called a:

```text
BROKEN TRACE
```

Trace-context propagation is therefore one of the most important concepts in distributed tracing.

---

# 5. Segment and Subsegment — X-Ray Terminology

Traditional X-Ray terminology uses:

```text
TRACE
 │
 ├── SEGMENT
 │
 │     └── SUBSEGMENTS
 │
 ├── SEGMENT
 │
 │     └── SUBSEGMENTS
 │
 └── SEGMENT
```

A segment generally represents work performed by a service handling a request.

Subsegments represent downstream or internal work such as:

```text
SQL query

DynamoDB call

HTTP dependency

S3 call

internal function
```

X-Ray receives service data as segments and combines segments sharing the same request into a trace. ([AWS Documentation][2])

---

# 6. OpenTelemetry Terminology

OpenTelemetry uses:

```text
TRACE
 │
 ├── SPAN
 │
 ├── SPAN
 │
 └── SPAN
```

Think:

```text
X-Ray segment/subsegment
          ≈
OpenTelemetry span concept
```

The terminology differs slightly, but the mental model remains:

```text
TRACE
=
whole request

SPAN
=
one timed unit of work
```

---

# 7. Example Trace

Imagine your Todo application endpoint:

```text
POST /add-todo
```

Trace:

```text
POST /add-todo
│
├── Express middleware       4 ms
│
├── authentication          12 ms
│
├── validation               3 ms
│
└── MongoDB insert        1850 ms
```

Total:

```text
~1.87 seconds
```

Without tracing:

```text
API is slow
```

With tracing:

```text
MongoDB insert
=
98% of latency
```

That is an actionable diagnosis.

---

# Part B — AWS X-Ray

## 8. What Is AWS X-Ray?

AWS X-Ray receives distributed tracing data and reconstructs application request paths, downstream dependencies, latency and faults. Integrated AWS services and instrumented applications can contribute trace information. ([AWS Documentation][4])

Conceptually:

```text
Application
     │
     ▼
OpenTelemetry instrumentation
     │
     ▼
Collector / CloudWatch Agent
     │
     ▼
X-Ray backend
     │
     ▼
Trace
     │
     ▼
Trace Map
```

---

# 9. Important 2026 X-Ray Change

This is one of the most important updates in the entire observability lesson.

Older tutorials say:

```text
Install AWS X-Ray SDK
+
run X-Ray daemon
```

That should **not** be your default choice for new applications today.

The X-Ray SDKs and X-Ray daemon entered **maintenance mode on February 25, 2026**. AWS plans to end their support on **February 25, 2027** and recommends migrating instrumentation to OpenTelemetry. ([AWS Documentation][5])

### Modern rule

```text
NEW APPLICATION
      │
      ▼
OpenTelemetry / ADOT
      │
      ▼
CloudWatch / X-Ray
```

not:

```text
NEW APPLICATION
      │
      ▼
legacy X-Ray SDK
```

---

# 10. Is X-Ray Itself Going Away?

No conclusion like:

```text
X-Ray service is deprecated
```

should be drawn from the SDK change.

The transition concerns the **X-Ray SDKs and daemon instrumentation model**.

AWS continues to use X-Ray trace data and trace views as part of CloudWatch/Application Signals observability, while recommending OpenTelemetry for instrumentation. ([AWS Documentation][6])

---

# 11. OpenTelemetry — The Modern Direction

OpenTelemetry gives you a vendor-neutral model for:

```text
Traces
Metrics
Logs
```

AWS provides:

# AWS Distro for OpenTelemetry — ADOT

and CloudWatch can ingest OTLP telemetry. AWS currently recommends the CloudWatch Agent for many CloudWatch OpenTelemetry scenarios because it operates as an AWS-managed OpenTelemetry Collector with CloudWatch integration built in. ([AWS Documentation][7])

Architecture:

```text
Node.js
Python
Java
.NET
    │
    ▼
OpenTelemetry
    │
    ▼
CloudWatch Agent
    │
    ├── metrics
    └── traces
         │
         ▼
      CloudWatch
      / X-Ray
```

---

# Part C — Sampling

## 12. Why Not Trace Every Request?

Suppose:

```text
100,000 requests/sec
```

and each creates many spans.

Tracing every request can create unnecessary:

```text
telemetry volume

storage

processing

cost

network overhead
```

So tracing systems commonly use:

# Sampling

---

# 13. Sampling Mental Model

```text
Incoming requests
      │
      ▼
100,000 requests
      │
      ▼
Sampling decision
      │
   ┌──┴────────┐
   ▼           ▼
Trace        Don't trace
```

You still collect enough representative traces to understand system behavior.

Traditional X-Ray default SDK sampling traces the first request each second and then 5% of additional requests, unless sampling rules change the behavior. ([AWS Documentation][2])

Because new applications should favor OpenTelemetry, treat that specific default as an **X-Ray SDK historical/default behavior**, not a universal OpenTelemetry law.

---

# 14. Don't Sample Important Requests Blindly

Imagine:

```text
/payment
```

and only:

```text
0.1%
```

is sampled.

A rare payment failure may never appear.

Production sampling strategies often give different priority to:

```text
errors

slow requests

critical transactions

high-volume health checks
```

versus ordinary traffic.

Tracing strategy should therefore be based on **business importance and traffic shape**, not one global percentage.

---

# Part D — Annotations vs Metadata

## 15. X-Ray Annotation

An annotation is:

```text
small indexed key/value context
```

Example:

```text
environment=production

customerTier=premium

orderRegion=india
```

Annotations can be searched using X-Ray filter expressions. ([AWS Documentation][8])

---

# 16. Metadata

Metadata is:

```text
additional non-indexed trace context
```

Example:

```json
{
  "retryCount": 2,
  "backend": {
    "cluster": "mongo-prod-01"
  }
}
```

Metadata can contain richer structures but isn't indexed for X-Ray filtering. ([AWS Documentation][8])

### Memory trick

```text
ANNOTATION
=
SEARCH ME


METADATA
=
STORE DETAILS
```

---

# 17. Do Not Put Secrets in Traces

Never attach:

```text
password

JWT

Authorization header

access key

database password

credit-card details
```

as annotations or metadata.

Tracing is observability data and should be treated like logs:

```text
use identifiers
not secrets
```

Anyone granted trace-read permissions may be able to view stored trace context. ([AWS Documentation][9])

---

# Part E — Trace Map / Application Map

## 18. Trace Map

Suppose traces reveal:

```text
                     frontend
                         │
                         ▼
                       API
                    /    |    \
                   /     |     \
                  ▼      ▼      ▼
               Auth    SQS    Payment
                               │
                               ▼
                              RDS
```

This is invaluable because you discover:

```text
dependencies

latency

error paths

unexpected service calls
```

from telemetry rather than relying on a stale architecture diagram.

---

# 19. 2026 Map Terminology

CloudWatch's newer:

# Application Map

has replaced the older CloudWatch Service Map experience.

For X-Ray-specific trace visualization, CloudWatch still exposes the:

# X-Ray Trace Map

as a separate tracing view. ([AWS Documentation][10])

So if an old tutorial says:

```text
CloudWatch → Service Map
```

don't be surprised when the console now emphasizes:

```text
Application Map
```

instead.

---

# Part F — CloudWatch Application Signals

## 20. What Problem Does Application Signals Solve?

Raw tracing gives enormous detail.

But operators also need:

```text
Which services exist?

Which service is unhealthy?

What operations are slow?

Which dependency is failing?

Are our SLOs being met?
```

CloudWatch Application Signals automatically organizes supported application telemetry into services, operations and dependencies and presents operational health, application topology and SLO information. ([AWS Documentation][1])

---

# 21. Application Signals Mental Model

```text
                      Application Signals
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
      Services            Operations          Dependencies
         │                    │                    │
         └────────────────────┼────────────────────┘
                              ▼
                     Latency / Availability
                              │
                              ▼
                             SLO
                              │
                              ▼
                       Application Map
```

---

# 22. Automatic Service Discovery

After Application Signals instrumentation, supported services and APIs can appear automatically in:

```text
Services

Service detail

Application Map
```

along with discovered dependencies. ([AWS Documentation][11])

Current support is tested across environments including:

```text
EKS
native Kubernetes
ECS
EC2
```

with Lambda having a dedicated Application Signals integration path. The current support matrix includes multiple language/instrumentation options, with Java, .NET, Python and Node.js as key supported routes and additional OpenTelemetry-based paths for other languages. ([AWS Documentation][12])

---

# 23. What Metrics Does Application Signals Generate?

For discovered services and operations, Application Signals automatically provides standard application signals such as:

```text
Latency

Availability
```

which can directly serve as SLI inputs. ([AWS Documentation][13])

This means instead of manually wiring:

```text
API request count

5xx count

latency distribution

dependency dimensions
```

for every microservice, Application Signals can build much of that operational service model from instrumentation.

---

# 24. Application Signals Correlation

Application Signals can correlate:

```text
service metrics

X-Ray traces

application logs

container telemetry
```

to help move from high-level degradation toward detailed evidence. ([AWS Documentation][14])

That creates a powerful drill-down:

```text
SLO red
  │
  ▼
Service slow
  │
  ▼
Operation /checkout slow
  │
  ▼
Correlated traces
  │
  ▼
Payment dependency
  │
  ▼
Correlated application logs
```

---

# Part G — SLI, SLO and SLA

## 25. These Three Are Often Confused

### SLI — Service Level Indicator

The actual measurement.

Examples:

```text
availability

latency

successful requests
```

---

### SLO — Service Level Objective

Your internal performance target.

Example:

```text
99.9% checkout availability
```

---

### SLA — Service Level Agreement

A contractual commitment made to a customer, potentially including commercial consequences.

Mental trick:

```text
SLI
=
INDICATOR


SLO
=
OBJECTIVE


SLA
=
AGREEMENT
```

---

# 26. Availability SLI

Application Signals defines its standard availability signal around successful versus fault responses, with `5xx` responses treated as faults in that standard metric. ([AWS Documentation][13])

Conceptually:

```text
Availability

=
Successful requests
────────────────────
Total requests
```

Example:

```text
9990 successful
10 failed

Availability
=
99.9%
```

---

# 27. Latency SLO

Example:

```text
SLO:

99%
of checkout requests

must complete
under 500 ms
```

This is much stronger than:

```text
Average latency < 500 ms
```

because an average can hide terrible tail performance.

CloudWatch Application Signals supports SLOs built around latency, availability and arbitrary CloudWatch metrics or metric expressions. ([AWS Documentation][13])

---

# 28. Error Budget

Suppose your SLO:

```text
Availability
=
99.9%
```

Your allowed failure budget is:

```text
100% - 99.9%
=
0.1%
```

This:

# error budget

represents how much unreliability your service can tolerate while still meeting the objective.

---

# 29. Why Error Budgets Matter

Imagine:

```text
SLO:
99.9%

Current:
99.999%
```

Your service is performing far better than required.

You may have room to:

```text
deploy features

perform changes

accept controlled risk
```

But if:

```text
Current:
99.85%
```

you have already exceeded the objective.

The operational response may become:

```text
reduce risky releases

focus on reliability

fix recurring failure
```

---

# 30. Burn Rate

CloudWatch SLOs can calculate:

# burn rate

which measures how quickly your service is consuming its error budget relative to the SLO target. ([AWS Documentation][13])

Mental model:

```text
Burn rate = 1
```

roughly means:

```text
consuming budget
at expected long-term pace
```

while:

```text
Burn rate = 10
```

means:

```text
budget disappearing
much faster
```

---

# 31. Page on Burn Rate, Not Every Error

One request fails:

```text
probably not an incident
```

Error budget burning 20× faster than expected:

```text
probably important
```

This is a much stronger SRE alerting philosophy.

---

# Part H — Application Signals + Change Events

## 32. “It Broke After Deployment”

This happens constantly:

```text
10:00 deployment

10:03 latency rises

10:05 errors rise
```

Application Signals can process supported CloudTrail-backed change events and display deployment/configuration changes alongside application topology and health information. ([AWS Documentation][15])

So an investigation can become:

```text
Latency degradation
      │
      ▼
Application Map
      │
      ▼
Deployment marker at 10:00
      │
      ▼
Version 42 deployed
```

instead of:

```text
"Did anyone deploy something?"
```

in Slack.

---

# Part I — Hands-On: Node.js + Application Signals

This directly applies to a Node.js/Express production API.

We'll use:

```text
EC2
ap-south-1
Node.js API
CloudWatch Agent
ADOT auto-instrumentation
```

AWS's current EC2 Application Signals setup for Node.js uses the AWS Distro for OpenTelemetry auto-instrumentation package and sends OTLP telemetry to the local CloudWatch Agent. ([AWS Documentation][16])

---

# 33. Architecture

```text
Node.js Express App
       │
       │ OpenTelemetry
       ▼
ADOT auto-instrumentation
       │
       ▼
CloudWatch Agent
localhost:4316
       │
       ├──── metrics
       │
       └──── traces
             │
             ▼
      Application Signals
             │
             ▼
          X-Ray traces
```

---

# 34. Install Node Instrumentation

Inside the application:

```bash
npm install @aws/aws-distro-opentelemetry-node-autoinstrumentation
```

This is the current AWS-documented ADOT auto-instrumentation package for Node.js Application Signals on EC2. ([AWS Documentation][16])

---

# 35. Configure CloudWatch Agent

A minimal conceptual agent configuration is:

```json
{
  "traces": {
    "traces_collected": {
      "application_signals": {}
    }
  },
  "logs": {
    "metrics_collected": {
      "application_signals": {}
    }
  }
}
```

AWS uses this pattern to enable Application Signals metric and trace collection through the CloudWatch Agent. ([AWS Documentation][16])

The EC2 role also needs the appropriate CloudWatch Agent permissions; AWS's documented setup uses `CloudWatchAgentServerPolicy`. ([AWS Documentation][16])

---

# 36. Start the Application with OpenTelemetry

Conceptually:

```bash
export SVC_NAME=todo-api

export OTEL_AWS_APPLICATION_SIGNALS_ENABLED=true
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4316/v1/traces

export OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT=http://localhost:4316/v1/metrics

export OTEL_RESOURCE_ATTRIBUTES="service.name=${SVC_NAME},deployment.environment=production"

node \
  --require '@aws/aws-distro-opentelemetry-node-autoinstrumentation/register' \
  start.js
```

AWS's current EC2 path uses the CloudWatch Agent's local OTLP endpoint on port `4316` and the ADOT Node.js register hook for auto-instrumentation. ([AWS Documentation][16])

---

# 37. Why Auto-Instrumentation Is Useful

Without it, you might manually add instrumentation around:

```text
Express request

Mongo query

AWS SDK call

HTTP dependency

Redis request
```

Auto-instrumentation can detect many supported frameworks and libraries without changing every business-code path.

You can then manually add custom spans where business-specific operations need more detail.

---

# 38. Give Services Real Names

Bad:

```text
UnknownService
```

Good:

```text
todo-api

payment-service

notification-worker

inventory-api
```

Also include environment context:

```text
production

staging

development
```

Otherwise your Application Map becomes:

```text
UnknownService
  │
  ├── UnknownService
  └── UnknownService
```

which is nearly useless.

AWS's Application Signals EC2 setup explicitly supports `service.name` and deployment-environment resource attributes for this reason. ([AWS Documentation][16])

---

# Part J — CloudWatch Synthetics

## 39. Real Users Are Not a Monitoring Strategy

Imagine your application fails at:

```text
03:00 AM
```

and nobody visits until:

```text
07:00 AM.
```

Real-user telemetry reports:

```text
nothing
```

because there are no users.

You want a robot continuously asking:

> “Can customers still use the application?”

That is:

# CloudWatch Synthetics

---

# 40. Canary

A:

# Canary

is a configurable script that runs periodically and behaves like a customer or API client.

It can test:

```text
website availability

API availability

login workflows

page content

latency

user journeys
```

and can collect screenshots/load-time information for browser-based tests. ([AWS Documentation][17])

---

# 41. Canary Architecture

```text
             CloudWatch Synthetics

                     Canary
                       │
                 every minute
                       │
                       ▼
                    Website
                       │
                  ┌────┴────┐
                  ▼         ▼
               Success    Failure
                  │         │
                  ▼         ▼
               metrics    Alarm
```

Canaries can currently run as frequently as once per minute and support both rate and cron scheduling. ([AWS Documentation][18])

---

# 42. API Canary

For your Todo app:

```text
GET /get-todo
```

a canary might:

```text
1. Resolve domain

2. Connect over HTTPS

3. Call /get-todo

4. Verify status 200

5. Validate expected JSON structure

6. Record latency
```

Now even at zero customer traffic:

```text
API health
```

continues to be measured.

---

# 43. Browser Canary

A stronger test:

```text
1. Open login page

2. Enter synthetic test account

3. Log in

4. Add a todo

5. Verify item appears

6. Log out
```

This tests:

```text
DNS
TLS
CloudFront
WAF
ALB
application
database
authentication
frontend JavaScript
```

in one customer-like workflow.

CloudWatch Synthetics browser runtimes currently support programmable browser automation through technologies including Playwright, Puppeteer and Selenium depending on runtime. ([AWS Documentation][18])

---

# 44. Important Canary Metrics

Useful Synthetics metrics include:

```text
SuccessPercent

Duration

2xx

4xx

5xx

Failed

Failed requests
```

depending on canary/runtime configuration. ([AWS Documentation][19])

Typical alert:

```text
SuccessPercent < 100%
for 2 consecutive runs
```

or:

```text
Duration > expected latency
```

---

# 45. Synthetics + Tracing

Enable active tracing for a canary and it can appear as a client on the Application Map / trace topology, allowing you to trace the synthetic request through your backend. ([AWS Documentation][18])

Now:

```text
Canary failed
      │
      ▼
trace
      │
      ▼
API
      │
      ▼
Payment Service
      │
      ▼
RDS slow
```

That is far more useful than:

```text
Canary returned timeout.
```

---

# 46. Protect Canary Credentials

Canary scripts may need credentials for:

```text
login

API authentication

private endpoints
```

Do not hardcode:

```text
username/password
```

into the script.

Use:

```text
Secrets Manager

appropriate IAM roles

controlled test accounts
```

and be aware that Synthetics can capture request information, HAR files, logs and screenshots, so sensitive values should be deliberately redacted. AWS documents redaction controls for sensitive URL/request details. ([AWS Documentation][20])

---

# Part K — RUM: Real User Monitoring

## 47. Synthetic Users Aren't Real Users Either

A canary in Mumbai may report:

```text
200 ms
```

while a real customer in Brazil reports:

```text
6 seconds.
```

Why?

Possible differences:

```text
ISP

device

browser

mobile network

location

frontend rendering

JavaScript errors

network path
```

This is why you also need:

# Real User Monitoring — RUM

---

# 48. CloudWatch RUM

CloudWatch RUM captures telemetry from actual user sessions in web and mobile applications and helps analyze client-side performance, errors, sessions, locations, browsers/devices and related user-experience information. ([AWS Documentation][21])

Architecture:

```text
Actual User Browser
       │
       ├── page performance
       ├── JS errors
       ├── HTTP errors
       ├── browser/device
       ├── location
       └── navigation
              │
              ▼
         CloudWatch RUM
```

---

# 49. RUM Answers Questions Backend Metrics Cannot

Example:

Backend:

```text
API p95
=
180 ms
```

RUM:

```text
Page load p95
=
5.8 sec
```

Now the bottleneck is probably not the backend API itself.

Investigate:

```text
large JS bundle

rendering

third-party scripts

frontend API waterfalls

image size

network path
```

---

# 50. RUM Metrics

RUM dashboards expose categories including:

```text
web vitals

JavaScript errors

HTTP errors

traffic volume

user flow

Apdex
```

and other real-user performance measurements. ([AWS Documentation][22])

You can filter client telemetry by dimensions such as:

```text
browser

device

location

page
```

to answer:

```text
"Is this only happening
to Safari users in India?"
```

---

# 51. RUM Sessions

RUM session views can show a waterfall of events for an actual sampled user session.

When tracing is enabled, supported HTTP events can include a trace ID linking client-side activity directly into backend trace data. ([AWS Documentation][22])

That's extremely powerful:

```text
Real customer page slow
         │
         ▼
RUM session
         │
         ▼
specific HTTP request
         │
         ▼
trace ID
         │
         ▼
backend trace
         │
         ▼
database latency
```

---

# 52. RUM + X-Ray Active Tracing

CloudWatch RUM can enable tracing for sampled sessions, generating OpenTelemetry spans that appear in tracing views and can connect client pages into Application Signals. ([AWS Documentation][23])

So modern end-to-end tracing can begin at:

```text
BROWSER
```

instead of only:

```text
BACKEND API.
```

---

# 53. Session Replay

CloudWatch RUM also supports:

# Session Replay

for web applications.

This allows authorized operators to replay captured user sessions visually to understand what users experienced. ([AWS Documentation][24])

For example:

```text
User clicks Checkout
      │
      ▼
spinner
      │
      ▼
error modal
      │
      ▼
button disappears
```

Session Replay can make frontend failures easier to reproduce.

---

# 54. Privacy Is Critical

RUM collects real-user telemetry.

AWS explicitly advises customers to evaluate legal/privacy requirements around cookies and end-user data and warns against putting sensitive personal information into free-form fields. ([AWS Documentation][25])

Therefore design:

```text
data collection

cookie consent

masking

sampling

retention

access control
```

before enabling aggressive client telemetry.

Observability must not become surveillance by accident.

---

# Part L — Synthetics vs RUM

## 55. Never Confuse Them

```text
SYNTHETICS

fake controlled user
running continuously
```

versus:

```text
RUM

actual customer
actual browser/device/network
```

### Synthetics tells you:

```text
Can a known workflow work right now?
```

### RUM tells you:

```text
What are real users actually experiencing?
```

You normally want both.

---

# 56. Example

At 10:00:

```text
Synthetic canary:
healthy from Mumbai
```

RUM shows:

```text
German customers:
huge latency spike
```

Likely:

```text
not universal application failure
```

Possibly:

```text
regional internet path
ISP issue
edge issue
```

That leads us to Internet Monitor.

---

# Part M — CloudWatch Internet Monitor

## 57. What Problem Does Internet Monitor Solve?

Sometimes:

```text
Application healthy

CloudFront healthy

ALB healthy

EC2 healthy

Database healthy
```

yet users in a specific geography complain.

The problem might exist:

```text
OUTSIDE YOUR VPC
```

on the internet path between clients and AWS.

CloudWatch Internet Monitor uses AWS global-network connectivity information to detect performance and availability degradation affecting internet traffic to your application and can provide optimization suggestions. ([AWS Documentation][26])

---

# 58. Internet Path Mental Model

```text
User
 │
 ▼
ISP
 │
 ▼
Internet / ASN
 │
 ▼
AWS edge/network
 │
 ▼
Application
```

Traditional CloudWatch infrastructure metrics mainly observe:

```text
AWS side
```

Internet Monitor helps investigate:

```text
client location
+
internet network path
```

---

# 59. Performance and Availability Scores

Internet Monitor calculates:

```text
Performance Score

Availability Score
```

relative to its estimated baseline for your application's traffic. ([AWS Documentation][27])

Example:

```text
Performance score:
99%

Availability:
99.9%

Mumbai:
healthy


Frankfurt:
Performance 70%
```

Now the incident is geographically constrained.

---

# 60. Health Events

Internet Monitor generates health events when measured performance or availability degradation exceeds configured thresholds. The current default overall threshold is 95% for both performance and availability scores, although it can be customized. ([AWS Documentation][28])

Health events are also published to EventBridge, enabling automated notification workflows. ([AWS Documentation][29])

Architecture:

```text
Internet degradation
       │
       ▼
Internet Monitor
       │
       ▼
Health Event
       │
       ▼
EventBridge
       │
       ▼
SNS / Incident system
```

---

# 61. Useful Internet Metrics

Internet Monitor query capabilities expose signals including:

```text
performance score

availability score

round-trip time

time to first byte

bytes transferred
```

for monitored traffic. ([AWS Documentation][30])

This helps distinguish:

```text
backend slow
```

from:

```text
internet path slow.
```

---

# Part N — Cross-Account Observability

## 62. Enterprise Problem

Imagine:

```text
Account A
Frontend

Account B
API

Account C
Payment

Account D
Database

Account E
Security
```

A single user request crosses four accounts.

Without centralized observability:

```text
switch account
switch role
switch console
search traces
switch account
search logs
```

during every incident.

Not scalable.

---

# 63. CloudWatch Cross-Account Observability

CloudWatch supports a central:

```text
MONITORING ACCOUNT
```

and multiple:

```text
SOURCE ACCOUNTS
```

using:

# Observability Access Manager — OAM

A monitoring account creates a:

```text
sink
```

while source accounts create:

```text
links
```

to share supported observability telemetry. ([AWS Documentation][31])

---

# 64. Architecture

```text
              AWS ORGANIZATION

      ┌──────────┼──────────┐
      ▼          ▼          ▼
   Account A   Account B  Account C
   Frontend      API       Payment
      │          │          │
      └──────────┼──────────┘
                 ▼
               OAM
                 │
                 ▼
        Monitoring Account
                 │
        ┌────────┼─────────┐
        ▼        ▼         ▼
     Metrics    Logs     Traces
                 │
                 ▼
        Application Signals
```

Application Signals cross-account monitoring requires relevant service/SLO, metric, log and trace telemetry to be shared. ([AWS Documentation][15])

---

# 65. AWS Organizations Is the Better Scale Model

CloudWatch recommends using AWS Organizations for onboarding source accounts because newly created organization accounts can then be incorporated into the cross-account observability setup automatically rather than configured individually. ([AWS Documentation][31])

This follows the pattern we've repeatedly used:

```text
Organizations
+
central service
+
delegated governance
```

---

# 66. Current Scale

A CloudWatch monitoring account can currently link to as many as:

```text
100,000 source accounts
```

and a source account can share telemetry with up to:

```text
5 monitoring accounts.
```

([AWS Documentation][31])

You do not need to memorize those numbers for daily architecture, but they show that OAM is designed for very large organizations.

---

# Part O — Production Incident Walkthrough

## 67. Incident

User reports:

> Checkout takes 9 seconds.

Start with:

```text
RUM
```

not SSH.

---

# 68. Step 1 — RUM

RUM shows:

```text
India users:
p95 = 1.2 sec

Europe users:
p95 = 8.8 sec
```

Now we know:

```text
problem is geographically biased.
```

---

# 69. Step 2 — Internet Monitor

Internet Monitor:

```text
Europe performance score:
healthy
```

Therefore likely:

```text
not primarily public internet degradation.
```

Continue into application telemetry.

---

# 70. Step 3 — Application Signals

Application Map:

```text
Frontend
    │
    ▼
Checkout API
    │
    ├── Inventory
    └── Payment
          │
          ▼
        Database
```

Service health:

```text
Checkout:
healthy

Payment:
latency degraded
```

Now the blast radius shrinks dramatically.

---

# 71. Step 4 — Trace

Open a slow trace:

```text
Checkout API        8.6 sec
│
├── auth            20 ms
├── inventory       70 ms
└── payment         8.4 sec
       │
       ├── API work   80 ms
       └── database 8.2 sec
```

Now:

```text
ROOT CAUSE AREA
=
payment database dependency
```

---

# 72. Step 5 — Logs

Use trace ID:

```text
T-123
```

to find correlated application logs.

```text
PaymentService
WARN
DB connection acquisition = 7900ms
```

Now:

```text
slow SQL?
```

No.

```text
DB connection pool exhaustion.
```

Different fix.

---

# 73. Step 6 — CloudWatch Metrics

RDS:

```text
CPU:
35%

FreeMemory:
healthy

DatabaseConnections:
at maximum
```

Now the hypothesis is confirmed:

```text
connection pool /
connection capacity issue.
```

CPU scaling alone would not address the primary bottleneck.

---

# 74. Step 7 — CloudTrail / Change Event

Application Signals shows:

```text
10:05 deployment
payment-service v52
```

Latency started:

```text
10:06
```

Investigate release.

New configuration:

```text
DB_POOL_SIZE
200 → 2000
per task
```

Ten ECS tasks:

```text
potential connections
20,000
```

Database max:

```text
far lower
```

Root cause complete.

---

# 75. Full Root Cause Chain

```text
RUM
│
└── users slow


Application Signals
│
└── Payment unhealthy


X-Ray/OpenTelemetry trace
│
└── DB connection acquisition slow


CloudWatch RDS metrics
│
└── connections saturated


CloudWatch Logs
│
└── pool wait timeout


Change Event / CloudTrail
│
└── deployment changed pool config


ROOT CAUSE
│
└── bad connection-pool configuration
```

This is what **observability** means.

Not:

```text
Look at CPU graph.
```

---

# Part P — Synthetic Incident

## 76. No Users Yet

At 02:14:

```text
Canary:
Checkout failed
```

Users are asleep.

Canary triggers:

```text
CloudWatch Alarm
      │
      ▼
EventBridge/SNS
      │
      ▼
On-call
```

Engineer investigates before customers wake up.

That is one of the biggest benefits of synthetic monitoring: it continuously exercises important paths even without live customer traffic. ([AWS Documentation][17])

---

# Part Q — Terraform Mental Models

## 77. Synthetics Canary

Terraform's AWS provider supports CloudWatch Synthetics resources such as:

```text
aws_synthetics_canary
```

A production design generally includes:

```text
canary

IAM execution role

S3 artifact location

CloudWatch alarms

Secrets Manager if authentication needed
```

Conceptually:

```hcl
resource "aws_synthetics_canary" "api" {
  name                 = "prod-api-health"
  execution_role_arn   = aws_iam_role.canary.arn
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.id}/"

  # runtime/version, schedule and code configured here
}
```

Because Synthetics runtime versions evolve, verify the current runtime before pinning one in production rather than copying an old tutorial.

---

# 78. RUM App Monitor

Terraform also supports defining RUM monitors.

Conceptually:

```hcl
resource "aws_rum_app_monitor" "frontend" {
  name   = "todo-production-web"
  domain = "app.example.com"

  # telemetry and session configuration
}
```

The important architecture is:

```text
Terraform
    │
    ▼
RUM App Monitor
    │
    ▼
frontend config/snippet
    │
    ▼
real browser telemetry
```

Never hardcode production monitoring configuration manually if it forms part of your repeatable infrastructure baseline.

---

# 79. Cross-Account OAM

The cross-account IaC model is:

```text
Monitoring account
      │
      ▼
OAM Sink


Source account
      │
      ▼
OAM Link
      │
      ▼
Sink
```

With AWS Organizations, roll this pattern through organization deployment mechanisms instead of configuring hundreds of links manually. CloudWatch explicitly supports Organizations-based onboarding for this use case. ([AWS Documentation][31])

---

# Part R — Troubleshooting

## 80. “No Traces Are Appearing”

Check:

```text
1. Is application actually instrumented?

2. Is OpenTelemetry auto-instrumentation loading?

3. Is CloudWatch Agent running?

4. Is OTLP endpoint correct?

5. IAM permissions?

6. Network connectivity?

7. Sampling eliminating most traffic?

8. Correct Region?

9. service.name configured?

10. Agent/exporter logs?
```

For Application Signals on EC2, AWS requires compatible/current CloudWatch Agent and ADOT instrumentation, appropriate IAM permissions and correct OTLP exporter endpoints. ([AWS Documentation][16])

---

# 81. “Application Signals Shows UnknownService”

Most likely:

```text
service.name
```

wasn't configured/discovered correctly.

For custom EC2/ECS setups, service/environment naming often needs to be supplied explicitly. ([AWS Documentation][16])

Fix:

```text
OTEL_RESOURCE_ATTRIBUTES
=
service.name=todo-api,
deployment.environment=production
```

---

# 82. “Trace Stops After Service A”

Think:

```text
TRACE CONTEXT PROPAGATION
```

Check Service A's outbound client and Service B's inbound instrumentation.

If the context isn't propagated:

```text
Trace A
Service A

Trace B
Service B
```

instead of one connected trace.

---

# 83. “Trace Exists but Database Call Doesn't”

Possible reasons:

```text
database library not instrumented

unsupported library

manual connection code

custom client

instrumentation initialized too late
```

Use a custom OpenTelemetry span where automatic instrumentation doesn't capture the operation.

---

# 84. “Everything Is Slow Because Tracing Was Enabled”

Check:

```text
sampling

instrumentation version

span volume

custom spans

export queue

collector capacity

high-cardinality attributes
```

Tracing should be deliberately sampled and instrumented.

Never create spans for every:

```text
tiny function

loop iteration

object allocation
```

just because you can.

---

# 85. “Canary Is Failing but Website Works”

Check:

```text
test credentials expired

WAF blocks canary

IP allow list

canary IAM

DNS

VPC routing

browser selector changed

page DOM changed

script timeout

third-party dependency
```

Synthetics browser tests can break when selectors or page structure changes even when the human workflow still works, so treat canary code like production test code. AWS documents canary timeouts and artifact/log troubleshooting for failed runs. ([AWS Documentation][32])

---

# 86. “RUM Shows Nothing”

Check:

```text
RUM snippet/client installed?

correct app monitor?

domain allowed?

browser blocked telemetry?

IAM/resource policy?

sampling?

Content Security Policy?

wrong Region?
```

Also verify whether the problem occurs in users whose browsers block the telemetry client.

RUM data comes from actual client sessions, so absent users also means absent user telemetry.

---

# Part S — Certification / Interview Scenarios

## 87. Scenario

> Need to find which microservice caused one slow distributed request.

Answer:

```text
distributed tracing

OpenTelemetry
+
AWS X-Ray / Application Signals
```

not simply:

```text
CloudWatch CPU metrics.
```

---

# 88. Scenario

> Need a robot to log into the site every five minutes and verify Checkout works.

Answer:

```text
CloudWatch Synthetics
Canary
```

Synthetics is designed to run scheduled endpoint/user-workflow checks even when real customer traffic is absent. ([AWS Documentation][18])

---

# 89. Scenario

> Need actual browser latency and JavaScript error information from customers.

Answer:

```text
CloudWatch RUM
```

RUM collects real-user client performance and error/session telemetry. ([AWS Documentation][21])

---

# 90. Scenario

> Only customers from one country report poor performance, while AWS backend metrics are healthy.

Think:

```text
CloudWatch Internet Monitor
+
RUM
```

because the problem may be client/geography/internet-path specific. ([AWS Documentation][26])

---

# 91. Scenario

> Need a central observability account for telemetry from many AWS accounts.

Answer:

```text
CloudWatch Cross-Account Observability
+
Observability Access Manager
```

with:

```text
sink
+
links
```

and preferably AWS Organizations at scale. ([AWS Documentation][31])

---

# 92. Scenario

> New application needs tracing in 2026. Should we start with the X-Ray SDK?

Preferred answer:

```text
NO for a new instrumentation design.

Use OpenTelemetry / ADOT.
```

because the X-Ray SDKs and daemon are already in maintenance mode and are scheduled for end of support in February 2027. ([AWS Documentation][5])

This is a very important modern interview answer.

---

# 93. Scenario

> Need searchable custom trace property such as `customerTier=premium`.

Think:

```text
Annotation
```

rather than ordinary metadata, because X-Ray annotations are indexed for trace filtering. ([AWS Documentation][8])

---

# 94. Scenario

> Need to store rich diagnostic JSON in the trace, but don't need to search on it.

Use:

```text
Metadata
```

because metadata can contain richer values but isn't indexed for filtering. ([AWS Documentation][8])

---

# Part T — The Complete Observability Architecture

```text
                              REAL USERS
                                  │
                                  ▼
                             CloudWatch RUM
                                  │
                         real client experience
                                  │
                                  ▼
                               Frontend

                    SYNTHETIC USER
                          │
                          ▼
                  CloudWatch Synthetics
                          │
                          ▼
                       CloudFront
                          │
                          ▼
                         ALB
                          │
                          ▼
                     Node.js API
                          │
                  OpenTelemetry / ADOT
                          │
                          ▼
                    CloudWatch Agent
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
       Metrics           Logs           Traces
          │               │               │
          │               │               ▼
          │               │             X-Ray
          │               │               │
          └───────────────┼───────────────┘
                          ▼
                  Application Signals
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
          Services      SLOs      Application Map
             │                         │
             └────────────┬────────────┘
                          ▼
                     Root Cause


              INTERNET EXPERIENCE
                       │
                       ▼
                Internet Monitor


              MULTI-ACCOUNT VIEW
                       │
                       ▼
             Observability Access
                  Manager
                       │
                       ▼
              Monitoring Account
```

---

# 95. Never-Forget Decision Table

| Question                                     | Best starting tool                |
| -------------------------------------------- | --------------------------------- |
| Is CPU high?                                 | CloudWatch Metrics                |
| Why did request fail?                        | Logs                              |
| Which service caused request latency?        | Trace / X-Ray                     |
| Which service is unhealthy?                  | Application Signals               |
| Are we meeting reliability objectives?       | SLO                               |
| Is error budget disappearing rapidly?        | Burn rate                         |
| Does website work with no users online?      | Synthetics                        |
| What are real customers experiencing?        | RUM                               |
| Is problem browser/device/location specific? | RUM                               |
| Is internet path degraded geographically?    | Internet Monitor                  |
| How do I view telemetry from many accounts?  | OAM / Cross-account observability |
| How do I instrument new apps?                | OpenTelemetry / ADOT              |

---

# 96. 30 Rules to Burn Into Memory

```text
1. Metrics tell you that something changed.

2. Logs explain detailed events.

3. Traces show where a request spent time.

4. One distributed request shares a trace context.

5. A trace contains multiple units of work.

6. OpenTelemetry calls those units spans.

7. X-Ray historically uses segments/subsegments.

8. Broken trace propagation creates disconnected traces.

9. Sampling controls tracing volume.

10. Don't blindly trace 100% of huge traffic.

11. Don't sample away every critical transaction.

12. X-Ray annotations are indexed/searchable.

13. X-Ray metadata is not indexed.

14. Never put secrets into trace attributes.

15. The X-Ray SDK/daemon entered maintenance
    mode February 25, 2026.

16. X-Ray SDK/daemon support is scheduled to end
    February 25, 2027.

17. Use OpenTelemetry/ADOT for new instrumentation.

18. Application Signals organizes telemetry
    by services and dependencies.

19. Application Signals provides latency
    and availability signals.

20. SLI = measurement.

21. SLO = reliability objective.

22. SLA = customer agreement.

23. Error budget measures tolerated unreliability.

24. Burn rate shows how fast error budget disappears.

25. Synthetics = controlled fake user.

26. RUM = actual user experience.

27. Synthetics can discover failures before customers do.

28. Internet Monitor investigates internet-path experience.

29. OAM enables central multi-account observability.

30. Mature incident response correlates:
    user → service → trace → logs → metrics → change.
```

---

# 97. The Most Important Mental Model

When an application is slow, do **not** immediately ask:

```text
"Which server has high CPU?"
```

Ask:

```text
WHO is affected?
      │
      ▼
RUM / Synthetics


WHERE is the slowdown?
      │
      ▼
Application Signals / Trace


WHAT operation is slow?
      │
      ▼
Span / dependency


WHY is it slow?
      │
      ▼
Logs + metrics


WHAT CHANGED?
      │
      ▼
CloudTrail / change events


IS INTERNET PATH INVOLVED?
      │
      ▼
Internet Monitor
```

That is production observability.

---

# ✅ Lesson 32 Part 4 Complete

You now understand:

```text
✓ distributed tracing
✓ traces
✓ trace IDs
✓ propagation
✓ spans
✓ X-Ray segments
✓ X-Ray subsegments
✓ OpenTelemetry model

✓ X-Ray architecture
✓ X-Ray Trace Map
✓ Application Map
✓ current 30-day trace retention

✓ sampling
✓ sampling strategies
✓ annotations
✓ metadata
✓ trace filtering

✓ 2026 X-Ray SDK maintenance status
✓ 2027 X-Ray SDK/daemon end-of-support plan
✓ migration to OpenTelemetry
✓ ADOT
✓ OTLP
✓ CloudWatch Agent tracing

✓ Application Signals
✓ service discovery
✓ dependencies
✓ service operations
✓ latency
✓ availability
✓ trace/log correlation
✓ deployment/change-event correlation

✓ SLI
✓ SLO
✓ SLA
✓ error budgets
✓ burn rates
✓ latency SLOs
✓ availability SLOs

✓ Node.js ADOT auto-instrumentation
✓ CloudWatch Agent OTLP pipeline
✓ service.name
✓ environment identification

✓ CloudWatch Synthetics
✓ canaries
✓ API canaries
✓ browser canaries
✓ SuccessPercent
✓ Duration
✓ screenshots/artifacts
✓ active tracing
✓ synthetic credential security

✓ CloudWatch RUM
✓ real-user sessions
✓ web performance
✓ JavaScript errors
✓ HTTP failures
✓ browser/device/location analysis
✓ trace correlation
✓ user journey
✓ session replay
✓ privacy considerations

✓ Internet Monitor
✓ internet performance
✓ availability score
✓ performance score
✓ geographic incidents
✓ EventBridge health events

✓ Observability Access Manager
✓ source accounts
✓ monitoring account
✓ sinks
✓ links
✓ Organizations integration
✓ multi-account observability

✓ complete browser-to-database incident workflow
✓ Terraform/IaC architecture
✓ troubleshooting
✓ SAA-C03 scenarios
✓ DOP-C02 scenarios
```

# ✅ Lesson 32 — AWS Observability & Operations COMPLETE

Across Lesson 32 we built the full operational control plane:

```text
                    AWS PRODUCTION OPERATIONS

                              │
         ┌────────────────────┼─────────────────────┐
         ▼                    ▼                     ▼
     CloudWatch           CloudTrail             Config
         │                    │                     │
     behavior             API audit            resource state
         │                    │                     │
         └────────────────────┼─────────────────────┘
                              ▼
                         EventBridge
                              │
                              ▼
                         Automation


                        Systems Manager
                              │
             Session / Run / Patch / Fleet
                              │
                              ▼
                         Managed Nodes


                    Application Observability
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
             RUM          Synthetics       Traces
               │              │              │
               └──────────────┼──────────────┘
                              ▼
                     Application Signals
                              │
                         SLO / Map
                              │
                              ▼
                         ROOT CAUSE
```

---

# Next — Lesson 33

# **AWS Serverless Architecture — Lambda & API Gateway from Beginner to Production**

We now move from operating servers to:

```text
                    NO SERVER MANAGEMENT

                           Client
                             │
                             ▼
                        API Gateway
                             │
                             ▼
                           Lambda
                             │
               ┌─────────────┼─────────────┐
               ▼             ▼             ▼
           DynamoDB         SQS           S3
               │             │             │
               └─────────────┼─────────────┘
                             ▼
                         EventBridge
```

We'll build Lambda from first principles and then go deep into **execution environments, cold starts, concurrency, reserved/provisioned concurrency, timeouts, memory/CPU sizing, `/tmp` storage, IAM execution roles, VPC Lambda, ENIs/Hyperplane, NAT/VPC endpoints, environment variables, Secrets Manager, Lambda Layers, container images, versions, aliases, weighted deployments, async vs synchronous invocation, retries, destinations, DLQs, event-source mappings, partial batch failure, idempotency, API Gateway REST vs HTTP vs WebSocket APIs, integrations, authorizers, JWT/Cognito, throttling, caching, custom domains, ACM, WAF, access logging, tracing, Lambda Powertools/OpenTelemetry, Terraform, cost optimization, and a production serverless capstone.**

[1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html?utm_source=chatgpt.com "Application Signals - Amazon CloudWatch"
[2]: https://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html?utm_source=chatgpt.com "AWS X-Ray concepts"
[3]: https://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html?utm_source=chatgpt.com "AWS X-Ray segment documents"
[4]: https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html?utm_source=chatgpt.com "AWS X-Ray"
[5]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-daemon-timeline.html?utm_source=chatgpt.com "X-Ray SDK and Daemon Support timeline"
[6]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-migration.html?utm_source=chatgpt.com "Migrating from X-Ray instrumentation to OpenTelemetry ..."
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLPGettingStarted.html?utm_source=chatgpt.com "Getting started - Amazon CloudWatch"
[8]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-dotnet-segment.html?utm_source=chatgpt.com "Add annotations and metadata to segments with the X-Ray ..."
[9]: https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs.html?utm_source=chatgpt.com "AWS X-Ray SDK for Node.js"
[10]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ServiceMap.html?utm_source=chatgpt.com "View your application topology and monitor operational ..."
[11]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Services.html?utm_source=chatgpt.com "Monitor the operational health of your applications with ..."
[12]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-supportmatrix.html "Supported systems - Amazon CloudWatch"
[13]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-ServiceLevelObjectives.html "Service level objectives (SLOs) - Amazon CloudWatch"
[14]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ServiceDetail.html?utm_source=chatgpt.com "View detailed service activity and operational health with the service ..."
[15]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html "Application Signals - Amazon CloudWatch"
[16]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-EC2Main.html "Enable your applications on Amazon EC2 - Amazon CloudWatch"
[17]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html?utm_source=chatgpt.com "Synthetic monitoring (canaries) - Amazon CloudWatch"
[18]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html "Synthetic monitoring (canaries) - Amazon CloudWatch"
[19]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries_metrics.html?utm_source=chatgpt.com "CloudWatch metrics published by canaries - AWS Documentation"
[20]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/servicelens_canaries_security.html?utm_source=chatgpt.com "Security considerations for Synthetics canaries"
[21]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM.html?utm_source=chatgpt.com "CloudWatch RUM - AWS Documentation"
[22]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-view-data.html "Viewing the CloudWatch RUM dashboard - Amazon CloudWatch"
[23]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-web-mobile.html?utm_source=chatgpt.com "Set up a mobile application to use CloudWatch RUM"
[24]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-session-replay.html?utm_source=chatgpt.com "Session replay - Amazon CloudWatch"
[25]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-RUM-privacy.html?utm_source=chatgpt.com "Data protection and data privacy with CloudWatch RUM"
[26]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-InternetMonitor.what-is-cwim.html?utm_source=chatgpt.com "What is Internet Monitor? - Amazon CloudWatch"
[27]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-IM-components.html?utm_source=chatgpt.com "Components and terms for Internet Monitor"
[28]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-IM-inside-internet-monitor.html?utm_source=chatgpt.com "How Internet Monitor works - Amazon CloudWatch"
[29]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-IM-EventBridge-integration.html?utm_source=chatgpt.com "Using Internet Monitor with Amazon EventBridge"
[30]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-IM-view-cw-tools-cwim-query.html?utm_source=chatgpt.com "Use the Internet Monitor query interface"
[31]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Unified-Cross-Account.html "CloudWatch cross-account observability - Amazon CloudWatch"
[32]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries_Troubleshoot.html?utm_source=chatgpt.com "Troubleshooting a failed canary - Amazon CloudWatch"
