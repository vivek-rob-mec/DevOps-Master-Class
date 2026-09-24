# AWS Masterclass — Phase 3

# Lesson 60: Resilience Hub, Fault Injection Service and Application Recovery Controller

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish availability, resilience, recovery and disaster recovery.
* Define steady-state behaviour and failure hypotheses.
* Model applications in AWS Resilience Hub.
* Set disruption-specific RTO and RPO objectives.
* Run resilience assessments and interpret resilience scores.
* Implement recommended CloudWatch alarms, SOPs and FIS experiments.
* Detect application-resource and policy drift.
* Design safe chaos-engineering experiments.
* Use AWS FIS targets, actions, sequencing and stop conditions.
* Preview targets before injecting a fault.
* Run multi-account fault experiments.
* Test complete Availability Zone impairment.
* Use ARC zonal shift and zonal autoshift.
* Design sufficient capacity for losing one Availability Zone.
* Understand ARC readiness checks.
* Build multi-Region routing controls and safety rules.
* Use Region switch plans to orchestrate failover and failback.
* Distinguish graceful and ungraceful recovery workflows.
* Automate recovery without creating a second outage.
* Provision resilience resources using Terraform.
* Conduct production game days and record measurable outcomes.

---

# 2. The resilience-service mental model

```text
AWS Resilience Hub
    → Assess whether the architecture can meet resilience targets

AWS Fault Injection Service
    → Inject controlled failures to test assumptions

Amazon Application Recovery Controller
    → Shift traffic and orchestrate application recovery

CloudWatch
    → Detect impact and provide experiment guardrails

Systems Manager
    → Execute recovery procedures

AWS Backup / DRS
    → Restore data and workloads after disasters
```

## Never-forget distinction

```text
Resilience Hub:
What weaknesses exist?

FIS:
Does the system really survive failure?

ARC:
How do we move traffic and execute recovery?

CloudWatch:
Are users being affected?

Systems Manager:
How do we automate repair?

AWS Backup:
How do we restore lost or corrupted data?
```

AWS Resilience Hub assesses applications against defined recovery objectives and provides architecture and operational recommendations. AWS FIS injects controlled faults. ARC provides multi-AZ and multi-Region recovery capabilities such as zonal shift, routing control and Region switch. ([AWS Documentation][1])

---

# 3. Availability versus resilience

## Availability

Availability is the proportion of time a service is usable.

```text
Availability =
Successful service time / Total measured time
```

Example:

```text
Monthly availability target:
99.9%
```

## Resilience

Resilience is the ability to:

```text
Withstand disruption
Recover inside an acceptable time
Continue delivering critical functions
Adapt when dependencies fail
```

A system can be highly available during ordinary failures but still be poorly prepared for:

* Availability Zone loss.
* Region loss.
* Corrupt configuration.
* Capacity exhaustion.
* Database failover.
* Credential failure.
* Broken DNS.
* Dependency latency.
* Operator mistakes.

---

# 4. Resilience is not only redundancy

Redundancy:

```text
Two application instances
```

Resilience:

```text
Two instances
+
Independent failure domains
+
Load-balancer health checks
+
Enough spare capacity
+
Automated replacement
+
Monitoring
+
Recovery procedure
+
Regular failure testing
```

Bad redundancy:

```text
Instance A ─┐
            ├── Same Availability Zone
Instance B ─┘
```

Better:

```text
Instance A:
ap-south-1a

Instance B:
ap-south-1b

Instance C:
ap-south-1c
```

But even three Availability Zones are insufficient when all three instances depend on:

```text
One undersized NAT gateway
One unreplicated database
One shared credential
One single-threaded worker
One DNS record changed manually
```

---

# 5. Resilience questions

For every critical dependency, ask:

```text
What happens when it fails?

How is failure detected?

What customer capability is affected?

Is there another healthy path?

Who or what performs recovery?

How long does recovery take?

How much data is lost?

Has this exact scenario been tested?
```

If the last answer is “no,” the architecture relies partly on hope.

---

# Part 1 — Resilience engineering foundations

# 6. Failure domains

Typical failure domains include:

```text
Process
Container
Virtual machine
Node
Rack
Availability Zone
Region
AWS account
Network provider
Identity provider
Software release
Human operator
External dependency
```

A design should avoid allowing one failure domain to take down every replica.

Example:

```text
Three EC2 instances
+
One Availability Zone
=
One zonal failure domain
```

---

# 7. Disruption levels

A practical resilience hierarchy:

```text
Application disruption
    → Bug, process crash, bad configuration

Infrastructure disruption
    → Instance, node, disk or network component

Availability Zone disruption
    → Zonal capacity or connectivity impairment

Regional disruption
    → Large-scale Regional application impairment
```

AWS Resilience Hub evaluates application components against application, infrastructure, Availability Zone and Region disruption scenarios and can recommend alarms, recovery procedures and FIS experiments for those disruption types. ([AWS Documentation][2])

---

# 8. Steady state

A steady state describes normal acceptable behaviour before failure injection.

Example TodoApp steady state:

```text
Success rate:
>= 99.9%

p95 API latency:
< 400 ms

Healthy ECS tasks:
>= 6

Oldest SQS message:
< 60 seconds

Database connections:
< 70% of limit

Login success rate:
>= 99%
```

A chaos experiment needs a measurable steady state.

Bad hypothesis:

```text
The application should probably work.
```

Good hypothesis:

```text
When one ECS task is terminated,
the API success rate remains above 99.9%
and p95 latency remains below 500 ms.
```

---

# 9. Fault hypothesis structure

Use:

```text
Given:
The application is healthy.

When:
A defined failure occurs.

Then:
A measurable customer outcome remains acceptable.

And:
The application recovers within a measured time.
```

Example:

```text
Given:
Six ECS tasks are healthy across three AZs.

When:
Two tasks in one AZ stop.

Then:
Error rate remains below 1%.

And:
ECS restores desired capacity within 5 minutes.
```

---

# 10. Blast radius

Blast radius means the maximum scope affected by an experiment.

Possible controls:

```text
One resource
One replica
One Availability Zone
One development environment
One account
One percentage of targets
```

Experiment maturity:

```text
Stage 1:
One disposable resource in development

Stage 2:
One replica in staging

Stage 3:
One production replica during low traffic

Stage 4:
Complete zonal scenario

Stage 5:
Multi-Region game day
```

Do not begin resilience engineering by terminating every production node.

---

# Part 2 — AWS Resilience Hub

# 11. What is AWS Resilience Hub?

AWS Resilience Hub is a centralized service for managing and improving application resilience posture.

It enables you to:

* Define resilience goals.
* Model applications and dependencies.
* Assess application resources.
* Compare estimated recovery capabilities with RTO and RPO.
* Identify resilience gaps.
* Receive architecture recommendations.
* Receive operational recommendations.
* Track resilience posture and drift. ([AWS Documentation][1])

---

# 12. Resilience Hub architecture

```text
Application resources
├── CloudFormation
├── Terraform state
├── Resource Groups
├── myApplications
├── EKS namespaces
└── Manually grouped resources
        |
        v
AWS Resilience Hub application
        |
        v
Resiliency policy
        |
        v
Assessment
        |
        ├── Estimated RTO/RPO
        ├── Architecture recommendations
        ├── CloudWatch alarm recommendations
        ├── Systems Manager SOP recommendations
        └── AWS FIS experiment recommendations
```

Resilience Hub can discover resources from CloudFormation stacks, Resource Groups, myApplications, Terraform state files and EKS clusters or namespaces. ([AWS Documentation][3])

---

# 13. Resilience Hub application

A Resilience Hub application is a logical collection of resources that together deliver an application capability.

Example:

```text
TodoApp application
├── CloudFront
├── API Gateway or ALB
├── ECS service
├── Auto Scaling
├── Aurora
├── ElastiCache
├── SQS
├── S3
└── Route 53
```

Do not create one Resilience Hub application for the complete AWS organization.

Define applications around meaningful business capabilities and recovery ownership.

---

# 14. Application Components

An Application Component, or AppComponent, groups resources that work and fail as one logical unit.

Example:

```text
Compute AppComponent
├── ECS service
├── Auto Scaling group
└── Load balancer

Database AppComponent
├── Aurora primary
└── Aurora replicas

Messaging AppComponent
├── SQS processing queue
└── Dead-letter queue
```

Resilience Hub uses AppComponent types to understand how related resources contribute to application recovery. A primary and replica database can belong to the same database component. ([AWS Documentation][4])

---

# 15. Why AppComponent grouping matters

Bad grouping:

```text
All 300 application resources
    → One component
```

This hides meaningful failure boundaries.

Better:

```text
Frontend
API compute
Database
Cache
Messaging
File storage
Authentication
```

The groups should reflect:

* Shared recovery behaviour.
* Shared failure mode.
* Operational ownership.
* Dependency path.

---

# 16. Resiliency policy

A resiliency policy defines target RTO and RPO values for disruption types.

Conceptual example:

```text
Application disruption:
RTO = 5 minutes
RPO = 0

Infrastructure disruption:
RTO = 10 minutes
RPO = 0

Availability Zone disruption:
RTO = 30 minutes
RPO = 5 minutes

Region disruption:
RTO = 2 hours
RPO = 15 minutes
```

The policy represents business targets.

It does not automatically make the application compliant.

---

# 17. Different disruption types need different targets

An application-process crash can recover quickly:

```text
Container restart:
RTO 2 minutes
RPO 0
```

A complete Region recovery may take longer:

```text
Regional recovery:
RTO 2 hours
RPO 15 minutes
```

Using one RTO for every disruption hides the true recovery design.

---

# 18. Resilience assessment

An assessment:

```text
1. Discovers application resources.

2. Groups and evaluates components.

3. Estimates recovery behaviour.

4. Compares estimates with the resiliency policy.

5. Reports gaps.

6. Generates architecture and operational recommendations.
```

When application resources change, AWS recommends running another assessment because each AppComponent configuration is compared with the attached policy and current recommendations. ([AWS Documentation][5])

---

# 19. Estimated RTO and RPO

Assessment output can show:

```text
Policy RTO:
30 minutes

Estimated workload RTO:
75 minutes

Result:
Policy breached
```

and:

```text
Policy RPO:
15 minutes

Estimated workload RPO:
5 minutes

Result:
Policy met
```

The estimates are architecture assessments—not guarantees.

Actual recovery performance must be proven with drills and measured procedures.

