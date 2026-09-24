# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 10: Final Revision + Decision Matrix + SAA/DOP + Senior Interview Mastery

This is the **final part of Lesson 37**.

The goal now is not to add another hundred services.

The goal is to make this entire lesson retrievable from your head under:

```text
Exam pressure

Interview pressure

Production incident pressure

Architecture-design pressure
```

By the end, when somebody gives you:

```text
RTO
RPO
failure scope
data type
traffic model
cost requirement
```

you should be able to derive the architecture rather than guess the AWS service.

---

# 37.830 The entire Lesson 37 in 30 seconds

Memorize this first:

```text
                       RESILIENCE

                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼

                HA                   DR

         keep operating       recover workload
         through failures     after disaster

                 │                   │
              Multi-AZ           RTO + RPO
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼

               BACKUP           STANDBY          ACTIVE/
               RESTORE                           ACTIVE

                    │
              ┌─────┴─────┐
              ▼           ▼

          PILOT LIGHT   WARM STANDBY
```

And underneath all of them:

```text
BACKUPS
+
REPLICATION
+
AUTOMATION
+
TRAFFIC CONTROL
+
TESTING
+
FAILBACK
```

AWS's current Reliability Pillar still frames DR around business-defined RTO/RPO and the strategies **backup and restore, pilot light, warm standby, and multi-site active/active**. ([AWS Documentation][1])

---

# 37.831 RTO vs RPO — never confuse them again

## RTO

# Recovery Time Objective

Question:

> How long can the service remain unavailable?

```text
FAILURE
10:00
  │
  │ downtime
  │
  ▼
10:15
SERVICE RESTORED

RTO = 15 minutes
```

AWS defines RTO as the maximum acceptable delay between interruption and restoration. ([AWS Documentation][1])

---

## RPO

# Recovery Point Objective

Question:

> How much recent data can we afford to lose?

```text
Last usable recovery point
09:55
   │
   │ potential data loss
   ▼
10:00
FAILURE

RPO = 5 minutes
```

AWS defines RPO as the maximum acceptable age of the last recovery point relative to the interruption. ([AWS Documentation][1])

---

# 37.832 Permanent shortcut

```text
RTO
=
TIME TO RECOVER


RPO
=
DATA WE CAN LOSE
```

Or:

```text
RTO → TIME

RPO → POINT IN DATA HISTORY
```

---

# 37.833 RTO/RPO interview translation

Business:

> "Service must return within 30 minutes and at most 2 minutes of transactions can be lost."

You immediately translate:

```text
RTO = 30 minutes

RPO = 2 minutes
```

Then you design.

Do **not** begin with:

```text
Aurora?

DynamoDB?

Route 53?

ARC?
```

First:

```text
BUSINESS REQUIREMENT
        ↓
RTO / RPO
        ↓
FAILURE SCOPE
        ↓
ARCHITECTURE
        ↓
AWS SERVICES
```

AWS recommends choosing recovery objectives from business impact rather than arbitrarily selecting overly strict or overly loose targets. ([AWS Documentation][2])

---

# 37.834 Availability vs Disaster Recovery

## High Availability

Question:

> Can the workload continue operating when a component fails?

Examples:

```text
EC2 fails
→ ASG replaces

ECS task fails
→ ECS replaces

AZ fails
→ workload continues in other AZs

DB instance fails
→ Multi-AZ failover
```

---

## Disaster Recovery

Question:

> How do we restore the workload after a larger disruptive event?

Examples:

```text
data corruption

major environment loss

Region-level outage

cyberattack

catastrophic operator error
```

AWS explicitly distinguishes availability—which focuses on component resilience over normal operations—from DR, which focuses on recovering copies of an entire workload after disaster events. ([AWS Documentation][3])

---

# 37.835 Never-forget

```text
HA
=
CONTINUE


DR
=
RECOVER
```

And:

```text
Multi-AZ
is usually HA


Multi-Region
is commonly used for
regional DR / global resilience
```

But they work together.

---

# 37.836 Correct resilience hierarchy

```text
                APPLICATION FAILURE

                      │
                      ▼
               ECS / ASG / EKS

                      │

                   AZ LOSS

                      │
                      ▼
                  Multi-AZ
             Zonal Shift/Autoshift

                      │

                 REGION LOSS

                      │
                      ▼
              Multi-Region DR
             Region Switch / DNS

                      │

              LOGICAL DATA LOSS

                      │
                      ▼
                Backup / PITR
```

A Region-level recovery mechanism should not be your first response to one dead container.

---

# 37.837 The four classic DR strategies

```text
BACKUP & RESTORE
       ↓
PILOT LIGHT
       ↓
WARM STANDBY
       ↓
MULTI-SITE ACTIVE/ACTIVE
```

As you move right/down:

```text
more infrastructure already running

generally lower recovery time potential

higher steady-state cost

higher operational complexity
```

AWS's current Well-Architected guidance identifies active/active as the most operationally complex classic DR strategy and recommends using it only when business requirements justify that complexity. ([AWS Documentation][4])

---

# 37.838 Master DR strategy comparison

| Strategy         | What exists in DR normally? | Disaster action        | Relative steady-state cost |               Relative recovery effort |
| ---------------- | --------------------------- | ---------------------- | -------------------------: | -------------------------------------: |
| Backup & Restore | Backups + IaC               | Build + restore        |                     Lowest |                                Highest |
| Pilot Light      | Critical core/data          | Start/deploy + scale   |                        Low |                                   High |
| Warm Standby     | Complete reduced stack      | Scale + switch         |                Medium/high |                                  Lower |
| Active/Active    | Full active stacks          | Evacuate failed Region |                    Highest | Low activation, high design complexity |

AWS describes Warm Standby as a **scaled-down but fully functional** workload in another Region, while Pilot Light requires additional infrastructure/app activation during recovery. ([AWS Documentation][5])

---

# 37.839 Backup & Restore

Normal:

```text
PRIMARY

████████████


DR

Backups
Terraform
Artifacts
```

Disaster:

```text
Restore data
    ↓
Deploy infrastructure
    ↓
Deploy application
    ↓
Validate
    ↓
Shift traffic
```

Use when:

```text
longer RTO acceptable

lower criticality

steady-state DR cost must be low

rebuild automation is strong
```

---

# 37.840 Pilot Light

Normal:

```text
PRIMARY
████████████


DR
██
```

Keep things such as:

```text
data replication
network foundation
IAM
critical core
artifacts
```

ready.

Then:

```text
deploy/start remaining stack
       ↓
scale
       ↓
traffic
```

---

# 37.841 Warm Standby

Normal:

```text
PRIMARY
████████████


DR
████
```

Complete application is already functional.

Example:

```text
Mumbai
20 ECS tasks


Singapore
2 ECS tasks
```

Failure:

```text
Singapore
2 → 20
```

then traffic shifts.

AWS specifically describes Warm Standby as a continuously running scaled-down workload. ([AWS Documentation][4])

---

# 37.842 Hot Standby

If Warm Standby runs at:

```text
full production capacity
```

it becomes:

```text
HOT STANDBY
```

Conceptually:

```text
Primary
████████████

Secondary
████████████
```

but secondary may still receive little/no normal customer traffic.

AWS uses this terminology in its current DR strategy guidance. ([AWS Documentation][4])

---

