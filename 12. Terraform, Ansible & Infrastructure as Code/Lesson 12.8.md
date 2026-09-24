# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.8 — EC2 and Security Groups with Terraform

In Lesson 12.7, you built the AWS networking foundation:

```text id="recap-12-7"
VPC
public subnets
private subnets
Internet Gateway
public route table
private route table
route table associations
networking outputs
AWS CLI VPC validation
cost-safe NAT Gateway avoidance
```

Now we add the first real compute layer:

```text id="lesson-focus"
security groups
EC2 instance
Ubuntu AMI lookup
IAM role and instance profile
SSM access model
user_data bootstrap
public IP cost awareness
AWS CLI validation
troubleshooting
cleanup
```

AWS security groups are stateful virtual firewalls for EC2 instances: inbound rules control incoming traffic and outbound rules control outgoing traffic. We will manage security-group rules with separate Terraform resources instead of inline rules, because the current AWS provider documentation warns not to mix standalone VPC security group rule resources with inline `ingress`/`egress` rules on the same security group. ([AWS Documentation][1])

---

# 1. Goal

Create a production-style dev EC2 instance in `ap-south-1` using your existing VPC module.

You will build:

```text id="goal"
real security group module
least-privilege ingress rules
egress rule
IAM role for EC2
IAM instance profile
SSM managed instance permissions
latest Ubuntu AMI lookup
EC2 instance in public subnet for dev
user_data bootstrap
HTTP health endpoint
Terraform outputs for future ALB and Ansible
AWS CLI validation scripts
cleanup to avoid EC2 and public IPv4 charges
```

Architecture:

```text id="architecture"
VPC from Lesson 12.7
  ↓
Public subnet
  ↓
Security group
  ├── inbound HTTP 80 from 0.0.0.0/0
  ├── inbound app port 3002 from your chosen CIDR
  └── outbound all traffic
  ↓
EC2 Ubuntu instance
  ├── public IP for dev testing
  ├── IAM instance profile
  ├── SSM enabled
  └── user_data installs nginx and exposes app health page
```

Cost warning:

```text id="cost-warning"
This lesson creates an EC2 instance and a public IPv4 address.
Destroy it when you are done practicing.
```

AWS charges for public IPv4 addresses whether they are attached to a service or idle; current Amazon VPC pricing lists an hourly charge of `$0.005` for in-use public IPv4 addresses. ([Amazon Web Services, Inc.][2])

---

# 2. What You Will Learn

```text id="lesson-map"
12.8.1   EC2 mental model
12.8.2   security group mental model
12.8.3   stateful SG vs stateless NACL concept
12.8.4   standalone SG rule resources
12.8.5   public subnet EC2 dev pattern
12.8.6   private subnet production pattern
12.8.7   public IP behavior and cost
12.8.8   latest Ubuntu AMI lookup
12.8.9   IAM role vs instance profile
12.8.10  SSM vs SSH access model
12.8.11  user_data bootstrap
12.8.12  compute module real AWS implementation
12.8.13  security-group module real AWS implementation
12.8.14  AWS CLI validation
12.8.15  troubleshooting
12.8.16  cleanup
```

Terraform’s `aws_instance` resource supports `ami`, `instance_type`, `subnet_id`, `vpc_security_group_ids`, `iam_instance_profile`, and `user_data`, and the registry notes that using an IAM instance profile requires `iam:PassRole` permission. ([Terraform Registry][3])

---

# 3. Never Confuse These

## Security Group vs NACL

```text id="sg-vs-nacl"
Security Group:
  instance/ENI-level firewall
  stateful
  allow rules only

Network ACL:
  subnet-level firewall
  stateless
  allow and deny rules
```

For this lesson:

```text id="sg-only"
We manage security groups only.
NACL remains default.
```

---

## Ingress vs Egress

```text id="ingress-egress"
Ingress:
  traffic entering the EC2 instance

Egress:
  traffic leaving the EC2 instance
```

Example:

```text id="ingress-egress-example"
Inbound HTTP:
  client -> EC2:80

Outbound package install:
  EC2 -> internet:443
```

---

## Public Subnet vs Public IP

```text id="public-subnet-vs-public-ip"
Public subnet:
  subnet route table has 0.0.0.0/0 -> Internet Gateway

Public IP:
  address assigned to an EC2 network interface
```

You usually need both for direct internet access:

```text id="public-access-requirements"
public subnet route
public IP
security group allow
NACL allow
app listening
OS firewall allow
```

---

## IAM Role vs Instance Profile

```text id="role-vs-instance-profile"
IAM role:
  permissions policy identity

Instance profile:
  container used to attach IAM role to EC2
```

AWS documentation describes an instance profile as the container that passes IAM role information to an EC2 instance at launch. ([AWS Documentation][4])

---

## SSM vs SSH

```text id="ssm-vs-ssh"
SSH:
  requires key pair, port 22, network path, security group ingress

SSM Session Manager:
  uses AWS Systems Manager agent and IAM permissions
  does not require inbound SSH from the internet
```

Session Manager lets you start sessions through the AWS console, EC2 console, AWS CLI, or SSH integration, but the instance still needs the required Systems Manager setup and permissions. ([AWS Documentation][5])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.8-ec2-security-groups/{notes,scripts,runbooks,reports,user-data}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.8-ec2-security-groups
```

---

# 5. Create EC2 Mental Model Notes

```bash id="ec2-note"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/notes/ec2-security-group-mental-model.md
```

Paste:

```markdown id="ec2-note-content"
# EC2 and Security Group Mental Model

## EC2

EC2 provides virtual machines called instances.

An EC2 instance needs:

- AMI
- instance type
- subnet
- security group
- IAM instance profile if AWS API access is needed
- storage
- tags
- optional user_data

## Security group

A security group is a stateful firewall attached to an ENI or instance.

