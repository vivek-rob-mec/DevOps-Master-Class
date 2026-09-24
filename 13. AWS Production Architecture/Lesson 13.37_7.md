# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 7: Amazon Application Recovery Controller (ARC) Deep Dive

We have spent six parts building the technical recovery architecture.

Now imagine everything exists:

```text
Mumbai
──────
ALB             ✓
ECS             ✓
Aurora Primary  ✓
ECR             ✓
Secrets         ✓


Singapore
─────────
ALB               ✓
ECS Warm Standby  ✓
Aurora Secondary  ✓
ECR               ✓
Secrets           ✓
```

A serious incident begins.

The difficult question becomes:

> **Who coordinates database promotion, application scaling, validation, traffic movement, approvals, failback, and all the safety checks—in the correct order?**

That's where **Amazon Application Recovery Controller (ARC)** becomes important.

ARC currently includes both **Multi-Region recovery capabilities**—notably Region switch and routing control—and **Multi-AZ recovery capabilities** through zonal shift and zonal autoshift. ([AWS Documentation][1])

---

# 37.509 First: ARC is not one single feature

When someone says:

> "We're using ARC."

Ask:

> **Which ARC capability?**

Current mental model:

```text
                AMAZON ARC
                    │
       ┌────────────┴────────────┐
       │                         │
       ▼                         ▼

 MULTI-REGION                MULTI-AZ
 RECOVERY                    RECOVERY
       │                         │
       ├── Region Switch         ├── Zonal Shift
       │
       ├── Routing Control       └── Zonal Autoshift
       │
       └── Readiness Check*
```

And an important **2026 update**:

> ARC **Readiness Check is no longer open to new customers**. Existing customers can continue using it. ([AWS Documentation][2])

We'll still learn what it does because you'll encounter it in existing architectures and exams/interviews, but for new designs we should not architect as though every new account can enable it.

---

# 37.510 Why ARC exists

Without orchestration, your DR runbook might look like:

```text
Incident declared
       │
       ▼
Engineer opens document
       │
       ▼
Promote database
       │
       ▼
Scale ECS
       │
       ▼
Modify Auto Scaling
       │
       ▼
Change DNS
       │
       ▼
Run Lambda
       │
       ▼
Check health
       │
       ▼
Change another account
       │
       ▼
Hope nothing was skipped
```

For a complex application with many accounts and services, that becomes risky.

ARC Region switch provides a centralized mechanism to define recovery plans containing ordered workflows and execution blocks for those recovery actions. Plans can execute manually or be triggered automatically from CloudWatch alarms. ([AWS Documentation][3])

---

# 37.511 Region Switch mental model

Think of **ARC Region switch** as:

> **A recovery workflow orchestrator for a Multi-Region application.**

Architecture:

```text
                  ARC REGION SWITCH
                         │
                         ▼
                    RECOVERY PLAN
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
    DATA               COMPUTE           TRAFFIC
       │                 │                 │
Promote Aurora       Scale ECS       Routing Control
Promote RDS          Scale ASG       Route 53
Scale Aurora         Scale EKS
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
                     VALIDATION
                         │
                         ▼
                     DR ACTIVE
```

Region switch supports both **active/passive** and **active/active** Multi-Region approaches. Active/passive uses failover/failback terminology; active/active uses shift-away/return semantics. ([AWS Documentation][3])

---

# 37.512 Region Switch Plan

The central object is the:

# Region Switch Plan

You specify:

```text
Application:
payments

Regions:
ap-south-1
ap-southeast-1

Architecture:
active/passive

RTO:
for example 20 minutes

Recovery workflow:
defined steps
```

A plan then contains:

```text
PLAN
 │
 ├── Workflow
 │     │
 │     ├── Step 1
 │     ├── Step 2
 │     ├── Step 3
 │     └── Step 4
 │
 └── execution configuration
```

Region switch plans define workflows built from sequential **steps**, and each step may contain one or more **execution blocks** that can execute in parallel. ([AWS Documentation][3])

---

# 37.513 Workflow vs Step vs Execution Block

This terminology matters.

### Workflow

The overall recovery sequence.

```text
Mumbai → Singapore recovery
```

### Step

One ordered stage.

```text
Step 1
Promote data
```

### Execution Block

The actual action ARC performs.

For example:

```text
Aurora Global Database
failover operation
```

Mental model:

```text
PLAN
 │
 ▼
WORKFLOW
 │
 ├── STEP 1
 │     ├── Execution block A
 │     └── Execution block B
 │
 ├── STEP 2
 │     └── Execution block C
 │
 └── STEP 3
       └── Execution block D
```

Multiple execution blocks inside the same step can run in parallel, while steps themselves define ordered recovery stages. ([AWS Documentation][4])

---

# 37.514 Example production Region Switch Plan

Suppose our payment application uses:

```text
Aurora Global DB
ECS
Auto Scaling workers
Route 53
custom application validation
```

Plan:

```text
STEP 1 — DATA

Aurora Global Database
Mumbai → Singapore


STEP 2 — CAPACITY

Scale Singapore ECS
Scale worker ASGs


STEP 3 — APPLICATION VALIDATION

Invoke Lambda smoke test


STEP 4 — APPROVAL

Operator approves traffic shift


STEP 5 — TRAFFIC

Routing Control
Mumbai OFF
Singapore ON


STEP 6 — MONITOR

CloudWatch alarms
```

That is much safer than five engineers manually running unrelated scripts in different terminals.

---

# 37.515 Current Region Switch execution blocks

As of August 2026, AWS documents execution blocks for capabilities including:

```text
Child Region Switch plans

EC2 Auto Scaling scaling

EKS scaling

ECS service scaling

ARC routing controls

Aurora Global Database recovery

Aurora provisioned scaling

Aurora Serverless scaling

DocumentDB global cluster recovery

Neptune global database recovery

RDS read-replica promotion

RDS cross-Region replica creation

Manual approval

Custom Lambda action

Route 53 health-check traffic control

Lambda event-source mapping
```

That set is current service behavior and will evolve, so verify it when implementing a real recovery plan. ([AWS Documentation][5])

---

# 37.516 This directly solves our Part 4 ordering problem

Remember:

```text
BAD

Traffic shift
     ↓
DB still read-only
     ↓
ERROR
```

With a recovery workflow:

```text
GOOD

DATA
 ↓
CAPACITY
 ↓
VALIDATION
 ↓
APPROVAL
 ↓
TRAFFIC
```