# 37.843 Active/Active

```text
             USERS

       ┌───────┴───────┐
       ▼               ▼

    Mumbai          Singapore

    ACTIVE            ACTIVE
```

When Mumbai fails:

```text
Mumbai X

Singapore absorbs
surviving traffic
```

But:

> Active/active compute is not automatically active/active data.

That distinction separates beginner from senior architecture thinking.

---

# 37.844 Strategy decision shortcut

Use this mental tree:

```text
What RTO is acceptable?
        │
        ├── Hours+
        │      ↓
        │ Backup & Restore
        │
        ├── Tens of minutes / hours
        │      ↓
        │ Pilot Light
        │
        ├── Minutes
        │      ↓
        │ Warm Standby
        │
        └── Extremely aggressive
               ↓
           Active/Active
```

This is conceptual, not a promise of exact RTO ranges.

Actual recovery time depends on the application, data layer, automation, capacity, validation, and client behavior. AWS likewise recommends selecting the pattern according to measured workload objectives rather than fixed memorized times. ([AWS Documentation][3])

---

# 37.845 Bonus current AWS option — Elastic Disaster Recovery

A modern AWS architect should also know:

# AWS Elastic Disaster Recovery — DRS

AWS currently positions Elastic Disaster Recovery as an alternative for workloads where you might otherwise evaluate Pilot Light or Warm Standby. AWS's Well-Architected guidance notes continual block-level replication with RPO measured in seconds and recovery time potentially measured in minutes while keeping only replication resources running in the recovery Region until recovery is initiated. ([AWS Documentation][4])

Mental model:

```text
Source servers
     │
continuous replication
     ▼
low-cost staging resources
in recovery Region
     │
     │ disaster
     ▼
launch recovery environment
```

Very useful for:

```text
legacy EC2/server workloads

lift-and-shift DR

VM-based environments

applications that are difficult
to redesign as cloud-native
```

---

# 37.846 Multi-AZ vs Multi-Region

## Multi-AZ

```text
AWS REGION
│
├── AZ-A
├── AZ-B
└── AZ-C
```

Protect against:

```text
instance
rack
facility/AZ-level
failure classes
```

---

## Multi-Region

```text
Region A
    │
    │ replication
    ▼
Region B
```

Adds protection for:

```text
Region-level recovery requirements
```

AWS advises first building appropriate availability within Regions, then selecting Multi-Region recovery when workload requirements justify it. ([AWS Documentation][3])

---

# 37.847 Biggest architecture mistake

Do not build:

```text
bad single-AZ application
      │
      ▼
duplicate into two Regions
```

You now have:

```text
two fragile applications.
```

First:

```text
instance resilience
      ↓
Multi-AZ
      ↓
backup
      ↓
Multi-Region
```

---

# 37.848 Replication vs Backup

This may be the single most important data lesson.

## Replication

```text
current state
     │
     ▼
another copy
```

Useful mainly for:

```text
availability
location failure
fast recovery
```

---

## Backup

```text
current state
     │
     ▼
historical recovery points
```

Useful for:

```text
corruption
bad deployment
accidental deletion
ransomware
historical recovery
```

AWS explicitly says that continuous replication alone doesn't necessarily protect against corruption or destruction and recommends maintaining point-in-time backup capability as well. ([AWS Documentation][4])

---

# 37.849 Never-forget example

Developer:

```sql
DELETE FROM customers;
```

Replication:

```text
Mumbai:
customers deleted

     ↓ replicate

Singapore:
customers deleted
```

Replication succeeded perfectly.

DR failed logically.

You need:

```text
Backup / PITR
```

to recover historical state.

---

# 37.850 Redundancy vs replication vs backup

```text
REDUNDANCY
=
another resource can serve


REPLICATION
=
copy state elsewhere


BACKUP
=
historical recovery state
```

Use all three deliberately.

---

# 37.851 Active/Passive vs Active/Active

## Active/Passive

```text
Mumbai
ACTIVE

Singapore
PASSIVE / STANDBY
```

Failure:

```text
promote/activate Singapore
```

Simpler:

```text
writer ownership
traffic
operations
```

---

## Active/Active

```text
Mumbai
ACTIVE

Singapore
ACTIVE
```

Failure:

```text
evacuate Mumbai
```

But introduces:

```text
distributed consistency

capacity sharing

session management

idempotency

conflict resolution

deployment blast radius
```

AWS specifically warns that Multi-site Active/Active carries the highest operational complexity of the classic DR strategies. ([AWS Documentation][4])

---

# 37.852 The "active/active what?" interview trick

If interviewer says:

> "The application is active/active."

Ask mentally:

```text
Traffic?
Compute?
Reads?
Writes?
Database?
Queues?
Tenants?
```

Because this is possible:

```text
HTTP traffic        ACTIVE/ACTIVE

Compute             ACTIVE/ACTIVE

Database reads      ACTIVE/ACTIVE

Database writes     SINGLE WRITER
```

And it's a perfectly valid architecture.

---

# 37.853 Active/active data levels

```text
LEVEL 1

Both Regions serve users.
One Region owns all writes.


LEVEL 2

Both Regions serve users.
Reads local.
Writes central.


LEVEL 3

Both Regions write
different customer/data shards.


LEVEL 4

Both Regions can write
the same logical dataset.
```

Complexity generally increases as you approach Level 4.

---

# 37.854 Data architecture decision matrix

| Requirement                                                | Strong AWS candidate          |
| ---------------------------------------------------------- | ----------------------------- |
| Relational + one write Region + global reads/DR            | Aurora Global Database        |
| Traditional relational RDS DR                              | Cross-Region RDS read replica |
| Multi-active key-value/document                            | DynamoDB Global Tables        |
| Multi-active DynamoDB with eventual consistency            | MREC                          |
| Multi-active DynamoDB with strong cross-Region consistency | MRSC                          |
| Distributed active-active relational SQL                   | Aurora DSQL                   |
| Cross-Region object replication                            | S3 CRR                        |
| Shared NFS filesystem DR                                   | EFS replication               |
| EC2 block-volume restore                                   | EBS snapshots/copies          |
| Historical centralized backup                              | AWS Backup                    |

Aurora Global Database currently uses one primary write Region with up to ten read-only secondary Regions, while DynamoDB Global Tables provide multi-Region, multi-active replication. ([AWS Documentation][6])

---

# 37.855 Aurora Global Database

Mental model:

```text
Mumbai
PRIMARY WRITER
    │
    │ async
    ▼
Singapore
SECONDARY
READ
```

Current Aurora Global Database architecture has one primary write Region and up to ten secondary Regions. ([AWS Documentation][6])

Use when:

```text
SQL relational model

one authoritative writer

global read locality

fast regional DR
```

---

# 37.856 Aurora Global failover

When primary Region fails:

```text
Mumbai
   X

Singapore
SECONDARY
    │
    ▼
FAILOVER
    │
    ▼
PRIMARY
```

AWS recommends **managed failover** for DR; when the old Region becomes available again, Aurora can bring it back into the global database as a secondary. ([AWS Documentation][7])

---

# 37.857 Aurora write forwarding

```text
Singapore app
       │
       ▼
Singapore secondary
       │
       │ forward
       ▼
Mumbai primary
       │
       ▼
actual write
```

Never forget:

