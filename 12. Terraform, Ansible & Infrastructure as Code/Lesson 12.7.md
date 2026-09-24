# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.7 — AWS VPC Infrastructure with Terraform

In Lesson 12.6, you learned Terraform workspaces:

```text id="recap-12-6"
default workspace
named workspaces
workspace-specific state
terraform.workspace
workspace vs environment folders
workspace safety guards
wrong-workspace incident runbooks
```

Now we start building **real AWS infrastructure**.

This lesson creates a production-style VPC foundation in:

```text id="region"
ap-south-1
```

We will create:

```text id="aws-resources"
VPC
public subnets
private subnets
Internet Gateway
public route table
private route table
public route to Internet Gateway
route table associations
VPC outputs for future EC2 and ALB modules
```

We will **not create a NAT Gateway by default** because NAT Gateway has hourly and data-processing charges. AWS states that NAT Gateways are charged for each hour they are available and for each GB processed. ([AWS Documentation][1])

---

# 1. Goal

Build the real AWS networking layer that future lessons will use.

Architecture:

```text id="architecture"
VPC: 10.10.0.0/16

Public Subnet 1: 10.10.1.0/24
Public Subnet 2: 10.10.2.0/24

Private Subnet 1: 10.10.11.0/24
Private Subnet 2: 10.10.12.0/24

Internet Gateway:
  attached to VPC

Public Route Table:
  0.0.0.0/0 -> Internet Gateway

Private Route Table:
  local VPC route only
  no NAT Gateway by default
```

AWS route tables contain rules that decide where subnet traffic is directed, and route targets can include an Internet Gateway, NAT Gateway, VPC peering connection, VPN connection, or other supported targets. ([AWS Documentation][2])

---

# 2. What You Will Learn

```text id="lesson-map"
12.7.1   VPC mental model
12.7.2   public vs private subnet
12.7.3   Internet Gateway
12.7.4   route tables
12.7.5   subnet route table association
12.7.6   availability zones
12.7.7   map_public_ip_on_launch
12.7.8   NAT Gateway cost warning
12.7.9   VPC endpoint concept
12.7.10  Terraform AWS provider setup
12.7.11  networking module real AWS resources
12.7.12  module outputs for EC2 and ALB
12.7.13  AWS CLI validation
12.7.14  Terraform troubleshooting
12.7.15  cleanup
12.7.16  revision checkpoint
```

---

# 3. Never Confuse These

## VPC vs Subnet

```text id="vpc-vs-subnet"
VPC:
  isolated network boundary in AWS

Subnet:
  IP range inside a VPC, placed in one Availability Zone
```

A subnet is not multi-AZ. A VPC can span Availability Zones, but each subnet belongs to one Availability Zone.

---

## Public Subnet vs Private Subnet

```text id="public-private"
Public subnet:
  route table has 0.0.0.0/0 route to Internet Gateway
  instances may receive public IPs

Private subnet:
  no direct route to Internet Gateway
  instances do not directly accept internet traffic
```

Important:

```text id="public-subnet-rule"
A subnet is not public only because its name says public.
It is public because its route table sends internet-bound traffic to an Internet Gateway.
```

---

## Internet Gateway vs NAT Gateway

```text id="igw-vs-nat"
Internet Gateway:
  lets public subnet resources communicate with the internet when routing and IP settings allow it

NAT Gateway:
  lets private subnet resources initiate outbound internet access without receiving inbound internet traffic
```

For dev labs, we avoid NAT Gateway unless needed because of cost.

---

## Route Table vs Route

```text id="route-table-vs-route"
Route table:
  collection of routing rules

Route:
  one routing rule inside a route table
```

Example:

```text id="route-example"
destination: 0.0.0.0/0
target: Internet Gateway
```

---

## Availability Zone Name vs AZ ID

Availability Zone names such as `ap-south-1a` can map differently across AWS accounts. For this course, using the available AZ names is fine for learning, but in production you should be aware of AZ name mapping when coordinating multi-account architectures.

