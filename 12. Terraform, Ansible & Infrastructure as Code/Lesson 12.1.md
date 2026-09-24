# Module 12 — Terraform, Ansible, and Infrastructure as Code

# Deep Track Plan + Lesson 12.1

We’ll do this module in the same production-style format as Kubernetes:

```text
Terraform first:
  mental model → structure → state/backend → variables → modules → workspaces → AWS infra → ALB → S3/CloudFront → IAM

Then Ansible:
  inventory → playbooks → roles → variables → handlers → templates → idempotency → server config

Then integration:
  Terraform creates infra
  Terraform outputs inventory values
  Ansible configures servers
  CI/CD validates and applies IaC
  policy checks prevent dangerous changes
  final capstone
```

Terraform is used to define and manage infrastructure through configuration and state; HashiCorp recommends remote state/backends for secure collaboration, and Terraform modules are reusable configuration packages. ([Sentinel | HashiCorp Developer][1])
Ansible uses YAML playbooks to automate configuration and orchestration against inventory hosts, and variables can come from playbooks, inventory, roles, files, or command-line values. ([Ansible Documentation][2])

---

# Module 12 Roadmap

```text
12.1  IaC mental model
12.2  Terraform project structure
12.3  Terraform state and backend
12.4  variables, locals, outputs
12.5  modules
12.6  workspaces
12.7  AWS VPC infrastructure
12.8  EC2 and security groups
12.9  ALB and target groups
12.10 S3 and CloudFront
12.11 IAM troubleshooting
12.12 Ansible inventory and roles
12.13 Terraform + Ansible integration
12.14 CI/CD for IaC
12.15 policy checks
12.16 final IaC capstone
```

Enhanced structure:

```text
Terraform Deep Section:
  12.1 → 12.11

Ansible Deep Section:
  12.12

Terraform + Ansible Together:
  12.13

Production Automation:
  12.14 → 12.16
```

---

# Module 12 Rules We Will Follow

```text
Region:
  ap-south-1 for AWS resources

CloudFront ACM exception:
  us-east-1 when needed for CloudFront certificates

Cost safety:
  every AWS lab includes cleanup

Production mindset:
  no hardcoded secrets
  no manual console-first infrastructure
  no committing tfstate
  no applying without plan review
  no broad IAM unless intentionally scoped for lab
```

---

# Never Confuse These

## Terraform vs Ansible

```text
Terraform:
  creates and manages infrastructure lifecycle

Ansible:
  configures machines, packages, services, files, users, app runtime
```

Simple example:

```text
Terraform:
  create VPC, subnet, EC2, ALB, S3, CloudFront, IAM

Ansible:
  install nginx, configure app, copy files, start service, tune server
```

Never say:

```text
Terraform installs nginx better than Ansible.
Ansible manages AWS infra state better than Terraform.
```

Correct:

```text
Terraform provisions infra.
Ansible configures infra.
```

---

## Terraform State

Never forget:

```text
Terraform state maps your code to real infrastructure.
```

State is not optional in real Terraform work.

Never commit:

```text
terraform.tfstate
terraform.tfstate.backup
.terraform/
.terraform.lock.hcl? 
```

Correction:

```text
Commit .terraform.lock.hcl.
Do not commit .terraform directory.
Do not commit tfstate.
```

Terraform stores state locally by default, but remote backends are recommended for collaboration and safer state handling. ([Sentinel | HashiCorp Developer][1])

---

## Plan vs Apply

```text
terraform plan:
  preview intended changes

terraform apply:
  performs real changes

terraform destroy:
  deletes real infrastructure
```

Never run this casually:

```bash
terraform apply -auto-approve
terraform destroy -auto-approve
```

Only use `-auto-approve` in controlled CI/CD after strong validation.

---

## Workspaces

Terraform workspaces allow multiple state instances for the same configuration, but they are not always the best environment-separation strategy. HashiCorp notes that separate configurations with separate backends are often better for representing different environment instances. ([HashiCorp Developer][3])

Never assume:

```text
workspace = complete production isolation
```

Better production pattern:

```text
environments/dev
environments/staging
environments/prod
```

with separate backend keys or accounts.

---

## Modules

A module is reusable Terraform configuration. Every Terraform configuration has a root module, and child modules are called from that root module. Modules should follow a standard structure and include documentation. ([HashiCorp Developer][4])

Never confuse:

```text
module = reusable infrastructure package
provider = plugin that talks to API
resource = actual managed object
data source = read existing object
```

---

# Lesson 12.1 — IaC Mental Model

## Goal

Build your mental model for Infrastructure as Code and create a local Terraform-only lab with no AWS charges.

You will understand:

```text
what IaC is
why Terraform exists
why Ansible exists
declarative vs procedural automation
desired state
state file
drift
plan/apply lifecycle
idempotency
review gates
safe production workflow
```

Estimated time:

```text
45–60 minutes
```

---

# 1. Create Module 12 Folder

```bash
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.1-iac-mental-model/{terraform-local,notes,scripts,runbooks,reports}
```

Check:

```bash
tree -L 3 12-terraform-ansible-iac
```

---

# 2. IaC Mental Model

Infrastructure as Code means:

```text
You describe infrastructure in files.
You version those files in Git.
You review changes before applying.
Tools reconcile real infrastructure with desired configuration.
```

Manual infra:

```text
click in console
forget what changed
difficult to repeat
hard to review
hard to rollback
no reliable history
```

IaC infra:

```text
write code
review diff
plan change
apply change
store state
audit history
repeat safely
```

---

# 3. Declarative vs Procedural

## Terraform is mostly declarative

You describe the desired end state:

```text
I want:
  1 VPC
  2 public subnets
  2 private subnets
  1 ALB
  2 EC2 instances
```

Terraform decides create/update/delete order.

---

## Ansible is mostly procedural and task-oriented

You describe steps:

```text
install nginx
copy config
restart service
create user
pull artifact
start app
```

Good Ansible tasks are idempotent, meaning they should safely run multiple times without unnecessary changes.

---

# 4. IaC Lifecycle

```text
write
  ↓
format
  ↓
validate
  ↓
plan
  ↓
review
  ↓
apply
  ↓
verify
  ↓
monitor
  ↓
detect drift
  ↓
update code
```

Production workflow:

```text
developer branch
  ↓
terraform fmt
  ↓
terraform validate
  ↓
security/policy scan
  ↓
terraform plan
  ↓
human review
  ↓
approved apply
  ↓
post-apply validation
```

---

# 5. Create Notes

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/notes/iac-mental-model.md
```

Paste:

```markdown
# IaC Mental Model

## What is IaC?

Infrastructure as Code means infrastructure is described, reviewed, versioned, tested, and applied using code.

## Why IaC?

- repeatability
- auditability
- peer review
- automation
- disaster recovery
- environment consistency
- safer change management

## Terraform

Best for provisioning infrastructure lifecycle:

- VPC
- subnets
- route tables
- EC2
- ALB
- S3
- CloudFront
- IAM
- DNS
- databases
- Kubernetes clusters

## Ansible

Best for configuring systems:

- packages
- users
- files
- services
- app config
- deployment steps
- server hardening
- runtime validation

## Golden rule

Terraform creates infrastructure.
Ansible configures infrastructure.
CI/CD controls the workflow.
Policy checks reduce risk.
```

---

# 6. Create “Never Forget” Notes

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/notes/never-confuse-iac-points.md
```

Paste:

```markdown
# Never Confuse These IaC Points

## Terraform

Terraform is declarative infrastructure lifecycle management.

Do not confuse:

- provider with resource
- resource with data source
- variable with output
- state with code
- plan with apply
- workspace with full environment isolation
- module with environment
- count with for_each
- depends_on with normal dependency inference

## Terraform state

State maps Terraform resources to real infrastructure.

Never commit:

- terraform.tfstate
- terraform.tfstate.backup
- .terraform/

Usually commit:

- .terraform.lock.hcl

## Terraform plan

Plan is a preview, not a harmless command if exposed.

Plan can reveal sensitive values depending on configuration.

## Terraform apply

Apply changes real infrastructure.

## Terraform destroy

Destroy deletes real infrastructure.

Use carefully.

## Ansible

Ansible is task-based automation.

Do not confuse:

- inventory with playbook
- playbook with role
- role defaults with role vars
- handler with task
- template with static file
- check mode with guaranteed safety
- idempotent with no-op

## Terraform + Ansible

Terraform output can feed Ansible inventory.

Terraform should not become a shell-script dumping ground.

Ansible should not become cloud state management.
```

---

# 7. Create Local Terraform Lab

This lab uses Terraform without AWS resources.

It demonstrates:

```text
configuration
variables
locals
terraform_data resource
outputs
plan
apply
state
change detection
destroy
```

Enter folder:

```bash
cd ~/devops-masterclass/12-terraform-ansible-iac/12.1-iac-mental-model/terraform-local
```

Create `versions.tf`:

```bash
nano versions.tf
```

Paste:

```hcl
terraform {
  required_version = ">= 1.5.0"
}
```

Create `variables.tf`:

```bash
nano variables.tf
```

Paste:

```hcl
variable "project_name" {
  description = "Project name used for naming examples."
  type        = string
  default     = "devops-masterclass"

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "project_name must be at least 3 characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, or prod."
  }
}

variable "replica_count" {
  description = "Desired app replica count."
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "replica_count must be between 1 and 10."
  }
}
```