```text
WRITE FORWARDING
≠
INDEPENDENT MULTI-WRITER
```

The authoritative write still occurs at the primary cluster. ([AWS Documentation][8])

---

# 37.858 RDS cross-Region replica

Mental model:

```text
Mumbai RDS
PRIMARY
   │
   │ replicate
   ▼
Singapore replica
READ
```

Failure:

```text
promote replica
      ↓
independent writable DB
```

Useful when you don't need Aurora's Global Database architecture but still require running cross-Region relational standby capacity.

---

# 37.859 DynamoDB Global Tables

Mental model:

```text
Mumbai
READ + WRITE
      │
      ↕
Singapore
READ + WRITE
```

DynamoDB Global Tables provide multi-Region, multi-active replicas. ([AWS Documentation][9])

Now distinguish:

```text
MREC

vs

MRSC
```

---

# 37.860 MREC

# Multi-Region Eventual Consistency

Writes are asynchronously replicated across Regions, typically very quickly, but another Region can temporarily observe an older value. MREC is currently the default Global Tables consistency mode if you don't explicitly select another. ([AWS Documentation][10])

Mental model:

```text
Mumbai writes v2
      │
      │ asynchronous
      ▼
Singapore temporarily v1
      │
      ▼
eventually v2
```

Benefits:

```text
lower local write latency

flexible multi-active topology
```

Trade-off:

```text
temporary stale remote state
+
concurrent-write conflict semantics
```

---

# 37.861 MRSC

# Multi-Region Strong Consistency

Current DynamoDB Global Tables also support MRSC.

AWS requires exactly three participating Regions in one of these forms:

```text
3 replicas

or

2 replicas + 1 witness
```

and documents zero RPO for the MRSC architecture. ([AWS Documentation][11])

Mental model:

```text
Replica A
   \

    distributed
    coordination

   /
Replica B

   +

Witness / third replica
```

Trade-off:

```text
stronger consistency
↔
higher coordination latency / constraints
```

AWS's own guidance notes MRSC has stronger guarantees but somewhat higher write latency than MREC. ([AWS Documentation][12])

---

# 37.862 Do not say this anymore

Outdated:

> "DynamoDB Global Tables are always eventually consistent between Regions."

Correct in 2026:

```text
Global Tables
      │
      ├── MREC
      │    eventual
      │
      └── MRSC
           strong
```

([AWS Documentation][10])

---

# 37.863 Aurora DSQL

Aurora DSQL is a different architecture from Aurora Global Database.

Current Multi-Region Aurora DSQL provides two Regional endpoints that represent a single logical distributed database and can concurrently serve reads and writes with strong consistency. A witness Region participates in the architecture but has no client endpoint. ([AWS Documentation][13])

Mental model:

```text
Region A
READ + WRITE
     \
      \
       ONE LOGICAL
       DISTRIBUTED DB
      /
     /
Region B
READ + WRITE

      +
Witness
```

AWS describes Aurora DSQL as an active-active serverless distributed relational database. ([AWS Documentation][14])

---

# 37.864 Aurora Global vs Aurora DSQL

| Area                         | Aurora Global Database            | Aurora DSQL                      |
| ---------------------------- | --------------------------------- | -------------------------------- |
| Relational                   | Yes                               | Yes                              |
| Traditional writer model     | One primary Region                | Active-active Regions            |
| Secondary Region             | Read-oriented                     | Read/write                       |
| Replication model            | Async global secondary            | Distributed strong consistency   |
| Traditional promotion needed | Yes                               | Not same primary/secondary model |
| Best mental model            | Global relational DR/read scaling | Distributed relational system    |

Current AWS documentation clearly treats these as distinct database architectures. ([AWS Documentation][6])

---

# 37.865 How to choose MREC vs MRSC

Ask:

```text
Can users tolerate
brief stale reads?
```

If yes:

```text
MREC may fit.
```

Ask:

```text
Do we require latest committed
state across Regions
and are willing to accept
stronger coordination constraints?
```

Then:

```text
evaluate MRSC.
```

Do not choose strong consistency merely because:

```text
"strong sounds safer."
```

AWS recommends choosing based on consistency, latency, availability, topology, and business requirements. ([AWS Documentation][15])

---

# 37.866 Multi-writer conflict problem

Initial:

```text
status = PENDING
```

Mumbai writes:

```text
status = PAID
```

Singapore writes:

```text
status = CANCELLED
```

Now:

```text
Which one wins?
```

In eventually consistent multi-writer systems, application/domain semantics matter.

Never treat:

```text
replication convergence
```

as equivalent to:

```text
correct business result.
```

---

# 37.867 Idempotency — mandatory mental model

Payment request:

```text
Idempotency-Key:
PAY-1001
```

Mumbai processes it.

Response times out.

Client retries to Singapore.

Expected:

```text
PAY-1001
was already processed

→ don't charge again
```

Never rely on:

```text
"the network won't retry."
```

Distributed systems retry.

---

# 37.868 Session-state rule

Never place critical customer workflow state only inside:

```text
one ECS task's RAM.
```

Because:

```text
task dies

or Region changes
```

and state disappears.

Use appropriate:

```text
durable state

replicated state

stateless/signed token patterns

workflow state store
```

depending on the workload.

---

# 37.869 Traffic-layer decision matrix

Now the most commonly confused services:

| Tool                | Mental model                                    |
| ------------------- | ----------------------------------------------- |
| Route 53            | DNS routing                                     |
| Global Accelerator  | Static anycast network entry + endpoint routing |
| ARC Routing Control | Explicit resilient ON/OFF traffic control       |
| ARC Region Switch   | Recovery workflow orchestration                 |
| CloudFront          | CDN / edge HTTP content delivery                |
| ALB                 | Regional Layer-7 load balancing                 |

AWS Well-Architected lists Route 53, ARC, Global Accelerator, and CloudFront among valid mechanisms for Multi-Region traffic failover depending on the workload. ([AWS Documentation][16])

---

# 37.870 Route 53

Use when you need:

```text
DNS-based routing
```

including:

```text
failover
weighted
latency
geolocation
```

For active/passive:

```text
payments.example.com
      │
      ├── PRIMARY → Mumbai
      └── SECONDARY → Singapore
```

Route 53 supports health-check-driven active/passive and active-active DNS failover patterns. ([AWS Documentation][17])

---

# 37.871 Route 53 weakness to remember

DNS routing involves:

```text
resolver caching

client caching

TTL

new connection behavior
```

DNS changes don't teleport existing TCP connections.

So:

```text
DNS failover
≠
instant relocation
of all existing sessions
```

---

# 37.872 Global Accelerator

Use when you value:

```text
stable global IP addresses

network-level endpoint steering

TCP/UDP global traffic

customer firewall allowlisting

reduced dependency on DNS changes
```

Global Accelerator currently provides two static anycast IPv4 addresses for an IPv4 accelerator, advertised from the AWS edge network. ([AWS Documentation][18])

Architecture:

```text
Client
  │
  ▼
Static Anycast IPs
  │
  ▼
Global Accelerator
  │
 ┌┴─────────────┐
 ▼              ▼
Mumbai       Singapore
```

---

# 37.873 Route 53 vs Global Accelerator

## Route 53

```text
DNS answer changes
```

## Global Accelerator

```text
client keeps using
same accelerator IPs

AWS changes healthy backend routing
```

