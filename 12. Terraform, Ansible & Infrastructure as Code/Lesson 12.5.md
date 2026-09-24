# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.5 — Terraform Modules

In Lesson 12.4, you built production-style Terraform contracts:

```text id="recap-12-4"
input variables
type constraints
validation blocks
locals
outputs
sensitive variables
tfvars examples
TF_VAR_ overrides
naming and tagging contracts
multi-environment planning
```

Now we go deep into **Terraform modules**.

A Terraform configuration is made of a **root module** plus any tree of **child modules** it calls. A module can call other modules and pass outputs from one module into inputs of another, but HashiCorp warns against overusing modules because excessive module layers can make Terraform harder to understand and maintain. ([HashiCorp Developer][1])

---

# 1. Goal

You will turn your current placeholder modules into real production-style module contracts.

This lesson still avoids creating AWS application infrastructure. We will use `terraform_data` so the focus stays on module design, composition, interfaces, outputs, versioning, validation, documentation, and refactoring.

You will build:

```text id="goal"
networking module contract
security-group module contract
compute module contract
load-balancer module contract
storage module contract
cdn module contract
iam module contract
module composition from environments/dev
module output chaining
module validation scripts
module documentation generator
module anti-pattern notes
module refactor notes
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.5.1   root module vs child module
12.5.2   module inputs
12.5.3   module outputs
12.5.4   module composition
12.5.5   module source paths
12.5.6   module versioning
12.5.7   provider passing
12.5.8   module contracts
12.5.9   when to create modules
12.5.10  when not to create modules
12.5.11  module anti-patterns
12.5.12  networking module design
12.5.13  compute module design
12.5.14  security-group module design
12.5.15  storage/CDN/IAM contracts
12.5.16  module validation
12.5.17  module documentation
12.5.18  module testing mindset
12.5.19  refactoring with moved blocks/state mv
12.5.20  production module runbooks
```

---

# 3. Never Confuse These

## Root Module vs Child Module

```text id="root-child"
Root module:
  directory where terraform init/plan/apply runs

Child module:
  reusable package called by a module block
```

Example:

```text id="root-child-example"
Root:
  environments/dev

Children:
  modules/networking
  modules/compute
  modules/load-balancer
```

Never apply child modules directly unless you are intentionally testing them as standalone examples.

---

## Module Source vs Provider Source

```text id="module-provider-source"
module source:
  where Terraform downloads/loads module code from

provider source:
  where Terraform downloads provider plugin from
```

Example module source:

```hcl id="module-source-example"
module "networking" {
  source = "../../modules/networking"
}
```

Example provider source:

```hcl id="provider-source-example"
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 6.0"
  }
}
```

Terraform can load modules from local paths, registries, Git repositories, object storage, and other supported sources; if you change a module’s `source` or registry `version`, you must rerun `terraform init`. ([HashiCorp Developer][2])

---

## Module Inputs vs Module Outputs

```text id="module-input-output"
inputs:
  values passed into a module

outputs:
  values returned by a module
```

Example:

```hcl id="module-input-output-example"
module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

output "vpc_id" {
  value = module.networking.vpc_id
}
```

Parent modules access child module outputs as `module.<NAME>.<OUTPUT>`. ([HashiCorp Developer][3])

---

## Module Version vs Provider Version

```text id="module-vs-provider-version"
module version:
  version of reusable Terraform module code

provider version:
  version of provider plugin
```

Local modules usually do not use the `version` argument.

Registry modules should use versions:

```hcl id="registry-module-version"
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "x.y.z"
}
```

Terraform registry modules support versioning, and the registry protocol expects semantic-version-style module versions. ([HashiCorp Developer][4])

---

## Provider Passing

Root modules usually configure providers.

Child modules usually declare provider requirements but avoid provider configuration blocks.

HashiCorp explicitly recommends against writing reusable child modules with their own provider configuration blocks; provider configurations should normally be passed from the root module. ([HashiCorp Developer][5])

Good:

```hcl id="provider-good"
# root module
provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"
}
```

Avoid in reusable child modules:

```hcl id="provider-bad"
# child module
provider "aws" {
  region = "ap-south-1"
}
```

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.5-terraform-modules/{notes,scripts,runbooks,reports,examples}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.5-terraform-modules
```

---

# 5. Create Module Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/terraform-modules-mental-model.md
```

Paste:

````markdown id="mental-note-content"
# Terraform Modules Mental Model

## What is a module?

A Terraform module is a directory of Terraform configuration files.

Every Terraform configuration has one root module.

A root module can call child modules.

## Root module

The directory where you run:

```bash
terraform init
terraform plan
terraform apply
````

Example:

```text
environments/dev
```

## Child module

A reusable package called by a `module` block.

Example:

```text
modules/networking
```

## Module inputs

Variables declared inside the child module and supplied by the parent module.

## Module outputs

Values exposed by the child module and consumed by the parent module.

## Good module boundary

A module should represent a meaningful infrastructure capability:

* networking
* compute
* load balancer
* storage
* CDN
* IAM
* observability

## Bad module boundary

Avoid modules for tiny fragments with no reusable purpose:

* one tag
* one string
* one single security group rule
* one output wrapper

## Golden rule

A module should make the root module easier to read, not harder.

````

---

# 6. Create Never-Forget Module Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/never-confuse-terraform-modules.md
````

Paste:

````markdown id="never-note-content"
# Never Forget — Terraform Modules

## 1. A module is just a directory of Terraform files

It is not magic.

## 2. The root module is where commands run

Do not accidentally run `terraform apply` from the wrong folder.

## 3. Module source tells Terraform where code is

Example:

```hcl
source = "../../modules/networking"
````