Create `main.tf`:

```bash
nano main.tf
```

Paste:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "12.1-iac-mental-model"
  }
}

resource "terraform_data" "application_plan" {
  input = {
    name          = "${local.name_prefix}-api"
    environment   = var.environment
    replica_count = var.replica_count
    region        = "ap-south-1"
    runtime       = "nodejs"
    owner         = "devops"
    tags          = local.common_tags
  }
}

resource "terraform_data" "deployment_policy" {
  input = {
    rollout_strategy = "rolling"
    max_unavailable  = 0
    max_surge        = 1
    require_approval = var.environment == "prod" ? true : false
  }
}
```

Create `outputs.tf`:

```bash
nano outputs.tf
```

Paste:

```hcl
output "application_plan" {
  description = "Rendered application infrastructure intent."
  value       = terraform_data.application_plan.output
}

output "deployment_policy" {
  description = "Rendered deployment safety policy."
  value       = terraform_data.deployment_policy.output
}

output "name_prefix" {
  description = "Common name prefix."
  value       = local.name_prefix
}
```

Create `.gitignore`:

```bash
nano .gitignore
```

Paste:

```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfplan
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

---

# 8. Run Terraform Workflow

Initialize:

```bash
terraform init
```

Format:

```bash
terraform fmt -recursive
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan -out=tfplan
```

Show plan:

```bash
terraform show tfplan
```

Apply saved plan:

```bash
terraform apply tfplan
```

Show outputs:

```bash
terraform output
terraform output -json
```

Check state:

```bash
terraform state list

terraform state show terraform_data.application_plan
```

Expected state list:

```text
terraform_data.application_plan
terraform_data.deployment_policy
```

---

# 9. Make a Controlled Change

Change `replica_count` without editing files:

```bash
terraform plan -var="replica_count=3" -out=tfplan-replicas-3
```

Review:

```bash
terraform show tfplan-replicas-3
```

Apply:

```bash
terraform apply tfplan-replicas-3
```

Check output:

```bash
terraform output application_plan
```

Now change environment:

```bash
terraform plan -var="environment=prod" -var="replica_count=3" -out=tfplan-prod
terraform show tfplan-prod
terraform apply tfplan-prod
```

Notice:

```text
require_approval becomes true for prod.
name_prefix changes from devops-masterclass-dev to devops-masterclass-prod.
```

This is the first practical IaC lesson:

```text
small variable changes can change infrastructure intent.
```

---

# 10. Destroy Local Lab Resources

This lab has no AWS resources, but still practice cleanup:

```bash
terraform destroy
```

Confirm with:

```text
yes
```

Check state:

```bash
terraform state list
```

Expected:

```text
No resources in state.
```

---

# 11. Create Workflow Script

Go back:

```bash
cd ~/devops-masterclass
```

Create script:

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/terraform-local-workflow.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="12-terraform-ansible-iac/12.1-iac-mental-model/terraform-local"

cd "$TF_DIR"

echo "===== Terraform Local Workflow ====="

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

echo
echo "Outputs:"
terraform output

echo
echo "State:"
terraform state list
```

Make executable:

```bash
chmod +x 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/terraform-local-workflow.sh
```

Run:

```bash
./12-terraform-ansible-iac/12.1-iac-mental-model/scripts/terraform-local-workflow.sh
```

---

# 12. Create Cleanup Script

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/cleanup-lesson-12-1.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="12-terraform-ansible-iac/12.1-iac-mental-model/terraform-local"

cd "$TF_DIR"

echo "===== Cleanup Lesson 12.1 ====="

if [ -d ".terraform" ]; then
  terraform destroy -auto-approve || true
fi

rm -f tfplan tfplan-* crash.log

echo "Lesson 12.1 local Terraform resources cleaned."
```

Make executable:

```bash
chmod +x 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/cleanup-lesson-12-1.sh
```

Run when done:

```bash
./12-terraform-ansible-iac/12.1-iac-mental-model/scripts/cleanup-lesson-12-1.sh
```

---

# 13. Create Validation Script

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/validate-lesson-12-1.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.1 ====="

BASE="12-terraform-ansible-iac/12.1-iac-mental-model"
TF_DIR="$BASE/terraform-local"

test -d "$BASE"
test -d "$BASE/notes"
test -d "$BASE/scripts"
test -d "$BASE/runbooks"
test -d "$BASE/reports"
test -d "$TF_DIR"

test -f "$BASE/notes/iac-mental-model.md"
test -f "$BASE/notes/never-confuse-iac-points.md"

test -f "$TF_DIR/versions.tf"
test -f "$TF_DIR/main.tf"
test -f "$TF_DIR/variables.tf"
test -f "$TF_DIR/outputs.tf"
test -f "$TF_DIR/.gitignore"

