# AWS Masterclass — Lesson 35 Part 1

# Amazon ECS from First Principles

## Clusters, Task Definitions, Tasks, Services, Fargate, EC2, Managed Instances, Networking, IAM & Container Architecture

Until now, we have run containers locally:

```text
Dockerfile
   │
   ▼
docker build
   │
   ▼
Docker Image
   │
   ▼
docker run
   │
   ▼
Container
```

That works beautifully on one machine.

But production asks harder questions:

```text
Where does the container run?

What happens if the machine dies?

Who restarts the container?

How do I run 20 replicas?

How do I spread them across AZs?

How do I attach an ALB?

How does each container get AWS credentials?

How do I deploy a new image safely?

How do I scale?

Who manages the EC2 hosts?
```

That is the problem Amazon ECS solves.

AWS defines the core ECS objects as **task definition, cluster, task, and service**: the task definition is the application blueprint, a task is a running instantiation of that blueprint, and a service maintains a desired number of tasks. ([AWS Documentation][1])

---

# 1. ECS Mental Model

Burn this into memory:

```text
                   Amazon ECS

                       CLUSTER
                          │
                          ▼
                     ECS SERVICE
                          │
                  desiredCount = 3
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
        TASK            TASK            TASK
          │               │               │
          ▼               ▼               ▼
     Containers      Containers      Containers

                     created from

                  TASK DEFINITION
                       revision
```

And those tasks need some actual compute:

```text
                     ECS TASKS
                        │
        ┌───────────────┼─────────────────┐
        ▼               ▼                 ▼
     Fargate          ECS EC2       Managed Instances
```

A single ECS cluster can contain workloads backed by multiple ECS capacity models. ([AWS Documentation][2])

---

# 2. ECS Is an Orchestrator, Not a Container Runtime

Docker answers:

```text
How do I build/run this container?
```

ECS answers:

```text
Where should it run?

How many should exist?

What happens when one dies?

Which deployment should replace it?

Which network should it join?

Which IAM permissions should it receive?
```

So think:

```text
Docker
=
container technology


ECS
=
container orchestration/control plane
```

---

# 3. ECS Cluster

A cluster is the logical grouping in which ECS workloads run.

Example:

```text
production-cluster
│
├── todo-backend-service
├── payment-service
├── email-worker-service
└── nightly-report-task
```

Do **not** think:

```text
ECS cluster
=
one EC2 server.
```

A cluster is a logical orchestration boundary; its tasks can run on Fargate, ECS Managed Instances, EC2 capacity, or external infrastructure depending on configuration. ([AWS Documentation][2])

---

# 4. Cluster vs Kubernetes Cluster

Because you already know Kubernetes, map the mental models carefully:

```text
Kubernetes                       ECS
────────────────────────────────────────────

Cluster                         Cluster

Pod                             Task

Pod spec-ish configuration      Task Definition

Deployment / ReplicaSet         ECS Service

Container                       Container

Service                         ALB / Service Connect /
                                Cloud Map depending need

Node                            EC2 container instance
                                when using ECS on EC2
```

It is not a perfect 1:1 mapping.

But:

```text
ECS Task
≈
smallest schedulable
application unit
```

is a useful starting point.

---

# 5. Task Definition

The:

# Task Definition

is the blueprint.

AWS describes it as a JSON application blueprint containing one or more container definitions and related runtime parameters. ([AWS Documentation][3])

Think of:

```text
Task Definition
│
├── image
├── CPU
├── memory
├── ports
├── environment
├── secrets
├── logging
├── task IAM role
├── execution IAM role
├── network mode
├── volumes
├── health checks
└── multiple containers
```

Example:

```text
todo-api:17
```

means:

```text
family:
todo-api

revision:
17
```

---

# 6. Task Definition Revision

Suppose:

```text
todo-api:15
todo-api:16
todo-api:17
```

Every new registered configuration creates another revision.

Production service could run:

```text
todo-api:16
```

while you prepare:

```text
todo-api:17
```

Then deployment changes the service to revision 17.

This is very similar conceptually to:

```text
immutable application release
```

rather than editing running containers manually.

---

# 7. Task

A:

# Task

is a running instance of a task definition. ([AWS Documentation][3])

```text
Task Definition
todo-api:17
      │
      ├─────────┬─────────┐
      ▼         ▼         ▼
    Task A    Task B    Task C
```

If your task definition contains:

```text
nginx
+
node
+
log-router
```

then one ECS task can contain all three containers.

---

# 8. Task ≠ Container

This distinction is important.

```text
TASK
│
├── Container A
├── Container B
└── Container C
```

A task may contain:

```text
1 container

or

multiple tightly coupled containers
```

Much like a Kubernetes Pod can contain multiple containers.

---

# 9. Standalone Task

Sometimes you want:

```text
run job
→ complete
→ stop
```

Example:

```text
database migration

nightly report

one-time data import

thumbnail batch

maintenance script
```

Then use:

```text
RunTask
```

instead of creating a long-running ECS service.

---

# 10. Service

A:

# Service

maintains a desired number of tasks.

Suppose:

```text
desiredCount = 3
```

ECS attempts to maintain:

```text
Task 1
Task 2
Task 3
```

If Task 2 stops:

```text
Task 1      ✓
Task 2      X
Task 3      ✓
             │
             ▼
       ECS scheduler
             │
             ▼
       start replacement
             │
             ▼
Task 4      ✓
```

AWS explicitly defines ECS services this way: if a task stops, the scheduler launches a replacement to maintain the desired count. ([AWS Documentation][4])

---

# 11. Task vs Service

Use:

```text
TASK
```

when:

```text
run once
perform job
finish
```

Use:

```text
SERVICE
```

when:

```text
keep application running

maintain replicas

replace failed tasks

connect to load balancer

perform rolling deployment

autoscale
```

---

# 12. Example

Your backend API:

```text
Node.js Express
port 3002
```

should normally run as:

```text
ECS Service
```

because it must remain available.

A database migration:

```text
npm run migrate
```

should normally be:

```text
standalone ECS Task
```

because it should finish and exit.

---

# Part A — Container Definitions

# 13. Basic Container Definition

Conceptually:

```json
{
  "name": "todo-api",
  "image": "ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/todo-api:1.0.0",
  "essential": true,
  "portMappings": [
    {
      "containerPort": 3002,
      "protocol": "tcp"
    }
  ]
}
```

This tells ECS:

```text
run this image

container name = todo-api

port = 3002

if this essential container dies,
task health/lifecycle is affected
```

---

# 14. `essential`

Suppose task:

```text
Task
│
├── todo-api       essential=true
│
└── telemetry      essential=false
```

If:

```text
todo-api
```

dies:

```text
task cannot meaningfully continue.
```

But a nonessential helper can sometimes stop without requiring the whole task to be considered failed.

Essential-container health also participates in ECS task health calculation when task-definition health checks are configured. ([AWS Documentation][5])

---

# 15. Sidecar Pattern

A task can contain:

```text
┌────────────────────────────────┐
│ ECS Task                       │
│                                │
│  ┌──────────┐   ┌───────────┐ │
│  │ Node API │   │ FireLens  │ │
│  │          │   │ log router│ │
│  └──────────┘   └───────────┘ │
│                                │
└────────────────────────────────┘
```

Other sidecars might provide:

```text
telemetry collector

proxy

service mesh component

security agent

log router
```

Only group containers into one task when their lifecycle genuinely belongs together.

---

# 16. Container Dependencies

Suppose:

```text
migration/init container
must finish successfully
before application starts.
```

ECS supports dependency conditions including:

```text
START

COMPLETE

SUCCESS

HEALTHY
```

with conditions such as `SUCCESS` requiring the dependent container to finish with exit code 0, and `HEALTHY` waiting for its configured health check to pass. ([AWS Documentation][6])

Example:

```text
Init Container
      │
   SUCCESS
      │
      ▼
Node API
```

---

# 17. Health Check

Your task definition might include:

```json
"healthCheck": {
  "command": [
    "CMD-SHELL",
    "curl -f http://localhost:3002/health || exit 1"
  ],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 30
}
```

Important:

AWS notes that ECS evaluates health checks configured in the task definition; a Docker image health check not represented/overridden in the ECS container definition is not automatically treated as the ECS health check. ([AWS Documentation][7])

---

# 18. Three Different Health Questions

Later when ALB arrives, distinguish:

```text
Container health check
        │
        ▼
Is process healthy inside task?


ECS service health
        │
        ▼
Should task remain part of service?


ALB target health
        │
        ▼
Should user traffic be routed here?
```

These are connected but not identical.

This distinction solves many ECS troubleshooting incidents.

---

# Part B — ECS Compute Choices

# 19. Where Does a Task Actually Run?

ECS is control plane.

You still need:

```text
COMPUTE CAPACITY.
```

The main current AWS-managed choices we care about are:

```text
Fargate

ECS on EC2

ECS Managed Instances
```

AWS also supports external capacity, but we'll focus on the AWS-native production models. ([AWS Documentation][8])

---

# 20. AWS Fargate

Fargate means:

```text
You provide:
────────────

container image
CPU
memory
networking
IAM
task definition


AWS provides/manages:
────────────────────

worker infrastructure
host provisioning
host lifecycle
host scaling
```

AWS describes Fargate as running ECS containers without managing the underlying EC2 server fleet. ([AWS Documentation][9])

---

# 21. Fargate Architecture

```text
                  ECS Control Plane
                         │
                         ▼
                     ECS Service
                         │
                 desiredCount=3
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
      Fargate Task   Fargate Task   Fargate Task
          │              │              │
       AWS-managed infrastructure underneath
```

You do not:

```text
SSH into worker

patch worker OS

manage ECS agent

manage EC2 Auto Scaling group
```

for Fargate capacity.

---

# 22. Fargate Isolation

AWS states each Fargate task receives its own isolation boundary and does not share its underlying kernel, CPU resources, memory resources, or ENI with another task. ([AWS Documentation][9])

That is a major difference from classic EC2 task packing.

---

# 23. Fargate CPU/Memory

Fargate doesn't let you choose arbitrary combinations like:

```text
1.37 vCPU
6.42 GB
```

You select a supported matrix.

Current documented Fargate task sizes range from:

```text
0.25 vCPU
```

through large Linux configurations reaching:

```text
32 vCPU
```

with memory combinations determined by the selected CPU size; some larger task sizes require modern Fargate platform versions. ([AWS Documentation][10])

Examples:

```text
0.25 vCPU
→ 512 MiB / 1 GB / 2 GB


0.5 vCPU
→ 1–4 GB


1 vCPU
→ 2–8 GB


2 vCPU
→ 4–16 GB
```

and larger combinations continue beyond that. ([AWS Documentation][10])

---

# 24. Container CPU Units

In ECS:

```text
1024 CPU units
≈
1 vCPU
```

for task sizing/resource accounting. ([AWS Documentation][11])

So:

```text
256 units  ≈ 0.25 vCPU
512 units  ≈ 0.5 vCPU
1024 units ≈ 1 vCPU
2048 units ≈ 2 vCPU
```

Keep this conversion permanently.

---

# 25. Fargate Ephemeral Storage

Current Fargate tasks receive:

```text
20 GiB
```

of ephemeral storage by default, and supported task ephemeral storage can be increased up to:

```text
200 GiB.
```

([AWS Documentation][12])

Think:

```text
/container filesystem
temporary files
downloaded build/work files
scratch data
```

not:

```text
permanent database.
```

When the task disappears, you should not treat ephemeral task storage as durable business storage.

---

# 26. Need Persistent Shared Storage?

Evaluate:

```text
EFS
```

or application-specific durable AWS storage.

We will integrate EFS/EBS storage with ECS later.

---

# Part C — ECS on EC2

# 27. EC2 Capacity Model

Now:

```text
                    ECS Cluster
                        │
            ┌───────────┼────────────┐
            ▼           ▼            ▼
         EC2 A        EC2 B        EC2 C
            │           │            │
         tasks         tasks        tasks
```

You manage:

```text
instance type

AMI

OS patching

ECS agent lifecycle

Auto Scaling Group

capacity planning

instance draining

host security

instance utilization
```

ECS schedules containers onto that fleet.

---

# 28. Why Would Anyone Choose EC2?

Because you gain more control.

Examples:

```text
specialized EC2 instances

GPU

high-memory instances

storage-heavy instances

custom host configuration

special networking requirements

predictable sustained utilization

cost optimization through packing

Spot/RI/Savings Plan strategies
```

AWS notes EC2 capacity gives greater instance-level choice/control, while you remain responsible for managing that infrastructure. ([AWS Documentation][13])

---

# 29. Task Packing

Imagine:

```text
EC2:
8 vCPU
32 GB RAM
```

and each task needs:

```text
1 vCPU
4 GB RAM
```

ECS may place multiple tasks on one EC2 instance:

```text
EC2 instance
│
├── Task 1
├── Task 2
├── Task 3
├── Task 4
├── Task 5
└── ...
```

This can produce high host utilization.

But now you must manage:

```text
TASK scaling
+
EC2 capacity scaling
```

as two different layers.

---

# 30. ECS Service Scaling Is Not EC2 Scaling

Suppose:

```text
desired task count:
10 → 30
```

but cluster EC2 capacity can hold only:

```text
15 tasks.
```

Then:

```text
ECS wants 30
       │
       ▼
only capacity for 15
       │
       ▼
remaining tasks cannot be placed
```

You must also scale the container-instance fleet.

This is where:

# Capacity Providers

become important.

---

# Part D — Capacity Providers

# 31. Capacity Provider Mental Model

Instead of saying:

```text
run task on EC2
```

you can say:

```text
use this CAPACITY STRATEGY.
```

For example:

```text
ECS Service
     │
     ▼
Capacity Provider Strategy
     │
 ┌───┴─────────────┐
 ▼                 ▼
FARGATE        FARGATE_SPOT
```

or EC2/Managed Instances strategies.

AWS recommends capacity providers when you want richer capacity management than a basic launch-type selection. ([AWS Documentation][8])

---

# 32. `base` and `weight`

A capacity-provider strategy can describe:

```text
base
```

and:

```text
weight
```

Think:

```text
base
=
minimum number assigned
to one provider first


weight
=
relative distribution
after base is satisfied
```

Example conceptual strategy:

```text
FARGATE
base = 2
weight = 1

FARGATE_SPOT
weight = 3
```

Interpretation:

```text
first 2
→ Fargate

remaining capacity
→ roughly 1:3 distribution
   Fargate : Fargate Spot
```

Capacity provider strategies use these base/weight mechanics for placement. ([AWS Documentation][14])

---

# Part E — Fargate Spot

# 33. Fargate Spot

For workloads that can tolerate interruption:

```text
FARGATE_SPOT
```

can reduce compute cost.

Good candidates:

```text
workers

batch jobs

asynchronous processing

stateless horizontally scalable tasks

noncritical replicas
```

Not ideal for:

```text
single critical stateful replica

non-idempotent long operation

work that cannot restart
```

---

# 34. Interruption

AWS currently gives Fargate Spot tasks approximately a:

```text
2-minute interruption warning
```

before reclaiming the capacity; the interruption is surfaced through an ECS task state-change EventBridge event and `SIGTERM` is sent to the task. ([AWS Documentation][15])

Your application needs to handle:

```text
SIGTERM
     │
     ▼
stop accepting new work
     │
     ▼
finish/checkpoint if possible
     │
     ▼
exit gracefully
```

---

# 35. Never Put All Critical Capacity on Spot

Production pattern:

```text
Service desired = 10

4 Fargate On-Demand
6 Fargate Spot
```

can be safer than:

```text
10 Spot
```

