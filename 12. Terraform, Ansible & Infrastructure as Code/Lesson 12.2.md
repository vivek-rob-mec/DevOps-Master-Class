# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.2 — Terraform Project Structure

In Lesson 12.1, you built the **IaC mental model**:

```text id="recap-12-1"
Terraform provisions infrastructure.
Ansible configures infrastructure.
Terraform state maps code to real resources.
Plan previews.
Apply changes real infrastructure.
Destroy deletes real infrastructure.
State must not be committed.
Production IaC needs review gates.
```

Now we move into **Terraform project structure**.

Terraform files use the `.tf` extension, and a directory of Terraform files forms a module. The directory where you run Terraform commands is the **root module**, and child modules are reusable modules called from that root module. Terraform documentation also recommends a standard module structure so tools can understand and document modules consistently. ([HashiCorp Developer][1])

---

# 1. Goal

Build a production-style Terraform repository layout for Module 12.

You will create:

```text id="goal-map"
12-terraform-ansible-iac/
  environments/
    dev/
    staging/
    prod/
  modules/
    networking/
    compute/
    load-balancer/
    storage/
    cdn/
    iam/
  global/
    backend/
    iam/
  scripts/
  docs/
  Makefile
  README.md
```

This lesson will not create AWS resources yet. It is a **safe local structure lab**.

---

# 2. What You Will Learn

```text id="lesson-map"
12.2.1   root module vs child module
12.2.2   environment folders
12.2.3   why not put everything in one main.tf
12.2.4   provider pinning
12.2.5   .terraform.lock.hcl
12.2.6   backend config separation
12.2.7   modules folder structure
12.2.8   naming conventions
12.2.9   tagging conventions
12.2.10  tfvars strategy
12.2.11  dev/staging/prod structure
12.2.12  scripts and Makefile workflow
12.2.13  never-confuse Terraform structure rules
12.2.14  validation and cleanup
```

---

# 3. Never Confuse These

## Root Module vs Child Module

```text id="root-child"
Root module:
  the directory where you run terraform init/plan/apply

Child module:
  reusable Terraform configuration called by a module block
```

Example:

```text id="root-child-example"
environments/dev:
  root module

modules/networking:
  child module
```

Never run `terraform apply` from inside every child module during normal environment deployment.

You usually apply from:

```bash id="apply-root"
cd environments/dev
terraform apply
```

---

## Environment Folder vs Workspace

Do not confuse these:

```text id="env-vs-workspace"
environment folder:
  separate directory for dev/staging/prod code and backend config

Terraform workspace:
  separate state instance for the same configuration
```

For production-grade projects, environment folders are often clearer:

```text id="env-folder-clear"
environments/dev
environments/staging
environments/prod
```

Terraform workspaces can be useful, but they are not a replacement for all environment isolation. HashiCorp notes that separate configurations with distinct backend settings are often better for different environment instances. ([HashiCorp Developer][2])

---

## Provider Requirement vs Provider Configuration

```text id="provider-req-config"
required_providers:
  declares which provider and version range the module needs

provider block:
  configures the provider, such as AWS region
```

Root module example:

```hcl id="provider-root"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

Child modules should declare provider requirements, but should usually avoid their own provider configuration blocks. Terraform docs recommend passing provider configurations from root modules to child modules rather than defining provider blocks inside reusable child modules. ([HashiCorp Developer][3])

---

## `.terraform.lock.hcl` vs `.terraform/`

```text id="lock-vs-dir"
.terraform.lock.hcl:
  commit this

.terraform/:
  do not commit this
```

Terraform creates `.terraform.lock.hcl` to record provider dependency selections and checksums for the root module directory. The `.terraform` directory stores downloaded provider and module packages locally. ([HashiCorp Developer][4])

---

## `main.tf` Is Not Magic

Terraform loads all `.tf` files in a directory together.

These are just naming conventions:

```text id="tf-file-conventions"
main.tf:
  primary resources/module calls

variables.tf:
  input variables

outputs.tf:
  output values

versions.tf:
  Terraform and provider requirements

providers.tf:
  provider configuration

