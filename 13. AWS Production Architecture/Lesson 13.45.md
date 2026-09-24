# AWS Masterclass — Phase 3

# Lesson 44: Amazon ECS and AWS Fargate Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish Amazon ECS from AWS Fargate.
* Design ECS clusters, tasks, task definitions and services.
* Choose between Fargate, Fargate Spot and EC2 capacity.
* Configure task CPU, memory and ephemeral storage.
* Understand task roles and task execution roles.
* Deploy tasks securely into private subnets.
* Use Application Load Balancers with ECS services.
* Configure container and load-balancer health checks.
* Implement rolling, blue/green, canary and linear deployments.
* Configure automatic rollback and deployment circuit breakers.
* Scale ECS services using CPU, memory, request and custom metrics.
* Use Service Connect and Cloud Map for service discovery.
* Inject secrets safely.
* Troubleshoot containers using ECS Exec.
* Monitor services with CloudWatch and Container Insights.
* Build a production ECS Fargate architecture using Terraform.

---

# 2. ECS mental model

Amazon Elastic Container Service is AWS’s managed container orchestration service.

```text
Container image
      |
      v
Task definition
      |
      v
ECS task
      |
      v
ECS service
      |
      v
ECS cluster
      |
      v
Fargate, EC2 or other capacity
```

Amazon ECS manages task scheduling, replacement, deployment, service discovery, load-balancer registration and integration with AWS services. The underlying compute comes from a capacity option such as Fargate or EC2. ([AWS Documentation][1])

## One-line memory trick

```text
ECR stores the image.
Task definition describes it.
Task runs it.
Service maintains it.
Cluster organizes it.
Fargate supplies the compute.
```

---

# 3. ECS versus Fargate

Amazon ECS and AWS Fargate are not competing products.

```text
Amazon ECS:
Container orchestrator

AWS Fargate:
Serverless container compute
```

Architecture:

```text
Amazon ECS
    |
    | Schedules tasks
    v
AWS Fargate
    |
    | Provides CPU, memory, storage and networking
    v
Running containers
```

With Fargate, you specify the task’s CPU, memory, networking and IAM configuration, while AWS manages the underlying hosts. Each Fargate task receives its own isolation boundary and network interface. ([AWS Documentation][2])

---

# 4. ECS versus Kubernetes

```text
Amazon ECS:
AWS-native container orchestration

Amazon EKS:
Managed Kubernetes
```

Choose ECS when:

* You do not specifically require Kubernetes.
* Your workloads are primarily on AWS.
* You prefer simpler AWS-native operations.
* You want deep integration with IAM, ALB, CloudWatch and Fargate.
* Your team does not want to operate Kubernetes controllers and manifests.

Choose EKS when:

* Kubernetes portability is required.
* Existing tooling depends on Kubernetes APIs.
* Your organisation already has Kubernetes expertise.
* You need Kubernetes-specific operators or ecosystem components.

ECS usually has fewer control-plane concepts for an AWS-only container platform.

---

# 5. Core ECS components

```text
Cluster
Task definition
Task
Service
Container
Capacity provider
```

## Cluster

A logical grouping of ECS workloads and their available capacity.

## Task definition

A versioned blueprint describing one or more containers.

## Task

A running instance of a task definition.

## Service

Maintains a desired number of tasks and replaces failed ones.

## Container

The application or supporting process inside a task.

## Capacity provider

Defines where tasks receive compute capacity.

---

# 6. ECS cluster

An ECS cluster is a logical management boundary.

```text
production-cluster
├── todo-api service
├── todo-worker service
├── notification service
└── scheduled migration tasks
```

A cluster can be used with Fargate capacity, EC2 capacity providers or other supported ECS infrastructure options. Service Auto Scaling can independently change the number of service tasks. ([AWS Documentation][3])

A cluster does not itself run your application.

It contains or references the capacity on which ECS schedules tasks.

---

# 7. Task definition

A task definition is a JSON blueprint for your application.

It can describe:

* Container images.
* CPU and memory.
* Container ports.
* Environment variables.
* Secrets.
* Logging.
* Health checks.
* IAM roles.
* Network mode.
* Storage volumes.
* Startup commands.
* Container dependencies.
* Operating-system and CPU architecture.

Task definitions are revisioned and are used to start standalone tasks or create services. ([AWS Documentation][4])

Example family:

```text
todo-api
```

Revisions:

```text
todo-api:1
todo-api:2
todo-api:3
```

---

# 8. ECS task

A task is one running copy of a task definition.

```text
Task definition:
todo-api:42

Running tasks:
├── task A
├── task B
├── task C
└── task D
```

A task can contain:

```text
Application container
+
Logging sidecar
+
Proxy sidecar
+
Monitoring sidecar
```

All containers in a Fargate task share the task’s allocated CPU, memory, storage and task-level network interface.

---

# 9. ECS service

An ECS service maintains a desired number of tasks.

```text
Desired count:
4

Current state:
3 tasks running

ECS service scheduler:
Starts one replacement task
```

If a service task exits, becomes unhealthy or is stopped by infrastructure maintenance, the service scheduler launches a replacement to return to the desired count. ([AWS Documentation][4])

Use services for:

* APIs.
* Web applications.
* Long-running workers.
* Internal microservices.
* Consumers that must remain running.

---

# 10. Standalone tasks

A standalone task runs without an ECS service maintaining it.

Use for:

* Database migrations.
* One-time scripts.
* Batch processing.
* Scheduled jobs.
* Administrative operations.
* Data imports.
* Cleanup jobs.

```text
Run task
   |
   v
Task performs work
   |
   v
Task exits
```

If a standalone task is stopped by Fargate maintenance, ECS does not automatically replace it. You must use a scheduler, workflow or custom logic where continued execution is required. ([AWS Documentation][5])

---

# 11. Capacity choices

ECS capacity can be provided through:

```text
AWS Fargate
Fargate Spot
EC2 Auto Scaling group capacity providers
ECS Managed Instances
External/ECS Anywhere infrastructure
```

AWS recommends capacity providers for advanced capacity management rather than manually launching and registering EC2 instances. ([AWS Documentation][6])

---

# 12. Fargate

Fargate is a strong choice when you want:

* No EC2 instance management.
* Per-task resource allocation.
* Strong task-level isolation.
* Simple capacity operations.
* Rapid application deployment.
* Independent task scaling.
* Reduced host patching responsibility.

```text
Task requests:
1 vCPU
2 GB memory

Fargate:
Selects and manages underlying infrastructure
```

You pay according to resources allocated to the task, including vCPU, memory and chargeable storage usage. ([Amazon Web Services, Inc.][7])

---

# 13. When EC2-backed ECS may be better

Consider ECS on EC2 when:

* Workloads run constantly at high utilization.
* You can achieve significant bin-packing efficiency.
* GPUs are required.
* Special EC2 instance types are needed.
* Host-level agents are required.
* Kernel or privileged-container features are needed.
* Reserved Instances or Savings Plans make EC2 capacity economical.
* You need deeper host-level control.

With EC2-backed ECS, you operate:

* Auto Scaling groups.
* EC2 AMIs.
* ECS container agents.
* Host patching.
* Disk capacity.
* Host security.
* Instance draining.
* Capacity scaling.

---

# 14. Fargate task CPU and memory

A Fargate task must use a supported CPU and memory combination.

Examples include:

| vCPU | Supported memory examples |
| ---: | ------------------------- |
| 0.25 | 0.5, 1 or 2 GB            |
|  0.5 | 1–4 GB                    |
|    1 | 2–8 GB                    |
|    2 | 4–16 GB                   |
|    4 | 8–30 GB                   |

Larger Fargate configurations also support additional CPU and memory ranges. Task-level CPU and memory are mandatory for Fargate. ([AWS Documentation][8])

