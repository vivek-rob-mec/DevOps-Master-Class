AWS Masterclass — Lesson 23
Build Phase 3 — ALB, Target Group, ECS Cluster Foundation, CloudWatch Log Group, and Task Definition Skeleton

Today we continue your ~/aws-production-capstone Terraform build.

In Lesson 21, you created the VPC foundation.
In Lesson 22, you added security groups, private S3, CloudFront OAC design notes, and ECR.
Now we add the backend runtime foundation:

Application Load Balancer
  ↓
Target Group
  ↓
Future ECS Fargate service
  ↓
CloudWatch Logs
  ↓
ECS Task Definition Skeleton

Important cost warning: Application Load Balancer is billable while it is running, including hourly load balancer cost and LCU-related cost. Destroy it after the lab if you are not keeping the environment.

Goal

Create these Terraform modules/resources:

modules/load-balancer
  aws_lb
  aws_lb_target_group
  aws_lb_listener

modules/iam
  ECS task execution role
  ECS task role

modules/compute
  ECS cluster
  CloudWatch log group
  ECS task definition skeleton

We will not create the ECS service yet. That comes in the next phase.

Why? Because if we create a Fargate service now, private subnets need a path to pull images from ECR and send logs to CloudWatch. That usually means NAT Gateway or VPC endpoints. We will design that properly later instead of accidentally creating cost-heavy infrastructure.

Architecture after today
Internet
  ↓
Public ALB
  ↓ HTTP listener :80
Target Group
  target_type = ip
  health_check = /health
  port = 3000

ECS Cluster
  no running tasks yet

ECS Task Definition
  Fargate
  awsvpc
  image = ECR repo URI + bootstrap tag
  logs = CloudWatch Logs

For ECS tasks on Fargate, AWS requires awsvpc network mode, and when you create target groups for Fargate tasks, the target type must be ip, not instance.

Step 1 — Create module folders
cd ~/aws-production-capstone

mkdir -p \
  modules/load-balancer \
  modules/compute

Your structure should now include:

~/aws-production-capstone
├── environments/dev
├── modules/networking
├── modules/security-groups
├── modules/storage
├── modules/container-registry
├── modules/load-balancer
├── modules/iam
├── modules/compute
├── scripts
└── docs
Step 2 — Add root variables

Append these to environments/dev/variables.tf:

cat >> environments/dev/variables.tf <<'EOF'

variable "app_health_check_path" {
  description = "Application health check path"
  type        = string
  default     = "/health"
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Fargate task memory in MiB"
  type        = string
  default     = "512"
}

variable "container_image_tag" {
  description = "Container image tag for the initial task definition skeleton"
  type        = string
  default     = "bootstrap"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
EOF

The bootstrap image tag does not need to exist yet because we are not running tasks today. It gives us a valid task definition skeleton that we will update later when CI/CD pushes a real image.

Step 3 — Create the Load Balancer module

Create modules/load-balancer/variables.tf:

cat > modules/load-balancer/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}
EOF

Create modules/load-balancer/main.tf:

cat > modules/load-balancer/main.tf <<'EOF'
resource "aws_lb" "app" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [
    var.alb_sg_id
  ]

  subnets = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.name_prefix}-alb"
    Tier = "public-edge"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.name_prefix}-tg"
    Tier = "app-targets"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${var.name_prefix}-http-listener"
  }
}
EOF

Create modules/load-balancer/outputs.tf:

cat > modules/load-balancer/outputs.tf <<'EOF'
output "alb_arn" {
  value = aws_lb.app.arn
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_zone_id" {
  value = aws_lb.app.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "target_group_name" {
  value = aws_lb_target_group.app.name
}

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
EOF

An ALB listener checks connection requests and forwards traffic based on rules. A target group is used by listener rules to route requests to registered targets, and ALB health checks are performed against targets registered in a target group.

Step 4 — Create IAM module for ECS roles

Create modules/iam/variables.tf:

cat > modules/iam/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for IAM resources"
  type        = string
}
EOF

Create modules/iam/main.tf:

cat > modules/iam/main.tf <<'EOF'
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = {
    Name = "${var.name_prefix}-ecs-task-execution-role"
    Tier = "iam-runtime"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = {
    Name = "${var.name_prefix}-ecs-task-role"
    Tier = "iam-runtime"
  }
}
EOF

Create modules/iam/outputs.tf:

cat > modules/iam/outputs.tf <<'EOF'
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "ecs_task_execution_role_name" {
  value = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_name" {
  value = aws_iam_role.ecs_task.name
}
EOF

The ECS task execution role is used by ECS/Fargate to pull images from ECR and send container logs to CloudWatch Logs when using the awslogs driver. The ECS task role is different: it is the application runtime role used by your containerized app.

Step 5 — Create the Compute module

Create modules/compute/variables.tf:

cat > modules/compute/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for compute resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "container_name" {
  description = "Container name"
  type        = string
}

variable "container_image" {
  description = "Container image URI"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
}

variable "task_cpu" {
  description = "Fargate task CPU"
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}
EOF

Create modules/compute/main.tf:

cat > modules/compute/main.tf <<'EOF'
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
    Tier = "compute"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}/${var.container_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${var.name_prefix}/${var.container_name}"
    Tier = "logs"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-${var.container_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "APP_ENV"
          value = "dev"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -qO- http://localhost:${var.container_port}/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.container_name
        }
      }
    }
  ])

  tags = {
    Name = "${var.name_prefix}-${var.container_name}-task-definition"
    Tier = "compute"
  }
}
EOF

Create modules/compute/outputs.tf:

cat > modules/compute/outputs.tf <<'EOF'
output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.app.family
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
EOF

Before ECS containers can send logs to CloudWatch, the task definition needs an awslogs log driver configuration. AWS also documents awslogs task definition examples for routing ECS container logs to CloudWatch Logs.

Step 6 — Update root main.tf

Replace environments/dev/main.tf with this:

cat > environments/dev/main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix    = local.name_prefix
  vpc_id         = module.networking.vpc_id
  container_port = var.container_port
  db_port        = var.db_port
}

module "storage" {
  source = "../../modules/storage"

  name_prefix   = local.name_prefix
  force_destroy = true
}

module "container_registry" {
  source = "../../modules/container-registry"

  repository_name      = "${local.name_prefix}-api"
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix       = local.name_prefix
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  container_port    = var.container_port
  health_check_path = var.app_health_check_path
}

module "compute" {
  source = "../../modules/compute"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  container_name     = "api"
  container_image    = "${module.container_registry.repository_url}:${var.container_image_tag}"
  container_port     = var.container_port
  task_cpu           = var.ecs_task_cpu
  task_memory        = var.ecs_task_memory
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn
  log_retention_days = var.log_retention_days
}
EOF
Step 7 — Update root outputs

Replace environments/dev/outputs.tf with this:

cat > environments/dev/outputs.tf <<'EOF'
output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.networking.private_db_subnet_ids
}

output "alb_sg_id" {
  value = module.security_groups.alb_sg_id
}

output "ecs_tasks_sg_id" {
  value = module.security_groups.ecs_tasks_sg_id
}

output "database_sg_id" {
  value = module.security_groups.database_sg_id
}

output "static_assets_bucket_name" {
  value = module.storage.bucket_name
}

output "static_assets_bucket_regional_domain_name" {
  value = module.storage.bucket_regional_domain_name
}

output "ecr_repository_name" {
  value = module.container_registry.repository_name
}

output "ecr_repository_url" {
  value = module.container_registry.repository_url
}

output "alb_dns_name" {
  value = module.load_balancer.alb_dns_name
}

output "target_group_arn" {
  value = module.load_balancer.target_group_arn
}

output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}

output "ecs_cluster_arn" {
  value = module.compute.ecs_cluster_arn
}

output "task_definition_arn" {
  value = module.compute.task_definition_arn
}

output "cloudwatch_log_group_name" {
  value = module.compute.cloudwatch_log_group_name
}

output "ecs_task_execution_role_name" {
  value = module.iam.ecs_task_execution_role_name
}

output "ecs_task_role_name" {
  value = module.iam.ecs_task_role_name
}
EOF
Step 8 — Format, validate, and plan
cd ~/aws-production-capstone

terraform fmt -recursive

cd environments/dev

terraform init
terraform validate
terraform plan -out=tfplan

Expected new resources:

aws_lb.app
aws_lb_target_group.app
aws_lb_listener.http
aws_iam_role.ecs_task_execution
aws_iam_role_policy_attachment.ecs_task_execution_managed
aws_iam_role.ecs_task
aws_ecs_cluster.this
aws_cloudwatch_log_group.app
aws_ecs_task_definition.app
Step 9 — Apply