That sequence is encoded as part of the recovery mechanism rather than remaining only in someone's head.

---

# 37.517 Graceful vs Ungraceful execution

Region switch distinguishes:

```text
GRACEFUL

planned operation
```

from:

```text
UNGRACEFUL

unplanned disaster recovery
```

For a graceful switch, both sides can cooperate.

Example:

```text
Mumbai healthy
Singapore healthy

planned game day
```

You can:

```text
wait for data
cleanly transition
perform orderly actions
```

For an ungraceful event:

```text
Mumbai impaired/unreachable
```

the workflow can skip or alter actions that depend on the failed Region. ([AWS Documentation][4])

---

# 37.518 Why this distinction matters

Imagine a planned database switchover.

You can tell Mumbai:

```text
stop accepting writes
synchronize
switch roles
```

But during a real Region outage:

```text
Mumbai X
```

you cannot depend on:

```text
"First ask Mumbai to cleanly shut down."
```

So recovery automation must understand:

```text
planned path
≠
disaster path
```

That's mature DR engineering.

---

# 37.519 Post-Recovery Workflow

Region switch also supports **post-recovery execution**.

Think:

```text
FAILOVER COMPLETE
       │
       ▼
Singapore active
       │
       ▼
Now prepare system
for the NEXT failure
```

Post-recovery actions can include creating replacement read replicas, custom Lambda actions, manual approvals, and child plans, depending on the workflow. ([AWS Documentation][4])

This is extremely important.

DR isn't finished at:

```text
Singapore serving traffic ✓
```

You may now have:

```text
no standby database
no secondary Region
degraded redundancy
```

So recovery should restore:

# Recovery readiness.

---

# 37.520 Parent Plans

Imagine your business consists of:

```text
Authentication

Payments

Orders

Inventory

Notifications
```

They cannot all recover in arbitrary order.

For example:

```text
Authentication
      ↓
Database/Core Services
      ↓
Payments
      ↓
Orders
      ↓
Notifications
```

Region switch allows **parent plans** that orchestrate multiple child plans in a required sequence. AWS currently limits the plan hierarchy to two levels—parent plus child—but one parent may coordinate multiple child plans. ([AWS Documentation][4])

---

# 37.521 Enterprise parent-plan example

```text
              ENTERPRISE RECOVERY PLAN

                        │
                        ▼
                 Shared Services
                        │
             ┌──────────┼──────────┐
             ▼          ▼          ▼

           Auth       Database    Network

                        │
                        ▼
                     Payments
                        │
                        ▼
                      Orders
                        │
                        ▼
                  Notifications
```

This solves an important problem:

> **Application recovery dependencies.**

---

# 37.522 Cross-account recovery

Production applications often aren't inside one AWS account.

For example:

```text
NETWORK ACCOUNT
Security/TGW/DNS


SHARED SERVICES ACCOUNT
Authentication


PROD ACCOUNT
Application


DATABASE ACCOUNT
Data services
```

Region switch can access application resources in other accounts through configured cross-account IAM roles, and Region switch plans themselves can be shared through AWS RAM. ([AWS Documentation][6])

So:

```text
Plan account
    │
execution role
    │
    ▼
cross-account role
    │
    ▼
Resource account
```

This aligns very well with the multi-account architecture we studied in Lesson 36.

---

# 37.523 IAM becomes mission-critical

Your recovery plan may need permission to:

```text
promote DB

scale ASG

update routing control

invoke Lambda

modify application resources
```

If the execution IAM role is missing:

```text
rds:PromoteReadReplica
```

or an equivalent required action:

```text
DR workflow stops.
```

That is why recovery permissions themselves must be:

```text
preconfigured
tested
monitored
```

not created during the incident.

---

# 37.524 Plan Evaluation

A major current Region switch capability is:

# Plan Evaluation

ARC evaluates a plan:

```text
when created

when updated

and then

every 30 minutes
during steady state
```

It checks things such as:

```text
IAM permissions

resource configuration

running capacity
```

and surfaces warnings when configuration might block recovery. ([AWS Documentation][4])

---

# 37.525 This detects DR drift

Imagine yesterday:

```text
Singapore ECS
max tasks = 100
```

Today someone changes it to:

```text
max tasks = 5
```

or IAM loses a permission.

Your recovery document may still say:

```text
DR READY
```

but the infrastructure is no longer ready.

Region switch plan evaluation provides ongoing checking of important plan/resource assumptions and can surface warnings through the console, API, and EventBridge. ([AWS Documentation][4])

---

# 37.526 But Plan Evaluation is NOT a DR test

This distinction is crucial.

Plan evaluation:

```text
permissions look correct ✓

configuration looks correct ✓

capacity looks plausible ✓
```

does not prove:

```text
application will successfully
process a payment after failover.
```

AWS explicitly recommends actually executing recovery tests rather than relying solely on plan evaluation. ([AWS Documentation][4])

Our rule remains:

> **Configuration validation is not runtime validation.**

---

# 37.527 Actual Recovery Time

Remember RTO?

Region switch can calculate an:

# Actual Recovery Time

for plan execution.

It combines the time for the recovery plan execution and, when configured, the additional time until specified regional application-health CloudWatch alarms return to healthy. ([AWS Documentation][7])

So you can compare:

```text
TARGET RTO

20 minutes
```

with:

```text
ACTUAL RECOVERY

16m 42s
```

or:

```text
ACTUAL RECOVERY

31m 08s
```

Now DR readiness becomes measurable.

---

# 37.528 Recovery report

Region switch can also automatically generate execution reports and place them in an S3 bucket.

Current reports can include:

```text
plan configuration

execution timeline

steps/resources/status

warnings

CloudWatch alarm state/history

child-plan information
```

This is useful for:

```text
DR evidence

audit

regulatory testing

post-incident analysis
```

AWS currently supports automatic PDF execution reports for Region switch plan runs. ([AWS Documentation][4])

---

# 37.529 CloudWatch-triggered Region Switch

Region switch plans can be:

```text
MANUAL
```

or triggered automatically using:

```text
CloudWatch alarms.
```

([AWS Documentation][3])

That creates:

```text
Application metric
       │
       ▼
CloudWatch Alarm
       │
       ▼
Region Switch Plan
       │
       ▼
Recovery workflow
```

But this must be designed with care.

---

# 37.530 The biggest automation danger

