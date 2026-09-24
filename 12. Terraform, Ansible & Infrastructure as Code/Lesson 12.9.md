# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.9 — ALB and Target Groups with Terraform

In Lesson 12.8, you built:

```text id="recap-12-8"
EC2 instance
security group module
IAM role
IAM instance profile
SSM access model
Ubuntu AMI lookup
user_data nginx bootstrap
HTTP health endpoint
AWS CLI validation
```

Now we put an **Application Load Balancer** in front of EC2.

An Application Load Balancer receives client requests and distributes them across registered targets in one or more target groups. AWS performs health checks against targets in the target group before routing traffic to them. ([AWS Documentation][1])

---

# 1. Goal

Build a production-style ALB layer in `ap-south-1`.

You will create:

```text id="goal"
ALB security group
Application Load Balancer
Target Group
Target Group Attachments
HTTP Listener
Health Checks
EC2 security-group rule allowing traffic from ALB SG
AWS CLI validation
Target health troubleshooting
502/503 debugging runbooks
Cleanup scripts
```

Architecture:

```text id="architecture"
Internet
  ↓
Application Load Balancer
  ├── public subnet 1
  └── public subnet 2
  ↓ HTTP listener :80
Target Group
  ↓ health check /health
EC2 instance
  └── nginx running on port 80
```

This lesson prepares for:

```text id="future"
12.10 S3 and CloudFront
CloudFront → ALB origin
```

Cost warning:

```text id="cost-warning"
This lesson creates an ALB.
ALBs have hourly and LCU-based charges.
Destroy dev resources when you are done practicing.
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.9.1   ALB mental model
12.9.2   listener vs target group
12.9.3   target registration
12.9.4   target health checks
12.9.5   ALB security group
12.9.6   EC2 security group from ALB SG
12.9.7   public ALB + protected EC2 pattern
12.9.8   Terraform aws_lb
12.9.9   Terraform aws_lb_target_group
12.9.10  Terraform aws_lb_listener
12.9.11  Terraform aws_lb_target_group_attachment
12.9.12  AWS CLI target health validation
12.9.13  HTTP validation through ALB DNS
12.9.14  502/503 troubleshooting
12.9.15  future CloudFront ALB origin readiness
12.9.16  cleanup and cost safety
```

Terraform’s AWS provider has dedicated resources for `aws_lb`, `aws_lb_target_group`, `aws_lb_listener`, and `aws_lb_target_group_attachment`. The target-group attachment resource registers a target such as an EC2 instance with the target group. ([Terraform Registry][2])

---

# 3. Never Confuse These

## ALB vs Target Group

```text id="alb-vs-tg"
ALB:
  receives client traffic

Target Group:
  contains backend targets that receive forwarded traffic
```

Example:

```text id="alb-tg-example"
ALB listener :80
  forwards to
Target Group app-tg
  targets EC2 instance IDs
```

---

## Listener vs Listener Rule

```text id="listener-vs-rule"
Listener:
  process that checks for connection requests on a port/protocol

Listener Rule:
  routing condition/action under a listener
```

In this lesson:

```text id="simple-listener"
One HTTP listener on port 80.
Default action forwards to one target group.
```

---

## ALB Security Group vs EC2 Security Group

```text id="alb-sg-vs-ec2-sg"
ALB SG:
  allows inbound traffic from clients

EC2 SG:
  allows inbound app traffic from ALB SG
```

Production pattern:

```text id="prod-pattern"
Internet -> ALB SG :80/:443
ALB SG -> EC2 SG :80 or app port
```

AWS recommends ensuring target instance security groups allow traffic from the load balancer on the listener and health-check ports. ([AWS Documentation][3])

---

## Health Check Path vs Application Path

```text id="hc-vs-app"
Health check path:
  path ALB uses to decide target health

Application path:
  path users call
```

Example:

```text id="hc-example"
health check:
  /health

user traffic:
  /
```

A healthy `/` does not always mean `/health` is healthy, and a healthy `/health` does not always mean the whole app is correct.

---

## 502 vs 503

```text id="502-503"
502 Bad Gateway:
  ALB reached a target but received invalid/broken response

503 Service Unavailable:
  no healthy targets or no available target group route
```

Common 503 causes:

```text id="503-causes"
target health check failing
target group has no registered targets
EC2 SG blocks ALB traffic
app not listening on target port
wrong health check path
wrong target group port
```

AWS ALB troubleshooting docs specifically call out target security group rules, health-check settings, and target response behavior as common causes of ALB errors. ([AWS Documentation][4])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.9-alb-target-groups/{notes,scripts,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.9-alb-target-groups
```

---

# 5. Create ALB Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/notes/alb-target-group-mental-model.md
```

Paste:

````markdown id="mental-note-content"
# ALB and Target Group Mental Model

## Application Load Balancer

An ALB receives HTTP/HTTPS traffic and forwards requests to target groups.

## Listener

A listener listens on a protocol and port.

Example:

```text
HTTP :80
````

## Target Group

A target group contains registered targets.

Examples:

* EC2 instance IDs
* IP addresses
* Lambda functions

This course uses EC2 instance targets.

## Target Group Attachment

Registers a target into a target group.

## Health Check

ALB checks target health using configured protocol, port, path, timeout, interval, and status matcher.

## Public ALB pattern

Public subnets:
ALB

Private/protected backend:
EC2 targets

## Dev shortcut

This lesson may still use public EC2 from Lesson 12.8, but traffic should be validated through ALB DNS.

## Golden rule

ALB does not magically fix backend problems.
Target must be registered, reachable, listening, and healthy.

````

---

# 6. Create Never-Forget Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/notes/never-confuse-alb-points.md
````

Paste:

````markdown id="never-note-content"
# Never Forget — ALB and Target Groups

## 1. ALB needs at least two subnets

For internet-facing ALB, use public subnets in different Availability Zones.

## 2. ALB SG and EC2 SG are separate

ALB SG receives traffic from users.
EC2 SG receives traffic from ALB SG.

## 3. Target group health decides routing

If targets are unhealthy, ALB returns errors such as 503.

## 4. Health check port and app port must match reality

If nginx listens on 80, target group should check 80.

## 5. Health check path must exist

This lab uses:

```text
/health
````

## 6. Target type matters

This lab uses:

```text
instance
```

So targets are EC2 instance IDs.

## 7. Do not expose EC2 directly in production

Use:

```text
Internet -> ALB -> EC2
```

not:

```text
Internet -> EC2
```

## 8. Security group reference is better than broad CIDR

Allow EC2 app traffic from ALB security group, not from 0.0.0.0/0.

## 9. ALB DNS name is the validation endpoint

Use:

```bash
curl http://ALB_DNS_NAME/health
```

## 10. ALB prepares CloudFront origin integration

CloudFront can use ALB DNS name as a custom origin in a later lesson.

````

---

# 7. Update Security Group Module for ALB-to-EC2 Rule

We need EC2 SG to allow traffic from the ALB SG. Add optional source security group support.

From Module 12 root:

```bash id="cd-module-root"
cd ~/devops-masterclass/12-terraform-ansible-iac
````

Update `modules/security-group/variables.tf`:

```bash id="sg-vars"
cat > modules/security-group/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
  nullable    = false
}