---

# 20. Architecture recommendations

Resilience Hub can recommend design changes optimized around:

* Estimated RTO.
* Estimated RPO.
* Cost.
* Minimal architectural change. ([AWS Documentation][6])

Example options:

```text
Option A:
Add Multi-AZ database
Higher cost
Much lower RTO

Option B:
Increase backup frequency
Low cost
Improved RPO
Longer RTO

Option C:
Create warm standby
Higher cost
Improved Regional recovery
```

The lowest-cost recommendation is not always the correct business choice.

---

# 21. Operational recommendations

Operational recommendations include:

```text
CloudWatch alarms
Systems Manager SOPs
AWS FIS experiments
```

Resilience Hub can generate CloudFormation templates for selected recommendations so they can be reviewed, version controlled and integrated into deployment pipelines. ([AWS Documentation][7])

---

# 22. Alarm recommendations

Recommended alarms might detect:

```text
Unhealthy load-balancer targets
Database failover
Queue-age increase
Auto Scaling capacity deficit
Application errors
Dependency latency
Insufficient replica count
```

Resilience Hub can generate a CloudFormation template containing selected recommended alarms. The template should be reviewed and incorporated into the application’s codebase rather than deployed blindly. ([AWS Documentation][8])

---

# 23. Standard operating procedures

An SOP is a documented or automated recovery procedure.

Examples:

```text
Restart failed application process
Replace unhealthy instance
Fail over database
Scale secondary environment
Clear stuck messages
Restore from backup
Shift traffic away from an AZ
```

Resilience Hub integrates with Systems Manager Automation documents to provide a starting point for automated SOPs. ([AWS Documentation][9])

---

# 24. SOP lifecycle

```text
Recommendation
      |
      v
Generate CloudFormation template
      |
      v
Review SSM Automation document
      |
      v
Restrict IAM permissions
      |
      v
Deploy to staging
      |
      v
Run manually
      |
      v
Test with FIS
      |
      v
Approve for production
```

A recovery document is production code.

It requires:

* Version control.
* Code review.
* Testing.
* Rollback.
* Ownership.
* Audit logging.

---

# 25. FIS recommendations

Resilience Hub can recommend FIS experiments that:

```text
Inject a failure
Verify an alarm detects the problem
Run or validate a recovery SOP
Measure the resulting application recovery
```

A strong resilience test connects:

```text
Fault
→ Detection
→ Recovery action
→ Verified steady state
```

Resilience Hub’s score considers whether recommended alarms, SOPs and tests are implemented for disruption scenarios. ([AWS Documentation][10])

---

# 26. Resilience score

The resilience score ranges up to 100 and reflects how closely the application follows recommendations around:

* Policy compliance.
* Alarms.
* SOPs.
* Tests. ([AWS Documentation][10])

Do not optimize only for the score.

A score can improve because a recommendation was implemented, but production readiness still requires:

* Real test execution.
* Correct IAM permissions.
* Current runbooks.
* Sufficient capacity.
* Successful business validation.

---

# 27. Scheduled assessments and drift

Resilience Hub can automatically assess applications daily and notify when drift is detected.

Drift can include:

* Application resources added or removed.
* Resource configuration affecting resilience.
* Recovery capability no longer matching policy.
* Operational recommendations no longer implemented.

Enabling drift notifications also enables scheduled assessment. ([AWS Documentation][11])

---

# 28. Resilience drift example

Initial design:

```text
ECS desired count:
6 across 3 AZs

Assessment:
AZ resilience compliant
```

Later change:

```text
Desired count:
2

Placement:
Both tasks in one AZ
```

New assessment:

```text
Estimated zonal recovery worsens
Policy drift detected
```

Infrastructure can still be “running” while resilience posture has degraded.

---

# 29. EventBridge integration

Resilience Hub emits events using:

```text
source:
aws.resiliencehub
```

EventBridge rules can route assessment or drift events to:

* SNS.
* Ticketing.
* Lambda.
* Step Functions.
* Security or platform dashboards. ([AWS Documentation][12])

Example workflow:

```text
Application drift detected
      |
      v
EventBridge
      |
      v
Create platform ticket
      |
      v
Block production promotion
until assessment passes
```

---

# 30. Assessment in CI/CD

A resilience-aware delivery process:

```text
Terraform change
      |
      v
Deploy to staging
      |
      v
Update Resilience Hub application
      |
      v
Run assessment
      |
      v
Evaluate policy compliance
      |
      ├── Compliant → Continue
      └── Noncompliant → Review/block
```

Do not block every deployment automatically on a score difference without first understanding expected architecture changes and assessment timing.

---

# 31. Resilience Hub cost awareness

As of August 2026, Resilience Hub’s newer service-based pricing includes a base service fee with an included number of resources and assessments, plus per-resource assessment costs beyond those allowances; optional dependency discovery has a separate fee. Confirm current pricing before onboarding large applications or enabling frequent assessments. ([AWS Documentation][13])

Cost controls:

* Model meaningful services, not every temporary resource as an independent application.
* Use scheduled assessments where justified.
* Avoid repeatedly assessing unchanged large applications.
* Tag and group application resources correctly.
* Review dependency-discovery requirements.

---

# Part 3 — AWS Fault Injection Service

# 32. What is AWS FIS?

AWS Fault Injection Service is a managed service for performing controlled fault-injection experiments against AWS resources.

An experiment template defines:

```text
Actions
Targets
Stop conditions
Experiment IAM role
Optional logging and reporting
```

The template is the reusable blueprint, while an experiment is one execution of that blueprint. ([AWS Documentation][14])

---

# 33. Chaos engineering is not random destruction

Chaos engineering is a disciplined process:

```text
1. Define steady state.

2. Form a hypothesis.

3. Limit blast radius.

4. Define abort conditions.

5. Inject a controlled fault.

6. Observe the system.

7. Measure recovery.

8. Learn and improve.
```

Bad chaos:

```text
Terminate random production resources
and see what happens.
```

Good chaos:

```text
Stop one tagged ECS task,
while a CloudWatch alarm stops the experiment
if customer error rate exceeds 2%.
```

---

# 34. Experiment-template components

```text
Experiment template
├── Description
├── IAM role
├── Targets
├── Actions
├── Action dependencies
├── Stop conditions
├── Experiment options
├── Logging
├── Report configuration
└── Tags
```

---

# 35. Targets

Targets identify which AWS resources an action can affect.

Resources can be selected using:

* Explicit resource IDs or ARNs.
* Resource tags.
* Resource filters.
* Action-specific parameters.

AWS FIS resolves targets at the start of an experiment and uses those selected resources for that execution. If no target is resolved, the experiment normally fails unless empty-target handling is configured to skip. ([AWS Documentation][15])

---

# 36. Target-selection modes

```text
ALL
    → Every resolved target

COUNT(n)
    → A random count of resolved targets

PERCENT(n)
    → A random percentage of resolved targets
```

Example:

```text
COUNT(1)
```

selects one random resource.

```text
PERCENT(25)
```

selects 25% of resolved targets. ([AWS Documentation][15])

---

# 37. Safe target tags

Recommended target tags:

```text
ChaosReady = true
Environment = staging
Application = TodoApp
ExperimentScope = task-stop
```

Do not target with only:

```text
Environment = production
```

Use several conditions and bounded selection.

Example:

```text
Environment = production
AND
Application = TodoApp
AND
ChaosReady = true
AND
ExperimentScope = task-stop
```

---

# 38. Target preview

Before injecting a fault, run a target preview:

```bash
aws fis start-experiment \
  --experiment-options actionsMode=skip-all \
  --experiment-template-id "$TEMPLATE_ID"
```

`actionsMode=skip-all` resolves and displays targets without running the fault actions. Resources selected during the eventual real experiment can differ if infrastructure changes or random selection is used. ([AWS Documentation][16])

A target preview should be mandatory before:

* First execution.
* Production execution.
* Tag changes.
* OU/account changes.
* Experiment-template updates.

---

# 39. Actions

An action is the failure or stress condition FIS applies.

Action identifiers follow:

```text
aws:<service>:<action>
```

Examples:

```text
aws:ec2:stop-instances
aws:ec2:reboot-instances
aws:ecs:stop-task
aws:eks:pod-delete
aws:rds:failover-db-cluster
aws:ebs:pause-volume-io
aws:lambda:invocation-error
aws:network:disrupt-connectivity
```

AWS maintains a current action reference because supported services and actions evolve. ([AWS Documentation][17])

---

# 40. Action sequencing

Actions can run:

```text
In parallel
or
After another action
```

Example:

```text
Action A:
Stop one EC2 instance

Action B:
After Action A finishes,
stop both test instances
```

Action dependencies let an experiment represent a failure sequence rather than one isolated event. ([AWS Documentation][18])

---

# 41. Temporary EC2 stop action

Example action:

```json
{
  "actionId": "aws:ec2:stop-instances",
  "parameters": {
    "startInstancesAfterDuration": "PT3M"
  },
  "targets": {
    "Instances": "oneTestInstance"
  }
}
```

The `startInstancesAfterDuration` parameter can automatically restart stopped instances after a configured duration, supported from one minute through 12 hours. Encrypted EBS volumes may require the experiment role to use the associated KMS key. ([AWS Documentation][19])

---

# 42. Common compute experiments

## EC2

```text
Stop instance
Reboot instance
Terminate instance
Interrupt Spot instance
Inject API capacity error
Stress CPU, memory, I/O or network through SSM
```

## ECS

```text
Stop task
Drain container instance
CPU stress
I/O stress
Kill process
Network latency
Packet loss
Port blackhole
```

## EKS

```text
Delete pod
Terminate node-group instances
CPU stress
Memory stress
I/O stress
Network latency
Packet loss
```

Supported target quotas and action capabilities vary, so review the current action and quota references before setting large target percentages. ([AWS Documentation][17])

---

# 43. Database experiments

Examples:

```text
RDS cluster failover
RDS instance reboot
Database network interruption
Dependency latency around database clients
```

Hypothesis:

```text
When Aurora fails over,
API error rate remains below 2%,
clients reconnect automatically,
and service recovers within 60 seconds.
```

Test:

* Connection-pool recovery.
* DNS refresh.
* Transaction retries.
* Idempotency.
* Read/write endpoint use.
* Alarm timing.

---

# 44. Network experiments

Network faults can test:

```text
Subnet connectivity loss
Cross-Region connectivity loss
Transit Gateway interruption
Network latency
Packet loss
Port blackhole
```

