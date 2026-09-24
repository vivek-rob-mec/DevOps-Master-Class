# Lesson 24 — Final Production Hands-On Lab

## ALB + Private EC2 + Mixed On-Demand/Spot ASG + Target Tracking + Instance Refresh

This is where we convert all the Auto Scaling theory into one working architecture.

AWS confirms that instances attached to an ASG target group are automatically registered/deregistered, and enabling ELB health checks allows the ASG to replace instances that the load balancer reports unhealthy. Capacity Rebalancing can proactively replace Spot instances at elevated interruption risk. ([AWS Documentation][1])

---

## 1. Architecture We Are Building

```text
                              Internet
                                 │
                                 ▼
                        Application Load
                            Balancer
                                 │
                  ┌──────────────┴──────────────┐
                  │                             │
             Public Subnet A               Public Subnet B
                  │                             │
                  └──────────────┬──────────────┘
                                 │
                            Target Group
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
                   ▼                           ▼
             Private Subnet A            Private Subnet B
                EC2                           EC2
                 │                             │
                 └────────────┬────────────────┘
                              │
                    Auto Scaling Group
                              │
                    Mixed Instances Policy
                       │              │
                  On-Demand         Spot
                       │              │
                       └──────┬───────┘
                              │
                     t3.micro / t3a.micro
                              │
                  Target Tracking Scaling
                              │
                     CPU target = 50%
                              │
                    Capacity Rebalance
                              │
                     Instance Refresh
                              │
                         CloudWatch
```

For the lab:

```text
Region          = ap-south-1
Min             = 2
Desired         = 2
Max             = 4

On-Demand base  = 1
Spot above base = 100%

Scaling metric  = ASGAverageCPUUtilization
Target          = 50%
```

So normally we expect approximately:

```text
2 EC2 instances
│
├── 1 On-Demand
└── 1 Spot
```

AWS recommends multiple instance types and Capacity Rebalancing for mixed Spot fleets; `price-capacity-optimized` is designed to consider both capacity availability and price. ([AWS Documentation][2])

---

# 2. Project Structure

Create:

```bash
mkdir lesson24-asg-lab
cd lesson24-asg-lab
```

Structure:

```text
lesson24-asg-lab/
│
├── versions.tf
├── variables.tf
├── network.tf
├── security.tf
├── iam.tf
├── compute.tf
├── scaling.tf
├── outputs.tf
├── terraform.tfvars
└── user_data.sh
```

---

# 3. Terraform Provider

## `versions.tf`

```hcl
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

We are using the current AWS provider 6.x generation rather than old 5.x-era examples. ([Terraform Registry][3])

---

# 4. Variables

## `variables.tf`

```hcl
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "lesson24-asg"
}

variable "app_version" {
  type    = string
  default = "v1"
}
```

## `terraform.tfvars`

```hcl
aws_region   = "ap-south-1"
project_name = "lesson24-asg"
app_version  = "v1"
```

Later we will deliberately change:

```text
v1 → v2
```

and watch Instance Refresh replace the fleet.

---

# 5. Networking

## `network.tf`

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.24.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ------------------------
# Public Subnets
# ------------------------

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.24.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.24.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-b"
  }
}

# ------------------------
# Private Subnets
# ------------------------

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.24.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.24.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-b"
  }
}

# ------------------------
# Public Route Table
# ------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------
# NAT Gateway
# ------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
```

### Production note

We use **one NAT Gateway** to keep the lab simpler.

A higher-availability production design would commonly use:

```text
AZ-A → NAT-A
AZ-B → NAT-B
```

so an AZ/NAT failure doesn't remove outbound connectivity from both private subnets.

---

# 6. Security Groups

## `security.tf`

```hcl
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow ALB traffic to application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP only from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Notice something important:

```text
EC2 port 80
source =
ALB Security Group
```

Not:

```text
0.0.0.0/0
```

The EC2 instances themselves do not need direct Internet ingress.

---

# 7. IAM + Systems Manager

We won't open:

```text
SSH :22
```

Instead we'll use:

```text
AWS Systems Manager
```

## `iam.tf`

```hcl
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2.name
}
```

---

# 8. User Data

## `user_data.sh`

```bash
#!/bin/bash

set -euxo pipefail

dnf install -y nginx

