Yes — **I remember our flow**, and I’ll keep following it. We are not treating AWS as isolated services or just preparing for certification questions.

Our approach is:

| Layer               | How we are learning                                                     |
| ------------------- | ----------------------------------------------------------------------- |
| **Beginner**        | What is it? Why does it exist? Terminology and mental model             |
| **Intermediate**    | Configuration, networking, permissions, integrations                    |
| **Advanced**        | HA, scaling, resilience, security, performance, cost                    |
| **Production**      | How companies actually architect and operate it                         |
| **Troubleshooting** | Symptoms → investigation → root cause → fix                             |
| **Hands-on**        | Console → AWS CLI → Terraform                                           |
| **Architecture**    | How the service connects with VPC, ALB, Route 53, CloudFront, IAM, etc. |
| **Certification**   | CLF-C02 → SAA-C03 → DOP-C02 concepts                                    |
| **Interview**       | Scenario-based questions rather than memorized definitions              |
| **Revision**        | “Never forget” rules and mental shortcuts                               |
| **Project**         | Eventually combine everything into production architectures             |

And our larger AWS journey is still going toward **networking, hosting, DNS/domain configuration, CloudFront, databases, security, observability, HA/DR, server sizing, hybrid architecture, migration, Terraform, troubleshooting, and eventually complete production architecture design** — not stopping after EC2.

Where we currently are:

```text
AWS fundamentals
       ↓
IAM / security
       ↓
Networking / VPC
       ↓
EC2 compute
       ↓
Load balancing
       ↓
Target Groups + Health Checks
       ↓
Auto Scaling
       ↓
Scaling policies
       ↓
Launch Templates
       ↓
Instance Refresh
       ↓
Lifecycle Hooks
       ↓
Warm Pools
       ↓
★ WE ARE HERE ★
       ↓
Mixed Instances
On-Demand + Spot
Capacity Rebalancing
Cost optimization
```

So let's continue exactly from there.

---

# AWS Lesson 24 — Part 3

# Mixed Instances, Spot Instances & Production Cost Optimization

This is an important **SAA-C03 + DOP-C02 + real production architecture** topic.

Previously our ASG looked like:

```text
Auto Scaling Group
        │
        ├── t3.micro
        ├── t3.micro
        ├── t3.micro
        └── t3.micro

Purchase option:
100% On-Demand
```

That's simple and reliable.

But there are two problems.

### Problem 1 — Cost

Imagine you need:

```text
100 EC2 instances
```

Running all 100 as On-Demand can become expensive.

### Problem 2 — Capacity

Imagine AWS temporarily has insufficient capacity for:

```text
t3.micro
```

in one Availability Zone.

Your ASG may struggle to get the capacity it needs.

A better production design can allow:

```text
t3.small
t3.medium
m6i.large
m6a.large
m7i.large
m7a.large
...
```

and combine:

```text
On-Demand
+
Spot
```

This is called a **Mixed Instances Auto Scaling Group**. AWS supports combining multiple instance types and both On-Demand and Spot purchasing models in a single Auto Scaling group. ([AWS Documentation][1])

---

# 1. First Understand the Three Concepts

Don't mix these up.

```text
Instance Type
     │
     │ Hardware characteristics
     ▼
t3.micro
m7i.large
c7i.large


Purchase Option
     │
     │ How you pay/acquire capacity
     ▼
On-Demand
Spot


Auto Scaling Group
     │
     │ Manages fleet
     ▼
Min / Desired / Max
```

So:

> `m7i.large` is not On-Demand or Spot by itself.

The same compatible instance type can potentially be launched under different purchasing models.

---

# 2. On-Demand Instance

On-Demand is the straightforward model:

```text
Need EC2
  ↓
Launch
  ↓
Use it
  ↓
Pay applicable On-Demand usage
```

The major operational advantage is predictability of purchasing model.

For critical baseline capacity such as:

```text
API servers
payment services
core web application
control services
```

it is common to keep some guaranteed baseline capacity using On-Demand.