A network experiment is often more realistic than stopping a server because many incidents involve partial reachability, latency or one failed path rather than complete shutdown.

---

# 45. Lambda experiments

Lambda fault actions can simulate:

```text
Invocation error
Invocation delay
HTTP integration response alteration
```

Test whether callers implement:

* Timeouts.
* Retries.
* Exponential backoff.
* Circuit breakers.
* Idempotency.
* Fallback responses.

---

# 46. AZ power-interruption scenario

The FIS scenario library includes an Availability Zone power-interruption scenario designed to model a complete zonal interruption.

It can include effects such as:

* Stopping zonal EC2 compute.
* Preventing new capacity launches in the AZ.
* Stopping dependent ECS tasks.
* Removing EKS capacity.
* RDS or ElastiCache failover behaviour.
* EBS unresponsiveness.
* Subnet connectivity disruption. ([AWS Documentation][20])

This is an advanced experiment.

Run it only after smaller component tests succeed.

---

# 47. Scenario library

The FIS scenario library provides reusable scenarios that can be customized into experiment templates.

Benefits:

* Reduced setup time.
* Predefined multi-action failures.
* Consistent experiment structure.
* Easier game-day preparation.

AWS recommends enabling experiment logging when using scenario templates. ([AWS Documentation][21])

---

# 48. Stop conditions

A stop condition uses a CloudWatch alarm.

```text
Experiment running
      |
      v
CloudWatch alarm enters ALARM
      |
      v
FIS stops experiment
```

A stopped experiment cannot be resumed. ([AWS Documentation][22])

Examples:

```text
Customer 5xx rate > 2%
p99 latency > 2 seconds
Healthy target count < minimum
Queue age > 5 minutes
Payment failure rate > 1%
```

---

# 49. Stop conditions must measure customer impact

Weak stop condition:

```text
One target’s CPU > 90%
```

The experiment may intentionally cause high CPU.

Better:

```text
API availability < 99%
```

Strong stop conditions usually focus on:

* Customer impact.
* Critical business functions.
* System-wide capacity.
* Data integrity risk.
* Experiment-control failures.

---

# 50. Emergency stop strategy

Do not rely on only one alarm.

Use:

```text
Automatic CloudWatch stop condition
+
Named experiment operator
+
Manual stop command
+
On-call monitoring
+
Predefined rollback
```

Manual stop:

```bash
aws fis stop-experiment \
  --id "$EXPERIMENT_ID" \
  --region ap-south-1
```

Stopping FIS prevents remaining experiment actions, but it does not necessarily undo every effect immediately.

---

# 51. IAM experiment role

FIS requires an IAM role granting the exact permissions needed to execute the configured actions. ([AWS Documentation][23])

Bad:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Better:

```text
Allow:
ecs:StopTask

Only:
Tagged TodoApp staging tasks

Deny:
Other applications and accounts
```

AWS-managed FIS policies are convenient but may be broader than a specific experiment needs; AWS recommends narrowing permissions with customer-managed policies. ([AWS Documentation][24])

---

# 52. Separate operator and experiment roles

```text
Human or pipeline operator
    |
    | fis:StartExperiment
    | iam:PassRole
    v
FIS experiment role
    |
    | Limited fault actions
    v
Tagged target resources
```

The operator should not automatically have all resource-fault permissions directly.

The experiment role should not be reusable as a general administrative role.

---

# 53. Logging and audit

FIS experiments can log activity to:

* CloudWatch Logs.
* S3.

CloudTrail records:

* FIS API calls.
* Underlying AWS service actions performed during experiments. ([AWS Documentation][25])

Store:

```text
Experiment ID
Template version
Operator
Targets
Start/end time
Actions
Stop reason
CloudWatch metrics
Observed outcome
Follow-up actions
```

---

# 54. Experiment reports

FIS can generate a PDF experiment report and store it in S3.

Reports can include:

* Experiment actions.
* Timing.
* CloudWatch dashboard snapshots.
* Pre-experiment steady state.
* Experiment impact.
* Post-experiment recovery period. ([AWS Documentation][26])

Use reports as:

* Game-day evidence.
* Compliance evidence.
* Post-experiment review input.
* Reliability maturity tracking.

---

# 55. Multi-account experiments

FIS supports experiments spanning multiple AWS accounts in one Region.

Architecture:

```text
Orchestrator account
        |
        | FIS experiment
        v
Target role in Account A
Target role in Account B
Target role in Account C
```

The orchestrator account owns the template and central logs. Target-account roles grant narrowly scoped permissions. Target-account users receive AWS Health awareness for affected resources. ([AWS Documentation][27])

---

# 56. Multi-account IAM

Multi-account experiments use role chaining:

```text
AWS FIS
   |
   v
Orchestrator experiment role
   |
   v
Target-account FIS role
   |
   v
Target resources
```

Trust policies and permissions are required in the orchestrator and each target account. ([AWS Documentation][28])

Use consistent target tags across accounts:

```text
Application = TodoApp
ChaosReady = true
Environment = production
```

---

# 57. Production experiment approval

Recommended approval record:

```text
Experiment name
Hypothesis
Expected impact
Target resources
Target-preview result
Stop conditions
Start and end window
Incident commander
Application owner
Rollback steps
Communication channel
Change ticket
```

Chaos engineering should be routine and controlled—not secretive.

---

# Part 4 — Amazon Application Recovery Controller

# 58. What is ARC?

Amazon Application Recovery Controller provides capabilities for recovering multi-AZ and multi-Region applications.

Main capabilities:

```text
Zonal shift
Zonal autoshift
Readiness check
Routing control
Region switch
```

Zonal capabilities operate inside one Region. Routing control and Region switch are designed for multi-Region application recovery. ([AWS Documentation][29])

---

# 59. ARC capability comparison

| Capability      | Failure scope     | Main purpose                                            |
| --------------- | ----------------- | ------------------------------------------------------- |
| Zonal shift     | Availability Zone | Manually move traffic away from one AZ                  |
| Zonal autoshift | Availability Zone | AWS automatically moves traffic during an AZ impairment |
| Readiness check | Multi-Region      | Audit replica capacity, quotas and routing readiness    |
| Routing control | Multi-Region      | Reliable traffic on/off switches                        |
| Region switch   | Multi-Region      | Orchestrate complete application recovery workflow      |

---

# Part 5 — Zonal shift

# 60. What is zonal shift?

Zonal shift lets you manually shift traffic for a supported Regional resource away from one Availability Zone to healthy AZs in the same Region. ([AWS Documentation][30])

```text
Before shift:

AZ-A ← traffic
AZ-B ← traffic
AZ-C ← traffic

After shift away from AZ-B:

AZ-A ← more traffic
AZ-B ← no new supported-resource traffic
AZ-C ← more traffic
```

---

# 61. Use cases

Use zonal shift when:

* One AZ has an infrastructure impairment.
* A zonal deployment is unhealthy.
* One AZ shows high latency.
* Network behaviour is abnormal in one zone.
* You want to pre-emptively evacuate traffic.
* A bad zonal application rollout affects one zone.

---

# 62. Zonal shift is temporary

A zonal shift requires an expiration from one minute through 72 hours.

It can be:

* Cancelled early.
* Extended if the problem continues.

It is a mitigation—not a permanent traffic-routing architecture. ([AWS Documentation][31])

---

# 63. Capacity requirement

Before shifting traffic, the application must have enough capacity in the remaining AZs.

For a three-AZ application:

```text
Normal total demand:
300 requests/second

Capacity per AZ:
100 requests/second

Total capacity:
300 requests/second
```

Shift away from one AZ:

```text
Remaining capacity:
200 requests/second

Demand:
300 requests/second

Result:
Overload
```

Better:

```text
Capacity per AZ:
150 requests/second

Remaining after one AZ loss:
300 requests/second

Result:
Demand can still be served
```

ARC recommends pre-scaling applications so that they can operate normally after losing one AZ. ([AWS Documentation][32])

---

# 64. N minus one capacity

For an application spread across `N` AZs, design capacity so that `N-1` AZs can handle the expected workload.

```text
Three AZs:
Any two must handle normal peak demand.
```

This applies to:

* Compute.
* Database connections.
* NAT and egress.
* Load-balancer targets.
* Cache nodes.
* IP capacity.
* Service quotas.
* Downstream dependencies.

---

# 65. Starting a zonal shift

Conceptual CLI:

```bash
aws arc-zonal-shift start-zonal-shift \
  --away-from ap-south-1b \
  --resource-identifier "$RESOURCE_ARN" \
  --expires-in 1h \
  --comment "Shift due to elevated latency" \
  --region ap-south-1
```

Before executing:

```text
[ ] Supported resource
[ ] Correct AZ identifier
[ ] Capacity verified
[ ] Customer metrics monitored
[ ] Rollback/cancel command ready
[ ] Change or incident record created
```

---

# 66. Zonal shift limitations

A zonal shift:

* Does not repair the impaired AZ.
* Does not restore lost data.
* Does not create additional capacity automatically.
* Does not move every dependency.
* Does not protect a single-AZ database.
* Does not guarantee downstream services are zonally independent.

It shifts supported resource traffic.

Your complete application must still be designed for zonal failure.

---

# Part 6 — Zonal autoshift

# 67. What is zonal autoshift?

Zonal autoshift allows AWS to automatically shift traffic away from an AZ when AWS determines that an impairment could affect customers.

The application must already be pre-scaled to operate with one AZ removed. ([AWS Documentation][32])

```text
AWS detects AZ impairment
        |
        v
ARC starts autoshift
        |
        v
Supported-resource traffic
moves to healthy AZs
```

---

# 68. Manual shift versus autoshift

## Zonal shift

```text
Started by:
Your operator or automation
```

## Zonal autoshift

```text
Started by:
AWS during a qualifying AZ impairment
```

Both rely on the same architectural requirement:

```text
Remaining AZs must already have sufficient capacity.
```

---

# 69. Practice runs

Zonal autoshift includes practice-run capabilities that periodically test whether the application can tolerate traffic being shifted away from one AZ.

A practice run helps reveal:

* Insufficient spare capacity.
* Zonal dependency.
* Incorrect health behaviour.
* Autoscaling delay.
* Database bottleneck.
* Network-path limitation.

Practice runs are not equivalent to every possible AZ failure and should be supplemented with application-level tests.

---

# 70. Excluding unsafe practice windows

