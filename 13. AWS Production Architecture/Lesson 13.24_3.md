# AWS Lesson 24 — Part 4

# EC2 Auto Scaling Advanced Production Operations

Now we move from:

```text
"How do I create an Auto Scaling Group?"
```

to:

```text
"How do I operate an Auto Scaling fleet safely in production?"
```

This part connects many concepts we have already learned:

```text
Auto Scaling
    │
    ├── Mixed Instances
    ├── Spot
    ├── Capacity Rebalancing
    ├── Lifecycle Hooks
    ├── Health Checks
    ├── Instance Refresh
    │
    └── now:
          │
          ├── Spot interruption handling
          ├── Attribute-Based Instance Selection
          ├── Weighted Capacity
          ├── Termination policies
          ├── Scale-in protection
          ├── Instance maintenance policies
          ├── AZ balancing
          ├── Maximum instance lifetime
          ├── Suspended processes
          └── Monitoring/troubleshooting
```

---

# 1. Spot Interruption Handling in Production

In the previous part we learned:

```text
Spot = cheap
       +
       interruptible
```

So the application must assume:

> Any Spot instance may disappear.

Amazon EC2 provides two particularly useful signals:

```text
Rebalance Recommendation
        │
        │ instance is at elevated interruption risk
        ▼
Prepare proactively

Spot Interruption Notice
        │
        │ interruption imminent
        ▼
Final graceful-shutdown window
```

A rebalance recommendation can arrive before the interruption warning. A Spot interruption notice is normally issued about two minutes before EC2 stops or terminates the instance; hibernation behaves differently because hibernation starts immediately. ([AWS Documentation][1])

---

# 2. Detect Spot Interruption Using IMDSv2

Remember Instance Metadata Service?

From inside EC2:

```text
EC2 instance
     │
     ▼
169.254.169.254
     │
     ▼
Instance Metadata Service
```

For production we should use:

```text
IMDSv2
```

First obtain a token:

```bash
TOKEN=$(curl -sS -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
```

Then check for a Spot interruption action:

```bash
curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/spot/instance-action
```

Normally, when there is no interruption pending, that metadata item is absent.

When interruption is scheduled, you may receive something conceptually similar to:

```json
{
  "action": "terminate",
  "time": "2026-08-13T18:30:00Z"
}
```

The possible interruption actions include stop, terminate, or hibernate depending on configuration. AWS recommends polling interruption metadata frequently if your application depends on detecting it locally. ([AWS Documentation][1])

---

# 3. Detect Rebalance Recommendation

There is another metadata endpoint:

```text
/latest/meta-data/events/recommendations/rebalance
```

Example:

```bash
curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/events/recommendations/rebalance
```

If a rebalance recommendation exists, metadata can contain a notification time. ([AWS Documentation][2])

The important distinction is:

```text
Rebalance Recommendation
        │
        ▼
"The instance has elevated interruption risk."

Interruption Notice
        │
        ▼
"The interruption is now imminent."
```

Therefore:

```text
Rebalance
    ↓
start draining early

Interruption notice
    ↓
finish quickly
```

---

# 4. Production Interruption Handler

Imagine your EC2 instance processes jobs from SQS.

Bad architecture:

```text
SQS
 │
 ▼
Spot EC2
 │
 ├── receives job
 ├── spends 30 minutes processing
 │
 └── instance disappears
```

Better architecture:

```text
                     SQS
                      │
                      ▼
                  Spot Worker
                      │
               ┌──────┴──────┐
               │             │
            Normal      Rebalance
             work          signal
                            │
                            ▼
                    Stop accepting
                      new messages
                            │
                            ▼
                    Finish/checkpoint
                     current work
                            │
                            ▼
                       Terminate
```

Spot workloads should therefore be designed around fault tolerance, restartability, checkpointing, and externally stored state rather than assuming instance permanence. ([AWS Documentation][3])

---

# 5. Example Spot Watcher Script

A simplified educational example:

```bash
#!/usr/bin/env bash

set -Eeuo pipefail

METADATA="http://169.254.169.254/latest"

TOKEN=$(curl -fsS -X PUT \
  "$METADATA/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

HEADER="X-aws-ec2-metadata-token: $TOKEN"

while true; do

  REBALANCE=$(curl -fsS \
    -H "$HEADER" \
    "$METADATA/meta-data/events/recommendations/rebalance" \
    2>/dev/null || true)

  INTERRUPTION=$(curl -fsS \
    -H "$HEADER" \
    "$METADATA/meta-data/spot/instance-action" \
    2>/dev/null || true)

  if [[ -n "$REBALANCE" ]]; then
    echo "Rebalance recommendation detected"

    # Example:
    # systemctl stop worker
    # finish/checkpoint current task
    # stop consuming new messages
  fi

  if [[ -n "$INTERRUPTION" ]]; then
    echo "Spot interruption detected: $INTERRUPTION"

    # Perform only fast shutdown operations here.
    # flush logs
    # checkpoint work
    # deregister
    # stop accepting new work

    exit 0
  fi

  sleep 5
done
```