## 4. Module inputs are variables

The child module declares variables.
The parent passes values.

## 5. Module outputs are contracts

Changing output names can break parent modules, CI/CD, Ansible, or remote-state consumers.

## 6. Do not hardcode environment in child modules

Bad:

```hcl
name = "prod-vpc"
```

Good:

```hcl
name = "${var.name_prefix}-vpc"
```

## 7. Avoid provider blocks in reusable child modules

Root module should usually configure provider.

## 8. Do not over-module

Too many small modules create complexity, not clarity.

## 9. Version external modules

Registry or Git modules should use explicit version/ref strategies.

## 10. Refactoring modules can affect state addresses

Moving a resource into a module changes its address.

Example:

```text
aws_instance.web
module.compute.aws_instance.web
```

Use `moved` blocks or `terraform state mv` carefully.

````

---

# 7. Create Module Anti-Patterns Notes

```bash id="antipattern-note"
nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/module-anti-patterns.md
````

Paste:

````markdown id="antipattern-content"
# Terraform Module Anti-Patterns

## Anti-pattern 1: Wrapper module with no value

Bad:

```hcl
module "tags" {
  source = "../tags"
}
````

If the module only returns a static map, use locals.

## Anti-pattern 2: One resource per module always

Bad:

```text
modules/security-group-rule
modules/tag
modules/name
modules/one-subnet
```

This creates too many layers.

## Anti-pattern 3: Environment hardcoded in child module

Bad:

```hcl
resource "aws_s3_bucket" "this" {
  bucket = "prod-assets"
}
```

Good:

```hcl
bucket = "${var.name_prefix}-assets"
```

## Anti-pattern 4: Provider block in reusable child module

Bad:

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

Good:

Root module configures provider.

## Anti-pattern 5: Too many outputs

Bad:

Expose every internal implementation detail.

Good:

Expose stable useful contracts.

## Anti-pattern 6: No README

A reusable module without documentation becomes tribal knowledge.

## Anti-pattern 7: Secret output

Do not output secrets unless a consumer truly requires it.

## Anti-pattern 8: No variable validation

A module should reject invalid environment, ports, CIDRs, counts, names, and flags early.

## Anti-pattern 9: Breaking output names casually

Outputs are public contracts.

## Anti-pattern 10: Moving resources without state planning

Moving resources into modules changes addresses.

Use `moved` blocks or `terraform state mv` carefully.

````

---

# 8. Add Security Group Module

Create a dedicated security-group module contract because security rules are important enough to isolate.

```bash id="create-sg-module"
cd ~/devops-masterclass/12-terraform-ansible-iac

mkdir -p modules/security-group
touch modules/security-group/{versions.tf,variables.tf,main.tf,outputs.tf,README.md}
````

Add `versions.tf`:

```bash id="sg-versions"
cat > modules/security-group/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
```

Add `variables.tf`:

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
  description = "VPC identifier. This is a contract placeholder in Lesson 12.5."
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
EOF
```

Add `main.tf`:

```bash id="sg-main"
cat > modules/security-group/main.tf <<'EOF'
locals {
  sorted_ports = sort(tolist(var.allowed_ingress_ports))

  ingress_rules = {
    for port in local.sorted_ports :
    "tcp-${port}" => {
      description = "Allow TCP ${port}"
      protocol    = "tcp"
      from_port   = port
      to_port     = port
      cidrs       = var.allowed_cidr_blocks
    }
  }
}

resource "terraform_data" "security_group_contract" {
  input = {
    name          = "${var.name_prefix}-app-sg"
    vpc_id        = var.vpc_id
    ingress_rules = local.ingress_rules
    egress_rules = {
      all_outbound = {
        protocol  = "-1"
        from_port = 0
        to_port   = 0
        cidrs     = ["0.0.0.0/0"]
      }
    }
    tags = var.common_tags
  }
}
EOF
```

Add `outputs.tf`:

```bash id="sg-outputs"
cat > modules/security-group/outputs.tf <<'EOF'
output "security_group_contract" {
  description = "Security group contract for future AWS security group resources."
  value       = terraform_data.security_group_contract.output
}

output "security_group_id" {
  description = "Placeholder security group ID contract for future AWS resource integration."
  value       = "sg-placeholder-${var.name_prefix}"
}

output "allowed_ports" {
  description = "Sorted allowed ingress ports."
  value       = sort(tolist(var.allowed_ingress_ports))
}
EOF
```

Add README:

```bash id="sg-readme"
cat > modules/security-group/README.md <<'EOF'
# Security Group Module

## Purpose

Future AWS responsibility:

- application security group
- ALB security group
- ingress rules
- egress rules
- least-privilege network access

## Lesson 12.5 status

This module uses `terraform_data` contracts only.
Real AWS security groups are added in later lessons.

## Inputs

- name_prefix
- common_tags
- vpc_id
- allowed_ingress_ports
- allowed_cidr_blocks

## Outputs

- security_group_contract
- security_group_id
- allowed_ports

## Important

Do not allow broad ports casually.
Validate all ports and CIDRs.
EOF
```

---

# 9. Upgrade Networking Module

