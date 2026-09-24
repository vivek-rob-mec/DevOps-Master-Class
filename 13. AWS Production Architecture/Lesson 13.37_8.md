# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 8: DR Automation, Game Days, Chaos Engineering & Recovery Validation

We have now designed:

```text
Multi-AZ resilience        ✓

Backup and Restore         ✓

Pilot Light                ✓

Warm Standby               ✓

Active/Passive             ✓

Active/Active              ✓

Multi-Region data          ✓

ARC recovery control       ✓
```

But none of that proves:

# **The recovery architecture actually works.**

AWS Well-Architected explicitly recommends testing disaster-recovery implementations and conducting game days regularly rather than relying on architecture documentation alone. ([AWS Documentation][1])

This part is about proving resilience **before a real disaster does it for us**.

---

# 37.603 The most dangerous DR sentence

> "It should work."

Examples:

```text
"The Aurora replica should promote."

"The Singapore ECS cluster should scale."

"Route 53 should fail over."

"The backups should restore."

"The second AZ should handle traffic."

"The VPN backup should take over."
```

Those are assumptions.

Production engineering asks:

```text
Did we actually test it?

How long did it take?

What broke?

Was any data lost?

Did customers notice?

Could we fail back?
```

---

# 37.604 DR testing hierarchy

We'll use this progression:

```text
LEVEL 1
Configuration validation

        ↓

LEVEL 2
Backup restore test

        ↓

LEVEL 3
Component failure

        ↓

LEVEL 4
Instance/container failure

        ↓

LEVEL 5
AZ impairment

        ↓

LEVEL 6
Data-layer failover

        ↓

LEVEL 7
Regional traffic evacuation

        ↓

LEVEL 8
Complete game day

        ↓

LEVEL 9
Failback / reintegration
```

Do not begin your first resilience test with:

```text
"Let's shut down the whole production Region."
```

Build confidence progressively.

---

# 37.605 Three different concepts

We need to separate:

```text
FAILURE TESTING

GAME DAYS

CHAOS ENGINEERING
```

They overlap but aren't identical.

### Failure testing

```text
Known failure
→ verify known recovery mechanism
```

Example:

```text
stop EC2
→ verify ASG replaces it
```

---

### Game day

A planned operational exercise involving:

```text
people
process
technology
runbooks
communications
recovery
```

AWS recommends regular game days that include key stakeholders, known scenarios, recovery workflows, and measured outcomes. ([AWS Documentation][1])

---

### Chaos engineering

Think:

> Form a hypothesis about system resilience, deliberately inject a controlled fault, then observe whether the hypothesis is true.

Example:

```text
HYPOTHESIS:

"If one ECS task disappears,
customer checkout remains healthy."


EXPERIMENT:

Terminate task.


OBSERVE:

ALB health
5xx
latency
replacement time
customer success rate
```

AWS Fault Injection Service exists specifically for running controlled fault-injection experiments against AWS workloads. ([AWS Documentation][2])

---

# 37.606 The chaos experiment loop

Memorize:

```text
HYPOTHESIS
    │
    ▼
STEADY STATE
    │
    ▼
FAULT
    │
    ▼
OBSERVE
    │
    ▼
RECOVER
    │
    ▼
LEARN
    │
    ▼
IMPROVE
    │
    └──────────→ repeat
```

Chaos engineering is not:

```text
break random things
and see what happens.
```

It is structured experimentation.

---

# 37.607 Start with the business outcome

Poor hypothesis:

```text
"EC2 should restart."
```

Better:

```text
"If one application instance fails,
successful checkout rate remains above 99.9%,
p95 latency remains under 800 ms,
and capacity recovers within 5 minutes."
```

Now you've defined:

```text
FAILURE

+

CUSTOMER IMPACT

+

RECOVERY TARGET
```

That's much more meaningful.

---

# 37.608 Define steady state

Before breaking anything, define what "healthy" looks like.

Example:

```text
Checkout success > 99.9%

HTTP 5xx < 0.5%

p95 < 800 ms

Healthy targets >= 4

Queue depth < 1,000

DB connections < 70%

Replication lag < threshold
```

Then your experiment asks:

> Does the system remain inside acceptable boundaries after the fault?

---

# 37.609 Why business metrics beat infrastructure-only metrics

Suppose:

```text
CPU = 25%
Memory = 40%
ALB healthy = YES
```

but:

```text
payment success rate = 0%
```

Infrastructure looks wonderful.

Business is down.

So resilience experiments should ideally include:

```text
technical SLI
+
business SLI
```

Example:

```text
HTTP availability
+
successful orders/minute
```

---

# 37.610 AWS Fault Injection Service — FIS

AWS FIS is the managed AWS service for controlled fault injection.

Core architecture:

```text
              AWS FIS

                 │
                 ▼
        Experiment Template
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
    ACTIONS    TARGETS   STOP
                       CONDITIONS
       │
       ▼
    IAM ROLE
       │
       ▼
   AWS RESOURCES
```

An FIS experiment template defines actions, targets, stop conditions, an experiment role, and optional logging/report configuration. ([AWS Documentation][3])

---

# 37.611 FIS Experiment Template

Think:

```text
EXPERIMENT TEMPLATE
=
blueprint
```

Example:

```text
Target:
EC2 instances tagged App=Payments

Action:
stop instance

Duration:
3 minutes

Stop condition:
checkout error-rate alarm

Logging:
CloudWatch

Report:
S3
```

Then you can start multiple experiments from that template. AWS FIS takes a snapshot of the template when an experiment starts, so later template changes do not alter the already-running experiment. ([AWS Documentation][4])

---

# 37.612 FIS Action

An:

# Action

is what FIS actually does.

Examples vary by AWS service and currently include faults for services such as:

```text
EC2

ECS

EKS

Lambda

networking

RDS and other supported services
```

AWS maintains a current FIS actions reference because available actions evolve over time. ([AWS Documentation][5])

Examples:

```text
Stop EC2 instance

Stop ECS task

Inject CPU stress

Inject memory stress

Inject network latency

Inject packet loss

Trigger Spot interruption simulation
```

---

# 37.613 FIS Target

Target answers:

> **Which resources should experience the fault?**

Example:

```text
Resource type:
EC2 instance

Selection:
tag Environment=DR-Test

Mode:
COUNT(1)
```

Think:

```text
100 instances available

experiment target selection
       ↓
1 instance
```

not:

```text
destroy all 100
```

especially in early testing.

AWS FIS targets can be selected from resources in the experiment account, and multi-account experiments can target resources in additional configured accounts. ([AWS Documentation][6])

---

# 37.614 Blast radius

One of the most important chaos-engineering concepts:

# BLAST RADIUS

Ask:

```text
How much can this experiment break
if every assumption is wrong?
```

For the first test:

```text
1 ECS task
```

is better than:

```text
every production ECS task.
```

Progression:

```text
one component
    ↓
small percentage
    ↓
one AZ
    ↓
one service
    ↓
full failover
```

Confidence should grow before blast radius grows.

---

# 37.615 Stop Conditions

This is a critical AWS FIS safety feature.

FIS experiment templates can use CloudWatch alarms as:

# Stop Conditions.

If the configured alarm enters the relevant state while the experiment is running:

```text
FIS
 ↓
STOP EXPERIMENT
```

AWS documents CloudWatch alarm stop conditions as the mechanism for automatically terminating an experiment when application behavior exceeds acceptable thresholds. ([AWS Documentation][7])

---

# 37.616 Example stop condition

Experiment:

```text
Inject packet loss
into one application instance.
```

CloudWatch alarm:

```text
Checkout5xx > 5%
for 1 minute
```

Flow:

```text
FIS experiment
      │
      ▼
packet loss
      │
      ▼
checkout errors rise
      │
      ▼
CloudWatch ALARM
      │
      ▼
FIS STOP CONDITION
      │
      ▼
experiment terminated
```

That gives us a safety brake.

---

# 37.617 Stop condition vs experiment success criteria

These are not identical.

### Stop condition

```text
"Damage is becoming unacceptable.
Stop now."
```

### Success criteria