AWS documents both metadata-based detection and EventBridge-based interruption handling, so applications do not have to rely solely on local polling. ([AWS Documentation][1])

---

# 6. Capacity Rebalancing + Spot Signals

Now combine what we've learned.

```text
EC2 notices risk
       │
       ▼
Rebalance Recommendation
       │
       ├─────────────────────────┐
       │                         │
       ▼                         ▼
Application starts          Auto Scaling
draining work              Capacity Rebalance
                                 │
                                 ▼
                         Launch replacement
                                 │
                                 ▼
                        New capacity ready
                                 │
                                 ▼
                          Old instance gone
```

With Capacity Rebalancing enabled, EC2 Auto Scaling can proactively request replacement Spot capacity after a rebalance recommendation instead of waiting for the existing instance to be interrupted. ([AWS Documentation][4])

Terraform:

```hcl
resource "aws_autoscaling_group" "app" {

  name = "prod-app-asg"

  capacity_rebalance = true

  # ...
}
```

### Never forget

```text
Spot notice
=
application-level reaction

Capacity Rebalancing
=
fleet-level reaction
```

You often want **both**.

---

# 7. Attribute-Based Instance Type Selection

Previously we manually configured:

```text
m6i.large
m6a.large
m7i.large
m7a.large
m5.large
m5a.large
```

But AWS has a more advanced approach:

# Attribute-Based Instance Type Selection

Instead of saying:

> Give me `m6i.large`.

you say:

> Give me an instance satisfying these compute requirements.

Example:

```text
vCPU:
2–4

Memory:
4–16 GiB

Generation:
current

CPU architecture:
x86

Burstable:
allowed/excluded

Local storage:
not required
```

Then Auto Scaling determines which matching instance types can participate in the fleet. AWS also supports performance protection, where a baseline instance family can be used to filter out types that fall below a CPU-performance baseline. ([AWS Documentation][5])

---

# 8. Why Attribute-Based Selection Matters

Imagine AWS introduces:

```text
m8i.large
```

in the future.

Manual configuration:

```text
m6i.large
m7i.large
```

doesn't automatically know:

```text
m8i.large exists
```

Attribute-based configuration says:

```text
I care about:

2–4 vCPUs
8–16 GiB RAM
acceptable CPU architecture
acceptable generation
```

AWS can choose matching instance types.

Mental model:

```text
Manual selection:

"I want these server names."


Attribute selection:

"I want these server capabilities."
```

That's a more cloud-native abstraction. AWS explicitly supports attribute-based selection for mixed-instance Auto Scaling groups. ([AWS Documentation][5])

---

# 9. Example Terraform Attribute Requirements

Conceptually:

```hcl
mixed_instances_policy {

  launch_template {
    launch_template_specification {
      launch_template_id = aws_launch_template.app.id
      version            = aws_launch_template.app.latest_version
    }

    override {
      instance_requirements {

        vcpu_count {
          min = 2
          max = 4
        }

        memory_mib {
          min = 4096
          max = 16384
        }

        cpu_manufacturers = [
          "intel",
          "amd"
        ]

        instance_generations = [
          "current"
        ]

        bare_metal = "excluded"
      }
    }
  }
}
```

Current provider capabilities include requirements around vCPU count, memory, CPU manufacturer, instance generations, local storage, accelerators, network bandwidth and several other hardware attributes. ([Terraform Registry][6])

---

# 10. Manual Instance Types vs Attribute-Based Selection

| Manual selection              | Attribute-based selection       |
| ----------------------------- | ------------------------------- |
| `m6i.large`                   | 2–4 vCPU                        |
| `m6a.large`                   | 4–16 GiB RAM                    |
| `m7i.large`                   | Current generation              |
| You maintain list             | AWS derives matching types      |
| More explicit                 | More flexible                   |
| Easy to reason about          | Better capacity diversification |
| Good for strict compatibility | Strong for flexible fleets      |

### Which should you use?

If software licensing or performance certification says:

```text
ONLY c7i.2xlarge
```

manual selection may be appropriate.