Suppose one buggy health metric enters:

```text
ALARM
```

and automatically triggers:

```text
database promotion
+
global traffic shift.
```

That can turn:

```text
monitoring bug
```

into:

```text
production disaster.
```

So we need safety layers.

---

# 37.531 Detect ≠ Decide ≠ Act

This is a valuable operations mental model.

```text
DETECT

Something looks wrong.

       ↓

DECIDE

Is this actually a disaster?

       ↓

ACT

Execute recovery.
```

Bad architecture:

```text
one failed health check
       ↓
promote entire DR Region
```

Better architecture may use:

```text
multiple signals

CloudWatch composite alarms

approval gates

data-safety validation

controlled automation
```

depending on the workload's RTO.

---

# 37.532 Manual Approval Execution Block

Region switch supports an explicit:

# Manual Approval

execution block. ([AWS Documentation][5])

Example:

```text
STEP 1
Prepare Singapore
       ↓

STEP 2
Promote database
       ↓

STEP 3
Smoke test
       ↓

STEP 4
MANUAL APPROVAL
       │
       ├── APPROVE
       │      ↓
       │   shift traffic
       │
       └── CANCEL
```

This gives you:

```text
automation speed
+
human control at risky boundary
```

---

# 37.533 Good place for approval gates

Approval before:

```text
data-writer promotion

global DNS movement

old-primary fencing override

failback
```

may be valuable for certain high-risk systems.

Meanwhile safe tasks such as:

```text
scale ECS

warm caches

run validation
```

can occur automatically before approval.

This reduces:

```text
manual toil
```

without blindly automating irreversible actions.

---

# 37.534 Custom Lambda Execution

Region switch can invoke Lambda functions as custom execution blocks. ([AWS Documentation][5])

That is useful when your recovery needs something application-specific:

```text
notify payment partner

verify custom database state

update SaaS allowlist

flip feature flags

pause batch jobs

run smoke tests
```

Architecture:

```text
Region Switch
     │
     ▼
Custom Lambda
     │
     ├── internal API
     ├── validation
     └── custom automation
```

---

# 37.535 Lambda should not become an untested magic script

Bad:

```text
recovery.py
```

written three years ago and never executed.

Good:

```text
version controlled

tested

idempotent

observable

safe to retry

least privilege
```

because recovery automation itself can fail.

The same distributed-system principles from Part 5 apply to recovery tooling.

---

# 37.536 Idempotent recovery actions

Suppose plan executes:

```text
Scale ASG to 20
```

and times out before receiving confirmation.

Retry should safely result in:

```text
desired capacity = 20
```

not:

```text
20 + 20 + 20
```

Similarly:

```text
create duplicate queue
send payment twice
modify DNS twice incorrectly
```

should not happen because of retry behavior.

Design recovery actions so retries are safe whenever possible.

---

# 37.537 Region Switch data plane resilience

An important design property:

Region switch has a **data plane in each Region** so plan execution doesn't need to depend on the Region that you're deactivating. ([AWS Documentation][3])

This addresses one of the biggest DR anti-patterns:

```text
Recovery mechanism
lives only in
the Region that failed.
```

That would be absurd.

Recovery control needs its own resilience.

---

# 37.538 ARC Routing Control

Region switch is orchestration.

Another ARC capability is:

# Routing Control

Routing control is closer to:

> **A highly available switch that says whether traffic should flow to a particular application cell/Region.**

Conceptually:

```text
Mumbai Routing Control
       │
      ON

Singapore Routing Control
       │
      OFF
```

Failover:

```text
Mumbai
ON → OFF

Singapore
OFF → ON
```

Routing controls integrate with Route 53 health checks and DNS records to redirect traffic. They do **not** independently monitor endpoint response time or service health; they are explicit on/off controls. ([AWS Documentation][8])

---

# 37.539 Routing Control is NOT a health monitor

Very important.

Routing control does not itself ask:

```text
Is Mumbai HTTP healthy?

Is DB healthy?

Is latency bad?
```

It says:

```text
Mumbai allowed to receive traffic?
ON / OFF
```

Think:

```text
MONITORING SYSTEM
      │
      ▼
DECISION
      │
      ▼
ROUTING CONTROL
      │
      ▼
Route 53 health state
      │
      ▼
DNS traffic
```

ARC explicitly distinguishes routing control from normal health monitoring. ([AWS Documentation][8])

---

# 37.540 Routing Control architecture

```text
                       USERS
                         │
                         ▼
                      Route 53
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼

          Mumbai                  Singapore
           ALB                      ALB
             ▲                       ▲
             │                       │
       Route53 Health          Route53 Health
           Check                   Check
             ▲                       ▲
             │                       │
      Routing Control A      Routing Control B
             │                       │
            ON                      OFF
```

Change the routing-control states:

```text
Mumbai OFF
Singapore ON
```

and the associated Route 53 health-check states influence the routing records. ([AWS Documentation][8])

---

# 37.541 Routing Control components

The core routing-control structure includes:

```text
ARC Cluster
   │
   ├── Control Panel
   │      │
   │      ├── Routing Control Mumbai
   │      └── Routing Control Singapore
   │
   └── Safety Rules
```

ARC routing controls are grouped into control panels, and an ARC cluster provides the highly available data plane used for reading/updating routing states. ([AWS Documentation][9])

---

# 37.542 Why ARC Cluster architecture is special

A routing-control ARC cluster has:

```text
FIVE
Regional endpoints
```

distributed across five AWS Regions. ARC maintains consensus for routing-control states across the cluster. ([AWS Documentation][10])

Architecture:

```text
        ARC ROUTING CONTROL CLUSTER

Region 1 endpoint
       │
Region 2 endpoint
       │
Region 3 endpoint
       │
Region 4 endpoint
       │
Region 5 endpoint
```

This is designed so your failover control doesn't depend on one normal Regional endpoint.

---

# 37.543 Why the data-plane API matters

AWS recommends using the **ARC routing-control data-plane API** for production failover rather than relying on the console. Your recovery tooling should be able to try the five cluster endpoints in rotation if one endpoint is unavailable. ([AWS Documentation][10])

This is an advanced but important rule:

> **During disaster recovery, prefer the highly resilient recovery data plane, not a convenience console workflow.**

---

# 37.544 Do not discover the endpoints during the disaster

Bad workflow:

```text
Region outage
     ↓
now call configuration API
to discover ARC endpoints
     ↓
configuration API unavailable?
```

