# Module 13 — AWS Production Architecture

# Lesson 37 — AWS Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 1: Disaster-Recovery Mental Model + RTO/RPO + HA vs DR

Lesson 36 solved:

```text
How do networks, VPCs, data centers,
VPN, DX, TGW and DNS connect?
```

Lesson 37 asks a different production question:

> **What happens when an Availability Zone, AWS Region, database, application stack, or even an entire production environment becomes unavailable?**

AWS Well-Architected guidance treats disaster recovery as a business-driven design problem: define the acceptable recovery time and acceptable data loss, then choose a recovery architecture that can meet those objectives. ([AWS Documentation][1])

---

# 37.1 First: High Availability is NOT the same as Disaster Recovery

This distinction is critical.

Imagine:

```text
                    ap-south-1

              ┌──────────────────┐
              │      ALB         │
              └────────┬─────────┘
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
           AZ-A                AZ-B

          EC2-A                EC2-B
             │                   │
             └─────────┬─────────┘
                       ▼
                   Multi-AZ DB
```

This is primarily:

# High Availability — HA

The workload is designed to tolerate failures of components or an Availability Zone **within the Region**.

AWS recommends Multi-AZ architectures to reduce impact from AZ-level failures; separate Regions provide an additional fault-isolation boundary for Region-level disaster-recovery designs. ([AWS Documentation][2])

---

# 37.2 HA mental model

Think:

```text
One component fails
      ↓
another component
continues serving
```

Examples:

```text
EC2 dies
→ Auto Scaling replaces it

AZ-A has problem
→ ALB uses AZ-B

RDS primary fails
→ Multi-AZ failover

container dies
→ ECS/EKS replaces it
```

The intention is generally:

```text
KEEP SERVING
```

rather than:

```text
rebuild the entire application elsewhere.
```

---

# 37.3 Disaster Recovery mental model

Now imagine:

```text
              AWS REGION A

             ap-south-1
                 X
          REGIONAL FAILURE
```

Your Multi-AZ design:

```text
AZ-A
AZ-B
AZ-C
```

is still inside:

```text
ap-south-1
```

So another architecture may exist:

```text
                  PRIMARY REGION

                   ap-south-1
                       │
                       │ replication
                       ▼
                 RECOVERY REGION

                ap-southeast-1
```

That is:

# Disaster Recovery — DR

AWS guidance treats Region-level recovery as a separate concern from Multi-AZ availability and recommends selecting a DR strategy according to workload recovery objectives. ([AWS Documentation][3])

---

# 37.4 Never-forget HA vs DR

```text
HA
─────────────────────────

"What happens when
a component/AZ fails?"

Goal:
continue operating


DR
─────────────────────────

"What happens when
a serious disaster
takes down the normal
production environment?"

Goal:
recover the workload
```

A system can have:

```text
excellent HA
```

but:

```text
poor DR.
```

---

# 37.5 Example

You have:

```text
Application Load Balancer
      │
Auto Scaling Group
      │
3 Availability Zones
      │
RDS Multi-AZ
```

Excellent.

Then someone accidentally deletes:

```text
critical production data
```

or:

```text
bad deployment corrupts DB
```

or you must recover from:

```text
Regional disaster
```

Multi-AZ alone does not necessarily solve those scenarios.

This is why we need:

```text
backups
replication
recovery environments
cross-Region planning
tested runbooks
```

---

# 37.6 The TWO numbers that drive DR architecture

Before selecting:

```text
S3
RDS
Aurora
DynamoDB
Route 53
ARC
cross-Region replication
```

ask the business for two things:

# RTO

and

# RPO.

If you don't understand these, DR architecture becomes guesswork.

AWS explicitly recommends defining both recovery objectives before selecting and implementing a recovery strategy. ([AWS Documentation][4])

---

# 37.7 RTO — Recovery Time Objective

AWS defines RTO as the maximum acceptable delay between a service interruption and restoration of service. ([AWS Documentation][4])

Simpler:

> **How long can the application be unavailable?**

Example:

```text
Production goes down:

10:00 AM
```

Business says:

```text
Must be operational by:

10:30 AM
```

Then roughly:

```text
RTO = 30 minutes
```

---

# 37.8 RTO timeline

```text
10:00
  │
  │ DISASTER
  ▼
████████████████████████
         recovery
████████████████████████
                       │
                       ▼
                     10:30

Maximum tolerated recovery delay:
30 minutes
```

So RTO is mainly about:

# TIME TO RESTORE SERVICE.

---

# 37.9 Different workloads have different RTOs

For example:

```text
Payment processing
RTO = 5 minutes


Customer website
RTO = 30 minutes


Internal analytics
RTO = 8 hours


Archived reporting
RTO = 24 hours
```

These are just examples—not universal values.

Business impact determines the objective.

---

# 37.10 RPO — Recovery Point Objective

AWS defines RPO as the maximum acceptable period of data loss measured from the latest acceptable recovery point before an interruption. ([AWS Documentation][5])

