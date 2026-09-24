# AWS Masterclass — Phase 3

# Lesson 24: Amazon EC2 Auto Scaling Groups

## 1. Lesson objective

In this lesson, you will learn how AWS automatically:

* Adds EC2 instances when traffic increases.
* Removes unnecessary instances when traffic decreases.
* Replaces failed or unhealthy instances.
* Distributes instances across multiple Availability Zones.
* Integrates EC2 instances with an Application Load Balancer.
* Performs rolling application and AMI updates.
* Uses On-Demand and Spot Instances together.
* Maintains availability while controlling infrastructure cost.

By the end, you should understand this production architecture:

```text
                           Internet
                               |
                         Route 53 / DNS
                               |
                     Application Load Balancer
                       /                   \
              Public Subnet A        Public Subnet B
                    |                      |
             Target Group           Target Group
                    \                      /
                     EC2 Auto Scaling Group
                       /                \
              Private Subnet A      Private Subnet B
                    |                     |
               EC2 Instance          EC2 Instance
                       \              /
                         RDS / Cache
```

AWS recommends using multiple Availability Zones for resilient workloads. EC2 Auto Scaling helps maintain compute capacity across those zones, while Elastic Load Balancing routes requests to healthy targets. ([AWS Documentation][1])

---

# 2. Why Auto Scaling is required

Imagine that your application normally receives:

```text
1,000 requests per minute
```

Two EC2 instances are enough.

During a sale or product launch, traffic suddenly becomes:

```text
20,000 requests per minute
```

Two instances may become overloaded:

```text
CPU:           95%
Memory:        90%
Response time: 8 seconds
Error rate:    25%
```

Without Auto Scaling, an engineer must:

1. Notice the problem.
2. Launch more EC2 instances.
3. Install the application.
4. Configure networking.
5. Register the instances with the load balancer.
6. Remove the instances after traffic decreases.

This is slow, error-prone and operationally expensive.

With Auto Scaling:

```text
Traffic increases
       ↓
CloudWatch metric rises
       ↓
Scaling policy is triggered
       ↓
Auto Scaling Group increases desired capacity
       ↓
New EC2 instances launch
       ↓
Instances pass health checks
       ↓
ALB begins sending traffic
```

When traffic decreases, the process happens in reverse.

---

# 3. The simplest mental model

Think of EC2 Auto Scaling as a **server fleet manager**.

An Auto Scaling group is a logical collection of EC2 instances managed together. Its two core responsibilities are:

```text
1. Maintain the required number of instances
2. Adjust the number of instances based on demand
```

It can also replace unhealthy instances and apply scaling policies. ([AWS Documentation][2])

Use this analogy:

```text
Launch Template  = Server blueprint
Auto Scaling Group = Server fleet manager
CloudWatch Metric  = Sensor
Scaling Policy     = Decision rule
ALB                = Traffic distributor
Target Group       = List of application servers
```

## Thermostat analogy

Target tracking behaves like a thermostat:

```text
Desired room temperature: 24°C
Current temperature:      30°C
Thermostat action:        Increase cooling
```

For EC2:

```text
Target CPU:    50%
Current CPU:   80%
Scaling action: Add instances
```

AWS specifically recommends target tracking for many dynamic-scaling use cases because you choose the desired metric value and Auto Scaling manages the underlying scaling adjustments and CloudWatch alarms. ([AWS Documentation][3])

---

# 4. The three most important Auto Scaling values

Every Auto Scaling group has three capacity settings:

| Setting          | Meaning                                                         |
| ---------------- | --------------------------------------------------------------- |
| Minimum capacity | Lowest number of instances allowed                              |
| Desired capacity | Number of instances Auto Scaling currently attempts to maintain |
| Maximum capacity | Highest number of instances allowed                             |

Example:

```text
Minimum capacity: 2
Desired capacity: 3
Maximum capacity: 10
```

This means:

```text
At least 2 instances must exist.
Currently, AWS should maintain 3 instances.
The group may scale up to 10 instances.
```

## Scenario 1: An instance fails

Current state:

```text
Min:     2
Desired: 3
Max:    10
Running: 3
```

One instance becomes unhealthy:

```text
Running healthy instances: 2
Desired capacity:           3
```

Auto Scaling launches a replacement:

```text
Healthy instances: 3
Desired capacity: 3
```

This is **self-healing**, not necessarily demand-based scaling.

## Scenario 2: Traffic increases

```text
Min:     2
Desired: 3
Max:    10
```

A scaling policy decides that five instances are required:

```text
Desired capacity changes from 3 to 5
```

Auto Scaling launches two more instances.

## Scenario 3: Maximum is reached

```text
Min:      2
Desired: 10
Max:     10
```

Even when the scaling metric remains high, normal scaling policies cannot increase capacity beyond the configured maximum. ([AWS Documentation][4])

### Production warning

A maximum capacity of `10` is not a statement that your application can safely handle traffic with ten instances.

It is a safety boundary.

You must load-test:

```text
Requests handled by one instance
Instance startup time
CPU per request
Memory usage
Database connection consumption
ALB response time
Application failure point
```

---

# 5. Launch Template vs Auto Scaling Group

These two resources are frequently confused.