If workload says:

```text
Any modern x86 VM
with approximately these resources
```

attribute-based selection can significantly broaden the capacity pool.

---

# 11. Weighted Capacity

Now we get to another concept people often misunderstand.

Suppose your ASG allows:

```text
c5.large
c5.xlarge
c5.2xlarge
```

These don't provide the same compute power.

Without weighting:

```text
c5.large    = 1 instance
c5.xlarge   = 1 instance
c5.2xlarge  = 1 instance
```

Auto Scaling thinks in instance count.

But what if we want:

```text
c5.large    = 1 capacity unit
c5.xlarge   = 2 capacity units
c5.2xlarge  = 4 capacity units
```

That's **weighted capacity**.

AWS lets each instance type contribute multiple units toward the group's desired capacity. ([AWS Documentation][7])

---

# 12. Desired Capacity Changes Meaning

Without weights:

```text
desired_capacity = 8
```

means:

```text
8 instances
```

With weights:

```text
desired_capacity = 8
```

means:

```text
8 capacity units
```

For example:

```text
2 × c5.2xlarge

Weight each = 4

2 × 4 = 8 capacity units
```

or:

```text
4 × c5.xlarge

Weight each = 2

4 × 2 = 8
```

or:

```text
8 × c5.large

Weight each = 1

8 × 1 = 8
```

All provide:

```text
Desired capacity = 8 units
```

AWS explicitly distinguishes instance-count-based capacity from capacity-unit-based groups. ([AWS Documentation][7])

---

# 13. Terraform Weighted Capacity

Example:

```hcl
mixed_instances_policy {

  launch_template {

    launch_template_specification {
      launch_template_id = aws_launch_template.app.id
      version            = aws_launch_template.app.latest_version
    }

    override {
      instance_type     = "c5.large"
      weighted_capacity = "1"
    }

    override {
      instance_type     = "c5.xlarge"
      weighted_capacity = "2"
    }

    override {
      instance_type     = "c5.2xlarge"
      weighted_capacity = "4"
    }
  }
}
```

If you specify weights manually, AWS requires consistent weighting across the instance types in the group, and large gaps between weights can make capacity fulfillment inefficient. AWS currently recommends attribute-based instance selection when you want capacity expressed naturally in vCPU or memory units. ([AWS Documentation][7])

---

# 14. Important Weighted Capacity Trap

Suppose:

```text
Desired = 10 units

Current = 8 units

Remaining = 2
```

Available instance:

```text
weight = 4
```

AWS may launch it.

Then:

```text
Current = 12
Desired = 10
```

So you may temporarily be above desired capacity.

This is expected behavior.

AWS prioritizes Availability Zone distribution and the fleet's allocation strategy rather than requiring an exact capacity-unit match. With weighting, capacity can exceed desired capacity and, in some circumstances, MaxSize by up to the largest configured weight. ([AWS Documentation][7])

### Never forget

```text
Weighted fleet:

Desired capacity
≠ necessarily exact instance count
```

---

# 15. Termination Policies

Scale-out is only half of Auto Scaling.

Eventually:

```text
Traffic decreases
       ↓
Scale in
       ↓
Which EC2 should be terminated?
```

That is where **termination policies** matter.

AWS first considers maintaining Availability Zone balance and then applies termination-policy logic to determine which instance should be removed. The default policy is designed in part to remove instances using outdated configurations. ([AWS Documentation][8])

---

# 16. Example Scale-In

Suppose:

```text
AZ-a

i-001 LT v5
i-002 LT v6
i-003 LT v6

AZ-b

i-004 LT v6
i-005 LT v6
i-006 LT v6
```

Desired capacity changes:

```text
6 → 5
```

AWS doesn't simply do:

```text
terminate random instance
```

Availability Zone balance is considered first, and then the configured termination policy is applied. ([AWS Documentation][8])

This becomes important during:

```text
AMI migration
Launch Template upgrades
Spot/On-Demand transitions
AZ imbalances
instance-generation migrations
```

---

# 17. Scale-In Protection

Imagine an ASG contains:

```text
Instance A → web worker
Instance B → processing an important 45-minute job
Instance C → web worker
```

Traffic falls.

ASG decides:

```text
3 → 2
```

You don't want:

```text
Instance B terminated halfway through job
```

Use:

# Instance Scale-In Protection

Protection tells Auto Scaling:

```text
Do not choose this instance
for normal scale-in termination.
```

Scale-in protection is disabled by default unless configured otherwise, and you can enable or remove it for particular instances. ([AWS Documentation][9])

---

# 18. Enable Scale-In Protection