Avoid practice shifts during:

* Peak business events.
* Major deployments.
* Database migrations.
* Capacity-constrained periods.
* Existing incidents.
* External dependency maintenance.

Operational calendars and alarms should inform when practice runs are safe.

---

# 71. Testing autoshift with FIS

AWS FIS can test how autoshift-enabled resources respond to a simulated AZ impairment and autoshift trigger.

This differs from normal autoshift practice runs: FIS demonstrates impairment/autoshift behaviour as an experiment and cancels the induced autoshift after the scenario completes. ([AWS Documentation][33])

---

# 72. Zonal evacuation checklist

```text
[ ] Application spans at least two supported AZs
[ ] Remaining AZ capacity is sufficient
[ ] Autoscaling maximum supports recovery load
[ ] Database is Multi-AZ
[ ] Cache can lose a node/AZ
[ ] NAT and egress are zonally resilient
[ ] No hard-coded zonal endpoint exists
[ ] Customer SLO alarm is configured
[ ] Zonal shift has been practised
[ ] Return-to-normal procedure is documented
```

---

# Part 7 — ARC readiness checks

# 73. What is a readiness check?

ARC readiness checks continually audit whether multi-Region application replicas are configured and scaled to support recovery.

They can evaluate information such as:

* Resource quotas.
* Capacity.
* Network-routing configuration.
* Resource configuration consistency. ([AWS Documentation][34])

---

# 74. Readiness-check model

```text
Recovery group
├── Cell: ap-south-1
│   ├── ALB
│   ├── Auto Scaling group
│   └── Database
│
└── Cell: ap-southeast-1
    ├── ALB
    ├── Auto Scaling group
    └── Database

Resource sets
    |
    v
Readiness checks
    |
    v
READY / NOT READY
```

---

# 75. Recovery group

A recovery group represents the complete application or capability being recovered.

Example:

```text
TodoApp recovery group
├── Mumbai cell
└── Singapore cell
```

A cell represents an isolated application replica or failure boundary.

---

# 76. Resource set

A resource set groups equivalent resources across cells.

Example:

```text
ALB resource set
├── Mumbai ALB
└── Singapore ALB

Auto Scaling resource set
├── Mumbai ASG
└── Singapore ASG
```

Readiness rules compare or inspect resources in the set.

---

# 77. What readiness checks can catch

Examples:

```text
Standby Auto Scaling maximum too low
Standby subnet has insufficient IP space
Regional quota too low
DNS routing is inconsistent
Replica resource missing
Database configuration differs
Health-check policy is incorrect
```

ARC provides predefined readiness rules by supported resource type; the rules cannot be freely rewritten, although CloudWatch alarms can be incorporated as custom readiness indicators. ([AWS Documentation][31])

---

# 78. Readiness is not runtime health

A readiness check can say:

```text
READY
```

while the application is currently unhealthy because:

* Code is broken.
* External dependency is down.
* Customer requests fail.
* Certificate expired.
* Data is corrupt.

Readiness checks answer:

```text
Is the recovery architecture prepared?
```

CloudWatch and synthetic tests answer:

```text
Is the service healthy now?
```

---

# Part 8 — ARC routing control

# 79. What is routing control?

ARC routing control provides highly available on/off switches for moving traffic between multi-Region replicas.

Routing controls integrate with special Route 53 health checks and DNS routing records. ([AWS Documentation][35])

```text
Routing control:
Mumbai = ON

Routing control:
Singapore = OFF
```

Route 53 interprets the states through routing-control health checks.

---

# 80. Routing-control components

```text
ARC cluster
    |
    v
Control panel
    |
    ├── Mumbai routing control
    ├── Singapore routing control
    └── Recovery safety control
```

Components:

```text
Cluster
Control panel
Routing controls
Routing-control health checks
Safety rules
```

Each ARC cluster provides a data plane with endpoints in five AWS Regions. ([AWS Documentation][35])

---

# 81. Five data-plane endpoints

ARC provides five Regional endpoints for each routing-control cluster.

Best practice:

```text
Store all five endpoint URLs.

Choose an endpoint.

Retry through other endpoints if needed.

Use the routing-control data-plane API.
```

AWS recommends using the highly available data-plane API rather than depending on the console during an incident. ([AWS Documentation][36])

---

# 82. Why not depend only on the console?

During a major event:

* The console may be inaccessible to an operator.
* Federation may be impaired.
* A control-plane operation may fail.
* Documentation or bookmarks may be unavailable.

Recovery tooling should have:

```text
Saved cluster endpoints
Saved routing-control ARNs
Purpose-built credentials
CLI/API runbook
Multi-endpoint retry logic
Offline copy of procedure
```

---

# 83. Routing-control DNS architecture

```text
Route 53 failover record
        |
        v
ARC routing-control health check
        |
        v
Routing control state
        |
        ├── ON  → Record considered healthy
        └── OFF → Record considered unhealthy
```

Example:

```text
api.yourdatascientist.tech

Primary record:
ALB Mumbai
Health based on Mumbai routing control

Secondary record:
ALB Singapore
Health based on Singapore routing control
```

---

# 84. Routing-control state change

Conceptual:

```bash
aws route53-recovery-cluster \
  update-routing-control-state \
  --routing-control-arn "$SINGAPORE_CONTROL_ARN" \
  --routing-control-state On \
  --endpoint-url "$CLUSTER_ENDPOINT" \
  --region "$ENDPOINT_REGION"
```

When changing several states, use batch operations where appropriate to reduce unsafe intermediate states.

---

# 85. Safety rules

Routing controls support:

```text
Assertion rules
Gating rules
```

Safety rules reduce the risk of recovery automation causing an outage. ([AWS Documentation][37])

---

# 86. Assertion rule

An assertion rule requires a condition to remain true when routing-control states change.

Example:

```text
At least one Region must remain ON.
```

```text
Mumbai ON
Singapore OFF
    → Valid

Mumbai OFF
Singapore ON
    → Valid

Mumbai OFF
Singapore OFF
    → Blocked
```

This prevents accidentally turning off all traffic. ([AWS Documentation][38])

---

# 87. Gating rule

A gating rule introduces a master control governing whether specified routing controls can be changed.

Example:

```text
RecoveryAutomationEnabled = OFF
```

Automation cannot modify production routing controls.

During an approved failover:

```text
RecoveryAutomationEnabled = ON
```

The target routing controls can then be updated.

Gating controls are not themselves connected to DNS failover records. ([AWS Documentation][38])

---

# 88. Routing-control credentials

Recovery credentials should be:

* Purpose built.
* Protected outside the primary failure domain.
* Available during identity-provider impairment.
* Limited to ARC state operations.
* Rotated and tested.
* Logged.
* Controlled through break-glass procedures.

AWS specifically recommends keeping routing-control credentials and endpoint information secure but always accessible during a failure. ([AWS Documentation][36])

---

# 89. DNS TTL

Failover speed is affected by DNS TTL and client caching.

Example:

```text
TTL:
300 seconds
```

Some clients may continue using the previous endpoint for several minutes.

Lower TTL:

* Speeds DNS change adoption.
* Increases DNS query volume.
* Does not force all clients to obey immediately.
* Does not terminate long-lived existing connections.

ARC recommends lower TTLs for DNS records involved in failover and limiting long-lived client connections. ([AWS Documentation][36])

---

# Part 9 — ARC Region switch

# 90. What is Region switch?

Region switch provides an orchestrated recovery plan for applications deployed across two Regions.

It supports:

```text
Active/passive
Active/active
Cross-account application resources
Shared recovery plans
Failover and failback
Shift-away and return
```

([AWS Documentation][39])

---

# 91. Routing control versus Region switch

## Routing control

```text
Changes traffic state
```

## Region switch

```text
Orchestrates complete recovery:
Capacity
Database
Custom actions
Approvals
Traffic routing
Validation
```

A Region switch workflow can include an ARC routing-control execution block as one step.

---

# 92. Region switch plan

A plan is scoped to one multi-Region application.

```text
TodoApp Region switch plan
├── Primary Region: ap-south-1
├── Standby Region: ap-southeast-1
├── Desired RTO: 30 minutes
└── Recovery workflows
```

A plan contains one or more workflows, which contain ordered or parallel execution-block steps. ([AWS Documentation][40])

---

# 93. Region switch workflow

```text
Workflow: Activate Singapore
    |
    ├── Step 1: Enable maintenance mode
    ├── Step 2: Fence writes in Mumbai
    ├── Step 3: Promote secondary database
    ├── Step 4: Scale Singapore compute
    ├── Step 5: Run health validation
    ├── Step 6: Manual approval
    ├── Step 7: Switch traffic
    └── Step 8: Confirm customer health
```

Steps can run:

```text
Sequentially
or
In parallel
```

([AWS Documentation][41])

---

# 94. Active/passive plan

```text
Normal state:

Mumbai:
Active

Singapore:
Standby
```

Recovery:

```text
Activate Singapore
Fence Mumbai
Promote data
Scale compute
Shift traffic
```

An active/passive Region switch plan can use one generic activation workflow or separate workflows for each Region. ([AWS Documentation][41])

---

# 95. Active/active plan

```text
Normal state:

Mumbai:
Active

Singapore:
Active
```

During impairment:

```text
Deactivate impaired Region
Scale healthy Region if needed
Shift away traffic
```

Return:

```text
Validate repaired Region
Reactivate
Rebalance traffic
```

Active/active plans define activation and deactivation workflows. ([AWS Documentation][41])

---

# 96. Graceful execution

Graceful mode is used for planned recovery when both environments are reachable.

Example:

```text
1. Stop accepting new writes.

2. Drain traffic.

3. Synchronize final data.

4. Promote destination.

5. Switch traffic.

6. Deactivate source.
```

This minimizes:

* Data loss.
* Split brain.
* Duplicate processing.
* Interrupted transactions.

---

# 97. Ungraceful execution

Ungraceful mode is used when the impaired Region cannot cooperate.

Example:

```text
Primary Region unavailable
      |
      v
Skip source-side draining
      |
      v
Promote healthy Region
      |
      v
Activate traffic quickly
```

Region switch can alter or skip execution blocks according to whether the plan runs gracefully or ungracefully. ([AWS Documentation][41])

---

# 98. Data fencing

Before promoting a secondary Region, prevent two Regions from accepting conflicting writes.

Fencing techniques:

```text
Disable primary writer endpoint
Revoke write credential
Change database role
Block primary network path
Disable queue consumers
Set application read-only
Use epoch/leader token
```

Without fencing:

```text
Region A accepts writes
Region B accepts writes
    |
    v
Split brain
```

---

# 99. Execution blocks

Region switch workflows can coordinate actions such as:

* Scaling Auto Scaling groups.
* Promoting Aurora Global Database.
* Updating ARC routing controls.
* Invoking custom Lambda actions.
* Requiring manual approval.
* Executing nested child Region switch plans.

The official active/passive tutorial combines Auto Scaling, manual approvals, custom Lambda actions, Aurora Global Database and routing-control blocks. ([AWS Documentation][42])

---

# 100. Manual approval block

A manual approval block pauses the plan and waits for an authorized approver.

Use before:

* Database promotion.
* Public traffic switch.
* Destructive fencing.
* Failback.
* Shutting down the original Region.

The approval role requires permission to approve the execution step and must be correctly configured in the plan-owning account. ([AWS Documentation][43])

---

# 101. Recovery plan RTO tracking

A Region switch plan can store a desired RTO.

During executions, you can compare:

```text
Desired RTO:
30 minutes

Actual execution:
24 minutes

Result:
Target met
```

or:

```text
Actual:
42 minutes

Result:
Target missed
```

Region switch uses the configured RTO to provide insight into plan-execution duration. ([AWS Documentation][44])

---

# 102. Parent and child plans

A large platform may have:

```text
Parent plan:
Customer Platform Recovery

Child plans:
Identity
Payments
TodoApp
Notifications
Analytics
```

A parent workflow can execute child Region switch plans to coordinate dependencies. Child plans must use compatible Regions and the same recovery approach, and additional child nesting is restricted. ([AWS Documentation][45])

---

# 103. Cross-account recovery

Region switch supports resources across AWS accounts.

Example:

```text
Network account:
Global routing

Database account:
Aurora Global Database

TodoApp account:
Compute

Security account:
Approval and automation
```

Cross-account resources require:

* Resource-side IAM roles.
* Plan execution role trust.
* Narrow service permissions.
* External ID where configured.
* Tested role assumption. ([AWS Documentation][42])

---

# 104. Plan evaluation

Before execution, validate the plan.

Check:

```text
IAM role exists
Cross-account roles are assumable
Resources exist
Regions match
Execution blocks are configured
Routing controls are valid
Manual approval roles are valid
Child plans remain shared
```

Warnings should be resolved before a real incident.

---

# 105. Region switch best practices

Recovery preparation should include:

```text
Purpose-built recovery credentials
Offline runbook
Low DNS TTL
Pre-scaled secondary capacity
Healthy standby data
Plan evaluation
Regular executions
Measured RTO
Independent approval access
```

AWS specifically recommends keeping recovery credentials accessible and using lower TTLs for failover DNS records. ([AWS Documentation][46])

---

# Part 10 — Choosing the ARC capability

# 106. Decision table

## One AZ appears impaired

Use:

```text
Zonal shift
```

## AWS should automatically evacuate supported traffic during AZ impairment

Use:

```text
Zonal autoshift
```

## Need to audit whether the standby is ready

Use:

```text
Readiness check
```

## Need highly reliable manual or automated DNS failover switches

Use:

```text
Routing control
```

## Need a complete multi-step Regional recovery workflow

Use:

```text
Region switch
```

---

# 107. Capability combination

A mature application can use all capabilities:

```text
Normal operation:
Readiness checks

Zonal problem:
Zonal shift/autoshift

Regional problem:
Region switch workflow

Traffic activation:
Routing controls

Validation:
CloudWatch and synthetics

Testing:
AWS FIS

Assessment:
Resilience Hub
```

---

# Part 11 — TodoApp production design

# 108. TodoApp architecture

```text
Users
  |
  v
Route 53 / CloudFront
  |
  v
ALB or API Gateway
  |
  v
ECS across 3 AZs
  |
  ├── Aurora
  ├── ElastiCache
  ├── SQS
  ├── S3
  └── Cognito
```

Resilience objectives:

```text
Application failure:
RTO 5 minutes
RPO 0

Infrastructure failure:
RTO 10 minutes
RPO 0

AZ failure:
RTO 15 minutes
RPO 0–5 minutes

Region failure:
RTO 60 minutes
RPO 15 minutes
```

These values are illustrative and require business approval.

---

# 109. Resilience Hub model

```text
TodoApp
├── Edge AppComponent
├── API Compute AppComponent
├── Database AppComponent
├── Cache AppComponent
├── Messaging AppComponent
├── Storage AppComponent
└── Identity AppComponent
```

Input sources:

```text
Terraform state
CloudFormation stacks
EKS namespaces where used
Manually added external dependency placeholders
```

---

# 110. TodoApp FIS progression

## Experiment 1

```text
Stop one ECS task
```

Expected:

```text
No customer error increase
Task replaced in < 2 minutes
```

## Experiment 2

```text
Add 300 ms network latency to one task
```

Expected:

```text
ALB removes unhealthy target
p95 remains within SLO
```

## Experiment 3

```text
Aurora failover
```

Expected:

```text
Clients reconnect
No duplicate writes
Recovery < 60 seconds
```

## Experiment 4

```text
Complete AZ power-interruption scenario
```

Expected:

```text
Remaining AZs handle traffic
No queue backlog breach
```

## Experiment 5

```text
Regional game day
```

Expected:

```text
Region switch completes inside RTO
```

---

# 111. TodoApp zonal capacity

Assume peak load:

```text
900 requests/second
```

Three AZs.

Required N-1 design:

```text
Two AZs must serve 900 requests/second.
```

Minimum capacity per AZ:

```text
450 requests/second
```

Add operational headroom:

```text
Target:
550–600 requests/second per AZ
```

Also verify:

* Database connection capacity.
* NAT throughput.
* Cache capacity.
* SQS consumer capacity.
* Subnet IP space.
* ECS maximum desired count.

---

# 112. TodoApp Region switch workflow

```text
Workflow: Activate Singapore

1. Verify Singapore infrastructure readiness.

2. Enable maintenance page for write operations.

3. Pause Mumbai asynchronous producers.

4. Fence Mumbai database writes.

5. Promote Singapore database.

6. Update application secrets/endpoints.

7. Scale Singapore ECS service.

8. Wait for healthy ALB targets.

9. Run synthetic:
   login
   create todo
   read todo
   update todo

10. Manual approval.

11. Turn Singapore routing control ON.

12. Turn Mumbai routing control OFF.

13. Disable maintenance mode.

14. Monitor SLOs.

15. Record actual RTO and RPO.
```

---

# 113. Failback workflow

```text
1. Repair Mumbai.

2. Re-establish data replication.

3. Verify zero unresolved conflicts.

4. Deploy same application version.

5. Scale Mumbai.

6. Run synthetic validation.

7. Enter maintenance or controlled drain.

8. Fence Singapore writes.

9. Promote Mumbai.

10. Switch routing controls.

11. Monitor.

12. Return Singapore to standby.
```

Failback should be planned and tested separately from failover.

---

# Part 12 — Terraform implementation

# 114. Resilience policy

Conceptual Terraform:

```hcl
resource "aws_resiliencehub_resiliency_policy" "todoapp" {
  name = "todoapp-production"

  description = "TodoApp production recovery objectives"

  tier = "MissionCritical"

  policy {
    software {
      rto = 300
      rpo = 0
    }

    hardware {
      rto = 600
      rpo = 0
    }

    az {
      rto = 900
      rpo = 300
    }

    region {
      rto = 3600
      rpo = 900
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Validate exact tier names and resource schema against the AWS provider version pinned in the project because Resilience Hub resources and terminology continue to evolve.

---

# 115. FIS experiment role

```hcl
data "aws_iam_policy_document" "fis_trust" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "fis.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "fis" {
  name = "todoapp-fis-stop-instance"

  assume_role_policy = (
    data.aws_iam_policy_document.fis_trust.json
  )
}
```

Permissions:

```hcl
data "aws_iam_policy_document" "fis_actions" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:DescribeInstances"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ChaosReady"

      values = [
        "true"
      ]
    }
  }
}

resource "aws_iam_role_policy" "fis_actions" {
  role   = aws_iam_role.fis.id
  policy = data.aws_iam_policy_document.fis_actions.json
}
```

Confirm each action’s supported resource-level and condition-key behaviour before relying on tag conditions as the only boundary.

---

# 116. CloudWatch stop alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "customer_errors" {
  alarm_name = "todoapp-fis-stop-customer-impact"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  threshold = 2

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests>0,100*errors/requests,0)"
    label       = "ALB target 5xx percentage"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.todoapp.arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.todoapp.arn_suffix
      }
    }
  }

  treat_missing_data = "breaching"
}
```

Treating missing telemetry as breaching is appropriate when losing the signal means the experiment is no longer safely observable.

---

# 117. FIS experiment template

```hcl
resource "aws_fis_experiment_template" "stop_one_instance" {
  description = "Stop one ChaosReady TodoApp EC2 instance"

  role_arn = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.customer_errors.arn
  }

  target {
    name           = "oneTodoInstance"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "ChaosReady"
      value = "true"
    }

    resource_tag {
      key   = "Application"
      value = "TodoApp"
    }

    resource_tag {
      key   = "Environment"
      value = "staging"
    }
  }

  action {
    name      = "stopOneInstance"
    action_id = "aws:ec2:stop-instances"

    parameter {
      key   = "startInstancesAfterDuration"
      value = "PT3M"
    }

    target {
      key   = "Instances"
      value = "oneTodoInstance"
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}
```

`aws_fis_experiment_template` manages templates containing targets, actions and stop conditions. ([Terraform Registry][47])

---

# 118. FIS log group

```hcl
resource "aws_cloudwatch_log_group" "fis" {
  name = "/aws/fis/todoapp"

  retention_in_days = 90

  kms_key_id = aws_kms_key.logs.arn

  tags = {
    Application = "TodoApp"
    Purpose     = "resilience-testing"
  }
}
```

Add the corresponding FIS log configuration to the experiment template according to the pinned provider version.

---

# 119. ARC routing-control cluster

```hcl
resource "aws_route53recoverycontrolconfig_cluster" "todoapp" {
  name = "todoapp-production"
}
```

Control panel:

```hcl
resource "aws_route53recoverycontrolconfig_control_panel" "todoapp" {
  name        = "todoapp-regions"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.todoapp.arn
}
```