variable "allowed_ingress_ports" {
  description = "Set of unique allowed ingress ports from allowed_cidr_blocks."
  type        = set(number)
  nullable    = false

  validation {
    condition = alltrue([
      for port in var.allowed_ingress_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ingress ports must be between 1 and 65535."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the service."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 1))
    ])
    error_message = "All allowed_cidr_blocks values must be valid CIDR blocks."
  }
}

variable "source_security_group_rules" {
  description = "Ingress rules where source is another security group."
  type = map(object({
    source_security_group_id = string
    from_port                = number
    to_port                  = number
    ip_protocol              = string
    description              = string
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for _, rule in var.source_security_group_rules :
      rule.from_port >= 1 && rule.from_port <= 65535 &&
      rule.to_port >= 1 && rule.to_port <= 65535
    ])
    error_message = "source security group rule ports must be between 1 and 65535."
  }
}

variable "allow_all_egress" {
  description = "Whether to allow all outbound traffic."
  type        = bool
  default     = true
}
EOF
```

Update `modules/security-group/main.tf`:

```bash id="sg-main"
cat > modules/security-group/main.tf <<'EOF'
locals {
  sorted_ports = sort(tolist(var.allowed_ingress_ports))

  ingress_rule_matrix = length(var.allowed_cidr_blocks) == 0 ? {} : merge([
    for port in local.sorted_ports : {
      for cidr in var.allowed_cidr_blocks :
      "tcp-${port}-${replace(replace(cidr, "/", "-"), ".", "-")}" => {
        port = port
        cidr = cidr
      }
    }
  ]...)
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Application security group managed by Terraform"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-app-sg"
      Component = "security-group"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "app_tcp_cidr" {
  for_each = local.ingress_rule_matrix

  security_group_id = aws_security_group.app.id
  description       = "Allow TCP ${each.value.port} from ${each.value.cidr}"
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.port
  ip_protocol       = "tcp"
  to_port           = each.value.port

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-${each.key}"
      Component = "security-group"
      Direction = "ingress"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "app_tcp_source_sg" {
  for_each = var.source_security_group_rules

  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = each.value.source_security_group_id
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  to_port                      = each.value.to_port

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-${each.key}"
      Component = "security-group"
      Direction = "ingress"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  count = var.allow_all_egress ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-all-egress"
      Component = "security-group"
      Direction = "egress"
    }
  )
}
EOF
```

Update outputs:

```bash id="sg-outputs"
cat > modules/security-group/outputs.tf <<'EOF'
output "security_group_contract" {
  description = "Security group contract."
  value = {
    security_group_id          = aws_security_group.app.id
    security_group_name        = aws_security_group.app.name
    allowed_ports              = sort(tolist(var.allowed_ingress_ports))
    allowed_cidrs              = var.allowed_cidr_blocks
    source_security_group_rules = var.source_security_group_rules
    allow_all_egress           = var.allow_all_egress
  }
}

output "security_group_id" {
  description = "Application security group ID."
  value       = aws_security_group.app.id
}

output "security_group_name" {
  description = "Application security group name."
  value       = aws_security_group.app.name
}

output "allowed_ports" {
  description = "Sorted allowed ingress ports."
  value       = sort(tolist(var.allowed_ingress_ports))
}
EOF
```

---

# 8. Upgrade Load Balancer Module to Real ALB Resources

Update `modules/load-balancer/versions.tf`:

```bash id="lb-versions"
cat > modules/load-balancer/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
```

Update `modules/load-balancer/variables.tf`:

```bash id="lb-vars"
cat > modules/load-balancer/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID from networking module."
  type        = string
  nullable    = false
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from networking module."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnets are required for the ALB."
  }
}

variable "target_instance_ids" {
  description = "Target instance IDs from compute module."
  type        = map(string)
  nullable    = false
}

variable "app_port" {
  description = "Backend application port."
  type        = number
  nullable    = false

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "app_port must be between 1 and 65535."
  }
}

variable "enable_alb" {
  description = "Whether ALB should be enabled."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Target group health check path."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with /."
  }
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach ALB HTTP listener."
  type        = list(string)
  default     = ["0.0.0.0/0"]
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.allowed_http_cidrs : can(cidrhost(cidr, 1))
    ])
    error_message = "All allowed_http_cidrs values must be valid CIDR blocks."
  }
}

variable "internal" {
  description = "Whether the ALB is internal."
  type        = bool
  default     = false
}
EOF
```

Update `modules/load-balancer/main.tf`:

```bash id="lb-main"
cat > modules/load-balancer/main.tf <<'EOF'
locals {
  alb_name = substr("${var.name_prefix}-alb", 0, 32)
  tg_name  = substr("${var.name_prefix}-tg", 0, 32)

  public_subnet_id_list = values(var.public_subnet_ids)

  target_attachments = var.enable_alb ? var.target_instance_ids : {}
}

resource "aws_security_group" "alb" {
  count = var.enable_alb ? 1 : 0

  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group managed by Terraform"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-alb-sg"
      Component = "load-balancer"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = var.enable_alb ? {
    for cidr in var.allowed_http_cidrs :
    replace(replace(cidr, "/", "-"), ".", "-") => cidr
  } : {}

  security_group_id = aws_security_group.alb[0].id
  description       = "Allow HTTP to ALB from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-alb-http-${each.key}"
      Component = "load-balancer"
      Direction = "ingress"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  count = var.enable_alb ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "Allow ALB outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-alb-all-egress"
      Component = "load-balancer"
      Direction = "egress"
    }
  )
}