Example:

```json
{
  "cpu": "1024",
  "memory": "2048"
}
```

Meaning:

```text
1 vCPU
2 GB memory
```

---

# 15. Task CPU versus container CPU

Task-level CPU defines the total capacity available to the task.

Container-level CPU controls how that capacity is shared.

Example:

```text
Task:
1 vCPU = 1024 CPU units

Containers:
API       = 768 units
Telemetry = 256 units
```

For Fargate, task-level resources are required. Container-level reservations can be used when several containers share the task, but they are unnecessary for many single-container tasks. ([AWS Documentation][9])

---

# 16. Memory hard limit

A container-level memory value can act as a hard limit.

```text
Container memory:
1,024 MiB
```

If the container exceeds that limit, it may be killed for running out of memory.

Symptoms often include:

```text
Essential container exited
Exit code 137
OutOfMemoryError
```

Avoid setting memory exactly equal to the application’s average usage.

Allow headroom for:

* Traffic bursts.
* Runtime garbage collection.
* Native libraries.
* Sidecars.
* TLS buffers.
* Temporary response construction.

---

# 17. Fargate task sizing method

Measure:

```text
CPUUtilization
MemoryUtilization
Application latency
Request throughput
Garbage-collection behavior
```

Example:

```text
Current task:
0.5 vCPU
1 GB memory

Observations:
CPU p95 = 95%
Memory p95 = 52%
High latency during traffic bursts
```

Likely adjustment:

```text
Increase CPU before memory
```

Another example:

```text
CPU p95 = 30%
Memory p95 = 94%
OOM task exits
```

Likely adjustment:

```text
Increase memory
or
fix memory leak
```

Do not scale the task blindly before identifying the constrained resource.

---

# 18. Fargate ephemeral storage

Fargate Linux tasks on supported platform versions receive `20 GiB` of ephemeral storage by default.

It can be increased up to:

```text
200 GiB
```

Container image layers use part of that storage, so the full configured capacity is not necessarily available to application files. Ephemeral-storage usage can be exposed through task metadata and Container Insights. ([AWS Documentation][10])

Example task definition:

```json
{
  "ephemeralStorage": {
    "sizeInGiB": 50
  }
}
```

---

# 19. Ephemeral storage is temporary

Use ephemeral storage for:

* Temporary processing files.
* Image transformations.
* Downloaded archives.
* Build artifacts within a job.
* Local caches.
* Log buffers.

Do not use it for:

* Uploaded customer data.
* Permanent application state.
* Shared user files.
* Database data requiring durability.

When the task stops, its ephemeral storage disappears.

Use S3, EFS or another persistent data service for durable data.

---

# 20. Fargate Spot

Fargate Spot runs interruption-tolerant tasks on spare AWS capacity at a discount relative to standard Fargate.

When AWS reclaims the capacity, the task receives:

```text
EventBridge task state-change notification
+
SIGTERM
+
Approximately two-minute warning
```

([AWS Documentation][11])

Suitable workloads:

* Queue consumers.
* Batch tasks.
* Development environments.
* Stateless workers.
* Distributed data processing.
* Tasks that checkpoint frequently.

Avoid relying exclusively on Fargate Spot for:

* Single-instance critical APIs.
* Non-idempotent jobs.
* Tasks that cannot recover.
* Stateful workloads without checkpointing.
* Strict low-latency availability.

---

# 21. Mixed Fargate capacity strategy

Example:

```text
FARGATE:
Base = 2
Weight = 1

FARGATE_SPOT:
Weight = 3
```

Interpretation:

```text
First 2 tasks:
Run on standard Fargate

Remaining tasks:
Roughly distributed 1:3
between Fargate and Fargate Spot
```

Only one provider in a strategy can have a `base`, and at least one provider must have a weight above zero. Fargate and EC2 Auto Scaling group providers cannot be mixed inside the same individual capacity-provider strategy. ([AWS Documentation][12])

---

# 22. Graceful Spot termination

Your container must handle:

```text
SIGTERM
```

Example Node.js application:

```javascript
let server;

async function shutdown(signal) {
  console.log(`Received ${signal}; shutting down`);

  server.close(async () => {
    await closeDatabaseConnections();
    process.exit(0);
  });

  setTimeout(() => {
    process.exit(1);
  }, 25_000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

For workers:

```text
Stop receiving new messages
Finish or checkpoint current work
Release locks
Flush logs
Exit
```

---

# 23. Task networking

Fargate uses:

```text
awsvpc network mode
```

Each task receives:

* An elastic network interface.
* A private IP address.
* Security-group membership.
* VPC routing.
* Optional public IP where explicitly configured.

This gives ECS tasks networking behavior similar to EC2 instances. ([AWS Documentation][13])

---

# 24. Production subnet architecture

Recommended:

```text
Internet
   |
   v
Public Application Load Balancer
   |
   v
Private subnets
├── ECS task A
├── ECS task B
└── ECS task C
```

Tasks:

```text
Public IP:
Disabled

Inbound traffic:
Only from ALB security group

Outbound:
NAT gateway or VPC endpoints as required
```

Do not assign public IPs to production backend tasks merely because it makes initial testing easier.

---

# 25. Security-group architecture

## ALB security group

```text
Inbound:
443 from approved clients or internet

Outbound:
Application port to ECS task security group
```

## ECS task security group

```text
Inbound:
Port 3002 only from ALB security group

Outbound:
Required databases, AWS endpoints and external services
```

## Database security group

```text
Inbound:
Database port only from ECS task security group
```

Flow:

```text
Client
  |
  v
ALB SG
  |
  v
ECS task SG
  |
  v
Database SG
```

Avoid broad rules such as:

```text
0.0.0.0/0 → port 3002
0.0.0.0/0 → port 5432
```

---

# 26. Network dependencies

Private Fargate tasks commonly need access to:

* ECR API.
* ECR Docker registry.
* S3 for container layers.
* CloudWatch Logs.
* Secrets Manager.
* Systems Manager.
* KMS.
* STS.
* Application dependencies.

Connectivity can be provided through:

```text
NAT gateway
or
VPC endpoints
```

A fully private design may use interface endpoints for AWS APIs and an S3 gateway endpoint, reducing NAT dependence.

---

# 27. Task execution role

The task execution role is used by the ECS or Fargate agent.

It commonly permits:

* Pulling images from private ECR.
* Sending logs through `awslogs`.
* Retrieving task-definition secrets.
* Accessing private registry credentials.
* Supporting selected monitoring capabilities.

These credentials are used by the ECS infrastructure and are not directly supplied to application containers as task credentials. ([AWS Documentation][14])

Common managed policy:

```text
AmazonECSTaskExecutionRolePolicy
```

---

# 28. Task role

The task role is used by your application code.

Example:

```text
Todo API container
      |
      | Task-role credentials
      v
DynamoDB
S3
SQS
Secrets Manager
```

The task role should contain only the permissions needed by the containers in that task. ([AWS Documentation][15])

## Memory trick

```text
Execution role:
ECS starts the container.

Task role:
The application accesses AWS.
```

---

# 29. Execution role versus task role

| Activity                       | Role                               |
| ------------------------------ | ---------------------------------- |
| Pull image from ECR            | Execution role                     |
| Send logs using `awslogs`      | Execution role                     |
| Resolve task-definition secret | Execution role                     |
| Application writes to DynamoDB | Task role                          |
| Application sends SQS message  | Task role                          |
| Application reads an S3 object | Task role                          |
| ECS Exec communication         | Task role permissions are involved |

AWS recommends creating separate roles for separate responsibilities instead of using one broad shared role. ([AWS Documentation][16])

---

# 30. Container image management

Images should be stored in Amazon ECR using immutable release identifiers.

Good:

```text
todo-api:2026.07.28-42
todo-api:git-a19f82c
todo-api@sha256:...
```

Risky:

```text
todo-api:latest
```

ECS can resolve image tags to digests to maintain image version consistency across service tasks, and this behavior is enabled by default unless explicitly disabled. ([AWS Documentation][17])

For production:

* Enable ECR tag immutability.
* Scan images.
* Pin deployments to immutable tags or digests.
* Never rebuild the same production tag with different content.
* Retain previous release images for rollback.

---

# 31. Task-definition revisions

A new application release should usually create a new task-definition revision.

```text
todo-api:41
    |
    | New image and settings
    v