The Terraform AWS provider has an `aws_availability_zones` data source that can load available AZ names in the selected region. ([Terraform Registry][3])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/{notes,scripts,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure
```

---

# 5. Create VPC Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/notes/vpc-mental-model.md
```

Paste:

```markdown id="mental-note-content"
# AWS VPC Mental Model

## VPC

A VPC is an isolated virtual network in AWS.

## Subnet

A subnet is a CIDR range inside a VPC and belongs to one Availability Zone.

## Public subnet

A subnet is public when its route table has a default route to an Internet Gateway.

## Private subnet

A subnet is private when it does not have a direct default route to an Internet Gateway.

## Internet Gateway

An Internet Gateway enables internet connectivity for resources in public subnets when route tables and IP addressing are configured correctly.

## Route table

A route table controls where traffic from a subnet goes.

## NAT Gateway

A NAT Gateway lets private subnet resources initiate outbound internet connections.

For this course, NAT Gateway is disabled by default in dev because it creates hourly and data-processing charges.

## Golden rule

Names do not make a subnet public or private.
Routes do.
```

---

# 6. Create Never-Forget VPC Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/notes/never-confuse-vpc-points.md
```

Paste:

````markdown id="never-note-content"
# Never Forget — AWS VPC Terraform

## 1. A subnet is public because of routing

Public subnet:

```text
0.0.0.0/0 -> Internet Gateway
````

## 2. A subnet is not private just because it has no public IP

Private subnet means no direct internet route through Internet Gateway.

## 3. Internet Gateway alone is not enough

You also need:

* IGW attached to VPC
* route table route to IGW
* subnet associated with that route table
* public IP for internet-reachable instances
* security group and NACL allow rules

## 4. NAT Gateway is not free

Do not enable NAT Gateway casually in dev labs.

## 5. Route table association matters

A subnet uses one route table.

If you forget association, it uses the main route table.

## 6. map_public_ip_on_launch does not make a subnet public by itself

It only auto-assigns public IPs to launched instances.

The route table still matters.

## 7. CIDR planning matters

Do not overlap VPC CIDRs with other networks you may connect later.

## 8. Use outputs as contracts

Networking outputs feed:

* EC2 module
* ALB module
* security group module
* future Ansible inventory

## 9. Do not destroy shared networking blindly

Destroying VPC infrastructure can break everything built on top.

## 10. Validate with AWS CLI

Do not trust only Terraform output.
Verify VPC, subnets, route tables, and IGW in AWS.

````

---

# 7. Update Environment Provider Files

Now your environment root modules need the AWS provider.

From repo root:

```bash id="cd-module"
cd ~/devops-masterclass/12-terraform-ansible-iac
````

Update `versions.tf` for dev, staging, prod:

```bash id="versions-update"
cat > /tmp/module12_aws_versions.tf <<'EOF'
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

for env in dev staging prod; do
  cp /tmp/module12_aws_versions.tf environments/$env/versions.tf
done
```

Update `providers.tf`:

```bash id="providers-update"
cat > /tmp/module12_aws_providers.tf <<'EOF'
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_aws_providers.tf environments/$env/providers.tf
done
```

The AWS provider supports `default_tags` so common tags can be applied through provider configuration to supported AWS resources. ([HashiCorp Developer][4])

---

# 8. Upgrade Networking Module to Real AWS Resources

We now replace the `terraform_data` networking contract with real AWS networking resources.

Update `modules/networking/versions.tf`:

```bash id="networking-versions"
cat > modules/networking/versions.tf <<'EOF'
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

Update `modules/networking/variables.tf`:

```bash id="networking-vars"
cat > modules/networking/variables.tf <<'EOF'
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

variable "network_config" {
  description = "Network configuration."
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    enable_nat_gateway   = bool
  })
  nullable = false

  validation {
    condition     = can(cidrhost(var.network_config.vpc_cidr, 1))
    error_message = "vpc_cidr must be valid."
  }

  validation {
    condition     = length(var.network_config.public_subnet_cidrs) >= 2 && length(var.network_config.private_subnet_cidrs) >= 2
    error_message = "At least two public and two private subnets are required."
  }

  validation {
    condition = alltrue([
      for cidr in concat(var.network_config.public_subnet_cidrs, var.network_config.private_subnet_cidrs) :
      can(cidrhost(cidr, 1))
    ])
    error_message = "All subnet CIDRs must be valid CIDR blocks."
  }
}
EOF
```

Update `modules/networking/main.tf`:

```bash id="networking-main"
cat > modules/networking/main.tf <<'EOF'
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  public_subnets = {
    for index, cidr in var.network_config.public_subnet_cidrs :
    "public-${index + 1}" => {
      name = "${var.name_prefix}-public-${index + 1}"
      cidr = cidr
      az   = data.aws_availability_zones.available.names[index]
      tier = "public"
    }
  }

  private_subnets = {
    for index, cidr in var.network_config.private_subnet_cidrs :
    "private-${index + 1}" => {
      name = "${var.name_prefix}-private-${index + 1}"
      cidr = cidr
      az   = data.aws_availability_zones.available.names[index]
      tier = "private"
    }
  }

  all_subnets = merge(local.public_subnets, local.private_subnets)
}

resource "aws_vpc" "this" {
  cidr_block           = var.network_config.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-vpc"
      Component = "networking"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-igw"
      Component = "networking"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name      = each.value.name
      Tier      = "public"
      Component = "networking"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(
    var.common_tags,
    {
      Name      = each.value.name
      Tier      = "private"
      Component = "networking"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-public-rt"
      Tier      = "public"
      Component = "networking"
    }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-private-rt"
      Tier      = "private"
      Component = "networking"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
EOF
```

Terraform’s AWS provider supports route tables with routes and associations; the provider documentation also notes that Terraform has both standalone route resources and inline route-table routes, and you should avoid mixing both patterns for the same route table. ([Terraform Registry][5])

---

# 9. Update Networking Module Outputs

```bash id="networking-outputs"
cat > modules/networking/outputs.tf <<'EOF'
output "contract" {
  description = "Networking module contract."
  value = {
    vpc_id             = aws_vpc.this.id
    vpc_cidr           = aws_vpc.this.cidr_block
    internet_gateway_id = aws_internet_gateway.this.id
    public_subnet_ids  = { for key, subnet in aws_subnet.public : key => subnet.id }
    private_subnet_ids = { for key, subnet in aws_subnet.private : key => subnet.id }
    public_route_table_id  = aws_route_table.public.id
    private_route_table_id = aws_route_table.private.id
    nat_gateway_enabled = false
  }
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = { for key, subnet in aws_subnet.private : key => subnet.id }
}

output "public_subnet_contracts" {
  description = "Public subnet details."
  value = {
    for key, subnet in aws_subnet.public :
    key => {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      name              = subnet.tags["Name"]
    }
  }
}

output "private_subnet_contracts" {
  description = "Private subnet details."
  value = {
    for key, subnet in aws_subnet.private :
    key => {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      name              = subnet.tags["Name"]
    }
  }
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID."
  value       = aws_route_table.private.id
}
EOF
```

---

# 10. Update Networking README

````bash id="networking-readme"
cat > modules/networking/README.md <<'EOF'
# Networking Module

## Purpose

Creates the AWS VPC networking foundation.

## Resources

- VPC
- Internet Gateway
- public subnets
- private subnets
- public route table
- private route table
- public route to Internet Gateway
- route table associations

## Region

Environment root module controls the AWS provider region.

Course default:

```text
ap-south-1
````

## NAT Gateway

NAT Gateway is not enabled by default in this lesson to avoid hourly and data-processing charges.

## Inputs

* name_prefix
* common_tags
* network_config

## Outputs

* vpc_id
* vpc_cidr
* internet_gateway_id
* public_subnet_ids
* private_subnet_ids
* public_subnet_contracts
* private_subnet_contracts
* public_route_table_id
* private_route_table_id

## Public subnet rule

A subnet is public when its route table sends 0.0.0.0/0 to an Internet Gateway.

## Private subnet rule

A subnet is private when it has no direct route to an Internet Gateway.
EOF

````

---

# 11. Check AWS Identity Before Applying

```bash id="aws-checks"
cd ~/devops-masterclass

aws sts get-caller-identity
aws configure list

export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
````

If you use a named profile:

```bash id="aws-profile"
export AWS_PROFILE=default
```

Do not continue if `aws sts get-caller-identity` fails.

---

# 12. Run Dev Plan

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

Initialize with your S3 backend:

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
terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-7-dev
```

Review plan carefully:

```bash id="dev-show-plan"
terraform show tfplan-12-7-dev
```

You should see resources similar to:

```text id="expected-plan"
aws_vpc.this
aws_internet_gateway.this
aws_subnet.public["public-1"]
aws_subnet.public["public-2"]
aws_subnet.private["private-1"]
aws_subnet.private["private-2"]
aws_route_table.public
aws_route.public_internet
aws_route_table_association.public["public-1"]
aws_route_table_association.public["public-2"]
aws_route_table.private
aws_route_table_association.private["private-1"]
aws_route_table_association.private["private-2"]
```

---

# 13. Apply Dev VPC

```bash id="dev-apply"
terraform apply tfplan-12-7-dev
```

Show outputs:

```bash id="outputs"
terraform output networking_contract
terraform output module_composition_contract
terraform output future_ansible_inventory_contract
```

Store useful values:

```bash id="store-values"
VPC_ID="$(terraform output -json networking_contract | jq -r '.vpc_id')"
PUBLIC_RT_ID="$(terraform output -json networking_contract | jq -r '.public_route_table_id')"
PRIVATE_RT_ID="$(terraform output -json networking_contract | jq -r '.private_route_table_id')"

echo "VPC_ID=$VPC_ID"
echo "PUBLIC_RT_ID=$PUBLIC_RT_ID"
echo "PRIVATE_RT_ID=$PRIVATE_RT_ID"
```

---

# 14. Validate with AWS CLI

## VPC

```bash id="validate-vpc"
aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,IsDefault:IsDefault,Tags:Tags}' \
  --output table
