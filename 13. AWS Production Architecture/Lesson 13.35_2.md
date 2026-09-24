# AWS Masterclass — Lesson 35 Part 2

# ECS + ALB Production Networking, Health Checks & Zero-Downtime Deployments

In Part 1 we built:

```text
Cluster
   │
   ▼
Service
   │
   ▼
Tasks
   │
   ▼
Containers
```

But those tasks are still not a production web application.

For a real customer-facing service we need:

```text
                     INTERNET
                         │
                         ▼
                     Route 53
                         │
                         ▼
                      HTTPS
                         │
                         ▼
                 Application LB
                 public subnets
                         │
                  Target Group
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
    ECS Task — AZ-A               ECS Task — AZ-B
     private subnet                private subnet
          │                             │
          └──────────────┬──────────────┘
                         ▼
                     Node.js API
```

This lesson answers the production-critical questions:

```text
How does an ALB know where tasks are?

What happens when task IPs change?

Why target_type = ip?

How do health checks work?

How does ECS replace containers without downtime?

What are minimumHealthyPercent
and maximumPercent?

What if the new release is broken?

How do we automatically roll back?

How does connection draining work?

How should Node.js handle SIGTERM?

Rolling vs blue/green vs linear vs canary?

How do services call each other internally?
```

---

# Part A — The Complete ECS + ALB Architecture

For a Fargate application, the clean production pattern is:

```text
                            Internet

                               │
                               ▼
                            Route 53
                               │
                               ▼
                     api.example.com
                               │
                               ▼
                        ALB HTTPS :443
                  Public Subnet A + B
                               │
                               │ HTTP :3002
                               ▼
                     ALB Target Group
                       target_type=ip
                               │
                ┌──────────────┴──────────────┐
                │                             │
                ▼                             ▼

          ENI: 10.0.10.25               ENI: 10.0.20.31
          ECS Task #1                    ECS Task #2
          Private AZ-A                   Private AZ-B

                │                             │
                ▼                             ▼
         Node.js :3002                 Node.js :3002
```

Tasks using `awsvpc` networking have their own ENIs and private IP addresses. For ECS services using `awsvpc`, the ALB target group must therefore use **`ip` target type**, not `instance`; this applies naturally to Fargate and also to EC2 tasks using `awsvpc`. ([AWS Documentation][1])

---

# 1. What Is Actually Registered in the Target Group?

With Fargate:

```text
NOT:

EC2 instance
+
host port


BUT:

Task ENI IP
+
container port
```

For example:

```text
Target Group

10.0.10.25 : 3002
10.0.20.31 : 3002
10.0.10.42 : 3002
```

When an ECS service creates and destroys tasks, ECS handles registration and deregistration with its configured load balancer. ([AWS Documentation][1])

---

# 2. Why `target_type = "ip"`?

Consider a Fargate task:

```text
Task
 │
 ▼
ENI
 │
 ▼
10.0.10.25
```

There is no EC2 instance from your perspective that the ALB should register.

So:

```hcl
target_type = "ip"
```

is correct.

This would be wrong for Fargate:

```hcl
target_type = "instance"
```

AWS explicitly requires `ip` targets for `awsvpc` services because the target is associated with a task ENI rather than an EC2 container instance. ([AWS Documentation][2])

---

# Part B — Security Group Chaining

This is one of the best AWS security patterns to memorize.

Suppose:

```text
ALB SG:
sg-alb

ECS Task SG:
sg-api
```

Configure:

```text
Internet
   │
   ▼

sg-alb
Inbound:
443 ← 0.0.0.0/0

   │
   ▼

ALB

   │
   ▼

sg-api
Inbound:
3002 ← sg-alb
```

Not:

```text
3002 ← 0.0.0.0/0
```

This means:

> Only resources using the ALB security group can reach the application's port.

For managed blue/green ALB deployments, AWS likewise requires the load balancer's security group to be able to reach the ECS task security group. ([AWS Documentation][3])

---

# 3. Why Private Tasks?

The ALB is the public entry point:

```text
Internet
   │
   ▼
Public ALB
```

while tasks can remain:

```text
Private IP only
```

in private subnets.

```text
Public Subnets
────────────────────
ALB


Private Subnets
────────────────────
ECS Tasks

RDS

Redis
```

With `awsvpc`, tasks act like first-class VPC network endpoints with their own security groups and VPC routing. ([AWS Documentation][2])

---

# Part C — Port Mapping

Suppose Node.js listens on:

```text
3002
```

inside the container.

Task definition:

```json
{
  "portMappings": [
    {
      "containerPort": 3002,
      "protocol": "tcp"
    }
  ]
}
```

Then ECS service load balancing says:

```text
containerName = todo-api
containerPort = 3002
```

and the ALB routes traffic to that port. The ECS service's load-balancer configuration must reference a `containerPort` actually present in the task definition. ([AWS Documentation][4])

---

# 4. Dynamic Port Mapping — Don't Mix the Models

Older ECS-on-EC2 tutorials often show:

```text
containerPort = 3000
hostPort      = 0
```

Then Docker selects an ephemeral host port:

```text
EC2 host

Task A:
3000 → 49153

Task B:
3000 → 49154

Task C:
3000 → 49155
```

The ALB registers:

```text
EC2-A:49153
EC2-A:49154
EC2-A:49155
```

This is particularly relevant to ECS-on-EC2 using `bridge` network mode. ALB dynamic host-port mapping allows multiple copies of the same service on one container instance. ([AWS Documentation][1])

With Fargate/`awsvpc`, the cleaner mental model is instead:

```text
Task A
10.0.10.20 :3002

Task B
10.0.10.21 :3002

Task C
10.0.20.19 :3002
```

because each task owns its own network interface/IP. ([AWS Documentation][2])

### Never confuse

```text
EC2 bridge mode
→ dynamic HOST ports


awsvpc / Fargate
→ task IP + container port
```

---

# Part D — ALB Components

The flow is:

```text
ALB
 │
 ▼
Listener
 │
 ▼
Listener Rule
 │
 ▼
Target Group
 │
 ▼
ECS Tasks
```

Example:

```text
ALB
 │
 ├── :80
 │     └── redirect → HTTPS :443
 │
 └── :443
       │
       └── /*
            │
            ▼
       todo-api-target-group
```

ALBs are a strong fit for HTTP/HTTPS ECS workloads because they support layer-7 routing, path-based rules, multiple target groups and dynamic registration patterns. AWS recommends ALBs for ECS unless you specifically need a feature of NLB/GWLB. ([AWS Documentation][5])

---

# 5. One ALB Can Front Multiple ECS Services

For example:

```text
                           ALB
                            │
                ┌───────────┼──────────────┐
                ▼           ▼              ▼

        /api/*           /auth/*        /admin/*
            │               │              │
            ▼               ▼              ▼
       API Service     Auth Service     Admin Service
```

Or hostname-based:

```text
api.example.com
→ api ECS service


auth.example.com
→ auth ECS service
```

This is one reason ALB is often economically and operationally attractive for groups of HTTP microservices.

ALB supports path-based routing and multiple ECS target groups behind shared listeners. ([AWS Documentation][5])

---

# Part E — The Three Health Layers

This section is extremely important.

Your ECS application can have:

```text
1. Container health check

2. ECS service health

3. ALB target health
```

They answer different questions.

---

# 6. Container Health Check

Task definition:

```json
{
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "wget -q -O - http://localhost:3002/health || exit 1"
    ],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 30
  }
}
```

This happens:

```text
inside task/container
```

and answers:

```text
"Is my application process healthy?"
```

---

# 7. ALB Target Health Check

Target group:

```text
Protocol:
HTTP

Port:
traffic-port

Path:
/health
```

The ALB sends:

```http
GET /health
```

to every target.

For `instance` or `ip` targets, current ALB defaults include a 30-second interval, 5-second timeout, healthy threshold 5 and unhealthy threshold 2; the success-code default is HTTP `200`, although you can configure a broader matcher. ([AWS Documentation][6])

---

# 8. Design a Good `/health`

Bad:

```javascript
app.get("/health", async (req, res) => {
  await database.fullDeepQuery();
  await stripe.check();
  await redis.check();
  await emailProvider.check();
  await analytics.check();

  res.status(200).send("OK");
});
```

Why bad?

```text
Temporary email outage
        │
        ▼
health returns 500
        │
        ▼
ALB marks task unhealthy
        │
        ▼
ECS replaces application
        │
        ▼
new container starts
        │
        ▼
email still unavailable
        │
        ▼
repeat...
```

Your infrastructure just created a self-inflicted restart storm.

---

# 9. Liveness vs Readiness Mental Model

Think:

```text
LIVENESS

"Is this process fundamentally alive?"
```

and:

```text
READINESS

"Can this instance safely receive user traffic?"
```

For a simple Node API, a useful ALB health endpoint might verify:

```text
process alive
+
application initialized
+
critical dependency required to serve request
```

without making health depend on every optional external integration.

---

# 10. ALB Fail-Open Trap

An important ALB behavior: if every registered target in all enabled Availability Zones is unhealthy, ALB can **fail open** and route requests to the unhealthy targets rather than route nowhere. ([AWS Documentation][6])

So never assume:

```text
ALL TARGETS UNHEALTHY
=
ALB sends no traffic.
```

Operationally, the correct answer is:

```text
Fix why all tasks became unhealthy.
```

---

# Part F — Health Check Grace Period

Imagine your application needs:

```text
40 seconds
```

after container startup to:

```text
load configuration
initialize caches
connect database
warm application
start listening
```

But ALB begins health checks immediately.

Result:

```text
Task starts
   │
   ▼
not ready yet
   │
   ▼
health fails
   │
   ▼
ECS kills it
   │
   ▼
replacement
   │
   ▼
same thing
```

Use:

```text
healthCheckGracePeriodSeconds
```

---

# 11. Example

```hcl
health_check_grace_period_seconds = 60
```

This tells the ECS service scheduler:

> For 60 seconds after a task starts, don't use failing configured health checks as a reason to kill the task.

The ECS service grace period defaults to `0` if unspecified and can cover ELB, VPC Lattice and container health statuses considered by the service scheduler. ([AWS Documentation][7])

### Important distinction

```text
startPeriod
```

belongs to:

```text
container health check
```

while:

```text
healthCheckGracePeriodSeconds
```

belongs to:

```text
ECS service scheduling.
```

---

# Part G — What Happens When ECS Service Starts?

Suppose:

```text
desiredCount = 2
```

ECS creates:

```text
Task A
Task B
```

Then:

```text
Task gets ENI/IP
     │
     ▼
container starts
     │
     ▼
target registered
     │
     ▼
ALB health checks
     │
     ▼
target becomes healthy
     │
     ▼
ALB starts routing traffic
```

A target must pass its initial load-balancer health checks before it enters the `healthy` state and receives normal traffic. ([AWS Documentation][6])

---

# Part H — Multi-AZ Availability

A good production service:

```text
desiredCount >= 2
```

with subnets:

```text
Private AZ-A
Private AZ-B
```

might run:

```text
AZ-A
Task A

AZ-B
Task B
```

Then:

```text
AZ-A unavailable
     │
     ▼
Task B remains
     │
     ▼
service continues
```

ECS's scheduler includes Availability Zone balancing behavior when placing/stopping service tasks. ([AWS Documentation][8])

For production customer APIs:

```text
desiredCount = 1
```

should immediately make you think:

```text
single task failure
=
temporary service outage
```

even if ECS can eventually replace it.

---

# Part I — Rolling Deployment

Suppose current service:

```text
todo-api:17

Task A v17
Task B v17
Task C v17
Task D v17
```

You register:

```text
todo-api:18
```

Then update service:

```text
taskDefinition
17 → 18
```

A rolling deployment replaces old tasks incrementally with new ones. ECS currently supports an `ECS` deployment controller with native `ROLLING`, `BLUE_GREEN`, `LINEAR`, and `CANARY` strategies; rolling remains the default strategy. ([AWS Documentation][8])

---

# 12. Rolling Deployment Model

Conceptually:

```text
Initial

v17 v17 v17 v17


        ↓


Start v18

v17 v17 v17 v17 v18


        ↓

v18 healthy


        ↓

stop one v17


        ↓

v17 v17 v17 v18


        ↓

start next v18
```

Eventually:

```text
v18 v18 v18 v18
```

---

# Part J — `minimumHealthyPercent`

Suppose:

```text
desiredCount = 4

minimumHealthyPercent = 50
```

Then ECS needs at least:

```text
ceil(4 × 0.50)
=
2
```

healthy/running service tasks during the rolling operation.

That means ECS may stop up to two existing tasks before replacing them, subject to other deployment constraints. AWS rounds `minimumHealthyPercent` upward. ([AWS Documentation][9])

---

# 13. Example — 100%

```text
desiredCount = 4

minimumHealthyPercent = 100
```

ECS should maintain at least:

```text
4
```

healthy/running tasks during the deployment.

This is common for production APIs.

---

# Part K — `maximumPercent`

Suppose:

```text
desiredCount = 4

maximumPercent = 200
```

Then during deployment ECS can allow up to:

```text
floor(4 × 2.0)
=
8
```