for a customer-facing API.

Actual distribution depends on your availability and cost requirements.

---

# Part F — ECS Managed Instances

# 36. The Third Important Model

ECS Managed Instances gives you a middle ground:

```text
Fargate
        ← less infrastructure control

Managed Instances
        ← AWS manages EC2 infrastructure lifecycle
           but you can use broader EC2 instance capabilities

EC2 capacity
        ← maximum direct infrastructure control
```

AWS describes ECS Managed Instances as a fully managed ECS compute option using the broad EC2 instance portfolio while offloading infrastructure management to AWS. ([AWS Documentation][16])

---

# 37. Managed Instances Architecture

```text
                 ECS Service
                     │
                     ▼
            Managed Capacity Provider
                     │
                     ▼
              ECS determines need
                     │
                     ▼
         AWS provisions EC2 capacity
                     │
             ┌───────┴────────┐
             ▼                ▼
          EC2 host         EC2 host
             │                │
         multiple tasks   multiple tasks
```

AWS automatically handles capacity scaling and can consolidate workloads across instances to improve utilization. ([AWS Documentation][16])

---

# 38. Why Managed Instances Exists

Fargate is excellent for:

```text
simplicity
```

but you may need:

```text
specific EC2 families

hardware attributes

accelerators

instance-type selection

capacity reservations

different economics

more infrastructure capability
```

without wanting to own the complete node lifecycle.

Managed Instances lets capacity-provider configuration specify instance requirements, while ECS handles instance selection/provisioning. ([AWS Documentation][16])

---

# 39. Example

You could tell Managed Instances:

```text
I need approximately:

16–64 vCPU instances

x86_64

certain memory range

perhaps specific instance families
```

and ECS can choose matching EC2 capacity according to the provider's instance requirements. The current service also supports explicitly allowing/excluding instance types or families. ([AWS Documentation][17])

---

# 40. Managed Instances Packing

Unlike Fargate's per-task compute isolation model:

```text
Fargate
Task → dedicated Fargate resource
```

Managed Instances can place:

```text
multiple smaller tasks
```

on larger EC2 instances to improve utilization. AWS documents this as part of Managed Instances' infrastructure optimization behavior. ([AWS Documentation][16])

---

# 41. Fargate vs Managed Instances vs EC2

| Requirement                                    |            Fargate |        Managed Instances |          ECS on EC2 |
| ---------------------------------------------- | -----------------: | -----------------------: | ------------------: |
| Manage worker OS                               |                 No |       Mostly AWS-managed |             **Yes** |
| Choose broad EC2 hardware                      | Limited task sizes |                  **Yes** |             **Yes** |
| Manage ASG directly                            |                 No | No traditional ownership |             **Yes** |
| Task-level serverless feel                     |        **Highest** |                     High |               Lower |
| Host customization                             |                Low |                   Medium |         **Highest** |
| Packing control                                |                AWS | AWS-managed optimization | **Highest control** |
| Best starting point for ordinary stateless app |            **Yes** |                  Depends |             Depends |

The high-level operational distinction matches AWS's current ECS compute guidance: Fargate removes infrastructure management, EC2 gives direct host control, and Managed Instances provides AWS-managed infrastructure with broader EC2 capabilities. ([AWS Documentation][13])

---

# 42. Practical Selection Rule

Start with:

```text
FARGATE
```

when:

```text
ordinary web/API containers

small team

variable workload

don't want node operations

rapid production delivery
```

Consider:

```text
MANAGED INSTANCES
```

when:

```text
need broader EC2 instance selection

want infrastructure optimization

don't want to manage EC2 fleet lifecycle
```

Choose:

```text
ECS ON EC2
```

when you specifically require:

```text
maximum host control

custom node setup

advanced packing economics

specialized hardware/host requirements

existing EC2 operational model
```

---

# Part G — ECS Networking

# 43. Fargate Requires `awsvpc`

For Fargate:

```text
networkMode = awsvpc
```

is required. ([AWS Documentation][18])

This is one of the most important ECS networking concepts.

---

# 44. `awsvpc` Mental Model

Each Fargate task receives an ENI and private IP address. ([AWS Documentation][19])

Example:

```text
VPC
│
├── private subnet A
│      │
│      └── ECS Task
│           ENI
│           10.0.1.25
│
└── private subnet B
       │
       └── ECS Task
            ENI
            10.0.2.42
```

The task behaves much more like a first-class VPC network endpoint.

---

# 45. Security Group Per Task

Because the task has VPC networking, you can attach security groups.

Production architecture:

```text
Internet
   │
   ▼
ALB SG
allows 443 from internet
   │
   ▼
ALB
   │
   │ 3002
   ▼
ECS Task SG
allows 3002
ONLY FROM ALB SG
```

Not:

```text
0.0.0.0/0 :3002
```

---

# 46. Public vs Private Subnet

Preferred production architecture:

```text
PUBLIC SUBNETS
────────────────

ALB
NAT Gateway


PRIVATE SUBNETS
────────────────

ECS tasks
RDS
Redis
```

Then:

```text
Internet
   │
   ▼
ALB
   │
   ▼
private ECS task
```

Tasks usually do not need direct inbound internet exposure.

---

# 47. Outbound Access

Private Fargate task may need:

```text
pull image from ECR

send CloudWatch logs

call Secrets Manager

call external API
```