AWS recommends keeping a local copy/bookmark or otherwise pre-recording the cluster endpoints and routing-control identifiers used during recovery. ([AWS Documentation][11])

Mental rule:

```text
Emergency information
must be available
BEFORE emergency.
```

---

# 37.545 Safety Rules

Here's one of the strongest ARC concepts.

Suppose:

```text
Mumbai     ON
Singapore  OFF
```

Engineer intends:

```text
Mumbai     OFF
Singapore  ON
```

But accidentally performs:

```text
Mumbai     OFF
Singapore  OFF
```

Now you've removed traffic from everywhere.

ARC routing control supports:

# Safety Rules

to prevent dangerous combinations of routing-control states. ([AWS Documentation][12])

---

# 37.546 Two Safety Rule types

Current routing-control safety rules are:

```text
ASSERTION RULE

and

GATING RULE
```

([AWS Documentation][12])

They solve different safety problems.

---

# 37.547 Assertion Rule

An **assertion rule** validates that a state condition remains true before allowing routing-control changes.

Classic example:

> At least one Region must remain ON.

```text
Allowed:

Mumbai ON
Singapore OFF


Allowed:

Mumbai OFF
Singapore ON


Allowed:

Mumbai ON
Singapore ON


BLOCKED:

Mumbai OFF
Singapore OFF
```

ARC documents this as a way to prevent a fail-open/no-active-cell scenario. ([AWS Documentation][12])

---

# 37.548 Why Assertion Rules are so valuable

Without the rule:

```text
Automation bug
      ↓
turn all Regions OFF
      ↓
GLOBAL OUTAGE
```

With the rule:

```text
Automation bug
      ↓
ARC evaluates rule
      ↓
state change rejected
```

That's what:

# Guardrail

really means.

Not merely:

```text
we wrote a warning in the runbook.
```

---

# 37.549 Gating Rule

A **gating rule** acts like a master switch controlling whether specified routing controls may be modified. ([AWS Documentation][12])

Example:

```text
AUTOMATION_ENABLED
       │
       ├── ON
       │    ↓
       │  automation may change
       │  regional routing
       │
       └── OFF
            ↓
          routing controls locked
```

Use case:

```text
incident commander decides:

"Disable automatic regional traffic changes."
```

Then:

```text
Gating Control = OFF
```

Now the automation cannot casually modify protected controls.

---

# 37.550 Gating Rule mental model

Think:

```text
             MASTER RECOVERY SWITCH
                      │
                 ON / OFF
                      │
            ┌─────────┴─────────┐
            ▼                   ▼

       Mumbai control      Singapore control
```

It doesn't directly route user traffic.

It controls whether changes to the target routing controls are permitted.

---

# 37.551 Safety rules can be overridden

Sometimes your safety rule itself blocks an action that is necessary during a genuine emergency.

ARC allows authorized operators to explicitly override specified safety rules when updating routing-control states through supported API/CLI operations. ([AWS Documentation][13])

This is a good safety design:

```text
NORMAL

guardrail enforced


EMERGENCY

explicit privileged override
```

rather than:

```text
delete guardrail permanently.
```

---

# 37.552 Routing Control vs Region Switch

This distinction must be crystal clear.

### Routing Control

Think:

```text
TRAFFIC SWITCH
```

Example:

```text
Mumbai ON/OFF
Singapore ON/OFF
```

### Region Switch

Think:

```text
RECOVERY ORCHESTRATOR
```

Example:

```text
promote DB
scale ECS
invoke Lambda
approval
change routing control
```

So:

```text
Routing Control
can be ONE STEP
inside
Region Switch
```

Region switch has a dedicated ARC routing-control execution block for this purpose. ([AWS Documentation][5])

---

# 37.553 Route 53 vs Routing Control vs Region Switch

This is interview gold.

```text
ROUTE 53
────────
DNS traffic routing


ARC ROUTING CONTROL
───────────────────
highly available explicit
ON/OFF control for traffic cells
using Route53 health checks


ARC REGION SWITCH
─────────────────
orchestrates the whole
Multi-Region recovery workflow
```

Do not answer:

> "ARC is basically DNS."

No.

---

# 37.554 Our complete recovery stack

```text
                     MONITORING
                         │
                    CloudWatch
                         │
                         ▼
                 REGION SWITCH PLAN
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼

           DATA        CAPACITY    VALIDATION
            │            │            │
         Aurora         ECS         Lambda
         Failover       ASG         Smoke test

                         │
                         ▼
                    APPROVAL GATE
                         │
                         ▼
                   ROUTING CONTROL
                         │
                         ▼
                      ROUTE 53
                         │
                         ▼
                        USERS
```

Now we're starting to look like a real production DR system.

---

# 37.555 Readiness Check — important 2026 status

Historically ARC Readiness Checks provided ongoing audits comparing recovery replicas across things such as:

```text
capacity

service quotas

configuration

version differences

routing policies
```

Existing customers can still use that capability. It runs ongoing resource-readiness assessments and can report `READY` or `NOT READY`. ([AWS Documentation][2])

However:

# **As of 2026, ARC Readiness Check is no longer available to new customers.**

Existing customers are grandfathered. ([AWS Documentation][2])

This is exactly why we verify current AWS services rather than learning only old certification diagrams.

---

# 37.556 How existing Readiness Check architecture works

For existing users, the classic model is:

```text
RECOVERY GROUP
      │
      ├── CELL: Mumbai
      │
      └── CELL: Singapore
             │
             ▼
        RESOURCE SETS

        ALBs
        ASGs
        databases
        etc.
             │
             ▼
       READINESS CHECK
```

A **cell** is a failure-containment replica such as a Region or AZ, and resource sets group comparable resources so ARC can audit readiness. ([AWS Documentation][2])

---

# 37.557 What Readiness Check was/is good at

Suppose:

```text
Mumbai ASG max:
100


Singapore ASG max:
10
```

or:

```text
Mumbai EBS:
1 TB


Singapore equivalent:
500 GB
```

or a quota differs.

Readiness Check can identify mismatches that might prevent the recovery environment from accepting failover load. ([AWS Documentation][2])

But it never meant:

```text
application transaction
was successfully tested.
```

Again:

```text
RESOURCE READINESS
≠
BUSINESS TRANSACTION READINESS.
```

---

# 37.558 New-customer mindset