backend.tf:
  backend configuration
```

Terraform does not care if everything is in one file, but humans do.

---

# 4. Create Module 12 Structure

From repo root:

```bash id="create-structure"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/{environments/{dev,staging,prod},modules/{networking,compute,load-balancer,storage,cdn,iam},global/{backend,iam},scripts,docs}
mkdir -p 12-terraform-ansible-iac/12.2-terraform-project-structure/{notes,scripts,runbooks,reports}
```

Check:

```bash id="tree-structure"
tree -L 4 12-terraform-ansible-iac
```

Expected shape:

```text id="expected-tree"
12-terraform-ansible-iac/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── networking/
│   ├── compute/
│   ├── load-balancer/
│   ├── storage/
│   ├── cdn/
│   └── iam/
├── global/
│   ├── backend/
│   └── iam/
├── scripts/
├── docs/
└── 12.2-terraform-project-structure/
```

---

# 5. Create Root `.gitignore`

```bash id="gitignore"
nano 12-terraform-ansible-iac/.gitignore
```

Paste:

```gitignore id="gitignore-content"
# Terraform local directories
**/.terraform/*

# Terraform state files
**/terraform.tfstate
**/terraform.tfstate.*
**/*.tfstate
**/*.tfstate.*

# Terraform plans
**/*.tfplan
**/tfplan
**/tfplan-*

# Crash logs
**/crash.log
**/crash.*.log

# Override files
**/override.tf
**/override.tf.json
**/*_override.tf
**/*_override.tf.json

# Local variable files containing secrets or machine-specific values
**/*.auto.tfvars
**/*.auto.tfvars.json
**/terraform.tfvars
**/terraform.tfvars.json

# Keep examples
!**/*.tfvars.example

# Ansible later
**/.retry
```

Important correction:

```text id="gitignore-correction"
Do commit:
  .terraform.lock.hcl

Do not commit:
  .terraform/
  terraform.tfstate
  tfplan files
  secret tfvars
```

---

# 6. Environment Root Module Structure

Create common files for dev:

```bash id="dev-files"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev

touch versions.tf providers.tf backend.tf variables.tf locals.tf main.tf outputs.tf terraform.tfvars.example README.md
```

Repeat for staging and prod:

```bash id="copy-env-files"
cd ~/devops-masterclass/12-terraform-ansible-iac

for env in staging prod; do
  cp environments/dev/versions.tf environments/$env/versions.tf
  cp environments/dev/providers.tf environments/$env/providers.tf
  cp environments/dev/backend.tf environments/$env/backend.tf
  cp environments/dev/variables.tf environments/$env/variables.tf
  cp environments/dev/locals.tf environments/$env/locals.tf
  cp environments/dev/main.tf environments/$env/main.tf
  cp environments/dev/outputs.tf environments/$env/outputs.tf
  cp environments/dev/terraform.tfvars.example environments/$env/terraform.tfvars.example
  cp environments/dev/README.md environments/$env/README.md
done
```

---

# 7. Fill Dev Environment Files

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

## `versions.tf`

```bash id="versions-file"
nano versions.tf
```

Paste:

```hcl id="versions-content"
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    terraform = {
      source  = "terraform.io/builtin/terraform"
      version = ">= 1.0.0"
    }
  }
}
```

For AWS lessons later, this will become:

```hcl id="aws-version-future"
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Terraform provider requirements declare provider source and version constraints; root modules should constrain provider versions to avoid unexpected incompatible upgrades. ([HashiCorp Developer][5])

---

## `providers.tf`

```bash id="providers-file"
nano providers.tf
```

Paste:

```hcl id="providers-content"
# Provider configuration will be added in later AWS lessons.
# Example later:
#
# provider "aws" {
#   region = var.aws_region
#
#   default_tags {
#     tags = local.common_tags
#   }
# }
```

Why empty now?

```text id="empty-provider"
This lesson is a safe structure lab.
AWS provider configuration starts in later lessons.
```

---

## `backend.tf`

```bash id="backend-file"
nano backend.tf
```

Paste:

```hcl id="backend-content"
# Backend configuration will be added in Lesson 12.3.
#
# For now, this environment uses local state.
#
# Later example:
#
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "12-iac/dev/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
```

Never confuse:

```text id="backend-vs-provider"
backend:
  where Terraform state is stored

provider:
  how Terraform talks to AWS or another platform
```

---

## `variables.tf`

```bash id="variables-file"
nano variables.tf
```

Paste:

```hcl id="variables-content"
variable "project_name" {
  description = "Project name used for naming and tagging."
  type        = string
  default     = "devops-masterclass"

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "project_name must be at least 3 characters."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for regional resources."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "vivek"
}

variable "cost_center" {
  description = "Cost center or learning project tag."
  type        = string
  default     = "devops-learning"
}
```

---

## `locals.tf`

```bash id="locals-file"
nano locals.tf
```

Paste:

```hcl id="locals-content"
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Module      = "module-12"
  }
}
```

Use `locals` for reusable derived values:

```text id="locals-rule"
variables:
  external inputs

locals:
  internal calculated values

outputs:
  values exposed after apply
```

---

## `main.tf`

```bash id="main-file"
nano main.tf
```

Paste:

```hcl id="main-content"
resource "terraform_data" "environment_contract" {
  input = {
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
    name_prefix  = local.name_prefix
    tags         = local.common_tags
  }
}

resource "terraform_data" "module_plan" {
  input = {
    networking_module    = "../../modules/networking"
    compute_module       = "../../modules/compute"
    load_balancer_module = "../../modules/load-balancer"
    storage_module       = "../../modules/storage"
    cdn_module           = "../../modules/cdn"
    iam_module           = "../../modules/iam"
  }
}
```

This uses `terraform_data`, so it does not create AWS infrastructure.

---

## `outputs.tf`

```bash id="outputs-file"
nano outputs.tf
```

Paste:

```hcl id="outputs-content"
output "environment_contract" {
  description = "Environment metadata and tagging contract."
  value       = terraform_data.environment_contract.output
}

output "module_plan" {
  description = "Planned local child module paths for this environment."
  value       = terraform_data.module_plan.output
}

output "name_prefix" {
  description = "Common naming prefix."
  value       = local.name_prefix
}
```

---

## `terraform.tfvars.example`

```bash id="tfvars-example"
nano terraform.tfvars.example
```

Paste:

```hcl id="tfvars-content"
project_name = "devops-masterclass"
environment  = "dev"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"
```

Never commit real secrets in tfvars.

---

## `README.md`

```bash id="readme-dev"
nano README.md
```

Paste:

````markdown id="readme-dev-content"
# Dev Environment

This is the Terraform root module for the dev environment.

## Commands

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
````

## Notes

* Uses local state until Lesson 12.3.
* AWS resources are not created in Lesson 12.2.
* Remote S3 backend will be added later.
* Do not commit tfstate or tfplan files.

````

---

# 8. Adjust Staging and Prod Values

## Staging

```bash id="staging-tfvars"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/staging

cat > terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "staging"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"
EOF
````

Update default environment:

```bash id="staging-var"
python3 - <<'PY'
from pathlib import Path
p = Path("variables.tf")
s = p.read_text()
s = s.replace('default     = "dev"', 'default     = "staging"', 1)
p.write_text(s)
PY
```

## Prod

```bash id="prod-tfvars"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/prod

cat > terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "prod"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"
EOF
```

Update default environment:

```bash id="prod-var"
python3 - <<'PY'
from pathlib import Path
p = Path("variables.tf")
s = p.read_text()
s = s.replace('default     = "dev"', 'default     = "prod"', 1)
p.write_text(s)
PY
```

---

# 9. Create Child Module Standard Structure

Terraform standard module structure commonly includes files like `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, and optional nested modules/examples/tests depending on module complexity. ([HashiCorp Developer][6])

Create standard files:

```bash id="module-files"
cd ~/devops-masterclass/12-terraform-ansible-iac

for module in networking compute load-balancer storage cdn iam; do
  touch modules/$module/{versions.tf,main.tf,variables.tf,outputs.tf,README.md}
done
```