Options include:

```text
NAT Gateway

and/or

VPC endpoints
```

depending on destination.

We'll build the production VPC path in Part 2.

---

# 48. Public IP

Fargate tasks in a public subnet can optionally receive a public IP on their task ENI. ([AWS Documentation][19])

But for ordinary production APIs behind an ALB:

```text
private task IP
+
public ALB
```

is usually the cleaner security architecture.

---

# Part H — ECS IAM

# 49. The Most Important ECS IAM Distinction

There are two roles people constantly confuse:

```text
TASK EXECUTION ROLE

vs

TASK ROLE
```

Memorize:

```text
Execution Role
=
ECS infrastructure
needs permissions


Task Role
=
your application
needs permissions
```

AWS explicitly separates these roles this way. ([AWS Documentation][20])

---

# 50. Task Execution Role

Used by:

```text
ECS agent / Fargate infrastructure
```

for actions such as:

```text
pull image from private ECR

write container logs to CloudWatch

retrieve referenced secrets/config
```

depending on task configuration. ([AWS Documentation][21])

Common managed policy:

```text
AmazonECSTaskExecutionRolePolicy
```

is often the baseline.

---

# 51. Task Role

Used by:

```text
YOUR APPLICATION CODE
inside container.
```

Example:

```text
Node API
   │
   ▼
AWS SDK
   │
   ▼
S3:GetObject
```

Then:

```text
taskRoleArn
```

needs:

```text
s3:GetObject
```

for the required bucket.

AWS states that containers use the credentials associated with `taskRoleArn` for application AWS API calls. ([AWS Documentation][22])

---

# 52. Never Put Application Permissions in Execution Role

Bad thinking:

```text
App needs DynamoDB
      │
      ▼
give DynamoDBFullAccess
to execution role
```

Wrong boundary.

Correct:

```text
Execution role
→ ECR/logs/secrets needed by ECS


Task role
→ DynamoDB/S3/SQS needed by application
```

---

# 53. Avoid Static AWS Keys

Do not put:

```text
AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY
```

inside:

```text
Docker image

.env committed to Git

task definition plaintext
```

Use:

```text
Task Role
```

so AWS SDK credential resolution obtains temporary task credentials.

---

# Part I — Secrets

# 54. Ordinary Environment Variable

Fine for:

```text
NODE_ENV=production

PORT=3002

LOG_LEVEL=info
```

Not ideal for:

```text
DB_PASSWORD
API_KEY
JWT_PRIVATE_SECRET
```

---

# 55. Secrets Manager Integration

Task definition can reference:

```text
Secrets Manager

or
SSM Parameter Store
```

for sensitive values.

When ECS itself must resolve the referenced secret for injection, the task execution role needs the appropriate permissions. AWS explicitly documents this requirement for Secrets Manager-backed ECS task secrets. ([AWS Documentation][23])

---

# Part J — Production Todo Architecture

For your application, the target architecture becomes:

```text
                        Internet
                           │
                           ▼
                       Route 53
                           │
                           ▼
                       CloudFront
                           │
                           ▼
                          ALB
                      public subnets
                           │
                      HTTPS :443
                           │
                           ▼
                 ┌──────────────────┐
                 │ ECS Service      │
                 │ desiredCount=2+  │
                 └──────────────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
        Fargate Task A              Fargate Task B
        private subnet A            private subnet B
             │                           │
             │ Node.js :3002             │
             └─────────────┬─────────────┘
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
          MongoDB/RDS     SQS       Secrets Manager
                                           │
                                           ▼
                                          KMS

Image:
ECR
 │
 ▼
Task Execution Role
 │
 ▼
Task startup

Application:
Task Role
 │
 ▼
AWS services
```

For a stateless Node.js API, Fargate is a strong first production implementation because you can focus on the service/task architecture rather than maintaining container hosts. ([AWS Documentation][9])

---

# Part K — Minimal Task Definition

Example:

```json
{
  "family": "todo-api",

  "networkMode": "awsvpc",

  "requiresCompatibilities": [
    "FARGATE"
  ],

  "cpu": "512",
  "memory": "1024",

  "executionRoleArn":
    "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",

  "taskRoleArn":
    "arn:aws:iam::ACCOUNT_ID:role/todoApiTaskRole",

  "containerDefinitions": [
    {
      "name": "todo-api",

      "image":
        "ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/todo-api:1.0.0",

      "essential": true,

      "portMappings": [
        {
          "containerPort": 3002,
          "protocol": "tcp"
        }
      ],

      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        }
      ],

      "logConfiguration": {
        "logDriver": "awslogs",

        "options": {
          "awslogs-group": "/ecs/todo-api",
          "awslogs-region": "ap-south-1",
          "awslogs-stream-prefix": "ecs"
        }
      },

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
  ]
}
```

For Fargate, task-level CPU/memory are required and must use a supported combination, and `awsvpc` networking is mandatory. ([AWS Documentation][24])

---

# Part L — CLI Hands-On

Set:

```bash
export AWS_REGION=ap-south-1
export CLUSTER_NAME=todo-production
export TASK_FAMILY=todo-api
```

First:

```bash
aws sts get-caller-identity
```

---

# 56. Create Cluster

```bash
aws ecs create-cluster \
  --cluster-name "$CLUSTER_NAME" \
  --region "$AWS_REGION"
```