---

# 3. Spot Instance

Spot uses AWS's available spare EC2 capacity and can provide substantial savings compared with regular On-Demand pricing. The trade-off is that the capacity can be reclaimed, so the workload must tolerate interruption. ([AWS Documentation][1])

Mental model:

```text
AWS EC2 capacity
       │
       ├── Capacity needed for regular demand
       │
       └── Spare capacity
                │
                ▼
             SPOT
```

Therefore:

```text
Spot =
cheap capacity
+
interruptible capacity
```

This is the first **never-forget rule**:

> **Never design a Spot workload assuming the EC2 instance will live forever.**

---

# 4. Spot Is Excellent for Stateless Workloads

Good examples:

```text
Web servers behind ALB
Container workers
ECS workers
Batch processing
CI/CD build agents
Image/video processing
Data processing
Background workers
Distributed computing
Some Kubernetes worker nodes
ML training jobs with checkpointing
```

Bad architecture:

```text
             Spot EC2
                │
                ▼
         PostgreSQL database
                │
        all data stored only
        on local instance
```

Instance interrupted:

```text
EC2 gone
   ↓
Database unavailable
   ↓
Potential data/service disaster
```

Instead:

```text
                     ALB
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
        Spot        Spot      On-Demand
         EC2         EC2         EC2
          │           │           │
          └───────────┼───────────┘
                      │
                      ▼
                     RDS
```

The application servers are replaceable.

The persistent state lives elsewhere.

---

# 5. Why Multiple Instance Types?

Suppose your application only allows:

```text
m6i.large
```

You effectively have fewer capacity choices.

Conceptually:

```text
ASG
 ↓
m6i.large
 ↓
specific capacity pools
```

Now imagine allowing:

```text
m6i.large
m6a.large
m5.large
m5a.large
m7i.large
m7a.large
```

AWS now has substantially more possible capacity pools to consider.

```text
                     ASG
                      │
       ┌──────────────┼──────────────┐
       ↓              ↓              ↓
   m6i.large      m6a.large      m7i.large
       │              │              │
   AZ-a/b/c        AZ-a/b/c        AZ-a/b/c
```

This improves the ability to find suitable capacity, especially when using Spot. AWS recommends configuring multiple instance types and Availability Zones so Auto Scaling can select among available Spot capacity pools. ([AWS Documentation][2])

---

# 6. What Exactly Is a Spot Pool?

This terminology is very important.

Think approximately:

```text
Instance type
+
Availability Zone
=
Spot capacity pool
```

For example:

```text
m6i.large + ap-south-1a
m6i.large + ap-south-1b
m6i.large + ap-south-1c

m6a.large + ap-south-1a
m6a.large + ap-south-1b
m6a.large + ap-south-1c
```

These give Auto Scaling several places from which it can source Spot capacity.

Therefore:

```text
More suitable instance types
+
More Availability Zones
=
more capacity diversification
```

---

# 7. Mixed Instances Policy

Instead of:

```text
ASG
 │
 └── Launch Template
          │
          └── t3.micro
```

we can build:

```text
ASG
 │
 └── Mixed Instances Policy
          │
          ├── Launch Template
          │
          ├── m6i.large
          ├── m6a.large
          ├── m5.large
          └── m5a.large
                 │
                 ├── On-Demand
                 └── Spot
```

AWS calls this configuration a **Mixed Instances Policy**. ([AWS Documentation][3])

---

# 8. On-Demand Base Capacity

Now comes an important interview concept.

Imagine:

```text
Desired capacity = 10
```

and we configure:

```text
OnDemandBaseCapacity = 2
```

It means:

> Keep the first two units of capacity as On-Demand before applying the Spot/On-Demand percentage to capacity above that base.

AWS explicitly applies the base capacity first and then uses the configured percentage for the remaining capacity. ([AWS Documentation][4])

So:

```text
Desired = 10

Base On-Demand = 2

Remaining capacity:

10 - 2 = 8
```

---

# 9. On-Demand Percentage Above Base Capacity