For a new architecture in 2026, think more in terms of:

```text
Region Switch Plan Evaluation

CloudWatch health alarms

IaC drift detection

AWS Config / organizational controls

synthetic testing

capacity testing

game days
```

rather than assuming you will create new ARC Readiness Check resources.

Region switch plan evaluation is the newer ongoing plan validation mechanism we've just discussed. ([AWS Documentation][4])

---

# 37.559 Now switch scale: Multi-AZ ARC

Everything so far has mostly been:

```text
Mumbai Region
       X
        ↓
Singapore Region
```

But ARC also solves:

```text
One Availability Zone
inside Mumbai
becomes impaired.
```

This is where:

# Zonal Shift

and:

# Zonal Autoshift

enter.

ARC explicitly separates these Multi-AZ capabilities from its Multi-Region recovery features. ([AWS Documentation][14])

---

# 37.560 Zonal Shift

Imagine:

```text
                ap-south-1

        ┌──────────┼──────────┐
        ▼          ▼          ▼

      AZ-A        AZ-B       AZ-C
       ✓           X          ✓
```

You manually initiate:

# Zonal Shift

for a supported resource.

Traffic is shifted away from:

```text
AZ-B
```

toward healthy AZs in the **same Region**. ([AWS Documentation][15])

---

# 37.561 Zonal Shift is NOT regional DR

Memorize:

```text
ZONAL SHIFT

AZ-B
 ↓
AZ-A + AZ-C
```

versus:

```text
REGION SWITCH

Mumbai
 ↓
Singapore
```

Completely different failure scopes.

---

# 37.562 Why Zonal Shift is useful

Suppose:

```text
AZ-B has elevated network errors
```

but:

```text
ALB still sees enough targets
to continue sending some traffic there.
```

Your operations team may want:

```text
Stop using AZ-B NOW.
```

Zonal Shift provides an explicit mechanism to move supported resource traffic away from that AZ instead of waiting for every lower-level health mechanism to independently fail targets. ([AWS Documentation][15])

---

# 37.563 Currently supported Zonal Shift / Autoshift resource families

AWS currently lists support for:

```text
EC2 Auto Scaling groups

Amazon EKS

Application Load Balancers

Network Load Balancers
```

with resource-specific requirements and behaviors. ([AWS Documentation][16])

Because support has expanded over time, don't memorize that as a permanent exhaustive list.

Always check current supported resources before architecture implementation.

---

# 37.564 Capacity requirement for Zonal Shift

Here's the critical architecture rule.

Normal:

```text
AZ-A  33%
AZ-B  33%
AZ-C  33%
```

Shift away from AZ-B:

```text
AZ-A  50%
AZ-B   0%
AZ-C  50%
```

Can:

```text
AZ-A + AZ-C
```

handle the full workload?

If not:

```text
zonal shift succeeds

application overloads
```

That's not resilience.

---

# 37.565 Static stability principle

A strong Multi-AZ architecture should have enough capacity so the loss of one AZ doesn't immediately require a fragile emergency scale operation to survive.

Conceptually:

```text
3 AZ architecture

Normal:
~33% per AZ

But each surviving pair
must handle 100%
after one AZ is removed.
```

The exact capacity model depends on the application, but ARC zonal-autoshift guidance explicitly assumes the application is pre-scaled so it can continue operating after one AZ is removed. ([AWS Documentation][17])

---

# 37.566 Zonal Autoshift

Zonal Shift:

```text
YOU initiate.
```

Zonal Autoshift:

```text
AWS can initiate.
```

With Zonal Autoshift enabled, AWS can automatically shift supported resource traffic away from an AZ when internal AWS telemetry identifies a potential impairment affecting that AZ. ([AWS Documentation][18])

Architecture:

```text
AWS detects AZ impairment
        │
        ▼
ARC Zonal Autoshift
        │
        ▼
remove traffic from AZ
        │
        ▼
healthy AZs serve workload
```

---

# 37.567 Autoshift does not mean "AWS fixes my capacity"

Suppose:

```text
AZ-A capacity = 40%

AZ-B capacity = 40%

Total application demand = 80%
```

Autoshift removes AZ-B.

Remaining:

```text
AZ-A max = 40%

Demand = 80%
```

Traffic shift occurs correctly.

Application still collapses.

ARC cannot violate:

```text
CPU
memory
connection
quota
```

limits.

Capacity engineering is still your responsibility. ARC guidance explicitly expects workloads to be able to run with an AZ removed. ([AWS Documentation][17])

---

# 37.568 Practice Runs — one of the best ARC ideas

Before letting AWS automatically evacuate an AZ during a real incident, you want to know:

> Can my application actually survive without one AZ?

Zonal Autoshift therefore uses:

# Practice Runs.

AWS schedules regular practice runs that deliberately shift supported-resource traffic away from an AZ so you can verify your application behavior before a real autoshift. Practice runs are required when configuring zonal autoshift. ([AWS Documentation][18])

---

# 37.569 Current Practice Run behavior

AWS currently schedules practice runs roughly:

```text
weekly
```

and they run for approximately:

```text
30 minutes
```

when not blocked/interrupted. On-demand practice runs are also available. ([AWS Documentation][19])

That means resilience becomes:

```text
periodically exercised
```

instead of:

```text
assumed.
```

This matches the philosophy we've used throughout Lesson 37.

---

# 37.570 Outcome Alarm

A zonal-autoshift practice run requires at least one:

# Outcome Alarm

in CloudWatch. ([AWS Documentation][20])

Think:

```text
Practice Run
   │
shift AZ-B away
   │
   ▼
CloudWatch Outcome Alarm
   │
   ├── OK
   │     ↓
   │   application survives
   │
   └── ALARM
         ↓
       practice run fails/stops
```

You might monitor:

```text
5xx rate

latency

checkout success

CPU saturation

queue backlog
```

depending on the application.

---

# 37.571 Blocking Alarm

You can also configure optional:

# Blocking Alarms

These prevent a practice run from starting—or stop one already running—when the application is already in a condition where testing an AZ loss would be unsafe. ([AWS Documentation][20])

Example:

```text
Production already has:

High 5xx rate
      │
      ▼
Blocking Alarm = ALARM
      │
      ▼
DO NOT START
practice zonal shift
```

That's good chaos-engineering hygiene.

---

# 37.572 Outcome vs Blocking Alarm

Never confuse them.