Only apply when you are ready to create the ALB.

terraform apply tfplan

After apply:

terraform output

Save key values:

ALB_DNS_NAME="$(terraform output -raw alb_dns_name)"
TG_ARN="$(terraform output -raw target_group_arn)"
CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
TASK_DEF_ARN="$(terraform output -raw task_definition_arn)"
LOG_GROUP="$(terraform output -raw cloudwatch_log_group_name)"
Step 10 — Validate ALB

Check the ALB:

aws elbv2 describe-load-balancers \
  --names "aws-production-capstone-dev-alb" \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,Type:Type,State:State.Code,VpcId:VpcId}' \
  --output table

Check listener:

aws elbv2 describe-listeners \
  --load-balancer-arn "$(terraform output -raw alb_dns_name >/dev/null; aws elbv2 describe-load-balancers --names aws-production-capstone-dev-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)" \
  --query 'Listeners[].{Port:Port,Protocol:Protocol,DefaultActions:DefaultActions[].Type}' \
  --output table

Check target group:

aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query 'TargetGroups[].{Name:TargetGroupName,Protocol:Protocol,Port:Port,TargetType:TargetType,HealthPath:HealthCheckPath,Matcher:Matcher.HttpCode}' \
  --output table

Check target health:

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

Expected today:

No targets are registered yet.
That is okay.
ECS service comes in the next phase.

Test ALB endpoint:

curl -i "http://${ALB_DNS_NAME}/health"

Expected today:

HTTP/1.1 503 Service Temporarily Unavailable

That is expected because the ALB listener exists but no ECS tasks are registered in the target group yet.

Step 11 — Validate ECS foundation

Check ECS cluster:

aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --query 'clusters[].{Name:clusterName,Status:status,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount,ActiveServices:activeServicesCount}' \
  --output table

Expected:

RunningTasks = 0
ActiveServices = 0

Check task definition:

aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --query 'taskDefinition.{Family:family,Revision:revision,NetworkMode:networkMode,Requires:requiresCompatibilities,Cpu:cpu,Memory:memory,ExecutionRole:executionRoleArn,TaskRole:taskRoleArn}' \
  --output table

Check container details:

aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --query 'taskDefinition.containerDefinitions[].{Name:name,Image:image,Port:portMappings[0].containerPort,LogDriver:logConfiguration.logDriver,LogGroup:logConfiguration.options.awslogs-group}' \
  --output table
Step 12 — Validate CloudWatch log group
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes}' \
  --output table

Expected:

Retention = 7
StoredBytes = 0
Step 13 — Validate IAM roles
EXEC_ROLE_NAME="$(terraform output -raw ecs_task_execution_role_name)"
TASK_ROLE_NAME="$(terraform output -raw ecs_task_role_name)"

aws iam get-role \
  --role-name "$EXEC_ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate}' \
  --output table

aws iam list-attached-role-policies \
  --role-name "$EXEC_ROLE_NAME" \
  --query 'AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
  --output table

aws iam get-role \
  --role-name "$TASK_ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate}' \
  --output table

Expected:

Execution role has AmazonECSTaskExecutionRolePolicy attached.
Task role exists but has no app permissions yet.

That is correct. We add app permissions only when the app actually needs them.

Step 14 — Create one validation script

Create scripts/validate-phase-23.sh:

cd ~/aws-production-capstone

cat > scripts/validate-phase-23.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../environments/dev"

echo "===== Terraform outputs ====="
terraform output

ALB_DNS_NAME="$(terraform output -raw alb_dns_name)"
TG_ARN="$(terraform output -raw target_group_arn)"
CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
TASK_DEF_ARN="$(terraform output -raw task_definition_arn)"
LOG_GROUP="$(terraform output -raw cloudwatch_log_group_name)"
EXEC_ROLE_NAME="$(terraform output -raw ecs_task_execution_role_name)"
TASK_ROLE_NAME="$(terraform output -raw ecs_task_role_name)"

echo
echo "===== ALB endpoint test ====="
set +e
curl -i --max-time 10 "http://${ALB_DNS_NAME}/health"
CURL_EXIT="$?"
set -e

echo
echo "curl exit code: ${CURL_EXIT}"
echo "Note: HTTP 503 is expected in Phase 23 because no ECS service/tasks are registered yet."

echo
echo "===== Target group ====="
aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query 'TargetGroups[].{Name:TargetGroupName,Protocol:Protocol,Port:Port,TargetType:TargetType,HealthPath:HealthCheckPath,Matcher:Matcher.HttpCode}' \
  --output table