```

Expected:

```text id="vpc-expected"
State = available
CIDR = 10.10.0.0/16
IsDefault = false
```

---

## Subnets

```bash id="validate-subnets"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,PublicIpOnLaunch:MapPublicIpOnLaunch,Tags:Tags}' \
  --output table
```

Expected:

```text id="subnets-expected"
2 public subnets with MapPublicIpOnLaunch = true
2 private subnets with MapPublicIpOnLaunch = false
```

---

## Internet Gateway

```bash id="validate-igw"
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[].{InternetGatewayId:InternetGatewayId,Attachments:Attachments}' \
  --output table
```

Expected:

```text id="igw-expected"
Internet Gateway attached to VPC
```

---

## Route Tables

```bash id="validate-routes"
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Associations:Associations[].SubnetId,Routes:Routes}' \
  --output json
```

Look for:

```text id="routes-expected"
Public route table:
  0.0.0.0/0 -> Internet Gateway

Private route table:
  local route only
```

AWS documents that each route table contains route rules, and subnet route table associations determine which route table a subnet uses. ([AWS Documentation][6])

---

# 15. Create AWS Validation Script

Create:

```bash id="validation-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh
```

Paste:

```bash id="validation-script-content"
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

echo "===== AWS VPC Validation ====="
echo "Environment: $ENVIRONMENT"