Inbound rules control traffic entering the instance.
Outbound rules control traffic leaving the instance.

## Public dev pattern

For a learning/dev lab:

- instance in public subnet
- public IP enabled
- HTTP allowed
- SSH avoided if using SSM

## Production pattern

For production:

- instances often live in private subnets
- ALB sits in public subnets
- ALB security group allows internet traffic
- EC2 security group allows traffic only from ALB security group
- access uses SSM or bastion, not broad SSH

## Golden rule

Do not open SSH to 0.0.0.0/0.
Prefer SSM for administration.
```

---

# 6. Create Never-Forget Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/notes/never-confuse-ec2-sg-points.md
```

Paste:

```markdown id="never-note-content"
# Never Forget — EC2 and Security Groups

## 1. Security groups are stateful

If inbound traffic is allowed, response traffic is automatically allowed.

## 2. Security groups only allow

There are no explicit deny rules in security groups.

## 3. Do not mix SG rule styles

Avoid mixing these for the same security group:

- inline ingress/egress inside aws_security_group
- aws_security_group_rule
- aws_vpc_security_group_ingress_rule / egress_rule

Use one style consistently.

## 4. Public IP costs money

Public IPv4 addresses are charged hourly. Destroy test EC2 instances when done.

## 5. Public subnet is route-based

A public subnet needs route to Internet Gateway.

## 6. Instance profile is required for EC2 role attachment

EC2 uses instance profiles to receive role credentials.

## 7. SSM requires IAM permissions

Attach AmazonSSMManagedInstanceCore or equivalent least-privilege custom policy.

## 8. user_data runs at launch

Do not use user_data as a full configuration management replacement.

Later, Ansible will handle richer configuration.

## 9. EC2 in private subnet cannot apt update without NAT or endpoints

No NAT Gateway in this dev VPC means private subnet instances do not have general outbound internet.

## 10. Always validate from both Terraform and AWS CLI

Terraform output is not enough.
Check EC2 state, SG rules, public IP, IAM profile, and HTTP response.
```

---

# 7. Update Security Group Module to Real AWS Resources

From Module 12 root:

```bash id="cd-module-root"
cd ~/devops-masterclass/12-terraform-ansible-iac
```

Update `modules/security-group/versions.tf`:

```bash id="sg-versions"
cat > modules/security-group/versions.tf <<'EOF'
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
  description = "Set of unique allowed ingress ports."
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
  default     = ["0.0.0.0/0"]
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 1))
    ])
    error_message = "All allowed CIDR blocks must be valid."
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

  ingress_rule_matrix = merge([
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

resource "aws_vpc_security_group_ingress_rule" "app_tcp" {
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

Update `modules/security-group/outputs.tf`:

```bash id="sg-outputs"
cat > modules/security-group/outputs.tf <<'EOF'
output "security_group_contract" {
  description = "Security group contract."
  value = {
    security_group_id   = aws_security_group.app.id
    security_group_name = aws_security_group.app.name
    allowed_ports       = sort(tolist(var.allowed_ingress_ports))
    allowed_cidrs       = var.allowed_cidr_blocks
    allow_all_egress    = var.allow_all_egress
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

Update README:

```bash id="sg-readme"
cat > modules/security-group/README.md <<'EOF'
# Security Group Module

## Purpose

Creates the application security group and standalone ingress/egress rule resources.

## Resources

- aws_security_group
- aws_vpc_security_group_ingress_rule
- aws_vpc_security_group_egress_rule

## Rule style

This module uses standalone VPC security group rule resources.

Do not add inline ingress/egress rules to aws_security_group for this same group.

## Inputs

- name_prefix
- common_tags
- vpc_id
- allowed_ingress_ports
- allowed_cidr_blocks
- allow_all_egress

## Outputs

- security_group_contract
- security_group_id
- security_group_name
- allowed_ports

## Production note

For production EC2 behind an ALB, prefer allowing app traffic from the ALB security group instead of 0.0.0.0/0.
EOF
```

---

# 8. Update IAM Module to Real AWS Resources

We need an EC2 role and instance profile so the instance can use Systems Manager.

AWS’s managed policy `AmazonSSMManagedInstanceCore` is described as the policy for an EC2 role to enable AWS Systems Manager service core functionality, and its ARN is `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`. ([AWS Documentation][6])

Update `modules/iam/versions.tf`:

```bash id="iam-versions"
cat > modules/iam/versions.tf <<'EOF'
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

Update `modules/iam/main.tf`:

```bash id="iam-main"
cat > modules/iam/main.tf <<'EOF'
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "AllowEC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-ec2-role"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-instance-profile"
      Component = "iam"
    }
  )
}

resource "terraform_data" "iam_contract" {
  input = {
    instance_role_name        = aws_iam_role.ec2.name
    instance_profile_name     = aws_iam_instance_profile.ec2.name
    enable_ssm                = var.enable_ssm
    app_bucket_names          = var.app_bucket_names
    least_privilege_principle = true
    tags                      = var.common_tags
  }
}
EOF
```

Update `modules/iam/outputs.tf`:

```bash id="iam-outputs"
cat > modules/iam/outputs.tf <<'EOF'
output "contract" {
  description = "IAM module contract."
  value       = terraform_data.iam_contract.output
}

output "instance_profile_name" {
  description = "EC2 instance profile name."
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "EC2 instance profile ARN."
  value       = aws_iam_instance_profile.ec2.arn
}

output "instance_role_name" {
  description = "EC2 IAM role name."
  value       = aws_iam_role.ec2.name
}

output "instance_role_arn" {
  description = "EC2 IAM role ARN."
  value       = aws_iam_role.ec2.arn
}
EOF
```

Update README:

````bash id="iam-readme"
cat > modules/iam/README.md <<'EOF'
# IAM Module

## Purpose

Creates EC2 IAM role and instance profile for compute instances.

## Resources

- aws_iam_role
- aws_iam_role_policy_attachment
- aws_iam_instance_profile

## SSM

When enable_ssm = true, attaches:

```text
arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
````