Simpler:

> **How much data can we afford to lose?**

Example:

Disaster:

```text
10:00 AM
```

Latest recoverable data:

```text
9:45 AM
```

Potential lost data:

```text
15 minutes
```

Therefore:

```text
RPO ≈ 15 minutes
```

---

# 37.11 RPO timeline

```text
Last recoverable point
        │
        ▼
      09:45
        │
        │ 15 minutes of
        │ potential data loss
        ▼
      10:00
      DISASTER
```

So:

# RPO = DATA LOSS TOLERANCE.

---

# 37.12 Never-forget RTO vs RPO

```text
RTO
=
TIME


RPO
=
DATA
```

Or my preferred shortcut:

```text
RTO
→ "How quickly must I RECOVER?"


RPO
→ "How far back can my DATA go?"
```

---

# 37.13 Interview example

Question:

> A business says its system must recover within 15 minutes and may lose at most 5 minutes of transactions.

Translate:

```text
RTO = 15 minutes

RPO = 5 minutes
```

This should become automatic.

---

# 37.14 A common mistake

Engineer says:

> "We'll just use active/active Multi-Region because that's the most resilient."

But business says:

```text
RTO = 12 hours
RPO = 24 hours
```

and application is:

```text
low-value internal reporting.
```

You've potentially built an unnecessarily expensive architecture.

DR design is a balance among:

```text
Business criticality
RTO
RPO
Complexity
Cost
Operational burden
```

AWS explicitly recommends considering probability of disruption and recovery cost alongside RTO/RPO. ([AWS Documentation][1])

---

# 37.15 The DR cost curve

Conceptually:

```text
Lower cost
   ▲
   │
   │ Backup & Restore
   │
   │ Pilot Light
   │
   │ Warm Standby
   │
   │ Active/Active
   │
   └────────────────────────────►
                         More cost /
                         more continuously
                         running capacity
```

And generally:

```text
Backup/Restore
→ slower recovery


Active/Active
→ faster recovery potential
```

But actual RTO/RPO depends on implementation, data technology, automation, testing, and workload behavior.

---

# 37.16 AWS's four classic DR strategies

AWS DR guidance commonly discusses four broad patterns:

```text
1. Backup and Restore

2. Pilot Light

3. Warm Standby

4. Multi-Site Active/Active
```

AWS emphasizes choosing among these according to your required RTO/RPO and business constraints. ([AWS Documentation][6])

We are going to learn all four deeply.

---

# 37.17 Strategy #1 — Backup and Restore

Simplest architecture:

```text
                 PRIMARY REGION

Application
    │
Database
    │
Backups
    │
    ▼
Backup storage
    │
cross-Region copy
    ▼
RECOVERY REGION
```

But the actual application infrastructure might **not be continuously running** in the recovery Region.

When disaster occurs:

```text
Restore data
     ↓
Deploy infrastructure
     ↓
Deploy application
     ↓
Validate
     ↓
Redirect users
```

That's backup and restore.

---

# 37.18 Backup-and-Restore mental model

Think:

```text
DR Region before disaster

┌────────────────────────┐
│ Backups                │
│ Terraform              │
│ AMIs / artifacts       │
│ configuration          │
│ maybe little else      │
└────────────────────────┘
```

Then:

```text
DISASTER
   ↓
BUILD
   ↓
RESTORE
   ↓
START
   ↓
TEST
   ↓
FAIL OVER
```

---

# 37.19 Backup-and-Restore strengths

Conceptually:

```text
Lower steady-state infrastructure cost

Simple starting point

Useful for less critical systems

Good when longer RTO/RPO
is acceptable
```

But recovery takes time because significant infrastructure and/or data restoration work occurs after the incident.

AWS positions backup-and-restore at the slower-recovery/lower-cost end of the classic DR spectrum. ([AWS Documentation][6])

---

# 37.20 Example backup-and-restore architecture

```text
                      ap-south-1
                    PRIMARY REGION

                  ALB
                   │
                  EC2
                   │
                  RDS
                   │
                 Backup
                   │
                   ▼
              Cross-Region
               backup copy
                   │
                   ▼
              ap-southeast-1
               DR REGION

          Terraform definitions
          application artifact
          DB backup copy
```

Disaster:

```text
Primary Region X

      ↓

terraform apply
in DR Region

      ↓

restore database

      ↓

deploy app

      ↓

Route 53 failover

      ↓

users → DR
```

---

# 37.21 Terraform becomes extremely important for DR

Imagine infrastructure exists only because someone manually clicked:

```text
VPC
subnets
ALB
ASG
SGs
IAM
RDS
Route 53
```

in Mumbai.

During disaster:

> "Recreate all of that in Singapore."

Not ideal.

Instead:

```text
Infrastructure as Code
        │
        ├── ap-south-1
        │
        └── ap-southeast-1
```