TOKEN=$(curl -fsS -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

HOSTNAME=$(hostname)

cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Lesson 24 ASG Lab</title>
</head>

<body>
    <h1>AWS Auto Scaling Production Lab</h1>

    <p>Application Version: ${app_version}</p>

    <p>Instance ID: $INSTANCE_ID</p>

    <p>Availability Zone: $AZ</p>

    <p>Hostname: $HOSTNAME</p>
</body>
</html>
EOF

echo "healthy" > /usr/share/nginx/html/health

systemctl enable nginx
systemctl restart nginx
```

We're using IMDSv2 rather than an unauthenticated metadata call.

---

# 9. Amazon Linux 2023 AMI

Here's another production improvement.

Don't put:

```hcl
image_id = "ami-xxxxxxxx"
```

because Mumbai's latest AMI ID changes.

Instead:

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
```

AWS documents this public SSM parameter as a way to resolve the latest AL2023 x86-64 AMI for the Region. ([AWS Documentation][4])

---

# 10. ALB + Launch Template + ASG

## `compute.tf`

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --------------------------------------------------
# Application Load Balancer
# --------------------------------------------------

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

# --------------------------------------------------
# Target Group
# --------------------------------------------------

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30
}

# --------------------------------------------------
# ALB Listener
# --------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --------------------------------------------------
# Launch Template
# --------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix = "${var.project_name}-"

  image_id = data.aws_ssm_parameter.al2023.value

  update_default_version = true

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(
    templatefile(
      "${path.module}/user_data.sh",
      {
        app_version = var.app_version
      }
    )
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-instance"
      Environment = "lab"
      ManagedBy   = "Terraform"
      Version     = var.app_version
    }
  }
}

# --------------------------------------------------
# Auto Scaling Group
# --------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  default_instance_warmup = 60

  capacity_rebalance = true

  mixed_instances_policy {

    launch_template {

      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = aws_launch_template.app.latest_version
      }

      override {
        instance_type = "t3.micro"
      }

      override {
        instance_type = "t3a.micro"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0

      on_demand_allocation_strategy = "lowest-price"

      spot_allocation_strategy = "price-capacity-optimized"
    }
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 150

      instance_warmup = 60

      skip_matching = true
      auto_rollback = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_listener.http
  ]
}
```

HashiCorp's current ASG resource supports mixed-instance policies, instance refresh configuration, target-group attachment, and Capacity Rebalancing. ([Terraform Registry][5])

---

# 11. Target Tracking Scaling Policy

## `scaling.tf`

```hcl
resource "aws_autoscaling_policy" "cpu_target" {
  name = "${var.project_name}-cpu-target"

  autoscaling_group_name = aws_autoscaling_group.app.name

  policy_type = "TargetTrackingScaling"

  estimated_instance_warmup = 60

  target_tracking_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0

    disable_scale_in = false
  }
}
```

Our intention is:

```text
CPU > ~50%
      ↓
ASG attempts scale out


CPU substantially below target
      ↓
ASG can eventually scale in
```

Target tracking continuously adjusts capacity toward the configured utilization target rather than requiring us to manually define every scaling step. ([Terraform Registry][6])

---

# 12. Outputs

## `outputs.tf`

```hcl
output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}

output "launch_template_version" {
  value = aws_launch_template.app.latest_version
}
```

---

# 13. Validate Terraform Before Creating Anything

Run:

```bash
terraform fmt -recursive
```

Then:

```bash
terraform init
```

Then:

```bash
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

Create the plan:

```bash
terraform plan -out=tfplan
```

Read the plan.

Check especially for:

```text
VPC
4 subnets
IGW
NAT Gateway
ALB
Target Group
Launch Template
IAM role/profile
ASG
Scaling policy
```

Then:

```bash
terraform apply tfplan
```

---

# 14. First Validation

Get ALB DNS:

```bash
ALB=$(terraform output -raw alb_dns_name)

echo "$ALB"
```

Test:

```bash
curl http://$ALB
```

You should eventually receive something like:

```html
<h1>AWS Auto Scaling Production Lab</h1>

<p>Application Version: v1</p>

<p>Instance ID: i-012345678...</p>

<p>Availability Zone: ap-south-1a</p>
```

Run repeatedly:

```bash
for i in {1..10}; do
  curl -s http://$ALB | grep -E \
    "Application Version|Instance ID|Availability Zone"

  echo "----------------"
  sleep 2
done
```

You should see requests distributed across different instances.

---

# 15. Inspect the ASG

