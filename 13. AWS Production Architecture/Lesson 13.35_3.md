# AWS Masterclass — Lesson 35 Part 3

# ECS Auto Scaling, Capacity Providers, Fargate Spot, Container Insights & Production Operations

In Part 2 we made the ECS application highly available:

```text
Internet
   │
   ▼
ALB
   │
   ▼
ECS Service
   │
   ├── Task A — AZ-A
   └── Task B — AZ-B
```

But there is still a serious production problem.

At 02:00:

```text
Traffic = 50 requests/sec

2 tasks
=
fine
```

At 10:00:

```text
Traffic = 2,000 requests/sec

2 tasks
=
🔥
```

At midnight:

```text
Traffic = 5 requests/sec

20 tasks
=
💸
```

We therefore need:

# ECS Service Auto Scaling

```text
                     USERS
                       │
                       ▼
                      ALB
                       │
                       ▼
                  ECS Service
                 desiredCount=2
                       │
               load increases
                       │
                       ▼
                   CloudWatch
                       │
                       ▼
             Application Auto Scaling
                       │
                       ▼
                 desiredCount=8
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
     Task            Task            Task
      ...             ...             ...
```

Amazon ECS Service Auto Scaling uses **Application Auto Scaling** to automatically change an ECS service's desired task count. Current ECS supports target tracking, step scaling, scheduled scaling, and predictive scaling. ([AWS Documentation][1])

---

# Part A — The Two Different Scaling Layers

This distinction is critical.

## 1. ECS Service Scaling

Changes:

```text
NUMBER OF TASKS
```

Example:

```text
2 tasks
   │
   ▼
8 tasks
```

That's:

```text
ECS Service Auto Scaling
```

Application Auto Scaling modifies the service's desired count between configured minimum and maximum task counts. ([AWS Documentation][1])

---

# 2. Infrastructure / Capacity Scaling

If using ECS on EC2, tasks also need hosts.

```text
ECS Service
desiredCount:
4 → 20
       │
       ▼
Need compute capacity
       │
       ▼
EC2 Auto Scaling Group
3 instances → 10 instances
```

That is a different layer:

```text
TASK SCALING
≠
HOST SCALING
```

With EC2 capacity providers, ECS cluster auto scaling can manage the underlying Auto Scaling group. With Fargate, AWS manages the underlying compute capacity for the requested tasks. ([AWS Documentation][2])

### Never forget

```text
Service Auto Scaling
=
How many containers/tasks?


Capacity Provider / Cluster Auto Scaling
=
Where do those tasks get compute?
```

---

# 3. Fargate Makes This Simpler

With Fargate:

```text
Application Auto Scaling
       │
       ▼
desiredCount
2 → 20
       │
       ▼
ECS schedules 20 tasks
       │
       ▼
AWS provides underlying capacity
```

You don't separately maintain an EC2 Auto Scaling group for those Fargate tasks. ([AWS Documentation][3])

That is one reason Fargate is operationally attractive.

---

# Part B — The Four ECS Service Scaling Modes

Current ECS supports:

```text
ECS Service Auto Scaling
│
├── Target Tracking
│
├── Step Scaling
│
├── Scheduled Scaling
│
└── Predictive Scaling
```

([AWS Documentation][1])

Mental model:

```text
Target Tracking
=
"Keep CPU around 50%"


Step Scaling
=
"If metric is THIS bad,
add THIS many tasks"


Scheduled Scaling
=
"At 8:45 AM,
prepare more capacity"


Predictive Scaling
=
"Learn recurring demand
and scale before it arrives"
```

---

# Part C — Target Tracking

## 4. The Thermostat Model

Target tracking is the easiest model to understand.

Suppose:

```text
CPU target
=
50%
```

Auto Scaling tries to keep:

```text
average ECS service CPU
≈
50%
```

If:

```text
CPU = 85%
```

it scales out.

If:

```text
CPU = 20%
```

for sufficiently stable periods:

```text
scale in
```

ECS automatically creates and manages the CloudWatch alarms for a target-tracking policy. ([AWS Documentation][4])

---

# 5. Conceptual Calculation

Suppose:

```text
Running tasks:
4

CPU observed:
80%

CPU target:
50%
```

Conceptually:

```text
required capacity
≈
4 × 80 / 50

≈
6.4
```

so a reasonable scaling outcome might be around:

```text
7 tasks
```

Don't treat that equation as an exact guaranteed implementation formula—Application Auto Scaling deliberately rounds conservatively so that it doesn't add too little capacity or remove too much. ([AWS Documentation][4])

---

# 6. Predefined ECS Target-Tracking Metrics

The common service metrics include:

```text
ECSServiceAverageCPUUtilization

ECSServiceAverageMemoryUtilization

ALBRequestCountPerTarget
```

and ECS now also supports high-resolution CPU and memory variants for faster target tracking. ([AWS Documentation][5])

Which metric you choose should reflect:

```text
WHAT ACTUALLY LIMITS YOUR APPLICATION?
```

---

# Part D — CPU Scaling

## 7. Good CPU Candidate

Suppose your Node.js API:

```text
more requests
    │
    ▼
more application work
    │
    ▼
CPU increases
```

Then CPU is:

```text
correlated with demand
```

which makes it a good scaling metric.

AWS recommends selecting a utilization/saturation metric that changes predictably with workload and validating this relationship through load testing. ([AWS Documentation][6])

---

# 8. Example

```text
min tasks = 2
max tasks = 20

target CPU = 50%
```

At normal traffic:

```text
Task A 47%
Task B 52%

average ~50%
```

No scaling.

Traffic increases:

```text
Task A 86%
Task B 82%

average ~84%
```

Auto Scaling increases desired count.

New tasks lower average load:

```text
Task A 48%
Task B 51%
Task C 46%
Task D 49%
```

System approaches equilibrium.

---

# Part E — Memory Scaling

## 9. Memory Can Be Better Than CPU

Suppose your service does:

```text
PDF processing

large JSON transformations

in-memory caching

ML inference

image manipulation
```

CPU might stay:

```text
35%
```

while memory becomes:

```text
92%
```

Then CPU-based scaling might do nothing before tasks OOM.

Memory utilization can be a valid horizontal-scaling signal when adding replicas spreads memory demand across more tasks. ([AWS Documentation][6])

---

# 10. Multiple Target-Tracking Policies

A strong service may have:

```text
CPU target = 50%

Memory target = 70%
```

Important current behavior:

```text
SCALE OUT:
if ANY target-tracking policy
requests scale-out


SCALE IN:
only when ALL applicable
target-tracking policies
agree scale-in is safe
```

([AWS Documentation][4])

This reflects the AWS principle:

```text
availability first.
```

---

# 11. Example

CPU:

```text
40%
```

Memory:

```text
90%
```

CPU policy says:

```text
no scale out
```

Memory policy says:

```text
scale out
```

Final result:

```text
SCALE OUT
```

Now reverse it:

CPU:

```text
15%
```

Memory:

```text
85%
```

CPU may want:

```text
scale in
```

Memory says:

```text
NO
```

Final:

```text
don't scale in.
```

([AWS Documentation][4])

---

# Part F — ALB Request Count Scaling

## 12. Sometimes Request Volume Is Better

For a stateless HTTP service:

```text
ALB
 │
 ├── 500 requests
 ├── 500 requests
 ├── 500 requests
 └── ...
```

you may know through load testing:

```text
one task can safely handle
~500 requests/minute
```

Then:

```text
ALBRequestCountPerTarget
```

may be more meaningful than CPU.

AWS supports `ALBRequestCountPerTarget` as a predefined ECS target-tracking metric. ([AWS Documentation][7])

---

# 13. Example

Suppose:

```text
target:
700 requests per target
```

Current:

```text
2 targets

traffic:
2,800 requests
```

Average:

```text
1,400 / target
```

That's approximately twice your desired target.

Conceptually:

```text
2 tasks
→ ~4 tasks
```

may be appropriate.

---

# 14. Important 2026 Trap

Current AWS documentation says:

```text
ALBRequestCountPerTarget
```

is **not supported for target tracking when using the blue/green deployment type**. ([AWS Documentation][4])

So do not blindly copy:

```text
ALB request scaling
```

from a rolling-service tutorial into every modern ECS blue/green design.

---

# Part G — High-Resolution ECS Auto Scaling

This is a major newer capability older AWS courses won't contain.

## 15. Default ECS Service Metric Resolution

By default, ECS service:

```text
CPUUtilization

MemoryUtilization
```

are published for scaling at:

```text
60-second resolution.
```

ECS can now publish them at:

```text
20-second resolution
```

for faster service auto scaling. ([AWS Documentation][5])

---

# 16. High-Resolution Metric Names

Current predefined target-tracking metrics include:

```text
ECSServiceAverageCPUUtilizationHighResolution

ECSServiceAverageMemoryUtilizationHighResolution
```

([AWS Documentation][5])

So the difference is:

```text
Traditional:
60 sec


High resolution:
20 sec
```

---

# 17. When High Resolution Helps

Imagine a flash-sale API.

Traffic goes:

```text
10 req/sec
     │
     │ in 5 sec
     ▼
5,000 req/sec
```

Waiting for a full minute of metric data may be expensive from a latency perspective.

High-resolution metrics can detect CPU or memory utilization changes sooner and therefore drive faster target-tracking decisions. ([AWS Documentation][8])

---

# 18. CLI — Enable 20-Second Metrics

For your Mumbai service:

```bash
aws ecs update-service \
  --region ap-south-1 \
  --cluster todo-production \
  --service todo-api \
  --monitoring \
  "metricConfigurations=[{metricNames=[CPUUtilization,MemoryUtilization],resolutionSeconds=20}]"
```

Changing an existing service to 20-second monitoring creates a new service revision and triggers a deployment; the high-resolution scaling policy should be configured after the deployment completes and tasks are publishing the new metrics. ([AWS Documentation][5])

---

# 19. Register Scalable Target

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 20 \
  --region ap-south-1
```

This establishes:

```text
minimum:
2 tasks


maximum:
20 tasks
```

for service auto scaling. ([AWS Documentation][5])

---

# 20. High-Resolution CPU Policy

```bash
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name todo-highres-cpu \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 50.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType":
        "ECSServiceAverageCPUUtilizationHighResolution"
    },
    "ScaleOutCooldown": 30,
    "ScaleInCooldown": 180
  }' \
  --region ap-south-1
```

AWS documents this same high-resolution scaling flow using a 20-second ECS service metric and a corresponding high-resolution predefined metric. ([AWS Documentation][5])

---

# Part H — Cooldowns

## 21. Why Cooldowns Exist

Imagine CPU jumps:

```text
80%
```

Auto Scaling adds four tasks.

But those tasks require:

```text
30 seconds
```

to become useful.

Without cooldown logic:

```text
CPU still 80%
   │
   ▼
scale again

CPU still 80%
   │
   ▼
scale again

...
```

You may wildly over-scale before the new capacity has any chance to affect the metric.

---

# 22. Scale-Out Cooldown

After successful scale-out, Application Auto Scaling considers the new capacity while allowing time for it to take effect; another larger required scale-out can still override that cooldown. ([AWS Documentation][1])

Mental model:

```text
scale out
   │
   ▼
new tasks start
   │
   ▼
give them time
   │
   ▼
measure again
```

---

# 23. Scale-In Cooldown

AWS intentionally handles scale-in more conservatively.

During scale-in cooldown:

```text
another scale-in
=
blocked
```

but:

```text
urgent scale-out
=
allowed immediately.
```

([AWS Documentation][1])

That's exactly what you want:

```text
remove capacity slowly

add capacity quickly.
```

---

# 24. Practical Starting Point

For a Node API you might start load testing with values such as:

```text
ScaleOutCooldown = 30–60 sec

ScaleInCooldown = 180–300 sec
```

Those are design starting points rather than universal AWS defaults.

Choose based on:

```text
task startup time

traffic volatility

connection duration

downstream capacity

cost sensitivity
```

---

# Part I — Scale to Zero

## 25. Can ECS Service Scale to Zero?

Yes.

Configure:

```text
min capacity = 0
```

Current target-tracking behavior has an important caveat: when running capacity is zero, Service Auto Scaling waits for workload metric data before adding the first task and initially scales out by the minimum possible amount before normal target tracking resumes. ([AWS Documentation][1])

---

# 26. Why Scale-to-Zero Can Be Dangerous for APIs

For:

```text
public synchronous HTTP API
```

if:

```text
task count = 0
```

then:

```text
first customer request
```

may arrive before any application capacity exists.

That's usually a poor experience.

For customer-facing APIs:

```text
min = 2
```

is a much stronger HA starting point.

Scale-to-zero fits better for:

```text
event-driven workers

occasional background processing

development environments
```

when some cold-start delay is acceptable.

---

# Part J — SQS Backlog Scaling

This is one of the most useful production scaling patterns.

Suppose:

```text
SQS
 │
 ▼