```bash
aws autoscaling set-instance-protection \
  --instance-ids i-0123456789abcdef0 \
  --auto-scaling-group-name prod-worker-asg \
  --protected-from-scale-in
```

Check:

```bash
aws autoscaling describe-auto-scaling-instances \
  --instance-ids i-0123456789abcdef0 \
  --query 'AutoScalingInstances[0].ProtectedFromScaleIn'
```

After the job finishes:

```bash
aws autoscaling set-instance-protection \
  --instance-ids i-0123456789abcdef0 \
  --auto-scaling-group-name prod-worker-asg \
  --no-protected-from-scale-in
```

---

# 19. Correct Worker Pattern

```text
Worker starts job
      │
      ▼
Enable scale-in protection
      │
      ▼
Process job
      │
      ▼
Commit result
      │
      ▼
Disable scale-in protection
```

Pseudo workflow:

```bash
protect_instance

process_job

save_result

unprotect_instance
```

This pattern is useful for workloads that must finish bounded work before becoming eligible for ordinary scale-in. ([AWS Documentation][9])

But don't leave every instance protected forever.

Otherwise:

```text
ASG wants 10 → 5

All 10 protected

↓
Scale-in cannot proceed normally

↓
unnecessary cost
```

---

# 20. Instance Maintenance Policy

This is a more advanced fleet-level availability control.

Suppose an unhealthy instance needs replacement.

Without careful maintenance behavior:

```text
Desired capacity = 2

Instance 1 healthy
Instance 2 unhealthy

terminate unhealthy
      ↓
only 1 useful instance
      ↓
launch replacement
```

Production might prefer:

```text
launch replacement first
      ↓
wait until healthy
      ↓
terminate impaired instance
```

An **instance maintenance policy** lets an ASG use minimum and maximum healthy percentages to control capacity while instances are being replaced by supported replacement events. ([AWS Documentation][10])

---

# 21. Example Maintenance Policy

Conceptually:

```text
Desired = 4

Minimum healthy = 100%
Maximum healthy = 125%
```

Then:

```text
Normal:

4 instances


During replacement:

4 old/current
+
1 replacement

=
5

5 / 4 = 125%
```

Once replacement is ready:

```text
terminate old instance

5 → 4
```

This produces:

```text
Launch before terminate
```

instead of:

```text
Terminate before launch
```

for applicable replacement workflows. ([AWS Documentation][11])

Terraform currently supports an `instance_maintenance_policy` block with minimum and maximum healthy percentage controls. ([Terraform Registry][6])

Conceptually:

```hcl
instance_maintenance_policy {
  min_healthy_percentage = 100
  max_healthy_percentage = 125
}
```

---

# 22. Instance Maintenance Policy vs Instance Refresh

Don't confuse them.

### Instance Refresh

```text
"I intentionally want to replace the fleet."
```

Example:

```text
AMI v12 → AMI v13
```

### Instance Maintenance Policy

```text
"When replacement happens,
how much healthy capacity
must be maintained?"
```

Conceptually:

```text
Instance Refresh
       │
       └── WHY / WHEN fleet replacement happens


Maintenance Policy
       │
       └── CAPACITY RULES while replacement occurs
```

AWS applies maintenance-policy controls to multiple replacement scenarios, including health-related replacement and instance refresh behavior. ([AWS Documentation][10])

---

# 23. Availability Zone Balancing

Suppose:

```text
ASG desired = 6

AZ-a = 2
AZ-b = 2
AZ-c = 2
```

Perfect:

```text
2 | 2 | 2
```

Now AZ-c temporarily becomes unavailable:

```text
AZ-a = 3
AZ-b = 3
AZ-c = 0
```

When capacity becomes available again, Auto Scaling can rebalance across Availability Zones. AWS normally attempts to maintain equivalent numbers of instances across enabled AZs. ([AWS Documentation][12])

Conceptually:

```text
Before recovery

AZ-a    AZ-b    AZ-c
 ███     ███


After recovery

AZ-a    AZ-b    AZ-c
 ██      ██      ██
```

---

# 24. Newer AZ Distribution Controls

Current EC2 Auto Scaling documentation describes Availability Zone distribution strategies including **balanced best effort** and **balanced only**. Balanced best effort can place capacity in another healthy AZ when launches fail in one AZ, while balanced only continues trying to maintain strict balance. ([AWS Documentation][13])

Think of the difference like this:

```text
Balanced best effort

"I prefer AZ balance,
but serving the workload is more important."
```

versus:

```text
Balanced only

"I require the fleet
to remain evenly distributed."
```