So a strong interview answer is:

> Route 53 is DNS-based global routing, while Global Accelerator provides stable anycast IP entry points and health-aware network routing toward Regional endpoints.

([AWS Documentation][19])

---

# 37.874 ARC Routing Control

Think:

```text
TRAFFIC SWITCH
```

Example:

```text
Mumbai
ON

Singapore
OFF
```

Failover:

```text
Mumbai
OFF

Singapore
ON
```

ARC Routing Control uses highly available routing-control state to drive Route 53 DNS failover, and ARC exposes five Regional routing-control cluster endpoints for resilient data-plane operations. ([AWS Documentation][20])

---

# 37.875 ARC Region Switch

Think:

```text
RECOVERY ORCHESTRATOR
```

Not merely DNS.

Example:

```text
DB recovery
    ↓
scale compute
    ↓
Lambda validation
    ↓
manual approval
    ↓
routing control
```

This is the right mental separation:

```text
Route 53
=
WHERE TRAFFIC GOES


Routing Control
=
SHOULD THIS REGION RECEIVE TRAFFIC?


Region Switch
=
WHAT RECOVERY STEPS HAPPEN AND IN WHAT ORDER?
```

---

# 37.876 ARC current 2026 note

ARC **Readiness Check** is no longer open to new customers; existing customers can continue using it. AWS's document history says the new-customer closure took effect April 30, 2026. ([AWS Documentation][21])

So for new architectures, don't build your entire design assumption around newly adopting ARC Readiness Check.

---

# 37.877 ARC Multi-AZ decision matrix

| Capability      | Scope               | Trigger                  |
| --------------- | ------------------- | ------------------------ |
| Zonal Shift     | AZ                  | Operator                 |
| Zonal Autoshift | AZ                  | AWS impairment telemetry |
| Region Switch   | Region/application  | Operator or automation   |
| Routing Control | Cell/Region traffic | Operator/automation      |

AWS has continued expanding zonal-shift capabilities across supported resource families. ([AWS Documentation][22])

---

# 37.878 Zonal Shift

Scenario:

```text
AZ-A ✓
AZ-B X
AZ-C ✓
```

Action:

```text
remove workload traffic
from AZ-B
```

without moving the whole application to another Region.

Remember:

```text
AZ problem
→ Zonal Shift

Region problem
→ Regional recovery
```

---

# 37.879 Zonal Autoshift

Difference:

```text
Zonal Shift
=
you initiate


Zonal Autoshift
=
AWS can initiate
based on AZ impairment signals
```

But application capacity must be capable of operating without that AZ.

---

# 37.880 Capacity is part of DR

Suppose:

```text
Mumbai 50%
Singapore 50%
```

Then Mumbai fails.

Singapore suddenly needs:

```text
100%
```

If Singapore max capacity is:

```text
60%
```

then traffic failover succeeds while the application fails.

Architecture:

```text
TRAFFIC CAPACITY
+
COMPUTE CAPACITY
+
DATABASE CAPACITY
+
QUOTAS
```

must all survive the intended failure.

AWS specifically highlights recovery capacity considerations for standby strategies and recommends capacity reservations where suitable for workloads requiring guaranteed EC2 capacity. ([AWS Documentation][4])

---

# 37.881 AWS Backup vs replication

AWS Backup:

```text
historical recovery control
```

Global replication:

```text
continuity / geographic copy
```

Use both where needed.

AWS recommends explicitly testing the DR implementation, managing DR-site drift, and automating recovery. ([AWS Documentation][3])

---

# 37.882 Restore testing

The hierarchy:

```text
BACKUP JOB SUCCESS
       │
       ▼
RECOVERY POINT EXISTS
       │
       ▼
RESTORE SUCCEEDS
       │
       ▼
APPLICATION WORKS
```

The last box is what matters.

AWS's current DR guidance recommends regularly testing the recovery implementation rather than assuming that a backup or design is sufficient. ([AWS Documentation][3])

---

# 37.883 FIS vs Game Day vs Resilience Hub

## AWS FIS

Think:

```text
FAULT INJECTION ENGINE
```

Use to deliberately create controlled faults.

---

## Game Day

Think:

```text
PEOPLE
+
PROCESS
+
TECHNOLOGY
```

AWS recommends regular game days so teams practice actual operational recovery processes. ([AWS Documentation][23])

---

## AWS Resilience Hub

Think:

```text
ASSESS
RTO/RPO posture
+
recommend improvements/tests
```

AWS Resilience Hub's FIS experiments are built on AWS FIS actions. ([AWS Documentation][24])

---

# 37.884 Permanent testing model

```text
Resilience Hub
     │
     ▼
ASSESS


AWS FIS
     │
     ▼
BREAK


Game Day
     │
     ▼
PRACTICE


CloudWatch
     │
     ▼
OBSERVE


RTO/RPO
     │
     ▼
MEASURE
```

---

# 37.885 The DR evidence ladder

Weakest:

```text
"We have a diagram."
```

Better:

```text
"We have Terraform."
```

Better:

```text
"We have a standby."
```

Better:

```text
"We tested failover."
```

Better:

```text
"We measured RTO/RPO."
```

Best:

```text
"We regularly test
failover + failback
and remediate findings."
```

AWS's Reliability Pillar recommends exercising resiliency tests regularly and conducting game days as an ongoing engineering practice. ([AWS Documentation][23])

---

# 37.886 Failover vs failback

## Failover

```text
Primary
   X
   │
   ▼
Recovery Region
```

## Failback

```text
Recovery Region
        │
        ▼
Restored original Region
```

Never plan only:

```text
A → B
```

You also need:

```text
B → A
```

or:

```text
B remains primary
and A becomes new standby.
```

---

# 37.887 Data-authority rule

During every database incident ask:

# **WHO IS THE WRITER NOW?**

If nobody can answer that confidently:

```text
DO NOT
randomly change traffic.
```

Especially for single-writer systems:

```text
Old writer?

New writer?

Replication state?

Fencing?

```

must be clear first.

---

# 37.888 Traffic-before-data anti-pattern

Bad:

```text
Mumbai fails
    ↓
DNS → Singapore
    ↓
Singapore DB read-only
    ↓
customers fail
```

Correct:

```text
DATA READY
    ↓
COMPUTE READY
    ↓
APP READY
    ↓
TRAFFIC
```

Permanent rule:

> **Traffic shifting should usually be one of the final recovery steps for stateful workloads.**

---

# 37.889 DR dependency map

A Multi-Region app is not just:

```text
EC2 + DB
```

Inventory:

```text
VPC

subnets

routes

SG/NACL

ALB

compute

container images

database

cache

queues

object storage

secrets

KMS

certificates

IAM

DNS

monitoring

third-party APIs

hybrid network

corporate DNS
```

Every mandatory dependency needs a recovery answer.

---

# 37.890 Regional isolation test

Ask this powerful question:

> **If `ap-south-1` becomes completely unreachable right now, what in Singapore secretly still depends on it?**

Search for:

```text
Mumbai ECR

Mumbai secret ARN

Mumbai KMS key

Mumbai DB endpoint

Mumbai S3 bucket

Mumbai NAT EIP allowlist

Mumbai hybrid DNS

Mumbai-only partner VPN
```

Every hidden dependency weakens Regional isolation.

---