ECS Worker Service
```

CPU is often a bad signal.

Why?

One worker may be:

```text
waiting on network
```

and use only:

```text
15% CPU
```

while:

```text
500,000 messages
```

sit in the queue.

---

# 27. Better Metric

Use:

# Backlog Per Task

```text
ApproximateNumberOfMessagesVisible
──────────────────────────────────
RunningTaskCount
```

AWS documents this exact metric-math pattern for ECS service auto scaling. ([AWS Documentation][9])

---

# 28. Example

Queue:

```text
10,000 messages
```

Running workers:

```text
10
```

Backlog per task:

```text
10,000 / 10
=
1,000
```

Suppose each worker can process:

```text
10 messages/sec
```

and your target queue-drain latency is:

```text
20 sec
```

Then acceptable backlog per task is roughly:

```text
10 × 20
=
200 messages/task
```

If current value is:

```text
1,000
```

you need considerably more worker capacity.

---

# 29. Better Scaling Question

Don't ask:

```text
How many messages are there?
```

Ask:

```text
How much work
does each running task
need to clear?
```

That is why:

```text
backlog / task
```

is much better than queue length alone.

---

# Part K — Step Scaling

Target tracking says:

```text
maintain metric near X.
```

Step scaling says:

```text
if threshold is mildly bad
add 2

if badly bad
add 5

if catastrophically bad
add 20.
```

ECS step scaling uses CloudWatch alarms and different scaling adjustments depending on how far the metric breaches its threshold. ([AWS Documentation][10])

---

# 30. Example

Queue backlog:

```text
0–1,000
→ no action


1,000–10,000
→ +5 tasks


10,000–50,000
→ +20 tasks


> 50,000
→ +50 tasks
```

This can be much more aggressive than target tracking.

---

# 31. Target Tracking vs Step Scaling

Use:

```text
Target Tracking
```

when:

```text
metric scales smoothly
with capacity

CPU

memory

requests/target

backlog-per-task
```

Use:

```text
Step Scaling
```

when you need explicit operational behavior:

```text
queue > 50k
→ immediately add 50 workers.
```

AWS specifically notes that step scaling can react rapidly because you explicitly control breach thresholds and adjustments. ([AWS Documentation][1])

---

# Part L — Scheduled Scaling

Suppose traffic is extremely predictable.

Every weekday:

```text
08:55
users begin arriving

09:00
traffic spikes
```

Reactive scaling means:

```text
09:00 traffic arrives

09:01 metric alarm

09:02 new tasks start

09:03 tasks healthy
```

Customers paid for your delay.

Instead:

```text
08:50
min capacity → 10
```

Scheduled scaling can proactively change an ECS service's minimum/maximum capacity at known dates/times, and it can be combined with dynamic policies afterward. ([AWS Documentation][11])

---

# 32. Architecture

```text
08:45
   │
   ▼
Scheduled Scaling
   │
   ▼
min tasks = 10
   │
   ▼
08:50
tasks already ready
   │
   ▼
09:00
traffic arrives
```

Then target tracking can still react:

```text
traffic larger than expected?
        │
        ▼
10 → 15 → 20
```

Scheduled and reactive scaling complement each other. ([AWS Documentation][11])

---

# Part M — Predictive Scaling

Predictive scaling is now directly relevant to ECS.

## 33. Mental Model

Instead of:

```text
load arrives
   │
   ▼
metric rises
   │
   ▼
scale
```

predictive scaling does:

```text
historical pattern
       │
       ▼
forecast demand
       │
       ▼
scale before demand
```

AWS positions it for services with recurring traffic patterns, especially where tasks take meaningful time to become ready. ([AWS Documentation][3])

---

# 34. Example

Historical pattern:

```text
Mon–Fri

08:00 low

09:00 rapid increase

12:00 peak

18:00 decline
```

Predictive scaling learns this and can prepare capacity ahead of the expected demand. ([AWS Documentation][3])

---

# 35. Current Data Requirements

Predictive scaling currently needs at least:

```text
24 hours
```

of historical data before generating forecasts; AWS says more data improves forecasting, with roughly two weeks being ideal. ([AWS Documentation][3])

AWS currently analyzes up to:

```text
14 days
```

of historical data and generates hourly requirements forecasts for the next:

```text
48 hours
```

with forecasts refreshed periodically. ([AWS Documentation][3])

---

# 36. Forecast-Only First

Predictive scaling initially supports:

```text
forecast-only
```

evaluation so you can see:

```text
what AWS WOULD have done
```

before you allow it to change production capacity. ([AWS Documentation][3])

That is the production-safe approach.

---

# 37. Predictive + Reactive

Recommended mental architecture:

```text
Predictive Scaling
       │
       ▼
prepare expected baseline
       │
       ▼
Target Tracking
       │
       ▼
handle unexpected demand
```

AWS supports predictive scaling alongside dynamic policies; when multiple policies produce capacity recommendations, the service uses the larger required task count. Predictive scaling itself does not scale the service in. ([AWS Documentation][3])

---

# Part N — Auto Scaling During Deployments

This catches many engineers.

During an ECS deployment, Application Auto Scaling automatically suspends:

```text
dynamic scale-in
```

while:

```text
scale-out
```

can continue unless explicitly suspended. ([AWS Documentation][1])

Why?

Imagine deploying:

```text
v18
```

while demand is increasing.

You don't want:

```text
deployment temporarily changes metrics
        │
        ▼
auto scaler aggressively removes tasks
```

during a sensitive rollout.

---

# Part O — Capacity Providers Revisited

Now connect service scaling to cost.

A Fargate service can use:

```text
FARGATE

FARGATE_SPOT
```

through a capacity-provider strategy. ([AWS Documentation][12])

Architecture:

```text
ECS Service
desired = 10
     │
     ▼
Capacity Provider Strategy
     │
 ┌───┴─────────────┐
 ▼                 ▼
FARGATE       FARGATE_SPOT
```

---

# 38. `base`

Example:

```text
FARGATE
base = 2
```

means the first:

```text
2 tasks
```

must run on Fargate before weighted distribution applies.

Only **one** capacity provider in a strategy can define a base value. ([AWS Documentation][13])

---

# 39. `weight`

Then suppose:

```text
FARGATE
weight = 1


FARGATE_SPOT
weight = 3
```

After the base requirement is satisfied, ECS uses the weights as relative placement proportions. ([AWS Documentation][13])

Conceptually:

```text
~25% On-Demand Fargate

~75% Fargate Spot
```

for the remaining tasks over sufficient task counts.

Don't expect exact percentages on tiny desired counts because placement involves integer tasks.

---

# 40. Example Production API Strategy

```text
desired = 10


FARGATE
base = 4
weight = 1


FARGATE_SPOT
weight = 2
```

Mental model:

```text
at least 4 stable
on-demand tasks