For many stateless web workloads:

```text
availability > perfect symmetry
```

so a best-effort balancing strategy is often easier to operate.

For some quorum-sensitive or tightly constrained architectures, strict distribution can matter more.

---

# 25. AZRebalance Process

Internally Auto Scaling has a process called:

```text
AZRebalance
```

It helps redistribute instances when the group becomes unbalanced.

AWS's documented processes include:

```text
Launch
Terminate
AddToLoadBalancer
AlarmNotification
AZRebalance
HealthCheck
InstanceRefresh
ReplaceUnhealthy
ScheduledActions
```

among the processes you may encounter or suspend depending on the operation. ([AWS Documentation][14])

---

# 26. Suspend Auto Scaling Processes

This is a dangerous but important troubleshooting tool.

Imagine Auto Scaling continuously replaces an instance while you're debugging.

```text
instance starts
    ↓
you SSH / SSM in
    ↓
ASG considers it unhealthy
    ↓
instance terminated
```

You're trying to debug:

```text
"Stop killing my instance!"
```

Temporarily you may suspend a process such as:

```text
ReplaceUnhealthy
```

AWS explicitly documents process suspension as a troubleshooting mechanism, but suspending processes changes normal fleet behavior and should therefore be temporary and deliberate. ([AWS Documentation][14])

---

# 27. See Suspended Processes

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names prod-web-asg \
  --query 'AutoScalingGroups[0].SuspendedProcesses'
```

Suspend:

```bash
aws autoscaling suspend-processes \
  --auto-scaling-group-name prod-web-asg \
  --scaling-processes ReplaceUnhealthy
```

Resume:

```bash
aws autoscaling resume-processes \
  --auto-scaling-group-name prod-web-asg \
  --scaling-processes ReplaceUnhealthy
```

---

# 28. Dangerous Example

Suppose you suspend:

```text
Launch
```

Desired capacity:

```text
10
```

Current:

```text
7
```

Auto Scaling may know:

```text
I need 3 more instances
```

but you've suspended the process responsible for launching them.

That can turn an operational troubleshooting action into an outage.

### Never forget

```text
Suspend process
=
temporarily disable part
of Auto Scaling's brain.
```

Always:

```text
1. Know why you're suspending.
2. Record what you suspended.
3. Troubleshoot.
4. Resume it.
5. Verify desired/current capacity.
```

---

# 29. Maximum Instance Lifetime

Another production control:

```text
max_instance_lifetime
```

Example:

```text
Maximum instance lifetime = 7 days
```

Once an instance exceeds that age, Auto Scaling can replace it. AWS defines this as the maximum time an ASG instance may remain in service before replacement. ([AWS Documentation][15])

Why?

Imagine servers accumulate:

```text
temporary files
stale caches
manual changes
old processes
configuration drift
old certificates
old runtime state
```

Replacing them periodically encourages:

```text
Disposable Infrastructure
```

rather than:

```text
"That EC2 has been alive
for 843 days.
Nobody knows what's installed."
```

---

# 30. Immutable Infrastructure Connection

Old-school mindset:

```text
Server
  ↓
patch
  ↓
patch again
  ↓
SSH
  ↓
manual fix
  ↓
another manual fix
  ↓
mystery server
```

Immutable pattern:

```text
Build new AMI
     ↓
Launch new EC2
     ↓
Validate
     ↓
Replace old EC2
```

Maximum instance lifetime can complement this operational philosophy by preventing instances from living indefinitely. AWS cites security and compliance replacement requirements as one use case. ([AWS Documentation][15])

Terraform:

```hcl
resource "aws_autoscaling_group" "app" {

  # ...

  max_instance_lifetime = 604800
}
```

Where:

```text
604800 seconds
=
7 days
```

---

# 31. Auto Scaling Monitoring

A production ASG should not be a black box.

We need visibility into:

```text
What ASG wants
vs
What ASG has
```

Important metrics include concepts such as:

```text
GroupDesiredCapacity

GroupInServiceInstances

GroupPendingInstances

GroupTerminatingInstances

GroupStandbyInstances

GroupTotalInstances
```

When ASG group metrics are enabled, EC2 Auto Scaling publishes them to CloudWatch at one-minute granularity on a best-effort basis. ([AWS Documentation][16])

Enable them:

```bash
aws autoscaling enable-metrics-collection \
  --auto-scaling-group-name prod-web-asg \
  --granularity 1Minute
```

---

# 32. The Most Important Operational Comparison

Imagine CloudWatch shows:

```text
GroupDesiredCapacity = 10