```text
"Did the workload meet
the resilience hypothesis?"
```

Example:

```text
Success threshold:

5xx < 1%
```

Emergency stop:

```text
5xx > 5%
```

This creates a buffer.

---

# 37.618 Think like a pilot

A safe experiment has:

```text
NORMAL RANGE

WARNING RANGE

ABORT RANGE
```

Example:

```text
0–1% 5xx
Expected

1–5%
Experiment failed,
but controlled

>5%
STOP immediately
```

That's much safer than:

```text
We'll watch Grafana
and decide manually.
```

---

# 37.619 FIS experiment role

FIS needs IAM permission to perform its actions.

Example:

```text
FIS
 │
AssumeRole
 │
 ▼
Experiment IAM Role
 │
 └── permission:
     ec2:StopInstances
```

Use:

# Least privilege.

Do not create:

```text
Effect: Allow
Action: *
Resource: *
```

because it's convenient for chaos testing.

Your fault-injection system is powerful by definition.

Treat its permissions accordingly.

---

# 37.620 Experiment logs

AWS FIS experiment activity can be sent to:

```text
CloudWatch Logs
```

or:

```text
Amazon S3
```

for later analysis and evidence. ([AWS Documentation][8])

Think:

```text
Experiment starts
      │
      ▼
Action triggered
      │
      ▼
Target selected
      │
      ▼
Stop condition?
      │
      ▼
Experiment completed
      │
      ▼
LOGS
```

That matters for:

```text
postmortem

audit

training

compliance

debugging
```

---

# 37.621 FIS reports

FIS can also generate experiment reports.

Current reports can summarize experiment actions and optionally include snapshots from a CloudWatch dashboard, with reports delivered to S3. ([AWS Documentation][9])

So your resilience evidence might contain:

```text
Experiment:
AZ packet-loss test

Started:
14:00

Finished:
14:12

Target:
AZ-A resources

Result:
Completed

5xx:
0.1% → 0.4%

Latency:
220ms → 390ms

Recovery:
3m 42s
```

That's much stronger than:

```text
"Test went okay."
```

---

# 37.622 EventBridge integration

FIS emits experiment-state changes through Amazon EventBridge, so automation can react when an experiment:

```text
starts

stops

completes

fails
```

For example:

```text
FIS Completed
     │
     ▼
EventBridge
     │
     ├── SNS
     │
     └── Lambda
```

AWS documents EventBridge integration for responding to experiment state changes. ([AWS Documentation][10])

---

# 37.623 CloudTrail

CloudTrail records FIS API calls and underlying API actions related to targeted resources.

That allows you to answer:

```text
Who started the experiment?

When?

Which action?

Which resource?

Which account?
```

AWS documents all FIS API actions as CloudTrail-recorded, with resource-service API calls also visible in the relevant service's CloudTrail events. ([AWS Documentation][11])

---

# 37.624 FIS Scenario Library

AWS FIS also provides a scenario library to help construct common resilience experiments rather than requiring every experiment to begin from a blank template. AWS recommends configuring stop conditions and experiment logging even when starting from scenarios. ([AWS Documentation][12])

But still review:

```text
targets

blast radius

permissions

stop conditions

expected impact
```

before starting anything.

Never think:

```text
AWS provided scenario
=
safe for my production workload.
```

The workload context remains yours.

---

# 37.625 Multi-account experiments

Remember our enterprise structure?

```text
Network Account

Security Account

Prod Application Account

Shared Services Account
```

A realistic resilience exercise may span several accounts.

FIS supports:

```text
multi-account experiments
```

where one orchestrator account owns the experiment and configured target-account roles allow FIS actions against selected resources in other accounts. ([AWS Documentation][13])

Architecture:

```text
CHAOS / RESILIENCE ACCOUNT
        │
        ▼
      FIS
   /     |      \
  ▼      ▼       ▼
Prod  Shared   Network
```

Very relevant to enterprise AWS.

---

# 37.626 But central chaos permissions can be dangerous

Imagine:

```text
Central FIS role

can stop resources in:
Prod
Dev
Security
Network
```

A compromised role could have an enormous blast radius.

Use controls such as:

```text
strict IAM

resource tags

account boundaries

approval workflow

SCPs where appropriate

specific experiment roles

CloudTrail

stop alarms
```

Centralized fault injection should not become a centralized outage mechanism.

---

# 37.627 First practical experiment — EC2 instance failure

Hypothesis:

> **Losing one application instance should produce no customer-visible outage.**

Architecture:

```text
ALB
 │
 ├── EC2-A
 ├── EC2-B
 └── EC2-C
```

Experiment:

```text
Stop EC2-B
```

Observe:

```text
ALB healthy hosts

5xx

latency

ASG replacement

replacement registration

application logs
```

AWS provides an FIS tutorial specifically demonstrating EC2 stop/start experiments. ([AWS Documentation][14])

---

# 37.628 Expected sequence

```text
EC2-B
  X

   ↓

ALB health check detects target failure

   ↓

traffic goes to A + C

   ↓

Auto Scaling notices desired capacity gap

   ↓

new EC2-D launched

   ↓

bootstrap

   ↓

ALB target healthy

   ↓

capacity restored
```

Measure every stage.

---

# 37.629 What do we measure?

Example:

```text
T0
instance stopped

T+10 sec
ALB begins removing target

T+45 sec
ASG launches replacement

T+2m 20s
application process ready

T+2m 50s
ALB target healthy

T+3m
capacity fully restored
```

Now you have actual recovery evidence.

---

# 37.630 The experiment may expose hidden problems

For example:

```text
ASG launches replacement
        ✓

user data fails
        ✕

application doesn't start
        ✕
```

or:

```text
EC2 launches
        ✓

Secrets Manager permission
        ✕

target remains unhealthy
```

That's exactly what we want to discover during a controlled test.

---

# 37.631 ECS task-failure test

Hypothesis:

> Stopping one ECS task should not significantly affect availability.

Architecture:

```text
ALB
 │
 ├── Task-1
 ├── Task-2
 ├── Task-3
 └── Task-4
```

FIS supports ECS task fault actions among its service-specific capabilities. ([AWS Documentation][3])

Test:

```text
Task-2
   X
```

Observe:

```text
desired count

replacement task

image pull

startup time

ALB registration

5xx

latency
```

---

# 37.632 Hidden ECR dependency

Suppose replacement task needs:

```text
ECR
```

but the image tag was deleted.

Then:

```text
old tasks
still healthy

new task
cannot start.
```

Normal operation hides the problem.

Failure injection exposes it.

That's why chaos testing finds **latent failures**.

---

# 37.633 EKS pod failure

AWS FIS also has EKS pod actions for injecting faults into Kubernetes workloads. ([AWS Documentation][15])

Hypothesis:

```text
One checkout pod can disappear
without user impact.
```

Test:

```text
Pod X
```

Observe:

```text
Deployment desired replicas

scheduler placement

Pod startup

readiness probes

service endpoints

PDB behavior

5xx
```

This directly connects our AWS course to the Kubernetes production module.

---

# 37.634 CPU stress test

Another class:

```text
CPU saturation
```

Hypothesis:

> If one compute node is CPU-saturated, traffic and autoscaling should keep the service healthy.

Example fault:

```text
CPU
20%
 ↓
100%
```

Observe:

```text
p95

p99

ALB response time

CPU alarm

Auto Scaling

task placement

customer success
```

FIS provides experiment examples for CPU fault injection using Systems Manager-based fault documents. ([AWS Documentation][16])

---

# 37.635 Network latency experiment

Distributed systems fail in nastier ways when:

```text
network isn't DOWN

but

network is SLOW.
```

Example:

```text
App
 │
 300ms injected latency
 │
 ▼
dependency
```

Symptoms:

```text
thread pools fill

timeouts

retries

connection pools expand

queue backlog grows
```

Sometimes slow dependencies cause more damage than completely dead ones.

---

# 37.636 Packet-loss experiment

Hypothesis:

> Application retries tolerate moderate packet loss without duplicate business transactions.

Inject:

```text
5% packet loss
```

Observe:

```text
request retries

duplicate transactions

idempotency

latency

connection resets

error rate
```

FIS supports networking fault scenarios/actions such as packet loss and network impairment through supported mechanisms/actions. ([AWS Documentation][17])

---

# 37.637 This tests Part 5 idempotency

Remember:

```text
POST /payment

Mumbai processes request

response lost

client retries
```

Packet loss lets us intentionally reproduce this.

Expected:

```text
ONE payment
```

not:

```text
TWO payments.
```

Chaos testing turns distributed-systems theory into evidence.

---

# 37.638 AZ-level testing

Now enlarge blast radius.

Architecture:

```text
             ALB

     ┌────────┼────────┐
     ▼        ▼        ▼

   AZ-A     AZ-B     AZ-C
```

Hypothesis:

> The application can survive removal of any one AZ without violating its SLO.

Test:

```text
AZ-B removed
```

Observe:

```text
request distribution

surviving CPU

DB impact

NAT paths

capacity

5xx

latency
```

---

# 37.639 ARC Zonal Shift is excellent for this

You don't necessarily need to destroy instances.

You can deliberately shift supported-resource traffic away from:

```text
AZ-B
```

using ARC Zonal Shift.

Then:

```text
AZ-A + AZ-C
```

must handle the workload.

This tests the architecture's **static stability**.

---

# 37.640 ARC Zonal Autoshift practice runs

If Zonal Autoshift is enabled, ARC requires practice-run configuration and periodically shifts traffic away from an AZ to prove that the application can survive without that AZ. AWS says practice runs are roughly weekly and approximately 30 minutes, with at least one outcome alarm required; optional blocking alarms can prevent or interrupt an unsafe practice run. ([AWS Documentation][18])

This is effectively:

```text
resilience testing
built into operations.
```

---

# 37.641 Outcome Alarm

Remember:

```text
OUTCOME ALARM
=
Did the experiment harm
the application?
```

Example:

```text
CheckoutSuccess < 99.5%
```

If it alarms during a practice run:

```text
test outcome indicates
the architecture did not
comfortably tolerate AZ loss.
```

At least one outcome alarm is required for zonal-autoshift practice runs. ([AWS Documentation][19])

---

# 37.642 Blocking Alarm

Remember:

```text
BLOCKING ALARM
=
Is this already a dangerous
time to run the experiment?
```

Example:

```text
Current5xx > 1%

or

DatabaseCPU > 80%
```

Then:

```text
do not start AZ-loss exercise.
```

Blocking alarms are optional but can stop or prevent practice runs when existing conditions make the test unsafe. ([AWS Documentation][20])

---

# 37.643 Prescale before AZ testing

AWS specifically recommends pre-scaling capacity before enabling zonal autoshift or running practice shifts, rather than relying on reactive scale-out after an AZ has already been removed. ([AWS Documentation][21])

Why?

Normal:

```text
AZ-A 33%
AZ-B 33%
AZ-C 33%
```

After losing B:

```text
AZ-A + AZ-C
must absorb 100%
```

If each was already:

```text
90% CPU
```

no recovery mechanism can invent capacity.

---

# 37.644 Database failover drill

Now move to stateful failure.

Example:

```text
Aurora Multi-AZ
```

or:

```text
Aurora Global Database
```

Hypothesis:

> Database failover occurs within the application's required RTO, and applications reconnect without manual restarts.

Measure:

```text
failure time

DB writer transition

connection errors

client retry behavior

new writer resolution

transaction loss

recovery
```

---

# 37.645 DB test is not only "new writer available"

Suppose:

```text
writer restored in 40 seconds
```

but app connection pool retries only every:

```text
5 minutes.
```

Application recovery:

```text
5+ minutes.
```

So again:

```text
DB RTO
≠
application RTO.
```

---

# 37.646 Transaction correctness test

Before failover:

```text
Order 1001 = CREATED
```

During failover:

```text
Order 1002 submitted
```

After recovery ask:

```text
Does 1001 exist?

Does 1002 exist?

Was 1002 duplicated?

Was payment charged once?

Are events consistent?
```

For databases, don't measure only:

```text
endpoint became healthy.
```

Measure:

# Business state correctness.

---

# 37.647 RPO measurement

Suppose target:

```text
RPO = 30 seconds
```

During test:

```text
T0
last known committed record

T+10
new record

T+20
new record

T+25
failure

T+60
DR active
```

Check recovered database.

If records through:

```text
T+20
```

exist:

```text
data loss ~5 seconds
```

Fine.

If last recovered record was:

```text
T-2 minutes
```

your RPO failed.

---

# 37.648 Never infer RPO from architecture name

Don't write:

```text
Aurora Global
therefore RPO = 0.
```

or:

```text
Active/Active
therefore RPO = 0.
```

Measure the actual recovery semantics appropriate to the data system, as we learned in Part 6.

---

# 37.649 Backup restore test

Now return to Part 2.

AWS Backup provides **restore testing plans** that periodically select recovery points and start restore jobs so you can prove they are restorable. ([AWS Documentation][22])

Architecture:

```text
Backup Vault
     │
     ▼
Restore Testing Plan
     │
     ▼
Recovery Point
     │
     ▼
Temporary Restored Resource
```

This should be part of your resilience program even if you also have replication.

---

# 37.650 Restore-testing validation

AWS Backup can integrate restore-testing completion with EventBridge.

Example:

```text
Restore Job
COMPLETED
    │
    ▼
EventBridge
    │
    ▼
Lambda
    │
    ▼
Validation
```

AWS explicitly documents this pattern for performing post-restore validation with Lambda or another EventBridge-supported target. ([AWS Documentation][23])

---

# 37.651 Example restored DB validation

After restore:

```bash
psql -h <restored-db> ...
```

Then test:

```sql
SELECT COUNT(*) FROM orders;

SELECT MAX(created_at) FROM orders;
```

Validate:

```text
schema exists

latest expected records

constraints

application user permissions

critical tables
```

Then optionally report:

```text
VALID
```

or:

```text
INVALID
```

back into the testing workflow.

---

# 37.652 Restore metadata matters

Restore jobs require metadata such as:

```text
subnet

security group

instance settings

encryption

target configuration
```

AWS Backup's current restore-testing capability can infer much of the metadata needed for supported restores, and AWS added APIs to preview inferred metadata. ([AWS Documentation][24])

This reduces—but does not eliminate—the need to understand actual restore requirements.

---

# 37.653 Full application restore test

More mature test:

```text
Restore DB
    │
    ▼
Deploy temporary app
    │
    ▼
Attach restored DB
    │
    ▼
Run smoke tests
    │
    ▼
Run business validation
    │
    ▼
Measure elapsed time
    │
    ▼
destroy test environment
```

Now you're testing:

```text
BACKUP
+
INFRASTRUCTURE
+
APPLICATION
+
OPERATIONS
```

not merely the backup engine.

---

# 37.654 AWS Resilience Hub

Another useful AWS service in this space is:

# AWS Resilience Hub.

It lets you define application resiliency policies with:

```text
RTO
RPO
```

targets, assess application architecture against those objectives, and receive resilience recommendations. ([AWS Documentation][25])

Mental model:

```text
Application
    │
    ▼
Resiliency Policy
RTO / RPO
    │
    ▼
Assessment
    │
    ├── gaps
    ├── recommendations
    ├── alarms
    ├── SOPs
    └── FIS tests
```

---

# 37.655 Resilience Hub is not proof either

Resilience Hub estimates whether application architecture is expected to meet policy objectives.

AWS explicitly notes that its RTO/RPO values are estimates and recommends actual testing, including AWS FIS, to determine real recovery performance. ([AWS Documentation][26])

So:

```text
Resilience Hub Assessment
=
architecture analysis
```

while:

```text
FIS / Game Day
=
runtime evidence.
```

Same distinction as:

```text
Reachability Analyzer
vs
real packets
```

from Lesson 36.

---

# 37.656 Resilience Hub + FIS

AWS Resilience Hub can recommend or manage tailored AWS FIS experiments based on the application's resources and assessed resilience posture. ([AWS Documentation][27])

Conceptually:

```text
Resilience Hub
     │
     ▼
find resilience weakness
     │
     ▼
recommend FIS experiment
     │
     ▼
run experiment
     │
     ▼
observe real behavior
```

That's a nice:

```text
ASSESS
→ TEST
→ IMPROVE
```

cycle.

---

# 37.657 What is a Game Day?

AWS describes game days as planned exercises where teams test how:

```text
people

process

technology
```

respond to operational events.

They should have:

```text
defined scope

participants

runbooks

failure scenario

recovery process

observations

follow-up actions
```

AWS Well-Architected recommends conducting them regularly. ([AWS Documentation][1])

---

# 37.658 Game Day is not only an engineering test

Participants might include:

```text
Incident Commander

SRE

DevOps

Application engineers

Database team

Networking

Security

Cloud platform team

Business representative

Communications
```

Why?

Because real disasters create organizational problems too.

Example:

```text
Who declares the disaster?

Who approves DB promotion?

Who speaks to customers?

Who contacts AWS Support?

Who tracks RTO?

Who owns failback?
```

Technology alone cannot answer those.

---

# 37.659 Game Day roles

A useful structure:

```text
GAME DAY LEAD
controls scenario


INCIDENT COMMANDER
coordinates recovery


APPLICATION TEAM
diagnoses app


DATA TEAM
handles writer/recovery


NETWORK TEAM
handles routing


OBSERVER / SCRIBE
records timeline


BUSINESS OWNER
validates service priorities
```

Separating:

```text
experiment controller
```

from:

```text
incident responders
```

is useful.

Responders shouldn't necessarily know every injected fault in advance if you're testing diagnosis.

---

# 37.660 Two game-day styles

### Known scenario

Everyone knows:

```text
"We are testing loss of AZ-B."
```

Good for:

```text
first exercises

runbook validation

training
```

### Blind / partially blind scenario

Responders know:

```text
"An incident will occur."
```

but not exactly what.

Good for:

```text
detection

diagnosis

incident command

communication
```

Start known.

Earn your way toward blind tests.

---

# 37.661 Pre-game checklist

Before deliberately injecting failure:

```text
Scope approved?                ✓

Business owner informed?       ✓

Experiment window?             ✓

Stop conditions?               ✓

Blast radius reviewed?         ✓

Rollback/recovery commands?    ✓

Observability working?         ✓

Backups verified?              ✓

On-call engineers available?   ✓

AWS Support contact path?      ✓

No major deployment running?   ✓

Blocking conditions clear?     ✓
```

Never perform chaos from:

```text
"I have admin access,
let's see what happens."
```

---

# 37.662 Experiment card

Create something like:

```text
Experiment:
AZ-B Evacuation

Hypothesis:
Checkout remains ≥99.9% successful
with AZ-B removed.

Scope:
Payments application

Blast Radius:
One AZ

Duration:
20 minutes

Success:
5xx < 1%
p95 < 900ms

Stop:
5xx > 5%
DB CPU > 90%

Recovery:
End shift / restore traffic

Owner:
Platform SRE

Observers:
App + DB + Network
```

This simple document forces clarity.

---

# 37.663 Start with reversible faults

Good early experiments:

```text
stop one instance

stop one task

inject latency

remove one AZ from traffic

scale a worker to zero

simulate dependency failure
```

Be cautious with irreversible/destructive actions such as:

```text
delete database

destroy KMS key

delete production backups
```

Chaos engineering is not an excuse to permanently destroy critical state.

Test recovery from such scenarios using isolated copies or carefully controlled lower environments instead.

---

# 37.664 Progressive blast radius

A mature progression:

```text
DEV
 ↓
STAGING
 ↓
PRE-PROD
 ↓
PRODUCTION SMALL
 ↓
PRODUCTION AZ
 ↓
PRODUCTION REGION
```

AWS Well-Architected recommends testing resiliency regularly and using production game days after resilience mechanisms have already been exercised in safer environments. ([AWS Documentation][28])

---

# 37.665 Why eventually test production?

Because staging often differs:

```text
smaller traffic

different quotas

different IAM

different external integrations

different data volume

different scaling behavior
```

A DR mechanism might work perfectly in staging and fail under:

```text
actual production scale.
```

So mature organizations carefully perform bounded production exercises.

---

# 37.666 But production testing must be earned

Before production:

```text
Experiment works in staging       ✓

Observability validated           ✓

Stop conditions tested            ✓

Rollback tested                   ✓

Expected behavior understood      ✓

Leadership/business approval      ✓

Blast radius minimized            ✓
```

Only then increase scope.

---

# 37.667 Regional game day

Now our main Lesson 37 scenario.

Architecture:

```text
                     USERS

                       │
                  Route53 / ARC
                       │
          ┌────────────┴────────────┐
          ▼                         ▼

       Mumbai                   Singapore
      PRIMARY                    STANDBY
```

Game day:

```text
Simulate Mumbai
unavailable
```

Goal:

```text
Recover in Singapore
within RTO
and RPO.
```

---

# 37.668 Regional game-day sequence

Example:

```text
T0
Start exercise

 ↓

Inject/declare Mumbai failure

 ↓

Monitoring detects incident

 ↓

Incident declared

 ↓

ARC Region Switch starts

 ↓

Database failover

 ↓

Singapore scale-up

 ↓

Validation

 ↓

Traffic shift

 ↓

Customer transaction test

 ↓

RTO measured

 ↓

RPO validated

 ↓

Operate on Singapore

 ↓

Recover Mumbai

 ↓

Failback/reintegration
```

This is the full DR lifecycle.

---

# 37.669 Measure every timestamp

Example:

| Event                          | Time     |
| ------------------------------ | -------- |
| Fault injected                 | 14:00:00 |
| Alert fired                    | 14:01:10 |
| Incident declared              | 14:03:00 |
| DB recovery started            | 14:04:20 |
| DB writer ready                | 14:08:10 |
| ECS scaled                     | 14:10:00 |
| Smoke tests passed             | 14:11:40 |
| Traffic shifted                | 14:12:00 |
| Customer transaction succeeded | 14:12:35 |

Then:

```text
Actual Recovery Time
≈ 12m 35s
```

If target:

```text
RTO = 15 min
```

you passed.

Barely.

Now improve.

---

# 37.670 Break RTO into components

Suppose:

```text
Detection      70 sec

Human decision 110 sec

DB recovery    250 sec

Scaling        110 sec

Validation     100 sec

Traffic         20 sec
```

Now you know where to optimize.

Maybe DB is fine.

Biggest waste:

```text
manual decision.
```

Then automation/approval workflow can improve actual RTO.

This is far better than saying:

```text
"DR is slow."
```

---

# 37.671 RPO test data

Before experiment, create controlled records:

```text
DR_TEST_001
14:00:00

DR_TEST_002
14:00:05

DR_TEST_003
14:00:10
...
```

At failure:

```text
14:00:30
```

After recovery inspect:

```text
latest recovered test record?
```

Suppose:

```text
DR_TEST_005
14:00:20
```

Then approximate data loss:

```text
10 seconds.
```

Now you've measured RPO rather than assumed it.

---

# 37.672 In-flight request validation

Very important.

At failure time, generate:

```text
orders

payments

uploads

messages
```

with unique IDs.

After recovery classify each:

```text
SUCCESS exactly once

FAILED visibly

RETRIED safely

DUPLICATED ✕

LOST ✕
```

This tests:

```text
idempotency

queue delivery

transaction semantics

client retry behavior
```

from Part 5.

---

# 37.673 Queue validation

Suppose before failover:

```text
SQS backlog = 50,000
```

After shifting application:

Ask:

```text
Were messages preserved?

Are Singapore consumers reading them?

Were any processed twice?

Did backlog explode?

Did poison messages block processing?
```

HTTP success alone does not prove event-driven recovery.

---

# 37.674 Session validation

During failover:

```text
User logged in

Cart has 3 products

Checkout on step 3
```

After shift:

```text
Is user still authenticated?

Is cart intact?

Can checkout continue?
```

This tests whether:

```text
session state
```

really survives regional movement.