Routing controls:

```hcl
resource "aws_route53recoverycontrolconfig_routing_control" "mumbai" {
  name = "mumbai"

  cluster_arn = (
    aws_route53recoverycontrolconfig_cluster.todoapp.arn
  )

  control_panel_arn = (
    aws_route53recoverycontrolconfig_control_panel.todoapp.arn
  )
}

resource "aws_route53recoverycontrolconfig_routing_control" "singapore" {
  name = "singapore"

  cluster_arn = (
    aws_route53recoverycontrolconfig_cluster.todoapp.arn
  )

  control_panel_arn = (
    aws_route53recoverycontrolconfig_control_panel.todoapp.arn
  )
}
```

The provider exposes separate control-panel and routing-control resources. ([Terraform Registry][48])

---

# 120. Routing-control health checks

```hcl
resource "aws_route53_health_check" "mumbai_control" {
  type = "RECOVERY_CONTROL"

  routing_control_arn = (
    aws_route53recoverycontrolconfig_routing_control.mumbai.arn
  )
}

resource "aws_route53_health_check" "singapore_control" {
  type = "RECOVERY_CONTROL"

  routing_control_arn = (
    aws_route53recoverycontrolconfig_routing_control.singapore.arn
  )
}
```

These health checks can be attached to Route 53 failover records.

---

# 121. Route 53 failover records

```hcl
resource "aws_route53_record" "api_primary" {
  zone_id = aws_route53_zone.main.zone_id

  name = "api.yourdatascientist.tech"
  type = "A"

  set_identifier = "mumbai"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.mumbai_control.id

  alias {
    name                   = aws_lb.mumbai.dns_name
    zone_id                = aws_lb.mumbai.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_secondary" {
  zone_id = aws_route53_zone.main.zone_id

  name = "api.yourdatascientist.tech"
  type = "A"

  set_identifier = "singapore"
  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = (
    aws_route53_health_check.singapore_control.id
  )

  alias {
    name                   = aws_lb.singapore.dns_name
    zone_id                = aws_lb.singapore.zone_id
    evaluate_target_health = true
  }
}
```

ARC routing-control health checks should represent operator-controlled routing state rather than ordinary endpoint health.

---

# 122. Region switch Terraform

The AWS provider includes the `aws_arcregionswitch_plan` resource for managing ARC Region switch plans. Plan configuration can include Regions, recovery approach, execution roles, workflows and execution blocks. ([Terraform Registry][49])

Because a production Region switch plan has many nested execution-block types and cross-account permissions, maintain it in a dedicated module:

```text
modules/region-switch/
├── plan.tf
├── workflows.tf
├── approvals.tf
├── database.tf
├── compute.tf
├── routing.tf
├── iam.tf
└── outputs.tf
```

Pin the provider version and test plan changes in a non-production pair of Regions.

---

# Part 13 — Safe hands-on FIS lab

# 123. Lab objective

Safely test:

```text
Target preview
One disposable EC2 instance stop
Automatic restart after 3 minutes
CloudWatch stop condition
Experiment evidence
Cleanup
```

Region:

```text
ap-south-1
```

Use only a disposable lab instance.

---

# 124. Prerequisites

```text
[ ] Disposable EC2 instance
[ ] Instance tagged ChaosReady=true
[ ] No production data
[ ] No Auto Scaling dependency
[ ] FIS IAM role
[ ] CloudWatch stop alarm
[ ] Session Manager or console access
```

Tag:

```bash
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags \
    Key=ChaosReady,Value=true \
    Key=Application,Value=TodoApp \
    Key=Environment,Value=lab \
  --region ap-south-1
```

---

# 125. Create experiment-template JSON

```bash
cat > /tmp/fis-template.json <<EOF
{
  "description": "Stop one TodoApp lab instance",
  "roleArn": "${FIS_ROLE_ARN}",
  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "${STOP_ALARM_ARN}"
    }
  ],
  "targets": {
    "oneLabInstance": {
      "resourceType": "aws:ec2:instance",
      "resourceTags": {
        "ChaosReady": "true",
        "Application": "TodoApp",
        "Environment": "lab"
      },
      "selectionMode": "COUNT(1)"
    }
  },
  "actions": {
    "stopInstance": {
      "actionId": "aws:ec2:stop-instances",
      "parameters": {
        "startInstancesAfterDuration": "PT3M"
      },
      "targets": {
        "Instances": "oneLabInstance"
      }
    }
  },
  "tags": {
    "Application": "TodoApp",
    "Environment": "lab"
  }
}
EOF
```

---

# 126. Create template

```bash
TEMPLATE_ID=$(
  aws fis create-experiment-template \
    --cli-input-json file:///tmp/fis-template.json \
    --region ap-south-1 \
    --query experimentTemplate.id \
    --output text
)

echo "$TEMPLATE_ID"
```

---

# 127. Generate target preview

```bash
PREVIEW_EXPERIMENT_ID=$(
  aws fis start-experiment \
    --experiment-template-id "$TEMPLATE_ID" \
    --experiment-options actionsMode=skip-all \
    --region ap-south-1 \
    --query experiment.id \
    --output text
)

echo "$PREVIEW_EXPERIMENT_ID"
```

Inspect:

```bash
aws fis get-experiment \
  --id "$PREVIEW_EXPERIMENT_ID" \
  --region ap-south-1
```

Verify that exactly the disposable instance is listed.

Do not proceed if another resource appears.

---

# 128. Run real experiment

```bash
EXPERIMENT_ID=$(
  aws fis start-experiment \
    --experiment-template-id "$TEMPLATE_ID" \
    --client-token "$(uuidgen)" \
    --region ap-south-1 \
    --query experiment.id \
    --output text
)

echo "$EXPERIMENT_ID"
```

Monitor:

```bash
watch -n 10 \
  "aws fis get-experiment \
    --id '$EXPERIMENT_ID' \
    --region ap-south-1 \
    --query 'experiment.{Status:state.status,Reason:state.reason}'"
```

---

# 129. Validate

Check the instance:

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region ap-south-1 \
  --query 'Reservations[0].Instances[0].State.Name'
```

Expected sequence:

```text
running
→ stopping
→ stopped
→ pending
→ running
```

Validate application or host recovery:

```text
[ ] Instance restarts
[ ] Status checks pass
[ ] SSM reconnects
[ ] Application service starts
[ ] Logs resume
[ ] Alarm remains acceptable
```

---

# 130. Cleanup

```bash
aws fis delete-experiment-template \
  --id "$TEMPLATE_ID" \
  --region ap-south-1

rm -f /tmp/fis-template.json
```

Remove lab tags or terminate the disposable instance after completing the test.

---

# Part 14 — Game-day engineering

# 131. What is a game day?

A game day is a planned exercise in which teams practise detecting, responding to and recovering from failures.

Participants:

```text
Incident commander
Application owner
Platform engineer
Database engineer
Network engineer
Security engineer
Observer/scribe
Business representative
```

---

# 132. Game-day phases

```text
1. Planning

2. Baseline verification

3. Failure injection

4. Detection

5. Diagnosis

6. Recovery

7. Business validation

8. Failback

9. Review
```

---

# 133. Planning checklist

```text
[ ] Hypothesis defined
[ ] Scope defined
[ ] Target preview completed
[ ] Customer impact limit defined
[ ] Stop conditions tested
[ ] IAM roles validated
[ ] Recovery procedure available
[ ] Communications channel created
[ ] Business owner informed
[ ] Change freeze agreed
[ ] Rollback tested
[ ] Experiment logging enabled
```

---

# 134. During the game day

Record exact timestamps:

```text
T0:
Fault started

T1:
First alert fired

T2:
On-call acknowledged

T3:
Root cause identified

T4:
Recovery action started

T5:
Technical service restored

T6:
Business function validated
```

Derive:

```text
Detection time = T1 - T0

Acknowledgement time = T2 - T1

Diagnosis time = T3 - T2

Recovery time = T5 - T3

Business RTO = T6 - T0
```

---

# 135. Game-day success criteria

Success does not mean:

```text
No alarm fired
because nobody noticed.
```

Success means:

* Fault stayed inside approved blast radius.
* Detection occurred.
* Correct people responded.
* Runbook was usable.
* Recovery worked.
* SLO remained within expected tolerance or recovered inside target.
* Gaps were documented.
* Improvements received owners and deadlines.

---

# 136. Post-game review

Document:

```text
What happened?
What was expected?
What differed?
Which alarms were late?
Which dashboard was missing?
Which permission failed?
Which manual step was confusing?
Was RTO met?
Was data loss inside RPO?
What should be automated?
What should remain manual?
```

Convert each lesson into:

```text
Owner
Action
Deadline
Priority
Verification test
```

---

# Part 15 — Troubleshooting

# 137. Resilience Hub misses resources

Check:

* Input source.
* Terraform state location and permissions.
* CloudFormation stack status.
* Resource Group membership.
* EKS access role and RBAC.
* Cross-account assessment role.
* Unsupported resource type.
* Draft versus published application version.
* Resource was added after last import.

Resilience Hub assesses the published application version; changes made only in the draft must be published before the new structure is used. ([AWS Documentation][50])

---

# 138. Assessment shows wrong RTO

Possible causes:

* Resource grouped into wrong AppComponent.
* Standby resource not discovered.
* Backup configuration not detected.
* Resource relationship missing.
* Terraform state outdated.
* Database replica grouped separately.
* Application policy targets misunderstood.
* Unsupported architecture pattern.

Review resource instances and application-component grouping rather than adjusting the business policy simply to make the assessment pass.

---

# 139. Resilience score remains low

Check:

```text
[ ] RTO/RPO policy compliance
[ ] Recommended alarms implemented
[ ] SOPs implemented
[ ] FIS experiments implemented
[ ] Excluded recommendations justified
[ ] Latest assessment run
[ ] Application structure current
```

Including or excluding operational recommendations affects the score only after another assessment is run. ([AWS Documentation][51])

---

# 140. FIS experiment targets too many resources

Immediately stop before running actions.

Check:

* Tag keys.
* Tag values.
* Selection mode.
* Account targeting.
* Region.
* Resource filters.
* Target preview.
* Random percentage behaviour.
* Newly added resources.

Use:

```text
COUNT(1)
```

before increasing percentage-based scope.

---

# 141. FIS target preview is empty

Check:

* Resource exists in Region.
* Resource type is correct.
* Tags match exactly.
* Filters match.
* Experiment role can describe resources.
* Target account role works.
* Empty-target resolution setting.
* Resource is in supported state.

Targets are resolved at experiment start; dynamic infrastructure may differ from an earlier preview. ([AWS Documentation][52])

---

# 142. FIS experiment stops immediately

Check:

* Stop alarm is already in `ALARM`.
* Alarm has insufficient or missing data.
* Metric dimensions incorrect.
* Alarm period too short.
* Baseline already breached.
* IAM error.
* Target cannot be resolved.
* KMS permission missing.
* Action unsupported for resource state.

Verify all stop alarms are healthy immediately before starting.

---

# 143. FIS stopped but failure continues

Stopping an experiment does not necessarily instantly reverse effects.

Examples:

```text
Terminated instance:
Cannot be restarted