## Launch Template

A launch template defines **how to create an EC2 instance**.

It commonly contains:

```text
AMI
Instance type
Security groups
IAM instance profile
SSH key
EBS volumes
User data
Network settings
Metadata settings
Tags
Spot configuration
```

Example:

```text
AMI:                 ami-xxxxxxxx
Instance type:       t3.micro
Security group:      app-server-sg
IAM role:            ec2-app-role
Root disk:           20 GB gp3
Metadata:            IMDSv2 required
User data:           Install and start application
```

AWS recommends launch templates instead of older launch configurations. Features such as mixed instance types and combined Spot/On-Demand capacity require a launch template. ([AWS Documentation][5])

## Auto Scaling Group

The Auto Scaling group defines **how the fleet operates**.

It contains:

```text
Minimum capacity
Desired capacity
Maximum capacity
Subnets
Availability Zones
Target groups
Health-check type
Health-check grace period
Scaling policies
Termination policy
Instance refresh settings
```

### Never-forget distinction

```text
Launch Template:
“What should each server look like?”

Auto Scaling Group:
“How many servers should exist, where should they run,
and how should AWS manage them?”
```

---

# 6. Multi-AZ Auto Scaling

A production Auto Scaling group should normally use subnets in at least two Availability Zones.

Example in `ap-south-1`:

```text
VPC: 10.0.0.0/16

Public subnet A:
10.0.1.0/24
ap-south-1a
Contains ALB node

Public subnet B:
10.0.2.0/24
ap-south-1b
Contains ALB node

Private application subnet A:
10.0.11.0/24
ap-south-1a
Contains Auto Scaling instances

Private application subnet B:
10.0.12.0/24
ap-south-1b
Contains Auto Scaling instances
```

The Auto Scaling group receives both private subnet IDs:

```hcl
vpc_zone_identifier = [
  aws_subnet.private_app_a.id,
  aws_subnet.private_app_b.id
]
```

AWS can then distribute the group’s instances across those Availability Zones.

AWS Well-Architected guidance recommends deploying workloads in multiple locations such as multiple Availability Zones, so failure of one instance or one zone does not necessarily stop the workload. ([AWS Documentation][6])

---

# 7. ALB and Auto Scaling integration

The Application Load Balancer and Auto Scaling group perform different jobs.

## Application Load Balancer

The ALB:

```text
Accepts client requests
Terminates HTTP or HTTPS connections
Evaluates listener rules
Selects a target group
Routes requests to healthy targets
```

An ALB operates at Layer 7 and performs health checks against targets registered in its target groups. ([AWS Documentation][7])

## Auto Scaling Group

The ASG:

```text
Launches instances
Terminates instances
Registers new instances with the target group
Deregisters terminated instances
Replaces unhealthy instances
Adjusts desired capacity
```

When an Auto Scaling group is attached to an ALB target group, instances launched by the group are automatically registered, and instances terminated by the group are automatically deregistered. ([AWS Documentation][8])

## Complete request flow

```text
1. User sends HTTPS request.
2. DNS resolves the ALB hostname.
3. ALB listener receives the request on port 443.
4. Listener rule selects a target group.
5. ALB selects a healthy EC2 target.
6. EC2 application processes the request.
7. EC2 returns the response through the ALB.
```

---

# 8. Security-group design

Use separate security groups for the load balancer and application servers.

## ALB security group

```text
Inbound:
443 from 0.0.0.0/0
80 from 0.0.0.0/0, only when redirecting HTTP to HTTPS

Outbound:
Application port to app security group
```

## EC2 application security group

```text
Inbound:
Port 80 or 3000 from ALB security group only

Outbound:
Required application destinations
```

Do not configure this for private application instances:

```text
Port 3000 from 0.0.0.0/0
```

Use this:

```text
Port 3000 from sg-alb
```

The instance security group must allow the load balancer security group to reach both the application port and the configured health-check port. ([AWS Documentation][9])

---

# 9. EC2 health checks vs ELB health checks

Auto Scaling can evaluate different health signals.

## EC2 health checks

EC2 status checks detect infrastructure or operating-system reachability problems such as:

```text
Underlying host failure
Instance system failure
Network reachability failure
Operating-system failure
```

But an EC2 instance can be technically running while the application is broken.

Example:

```text
EC2 state:       running
EC2 status:      passed
Nginx:           stopped
Node.js process: crashed
Application:     unavailable
```

An EC2-only health check may not detect the application failure.

## ELB health checks

The ALB sends requests to the application:

```http
GET /health
```

Expected response:

```http
HTTP/1.1 200 OK
```

When the target repeatedly fails according to the target-group configuration, the ALB marks it unhealthy and stops treating it as a healthy routing target. When ELB health checks are enabled for the Auto Scaling group, Auto Scaling can use that health result to replace the instance. ([AWS Documentation][10])

## Recommended configuration

```hcl
health_check_type         = "ELB"
health_check_grace_period = 180
```

This lets Auto Scaling consider load-balancer health after allowing the instance some startup time.

---

# 10. Designing a correct `/health` endpoint

A health endpoint should answer:

```text
“Can this instance safely receive normal traffic?”
```

A basic Express health endpoint:

```javascript
app.get("/health", (_req, res) => {
  res.status(200).json({
    status: "healthy",
    timestamp: new Date().toISOString()
  });
});
```

A more useful readiness endpoint:

```javascript
app.get("/ready", async (_req, res) => {
  try {
    await database.command({ ping: 1 });

    res.status(200).json({
      status: "ready",
      database: "connected"
    });
  } catch {
    res.status(503).json({
      status: "not-ready",
      database: "unavailable"
    });
  }
});
```

## Liveness vs readiness

```text
Liveness:
“Is the process alive?”

Readiness:
“Can this process safely handle traffic?”
```

For ALB routing, readiness is usually more important.

### Avoid excessive dependencies

A health endpoint that depends on every external service can create cascading failure.

For example:

```text
Application is healthy.
Third-party email API is unavailable.
Health check fails.
Every EC2 instance is replaced.
New instances also fail the same check.
Entire target group becomes unhealthy.
```

Health checks should test critical serving dependencies, not every optional feature.

Also remember that when every target in a target group is unhealthy, ALB can fail open and route to all registered targets, so “all unhealthy” does not always mean “all traffic is discarded.” ([AWS Documentation][10])

---

# 11. Health-check grace period

A new instance may require time to:

```text
Boot the operating system
Execute user data
Download packages
Start Docker
Pull an image
Start the application
Connect to the database
Warm application caches
Pass the ALB health check
```

Suppose startup takes 120 seconds.

If the grace period is only 30 seconds:

```text
Instance launches
       ↓
Application is still starting
       ↓
Health check fails
       ↓
Auto Scaling marks instance unhealthy
       ↓
Instance is terminated
       ↓
Replacement repeats the same cycle
```

This is called a **launch-terminate loop**.

Set the grace period high enough for normal startup, but not so high that genuinely broken instances remain unnoticed for too long. AWS gives the same general guidance for instance refresh and maintenance behavior. ([AWS Documentation][11])

---

# 12. Default instance warmup

The health-check grace period and instance warmup are related but different.

## Health-check grace period

Protects a newly launched instance from being replaced too quickly because it has not completed startup.

## Instance warmup

Tells scaling logic how long a new instance needs before its metrics should fully influence further scaling decisions.

Example:

```hcl
default_instance_warmup = 180
```

Without an appropriate warmup:

```text
1. CPU becomes high.
2. ASG launches two instances.
3. New instances have not started serving traffic.
4. CPU remains high on old instances.
5. ASG assumes more capacity is required.
6. Additional unnecessary instances launch.
```

Target tracking and step scaling use instance warmup rather than relying on the simple-scaling cooldown mechanism. ([AWS Documentation][12])

---

# 13. Scaling methods

EC2 Auto Scaling supports several approaches.

## 13.1 Manual scaling

You directly change desired capacity:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name production-web-asg \
  --desired-capacity 4 \
  --region ap-south-1
```

Suitable for:

```text
Testing
Emergency response
Temporary maintenance
Controlled experiments
```

Not suitable as the main production scaling strategy.

---

## 13.2 Target tracking scaling

Target tracking attempts to keep a metric near a target value.

Example:

```text
Metric: Average CPU utilization
Target: 50%
```

Conceptually:

```text
CPU above 50% → Add capacity
CPU below 50% → Consider removing capacity
```

Terraform example:

```hcl
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}
```

Target tracking is commonly the best starting point because AWS manages the corresponding CloudWatch alarms and scaling adjustments. ([AWS Documentation][3])

### Available predefined metrics include

```text
ASGAverageCPUUtilization
ASGAverageNetworkIn
ASGAverageNetworkOut
ALBRequestCountPerTarget
```

The metric should change predictably as capacity changes. For example, when capacity doubles, average CPU or request count per target should normally decrease. ([AWS Documentation][13])

---

## 13.3 ALB request-count scaling

CPU is not always the best scaling metric.

A web application might have:

```text
Low CPU usage
High request count
High downstream latency
Large number of concurrent connections
```

You can scale based on:

```text
ALBRequestCountPerTarget
```

Example:

```hcl
resource "aws_autoscaling_policy" "alb_requests" {
  name                   = "alb-request-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      resource_label = join("/", [
        aws_lb.app.arn_suffix,
        aws_lb_target_group.app.arn_suffix
      ])
    }

    target_value = 500
  }
}
```

`500` is only an example. Determine the actual target with load testing.

AWS requires the ALB and target-group resource label when using the `ALBRequestCountPerTarget` predefined metric. ([AWS Documentation][13])

---

## 13.4 Step scaling

Step scaling applies different actions depending on the severity of a CloudWatch alarm.

Example:

```text
CPU 60–70% → Add 1 instance
CPU 70–85% → Add 2 instances
CPU >85%   → Add 4 instances
```

This is useful when load does not grow linearly.

Example logic:

```text
Small overload → Small response
Large overload → Aggressive response
```

Step scaling requires you to create and manage the CloudWatch alarm and define the scaling adjustments. ([AWS Documentation][14])

---

## 13.5 Simple scaling

Simple scaling performs one fixed adjustment and then observes a cooldown.

Example:

```text
CPU > 70% → Add 2 instances
Wait 300 seconds
```

It is less flexible than target tracking or step scaling and is generally not the first choice for modern designs.

AWS documents that target tracking and step scaling can scale out without waiting for the simple-scaling cooldown; they use instance warmup behavior instead. ([AWS Documentation][12])

---

## 13.6 Scheduled scaling

Scheduled scaling changes capacity at known times.

Example:

```text
Every weekday at 8:45 AM:
Desired capacity = 6