---

# 10. Fill Child Modules with Contracts

For now, modules will contain contracts and placeholders. Later lessons will replace these with real AWS resources.

## Networking Module

```bash id="networking-main"
cat > modules/networking/main.tf <<'EOF'
resource "terraform_data" "networking_contract" {
  input = {
    module_name = "networking"
    purpose     = "VPC, subnets, route tables, gateways"
  }
}
EOF

cat > modules/networking/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/networking/outputs.tf <<'EOF'
output "contract" {
  description = "Networking module contract."
  value       = terraform_data.networking_contract.output
}
EOF

cat > modules/networking/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/networking/README.md <<'EOF'
# Networking Module

Future responsibility:

- VPC
- public subnets
- private subnets
- route tables
- internet gateway
- NAT gateway concept
- VPC endpoints concept
EOF
```

## Compute Module

```bash id="compute-main"
cat > modules/compute/main.tf <<'EOF'
resource "terraform_data" "compute_contract" {
  input = {
    module_name = "compute"
    purpose     = "EC2 instances, launch templates, instance profiles"
  }
}
EOF

cat > modules/compute/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/compute/outputs.tf <<'EOF'
output "contract" {
  description = "Compute module contract."
  value       = terraform_data.compute_contract.output
}
EOF

cat > modules/compute/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/compute/README.md <<'EOF'
# Compute Module

Future responsibility:

- EC2
- security groups
- key pairs
- IAM instance profiles
- user data
- autoscaling group concept
EOF
```

## Load Balancer Module

```bash id="lb-main"
cat > modules/load-balancer/main.tf <<'EOF'
resource "terraform_data" "load_balancer_contract" {
  input = {
    module_name = "load-balancer"
    purpose     = "ALB, target groups, listeners, health checks"
  }
}
EOF

cat > modules/load-balancer/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/load-balancer/outputs.tf <<'EOF'
output "contract" {
  description = "Load balancer module contract."
  value       = terraform_data.load_balancer_contract.output
}
EOF

cat > modules/load-balancer/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/load-balancer/README.md <<'EOF'
# Load Balancer Module

Future responsibility:

- Application Load Balancer
- target groups
- listeners
- listener rules
- health checks
EOF
```

## Storage Module

```bash id="storage-main"
cat > modules/storage/main.tf <<'EOF'
resource "terraform_data" "storage_contract" {
  input = {
    module_name = "storage"
    purpose     = "S3 buckets, versioning, encryption, lifecycle"
  }
}
EOF

cat > modules/storage/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/storage/outputs.tf <<'EOF'
output "contract" {
  description = "Storage module contract."
  value       = terraform_data.storage_contract.output
}
EOF

cat > modules/storage/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/storage/README.md <<'EOF'
# Storage Module

Future responsibility:

- S3 static website bucket
- S3 private bucket
- versioning
- encryption
- lifecycle rules
- bucket policy
EOF
```

## CDN Module

```bash id="cdn-main"
cat > modules/cdn/main.tf <<'EOF'
resource "terraform_data" "cdn_contract" {
  input = {
    module_name = "cdn"
    purpose     = "CloudFront distribution, origins, cache behavior"
  }
}
EOF

cat > modules/cdn/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/cdn/outputs.tf <<'EOF'
output "contract" {
  description = "CDN module contract."
  value       = terraform_data.cdn_contract.output
}
EOF

cat > modules/cdn/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/cdn/README.md <<'EOF'
# CDN Module

Future responsibility:

- CloudFront distribution
- S3 origin
- ALB origin
- cache policies
- origin access control
- ACM certificate reference
EOF
```

## IAM Module

```bash id="iam-main"
cat > modules/iam/main.tf <<'EOF'
resource "terraform_data" "iam_contract" {
  input = {
    module_name = "iam"
    purpose     = "IAM roles, policies, instance profiles"
  }
}
EOF

cat > modules/iam/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
}
EOF

cat > modules/iam/outputs.tf <<'EOF'
output "contract" {
  description = "IAM module contract."
  value       = terraform_data.iam_contract.output
}
EOF

cat > modules/iam/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF

cat > modules/iam/README.md <<'EOF'
# IAM Module

Future responsibility:

- least-privilege policies
- EC2 instance role
- CI/CD deployment role
- IAM troubleshooting examples
EOF
```