Now configure:

```text
OnDemandPercentageAboveBaseCapacity = 25
```

That means 25% of the **remaining capacity** should be On-Demand.

Remaining:

```text
8
```

25%:

```text
8 × 25%
= 2
```

Therefore:

```text
Base On-Demand = 2

Additional On-Demand = 2

Spot = 6
```

Final fleet:

```text
10 instances

├── 4 On-Demand
└── 6 Spot
```

Or:

```text
████ On-Demand
██████ Spot
```

---

# 10. Very Important Exam Trap

Suppose:

```text
Desired = 10

OnDemandBaseCapacity = 2

OnDemandPercentageAboveBaseCapacity = 25%
```

Do **NOT** calculate:

```text
10 × 25% = 2.5
```

because the percentage isn't applied to the entire group.

Correct:

```text
Step 1
Baseline = 2 On-Demand

Step 2
Remaining = 10 - 2
          = 8

Step 3
25% of 8
= 2

Step 4

On-Demand = 2 + 2
          = 4

Spot = 6
```

AWS also rounds fractional percentage results upward in favor of On-Demand capacity. ([AWS Documentation][4])

### Memory trick

```text
BASE FIRST
PERCENTAGE SECOND
```

---

# 11. Real Production Example

Imagine your application normally needs:

```text
4 servers
```

but during peak traffic:

```text
20 servers
```

Architecture:

```text
Minimum = 4
Desired = 4
Maximum = 20
```

We could configure:

```text
On-Demand Base = 4

Percentage above base = 20% On-Demand
```

At normal traffic:

```text
4 instances

████
100% baseline On-Demand
```

During peak:

```text
20 total
```

Remaining after base:

```text
20 - 4 = 16
```

20% On-Demand:

```text
16 × 20%
≈ 3.2
```

AWS rounds fractional results upward in favor of On-Demand. ([AWS Documentation][4])

Conceptually you get approximately:

```text
Baseline:
4 On-Demand

Additional:
~4 On-Demand
~12 Spot
```

This is powerful:

```text
Critical baseline
      ↓
On-Demand

Elastic peak capacity
      ↓
mostly Spot
```

---

# 12. Spot Allocation Strategy

Now AWS has several possible Spot pools.

Question:

> Which one should AWS choose?

That's what the **Spot allocation strategy** answers.

Current AWS Auto Scaling options include strategies such as:

```text
price-capacity-optimized
capacity-optimized
capacity-optimized-prioritized
lowest-price
```

AWS currently recommends **`price-capacity-optimized`** for getting started and recommends against `lowest-price` because of its higher interruption risk. ([AWS Documentation][5])

---

# 13. `price-capacity-optimized`

This is the strategy you should remember first.

```text
AWS evaluates:

Available capacity
       +
Relative price
       ↓
select attractive Spot pools
```

AWS describes it as selecting pools with strong capacity availability while also considering the lowest possible price among suitable pools. ([AWS Documentation][5])

Mental model:

```text
Not simply:

CHEAPEST


Instead:

LOW INTERRUPTION RISK
       +
GOOD PRICE
```

For many general-purpose production workloads:

```text
price-capacity-optimized
```

is a strong default.

---

# 14. `capacity-optimized`

Here the priority is capacity availability.

```text
Possible pools
      │
      ├── Pool A: low capacity
      ├── Pool B: high capacity   ← choose
      └── Pool C: medium capacity
```

This can be useful when interruption cost is especially important.

AWS uses real-time capacity information to favor pools with stronger available capacity. ([AWS Documentation][5])

---

# 15. `capacity-optimized-prioritized`

Imagine you prefer:

```text
1. m7i.large
2. m6i.large
3. m6a.large
4. m5.large
```

AWS will consider your priority ordering but optimize primarily for capacity. AWS describes honoring the priority on a best-effort basis while optimizing for capacity first. ([AWS Documentation][5])

Useful when:

```text
I care about capacity
BUT
I still have preferred instance types.
```

---