running/pending/stopping tasks, depending on deployment phase.

So ECS can potentially launch all four new tasks before terminating the old four. AWS rounds the maximum threshold downward. ([AWS Documentation][9])

---

# 14. Production Pair

A common configuration:

```text
minimumHealthyPercent = 100

maximumPercent = 200
```

allows the conceptual pattern:

```text
4 old
+
up to 4 new
```

during deployment.

Benefit:

```text
strong availability
```

Tradeoff:

```text
temporary extra compute capacity
```

---

# 15. Low-Capacity EC2 Cluster Trap

For Fargate:

```text
maximumPercent=200
```

is easier because AWS can provision extra task compute, subject to quotas/capacity.

For ECS-on-EC2:

```text
cluster has capacity for exactly 4 tasks
```

but deployment wants:

```text
4 old
+
4 new
```

you have a problem.

You may need:

```text
lower min healthy

or

additional EC2 capacity.
```

This is why deployment strategy and capacity strategy cannot be designed independently.

---

# Part L — Zero-Downtime Requirements

A rolling deployment can be effectively zero-downtime only when all pieces cooperate:

```text
multiple tasks

multi-AZ placement

correct ALB health checks

correct grace period

minimumHealthyPercent

enough capacity

graceful shutdown

connection draining

working new revision

automatic rollback
```

Changing only:

```text
desiredCount=2
```

does not guarantee zero downtime.

---

# Part M — Deployment Circuit Breaker

Now imagine release `v18` is broken:

```text
v18 starts
   │
   ▼
crashes
   │
   ▼
new replacement starts
   │
   ▼
crashes
   │
   ▼
another replacement
   │
   ▼
crashes...
```

Without deployment-failure logic, this can remain unhealthy much longer than desired.

Use:

# ECS Deployment Circuit Breaker

```text
new deployment
      │
      ▼
tasks fail startup / health
      │
      ▼
failure threshold reached
      │
      ▼
deployment FAILED
      │
      ▼
automatic rollback
```

The ECS deployment circuit breaker evaluates whether new deployment tasks reach `RUNNING` and then whether applicable ELB, Cloud Map and container health checks pass; it can automatically roll a failed deployment back to the latest completed deployment. ([AWS Documentation][10])

---

# 16. Two Circuit-Breaker Phases

Current ECS logic effectively checks:

```text
STAGE 1

Can new tasks reach RUNNING?
```

then:

```text
STAGE 2

Do the running tasks pass
configured health checks?
```

The second phase can use:

```text
ALB health

Cloud Map health

container health
```

to identify bad deployments. ([AWS Documentation][10])

---

# 17. Rollback

Initial:

```text
Deployment A
v17
COMPLETED
```

Deploy:

```text
Deployment B
v18
```

If B fails:

```text
B → FAILED
```

with rollback enabled:

```text
A
becomes active again
```

The circuit breaker uses the most recent suitable `COMPLETED` deployment as the rollback target. ([AWS Documentation][10])

---

# 18. Current Circuit-Breaker Threshold Controls

A newer ECS capability allows the deployment circuit breaker's failure counting to be tuned rather than relying only on the older opaque behavior.

Current controls include:

```text
resetOnHealthyTask

thresholdConfiguration
```

with threshold modes including a bounded percentage and configurable counts/percent behavior. The current default bounded-percent calculation is clamped to a minimum of 3 and maximum of 200 failures. ([AWS Documentation][10])

For ordinary applications, starting with the default logic is reasonable; custom thresholds matter when startup behavior is unusual.

---

# Part N — CloudWatch Alarm Rollback

Container health alone may not detect a logically broken release.

Example:

```text
v18 health endpoint:
200 OK

BUT

API 5xx:
35%

latency:
8 seconds
```

Container is technically alive.

Application is operationally broken.

ECS deployment failure detection can also use CloudWatch alarms and can roll deployments back when those alarm conditions detect a bad release. ([AWS Documentation][11])

Useful deployment alarms can include:

```text
ALB 5xx rate

target response latency

application error metric

business success rate
```

This gives you:

```text
Infrastructure health
+
Application health
```

rather than checking only:

```text
Did the process start?
```

---

# Part O — EventBridge Deployment Alerts

ECS emits deployment state-change events to EventBridge, including events for:

```text
SERVICE_DEPLOYMENT_IN_PROGRESS

SERVICE_DEPLOYMENT_COMPLETED

SERVICE_DEPLOYMENT_FAILED
```

and AWS recommends monitoring deployment failures programmatically. ([AWS Documentation][12])

Architecture:

```text
ECS Deployment
      │
      ▼
EventBridge
      │
      ▼
SERVICE_DEPLOYMENT_FAILED
      │
      ├── SNS
      ├── Slack/ChatOps
      └── incident automation
```

Excellent DevOps pattern.

---

# Part P — Connection Draining

Suppose ECS decides to stop:

```text
Task A
```

but Task A is currently serving:

```text
Request 1
Request 2
Request 3
```

You do not want:

```text
Task dies immediately
        │
        ▼
users receive connection reset
```

ALB target deregistration supports:

# Deregistration Delay

When a target enters draining, ALB stops giving it new requests and allows existing traffic time to finish. The default ALB deregistration delay is currently **300 seconds**, configurable from `0` to `3600` seconds. ([AWS Documentation][13])

---

# 19. Draining Model

```text
Task A
ACTIVE
  │
  ▼
deregister requested
  │
  ▼
DRAINING
  │
  ├── no new requests
  │
  ├── existing requests finish
  │
  ▼
UNUSED
```

This is crucial during:

```text
deployment

scale-in

task replacement
```

---

# 20. Do Not Always Use 300 Seconds

Suppose your API requests normally finish in:

```text
< 1 second
```

Then waiting five minutes to drain every task can make deployments unnecessarily slow.

AWS's ECS optimization guidance notes that shorter deregistration delays can improve deployment speed for short-lived request workloads, while warning against very short values for streaming or long-lived requests. ([AWS Documentation][14])

For example, an API might use:

```text
30–60 seconds
```

after validating that its requests finish safely in that window.

But:

```text
WebSockets

streaming

large uploads

long polling
```

may require a very different value.

---

# Part Q — SIGTERM

Connection draining is only half the story.

ECS also needs the process to shut down correctly.

ECS first sends a stop signal—`SIGTERM` by default—to the container, then later sends `SIGKILL` if the container has not exited within the stop timeout. ([AWS Documentation][14])

The application needs to react.

---

# 21. Bad Node.js Shutdown

```javascript
app.listen(3002);
```

with no shutdown handling.

When termination comes:

```text
SIGTERM
   │
   ▼
process doesn't deliberately drain
   │
   ▼
in-flight work can be interrupted
```