---

# 11. Connect Dev Root Module to Child Modules

Update dev `main.tf`:

```bash id="dev-main-modules"
cat > environments/dev/main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "cdn" {
  source = "../../modules/cdn"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

resource "terraform_data" "environment_contract" {
  input = {
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
    name_prefix  = local.name_prefix
    tags         = local.common_tags
  }
}
EOF
```

Update dev outputs:

```bash id="dev-outputs"
cat > environments/dev/outputs.tf <<'EOF'
output "environment_contract" {
  description = "Environment metadata and tagging contract."
  value       = terraform_data.environment_contract.output
}

output "networking_contract" {
  description = "Networking module contract."
  value       = module.networking.contract
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

output "name_prefix" {
  description = "Common naming prefix."
  value       = local.name_prefix
}
EOF
```

Copy to staging and prod:

```bash id="copy-main-outputs"
cp environments/dev/main.tf environments/staging/main.tf
cp environments/dev/outputs.tf environments/staging/outputs.tf

cp environments/dev/main.tf environments/prod/main.tf
cp environments/dev/outputs.tf environments/prod/outputs.tf
```

Terraform module blocks can use local paths, registries, Git, object storage, or other sources; Terraform then includes the child module resources as part of the root configuration. ([HashiCorp Developer][7])

---

# 12. Validate Dev Environment

```bash id="validate-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform state list
```

Expected state list includes:

```text id="state-list"
module.networking.terraform_data.networking_contract
module.compute.terraform_data.compute_contract
module.load_balancer.terraform_data.load_balancer_contract
module.storage.terraform_data.storage_contract
module.cdn.terraform_data.cdn_contract
module.iam.terraform_data.iam_contract
terraform_data.environment_contract
```

Destroy local resources:

```bash id="destroy-dev"
terraform destroy
```

---

# 13. Validate Staging and Prod Without Apply

For project structure validation, plan is enough.

```bash id="validate-all-envs"
cd ~/devops-masterclass/12-terraform-ansible-iac

for env in dev staging prod; do
  echo "===== $env ====="
  cd environments/$env
  terraform init
  terraform fmt -recursive
  terraform validate
  terraform plan -out=tfplan
  rm -f tfplan
  cd ../..
done
```

---

# 14. Create Project README

```bash id="project-readme"
cd ~/devops-masterclass/12-terraform-ansible-iac

nano README.md
```

Paste:

````markdown id="project-readme-content"
# Module 12 — Terraform, Ansible, and Infrastructure as Code

## Purpose

This module builds production-style Infrastructure as Code skills using Terraform and Ansible.

## Structure

```text
environments/
  dev/
  staging/
  prod/

modules/
  networking/
  compute/
  load-balancer/
  storage/
  cdn/
  iam/

global/
  backend/
  iam/

scripts/
docs/
````

## Environment root modules

Run Terraform from:

```bash
environments/dev
environments/staging
environments/prod
```

## Child modules

Reusable modules live under:

```bash
modules/
```

## Safety rules

Do not commit:

* `.terraform/`
* `terraform.tfstate`
* `terraform.tfstate.backup`
* `tfplan`
* secret tfvars

Usually commit:

* `.tf` files
* `.terraform.lock.hcl`
* `.tfvars.example`
* documentation
* scripts

## Standard workflow

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Current status

Lesson 12.2 creates safe local Terraform structure only.
AWS resources begin in later lessons.

````

---

# 15. Create Makefile

```bash id="makefile"
nano Makefile
````

Paste:

```makefile id="makefile-content"
ENV ?= dev
TF_DIR := environments/$(ENV)

.PHONY: fmt init validate plan apply destroy clean check-env

check-env:
	@test -d "$(TF_DIR)" || (echo "Invalid ENV=$(ENV). Use dev, staging, or prod."; exit 1)

fmt:
	terraform fmt -recursive

init: check-env
	cd $(TF_DIR) && terraform init

validate: check-env
	cd $(TF_DIR) && terraform validate

plan: check-env
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: check-env
	cd $(TF_DIR) && terraform apply tfplan

destroy: check-env
	cd $(TF_DIR) && terraform destroy

clean:
	find . -name "tfplan" -delete
	find . -name "tfplan-*" -delete
	find . -name ".terraform" -type d -prune -exec rm -rf {} +
```

Use:

```bash id="make-commands"
make fmt
make init ENV=dev
make validate ENV=dev
make plan ENV=dev
make apply ENV=dev
make destroy ENV=dev
make clean
```

---

# 16. Create Structure Audit Script

```bash id="audit-script"
nano scripts/audit-terraform-structure.sh
```

Paste:

```bash id="audit-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Terraform Structure Audit ====="

BASE="."

required_dirs=(
  "environments/dev"
  "environments/staging"
  "environments/prod"
  "modules/networking"
  "modules/compute"
  "modules/load-balancer"
  "modules/storage"
  "modules/cdn"
  "modules/iam"
  "global/backend"
  "global/iam"
  "scripts"
  "docs"
)

required_env_files=(
  "versions.tf"
  "providers.tf"
  "backend.tf"
  "variables.tf"
  "locals.tf"
  "main.tf"
  "outputs.tf"
  "terraform.tfvars.example"
  "README.md"
)

required_module_files=(
  "versions.tf"
  "main.tf"
  "variables.tf"
  "outputs.tf"
  "README.md"
)

for dir in "${required_dirs[@]}"; do
  test -d "$BASE/$dir" || { echo "Missing directory: $dir"; exit 1; }
done

for env in dev staging prod; do
  for file in "${required_env_files[@]}"; do
    test -f "$BASE/environments/$env/$file" || { echo "Missing environment file: environments/$env/$file"; exit 1; }
  done
done

for module in networking compute load-balancer storage cdn iam; do
  for file in "${required_module_files[@]}"; do
    test -f "$BASE/modules/$module/$file" || { echo "Missing module file: modules/$module/$file"; exit 1; }
  done
done

echo "Checking for unsafe files..."

if find . -name "terraform.tfstate" -o -name "terraform.tfstate.backup" -o -name "*.tfplan" | grep .; then
  echo "Unsafe Terraform local files found. Clean before commit."
  exit 1
fi

echo "Terraform structure audit passed."
```

Make executable:

```bash id="chmod-audit"
chmod +x scripts/audit-terraform-structure.sh
```

Run:

```bash id="run-audit"
cd ~/devops-masterclass/12-terraform-ansible-iac

./scripts/audit-terraform-structure.sh
```

---

# 17. Create Multi-Environment Validation Script

```bash id="validate-script"
nano scripts/validate-all-terraform.sh
```

Paste:

```bash id="validate-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate All Terraform Environments ====="

terraform version >/dev/null

terraform fmt -recursive

for env in dev staging prod; do
  echo
  echo "===== Validating environment: $env ====="

  pushd "environments/$env" >/dev/null

  terraform init -backend=false
  terraform validate
  terraform plan -out=tfplan >/dev/null
  rm -f tfplan

  popd >/dev/null
done

echo
echo "All Terraform environments validated."
```

Make executable:

```bash id="chmod-validate"
chmod +x scripts/validate-all-terraform.sh
```

Run:

```bash id="run-validate"
cd ~/devops-masterclass/12-terraform-ansible-iac

./scripts/validate-all-terraform.sh
```

`terraform validate` checks whether configuration files are syntactically valid and internally consistent, but Terraform documentation notes that `terraform plan` verifies configuration in the context of a run, including input values and state. ([HashiCorp Developer][8])

---

# 18. Create Lesson 12.2 Validation Script