# 16. Why `lowest-price` Can Be Dangerous

It sounds attractive:

```text
"Just buy the cheapest Spot instance."
```

But:

```text
Cheapest pool
     ≠
Most stable pool
```

Imagine:

```text
Pool A
Price: ₹₹
Capacity: HIGH

Pool B
Price: ₹
Capacity: VERY LOW
```

Lowest-price logic might favor:

```text
Pool B
```

and that capacity could be more interruption-prone.

AWS currently does **not recommend `lowest-price` for Auto Scaling Spot allocation** because it carries the highest interruption risk among these strategies. ([AWS Documentation][5])

Remember:

```text
Cheap but constantly interrupted
is not really cheap operationally.
```

---

# 17. On-Demand Allocation Strategy

There is also a separate strategy for On-Demand capacity.

Current Auto Scaling options include:

```text
lowest-price
prioritized
```

For `prioritized`, Auto Scaling tries the launch-template override instance types according to your specified order. ([AWS Documentation][5])

Example:

```text
Priority:

1. m7i.large
2. m6i.large
3. m6a.large
```

AWS attempts to satisfy On-Demand capacity based on that ordering.

---

# 18. Terraform Mixed Instances Configuration

Now let's convert the concept into infrastructure.

```hcl
resource "aws_autoscaling_group" "app" {

  name = "prod-app-asg"

  min_size         = 2
  desired_capacity = 4
  max_size         = 10

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  capacity_rebalance = true

  mixed_instances_policy {

    launch_template {

      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.small"
      }

      override {
        instance_type = "t3a.small"
      }

      override {
        instance_type = "t3.medium"
      }

      override {
        instance_type = "t3a.medium"
      }
    }

    instances_distribution {

      on_demand_base_capacity = 2

      on_demand_percentage_above_base_capacity = 25

      on_demand_allocation_strategy = "lowest-price"

      spot_allocation_strategy = "price-capacity-optimized"
    }
  }
}
```

Conceptually:

```text
ASG
│
├── Desired = 4
│
├── Base On-Demand = 2
│
├── Remaining capacity
│      ├── some On-Demand
│      └── mostly Spot
│
├── t3.small
├── t3a.small
├── t3.medium
└── t3a.medium
```

AWS supports exactly this general mixed-fleet model: multiple instance types plus On-Demand and Spot capacity inside the same ASG. ([AWS Documentation][1])

---

# 19. Capacity Rebalancing

Now we hit a very important production concept.

Suppose:

```text
ASG

Instance A → Spot
Instance B → Spot
Instance C → On-Demand
Instance D → Spot
```

AWS determines:

```text
Instance B
has elevated Spot interruption risk.
```

Without proactive handling, eventually:

```text
Spot interruption
      ↓
instance disappears
      ↓
ASG detects capacity loss
      ↓
replacement requested
```

Reactive.

With:

```hcl
capacity_rebalance = true
```

Auto Scaling can react to an EC2 **rebalance recommendation** and attempt to launch replacement Spot capacity before terminating the at-risk instance. ([AWS Documentation][2])

Conceptually:

```text
Spot B becomes risky
       │
       ▼
Rebalance recommendation
       │
       ▼
ASG requests replacement Spot D
       │
       ▼
Spot D becomes healthy
       │
       ▼
Old Spot B removed
```

That's much better.

---

# 20. Capacity Rebalance vs Normal Replacement

Without:

```text
Instance interrupted
       ↓
Oh no!
       ↓
Launch replacement
```

With Capacity Rebalancing:

```text
Instance likely to be interrupted
       ↓
Prepare replacement
       ↓
Replacement healthy
       ↓
Remove old capacity
```

So remember:

> **Capacity Rebalancing is proactive Spot replacement.**

AWS specifically describes it as proactively replacing Spot Instances at elevated interruption risk. ([AWS Documentation][2])

---

# 21. Spot Two-Minute Interruption Notice

Another exam/interview point.