## Important

Creating an EC2 instance with an IAM instance profile requires the caller to have iam:PassRole permission.

## Outputs

* instance_profile_name
* instance_profile_arn
* instance_role_name
* instance_role_arn
* contract
  EOF

````

Terraform’s IAM role policy attachment resource manages attaching a managed policy to a role, while the IAM instance profile resource creates the profile used by EC2. :contentReference[oaicite:6]{index=6}

---

# 9. Create EC2 User Data Script

Create:

```bash id="userdata-file"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.8-ec2-security-groups/user-data/app-bootstrap.sh.tftpl
````

Paste:

```bash id="userdata-content"
#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y nginx curl jq

cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html>
  <head>
    <title>DevOps Masterclass EC2</title>
  </head>
  <body>
    <h1>DevOps Masterclass EC2 is running</h1>
    <p>Managed by Terraform.</p>
  </body>
</html>
HTML

cat > /var/www/html/health <<'EOF'
healthy
EOF

cat > /var/www/html/metadata.json <<EOF
{
  "project": "${project_name}",
  "environment": "${environment}",
  "app_port": ${app_port},
  "managed_by": "terraform",
  "lesson": "12.8-ec2-security-groups"
}
EOF

cat > /etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        add_header Content-Type text/plain;
        return 200 'healthy\n';
    }
}
NGINX

systemctl enable nginx
systemctl restart nginx

echo "user_data completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /var/log/devops-masterclass-userdata.log
```

Important:

```text id="userdata-note"
user_data is good for bootstrap.
Ansible is better for richer ongoing configuration.
```

---

# 10. Update Compute Module to Real EC2

Update `modules/compute/versions.tf`:

```bash id="compute-versions"
cd ~/devops-masterclass/12-terraform-ansible-iac

cat > modules/compute/versions.tf <<'EOF'
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

Update `modules/compute/variables.tf`:

```bash id="compute-vars"
cat > modules/compute/variables.tf <<'EOF'
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

variable "environment" {
  description = "Environment name."
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "Project name."
  type        = string
  nullable    = false
}

variable "compute_config" {
  description = "Compute configuration."
  type = object({
    instance_type  = string
    instance_count = number
    app_port       = number
    enable_ssm     = bool
  })
  nullable = false

  validation {
    condition     = var.compute_config.instance_count >= 1 && var.compute_config.instance_count <= 6
    error_message = "instance_count must be between 1 and 6."
  }

  validation {
    condition     = var.compute_config.app_port >= 1 && var.compute_config.app_port <= 65535
    error_message = "app_port must be a valid TCP port."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from networking module."
  type        = map(string)
  default     = {}
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from networking module."
  type        = map(string)
  nullable    = false
}

variable "security_group_id" {
  description = "Security group ID from security-group module."
  type        = string
  nullable    = false
}

variable "instance_profile_name" {
  description = "IAM instance profile name."
  type        = string
  nullable    = false
}

variable "use_public_subnet_for_dev" {
  description = "Whether to place EC2 in public subnet for dev testing."
  type        = bool
  default     = true
}

variable "associate_public_ip_address" {
  description = "Whether to associate public IPv4 address."
  type        = bool
  default     = true
}

variable "user_data_template_path" {
  description = "Path to user_data template."
  type        = string
  nullable    = false
}
EOF
```

Update `modules/compute/main.tf`:

```bash id="compute-main"
cat > modules/compute/main.tf <<'EOF'
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*",
      "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  subnet_pool = var.use_public_subnet_for_dev ? var.public_subnet_ids : var.private_subnet_ids

  subnet_keys = sort(keys(local.subnet_pool))

  instance_map = {
    for index in range(var.compute_config.instance_count) :
    "app-${index + 1}" => {
      name      = "${var.name_prefix}-app-${index + 1}"
      subnet_id = local.subnet_pool[local.subnet_keys[index % length(local.subnet_keys)]]
    }
  }

  rendered_user_data = templatefile(var.user_data_template_path, {
    project_name = var.project_name
    environment  = var.environment
    app_port     = var.compute_config.app_port
  })
}

resource "aws_instance" "app" {
  for_each = local.instance_map

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.compute_config.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = var.associate_public_ip_address

  user_data                   = local.rendered_user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.common_tags,
      {
        Name      = "${each.value.name}-root"
        Component = "compute"
      }
    )
  }

  tags = merge(
    var.common_tags,
    {
      Name      = each.value.name
      Component = "compute"
      Role      = "app"
    }
  )
}

resource "terraform_data" "compute_contract" {
  input = {
    ami_id              = data.aws_ami.ubuntu.id
    ami_name            = data.aws_ami.ubuntu.name
    instance_type       = var.compute_config.instance_type
    instance_count      = var.compute_config.instance_count
    app_port            = var.compute_config.app_port
    enable_ssm          = var.compute_config.enable_ssm
    instance_profile    = var.instance_profile_name
    security_group_id   = var.security_group_id
    public_subnet_mode  = var.use_public_subnet_for_dev
    public_ip_enabled   = var.associate_public_ip_address
    instance_ids        = { for key, instance in aws_instance.app : key => instance.id }
    public_ips          = { for key, instance in aws_instance.app : key => instance.public_ip }
    private_ips         = { for key, instance in aws_instance.app : key => instance.private_ip }
    tags                = var.common_tags
  }
}
EOF
```

Canonical’s Ubuntu-on-AWS documentation shows using Canonical’s owner ID `099720109477` to programmatically locate verified Ubuntu AMIs, and HashiCorp’s Terraform tutorials use the same owner ID for Ubuntu AMI data-source examples. ([Ubuntu Documentation][7])

