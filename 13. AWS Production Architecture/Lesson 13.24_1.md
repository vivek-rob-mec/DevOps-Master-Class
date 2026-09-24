# Lesson 24 — EC2 Auto Scaling: Production Continuation

## Safe Rolling Deployments with Instance Refresh, Lifecycle Hooks, and Warm Pools

So far, Auto Scaling has helped us:

* Maintain a required number of EC2 instances.
* Replace unhealthy instances.
* Scale out when traffic increases.
* Scale in when traffic decreases.
* Distribute instances across Availability Zones.

But production systems have another important problem:

> How do we update every EC2 instance without taking the application offline?

Suppose your Auto Scaling group currently runs:

```text
Launch Template version 6
AMI: ami-old
Application version: v1.4
Instances: 4
```

You create:

```text
Launch Template version 7
AMI: ami-new
Application version: v1.5
```

Changing the launch template does **not automatically rebuild all existing instances**. Existing instances continue using the configuration with which they were originally launched.

For controlled replacement, we use **EC2 Auto Scaling Instance Refresh**.

---

# 1. What Is Instance Refresh?

Instance Refresh gradually replaces existing instances in an Auto Scaling group with instances using a new configuration.

```text
Existing fleet
┌─────────┬─────────┬─────────┬─────────┐
│ LT v6   │ LT v6   │ LT v6   │ LT v6   │
└─────────┴─────────┴─────────┴─────────┘

                    ↓ Instance Refresh

Temporary mixed fleet
┌─────────┬─────────┬─────────┬─────────┐
│ LT v7   │ LT v7   │ LT v6   │ LT v6   │
└─────────┴─────────┴─────────┴─────────┘

                    ↓

Updated fleet
┌─────────┬─────────┬─────────┬─────────┐
│ LT v7   │ LT v7   │ LT v7   │ LT v7   │
└─────────┴─────────┴─────────┴─────────┘
```

Instance Refresh supports:

* Rolling replacements.
* Minimum and maximum healthy percentages.
* Instance warm-up periods.
* Deployment checkpoints.
* Checkpoint delays.
* Bake time.
* Skip matching.
* Automatic rollback.
* CloudWatch alarm monitoring.

Checkpoints pause the refresh at selected percentages, while bake time keeps the deployment in a validation state after all replacements have finished. AWS can also skip instances that already match the desired configuration. ([AWS Documentation][1])

---

# 2. Minimum and Maximum Healthy Percentage

These two values control the availability and speed of your deployment.

Assume:

```text
Desired capacity = 4
Minimum healthy percentage = 75%
Maximum healthy percentage = 125%
```

## Minimum healthy capacity

```text
4 × 75% = 3
```

At least three instances must remain healthy during the deployment.

## Maximum healthy capacity

```text
4 × 125% = 5
```

Auto Scaling can temporarily have up to five healthy or pending instances while performing replacements.

### Production interpretation

| Configuration              | Result                                                      |
| -------------------------- | ----------------------------------------------------------- |
| Minimum 100%, maximum 100% | New capacity cannot be added before old capacity is removed |
| Minimum 75%, maximum 100%  | Some capacity may be temporarily unavailable                |
| Minimum 100%, maximum 125% | New instance can launch before an old instance is removed   |
| Minimum 90%, maximum 110%  | Conservative production rolling deployment                  |
| Minimum 50%, maximum 150%  | Faster but more aggressive deployment                       |

For a critical web application behind an ALB, a strong starting point is:

```text
Minimum healthy: 100%
Maximum healthy: 125%
```

For a small lab with limited capacity:

```text
Minimum healthy: 50% or 75%
Maximum healthy: 100% or 125%
```

AWS defines the minimum as the percentage that must remain healthy and ready, while the maximum controls how much temporary capacity may exist during replacement. ([AWS Documentation][2])

---

# 3. Production Deployment Architecture