test -x "$BASE/scripts/terraform-local-workflow.sh"
test -x "$BASE/scripts/cleanup-lesson-12-1.sh"

terraform version >/dev/null

cd "$TF_DIR"

terraform init >/dev/null
terraform fmt -check -recursive
terraform validate

terraform plan -out=tfplan-validation >/dev/null
terraform apply -auto-approve tfplan-validation >/dev/null

terraform output name_prefix >/dev/null
terraform state list | grep terraform_data.application_plan >/dev/null

terraform destroy -auto-approve >/dev/null
rm -f tfplan-validation

echo "Lesson 12.1 validation passed."
```

Make executable:

```bash
chmod +x 12-terraform-ansible-iac/12.1-iac-mental-model/scripts/validate-lesson-12-1.sh
```

Run:

```bash
./12-terraform-ansible-iac/12.1-iac-mental-model/scripts/validate-lesson-12-1.sh
```

---

# 14. IaC Runbook

```bash
nano 12-terraform-ansible-iac/12.1-iac-mental-model/runbooks/iac-safe-change-runbook.md
```

Paste:

````markdown
# IaC Safe Change Runbook

## 1. Pull latest code

```bash
git pull
````

## 2. Format

```bash
terraform fmt -recursive
```

## 3. Validate

```bash
terraform validate
```

## 4. Plan

```bash
terraform plan -out=tfplan
```

## 5. Review plan

Check for:

* resources to create
* resources to update
* resources to replace
* resources to destroy
* IAM permission changes
* public exposure
* security group changes
* state/backend changes
* expensive resources

## 6. Apply

```bash
terraform apply tfplan
```

## 7. Validate after apply

Check:

* outputs
* AWS resources
* health checks
* logs
* metrics
* cost impact

## 8. Commit only safe files

Commit:

* .tf files
* .terraform.lock.hcl
* docs
* scripts

Do not commit:

* terraform.tfstate
* terraform.tfstate.backup
* .terraform/
* tfplan files
* secrets

````

---

# 15. Revision Checkpoint

Before moving to 12.2, you must be able to answer:

```text
What is IaC?
Why is manual infrastructure risky?
What does Terraform manage?
What does Ansible manage?
What is declarative automation?
What is procedural automation?
What is Terraform state?
Why should tfstate not be committed?
What is the difference between plan and apply?
Why is destroy dangerous?
Why should production IaC changes go through review?
````

Strong interview answer:

```text
Infrastructure as Code means defining infrastructure in version-controlled files so changes can be reviewed, tested, planned, applied, audited, and repeated. I use Terraform for infrastructure lifecycle management such as VPCs, subnets, EC2, ALBs, S3, CloudFront, IAM, and DNS. I use Ansible for configuration management such as installing packages, managing files, configuring services, hardening servers, and deploying application runtime changes.

Terraform is declarative and tracks real infrastructure through state, so state must be protected and usually stored remotely for team workflows. Ansible is task-oriented and should be written idempotently so repeated runs are safe. In production, I never apply infrastructure blindly. I format, validate, generate a plan, review blast radius, apply only approved changes, and validate the system afterward.
```

Resume bullet:

```text
Built a foundational Infrastructure as Code workflow using Terraform and Ansible mental models, safe change management, Terraform local state practice, variables, locals, outputs, validation scripts, cleanup automation, Git-safe ignore rules, and production IaC runbooks.
```

---

# 16. Commit Lesson 12.1

```bash
cd ~/devops-masterclass

git status

git add 12-terraform-ansible-iac

git commit -m "feat: start Terraform Ansible IaC module with mental model lab"

git push
```

---

# Next Lesson

```text
12.2 — Terraform Project Structure
```

We’ll build a production-style Terraform repository layout:

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
Makefile
README.md
```

And we’ll cover the rules you should never forget:

```text
root module vs child module
environment folder vs workspace
backend config vs provider config
provider pinning
.terraform.lock.hcl
naming conventions
tagging strategy
file structure
when to split modules
when not to split modules
how to avoid spaghetti Terraform
```

[1]: https://docs.hashicorp.com/terraform/language/state?utm_source=chatgpt.com "State | Terraform | HashiCorp Developer"
[2]: https://docs.ansible.com/projects/ansible/latest/playbook_guide/index.html?utm_source=chatgpt.com "Using Ansible playbooks — Ansible Community Documentation"
[3]: https://developer.hashicorp.com/terraform/cli/workspaces?utm_source=chatgpt.com "Manage workspaces | Terraform | HashiCorp Developer"
[4]: https://developer.hashicorp.com/terraform/language/modules?utm_source=chatgpt.com "Modules overview | Terraform | HashiCorp Developer"