Replace placeholder networking module with a real contract.

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
  description = "Network configuration contract."
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
}
EOF
```

```bash id="networking-main"
cat > modules/networking/main.tf <<'EOF'
locals {
  public_subnets = {
    for index, cidr in var.network_config.public_subnet_cidrs :
    "public-${index + 1}" => {
      name = "${var.name_prefix}-public-${index + 1}"
      cidr = cidr
      tier = "public"
    }
  }

  private_subnets = {
    for index, cidr in var.network_config.private_subnet_cidrs :
    "private-${index + 1}" => {
      name = "${var.name_prefix}-private-${index + 1}"
      cidr = cidr
      tier = "private"
    }
  }

  all_subnets = merge(local.public_subnets, local.private_subnets)
}

resource "terraform_data" "networking_contract" {
  input = {
    vpc_id             = "vpc-placeholder-${var.name_prefix}"
    vpc_name           = "${var.name_prefix}-vpc"
    vpc_cidr           = var.network_config.vpc_cidr
    public_subnets     = local.public_subnets
    private_subnets    = local.private_subnets
    all_subnets        = local.all_subnets
    enable_nat_gateway = var.network_config.enable_nat_gateway
    tags               = var.common_tags
  }
}
EOF
```

```bash id="networking-outputs"
cat > modules/networking/outputs.tf <<'EOF'
output "contract" {
  description = "Networking module contract."
  value       = terraform_data.networking_contract.output
}

output "vpc_id" {
  description = "Placeholder VPC ID for future AWS integration."
  value       = terraform_data.networking_contract.output.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = terraform_data.networking_contract.output.vpc_cidr
}

output "public_subnet_ids" {
  description = "Placeholder public subnet IDs."
  value = {
    for key, subnet in terraform_data.networking_contract.output.public_subnets :
    key => "subnet-placeholder-${subnet.name}"
  }
}

output "private_subnet_ids" {
  description = "Placeholder private subnet IDs."
  value = {
    for key, subnet in terraform_data.networking_contract.output.private_subnets :
    key => "subnet-placeholder-${subnet.name}"
  }
}

output "public_subnet_contracts" {
  description = "Public subnet contracts."
  value       = terraform_data.networking_contract.output.public_subnets
}

output "private_subnet_contracts" {
  description = "Private subnet contracts."
  value       = terraform_data.networking_contract.output.private_subnets
}
EOF
```

```bash id="networking-readme"
cat > modules/networking/README.md <<'EOF'
# Networking Module

## Purpose

Future AWS responsibility:

- VPC
- public subnets
- private subnets
- route tables
- internet gateway
- NAT gateway
- VPC endpoints

## Lesson 12.5 status

This module uses terraform_data contracts only.
Real AWS networking starts in Lesson 12.7.

## Inputs

- name_prefix
- common_tags
- network_config

## Outputs

- contract
- vpc_id
- vpc_cidr
- public_subnet_ids
- private_subnet_ids
- public_subnet_contracts
- private_subnet_contracts

## Design rule

Networking is a strong module boundary because many resources depend on VPC and subnet outputs.
EOF
```

---

# 10. Upgrade Compute Module

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

variable "compute_config" {
  description = "Compute configuration contract."
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
EOF
```

```bash id="compute-main"
cat > modules/compute/main.tf <<'EOF'
locals {
  instance_names = [
    for index in range(var.compute_config.instance_count) :
    "${var.name_prefix}-app-${index + 1}"
  ]
}

resource "terraform_data" "compute_contract" {
  input = {
    instance_type     = var.compute_config.instance_type
    instance_count    = var.compute_config.instance_count
    app_port          = var.compute_config.app_port
    enable_ssm        = var.compute_config.enable_ssm
    private_subnet_ids = var.private_subnet_ids
    security_group_id = var.security_group_id
    instance_names    = local.instance_names
    tags              = var.common_tags
  }
}
EOF
```

```bash id="compute-outputs"
cat > modules/compute/outputs.tf <<'EOF'
output "contract" {
  description = "Compute module contract."
  value       = terraform_data.compute_contract.output
}

output "instance_names" {
  description = "Planned instance names."
  value       = terraform_data.compute_contract.output.instance_names
}

output "instance_ids" {
  description = "Placeholder instance IDs for future AWS integration."
  value = [
    for name in terraform_data.compute_contract.output.instance_names :
    "i-placeholder-${name}"
  ]
}

output "app_port" {
  description = "Application port."
  value       = terraform_data.compute_contract.output.app_port
}
EOF
```

```bash id="compute-readme"
cat > modules/compute/README.md <<'EOF'
# Compute Module

## Purpose

Future AWS responsibility:

- EC2 instances
- launch templates
- IAM instance profile attachment
- security group attachment
- subnet placement
- user data
- SSM enablement

## Lesson 12.5 status

This module uses terraform_data contracts only.

## Inputs

- name_prefix
- common_tags
- compute_config
- private_subnet_ids
- security_group_id

## Outputs

- contract
- instance_names
- instance_ids
- app_port

## Design rule

Compute depends on networking and security outputs.
EOF
```

---

# 11. Upgrade Load Balancer Module

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
}