```text
Developer
    │
    ▼
Build application
    │
    ▼
Create immutable AMI
    │
    ▼
Create Launch Template version 7
    │
    ▼
Start Instance Refresh
    │
    ├── Launch new EC2 instance
    │
    ├── Run user data
    │
    ├── Wait for application startup
    │
    ├── Register with ALB target group
    │
    ├── Pass ALB health check
    │
    ├── Complete warm-up period
    │
    └── Terminate old instance
    │
    ▼
Repeat until fleet is updated
```

The key principle is:

> Do not deploy production application changes by manually SSHing into every Auto Scaling instance.

Instances should be disposable and reproducible from:

* An immutable AMI.
* A versioned launch template.
* A container image version.
* A controlled bootstrap process.
* Infrastructure as Code.

---

# 4. Hands-On Instance Refresh with AWS CLI

This example assumes:

* Region: `ap-south-1`
* Auto Scaling group: `prod-web-asg`
* A normal launch template, not a mixed instances policy.
* A working ALB target group.
* A new AMI has already been created.

Set the variables:

```bash
export AWS_REGION="ap-south-1"
export ASG_NAME="prod-web-asg"
export NEW_AMI_ID="ami-0123456789abcdef0"
```

## Step 1: Find the current launch template

```bash
LT_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_REGION" \
  --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId' \
  --output text)

CURRENT_VERSION=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_REGION" \
  --query 'AutoScalingGroups[0].LaunchTemplate.Version' \
  --output text)

echo "Launch template: $LT_ID"
echo "Current version: $CURRENT_VERSION"
```

Confirm that neither value is empty:

```bash
test -n "$LT_ID" && test "$LT_ID" != "None" || {
  echo "Launch template not found"
  exit 1
}
```

---

## Step 2: Create a new launch template version

Create the update file:

```bash
cat > launch-template-update.json <<EOF
{
  "ImageId": "$NEW_AMI_ID"
}
EOF
```

Create the new version from the current version:

```bash
NEW_VERSION=$(aws ec2 create-launch-template-version \
  --launch-template-id "$LT_ID" \
  --source-version "$CURRENT_VERSION" \
  --launch-template-data file://launch-template-update.json \
  --version-description "Production application deployment" \
  --region "$AWS_REGION" \
  --query 'LaunchTemplateVersion.VersionNumber' \
  --output text)

echo "New launch template version: $NEW_VERSION"
```

Validate it:

```bash
aws ec2 describe-launch-template-versions \
  --launch-template-id "$LT_ID" \
  --versions "$NEW_VERSION" \
  --region "$AWS_REGION" \
  --query 'LaunchTemplateVersions[0].{
    Version:VersionNumber,
    AMI:LaunchTemplateData.ImageId,
    InstanceType:LaunchTemplateData.InstanceType,
    Description:VersionDescription
  }' \
  --output table
```

---

# 5. Create the Instance Refresh Configuration

```bash
cat > instance-refresh.json <<EOF
{
  "AutoScalingGroupName": "$ASG_NAME",
  "Strategy": "Rolling",
  "DesiredConfiguration": {
    "LaunchTemplate": {
      "LaunchTemplateId": "$LT_ID",
      "Version": "$NEW_VERSION"
    }
  },
  "Preferences": {
    "MinHealthyPercentage": 75,
    "MaxHealthyPercentage": 125,
    "InstanceWarmup": 180,
    "CheckpointPercentages": [25, 50, 100],
    "CheckpointDelay": 300,
    "SkipMatching": true,
    "AutoRollback": true,
    "ScaleInProtectedInstances": "Ignore",
    "StandbyInstances": "Ignore",
    "BakeTime": 600
  }
}
EOF
```

## Meaning of each preference

### `MinHealthyPercentage`

```json
"MinHealthyPercentage": 75
```

At least 75% of desired capacity must remain healthy.

### `MaxHealthyPercentage`