VPC_ID="$(terraform output -json networking_contract | jq -r '.vpc_id')"
PUBLIC_RT_ID="$(terraform output -json networking_contract | jq -r '.public_route_table_id')"
PRIVATE_RT_ID="$(terraform output -json networking_contract | jq -r '.private_route_table_id')"

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "null" ]; then
  echo "Unable to read VPC ID from Terraform output."
  exit 1
fi

echo
echo "VPC:"
aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,IsDefault:IsDefault}' \
  --output table

echo
echo "Subnets:"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,PublicIpOnLaunch:MapPublicIpOnLaunch}' \
  --output table

echo
echo "Internet Gateway:"
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[].{InternetGatewayId:InternetGatewayId,State:Attachments[0].State}' \
  --output table

echo
echo "Route tables:"
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Associations:Associations[].SubnetId,Routes:Routes[].{Destination:DestinationCidrBlock,GatewayId:GatewayId,NatGatewayId:NatGatewayId,State:State}}' \
  --output json

echo
echo "Checking public route table route..."
aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RT_ID" \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' \
  --output text | grep '^igw-' >/dev/null

echo "Public route table has default route to Internet Gateway."

echo
echo "Checking private route table has no default NAT/IGW route..."
PRIVATE_DEFAULT_ROUTES="$(
  aws ec2 describe-route-tables \
    --route-table-ids "$PRIVATE_RT_ID" \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' \
    --output text
)"