todo-api:42
```

Task definitions should be immutable release records.

Avoid:

* Manually editing production tasks.
* Reusing mutable image tags.
* Changing container state from inside a running task.
* Treating ECS Exec modifications as deployments.

The running container should be replaceable from the registered task definition and image.

---

# 32. Essential containers

A container can be marked:

```json
{
  "essential": true
}
```

If an essential container stops, ECS treats the task as stopped.

Example:

```text
API container:
Essential = true

Telemetry sidecar:
Essential = false
```

If the API exits, the task must stop.

If a noncritical metrics sidecar exits, you may decide whether the application task should continue.

Choose essential status based on whether the task can operate correctly without the container.

---

# 33. Sidecar pattern

One task may contain:

```text
Application
Log router
Service Connect proxy
Security agent
OpenTelemetry collector
```

Benefits:

* Shared lifecycle.
* Local communication.
* Shared volumes.
* Consistent deployment.

Costs:

* Shared task CPU and memory.
* Larger blast radius.
* Sidecar failure can stop the task.
* More complex startup dependencies.
* Increased Fargate resource cost.

Do not put unrelated applications in one task merely to reduce the visible number of tasks.

---

# 34. Container dependencies

You can control startup relationships.

Example:

```text
Telemetry sidecar:
Must be healthy

Application:
Starts after telemetry sidecar is healthy
```

Possible dependency states include concepts such as:

```text
START
COMPLETE
SUCCESS
HEALTHY
```

This is useful for:

* Init containers.
* Proxy readiness.
* Configuration generation.
* Migration checks.
* Log-router startup.

Avoid making long-running application startup depend on a one-time container that never exits.

---

# 35. Container health checks

ECS container health checks execute a command inside the container.

Example:

```json
{
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "curl --fail http://localhost:3002/health || exit 1"
    ],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 20
  }
}
```

Container health checks validate application behavior locally and affect ECS task health. ([AWS Documentation][18])

---

# 36. Health-check endpoint design

A health endpoint should answer a clear question.

## Liveness

```text
Is the process alive and capable of responding?
```

Example:

```text
/health/live
```

## Readiness

```text
Can this task safely receive traffic?
```

Example:

```text
/health/ready
```

Readiness may check:

* Application initialization.
* Required configuration.
* Critical database connectivity.
* Dependency availability.

Do not make health checks depend on every optional downstream service.

If an optional email provider is down, your entire API should not necessarily be removed from service.

---

# 37. Load-balancer health checks

For ALB-connected services:

```text
ALB
 |
 | GET /health/ready
 v
ECS task
```

ECS considers a load-balanced task healthy when it is running and the load balancer reports it healthy. ([AWS Documentation][19])

Configure:

* Correct protocol.
* Correct port.
* Correct health path.
* Expected status range.
* Health interval.
* Timeout.
* Healthy threshold.
* Unhealthy threshold.
* Deregistration delay.

---

# 38. Health-check grace period

Some applications need startup time for:

* Runtime initialization.
* Dependency loading.
* Database migrations.
* Cache warm-up.
* JIT compilation.

A service health-check grace period tells ECS to temporarily ignore failing health checks after task startup.

Example:

```text
Application normal startup:
45 seconds

Grace period:
60 seconds
```

Do not use a ten-minute grace period to conceal a broken application startup.

---

# 39. Faster deployments through health checks

Load-balancer health checks commonly default to a 30-second interval and five healthy checks for recovering targets.

For applications that stabilize rapidly, AWS documents that settings such as:

```text
Health check interval:
5 seconds