Update `modules/compute/outputs.tf`:

```bash id="compute-outputs"
cat > modules/compute/outputs.tf <<'EOF'
output "contract" {
  description = "Compute module contract."
  value       = terraform_data.compute_contract.output
}

output "ami_id" {
  description = "Ubuntu AMI ID."
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Ubuntu AMI name."
  value       = data.aws_ami.ubuntu.name
}

output "instance_ids" {
  description = "EC2 instance IDs."
  value       = { for key, instance in aws_instance.app : key => instance.id }
}

output "instance_names" {
  description = "EC2 instance names."
  value       = { for key, instance in aws_instance.app : key => instance.tags["Name"] }
}

output "public_ips" {
  description = "EC2 public IPv4 addresses."
  value       = { for key, instance in aws_instance.app : key => instance.public_ip }
}

output "private_ips" {
  description = "EC2 private IPv4 addresses."
  value       = { for key, instance in aws_instance.app : key => instance.private_ip }
}

output "app_port" {
  description = "Application port."
  value       = var.compute_config.app_port
}

output "first_instance_id" {
  description = "First EC2 instance ID."
  value       = values(aws_instance.app)[0].id
}

output "first_public_ip" {
  description = "First public IPv4 address."
  value       = values(aws_instance.app)[0].public_ip
}

output "first_private_ip" {
  description = "First private IPv4 address."
  value       = values(aws_instance.app)[0].private_ip
}
EOF
```

Update README:

````bash id="compute-readme"
cat > modules/compute/README.md <<'EOF'
# Compute Module

## Purpose

Creates EC2 app instances.

## Resources

- aws_instance
- aws_ami data source
- terraform_data contract

## AMI

Uses latest Ubuntu 24.04 Noble AMI from Canonical owner ID:

```text
099720109477
````

## Access

This module is designed to use AWS Systems Manager Session Manager instead of broad public SSH.

## User data

Bootstraps nginx and health endpoint.

## Inputs

* name_prefix
* common_tags
* environment
* project_name
* compute_config
* public_subnet_ids
* private_subnet_ids
* security_group_id
* instance_profile_name
* use_public_subnet_for_dev
* associate_public_ip_address
* user_data_template_path

## Outputs

* instance_ids
* public_ips
* private_ips
* first_instance_id
* first_public_ip
* first_private_ip
* ami_id
* ami_name
* app_port
* contract

## Production note

For production, prefer private subnet instances behind ALB, not direct public EC2 exposure.
EOF

````

---

# 11. Update Environment Root Composition

Update all environment `main.tf` files:

```bash id="root-main-update"
cat > /tmp/module12_8_main.tf <<'EOF'
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
  target_instance_ids = values(module.compute.instance_ids)
  app_port            = module.compute.app_port
  enable_alb          = var.feature_flags.enable_alb
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
      "load_balancer -> cdn",
      "storage -> iam",
    ]

    vpc_id                = module.networking.vpc_id
    security_group_id     = module.security_group.security_group_id
    instance_ids          = module.compute.instance_ids
    public_ips            = module.compute.public_ips
    private_ips           = module.compute.private_ips
    load_balancer_dns     = module.load_balancer.alb_dns_name
    cdn_domain_name       = module.cdn.distribution_domain_name
    assets_bucket_name    = module.storage.assets_bucket_name
    instance_profile_name = module.iam.instance_profile_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_8_main.tf environments/$env/main.tf
done
````

---

# 12. Add `allowed_cidr_blocks` Variable

Update all environment `variables.tf` files by adding this variable:

```bash id="add-cidr-variable"
python3 - <<'PY'
from pathlib import Path

block = '''
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach EC2 application ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 1))
    ])
    error_message = "All allowed_cidr_blocks values must be valid CIDR blocks."
  }
}
'''

for env in ["dev", "staging", "prod"]:
    p = Path(f"environments/{env}/variables.tf")
    s = p.read_text()
    if 'variable "allowed_cidr_blocks"' not in s:
        s = s + "\n" + block
    p.write_text(s)
PY
```

Update `terraform.tfvars.example` files.

For dev:

```bash id="dev-cidr-tfvars"
python3 - <<'PY'
from pathlib import Path
p = Path("environments/dev/terraform.tfvars.example")
s = p.read_text()
if "allowed_cidr_blocks" not in s:
    s += '\nallowed_cidr_blocks = ["0.0.0.0/0"]\n'
p.write_text(s)
PY
```

For staging and prod, keep restrictive examples:

```bash id="stage-prod-cidr-tfvars"
python3 - <<'PY'
from pathlib import Path
for env in ["staging", "prod"]:
    p = Path(f"environments/{env}/terraform.tfvars.example")
    s = p.read_text()
    if "allowed_cidr_blocks" not in s:
        s += '\n# Replace with your office/VPN CIDR in real environments.\nallowed_cidr_blocks = ["203.0.113.10/32"]\n'
    p.write_text(s)
PY
```

Important:

```text id="allowed-cidr-note"
For learning, dev uses 0.0.0.0/0 for HTTP/app testing.
For real environments, restrict CIDRs or use ALB-to-EC2 security-group referencing.
```

---

# 13. Update Environment Outputs

```bash id="root-outputs-update"
cat > /tmp/module12_8_outputs.tf <<'EOF'
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
  description = "Security group module contract."
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

output "future_ansible_inventory_contract" {
  description = "Future handoff contract for Ansible inventory generation."
  value = {
    environment        = local.normalized_env
    instance_names     = module.compute.instance_names
    instance_ids       = module.compute.instance_ids
    public_ips         = module.compute.public_ips
    private_ips        = module.compute.private_ips
    app_port           = module.compute.app_port
    instance_role_name = module.iam.instance_role_name
    security_group_id  = module.security_group.security_group_id
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_8_outputs.tf environments/$env/outputs.tf
done
```