GroupInServiceInstances = 6

GroupPendingInstances = 4
```

That may simply mean:

```text
Scale-out is in progress.
```

But:

```text
Desired = 10

InService = 6

Pending = 0
```

for an extended period should immediately make you investigate.

Possible reasons:

```text
EC2 capacity problem
IAM permission
launch template problem
AMI unavailable
subnet exhausted
EC2 quota
security configuration
Spot capacity
lifecycle hook
suspended Launch process
```

---

# 33. Weighted Fleet Monitoring

Remember capacity weights?

Normal metrics may refer to instances.

Weighted fleets can also expose capacity-unit metrics such as:

```text
GroupInServiceCapacity
GroupPendingCapacity
GroupStandbyCapacity
GroupTerminatingCapacity
GroupTotalCapacity
```

These are useful because:

```text
3 instances
```

might actually represent:

```text
12 capacity units
```

depending on their weights. ([AWS Documentation][17])

---

# 34. Production ASG Troubleshooting Method

Suppose application traffic is increasing.

CloudWatch says:

```text
CPU = 90%
```

but no additional instances appear.

Don't immediately modify the scaling policy.

Follow layers.

---

## Layer 1 — Scaling Decision

Check:

```text
Did CloudWatch alarm trigger?

Did target tracking calculate scale-out?

Is scaling policy attached?

Is AlarmNotification suspended?
```

---

## Layer 2 — Desired Capacity

Check:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names prod-web-asg \
  --query 'AutoScalingGroups[0].{
     Min:MinSize,
     Desired:DesiredCapacity,
     Max:MaxSize
  }'
```

Suppose:

```json
{
  "Min": 2,
  "Desired": 10,
  "Max": 10
}
```

Traffic still rising?

Then:

```text
ASG has reached MaxSize.
```

Scaling policy can yell:

```text
MORE SERVERS!
```

but:

```text
MaxSize = 10
```

says:

```text
No.
```

---

# 35. Layer 3 — Scaling Activity

This is one of the first commands I want you to remember in real troubleshooting:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name prod-web-asg \
  --max-items 20 \
  --output table
```

This often tells you:

```text
what ASG attempted
why it attempted it
whether it succeeded
why it failed
```

Example symptoms:

```text
Launching EC2 instance failed
```

Then your investigation moves from:

```text
Auto Scaling policy problem
```

to:

```text
EC2 launch problem
```

That distinction is critical.

---

# 36. Layer 4 — Launch Template

Validate:

```bash
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-0123456789abcdef0 \
  --versions '$Default'
```

Check:

```text
AMI ID
Instance type
IAM profile
security group
user data
key
metadata options
block device mappings
```

---

# 37. Layer 5 — Networking

Instance may launch but never become usable.

Check:

```text
Subnet has available IP?
        │
        ├── no → launch/networking problem
        │
        ▼
Route table correct?
        │
        ▼
NAT available for private bootstrap?
        │
        ▼
SG allows ALB → EC2?
        │
        ▼
App listening on correct port?
```

Remember our architecture:

```text
Internet
   │
   ▼
ALB
   │
   │ SG: ALB-SG
   ▼
EC2
SG rule:

Source:
ALB-SG

Port:
application port
```

Not:

```text
0.0.0.0/0 : 3000
```

unless there is a genuine requirement.

---

# 38. Layer 6 — Health Checks

Suppose EC2 keeps cycling:

```text
Launch
 ↓
2 minutes
 ↓
Terminate
 ↓
Launch
 ↓
Terminate
```

This is a classic sign to investigate:

```text
Health check
```

Check:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN"
```

Possible states:

```text
initial
healthy
unhealthy
draining
unused
```

Auto Scaling can use ELB health information when configured, allowing unhealthy `InService` instances to be replaced while maintaining desired capacity. ([AWS Documentation][18])

---

# 39. The Golden Troubleshooting Chain

Memorize this:

```text
Metric high
   ↓
Scaling policy triggered?
   ↓
Desired capacity changed?
   ↓
Below MaxSize?
   ↓
Scaling activity started?
   ↓
EC2 launch succeeded?
   ↓
Lifecycle hook completed?
   ↓
Instance entered InService?
   ↓
Target registered?
   ↓
ALB health check passed?
   ↓
Application serving traffic?
```

If you follow this sequence, many ASG incidents become much easier to isolate.

---

# 40. Production Architecture After Lesson 24

Look how far we've come.