AWS Well-Architected specifically recommends using Infrastructure as Code for recovery environments so infrastructure can be deployed repeatably. ([AWS Documentation][3])

---

# 37.22 Strategy #2 — Pilot Light

The phrase comes from a gas heater.

A tiny flame remains running so the full system can be started quickly.

AWS DR mental model:

```text
PRIMARY REGION

Full application
████████████████████


DR REGION

Critical core
██
```

The most important stateful/core components remain ready in the recovery Region, while application capacity or additional infrastructure is brought up during failover.

AWS differentiates pilot light from warm standby by noting that pilot light still requires starting/deploying/scaling significant application infrastructure, whereas warm standby already has a functioning scaled-down stack. ([AWS Documentation][6])

---

# 37.23 Pilot Light example

Primary:

```text
                 ap-south-1

             ALB
              │
         Auto Scaling
          20 EC2
              │
           Aurora
              │
          Production
```

DR:

```text
             ap-southeast-1

          replicated DB
               │
        critical core data
               │
        app infrastructure
        prepared in IaC
```

During disaster:

```text
Deploy/start compute
      ↓
Scale infrastructure
      ↓
promote/reconfigure data
      ↓
redirect users
```

---

# 37.24 Why Pilot Light is faster than pure restore

Because some of the hardest stateful pieces may already exist.

Instead of:

```text
restore everything from scratch
```

you may already have:

```text
replicated database/data
network foundation
security configuration
critical services
```

ready.

AWS describes pilot light as maintaining critical core components in the recovery Region and scaling/starting the rest during recovery. ([AWS Documentation][6])

---

# 37.25 Strategy #3 — Warm Standby

Now we go further.

DR Region already contains:

# A working, smaller copy of production.

```text
PRIMARY

20 application instances
large database
full capacity


DR

2 application instances
smaller operating capacity
replicated database
```

Both environments are deployed.

DR is simply:

```text
smaller.
```

AWS defines warm standby as a fully functional but reduced-capacity version of the workload that is already running in the recovery Region and is scaled up during failover. ([AWS Documentation][6])

---

# 37.26 Warm Standby architecture

```text
          PRIMARY REGION

          ALB
           │
      ┌────┼────┐
      ▼    ▼    ▼
     App  App  App
     App  App  App
           │
        Database
           │
      replication
           │
           ▼
         DR REGION

          ALB
           │
          App
           │
      DR database
```

Normal state:

```text
DR runs at reduced capacity.
```

During disaster:

```text
scale up DR
      ↓
switch/promote data
      ↓
redirect traffic
```

---

# 37.27 Pilot Light vs Warm Standby

This is frequently confused.

## Pilot Light

```text
critical core running
but not a full operational
application stack
```

Recovery requires:

```text
deploy/start + scale
```

## Warm Standby

```text
complete application
already running
at reduced capacity
```

Recovery mainly requires:

```text
scale + redirect
```

AWS explicitly draws this distinction. ([AWS Documentation][6])

---

# 37.28 Never-forget picture

```text
BACKUP & RESTORE

Primary: ██████████
DR:      backups


PILOT LIGHT

Primary: ██████████
DR:      ██


WARM STANDBY

Primary: ██████████
DR:      █████


ACTIVE/ACTIVE

Region A: ██████████
Region B: ██████████
```

Perfect mental picture.

---

# 37.29 Strategy #4 — Multi-Site Active/Active

Now both Regions actively serve production.

```text
                    GLOBAL USERS
                         │
                         ▼
                 GLOBAL ROUTING
                    /         \
                   /           \
                  ▼             ▼

            ap-south-1     ap-southeast-1

                ALB             ALB
                 │               │
                APP             APP
                 │               │
                 └──────┬────────┘
                        │
                  DATA STRATEGY
```

AWS includes Multi-Site Active/Active among its classic DR strategies and notes that active/active/hot recovery environments maintain production-equivalent infrastructure rather than a scaled-down standby. ([AWS Documentation][3])

---

# 37.30 In active/active, both Regions serve real users

Example:

```text
India users
        ↓
Mumbai


Southeast Asia users
        ↓
Singapore
```

If Mumbai becomes unavailable:

```text
Mumbai X
   │
   ▼
Users shift
to Singapore
```

This can provide very aggressive recovery objectives, but it is also the most architecturally demanding pattern.

---

# 37.31 Active/active is NOT simply "copy the EC2s"

The difficult part is often:

# DATA.

Application compute can often be duplicated relatively easily.

The hard questions are:

```text
Where is the authoritative write?

Can both Regions write?

How is data replicated?

What happens during network partition?

How are conflicting writes handled?

What is replication lag?

How is failback handled?
```

Multi-Region architecture becomes a **distributed-systems problem**, not merely an EC2 problem.

---

# 37.32 Example active/active problem

Region A:

```text
Customer balance:
₹10,000
```

Region B:

```text
Customer balance:
₹10,000
```

At the same moment:

```text
Region A:
withdraw ₹2,000

Region B:
withdraw ₹5,000
```