variable "target_instance_ids" {
  description = "Target instance IDs from compute module."
  type        = list(string)
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
EOF
```

```bash id="lb-main"
cat > modules/load-balancer/main.tf <<'EOF'
resource "terraform_data" "load_balancer_contract" {
  input = {
    enabled             = var.enable_alb
    alb_name            = "${var.name_prefix}-alb"
    target_group_name   = "${var.name_prefix}-tg"
    listener_http_port  = 80
    listener_https_port = 443
    backend_app_port    = var.app_port
    vpc_id              = var.vpc_id
    public_subnet_ids   = var.public_subnet_ids
    target_instance_ids = var.target_instance_ids
    health_check = {
      path                = "/health"
      interval_seconds    = 30
      timeout_seconds     = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
    tags = var.common_tags
  }
}
EOF
```

```bash id="lb-outputs"
cat > modules/load-balancer/outputs.tf <<'EOF'
output "contract" {
  description = "Load balancer module contract."
  value       = terraform_data.load_balancer_contract.output
}

output "alb_dns_name" {
  description = "Placeholder ALB DNS name for future AWS integration."
  value       = "${terraform_data.load_balancer_contract.output.alb_name}.elb.amazonaws.com"
}

output "target_group_name" {
  description = "Target group name."
  value       = terraform_data.load_balancer_contract.output.target_group_name
}
EOF
```

```bash id="lb-readme"
cat > modules/load-balancer/README.md <<'EOF'
# Load Balancer Module

## Purpose

Future AWS responsibility:

- Application Load Balancer
- target groups
- listeners
- listener rules
- health checks
- instance or IP target registration

## Inputs

- name_prefix
- common_tags
- vpc_id
- public_subnet_ids
- target_instance_ids
- app_port
- enable_alb

## Outputs

- contract
- alb_dns_name
- target_group_name

## Design rule

Load balancer depends on networking and compute outputs.
EOF
```

---

# 12. Upgrade Storage Module

```bash id="storage-vars"
cat > modules/storage/variables.tf <<'EOF'
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

variable "enable_versioning" {
  description = "Whether bucket versioning should be enabled."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Whether future S3 bucket force_destroy should be allowed."
  type        = bool
  default     = false
}
EOF
```

```bash id="storage-main"
cat > modules/storage/main.tf <<'EOF'
resource "terraform_data" "storage_contract" {
  input = {
    assets_bucket_name = "${var.name_prefix}-assets"
    logs_bucket_name   = "${var.name_prefix}-logs"
    environment        = var.environment
    enable_versioning  = var.enable_versioning
    force_destroy      = var.force_destroy
    encryption         = "AES256"
    block_public_access = true
    tags               = var.common_tags
  }
}
EOF
```

```bash id="storage-outputs"
cat > modules/storage/outputs.tf <<'EOF'
output "contract" {
  description = "Storage module contract."
  value       = terraform_data.storage_contract.output
}

output "assets_bucket_name" {
  description = "Planned assets bucket name."
  value       = terraform_data.storage_contract.output.assets_bucket_name
}

output "logs_bucket_name" {
  description = "Planned logs bucket name."
  value       = terraform_data.storage_contract.output.logs_bucket_name
}
EOF
```

---

# 13. Upgrade CDN Module

```bash id="cdn-vars"
cat > modules/cdn/variables.tf <<'EOF'
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

variable "enable_cloudfront" {
  description = "Whether CloudFront should be enabled."
  type        = bool
  default     = false
}

variable "origin_domain_name" {
  description = "Origin domain name for future CloudFront distribution."
  type        = string
  nullable    = false
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}
EOF
```

```bash id="cdn-main"
cat > modules/cdn/main.tf <<'EOF'
resource "terraform_data" "cdn_contract" {
  input = {
    enabled            = var.enable_cloudfront
    distribution_name  = "${var.name_prefix}-cdn"
    origin_domain_name = var.origin_domain_name
    price_class        = var.price_class
    viewer_protocol_policy = "redirect-to-https"
    default_ttl        = 3600
    max_ttl            = 86400
    tags               = var.common_tags
  }
}
EOF
```

```bash id="cdn-outputs"
cat > modules/cdn/outputs.tf <<'EOF'
output "contract" {
  description = "CDN module contract."
  value       = terraform_data.cdn_contract.output
}

output "distribution_domain_name" {
  description = "Placeholder CloudFront domain name."
  value       = "${terraform_data.cdn_contract.output.distribution_name}.cloudfront.net"
}
EOF
```

---

# 14. Upgrade IAM Module

```bash id="iam-vars"
cat > modules/iam/variables.tf <<'EOF'
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

variable "enable_ssm" {
  description = "Whether EC2 instances should support AWS Systems Manager."
  type        = bool
  default     = true
}

variable "app_bucket_names" {
  description = "Application bucket names that compute may need read access to later."
  type        = list(string)
  default     = []
}
EOF
```

```bash id="iam-main"
cat > modules/iam/main.tf <<'EOF'
resource "terraform_data" "iam_contract" {
  input = {
    instance_role_name        = "${var.name_prefix}-ec2-role"
    instance_profile_name     = "${var.name_prefix}-instance-profile"
    cicd_role_name            = "${var.name_prefix}-cicd-role"
    enable_ssm                = var.enable_ssm
    app_bucket_names          = var.app_bucket_names
    least_privilege_principle = true
    tags                      = var.common_tags
  }
}
EOF
```

```bash id="iam-outputs"
cat > modules/iam/outputs.tf <<'EOF'
output "contract" {
  description = "IAM module contract."
  value       = terraform_data.iam_contract.output
}

output "instance_profile_name" {
  description = "Planned instance profile name."
  value       = terraform_data.iam_contract.output.instance_profile_name
}

output "instance_role_name" {
  description = "Planned instance role name."
  value       = terraform_data.iam_contract.output.instance_role_name
}
EOF
```

---

# 15. Compose Modules in Environment Root Modules

Update all environment root modules so outputs flow from one module into another.

```bash id="root-main-template"
cat > /tmp/module12_5_main.tf <<'EOF'
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
  allowed_cidr_blocks   = ["0.0.0.0/0"]
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

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  compute_config    = var.compute_config
  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id = module.security_group.security_group_id
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  target_instance_ids = module.compute.instance_ids
  app_port            = module.compute.app_port
  enable_alb          = var.feature_flags.enable_alb
}

module "storage" {
  source = "../../modules/storage"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  environment       = local.normalized_env
  enable_versioning = true
  force_destroy     = local.normalized_env == "prod" ? false : true
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
      "compute -> load_balancer",
      "load_balancer -> cdn",
      "storage -> iam",
    ]

    networking_vpc_id       = module.networking.vpc_id
    security_group_id       = module.security_group.security_group_id
    compute_instance_ids    = module.compute.instance_ids
    load_balancer_dns_name  = module.load_balancer.alb_dns_name
    cdn_domain_name         = module.cdn.distribution_domain_name
    assets_bucket_name      = module.storage.assets_bucket_name
    instance_profile_name   = module.iam.instance_profile_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_5_main.tf environments/$env/main.tf
done
```

Important Terraform graph concept:

```text id="dependency-concept"
When module.compute uses module.networking.private_subnet_ids,
Terraform understands compute depends on networking output.
```

Terraform builds a dependency graph from references between expressions, including module outputs and resource attributes.

---

# 16. Update Environment Outputs

```bash id="root-outputs-template"
cat > /tmp/module12_5_outputs.tf <<'EOF'
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

output "common_tags" {
  description = "Common tags applied across resources."
  value       = local.common_tags
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

output "load_balancer_contract" {
  description = "Load balancer module contract."
  value       = module.load_balancer.contract
}

output "storage_contract" {
  description = "Storage module contract."
  value       = module.storage.contract
}

output "cdn_contract" {
  description = "CDN module contract."
  value       = module.cdn.contract
}

output "iam_contract" {
  description = "IAM module contract."
  value       = module.iam.contract
}

output "future_ansible_inventory_contract" {
  description = "Future handoff contract for Ansible inventory generation."
  value = {
    environment        = local.normalized_env
    instance_names     = module.compute.instance_names
    instance_ids       = module.compute.instance_ids
    app_port           = module.compute.app_port
    alb_dns_name       = module.load_balancer.alb_dns_name
    instance_role_name = module.iam.instance_role_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_5_outputs.tf environments/$env/outputs.tf
done
```

---

# 17. Run Dev Module Composition

```bash id="run-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev

terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl

terraform fmt -recursive
terraform validate

terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-5-dev
terraform apply tfplan-12-5-dev
```

Check outputs:

```bash id="check-dev-outputs"
terraform output module_composition_contract
terraform output future_ansible_inventory_contract
terraform output networking_contract
terraform output security_group_contract
```

Check module state addresses:

```bash id="check-module-state"
terraform state list | sort
```

Expected examples:

```text id="expected-state"
module.networking.terraform_data.networking_contract
module.security_group.terraform_data.security_group_contract
module.compute.terraform_data.compute_contract
module.load_balancer.terraform_data.load_balancer_contract
module.storage.terraform_data.storage_contract
module.cdn.terraform_data.cdn_contract
module.iam.terraform_data.iam_contract
terraform_data.environment_contract
terraform_data.module_composition_contract
```

`terraform state list` shows resource addresses, and resources inside child modules include the module path as part of the address. ([HashiCorp Developer][6])

---

# 18. Validate Staging and Prod Plans

```bash id="plan-staging-prod"
cd ~/devops-masterclass/12-terraform-ansible-iac

for env in staging prod; do
  echo "===== $env ====="
  cd environments/$env

  terraform init -backend=false
  terraform fmt -recursive
  terraform validate
  terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-5-$env
  terraform show -no-color tfplan-12-5-$env > ../../12.5-terraform-modules/reports/$env-module-plan.txt
  rm -f tfplan-12-5-$env

  cd ../..
done
```

---

# 19. Module Source Path Lab

Create examples note:

```bash id="source-note"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/module-sources-and-versioning.md
```

Paste:

````markdown id="source-note-content"
# Module Sources and Versioning

## Local module

```hcl
module "networking" {
  source = "../../modules/networking"
}
````

Good for:

* same repository modules
* active development
* monorepo workflows

## Registry module

```hcl id="fz8grm"
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "x.y.z"
}
```

Good for:

* widely used public/private modules
* versioned module consumption

## Git module

```hcl id="eepr52"
module "networking" {
  source = "git::https://github.com/example/terraform-modules.git//networking?ref=v1.2.0"
}
```

Good for:

* private module repos
* tag-based module releases

## Important

If source or version changes, rerun:

```bash id="dokq4m"
terraform init
```

## Production rule

External modules should be pinned by version or Git ref.
Do not consume moving branches like main for production.

````id="t4c2xo"

---

# 20. Provider Passing Notes

Create note:

```bash id="provider-note"
nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/provider-passing-in-modules.md
````

Paste:

````markdown id="provider-note-content"
# Provider Passing in Modules

## Root module owns provider config

Example:

```hcl
provider "aws" {
  region = var.aws_region
}
````

## Child modules declare requirements

Example:

```hcl id="bdby8d"
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
```

## Avoid child provider configuration blocks

Avoid this inside reusable modules:

```hcl id="1vih6o"
provider "aws" {
  region = "ap-south-1"
}
```

## Aliased provider example

Root:

```hcl id="hm682m"
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

module "cdn" {
  source = "../../modules/cdn"

  providers = {
    aws.use1 = aws.use1
  }
}
```

Child:

```hcl id="8o2gc8"
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [aws.use1]
    }
  }
}
```

## Course usage later

CloudFront ACM certificates require us-east-1.
So later CDN-related modules may need aliased provider passing.

````

---

# 21. Refactoring and State Notes

Create note:

```bash id="refactor-note"
nano 12-terraform-ansible-iac/12.5-terraform-modules/notes/module-refactoring-state.md
````

Paste:

````markdown id="refactor-note-content"
# Module Refactoring and State

## Why refactoring is dangerous

Moving a resource into a module changes its Terraform address.

Example before:

```text
aws_instance.web
````

Example after:

```text id="yhlpct"
module.compute.aws_instance.web
```

Terraform may think:

* old resource should be destroyed
* new resource should be created

unless state is moved.

## Safer modern pattern

Use `moved` blocks when refactoring inside configuration.

Example:

```hcl id="ssnulp"
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

## CLI pattern

Use state mv when needed:

```bash id="yazfh3"
terraform state mv aws_instance.web module.compute.aws_instance.web
```

## Production refactor checklist

1. Backup state.
2. Make code change.
3. Add moved block or plan state mv.
4. Run plan.
5. Confirm no unintended destroy/create.
6. Apply.
7. Remove moved block only after safe lifecycle policy.

## Golden rule

Module refactoring is state refactoring.
Never move real resources into modules without a state plan.

````

Terraform supports configuration-based `moved` blocks for refactoring addresses, and `terraform state mv` changes which resource address in configuration is associated with an existing remote object. :contentReference[oaicite:6]{index=6}

---

# 22. Module Documentation Script

Create a simple docs generator:

```bash id="docs-script"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-docs-summary.sh
````

Paste:

```bash id="docs-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="12-terraform-ansible-iac"
OUT="$BASE/12.5-terraform-modules/reports/module-docs-summary.md"

mkdir -p "$(dirname "$OUT")"

{
  echo "# Module Documentation Summary"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  for module_dir in "$BASE"/modules/*; do
    [ -d "$module_dir" ] || continue
    module_name="$(basename "$module_dir")"

    echo "## $module_name"
    echo

    echo "### Files"
    find "$module_dir" -maxdepth 1 -type f -printf "- %f\n" | sort
    echo

    echo "### Variables"
    grep -n '^variable ' "$module_dir/variables.tf" 2>/dev/null || echo "No variables.tf"
    echo

    echo "### Outputs"
    grep -n '^output ' "$module_dir/outputs.tf" 2>/dev/null || echo "No outputs.tf"
    echo
  done
} > "$OUT"

echo "Module documentation summary written to:"
echo "$OUT"
```

Make executable:

```bash id="chmod-docs"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-docs-summary.sh
```

Run:

```bash id="run-docs"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-docs-summary.sh
```

---

# 23. Module Contract Audit Script

```bash id="audit-script"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-contract-audit.sh
```

Paste:

```bash id="audit-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="12-terraform-ansible-iac"

echo "===== Terraform Module Contract Audit ====="

required_files=(
  "versions.tf"
  "variables.tf"
  "main.tf"
  "outputs.tf"
  "README.md"
)

for module_dir in "$BASE"/modules/*; do
  [ -d "$module_dir" ] || continue

  module_name="$(basename "$module_dir")"
  echo
  echo "Checking module: $module_name"

  for file in "${required_files[@]}"; do
    test -f "$module_dir/$file" || {
      echo "Missing $file in $module_name"
      exit 1
    }
  done

  grep -q '^variable "name_prefix"' "$module_dir/variables.tf" || {
    echo "Module $module_name missing name_prefix variable"
    exit 1
  }

  grep -q '^variable "common_tags"' "$module_dir/variables.tf" || {
    echo "Module $module_name missing common_tags variable"
    exit 1
  }

  grep -q '^output ' "$module_dir/outputs.tf" || {
    echo "Module $module_name has no outputs"
    exit 1
  }

  if grep -R '^provider "' "$module_dir" >/dev/null 2>&1; then
    echo "Module $module_name contains provider block. Avoid provider config in reusable child modules."
    exit 1
  fi
done

echo
echo "Module contract audit passed."
```

Make executable:

```bash id="chmod-audit"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-contract-audit.sh
```

Run:

```bash id="run-audit"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-contract-audit.sh
```

---

# 24. Module Composition Graph Script

```bash id="graph-script"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-composition-summary.sh
```

Paste:

```bash id="graph-content"
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

echo "===== Module Composition Summary ====="
echo "Environment: $ENVIRONMENT"

echo
echo "Module blocks:"
grep -n '^module "' main.tf || true

echo
echo "Module dependency references:"
grep -n 'module\.' main.tf outputs.tf || true

echo
echo "Current module state addresses:"
terraform state list 2>/dev/null | grep '^module\.' | sort || true

echo
echo "Composition output:"
terraform output module_composition_contract || true
```

Make executable:

```bash id="chmod-graph"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-composition-summary.sh
```

Run:

```bash id="run-graph"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/module-composition-summary.sh
```

---

# 25. Multi-Environment Module Validation Script

```bash id="multi-validate-script"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-module-composition.sh
```

Paste:

```bash id="multi-validate-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="12-terraform-ansible-iac"
REPORT_DIR="$BASE/12.5-terraform-modules/reports"

mkdir -p "$REPORT_DIR"

echo "===== Validate Terraform Module Composition ====="

"$BASE/12.5-terraform-modules/scripts/module-contract-audit.sh"

for env in dev staging prod; do
  echo
  echo "===== Environment: $env ====="

  pushd "$BASE/environments/$env" >/dev/null

  terraform init -backend=false >/dev/null
  terraform fmt -check -recursive
  terraform validate

  terraform plan \
    -var-file=terraform.tfvars.example \
    -out="tfplan-12-5-$env" >/dev/null

  terraform show -no-color "tfplan-12-5-$env" > "../../12.5-terraform-modules/reports/$env-module-composition-plan.txt"

  rm -f "tfplan-12-5-$env"

  popd >/dev/null
done

echo
echo "Module composition validation passed."
```

Make executable:

```bash id="chmod-multi-validate"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-module-composition.sh
```

Run:

```bash id="run-multi-validate"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-module-composition.sh
```

---

# 26. Lesson Validation Script

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-lesson-12-5.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.5 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.5-terraform-modules"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/examples"

test -f "$LESSON/notes/terraform-modules-mental-model.md"
test -f "$LESSON/notes/never-confuse-terraform-modules.md"
test -f "$LESSON/notes/module-anti-patterns.md"
test -f "$LESSON/notes/module-sources-and-versioning.md"
test -f "$LESSON/notes/provider-passing-in-modules.md"
test -f "$LESSON/notes/module-refactoring-state.md"

test -x "$LESSON/scripts/module-docs-summary.sh"
test -x "$LESSON/scripts/module-contract-audit.sh"
test -x "$LESSON/scripts/module-composition-summary.sh"
test -x "$LESSON/scripts/validate-module-composition.sh"

test -d "$BASE/modules/security-group"
test -f "$BASE/modules/security-group/main.tf"
test -f "$BASE/modules/security-group/variables.tf"
test -f "$BASE/modules/security-group/outputs.tf"
test -f "$BASE/modules/security-group/README.md"

terraform version >/dev/null

"$LESSON/scripts/validate-module-composition.sh"
"$LESSON/scripts/module-docs-summary.sh"

echo
echo "Lesson 12.5 validation passed."
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-lesson-12-5.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-lesson-12-5.sh
```

---

# 27. Cleanup Script

```bash id="cleanup-script"
nano 12-terraform-ansible-iac/12.5-terraform-modules/scripts/cleanup-lesson-12-5.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.5 ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

echo "Lesson 12.5 local plan artifacts cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.5-terraform-modules/scripts/cleanup-lesson-12-5.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/cleanup-lesson-12-5.sh
```

---

# 28. Production Module Design Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.5-terraform-modules/runbooks/production-module-design-runbook.md
```

Paste:

````markdown id="runbook-content"
# Production Terraform Module Design Runbook

## 1. Choose module boundaries carefully

Good module boundaries:

- networking
- security groups
- compute
- load balancer
- storage
- CDN
- IAM
- observability

Avoid modules for tiny fragments.

## 2. Define clear inputs

Every input should have:

- description
- type
- default only when safe
- validation when useful
- nullable=false when required

## 3. Define stable outputs

Expose:

- IDs
- ARNs
- DNS names
- names
- inventory values
- integration contracts

Do not expose every internal detail.

## 4. Avoid provider blocks in child modules

Root module configures providers.
Child module declares provider requirements.

## 5. Compose modules in root

Example:

```hcl
module "compute" {
  source = "../../modules/compute"

  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id  = module.security_group.security_group_id
}
````

## 6. Validate before apply

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars.example
```

## 7. Refactor carefully

Moving resources into modules changes addresses.

Use:

```hcl id="q9cr1w"
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web
}
```

or:

```bash id="bw90xg"
terraform state mv aws_instance.web module.compute.aws_instance.web
```

## Golden rule

A good module hides complexity but exposes a clean contract.

````id="n2r70v"

---

# 29. Module Review Checklist

```bash id="checklist"
nano 12-terraform-ansible-iac/12.5-terraform-modules/runbooks/module-review-checklist.md
````

Paste:

```markdown id="checklist-content"
# Terraform Module Review Checklist

## Inputs

- [ ] All variables have descriptions.
- [ ] Important variables have type constraints.
- [ ] Required values use nullable=false.
- [ ] Validations exist for ports, CIDRs, names, counts, and environments.
- [ ] Defaults are safe.
- [ ] No secrets are hardcoded.

## Implementation

- [ ] Module has meaningful boundary.
- [ ] Module avoids provider configuration blocks.
- [ ] Module avoids environment hardcoding.
- [ ] Resource names use name_prefix.
- [ ] Tags are passed in.
- [ ] Dependencies are created by references, not unnecessary depends_on.
- [ ] No over-complicated dynamic blocks unless justified.

## Outputs

- [ ] Outputs are useful contracts.
- [ ] Outputs avoid leaking secrets.
- [ ] Output names are stable.
- [ ] Downstream consumers are considered.

## Documentation

- [ ] README exists.
- [ ] Purpose is explained.
- [ ] Inputs are listed.
- [ ] Outputs are listed.
- [ ] Usage example exists.

## State/refactor

- [ ] No unintended destroy/create.
- [ ] Moved blocks or state mv planned if refactoring existing resources.
- [ ] Plan reviewed.
```

---

# 30. Common Mistakes and Fixes

## Mistake 1 — Applying from module folder

Wrong:

```bash id="wrong-apply"
cd modules/networking
terraform apply
```

Correct:

```bash id="correct-apply"
cd environments/dev
terraform apply
```

---

## Mistake 2 — Hardcoding values in child module

Wrong:

```hcl id="wrong-hardcode"
environment = "prod"
region      = "ap-south-1"
```

Correct:

```hcl id="correct-input"
environment = var.environment
```

---

## Mistake 3 — Provider block in reusable child module

Wrong:

```hcl id="wrong-provider"
provider "aws" {
  region = "ap-south-1"
}
```

Correct:

```text id="correct-provider"
Configure provider in root module.
Pass aliased providers explicitly only when needed.
```

---

## Mistake 4 — Too many modules

Bad:

```text id="too-many"
module for one string
module for one tag
module for one output
module for one security rule
```

Better:

```text id="meaningful-modules"
networking
security group
compute
load balancer
storage
cdn
iam
```

---

## Mistake 5 — Moving resources into modules without state planning

Wrong mindset:

```text id="wrong-refactor"
I moved code into a module, Terraform will understand automatically.
```

Correct:

```text id="correct-refactor"
Resource address changed.
Use moved block or terraform state mv.
```

---

# 31. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is a Terraform module?
What is a root module?
What is a child module?
What is module source?
What are module inputs?
What are module outputs?
How does a parent module consume a child output?
Why should reusable child modules avoid provider blocks?
When should you create a module?
When should you not create a module?
What is module overuse?
Why should external modules be versioned?
What happens when a resource moves into a module?
What are moved blocks?
When might terraform state mv be needed?
Why are outputs considered contracts?
How do module boundaries affect maintainability?
```

Strong interview answer:

```text id="interview-answer"
A Terraform module is a directory of Terraform configuration. The directory where I run Terraform is the root module, and reusable packages called from it are child modules. I use modules to represent meaningful infrastructure capabilities such as networking, compute, security groups, load balancers, storage, CDN, and IAM.

A good module has a clear input contract through variables, a clean implementation, stable outputs, documentation, and validation. I avoid hardcoding environments or regions inside reusable modules, and I avoid provider configuration blocks in child modules because provider configuration should normally come from the root module. I also avoid over-modularizing because too many tiny modules make the code harder to understand.

When composing modules, I pass outputs from one module into another, such as networking subnet outputs into compute and compute instance IDs into the load balancer. I treat outputs as stable contracts because CI/CD, Ansible, or other Terraform configurations may consume them. If I refactor resources into modules, I plan state migration carefully using moved blocks or terraform state mv to avoid accidental destroy/create.
```

Resume bullet:

```text id="resume-bullet"
Built production-style Terraform module architecture with reusable networking, security-group, compute, load-balancer, storage, CDN, and IAM modules, strong module input/output contracts, module composition across dev/staging/prod roots, provider-passing guidelines, module anti-pattern documentation, refactoring/state-move guidance, module contract audits, documentation summaries, and multi-environment validation automation.
```

---

# 32. Commit Lesson 12.5

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.5-terraform-modules/scripts/cleanup-lesson-12-5.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.5-terraform-modules/scripts/validate-lesson-12-5.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.5-terraform-modules -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/modules -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Terraform module architecture and contracts"

git push
```

---

# 33. Next Lesson

```text id="next-lesson"
12.6 — Terraform Workspaces
```

We will go deep into:

```text id="next-topics"
default workspace
terraform workspace list/select/new/delete
workspace-specific state
terraform.workspace
workspace pitfalls
workspace vs environment folders
when workspaces are useful
when workspaces are dangerous
backend key design
dev/staging/prod strategy
safe workspace lab
workspace drift risk
workspace cleanup
production decision framework
never-confuse workspace vs branch vs environment
```

[1]: https://developer.hashicorp.com/terraform/language/files?utm_source=chatgpt.com "Files and configuration structure - Configuration Language | Terraform | HashiCorp Developer"
[2]: https://developer.hashicorp.com/terraform/language/modules/configuration?utm_source=chatgpt.com "Use modules in your configuration | Terraform | HashiCorp Developer"
[3]: https://developer.hashicorp.com/terraform/language/values/outputs?utm_source=chatgpt.com "Use outputs to expose module data | Terraform | HashiCorp Developer"
[4]: https://developer.hashicorp.com/terraform/registry/modules/use?utm_source=chatgpt.com "Find and use modules in the Terraform registry | Terraform | HashiCorp Developer"
[5]: https://developer.hashicorp.com/terraform/language/modules/develop/providers?utm_source=chatgpt.com "Providers Within Modules - Configuration Language | Terraform | HashiCorp Developer"
[6]: https://developer.hashicorp.com/terraform/cli/commands/state/list?utm_source=chatgpt.com "terraform state list command reference | Terraform | HashiCorp Developer"