---

# 37.675 Hybrid dependency validation

Lesson 36 returns again.

Singapore DR may need:

```text
Oracle on-prem

AD/DNS

corporate APIs
```

During game day test:

```text
Singapore → TGW/DX/VPN → On-Prem
```

and:

```text
Singapore → Resolver → corp.internal
```

If those paths aren't tested, your application may recover but enterprise dependencies may fail.

---

# 37.676 Third-party dependency validation

Also test:

```text
payment processor

email provider

fraud API

SaaS API

partner VPN

IP allowlists
```

Example:

```text
Singapore NAT EIP
not allowlisted
```

Your DR application looks healthy internally but all third-party calls fail.

This is precisely why game days need end-to-end scope.

---

# 37.677 Failback is mandatory

Game day isn't over when:

```text
Singapore ACTIVE
```

You must exercise:

```text
Singapore
    ↓
Mumbai recovered
    ↓
data synchronization
    ↓
validate Mumbai
    ↓
traffic reintroduction
```

Otherwise you've tested only half of the recovery lifecycle.

---

# 37.678 Failback can expose worse problems than failover

During the disaster:

```text
Singapore generated new data.
```

Now Mumbai is stale.

If you fail back carelessly:

```text
new Singapore writes
      ↓
lost/overwritten
```

So failback tests:

```text
reverse replication

data authority

re-sync

schema compatibility

traffic shift

rollback
```

Very important.

---

# 37.679 Don't rush failback

Game-day requirement:

```text
Mumbai must remain healthy
for defined stability period

Data synchronized

Smoke test passed

Capacity ready

No replication errors

Approval received
```

then:

```text
traffic reintroduced.
```

This prevents flapping.

---

# 37.680 Game Day scorecard

Example:

| Objective          |  Target | Actual | Result |
| ------------------ | ------: | -----: | ------ |
| Detection          |  <2 min |  1m10s | ✅      |
| DR declaration     |  <5 min |     3m | ✅      |
| DB recovery        |  <7 min |  4m10s | ✅      |
| Traffic recovery   | <15 min | 12m35s | ✅      |
| RPO                | <30 sec | 10 sec | ✅      |
| Duplicate payments |       0 |      0 | ✅      |
| Failback           | <60 min | 72 min | ❌      |

Now you have engineering data.

---

# 37.681 Failure is a successful experiment

Suppose:

```text
Target RTO:
15 min

Actual:
27 min
```

Game day:

# SUCCESS

Why?

Because you discovered the gap before a real disaster.

The application failed its requirement.

The experiment succeeded in producing learning.

Do not punish teams for discovering resilience weaknesses during controlled exercises.

Otherwise teams will design:

```text
easy tests
```

that always pass.

---

# 37.682 Post-game review

Immediately capture:

```text
What worked?

What failed?

What surprised us?

Where was diagnosis slow?

Where was automation missing?

Which alarm was noisy?

Which runbook was wrong?

Which permission failed?

Which dependency was forgotten?

Actual RTO?

Actual RPO?

What needs ownership?
```

Then create tracked remediation.

---

# 37.683 No remediation = no value

Bad:

```text
Game Day
 ↓
found 12 issues
 ↓
write document
 ↓
forget
```

Good:

```text
Game Day
 ↓
find gap
 ↓
ticket
 ↓
owner
 ↓
deadline
 ↓
fix
 ↓
retest
```

The resilience loop ends only after:

```text
learning becomes change.
```

---

# 37.684 Recovery runbooks must be executable

Poor runbook:

```text
"Fail over the database."
```

Better:

```text
1. Verify replica state.
2. Record replication lag.
3. Confirm old writer state.
4. Execute approved failover method.
5. Verify new writer endpoint.
6. Run write/read validation.
7. Record timestamp.
8. Notify traffic owner.
```

A runbook should reduce thinking under pressure.

---

# 37.685 Automate deterministic steps

Humans are excellent at:

```text
judgment

ambiguity

risk assessment

coordination
```

Machines are excellent at:

```text
repeatable API calls

waiting

retrying

checking conditions

collecting timestamps
```

Therefore:

```text
Human:
Declare disaster

Automation:
Scale ECS

Automation:
Run smoke tests

Human:
Approve writer/traffic shift
```

may be an excellent compromise.

---

# 37.686 Automation ladder

### Level 0

```text
All manual
```

### Level 1

```text
documented CLI commands
```

### Level 2

```text
scripts
```

### Level 3

```text
Step Functions / SSM Automation
```

### Level 4

```text
ARC Region Switch
```

### Level 5

```text
event-triggered orchestration
with safety gates
```

Higher isn't always better.

Choose based on:

```text
RTO
risk
complexity
```

---

# 37.687 CI/CD can validate DR continually

Imagine release pipeline:

```text
Build application

      ↓

Deploy Mumbai

      ↓

Deploy/update Singapore

      ↓

Verify ECR image

      ↓

Verify secret replica

      ↓

Verify ACM

      ↓

Run Singapore smoke test

      ↓

Verify DR data health

      ↓

Release complete
```

Now every release keeps DR aligned.

That's much stronger than:

```text
"We update the DR Region quarterly."
```

---

# 37.688 IaC validation

Pipeline can test:

```text
terraform validate

terraform plan

policy checks

region-specific resource existence

CIDR overlap

capacity variables

replica topology

Route53 targets
```

Then periodically perform:

```text
real runtime recovery tests.
```

Again:

```text
IaC correctness
+
runtime testing
```

both matter.

---

# 37.689 Resilience as code

You can store:

```text
FIS templates

CloudWatch alarms

ARC plans

backup plans

restore-test plans

synthetic tests

runbooks

dashboards
```

as code or controlled configuration.

Conceptual repo:

```text
resilience/
│
├── fis/
│   ├── ec2-failure.json
│   ├── latency.json
│   └── az-loss.json
│
├── alarms/
│
├── backup-tests/
│
├── arc/
│
├── runbooks/
│
└── dashboards/
```

Now resilience evolves through code review just like infrastructure.

---

# 37.690 AWS FIS CLI mental workflow

Create template from JSON:

```bash
aws fis create-experiment-template \
  --cli-input-json file://experiment.json
```

AWS documents this exact pattern for CLI-created experiment templates. ([AWS Documentation][29])

Start it:

```bash
aws fis start-experiment \
  --experiment-template-id EXTxxxxxxxxx
```

AWS documents `start-experiment` as the CLI operation for launching an experiment from a template. ([AWS Documentation][4])

But never paste a fault template into production before reviewing its targets and stop conditions.

---

# 37.691 Simplified FIS template anatomy

Conceptual JSON:

```json
{
  "description": "Terminate one test application instance",

  "targets": {
    "AppInstances": {
      "resourceType": "aws:ec2:instance"
    }
  },

  "actions": {
    "StopInstance": {
      "actionId": "aws:ec2:stop-instances"
    }
  },

  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "CHECKOUT_CRITICAL_ALARM_ARN"
    }
  ],

  "roleArn": "FIS_EXPERIMENT_ROLE_ARN"
}
```

An actual FIS template also needs correct target-selection details and action-target mapping, but this shows the core relationship:

```text
TARGET
+
FAULT
+
SAFETY BRAKE
+
IAM
```

which matches the current FIS experiment-template model. ([AWS Documentation][3])

---

# 37.692 Action sequencing

FIS actions can run:

```text
in parallel
```

or:

```text
in a defined dependency order
```

via `startAfter`. ([AWS Documentation][30])

Example:

```text
ACTION 1
inject latency

       ↓

ACTION 2
wait

       ↓

ACTION 3
stop instance
```

But be careful:

Combined faults dramatically increase blast radius.

Start simple.

---

# 37.693 Compound failures

Real disasters aren't always one clean failure.

Example:

```text
AZ-B fails
       +
traffic surges
       +
one DB replica is already unhealthy
```

Later-stage game days can intentionally combine faults.

But only after single-fault resilience is proven.

Progress:

```text
single failure
       ↓
known compound failure
       ↓
complex incident
```

Don't start your chaos program with:

```text
AZ failure + DB failover + network partition + load spike.
```