Now:

```text
What is the correct balance?
```

This is why you must deeply understand the data layer before saying:

> "Let's make everything active/active."

---

# 37.33 DR strategy comparison

| Strategy         | DR capacity during normal operation | Recovery complexity                                 | Typical relative cost |
| ---------------- | ----------------------------------- | --------------------------------------------------- | --------------------- |
| Backup & Restore | Mostly backups                      | Highest during recovery                             | Lowest                |
| Pilot Light      | Critical core                       | Moderate-high                                       | Low-medium            |
| Warm Standby     | Full but reduced stack              | Lower                                               | Medium-high           |
| Active/Active    | Full production capacity            | Very complex design, fast traffic recovery possible | Highest               |

AWS's guidance shows the same broad progression: as more infrastructure remains running in the recovery environment, recovery can become faster but steady-state cost and architectural complexity increase. ([AWS Documentation][6])

---

# 37.34 Don't memorize exact RTO numbers for each strategy

You may find diagrams saying:

```text
Backup:
hours

Pilot Light:
tens of minutes

Warm:
minutes

Active/Active:
near zero
```

AWS guidance uses example ranges like these, but actual values depend on the workload and automation. ([AWS Documentation][7])

Do not interview-answer:

> "Warm standby always has exactly 10-minute RTO."

Wrong.

Say:

> Warm standby generally supports more aggressive recovery objectives than pilot light because a functional application stack is already operating, but the actual RTO/RPO depends on the workload and implementation.

Much better.

---

# 37.35 RTO and RPO are independent

Consider:

```text
RTO = 4 hours

RPO = 1 minute
```

Meaning:

```text
Application can be offline
for up to 4 hours

BUT

business can lose only
1 minute of data.
```

This might require:

```text
aggressive data replication
```

but not necessarily:

```text
fully active application compute.
```

Important distinction.

---

# 37.36 Another example

```text
RTO = 5 minutes

RPO = 24 hours
```

Strange, but possible depending on business context.

Meaning:

```text
service must return very quickly

but old data is acceptable.
```

The data strategy and compute strategy can therefore have different requirements.

---

# 37.37 RTO/RPO at COMPONENT level

Don't only write:

```text
Application RTO = 30 minutes
```

Break it down:

```text
DNS
RTO = 2 minutes


Load balancer
RTO = 5 minutes


Compute
RTO = 10 minutes


Database
RTO = 15 minutes


Queue
RTO = 10 minutes
```

AWS Well-Architected recommends designing recovery/failover mechanisms for the application's components so the overall workload can meet its objectives. ([AWS Documentation][8])

---

# 37.38 Recovery dependency chain

Suppose your web tier recovers in:

```text
2 minutes
```

but database takes:

```text
2 hours.
```

Your application RTO is effectively constrained by:

```text
database recovery.
```

Think:

```text
DNS        1 min
ALB        2 min
EC2        5 min
App        8 min
Database 120 min
           ↑
     bottleneck
```

So don't optimize one layer while ignoring the slowest recovery dependency.

---

# 37.39 Availability Zones vs Regions

Important hierarchy:

```text
AWS
 │
 ├── Region
 │     │
 │     ├── AZ-A
 │     ├── AZ-B
 │     └── AZ-C
 │
 └── Region
       │
       ├── AZ-A
       ├── AZ-B
       └── AZ-C
```

Regions are separate fault-isolation boundaries, while AZs give isolated infrastructure locations within a Region. Multi-AZ designs are the normal first line of defense against infrastructure failures; Multi-Region should be introduced when the business recovery requirements justify it. ([AWS Documentation][2])

---

# 37.40 Very important production rule

Don't jump straight from:

```text
Single AZ
```

to:

```text
Multi-Region active/active
```

First fix:

```text
Multi-AZ resilience.
```

A poorly designed single-Region application duplicated into two Regions becomes:

```text
two poorly designed systems.
```

---

# 37.41 Typical resilience layers

Think:

```text
LEVEL 1

Instance resilience
Auto Scaling


LEVEL 2

Multi-AZ
regional HA


LEVEL 3

Backups
data recovery


LEVEL 4

Cross-Region DR


LEVEL 5

Active/Active
multi-Region architecture
```

Each layer protects against different failure classes.

---

# 37.42 Failure scope matters

Imagine:

### EC2 failure

```text
one instance X
```

Solution:

```text
Auto Scaling
```

### AZ failure

```text
AZ-A X
```

Solution:

```text
Multi-AZ application
```

### database corruption

```text
data X
```

Solution might require:

```text
backup/PITR
```

### Region-level disaster

```text
ap-south-1 X
```

Solution:

```text
cross-Region DR strategy
```

Different failures require different mechanisms.

---

# 37.43 Backup is NOT HA

Suppose:

```text
RDS fails
```

and you have a backup from:

```text
6 hours ago.
```

You can restore later.

That's:

```text
recoverability
```

not:

```text
high availability.
```