```json
"MaxHealthyPercentage": 125
```

Permits temporary additional capacity during replacement.

### `InstanceWarmup`

```json
"InstanceWarmup": 180
```

After an instance becomes healthy, Auto Scaling waits 180 seconds before considering it fully warmed up.

This should represent the time required for:

* Application initialization.
* JVM or Node.js startup.
* Cache initialization.
* Database connection pools.
* CPU utilization stabilization.

### `CheckpointPercentages`

```json
"CheckpointPercentages": [25, 50, 100]
```

The refresh pauses after 25%, 50%, and 100% of instances have been updated.

### `CheckpointDelay`

```json
"CheckpointDelay": 300
```

Wait five minutes at every checkpoint before continuing.

During this window, operators can inspect:

* ALB target health.
* Application error rate.
* CPU and memory.
* HTTP 5xx responses.
* CloudWatch alarms.
* Application logs.

### `BakeTime`

```json
"BakeTime": 600
```

After all instances are replaced, wait ten additional minutes before marking the refresh successful.

### `SkipMatching`

```json
"SkipMatching": true
```

Instances already using the desired launch template configuration are not replaced.

Be careful: skip matching compares infrastructure configuration. It cannot determine whether unchanged user data downloaded a newer application build from somewhere else. When user data pulls “latest” code, disable skip matching or, preferably, use versioned artifacts. ([AWS Documentation][3])

### `AutoRollback`

```json
"AutoRollback": true
```

AWS attempts to return the group to its previous configuration if the refresh fails.

## Critical rollback rule

For reliable automatic rollback, specify a **numeric launch template version**:

```json
"Version": "7"
```

Avoid:

```json
"Version": "$Latest"
```

or:

```json
"Version": "$Default"
```

AWS documents that automatic rollback is not supported when an Auto Scaling group uses `$Latest` or `$Default`, when no desired configuration is supplied, or when certain SSM parameter-based AMI references are used. ([AWS Documentation][4])

---

# 6. Start the Refresh

```bash
REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --cli-input-json file://instance-refresh.json \
  --region "$AWS_REGION" \
  --query 'InstanceRefreshId' \
  --output text)

echo "Instance Refresh ID: $REFRESH_ID"
```

---

# 7. Monitor the Deployment

```bash
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name "$ASG_NAME" \
  --instance-refresh-ids "$REFRESH_ID" \
  --region "$AWS_REGION" \
  --query 'InstanceRefreshes[0].{
    Status:Status,
    Reason:StatusReason,
    PercentageComplete:PercentageComplete,
    InstancesRemaining:InstancesToUpdate,
    StartTime:StartTime,
    EndTime:EndTime
  }' \
  --output table
```

Useful refresh states include:

```text
Pending
InProgress
Baking
Successful
Failed
Cancelling
Cancelled
RollbackInProgress
RollbackSuccessful
RollbackFailed
```

The percentage only increases after a replacement instance becomes healthy and completes the configured warm-up period. ([AWS Documentation][4])

Watch continuously:

```bash
watch -n 15 "
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name '$ASG_NAME' \
  --instance-refresh-ids '$REFRESH_ID' \
  --region '$AWS_REGION' \
  --query 'InstanceRefreshes[0].[Status,PercentageComplete,InstancesToUpdate,StatusReason]' \
  --output table
"
```

---

# 8. Inspect the EC2 Fleet

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_REGION" \
  --query 'AutoScalingGroups[0].Instances[].{
    InstanceId:InstanceId,
    Health:HealthStatus,
    Lifecycle:LifecycleState,
    LaunchTemplateVersion:LaunchTemplate.Version
  }' \
  --output table