# 37.891 Hard-coded Region anti-pattern

Bad:

```python
DB_HOST = "something.ap-south-1.rds.amazonaws.com"
```

Bad IAM:

```text
arn:aws:secretsmanager:ap-south-1:...
```

Bad config:

```text
AWS_REGION=ap-south-1
```

everywhere.

Recovery-friendly applications make Region-specific configuration deliberate and replaceable.

---

# 37.892 DR troubleshooting sequence

When failover "doesn't work," do **not** randomly inspect everything.

Use:

```text
1. Did the failure get detected?

2. Did the incident trigger the correct
   recovery scope?

3. Is recovery data current enough?

4. Who owns write authority?

5. Did database promotion/failover work?

6. Did DR compute scale?

7. Are images/artifacts available?

8. Are secrets available?

9. Is KMS usable?

10. Is TLS/ACM valid?

11. Is the application healthy locally?

12. Are third-party dependencies working?

13. Is hybrid connectivity working?

14. Is DNS / traffic control pointing correctly?

15. Are clients re-resolving/reconnecting?

16. Does surviving capacity handle full load?

17. Is business transaction correctness okay?
```

This is the DR equivalent of Lesson 36's packet-walk troubleshooting method.

---

# 37.893 Failure diagnosis example

Symptoms:

```text
DNS says Singapore ✓

ALB healthy ✓

ECS tasks running ✓

customers still get 500
```

Investigate:

```text
App logs
   ↓
DB connection
   ↓
Secret
   ↓
KMS
```

Maybe:

```text
Singapore task role
doesn't have kms:Decrypt.
```

Therefore:

```text
ECS RUNNING
≠
APPLICATION RECOVERED
```

---

# 37.894 Another diagnosis

Symptoms:

```text
Singapore works at 5% test traffic

but fails at 100%
```

Likely investigate:

```text
ECS max capacity

DB size

DB connections

NAT capacity

service quotas

third-party rate limits

queue consumers
```

This is:

```text
capacity readiness problem
```

not:

```text
DNS problem.
```

---

# 37.895 Another diagnosis

Symptoms:

```text
Users occasionally see old data
after active/active routing.
```

Questions:

```text
MREC?

async Aurora secondary?

session moved Regions?

replication lag?

read-after-write assumption?
```

This is:

```text
CONSISTENCY / ROUTING
```

not necessarily an application bug.

---

# 37.896 Another diagnosis

Symptoms:

```text
DB promotion succeeded

Singapore writes work

failback corrupts data
```

Ask:

```text
Did Singapore become authoritative?

Was Mumbai re-synchronized?

Did you route users back before
Mumbai caught up?
```

Likely:

```text
failback sequencing bug.
```

---

# 37.897 Architecture Scenario 1 — cheap internal reporting app

Requirements:

```text
RTO = 12 hours

RPO = 24 hours

low business impact
```

Best starting evaluation:

# Backup & Restore.

Why not active/active?

Because you'd be solving a problem the business did not request while paying for substantial unnecessary complexity.

AWS warns against recovery objectives and architectures that are stricter and more expensive than business requirements justify. ([AWS Documentation][2])

---

# 37.898 Scenario 2 — customer API

Requirements:

```text
RTO = 20 minutes

RPO = few minutes

relational database

moderate budget
```

Strong candidate:

```text
Warm Standby

+

Aurora Global Database
or appropriate RDS DR

+

controlled traffic failover
```

Depending on database and application requirements.

---

# 37.899 Scenario 3 — legacy server application

Requirements:

```text
many EC2/VM-like servers

difficult to redesign

RTO minutes

RPO seconds
```

Evaluate:

# AWS Elastic Disaster Recovery.

AWS currently presents DRS as a lower-cost pilot-light-style approach with continual replication and warm-standby-like recovery objectives for suitable server workloads. ([AWS Documentation][4])

---

# 37.900 Scenario 4 — global catalog API

Requirements:

```text
users worldwide

key-value data

both Regions read/write

temporary staleness acceptable

low write latency important
```

Strong candidate:

```text
DynamoDB Global Tables
MREC
```

MREC uses asynchronous cross-Region replication and prioritizes lower write latency with eventual consistency. ([AWS Documentation][10])

---

# 37.901 Scenario 5 — global key-value data requiring strong consistency

Requirements:

```text
multi-Region DynamoDB

strong reads/writes

zero RPO architecture required
```

Evaluate:

```text
DynamoDB Global Tables
MRSC
```

subject to supported Region/topology constraints.

Current MRSC requires exactly three Regions as three replicas or two replicas plus a witness. ([AWS Documentation][11])

---

# 37.902 Scenario 6 — global relational active/active

Requirements:

```text
relational SQL

both data Regions must read/write

strong consistency

distributed architecture
```

Evaluate:

# Aurora DSQL

rather than assuming Aurora Global Database is multi-writer.

Current Multi-Region DSQL exposes two application-serving Regional endpoints for one strongly consistent logical database plus a witness Region. ([AWS Documentation][13])

---

# 37.903 Scenario 7 — global relational single writer

Requirements:

```text
PostgreSQL/MySQL-style relational

one writer okay

global read latency important

fast Region DR
```

Evaluate:

# Aurora Global Database.

One primary Region owns writes; secondary Regions serve read-oriented Global Database roles. ([AWS Documentation][6])

---

# 37.904 Scenario 8 — customer firewall requires fixed IPs

Requirements:

```text
global TCP/API

customers allowlist source endpoint IP

regional failover required
```

Evaluate:

# Global Accelerator.

It provides static anycast entry addresses that stay associated with the accelerator while backend endpoints can change. ([AWS Documentation][19])

---

# 37.905 Scenario 9 — standard web application with DNS failover

Requirements:

```text
HTTPS

DNS-based failover acceptable

warm standby

no fixed global IP requirement
```

Evaluate:

```text
Route 53 Failover Routing
+
healthy primary/secondary endpoints
```

Route 53 directly supports active/passive DNS failover configurations. ([AWS Documentation][17])

---

# 37.906 Scenario 10 — complex regulated application

Requirements:

```text
DB promotion

ECS scaling

approval gate

traffic switch

audit trail

cross-account resources
```

Evaluate:

# ARC Region Switch

because the problem is no longer merely:

```text
"change DNS."
```

It is:

```text
"orchestrate an ordered recovery workflow."
```

---

# 37.907 SAA exam trap — Multi-AZ vs read replica

Question:

> Need higher database availability within one Region.

Think:

```text
Multi-AZ
```

Question:

> Need read scaling / cross-Region DR.

Think:

```text
read replica / global architecture
```

Don't choose a cross-Region DR feature merely to solve a simple local database-instance failure.

---

# 37.908 SAA trap — backup vs replication

Question:

> Must recover from accidental deletion from yesterday.

Think:

```text
Backup / PITR / versioning
```

not merely:

```text
replica.
```

Because the deletion may replicate.

AWS expressly recommends backup/PITR alongside replication for protection from data corruption/destruction. ([AWS Documentation][4])

---

# 37.909 SAA trap — Pilot Light vs Warm Standby

Question:

> Core data services exist but application servers are started during disaster.

# Pilot Light.

Question:

> Complete working stack already runs at reduced capacity.

# Warm Standby.

([AWS Documentation][5])

---