---

# 37.694 Multi-account FIS example

Enterprise application:

```text
App Account
→ ECS

Shared Account
→ DNS

Network Account
→ network resources
```

A multi-account FIS experiment may target selected resources across these accounts from an orchestrator account, with each target account configured with the appropriate role. ([AWS Documentation][13])

This is powerful for true enterprise game days.

Also potentially dangerous.

Use tight governance.

---

# 37.695 Game-day communication test

A real incident includes:

```text
Slack/ChatOps

PagerDuty/on-call equivalent

email/status page

executive escalation

customer communication

AWS Support
```

During game day ask:

```text
Did the correct on-call receive alert?

How long until acknowledged?

Who became Incident Commander?

Was escalation clear?

Did stakeholders receive updates?
```

AWS game-day guidance explicitly includes people and processes, not only service failover. ([AWS Documentation][1])

---

# 37.696 Incident command timeline

Example:

```text
14:00
fault begins

14:01
monitoring detects

14:02
on-call acknowledges

14:03
incident channel created

14:04
Incident Commander assigned

14:05
DR declared

14:06
recovery workflow starts
```

Notice:

```text
5 minutes
```

was consumed before any infrastructure recovery.

Human process is part of RTO.

---

# 37.697 Observability checklist during chaos

At minimum observe:

```text
TRAFFIC
───────
requests/sec
5xx
4xx
latency


COMPUTE
───────
CPU
memory
healthy instances/tasks
scaling


DATA
────
DB health
replication lag
connections
throttling


EVENTS
──────
queue depth
age of oldest message


NETWORK
───────
flow logs
TGW
VPN/DX where applicable


BUSINESS
────────
checkout success
payment success
orders/minute
```

Don't run chaos blind.

---

# 37.698 Stop-condition metrics should reflect customers

A bad stop condition:

```text
CPU > 90%
```

might stop an experiment even though the application is handling the event beautifully.

Or worse:

```text
CPU < 90%
```

while checkout is completely broken.

Better stop-condition design often combines infrastructure and business signals.

For example:

```text
CheckoutSuccess < 95%

OR

HTTP 5xx > 5%

OR

DB errors > critical threshold
```

Use CloudWatch alarm design that represents actual unacceptable service impact.

---

# 37.699 Composite alarms

CloudWatch composite alarms can help build higher-level safety logic.

Conceptually:

```text
CriticalCustomerImpact
=
High5xx
OR
PaymentFailure
OR
ExtremeLatency
```

Then that alarm can feed:

```text
FIS Stop Condition
```

This is much more meaningful than:

```text
CPUAlarm
```

alone.

---

# 37.700 Test detection, not only recovery

Suppose application fails exactly as expected.

But:

```text
no alert for 15 minutes.
```

Your recovery architecture may be perfect.

Actual RTO still suffers.

Therefore game days test:

```text
DETECTION
+
RECOVERY
```

not only recovery.

---

# 37.701 Test alarm quality

During experiment ask:

```text
Did expected alarm fire?

How long?

Did irrelevant alarms explode?

Could the on-call identify root cause?

Did alert contain enough context?
```

A game day that produces:

```text
300 alarms
```

may reveal alerting architecture problems.

---

# 37.702 Monitor for false positives

Now opposite test.

Inject a harmless:

```text
single task failure.
```

Correct outcome:

```text
ECS recovers
```

without:

```text
Region DR initiated.
```

This verifies that your recovery system respects failure scope.

Remember:

```text
task failure
≠
regional disaster.
```

---

# 37.703 Recovery escalation test

A mature exercise might test:

```text
Task fails
  ↓
ECS handles

Then

AZ degraded
  ↓
Zonal Shift handles

Then

Region unavailable
  ↓
Region Switch handles
```

This proves the resilience hierarchy:

```text
local mechanism first

larger failover only
when failure scope requires it.
```

---

# 37.704 Cost of chaos testing

Experiments can cause real AWS costs:

```text
extra compute

extra data transfer

restore resources

temporary DBs

FIS usage

CloudWatch logs

cross-Region traffic

load testing
```

So experiments should include:

```text
budget

cleanup

resource expiration

tags
```

especially when restoring large datasets or scaling standby environments.

---

# 37.705 Automatic cleanup

Temporary resources should have clear cleanup paths.

Example:

```text
restore-test-db
tag:
Purpose=DR-Test

ExpiresAt=...
```

After validation:

```text
destroy resource.
```

Do not discover one month later:

```text
20 restored RDS instances
still running.
```

---

# 37.706 Recovery test cadence

There is no universal one-size cadence.

Think based on:

```text
criticality

change frequency

RTO

regulation

risk
```

Example:

```text
Backup restore
weekly/monthly

AZ practice
regularly

component chaos
continuous/weekly

regional game day
quarterly/semiannual
```

These are illustrative—not AWS mandates.

AWS Well-Architected's principle is:

# conduct game days regularly. ([AWS Documentation][1])

---

# 37.707 Trigger extra testing after major change

Even if scheduled game day is months away, rerun relevant resilience tests after:

```text
database migration

network redesign

new Region

new container runtime

new deployment architecture

IAM redesign

new KMS setup

traffic-control change
```

Because:

```text
architecture changed
=
old resilience evidence
may no longer apply.
```

---

# 37.708 Drift invalidates yesterday's test

Last month:

```text
Singapore max capacity = 100
```

Today:

```text
someone set max = 10.
```

Your successful previous game day no longer proves current readiness.

Therefore combine:

```text
continuous configuration assessment

+

periodic runtime testing.
```

That's exactly where:

```text
Resilience Hub

ARC plan evaluation

Config/IaC

FIS

game days
```

complement one another.

---

# 37.709 Resilience evidence ladder

Think:

```text
DOCUMENTATION
lowest evidence

      ↓

CONFIGURATION REVIEW

      ↓

STATIC ASSESSMENT

      ↓

RESTORE TEST

      ↓

COMPONENT FAILURE TEST

      ↓

AZ GAME DAY

      ↓

REGIONAL FAILOVER

      ↓

PRODUCTION-SCALE GAME DAY
highest evidence
```

The closer the test is to:

```text
real failure
+
real scale
+
real dependencies
```

the stronger the evidence.

---

# 37.710 Compliance evidence

For regulated environments you may need to prove:

```text
When DR test occurred

Who approved it

Which resources were tested

Actual RTO

Actual RPO

Result

Defects

Remediation
```

FIS logging/reports, ARC reports, CloudTrail, AWS Backup restore-test events, and your incident-management records can all contribute evidence. FIS currently supports experiment logging and PDF experiment reports, while AWS Backup emits restore-testing events through EventBridge. ([AWS Documentation][8])

---

# 37.711 The "unknown unknown" test

Runbooks test:

```text
known knowns.
```

Chaos engineering helps discover:

```text
unknown weaknesses.
```

Example surprise:

```text
AZ-B removed
    ↓
all NAT Gateways used by app
were actually in AZ-B
    ↓
outbound dependencies fail globally
```

or:

```text
Singapore app healthy
    ↓
certificate missing
```

or:

```text
DB failover works
    ↓
app caches old writer DNS
for 30 minutes.
```

These hidden coupling problems are exactly why runtime experiments matter.

---

# 37.712 Fault-domain mapping

Before chaos testing draw:

```text
APPLICATION
     │
     ├── AZ-A components
     ├── AZ-B components
     ├── AZ-C components
     │
     ├── Region A
     └── Region B
```

Then ask:

```text
Which components share
the same failure domain?
```

If all three "AZ-resilient" app servers use:

```text
one single-AZ Redis node
```

you don't actually have full AZ resilience.

---

# 37.713 Dependency graph again

Game day scope should use:

```text
User
  ↓
Route53
  ↓
ALB
  ↓
ECS
  ↓
Aurora
 / | \
SQS Secrets ECR
       |
      KMS

+
On-Prem
+
third party
```

Fault injection on one box without considering the graph can produce misleading conclusions.

---

# 37.714 Failure Mode and Effects Analysis — FMEA mental model

For each component ask:

```text
COMPONENT:
Aurora writer

FAILURE:
writer unavailable

EFFECT:
application writes fail

DETECTION:
CloudWatch + synthetic transaction

MITIGATION:
Aurora failover

RECOVERY TARGET:
<2 minutes

TEST:
scheduled failover drill
```

Repeat for:

```text
ALB

ECS

AZ

ECR

Secrets

Route53

VPN

database

Region
```

This gives structure to resilience testing.

---

# 37.715 Example FMEA table

| Component  | Failure          | Mitigation                   | Test            |
| ---------- | ---------------- | ---------------------------- | --------------- |
| ECS task   | task stops       | ECS replacement              | FIS task stop   |
| EC2        | instance stops   | ASG                          | FIS EC2 stop    |
| AZ         | impaired         | Multi-AZ + ARC               | Zonal Shift     |
| DB writer  | unavailable      | DB failover                  | DB game day     |
| Region     | unavailable      | Multi-Region DR              | Region game day |
| Backup     | unusable         | restore testing              | AWS Backup test |
| Hybrid VPN | path down        | redundant tunnel/DX          | routing drill   |
| DNS        | resolver failure | redundant Resolver endpoints | DNS fault test  |

This connects Lessons 36 and 37 beautifully.

---

# 37.716 A senior engineer's test question

Instead of asking:

> "Do we have Multi-AZ?"

Ask:

> **"Show me the last test where you removed one AZ and demonstrate what happened to error rate, latency, and capacity."**

Instead of:

> "Do we have backups?"

Ask:

> **"Show me the last successful restore and application-level validation."**

Instead of:

> "Do we have DR?"

Ask:

> **"Show me the last measured Region failover and failback."**

This is a fundamentally stronger operational mindset.

---

# 37.717 Interview question — What is AWS FIS?

Strong answer:

> **AWS Fault Injection Service is a managed fault-injection service used to run controlled resilience experiments against AWS workloads. Experiments are defined from templates containing actions, targets, IAM permissions, stop conditions, and optional logging/reporting.** ([AWS Documentation][3])

---

# 37.718 Interview question — Why stop conditions?

> **To automatically terminate an experiment when a CloudWatch alarm indicates that application impact has exceeded an acceptable safety boundary.** ([AWS Documentation][7])

---

# 37.719 Interview question — Game day vs chaos engineering?

Good answer:

> **A game day is a planned operational exercise that validates people, process, technology, runbooks, communication, and recovery. Chaos engineering is the controlled experimental practice of injecting failures to test explicit resilience hypotheses. Chaos experiments can be part of a game day.**

AWS Well-Architected encourages structured, regular game days, while FIS provides managed fault injection for technical experiments. ([AWS Documentation][1])

---

# 37.720 Interview question — Why is restore testing important?

> Because a successful backup job proves only that a recovery point was created. Restore testing verifies that the recovery point can actually be restored; application-level validation should then prove that the restored resource is usable.

AWS Backup supports scheduled restore-testing plans and EventBridge-triggered post-restore validation. ([AWS Documentation][22])

---

# 37.721 Interview question — AWS Resilience Hub vs AWS FIS?

```text
RESILIENCE HUB
=
assess architecture
against RTO/RPO policy,
identify gaps,
recommend improvements/tests


AWS FIS
=
inject real faults
and observe workload behavior
```

AWS Resilience Hub can also surface and run FIS-based resilience tests for applications. ([AWS Documentation][31])

---

# 37.722 Interview question — What should a chaos experiment contain?

At minimum:

```text
hypothesis

steady-state metric

fault

target

blast radius

success criteria

stop condition

observability

recovery action

owner
```

For AWS FIS specifically, the managed experiment template centers on:

```text
actions
targets
stop conditions
IAM role
```

plus optional logging/reporting. ([AWS Documentation][3])

---

# 37.723 Interview trap — "Chaos engineering means randomly breaking production."

Wrong.

It is controlled experimentation with:

```text
defined hypotheses

bounded targets

stop conditions

observability

recovery plans
```

Random destruction is operational negligence, not chaos engineering.

---

# 37.724 Interview trap — "If the backup job is green, DR is proven."

Wrong.

Need:

```text
restore
+
validation.
```

AWS Backup restore testing exists precisely to address that gap. ([AWS Documentation][22])

---

# 37.725 Interview trap — "If an AZ test works once, we're done."

Wrong.

Infrastructure and application configuration drift.

AWS therefore recommends regular game days, and ARC Zonal Autoshift uses recurring practice runs to repeatedly validate AZ-removal readiness. ([AWS Documentation][1])

---

# 37.726 Interview trap — "FIS stop conditions guarantee zero impact."

No.

A stop condition reacts when the alarm enters its triggering state.

Some impact may already have occurred.

Therefore:

```text
blast radius minimization
+
safe thresholds
+
observability
```

remain essential.

Stop conditions are brakes, not magical prevention. ([AWS Documentation][7])

---

# 37.727 Complete resilience-testing lifecycle

Memorize:

```text
DEFINE RTO/RPO
      │
      ▼
DESIGN RESILIENCE
      │
      ▼
ASSESS CONFIGURATION
      │
      ▼
DEFINE HYPOTHESIS
      │
      ▼
BUILD EXPERIMENT
      │
      ▼
SET SAFETY CONTROLS
      │
      ▼
INJECT FAILURE
      │
      ▼
OBSERVE
      │
      ▼
RECOVER
      │
      ▼
MEASURE RTO/RPO
      │
      ▼
FAILBACK
      │
      ▼
POSTMORTEM
      │
      ▼
FIX
      │
      ▼
RETEST
```

That's the resilience lifecycle.

---

# 37.728 Production Game Day example — final

## Scenario

```text
Payments platform

Primary:
ap-south-1

Recovery:
ap-southeast-1

RTO:
15 minutes

RPO:
30 seconds
```

## Fault

```text
Treat Mumbai application
as Regionally unavailable.
```

## Success conditions

```text
Detection < 2m

Data recovery < 8m

Traffic recovery < 15m

Data loss < 30s

Duplicate payments = 0

Checkout success after recovery > 99%

Failback completed successfully
```

## Stop conditions

```text
Payment duplication > 0

Unexpected data corruption

Singapore 5xx > 5%

DB error rate critical

Security incident detected
```

---

# 37.729 During the exercise

```text
FAULT
  │
  ▼
CloudWatch detects
  │
  ▼
Incident declared
  │
  ▼
ARC recovery workflow
  │
  ├── data
  ├── capacity
  ├── smoke test
  └── approval
  │
  ▼
traffic → Singapore
  │
  ▼
synthetic payment
  │
  ▼
RTO/RPO measurement
  │
  ▼
operate in DR
  │
  ▼
recover Mumbai
  │
  ▼
resynchronize
  │
  ▼
controlled failback
```

That one exercise tests essentially everything in Lesson 37.

---

# 37.730 What we'd probably discover

Realistically:

```text
Singapore DB works                ✓

ECS scaling works                 ✓

ECR replication works             ✓

Secret replica works              ✓

ACM works                         ✓

One partner IP allowlist missing  ✕

one alarm too noisy               ✕

failback takes too long           ✕

runbook has outdated command      ✕
```

That's a valuable outcome.

Now fix the gaps.

---

# 37.731 Five maturity levels

### Level 1 — Paper DR

```text
"We have a runbook."
```

### Level 2 — Infrastructure DR

```text
"We have the resources."
```

### Level 3 — Tested DR

```text
"We've restored/failover-tested."
```

### Level 4 — Measured DR

```text
"We know actual RTO/RPO."
```

### Level 5 — Continuously validated resilience

```text
"Recovery mechanisms,
fault injection,
restore tests,
and game days are
part of normal engineering."
```

Level 5 is where serious reliability programs aim.

---

# 37.732 The most important rule from Part 8

> **Resilience is not what the architecture diagram says. Resilience is what the workload demonstrates when components actually fail.**

That's the central lesson.

---

# 37.733 Never-forget Part 8 sheet