```

During the deployment, you should see a mixture:

```text
Instance       Health    Lifecycle   Version
i-old-01       Healthy   InService   6
i-old-02       Healthy   InService   6
i-new-01       Healthy   InService   7
i-new-02       Healthy   InService   7
```

At completion:

```text
Instance       Health    Lifecycle   Version
i-new-01       Healthy   InService   7
i-new-02       Healthy   InService   7
i-new-03       Healthy   InService   7
i-new-04       Healthy   InService   7
```

---

# 9. Validate ALB Target Health

Set your target group ARN:

```bash
export TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/prod-web/abc123"
```

Check targets:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --region "$AWS_REGION" \
  --query 'TargetHealthDescriptions[].{
    Instance:Target.Id,
    Port:Target.Port,
    State:TargetHealth.State,
    Reason:TargetHealth.Reason,
    Description:TargetHealth.Description
  }' \
  --output table
```

Expected:

```text
State: healthy
```

Also test the application:

```bash
curl -fsS https://yourdatascientist.tech/health
```

Example response:

```json
{
  "status": "healthy",
  "version": "1.5.0"
}
```

Auto Scaling can replace instances based on EC2, Elastic Load Balancing, EBS, VPC Lattice, and custom health signals. For an ALB-backed application, configure the ASG health check type as `ELB`; otherwise, EC2 Auto Scaling does not automatically treat every failed load-balancer health check as grounds for replacement. ([AWS Documentation][5])

---

# 10. Cancel a Bad Deployment

When the deployment is still running:

```bash
aws autoscaling cancel-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --region "$AWS_REGION"
```

Important distinction:

```text
Cancel:
Stops additional replacements.

Rollback:
Returns updated instances and ASG configuration toward the previous version.
```

Cancellation does not necessarily restore instances already replaced.

With `AutoRollback: true`, a qualifying refresh failure can initiate automatic rollback.

---

# 11. Lifecycle Hooks

Instance Refresh controls **which instances are replaced and how quickly**.

Lifecycle hooks control **what must happen before an instance enters or leaves service**.

## Normal launch lifecycle

```text
Pending
   │
   ▼
Pending:Proceed
   │
   ▼
InService
```

## Launch lifecycle with a hook

```text
Pending
   │
   ▼
Pending:Wait
   │
   ├── Install application
   ├── Download configuration
   ├── Register monitoring agent
   ├── Run readiness test
   └── Signal completion
   │
   ▼
Pending:Proceed
   │
   ▼
InService
```

Lifecycle hooks place an instance into a wait state. The default waiting period is one hour unless another timeout is configured. A launch hook can return `CONTINUE`, allowing the instance to proceed, or `ABANDON`, causing a failed launch instance to be terminated. ([AWS Documentation][6])

---

# 12. Create a Launch Lifecycle Hook

```bash
aws autoscaling put-lifecycle-hook \
  --lifecycle-hook-name "wait-for-application-readiness" \
  --auto-scaling-group-name "$ASG_NAME" \
  --lifecycle-transition "autoscaling:EC2_INSTANCE_LAUNCHING" \
  --heartbeat-timeout 900 \
  --default-result "ABANDON" \
  --region "$AWS_REGION"
```

This means:

```text
New instance enters Pending:Wait
Maximum wait: 15 minutes
Successful bootstrap: CONTINUE
Timeout or failure: ABANDON
```

View it:

```bash
aws autoscaling describe-lifecycle-hooks \
  --auto-scaling-group-name "$ASG_NAME" \
  --region "$AWS_REGION" \
  --output table
```

---

# 13. Complete the Lifecycle Action

After application readiness succeeds:

```bash
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name "wait-for-application-readiness" \
  --auto-scaling-group-name "$ASG_NAME" \
  --instance-id "$INSTANCE_ID" \
  --lifecycle-action-result "CONTINUE" \
  --region "$AWS_REGION"
```

When bootstrap fails:

```bash
aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name "wait-for-application-readiness" \
  --auto-scaling-group-name "$ASG_NAME" \
  --instance-id "$INSTANCE_ID" \
  --lifecycle-action-result "ABANDON" \
  --region "$AWS_REGION"
```