resource "aws_lb" "app" {
  count = var.enable_alb ? 1 : 0

  name               = local.alb_name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = local.public_subnet_id_list

  enable_deletion_protection = false

  tags = merge(
    var.common_tags,
    {
      Name      = local.alb_name
      Component = "load-balancer"
    }
  )
}

resource "aws_lb_target_group" "app" {
  count = var.enable_alb ? 1 : 0

  name        = local.tg_name
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.common_tags,
    {
      Name      = local.tg_name
      Component = "load-balancer"
    }
  )
}

resource "aws_lb_target_group_attachment" "app" {
  for_each = local.target_attachments

  target_group_arn = aws_lb_target_group.app[0].arn
  target_id        = each.value
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  count = var.enable_alb ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-http-listener"
      Component = "load-balancer"
    }
  )
}
EOF
```

Update outputs:

```bash id="lb-outputs"
cat > modules/load-balancer/outputs.tf <<'EOF'
output "contract" {
  description = "Load balancer module contract."
  value = {
    enabled            = var.enable_alb
    alb_arn            = var.enable_alb ? aws_lb.app[0].arn : null
    alb_dns_name       = var.enable_alb ? aws_lb.app[0].dns_name : null
    alb_zone_id        = var.enable_alb ? aws_lb.app[0].zone_id : null
    alb_security_group_id = var.enable_alb ? aws_security_group.alb[0].id : null
    target_group_arn   = var.enable_alb ? aws_lb_target_group.app[0].arn : null
    target_group_name  = var.enable_alb ? aws_lb_target_group.app[0].name : null
    listener_arn       = var.enable_alb ? aws_lb_listener.http[0].arn : null
    health_check_path  = var.health_check_path
    target_instance_ids = var.target_instance_ids
    app_port           = var.app_port
  }
}

output "alb_arn" {
  description = "ALB ARN."
  value       = var.enable_alb ? aws_lb.app[0].arn : null
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = var.enable_alb ? aws_lb.app[0].dns_name : null
}

output "alb_zone_id" {
  description = "ALB hosted zone ID."
  value       = var.enable_alb ? aws_lb.app[0].zone_id : null
}

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = var.enable_alb ? aws_security_group.alb[0].id : null
}

output "target_group_arn" {
  description = "Target group ARN."
  value       = var.enable_alb ? aws_lb_target_group.app[0].arn : null
}

output "target_group_name" {
  description = "Target group name."
  value       = var.enable_alb ? aws_lb_target_group.app[0].name : null
}
EOF
```

Update README:

````bash id="lb-readme"
cat > modules/load-balancer/README.md <<'EOF'
# Load Balancer Module

## Purpose

Creates an Application Load Balancer for HTTP traffic.

## Resources

- aws_security_group for ALB
- aws_vpc_security_group_ingress_rule
- aws_vpc_security_group_egress_rule
- aws_lb
- aws_lb_target_group
- aws_lb_target_group_attachment
- aws_lb_listener

## Listener

HTTP port 80.

## Target Group

HTTP target group using instance targets.

## Health Check

Default path:

```text
/health
````

## Inputs

* name_prefix
* common_tags
* vpc_id
* public_subnet_ids
* target_instance_ids
* app_port
* enable_alb
* health_check_path
* allowed_http_cidrs
* internal

## Outputs

* alb_dns_name
* alb_arn
* alb_zone_id
* alb_security_group_id
* target_group_arn
* target_group_name
* contract

## Production note

For production, add HTTPS listener with ACM certificate.
CloudFront ACM certificates must be in us-east-1.
Regional ALB certificates are in the ALB region.
EOF

````

---

# 9. Update Environment Root Composition

Important change:

```text id="design-change"
EC2 SG should allow app traffic from ALB SG.
````

Because `module.security_group` needs `module.load_balancer.alb_security_group_id`, and `module.load_balancer` needs compute instance IDs, we avoid a module cycle by:

```text id="cycle-avoidance"
1. security_group allows dev direct CIDR ports for now
2. load_balancer creates ALB SG
3. later we add a separate EC2 SG rule from ALB SG in the root module
```

Add root-level SG rule for ALB → EC2.

Update all `environments/*/main.tf`:

```bash id="root-main-update"
cat > /tmp/module12_9_main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix    = local.name_prefix
  common_tags    = local.common_tags
  network_config = var.network_config
}

module "security_group" {
  source = "../../modules/security-group"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  vpc_id                = module.networking.vpc_id
  allowed_ingress_ports = var.allowed_ingress_ports
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  allow_all_egress      = true
}

module "storage" {
  source = "../../modules/storage"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  environment       = local.normalized_env
  enable_versioning = true
  force_destroy     = local.normalized_env == "prod" ? false : true
}

module "iam" {
  source = "../../modules/iam"

  name_prefix      = local.name_prefix
  common_tags      = local.common_tags
  enable_ssm       = var.compute_config.enable_ssm
  app_bucket_names = [module.storage.assets_bucket_name]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                 = local.name_prefix
  common_tags                 = local.common_tags
  environment                 = local.normalized_env
  project_name                = local.normalized_project
  compute_config              = var.compute_config
  public_subnet_ids           = module.networking.public_subnet_ids
  private_subnet_ids          = module.networking.private_subnet_ids
  security_group_id           = module.security_group.security_group_id
  instance_profile_name       = module.iam.instance_profile_name
  use_public_subnet_for_dev   = local.normalized_env == "dev" ? true : false
  associate_public_ip_address = local.normalized_env == "dev" ? true : false
  user_data_template_path     = "${path.root}/../../12.8-ec2-security-groups/user-data/app-bootstrap.sh.tftpl"
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  target_instance_ids = module.compute.instance_ids
  app_port            = 80
  enable_alb          = var.feature_flags.enable_alb
  health_check_path   = "/health"
  allowed_http_cidrs  = ["0.0.0.0/0"]
  internal            = false
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_ec2_http" {
  count = var.feature_flags.enable_alb ? 1 : 0

  security_group_id            = module.security_group.security_group_id
  referenced_security_group_id = module.load_balancer.alb_security_group_id
  description                  = "Allow HTTP from ALB security group to EC2"
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-allow-alb-to-ec2-http"
      Component = "load-balancer"
      Direction = "ingress"
    }
  )
}

module "cdn" {
  source = "../../modules/cdn"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  enable_cloudfront  = var.feature_flags.enable_cloudfront
  origin_domain_name = module.load_balancer.alb_dns_name
  price_class        = "PriceClass_100"
}

resource "terraform_data" "environment_contract" {
  input = {
    project_name = local.normalized_project
    environment  = local.normalized_env
    aws_region   = var.aws_region
    name_prefix  = local.name_prefix
    tags         = local.common_tags
  }
}

resource "terraform_data" "module_composition_contract" {
  input = {
    dependency_flow = [
      "networking -> security_group",
      "networking -> compute",
      "security_group -> compute",
      "iam -> compute",
      "compute -> load_balancer",
      "load_balancer -> ec2 security group ingress rule",
      "load_balancer -> cdn",
      "storage -> iam",
    ]

    vpc_id                = module.networking.vpc_id
    ec2_security_group_id = module.security_group.security_group_id
    alb_security_group_id = module.load_balancer.alb_security_group_id
    instance_ids          = module.compute.instance_ids
    public_ips            = module.compute.public_ips
    private_ips           = module.compute.private_ips
    alb_dns_name          = module.load_balancer.alb_dns_name
    target_group_arn      = module.load_balancer.target_group_arn
    cdn_domain_name       = module.cdn.distribution_domain_name
    assets_bucket_name    = module.storage.assets_bucket_name
    instance_profile_name = module.iam.instance_profile_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_9_main.tf environments/$env/main.tf
done
```

Why target group port `80`?

```text id="port-choice"
Your Lesson 12.8 user_data runs nginx on port 80.
So ALB target group forwards to EC2 port 80.
```

Your `compute_config.app_port` may still be `3002` for future app deployment, but this ALB lab validates nginx on port `80`.

---

# 10. Update Environment Outputs

```bash id="outputs-update"
cat > /tmp/module12_9_outputs.tf <<'EOF'
output "environment_contract" {
  description = "Environment metadata and tagging contract."
  value       = terraform_data.environment_contract.output
}

output "module_composition_contract" {
  description = "Shows how module outputs are chained through the root module."
  value       = terraform_data.module_composition_contract.output
}

output "name_prefix" {
  description = "Common naming prefix."
  value       = local.name_prefix
}

output "networking_contract" {
  description = "Networking module contract."
  value       = module.networking.contract
}

output "security_group_contract" {
  description = "EC2 security group contract."
  value       = module.security_group.security_group_contract
}

output "compute_contract" {
  description = "Compute module contract."
  value       = module.compute.contract
}

output "iam_contract" {
  description = "IAM module contract."
  value       = module.iam.contract
}

output "storage_contract" {
  description = "Storage module contract."
  value       = module.storage.contract
}

output "load_balancer_contract" {
  description = "Load balancer module contract."
  value       = module.load_balancer.contract
}

output "cdn_contract" {
  description = "CDN module contract."
  value       = module.cdn.contract
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs."
  value       = module.compute.instance_ids
}

output "ec2_public_ips" {
  description = "EC2 public IPv4 addresses."
  value       = module.compute.public_ips
}

output "ec2_private_ips" {
  description = "EC2 private IPv4 addresses."
  value       = module.compute.private_ips
}

output "first_ec2_instance_id" {
  description = "First EC2 instance ID."
  value       = module.compute.first_instance_id
}

output "first_ec2_public_ip" {
  description = "First EC2 public IPv4 address."
  value       = module.compute.first_public_ip
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = module.load_balancer.alb_dns_name
}

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = module.load_balancer.alb_security_group_id
}

output "target_group_arn" {
  description = "Target group ARN."
  value       = module.load_balancer.target_group_arn
}

output "future_ansible_inventory_contract" {
  description = "Future handoff contract for Ansible inventory generation."
  value = {
    environment           = local.normalized_env
    instance_names        = module.compute.instance_names
    instance_ids          = module.compute.instance_ids
    public_ips            = module.compute.public_ips
    private_ips           = module.compute.private_ips
    app_port              = module.compute.app_port
    instance_role_name    = module.iam.instance_role_name
    ec2_security_group_id = module.security_group.security_group_id
    alb_dns_name          = module.load_balancer.alb_dns_name
    target_group_arn      = module.load_balancer.target_group_arn
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_9_outputs.tf environments/$env/outputs.tf
done
```

---

# 11. AWS Prerequisites

Check identity and region:

```bash id="aws-check"
cd ~/devops-masterclass

aws sts get-caller-identity
aws configure list

export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

You need permissions for:

```text id="permissions"
elasticloadbalancing:CreateLoadBalancer
elasticloadbalancing:CreateTargetGroup
elasticloadbalancing:RegisterTargets
elasticloadbalancing:CreateListener
elasticloadbalancing:DescribeLoadBalancers
elasticloadbalancing:DescribeTargetGroups
elasticloadbalancing:DescribeTargetHealth
elasticloadbalancing:DeleteLoadBalancer
elasticloadbalancing:DeleteTargetGroup
elasticloadbalancing:DeleteListener
ec2:CreateSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:DescribeSecurityGroups
ec2:DescribeSubnets
ec2:DescribeVpcs
iam:PassRole
```

---

# 12. Plan Dev ALB

Go to dev environment:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

Initialize:

```bash id="dev-init"
terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

Format and validate:

```bash id="dev-fmt"
terraform fmt -recursive
terraform validate
```

Plan:

```bash id="dev-plan"
terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-9-dev
```

Review:

```bash id="dev-show"
terraform show tfplan-12-9-dev
```

Expected new resources:

```text id="expected"
module.load_balancer.aws_security_group.alb[0]
module.load_balancer.aws_vpc_security_group_ingress_rule.alb_http
module.load_balancer.aws_vpc_security_group_egress_rule.alb_all_outbound[0]
module.load_balancer.aws_lb.app[0]
module.load_balancer.aws_lb_target_group.app[0]
module.load_balancer.aws_lb_target_group_attachment.app
module.load_balancer.aws_lb_listener.http[0]
aws_vpc_security_group_ingress_rule.allow_alb_to_ec2_http[0]
```

---

# 13. Apply Dev ALB

```bash id="dev-apply"
terraform apply tfplan-12-9-dev
```

Store outputs:

```bash id="store-outputs"
ALB_DNS="$(terraform output -raw alb_dns_name)"
TG_ARN="$(terraform output -raw target_group_arn)"
ALB_SG_ID="$(terraform output -raw alb_security_group_id)"
EC2_SG_ID="$(terraform output -json security_group_contract | jq -r '.security_group_id')"

echo "ALB_DNS=$ALB_DNS"
echo "TG_ARN=$TG_ARN"
echo "ALB_SG_ID=$ALB_SG_ID"
echo "EC2_SG_ID=$EC2_SG_ID"
```

---

# 14. Validate ALB with AWS CLI

## Load balancer

```bash id="validate-alb"
aws elbv2 describe-load-balancers \
  --names "$(terraform output -json load_balancer_contract | jq -r '.target_group_name' | sed 's/-tg$/-alb/')" \
  --query 'LoadBalancers[0].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId,SecurityGroups:SecurityGroups,AvailabilityZones:AvailabilityZones[].ZoneName}' \
  --output table
```

If name lookup fails, use ARN:

```bash id="validate-alb-arn"
ALB_ARN="$(terraform output -json load_balancer_contract | jq -r '.alb_arn')"

aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId,SecurityGroups:SecurityGroups,AvailabilityZones:AvailabilityZones[].ZoneName}' \
  --output table
```

Expected:

```text id="alb-expected"
State = active
Scheme = internet-facing
Type = application
At least two AZs
```

---

## Target group

```bash id="validate-tg"
aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query 'TargetGroups[0].{Name:TargetGroupName,Protocol:Protocol,Port:Port,TargetType:TargetType,VpcId:VpcId,HealthCheckPath:HealthCheckPath,Matcher:Matcher.HttpCode}' \
  --output table
```

Expected:

```text id="tg-expected"
Protocol = HTTP
Port = 80
TargetType = instance
HealthCheckPath = /health
Matcher = 200
```

---

## Target health

```bash id="target-health"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

Expected eventually:

```text id="target-healthy"
State = healthy
```

If not healthy immediately, wait:

```bash id="target-health-wait"
for i in {1..30}; do
  echo "attempt $i"
  aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].{TargetId:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
    --output table

  if aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].TargetHealth.State' \
    --output text | grep -q healthy; then
    break
  fi

  sleep 10
done
```

Before ALB sends health checks, the target must be registered, the target group must be used by a listener rule, and the target Availability Zone must be enabled for the load balancer. ([AWS Documentation][5])

---

## Security groups

Check ALB SG:

```bash id="alb-sg"
aws ec2 describe-security-groups \
  --group-ids "$ALB_SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

Check EC2 SG:

```bash id="ec2-sg"
aws ec2 describe-security-groups \
  --group-ids "$EC2_SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

Look for:

```text id="sg-check"
ALB SG:
  inbound TCP 80 from 0.0.0.0/0

EC2 SG:
  inbound TCP 80 from ALB SG
```

---

# 15. Validate Through ALB DNS

```bash id="curl-alb"
curl -I "http://$ALB_DNS/"
curl "http://$ALB_DNS/health"
curl "http://$ALB_DNS/metadata.json"
```

Expected:

```text id="curl-expected"
HTTP 200
healthy
metadata JSON
```

Retry loop:

```bash id="curl-retry"
for i in {1..30}; do
  echo "attempt $i"
  curl -fsS "http://$ALB_DNS/health" && break || true
  sleep 10
done
```

Important:

```text id="dns-delay"
ALB DNS may take a short time to become reachable after creation.
Target health may also take time to turn healthy.
```

---

# 16. Create ALB Validation Script

```bash id="validate-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh
```

Paste:

```bash id="validate-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== ALB AWS Validation ====="
echo "Environment: $ENVIRONMENT"

ALB_DNS="$(terraform output -raw alb_dns_name)"
ALB_ARN="$(terraform output -json load_balancer_contract | jq -r '.alb_arn')"
TG_ARN="$(terraform output -raw target_group_arn)"
ALB_SG_ID="$(terraform output -raw alb_security_group_id)"
EC2_SG_ID="$(terraform output -json security_group_contract | jq -r '.security_group_id')"

echo "ALB DNS: $ALB_DNS"
echo "ALB ARN: $ALB_ARN"
echo "TG ARN: $TG_ARN"
echo "ALB SG: $ALB_SG_ID"
echo "EC2 SG: $EC2_SG_ID"

echo
echo "Load Balancer:"
aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId,SecurityGroups:SecurityGroups,AvailabilityZones:AvailabilityZones[].ZoneName}' \
  --output table

ALB_STATE="$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].State.Code' --output text)"

if [ "$ALB_STATE" != "active" ]; then
  echo "ERROR: ALB is not active."
  exit 1
fi

echo
echo "Target Group:"
aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --query 'TargetGroups[0].{Name:TargetGroupName,Protocol:Protocol,Port:Port,TargetType:TargetType,VpcId:VpcId,HealthCheckPath:HealthCheckPath,Matcher:Matcher.HttpCode}' \
  --output table

echo
echo "Target Health:"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

echo
echo "Waiting for at least one healthy target..."
for i in {1..30}; do
  STATES="$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[].TargetHealth.State' --output text || true)"

  echo "attempt $i states: $STATES"

  if echo "$STATES" | grep -q healthy; then
    echo "At least one target is healthy."
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "ERROR: no healthy targets after retries."
    exit 1
  fi

  sleep 10
done

echo
echo "ALB security group:"
aws ec2 describe-security-groups \
  --group-ids "$ALB_SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json

echo
echo "EC2 security group:"
aws ec2 describe-security-groups \
  --group-ids "$EC2_SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json

echo
echo "HTTP validation through ALB:"
for i in {1..30}; do
  if curl -fsS "http://$ALB_DNS/health"; then
    echo
    echo "ALB HTTP health validation passed."
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "ERROR: ALB HTTP validation failed."
    exit 1
  fi

  echo "Waiting for ALB DNS/target health... attempt $i"
  sleep 10
done

echo
echo "ALB validation completed."
```

Make executable:

```bash id="chmod-validate"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh
```

Run:

```bash id="run-validate"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh
```

---

# 17. Create ALB Plan Script

```bash id="plan-script"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/plan-alb.sh
```

Paste:

```bash id="plan-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="../../12.9-alb-target-groups/reports"

mkdir -p "$BASE/12.9-alb-target-groups/reports"

cd "$ENV_DIR"

echo "===== Terraform ALB Plan ====="
echo "Environment: $ENVIRONMENT"
echo "Current workspace: $(terraform workspace show 2>/dev/null || echo not-initialized)"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -recursive
terraform validate

terraform plan -var-file=terraform.tfvars.example -out="tfplan-12-9-$ENVIRONMENT"
terraform show -no-color "tfplan-12-9-$ENVIRONMENT" > "$REPORT_DIR/$ENVIRONMENT-alb-plan.txt"

echo
echo "Plan saved:"
echo "$BASE/12.9-alb-target-groups/reports/$ENVIRONMENT-alb-plan.txt"
echo
echo "Apply manually from $ENV_DIR with:"
echo "terraform apply tfplan-12-9-$ENVIRONMENT"
```

Make executable:

```bash id="chmod-plan"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/plan-alb.sh
```

Run:

```bash id="run-plan"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/plan-alb.sh
```

---

# 18. Create Target Health Debug Script

```bash id="target-debug-script"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/debug-target-health.sh
```

Paste:

```bash id="target-debug-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== ALB Target Health Debug ====="
echo "Environment: $ENVIRONMENT"

TG_ARN="$(terraform output -raw target_group_arn)"
ALB_DNS="$(terraform output -raw alb_dns_name)"
INSTANCE_IDS="$(terraform output -json ec2_instance_ids | jq -r '.[]')"
ALB_SG_ID="$(terraform output -raw alb_security_group_id)"
EC2_SG_ID="$(terraform output -json security_group_contract | jq -r '.security_group_id')"

echo "ALB DNS: $ALB_DNS"
echo "TG ARN: $TG_ARN"
echo "ALB SG: $ALB_SG_ID"
echo "EC2 SG: $EC2_SG_ID"

echo
echo "Target group details:"
aws elbv2 describe-target-groups \
  --target-group-arns "$TG_ARN" \
  --output table

echo
echo "Target health:"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{TargetId:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

echo
echo "Instances:"
for id in $INSTANCE_IDS; do
  aws ec2 describe-instances \
    --instance-ids "$id" \
    --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,VpcId:VpcId,SecurityGroups:SecurityGroups[].GroupId}' \
    --output table
done

echo
echo "Security group rules:"
echo "ALB SG:"
aws ec2 describe-security-groups --group-ids "$ALB_SG_ID" --output json

echo
echo "EC2 SG:"
aws ec2 describe-security-groups --group-ids "$EC2_SG_ID" --output json

echo
echo "Direct ALB curl:"
curl -v "http://$ALB_DNS/health" || true

echo
echo "Debug hints:"
cat <<'EOF'
If target is unhealthy:
  - verify EC2 instance is running
  - verify nginx is running
  - verify target group port is 80
  - verify health check path is /health
  - verify EC2 SG allows TCP 80 from ALB SG
  - verify ALB has subnets in enabled AZs
  - verify route tables and NACLs
EOF
```

Make executable:

```bash id="chmod-target-debug"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/debug-target-health.sh
```

Run:

```bash id="run-target-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/debug-target-health.sh
```

---

# 19. Create ALB Summary Script

```bash id="summary-script"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/alb-summary.sh
```

Paste:

```bash id="summary-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== ALB Terraform Summary ====="
echo "Environment: $ENVIRONMENT"

terraform output alb_dns_name
terraform output alb_security_group_id
terraform output target_group_arn
terraform output load_balancer_contract
terraform output module_composition_contract
terraform output future_ansible_inventory_contract

echo
echo "State addresses:"
terraform state list | grep -E 'module.load_balancer|aws_lb|aws_vpc_security_group_ingress_rule.allow_alb' | sort || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/alb-summary.sh
```

Run:

```bash id="run-summary"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/alb-summary.sh
```

---

# 20. Create Lesson Validation Script

This validates Terraform configuration but does not automatically create the ALB.

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-lesson-12-9.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.9 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.9-alb-target-groups"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"

test -f "$LESSON/notes/alb-target-group-mental-model.md"
test -f "$LESSON/notes/never-confuse-alb-points.md"

test -x "$LESSON/scripts/validate-alb-aws.sh"
test -x "$LESSON/scripts/plan-alb.sh"
test -x "$LESSON/scripts/debug-target-health.sh"
test -x "$LESSON/scripts/alb-summary.sh"

test -f "$BASE/modules/load-balancer/main.tf"
test -f "$BASE/modules/load-balancer/variables.tf"
test -f "$BASE/modules/load-balancer/outputs.tf"
test -f "$BASE/modules/load-balancer/README.md"

grep -q 'resource "aws_lb" "app"' "$BASE/modules/load-balancer/main.tf"
grep -q 'resource "aws_lb_target_group" "app"' "$BASE/modules/load-balancer/main.tf"
grep -q 'resource "aws_lb_target_group_attachment" "app"' "$BASE/modules/load-balancer/main.tf"
grep -q 'resource "aws_lb_listener" "http"' "$BASE/modules/load-balancer/main.tf"
grep -q 'resource "aws_security_group" "alb"' "$BASE/modules/load-balancer/main.tf"

grep -q 'allow_alb_to_ec2_http' "$BASE/environments/dev/main.tf"

terraform version >/dev/null
aws sts get-caller-identity >/dev/null

for env in dev staging prod; do
  echo
  echo "===== Validating Terraform env: $env ====="

  pushd "$BASE/environments/$env" >/dev/null

  terraform init -backend=false >/dev/null
  terraform fmt -check -recursive
  terraform validate

  terraform plan \
    -var-file=terraform.tfvars.example \
    -out="tfplan-12-9-validation-$env" >/dev/null

  terraform show -no-color "tfplan-12-9-validation-$env" >/dev/null
  rm -f "tfplan-12-9-validation-$env"

  popd >/dev/null
done

echo
echo "Lesson 12.9 validation passed."
echo
echo "After applying dev, validate AWS resources with:"
echo "ENVIRONMENT=dev ./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh"
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-lesson-12-9.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-lesson-12-9.sh
```

---

# 21. Cleanup Scripts

## Local artifacts only

```bash id="local-cleanup-script"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-local.sh
```

Paste:

```bash id="local-cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.9 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

echo "Local Terraform plan artifacts cleaned."
echo "AWS resources were not destroyed."
```

Make executable:

```bash id="chmod-local-cleanup"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-local.sh
```

Run:

```bash id="run-local-cleanup"
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-local.sh
```

---

## Destroy dev resources

This destroys the full dev stack currently managed by the dev root module, including ALB, EC2, security groups, IAM, S3 module resources if later real, and VPC.

```bash id="destroy-script"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-dev.sh
```

Paste:

```bash id="destroy-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [ "$ENVIRONMENT" != "dev" ]; then
  echo "This cleanup script is intentionally limited to ENVIRONMENT=dev."
  echo "Refusing to destroy $ENVIRONMENT."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/dev"

cd "$ENV_DIR"

echo "===== Cleanup Lesson 12.9 Dev Resources ====="
echo "Current workspace: $(terraform workspace show)"

terraform plan -destroy -var-file=terraform.tfvars.example -out=tfplan-destroy-12-9-dev
terraform show tfplan-destroy-12-9-dev

echo
echo "This destroy plan may include ALB, target group, listeners, EC2, security groups, IAM, and VPC resources."
echo "Review carefully."
echo "Type DESTROY_DEV_ALB_EC2_VPC to continue:"
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY_DEV_ALB_EC2_VPC" ]; then
  echo "Cleanup cancelled."
  rm -f tfplan-destroy-12-9-dev
  exit 0
fi

terraform apply tfplan-destroy-12-9-dev
rm -f tfplan-destroy-12-9-dev

echo "Dev ALB/EC2/VPC resources destroyed."
```

Make executable:

```bash id="chmod-destroy"
chmod +x 12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-dev.sh
```

Run only if done:

```bash id="run-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-dev.sh
```

Recommended:

```text id="keep-or-destroy"
Keep resources if continuing directly to Lesson 12.10 CloudFront with ALB origin.
Destroy if stopping to avoid ALB, EC2, EBS, and public IPv4 costs.
```

---

# 22. ALB Troubleshooting Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/runbooks/alb-target-group-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# ALB and Target Group Troubleshooting Runbook

## 1. Check Terraform context

```bash
pwd
terraform workspace show
terraform output alb_dns_name
terraform output target_group_arn
````

## 2. Check ALB

```bash id="fyv63c"
aws elbv2 describe-load-balancers --load-balancer-arns ALB_ARN
```

Check:

* State = active
* Scheme = internet-facing
* Type = application
* Subnets in at least two AZs
* Security group attached

## 3. Check target group

```bash id="tg-check"
aws elbv2 describe-target-groups --target-group-arns TG_ARN
```

Check:

* protocol
* port
* target type
* VPC
* health check path
* matcher

## 4. Check target health

```bash id="target-check"
aws elbv2 describe-target-health --target-group-arn TG_ARN
```

## 5. Check security groups

```bash id="sg-check"
aws ec2 describe-security-groups --group-ids ALB_SG_ID EC2_SG_ID
```

Required:

```text
ALB SG:
  inbound 80 from client CIDR
  outbound to EC2

EC2 SG:
  inbound 80 from ALB SG
  outbound as needed
```

## 6. Check EC2

```bash id="ec2-check"
aws ec2 describe-instances --instance-ids INSTANCE_ID
```

Check:

* running
* subnet
* security group
* private IP
* user_data completed

## 7. Check through ALB

```bash id="curl-check"
curl -v http://ALB_DNS/health
```

## Common symptoms

### 503 Service Unavailable

Likely causes:

* no registered targets
* targets unhealthy
* wrong health check path
* EC2 SG blocks ALB
* app not listening
* target group wrong port
* ALB listener not forwarding to target group

### 502 Bad Gateway

Likely causes:

* target closed connection
* malformed response
* app crash
* app timeout
* protocol mismatch

### Target.ResponseCodeMismatch

Likely causes:

* health check path returns non-200
* app redirects health path
* nginx config does not serve health path

### Target.Timeout

Likely causes:

* EC2 SG blocks ALB
* app not listening
* NACL blocks traffic
* wrong port

### Target.NotRegistered

Likely causes:

* target group attachment missing
* wrong target type
* wrong instance IDs

## Golden rule

ALB success requires:
listener -> target group -> registered target -> security group path -> healthy app response.

````id="runbook-end"

---

# 23. Production ALB Design Runbook

```bash id="prod-runbook"
nano 12-terraform-ansible-iac/12.9-alb-target-groups/runbooks/production-alb-design-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production ALB Design Runbook

## Recommended production pattern

```text
Internet
  ↓
CloudFront or Route 53
  ↓
ALB in public subnets
  ↓
EC2/ASG/ECS in private subnets
````

## Security groups

### ALB SG

Inbound:

```text
80/443 from internet or CloudFront prefix list
```

Outbound:

```text
app port to EC2 SG
```

### EC2 SG

Inbound:

```text
app port from ALB SG only
```

No direct SSH from internet.

## Health checks

Use a lightweight endpoint:

```text
/health
```

Health endpoint should verify:

* app process is running
* critical dependencies are reachable if needed
* response is fast
* status code is stable

## HTTPS

Production ALB should normally use HTTPS listener.

Regional ALB certificate:

```text
ACM certificate in ALB region
```

CloudFront certificate:

```text
ACM certificate in us-east-1
```

## Target registration

For static EC2 labs:

```text
target group attachment
```

For production autoscaling:

```text
Auto Scaling Group attached to target group
```

## Logging

Enable ALB access logs to S3 for production.

## Golden rule

Do not put production EC2 instances directly on the internet when ALB can front them.

````

---

# 24. Common Errors and Fixes

## Error 1 — ALB requires at least two subnets

Cause:

```text id="two-subnets-cause"
Application Load Balancer needs subnets in at least two Availability Zones.
````

Fix:

```text id="two-subnets-fix"
Ensure module.networking.public_subnet_ids has at least two subnets.
```

---

## Error 2 — Target unhealthy with `Target.Timeout`

Cause:

```text id="timeout-cause"
ALB cannot connect to target.
```

Check:

```bash id="timeout-debug"
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
aws ec2 describe-security-groups --group-ids "$EC2_SG_ID"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID"
```

Fix:

```text id="timeout-fix"
Allow EC2 SG inbound TCP 80 from ALB SG.
Confirm nginx is listening on 80.
Confirm target group port is 80.
```

---

## Error 3 — Target unhealthy with `Target.ResponseCodeMismatch`

Cause:

```text id="response-mismatch-cause"
Health check path does not return expected HTTP 200.
```

Fix:

```bash id="response-mismatch-debug"
curl http://EC2_PUBLIC_IP/health
curl http://ALB_DNS/health
```

Then fix health check path or app endpoint.

---

## Error 4 — ALB returns 503

Cause:

```text id="alb-503-cause"
No healthy targets.
```

Fix:

```bash id="alb-503-debug"
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
```

Then fix target health first.

---

## Error 5 — ALB returns 502

Cause:

```text id="alb-502-cause"
Target returned invalid response, closed connection, or protocol mismatch.
```

Fix:

```text id="alb-502-fix"
Check app logs, nginx status, target protocol/port, app timeout.
```

---

## Error 6 — Security group cycle in Terraform

Cause:

```text id="sg-cycle-cause"
ALB module needs EC2 SG and EC2 SG module needs ALB SG.
```

Fix:

```text id="sg-cycle-fix"
Create ALB SG in ALB module.
Create EC2 SG in SG module.
Add ALB-to-EC2 SG rule at root module after both outputs exist.
```

---

# 25. Cost Safety

This lesson can create:

```text id="cost-created"
Application Load Balancer
Target Group
Listener
EC2 instance
EBS root volume
public IPv4 address
security groups
VPC resources
```

Cost reminder:

```text id="cost-reminder"
ALB and EC2 are billable.
Public IPv4 is billable.
Destroy dev resources if stopping.
```

Check running billable resources:

```bash id="cost-check"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Type:Type}' \
  --output table

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

Destroy if done:

```bash id="cost-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-dev.sh
```

---

# 26. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is an Application Load Balancer?
What is a listener?
What is a target group?
What is a target group attachment?
What is target type instance?
What does target health mean?
Why does ALB need public subnets?
Why does ALB need at least two AZs?
What security group does ALB use?
What security group does EC2 use?
Why should EC2 allow traffic from ALB SG instead of 0.0.0.0/0?
What causes ALB 503?
What causes ALB 502?
What does Target.Timeout mean?
What does Target.ResponseCodeMismatch mean?
How do you validate ALB DNS?
How do you check target health with AWS CLI?
How does this prepare for CloudFront ALB origin?
```

Strong interview answer:

```text id="interview-answer"
I built a Terraform Application Load Balancer layer with a reusable load-balancer module. The module creates an internet-facing ALB across public subnets, an ALB security group, an HTTP listener, an instance target group, target group attachments, and health checks. The root module wires compute outputs into the load balancer and adds an EC2 security group rule that allows HTTP traffic from the ALB security group.

For troubleshooting, I check the ALB state, listener, target group settings, registered targets, target health, EC2 state, security groups, and the application health endpoint. If ALB returns 503, I first check whether targets are registered and healthy. If target health shows timeout, I inspect EC2 security group rules, app port, route tables, and NACLs. If target health shows response code mismatch, I verify that the health check path returns HTTP 200. I validate recovery using AWS CLI target-health checks and curl through the ALB DNS name.
```

Resume bullet:

```text id="resume-bullet"
Built a Terraform Application Load Balancer layer in AWS ap-south-1 with public ALB subnets, ALB security group, HTTP listener, target group, EC2 target attachments, health checks, ALB-to-EC2 security group referencing, Terraform outputs for CloudFront origin readiness, AWS CLI validation scripts, target-health debugging automation, 502/503 troubleshooting runbooks, and cost-safe cleanup workflows.
```

---

# 27. Commit Lesson 12.9

Clean local plans only:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-local.sh
```

Validate Terraform config:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-lesson-12-9.sh
```

If you applied dev ALB, validate AWS resources:

```bash id="validate-aws-before-commit"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.9-alb-target-groups -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/modules/load-balancer -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add ALB and target group Terraform module"

git push
```

---

# 28. Keep or Destroy?

For the next lesson, you should usually **keep the dev ALB and EC2** because Lesson 12.10 will use the ALB as a CloudFront origin.

Keep:

```text id="keep"
Recommended if continuing directly to Lesson 12.10.
```

Destroy:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/cleanup-lesson-12-9-dev.sh
```

---

# 29. Next Lesson

```text id="next-lesson"
12.10 — S3 and CloudFront with Terraform
```

We will build:

```text id="next-topics"
S3 private static assets bucket
S3 bucket versioning
S3 encryption
S3 public access block
CloudFront distribution
S3 origin with Origin Access Control
ALB origin option
CloudFront cache behavior
viewer protocol redirect
default root object
custom error response for SPA
CloudFront invalidation concept
ACM us-east-1 reminder
CloudFront 403 troubleshooting
CloudFront origin debugging
cleanup and cost safety
```

[1]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html?utm_source=chatgpt.com "What is an Application Load Balancer? - Elastic Load Balancing"
[2]: https://registry.terraform.io/providers/hashicorp/aws/6.40.0/docs/resources/lb_target_group_attachment?utm_source=chatgpt.com "aws_lb_target_group_attachment | Resources | hashicorp/aws | Terraform | Terraform Registry"
[3]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-application-load-balancer.html?utm_source=chatgpt.com "Create an Application Load Balancer - Elastic Load Balancing"
[4]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html?utm_source=chatgpt.com "Troubleshoot your Application Load Balancers - Elastic Load Balancing"
[5]: https://docs.aws.amazon.com/en_en/elasticloadbalancing/latest/application/target-group-health-checks.html?utm_source=chatgpt.com "Health checks for Application Load Balancer target groups - Elastic Load Balancing"