---

# 22. Better Node.js

```javascript
const server = app.listen(3002, () => {
  console.log("Server running on port 3002");
});

process.on("SIGTERM", () => {
  console.log("SIGTERM received");

  server.close(() => {
    console.log("HTTP server closed");
    process.exit(0);
  });
});
```

The important behavior:

```text
SIGTERM
   │
   ▼
stop accepting new HTTP requests
   │
   ▼
finish current requests
   │
   ▼
close server
   │
   ▼
exit cleanly
```

AWS specifically recommends handling SIGTERM for ECS services; its Node.js example uses `server.close()` for this purpose. ([AWS Documentation][14])

---

# 23. Real Production Shutdown

A stronger implementation:

```javascript
let shuttingDown = false;

app.get("/health", (req, res) => {
  if (shuttingDown) {
    return res.status(503).json({
      status: "draining"
    });
  }

  res.status(200).json({
    status: "ok"
  });
});

const server = app.listen(3002);

process.on("SIGTERM", async () => {
  shuttingDown = true;

  console.log("Starting graceful shutdown");

  server.close(async () => {
    try {
      await mongoose.connection.close();

      console.log("Shutdown complete");
      process.exit(0);
    } catch (error) {
      console.error(error);
      process.exit(1);
    }
  });
});
```

Now during shutdown:

```text
health → 503

ALB stops using task

existing requests drain

DB connection closes

process exits
```

That is much closer to production behavior.

---

# Part R — `stopTimeout`

The container definition supports a stop timeout controlling how long ECS allows graceful termination before forcing shutdown.

Conceptually:

```json
{
  "stopTimeout": 60
}
```

The operational design should satisfy:

```text
Typical longest in-flight work
<
stop timeout
```

so the process gets enough time to finish its SIGTERM handler before ECS sends the hard kill. AWS's ECS shutdown guidance explicitly connects stop timeout with graceful SIGTERM handling. ([AWS Documentation][14])

---

# Part S — Four Deployment Strategies in Modern ECS

This is an important **2026 update**.

Many older ECS tutorials teach only:

```text
ECS rolling
```

versus:

```text
CodeDeploy blue/green.
```

Modern native ECS service deployments now support these strategies with the ECS deployment controller:

| Strategy     | Traffic pattern                             |
| ------------ | ------------------------------------------- |
| `ROLLING`    | Replace tasks incrementally                 |
| `BLUE_GREEN` | Build complete green, then switch           |
| `LINEAR`     | Shift traffic in equal increments           |
| `CANARY`     | Send small percentage first, then remainder |

([AWS Documentation][8])

The older **CodeDeploy-powered ECS blue/green controller still exists**, but AWS now recommends the newer Amazon ECS-native blue/green deployment model for new migration paths. ([AWS Documentation][15])

---

# Part T — Native ECS Blue/Green

Architecture:

```text
                         ALB
                          │
                    Production
                      Listener
                          │
                          ▼
                    Listener Rule
                          │
              ┌───────────┴───────────┐
              │                       │

          Target Group A          Target Group B

              │                       │
              ▼                       ▼

          BLUE v17                GREEN v18
          Task A                  Task C
          Task B                  Task D
```

A managed ALB blue/green deployment needs two target groups: one primary and one alternate. For `awsvpc`/Fargate those target groups use `ip` target type. ([AWS Documentation][3])

---

# 24. Blue/Green Flow

```text
Step 1
────────
100% traffic → Blue


Step 2
────────
Green tasks start


Step 3
────────
Green health checks pass


Step 4
────────
Optional test traffic → Green


Step 5
────────
Production listener → Green


Step 6
────────
Bake period


Step 7
────────
Blue terminated
```

This is the current native ECS blue/green workflow with managed traffic shifting through ALB. ([AWS Documentation][16])

---

# 25. Why Blue/Green Is Powerful

If Green is bad:

```text
Production
    │
    ▼
Green
  BAD
    │
    ▼
switch listener
    │
    ▼
Blue
```

Rollback can be much faster than reconstructing an entire old rolling deployment because the old environment is intentionally retained through the bake period. ([AWS Documentation][16])

Tradeoff:

```text
temporarily ~2× application capacity
```

because both revisions can run together. ([AWS Documentation][16])

---

# Part U — Canary Deployment

Canary asks:

> Why expose 100% of customers to v18 immediately?

Instead:

```text
                     ALB

                ┌─────┴─────┐
                ▼           ▼

             BLUE v17     GREEN v18

                90%         10%
```

Observe:

```text
errors

latency

business conversion

memory

CPU

logs
```

Then:

```text
if healthy
    │
    ▼
100% → Green
```

Native ECS canary deployments shift a configured small percentage first, wait through a canary evaluation period, and then shift the remaining production traffic. ([AWS Documentation][17])

---

# 26. Canary Is About Blast Radius

Suppose bug impacts:

```text
20% of payment requests.
```

Rolling deployment can eventually expose many customers during replacement.

Canary:

```text
5–10% initial traffic
```

can reveal the problem while limiting exposure.

That makes canary particularly valuable for:

```text
high-risk API releases

payment services

authentication

checkout

core backend changes
```

---

# Part V — Linear Deployment

Linear deployment looks like:

```text
10% Green
90% Blue

wait


20% Green
80% Blue

wait


30% Green
70% Blue

wait

...

100% Green
```

Native ECS linear deployments shift traffic in equal increments. The current step percentage is configurable from `3.0` to `100.0`, with configurable wait/bake time between shifts. ([AWS Documentation][18])

---

# 27. Canary vs Linear

Think:

```text
CANARY

10%
wait
100%
```

versus:

```text
LINEAR

10%
20%
30%
40%
...
100%
```

Canary:

```text
fast validation with
small initial blast radius
```

Linear:

```text
progressively increase confidence
through multiple traffic stages.
```

---

# Part W — Deployment Lifecycle Hooks

Native ECS blue/green, canary and linear strategies support deployment lifecycle hooks.

A hook can be:

```text
Lambda validation
```

or:

```text
pause point requiring continuation.
```

Examples:

```text
Green started
     │
     ▼
Lifecycle Hook
     │
     ▼
Run integration tests
     │
 ┌───┴───┐
 ▼       ▼
PASS    FAIL
 │       │
 ▼       ▼
shift   rollback
traffic
```

Current ECS deployment lifecycle hooks can run Lambda functions at specific deployment stages, and pause hooks can suspend progress until explicitly continued. ([AWS Documentation][19])

This is excellent for:

```text
smoke tests

security checks

API contract checks

database compatibility

manual change approval
```

---

# Part X — Rolling vs Blue/Green vs Canary vs Linear