additional capacity
may lean toward Spot.
```

This can be a good approach when the application tolerates loss of some replicas.

---

# Part P — Fargate Spot

Fargate Spot runs interruption-tolerant tasks on spare capacity and AWS can reclaim that capacity with approximately a **two-minute warning**. ([AWS Documentation][13])

The task state-change event is also sent through EventBridge, including the stopped reason. ([AWS Documentation][12])

---

# 41. Good Fargate Spot Workload

```text
SQS worker
    │
    ▼
process idempotently
    │
    ▼
delete message only on success
```

Spot interruption:

```text
SIGTERM
   │
   ▼
stop taking new work
   │
   ▼
finish/checkpoint if possible
   │
   ▼
task exits
```

If unfinished queue work safely reappears later:

```text
new worker retries it.
```

Perfect fit.

---

# 42. Poor Spot Workload

Avoid placing your only:

```text
payment processor replica

WebSocket gateway

stateful session host

non-checkpointable 3-hour job
```

entirely on Fargate Spot unless your architecture explicitly tolerates interruption.

---

# Part Q — Task Scale-In Protection

Consider an SQS worker.

Service:

```text
desiredCount = 20
```

Auto Scaling decides:

```text
20 → 10
```

But Task #7 is halfway through a:

```text
20-minute report generation job.
```

You don't want the scaler terminating it.

Use:

# ECS Task Scale-In Protection

---

# 43. Architecture

```text
Task receives work
      │
      ▼
ProtectionEnabled=true
      │
      ▼
process job
      │
      ▼
job complete
      │
      ▼
ProtectionEnabled=false
```

ECS will avoid terminating a protected service task during scale-in. AWS specifically recommends the task-agent endpoint for queue/job-processing workloads that know when they are actively working. ([AWS Documentation][14])

---

# 44. From Inside the Task

The task can call:

```bash
curl \
  --request PUT \
  --header 'Content-Type: application/json' \
  "${ECS_AGENT_URI}/task-protection/v1/state" \
  --data '{
    "ProtectionEnabled": true,
    "ExpiresInMinutes": 60
  }'
```

Current protection defaults to two hours if an expiration isn't specified, and custom protection can range from 1 minute to 2,880 minutes (48 hours). ([AWS Documentation][14])

---

# 45. Clear It When Finished

```bash
curl \
  --request PUT \
  --header 'Content-Type: application/json' \
  "${ECS_AGENT_URI}/task-protection/v1/state" \
  --data '{
    "ProtectionEnabled": false
  }'
```

If you never clear task protection:

```text
idle task
remains protected
        │
        ▼
scale-in delayed
        │
        ▼
cost increases.
```

AWS explicitly warns against protection windows longer than necessary. ([AWS Documentation][14])

---

# Part R — ECS Monitoring Layers

A mature ECS monitoring model has:

```text
Layer 1
ECS service metrics


Layer 2
ALB metrics


Layer 3
Container Insights


Layer 4
Application metrics


Layer 5
Logs


Layer 6
Distributed traces
```

No single layer tells the whole story.

---

# 46. Basic ECS Metrics

ECS automatically provides service-level metrics including:

```text
CPU utilization

memory utilization

running task count
```

with standard ECS/CloudWatch monitoring behavior. Fargate services automatically expose CPU and memory utilization metrics. ([AWS Documentation][15])

Useful questions:

```text
How loaded is the service?

How many tasks are running?

Is utilization rising?
```

---

# Part S — Container Insights with Enhanced Observability

This is the modern monitoring option you should know.

AWS now recommends:

# Container Insights with enhanced observability

over basic Container Insights for ECS because it adds deeper visibility down to individual tasks and containers. ([AWS Documentation][16])

---

# 47. What It Gives You

Enhanced observability provides more granular:

```text
cluster metrics

service metrics

task metrics

container metrics
```

and lets you troubleshoot resource usage and container behavior in much more detail. ([AWS Documentation][17])

Examples include:

```text
ContainerCpuUtilization

ContainerMemoryUtilized

ContainerMemoryReserved

task-level utilization

container restart information
```

with additional metrics depending on compute type. ([AWS Documentation][17])

---

# 48. Why Average Service CPU Can Hide Problems

Suppose:

```text
Task A CPU = 10%

Task B CPU = 12%

Task C CPU = 99%

Task D CPU = 11%
```

Average:

```text
33%
```

Service dashboard might look:

```text
fine.
```

But:

```text
Task C
```

may have a hot partition or specific customer workload.

Container/task-level visibility helps expose these outliers. ([AWS Documentation][17])

---

# 49. Enable Enhanced Observability

For new clusters account-wide:

```bash
aws ecs put-account-setting \
  --name containerInsights \
  --value enhanced \
  --principal-arn \
  arn:aws:iam::<ACCOUNT_ID>:root
```

For an existing cluster:

```bash
aws ecs update-cluster-settings \
  --cluster todo-production \
  --settings \
  name=containerInsights,value=enhanced
```

AWS documents `containerInsights=enhanced` as the current ECS account/cluster setting. ([AWS Documentation][16])

---

# 50. Fargate Ephemeral Storage Monitoring

For supported modern Fargate Linux tasks, enhanced Container Insights exposes:

```text
EphemeralStorageReserved

EphemeralStorageUtilized
```

which is useful if workloads create:

```text
temporary archives

images

large logs

ML model files

downloads
```

and risk exhausting task storage. ([AWS Documentation][17])

---

# Part T — Logging: `awslogs` vs FireLens

## 51. Simple Logging

For ordinary apps:

```text
Container
   │
 stdout / stderr
   │
   ▼
awslogs driver
   │
   ▼
CloudWatch Logs
```

The ECS `awslogs` driver forwards container stdout/stderr to CloudWatch Logs. ([AWS Documentation][18])

This is excellent when:

```text
CloudWatch is your only log destination.
```

---

# 52. When FireLens Is Better

Suppose you need:

```text
Container logs
      │
      ├── CloudWatch
      ├── OpenSearch
      ├── Firehose → S3
      └── external observability vendor
```

Use:

# FireLens

FireLens allows ECS task definitions to route logs through Fluent Bit or Fluentd to AWS or supported partner destinations. ([AWS Documentation][19])

---

# 53. FireLens Architecture

```text
┌──────────────────────────────┐
│ ECS Task                     │
│                              │
│  Application                 │
│      │                       │
│      ▼                       │
│  awsfirelens                 │
│      │                       │
│      ▼                       │
│ Fluent Bit log-router        │
│      │                       │
└──────┼───────────────────────┘
       │
       ├── CloudWatch
       ├── Firehose
       ├── OpenSearch
       └── external destination