if [ -n "$PRIVATE_DEFAULT_ROUTES" ]; then
  echo "WARNING: private route table has default route:"
  echo "$PRIVATE_DEFAULT_ROUTES"
else
  echo "Private route table has no internet default route."
fi

echo
echo "AWS VPC validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh
```

Run:

```bash id="run-vpc-validation"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh
```

---

# 16. Create Terraform Networking Plan Script

```bash id="plan-script"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/plan-vpc.sh
```

Paste:

```bash id="plan-script-content"
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
REPORT_DIR="../../12.7-aws-vpc-infrastructure/reports"

mkdir -p "$BASE/12.7-aws-vpc-infrastructure/reports"

cd "$ENV_DIR"

echo "===== Terraform VPC Plan ====="
echo "Environment: $ENVIRONMENT"
echo "Current workspace: $(terraform workspace show 2>/dev/null || echo not-initialized)"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -recursive
terraform validate

terraform plan -var-file=terraform.tfvars.example -out="tfplan-12-7-$ENVIRONMENT"
terraform show -no-color "tfplan-12-7-$ENVIRONMENT" > "$REPORT_DIR/$ENVIRONMENT-vpc-plan.txt"

echo
echo "Plan saved:"
echo "$BASE/12.7-aws-vpc-infrastructure/reports/$ENVIRONMENT-vpc-plan.txt"
echo
echo "Apply manually from $ENV_DIR with:"
echo "terraform apply tfplan-12-7-$ENVIRONMENT"
```

Make executable:

```bash id="chmod-plan"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/plan-vpc.sh
```

Run dev plan:

```bash id="run-plan"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/plan-vpc.sh
```

---

# 17. Create VPC Summary Script

```bash id="summary-script"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/vpc-summary.sh
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

echo "===== VPC Terraform Summary ====="
echo "Environment: $ENVIRONMENT"

terraform output networking_contract
terraform output module_composition_contract