```bash id="lesson-validation"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/validate-lesson-12-2.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.2 ====="

BASE="12-terraform-ansible-iac"

test -d "$BASE/environments/dev"
test -d "$BASE/environments/staging"
test -d "$BASE/environments/prod"

test -d "$BASE/modules/networking"
test -d "$BASE/modules/compute"
test -d "$BASE/modules/load-balancer"
test -d "$BASE/modules/storage"
test -d "$BASE/modules/cdn"
test -d "$BASE/modules/iam"

test -f "$BASE/.gitignore"
test -f "$BASE/README.md"
test -f "$BASE/Makefile"

test -x "$BASE/scripts/audit-terraform-structure.sh"
test -x "$BASE/scripts/validate-all-terraform.sh"

terraform version >/dev/null

cd "$BASE"

./scripts/audit-terraform-structure.sh
./scripts/validate-all-terraform.sh

echo "Lesson 12.2 validation passed."
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/validate-lesson-12-2.sh
```

Run:

```bash id="run-lesson-validation"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/validate-lesson-12-2.sh
```

---

# 19. Create Cleanup Script

```bash id="cleanup-script"
nano 12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/cleanup-lesson-12-2.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.2 ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name ".terraform" -type d -prune -exec rm -rf {} +
find "$BASE" -name "terraform.tfstate" -delete
find "$BASE" -name "terraform.tfstate.backup" -delete

echo "Lesson 12.2 local Terraform artifacts cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/cleanup-lesson-12-2.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/cleanup-lesson-12-2.sh
```

---

# 20. Create Project Structure Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.2-terraform-project-structure/runbooks/terraform-project-structure-runbook.md
```

Paste:

````markdown id="runbook-content"
# Terraform Project Structure Runbook

## Recommended layout

```text
environments/
  dev/
  staging/
  prod/

modules/
  networking/
  compute/
  load-balancer/
  storage/
  cdn/
  iam/

global/
  backend/
  iam/

scripts/
docs/
````

## Root module

The root module is where Terraform commands run.

Example:

```bash
cd environments/dev
terraform init
terraform plan
```

## Child module

Reusable infrastructure package.

Example:

```text
modules/networking
```

Called by:

```hcl
module "networking" {
  source = "../../modules/networking"
}
```

## Environment folder rules

Each environment should have:

* versions.tf
* providers.tf
* backend.tf
* variables.tf
* locals.tf
* main.tf
* outputs.tf
* terraform.tfvars.example
* README.md

## Module folder rules

Each reusable module should have:

* versions.tf
* main.tf
* variables.tf
* outputs.tf
* README.md

## Do not commit

* .terraform/
* terraform.tfstate
* terraform.tfstate.backup
* tfplan files
* secrets
* real terraform.tfvars

## Usually commit

* .tf files
* .terraform.lock.hcl
* .tfvars.example
* scripts
* docs
* README files

## Golden rule

Keep root modules environment-specific.
Keep child modules reusable.

````

---

# 21. Create “Never Forget” Structure Notes

```bash id="never-forget"
nano 12-terraform-ansible-iac/12.2-terraform-project-structure/notes/never-forget-terraform-structure.md
````

Paste:

```markdown id="never-content"
# Never Forget — Terraform Project Structure

## 1. Root module is where commands run

If you run Terraform in the wrong folder, you use the wrong state and wrong config.

## 2. Do not put all production infra in one giant main.tf

Split by purpose:

- providers.tf
- backend.tf
- variables.tf
- locals.tf
- main.tf
- outputs.tf

## 3. Do not over-module too early

Bad:

- module for one tag
- module for one security group rule
- module for one variable

Good:

- networking module
- compute module
- load balancer module
- storage module
- CDN module
- IAM module

## 4. Child modules should be reusable

Avoid hardcoding:

- environment
- region
- account-specific values
- personal names
- secrets

## 5. Backend is not provider

Backend stores state.
Provider talks to cloud APIs.

## 6. .terraform.lock.hcl is important

Commit it so provider selections are reproducible.

## 7. terraform.tfvars.example is safe

terraform.tfvars may contain real values and should usually not be committed.

## 8. Environment folders beat cleverness

For production clarity:

- environments/dev
- environments/staging
- environments/prod

are easier to review than one magical folder with too many conditionals.

## 9. Outputs are contracts

Outputs expose values for humans, CI/CD, other Terraform states, or Ansible later.

