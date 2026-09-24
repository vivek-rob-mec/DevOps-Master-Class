# AWS Masterclass — Lesson 21

## Build Phase 1 — Terraform Production Capstone Foundation

Now that the 20-lesson AWS track is complete, we move into the **build phase**.

We will build the final production architecture step by step, not all at once:

```text
Phase 1: Terraform repo foundation, providers, remote-safe structure, tags
Phase 2: VPC, public/private app/private DB subnets
Phase 3: S3 private bucket + CloudFront OAC
Phase 4: ALB + target group + ECS Fargate
Phase 5: RDS/DynamoDB + Secrets Manager
Phase 6: CloudWatch alarms, dashboards, logs
Phase 7: CI/CD with ECR and deployment artifacts
Phase 8: final cleanup, resume, interview explanation
```

Today we create the **Terraform foundation** and a **safe VPC module**. No NAT Gateway, RDS, ALB, or ECS yet, so this phase stays low-cost.

CloudFront OAC will be used later for private S3 access; AWS recommends OAC for restricting access to S3 origins through CloudFront, and the bucket policy can scope access to a specific CloudFront distribution using `AWS:SourceArn`. ([AWS Documentation][1]) For ECS Fargate later, remember that tasks using `awsvpc` networking require target group type `ip`, not `instance`. ([AWS Documentation][2])

---

## Goal

Create a Terraform project for the production capstone:

```text
Region:
  ap-south-1

Global exception:
  us-east-1 for CloudFront ACM later

Creates today:
  Terraform repo structure
  provider config
  variables
  tags
  VPC module
  public subnets
  private app subnets
  private DB subnets
  route tables
  Internet Gateway
  no NAT Gateway yet
```

---

## Architecture for today

```text
VPC 10.30.0.0/16

Public subnets:
  10.30.1.0/24
  10.30.2.0/24

Private app subnets:
  10.30.11.0/24
  10.30.12.0/24

Private DB subnets:
  10.30.21.0/24
  10.30.22.0/24

Public route table:
  0.0.0.0/0 -> Internet Gateway

Private route tables:
  local-only for now
```

A subnet belongs to one Availability Zone, and ALB target health checks require targets to be registered to a target group used by a listener rule with the target AZ enabled for the load balancer. ([AWS Documentation][3])

---

# Step 1 — Create project structure

```bash
mkdir -p ~/aws-production-capstone
cd ~/aws-production-capstone

mkdir -p \
  environments/dev \
  modules/networking \
  modules/security-groups \
  modules/storage \
  modules/cdn \
  modules/compute \
  modules/database \
  modules/iam \
  modules/observability \
  scripts \
  docs
```

Create `.gitignore`:

```bash
cat > .gitignore <<'EOF'
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.lock.hcl
plans/
EOF
```

For a real team, you can commit `.terraform.lock.hcl`, but for this learning repo we keep the initial setup simple.

---

# Step 2 — Root Terraform files

Create `environments/dev/provider.tf`:

```bash
cat > environments/dev/provider.tf <<'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}
EOF
```

Create `environments/dev/variables.tf`:

```bash
cat > environments/dev/variables.tf <<'EOF'
variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aws-production-capstone"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Resource owner"
  type        = string
  default     = "vivek"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.30.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 2
}
EOF
```

Create `environments/dev/locals.tf`:

```bash
cat > environments/dev/locals.tf <<'EOF'
locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Application = "production-capstone"
  }
}
EOF
```

Create `environments/dev/main.tf`:

```bash
cat > environments/dev/main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
}
EOF
```

Create `environments/dev/outputs.tf`:

```bash
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
EOF
```

---

# Step 3 — Networking module

Create `modules/networking/variables.tf`:

```bash
cat > modules/networking/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "az_count" {
  description = "Number of AZs"
  type        = number
  default     = 2
}
EOF
```

Create `modules/networking/main.tf`:

```bash
cat > modules/networking/main.tf <<'EOF'
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnet_cidrs = [
    "10.30.1.0/24",
    "10.30.2.0/24"
  ]

  private_app_subnet_cidrs = [
    "10.30.11.0/24",
    "10.30.12.0/24"
  ]

  private_db_subnet_cidrs = [
    "10.30.21.0/24",
    "10.30.22.0/24"
  ]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-app-${count.index + 1}"
    Tier = "private-app"
  }
}

resource "aws_subnet" "private_db" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_db_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-db-${count.index + 1}"
    Tier = "private-db"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_default_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count = var.az_count

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_app" {
  count = var.az_count

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_db" {
  count = var.az_count

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-db-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_db" {
  count = var.az_count

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}
EOF
```

Create `modules/networking/outputs.tf`:

```bash
cat > modules/networking/outputs.tf <<'EOF'
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.private_db[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  value = aws_route_table.private_app[*].id
}

output "private_db_route_table_ids" {
  value = aws_route_table.private_db[*].id
}
EOF
```

---

# Step 4 — Validate Terraform locally

```bash
cd ~/aws-production-capstone/environments/dev

terraform init
terraform fmt -recursive ../.. 
terraform validate
```

Create a plan:

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see resources like:

```text
aws_vpc
aws_internet_gateway
aws_subnet.public
aws_subnet.private_app
aws_subnet.private_db
aws_route_table
aws_route
aws_route_table_association
```

---

# Step 5 — Optional apply

This creates low-cost networking resources, but still verify your account before applying.

```bash
terraform apply tfplan
```

Validate:

```bash
terraform output

aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=aws-production-capstone" \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State}' \
  --output table

aws ec2 describe-subnets \
  --filters "Name=tag:Project,Values=aws-production-capstone" \
  --query 'Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

---

# Step 6 — Cleanup

If you applied and want to remove everything:

```bash
cd ~/aws-production-capstone/environments/dev
terraform destroy
```

Verify nothing remains:

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=aws-production-capstone" \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State}' \
  --output table
```

---

# Common errors and fixes

## Error: `NoCredentialProviders` or credential error

Check:

```bash
aws sts get-caller-identity
aws configure list
```

Fix your AWS profile or environment variables.

---

## Error: `UnauthorizedOperation`

Your IAM identity lacks EC2/VPC permissions.

You likely need permissions such as:

```text
ec2:CreateVpc
ec2:CreateSubnet
ec2:CreateInternetGateway
ec2:AttachInternetGateway
ec2:CreateRouteTable
ec2:CreateRoute
ec2:AssociateRouteTable
ec2:CreateTags
ec2:Describe*
```

Start troubleshooting with:

```bash
aws sts get-caller-identity
```

---

## Error: CIDR conflict

If `10.30.0.0/16` already exists or overlaps with another connected network, change:

```hcl
vpc_cidr = "10.31.0.0/16"
```

Then update the subnet CIDRs in the module.

---

## Error: destroy fails with dependency violation

Usually a subnet, route table, or gateway still has dependencies.

Run:

```bash
terraform state list
terraform destroy
```

If you later add ALB, NAT, endpoints, ECS, or RDS, destroy order becomes more important.

---

# Resume-ready takeaway

```text
Built the Terraform foundation for a production AWS platform in ap-south-1, including modular VPC design with public, private application, and private database subnets, route tables, Internet Gateway routing, standard tags, provider aliases, and environment-based structure for future CloudFront, ECS Fargate, RDS, observability, and CI/CD modules.
```

# Next build phase

```text
Lesson 22 — Add security groups, private S3 bucket, CloudFront OAC design files, and ECR repository for the container image.
```

[1]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html?utm_source=chatgpt.com "Use various origins with CloudFront distributions - Amazon CloudFront"
[2]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/glb.html?utm_source=chatgpt.com "Use a Gateway Load Balancer for Amazon ECS - Amazon Elastic Container Service"
[3]: https://docs.aws.amazon.com/en_en/elasticloadbalancing/latest/application/target-group-health-checks.html?utm_source=chatgpt.com "Health checks for Application Load Balancer target groups - Elastic Load Balancing"