---

# 14. AWS/IAM Prerequisites

Check AWS identity:

```bash id="aws-identity"
cd ~/devops-masterclass

aws sts get-caller-identity
aws configure list

export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

You need permissions for:

```text id="needed-permissions"
ec2:RunInstances
ec2:TerminateInstances
ec2:DescribeInstances
ec2:CreateSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:RevokeSecurityGroupIngress
ec2:RevokeSecurityGroupEgress
ec2:CreateTags
iam:CreateRole
iam:CreateInstanceProfile
iam:AddRoleToInstanceProfile
iam:AttachRolePolicy
iam:PassRole
```

Important:

```text id="iam-passrole"
If EC2 creation fails with iam:PassRole, your user/role cannot pass the EC2 role to the instance.
```

---

# 15. Plan Dev EC2

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

Initialize:

```bash id="dev-init"
terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

Format and validate:

```bash id="dev-fmt-validate"
terraform fmt -recursive
terraform validate
```

Plan:

```bash id="dev-plan"
terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-8-dev
```

Review:

```bash id="dev-show"
terraform show tfplan-12-8-dev
```

Expected new resources:

```text id="expected-plan"
module.security_group.aws_security_group.app
module.security_group.aws_vpc_security_group_ingress_rule.app_tcp
module.security_group.aws_vpc_security_group_egress_rule.all_outbound
module.iam.aws_iam_role.ec2
module.iam.aws_iam_role_policy_attachment.ssm_core
module.iam.aws_iam_instance_profile.ec2
module.compute.data.aws_ami.ubuntu
module.compute.aws_instance.app["app-1"]
```

---

# 16. Apply Dev EC2

```bash id="dev-apply"
terraform apply tfplan-12-8-dev
```

Wait until EC2 is running:

```bash id="wait-output"
terraform output first_ec2_instance_id
terraform output first_ec2_public_ip
```

Store values:

```bash id="store-values"
INSTANCE_ID="$(terraform output -raw first_ec2_instance_id)"
PUBLIC_IP="$(terraform output -raw first_ec2_public_ip)"
SG_ID="$(terraform output -json security_group_contract | jq -r '.security_group_id')"

echo "INSTANCE_ID=$INSTANCE_ID"
echo "PUBLIC_IP=$PUBLIC_IP"
echo "SG_ID=$SG_ID"
```

---

# 17. Validate EC2 with AWS CLI

## Instance state

```bash id="describe-instance"
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,VpcId:VpcId,IamProfile:IamInstanceProfile.Arn}' \
  --output table
```

Expected:

```text id="instance-expected"
State = running
InstanceType = t2.micro
PublicIp exists for dev
IAM profile attached
```

---

## Security group rules

```bash id="describe-sg"
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

Expected:

```text id="sg-expected"
Ingress allows TCP 80, 443, 3002 depending on dev tfvars.
Egress allows outbound traffic.
```

---

## IAM profile

```bash id="describe-profile"
PROFILE_NAME="$(terraform output -json iam_contract | jq -r '.instance_profile_name')"

aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --query 'InstanceProfile.{Name:InstanceProfileName,Roles:Roles[].RoleName}' \
  --output table
```

---

## HTTP health check

User data can take a minute or two.

```bash id="http-health"
curl -I "http://$PUBLIC_IP/"
curl "http://$PUBLIC_IP/health"
curl "http://$PUBLIC_IP/metadata.json"
```

Expected:

```text id="http-expected"
HTTP 200
healthy
metadata JSON
```

If it fails immediately:

```bash id="wait-health"
for i in {1..30}; do
  echo "attempt $i"
  curl -fsS "http://$PUBLIC_IP/health" && break || true
  sleep 10
done
```

---

# 18. Validate SSM Readiness

Check SSM instance information:

```bash id="ssm-check"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,PlatformName:PlatformName,AgentVersion:AgentVersion}' \
  --output table
```

Expected eventually:

```text id="ssm-expected"
PingStatus = Online
```

If the instance is not online yet, wait and retry:

```bash id="ssm-wait"
for i in {1..30}; do
  aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[].PingStatus' \
    --output text
  sleep 10
done
```

Start session if AWS CLI Session Manager plugin is installed and IAM allows it:

```bash id="ssm-start-session"
aws ssm start-session --target "$INSTANCE_ID"
```

Inside session:

```bash id="ssm-inside"
hostname
curl http://127.0.0.1/health
sudo systemctl status nginx --no-pager
exit
```

If `start-session` is not available, install the Session Manager plugin for your OS or use the AWS console.

---

# 19. Create EC2 Validation Script

```bash id="validation-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh
```

Paste:

```bash id="validation-content"
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

echo "===== EC2 AWS Validation ====="
echo "Environment: $ENVIRONMENT"

INSTANCE_ID="$(terraform output -raw first_ec2_instance_id)"
PUBLIC_IP="$(terraform output -raw first_ec2_public_ip)"
SG_ID="$(terraform output -json security_group_contract | jq -r '.security_group_id')"
PROFILE_NAME="$(terraform output -json iam_contract | jq -r '.instance_profile_name')"

echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Security Group: $SG_ID"
echo "Instance Profile: $PROFILE_NAME"

echo
echo "Instance:"
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,InstanceType:InstanceType,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,VpcId:VpcId,IamProfile:IamInstanceProfile.Arn}' \
  --output table

STATE="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)"

if [ "$STATE" != "running" ]; then
  echo "ERROR: instance is not running."
  exit 1
fi

echo
echo "Security group:"
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json

echo
echo "IAM instance profile:"
aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --query 'InstanceProfile.{Name:InstanceProfileName,Roles:Roles[].RoleName}' \
  --output table