A practical decision model:

```text
Low/medium-risk application
cost-conscious
simple deployment
        │
        ▼
      ROLLING
```

```text
Need isolated full environment
and extremely fast rollback
        │
        ▼
    BLUE_GREEN
```

```text
Want limited real-traffic exposure
before full rollout
        │
        ▼
      CANARY
```

```text
Want gradual controlled production
traffic ramp-up
        │
        ▼
      LINEAR
```

Native ECS now directly exposes these strategies under the ECS deployment controller. ([AWS Documentation][8])

---

# Part Y — Cloud Map Service Discovery

Suppose:

```text
Frontend ECS
     │
     ▼
Backend ECS
```

You don't necessarily want:

```text
frontend
→ public ALB
→ backend
```

for every internal request.

One option is:

# ECS Service Discovery + AWS Cloud Map

```text
Backend Service
     │
     ▼
Cloud Map
     │
     ▼
backend.prod.internal
     │
     ▼
Task IPs
```

ECS service discovery uses Cloud Map namespaces and services so clients can discover ECS task endpoints through DNS or the Cloud Map API. ([AWS Documentation][20])

---

# 28. Example

Namespace:

```text
prod.internal
```

Service:

```text
todo-api
```

DNS:

```text
todo-api.prod.internal
```

can resolve to private task addresses.

For `awsvpc`, Cloud Map can register task IP records directly. ([AWS Documentation][20])

---

# 29. Cloud Map Limitation

Pure DNS discovery means:

```text
DNS cache

record TTL

client behavior

connection balancing
```

become part of your service-to-service architecture.

Modern ECS often makes:

# Service Connect

the more interesting option.

---

# Part Z — ECS Service Connect

Service Connect provides:

```text
service discovery
+
service-to-service connectivity
+
managed proxy
+
standardized metrics/logs
```

as part of ECS service configuration. AWS describes Service Connect as ECS-managed discovery plus a service mesh for ECS services. ([AWS Documentation][21])

---

# 30. Architecture

Suppose:

```text
Frontend
```

calls:

```text
API
```

with Service Connect:

```text
┌──────────────────────────┐
│ Frontend Task            │
│                          │
│ App                      │
│   │                      │
│   ▼                      │
│ Service Connect Proxy    │
└──────────────┬───────────┘
               │
               ▼
        api:3002
               │
               ▼
┌──────────────────────────┐
│ API Task                 │
│                          │
│ Service Connect Proxy    │
│      │                   │
│      ▼                   │
│ Node API                 │
└──────────────────────────┘
```

Clients can use stable short service names instead of directly managing changing task IPs. Service Connect creates endpoints within a Cloud Map namespace and runs an ECS-managed proxy sidecar in participating tasks. ([AWS Documentation][21])

---

# 31. Service Connect Example Names

Client might call:

```text
http://todo-api:3002
```

instead of:

```text
http://10.0.10.25:3002
```

The local Service Connect proxy performs the service routing. AWS documents round-robin endpoint balancing plus failure-aware outlier behavior in Service Connect. ([AWS Documentation][22])

---

# 32. Service Connect vs ALB

They solve different problems.

```text
ALB
=
external / north-south traffic
```

Example:

```text
Internet
→ ALB
→ API
```

Service Connect:

```text
internal / east-west ECS traffic
```

Example:

```text
API
→ payment
→ inventory
```

You can use both:

```text
                         Internet
                            │
                            ▼
                           ALB
                            │
                            ▼
                       API Service
                            │
                      Service Connect
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
        Payment Service             Inventory Service
```

---

# Part AA — ECS Exec

Traditional VM debugging:

```text
SSH
→ server
→ docker exec
```

Fargate has:

```text
no server for you to SSH into.
```

Use:

# ECS Exec

ECS Exec lets you execute commands or open a shell directly inside running ECS containers on Fargate or EC2 without opening inbound SSH ports or managing host SSH keys. ([AWS Documentation][23])

---

# 33. Enable ECS Exec

Service:

```bash
aws ecs update-service \
  --cluster todo-production \
  --service todo-api \
  --enable-execute-command \
  --force-new-deployment \
  --region ap-south-1
```

Then:

```bash
aws ecs execute-command \
  --cluster todo-production \
  --task <TASK_ARN> \
  --container todo-api \
  --command "/bin/sh" \
  --interactive \
  --region ap-south-1
```

ECS Exec relies on Systems Manager functionality and appropriate task-role permissions; Fargate platform requirements also apply. ([AWS Documentation][24])

---

# 34. Production Philosophy

Use ECS Exec as:

```text
break-glass diagnostics
```

not:

```text
"SSH into production
and manually patch files."
```

If you fix production by doing:

```bash
vi /app/server.js
```

inside one container:

```text
Task dies
   │
   ▼
replacement starts
   │
   ▼
manual change disappears.
```

Correct flow:

```text
Git
 ↓
CI
 ↓
Docker image
 ↓
ECR
 ↓
new task definition
 ↓
ECS deployment
```

---

# Part AB — Terraform Production ALB

Now build your Todo API architecture.

## Target group

```hcl
resource "aws_lb_target_group" "todo_api" {
  name = "todo-api-tg"

  port     = 3002
  protocol = "HTTP"

  target_type = "ip"

  vpc_id = aws_vpc.main.id

  deregistration_delay = 60

  health_check {
    enabled = true

    path = "/health"

    protocol = "HTTP"

    matcher = "200"

    interval = 30

    timeout = 5

    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
```

For Fargate/`awsvpc`, `ip` is the required target type. ALB target-group health and deregistration settings determine when a task receives traffic and how long existing requests can drain. ([AWS Documentation][1])

---

# 35. ALB Security Group

```hcl
resource "aws_security_group" "alb" {
  name   = "todo-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 443
    to_port   = 443

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}
```

---

# 36. ECS Task Security Group

```hcl
resource "aws_security_group" "ecs_tasks" {
  name   = "todo-ecs-tasks"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3002
    to_port   = 3002

    protocol = "tcp"

    security_groups = [
      aws_security_group.alb.id
    ]
  }

  egress {
    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}
```

The critical rule:

```text
ECS :3002
ONLY FROM
ALB SG
```

---

# 37. ALB

```hcl
resource "aws_lb" "api" {
  name = "todo-api-alb"

  internal = false

  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}
```

---