## 10. README is part of production readiness

Every environment and module should explain purpose, inputs, outputs, and usage.
```

---

# 22. Revision Checkpoint

You should now be able to answer:

```text id="revision-questions"
What is a Terraform root module?
What is a child module?
Where should you run terraform apply?
Why do we use environments/dev, staging, prod?
Why should child modules avoid provider configuration blocks?
What goes in versions.tf?
What goes in providers.tf?
What goes in backend.tf?
What goes in variables.tf?
What goes in locals.tf?
What goes in outputs.tf?
Why commit .terraform.lock.hcl?
Why not commit .terraform/?
Why not commit terraform.tfstate?
Why not commit secret tfvars?
When should you create a module?
When should you avoid creating a module?
```

Strong interview answer:

```text id="interview-answer"
A Terraform project should separate environment root modules from reusable child modules. I run Terraform from an environment folder such as environments/dev or environments/prod. That root module contains backend configuration, provider configuration, variables, locals, outputs, and module calls. Reusable infrastructure components such as networking, compute, load balancers, storage, CDN, and IAM live under modules.

I keep child modules reusable by passing inputs from the root module and avoiding hardcoded environment or account-specific values. I also avoid provider configuration blocks inside child modules unless there is a specific advanced reason; the root module usually owns provider configuration. I commit .terraform.lock.hcl for reproducible provider selections, but I never commit .terraform directories, tfstate files, plan files, real tfvars, or secrets.

This structure makes infrastructure easier to review, test, reuse, and promote across dev, staging, and production.
```

Resume bullet:

```text id="resume-bullet"
Built a production-style Terraform repository structure with environment root modules, reusable child modules for networking, compute, load balancing, storage, CDN, and IAM, Git-safe ignore rules, provider/version conventions, tfvars examples, Makefile workflows, multi-environment validation scripts, structure audits, and Terraform project structure runbooks.
```

---

# 23. Commit Lesson 12.2

Clean first:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/cleanup-lesson-12-2.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.2-terraform-project-structure/scripts/validate-lesson-12-2.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac -maxdepth 4 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Terraform project structure foundation"

git push
```

---

# 24. Next Lesson

```text id="next-lesson"
12.3 — Terraform State and Backend
```

We will go deep into:

```text id="next-topics"
local state
remote state
state locking
S3 backend
DynamoDB locking concept
state file anatomy
terraform state list/show
terraform import
terraform state mv
terraform state rm
backend migration
state drift
state recovery
never manually edit state unless last resort
AWS backend bootstrap
ap-south-1 S3 state bucket
DynamoDB lock table
safe backend runbook
```

[1]: https://developer.hashicorp.com/terraform/language/files?utm_source=chatgpt.com "Files and configuration structure - Configuration Language | Terraform | HashiCorp Developer"
[2]: https://developer.hashicorp.com/terraform/tutorials/cli/init?utm_source=chatgpt.com "Initialize Terraform configuration | Terraform | HashiCorp Developer"
[3]: https://developer.hashicorp.com/terraform/language/modules/develop/providers?utm_source=chatgpt.com "Providers Within Modules - Configuration Language | Terraform | HashiCorp Developer"
[4]: https://developer.hashicorp.com/terraform/language/files/dependency-lock?utm_source=chatgpt.com "Dependency Lock File (.terraform.lock.hcl) - Configuration Language | Terraform | HashiCorp Developer"
[5]: https://developer.hashicorp.com/terraform/language/providers/requirements?utm_source=chatgpt.com "Provider Requirements - Configuration Language | Terraform | HashiCorp Developer"
[6]: https://developer.hashicorp.com/terraform/language/modules/develop/structure?utm_source=chatgpt.com "Standard Module Structure | Terraform | HashiCorp Developer"
[7]: https://developer.hashicorp.com/terraform/language/modules/configuration?utm_source=chatgpt.com "Use modules in your configuration | Terraform | HashiCorp Developer"
[8]: https://developer.hashicorp.com/terraform/cli/commands/validate?utm_source=chatgpt.com "terraform validate command reference | Terraform | HashiCorp Developer"