```bash
ASG=$(terraform output -raw asg_name)

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG" \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].{
    Min:MinSize,
    Desired:DesiredCapacity,
    Max:MaxSize,
    HealthCheck:HealthCheckType,
    CapacityRebalance:CapacityRebalance
  }' \
  --output table
```

Expected conceptually:

```text
Min                 2
Desired             2
Max                 4
HealthCheck         ELB
CapacityRebalance   True
```

---

# 16. Determine Which Instance Is Spot

Run:

```bash
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters \
    "Name=tag:aws:autoscaling:groupName,Values=$ASG" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{
     Instance:InstanceId,
     Type:InstanceType,
     Purchase:InstanceLifecycle,
     AZ:Placement.AvailabilityZone
  }' \
  --output table
```

You may see:

```text
Instance       Type        Purchase     AZ
-------------------------------------------------
i-aaa          t3.micro    None         ap-south-1a
i-bbb          t3a.micro   spot         ap-south-1b
```

Here:

```text
Purchase = spot
```

means Spot.

For an ordinary On-Demand instance, `InstanceLifecycle` is normally absent/null.

---

# 17. Validate Target Health

```bash
TG=$(terraform output -raw target_group_arn)

aws elbv2 describe-target-health \
  --target-group-arn "$TG" \
  --region ap-south-1 \
  --query 'TargetHealthDescriptions[].{
      Instance:Target.Id,
      State:TargetHealth.State,
      Reason:TargetHealth.Reason
  }' \
  --output table
```

Expected:

```text
Instance       State
-------------------------
i-aaa          healthy
i-bbb          healthy
```

ALB health checks are performed against registered target-group members, and with ELB health checks enabled on the ASG, ALB-reported unhealthy instances can be replaced automatically. ([AWS Documentation][7])

---

# 18. Hands-On Scaling Test

Now we'll deliberately consume CPU.

First get the current instances:

```bash
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG" \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' \
  --output text)

echo "$INSTANCE_IDS"
```

Create:

## `cpu-load.json`

```json
{
  "commands": [
    "nohup sh -c 'yes > /dev/null & yes > /dev/null & sleep 600; pkill yes' >/tmp/cpu-load.log 2>&1 &"
  ]
}
```

Run it with Systems Manager:

```bash
aws ssm send-command \
  --instance-ids $INSTANCE_IDS \
  --document-name "AWS-RunShellScript" \
  --parameters file://cpu-load.json \
  --region ap-south-1
```

Now monitor the group:

```bash
watch -n 15 "
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names '$ASG' \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].{
     Desired:DesiredCapacity,
     InService:length(Instances[?LifecycleState==\`InService\`]),
     Total:length(Instances)
  }' \
  --output table
"
```

And inspect scaling activities:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG" \
  --region ap-south-1 \
  --max-items 10 \
  --output table
```

Eventually you should see something conceptually like:

```text
Desired:

2
↓
3
↓
possibly 4
```

depending on sustained load.

### This is the important mental chain

```text
CPU rises
   ↓
CloudWatch metric
   ↓
Target Tracking
   ↓
DesiredCapacity increases
   ↓
ASG launches EC2
   ↓
EC2 bootstraps
   ↓
Target registers
   ↓
ALB health check
   ↓
InService
```

---

# 19. Stop CPU Load

If needed:

```bash
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG" \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' \
  --output text)
```

Then:

```bash
aws ssm send-command \
  --instance-ids $INSTANCE_IDS \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["pkill yes || true"]' \
  --region ap-south-1
```

Don't expect immediate scale-in.

Remember:

```text
Scale-out = aggressive

Scale-in = deliberately more conservative
```

because excessive scale-in can create oscillation and availability problems.

---

# 20. Failure Simulation — Break Nginx

This is one of the most valuable parts of the lab.

Pick an instance:

```bash
VICTIM=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG" \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "$VICTIM"
```

Stop nginx:

```bash
aws ssm send-command \
  --instance-ids "$VICTIM" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl stop nginx"]' \
  --region ap-south-1
```

Now watch target health:

```bash
watch -n 10 "
aws elbv2 describe-target-health \
  --target-group-arn '$TG' \
  --region ap-south-1 \
  --query 'TargetHealthDescriptions[].[
     Target.Id,
     TargetHealth.State,
     TargetHealth.Reason
  ]' \
  --output table
"
```

You should eventually see:

```text
healthy
   ↓
unhealthy
```

Then inspect ASG activity:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG" \
  --region ap-south-1 \
  --max-items 20 \
  --output table
```