When EC2 is going to interrupt a Spot Instance, AWS provides a Spot interruption notice shortly before interruption, commonly giving **up to two minutes** to respond. A rebalance recommendation can arrive earlier, but AWS notes that it is not guaranteed to arrive earlier than the interruption notice. ([AWS Documentation][2])

Therefore you should never design:

```text
Interruption detected

↓ 10-minute backup

↓ 5-minute shutdown

↓ 8-minute data upload
```

You may not have that time.

Instead:

```text
Interruption/rebalance signal
        ↓
STOP taking new work
        ↓
Drain
        ↓
Checkpoint
        ↓
Flush small critical state
        ↓
Exit
```

Fast.

---

# 22. Combine This with Lifecycle Hooks

Remember what we just studied?

```text
Lifecycle Hooks
```

Now you'll see **why I taught lifecycle hooks before Spot**.

Architecture:

```text
Spot interruption risk
        │
        ▼
Capacity Rebalancing
        │
        ▼
Replacement launched
        │
        ▼
Termination lifecycle hook
        │
        ├── Stop accepting jobs
        ├── Complete/checkpoint work
        ├── Flush logs
        └── Deregister
        │
        ▼
Terminate old Spot
```

AWS specifically recommends lifecycle hooks where graceful application shutdown work is needed during rebalancing. ([AWS Documentation][2])

See our sequence?

We learned:

```text
ASG
 ↓
Health checks
 ↓
Instance Refresh
 ↓
Lifecycle Hooks
 ↓
Warm Pools
 ↓
Spot
 ↓
Capacity Rebalancing
```

Each concept is preparing the next one.

---

# 23. Production Architecture

Now combine everything you've learned.

```text
                         Route 53
                            │
                            ▼
                       CloudFront
                            │
                            ▼
                    Application LB
                    /             \
                   /               \
             ap-south-1a       ap-south-1b
                  │                 │
          ┌───────┼──────┐   ┌─────┼────────┐
          │       │      │   │     │        │
          ▼       ▼      ▼   ▼     ▼        ▼
        Spot    Spot    OD   Spot   OD     Spot
          │       │      │   │     │        │
          └───────┴──────┴───┴─────┴────────┘
                          │
                          ▼
                  Auto Scaling Group
                          │
             Mixed Instances Policy
                          │
            Capacity Rebalancing
                          │
                    Health checks
                          │
                          ▼
                         RDS
```

Now your infrastructure has:

```text
High availability
      +
Elastic scaling
      +
Capacity diversification
      +
Spot savings
      +
On-Demand baseline
      +
Automatic replacement
      +
Proactive rebalancing
```

That is much closer to **real cloud architecture** than simply:

```text
Launch one EC2
open port 80
install nginx
```

---

# 24. Common Production Failure

An engineer configures:

```text
100% Spot

Single instance type:
c6i.large

Single AZ:
ap-south-1a
```

Looks cheap.

But architecture is fragile:

```text
One AZ
+
One instance type
+
One Spot pool family choice
+
100% interruptible capacity
=
capacity risk
```

A stronger design:

```text
Multiple AZs

ap-south-1a
ap-south-1b
ap-south-1c

+

Several equivalent instance types

+

On-Demand baseline

+

Spot elasticity

+

price-capacity-optimized

+

Capacity Rebalancing
```

AWS's Spot guidance similarly emphasizes diversification and the `price-capacity-optimized` allocation strategy. ([AWS Documentation][4])

---

# 25. Troubleshooting Scenario

Suppose your ASG says:

```text
Desired = 10
Current = 7
```

and scaling activity shows failures obtaining Spot capacity.

Don't immediately say:

> "Auto Scaling is broken."

Think systematically:

```text
1. Are enough instance types configured?

2. Are multiple AZs/subnets configured?

3. Is one instance type overly restrictive?

4. Which allocation strategy is configured?

5. Is the Spot price configuration restricting capacity?

6. Are launch-template requirements too restrictive?

7. Is there an architecture mismatch?
   ARM vs x86?
   AMI compatibility?
   instance architecture?

8. Are EC2 quotas limiting launches?

9. Are IAM permissions blocking launch operations?

10. Are instances launching but failing health checks?
```