```text
1.
A backup is not proven
until it restores.


2.
A restore is not proven
until the application works.


3.
A DR architecture is not proven
until failover is tested.


4.
Failover testing is incomplete
until failback is tested.


5.
Chaos engineering starts
with a hypothesis.


6.
Always bound the blast radius.


7.
Use stop conditions
as safety brakes.


8.
Measure business health,
not only CPU and memory.


9.
Actual RTO must be measured.


10.
Actual RPO must be measured.


11.
Fault injection should
progress from small to large.


12.
Game days test:
people + process + technology.


13.
Discovering a weakness
during a game day is success.


14.
Every finding needs:
owner + fix + retest.


15.
Configuration assessments
do not replace runtime testing.


16.
Use the smallest recovery layer
that matches the failure scope.


17.
Production resilience
must be exercised regularly.
```

---

# 37.734 One diagram to remember

```text
                    RESILIENCE PROGRAM

                          RTO/RPO
                             │
                             ▼
                       ARCHITECTURE
                             │
               ┌─────────────┼─────────────┐
               ▼             ▼             ▼

            BACKUP        MULTI-AZ      MULTI-REGION
               │             │             │
               ▼             ▼             ▼

          Restore Test    Zonal Test    Region Game Day
               │             │             │
               └─────────────┼─────────────┘
                             ▼

                        AWS FIS / ARC
                             │
                             ▼
                         OBSERVABILITY
                             │
                             ▼
                        MEASURE RTO/RPO
                             │
                             ▼
                           LEARN
                             │
                             ▼
                           FIX
                             │
                             ▼
                          RETEST
```

---

# ✅ Part 8 Complete

Lesson 37 progress:

```text
Part 1
HA vs DR + RTO/RPO                    ✓

Part 2
Backup & Restore                      ✓

Part 3
Pilot Light + Warm Standby            ✓

Part 4
Active/Passive Multi-Region           ✓

Part 5
Active/Active Multi-Region            ✓

Part 6
Multi-Region Data Layer               ✓

Part 7
Application Recovery Controller       ✓

Part 8
DR Automation / Testing / Chaos       ✓

Part 9
Complete Multi-Region DR Capstone     NEXT

Part 10
Final Revision / Interview Mastery
```

We are now roughly **85–90% through Lesson 37**.

# Next — Lesson 37, Part 9

## Complete Production Multi-Region DR Capstone

Now we'll build everything into **one end-to-end architecture**:

```text
                           USERS
                             │
                  Route53 / ARC / GA
                             │
               ┌─────────────┴─────────────┐
               ▼                           ▼

            MUMBAI                     SINGAPORE
            PRIMARY                    DR REGION

          Multi-AZ VPC                Multi-AZ VPC
               │                           │
              ALB                         ALB
               │                           │
           ECS / ASG                  ECS / ASG
               │                           │
               └──── Aurora Global ────────┘

          ECR ─────────────────────────→ ECR

       Secrets ────────────────────────→ Secrets

           S3 ─────────────────────────→ S3

        Backup ────────────────────────→ DR Vault

               │                           │
               └──────────── ARC ──────────┘
                              │
                        Recovery Plan
                              │
                      CloudWatch + FIS
```

We'll design the **Terraform repository, primary/DR VPCs, regional provider aliases, ECR replication, Secrets replication, data strategy, Route 53 failover, ARC workflow, monitoring, backup policy, validation commands, failure injection, exact failover runbook, actual RTO/RPO measurement, failback process, and cleanup/cost controls**.

That capstone will combine almost every major concept from **Lessons 36 and 37** into one production architecture.

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_testing_resiliency_game_days_resiliency.html?utm_source=chatgpt.com "REL12-BP05 Conduct game days regularly - Reliability Pillar"
[2]: https://docs.aws.amazon.com/fis/latest/userguide/what-is.html?utm_source=chatgpt.com "What is AWS Fault Injection Service?"
[3]: https://docs.aws.amazon.com/fis/latest/userguide/experiment-templates.html?utm_source=chatgpt.com "AWS FIS experiment template components"
[4]: https://docs.aws.amazon.com/fis/latest/userguide/start-experiment-from-template.html?utm_source=chatgpt.com "Start an experiment from a template - AWS Documentation"
[5]: https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html?utm_source=chatgpt.com "AWS FIS Actions reference - AWS Fault Injection Service"
[6]: https://docs.aws.amazon.com/fis/latest/userguide/targets.html?utm_source=chatgpt.com "Targets for AWS FIS - AWS Fault Injection Service"
[7]: https://docs.aws.amazon.com/fis/latest/userguide/stop-conditions.html?utm_source=chatgpt.com "Stop conditions for AWS FIS - AWS Fault Injection Service"
[8]: https://docs.aws.amazon.com/fis/latest/userguide/monitoring-logging.html?utm_source=chatgpt.com "Experiment logging for AWS FIS - AWS Fault Injection Service"
[9]: https://docs.aws.amazon.com/fis/latest/userguide/experiment-report-configuration.html?utm_source=chatgpt.com "Experiment report configurations for AWS FIS"
[10]: https://docs.aws.amazon.com/fis/latest/userguide/monitoring-experiments.html?utm_source=chatgpt.com "Monitoring AWS FIS experiments"
[11]: https://docs.aws.amazon.com/fis/latest/userguide/logging-using-cloudtrail.html?utm_source=chatgpt.com "Log API calls with AWS CloudTrail"
[12]: https://docs.aws.amazon.com/fis/latest/userguide/scenario-library.html?utm_source=chatgpt.com "Working with the AWS FIS scenario library"
[13]: https://docs.aws.amazon.com/fis/latest/userguide/create.html?utm_source=chatgpt.com "Create a multi-account experiment template"
[14]: https://docs.aws.amazon.com/fis/latest/userguide/fis-tutorial-stop-instances.html?utm_source=chatgpt.com "Tutorial: Test instance stop and start using AWS FIS"
[15]: https://docs.aws.amazon.com/fis/latest/userguide/eks-pod-actions.html?utm_source=chatgpt.com "Use the AWS FIS aws:eks:pod actions - AWS Fault Injection Service"
[16]: https://docs.aws.amazon.com/fis/latest/userguide/experiment-template-example.html?utm_source=chatgpt.com "Example AWS FIS experiment templates"
[17]: https://docs.aws.amazon.com/fis/latest/userguide/doc-history.html?utm_source=chatgpt.com "Document history - AWS Fault Injection Service"
[18]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.about.html?utm_source=chatgpt.com "About zonal autoshift"
[19]: https://docs.aws.amazon.com/r53recovery/latest/dg/introduction-components-zonal-autoshift.html?utm_source=chatgpt.com "Zonal autoshift components"
[20]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.alarms.html?utm_source=chatgpt.com "Alarms for practice runs"
[21]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.html?utm_source=chatgpt.com "Zonal autoshift in ARC"
[22]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html?utm_source=chatgpt.com "Restore testing - AWS Backup"
[23]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing-validation.html?utm_source=chatgpt.com "Restore testing validation - AWS Backup"
[24]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing-inferred-metadata.html?utm_source=chatgpt.com "Restore testing inferred metadata - AWS Backup"
[25]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/setup-resiliency-policy.html?utm_source=chatgpt.com "Set RTO and RPO - AWS Resilience Hub"
[26]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/resil-recs.html?utm_source=chatgpt.com "Reviewing resiliency recommendations"
[27]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/testing.html?utm_source=chatgpt.com "Managing AWS Fault Injection Service experiments"
[28]: https://docs.aws.amazon.com/wellarchitected/2023-10-03/framework/rel_testing_resiliency_game_days_resiliency.html?utm_source=chatgpt.com "REL12-BP06 Conduct game days regularly"
[29]: https://docs.aws.amazon.com/fis/latest/userguide/create-template.html?utm_source=chatgpt.com "Create an experiment template - AWS Fault Injection Service"
[30]: https://docs.aws.amazon.com/fis/latest/userguide/action-sequence.html?utm_source=chatgpt.com "Actions for AWS FIS - AWS Fault Injection Service"
[31]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/concepts-terms.html?utm_source=chatgpt.com "AWS Resilience Hub concepts"