if [ "$ENVIRONMENT" = "dev" ]; then
  echo
  echo "HTTP health check:"
  for i in {1..30}; do
    if curl -fsS "http://$PUBLIC_IP/health"; then
      echo
      echo "HTTP health check passed."
      break
    fi

    if [ "$i" -eq 30 ]; then
      echo "ERROR: HTTP health check failed after retries."
      exit 1
    fi

    echo "Waiting for user_data/nginx... attempt $i"
    sleep 10
  done
else
  echo "Skipping public HTTP validation for non-dev environment."
fi

echo
echo "SSM managed instance check:"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,PlatformName:PlatformName,AgentVersion:AgentVersion}' \
  --output table || true

echo
echo "EC2 AWS validation completed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh
```

Run:

```bash id="run-validation"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh
```

---

# 20. Create EC2 Plan Script

```bash id="plan-script"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/plan-ec2.sh
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
REPORT_DIR="../../12.8-ec2-security-groups/reports"

mkdir -p "$BASE/12.8-ec2-security-groups/reports"

cd "$ENV_DIR"

echo "===== Terraform EC2 Plan ====="
echo "Environment: $ENVIRONMENT"
echo "Current workspace: $(terraform workspace show 2>/dev/null || echo not-initialized)"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -recursive
terraform validate

terraform plan -var-file=terraform.tfvars.example -out="tfplan-12-8-$ENVIRONMENT"
terraform show -no-color "tfplan-12-8-$ENVIRONMENT" > "$REPORT_DIR/$ENVIRONMENT-ec2-plan.txt"

echo
echo "Plan saved:"
echo "$BASE/12.8-ec2-security-groups/reports/$ENVIRONMENT-ec2-plan.txt"
echo
echo "Apply manually from $ENV_DIR with:"
echo "terraform apply tfplan-12-8-$ENVIRONMENT"
```

Make executable:

```bash id="chmod-plan"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/plan-ec2.sh
```

Run:

```bash id="run-plan"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/plan-ec2.sh
```

---

# 21. Create EC2 Summary Script

```bash id="summary-script"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/ec2-summary.sh
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

echo "===== EC2 Terraform Summary ====="
echo "Environment: $ENVIRONMENT"

terraform output ec2_instance_ids
terraform output ec2_public_ips
terraform output ec2_private_ips
terraform output security_group_contract
terraform output iam_contract
terraform output future_ansible_inventory_contract

echo
echo "State addresses:"
terraform state list | grep -E 'module.compute|module.security_group|module.iam|aws_instance|aws_security_group|aws_iam' | sort || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/ec2-summary.sh
```

Run:

```bash id="run-summary"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/ec2-summary.sh
```

---

# 22. Create Lesson Validation Script

This validates files and Terraform configuration. It does not automatically create EC2.

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-lesson-12-8.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.8 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.8-ec2-security-groups"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/user-data"

test -f "$LESSON/notes/ec2-security-group-mental-model.md"
test -f "$LESSON/notes/never-confuse-ec2-sg-points.md"
test -f "$LESSON/user-data/app-bootstrap.sh.tftpl"

test -x "$LESSON/scripts/validate-ec2-aws.sh"
test -x "$LESSON/scripts/plan-ec2.sh"
test -x "$LESSON/scripts/ec2-summary.sh"

test -f "$BASE/modules/security-group/main.tf"
test -f "$BASE/modules/security-group/variables.tf"
test -f "$BASE/modules/security-group/outputs.tf"

test -f "$BASE/modules/compute/main.tf"
test -f "$BASE/modules/compute/variables.tf"
test -f "$BASE/modules/compute/outputs.tf"

test -f "$BASE/modules/iam/main.tf"
test -f "$BASE/modules/iam/variables.tf"
test -f "$BASE/modules/iam/outputs.tf"

grep -q 'resource "aws_security_group" "app"' "$BASE/modules/security-group/main.tf"
grep -q 'resource "aws_vpc_security_group_ingress_rule" "app_tcp"' "$BASE/modules/security-group/main.tf"
grep -q 'resource "aws_vpc_security_group_egress_rule" "all_outbound"' "$BASE/modules/security-group/main.tf"

grep -q 'resource "aws_instance" "app"' "$BASE/modules/compute/main.tf"
grep -q 'data "aws_ami" "ubuntu"' "$BASE/modules/compute/main.tf"
grep -q 'metadata_options' "$BASE/modules/compute/main.tf"
grep -q 'user_data_replace_on_change' "$BASE/modules/compute/main.tf"

grep -q 'resource "aws_iam_role" "ec2"' "$BASE/modules/iam/main.tf"
grep -q 'resource "aws_iam_instance_profile" "ec2"' "$BASE/modules/iam/main.tf"
grep -q 'AmazonSSMManagedInstanceCore' "$BASE/modules/iam/main.tf"

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
    -out="tfplan-12-8-validation-$env" >/dev/null

  terraform show -no-color "tfplan-12-8-validation-$env" >/dev/null
  rm -f "tfplan-12-8-validation-$env"

  popd >/dev/null
done

echo
echo "Lesson 12.8 validation passed."
echo
echo "After applying dev, validate AWS resources with:"
echo "ENVIRONMENT=dev ./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh"
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-lesson-12-8.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-lesson-12-8.sh
```

---

# 23. Cleanup Scripts

## Local artifacts only

```bash id="local-cleanup"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-local.sh
```

Paste:

```bash id="local-cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.8 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

echo "Local Terraform plan artifacts cleaned."
echo "AWS resources were not destroyed."
```

Make executable:

```bash id="chmod-local-cleanup"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-local.sh
```

Run:

```bash id="run-local-cleanup"
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-local.sh
```

---

## Destroy dev EC2 resources

This will destroy resources managed by the dev environment root module, including VPC resources from Lesson 12.7 unless you later separate destroy targets. Use this only when you are done with EC2/VPC labs.