That is how a DevOps/SRE engineer thinks.

Not:

```text
terraform apply failed
      ↓
Google error
      ↓
copy random command
```

Instead:

```text
Observe
  ↓
Classify
  ↓
Find failing layer
  ↓
Validate hypothesis
  ↓
Fix root cause
```

---

# 26. Interview Scenario

### Interviewer

> We have a stateless web application that runs 50 EC2 instances during peak traffic. How would you reduce cost without dramatically compromising availability?

Weak answer:

```text
Use Spot Instances.
```

Better answer:

```text
I'd run the application in a Multi-AZ Auto Scaling group behind an ALB.

I'd maintain an On-Demand baseline for critical capacity and use Spot for elastic capacity above that baseline.

I'd diversify across several compatible instance types and Availability Zones, use price-capacity-optimized allocation for Spot, enable Capacity Rebalancing, configure appropriate health checks and lifecycle handling, and keep the application stateless so interrupted instances can be replaced safely.
```

That is a much more production-level answer and is consistent with AWS's current mixed-instance and Spot guidance. ([AWS Documentation][1])

---

# 27. Never-Forget Diagram

```text
                EC2 AUTO SCALING
                       │
          ┌────────────┴────────────┐
          │                         │
     On-Demand                    Spot
          │                         │
      Reliable                   Cheaper
      baseline                Interruptible
          │                         │
          └────────────┬────────────┘
                       │
              Mixed Instances
                       │
           Multiple instance types
                       │
            Multiple AZs/subnets
                       │
             Allocation strategy
                       │
         price-capacity-optimized
                       │
                       ▼
            Capacity Rebalancing
                       │
                       ▼
             Lifecycle handling
                       │
                       ▼
               ALB health checks
                       │
                       ▼
                Production ASG
```

And memorize these four lines:

```text
On-Demand = stable baseline.

Spot = interruptible cost optimization.

Mixed Instances = diversification.

Capacity Rebalancing = proactive Spot replacement.
```

One more:

```text
BASE FIRST
PERCENTAGE SECOND
```

---

# Where Our Flow Goes Next

We have **not finished Lesson 24 yet**.

The next section will take this further into:

```text
Lesson 24 — Part 4

EC2 Auto Scaling Advanced Production Operations

→ Spot interruption handling hands-on
→ EC2 Instance Metadata interruption/rebalance signals
→ Attribute-Based Instance Type Selection
→ Instance weighting / capacity units
→ scaling by vCPU/memory instead of instance count
→ termination policies in depth
→ scale-in protection
→ instance maintenance policies
→ AZ balancing
→ impaired AZ scenarios
→ maximum instance lifetime
→ suspended ASG processes
→ troubleshooting scaling activity
→ CloudWatch + ASG observability
→ complete Terraform production ASG
→ hands-on failure simulation
→ SAA-C03/DOP-C02 scenarios
→ final Lesson 24 production lab
```

Then, **only after we have properly finished Auto Scaling**, we'll move to the next service/architecture lesson in our AWS masterclass rather than skipping ahead. That's the flow we'll maintain.

[1]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-mixed-instances-groups.html "Auto Scaling groups with multiple instance types and purchase options - Amazon EC2 Auto Scaling"
[2]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-capacity-rebalancing.html "Capacity Rebalancing in Auto Scaling to replace at-risk Spot Instances - Amazon EC2 Auto Scaling"
[3]: https://docs.aws.amazon.com/autoscaling/ec2/APIReference/API_MixedInstancesPolicy.html?utm_source=chatgpt.com "MixedInstancesPolicy - Amazon EC2 Auto Scaling"
[4]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/mixed-instances-groups-set-up-overview.html "Setup overview for creating a mixed instances group - Amazon EC2 Auto Scaling"
[5]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/allocation-strategies.html "Allocation strategies for multiple instance types - Amazon EC2 Auto Scaling"