```text
                              Route 53
                                  │
                                  ▼
                             CloudFront
                                  │
                                  ▼
                              AWS WAF
                                  │
                                  ▼
                                  ALB
                       ┌──────────┼──────────┐
                       │          │          │
                       ▼          ▼          ▼
                     AZ-A       AZ-B       AZ-C
                       │          │          │
                    EC2/Spot   EC2/OD    EC2/Spot
                       │          │          │
                       └──────────┼──────────┘
                                  │
                         Auto Scaling Group
                                  │
          ┌───────────────────────┼─────────────────────┐
          │                       │                     │
          ▼                       ▼                     ▼
   Mixed Instances          Instance Refresh       Health Checks
          │                       │                     │
          ▼                       ▼                     ▼
 Attribute-Based          Maintenance Policy        ALB / EC2
    Selection
          │
          ▼
 On-Demand + Spot
          │
          ▼
Capacity Rebalancing
          │
          ▼
Lifecycle Hooks
          │
          ▼
Scale-In Protection
          │
          ▼
CloudWatch Monitoring
```

This is now a **production fleet**, not merely some EC2 instances.

---

# 41. SAA-C03 / DOP-C02 Scenarios

### Scenario 1

A stateless application requires large scale and management wants to reduce EC2 costs.

Best direction:

```text
Multi-AZ ASG
+
On-Demand baseline
+
Spot elastic capacity
+
multiple instance types
+
price-capacity-optimized
+
Capacity Rebalancing
```

---

### Scenario 2

Spot workers perform long-running jobs.

Requirement:

```text
Do not terminate workers
while actively processing jobs.
```

Think:

```text
Scale-in protection
+
graceful job/checkpoint design
+
Spot interruption handling
+
Capacity Rebalancing
```

---

### Scenario 3

Company says:

> Every EC2 instance must be replaced at least once every seven days.

Think:

```text
Maximum instance lifetime
```

---

### Scenario 4

Company doesn't care about exact instance families.

Requirement:

```text
2–4 vCPU
8–16 GB RAM
modern processor
```

Think:

```text
Attribute-Based Instance Type Selection
```

---

### Scenario 5

Different EC2 sizes provide different compute capacity.

Think:

```text
Weighted Capacity
```

or, particularly for vCPU/memory-based fulfillment:

```text
Attribute-Based Instance Type Selection
+
desired capacity type
```

AWS specifically recommends attribute-based selection when desired capacity should naturally represent vCPU or memory. ([AWS Documentation][7])

---

### Scenario 6

Unhealthy server must be replaced but application cannot tolerate capacity dropping below 100%.

Think:

```text
Instance Maintenance Policy

MinHealthy = 100%
MaxHealthy > 100%
```

---

### Scenario 7

Auto Scaling mysteriously stopped replacing unhealthy instances.

Think:

```text
Check SuspendedProcesses

especially:

ReplaceUnhealthy
Launch
HealthCheck
```

---

# 42. Never-Forget Map

```text
                    AUTO SCALING
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
      SCALE            REPLACE          PROTECT
        │                │                 │
        ▼                ▼                 ▼
 Scaling policy     Instance Refresh   Scale-in protection
 Target tracking    Health replacement
 Step scaling       Max lifetime
 Predictive          Maintenance policy
        │
        ▼
     CAPACITY
        │
        ├── On-Demand
        ├── Spot
        ├── Mixed Instances
        ├── Attribute-based selection
        └── Weighted capacity
                  │
                  ▼
              RESILIENCE
                  │
             Multi-AZ
                  │
          Capacity Rebalance
                  │
           Lifecycle hooks
                  │
                  ▼
              OPERATIONS
                  │
             CloudWatch
                  │
          Scaling activities
                  │
          Health-check tracing
```

---

# 43. Six Lines to Permanently Remember

```text
Target Tracking
=
How much capacity do I need?
```

```text
Mixed Instances
=
What types of capacity can satisfy it?
```

```text
Attribute-Based Selection
=
Tell AWS the required hardware capability,
not necessarily exact instance names.
```

```text
Weighted Capacity
=
Different instance sizes count
as different amounts of capacity.
```

```text
Capacity Rebalancing
=
Replace risky Spot capacity proactively.
```

```text
Instance Maintenance Policy
=
Control healthy-capacity boundaries
while replacement occurs.
```

And one DevOps principle:

> **If Auto Scaling is failing, find the exact layer where desired state stops becoming actual state.**

That means:

```text
Alarm
  ↓
Policy
  ↓
Desired
  ↓
Launch
  ↓
EC2
  ↓
Bootstrap
  ↓
Lifecycle
  ↓
Target Group
  ↓
Health
  ↓
Traffic
```