Every weekday at 8:00 PM:
Desired capacity = 2
```

Suitable for:

```text
Office-hour applications
Payroll processing
Scheduled television events
Known batch windows
Planned product launches
```

Scheduled scaling changes minimum, maximum or desired capacity at specified times based on predictable demand. ([AWS Documentation][15])

Example CLI:

```bash
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name production-web-asg \
  --scheduled-action-name weekday-scale-out \
  --recurrence "45 8 * * MON-FRI" \
  --min-size 4 \
  --desired-capacity 6 \
  --max-size 12 \
  --time-zone "Asia/Kolkata" \
  --region ap-south-1
```

---

## 13.7 Predictive scaling

Predictive scaling analyzes historical load patterns and forecasts future capacity requirements.

Suitable for recurring patterns such as:

```text
Daily morning peak
Weekday office traffic
Weekend traffic increase
Monthly payroll processing
Recurring media events
```

Predictive scaling is proactive:

```text
Prediction:
Traffic will increase at 9:00 AM.

Action:
Launch instances before 9:00 AM.
```

Dynamic scaling is reactive:

```text
Observation:
Traffic has already increased.

Action:
Launch instances now.
```

AWS supports combining predictive scaling with dynamic scaling so predictive scaling handles recurring patterns and dynamic scaling handles unexpected changes. Forecast-only mode can be used to evaluate the forecast before allowing it to modify capacity. ([AWS Documentation][16])

---

# 14. Choosing the correct scaling metric

Do not automatically select CPU for every application.

| Workload                     | Better metric                      |
| ---------------------------- | ---------------------------------- |
| CPU-intensive API            | Average CPU                        |
| ALB web application          | Request count per target           |
| Queue worker                 | Queue backlog per instance         |
| Memory-intensive service     | Custom memory metric               |
| Concurrent-connection server | Custom active-connections metric   |
| Batch processor              | Remaining jobs or processing delay |
| Streaming consumer           | Consumer lag                       |

## Why queue length alone can be misleading

Suppose:

```text
Queue messages: 1,000
Instances:      1
```

That is heavy backlog.

Now:

```text
Queue messages: 1,000
Instances:      20
```

The same queue length may be manageable.

A better metric is:

```text
Backlog per instance =
Visible messages / InService instances
```

AWS documents this approach for SQS-backed worker fleets because raw queue depth does not necessarily change proportionally with Auto Scaling capacity. ([AWS Documentation][17])

## Backlog target formula

```text
Acceptable backlog per instance =
Acceptable processing latency / Average processing time per message
```

Example:

```text
Acceptable latency:           20 seconds
Average processing time:      0.2 seconds
Acceptable backlog/instance:  20 / 0.2
                              = 100 messages
```

Your target-tracking value could therefore be approximately:

```text
100 messages per instance
```

---

# 15. Scale-out vs scale-in

Scaling out and scaling in should not be treated identically.

## Scale-out

```text
Add capacity quickly.
```

Reason:

```text
Insufficient capacity can cause:
High latency
Timeouts
HTTP 5xx errors
Dropped requests
Customer impact
```

## Scale-in

```text
Remove capacity carefully.
```

Reason:

```text
An instance may still be:
Processing a request
Running a background job
Uploading data
Holding a WebSocket connection
Writing logs
Participating in deployment
```

A good production strategy is:

```text
Fast scale-out
Conservative scale-in
```

---

# 16. Deregistration delay and connection draining

When an instance is selected for termination, it should stop receiving new traffic while completing active requests.

Conceptually:

```text
Instance selected for termination
        ↓
ALB begins deregistration
        ↓
No new requests routed to target
        ↓
Existing requests get time to finish
        ↓
Instance terminates
```

Terraform:

```hcl
resource "aws_lb_target_group" "app" {
  name        = "production-app-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  deregistration_delay = 60

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-299"
  }
}
```

Choose deregistration delay according to the longest legitimate request duration.

---

# 17. Scale-in protection

Some instances should not be terminated while performing important work.

Example:

```text
Worker receives a 20-minute video-processing job.
Traffic decreases.
ASG decides to scale in.
Worker is terminated after 3 minutes.
The processing job is lost.
```

You can use instance scale-in protection while the job is active.

CLI:

```bash
aws autoscaling set-instance-protection \
  --instance-ids i-0123456789abcdef0 \
  --auto-scaling-group-name video-worker-asg \
  --protected-from-scale-in \
  --region ap-south-1
```

After work completes:

```bash
aws autoscaling set-instance-protection \
  --instance-ids i-0123456789abcdef0 \
  --auto-scaling-group-name video-worker-asg \
  --no-protected-from-scale-in \
  --region ap-south-1