```

ECS automatically arranges FireLens container startup ordering so the log router starts before containers using it. ([AWS Documentation][19])

---

# 54. Fluent Bit vs Fluentd

AWS currently recommends:

```text
Fluent Bit
```

as the FireLens log router because it generally consumes fewer resources than Fluentd. ([AWS Documentation][20])

Current AWS for Fluent Bit images are available for both:

```text
ARM64

x86-64
```

on Linux. ([AWS Documentation][20])

---

# 55. FireLens Task Definition Concept

```json
{
  "name": "log-router",
  "image":
    "public.ecr.aws/aws-observability/aws-for-fluent-bit:3",

  "essential": true,

  "firelensConfiguration": {
    "type": "fluentbit"
  }
}
```

Application:

```json
{
  "name": "todo-api",

  "logConfiguration": {
    "logDriver": "awsfirelens",

    "options": {
      "Name": "cloudwatch",
      "region": "ap-south-1",
      "log_group_name": "/ecs/todo-api"
    }
  }
}
```

FireLens supports this task-definition-based routing model. ([AWS Documentation][19])

---

# Part U — Logging Reliability

A production log pipeline should ask:

```text
What happens when
log destination is slow?
```

You don't want:

```text
logging failure
       │
       ▼
application outage.
```

For very high log-throughput workloads, AWS has specific FireLens/Fluent Bit buffering guidance to prevent instability or log loss under pressure. ([AWS Documentation][21])

This is why logs themselves need:

```text
capacity planning.
```

---

# Part V — Cost Optimization

Autoscaling is only part of ECS cost optimization.

Think in five dimensions:

```text
1. Task count

2. Task CPU/memory size

3. Fargate vs Spot

4. Architecture

5. CPU architecture
```

---

# 56. Rightsize Tasks First

Suppose task definition:

```text
2 vCPU
8 GB memory
```

but Container Insights repeatedly shows:

```text
CPU:
10–20%

Memory:
800 MB
```

Scaling from:

```text
2 → 10 tasks
```

may not be your primary problem.

You're already over-provisioning each task.

A better design might be:

```text
0.5–1 vCPU

1–2 GB
```

after load testing.

Enhanced Container Insights specifically helps compare actual utilization with reserved resources for rightsizing decisions. ([AWS Documentation][17])

---

# 57. Horizontal vs Vertical Scaling

Horizontal:

```text
2 tasks
→
8 tasks
```

Vertical:

```text
0.5 vCPU
→
1 vCPU
```

A healthy design uses load testing to determine whether the application scales well by adding replicas, increasing task resources, or both. AWS's ECS scaling guidance explicitly discusses both horizontal and vertical scaling dimensions. ([AWS Documentation][6])

---

# Part W — ARM64 / Graviton

ECS supports ARM64 workloads on both:

```text
Fargate

EC2
```

for Linux workloads. For Fargate ARM64, current AWS documentation requires platform version 1.4.0 or later. ([AWS Documentation][22])

Task definition concept:

```json
{
  "runtimePlatform": {
    "cpuArchitecture": "ARM64",
    "operatingSystemFamily": "LINUX"
  }
}
```

---

# 58. Container Images Must Support ARM

If your Docker image is:

```text
amd64 only
```

you cannot simply switch:

```text
cpuArchitecture=ARM64
```

and expect it to run.

Build either:

```text
ARM64 image
```

or preferably:

```text
multi-architecture image.
```

Example Docker Buildx concept:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "$ECR_REPO:$IMAGE_TAG" \
  --push .
```

ECS supports ARM64 container workloads, but your application dependencies and image layers must also be compatible with that architecture. ([AWS Documentation][22])

---

# Part X — Terraform Auto Scaling

The HashiCorp AWS provider exposes:

```text
aws_appautoscaling_target

aws_appautoscaling_policy
```

for Application Auto Scaling resources. ([Terraform Registry][23])

---

# 59. Scalable Target

```hcl
resource "aws_appautoscaling_target" "ecs" {
  max_capacity = 20
  min_capacity = 2

  resource_id =
    "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"

  scalable_dimension =
    "ecs:service:DesiredCount"

  service_namespace = "ecs"
}
```

This establishes:

```text
2 ≤ desiredCount ≤ 20
```

---

# 60. CPU Target Tracking

```hcl
resource "aws_appautoscaling_policy" "cpu" {
  name = "todo-api-cpu"

  policy_type = "TargetTrackingScaling"

  resource_id =
    aws_appautoscaling_target.ecs.resource_id

  scalable_dimension =
    aws_appautoscaling_target.ecs.scalable_dimension

  service_namespace =
    aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 50

    scale_out_cooldown = 30
    scale_in_cooldown  = 180

    predefined_metric_specification {
      predefined_metric_type =
        "ECSServiceAverageCPUUtilization"
    }
  }
}
```

Target tracking lets Application Auto Scaling create/manage the corresponding CloudWatch alarms rather than requiring you to manually maintain those alarms. ([AWS Documentation][4])

---

# 61. Memory Target Tracking

```hcl
resource "aws_appautoscaling_policy" "memory" {
  name = "todo-api-memory"

  policy_type = "TargetTrackingScaling"

  resource_id =
    aws_appautoscaling_target.ecs.resource_id

  scalable_dimension =
    aws_appautoscaling_target.ecs.scalable_dimension

  service_namespace =
    aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70

    scale_out_cooldown = 30
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type =
        "ECSServiceAverageMemoryUtilization"
    }
  }
}
```

With both CPU and memory target tracking, any policy can trigger scale-out while scale-in remains conservative across the policies. ([AWS Documentation][4])

---

# Part Y — Terraform Fargate + Spot

Do not use:

```hcl
launch_type = "FARGATE"
```

when you're intentionally using a capacity-provider strategy.

Instead:

```hcl
resource "aws_ecs_service" "workers" {
  name    = "todo-worker"
  cluster = aws_ecs_cluster.main.id

  task_definition =
    aws_ecs_task_definition.worker.arn

  desired_count = 6

  capacity_provider_strategy {
    capacity_provider = "FARGATE"

    base   = 2
    weight = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"

    weight = 3
  }

  network_configuration {
    subnets = var.private_subnet_ids

    security_groups = [
      aws_security_group.worker.id
    ]

    assign_public_ip = false
  }
}
```

Fargate capacity-provider strategies support `FARGATE` and `FARGATE_SPOT`; `base` is applied first and weights determine the relative placement of the remaining tasks. ([AWS Documentation][12])

---

# Part Z — Terraform Container Insights

For the cluster:

```hcl
resource "aws_ecs_cluster" "main" {
  name = "todo-production"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}
```

The current ECS setting value for enhanced Container Insights is:

```text
enhanced
```