Similarly:

```text
Multi-AZ
```

does not automatically protect against:

```text
logical data corruption replicated everywhere.
```

Never confuse:

```text
redundancy
```

with:

```text
backup.
```

---

# 37.44 Replication is NOT backup

Suppose bad SQL runs:

```sql
DELETE FROM customers;
```

If replication immediately sends that change to DR:

```text
Primary:
customers deleted

DR:
customers deleted
```

Congratulations—you have replicated your disaster.

Therefore:

```text
replication
≠
backup
```

You need both depending on recovery requirements.

---

# 37.45 Three separate concepts

Memorize:

```text
REDUNDANCY
=
another component can serve


REPLICATION
=
copy changes elsewhere


BACKUP
=
historical recoverable state
```

They're related but not interchangeable.

---

# 37.46 Failover

Failover means:

```text
PRIMARY
   X

   ↓

SECONDARY
becomes serving environment
```

For example:

```text
Route 53
     │
     ├── Mumbai   X
     │
     └── Singapore ✓
```

Users are redirected to the healthy environment.

---

# 37.47 Failback

After fixing the primary Region:

```text
Mumbai returns
```

you may want:

```text
Singapore
     ↓
Mumbai
```

again.

That's:

# Failback.

Failback is often harder than people expect because data created during the disaster must be reconciled/replicated correctly before shifting production back.

---

# 37.48 DR without failback planning is incomplete

A runbook that only says:

```text
Fail from A → B
```

isn't finished.

You also need:

```text
How do we recover A?

How do we synchronize data?

When is A trusted again?

How do we move users back?

What if failback fails?
```

Production DR is a lifecycle:

```text
NORMAL
  ↓
FAILURE
  ↓
FAILOVER
  ↓
RECOVERY
  ↓
FAILBACK
  ↓
NORMAL
```

---

# 37.49 Manual vs automated recovery

Manual:

```text
Alarm
 ↓
Engineer wakes up
 ↓
opens runbook
 ↓
scales DR
 ↓
promotes DB
 ↓
changes DNS
 ↓
tests
```

Automated:

```text
Failure detected
      ↓
predefined recovery workflow
      ↓
validated actions
      ↓
traffic shift
```

AWS Well-Architected recommends automating recovery where practical to make recovery faster, more predictable, and less susceptible to human error. ([AWS Documentation][9])

---

# 37.50 But never automate unsafe failover blindly

Imagine monitoring briefly reports:

```text
Primary unhealthy
```

and automation instantly:

```text
promotes secondary DB
```

Meanwhile primary was still processing writes.

You can create:

```text
split brain
```

or inconsistent data.

So sophisticated recovery needs:

```text
health signals
guardrails
quorum/safety checks
traffic controls
data consistency checks
```

This is where services such as:

# Amazon Application Recovery Controller — ARC

become relevant.

---

# 37.51 Amazon Application Recovery Controller — ARC

ARC provides AWS resilience capabilities including areas for:

```text
Multi-Region routing control

Region switch

readiness checks

zonal shift

zonal autoshift
```

The current AWS documentation distinguishes multi-Region capabilities such as routing control/Region switch from Multi-AZ capabilities such as zonal shift and zonal autoshift. ([AWS Documentation][10])

We'll learn ARC deeply later in this lesson.

For now, mental model:

```text
ARC
=
controlled application recovery
and traffic-shift mechanisms
```

---

# 37.52 Zonal Shift

Suppose:

```text
AZ-B
```

has a problem.

ARC Zonal Shift lets you manually shift traffic for supported resources away from that Availability Zone to healthy AZs **within the same Region**. ([AWS Documentation][11])

Architecture:

```text
              ALB / supported resource

          ┌────────┼────────┐
          ▼        ▼        ▼
        AZ-A      AZ-B     AZ-C
                   X

                    ↓
                Zonal Shift

          ┌────────────┬───────┐
          ▼            ▼
        AZ-A          AZ-C
```

---

# 37.53 Zonal Autoshift

Zonal Autoshift can automatically shift traffic away from an AZ when AWS identifies a potential AZ impairment for supported resources, while zonal shift is manually initiated. ([AWS Documentation][12])

Mental distinction:

```text
ZONAL SHIFT
=
I initiate it


ZONAL AUTOSHIFT
=
AWS can initiate the shift
for supported scenarios
```

Both are:

```text
AZ-level
```

not:

```text
Region-to-Region DR.
```

---

# 37.54 ARC Region Switch

AWS's current ARC Region switch capability can coordinate recovery operations across Regions and supports both active/passive failover/failback and active/active shift-away/return patterns. It also supports cross-account application resources in a recovery plan. ([AWS Documentation][10])

Conceptually:

```text
           PRIMARY REGION
                  │
                  X
                  │
             ARC plan
                  │
                  ▼
           RECOVERY REGION
```

This is a modern capability we'll cover carefully rather than teaching only older DNS-failover patterns.

---