The expected production behavior is:

```text
Nginx stopped
      ↓
/health fails
      ↓
ALB marks target unhealthy
      ↓
ASG sees ELB unhealthy
      ↓
ASG replaces instance
      ↓
new instance launches
      ↓
Nginx installs
      ↓
/health = 200
      ↓
new target becomes healthy
```

This is exactly why:

```hcl
health_check_type = "ELB"
```

matters. AWS otherwise defaults primarily to EC2 health signals rather than automatically using every ALB health failure for ASG replacement. ([AWS Documentation][8])

---

# 21. Now Perform a Real Rolling Deployment

Current version:

```text
v1
```

Modify:

```bash
nano terraform.tfvars
```

Change:

```hcl
app_version = "v1"
```

to:

```hcl
app_version = "v2"
```

Now:

```bash
terraform plan
```

Notice:

```text
Launch Template
      ↓
new version
```

Apply:

```bash
terraform apply
```

Because the ASG references the concrete Terraform-managed launch-template version and has an Instance Refresh strategy configured, this gives us a controlled fleet replacement pattern rather than manually SSHing into running machines. AWS Instance Refresh supports rolling replacement of existing ASG instances with a new desired configuration. ([Terraform Registry][5])

---

# 22. Watch Instance Refresh

```bash
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name "$ASG" \
  --region ap-south-1 \
  --query 'InstanceRefreshes[0].{
     Status:Status,
     Percentage:PercentageComplete,
     Remaining:InstancesToUpdate,
     Reason:StatusReason
  }' \
  --output table
```

Watch continuously:

```bash
watch -n 15 "
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name '$ASG' \
  --region ap-south-1 \
  --query 'InstanceRefreshes[0].{
     Status:Status,
     Percent:PercentageComplete,
     Remaining:InstancesToUpdate
  }' \
  --output table
"
```

Conceptually:

```text
v1    v1
│     │

        Instance Refresh
               ↓

v2    v1

               ↓

v2    v2
```

Our configuration:

```text
MinHealthy = 100%
MaxHealthy = 150%
```

means the deployment can temporarily add capacity instead of immediately sacrificing healthy capacity.

---

# 23. Validate v2

Run:

```bash
for i in {1..10}; do
  curl -s http://$ALB | grep -E \
    "Application Version|Instance ID|Availability Zone"

  echo "----------------------"

  sleep 2
done
```

At the end every response should show:

```text
Application Version: v2
```

That is a complete immutable-style deployment:

```text
Change application
      ↓
New Launch Template version
      ↓
New EC2
      ↓
Health validation
      ↓
Old EC2 removed
```

Not:

```text
SSH
↓
git pull
↓
npm install
↓
restart
↓
pray
```

---

# 24. Validate Capacity Rebalancing

Check:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG" \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].CapacityRebalance'
```

Expected:

```text
true
```

Capacity Rebalancing is specifically intended to proactively replace Spot instances after EC2 identifies elevated interruption risk. ([AWS Documentation][9])

We won't manufacture a genuine Spot interruption during the basic lab.

The mental flow is:

```text
Spot instance
      ↓
EC2 rebalance recommendation
      ↓
ASG Capacity Rebalance
      ↓
replacement Spot requested
      ↓
new capacity ready
      ↓
at-risk capacity removed
```

---

# 25. Real Production Troubleshooting Exercise

Suppose:

```text
Desired = 4
InService = 2
```

Your investigation should now be automatic:

```text
Scaling policy?
      ↓
Desired capacity?
      ↓
MaxSize?
      ↓
Scaling activity?
      ↓
Launch template?
      ↓
EC2 quota/capacity?
      ↓
Subnet IP space?
      ↓
Spot availability?
      ↓
User data?
      ↓
Lifecycle state?
      ↓
Target registration?
      ↓
Health checks?
      ↓
Application?
```

First command:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG" \
  --region ap-south-1 \
  --max-items 20
```

This command should become one of your **muscle-memory ASG troubleshooting commands**.

---

# 26. Cost Warning

This lab creates billable infrastructure, especially:

```text
EC2
ALB
NAT Gateway
Elastic/Public IPv4 resources
Spot/On-Demand compute
network traffic
```

So after completing the exercises, destroy it.

---

# 27. Cleanup

First:

```bash
terraform plan -destroy
```

Review carefully.

Then:

```bash
terraform destroy
```