and AWS recommends the enhanced mode for deeper task/container visibility. ([AWS Documentation][16])

---

# Part AA — Production Scaling Lab

Let's turn your Node API into an auto-scaled service.

Architecture:

```text
                           k6 / Load Test
                                 │
                                 ▼
                                ALB
                                 │
                                 ▼
                           ECS Service
                          min=2 max=10
                                 │
                        CPU target=50%
                                 │
                   ┌─────────────┼─────────────┐
                   ▼             ▼             ▼
                 Task          Task          Task
```

---

# 62. Confirm Current Service

```bash
aws ecs describe-services \
  --cluster todo-production \
  --services todo-api \
  --region ap-south-1 \
  --query 'services[0].{
    desired:desiredCount,
    running:runningCount,
    pending:pendingCount
  }'
```

Expected before test:

```text
desired = 2
running = 2
```

---

# 63. Register Scalable Target

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10 \
  --region ap-south-1
```

([AWS Documentation][5])

---

# 64. Create CPU Target Policy

```bash
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name todo-cpu-target \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 50,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType":
        "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 30,
    "ScaleInCooldown": 180
  }' \
  --region ap-south-1
```

ECS target tracking then manages scaling alarms and task-count adjustments around the configured target. ([AWS Documentation][4])

---

# 65. Verify Scaling Configuration

```bash
aws application-autoscaling \
  describe-scalable-targets \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --region ap-south-1
```

Then:

```bash
aws application-autoscaling \
  describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --region ap-south-1
```

---

# 66. Generate Load

Example with `hey`:

```bash
hey \
  -z 10m \
  -c 100 \
  https://api.yourdatascientist.tech/get-todo
```

or use:

```text
k6
JMeter
Locust
```

The important goal is not to generate maximum random traffic.

It is to observe:

```text
load
   │
   ▼
CPU/request metric
   │
   ▼
scaling policy
   │
   ▼
desired count
   │
   ▼
running count
   │
   ▼
latency improvement
```

AWS recommends load testing when choosing and validating ECS scaling metrics. ([AWS Documentation][6])

---

# 67. Watch Tasks

```bash
watch -n 5 '
aws ecs describe-services \
  --cluster todo-production \
  --services todo-api \
  --region ap-south-1 \
  --query "services[0].{
    desired:desiredCount,
    running:runningCount,
    pending:pendingCount
  }"
'
```

You should eventually observe something like:

```text
2
↓
3
↓
5
↓
7
```

depending on your metric behavior and limits.

---

# 68. Watch Scaling Activities

```bash
aws application-autoscaling \
  describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/todo-production/todo-api \
  --scalable-dimension ecs:service:DesiredCount \
  --region ap-south-1
```

Now you can correlate:

```text
CloudWatch metric rise
       │
       ▼
scaling decision
       │
       ▼
desired count change
       │
       ▼
task placement
       │
       ▼
ALB target healthy
```

---

# 69. Stop Load

When testing stops:

```text
metric drops
     │
     ▼
scale-in evaluation
     │
     ▼
cooldown / conservative scale-in
     │
     ▼
7 → 5 → 3 → 2
```

Scale-in is intentionally more conservative than scale-out. ([AWS Documentation][4])

---

# Part AB — Production Worker Architecture

Now combine everything:

```text
                        PRODUCERS

                            │
                            ▼
                           SQS
                            │
                ApproxMessagesVisible
                            │
                            ▼
                 CloudWatch Metric Math
                            │
            messages / running ECS tasks
                            │
                            ▼
                  Application Auto Scaling
                            │
                            ▼
                     Worker Service
                   min=0 max=100
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
     Fargate Worker    Spot Worker       Spot Worker
          │                 │                 │
          ▼                 ▼                 ▼
    Protect task       Protect task      Protect task
    while working      while working     while working
```

This is an excellent asynchronous compute architecture because AWS explicitly supports backlog-per-task target tracking, Fargate/Fargate Spot capacity strategies, and service-task scale-in protection. ([AWS Documentation][9])

---

# Part AC — Troubleshooting Auto Scaling

## 70. “CPU is 95%, but tasks don't scale”

Check:

```text
scalable target registered?

max capacity already reached?

target tracking policy attached?

correct cluster/service resource ID?

metric exists?

scaling suspended?

deployment state?

service already has pending tasks?
```

Target tracking does not scale from insufficient metric data, and minimum/maximum task-count limits bound its decisions. ([AWS Documentation][4])

---

# 71. “Desired count increased but running count didn't”

This is very different.

```text
Application Auto Scaling:
desired = 20
```

but:

```text
ECS:
running = 8
pending = 12
```

Auto scaler did its job.

Now investigate:

```text
Fargate capacity availability

subnet IP exhaustion

CPU/memory/task configuration

EC2 cluster capacity

placement constraints

image pull

quota

security/network initialization
```

ECS uses actual running task count as an important starting point in scaling calculations so unavailable placement capacity does not create runaway desired-count inflation. ([AWS Documentation][1])

---

# 72. “Service keeps bouncing 2 → 10 → 2 → 10”

Possible:

```text
bad scaling metric

scale-in too aggressive

startup too slow

cooldown too short

requests redistributed sharply

CPU bursts

task size too small
```

This is:

```text
FLAPPING
```

Target tracking deliberately attempts to reduce rapid task-count oscillation, but your target/cooldown/workload characteristics still matter. ([AWS Documentation][4])

---

# 73. “CPU only 20%, but latency is terrible”

CPU may simply be the wrong metric.

Possible bottleneck:

```text
database connection pool

external API

thread/event-loop saturation

network

disk

lock contention

request queue

memory pressure
```

AWS explicitly recommends finding a metric correlated with demand/saturation instead of assuming CPU is universally correct. ([AWS Documentation][6])

---

# 74. “SQS backlog grows while worker CPU is low”

Exactly why:

```text
backlog-per-task
```

is useful.

Use:

```text
ApproximateNumberOfMessagesVisible
/
RunningTaskCount
```

rather than relying only on CPU. ([AWS Documentation][9])

---

# 75. “Scale-in killed my long-running job”

Use:

```text
ECS task scale-in protection.
```

Protect the task when it starts active work, then remove protection when work completes. ([AWS Documentation][14])

---

# 76. “Protected tasks prevent deployment finishing”

Expected possibility.

For rolling deployments, old protected tasks cannot be stopped until protection is cleared or expires; AWS notes that deployment `maximumPercentage` may need enough room for replacement tasks while old tasks remain protected. ([AWS Documentation][14])

Never use task protection as:

```text
ProtectionEnabled=true forever.
```

---

# 77. “Fargate Spot tasks keep disappearing”

Check ECS task state-change events.

Spot capacity can be reclaimed and tasks receive approximately a two-minute interruption warning. ([AWS Documentation][12])

If your architecture cannot tolerate that:

```text
you chose the wrong capacity mix.
```

---

# 78. “Logs work locally but disappear under high traffic”

Check:

```text
FireLens buffer