```text
OUTCOME ALARM
─────────────
"Did losing the AZ
hurt the application?"


BLOCKING ALARM
──────────────
"Is now a bad time
to run the experiment?"
```

Very useful mental distinction.

---

# 37.573 Example Practice Run

Normal:

```text
AZ-A ✓
AZ-B ✓
AZ-C ✓
```

Practice:

```text
AZ-A ✓
AZ-B X intentionally
AZ-C ✓
```

Observe:

```text
HTTP 5xx?
latency?
database load?
CPU?
queue?
```

If healthy:

```text
SUCCEEDED
```

If the configured outcome alarm enters `ALARM`:

```text
FAILED
```

AWS reports practice-run outcomes so teams can adjust capacity/configuration before relying on autoshift. ([AWS Documentation][20])

---

# 37.574 ARC + FIS

Remember AWS Fault Injection Service?

During zonal-autoshift practice-run scheduling, ARC accounts for certain conflicting conditions; AWS currently documents that practice runs won't start or continue while an AWS FIS experiment is active in the relevant context. ([AWS Documentation][19])

Why?

You don't want:

```text
Chaos experiment #1
+
Chaos experiment #2
```

accidentally stacking into:

```text
real outage.
```

Experiment coordination is part of resilience engineering.

---

# 37.575 Zonal Shift vs Autoshift

| Capability          | Who triggers it?                            | Failure scope                   |
| ------------------- | ------------------------------------------- | ------------------------------- |
| **Zonal Shift**     | Operator                                    | AZ                              |
| **Zonal Autoshift** | AWS based on impairment telemetry           | AZ                              |
| **Region Switch**   | Operator or CloudWatch-triggered automation | Region                          |
| **Routing Control** | Operator/automation changes routing state   | Application cell/Region traffic |

([AWS Documentation][3])

This table is worth remembering.

---

# 37.576 Multi-AZ before Multi-Region

Imagine:

```text
AZ-B has impairment.
```

Bad response:

```text
Fail entire Mumbai Region
to Singapore immediately.
```

If your system can safely solve the issue using:

```text
Zonal Shift
```

then Regional DR may be unnecessarily disruptive.

Resilience escalation should roughly follow failure scope:

```text
INSTANCE
   ↓
AZ
   ↓
REGION
```

Use the smallest recovery action that safely resolves the problem.

---

# 37.577 Recovery escalation ladder

```text
Container fails
      │
      ▼
ECS/EKS replaces it


Instance fails
      │
      ▼
Auto Scaling


AZ impairment
      │
      ▼
Zonal Shift / Autoshift
+ Multi-AZ architecture


Region/application disaster
      │
      ▼
Region Switch / Routing Control
+ Multi-Region architecture
```

That's a powerful architecture mental model.

---

# 37.578 ARC does NOT create your recovery architecture

Very important.

ARC cannot compensate for:

```text
no secondary Region

no database replica

no spare capacity

no certificates

no secrets

no images

no IAM

bad networking
```

ARC can orchestrate:

```text
an architecture that already exists.
```

It does not magically create resilience from an unprepared workload.

---

# 37.579 Bad ARC design

```text
Singapore:

ALB          ✕
DB replica   ✕
Secret       ✕
ECR image    ✕
Capacity     ✕

But:

ARC Plan     ✓
```

When Mumbai fails:

```text
ARC perfectly orchestrates
a broken recovery environment.
```

Same rule as Route 53:

> **Recovery orchestration cannot replace recovery readiness.**

---

# 37.580 Strong ARC architecture

```text
                    APPLICATION

           ┌────────────┴────────────┐
           ▼                         ▼

        Mumbai                   Singapore
        Region                   Region

       Multi-AZ                 Multi-AZ

     AZ-A AZ-B AZ-C           AZ-A AZ-B AZ-C
       │                         │

 Zonal Shift                Zonal Shift
 Autoshift                  Autoshift

           \                   /
            \                 /
             ▼               ▼

               REGION SWITCH
                     │
                     ▼
             ROUTING CONTROL
                     │
                     ▼
                  Route53
```

Now resilience exists at:

```text
AZ layer
+
Region layer.
```

---

# 37.581 Example Payment Recovery Plan

Let's put everything together.

### Normal

```text
Mumbai
PRIMARY
100% traffic

Singapore
WARM STANDBY
```

Monitoring detects serious regional application outage.

### Recovery workflow

```text
STEP 1
CloudWatch alarm triggers plan

        ↓

STEP 2
Aurora Global Database
managed recovery toward Singapore

        ↓

STEP 3
Scale Singapore ECS
2 → 20

Scale workers
1 → 8

        ↓

STEP 4
Lambda validation

GET /health
DB write/read test
dependency test

        ↓

STEP 5
Manual Approval

Incident Commander:
APPROVE

        ↓

STEP 6
Routing Control

Mumbai     OFF
Singapore  ON

        ↓

STEP 7
Observe CloudWatch

        ↓

STEP 8
DR ACTIVE
```

Every piece of this sequence maps to current Region switch/routing-control capabilities. ([AWS Documentation][5])

---

# 37.582 Why traffic goes last

Because:

```text
database ready      ✓
capacity ready      ✓
application ready   ✓
operator approval   ✓
```

then:

```text
USERS → Singapore
```

This carries forward one of our most important Lesson 37 rules:

> **Traffic shifting is the final visible step of recovery, not the first.**

---

# 37.583 Active/Active ARC example

Normal:

```text
Mumbai      50%
Singapore   50%
```

Mumbai degrades.

Instead of:

```text
activate Singapore
```

Singapore is already active.

Region Switch can orchestrate:

```text
scale Singapore if required
       ↓
validate capacity
       ↓
routing control
       ↓
Mumbai OFF
       ↓
Singapore absorbs traffic
```

AWS calls this:

```text
SHIFT AWAY
```

rather than active/passive failover. ([AWS Documentation][3])

---

# 37.584 Region reintegration

Mumbai recovers.

Don't simply:

```text
Mumbai ON
```

immediately.

Plan:

```text
Verify infrastructure
       ↓
Verify data synchronization
       ↓
Scale Mumbai
       ↓
Run smoke tests
       ↓
Approval
       ↓
Reintroduce traffic
```

For active/active this is the:

```text
RETURN
```

workflow.

For active/passive it may be a:

```text
FAILBACK
```

workflow. ([AWS Documentation][3])

---

# 37.585 DR automation safety hierarchy