echo
echo "State addresses:"
terraform state list | grep -E 'module.networking|aws_vpc|aws_subnet|aws_route|aws_internet_gateway' | sort || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/vpc-summary.sh
```

Run:

```bash id="run-summary"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/vpc-summary.sh
```

---

# 18. Create Lesson Validation Script

This checks files and Terraform configuration. It does not automatically apply AWS resources.

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-lesson-12-7.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.7 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.7-aws-vpc-infrastructure"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"

test -f "$LESSON/notes/vpc-mental-model.md"
test -f "$LESSON/notes/never-confuse-vpc-points.md"

test -x "$LESSON/scripts/validate-vpc-aws.sh"
test -x "$LESSON/scripts/plan-vpc.sh"
test -x "$LESSON/scripts/vpc-summary.sh"

test -f "$BASE/modules/networking/versions.tf"
test -f "$BASE/modules/networking/variables.tf"
test -f "$BASE/modules/networking/main.tf"
test -f "$BASE/modules/networking/outputs.tf"
test -f "$BASE/modules/networking/README.md"

grep -q 'resource "aws_vpc" "this"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_subnet" "public"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_subnet" "private"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_internet_gateway" "this"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_route_table" "public"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_route" "public_internet"' "$BASE/modules/networking/main.tf"
grep -q 'resource "aws_route_table_association" "public"' "$BASE/modules/networking/main.tf"

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
    -out="tfplan-12-7-validation-$env" >/dev/null

  terraform show -no-color "tfplan-12-7-validation-$env" >/dev/null
  rm -f "tfplan-12-7-validation-$env"

  popd >/dev/null
done

echo
echo "Lesson 12.7 validation passed."
echo
echo "To validate real AWS resources after dev apply, run:"
echo "ENVIRONMENT=dev ./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh"
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-lesson-12-7.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-lesson-12-7.sh
```

---

# 19. Cleanup Script

This destroys the dev VPC resources. Run only when you are done practicing or before moving to a different design.

```bash id="cleanup-script"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-dev.sh
```

Paste:

```bash id="cleanup-content"
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

echo "===== Cleanup Lesson 12.7 Dev VPC ====="
echo "Current workspace: $(terraform workspace show)"

terraform plan -destroy -var-file=terraform.tfvars.example -out=tfplan-destroy-12-7-dev
terraform show tfplan-destroy-12-7-dev

echo
echo "Review the destroy plan above."
echo "Type DESTROY_DEV_VPC to continue:"
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY_DEV_VPC" ]; then
  echo "Cleanup cancelled."
  rm -f tfplan-destroy-12-7-dev
  exit 0
fi

terraform apply tfplan-destroy-12-7-dev
rm -f tfplan-destroy-12-7-dev

echo "Dev VPC resources destroyed."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-dev.sh
```

Run only if you want to destroy the dev VPC:

```bash id="run-cleanup"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-dev.sh
```

---

# 20. Local Artifact Cleanup Script

This removes plan files only and does not destroy AWS resources.

```bash id="local-cleanup"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-local.sh
```

Paste:

```bash id="local-cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.7 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

echo "Local Terraform plan artifacts cleaned."
echo "AWS resources were not destroyed."
```

Make executable:

```bash id="chmod-local-cleanup"
chmod +x 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-local.sh
```

Run:

```bash id="run-local-cleanup"
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-local.sh
```

---

# 21. VPC Troubleshooting Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/runbooks/vpc-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# AWS VPC Terraform Troubleshooting Runbook

## 1. Check AWS identity

```bash
aws sts get-caller-identity
aws configure list
````

## 2. Check region

```bash id="region-check"
echo $AWS_REGION
echo $AWS_DEFAULT_REGION
```

Course default:

```text
ap-south-1
```

## 3. Check Terraform backend

```bash id="backend-check"
terraform init -reconfigure -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

## 4. Check plan

```bash id="plan-check"
terraform plan -var-file=terraform.tfvars.example -out=tfplan
terraform show tfplan
```

## 5. Check VPC

```bash id="vpc-check"
aws ec2 describe-vpcs --vpc-ids VPC_ID
```

## 6. Check subnets

```bash id="subnet-check"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=VPC_ID"
```

## 7. Check Internet Gateway

```bash id="igw-check"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=VPC_ID"
```

## 8. Check route tables

```bash id="rt-check"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=VPC_ID"
```

## 9. Common symptoms

### Public subnet instances cannot reach internet

Check:

* Internet Gateway attached
* route table has 0.0.0.0/0 to IGW
* subnet associated with public route table
* instance has public IP
* security group egress
* NACL rules

### Private subnet has internet access unexpectedly

Check:

* private route table default route
* NAT Gateway route
* wrong route table association

### Subnet not in expected AZ

Check:

* aws_availability_zones data source
* subnet index mapping
* account-specific AZ name mapping

### Terraform wants to replace subnets

Likely causes:

* changed CIDR
* changed availability_zone
* changed VPC ID

Review plan carefully.

## Golden rule

A subnet's public/private behavior is defined by route table association and routes, not by name.

````id="runbook-end"

---

# 22. NAT Gateway and VPC Endpoint Notes

Create:

```bash id="nat-note"
nano 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/notes/nat-gateway-and-vpc-endpoints.md
````

Paste:

```markdown id="nat-note-content"
# NAT Gateway and VPC Endpoints

## NAT Gateway

A NAT Gateway allows resources in private subnets to initiate outbound internet access.

Examples:

- apt update
- yum install
- container image pull
- external API calls

## Cost warning

NAT Gateway has hourly charges and data-processing charges.

Do not enable casually in dev labs.

## VPC endpoints

VPC endpoints allow private connectivity to supported AWS services without sending traffic through the public internet.

Examples:

- S3 Gateway Endpoint
- DynamoDB Gateway Endpoint
- Interface Endpoints for many AWS services

## Production design

Private subnets often need one of these:

- NAT Gateway for broad outbound internet
- VPC endpoints for AWS service access
- no outbound internet for isolated workloads

## Course design

Lesson 12.7 keeps private subnets isolated by default.

NAT Gateway support can be added later as an optional production enhancement.
```

VPC endpoints can reduce NAT Gateway data processing charges for traffic to supported AWS services, and AWS recommends checking whether traffic can use Gateway VPC endpoints such as S3 instead of passing through NAT Gateway. ([AWS Documentation][1])

---

# 23. Common Errors and Fixes

## Error 1 — UnauthorizedOperation

Example:

```text id="unauthorized"
UnauthorizedOperation: You are not authorized to perform this operation.
```

Check identity:

```bash id="fix-unauthorized"
aws sts get-caller-identity
```

Needed permissions include VPC, subnet, Internet Gateway, route table, route, and tag operations.

---

## Error 2 — VPC CIDR conflict

Example:

```text id="cidr-conflict"
CIDR conflicts with another VPC or connected network.
```

Fix:

```text id="cidr-fix"
Choose a non-overlapping CIDR range.
For this course:
  dev     10.10.0.0/16
  staging 10.20.0.0/16
  prod    10.30.0.0/16
```

---

## Error 3 — InvalidSubnet.Conflict

Cause:

```text id="subnet-conflict-cause"
Subnet CIDRs overlap inside the same VPC.
```

Fix:

```text id="subnet-conflict-fix"
Ensure public and private subnet CIDRs are unique and inside the VPC CIDR.
```

---

## Error 4 — Route already exists

Cause:

```text id="route-exists-cause"
A route to 0.0.0.0/0 already exists in that route table.
```

Fix:

```text id="route-exists-fix"
Use either inline route table routes or standalone aws_route resources consistently.
Do not define the same route twice.
```

---

## Error 5 — Dependency violation during destroy

Cause:

```text id="dependency-cause"
Resources still depend on the VPC or subnets.
```

Fix:

```bash id="dependency-fix"
terraform state list
terraform destroy
```

If future EC2, ALB, NAT, or endpoints exist, destroy dependent resources before VPC.

---

# 24. Cost Safety

Created resources in this lesson:

```text id="cost-created"
VPC
subnets
Internet Gateway
route tables
routes
route table associations
```

Avoided by default:

```text id="cost-avoided"
NAT Gateway
EC2 instances
Elastic IPs
ALB
VPC endpoints
```

Cost reminder:

```text id="cost-reminder"
Do not enable NAT Gateway unless you intentionally accept hourly and data-processing charges.
```

---

# 25. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is a VPC?
What is a subnet?
Can one subnet span multiple AZs?
What makes a subnet public?
What makes a subnet private?
What does an Internet Gateway do?
Why is Internet Gateway alone not enough for public connectivity?
What is a route table?
What is a route table association?
What does map_public_ip_on_launch do?
Why did we avoid NAT Gateway in dev?
What does aws_availability_zones do?
Why do networking outputs matter?
Which outputs will EC2 need later?
Which outputs will ALB need later?
How do you validate VPC resources with AWS CLI?
What Terraform errors happen with overlapping CIDRs?
Why should you not destroy shared networking blindly?
```