Fluent Bit memory

destination throughput

network connectivity

IAM

application logging volume
```

High-throughput container logging requires appropriate FireLens/Fluent Bit buffering and resource tuning. ([AWS Documentation][21])

---

# 79. “I enabled Container Insights but can't see per-container details”

Verify:

```text
containerInsights = enhanced
```

rather than just:

```text
enabled.
```

AWS differentiates standard Container Insights from Container Insights **with enhanced observability**, which provides more detailed task/container dimensions and metrics. ([AWS Documentation][16])

---

# 80. “20-second scaling metrics aren't available”

For an existing service, you must first change the service monitoring configuration, allow the resulting deployment to complete, and wait until all tasks emit at 20-second resolution before selecting the high-resolution target-tracking metric. ([AWS Documentation][5])

Also note current high-resolution metric support has deployment-controller/load-balancer considerations documented by AWS. ([AWS Documentation][5])

---

# Part AD — Interview / Certification Scenarios

## Scenario 1

> ECS Fargate web API has high CPU during demand spikes. Need simple automatic scaling.

Answer:

```text
Application Auto Scaling
+
Target Tracking
+
ECSServiceAverageCPUUtilization
```

([AWS Documentation][4])

---

## Scenario 2

> Need ECS service CPU scaling to react faster than one-minute metrics.

Current answer:

```text
20-second ECS service monitoring
+
ECSServiceAverageCPUUtilizationHighResolution
```

([AWS Documentation][5])

This is a modern 2026 answer older training material may omit.

---

## Scenario 3

> One metric says scale out, another says scale in.

For multiple target-tracking policies:

```text
scale out wins
```

because ECS scales out if any policy requires it and scales in only when all applicable target-tracking policies agree. ([AWS Documentation][4])

---

## Scenario 4

> ECS worker processes SQS messages but CPU doesn't correlate with backlog.

Think:

```text
backlog per task
=
ApproximateNumberOfMessagesVisible
/
RunningTaskCount
```

([AWS Documentation][9])

---

## Scenario 5

> Traffic spikes every weekday at 9 AM.

Options:

```text
Scheduled Scaling
```

for explicitly known schedules, or:

```text
Predictive Scaling
```

when you want AWS to learn recurring historical traffic patterns. ([AWS Documentation][11])

---

## Scenario 6

> Service has only 12 hours of metrics; predictive scaling forecast absent.

Expected.

Predictive scaling currently requires at least:

```text
24 hours
```

of historical data to begin forecasting. ([AWS Documentation][3])

---

## Scenario 7

> Need cheap interruption-tolerant ECS workers.

Think:

```text
FARGATE_SPOT
```

through a Fargate capacity-provider strategy. ([AWS Documentation][13])

---

## Scenario 8

> Need some guaranteed stable capacity plus cheaper burst tasks.

Use:

```text
FARGATE
base=N

+
FARGATE_SPOT
weighted additional capacity
```

([AWS Documentation][13])

---

## Scenario 9

> Long-running SQS task must not be killed during scale-in.

Use:

```text
ECS Task Scale-In Protection
```

and clear protection after the job completes. ([AWS Documentation][14])

---

## Scenario 10

> Need task/container-level ECS CPU and memory troubleshooting.

Use:

```text
Container Insights
with enhanced observability
```

([AWS Documentation][17])

---

## Scenario 11

> Need ECS logs delivered to multiple backends.

Think:

```text
FireLens
+
Fluent Bit
```

([AWS Documentation][19])

---

## Scenario 12

> Need ARM64 containers on ECS Fargate.

Supported for Linux workloads with the current documented Fargate platform requirements; task images and dependencies must be ARM-compatible. ([AWS Documentation][22])

---

# Part AE — The Production Scaling Mental Model

Burn this picture into memory:

```text
                          USERS
                            │
                            ▼
                           ALB
                            │
                            ▼
                       ECS SERVICE
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
            running tasks          CloudWatch
                                      │
                        ┌─────────────┼─────────────┐
                        ▼             ▼             ▼
                       CPU          Memory      Requests
                        │             │             │
                        └─────────────┼─────────────┘
                                      ▼
                          Application Auto Scaling
                                      │
                         min=2     target     max=20
                                      │
                        ┌─────────────┼─────────────┐
                        ▼                           ▼
                    SCALE OUT                    SCALE IN
                        │                           │
                    aggressive                   cautious
                        │                           │
                        ▼                           ▼
                  desired + tasks             desired - tasks
                        │
                        ▼
                CAPACITY PROVIDER
                        │
                  ┌─────┴──────┐
                  ▼            ▼
              FARGATE      FARGATE_SPOT
                  │            │
                  └─────┬──────┘
                        ▼
                     TASKS


                  OBSERVABILITY
                  ─────────────

          Container Insights Enhanced
                    +
                 FireLens
                    +
             CloudWatch Logs
                    +
           application metrics
                    +
                  traces
```

---

# 81. 40 Rules to Burn Into Memory

```text
1. ECS Service Auto Scaling changes desired task count.

2. EC2 cluster auto scaling changes host capacity.

3. Don't confuse task scaling with infrastructure scaling.

4. Fargate removes the EC2-host scaling layer from you.

5. Target Tracking is the default scaling model to learn first.

6. Target Tracking behaves like a thermostat.

7. CPU scaling works only if CPU correlates with demand.

8. Memory may be the real saturation signal.

9. ALBRequestCountPerTarget can scale HTTP services.

10. ALB request target tracking has deployment-type limitations.

11. ECS now supports 20-second CPU/memory metrics.

12. High-resolution metrics enable faster scaling reactions.

13. Multiple target policies scale out if any wants scale-out.

14. They scale in only when all applicable policies agree.

15. Scale-out should be aggressive.

16. Scale-in should be conservative.

17. Cooldowns prevent unstable repeated scaling.

18. Scale-out can override scale-in cooldown.

19. ECS services can scale to zero.

20. Scale-to-zero is often wrong for synchronous public APIs.

21. Queue workers should often scale on backlog per task.

22. Backlog-per-task = queue backlog / running workers.

23. Step Scaling gives explicit threshold-based adjustments.

24. Scheduled Scaling handles known time-based demand.

25. Predictive Scaling learns recurring demand patterns.

26. Predictive Scaling currently needs at least 24h history.

27. Predictive and dynamic scaling can work together.