I want you to remember this pattern:

```text
MONITOR
   │
   ▼
DETECT
   │
   ▼
VALIDATE
   │
   ▼
PREPARE
   │
   ▼
SAFE DATA ACTION
   │
   ▼
APPROVAL / GUARDRAIL
   │
   ▼
TRAFFIC SHIFT
   │
   ▼
VERIFY
```

Not:

```text
Alarm
 ↓
Panic
 ↓
DNS change
```

---

# 37.586 ARC vs homemade scripts

Could you build a DR system yourself with:

```text
Lambda
Step Functions
CloudWatch
Route53
Bash
Terraform
```

Yes.

But then **you own**:

```text
orchestration

state

retries

cross-account execution

auditing

plan health

data-plane availability

traffic controls

approval logic
```

Region switch exists to provide a managed orchestration layer around many of these recovery operations. ([AWS Documentation][3])

That doesn't mean ARC is automatically required for every DR workload.

Simple systems may still use simpler mechanisms.

---

# 37.587 When ARC Region Switch is particularly compelling

Think:

```text
many recovery steps

multiple AWS services

several accounts

data promotion

compute scaling

manual approvals

complex failback

strong audit requirements

aggressive RTO
```

The more your runbook looks like:

```text
40 manual steps
across 5 accounts
```

the more orchestration becomes valuable.

---

# 37.588 When ARC may be overkill

Suppose:

```text
Static site

S3
CloudFront

simple secondary origin
```

and recovery logic is tiny.

You may not need a sophisticated Region switch workflow.

Architecture principle:

> Use complexity proportional to recovery complexity.

Not:

```text
"ARC exists,
therefore every workload needs ARC."
```

---

# 37.589 Interview question — What is ARC?

Strong answer:

> **Amazon Application Recovery Controller provides AWS capabilities for improving application recovery. Its Multi-Region capabilities include Region switch for orchestrating recovery workflows and routing control for highly available traffic-control overrides, while Multi-AZ capabilities include zonal shift and zonal autoshift for moving traffic away from impaired Availability Zones.** ([AWS Documentation][1])

That's much stronger than:

> "ARC is Route 53 failover."

---

# 37.590 Interview question — Routing Control vs health check?

Strong answer:

> **A routing control isn't an endpoint-health monitor. It is an explicit on/off traffic control whose state drives an associated Route 53 health check and DNS routing. External monitoring or operators decide when the routing-control state should change.** ([AWS Documentation][8])

---

# 37.591 Interview question — Why safety rules?

Answer:

> To prevent dangerous routing-state transitions during recovery, such as accidentally turning every Region off or allowing automation to modify protected routing controls.

Assertion rules enforce state invariants; gating rules provide a master switch over routing-control changes. ([AWS Documentation][12])

---

# 37.592 Interview question — Assertion vs Gating Rule

```text
ASSERTION RULE

"This condition must
remain true."

Example:
At least one Region ON.


GATING RULE

"Are these routing controls
allowed to change?"

Example:
Automation enabled/disabled.
```

That's the mental shortcut.

---

# 37.593 Interview question — Zonal Shift vs Region Switch

```text
ZONAL SHIFT

AZ problem
within one Region


REGION SWITCH

Multi-Region application
recovery orchestration
```

Zonal shift is manually initiated for supported resources, while Region switch runs defined Multi-Region recovery workflows. ([AWS Documentation][3])

---

# 37.594 Interview question — Zonal Shift vs Zonal Autoshift

```text
ZONAL SHIFT
=
you initiate.


ZONAL AUTOSHIFT
=
AWS initiates based on
its AZ impairment telemetry.
```

([AWS Documentation][14])

---

# 37.595 Interview question — Why practice runs?

Because automatic AZ evacuation is only safe if the application can actually survive the loss of an AZ.

Zonal Autoshift practice runs periodically remove an AZ from service for the resource and use configured CloudWatch alarms to evaluate whether the application remains healthy. ([AWS Documentation][20])

---

# 37.596 Interview trap — "ARC Readiness Checks should be enabled for every new workload."

That is now outdated.

As of 2026:

```text
Readiness Check
=
existing customers only
for new adoption purposes.
```

New customers cannot newly adopt ARC Readiness Check, although existing customers can continue using it. ([AWS Documentation][2])

That's exactly the kind of current service detail that distinguishes modern AWS knowledge from old course material.

---

# 37.597 Interview trap — "Routing Control automatically detects outages."

Wrong.

Routing control itself is an on/off mechanism, not an application monitor. ([AWS Documentation][8])

Your:

```text
monitoring
+
decision logic
```

determines whether and when its state changes.

---

# 37.598 Interview trap — "Region Switch guarantees the required compute appears."

No.

AWS specifically warns that Region switch compute-scaling execution blocks do not guarantee that requested compute capacity will actually be obtainable. Critical workloads requiring guaranteed recovery capacity should consider capacity-reservation strategies. ([AWS Documentation][5])

This brings us back to:

```text
capacity planning
```

from Parts 3–5.

---

# 37.599 Interview trap — "Plan evaluation proves DR works."

No.

It can identify plan/configuration issues.

But AWS still recommends executing actual recovery tests. ([AWS Documentation][4])

Never forget:

```text
PLAN VALID
≠
APPLICATION RECOVERS.
```

---

# 37.600 The ARC hierarchy to memorize

```text
                         ARC

                          │
          ┌───────────────┴───────────────┐
          │                               │
          ▼                               ▼

      MULTI-REGION                     MULTI-AZ

          │                               │
          ├── REGION SWITCH               ├── ZONAL SHIFT
          │       │                       │      manual
          │       ├── plans               │
          │       ├── workflows           └── ZONAL AUTOSHIFT
          │       ├── steps                      automatic
          │       └── execution blocks           + practice runs
          │
          └── ROUTING CONTROL
                  │
                  ├── cluster
                  ├── control panel
                  ├── routing controls
                  ├── Route53 health checks
                  └── safety rules
                        │
                        ├── assertion
                        └── gating
```

That is your core ARC mental map.

---

# 37.601 Never-forget ARC rules