---

# Lesson 24 — Where We Are Now

We have now covered the core theory and advanced production behavior of EC2 Auto Scaling:

```text
✓ ASG fundamentals
✓ Min / Desired / Max
✓ Launch Templates
✓ Multi-AZ placement
✓ Health checks
✓ Scaling policies
✓ Target tracking
✓ Step scaling
✓ Scheduled scaling
✓ Predictive concepts
✓ Cooldowns / warm-up
✓ Instance Refresh
✓ Rolling deployment
✓ Checkpoints
✓ Bake time
✓ Auto rollback
✓ Lifecycle Hooks
✓ Warm Pools
✓ Mixed Instances
✓ On-Demand + Spot
✓ Spot allocation strategies
✓ Capacity Rebalancing
✓ Spot interruption handling
✓ Attribute-Based Instance Selection
✓ Weighted Capacity
✓ Termination policies
✓ Scale-in protection
✓ Instance Maintenance Policies
✓ AZ balancing
✓ Maximum instance lifetime
✓ Suspended processes
✓ CloudWatch ASG metrics
✓ Production troubleshooting
```

## Next: Lesson 24 — Final Hands-On Production Lab

Next we will **stop adding theory temporarily and build this ourselves**:

```text
                         Internet
                            │
                            ▼
                           ALB
                            │
                  ┌─────────┴─────────┐
                  │                   │
             Private AZ-A        Private AZ-B
                  │                   │
                  ▼                   ▼
              EC2 instances       EC2 instances
                  └─────────┬─────────┘
                            │
                    Auto Scaling Group
                            │
                 Mixed Instances Policy
                            │
                   On-Demand + Spot
                            │
                  Target Tracking Policy
                            │
                   Capacity Rebalance
                            │
                    Instance Refresh
                            │
                      CloudWatch
```

We’ll build it in **`ap-south-1`**, first understanding every resource, then Terraform, AWS CLI validation, forced scaling test, health-check failure simulation, Instance Refresh deployment, Spot/rebalance discussion, monitoring, troubleshooting, **cleanup to avoid charges**, and finally the resume/interview explanation.

After that lab, **Lesson 24 will be properly closed**, and we move to the next AWS lesson in our original masterclass flow.

[1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html?utm_source=chatgpt.com "Spot Instance interruption notices"
[2]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html?utm_source=chatgpt.com "Use instance metadata to manage your EC2 ..."
[3]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-interruptions.html?utm_source=chatgpt.com "Spot Instance interruptions - Amazon Elastic Compute Cloud"
[4]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-capacity-rebalancing.html?utm_source=chatgpt.com "Capacity Rebalancing in Auto Scaling to replace at-risk ..."
[5]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/create-mixed-instances-group-attribute-based-instance-type-selection.html?utm_source=chatgpt.com "Create mixed instances group using attribute-based instance ..."
[6]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group?utm_source=chatgpt.com "aws_autoscaling_group | Resources | hashicorp/aws | Terraform"
[7]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-mixed-instances-groups-instance-weighting.html?utm_source=chatgpt.com "Configure an Auto Scaling group to use instance weights"
[8]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-termination-policies.html?utm_source=chatgpt.com "Configure termination policies for Amazon EC2 Auto Scaling"
[9]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-instance-protection.html?utm_source=chatgpt.com "Use instance scale-in protection to control instance termination"
[10]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-maintenance-policy-overview-and-considerations.html?utm_source=chatgpt.com "Instance maintenance policy for Auto Scaling group"
[11]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-instance-maintenance-policy.html?utm_source=chatgpt.com "Instance maintenance policies - Amazon EC2 Auto Scaling"
[12]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-benefits.html?utm_source=chatgpt.com "Auto Scaling benefits for application architecture"
[13]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-availability-zone-balanced.html?utm_source=chatgpt.com "Auto Scaling group Availability Zone distribution"
[14]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-suspend-resume-processes.html?utm_source=chatgpt.com "Suspend and resume Amazon EC2 Auto Scaling processes"
[15]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-max-instance-lifetime.html?utm_source=chatgpt.com "Replace Auto Scaling instances based on maximum instance ..."
[16]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-metrics.html?utm_source=chatgpt.com "Amazon CloudWatch metrics for Amazon EC2 Auto Scaling"
[17]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/viewing-monitoring-graphs.html?utm_source=chatgpt.com "View monitoring graphs in the Amazon EC2 Auto Scaling ..."
[18]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-health-checks.html?utm_source=chatgpt.com "Health checks for instances in an Auto Scaling group"