# 37.55 Route 53 vs ARC

Don't yet think:

```text
ARC replaces Route 53.
```

ARC routing controls can work with Route 53 health checks and DNS records so the routing-control state influences which endpoint Route 53 serves. ([AWS Documentation][13])

Mental separation:

```text
Route 53
=
DNS traffic routing


ARC
=
recovery control/orchestration
around traffic shifting
```

We'll refine this in later parts.

---

# 37.56 The DR questions to ask BEFORE choosing AWS services

Never begin a DR design with:

> "Should I use Aurora Global Database?"

Start here:

```text
1. What disasters are we protecting against?


2. What is the RTO?


3. What is the RPO?


4. What data can be lost?


5. Can DR be active/passive?


6. Can users write in both Regions?


7. What capacity must DR handle?


8. How will DNS/traffic fail over?


9. How will credentials/secrets/config replicate?


10. How will we test failover?


11. How will we fail back?


12. What can the business afford?
```

Then select AWS technologies.

That's architecture.

---

# 37.57 Example business workloads

Let's classify four systems.

## Payroll reporting

```text
Business criticality:
moderate

RTO:
8 hours

RPO:
24 hours
```

Likely worth evaluating:

```text
Backup & Restore
```

rather than instantly designing global active/active.

---

## E-commerce frontend

```text
RTO:
30 minutes

RPO:
5 minutes
```

Maybe:

```text
Warm standby
```

depending on application/data architecture.

---

## Payment authorization

```text
RTO:
very aggressive

RPO:
near-zero requirement
```

Potentially:

```text
advanced Multi-Region
```

with a carefully designed distributed data layer.

Not simply:

```text
copy EC2 to Singapore.
```

---

## Development environment

```text
RTO:
days

RPO:
perhaps hours/day
```

Maybe:

```text
IaC + backup
```

is sufficient.

Same AWS Organization; completely different DR strategies.

---

# 37.58 One company can use all four strategies

A common mistake:

> "What's our company's DR strategy?"

Maybe there isn't **one**.

A company could use:

```text
Payments
→ Active/Active


Customer API
→ Warm Standby


Analytics
→ Pilot Light


Internal Wiki
→ Backup & Restore
```

Because business requirements differ.

This is a much more mature approach than forcing one recovery pattern onto every workload.

---

# 37.59 DR architecture should be tested

A diagram saying:

```text
Singapore = DR
```

doesn't prove anything.

You need exercises such as:

```text
Can DR start?

Can DB promote?

Can DR handle production load?

Can users reach it?

Do secrets exist?

Does IAM work?

Are TLS certificates present?

Does DNS change?

Do queues recover?

Can dependencies reach each other?

Can we fail back?
```

AWS guidance specifically recommends building recovery mechanisms into lower environments and using repeatable automation/IaC so failover processes are actually testable. ([AWS Documentation][8])

---

# 37.60 Disaster Recovery test

Conceptually:

```text
NORMAL

Mumbai serving traffic


TEST START

simulate Mumbai unavailable
         ↓
execute DR runbook
         ↓
activate Singapore
         ↓
redirect traffic
         ↓
validate app
         ↓
measure RTO
         ↓
measure RPO
         ↓
fail back
         ↓
document problems
```

If measured:

```text
Target RTO = 30 min
```

but test gives:

```text
Actual = 1h 42m
```

then your architecture does **not** meet its RTO.

The PowerPoint says nothing.

Measured recovery matters.

---

# 37.61 RTO is an objective, not a promise

Business says:

```text
RTO = 15 minutes
```

That means architecture must be designed and tested toward that objective.

It doesn't mean:

```text
AWS magically guarantees recovery
in 15 minutes.
```

Your implementation has to make it possible.

---

# 37.62 RPO depends heavily on replication and backup frequency

Example:

Backup every:

```text
24 hours
```

Potential RPO could be very large.

Backup every:

```text
15 minutes
```

may permit a smaller recovery point.

Continuous replication may reduce it further.

But technologies differ regarding:

```text
replication lag
consistency
failure mode
write semantics
```

So never blindly equate:

```text
replicated
=
zero RPO.
```

---

# 37.63 The data layer will drive much of Lesson 37

We'll eventually compare multi-Region capabilities/patterns involving:

```text
Amazon S3

Amazon RDS

Aurora

DynamoDB

EBS snapshots

AWS Backup

EFS

ElastiCache

OpenSearch

SQS/SNS/EventBridge

Secrets Manager

SSM Parameter Store
```

because each has different replication/recovery characteristics.

That's why DR cannot be reduced to:

```text
Route 53 failover.
```

Traffic routing is only one part.

---

# 37.64 Dependency problem

Application in DR needs:

```text
Database
Secrets
KMS keys/policy
DNS
IAM
container image
configuration
certificates
queues
third-party APIs
```

If you replicated:

```text
database ✓
```

but forgot:

```text
application secret ✕
```

then the DR environment can still be useless.

Think:

```text
DR must include
the dependency graph
```

not only servers.

---

# 37.65 Example dependency graph

```text
                         USER
                           │
                           ▼
                       Route 53
                           │
                           ▼
                       CloudFront
                           │
                           ▼
                          ALB
                           │
                           ▼
                         ECS
                     /     |     \
                    /      |      \
                   ▼       ▼       ▼
                Aurora    SQS    Secrets
                   │               │
                   ▼               ▼
                  KMS          IAM/KMS
```

Your recovery strategy must answer:

> What happens to **every one of these dependencies** during Regional recovery?

---

# 37.66 Regional service vs global service thinking

During multi-Region design we'll continuously classify resources as:

```text
Regional

or

global / globally controlled
```

because recovery plans differ.

For example, workloads often need region-specific copies of compute/data resources while traffic-management or identity capabilities may have broader/global characteristics.

We'll verify every service as we use it rather than blindly assuming:

```text
"AWS automatically replicates everything globally."
```

It doesn't.

---

# 37.67 The most dangerous DR assumption

> "AWS has multiple Regions, so my application is automatically protected."

No.

If everything is deployed only in:

```text
ap-south-1
```

then the existence of:

```text
ap-southeast-1
```

does nothing for your workload until you design and deploy recovery capability there.

---

# 37.68 Second dangerous assumption

> "Our data is replicated, so DR is complete."

No.

What about:

```text
compute
networking
security
DNS
secrets
certificates
IAM
capacity
dependencies
failover procedure
failback
```

DR is a system-level property.

---

# 37.69 Third dangerous assumption

> "We take backups."

Good.

But ask:

```text
Have you restored them?

How long does restore take?

Are they cross-Region?

Are they protected against deletion?

Do they contain all required data?

Does the restored app actually work?
```

A backup that has never been restored is an untested assumption.

---

# 37.70 Fourth dangerous assumption

> "Our secondary Region is identical."

Check:

```text
service quotas?

instance capacity?

IAM roles?

KMS setup?

container images?

latest app version?

database schema?

network routes?

WAF policies?

DNS?

certificates?
```

Configuration drift can quietly destroy recovery readiness.

ARC readiness checks can monitor items such as quotas, capacity, and routing policy for multi-Region recovery environments. ([AWS Documentation][14])

---

# 37.71 Never-forget recovery spectrum

```text
                      RECOVERY SPEED

Slower                                      Faster
  │                                           │
  ▼                                           ▼

BACKUP        PILOT        WARM          ACTIVE/
RESTORE       LIGHT        STANDBY       ACTIVE

   │            │             │              │

lowest        lower        higher         highest
steady-state  running      running        running
capacity      capacity     capacity       capacity
```

This is conceptual, but incredibly useful.

---

# 37.72 Never-forget cost trade-off

Generally:

```text
Faster recovery
      ↑
      │
more resources already ready
      │
      ↑
higher steady-state cost
```

But don't interpret this as an exact price formula.

Architecture, managed-service choices, data transfer, and operational complexity all matter.

---

# 37.73 First interview question

> What are RTO and RPO?

Strong answer:

> **RTO is the maximum acceptable amount of time to restore a workload after disruption. RPO is the maximum acceptable amount of data loss measured by how far back the recovery point can be.**

That's exactly aligned with AWS's definitions. ([AWS Documentation][4])

---

# 37.74 Second interview question

> What's the difference between HA and DR?

Strong answer:

> **High availability keeps a workload operating through expected component or AZ failures, typically within a Region. Disaster recovery focuses on restoring the workload after a larger disruptive event, potentially using another Region or recovery environment, according to RTO and RPO.**

---

# 37.75 Third interview question

> Pilot Light vs Warm Standby?

Answer:

```text
Pilot Light:
critical core/data remains ready,
but significant application resources
must be started/deployed/scaled.


Warm Standby:
complete functional stack already runs
at reduced capacity and mainly
needs scaling during recovery.
```

AWS makes exactly this distinction. ([AWS Documentation][6])

---

# 37.76 Fourth interview question

> Which DR strategy has the lowest steady-state resource footprint?

Usually:

# Backup and Restore.

But qualify your answer by saying the actual cost depends on implementation.

---

# 37.77 Fifth interview question

> Which classic strategy can provide the most aggressive recovery?

Generally:

# Multi-Site Active/Active.

Because both locations are already serving production, but it requires a much more complex application and data design. ([AWS Documentation][3])

---

# 37.78 Sixth interview question

> Does active/active mean RPO is automatically zero?

# No.

Data-layer consistency and replication semantics determine actual data-loss behavior.

That's a very important answer.

---

# 37.79 Seventh interview question

> Is Multi-AZ the same as Multi-Region DR?

# No.

Multi-AZ distributes a workload across isolated AZs inside a Region.

Multi-Region uses separate Regions as fault-isolation boundaries and is used when the workload's recovery requirements justify regional recovery. ([AWS Documentation][2])