Verify:

```bash
aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --region "$AWS_REGION"
```

---

# 57. Register Task Definition

Save task definition as:

```text
task-definition.json
```

Then:

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region "$AWS_REGION"
```

List revisions:

```bash
aws ecs list-task-definitions \
  --family-prefix "$TASK_FAMILY" \
  --sort DESC \
  --region "$AWS_REGION"
```

Task definitions in `ACTIVE` state can be used to run tasks or create services. ([AWS Documentation][25])

---

# 58. Run One Standalone Fargate Task

Conceptually:

```bash
aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_FAMILY" \
  --launch-type FARGATE \
  --network-configuration \
  "awsvpcConfiguration={
    subnets=[subnet-PRIVATE_A],
    securityGroups=[sg-ECS_TASK],
    assignPublicIp=DISABLED
  }" \
  --region "$AWS_REGION"
```

This launches a task from the selected task-definition revision using Fargate capacity. `RunTask` also supports capacity-provider strategies if you use that model instead of directly specifying a launch type. ([AWS Documentation][26])

---

# 59. List Tasks

```bash
aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION"
```

Then:

```bash
aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks <TASK_ARN> \
  --region "$AWS_REGION"
```

Inspect:

```text
lastStatus

desiredStatus

healthStatus

taskDefinitionArn

containers

networkInterfaces

stoppedReason
```

---

# 60. The Most Important Debugging Field

Whenever a task won't start or unexpectedly stops:

```text
STOPPED REASON
```

is one of the first things you investigate.

Use:

```bash
aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].{
    LastStatus:lastStatus,
    StopCode:stopCode,
    StoppedReason:stoppedReason,
    Containers:containers[*].reason
  }' \
  --region "$AWS_REGION"
```

---

# Part M — Terraform Mental Model

A minimal production stack will eventually contain:

```text
aws_ecs_cluster

aws_ecs_task_definition

aws_ecs_service

aws_lb

aws_lb_target_group

aws_lb_listener

aws_security_group

aws_cloudwatch_log_group

aws_iam_role

aws_iam_role_policy