```bash id="destroy-script"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-dev.sh
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

echo "===== Cleanup Lesson 12.8 Dev Resources ====="
echo "Current workspace: $(terraform workspace show)"

terraform plan -destroy -var-file=terraform.tfvars.example -out=tfplan-destroy-12-8-dev
terraform show tfplan-destroy-12-8-dev

echo
echo "This destroy plan may include EC2, security groups, IAM, and VPC resources."
echo "Review carefully."
echo "Type DESTROY_DEV_EC2_VPC to continue:"
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY_DEV_EC2_VPC" ]; then
  echo "Cleanup cancelled."
  rm -f tfplan-destroy-12-8-dev
  exit 0
fi

terraform apply tfplan-destroy-12-8-dev
rm -f tfplan-destroy-12-8-dev

echo "Dev EC2/VPC resources destroyed."
```

Make executable:

```bash id="chmod-destroy"
chmod +x 12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-dev.sh
```

Run only when finished:

```bash id="run-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-dev.sh
```

Recommended:

```text id="keep-or-destroy"
Keep dev resources if continuing directly to Lesson 12.9 ALB and Target Groups.
Destroy if you are stopping for the day to avoid EC2/public IPv4 costs.
```

---

# 24. EC2 Troubleshooting Runbook

Create:

```bash id="runbook"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/runbooks/ec2-security-group-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# EC2 and Security Group Troubleshooting Runbook

## 1. Check AWS identity

```bash
aws sts get-caller-identity
aws configure list
````

## 2. Check Terraform context

```bash id="tf-context"
pwd
terraform workspace show
terraform state list
```

## 3. Check instance

```bash id="instance-check"
aws ec2 describe-instances \
  --instance-ids INSTANCE_ID \
  --query 'Reservations[0].Instances[0].{State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,VpcId:VpcId,IamProfile:IamInstanceProfile.Arn}'
```

## 4. Check security group

```bash id="sg-check"
aws ec2 describe-security-groups --group-ids SG_ID
```

## 5. Check HTTP

```bash id="http-check"
curl -I http://PUBLIC_IP/
curl http://PUBLIC_IP/health
```

## 6. Check user_data logs through SSM

```bash id="userdata-logs"
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/devops-masterclass-userdata.log
sudo systemctl status nginx --no-pager
```

## 7. Check SSM

```bash id="ssm-check"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=INSTANCE_ID"
```

## Common errors

### UnauthorizedOperation

Likely missing EC2 permission.

### iam:PassRole denied

Caller cannot pass the EC2 role to the instance.

### HTTP timeout

Check:

* instance running
* public IP exists
* public subnet route to IGW
* security group inbound rule
* nginx running
* user_data completed
* NACL rules

### SSM not online

Check:

* IAM instance profile attached
* AmazonSSMManagedInstanceCore attached
* SSM agent installed/running
* outbound internet path exists
* VPC endpoints if private subnet without NAT
* time sync/DNS

### Instance launched but no public IP

Check:

* associate_public_ip_address
* subnet map_public_ip_on_launch
* subnet route table

### Terraform recreates EC2 after user_data change

This lesson uses:

```hcl id="2xbdea"
user_data_replace_on_change = true
```

So user_data changes intentionally replace the instance.

## Golden rule

Connectivity needs network path + public IP + security group + running service.

````

---

# 25. Security Group Runbook

```bash id="sg-runbook"
nano 12-terraform-ansible-iac/12.8-ec2-security-groups/runbooks/security-group-design-runbook.md
````

Paste:

````markdown id="sg-runbook-content"
# Security Group Design Runbook

## Dev pattern

For learning:

```text
HTTP 80 from 0.0.0.0/0
App port 3002 from 0.0.0.0/0 or your IP
No SSH if using SSM
All egress
````

## Better production pattern

```text
ALB SG:
  80/443 from internet

EC2 SG:
  app port only from ALB SG

Admin access:
  SSM, not SSH from internet
```

## Avoid

```text
22 from 0.0.0.0/0
all TCP from 0.0.0.0/0
all ports from internet
mixing inline and standalone rule resources
```

## Terraform rule style

Use standalone resources consistently:

```hcl
aws_vpc_security_group_ingress_rule
aws_vpc_security_group_egress_rule
```

Do not mix with inline `ingress` or `egress` on the same security group.

## Golden rule

Open the minimum path required for the application.

````

---

# 26. Common Errors and Fixes

## Error 1 — `iam:PassRole` denied

Example:

```text id="passrole-error"
User is not authorized to perform iam:PassRole
````

Cause:

```text id="passrole-cause"
Terraform is trying to launch EC2 with an IAM instance profile.
Your caller must be allowed to pass that role.
```

Fix IAM policy example:

```json id="passrole-policy"
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/devops-masterclass-dev-ec2-role"
}
```

---

## Error 2 — HTTP timeout

Run:

```bash id="http-timeout-debug"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID"
aws ec2 describe-security-groups --group-ids "$SG_ID"
curl -v "http://$PUBLIC_IP/health"
```

Check:

```text id="http-timeout-checks"
public IP exists
subnet public route exists
security group allows 80
nginx installed
user_data finished
instance status checks passed
```

---

## Error 3 — SSM not online

Check:

```bash id="ssm-debug"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID"
```

Common causes:

```text id="ssm-causes"
missing IAM instance profile
missing AmazonSSMManagedInstanceCore
SSM agent not installed/running
no outbound internet path
private subnet without NAT or VPC endpoints
```

Ubuntu AMIs usually include SSM Agent in many AWS images, but do not assume every custom AMI does. Validate.

---

## Error 4 — Security group rule conflict

Cause:

```text id="sg-conflict"
Mixed inline ingress/egress rules with standalone rule resources.
```

Fix:

```text id="sg-conflict-fix"
Use one rule management style consistently.
This course uses aws_vpc_security_group_ingress_rule and egress_rule.
```

---

## Error 5 — AMI data source returns no result

Check:

```bash id="ami-debug"
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate)[-5:].{Name:Name,ImageId:ImageId,CreationDate:CreationDate}' \
  --output table