# 38. HTTPS Listener

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn = aws_acm_certificate.api.arn

  default_action {
    type = "forward"

    target_group_arn =
      aws_lb_target_group.todo_api.arn
  }
}
```

---

# 39. HTTP → HTTPS

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

---

# Part AC — ECS Service + ALB

```hcl
resource "aws_ecs_service" "todo_api" {
  name = "todo-api"

  cluster =
    aws_ecs_cluster.main.id

  task_definition =
    aws_ecs_task_definition.api.arn

  desired_count = 2

  launch_type = "FARGATE"

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [
      aws_security_group.ecs_tasks.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn =
      aws_lb_target_group.todo_api.arn

    container_name =
      "todo-api"

    container_port =
      3002
  }

  depends_on = [
    aws_lb_listener.https
  ]
}
```

The current Terraform AWS provider exposes ECS service health-check grace configuration and the ECS service load-balancer/deployment settings used for this rolling deployment pattern. ([Terraform Registry][25])

---

# Part AD — Deployment Walkthrough

Current production:

```text
desiredCount = 2

todo-api:17
```

Tasks:

```text
10.0.10.21 → healthy
10.0.20.34 → healthy
```

---

## Build v18

CI:

```bash
docker build \
  -t todo-api:${BUILD_NUMBER} .
```

Tag:

```bash
docker tag \
  todo-api:${BUILD_NUMBER} \
  ${ECR_REPO}:${BUILD_NUMBER}
```

Push:

```bash
docker push \
  ${ECR_REPO}:${BUILD_NUMBER}
```

---

## Register task revision

```text
todo-api:17
    │
    ▼
todo-api:18

image:
todo-api:105
```

---

## Update service

```bash
aws ecs update-service \
  --cluster todo-production \
  --service todo-api \
  --task-definition todo-api:18 \
  --region ap-south-1
```

---

# 40. What ECS Does

```text
Service
currently:
v17 v17

     │
     ▼

starts:
v18

     │
     ▼

v18 reaches RUNNING

     │
     ▼

ALB health checks v18

     │
     ▼

v18 HEALTHY

     │
     ▼

traffic enters v18

     │
     ▼

old v17 deregisters

     │
     ▼

ALB drains requests

     │
     ▼

SIGTERM to old task

     │
     ▼

application gracefully stops

     │
     ▼

v17 removed
```

Repeat until:

```text
v18 v18
```

That is your zero-downtime rolling deployment path.

---

# Part AE — Broken Release Walkthrough

Suppose v19 has:

```javascript
process.exit(1);
```

Deployment:

```text
v18 v18
   │
   ▼
launch v19
   │
   ▼
v19 crashes
   │
   ▼
launch another
   │
   ▼
crashes
```

Circuit breaker notices the deployment cannot reach the required running/healthy state. ([AWS Documentation][10])

Then:

```text
v19 deployment
      │
      ▼
FAILED
      │
      ▼
rollback enabled
      │
      ▼
v18 restored
```

Meanwhile EventBridge can emit:

```text
SERVICE_DEPLOYMENT_FAILED
```

for your alert pipeline. ([AWS Documentation][12])

---

# Part AF — Validation Commands

## Service

```bash
aws ecs describe-services \
  --cluster todo-production \
  --services todo-api \
  --region ap-south-1
```

Useful deployment fields:

```text
desiredCount

runningCount

pendingCount

taskDefinition

deployments

rolloutState

rolloutStateReason
```

ECS surfaces deployment progress and failure status through its service/deployment descriptions. ([AWS Documentation][10])

---

# 41. Tasks

```bash
aws ecs list-tasks \
  --cluster todo-production \
  --service-name todo-api \
  --region ap-south-1
```

Then:

```bash
aws ecs describe-tasks \
  --cluster todo-production \
  --tasks <TASK_ARNS> \
  --region ap-south-1
```

Inspect:

```text
lastStatus

healthStatus

taskDefinitionArn

containers[].exitCode

containers[].reason

stoppedReason
```

---

# 42. Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --region ap-south-1
```

You want:

```text
healthy
healthy
```

Possible states include:

```text
initial

healthy

unhealthy

draining

unused
```

as the target moves through registration and deregistration. ([AWS Documentation][6])

---

# Part AG — Common ECS + ALB Failures

## 43. Tasks Running but ALB Shows Unhealthy

This is incredibly common.

Check:

```text
1. Does app listen on 0.0.0.0?

2. Correct container port?

3. Correct target-group port?

4. SG permits ALB → ECS?

5. /health returns expected code?

6. app actually ready?

7. route requires auth?

8. health path redirects?

9. timeout too aggressive?
```

A classic mistake:

```javascript
app.listen(3002, "127.0.0.1");
```

Then ALB cannot reach it through the task ENI.

Prefer listening on:

```text
0.0.0.0
```

inside the container for externally reachable container traffic.

---

# 44. Health Endpoint Returns `301`

Target group expects:

```text
200
```

but application returns:

```text
301
```

Then:

```text
TargetResponseCodeMismatch
```

can make the target unhealthy unless the matcher includes the returned status. ALB success-code matching can be configured across HTTP `200–499`, but only deliberately include codes that genuinely indicate healthy service behavior. ([AWS Documentation][6])

---

# 45. Tasks Die During Startup

Check:

```text
health_check_grace_period_seconds
```

If application requires 45 seconds but grace is:

```text
0
```

ECS may react to health failures before initialization finishes. ([AWS Documentation][7])

---

# 46. Deployment Never Moves

Suppose:

```text
desired = 2

minimumHealthy = 100%

maximum = 100%
```

Then ECS cannot:

```text
stop old task
```

because it violates minimum.

And cannot:

```text
start extra new task
```

because it violates maximum.

AWS explicitly warns to choose deployment percentages that permit at least one task to be started or stopped. ([AWS Documentation][9])

---

# 47. Correct Example

```text
desired = 2

min = 100

max = 200
```

Allowed:

```text
2 old
+
2 new
```

during replacement.

---

# 48. New Version Healthy but Customers See Errors

Health endpoint may be too shallow.

Example:

```text
GET /health
→ 200
```

but:

```text
POST /todos
→ 500
```

Use:

```text
CloudWatch alarms

application metrics

deployment hooks

synthetic tests
```

to complement liveness/ALB health checks.

ECS supports CloudWatch-alarm-based deployment failure detection and rollback for this kind of application-level protection. ([AWS Documentation][11])

---

# 49. Users Get 502 During Shutdown

Check:

```text
application SIGTERM handler

ALB deregistration delay

stopTimeout

long-running requests

Node child processes

database shutdown timing
```

If the target closes existing connections before the deregistration process safely finishes, clients can receive 5xx responses. ([AWS Documentation][13])

---

# 50. Deployment Takes Five Minutes Per Task

Check:

```text
deregistration_delay = 300
```

the ALB default. ([AWS Documentation][13])

If your requests last milliseconds:

```text
300 seconds
```

may be unnecessarily conservative.