Confirm:

```text
Enter a value: yes
```

Finally verify:

```bash
terraform state list
```

Ideally:

```text
<empty>
```

Also verify ASG:

```bash
aws autoscaling describe-auto-scaling-groups \
  --region ap-south-1 \
  --query "AutoScalingGroups[?AutoScalingGroupName=='lesson24-asg-asg']"
```

Expected:

```json
[]
```

Check load balancers if desired:

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1 \
  --query 'LoadBalancers[].LoadBalancerName'
```

And NAT Gateways:

```bash
aws ec2 describe-nat-gateways \
  --region ap-south-1 \
  --filter Name=state,Values=available,pending
```

Do **not** leave the NAT Gateway and ALB running just because the EC2 instances were destroyed.

---

# 28. What You Have Actually Learned

This lab connected almost the entire Auto Scaling lesson:

```text
VPC
 │
 ├── Public subnets
 │       ↓
 │      ALB
 │
 └── Private subnets
         ↓
        EC2
         ↓
   Launch Template
         ↓
  Mixed Instances
   │           │
On-Demand     Spot
   │           │
   └─────┬─────┘
         ↓
       ASG
         │
   ┌─────┼───────────────┐
   │     │               │
Scaling Health       Rebalancing
   │     │               │
   ▼     ▼               ▼
CPU    ALB          Spot resilience
   │
   ▼
Instance Refresh
   │
   ▼
Rolling Deployment
```

---

# 29. Interview-Level Explanation

If an interviewer asks:

> **How would you architect a cost-efficient, highly available EC2 web tier?**

You should now be able to say:

> I would place an Application Load Balancer across public subnets in multiple Availability Zones and run the application instances in private subnets inside an EC2 Auto Scaling group. I would use a versioned launch template, ELB health checks, target-tracking scaling, and a mixed instances policy with an On-Demand baseline and diversified Spot capacity. For Spot resilience I'd enable Capacity Rebalancing, and for deployments I'd use rolling Instance Refresh rather than modifying servers manually. Instance access would be handled through Systems Manager instead of exposing SSH.

That answer demonstrates architecture rather than just AWS vocabulary.

---

# 30. Lesson 24 — Never Forget

```text
Launch Template
=
HOW an instance is built.
```

```text
Auto Scaling Group
=
HOW MANY instances should exist.
```

```text
Scaling Policy
=
WHEN capacity changes.
```

```text
Target Group
=
WHERE ALB sends traffic.
```

```text
ELB Health Check
=
IS the application actually healthy?
```

```text
Mixed Instances
=
WHAT compute/purchase options may satisfy capacity.
```

```text
Capacity Rebalancing
=
PROACTIVELY replace risky Spot.
```

```text
Instance Refresh
=
SAFELY replace the fleet with a new version.
```

And the most important production rule:

```text
Desired state
        ↓
Actual capacity
        ↓
Healthy targets
        ↓
Successful requests

All four must agree.
```

## ✅ Lesson 24 complete

At this point, Auto Scaling should no longer mean merely:

> “CPU high → add EC2.”

You now understand it as a **fleet-management system involving capacity, health, deployment, availability, purchase models, networking, load balancing and failure recovery**.

Our next lesson continues the original AWS masterclass sequence from here rather than repeating Auto Scaling.

[1]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-register-targets.html?utm_source=chatgpt.com "Register targets with your Application Load Balancer target ..."
[2]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/mixed-instances-groups-set-up-overview.html?utm_source=chatgpt.com "Setup overview for creating a mixed instances group"
[3]: https://registry.terraform.io/providers/hashicorp/aws/latest?utm_source=chatgpt.com "hashicorp/aws - Terraform Registry"
[4]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami-parameter-store.html?utm_source=chatgpt.com "Reference the latest AMIs using Systems Manager public ..."
[5]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group?utm_source=chatgpt.com "aws_autoscaling_group - Terraform Registry"
[6]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy?utm_source=chatgpt.com "aws_autoscaling_policy | Resources | hashicorp/aws | Terraform"
[7]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html?utm_source=chatgpt.com "Target groups for your Application Load Balancers"
[8]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/attach-load-balancer-asg.html?utm_source=chatgpt.com "Attach an Elastic Load Balancing load balancer to your Auto ..."
[9]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-capacity-rebalancing.html?utm_source=chatgpt.com "Capacity Rebalancing in Auto Scaling to replace at-risk ..."