```

Fix:

```text id="ami-fix"
Adjust AMI name filter.
Verify region.
Verify architecture.
```

Terraform’s `aws_ami` data source fails if its filters do not resolve to exactly one AMI when `most_recent` is not enough or the filter is too narrow/broad. ([Terraform Registry][8])

---

# 27. Cost Safety

Created resources may include:

```text id="cost-resources"
EC2 instance
public IPv4 address
EBS root volume
security group
IAM role
IAM instance profile
```

Cost controls:

```text id="cost-controls"
instance_count = 1 in dev
t2.micro in dev
8 GiB gp3 root volume
destroy when done
no Elastic IP
no NAT Gateway
```

Check EC2 running instances:

```bash id="cost-check"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

Destroy when done:

```bash id="cost-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-dev.sh
```

---

# 28. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is an EC2 instance?
What is an AMI?
Why use aws_ami data source?
What is Canonical owner ID for Ubuntu AMIs?
What is a security group?
Are security groups stateful?
What is the difference between ingress and egress?
Why should you not open SSH to 0.0.0.0/0?
What is an IAM role?
What is an instance profile?
Why does EC2 need an instance profile?
What is iam:PassRole?
What does AmazonSSMManagedInstanceCore provide?
How is SSM different from SSH?
What does user_data do?
Why is user_data not a replacement for Ansible?
Why can public IPv4 create cost?
Why place dev EC2 in a public subnet but prod EC2 behind ALB/private subnet?
How do you validate EC2 with AWS CLI?
How do you debug HTTP timeout?
How do you debug SSM not online?
```

Strong interview answer:

```text id="interview-answer"
I built a Terraform compute layer that creates EC2 instances using a reusable compute module, a security group module, and an IAM module. The compute module looks up the latest Ubuntu AMI from Canonical, launches EC2 with an encrypted gp3 root volume, attaches a security group, attaches an IAM instance profile, enables IMDSv2, and uses user_data for lightweight bootstrap.

For access, I prefer Systems Manager Session Manager instead of exposing SSH to the internet. That requires an EC2 IAM role, an instance profile, and SSM permissions such as AmazonSSMManagedInstanceCore. I understand that the Terraform caller also needs iam:PassRole to launch an instance with that role.

For security groups, I avoid mixing inline rules and standalone rules. I use standalone ingress and egress rule resources, validate ports and CIDRs, and keep dev exposure minimal. In production, EC2 instances should usually live in private subnets and accept app traffic only from an ALB security group. After apply, I validate with AWS CLI by checking instance state, public/private IPs, security group rules, IAM profile, HTTP health endpoint, and SSM managed instance status.
```

Resume bullet:

```text id="resume-bullet"
Built a Terraform EC2 compute layer in AWS ap-south-1 with reusable security-group, IAM, and compute modules, latest Ubuntu AMI lookup, EC2 IAM role and instance profile, AmazonSSMManagedInstanceCore attachment, IMDSv2 enforcement, encrypted gp3 root volume, user_data nginx bootstrap, least-privilege security group rule structure, dev public subnet deployment, AWS CLI validation scripts, SSM readiness checks, cost-safety cleanup, and troubleshooting runbooks.
```

---

# 29. Commit Lesson 12.8

Clean local plans only:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-local.sh
```

Validate files and Terraform config:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-lesson-12-8.sh
```

If you applied dev EC2, validate AWS resources:

```bash id="validate-aws-before-commit"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.8-ec2-security-groups -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/modules/{compute,security-group,iam} -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add EC2 and security group Terraform modules"

git push
```

---

# 30. Keep or Destroy?

For the next lesson, you should usually **keep the dev resources** because Lesson 12.9 adds an ALB and target group in front of the EC2 instance.

Keep:

```text id="keep"
Recommended if continuing directly to Lesson 12.9.
```

Destroy:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/cleanup-lesson-12-8-dev.sh
```

---

# 31. Next Lesson

```text id="next-lesson"
12.9 — ALB and Target Groups with Terraform
```

We will build:

```text id="next-topics"
Application Load Balancer
ALB security group
target group
target attachment
listener
health checks
EC2 security group rule from ALB SG
public ALB + private/protected EC2 pattern
HTTP validation through ALB DNS
target health troubleshooting
502/503 debugging
future CloudFront ALB origin readiness
cleanup and cost safety
```

[1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html?icmpid=docs_ec2_console&utm_source=chatgpt.com "Amazon EC2 security groups for your EC2 instances - Amazon Elastic Compute Cloud"
[2]: https://aws.amazon.com/vpc/pricing/?utm_source=chatgpt.com "Amazon VPC Pricing"
[3]: https://registry.terraform.io/providers/-/aws/latest/docs/resources/instance?utm_source=chatgpt.com "aws_instance | Resources | hashicorp/aws | Terraform | Terraform Registry"
[4]: https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html?utm_source=chatgpt.com "Configure instance permissions required for Systems Manager - AWS Systems Manager"
[5]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html?utm_source=chatgpt.com "AWS Systems Manager Session Manager - AWS Systems Manager"
[6]: https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html?utm_source=chatgpt.com "AmazonSSMManagedInstanceCore - AWS Managed Policy"
[7]: https://documentation.ubuntu.com/aws/en/latest/aws-how-to/instances/find-ubuntu-images/?utm_source=chatgpt.com "Find Ubuntu images on AWS - Ubuntu on AWS documentation"
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami.html?utm_source=chatgpt.com "aws_ami | Data Sources | hashicorp/aws | Terraform | Terraform Registry"