aws_ecr_repository
```

---

# 61. Cluster

```hcl
resource "aws_ecs_cluster" "main" {
  name = "todo-production"
}
```

---

# 62. Log Group

```hcl
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/todo-api"
  retention_in_days = 30
}
```

---

# 63. Task Definition

```hcl
resource "aws_ecs_task_definition" "api" {
  family = "todo-api"

  requires_compatibilities = [
    "FARGATE"
  ]

  network_mode = "awsvpc"

  cpu    = 512
  memory = 1024

  execution_role_arn =
    aws_iam_role.ecs_execution.arn

  task_role_arn =
    aws_iam_role.api_task.arn

  container_definitions = jsonencode([
    {
      name      = "todo-api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = "ap-south-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
```

---

# 64. Service Skeleton

```hcl
resource "aws_ecs_service" "api" {
  name = "todo-api"

  cluster =
    aws_ecs_cluster.main.id

  task_definition =
    aws_ecs_task_definition.api.arn

  desired_count = 2

  launch_type = "FARGATE"

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
}
```

An ECS service then maintains that desired number of task-definition instances. ([AWS Documentation][4])

We deliberately haven't attached the ALB yet.

That is Part 2.

---

# Part N — Common Failures

# 65. Task Stuck in `PENDING`

Think:

```text
image pull?

network?

capacity?

IAM?

CPU/memory incompatible?

subnet IP exhaustion?

ECR connectivity?

secret retrieval?
```

Don't immediately assume:

```text
ECS is broken.
```

---

# 66. `CannotPullContainerError`

Investigate:

```text
image URI correct?

tag exists?

execution role has ECR permissions?

task can reach ECR endpoints?

NAT or VPC endpoints available?

private registry auth?
```

Remember:

```text
ECR pull
=
EXECUTION ROLE responsibility
```

rather than the application task role. ([AWS Documentation][27])

---

# 67. `ResourceInitializationError`

Typical categories include:

```text
CloudWatch Logs

Secrets Manager

SSM Parameter Store

networking

ECR

KMS
```

Ask:

```text
What resource was ECS trying
to initialize BEFORE
my application started?
```

This is different from:

```text
application itself crashed.
```

---

# 68. Application Gets `AccessDenied` Calling S3

If container is already running and:

```text
Node.js SDK → S3
```

fails:

check:

```text
TASK ROLE
```

not execution role. ([AWS Documentation][22])

---

# 69. Logs Never Appear

Check:

```text
awslogs configured?

log group exists?

execution role?

region correct?

network connectivity?

container starts long enough?
```

CloudWatch log delivery from the container runtime is an execution-role concern. ([AWS Documentation][27])

---

# 70. Task Keeps Restarting

If service:

```text
desiredCount=2
```

and application immediately crashes:

```text
start
  X
replace
  X
replace
  X
...
```

ECS service is doing exactly what you asked:

```text
maintain desiredCount.
```

Investigate:

```text
container exit code

application logs

health checks

missing environment variables

database connection

wrong command

port mismatch
```

---

# 71. Container Is Healthy but Task Is Unhealthy

Remember ECS task health is influenced by essential containers that have ECS-defined health checks. One essential unhealthy container can make the overall task unhealthy. ([AWS Documentation][5])

Inspect every:

```text
essential=true
```

container.

---

# 72. Fargate Configuration Rejected

Example:

```text
CPU = 256

Memory = 8192
```

invalid combination.

Fargate CPU/memory must match AWS's supported task-size matrix. ([AWS Documentation][10])

---

# 73. Running Out of Temporary Disk

Check Fargate:

```text
ephemeral storage
```

If your workload downloads:

```text
large ML model

video assets

temporary archives

build artifacts
```

20 GiB default may be insufficient.

You can configure up to 200 GiB of task ephemeral storage. ([AWS Documentation][12])

---

# Part O — Certification / Interview Scenarios

# 74. Scenario

> Run containers without managing EC2 instances.

Answer:

```text
ECS + Fargate
```

([AWS Documentation][9])

---

# 75. Scenario

> Need direct control over ECS worker instance type, AMI and host configuration.

Answer:

```text
ECS on EC2
```

---

# 76. Scenario

> Need broad EC2 instance selection but don't want to own underlying fleet lifecycle.

Modern answer:

```text
ECS Managed Instances
```

([AWS Documentation][16])

---

# 77. Scenario

> Web API must always have four replicas.

Think:

```text
ECS Service
desiredCount=4
```

not four manually launched standalone tasks. ([AWS Documentation][4])

---

# 78. Scenario

> Run one database migration and exit.

Think:

```text
Standalone ECS Task
```

rather than a service.

---

# 79. Scenario

> App container needs to read S3.

Answer:

```text
Task Role
```

not Task Execution Role. ([AWS Documentation][20])

---

# 80. Scenario

> ECS needs to pull private image from ECR.

Think:

```text
Task Execution Role
```

([AWS Documentation][21])

---

# 81. Scenario

> Fargate task must have network connectivity.

Answer includes:

```text
awsvpc
```

because Fargate requires it. ([AWS Documentation][18])

---

# 82. Scenario

> Need one task with app + log-router sidecar.

Use:

```text
one Task Definition
with multiple containerDefinitions
```

and define:

```text
essential
dependencies
health checks
```

appropriately.

---

# 83. Scenario

> Need 100,000 short asynchronous workers with interruption tolerance and cost sensitivity.

Consider:

```text
Fargate Spot
```

with:

```text
idempotency
checkpointing
graceful SIGTERM
retryable queue
```

because Spot capacity can be reclaimed with an interruption warning. ([AWS Documentation][15])

---

# 84. Scenario

> One Fargate Spot task gets interruption notification.

You have roughly:

```text
2 minutes
```

and ECS sends the task state-change notification plus `SIGTERM`. ([AWS Documentation][15])

Your container should not ignore termination handling.

---

# 85. Permanent ECS Object Model

```text
                         ECS CLUSTER

                             │
                             ▼
                           SERVICE
                             │
                     desiredCount = N
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
          TASK             TASK             TASK
            │                │                │
        containers       containers       containers
            ▲                ▲                ▲
            └────────────────┼────────────────┘
                             │
                       TASK DEFINITION
                         family:revision


                         CAPACITY

              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
           Fargate      Managed Instances   EC2


                          NETWORK

                           awsvpc
                             │
                             ▼
                        Task ENI/IP
                             │
                             ▼
                     Security Groups


                            IAM

             ┌───────────────┴───────────────┐
             ▼                               ▼
      Execution Role                      Task Role
             │                               │
             ▼                               ▼
      ECS infrastructure                Application
      ECR / logs / secrets              S3 / SQS / DDB
```

---

# 86. 30 ECS Rules to Burn Into Memory

```text
1. ECS orchestrates containers.

2. A cluster is a logical workload boundary.

3. A task definition is an application blueprint.

4. Task definitions are revisioned.

5. A task is a running task-definition instance.

6. A task can contain multiple containers.

7. A service maintains a desired number of tasks.

8. A standalone task runs independently and may exit.

9. Web APIs normally belong in ECS services.

10. Jobs/migrations often belong in standalone tasks.

11. Fargate removes EC2 worker management.

12. ECS on EC2 gives maximum host control.

13. Managed Instances is the middle operational model.

14. Fargate uses supported CPU/memory combinations.

15. 1024 ECS CPU units ≈ 1 vCPU.

16. Fargate defaults to 20 GiB ephemeral storage.

17. Fargate ephemeral storage can reach 200 GiB.

18. Fargate requires awsvpc networking.

19. Fargate tasks receive their own ENI.

20. Tasks can have security groups.

21. Prefer private tasks behind a public ALB.

22. Execution Role is for ECS infrastructure actions.

23. Task Role is for application AWS API calls.

24. Never put static AWS keys in the container image.

25. Use Secrets Manager/SSM for sensitive configuration.

26. `essential=true` affects task lifecycle/health.

27. Container dependencies can model startup ordering.

28. Health checks belong in task definitions deliberately.

29. Fargate Spot workloads must tolerate interruption.

30. Container scaling and infrastructure capacity
    are different concerns.
```

---

# ✅ Lesson 35 Part 1 Complete

You now understand:

```text
✓ Amazon ECS first principles
✓ Docker vs ECS responsibilities

✓ ECS clusters
✓ task definitions
✓ revisions
✓ tasks
✓ standalone tasks
✓ ECS services
✓ desired count

✓ multi-container tasks
✓ essential containers
✓ sidecars
✓ dependencies
✓ ECS health checks

✓ Fargate
✓ Fargate isolation
✓ CPU/memory sizing
✓ CPU units
✓ ephemeral storage

✓ ECS on EC2
✓ task packing
✓ host management
✓ two-layer scaling

✓ capacity providers
✓ base
✓ weight
✓ Fargate Spot
✓ interruption behavior

✓ ECS Managed Instances
✓ managed EC2 capacity
✓ instance requirements
✓ workload consolidation
✓ Fargate vs Managed Instances vs EC2

✓ awsvpc
✓ ENIs
✓ task IPs
✓ task security groups
✓ public/private subnet architecture

✓ Task Execution Role
✓ Task Role
✓ ECR permissions
✓ application permissions
✓ Secrets Manager integration

✓ CLI cluster/task workflow
✓ Terraform skeleton
✓ production Todo architecture
✓ troubleshooting
✓ certification scenarios
```

# Next — Lesson 35 Part 2

# **ECS + ALB Production Networking, Services, Health Checks & Zero-Downtime Deployments**

Now we'll turn the individual ECS tasks into a real highly available production service:

```text
                         Internet
                            │
                            ▼
                         Route 53
                            │
                            ▼
                         HTTPS
                            │
                            ▼
                           ALB
                 public subnet A/B
                            │
                    Target Group
                            │
                 ┌──────────┴──────────┐
                 ▼                     ▼
          ECS Task — AZ A       ECS Task — AZ B
          private subnet        private subnet
                 │                     │
                 └──────────┬──────────┘
                            ▼
                        Application
```

We'll go deeply into **ALB target groups with `ip` targets, listeners, ACM/TLS, security-group chaining, container/host ports, dynamic registration, ECS service scheduling, health-check grace periods, minimum/maximum healthy percentages, rolling deployments, ECS deployment circuit breaker, automatic rollback, blue/green and linear/canary deployment strategies, service revisions/deployment history, lifecycle shutdown and connection draining, container stop timeout, SIGTERM handling, ECS Exec, service discovery, Cloud Map, Service Connect, Terraform, and a zero-downtime deployment lab for your Node.js backend.**

[1]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html?utm_source=chatgpt.com "What is Amazon Elastic Container Service?"
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/clusters.html?utm_source=chatgpt.com "Amazon ECS clusters - Amazon Elastic Container Service"
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html?utm_source=chatgpt.com "Amazon ECS task definitions"
[4]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html?utm_source=chatgpt.com "Amazon ECS services - Amazon Elastic Container Service"
[5]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/healthcheck.html?utm_source=chatgpt.com "Determine Amazon ECS task health using container ..."
[6]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDependency.html?utm_source=chatgpt.com "ContainerDependency - Amazon Elastic Container Service"
[7]: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-ecs-taskdefinition-healthcheck.html?utm_source=chatgpt.com "ECS::TaskDefinition HealthCheck - AWS CloudFormation"
[8]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/capacity-launch-type-comparison.html?utm_source=chatgpt.com "Amazon Amazon ECS launch types and capacity providers"
[9]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html?utm_source=chatgpt.com "Architect for AWS Fargate for Amazon ECS"
[10]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html?utm_source=chatgpt.com "Amazon ECS task definition parameters for Fargate"
[11]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/capacity-tasksize.html?utm_source=chatgpt.com "Best practices for Amazon ECS task sizes"
[12]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-storage.html?utm_source=chatgpt.com "Fargate task ephemeral storage for Amazon ECS"
[13]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-configuration.html?utm_source=chatgpt.com "Architect your solution for Amazon ECS"
[14]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/asg-capacity-providers.html?utm_source=chatgpt.com "Amazon ECS capacity providers for EC2 workloads"
[15]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-capacity-providers.html?utm_source=chatgpt.com "Amazon ECS clusters for Fargate"
[16]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ManagedInstances.html?utm_source=chatgpt.com "Architect for Amazon ECS Managed Instances"
[17]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/managed-instances-instance-types.html?utm_source=chatgpt.com "Amazon ECS Managed Instances instance types"
[18]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_TaskDefinition.html?utm_source=chatgpt.com "TaskDefinition - Amazon Elastic Container Service"
[19]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html?utm_source=chatgpt.com "Amazon ECS task networking options for Fargate"
[20]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-ecs-iam-role-overview.html?utm_source=chatgpt.com "IAM roles for Amazon ECS"
[21]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html?utm_source=chatgpt.com "Amazon ECS task execution IAM role - AWS Documentation"
[22]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_RegisterTaskDefinition.html?utm_source=chatgpt.com "RegisterTaskDefinition - Amazon Elastic Container Service"
[23]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html?utm_source=chatgpt.com "Pass Secrets Manager secrets through Amazon ECS ..."
[24]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html?utm_source=chatgpt.com "Amazon ECS task definition differences for Fargate"
[25]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-definition-state.html?utm_source=chatgpt.com "Amazon ECS task definition states"
[26]: https://docs.aws.amazon.com/cli/latest/reference/ecs/run-task.html?utm_source=chatgpt.com "run-task — AWS CLI 2.36.14 Command Reference"
[27]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security-iam-roles.html?utm_source=chatgpt.com "Best practices for IAM roles in Amazon ECS"