echo
echo "===== Target health ====="
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

echo
echo "===== ECS cluster ====="
aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --query 'clusters[].{Name:clusterName,Status:status,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount,ActiveServices:activeServicesCount}' \
  --output table

echo
echo "===== ECS task definition ====="
aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --query 'taskDefinition.{Family:family,Revision:revision,NetworkMode:networkMode,Requires:requiresCompatibilities,Cpu:cpu,Memory:memory}' \
  --output table

echo
echo "===== Container details ====="
aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --query 'taskDefinition.containerDefinitions[].{Name:name,Image:image,Port:portMappings[0].containerPort,LogDriver:logConfiguration.logDriver,LogGroup:logConfiguration.options.awslogs-group}' \
  --output table

echo
echo "===== CloudWatch log group ====="
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes}' \
  --output table

echo
echo "===== ECS execution role attached policies ====="
aws iam list-attached-role-policies \
  --role-name "$EXEC_ROLE_NAME" \
  --query 'AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
  --output table

echo
echo "===== ECS task role ====="
aws iam get-role \
  --role-name "$TASK_ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn}' \
  --output table

echo
echo "Phase 23 validation completed."
EOF

chmod +x scripts/validate-phase-23.sh

Run it:

./scripts/validate-phase-23.sh
Common errors and fixes
Error 1 — ALB name too long

ALB names have length constraints. If you changed project or environment to a long value, shorten local.name_prefix.

Fix:

locals {
  name_prefix = "aws-prod-cap-dev"
}

Then run:

terraform plan
Error 2 — Target group name already exists

Cause:

A previous failed apply created the target group.

Fix:

aws elbv2 describe-target-groups \
  --names aws-production-capstone-dev-tg \
  --output table

If Terraform state does not know it, either import it or delete the orphaned target group after confirming it is unused.

Error 3 — ALB returns 503

In Phase 23, this is expected.

Cause:

No ECS service exists yet.
No task IPs are registered in the target group.

In the next phase, if it still returns 503 after ECS service creation, check:

ECS service events
target group health
container port
health check path
security group ALB → ECS
image pull
task startup logs
Error 4 — ECS task definition created but task cannot run later

Possible future causes:

ECR image tag does not exist
private subnet has no NAT or VPC endpoints
execution role missing ECR/Logs permissions
CloudWatch log group missing
security group wrong
container health check command unavailable

For today, this is not a failure because we are not running tasks.

Error 5 — AccessDenied on IAM role creation

You need permissions like:

iam:CreateRole
iam:AttachRolePolicy
iam:PassRole
iam:GetRole
iam:ListAttachedRolePolicies
iam:TagRole

Also check SCPs, permission boundaries, and whether your identity can create roles with the chosen name prefix.

Error 6 — AccessDenied on ALB creation

You need permissions like:

elasticloadbalancing:CreateLoadBalancer
elasticloadbalancing:CreateTargetGroup
elasticloadbalancing:CreateListener
elasticloadbalancing:AddTags
elasticloadbalancing:Describe*
ec2:Describe*

The ALB also needs at least two subnets in different Availability Zones for a normal internet-facing production-style setup.

Cleanup

Because the ALB is billable, destroy the stack when you finish practicing:

cd ~/aws-production-capstone/environments/dev
terraform destroy

Validate cleanup:

aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'aws-production-capstone-dev')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table

aws ecs describe-clusters \
  --clusters aws-production-capstone-dev-cluster \
  --query 'clusters[].{Name:clusterName,Status:status}' \
  --output table || true

aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/aws-production-capstone-dev" \
  --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays}' \
  --output table
What you built today
Terraform modules:
  load-balancer
  iam
  compute

AWS resources:
  Application Load Balancer
  HTTP listener
  IP target group
  ECS task execution role
  ECS task role
  ECS cluster
  CloudWatch log group
  ECS Fargate task definition skeleton

Resume-ready takeaway:

Built the runtime foundation for a production AWS ECS/Fargate platform using Terraform, including an internet-facing Application Load Balancer, IP target group with health checks, ECS cluster, Fargate task definition skeleton, CloudWatch logging, and separated ECS task execution/task runtime IAM roles.
Next build phase
Lesson 24 — Build and push a real Docker image to ECR, add ECS service in private subnets, and connect it to th