Tune based on measured request lifetime—not arbitrary desire for faster deployment.

---

# 51. ECS Exec Fails

Check:

```text
enableExecuteCommand?

task role SSM permissions?

Session Manager plugin?

supported Fargate/agent version?

network to SSM endpoints?

read-only root filesystem issues?

managed agent running?
```

AWS calls out task-role permissions and SSM-agent/connectivity requirements as common ECS Exec troubleshooting points. ([AWS Documentation][26])

---

# Part AH — Certification / Interview Scenarios

### Scenario 1

> Fargate service behind ALB. What target type?

```text
IP
```

because Fargate tasks use `awsvpc` ENIs. ([AWS Documentation][1])

---

### Scenario 2

> ECS app takes 90 seconds to initialize and gets terminated by failing health checks.

Use:

```text
healthCheckGracePeriodSeconds
```

and ensure container-health `startPeriod` is also designed appropriately where applicable. ([AWS Documentation][7])

---

### Scenario 3

> Must keep all four API tasks available during rolling deployment.

Think:

```text
desired = 4

minimumHealthyPercent = 100
```

and ensure `maximumPercent` plus compute capacity allows new tasks to start. ([AWS Documentation][9])

---

### Scenario 4

> Need automatic rollback when new tasks cannot reach healthy steady state.

Use:

```text
ECS Deployment Circuit Breaker
+
rollback
```

([AWS Documentation][10])

---

### Scenario 5

> Containers are technically healthy but the new version produces 40% application errors.

Use:

```text
CloudWatch alarm
deployment failure detection
+
rollback
```

([AWS Documentation][11])

---

### Scenario 6

> Need very fast rollback and full pre-production validation of replacement tasks.

Think:

```text
ECS native BLUE_GREEN
```

with:

```text
primary target group
+
alternate target group.
```

([AWS Documentation][16])

---

### Scenario 7

> Send 10% of real users to new version, wait, then switch all remaining traffic.

Think:

```text
CANARY
```

([AWS Documentation][17])

---

### Scenario 8

> Shift 10%, then 20%, then 30%, continuing gradually.

Think:

```text
LINEAR
```

([AWS Documentation][18])

---

### Scenario 9

> Older design uses CodeDeploy for ECS blue/green. Is that still the only way?

No.

Modern ECS has native:

```text
BLUE_GREEN

CANARY

LINEAR
```

strategies under the ECS deployment controller, while the older CodeDeploy controller remains supported. AWS now recommends the native ECS blue/green path for newer implementations/migrations. ([AWS Documentation][8])

---

### Scenario 10

> Need private ECS microservices to call each other by stable names with built-in ECS connectivity.

Evaluate:

```text
ECS Service Connect
```

([AWS Documentation][21])

---

### Scenario 11

> Need simple DNS-based ECS service discovery.

Use:

```text
AWS Cloud Map
+
ECS service discovery.
```

([AWS Documentation][20])

---

### Scenario 12

> Need shell access to Fargate without SSH.

Use:

```text
ECS Exec.
```

([AWS Documentation][23])

---

# Part AI — Production Deployment Architecture

The finished design:

```text
                            CLIENTS
                               │
                               ▼
                            Route 53
                               │
                               ▼
                    api.yourdatascientist.tech
                               │
                               ▼
                        ALB HTTPS :443
                  Public AZ-A + Public AZ-B
                               │
                         Security Group
                               │
                               ▼
                        Target Group
                        target_type=ip
                        /health
                        drain=60s
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼

           Private AZ-A                    Private AZ-B

          ECS Fargate                     ECS Fargate
              Task                            Task
               │                               │
         ENI 10.0.10.x                  ENI 10.0.20.x
               │                               │
               ▼                               ▼
        Node.js :3002                   Node.js :3002
               │                               │
               └──────────────┬────────────────┘
                              │
                              ▼
                        Service Connect
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼            ▼
               Redis        Worker      Payments


                       DEPLOYMENT CONTROL

                         ECS Service
                              │
                              ├── minHealthy = 100%
                              ├── maxPercent = 200%
                              ├── health grace
                              ├── circuit breaker
                              ├── rollback
                              └── CloudWatch alarms


                        SHUTDOWN PATH

                    ALB deregistration
                              │
                              ▼
                           DRAIN
                              │
                              ▼
                           SIGTERM
                              │
                              ▼
                     finish requests
                              │
                              ▼
                      close resources
                              │
                              ▼
                            EXIT


                        OBSERVABILITY

             ALB target health / 4xx / 5xx
                            +
                    ECS service events
                            +
                    Container Insights
                            +
                     application logs
                            +
                      EventBridge
                            +
                  deployment failure alert
```

---

# 52. Zero-Downtime Checklist

Before calling an ECS service production-ready, verify:

```text
□ desired count >= 2 for HA workload

□ tasks span multiple AZs

□ tasks run in private subnets

□ ALB spans multiple public subnets/AZs

□ target type = ip for Fargate/awsvpc

□ ALB SG accepts client HTTPS

□ task SG accepts app port only from ALB SG

□ /health endpoint exists

□ health endpoint is lightweight

□ ALB health matcher correct

□ health-check grace period configured

□ container health startPeriod appropriate

□ minimumHealthyPercent designed

□ maximumPercent designed

□ enough temporary deployment capacity exists

□ circuit breaker enabled

□ automatic rollback enabled

□ CloudWatch application alarms configured

□ EventBridge deployment-failure alert configured

□ deregistration delay tuned

□ application handles SIGTERM

□ stop timeout allows graceful shutdown

□ static AWS credentials are absent

□ task role is least-privilege

□ execution role is separate

□ ECS Exec is restricted / auditable

□ logs are centralized

□ deployment rollback tested

□ broken-image deployment tested

□ unhealthy-task replacement tested

□ AZ failure considered
```

---

# 53. 35 Rules to Burn Into Memory