For a launch hook:

```text
CONTINUE → instance proceeds toward InService
ABANDON  → instance is terminated and replaced
```

---

# 14. Readiness Script Example

The instance could run a script similar to:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

ASG_NAME="prod-web-asg"
HOOK_NAME="wait-for-application-readiness"
REGION="ap-south-1"

TOKEN=$(curl -sS -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/instance-id")

for attempt in $(seq 1 30); do
  if curl -fsS http://localhost:3000/health >/dev/null; then
    aws autoscaling complete-lifecycle-action \
      --lifecycle-hook-name "$HOOK_NAME" \
      --auto-scaling-group-name "$ASG_NAME" \
      --instance-id "$INSTANCE_ID" \
      --lifecycle-action-result CONTINUE \
      --region "$REGION"

    exit 0
  fi

  sleep 10
done

aws autoscaling complete-lifecycle-action \
  --lifecycle-hook-name "$HOOK_NAME" \
  --auto-scaling-group-name "$ASG_NAME" \
  --instance-id "$INSTANCE_ID" \
  --lifecycle-action-result ABANDON \
  --region "$REGION"

exit 1
```

The instance profile requires permission such as:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CompleteAutoScalingLifecycleAction",
      "Effect": "Allow",
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:RecordLifecycleActionHeartbeat"
      ],
      "Resource": "*"
    }
  ]
}
```

In production, restrict the resource and conditions wherever the AWS API supports doing so.

---

# 15. Termination Lifecycle Hook

A termination hook pauses an instance before termination.

Use cases:

* Flush application logs.
* Drain work from a queue.
* Finish a background job.
* Remove the instance from an external registry.
* Upload diagnostic information.
* Notify an external deployment system.

Create it:

```bash
aws autoscaling put-lifecycle-hook \
  --lifecycle-hook-name "graceful-instance-termination" \
  --auto-scaling-group-name "$ASG_NAME" \
  --lifecycle-transition "autoscaling:EC2_INSTANCE_TERMINATING" \
  --heartbeat-timeout 600 \
  --default-result "CONTINUE" \
  --region "$AWS_REGION"
```

Lifecycle flow:

```text
InService
    │
    ▼
Terminating:Wait
    │
    ├── Stop accepting new jobs
    ├── Finish current work
    ├── Flush logs
    └── Signal completion
    │
    ▼
Terminating:Proceed
    │
    ▼
Terminated
```

For termination hooks, both `CONTINUE` and `ABANDON` eventually allow termination, but `ABANDON` skips remaining lifecycle actions. ([AWS Documentation][6])

---

# 16. Terraform Production Configuration

```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "prod-web-"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  update_default_version = true

  user_data = base64encode(templatefile(
    "${path.module}/user-data.sh",
    {
      environment = "production"
    }
  ))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "prod-web"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}
```

Auto Scaling group:

```hcl
resource "aws_autoscaling_group" "web" {
  name = "prod-web-asg"

  min_size         = 2
  desired_capacity = 4
  max_size         = 6

  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.web.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180

  launch_template {
    id = aws_launch_template.web.id

    # Use the concrete Terraform-managed version.
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 75
      max_healthy_percentage = 125

      instance_warmup = 180

      checkpoint_percentages = [25, 50, 100]
      checkpoint_delay       = 300

      skip_matching = true
      auto_rollback = true

      scale_in_protected_instances = "Ignore"
      standby_instances            = "Ignore"

      bake_time = 600
    }
  }

  tag {
    key                 = "Name"
    value               = "prod-web-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

The important line is:

```hcl
version = aws_launch_template.web.latest_version
```

Do not use this when you expect Terraform to detect every launch-template update:

```hcl
version = "$Latest"
```

The current AWS provider documentation specifically recommends referencing the Terraform resource’s `latest_version` when the launch template must trigger instance replacement. Launch-template and mixed-instance-policy changes are automatically considered by the instance-refresh mechanism; `triggers` is for additional properties such as tags. ([Terraform Registry][7])

---

# 17. Terraform Lifecycle Hook

```hcl
resource "aws_autoscaling_lifecycle_hook" "launch" {
  name                   = "wait-for-application-readiness"
  autoscaling_group_name = aws_autoscaling_group.web.name

  lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout    = 900
  default_result       = "ABANDON"
}
```

For an existing group, the standalone resource is appropriate.

For a newly created group where the hook must exist **before the first instances launch**, use `initial_lifecycle_hook` inside `aws_autoscaling_group`. Otherwise, the ASG might launch its initial instances before Terraform creates the standalone lifecycle-hook resource. ([Terraform Registry][7])

---

# 18. Warm Pools

A warm pool maintains pre-initialized EC2 instances beside the Auto Scaling group.

```text
                    Auto Scaling Group
                  ┌─────────────────────┐
Traffic ──ALB───▶ │ InService instances │
                  └─────────────────────┘
                            ▲
                            │ scale out
                  ┌─────────────────────┐
                  │     Warm pool       │
                  │ pre-initialized EC2 │
                  └─────────────────────┘
```

Warm pools are useful when application startup is slow because of:

* Large software installation.
* JVM startup.
* Machine-learning model loading.
* Cache initialization.
* Windows boot and configuration.
* Large container-image downloads.

If the warm pool is empty during scale-out, Auto Scaling falls back to launching a normal cold instance. ([AWS Documentation][8])

Terraform example:

```hcl
resource "aws_autoscaling_group" "web" {
  # Existing ASG configuration...

  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = 2
    max_group_prepared_capacity = 6

    instance_reuse_policy {
      reuse_on_scale_in = true
    }
  }
}
```

With reuse enabled:

```text
Scale out:
Warm pool → Auto Scaling group