Healthy threshold:
2
```

can reduce health-validation time substantially. Newly registered targets require one successful initial health check to be considered healthy. ([AWS Documentation][20])

Test these values against real application startup behavior.

Aggressive settings can cause flapping when an application has temporary latency spikes.

---

# 40. Load-balancer choices

Fargate ECS services support:

```text
Application Load Balancer
Network Load Balancer
Gateway Load Balancer
```

([AWS Documentation][21])

## Application Load Balancer

Use for:

* HTTP and HTTPS.
* Host routing.
* Path routing.
* TLS termination.
* Header-based rules.
* Microservice APIs.
* Web applications.

## Network Load Balancer

Use for:

* TCP.
* TLS passthrough or termination.
* UDP.
* Static IP requirements.
* Very high network throughput.
* Protocols not handled by ALB.

## Gateway Load Balancer

Use for:

* Network virtual appliances.
* Firewalls.
* Inspection services.

---

# 41. ALB target type for Fargate

With Fargate and `awsvpc` networking, each task has its own IP.

Therefore, use:

```text
Target type:
ip
```

not:

```text
Target type:
instance
```

Architecture:

```text
ALB target group
├── 10.0.10.24:3002
├── 10.0.11.47:3002
└── 10.0.12.18:3002
```

---

# 42. ALB routing

Example:

```text
api.example.com/todos/*
    → Todo API service

api.example.com/users/*
    → User service

admin.example.com/*
    → Admin service
```

ALB can connect one service to multiple target groups and expose multiple task ports when required. ([AWS Documentation][21])

For internet-facing production APIs, a common chain is:

```text
CloudFront
    |
    v
WAF
    |
    v
ALB
    |
    v
ECS Fargate
```

or:

```text
API Gateway
    |
    v
VPC Link
    |
    v
Internal ALB
    |
    v
ECS Fargate
```

---

# 43. Desired task count

For an availability-sensitive service:

```text
Desired count:
At least 2
```

Deploy tasks across multiple Availability Zones.

Bad:

```text
One production task
in one subnet
```

Better:

```text
Task A:
Availability Zone A

Task B:
Availability Zone B

Task C:
Availability Zone C
```

The exact count depends on:

* Traffic.
* Fault tolerance.
* Deployment strategy.
* Task startup time.
* Availability target.
* Capacity-provider availability.

---

# 44. Rolling deployments

A rolling deployment gradually replaces old tasks with new tasks.

```text
Old tasks:
A A A A

Deployment:
A A A B
A A B B
A B B B
B B B B
```

The two primary controls are:

```text
minimumHealthyPercent
maximumPercent
```

For rolling services, the defaults are generally:

```text
minimumHealthyPercent = 100
maximumPercent = 200
```

([AWS Documentation][19])

---

# 45. Minimum healthy percent

Suppose:

```text
Desired count:
4

minimumHealthyPercent:
50%
```

ECS must maintain at least:

```text
2 healthy tasks
```

This allows ECS to stop up to two old tasks before starting replacements when extra capacity is unavailable.

Lowering the value:

* Reduces extra capacity requirements.
* Can reduce availability.
* Can reduce service throughput during deployment.

---

# 46. Maximum percent

Suppose:

```text
Desired count:
4

maximumPercent:
200%
```

ECS may run up to:

```text
8 tasks
```

during deployment.

This allows all four replacement tasks to start before the old tasks stop, provided capacity is available. ([AWS Documentation][22])

A common production configuration is:

```text
minimumHealthyPercent = 100
maximumPercent = 200
```

This prioritizes availability but may temporarily double Fargate capacity.

---

# 47. Invalid deployment configuration

If both values are:

```text
minimumHealthyPercent = 100
maximumPercent = 100
```

ECS cannot:

* Stop an old task, because that would fall below 100%.
* Start a new task, because that would exceed 100%.

This can block deployment and instance draining. ([AWS Documentation][23])

---

# 48. Deployment circuit breaker

The ECS deployment circuit breaker detects when a rolling deployment cannot reach a healthy steady state.

It can:

```text
Mark deployment FAILED
+
Automatically roll back
```

to the most recent completed deployment. ([AWS Documentation][24])

Terraform concept:

```hcl
deployment_circuit_breaker {
  enable   = true
  rollback = true
}
```

Use it for production rolling deployments.

Without it, a broken deployment may remain stuck repeatedly starting and stopping tasks.

---

# 49. Deployment alarms

Deployment rollback can also be connected to CloudWatch alarms.

Possible deployment alarms:

* ALB 5xx error rate.
* Target response latency.
* Application error rate.
* No healthy targets.
* Custom business transaction failures.

Example:

```text
New deployment
      |
      v
5xx alarm enters ALARM
      |
      v
Deployment fails
      |
      v
ECS rolls back
```

Choose alarms that represent application health, not only task startup.

---

# 50. Native ECS blue/green deployments

Blue/green deployment runs two service revisions:

```text
Blue:
Current production revision

Green:
New revision
```

```text
Production traffic
       |
       v
Blue tasks

Green tasks:
Created and tested separately
```

After validation:

```text
Production traffic
       |
       v
Green tasks
```

The old blue environment can remain available temporarily for rapid rollback. ECS supports blue/green deployment workflows that create and validate the green service revision before production traffic is shifted. ([AWS Documentation][25])

---

# 51. Canary traffic shifting

A canary deployment sends a small traffic percentage to the green revision before full promotion.

Example:

```text
Step 1:
10% green
90% blue

Bake time:
10 minutes

Step 2:
100% green
```

ECS’s native canary deployment strategy can combine traffic shifting, validation hooks and alarm-based rollback. ([AWS Documentation][26])

Monitor:

* Error rate.
* p95 latency.
* Business success rate.
* CPU and memory.
* Downstream failures.
* Database query behavior.

---

# 52. Linear deployment

A linear deployment shifts traffic in repeated increments.

Example:

```text
Every 5 minutes:
Shift another 20%

0%  → green
20% → green
40% → green
60% → green
80% → green
100% → green
```

ECS now supports native linear traffic-shifting strategies in addition to rolling and blue/green deployment options. ([AWS Documentation][27])

Use linear deployment when you want more observation points than a two-step canary.

---

# 53. Deployment lifecycle hooks

Lifecycle hooks can run Lambda functions or pause a deployment at specific phases.

Use cases:

* Run smoke tests.
* Validate database compatibility.
* Verify an internal test endpoint.
* Obtain human approval.
* Enforce security checks.
* Validate business metrics.

The hook returns a status such as:

```text
SUCCEEDED
FAILED
IN_PROGRESS
```

to tell ECS how deployment should proceed. ([AWS Documentation][28])

---

# 54. Blue/green capacity requirement

During blue/green deployment, both environments exist simultaneously.

```text
Normal capacity:
4 tasks

Blue/green deployment:
4 blue + 4 green
```

Ensure:

* Fargate quotas allow the extra tasks.
* Subnets have enough IP addresses.
* Database connections can support both revisions.
* Load-balancer target groups are configured.
* Cost impact is acceptable.
* Both versions can run simultaneously.

AWS recommends planning sufficient capacity for both revisions and using health checks, alarms, bake time and lifecycle validation. ([AWS Documentation][29])

---

# 55. Backward-compatible deployments

During a rolling or blue/green deployment, old and new application versions may run simultaneously.

Therefore database changes should generally follow:

```text
Expand
Migrate
Contract
```

Example:

```text
Step 1:
Add new nullable database column.

Step 2:
Deploy application supporting both old and new schemas.

Step 3:
Backfill data.

Step 4:
Move reads to new column.

Step 5:
Remove old column in a later release.
```

Do not deploy a schema change that immediately breaks the still-running old task revision.

---

# 56. Service Auto Scaling

ECS Service Auto Scaling changes the service’s desired task count through Application Auto Scaling.

Supported policy approaches include:

* Target tracking.
* Step scaling.
* Scheduled scaling.
* Predictive scaling.

ECS emits service CPU and memory metrics, and other CloudWatch metrics can be used to scale the task count. ([AWS Documentation][30])

---

# 57. Target-tracking scaling

Target tracking works like a thermostat.

Example:

```text
Target CPU:
60%
```

If average service CPU rises above the target:

```text
Scale out
```

If it remains below the target:

```text
Scale in gradually
```

Application Auto Scaling creates and manages the associated CloudWatch alarms. It prioritizes rapid scale-out and more conservative scale-in. ([AWS Documentation][31])

---

# 58. CPU scaling example

```hcl
resource "aws_appautoscaling_target" "service" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"

  resource_id = (
    "service/${aws_ecs_cluster.production.name}/${aws_ecs_service.todo_api.name}"
  )

  min_capacity = 2
  max_capacity = 20
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "todo-api-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.service.service_namespace
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  resource_id        = aws_appautoscaling_target.service.resource_id

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
}
```

---

# 59. ALB request-count scaling

For HTTP services, a strong scaling metric may be:

```text
ALBRequestCountPerTarget
```

Example target:

```text
1,000 requests per task per minute
```

If request volume rises:

```text
Requests per target increase
        |
        v
ECS adds tasks
        |
        v
Requests distributed across more targets
```

Target-tracking support has deployment-strategy considerations; for example, the predefined ALB request-count metric is not supported with some blue/green deployment configurations. ([AWS Documentation][31])

---

# 60. Queue-depth scaling

For SQS workers, average CPU may be low even while work is accumulating.

Use:

```text
Backlog per task =
Visible queue messages / Running task count
```

Example target:

```text
20 messages per worker
```

```text
Queue backlog:
1,000

Running tasks:
10

Backlog per task:
100
```

The service should scale out.

Use metric math or publish a custom metric appropriate to the worker’s processing rate and acceptable waiting time.

---

# 61. Avoid scaling only on CPU

CPU scaling may fail when:

* The workload waits on databases.
* Work is network-bound.
* Queue backlog increases while CPU remains low.
* One task handles many long-lived connections.
* Memory is the constrained resource.
* External rate limits constrain throughput.

Use the metric that most closely represents demand and capacity.

---

# 62. Autoscaling during deployment

For target-tracking policies:

* Scale-out can continue during an ECS deployment.
* Scale-in is suspended during the deployment to protect availability.

([AWS Documentation][31])

This may temporarily increase task count and cost.

Ensure database and subnet capacity can support:

```text
Deployment surge
+
Autoscaling surge
```

at the same time.

---

# 63. Service discovery

Internal ECS services need stable names even though task IP addresses change.

Options include:

```text
AWS Cloud Map service discovery
ECS Service Connect
Internal load balancer
VPC Lattice
```

Cloud Map can register task IPs behind a private DNS namespace. ECS recommends container health checks so unhealthy tasks are not treated as healthy service-discovery instances. ([AWS Documentation][32])

---

# 64. Cloud Map example

```text
Namespace:
production.local

Service:
todo-api
```

Internal DNS:

```text
todo-api.production.local
```

```text
Worker task
     |
     | DNS lookup
     v
Cloud Map
     |
     v
Healthy Todo API task IPs
```

Service discovery routes directly to tasks rather than through a configured service load balancer. ([AWS Documentation][32])

---

# 65. ECS Service Connect

Service Connect provides managed service-to-service connectivity and discovery for ECS services.

```text
Todo worker
     |
     | http://todo-api:3002
     v
Service Connect proxy
     |
     v
Healthy Todo API task
```

Service Connect creates endpoints using named task-definition ports and configures service tasks to connect through those endpoints. ([AWS Documentation][33])

Benefits:

* Simple service names.
* Managed service discovery.
* Connection-level load balancing.
* Passive outlier detection.
* Retry support.
* Service connectivity metrics.
* Easier microservice communication.

---

# 66. Service Connect health

Service Connect can avoid routing traffic to unhealthy task instances when proper container health checks are defined.

It also uses proxy-observed connection failures for passive outlier detection and retries selected failed connections. ([AWS Documentation][34])

Still configure:

* Application timeouts.
* Retries with limits.
* Circuit breakers.
* Idempotency.
* Dependency-specific health handling.

Service Connect does not make every downstream call automatically safe.

---

# 67. Environment variables

Use ordinary environment variables for nonsensitive settings:

```text
NODE_ENV=production
PORT=3002
LOG_LEVEL=INFO
QUEUE_URL=...
```

Do not store plain secrets inside:

* Dockerfiles.
* Git repositories.
* Task-definition `environment` fields.
* Jenkinsfiles.
* Terraform variable defaults.
* Container image layers.

---

# 68. Secrets Manager and Parameter Store

ECS can inject values from:

```text
AWS Secrets Manager
Systems Manager Parameter Store
```

through task-definition secret references. ([AWS Documentation][35])

Example:

```json
{
  "secrets": [
    {
      "name": "DATABASE_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:ap-south-1:123456789012:secret:todo-db"
    }
  ]
}
```

The task execution role needs permission to retrieve injected task-definition secrets.

---

# 69. Secret-rotation behavior

When a secret is injected as an environment variable:

```text
Task starts
    |
    v
ECS retrieves secret
    |
    v
Secret value becomes container environment variable
```

If the secret later rotates, the running container does not automatically receive the new value.

You normally need to:

```text
Force a new ECS deployment
```

or have the application retrieve and cache secrets programmatically.

Environment-variable injection also means processes inside the container may be able to read the secret value.

---

# 70. Logging with `awslogs`

A common task-definition configuration is:

```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/production/todo-api",
      "awslogs-region": "ap-south-1",
      "awslogs-stream-prefix": "ecs"
    }
  }
}
```

ECS can send container stdout and stderr to CloudWatch Logs through the `awslogs` driver. ([AWS Documentation][36])

Applications should:

* Write structured JSON to stdout.
* Include request and trace IDs.
* Avoid local-only log files.
* Exclude credentials and tokens.
* Configure explicit retention.

---

# 71. FireLens

For advanced log routing, FireLens can use a Fluent Bit or Fluentd sidecar.

```text
Application stdout
        |
        v
FireLens log router
        |
        ├── CloudWatch Logs
        ├── OpenSearch
        ├── S3/Firehose
        └── External platform
```

Use FireLens when:

* Logs need transformation.
* Multiple destinations are required.
* Records need enrichment.
* A vendor-specific log pipeline is used.

Account for sidecar CPU and memory in the task size.

---

# 72. Container Insights

CloudWatch Container Insights collects and summarizes ECS container and service metrics.

Enhanced observability adds more detailed task and container telemetry. ([AWS Documentation][37])

Monitor:

* Task CPU.
* Task memory.
* Running task count.
* Pending task count.
* Network traffic.
* Storage usage.
* Container restarts.
* Service deployment state.

Enable it intentionally because detailed observability adds monitoring cost.

---

# 73. ECS CloudWatch metrics

ECS sends service and cluster metrics to CloudWatch, commonly at one-minute periods. ([AWS Documentation][38])

Important service metrics:

```text
CPUUtilization
MemoryUtilization
DesiredTaskCount
RunningTaskCount
PendingTaskCount
```

Combine with ALB metrics:

```text
RequestCount
TargetResponseTime
HTTPCode_Target_5XX_Count
HealthyHostCount
UnHealthyHostCount
```

And application metrics:

```text
Business success rate
Queue processing duration
Database error rate
Request p95 latency
```

---

# 74. ECS Exec

ECS Exec allows authorised operators to run commands inside a running ECS container through Systems Manager infrastructure.

```text
Operator
   |
   | IAM-authorized execute-command
   v
ECS Exec
   |
   v
Running container
```

Use it for:

* Inspecting environment and files.
* Checking processes.
* Running diagnostic commands.
* Testing local health endpoints.
* Emergency troubleshooting.

ECS Exec can send command-session logs to CloudWatch Logs or S3 when configured. ([AWS Documentation][39])

---

# 75. ECS Exec example

```bash
aws ecs execute-command \
  --cluster production \
  --task TASK_ARN \
  --container todo-api \
  --interactive \
  --command "/bin/sh" \
  --region ap-south-1
```

Inside:

```bash
env
ps aux
df -h
curl http://localhost:3002/health
```

Do not use ECS Exec to make permanent production changes.

Any correction performed manually will disappear when the task is replaced.

Fix the image, configuration or task definition instead.

---

# 76. ECS Exec security

Configure:

* IAM authorization.
* CloudTrail.
* KMS encryption where required.
* CloudWatch or S3 session logging.
* Limited production access.
* Justified incident use.
* No shared administrator roles.

ECS Exec requires appropriate task-role permissions for communication with Systems Manager components. ([AWS Documentation][15])

Be aware that command logging requires compatible utilities such as `script` and `cat` inside the image for supported logging modes. ([AWS Documentation][39])

---

# 77. Graceful task shutdown

When ECS stops a task, the container should:

```text
Receive SIGTERM
Stop accepting new work
Drain requests
Commit or release active work
Flush telemetry
Close connections
Exit
```

After the stop timeout, the container may be forcefully terminated.

For HTTP services:

* Configure ALB deregistration delay.
* Handle `SIGTERM`.
* Stop accepting new requests.
* Let in-flight requests finish.
* Exit before the timeout.

For SQS workers:

* Stop receiving new messages.
* Finish safely within visibility timeout.
* Extend message visibility when needed.
* Avoid deleting unfinished messages.

---

# 78. Service task protection

Some long-running tasks should not be removed during scale-in or deployment while they process critical work.

ECS task protection can temporarily protect selected service tasks from termination.

Use carefully:

* Set an expiry.
* Remove protection after work completes.
* Monitor protected-task count.
* Avoid protecting every task indefinitely.

Otherwise, deployments and scale-in operations may become blocked.

---

# 79. Fargate maintenance and retirement

AWS maintains the Fargate host infrastructure.

When an old platform-version revision is retired, ECS notifies affected tasks and replaces service-managed tasks according to the service configuration. Existing tasks are not live-migrated to newer revisions. ([AWS Documentation][5])

Production requirements:

* Monitor EventBridge task state-change events.
* Monitor AWS Health notifications.
* Maintain at least two tasks.
* Ensure graceful shutdown.
* Make tasks disposable.
* Avoid local-only state.

---

# 80. Scheduled tasks

Use EventBridge Scheduler or EventBridge rules to run ECS tasks on a schedule.

Examples:

```text
Nightly report
Database cleanup
Weekly certificate check
Monthly reconciliation
Scheduled import
```

The scheduler execution role requires:

* `ecs:RunTask`.
* `iam:PassRole` for the task role and execution role where applicable.

([AWS Documentation][40])

For complex schedules and retry/DLQ controls, EventBridge Scheduler is usually preferable.

---

# 81. Cost optimization

Major Fargate cost drivers include:

```text
Allocated vCPU
Allocated memory
Task duration
Additional ephemeral storage
Public IPv4 addresses
NAT gateway traffic
CloudWatch logging
Container Insights
Load balancers
Cross-AZ data transfer
```

Cost practices:

* Right-size CPU and memory.
* Scale services down when demand falls.
* Use Fargate Spot for tolerant workers.
* Use ARM64 images when compatible.
* Avoid oversized sidecars.
* Set log retention.
* Use VPC endpoints where they economically replace NAT traffic.
* Separate workloads with different scaling profiles.
* Stop unused development services.
* Use Compute Savings Plans for stable Fargate usage.

---

# 82. ARM64 versus x86_64

Fargate supports task architectures such as:

```text
X86_64
ARM64
```

Use ARM64 when:

* Application dependencies support it.
* Container images are built for ARM.
* Performance testing is successful.
* Native libraries are compatible.

Build multiarchitecture images:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/todo-api:42 \
  --push .
```

Do not deploy an `amd64`-only image to an ARM64 task.

---

# 83. Terraform ECS cluster

```hcl
resource "aws_ecs_cluster" "production" {
  name = "production"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.ecs_exec.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
        cloud_watch_encryption_enabled = true

        s3_bucket_name = aws_s3_bucket.ecs_exec.id
        s3_key_prefix  = "sessions"
      }
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 84. Terraform execution role

```hcl
resource "aws_iam_role" "task_execution" {
  name = "production-todo-api-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role = aws_iam_role.task_execution.name

  policy_arn = (
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  )
}
```

---

# 85. Terraform task role

```hcl
resource "aws_iam_role" "todo_api" {
  name = "production-todo-api-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "todo_api" {
  name = "todo-api-access"
  role = aws_iam_role.todo_api.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]

        Resource = [
          aws_dynamodb_table.todoapp.arn,
          "${aws_dynamodb_table.todoapp.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.todo_processing.arn
      }
    ]
  })
}
```

---

# 86. Terraform task definition

```hcl
resource "aws_cloudwatch_log_group" "todo_api" {
  name              = "/ecs/production/todo-api"
  retention_in_days = 30

  kms_key_id = aws_kms_key.logs.arn
}

resource "aws_ecs_task_definition" "todo_api" {
  family = "production-todo-api"

  requires_compatibilities = [
    "FARGATE"
  ]

  network_mode = "awsvpc"

  cpu    = "1024"
  memory = "2048"

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.todo_api.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  ephemeral_storage {
    size_in_gib = 30
  }

  container_definitions = jsonencode([
    {
      name      = "todo-api"
      image     = "${aws_ecr_repository.todo_api.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [{
        name          = "http"
        containerPort = 3002
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = "3002"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.database.arn
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl --fail http://localhost:3002/health || exit 1"
        ]

        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.todo_api.name
          awslogs-region        = "ap-south-1"
          awslogs-stream-prefix = "ecs"
        }
      }

      stopTimeout = 60
    }
  ])

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 87. Terraform ALB target group

```hcl
resource "aws_lb_target_group" "todo_api" {
  name = "production-todo-api"

  port        = 3002
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = aws_vpc.main.id

  deregistration_delay = 30

  health_check {
    enabled = true

    path     = "/health"
    port     = "traffic-port"
    protocol = "HTTP"

    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3

    matcher = "200-299"
  }

  tags = {
    Environment = "production"
  }
}
```

---

# 88. Terraform ECS service

```hcl
resource "aws_ecs_service" "todo_api" {
  name    = "todo-api"
  cluster = aws_ecs_cluster.production.id

  task_definition = aws_ecs_task_definition.todo_api.arn

  desired_count = 3

  enable_execute_command = true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 2
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 2
  }

  network_configuration {
    assign_public_ip = false

    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]

    security_groups = [
      aws_security_group.todo_api.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.todo_api.arn
    container_name   = "todo-api"
    container_port   = 3002
  }

  health_check_grace_period_seconds = 60

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  depends_on = [
    aws_lb_listener.https
  ]

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

`desired_count` is commonly ignored by Terraform when Application Auto Scaling owns the live task count.

---

# 89. AWS CLI deployment workflow

Register task definition:

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region ap-south-1
```

Update service:

```bash
aws ecs update-service \
  --cluster production \
  --service todo-api \
  --task-definition production-todo-api:42 \
  --force-new-deployment \
  --region ap-south-1
```

Wait for stability:

```bash
aws ecs wait services-stable \
  --cluster production \
  --services todo-api \
  --region ap-south-1
```

Inspect service:

```bash
aws ecs describe-services \
  --cluster production \
  --services todo-api \
  --region ap-south-1
```

---

# 90. Validate a deployment

Check running task definition:

```bash
aws ecs describe-services \
  --cluster production \
  --services todo-api \
  --query 'services[0].taskDefinition' \
  --output text \
  --region ap-south-1
```

List tasks:

```bash
aws ecs list-tasks \
  --cluster production \
  --service-name todo-api \
  --region ap-south-1
```

Inspect tasks:

```bash
aws ecs describe-tasks \
  --cluster production \
  --tasks TASK_ARN \
  --region ap-south-1
```

Validate application:

```bash
curl --fail https://api.yourdatascientist.tech/health
```

Check target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --region ap-south-1
```

---

# 91. Troubleshooting task stopped

Inspect:

```bash
aws ecs describe-tasks \
  --cluster production \
  --tasks TASK_ARN \
  --query 'tasks[0].{
    stoppedReason:stoppedReason,
    stopCode:stopCode,
    containers:containers[*].{
      name:name,
      reason:reason,
      exitCode:exitCode
    }
  }' \
  --region ap-south-1
```

Common causes:

```text
CannotPullContainerError
ResourceInitializationError
EssentialContainerExited
OutOfMemoryError
TaskFailedToStart
SpotInterruption
ServiceSchedulerInitiated
```

Always inspect:

* `stoppedReason`.
* `stopCode`.
* Container `reason`.
* Container `exitCode`.
* Service events.
* CloudWatch logs.

---

# 92. Troubleshooting `CannotPullContainerError`

Check:

1. Image tag exists.
2. ECR repository Region is correct.
3. Execution role exists.
4. Execution role can pull from ECR.
5. Private task can reach ECR endpoints.
6. S3 connectivity exists for ECR layers.
7. Image architecture matches task architecture.
8. Cross-account ECR policy permits access.
9. Image manifest is supported.
10. Disk space is sufficient.

Useful command:

```bash
aws ecr describe-images \
  --repository-name todo-api \
  --image-ids imageTag=42 \
  --region ap-south-1
```

---

# 93. Troubleshooting `ResourceInitializationError`

Common causes:

* Secret retrieval failed.
* Parameter Store access failed.
* KMS key denied.
* CloudWatch log group missing.
* Logs endpoint unavailable.
* ECR authentication failed.
* Task execution role lacks permission.
* VPC DNS or networking failed.
* EFS mount failed.

Ask:

```text
Did the container begin running?
```

If not, investigate the execution role and task infrastructure before debugging application code.

---

# 94. Troubleshooting unhealthy ALB targets

Check:

```text
Container is listening on 0.0.0.0
Correct container port
Correct target-group port
Task security group allows ALB security group
Health path exists
Health response is 200
Health check is not authentication protected
Grace period is sufficient
Application startup completed
Target type is ip
```

A frequent Node.js error:

```javascript
app.listen(3002, "127.0.0.1");
```

This listens only on loopback.

Use:

```javascript
app.listen(3002, "0.0.0.0");
```

inside a container.

---

# 95. Troubleshooting deployment stuck

Check:

* New tasks are `PENDING`.
* Subnets are out of IP addresses.
* Fargate capacity is unavailable.
* Fargate Spot has no capacity.
* Task definition has invalid CPU/memory.
* Image cannot be pulled.
* New task fails health checks.
* `minimumHealthyPercent` and `maximumPercent` block progress.
* Service quota is reached.
* Secrets cannot be resolved.
* Deployment circuit breaker status.
* CloudWatch deployment alarms.
* ALB target health.

Service events are often the fastest source:

```bash
aws ecs describe-services \
  --cluster production \
  --services todo-api \
  --query 'services[0].events[0:15]' \
  --region ap-south-1
```

---

# 96. Troubleshooting OOM exits

Symptoms:

```text
Exit code 137
Task stops under load
MemoryUtilization reaches 100%
```

Investigate:

* Task and container memory.
* Runtime heap size.
* Memory leak.
* Unbounded cache.
* Large request bodies.
* Too many concurrent requests.
* Sidecar memory.
* Native-module allocations.
* Large temporary object processing.

Increasing memory may restore service, but still profile the application to determine whether consumption grows indefinitely.

---

# 97. Troubleshooting no internet connectivity

For private tasks, check:

* Private subnet route to NAT gateway.
* NAT gateway availability.
* Public subnet route to internet gateway.
* Task security-group egress.
* Network ACLs.
* DNS support and hostnames.
* Interface endpoints.
* Endpoint security groups.
* Proxy settings.

Remember:

```text
Private subnet
    |
    v
NAT gateway in public subnet
    |
    v
Internet gateway
```

Assigning a public IP is not the recommended fix for a private production service.

---

# 98. Troubleshooting secret access

If the task fails before the application starts:

```text
Task execution role issue
```

Check:

* `secretsmanager:GetSecretValue`.
* `ssm:GetParameters`.
* `kms:Decrypt`.
* Secret ARN.
* Secret Region.
* VPC endpoint or NAT path.
* KMS key policy.

If the application retrieves the secret itself after startup:

```text
Task role issue
```

Distinguishing the two roles prevents hours of incorrect IAM troubleshooting.

---

# 99. Troubleshooting ECS Exec

Check:

* Service has `enable_execute_command`.
* Task was started after Exec was enabled.
* ECS Exec agent is running.
* Operator has required IAM permissions.
* Task role has required SSM message permissions.
* Session Manager plugin is installed.
* Network path reaches Systems Manager endpoints.
* KMS and logging permissions are correct.
* Container has a supported shell.

AWS provides an ECS Exec Checker utility for validating prerequisites. ([AWS Documentation][41])

---

# 100. Production TodoApp architecture

```text
Route 53
   |
   v
CloudFront
   |
   v
AWS WAF
   |
   v
Application Load Balancer
   |
   v
Private ECS Fargate service
├── Task A in AZ-A
├── Task B in AZ-B
└── Task C in AZ-C
        |
        ├── DynamoDB
        ├── SQS
        ├── EventBridge
        ├── Secrets Manager
        └── CloudWatch Logs
```

Background workers:

```text
SQS
 |
 v
Todo worker ECS service
 |
 ├── Fargate base capacity
 └── Fargate Spot burst capacity
```

Operational controls:

```text
Immutable ECR images
Task-definition revisions
Deployment circuit breaker
Canary or rolling deployment
Service Auto Scaling
Container Insights
ECS Exec auditing
Structured logs
Multi-AZ private networking
```

---

# 101. Production readiness checklist

```text
[ ] Images are stored in ECR
[ ] Image tags are immutable
[ ] Vulnerability scanning is enabled
[ ] Production uses immutable image versions
[ ] Task definitions are version controlled
[ ] Task role and execution role are separate
[ ] IAM roles use least privilege
[ ] Tasks run in private subnets
[ ] Public IP assignment is disabled
[ ] Tasks span multiple Availability Zones
[ ] Security groups reference other security groups
[ ] NAT or VPC endpoint connectivity is tested
[ ] CPU and memory are load tested
[ ] Memory has safe headroom
[ ] Ephemeral storage is sized intentionally
[ ] Durable data is externalized
[ ] Application handles SIGTERM
[ ] Stop timeout is sufficient
[ ] Container health checks exist
[ ] ALB health checks validate readiness
[ ] Health-check grace period matches startup
[ ] Target groups use IP targets for Fargate
[ ] Minimum healthy and maximum percent are valid
[ ] Deployment circuit breaker is enabled
[ ] Automatic rollback is enabled
[ ] Deployment alarms represent customer health
[ ] Database changes are backward compatible
[ ] Service Auto Scaling is configured
[ ] Scaling metric represents actual demand
[ ] Maximum task count protects dependencies
[ ] Fargate Spot is used only for tolerant work
[ ] Spot tasks checkpoint or retry safely
[ ] Secrets are stored outside task-definition plaintext
[ ] Secret rotation triggers safe task replacement
[ ] Logs are structured
[ ] Log retention is explicit
[ ] Container Insights is enabled where justified
[ ] ECS Exec is audited
[ ] ECS service and task events are monitored
[ ] Stopped-task alerts exist
[ ] Fargate retirement events are monitored
[ ] Rollback is tested
```

---

# 102. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Amazon ECS:
Container orchestration

AWS Fargate:
Serverless compute for containers

ECR:
Container-image registry

ECS service:
Maintains running tasks
```

## Solutions Architect Associate

Understand:

```text
Task definition
Task
Service
Cluster
Fargate versus EC2
Task role versus execution role
awsvpc networking
ALB integration
Service Auto Scaling
Fargate Spot
```

## DevOps Engineer Professional

Understand:

```text
Task-definition revisioning
Image digest consistency
Capacity-provider strategies
Rolling-deployment percentages
Circuit-breaker rollback
Blue/green and canary deployments
Lifecycle hooks
Custom autoscaling metrics
ECS Exec
Container Insights
Graceful shutdown
Multi-account deployment roles
```

---

# 103. Interview questions

## Question 1: What is Amazon ECS?

**Answer:**

Amazon ECS is an AWS-managed container orchestration service that schedules and manages container tasks and services.

## Question 2: What is AWS Fargate?

**Answer:**

Fargate is serverless container compute used by services such as ECS. AWS manages the underlying servers while you allocate CPU, memory, storage, networking and IAM to each task.

## Question 3: What is a task definition?

**Answer:**

It is a versioned blueprint describing one or more containers, including images, resources, ports, roles, logging, health checks and storage.

## Question 4: What is an ECS task?

**Answer:**

It is one running instance of a task definition.

## Question 5: What is an ECS service?

**Answer:**

It maintains a desired number of task instances and replaces tasks when they stop or become unhealthy.

## Question 6: What is the difference between a task role and execution role?

**Answer:**

The execution role lets ECS pull images, publish logs and resolve task-definition secrets. The task role gives the application container permission to call AWS APIs.

## Question 7: What network mode does Fargate use?

**Answer:**

Fargate uses `awsvpc`, giving each task its own elastic network interface, private IP and security groups.

## Question 8: Which ALB target type is used for Fargate?

**Answer:**

`ip`, because every Fargate task is registered using its task ENI’s IP address.

## Question 9: What does `minimumHealthyPercent` control?

**Answer:**

It defines the minimum percentage of desired tasks that must remain healthy during a rolling deployment.

## Question 10: What does `maximumPercent` control?

**Answer:**

It defines the maximum percentage of desired tasks that may exist in running, pending or stopping states during deployment.

## Question 11: What is the deployment circuit breaker?

**Answer:**

It detects when a rolling deployment cannot become healthy and can automatically roll back to the previous completed deployment.

## Question 12: What is Fargate Spot?

**Answer:**

It runs interruption-tolerant tasks on spare Fargate capacity at a discounted price, with approximately two minutes’ interruption notice.

## Question 13: What is a capacity-provider strategy?

**Answer:**

It defines how ECS distributes tasks across providers such as standard Fargate, Fargate Spot or EC2-backed capacity.

## Question 14: What is ECS Service Auto Scaling?

**Answer:**

It changes the desired task count using Application Auto Scaling policies based on CPU, memory, ALB request count, schedules or custom metrics.

## Question 15: What is Service Connect?

**Answer:**

It provides ECS-native service discovery and connectivity using named endpoints and managed proxies between ECS services.

## Question 16: What is ECS Exec?

**Answer:**

It provides IAM-controlled command execution inside running containers through Systems Manager infrastructure.

## Question 17: What happens to Fargate local storage when a task stops?

**Answer:**

The task’s ephemeral storage is deleted. Persistent application data must be stored externally.

## Question 18: How should an application handle task shutdown?

**Answer:**

It should handle `SIGTERM`, stop accepting new work, finish or release active operations, flush telemetry and exit before the stop timeout.

## Question 19: Why should a production service run at least two tasks?

**Answer:**

It improves availability during task failure, infrastructure maintenance and deployments and allows tasks to be distributed across Availability Zones.

## Question 20: How would you deploy ECS safely?

**Answer:**

Use immutable images, a new task-definition revision, health checks, rolling or canary traffic shifting, a deployment circuit breaker, CloudWatch alarms and automatic rollback.

---

# 104. Never-forget revision

```text
ECS:
Container orchestrator.

Fargate:
Serverless container compute.

Cluster:
Logical workload and capacity group.

Task definition:
Versioned application blueprint.

Task:
Running task-definition instance.

Service:
Maintains desired tasks.

Capacity provider:
Defines compute placement.

Task execution role:
Used by ECS infrastructure.

Task role:
Used by application code.

awsvpc:
One ENI and IP per task.

Fargate Spot:
Discounted interruptible capacity.

Container health check:
Local container health.

ALB health check:
Traffic-readiness health.

minimumHealthyPercent:
Deployment availability floor.

maximumPercent:
Deployment task-count ceiling.

Circuit breaker:
Detects and rolls back failed deployment.

Service Auto Scaling:
Changes desired task count.

Service Connect:
ECS service-to-service connectivity.

ECS Exec:
Secure command execution in a task.

Container Insights:
Detailed container telemetry.
```

## One-line memory trick

```text
Build an immutable image.
Describe it in a task definition.
Run it as a service.
Keep tasks private.
Give each task least privilege.
Scale by demand.
Deploy with health checks.
Replace instead of repairing.
```

## Lesson 44 outcome

You can now design ECS where:

```text
A container must run without managing servers
    → ECS schedules it on Fargate.

An API task fails
    → ECS service replaces it.

Traffic increases
    → Service Auto Scaling adds tasks.

A release cannot pass health checks
    → Deployment circuit breaker rolls it back.

A worker can tolerate interruption
    → Fargate Spot reduces compute cost.

Services need stable internal names
    → Service Connect provides discovery and routing.

A task needs DynamoDB access
    → Its task role grants only required actions.

ECS needs to pull the image
    → The execution role grants ECR access.

An engineer needs diagnostics
    → ECS Exec opens an audited session.

A task is replaced
    → No application data is lost because state is external.
```

**Next lesson: Lesson 45 — Amazon ECR and the production container supply chain: repositories, image layers, tags and digests, vulnerability scanning, lifecycle policies, cross-account access, replication, signing, SBOMs and CI/CD promotion.**

[1]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html?utm_source=chatgpt.com "What is Amazon Elastic Container Service?"
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html?utm_source=chatgpt.com "Architect for AWS Fargate for Amazon ECS"
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/clusters.html?utm_source=chatgpt.com "Amazon ECS clusters - Amazon Elastic Container Service"
[4]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html?utm_source=chatgpt.com "Amazon ECS task definitions"
[5]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-maintenance.html?utm_source=chatgpt.com "Task retirement and maintenance for AWS Fargate on ..."
[6]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/capacity-launch-type-comparison.html?utm_source=chatgpt.com "Amazon Amazon ECS launch types and capacity providers"
[7]: https://aws.amazon.com/fargate/pricing/?utm_source=chatgpt.com "AWS Fargate Pricing - Amazon.com"
[8]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html?utm_source=chatgpt.com "Amazon ECS task definition parameters for Fargate"
[9]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-size-best-practice.html?utm_source=chatgpt.com "Choosing Fargate task sizes for Amazon ECS"
[10]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-storage.html?utm_source=chatgpt.com "Fargate task ephemeral storage for Amazon ECS"
[11]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-capacity-providers.html?utm_source=chatgpt.com "Amazon ECS clusters for Fargate"
[12]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/asg-capacity-providers.html?utm_source=chatgpt.com "Amazon ECS capacity providers for EC2 workloads"
[13]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking-awsvpc.html?utm_source=chatgpt.com "Allocate a network interface for an Amazon ECS task"
[14]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html?utm_source=chatgpt.com "Amazon ECS task execution IAM role - AWS Documentation"
[15]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html?utm_source=chatgpt.com "Amazon ECS task IAM role - Amazon Elastic Container Service"
[16]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-iam-roles.html?utm_source=chatgpt.com "Best practices for IAM roles in Amazon ECS"
[17]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html?utm_source=chatgpt.com "Deploy Amazon ECS services by replacing tasks"
[18]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/healthcheck.html?utm_source=chatgpt.com "Determine Amazon ECS task health using container ..."
[19]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/update-service-parameters.html?utm_source=chatgpt.com "Update Amazon ECS service parameters"
[20]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/load-balancer-healthcheck.html?utm_source=chatgpt.com "Optimize load balancer health check parameters for ..."
[21]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html?utm_source=chatgpt.com "Use load balancing to distribute Amazon ECS service traffic"
[22]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_definition_parameters.html?utm_source=chatgpt.com "Amazon ECS service definition parameters"
[23]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/container-instance-draining.html?utm_source=chatgpt.com "Draining Amazon ECS container instances"
[24]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html?utm_source=chatgpt.com "How the Amazon ECS deployment circuit breaker detects ..."
[25]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-blue-green.html?utm_source=chatgpt.com "Amazon ECS blue/green deployments"
[26]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/canary-deployment.html?utm_source=chatgpt.com "Amazon ECS canary deployments"
[27]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-linear.html?utm_source=chatgpt.com "Amazon ECS linear deployments"
[28]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-lifecycle-hooks.html?utm_source=chatgpt.com "Lifecycle hooks for Amazon ECS service deployments"
[29]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/blue-green-deployment-implementation.html?utm_source=chatgpt.com "Required resources for Amazon ECS blue/green ..."
[30]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html?utm_source=chatgpt.com "Automatically scale your Amazon ECS service"
[31]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-autoscaling-targettracking.html?utm_source=chatgpt.com "Use a target metric to scale Amazon ECS services"
[32]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html?utm_source=chatgpt.com "Use service discovery to connect Amazon ECS ..."
[33]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect.html?utm_source=chatgpt.com "Use Service Connect to connect Amazon ECS ..."
[34]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect-concepts.html?utm_source=chatgpt.com "Amazon ECS Service Connect configuration overview"
[35]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html?utm_source=chatgpt.com "Pass sensitive data to an Amazon ECS container"
[36]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-logging-monitoring.html?utm_source=chatgpt.com "Logging and Monitoring in Amazon Elastic Container Service"
[37]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-container-insights.html?utm_source=chatgpt.com "Monitor Amazon ECS containers using Container Insights ..."
[38]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html?utm_source=chatgpt.com "Monitor Amazon ECS using CloudWatch"
[39]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html?utm_source=chatgpt.com "Monitor Amazon ECS containers with ECS Exec"
[40]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/CWE_IAM_role.html?utm_source=chatgpt.com "Amazon ECS EventBridge IAM Role - AWS Documentation"
[41]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec-troubleshooting.html?utm_source=chatgpt.com "Troubleshoot Amazon ECS Exec issues"