```text
1. Public traffic should hit the ALB, not Fargate tasks directly.

2. Fargate uses awsvpc networking.

3. awsvpc tasks have their own ENIs/IPs.

4. ALB target type for awsvpc = ip.

5. The target group points to task IP + application port.

6. ECS automatically registers/deregisters service tasks.

7. ALB SG should be public; task SG should reference ALB SG.

8. Don't open your container port to the whole internet.

9. Container health and ALB health are different.

10. Health endpoints should be lightweight.

11. Don't make health depend on every optional dependency.

12. healthCheckGracePeriod prevents premature replacement.

13. startPeriod belongs to container health checks.

14. Run multiple replicas across AZs for HA.

15. Rolling update replaces tasks incrementally.

16. minimumHealthyPercent is the lower availability bound.

17. maximumPercent is the deployment surge bound.

18. Bad min/max combinations can stall deployments.

19. Extra deployment capacity must physically exist.

20. Circuit breaker detects failed ECS deployments.

21. Enable automatic rollback.

22. CloudWatch alarms detect logical/application failures.

23. EventBridge can alert on failed deployments.

24. ALB deregistration enables connection draining.

25. Default ALB deregistration delay is 300 seconds.

26. Tune draining to your request lifetime.

27. ECS sends SIGTERM before forced termination.

28. Applications must handle SIGTERM gracefully.

29. Stop accepting new work before shutting down.

30. Native ECS now supports Rolling, Blue/Green,
    Linear and Canary strategies.

31. Blue/green uses parallel blue and green revisions.

32. Canary limits initial blast radius.

33. Linear gradually increases new-version traffic.

34. Service Connect is optimized for ECS east-west communication.

35. ECS Exec is break-glass debugging—not configuration management.
```

# ✅ Lesson 35 Part 2 Complete

You now understand:

```text
✓ ECS + ALB architecture
✓ public vs private networking
✓ IP target groups
✓ task ENIs
✓ security-group chaining

✓ container ports
✓ host ports
✓ dynamic port mapping
✓ bridge vs awsvpc networking

✓ ALB listeners
✓ listener rules
✓ target groups
✓ path routing

✓ container health checks
✓ ALB health checks
✓ ECS health
✓ liveness/readiness thinking
✓ health grace periods

✓ multi-AZ ECS services
✓ desired count
✓ rolling deployments

✓ minimumHealthyPercent
✓ maximumPercent
✓ deployment surge capacity

✓ deployment circuit breaker
✓ automatic rollback
✓ configurable failure thresholds
✓ CloudWatch alarm rollback
✓ EventBridge deployment alerts

✓ ALB deregistration
✓ connection draining
✓ SIGTERM
✓ graceful Node.js shutdown
✓ stop timeout

✓ native ECS Rolling deployments
✓ native ECS Blue/Green
✓ native ECS Canary
✓ native ECS Linear
✓ lifecycle hooks
✓ bake periods
✓ fast rollback

✓ Cloud Map
✓ ECS service discovery
✓ Service Connect
✓ internal ECS networking

✓ ECS Exec
✓ Fargate diagnostics

✓ Terraform ALB
✓ Terraform target group
✓ Terraform ECS service
✓ production security groups
✓ broken-deployment lab logic
✓ troubleshooting
✓ certification scenarios
```

# Next — Lesson 35 Part 3

# **ECS Auto Scaling, Capacity Providers, Fargate Spot, Container Insights, FireLens & Production Operations**

Next we'll make the service automatically react to real production load:

```text
                           USERS
                             │
                             ▼
                            ALB
                             │
                             ▼
                         ECS Service
                    desiredCount = 2
                             │
                 traffic increases
                             │
                             ▼
                       CloudWatch
                             │
                             ▼
                 Application Auto Scaling
                             │
                             ▼
                    desiredCount = 8
                             │
           ┌─────────┬───────┼───────┬─────────┐
           ▼         ▼       ▼       ▼         ▼
         Task      Task    Task    Task      Task
```

We’ll go deeply into **target-tracking scaling, step scaling, CPU vs memory vs ALB request-count scaling, custom SQS backlog-per-task scaling, scale-in cooldowns, min/max capacity, scheduled scaling, predictive concepts, capacity-provider base/weight strategies, Fargate + Fargate Spot mixes, graceful Spot interruption, scale-in protection, Container Insights, enhanced observability, FireLens/Fluent Bit log routing, ECS deployment metrics, CloudWatch alarms, cost optimization, rightsizing, ARM64/Graviton, autoscaling failure scenarios, Terraform, and a complete load-tested production scaling lab.**

[1]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html?utm_source=chatgpt.com "Use an Application Load Balancer for Amazon ECS"
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking-awsvpc.html?utm_source=chatgpt.com "Allocate a network interface for an Amazon ECS task"
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb-resources-for-blue-green.html "Application Load Balancer resources for blue/green, linear, and canary deployments - Amazon Elastic Container Service"
[4]: https://docs.aws.amazon.com/cli/latest/reference/ecs/create-service.html?utm_source=chatgpt.com "create-service — AWS CLI 2.36.2 Command Reference"
[5]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html?utm_source=chatgpt.com "Use load balancing to distribute Amazon ECS service traffic"
[6]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html "Health checks for Application Load Balancer target groups - Elastic Load Balancing"
[7]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_definition_parameters.html "Amazon ECS service definition parameters - Amazon Elastic Container Service"
[8]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_service-options.html "Amazon ECS service deployment controllers and strategies - Amazon Elastic Container Service"
[9]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html "Deploy Amazon ECS services by replacing tasks - Amazon Elastic Container Service"
[10]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html "How the Amazon ECS deployment circuit breaker detects failures - Amazon Elastic Container Service"
[11]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-failure-detection.html?utm_source=chatgpt.com "Amazon ECS deployment failure detection"
[12]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_service_deployment_events.html?utm_source=chatgpt.com "Amazon ECS service deployment state change events"
[13]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html "Edit target group attributes for your Application Load Balancer - Elastic Load Balancing"
[14]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/load-balancer-connection-draining.html "Optimize load balancer connection draining parameters for Amazon ECS - Amazon Elastic Container Service"
[15]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html?utm_source=chatgpt.com "CodeDeploy blue/green deployments for Amazon ECS"
[16]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-blue-green.html "Amazon ECS blue/green deployments - Amazon Elastic Container Service"
[17]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/canary-deployment.html "Amazon ECS canary deployments - Amazon Elastic Container Service"
[18]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-linear.html "Amazon ECS linear deployments - Amazon Elastic Container Service"
[19]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-lifecycle-hooks.html?utm_source=chatgpt.com "Lifecycle hooks for Amazon ECS service deployments"
[20]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html "Use service discovery to connect Amazon ECS services with DNS names - Amazon Elastic Container Service"
[21]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect.html "Use Service Connect to connect Amazon ECS services with short names - Amazon Elastic Container Service"
[22]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect-concepts-deploy.html?utm_source=chatgpt.com "Amazon ECS Service Connect components - Amazon Elastic Container Service"
[23]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html "Monitor Amazon ECS containers with ECS Exec - Amazon Elastic Container Service"
[24]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec-run.html?utm_source=chatgpt.com "Running commands using ECS Exec - AWS Documentation"
[25]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service.html?utm_source=chatgpt.com "aws_ecs_service | Resources | hashicorp/aws | Terraform"
[26]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec-troubleshooting.html?utm_source=chatgpt.com "Troubleshoot Amazon ECS Exec issues"