# 37.910 SAA trap — Warm Standby vs Active/Active

Warm Standby:

```text
DR full stack exists
but isn't normally full active traffic capacity.
```

Active/active:

```text
multiple Regions actively serve workload traffic.
```

---

# 37.911 SAA trap — Global Accelerator vs CloudFront

## CloudFront

Think:

```text
HTTP/S CDN
edge caching/content delivery
```

## Global Accelerator

Think:

```text
global network routing
static anycast IPs
TCP/UDP endpoints
```

Do not select GA just because:

```text
"global"
```

appears in the name.

---

# 37.912 SAA trap — Route 53 vs Global Accelerator

Route 53:

```text
DNS routing
```

Global Accelerator:

```text
stable network entry IPs
+
endpoint routing
```

Current GA default IPv4 accelerators have two static anycast IPv4 addresses. ([AWS Documentation][18])

---

# 37.913 SAA trap — Aurora Global = multi-writer

Wrong.

Current Aurora Global Database:

```text
ONE primary write Region
+
up to 10 secondary Regions
```

([AWS Documentation][6])

---

# 37.914 SAA/DOP trap — active/active = RPO 0

Wrong.

RPO comes from:

```text
data replication and consistency semantics
```

not:

```text
number of active ALBs.
```

MREC, async Aurora replication, MRSC, and DSQL all behave differently. ([AWS Documentation][10])

---

# 37.915 DOP trap — automate everything immediately

Bad answer:

```text
One CloudWatch alarm
→ instant DB promotion
→ DNS switch
```

for a critical financial system without safety analysis.

Better:

```text
detect
  ↓
validate
  ↓
prepare
  ↓
safe data action
  ↓
approval/guardrail if needed
  ↓
traffic
```

Automation should reduce recovery error, not accelerate the wrong decision.

---

# 37.916 DOP trap — DR testing = ping endpoint

No.

Test:

```text
application transaction

data correctness

replication state

artifact availability

secrets

KMS

traffic switch

capacity

failback
```

AWS's Well-Architected Framework recommends actual resilience testing and regular game days rather than relying on superficial checks. ([AWS Documentation][23])

---

# 37.917 DOP trap — "Terraform applied, so DR is ready"

Wrong.

```text
terraform apply
```

proves:

```text
AWS accepted desired infrastructure configuration
```

not:

```text
payments work in Singapore.
```

You still need runtime validation.

---

# 37.918 Senior interview — design from requirements

Interviewer:

> Design DR for an e-commerce checkout service. RTO 15 minutes, RPO under 1 minute.

Strong reasoning:

```text
1. Establish Multi-AZ HA in primary.

2. Choose a recovery Region.

3. Evaluate Warm Standby because
   15-minute RTO is aggressive.

4. Use suitable continuously replicated
   database technology to support
   sub-minute data objective.

5. Replicate images/artifacts,
   secrets and object data.

6. Maintain a functional reduced
   application stack.

7. Automate capacity expansion
   and data recovery.

8. Validate before traffic movement.

9. Use Route 53/GA/ARC depending
   traffic-control requirements.

10. Maintain independent backups/PITR.

11. Test actual RTO/RPO.

12. Test failback.
```

That's much stronger than simply listing AWS products.

---

# 37.919 Senior interview — why might Warm Standby beat Active/Active?

Answer:

> Because the required RTO/RPO might be achievable without accepting the significant data-consistency, routing, deployment, and operational complexity of active/active.

AWS explicitly recommends Multi-site Active/Active only when business requirements justify the extra operational complexity. ([AWS Documentation][4])

---

# 37.920 Senior interview — why can active/active be dangerous?

Because:

```text
concurrent writers

network partitions

stale reads

duplicate requests

session movement

capacity after Region loss

global deployments

logical data corruption
```

all become first-class architecture concerns.

---

# 37.921 Senior interview — why doesn't replication replace backup?

Answer:

> Replication usually reproduces the current state—including destructive or corrupt changes—while backups/PITR preserve historical recovery points.

This aligns directly with AWS's DR guidance. ([AWS Documentation][4])

---

# 37.922 Senior interview — what determines DR RTO?

Think:

```text
Detection time
      +
Decision time
      +
Data recovery/promotion
      +
Compute scaling
      +
Application validation
      +
Traffic shift
      +
Client recovery
```

So:

```text
RTO
≠
DNS TTL
```

and:

```text
RTO
≠
database failover time
```

alone.

---

# 37.923 Senior interview — what determines RPO?

Primarily:

```text
replication model

backup frequency

transaction durability semantics

recovery-point selection
```

Examples:

```text
Aurora Global async
≠
DynamoDB MRSC
≠
snapshot every hour
```

Different architecture, different data-loss behavior. ([AWS Documentation][10])

---

# 37.924 Senior interview — what is fencing?

Concept:

```text
OLD WRITER
    X
cannot write

      ↓

NEW WRITER
    ✓
can write
```

Purpose:

```text
avoid two authoritative writers
during failover.
```

Important in stateful recovery and network-partition scenarios.

---

# 37.925 Senior interview — what is split brain?

```text
Region A
WRITE ✓

network partition

Region B
WRITE ✓

same authoritative dataset
```

Both sides independently believe they are correct.

Potential result:

```text
divergent data
```

This is why promotion safety matters.

---

# 37.926 Senior interview — why idempotency?

Because:

```text
request can succeed
but response can be lost.
```

Client retries.

Without idempotency:

```text
duplicate payment
duplicate order
duplicate email
```

With idempotency:

```text
same logical operation
=
one business effect
```

---

# 37.927 Senior interview — how would you test DR?

Strong answer:

```text
1. Define hypothesis and objectives.

2. Establish healthy baseline.

3. Start with small component failure.

4. Validate instance/task recovery.

5. Exercise one-AZ loss.

6. Test data failover.

7. Test Regional traffic evacuation.

8. Measure actual RTO.

9. Measure actual RPO.

10. Validate in-flight transactions.

11. Operate in recovery Region.

12. Test failback.

13. Document gaps.

14. Fix.

15. Retest.
```

AWS recommends regular resilience testing and game days using realistic response procedures. ([AWS Documentation][23])

---

# 37.928 Senior interview — FIS vs Game Day

```text
FIS
=
tool for injecting technical faults


Game Day
=
structured operational exercise
covering people + process + technology
```

One can be used inside the other.

AWS Resilience Hub's recommended/runnable resilience experiments themselves use AWS FIS actions. ([AWS Documentation][24])

---

# 37.929 Senior interview — what makes a good FIS experiment?

```text
Hypothesis

Target

Fault

Blast radius

Success criteria

Stop condition

Metrics

Recovery procedure

Owner
```

Not:

```text
"Let's kill some servers."
```

---

# 37.930 Senior interview — DR and security

A production DR strategy also needs:

```text
cross-account backup isolation

KMS recovery permissions

secret availability

IAM roles

audit trail

ransomware protection

backup immutability
```

A backup that exists but cannot be decrypted is not useful recovery capacity.

---

# 37.931 Senior interview — recovery control plane risk

Bad architecture:

```text
primary Region fails
      │
      ▼
recovery script exists
only in primary Region
```

You lost your:

```text
recovery tool
```

with the environment you're trying to recover.

Recovery control mechanisms should have resilience independent of the failure they're meant to handle.