```text
1.
ARC Region Switch orchestrates
Multi-Region recovery workflows.


2.
Routing Control is an explicit
traffic switch, not a health monitor.


3.
Routing controls influence Route 53
through associated health checks.


4.
Safety rules prevent dangerous
routing-state transitions.


5.
Assertion Rule =
condition must remain true.


6.
Gating Rule =
master permission switch.


7.
Region Switch can coordinate
data, compute, custom actions,
approvals, and traffic.


8.
Graceful recovery
≠
ungraceful disaster recovery.


9.
Plan evaluation checks readiness
assumptions but does not replace
actual recovery testing.


10.
Zonal Shift solves AZ-level issues.


11.
Zonal Autoshift lets AWS shift
away from an impaired AZ.


12.
Autoshift requires practice-run
readiness discipline.


13.
Surviving AZs/Regions must have
enough capacity.


14.
Readiness Check is no longer
open to new customers as of 2026.


15.
Recovery orchestration cannot
repair an unprepared architecture.
```

---

# 37.602 One final enterprise diagram

```text
                       GLOBAL USERS
                            │
                            ▼
                         Route53
                            │
                   ARC Routing Control
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼

         PRIMARY REGION              DR REGION
          ap-south-1               ap-southeast-1

          ┌─────────┐               ┌─────────┐
          │ AZ-A ✓  │               │ AZ-A ✓  │
          │ AZ-B ✓  │               │ AZ-B ✓  │
          │ AZ-C ✓  │               │ AZ-C ✓  │
          └─────────┘               └─────────┘
              │                           │
       Zonal Shift /               Zonal Shift /
         Autoshift                   Autoshift
              │                           │
              └─────────────┬─────────────┘
                            │
                            ▼
                  ARC REGION SWITCH
                            │
               ┌────────────┼─────────────┐
               ▼            ▼             ▼
             DATA         COMPUTE       CUSTOM
               │            │             │
            Aurora         ECS          Lambda
             RDS           ASG
                           EKS
               │            │             │
               └────────────┼─────────────┘
                            ▼
                     MANUAL APPROVAL
                            │
                            ▼
                     ROUTING CONTROL
                            │
                            ▼
                     TRAFFIC SHIFT
                            │
                            ▼
                       DR ACTIVE
```

Now you can see how all the concepts from Lessons 36 and 37 finally connect.

---

# ✅ Part 7 Complete

Lesson 37 progress:

```text
Part 1
HA vs DR + RTO/RPO                   ✓

Part 2
Backup & Restore                     ✓

Part 3
Pilot Light + Warm Standby           ✓

Part 4
Active/Passive Multi-Region          ✓

Part 5
Active/Active Multi-Region           ✓

Part 6
Multi-Region Data Layer              ✓

Part 7
Application Recovery Controller      ✓

Part 8
DR Automation / Testing / Chaos      NEXT

Part 9
Complete Multi-Region DR Capstone

Part 10
Final Revision / Interview Mastery
```

We are now roughly **70–75% through Lesson 37**.

# Next — Lesson 37, Part 8

## DR Automation, Game Days, Chaos Engineering & Recovery Validation

Next we'll stop merely **designing** DR and start proving it.

We'll build a production-grade testing ladder:

```text
LEVEL 1
Backup restore test

        ↓

LEVEL 2
Application smoke test

        ↓

LEVEL 3
AZ failure simulation

        ↓

LEVEL 4
Database failover drill

        ↓

LEVEL 5
Regional traffic evacuation

        ↓

LEVEL 6
Full Multi-Region game day

        ↓

LEVEL 7
Failback test
```

We'll bring together **AWS Fault Injection Service, ARC practice runs, synthetic monitoring, automated restore testing, controlled fault injection, GameDay runbooks, failure hypotheses, blast-radius controls, stop conditions, RTO/RPO measurement, database consistency validation, observability, incident roles, postmortems, and CI/CD-based DR validation**.

And we'll answer the most important resilience question of this lesson:

> **How do we intentionally break production-like systems safely enough to prove that our disaster-recovery design really works before an actual disaster does it for us?**

[1]: https://docs.aws.amazon.com/r53recovery/latest/dg/what-is-route53-recovery.html?utm_source=chatgpt.com "What is ARC? - Amazon Application Recovery Controller ..."
[2]: https://docs.aws.amazon.com/r53recovery/latest/dg/readiness-what-is.html "What is readiness check in Amazon Application Recovery Controller (ARC)? - Amazon Application Recovery Controller (ARC)"
[3]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch.html "Region switch in ARC - Amazon Application Recovery Controller (ARC)"
[4]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch-plans.html "About Region switch - Amazon Application Recovery Controller (ARC)"
[5]: https://docs.aws.amazon.com/r53recovery/latest/dg/working-with-rs-execution-blocks.html "Add execution blocks - Amazon Application Recovery Controller (ARC)"
[6]: https://docs.aws.amazon.com/r53recovery/latest/dg/cross-account-resources-rs.html?utm_source=chatgpt.com "Cross-account support in Region switch"
[7]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch-plans.html?utm_source=chatgpt.com "About Region switch - Amazon Application Recovery ..."
[8]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.about.html "About routing control - Amazon Application Recovery Controller (ARC)"
[9]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.html?utm_source=chatgpt.com "Routing control in ARC"
[10]: https://docs.aws.amazon.com/r53recovery/latest/dg/introduction-regions-routing.html?utm_source=chatgpt.com "AWS Region availability for routing control"
[11]: https://docs.aws.amazon.com/r53recovery/latest/dg/r53-recovery-guide.pdf.pdf?utm_source=chatgpt.com "Amazon Application Recovery Controller (ARC)"
[12]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.safety-rules.html "Creating safety rules for routing control - Amazon Application Recovery Controller (ARC)"
[13]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.override-safety-rule.html?utm_source=chatgpt.com "Overriding safety rules to reroute traffic"
[14]: https://docs.aws.amazon.com/r53recovery/latest/dg/multi-az.html "Use zonal shift and zonal autoshift to recover applications in ARC - Amazon Application Recovery Controller (ARC)"
[15]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-shift.html?utm_source=chatgpt.com "Zonal shift in ARC"
[16]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-shift.resource-types.html "Supported resources - Amazon Application Recovery Controller (ARC)"
[17]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.html?utm_source=chatgpt.com "How zonal autoshift and practice runs work"
[18]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.html?utm_source=chatgpt.com "Zonal autoshift in ARC"
[19]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.scheduled-practice-runs.html?utm_source=chatgpt.com "When ARC schedules, starts, and ends practice runs"
[20]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.alarms.html?utm_source=chatgpt.com "Alarms for practice runs"