Database failover:
Already occurred

Network disruption:
May require action duration to finish

Stopped process:
Application must restart it
```

Design rollback according to the fault action—not merely the FIS experiment state.

---

# 144. Zonal shift causes overload

Root causes:

* No N-1 capacity.
* Autoscaling reacted too slowly.
* Maximum capacity too low.
* Subnets lack IPs.
* Database connection limit reached.
* Cache capacity insufficient.
* NAT or egress bottleneck.
* Downstream quotas exceeded.

Cancel the shift if customer impact is worse than the original impairment, then correct capacity before the next test.

---

# 145. Zonal shift does not move all traffic

Possible reasons:

* Resource type or configuration not supported.
* Existing long-lived connections remain.
* Dependency is outside the shifted resource.
* DNS caching.
* Application uses zonal endpoint directly.
* Target group configuration.
* Cross-zone behaviour.
* Shift applied to wrong resource identifier.

A zonal shift affects supported traffic paths, not arbitrary application connections.

---

# 146. Autoshift practice run fails

Check:

* Insufficient remaining capacity.
* Practice-run alarm triggered.
* Resource not opted in.
* Exclusion window.
* Application already experiencing an event.
* One AZ contains unique dependency.
* Autoscaling configuration.
* Unsupported resource mode.

Treat practice-run failure as evidence of a resilience gap—not as a reason to disable testing permanently.

---

# 147. ARC readiness status is `NOT READY`

Inspect individual readiness rules.

Common causes:

* Replica size mismatch.
* Regional quota insufficient.
* Resource missing.
* DNS records inconsistent.
* Health-check configuration differs.
* Standby capacity too low.
* Network configuration mismatch.

Do not manually mark the application ready without correcting or explicitly accepting the risk.

---

# 148. Routing-control update fails

Check:

* Correct cluster endpoint.
* Correct endpoint Region.
* Routing-control ARN.
* Purpose-built IAM credentials.
* Safety rule.
* Control panel.
* Gating control state.
* API retry logic.
* Network access.
* Clock synchronization.

Use all five cluster endpoints in retry logic. ARC routing-control state propagation across endpoints is designed to converge rapidly, with AWS documenting consistency within seconds. ([AWS Documentation][53])

---

# 149. Both routing controls cannot be turned off

This is likely an assertion safety rule working correctly.

Example:

```text
Required:
At least one control ON
```

To perform maintenance:

* Keep maintenance endpoint ON.
* Use a gating strategy.
* Update the safety design through approved control-plane operations.
* Do not bypass safety rules during an active incident unless the implications are understood.

---

# 150. Region switch plan evaluation warns

Check:

* Execution role permissions.
* Cross-account role trust.
* External ID.
* Child plan still shared.
* Resource exists in both Regions.
* Plan Regions match child plans.
* Approval role.
* Routing-control configuration.
* Aurora Global Database state.
* Lambda action exists.

Plan warnings should be resolved during normal operations—not during failover.

---

# 151. Region switch exceeds RTO

Measure each execution block:

```text
Database promotion:
12 minutes

Compute scaling:
8 minutes

Health checks:
7 minutes

Manual approval:
15 minutes

DNS adoption:
6 minutes
```

Total:

```text
48 minutes
```

Target:

```text
30 minutes
```

Improvements:

* Pre-scale standby.
* Reduce manual approval latency.
* Parallelize independent steps.
* Lower DNS TTL.
* Warm application caches.
* Pre-provision certificates and secrets.
* Optimize database promotion.
* Automate validation.

---

# 152. Failover succeeds but writes conflict

This indicates inadequate fencing or active/active conflict control.

Actions:

```text
1. Stop one writer path.

2. Preserve both data sets.

3. Identify overlapping writes.

4. Reconcile according to business rules.

5. Repair leader/epoch logic.

6. Retest ungraceful failover.
```

Never resolve split brain by deleting one side before understanding business transactions.

---

# 153. Production readiness checklist

```text
[ ] Business resilience objectives are documented
[ ] RTO/RPO differ by disruption type
[ ] Failure domains are mapped
[ ] Critical dependencies are identified
[ ] N-1 zonal capacity is verified
[ ] Resilience Hub application matches real architecture
[ ] AppComponents reflect failure boundaries
[ ] Resiliency policy has business approval
[ ] Assessments run after architecture changes
[ ] Scheduled assessments are enabled
[ ] Drift notifications are routed to owners
[ ] Alarm recommendations are reviewed
[ ] SOPs are version controlled
[ ] SOP permissions follow least privilege
[ ] SOPs are tested through FIS
[ ] Resilience score is tracked but not gamed
[ ] Every FIS experiment has a hypothesis
[ ] Every experiment has a target preview
[ ] Experiment targets use restrictive tags
[ ] Production experiments begin with COUNT(1)
[ ] Customer-impact stop conditions exist
[ ] Manual emergency stop is documented
[ ] FIS experiment role is least privilege
[ ] Experiment logs are retained
[ ] Experiment reports are stored
[ ] Multi-account role trust is tested
[ ] Zonal shifts have been practised
[ ] Autoshift-enabled resources have N-1 capacity
[ ] Practice-run exclusion windows are documented
[ ] ARC readiness checks cover critical replicas
[ ] Regional quotas support failover
[ ] ARC cluster endpoints are stored offline
[ ] Recovery credentials are independently accessible
[ ] Routing controls have assertion safety rules
[ ] Gating rules protect automation
[ ] Route 53 TTL supports RTO
[ ] Region switch plan is evaluated regularly
[ ] Graceful and ungraceful workflows exist
[ ] Database fencing is tested
[ ] Manual approval roles are independently accessible
[ ] Cross-account roles are least privilege
[ ] Failover RTO is measured
[ ] Failback is separately tested
[ ] Game days occur regularly
[ ] Every game-day gap has an owner
```

---

# 154. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Resilience Hub:
Application resilience assessment

FIS:
Controlled fault injection

ARC:
Application recovery and traffic shifting
```

## Solutions Architect Associate

Understand:

```text
RTO and RPO
Failure domains
Multi-AZ capacity
Zonal shift
Readiness checks
Routing controls
Route 53 failover
FIS stop conditions
```

## DevOps Engineer Professional

Understand:

```text
Resilience policies
AppComponents
Assessment and drift
SOP automation
FIS experiment templates
Target preview
Multi-account FIS
Scenario library
Zonal autoshift
Routing-control safety rules
Five-endpoint data plane
Region switch workflows
Graceful/ungraceful execution
Game-day measurement
```

---

# 155. Interview questions

## Question 1: What is AWS Resilience Hub?

**Answer:**

It is a service that models applications, evaluates them against defined RTO and RPO targets and recommends architecture, alarms, recovery procedures and fault experiments.

## Question 2: What is an AppComponent?

**Answer:**

It is a logical group of related application resources that operate and fail as one component, such as compute or database resources.

## Question 3: Does Resilience Hub guarantee the stated RTO?

**Answer:**

No. It estimates recovery capability from architecture and configuration. Actual recovery must be validated through drills.

## Question 4: What is a resilience score?

**Answer:**

It measures how closely an application implements recommended policy compliance, alarms, SOPs and resilience tests.

## Question 5: What is AWS FIS?

**Answer:**

It is a managed fault-injection service for running controlled experiments against AWS resources.

## Question 6: What is a FIS stop condition?

**Answer:**

It is a CloudWatch alarm that stops an experiment when an unacceptable threshold is reached.

## Question 7: What are FIS target-selection modes?

**Answer:**

`ALL`, `COUNT(n)` and `PERCENT(n)`.

## Question 8: What is a target preview?

**Answer:**

It resolves the resources an experiment would target while skipping all fault actions.

## Question 9: What is a steady-state hypothesis?

**Answer:**

It is a measurable statement describing acceptable system behaviour that should remain true while a controlled failure occurs.

## Question 10: What is zonal shift?

**Answer:**

It manually shifts traffic for a supported resource away from one Availability Zone to healthy AZs in the same Region.

## Question 11: What is zonal autoshift?

**Answer:**

It allows AWS to shift supported-resource traffic automatically away from an AZ when AWS detects a qualifying impairment.

## Question 12: What is the main prerequisite for zonal shift?

**Answer:**

The remaining Availability Zones must already have enough capacity to handle the complete expected workload.

## Question 13: What is ARC readiness check?

**Answer:**

It audits whether multi-Region replicas have suitable capacity, quotas, network routing and configuration for recovery.

## Question 14: What is ARC routing control?

**Answer:**

It provides highly available on/off traffic controls integrated with Route 53 health checks and DNS routing records.

## Question 15: Why does an ARC cluster have five endpoints?

**Answer:**

The endpoints provide a highly available recovery data plane, allowing clients to retry another Regional endpoint if one is unavailable.

## Question 16: What is an assertion safety rule?

**Answer:**

It blocks a routing-control update unless a required condition remains true, such as at least one Region staying active.

## Question 17: What is a gating safety rule?

**Answer:**

It uses a separate routing control as a master switch that permits or blocks changes to target routing controls.

## Question 18: What is Region switch?

**Answer:**

It orchestrates multi-step failover, failback, activation or deactivation workflows for active/passive and active/active multi-Region applications.

## Question 19: What is the difference between graceful and ungraceful recovery?

**Answer:**

Graceful recovery coordinates with a healthy source Region, such as draining and synchronizing data. Ungraceful recovery skips or changes source-side steps because the impaired Region cannot participate.

## Question 20: What is the most important chaos-engineering safety practice?

**Answer:**

Use a narrowly scoped blast radius with verified target preview, customer-impact stop conditions and a tested rollback procedure.