This is one reason ARC Routing Control provides a dedicated multi-Region data plane with five Regional cluster endpoints. ([AWS Documentation][20])

---

# 37.932 Architecture anti-pattern list

Avoid:

```text
1. Single AZ production
   with Multi-Region marketing slide.

2. DR database exists,
   but no DR application.

3. DR app exists,
   but artifacts live only in primary.

4. Secret only exists in primary Region.

5. One ACM cert assumed to work everywhere.

6. DR database too small for production traffic.

7. Cross-Region replication called "backup."

8. No failback procedure.

9. Manual DNS edit as entire DR plan.

10. Automatic DB promotion
    triggered by one noisy alarm.

11. Standby never tested.

12. Region hard-coded in app.

13. Third-party allowlists missing DR IPs.

14. Hybrid VPN/DX path only exists to primary.

15. Deployment simultaneously breaks all Regions.

16. Backup created but never restored.

17. Game-day findings never remediated.
```

If you see multiple items from this list, the organization has DR **assets**, not necessarily a reliable DR **system**.

---

# 37.933 Architecture decision matrix — one page

| Requirement                         | Likely starting direction     |
| ----------------------------------- | ----------------------------- |
| Hours/days RTO                      | Backup & Restore              |
| Reduced cost, faster than restore   | Pilot Light                   |
| Minutes-level target                | Warm Standby                  |
| Very aggressive regional recovery   | Active/Active                 |
| Server/VM lift-and-shift DR         | AWS Elastic Disaster Recovery |
| One-AZ problem                      | Zonal Shift/Autoshift         |
| Region recovery workflow            | ARC Region Switch             |
| Explicit regional traffic switch    | ARC Routing Control           |
| DNS failover                        | Route 53                      |
| Stable global network IPs           | Global Accelerator            |
| One global relational writer        | Aurora Global DB              |
| Multi-active NoSQL                  | DynamoDB Global Tables        |
| Strong Global Tables                | MRSC                          |
| Eventual Global Tables              | MREC                          |
| Multi-active distributed relational | Aurora DSQL                   |
| Historical recovery                 | AWS Backup / native PITR      |
| Controlled failure injection        | AWS FIS                       |
| Whole-team DR exercise              | Game Day                      |

Current AWS guidance supports these broad service roles, but exact service/Region support should always be verified when turning the matrix into a real implementation. ([AWS Documentation][4])

---

# 37.934 One-minute SAA exam method

When you read the question:

## Step 1

Identify:

```text
failure scope
```

Instance?

AZ?

Region?

Data corruption?

---

## Step 2

Find:

```text
RTO
RPO
```

Explicit or implied.

---

## Step 3

Identify:

```text
data model
```

Relational?

NoSQL?

Object?

Files?

---

## Step 4

Identify:

```text
cost sensitivity
```

Lowest cost?

Fastest recovery?

---

## Step 5

Identify:

```text
traffic model
```

DNS?

Fixed IP?

Active/passive?

Active/active?

---

## Step 6

Eliminate over-engineered answers.

That's often the fastest way to solve architecture exam questions.

---

# 37.935 DOP-C02 thinking method

DevOps Professional questions often care not only about architecture but:

```text
automation

monitoring

deployment

safe recovery

rollback

testing

organizational controls
```

So think:

```text
architecture
+
pipeline
+
alarms
+
runbook
+
automation
+
validation
+
rollback/failback
```

not only:

```text
service X.
```

---

# 37.936 Production troubleshooting mnemonic

Use:

# **D-D-D-C-A-T**

```text
D
Detection

D
Data

D
Dependencies

C
Capacity

A
Application

T
Traffic
```

Full sequence:

```text
DETECTION
   ↓
DATA AUTHORITY
   ↓
DEPENDENCIES
   ↓
CAPACITY
   ↓
APPLICATION HEALTH
   ↓
TRAFFIC SHIFT
```

That is a powerful Regional-DR troubleshooting order.

---

# 37.937 "Never forget" complete DR equation

```text
DR READINESS
=
RTO/RPO

+

HA

+

DATA REPLICATION

+

BACKUPS

+

DR INFRASTRUCTURE

+

ARTIFACTS

+

SECRETS/KMS

+

NETWORK/DNS

+

CAPACITY

+

AUTOMATION

+

TRAFFIC CONTROL

+

OBSERVABILITY

+

TESTING

+

FAILBACK
```

Miss one critical dependency and the whole recovery chain can fail.

---

# 37.938 Full enterprise mental map

```text
                            BUSINESS

                        RTO       RPO
                         │         │
                         └────┬────┘
                              ▼

                        DR STRATEGY
                              │
          ┌───────────────────┼────────────────────┐
          ▼                   ▼                    ▼

       BACKUP              STANDBY              ACTIVE
       RESTORE                │                 ACTIVE
                        ┌─────┴─────┐
                        ▼           ▼
                    PILOT       WARM


                              │
                              ▼
                           NETWORK

             ┌────────────────┼─────────────────┐
             ▼                ▼                 ▼

          Multi-AZ       Multi-Region      Hybrid/DNS
                                              │
                                              ▼
                                         Lesson 36


                              │
                              ▼
                             DATA

       ┌──────────┬───────────┼─────────────┬──────────┐
       ▼          ▼           ▼             ▼          ▼

     Aurora    DynamoDB      DSQL           S3        Backup
     Global    Global       Active/         CRR       PITR
     single    Tables       Active
     writer    MREC/MRSC


                              │
                              ▼
                           TRAFFIC

              ┌───────────────┼────────────────┐
              ▼               ▼                ▼

           Route53      Global Accelerator    ARC
             DNS         Static Anycast        │
                                                ├─ Routing Control
                                                ├─ Region Switch
                                                ├─ Zonal Shift
                                                └─ Autoshift


                              │
                              ▼
                          VALIDATION

              ┌───────────────┼──────────────┐
              ▼               ▼              ▼

          Restore Test       FIS          Game Day
              │               │              │
              └───────────────┼──────────────┘
                              ▼

                         MEASURE RTO/RPO
                              │
                              ▼
                           FAILBACK
```

If you can reconstruct that map from memory, you understand the architecture.

---

# 37.939 Fifteen permanent Lesson 37 rules

```text
1.
RTO = recovery time tolerance.


2.
RPO = data-loss tolerance.


3.
HA and DR solve different scopes.


4.
Multi-AZ comes before
Multi-Region complexity.


5.
Backup & Restore is cheapest
but recovery-heavy.


6.
Pilot Light keeps
the critical core alive.


7.
Warm Standby keeps
a full smaller stack alive.


8.
Active/Active is a distributed-
systems architecture,
not just two load balancers.


9.
Replication does not replace backup.


10.
Data architecture determines
the real RPO.


11.
Traffic should move only after
the recovery destination is ready.


12.
Route 53 routes DNS;
Global Accelerator provides
stable network entry;
ARC controls/orchestrates recovery.


13.
A backup is not proven
until restored.


14.
Failover is not fully proven
until failback works.


15.
Resilience is what the system
demonstrates under failure,
not what the diagram claims.
```

---

# 37.940 Twenty-second interview cheat sheet

If you're stuck, answer with this sequence:

> **First I would define the workload's failure scope, RTO and RPO. I would make the primary environment Multi-AZ, then select Backup & Restore, Pilot Light, Warm Standby, or Active/Active based on the business objectives. I would design the data layer separately because replication and consistency determine the achievable RPO. I would ensure the recovery Region has networking, artifacts, secrets, certificates, IAM, KMS and sufficient capacity. I would make data ready before shifting traffic, use Route 53, Global Accelerator or ARC according to the traffic and orchestration requirement, maintain independent backups/PITR, then regularly test both failover and failback and measure actual RTO/RPO.**

That answer alone demonstrates a very solid architecture mindset.

---

# 37.941 Certification "word triggers"

When exam wording says:

```text
"lowest cost DR"
```

think:

```text
Backup & Restore / Pilot Light
```

depending on RTO.

---

When it says:

```text
"fully functional reduced environment"
```

think:

```text
Warm Standby
```

---

When it says:

```text
"simultaneously serving users
from multiple Regions"
```

think:

```text
Active/Active
```

---

When it says:

```text
"stable static global IP"
```

think:

```text
Global Accelerator
```

---

When it says:

```text
"DNS-based primary/secondary"
```

think:

```text
Route 53 Failover
```

---

When it says:

```text
"orchestrate database promotion,
scale and traffic shift"
```

think:

```text
ARC Region Switch
```

---

When it says:

```text
"move traffic away from one AZ"
```

think:

```text
Zonal Shift
```

---

When it says:

```text
"AWS automatically shifts from
impaired AZ"
```

think:

```text
Zonal Autoshift
```

---

When it says:

```text
"multi-active key-value database"
```

think:

```text
DynamoDB Global Tables
```

---

When it says:

```text
"global relational reads,
single writer"
```

think:

```text
Aurora Global Database
```

---

When it says:

```text
"distributed active-active
relational database"
```

think:

```text
Aurora DSQL
```

---

# 37.942 Final mini quiz

Answer mentally before reading.

### Q1

RTO = ?

```text
Maximum acceptable service-recovery delay.
```

### Q2

RPO = ?

```text
Maximum acceptable data-loss window.
```

### Q3

Pilot Light vs Warm Standby?

```text
Pilot:
critical core ready,
significant app activation remains.

Warm:
full working reduced stack already running.
```

### Q4

Replication vs backup?

```text
Replication:
current state elsewhere.

Backup:
historical recoverable state.
```

### Q5

Aurora Global writer model?

```text
One primary write Region.
```

([AWS Documentation][6])

### Q6

DynamoDB Global Tables?

```text
Multi-active.
```

([AWS Documentation][9])

### Q7

MREC vs MRSC?

```text
MREC:
eventual.

MRSC:
strong cross-Region consistency,
three-Region topology.
```

([AWS Documentation][10])

### Q8

Route 53 vs GA?

```text
Route53:
DNS routing.

GA:
static anycast network entry.
```

([AWS Documentation][19])

### Q9

Routing Control vs Region Switch?

```text
Routing Control:
traffic ON/OFF.

Region Switch:
recovery workflow orchestration.
```

### Q10

What's missing if failover works but failback never tested?

```text
Half of the DR lifecycle.
```

---

# 37.943 Lesson 37 final completion map

We completed:

```text
Part 1
HA vs DR + RTO/RPO                 ✓

Part 2
AWS Backup & Restore               ✓

Part 3
Pilot Light & Warm Standby         ✓

Part 4
Active/Passive Multi-Region        ✓

Part 5
Active/Active Multi-Region         ✓

Part 6
Multi-Region Data Layer            ✓

Part 7
Application Recovery Controller    ✓

Part 8
Automation / FIS / Game Days       ✓

Part 9
Production DR Capstone             ✓

Part 10
Final Revision / Interview Mastery ✓
```

# ✅ Lesson 37 is officially complete.

You now have the full mental progression:

```text
HA
 ↓
RTO/RPO
 ↓
Backup
 ↓
Pilot Light
 ↓
Warm Standby
 ↓
Active/Passive
 ↓
Active/Active
 ↓
Global data
 ↓
Traffic control
 ↓
ARC
 ↓
Chaos testing
 ↓
Measured RTO/RPO
 ↓
Failback
```

And most importantly:

> **Don't choose a DR architecture because a service sounds advanced. Choose the recovery objective first, choose the consistency/data model second, then design the infrastructure, traffic control, automation, testing, and failback around those requirements.**

That principle aligns directly with AWS Well-Architected guidance: define business-driven RTO/RPO, choose an appropriate recovery strategy, manage configuration drift, automate recovery, and repeatedly test the implementation. ([AWS Documentation][3])

The next continuation moves us into the **next lesson of Module 13 — AWS Production Architecture**.

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/disaster-recovery-dr-objectives.html?utm_source=chatgpt.com "Disaster Recovery (DR) objectives - Reliability Pillar"
[2]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_objective_defined_recovery.html?utm_source=chatgpt.com "REL13-BP01 Define recovery objectives for downtime and ..."
[3]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/plan-for-disaster-recovery-dr.html?utm_source=chatgpt.com "Plan for Disaster Recovery (DR) - Reliability Pillar"
[4]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the ..."
[5]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html?utm_source=chatgpt.com "Disaster recovery options in the cloud"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html?utm_source=chatgpt.com "Using switchover or failover in Amazon Aurora Global Database"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-mysql-write-forwarding-consistency.html?utm_source=chatgpt.com "Read consistency for write forwarding - Amazon Aurora"
[9]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication"
[10]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[11]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables-security.html?utm_source=chatgpt.com "DynamoDB global tables security"
[12]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables.tutorial.html?utm_source=chatgpt.com "Tutorials: Creating global tables - Amazon DynamoDB"
[13]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/multi-region-aws-cli.html?utm_source=chatgpt.com "Using AWS CLI - Amazon Aurora DSQL"
[14]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/what-is-aurora-dsql.html?utm_source=chatgpt.com "When to use Aurora DSQL"
[15]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-global-table-design.prescriptive-guidance.checklist-and-faq.html?utm_source=chatgpt.com "Preparation checklist for DynamoDB global tables"
[16]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_withstand_component_failures_failover2good.html?utm_source=chatgpt.com "REL11-BP02 Fail over to healthy resources - Reliability Pillar"
[17]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html?utm_source=chatgpt.com "Creating Amazon Route 53 health checks"
[18]: https://docs.aws.amazon.com/global-accelerator/latest/dg/introduction-components.html?utm_source=chatgpt.com "AWS Global Accelerator components"
[19]: https://docs.aws.amazon.com/global-accelerator/latest/dg/introduction-how-it-works.html?utm_source=chatgpt.com "How AWS Global Accelerator works"
[20]: https://docs.aws.amazon.com/r53recovery/latest/dg/getting-started-cli-routing.control-state.html?utm_source=chatgpt.com "List and update routing controls and states with the AWS CLI"
[21]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-readiness-availability-change.html?utm_source=chatgpt.com "Amazon Application Recovery Controller (ARC) readiness ..."
[22]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/zonal-shift.html?utm_source=chatgpt.com "Zonal shift for your Application Load Balancer"
[23]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_testing_resiliency_game_days_resiliency.html?utm_source=chatgpt.com "REL12-BP05 Conduct game days regularly - Reliability Pillar"
[24]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/testing.html?utm_source=chatgpt.com "Managing AWS Fault Injection Service experiments"