```

Do not leave every instance protected indefinitely, or Auto Scaling may be unable to reduce capacity or complete an instance refresh.

---

# 18. Lifecycle hooks

Lifecycle hooks pause an instance during launch or termination so custom automation can run.

## Launch lifecycle hook

```text
EC2 launches
    ↓
Pending:Wait
    ↓
Install or configure application
    ↓
Run validation
    ↓
Complete lifecycle action
    ↓
InService
```

## Termination lifecycle hook

```text
Instance selected
    ↓
Terminating:Wait
    ↓
Drain application
Upload final logs
Release job lock
Notify monitoring system
    ↓
Complete lifecycle action
    ↓
Instance terminates
```

Lifecycle hooks are designed for custom actions during instance launch or before termination, and Auto Scaling events can be processed with services such as EventBridge and Lambda. ([AWS Documentation][18])

Typical uses:

```text
Register with a configuration-management system
Attach monitoring agents
Warm an application cache
Run smoke tests
Drain background workers
Upload diagnostic data
Remove the server from an external registry
```

---

# 19. Termination policies

When scaling in, AWS must decide which instance to terminate.

Factors may include:

```text
Availability Zone balancing
Launch-template version
Billing considerations
Instance age
Configured termination policies
```

Production considerations:

```text
Prefer removing outdated launch-template versions.
Avoid concentrating all instances in one AZ.
Protect instances running critical work.
Allow graceful traffic draining.
```

Do not depend on local EC2 disk data surviving scale-in.

Treat Auto Scaling instances as replaceable:

```text
Configuration → AMI, user data or configuration management
Logs          → CloudWatch Logs or centralized logging
Uploads       → S3
Sessions      → Redis, DynamoDB or database
Application   → Immutable artifact or container image
Secrets       → Secrets Manager or Parameter Store
```

---

# 20. Instance Refresh

Suppose your Auto Scaling group runs:

```text
Launch Template version 4
AMI: old-application-image
```

You create:

```text
Launch Template version 5
AMI: patched-application-image
```

Changing the launch template does not automatically guarantee that every existing instance is immediately replaced.

Instance Refresh performs a rolling replacement:

```text
Old instances
      ↓
Launch new instances
      ↓
Wait for health checks
      ↓
Terminate selected old instances
      ↓
Repeat
```

AWS Instance Refresh can update instances gradually and can use health checks, warmup, minimum healthy percentage and desired configuration controls. ([AWS Documentation][11])

Start from the CLI:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name production-web-asg \
  --preferences '{
    "MinHealthyPercentage": 90,
    "InstanceWarmup": 180,
    "SkipMatching": true
  }' \
  --region ap-south-1
```

Check progress:

```bash
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name production-web-asg \
  --region ap-south-1
```

## Meaning of `MinHealthyPercentage`

Suppose:

```text
Desired capacity:      10
Minimum healthy:       90%
```

Auto Scaling attempts to retain approximately nine healthy capacity units while replacing instances.

A lower percentage:

```text
Updates faster
Uses less temporary capacity
Creates more availability risk
```

A higher percentage:

```text
Updates more safely
May require temporary extra capacity
May take longer
```

---

# 21. Immutable deployment approach

A mature production deployment often follows this pattern:

```text
1. CI pipeline builds application.
2. Tests run.
3. Security scans run.
4. Packer builds a new AMI.
5. New launch-template version is created.
6. Auto Scaling group points to the new version.
7. Instance Refresh starts.
8. New instances pass health checks.
9. Old instances are removed.
```

This is more predictable than installing a large application from scratch every time an instance starts.

Use user data for lightweight startup configuration, not an uncontrolled sequence of lengthy installations.

Bad pattern:

```bash
apt update
install 40 packages
git clone application
npm install
npm run build
download configuration
manually rewrite files
start application
```

A temporary package-repository or Git outage could prevent every replacement instance from starting.

Better pattern:

```text
AMI already contains:
Operating-system patches
Runtime
Application artifact
Monitoring agent
Required packages

Startup performs:
Retrieve environment configuration
Retrieve secrets
Start service
Register readiness
```

---

# 22. Warm Pools

Some applications take a long time to start:

```text
Large Java application:          8 minutes
Windows application server:     12 minutes
Machine-learning model server:  15 minutes
Legacy enterprise service:      20 minutes
```

Dynamic scaling may detect increased demand immediately, but customers still wait for instances to boot.

A warm pool keeps pre-initialized instances available closer to readiness.

Conceptually:

```text
Normal scale-out:
Launch → initialize → start → health check → serve

Warm-pool scale-out:
Warm pool → resume/start → health check → serve
```

Warm pools are useful for long startup times, but they still consume resources and require lifecycle management. AWS supports instance refresh behavior for both active instances and warm-pool instances. ([AWS Documentation][19])

---

# 23. On-Demand and Spot mixed instances

A production Auto Scaling group can use:

```text
On-Demand Instances for baseline capacity
Spot Instances for additional flexible capacity
```

Example:

```text
Minimum baseline:
2 On-Demand instances

Burst capacity:
Additional Spot or On-Demand instances

Maximum:
20 total capacity units
```

Possible instance-type pool:

```text
t3.medium
t3a.medium
t4g.medium
m6i.large
m6a.large
```