---

# 156. Never-forget revision

```text
Resilience:
Ability to withstand and recover from disruption.

Steady state:
Measurable normal application behaviour.

Hypothesis:
Expected behaviour during a defined failure.

Blast radius:
Maximum experiment impact.

Resilience Hub:
Assesses resilience posture.

Resiliency policy:
RTO/RPO goals by disruption type.

AppComponent:
Resources that work and fail together.

Assessment:
Comparison of architecture with resilience goals.

SOP:
Documented or automated recovery procedure.

FIS:
Controlled fault injection.

Target:
Resource affected by an experiment.

Action:
Injected failure or stress.

Stop condition:
CloudWatch alarm that halts an experiment.

Target preview:
Resolves targets without injecting faults.

Zonal shift:
Manual AZ traffic evacuation.

Zonal autoshift:
AWS-initiated AZ traffic evacuation.

Readiness check:
Audits recovery preparedness.

Routing control:
Highly available traffic switch.

Assertion rule:
Ensures a safe state remains true.

Gating rule:
Master switch for routing changes.

Region switch:
Orchestrated multi-Region recovery.

Graceful:
Source Region cooperates.

Ungraceful:
Recovery proceeds without source cooperation.

Game day:
Planned resilience and incident-response exercise.
```

## One-line memory trick

```text
Assess with Resilience Hub.
Break safely with FIS.
Detect with CloudWatch.
Repair with Systems Manager.
Shift zones and Regions with ARC.
Measure whether the business RTO was actually met.
```

## Lesson 60 outcome

You can now design resilience where:

```text
An architecture changes
    → Resilience Hub detects recovery drift.

One application replica fails
    → FIS proves load balancing and replacement work.

Customer impact exceeds limits
    → A CloudWatch stop condition halts the experiment.

One Availability Zone is impaired
    → Zonal shift moves traffic away.

AWS detects an AZ impairment
    → Zonal autoshift can evacuate supported traffic.

A standby Region lacks capacity
    → Readiness checks report the gap before disaster.

A Regional outage occurs
    → Region switch executes the recovery workflow.

Automation tries to disable both Regions
    → An assertion rule blocks the unsafe state.

Failover requires human approval
    → A manual approval block pauses the plan.

A drill completes
    → Measured detection and recovery times prove whether the RTO is real.
```

**Next lesson: Lesson 61 — AWS cost architecture and FinOps: Cost Explorer, CUR/Data Exports, Budgets, Cost Anomaly Detection, Savings Plans, Reserved Instances, Spot, Compute Optimizer, Trusted Advisor, tagging, unit economics and production cost governance.**

[1]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/what-is.html?utm_source=chatgpt.com "AWS Resilience Hub"
[2]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/concepts-terms.html?utm_source=chatgpt.com "AWS Resilience Hub concepts"
[3]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/how-app-manage.html?utm_source=chatgpt.com "Select how this application is managed"
[4]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/AppComponent.html?utm_source=chatgpt.com "Managing Application Components - AWS Resilience Hub"
[5]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/resil-assessments.html?utm_source=chatgpt.com "Running and managing resiliency assessments in AWS ..."
[6]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/resil-recs.html?utm_source=chatgpt.com "Reviewing resiliency recommendations"
[7]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/cfn-integration.html?utm_source=chatgpt.com "Modifying the CloudFormation template"
[8]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/create-alarm.html?utm_source=chatgpt.com "Creating alarms from the operational recommendations"
[9]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/sops.html?utm_source=chatgpt.com "Managing standard operating procedures"
[10]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/resil-score.html?utm_source=chatgpt.com "Understanding resiliency scores - AWS Resilience Hub"
[11]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/scheduled-assessment.html?utm_source=chatgpt.com "Setup scheduled assessments and drift notification"
[12]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/next-gen-eventbridge-create-rule.html?utm_source=chatgpt.com "Creating an EventBridge rule for events from the next ..."
[13]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/next-gen-assessment-pricing.html?utm_source=chatgpt.com "Pricing - AWS Resilience Hub"
[14]: https://docs.aws.amazon.com/fis/latest/userguide/what-is.html?utm_source=chatgpt.com "What is AWS Fault Injection Service?"
[15]: https://docs.aws.amazon.com/fis/latest/userguide/targets.html?utm_source=chatgpt.com "Targets for AWS FIS - AWS Fault Injection Service"
[16]: https://docs.aws.amazon.com/fis/latest/userguide/experiment-options.html?utm_source=chatgpt.com "Experiment options for AWS FIS - AWS Fault Injection Service"
[17]: https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html?utm_source=chatgpt.com "AWS FIS Actions reference - AWS Fault Injection Service"
[18]: https://docs.aws.amazon.com/fis/latest/userguide/action-sequence.html?utm_source=chatgpt.com "Actions for AWS FIS - AWS Fault Injection Service"
[19]: https://docs.aws.amazon.com/fis/latest/userguide/fis-tutorial-stop-instances.html?utm_source=chatgpt.com "Tutorial: Test instance stop and start using AWS FIS"
[20]: https://docs.aws.amazon.com/fis/latest/userguide/az-availability-scenario.html?utm_source=chatgpt.com "AZ Availability: Power Interruption"
[21]: https://docs.aws.amazon.com/fis/latest/userguide/scenario-library-scenarios.html?utm_source=chatgpt.com "Scenarios reference - AWS Fault Injection Service"
[22]: https://docs.aws.amazon.com/fis/latest/userguide/stop-conditions.html?utm_source=chatgpt.com "Stop conditions for AWS FIS - AWS Fault Injection Service"
[23]: https://docs.aws.amazon.com/fis/latest/userguide/getting-started-iam-service-role.html?utm_source=chatgpt.com "IAM roles for AWS FIS experiments"
[24]: https://docs.aws.amazon.com/fis/latest/userguide/security_iam_id-based-policy-examples.html?utm_source=chatgpt.com "AWS Fault Injection Service policy examples"
[25]: https://docs.aws.amazon.com/fis/latest/userguide/monitoring-logging.html?utm_source=chatgpt.com "Experiment logging for AWS FIS - AWS Fault Injection Service"
[26]: https://docs.aws.amazon.com/fis/latest/userguide/experiment-report-configuration.html?utm_source=chatgpt.com "Experiment report configurations for AWS FIS"
[27]: https://docs.aws.amazon.com/fis/latest/userguide/multi-account.html?utm_source=chatgpt.com "Working with multi-account experiments for AWS FIS"
[28]: https://docs.aws.amazon.com/fis/latest/userguide/multi-account-prerequisites.html?utm_source=chatgpt.com "Prerequisites for multi-account experiments"
[29]: https://docs.aws.amazon.com/r53recovery/latest/dg/compare-capabilities.html?utm_source=chatgpt.com "Compare multi-AZ and multi-Region recovery capabilities in ARC"
[30]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-shift.html?utm_source=chatgpt.com "Zonal shift in ARC"
[31]: https://docs.aws.amazon.com/r53recovery/latest/dg/r53-recovery-guide.pdf.pdf?utm_source=chatgpt.com "Amazon Application Recovery Controller (ARC)"
[32]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-zonal-autoshift.how-it-works.html?utm_source=chatgpt.com "How zonal autoshift and practice runs work"
[33]: https://docs.aws.amazon.com/r53recovery/latest/dg/testing-zonal-autoshift-fis.html?utm_source=chatgpt.com "Testing zonal autoshift with AWS FIS"
[34]: https://docs.aws.amazon.com/r53recovery/latest/dg/recovery-readiness.html?utm_source=chatgpt.com "Readiness check in ARC - Amazon Application Recovery ..."
[35]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.html?utm_source=chatgpt.com "Routing control in ARC"
[36]: https://docs.aws.amazon.com/r53recovery/latest/dg/route53-arc-best-practices.regional.html?utm_source=chatgpt.com "Best practices for routing control in ARC"
[37]: https://docs.aws.amazon.com/r53recovery/latest/dg/routing-control.safety-rules.html?utm_source=chatgpt.com "Creating safety rules for routing control"
[38]: https://docs.aws.amazon.com/r53recovery/latest/dg/getting-started-cli-routing-config.html?utm_source=chatgpt.com "Set up routing control components"
[39]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch.html?utm_source=chatgpt.com "Region switch in ARC - Amazon Application Recovery Controller ..."
[40]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch-plans.html?utm_source=chatgpt.com "About Region switch - Amazon Application Recovery ..."
[41]: https://docs.aws.amazon.com/r53recovery/latest/dg/components-rs.html?utm_source=chatgpt.com "Region switch components - Amazon Application Recovery ..."
[42]: https://docs.aws.amazon.com/r53recovery/latest/dg/tutorial-region-switch.html?utm_source=chatgpt.com "Tutorial: Create an active/passive Region switch plan"
[43]: https://docs.aws.amazon.com/r53recovery/latest/dg/manual-approval-block.html?utm_source=chatgpt.com "Manual approval execution block"
[44]: https://docs.aws.amazon.com/r53recovery/latest/dg/working-with-rs-create-plan.html?utm_source=chatgpt.com "Create a Region switch plan"
[45]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch-plan-block.html?utm_source=chatgpt.com "ARC Region switch plan execution block"
[46]: https://docs.aws.amazon.com/r53recovery/latest/dg/best-practices.region-switch.html?utm_source=chatgpt.com "Best practices for Region switch in ARC - AWS Documentation"
[47]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fis_experiment_template?utm_source=chatgpt.com "aws_fis_experiment_template | Resources | hashicorp/aws"
[48]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53recoverycontrolconfig_control_panel?utm_source=chatgpt.com "aws_route53recoverycontrolconfi..."
[49]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/arcregionswitch_plan?utm_source=chatgpt.com "aws_arcregionswitch_plan | Resources | hashicorp/aws"
[50]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/modify-application-using-api.html?utm_source=chatgpt.com "Modifying your application - AWS Resilience Hub"
[51]: https://docs.aws.amazon.com/resilience-hub/latest/userguide/exclude-recommend.html?utm_source=chatgpt.com "Including or excluding operational recommendations"
[52]: https://docs.aws.amazon.com/fis/latest/userguide/generate-target-preview.html?utm_source=chatgpt.com "Generate a target preview from an experiment template"
[53]: https://docs.aws.amazon.com/r53recovery/latest/dg/introduction-regions-routing.html?utm_source=chatgpt.com "AWS Region availability for routing control"