Scale in:
Auto Scaling group → Warm pool
```

Without reuse:

```text
Scale in:
Auto Scaling group → Terminated
```

---

# 19. Production Troubleshooting Matrix

| Problem                                             | Likely reason                                         | Fix                                                               |
| --------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------- |
| Refresh stuck at 0%                                 | New instance has not completed warm-up                | Inspect `StatusReason` and startup logs                           |
| Instance repeatedly replaced                        | ALB health check is failing                           | Verify path, port, security groups and application binding        |
| Instance stuck in `Pending:Wait`                    | Lifecycle action was never completed                  | Call `complete-lifecycle-action` or fix EventBridge/Lambda worker |
| Automatic rollback does not start                   | `$Latest`, `$Default`, or no desired configuration    | Use a numeric launch-template version                             |
| Terraform apply changes template but not instances  | ASG uses literal `$Latest`                            | Reference `aws_launch_template.resource.latest_version`           |
| New code is not deployed                            | `SkipMatching=true` and infrastructure did not change | Disable skip matching or use versioned AMI/artifact               |
| Refresh waits and later fails                       | Standby or scale-in-protected instances use `Wait`    | Return instances to service or remove protection                  |
| New instance is healthy in EC2 but unhealthy in ALB | EC2 status checks do not test the application         | Configure `health_check_type = "ELB"`                             |
| Lifecycle launches slow down dramatically           | Hooks repeatedly fail or time out                     | Correct the hook worker and heartbeat logic                       |
| Old and new versions return different results       | Non-versioned configuration or dependency             | Pin application and configuration versions                        |

When `Wait` is selected for standby or scale-in-protected instances, the refresh waits for operator action and can fail after one hour if those instances remain blocked. ([AWS Documentation][9])

---

# 20. Interview Questions

## What is the difference between scaling and instance refresh?

**Scaling** changes the number of instances based on demand.

**Instance Refresh** replaces existing instances to deploy a new launch configuration while generally maintaining the requested capacity.

---

## Why use a launch template version instead of `$Latest`?

A numeric or Terraform-managed version gives the deployment an immutable, identifiable configuration and supports safer comparison and rollback behavior.

---

## What is instance warm-up?

It is the period after a replacement instance becomes healthy during which Auto Scaling waits before counting that instance as fully updated and continuing replacement.

---

## What is the difference between health-check grace period and instance warm-up?

```text
Health-check grace period:
Prevents premature unhealthy replacement after launch.