Do not use a single Spot instance type when the application supports alternatives. A broader compatible instance pool gives Auto Scaling more placement options.

Launch templates are required for mixed instance types and combined Spot/On-Demand configurations. ([AWS Documentation][5])

### Appropriate Spot workloads

```text
Stateless web servers
Background workers
CI runners
Image processing
Batch jobs
Distributed computation
Fault-tolerant APIs
```

### Use caution with

```text
Single-instance stateful databases
Non-restartable long-running jobs
Applications tied to local disk state
License-bound servers
Workloads without graceful interruption handling
```

---

# 24. Production Terraform structure

A clean infrastructure layout could be:

```text
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── dev.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── prod.tfvars
│
└── modules/
    ├── vpc/
    ├── alb/
    ├── security/
    └── autoscaling/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

# 25. Terraform launch-template example

```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail

    systemctl enable my-application
    systemctl start my-application
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.environment}-autoscaling-app"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

Important settings:

```text
http_tokens = required  → Enforces IMDSv2
encrypted = true        → Encrypts root EBS volume
create_before_destroy   → Avoids destroying the template too early
IAM instance profile    → Provides temporary AWS credentials to EC2
```

When using a customer-managed KMS key for EBS encryption, the KMS key policy must permit the required Auto Scaling service access. ([AWS Documentation][20])

---

# 26. Terraform Auto Scaling Group

```hcl
resource "aws_autoscaling_group" "app" {
  name = "${var.environment}-app-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 6

  vpc_zone_identifier = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 180
  default_instance_warmup   = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 180
    }

    triggers = [
      "tag"
    ]
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

---

# 27. Validation commands

## Inspect the group

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names production-app-asg \
  --region ap-south-1
```

## List instances managed by the group

```bash
aws autoscaling describe-auto-scaling-instances \
  --region ap-south-1 \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`production-app-asg`].[InstanceId,AvailabilityZone,LifecycleState,HealthStatus]' \
  --output table
```

## Check scaling activity

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1 \
  --max-items 20
```

This command is one of the most useful troubleshooting commands because it shows messages such as:

```text
Launching a new EC2 instance
Instance failed to launch
Security group does not exist
InsufficientInstanceCapacity
KMS key is not accessible
Instance failed ELB health checks
Maximum group size reached
```

## Check ALB target health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region ap-south-1
```

## Check desired and actual capacity

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].{
    Min:MinSize,
    Desired:DesiredCapacity,
    Max:MaxSize,
    Running:length(Instances)
  }'
```

---

# 28. Self-healing test

Do this only in a safe lab environment.

Get one instance:

```bash
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "$INSTANCE_ID"
```

Terminate it:

```bash
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region ap-south-1
```

Observe:

```bash
watch -n 10 "
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
  --output table
"
```

Expected result:

```text
1. Old instance enters termination.
2. Auto Scaling detects capacity below desired.
3. Replacement instance launches.
4. Replacement registers with target group.
5. Replacement passes health checks.
6. Capacity returns to desired value.
```

---

# 29. Load-based scaling test

Install a load-testing tool on your local machine or a dedicated test host.

Example with `hey`:

```bash
hey -z 10m -c 100 https://your-alb-or-domain.example.com/
```

Monitor:

```text
CloudWatch CPUUtilization
ALB RequestCountPerTarget
ALB TargetResponseTime
ALB HTTPCode_Target_5XX_Count
ASG desired capacity
ASG InService instance count
Scaling activities
```

Expected flow:

```text
Load increases
      ↓
Metric crosses target
      ↓
Desired capacity increases
      ↓
Instances launch and warm up
      ↓
Targets become healthy
      ↓
Load is distributed
      ↓
Average metric falls toward target
```

Do not generate aggressive load against infrastructure you do not own or have permission to test.

---

# 30. Common Auto Scaling problems

## Problem 1: Instance launches and immediately terminates

Possible causes:

```text
Health-check grace period too short
Incorrect health-check path
Application failed to start
Security group blocks ALB
Wrong application port
User-data failure
Missing secret or configuration
Database connection failure
```

Check:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1
```

Then inspect:

```text
EC2 console output
Cloud-init logs
Application logs
Systemd status
Target-group health reason
```

Useful Linux commands:

```bash
sudo cat /var/log/cloud-init-output.log
sudo systemctl status my-application
sudo journalctl -u my-application -n 200
sudo ss -lntp
curl -v http://localhost:3000/health
```

---

## Problem 2: Target remains unhealthy

Check:

```text
Is the application listening on 0.0.0.0?
Is the target-group port correct?
Does the health path exist?
Does it return an accepted status code?
Does the EC2 security group allow the ALB security group?
Is the instance in an enabled ALB Availability Zone?
```

ALB health checks only operate correctly when the target is registered, its target group is used by a listener rule and its Availability Zone is enabled for the load balancer. ([AWS Documentation][10])

Incorrect Node.js binding:

```javascript
app.listen(3000, "127.0.0.1");
```

Better for an EC2 service behind ALB:

```javascript
app.listen(3000, "0.0.0.0");
```

---

## Problem 3: Auto Scaling does not scale out

Check:

```text
Maximum capacity already reached
Scaling policy disabled
CloudWatch metric unavailable
Wrong metric dimension
Insufficient evaluation time
Instance warmup still active
Suspended Auto Scaling process
IAM or service-linked role issue
```

Inspect suspended processes:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name production-app-asg \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].SuspendedProcesses'
```

Auto Scaling processes can be suspended and resumed, which can temporarily disable operations such as launching, termination or alarm-driven scaling. ([AWS Documentation][21])

---

## Problem 4: Too many instances launch

Possible causes:

```text
Target value too low
Warmup too short
Application takes longer to become ready
Metric does not decrease as capacity increases
Health-check failures prevent useful capacity
Traffic is unevenly distributed
```

Example:

```text
CPU target: 10%
```

This may force an unnecessarily large fleet.

A target value should be high enough for cost efficiency while retaining reasonable headroom for unexpected traffic. ([AWS Documentation][13])

---

## Problem 5: Scaling oscillates

Symptoms:

```text
Scale from 2 to 5
Scale from 5 to 2
Scale from 2 to 5
Repeat
```

This is called flapping or oscillation.

Possible fixes:

```text
Increase instance warmup
Use a better proportional metric
Use conservative scale-in
Increase evaluation periods
Raise minimum capacity
Add a scale-in buffer
Correct uneven load distribution
```

---

## Problem 6: Instances cannot launch with encrypted EBS

Common cause:

```text
Customer-managed KMS key policy does not allow
the required Auto Scaling service access.
```

Check:

```text
KMS key policy
Service-linked role
Launch-template block-device mapping
Encryption key Region
Key enabled/disabled state
```

AWS explicitly requires the customer-managed KMS key policy to grant the necessary permissions for Auto Scaling launches. ([AWS Documentation][20])

---

# 31. Production design checklist

Before calling an Auto Scaling group production-ready, verify:

```text
[ ] Instances run across at least two Availability Zones
[ ] Application instances are in private subnets
[ ] ALB is attached to the target group
[ ] ASG uses ELB health checks
[ ] Health endpoint represents application readiness
[ ] Grace period matches startup time
[ ] Default instance warmup is configured
[ ] Minimum capacity tolerates one-instance failure
[ ] Maximum capacity protects cost and dependencies
[ ] Scaling metric matches workload behavior
[ ] Scale-out is tested
[ ] Scale-in is tested
[ ] Connection draining is configured
[ ] Application is stateless
[ ] Logs are centralized
[ ] Sessions are externalized
[ ] Secrets are not stored in user data
[ ] IMDSv2 is required
[ ] EBS volumes are encrypted
[ ] Instance Refresh is tested
[ ] CloudWatch alarms monitor unhealthy targets
[ ] Service quotas are reviewed
[ ] Database connection limits are considered
[ ] Cleanup and rollback processes exist
```

---

# 32. Critical architecture warning: scaling one layer can overload another

Suppose:

```text
Each EC2 instance opens 50 database connections.
Maximum ASG size is 20.
```

Potential database connections:

```text
20 × 50 = 1,000 connections
```

But the database may support only:

```text
500 safe application connections
```

Auto Scaling the application may therefore overload the database.

Always evaluate:

```text
EC2 capacity
Database connections
NAT Gateway ports
Third-party API rate limits
Cache throughput
SQS processing limits
License limits
Downstream service quotas
```

Auto Scaling does not automatically make every dependency scalable.

---

# 33. Certification-focused understanding

For AWS Cloud Practitioner:

```text
Auto Scaling improves elasticity and availability.
It can add or remove EC2 capacity according to demand.
```

For Solutions Architect Associate:

```text
Understand:
Min, desired and max capacity
Launch templates
Multi-AZ design
ALB target groups
Health checks
Target tracking
Scheduled scaling
Scaling metrics
Spot and On-Demand mixing
```

For DevOps Engineer Professional:

```text
Understand:
Instance Refresh
Lifecycle hooks
Immutable deployments
Deployment safety
Custom CloudWatch metrics
Predictive scaling
EventBridge automation
Rollback
Observability
Warm pools
Mixed instance policies
Scaling-process troubleshooting
```

---

# 34. Interview questions

## Question 1: What is the difference between desired and minimum capacity?

**Answer:**

Minimum capacity is the lowest capacity the Auto Scaling group is allowed to reach. Desired capacity is the capacity the group is currently trying to maintain. Desired capacity may change because of scaling policies, scheduled actions or manual updates, but normally remains between minimum and maximum capacity.

## Question 2: Can Auto Scaling replace an unhealthy application server?

**Answer:**

Yes, when the Auto Scaling group uses load-balancer health checks. The ALB detects that the application target is unhealthy, and Auto Scaling can mark and replace the instance after applicable grace-period behavior.

## Question 3: Why use ELB health checks instead of only EC2 health checks?

**Answer:**

An instance can pass EC2 infrastructure checks while its application process is unavailable. ELB health checks call an application endpoint and therefore provide application-level health information.

## Question 4: What metric should a web API use for scaling?

**Answer:**

It depends on its bottleneck. CPU may work for CPU-bound applications, while ALB request count per target may better represent traffic-driven applications. The metric should respond proportionally when the fleet size changes.

## Question 5: What is instance warmup?

**Answer:**

It is the period during which newly launched instances are given time to initialize before scaling logic fully considers their metrics for subsequent scaling decisions.

## Question 6: What is Instance Refresh?

**Answer:**

Instance Refresh performs a controlled rolling replacement of instances in an Auto Scaling group, commonly after updating an AMI or launch-template version.

## Question 7: Why place ASG instances in private subnets?

**Answer:**

Users should access the application through the load balancer. Private instances reduce direct internet exposure, while the instance security group accepts application traffic only from the load balancer security group.

## Question 8: What is the difference between predictive and dynamic scaling?

**Answer:**

Predictive scaling forecasts recurring demand and adds capacity in advance. Dynamic scaling reacts to observed CloudWatch metrics. They can be combined.

---

# 35. Never-forget revision

```text
Launch Template:
Defines one EC2 instance.