28. ECS suspends dynamic scale-in during deployments.

29. Capacity-provider base is satisfied before weights.

30. Only one capacity provider can define base.

31. FARGATE_SPOT is interruptible.

32. Spot currently provides about two minutes warning.

33. Spot workloads must be restart-safe.

34. Task Scale-In Protection protects active worker tasks.

35. Never leave task protection on indefinitely.

36. Use Container Insights with enhanced observability.

37. awslogs is excellent for simple CloudWatch-only logging.

38. FireLens is for flexible/multi-destination log routing.

39. Fluent Bit is AWS's preferred FireLens router.

40. Autoscaling without load testing is educated guessing.
```

---

# ✅ Lesson 35 Part 3 Complete

You now understand:

```text
✓ ECS Service Auto Scaling
✓ Application Auto Scaling

✓ task scaling vs host scaling
✓ Fargate underlying capacity
✓ EC2 cluster auto scaling

✓ target tracking
✓ thermostat model

✓ CPU-based scaling
✓ memory-based scaling
✓ ALB request scaling

✓ multiple target policies
✓ scale-out precedence
✓ conservative scale-in

✓ cooldowns
✓ scale-out cooldown
✓ scale-in cooldown

✓ scale-to-zero

✓ high-resolution ECS metrics
✓ 20-second CPU metrics
✓ 20-second memory metrics
✓ new high-resolution predefined metrics

✓ SQS backlog-per-task scaling
✓ CloudWatch metric math

✓ step scaling
✓ scheduled scaling
✓ predictive scaling
✓ forecast-only mode
✓ predictive + reactive architecture

✓ Fargate capacity providers
✓ FARGATE
✓ FARGATE_SPOT
✓ base
✓ weight

✓ Spot interruption
✓ EventBridge task events
✓ graceful termination

✓ ECS task scale-in protection
✓ agent task-protection endpoint

✓ Container Insights
✓ enhanced observability
✓ task/container metrics
✓ ephemeral-storage monitoring

✓ awslogs
✓ FireLens
✓ Fluent Bit
✓ log routing

✓ task rightsizing
✓ horizontal scaling
✓ vertical scaling

✓ ARM64
✓ Graviton-ready ECS designs
✓ multi-architecture images

✓ Terraform scalable targets
✓ Terraform target tracking
✓ Terraform Fargate + Spot

✓ production load test
✓ scaling validation
✓ troubleshooting
✓ certification scenarios
```

# Next — Lesson 35 Part 4

# **ECS Production Security, ECR Image Supply Chain, CI/CD & Complete Container Platform Capstone**

Next we'll connect the entire container lifecycle:

```text
Developer
    │
    ▼
Git
    │
    ▼
CI Pipeline
    │
    ├── unit tests
    ├── dependency scan
    ├── Docker build
    ├── image scan
    └── immutable tag
    │
    ▼
   ECR
    │
    ├── lifecycle policy
    ├── vulnerability scanning
    ├── image signing
    └── cross-account access
    │
    ▼
Task Definition Revision
    │
    ▼
ECS Deployment
    │
    ├── rolling / blue-green / canary
    ├── health validation
    ├── CloudWatch alarms
    └── automatic rollback
    │
    ▼
Production
```

We'll cover **ECR repositories, immutable image tags, digest pinning, lifecycle policies, vulnerability scanning, image signing/verification, cross-account ECR, private VPC endpoints, ECS secret management, task-role least privilege, runtime security, read-only root filesystems, Linux capabilities, non-root containers, deployment IAM, Jenkins/GitHub-style CI/CD patterns, database migrations, Terraform deployment separation, image promotion across environments, rollback by task-definition revision, observability gates, and a complete production-ready ECS capstone for the Todo application.**

[1]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html "Automatically scale your Amazon ECS service - Amazon Elastic Container Service"
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-auto-scaling.html?utm_source=chatgpt.com "Automatically manage Amazon ECS capacity with cluster ..."
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/predictive-auto-scaling.html "Use historical patterns to scale Amazon ECS services with predictive scaling - Amazon Elastic Container Service"
[4]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-autoscaling-targettracking.html "Use a target metric to scale Amazon ECS services - Amazon Elastic Container Service"
[5]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/target-tracking-faster-auto-scaling.html "Faster auto scaling with high-resolution metrics - Amazon Elastic Container Service"
[6]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/capacity-autoscaling-best-practice.html?utm_source=chatgpt.com "Optimizing Amazon ECS service auto scaling"
[7]: https://docs.aws.amazon.com/autoscaling/application/userguide/example_application-auto-scaling_PutScalingPolicy_section.html?utm_source=chatgpt.com "Use PutScalingPolicy with a CLI - Application Auto Scaling"
[8]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_utilization.html?utm_source=chatgpt.com "Amazon ECS service utilization metrics"
[9]: https://docs.aws.amazon.com/autoscaling/application/userguide/application-auto-scaling-target-tracking-metric-math.html "Create a target tracking scaling policy for Application Auto Scaling using metric math - Application Auto Scaling"
[10]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/step-scaling-create-policy.html?utm_source=chatgpt.com "Create a step scaling policy for Amazon ECS service auto ..."
[11]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-autoscaling-schedulescaling.html "Use scheduled actions to scale Amazon ECS services - Amazon Elastic Container Service"
[12]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-capacity-providers.html "Amazon ECS clusters for Fargate - Amazon Elastic Container Service"
[13]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_CapacityProviderStrategyItem.html "CapacityProviderStrategyItem - Amazon Elastic Container Service"
[14]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-scale-in-protection.html "Protect your Amazon ECS tasks from being terminated by scale-in events - Amazon Elastic Container Service"
[15]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html?utm_source=chatgpt.com "Monitor Amazon ECS using CloudWatch"
[16]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-ECS-cluster.html "Setting up Container Insights on Amazon ECS - Amazon CloudWatch"
[17]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-enhanced-observability-metrics-ECS.html "Amazon ECS Container Insights with enhanced observability metrics - Amazon CloudWatch"
[18]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html?utm_source=chatgpt.com "Send Amazon ECS logs to CloudWatch"
[19]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html "Send Amazon ECS logs to an AWS service or AWS Partner - Amazon Elastic Container Service"
[20]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/firelens-using-fluentbit.html "AWS for Fluent Bit image repositories for Amazon ECS - Amazon Elastic Container Service"
[21]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/firelens-docker-buffer-limit.html?utm_source=chatgpt.com "Configuring Amazon ECS logs for high throughput"
[22]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-arm64.html "Amazon ECS task definitions for 64-bit ARM workloads - Amazon Elastic Container Service"
[23]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy "Terraform Registry"