Instance warm-up:
Controls when the instance contributes to scaling metrics or when
Instance Refresh treats it as fully initialized.
```

---

## What does a lifecycle hook do?

It pauses an instance during launch or termination so that custom automation can complete before the instance continues through its lifecycle.

---

## When should `ABANDON` be used?

For a launch hook, use `ABANDON` when bootstrap or application-readiness checks fail and the instance must not enter service.

---

## What is the purpose of bake time?

Bake time provides a final observation window after all replacements have completed but before the deployment is marked successful.

---

## Why can skip matching be dangerous?

It compares instance infrastructure configuration, not the actual application state. An instance might match the launch template while still running outdated application code downloaded through non-versioned user data.

---

# Never-Forget Points

```text
Scaling changes quantity.
Instance Refresh changes the fleet version.
```

```text
Launch Template = recipe
AMI = machine image
ASG = fleet manager
Instance Refresh = rolling fleet upgrade
Lifecycle Hook = controlled pause
Warm Pool = pre-initialized standby capacity
```

```text
EC2 healthy does not always mean application healthy.
Use ALB health checks for an ALB-backed application.
```

```text
Use immutable, numeric launch-template versions for reliable rollback.
Avoid depending on $Latest in production deployments.
```

```text
A lifecycle hook must always have a completion path,
timeout strategy and failure result.
```

```text
A successful infrastructure deployment is not complete until:
1. Targets are healthy.
2. Application requests succeed.
3. Error rates remain acceptable.
4. Logs show no new failures.
5. The bake period completes.
```

## Resume-Ready Takeaway

> Implemented highly available EC2 Auto Scaling deployments using versioned launch templates, rolling Instance Refresh, health-percentage controls, checkpoints, bake periods, automatic rollback, ALB health validation, lifecycle hooks, and warm pools for controlled application startup and termination.

**Next continuation:** EC2 Auto Scaling mixed-instance groups, On-Demand and Spot capacity, capacity rebalance, interruption handling, allocation strategies, and production cost optimization.

[1]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/instance-refresh-overview.html?utm_source=chatgpt.com "How an instance refresh works in an Auto Scaling group - Amazon EC2 Auto Scaling"
[2]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/understand-instance-refresh-default-values.html?utm_source=chatgpt.com "Understand the default values for an instance refresh - Amazon EC2 Auto Scaling"
[3]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh-skip-matching.html?utm_source=chatgpt.com "Use an instance refresh with skip matching - Amazon EC2 Auto Scaling"
[4]: https://docs.aws.amazon.com/cli/latest/reference/autoscaling/describe-instance-refreshes.html?utm_source=chatgpt.com "describe-instance-refreshes — AWS CLI 2.36.2 Command Reference"
[5]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-health-checks.html?utm_source=chatgpt.com "Health checks for instances in an Auto Scaling group - Amazon EC2 Auto Scaling"
[6]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html?utm_source=chatgpt.com "Amazon EC2 Auto Scaling lifecycle hooks - Amazon EC2 Auto Scaling"
[7]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group?utm_source=chatgpt.com "aws_autoscaling_group | Resources | hashicorp/aws | Terraform"
[8]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html?utm_source=chatgpt.com "Decrease latency for applications with long boot times using warm pools - Amazon EC2 Auto Scaling"
[9]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/start-instance-refresh.html?utm_source=chatgpt.com "Start an instance refresh using the AWS Management Console or AWS CLI - Amazon EC2 Auto Scaling"