Auto Scaling Group:
Manages the fleet.

Minimum:
Never scale below this value.

Desired:
Capacity AWS currently attempts to maintain.

Maximum:
Never normally scale above this value.

ALB:
Distributes traffic.

Target Group:
Contains the application targets.

Health Check:
Determines whether a target should receive traffic.

Grace Period:
Allows a new instance time to start before health replacement.

Instance Warmup:
Allows new capacity time to become useful before further scaling decisions.

Target Tracking:
Maintains a metric near a target.

Step Scaling:
Uses different scaling actions for different alarm severities.

Scheduled Scaling:
Changes capacity at known times.

Predictive Scaling:
Forecasts recurring future demand.

Instance Refresh:
Rolls new launch-template or AMI configuration through the fleet.

Lifecycle Hook:
Pauses launch or termination for custom automation.

Warm Pool:
Keeps pre-initialized instances ready for faster scale-out.
```

## One-line memory trick

```text
ALB manages traffic.
ASG manages capacity.
Launch Template defines servers.
CloudWatch provides the signal.
Scaling Policy makes the decision.
```

## Lesson 24 outcome

You can now design an architecture where:

```text
One instance fails    → It is replaced.
Traffic increases     → More instances launch.
Traffic decreases     → Unneeded instances terminate.
One AZ has problems   → Other AZ capacity continues.
A new AMI is released → Instance Refresh rolls it out.
```

**Next lesson: Lesson 25 — Amazon RDS, Multi-AZ, Read Replicas, backups, failover, connection design and production database architecture.**

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/shared-responsibility-model-for-resiliency.html?utm_source=chatgpt.com "Shared Responsibility Model for Resiliency - Reliability Pillar"
[2]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html?utm_source=chatgpt.com "Auto Scaling groups"
[3]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scale-based-on-demand.html?utm_source=chatgpt.com "Dynamic scaling for Amazon EC2 Auto Scaling"
[4]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/predictive-scaling-policy-overview.html?utm_source=chatgpt.com "How predictive scaling works - Amazon EC2 Auto Scaling"
[5]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html?utm_source=chatgpt.com "Auto Scaling launch templates"
[6]: https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_fault_isolation_multiaz_region_system.html?utm_source=chatgpt.com "REL10-BP01 Deploy the workload to multiple locations - AWS Well-Architected Framework"
[7]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html?utm_source=chatgpt.com "What is an Application Load Balancer? - Elastic Load Balancing"
[8]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/autoscaling-load-balancer.html?utm_source=chatgpt.com "Use Elastic Load Balancing to distribute incoming ..."
[9]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-register-targets.html?utm_source=chatgpt.com "Register targets with your Application Load Balancer target group - Elastic Load Balancing"
[10]: https://docs.aws.amazon.com/en_en/elasticloadbalancing/latest/application/target-group-health-checks.html?utm_source=chatgpt.com "Health checks for Application Load Balancer target groups - Elastic Load Balancing"
[11]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-overview.html?utm_source=chatgpt.com "How an instance refresh works in an Auto Scaling group - Amazon EC2 Auto Scaling"
[12]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scaling-cooldowns.html?utm_source=chatgpt.com "Scaling cooldowns for Amazon EC2 Auto Scaling"
[13]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html?utm_source=chatgpt.com "Target tracking scaling policies for Amazon EC2 Auto Scaling - Amazon EC2 Auto Scaling"
[14]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html?utm_source=chatgpt.com "Step and simple scaling policies for Amazon EC2 Auto ..."
[15]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html?utm_source=chatgpt.com "Scheduled scaling for Amazon EC2 Auto Scaling"
[16]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-predictive-scaling.html?utm_source=chatgpt.com "Predictive scaling for Amazon EC2 Auto Scaling"
[17]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-using-sqs-queue.html?utm_source=chatgpt.com "Scaling policy based on Amazon SQS"
[18]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/what-is-amazon-ec2-auto-scaling.html?utm_source=chatgpt.com "What is Amazon EC2 Auto Scaling?"
[19]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html?utm_source=chatgpt.com "Decrease latency for applications with long boot times using warm pools - Amazon EC2 Auto Scaling"
[20]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html?utm_source=chatgpt.com "Required AWS KMS key policy for use with encrypted ..."
[21]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-suspend-resume-processes.html?utm_source=chatgpt.com "Suspend and resume Amazon EC2 Auto Scaling processes"