---

# 37.80 The mental framework for every future DR architecture

When I show you any AWS system, use:

```text
                  DR ANALYSIS

                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼

        RTO           RPO       FAILURE
                                 SCOPE

         │             │            │
         └─────────────┼────────────┘
                       ▼

                 DR STRATEGY

         Backup / Pilot / Warm / Active

                       │
                       ▼

                    DATA

                       │
                       ▼

                 INFRASTRUCTURE

                       │
                       ▼

                 TRAFFIC SHIFT

                       │
                       ▼

                    TESTING

                       │
                       ▼

                   FAILBACK
```

If one of those boxes is missing, the DR plan is incomplete.

---

# 37.81 Lesson 37 roadmap

Lesson 37 will proceed like this:

```text
Part 1
RTO/RPO + HA vs DR + four DR strategies
✓ CURRENT


Part 2
Backup & Restore Deep Dive
AWS Backup, snapshots, PITR,
cross-Region copies, restore workflows


Part 3
Pilot Light & Warm Standby
Terraform, application scaling,
database replication, recovery runbooks


Part 4
Multi-Region Active/Passive
Route 53 failover, health checks,
traffic shifting, dependencies


Part 5
Multi-Region Active/Active
data consistency, global services,
write strategies, conflict problems


Part 6
Multi-Region Data Layer
Aurora, RDS, DynamoDB, S3,
replication patterns


Part 7
Amazon Application Recovery Controller
Region switch, routing controls,
zonal shift/autoshift, readiness


Part 8
DR Automation, Testing & Chaos Exercises
IaC, failover drills, failback,
monitoring, runbooks


Part 9
Complete Multi-Region DR Capstone


Part 10
Final Revision + SAA/DOP/Interview Mastery
```

So Lesson 37 will be **large, but more controlled than Lesson 36**.

---

# 37.82 Final Part-1 memory sheet

```text
HA
=
keep serving through local failures


DR
=
restore after major disruption


RTO
=
how quickly must service return?


RPO
=
how much data can be lost?


BACKUP & RESTORE
=
rebuild + restore


PILOT LIGHT
=
critical core already alive


WARM STANDBY
=
full smaller stack already running


ACTIVE/ACTIVE
=
multiple sites actively serving


REPLICATION
≠
BACKUP


MULTI-AZ
≠
MULTI-REGION


FAILOVER
=
primary → recovery


FAILBACK
=
recovery → restored primary
```

---

# Next — Lesson 37, Part 2

## AWS Backup & Restore Deep Dive

Next we'll go from:

```text
"We take backups."
```

to the production-level questions:

```text
What exactly is backed up?

Where?

How frequently?

How is it encrypted?

Can an attacker delete it?

Is it copied cross-Region?

How do PITR and snapshots differ?

What is AWS Backup Vault Lock?

How do RDS/Aurora/EBS/S3 backups differ?

How do we restore an entire application?

How do we test that restore?

How do we automate it with Terraform?
```

Then we'll build an actual **backup-and-restore DR architecture** before moving into **Pilot Light and Warm Standby**.

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/plan-for-disaster-recovery-dr.html?utm_source=chatgpt.com "Plan for Disaster Recovery (DR) - Reliability Pillar"
[2]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/multi-region-architecture.html?utm_source=chatgpt.com "Multi-Region Architecture - AWS Prescriptive Guidance"
[3]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the ..."
[4]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/disaster-recovery-dr-objectives.html?utm_source=chatgpt.com "Disaster Recovery (DR) objectives - Reliability Pillar"
[5]: https://docs.aws.amazon.com/prescriptive-guidance/latest/aws-multi-region-fundamentals/fundamental-1.html?utm_source=chatgpt.com "Multi-Region fundamental 1: Understanding the requirements"
[6]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html?utm_source=chatgpt.com "Disaster recovery options in the cloud"
[7]: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-database-disaster-recovery/defining.html?utm_source=chatgpt.com "Defining your disaster recovery strategy"
[8]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_withstand_component_failures_failover2good.html?utm_source=chatgpt.com "REL11-BP02 Fail over to healthy resources - Reliability Pillar"
[9]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_auto_recovery.html?utm_source=chatgpt.com "REL13-BP05 Automate recovery - Reliability Pillar"
[10]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch.html?utm_source=chatgpt.com "Region switch in ARC - Amazon Application Recovery Controller ..."
[11]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-shift.html?utm_source=chatgpt.com "Zonal shift in ARC"
[12]: https://docs.aws.amazon.com/r53recovery/latest/dg/multi-az.html?utm_source=chatgpt.com "Use zonal shift and zonal autoshift to recover applications in ARC"
[13]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.create-health-check.html?utm_source=chatgpt.com "Creating a routing control health check in ARC"
[14]: https://docs.aws.amazon.com/r53recovery/latest/dg/recovery-readiness.html?utm_source=chatgpt.com "Readiness check in ARC - Amazon Application Recovery ..."