Strong interview answer:

```text id="interview-answer"
In Terraform, I design the AWS networking layer as a reusable module that creates a VPC, public and private subnets across multiple Availability Zones, an Internet Gateway, route tables, and route table associations. A subnet is public because its associated route table has a default route to an Internet Gateway, not because of its name. A private subnet has no direct Internet Gateway route.

For dev environments, I avoid NAT Gateway by default because it has hourly and data-processing charges. I still design the network module so NAT or VPC endpoints can be added later when required. I use data sources to select available Availability Zones, strong variable validation for CIDRs, provider default tags for ownership and cost tracking, and outputs for VPC ID, subnet IDs, route table IDs, and subnet contracts so compute and load balancer modules can consume them.

After applying, I validate with both Terraform outputs and AWS CLI commands for VPCs, subnets, Internet Gateways, and route tables. I specifically confirm that public subnets are associated with a route table that has 0.0.0.0/0 to the Internet Gateway and that private subnets do not have an internet default route.
```

Resume bullet:

```text id="resume-bullet"
Built a production-style AWS VPC networking module with Terraform in ap-south-1, including VPC, multi-AZ public and private subnets, Internet Gateway, public and private route tables, default public internet route, route table associations, provider default tags, strong CIDR validation, reusable module outputs for EC2 and ALB integration, AWS CLI validation scripts, cost-safe NAT Gateway avoidance, troubleshooting runbooks, and cleanup automation.
```

---

# 26. Commit Lesson 12.7

Clean local plans only:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-local.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-lesson-12-7.sh
```

If you applied dev VPC, validate AWS resources:

```bash id="validate-aws-before-commit"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.7-aws-vpc-infrastructure -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/modules/networking -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add AWS VPC infrastructure module"

git push
```

---

# 27. Keep or Destroy?

For the next lesson, you should usually **keep the dev VPC** because Lesson 12.8 uses it for EC2 and security groups.

Keep:

```text id="keep"
Recommended if continuing to Lesson 12.8.
```

Destroy:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/cleanup-lesson-12-7-dev.sh
```

---

# 28. Next Lesson

```text id="next-lesson"
12.8 — EC2 and Security Groups with Terraform
```

We will build:

```text id="next-topics"
real security group module
least-privilege ingress
egress rules
EC2 instance profile concept
Ubuntu AMI lookup
EC2 instance in public subnet for dev
optional private subnet design
user_data bootstrap
SSM vs SSH access model
key pair discussion
public IP behavior
security group troubleshooting
AWS CLI validation
cleanup to avoid charges
```

[1]: https://docs.aws.amazon.com/en_en/vpc/latest/userguide/nat-gateway-pricing.html?utm_source=chatgpt.com "Pricing for NAT gateways - Amazon Virtual Private Cloud"
[2]: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html?utm_source=chatgpt.com "Configure route tables - Amazon Virtual Private Cloud"
[3]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones?utm_source=chatgpt.com "aws_availability_zones | Data Sources | hashicorp/aws | Terraform | Terraform Registry"
[4]: https://developer.hashicorp.com/terraform/tutorials/aws/aws-default-tags?utm_source=chatgpt.com "Configure default tags for AWS resources | Terraform | HashiCorp Developer"
[5]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table.html?utm_source=chatgpt.com "aws_route_table | Resources | hashicorp/aws | Terraform | Terraform Registry"
[6]: https://docs.aws.amazon.com/vpc/latest/userguide/subnet-route-tables.html?utm_source=chatgpt.com "Subnet route tables - Amazon Virtual Private Cloud"
