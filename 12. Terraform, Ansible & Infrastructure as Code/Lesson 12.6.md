# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.6 — Terraform Workspaces

In Lesson 12.5, you built production-style Terraform modules:

```text id="recap-12-5"
networking module
security-group module
compute module
load-balancer module
storage module
cdn module
iam module
module composition
module output chaining
module contract audits
module refactoring notes
```

Now we go deep into **Terraform workspaces**.

Terraform CLI workspaces are **separate state instances inside the same working directory**. Every initialized Terraform working directory starts with a workspace named `default`, and commands such as `terraform workspace list`, `new`, `select`, and `delete` manage those workspace states. HashiCorp also clearly warns that CLI workspaces are not the same as HCP Terraform workspaces and are not a strong isolation mechanism for complex deployments requiring separate credentials and access controls. ([HashiCorp Developer][1])

---

# 1. Goal

You will learn when workspaces are useful, when they are dangerous, and how they interact with your existing environment-folder strategy.

This lesson uses a safe local workspace lab with `terraform_data`, then shows how workspaces affect S3 backend state paths.

You will build:

```text id="goal"
workspace mental model
safe workspace lab
workspace command practice
terraform.workspace usage
workspace-specific naming
workspace-specific state demonstration
workspace cleanup
workspace-vs-environment decision framework
backend key explanation
workspace audit scripts
production runbooks
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.6.1   default workspace
12.6.2   terraform workspace list/show/new/select/delete
12.6.3   workspace-specific state
12.6.4   terraform.workspace
12.6.5   workspace naming
12.6.6   local backend workspace storage
12.6.7   S3 backend workspace key behavior
12.6.8   workspace vs environment folder
12.6.9   workspace vs Git branch
12.6.10  workspace vs AWS account
12.6.11  safe use cases
12.6.12  dangerous use cases
12.6.13  feature-branch workspace pattern
12.6.14  drift and wrong-workspace risk
12.6.15  cleanup workflow
12.6.16  production decision framework
12.6.17  scripts, validation, runbooks
```

---

# 3. Never Confuse These

## CLI Workspace vs Environment Folder

```text id="workspace-vs-env"
CLI workspace:
  multiple states for the same working directory and same configuration

environment folder:
  separate root module directory, usually with separate backend key/config
```

Your current production-style pattern remains:

```text id="env-folder-pattern"
environments/dev
environments/staging
environments/prod
```

Workspaces are useful, but HashiCorp recommends separate configurations and separate backends for larger systems or deployments requiring separate credentials and access controls. CLI workspaces inside one working directory share one backend configuration, so they are not a complete isolation boundary. ([HashiCorp Developer][1])

---

## Workspace vs Git Branch

```text id="workspace-vs-branch"
Git branch:
  code version

Terraform workspace:
  state selection
```

Never assume:

```text id="wrong-branch"
I changed Git branch, so Terraform workspace also changed.
```

Correct workflow:

```bash id="correct-branch-workspace"
git checkout feature/alb-healthcheck
terraform workspace show
terraform workspace select feature-alb-healthcheck
```

---

## Workspace vs AWS Account

```text id="workspace-vs-account"
workspace:
  state name

AWS account:
  actual security and billing boundary
```

Never use workspaces alone as a security boundary for production. Separate AWS accounts, roles, backend keys, and permissions are stronger production boundaries.

---

## `terraform.workspace` vs `var.environment`

```text id="workspace-vs-var"
terraform.workspace:
  current selected workspace name

var.environment:
  explicit input variable

Production preference:
  use var.environment for clear environment intent
```

`terraform.workspace` can be referenced inside configuration and is useful for changing names, tags, or smaller test deployments by workspace. But because it is implicit state selection, use it carefully and make the selected workspace visible in scripts and outputs. ([Sentinel | HashiCorp Developer][2])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.6-terraform-workspaces/{workspace-local,notes,scripts,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.6-terraform-workspaces
```

---

# 5. Create Workspace Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/notes/workspace-mental-model.md
```

Paste:

````markdown id="mental-note-content"
# Terraform Workspace Mental Model

## What is a CLI workspace?

A Terraform CLI workspace is a separate state instance in the same working directory.

Same code.
Different state.

## Default workspace

Every initialized working directory starts with:

```text
default
````

The default workspace cannot be deleted.

## Workspace commands

```bash
terraform workspace show
terraform workspace list
terraform workspace new NAME
terraform workspace select NAME
terraform workspace delete NAME
```

## Workspace risk

If you are in the wrong workspace, Terraform may plan against the wrong state.

## Good use cases

* temporary feature environments
* short-lived review apps
* personal experiments
* same config with isolated test state

## Bad use cases

* production isolation by itself
* separate AWS account security boundaries
* complex environment decomposition
* completely different infrastructure per environment

## Golden rule

Workspaces separate state.
They do not replace good environment architecture.

````

---

# 6. Create “Never Forget” Workspace Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/notes/never-confuse-workspaces.md
````

Paste:

````markdown id="never-note-content"
# Never Forget — Terraform Workspaces

## 1. Workspace is state selection

It is not a Git branch.
It is not an AWS account.
It is not a full environment boundary.

## 2. Always check current workspace

Before plan/apply/destroy:

```bash
terraform workspace show
````

## 3. default workspace exists automatically

You cannot delete default.

## 4. Same config, different state

Changing workspace does not change your Terraform files.

## 5. terraform.workspace is implicit

Use carefully.

## 6. Do not hide production behavior only behind terraform.workspace

Use explicit variables and separate root modules for production clarity.

## 7. Deleting workspace requires destroying or removing its resources first

Do not delete state while real resources still exist.

## 8. Local workspace state is still local state

Local backend stores multiple workspace states under terraform.tfstate.d.

Do not commit those files.

## 9. Remote backend workspace state lives in backend

For S3 backend, non-default workspace state uses workspace path behavior.

## 10. Wrong workspace is a real incident

Running apply or destroy in the wrong workspace can modify or delete the wrong environment.

````

---

# 7. Create Safe Local Workspace Lab

This lab does not create AWS resources.

Enter folder:

```bash id="cd-local"
cd ~/devops-masterclass/12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local
````

Create files:

```bash id="touch-files"
touch versions.tf variables.tf locals.tf main.tf outputs.tf .gitignore README.md
```

---

## `versions.tf`

```bash id="versions"
cat > versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
```

---

## `variables.tf`

```bash id="variables"
cat > variables.tf <<'EOF'
variable "project_name" {
  description = "Project name for workspace lab."
  type        = string
  default     = "devops-masterclass"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must use lowercase letters, numbers, and hyphens only."
  }
}

variable "base_replicas" {
  description = "Base replica count before workspace adjustment."
  type        = number
  default     = 2

  validation {
    condition     = var.base_replicas >= 1 && var.base_replicas <= 10
    error_message = "base_replicas must be between 1 and 10."
  }
}
EOF
```

---

## `locals.tf`

```bash id="locals"
cat > locals.tf <<'EOF'
locals {
  current_workspace = terraform.workspace

  workspace_safe_name = replace(lower(terraform.workspace), "_", "-")

  is_default_workspace = terraform.workspace == "default"

  is_feature_workspace = startswith(terraform.workspace, "feature-")

  effective_environment = terraform.workspace == "default" ? "dev" : local.workspace_safe_name

  replica_count = local.is_feature_workspace ? 1 : var.base_replicas

  name_prefix = "${var.project_name}-${local.effective_environment}"

  common_tags = {
    Project     = var.project_name
    Workspace   = terraform.workspace
    Environment = local.effective_environment
    ManagedBy   = "terraform"
    Lesson      = "12.6-terraform-workspaces"
  }
}
EOF
```

---

## `main.tf`

```bash id="main"
cat > main.tf <<'EOF'
resource "terraform_data" "workspace_contract" {
  input = {
    project_name         = var.project_name
    current_workspace    = local.current_workspace
    workspace_safe_name  = local.workspace_safe_name
    is_default_workspace = local.is_default_workspace
    is_feature_workspace = local.is_feature_workspace
    effective_environment = local.effective_environment
    name_prefix          = local.name_prefix
    replica_count        = local.replica_count
    tags                 = local.common_tags
  }
}

resource "terraform_data" "workspace_runtime_plan" {
  input = {
    service_name = "${local.name_prefix}-api"
    config_name  = "${local.name_prefix}-config"
    replicas     = local.replica_count
    destroy_safe = local.is_default_workspace ? false : true
  }
}
EOF
```

---

## `outputs.tf`

```bash id="outputs"
cat > outputs.tf <<'EOF'
output "workspace_contract" {
  description = "Current workspace contract."
  value       = terraform_data.workspace_contract.output
}

output "workspace_runtime_plan" {
  description = "Runtime plan derived from workspace."
  value       = terraform_data.workspace_runtime_plan.output
}

output "current_workspace" {
  description = "Current Terraform workspace."
  value       = terraform.workspace
}

output "name_prefix" {
  description = "Workspace-aware name prefix."
  value       = local.name_prefix
}
EOF
```

---

## `.gitignore`

```bash id="gitignore"
cat > .gitignore <<'EOF'
.terraform/
terraform.tfstate
terraform.tfstate.backup
terraform.tfstate.d/
*.tfplan
tfplan
tfplan-*
crash.log
EOF
```

---

## `README.md`

````bash id="readme"
cat > README.md <<'EOF'
# Terraform Workspace Local Lab

This lab demonstrates CLI workspaces safely using terraform_data.

No AWS resources are created.

## Commands

```bash
terraform init
terraform workspace show
terraform workspace list
terraform workspace new feature-demo
terraform workspace select feature-demo
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform workspace select default
````

## Important

Workspaces separate state.
They do not replace environment folders for production isolation.
EOF

````

---

# 8. Run Default Workspace

Initialize:

```bash id="init-local"
terraform init
````

Show current workspace:

```bash id="show-default"
terraform workspace show
```

Expected:

```text id="default-output"
default
```

List:

```bash id="list-default"
terraform workspace list
```

Expected:

```text id="list-default-output"
* default
```

Plan and apply:

```bash id="apply-default"
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan-default
terraform apply tfplan-default
```

Check outputs:

```bash id="output-default"
terraform output current_workspace
terraform output name_prefix
terraform output workspace_contract
```

Expected:

```text id="expected-default"
current_workspace = "default"
name_prefix includes dev
replica_count = 2
destroy_safe = false
```

---

# 9. Create Feature Workspace

Create a workspace:

```bash id="new-feature"
terraform workspace new feature-login-page
```

Show:

```bash id="show-feature"
terraform workspace show
```

Expected:

```text id="feature-workspace"
feature-login-page
```

List:

```bash id="list-feature"
terraform workspace list
```

Expected:

```text id="list-feature-output"
  default
* feature-login-page
```

Plan and apply:

```bash id="apply-feature"
terraform plan -out=tfplan-feature-login-page
terraform apply tfplan-feature-login-page
```

Check output:

```bash id="output-feature"
terraform output current_workspace
terraform output name_prefix
terraform output workspace_contract
terraform output workspace_runtime_plan
```

Expected:

```text id="expected-feature"
current_workspace = "feature-login-page"
name_prefix includes feature-login-page
replica_count = 1
destroy_safe = true
```

Why different?

```text id="why-different"
Same code.
Different workspace.
Different state.
Different terraform.workspace value.
```

When you run a plan in a new workspace, Terraform does not access resources from other workspaces; those objects may still exist physically, but you must select their workspace to manage them. ([Sentinel | HashiCorp Developer][2])

---

# 10. Compare Workspace State

List state in feature workspace:

```bash id="feature-state"
terraform state list
```

Switch to default:

```bash id="select-default"
terraform workspace select default
```

List state:

```bash id="default-state"
terraform state list
```

Switch back:

```bash id="select-feature"
terraform workspace select feature-login-page
terraform state list
```

Observe:

```text id="state-observation"
Both workspaces have similar resource addresses.
But they are separate state instances.
```

Check local state storage:

```bash id="local-state-storage"
find . -maxdepth 4 -type f | sort
```

Expected local workspace state paths may include:

```text id="local-state-paths"
terraform.tfstate
terraform.tfstate.d/feature-login-page/terraform.tfstate
```

For local state, Terraform stores non-default workspace states in `terraform.tfstate.d`, and HashiCorp says this should be treated like local-only state and not committed. ([HashiCorp Developer][1])

---

# 11. Workspace Delete Rules

You cannot delete the current workspace. You also should not delete workspace state while real resources still exist.

Destroy feature resources first:

```bash id="destroy-feature"
terraform workspace select feature-login-page
terraform destroy
```

Confirm:

```text id="confirm-destroy"
yes
```

Switch away:

```bash id="switch-default"
terraform workspace select default
```

Delete feature workspace:

```bash id="delete-feature"
terraform workspace delete feature-login-page
```

List:

```bash id="list-after-delete"
terraform workspace list
```

Expected:

```text id="delete-expected"
* default
```

Terraform starts with a single `default` workspace that cannot be deleted, and workspace commands operate on the currently selected workspace in the current working directory. ([HashiCorp Developer][1])

---

# 12. Workspace with S3 Backend: Concept

Your environment folders already use S3 backend config files:

```text id="current-backend"
environments/dev:
  key = environments/dev/terraform.tfstate
```

With S3 backend and workspaces, the `default` workspace uses the configured key, while non-default workspaces use workspace-aware object paths under the backend’s workspace prefix. Terraform’s S3 backend docs show that workspace usage needs permissions for both the default state key and paths under `<workspace_key_prefix>/*/path/to/my/key`; lockfile permissions are also required for `.tflock` objects when `use_lockfile` is enabled. ([HashiCorp Developer][3])

Important:

```text id="s3-workspace-warning"
Do not casually create dev/staging/prod workspaces inside environments/dev.

That creates confusing paths such as:
  environments/dev default state
  env:/staging/environments/dev state

Better:
  environments/dev uses dev backend key
  environments/staging uses staging backend key
  environments/prod uses prod backend key
```

---

# 13. Add Workspace Key Prefix Example

We will not change your active backend yet. Create an example config only.

```bash id="workspace-config-example"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.6-terraform-workspaces/examples

cat > 12-terraform-ansible-iac/12.6-terraform-workspaces/examples/s3-backend-workspace-example.hcl <<'EOF'
# Example only.
# Do not apply blindly to active environments.

bucket               = "example-terraform-state-bucket"
key                  = "examples/workspace-lab/terraform.tfstate"
region               = "ap-south-1"
encrypt              = true
use_lockfile         = true
workspace_key_prefix = "workspace-states"
EOF
```

Meaning:

```text id="workspace-key-prefix-meaning"
default workspace:
  examples/workspace-lab/terraform.tfstate

non-default workspace:
  workspace-states/<workspace-name>/examples/workspace-lab/terraform.tfstate
```

---

# 14. Safe Workspace Naming Convention

Create note:

```bash id="naming-note"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/notes/workspace-naming-conventions.md
```

Paste:

````markdown id="naming-content"
# Workspace Naming Conventions

## Good names

```text
feature-login-page
feature-alb-healthcheck
test-cost-optimization
review-pr-123
````

## Avoid

```text id="y8wk3v"
prod
production
main
default2
vivek personal test
```

## Why avoid prod workspace?

Because production should usually be represented by a dedicated environment root module and backend access controls.

## Recommended pattern

Use workspaces mostly for short-lived review or feature states.

Examples:

```bash id="skz3uk"
terraform workspace new feature-login-page
terraform workspace new review-pr-123
```

## Cleanup rule

Every temporary workspace must have an owner and cleanup date.

````

---

# 15. Workspace Safety Wrapper Script

Create a wrapper that refuses dangerous actions unless workspace is visible.

```bash id="safe-wrapper"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-safe-plan.sh
````

Paste:

```bash id="safe-wrapper-content"
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local}"
PLAN_NAME="${PLAN_NAME:-tfplan}"

cd "$TF_DIR"

CURRENT_WORKSPACE="$(terraform workspace show 2>/dev/null || echo "not-initialized")"

echo "===== Workspace Safe Plan ====="
echo "Terraform directory: $TF_DIR"
echo "Current workspace: $CURRENT_WORKSPACE"

if [ "$CURRENT_WORKSPACE" = "not-initialized" ]; then
  terraform init
  CURRENT_WORKSPACE="$(terraform workspace show)"
  echo "Current workspace after init: $CURRENT_WORKSPACE"
fi

terraform fmt -recursive
terraform validate

terraform plan -out="$PLAN_NAME"

echo
echo "Plan generated: $PLAN_NAME"
echo "Workspace used: $CURRENT_WORKSPACE"
```

Make executable:

```bash id="chmod-safe-wrapper"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-safe-plan.sh
```

Run:

```bash id="run-safe-wrapper"
TF_DIR=12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local \
PLAN_NAME=tfplan-safe \
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-safe-plan.sh
```

---

# 16. Workspace Audit Script

```bash id="audit-script"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-audit.sh
```

Paste:

```bash id="audit-content"
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local}"

cd "$TF_DIR"

echo "===== Terraform Workspace Audit ====="
echo "Directory: $TF_DIR"

if [ ! -d ".terraform" ]; then
  echo "Terraform is not initialized. Running terraform init..."
  terraform init >/dev/null
fi

echo
echo "Current workspace:"
terraform workspace show

echo
echo "Workspace list:"
terraform workspace list

echo
echo "State resources in current workspace:"
terraform state list || true

echo
echo "Local workspace files:"
find . -maxdepth 4 \
  \( -name "terraform.tfstate" -o -path "./terraform.tfstate.d/*" \) \
  -type f -print 2>/dev/null || true

echo
echo "Workspace-sensitive references:"
grep -R "terraform.workspace" . --include='*.tf' || true
```

Make executable:

```bash id="chmod-audit"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-audit.sh
```

Run:

```bash id="run-audit"
TF_DIR=12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local \
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-audit.sh
```

---

# 17. Temporary Workspace Lifecycle Script

This creates a temporary workspace, applies, shows outputs, destroys, and deletes the workspace.

```bash id="lifecycle-script"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/temp-workspace-lifecycle.sh
```

Paste:

```bash id="lifecycle-content"
#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local}"
WORKSPACE_NAME="${WORKSPACE_NAME:-feature-demo}"

if [[ ! "$WORKSPACE_NAME" =~ ^(feature|review|test)-[a-z0-9-]+$ ]]; then
  echo "Unsafe temporary workspace name: $WORKSPACE_NAME"
  echo "Use feature-*, review-*, or test-* with lowercase letters, numbers, and hyphens."
  exit 1
fi

cd "$TF_DIR"

echo "===== Temporary Workspace Lifecycle ====="
echo "Directory: $TF_DIR"
echo "Workspace: $WORKSPACE_NAME"

terraform init

if terraform workspace list | sed 's/*//g' | awk '{$1=$1};1' | grep -qx "$WORKSPACE_NAME"; then
  terraform workspace select "$WORKSPACE_NAME"
else
  terraform workspace new "$WORKSPACE_NAME"
fi

terraform fmt -recursive
terraform validate

terraform plan -out="tfplan-$WORKSPACE_NAME"
terraform apply "tfplan-$WORKSPACE_NAME"

echo
echo "Outputs:"
terraform output

echo
echo "Destroying temporary workspace resources..."
terraform destroy -auto-approve

terraform workspace select default
terraform workspace delete "$WORKSPACE_NAME"

rm -f "tfplan-$WORKSPACE_NAME"

echo
echo "Temporary workspace lifecycle complete."
terraform workspace list
```

Make executable:

```bash id="chmod-lifecycle"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/temp-workspace-lifecycle.sh
```

Run:

```bash id="run-lifecycle"
TF_DIR=12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local \
WORKSPACE_NAME=feature-workspace-lab \
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/temp-workspace-lifecycle.sh
```

---

# 18. Workspace vs Environment Folder Decision Framework

Create note:

```bash id="decision-note"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/notes/workspace-vs-environment-folder.md
```

Paste:

````markdown id="decision-content"
# Workspace vs Environment Folder Decision Framework

## Use environment folders when

- dev/staging/prod need separate backend keys
- dev/staging/prod need separate credentials
- dev/staging/prod need separate approval gates
- prod needs stronger access control
- infrastructure differs meaningfully
- team ownership differs
- blast radius matters

Recommended:

```text
environments/dev
environments/staging
environments/prod
````

## Use CLI workspaces when

* same configuration
* same backend/authentication pattern
* short-lived feature or review environment
* temporary test copy
* easy cleanup is required
* no strong security boundary is needed

Example:

```text id="u3ojzb"
feature-login-page
review-pr-123
test-module-refactor
```

## Avoid workspaces when

* representing production security boundary
* splitting subsystems
* hiding major environment differences
* managing different AWS accounts without careful provider role mapping
* users may forget to select the right workspace

## Course recommendation

Use environment folders for dev/staging/prod.
Use workspaces only for temporary feature or review states.

````

---

# 19. Add Workspace Safety Check to Makefile

Update Module 12 `Makefile` to show current workspace before planning or applying.

```bash id="update-makefile"
cd ~/devops-masterclass/12-terraform-ansible-iac

cat > Makefile <<'EOF'
ENV ?= dev
TF_DIR := environments/$(ENV)

.PHONY: fmt init validate workspace plan apply destroy clean check-env show-context

check-env:
	@test -d "$(TF_DIR)" || (echo "Invalid ENV=$(ENV). Use dev, staging, or prod."; exit 1)

fmt:
	terraform fmt -recursive

init: check-env
	cd $(TF_DIR) && terraform init

validate: check-env
	cd $(TF_DIR) && terraform validate

workspace: check-env
	cd $(TF_DIR) && terraform workspace show

show-context: check-env
	@echo "ENV=$(ENV)"
	@echo "TF_DIR=$(TF_DIR)"
	@cd $(TF_DIR) && echo "Workspace=$$(terraform workspace show 2>/dev/null || echo not-initialized)"

plan: check-env show-context
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars.example -out=tfplan

apply: check-env show-context
	cd $(TF_DIR) && terraform apply tfplan

destroy: check-env show-context
	cd $(TF_DIR) && terraform destroy

clean:
	find . -name "tfplan" -delete
	find . -name "tfplan-*" -delete
	find . -name "*.tfplan" -delete
	find . -name ".terraform" -type d -prune -exec rm -rf {} +
EOF
````

Use:

```bash id="make-use"
make show-context ENV=dev
make plan ENV=dev
```

---

# 20. Wrong Workspace Detection Script for Environments

This script warns if someone is using a non-default workspace inside your `environments/dev`, `staging`, or `prod` folders.

```bash id="guard-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/guard-environment-workspace.sh
```

Paste:

```bash id="guard-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

ENV_DIR="12-terraform-ansible-iac/environments/$ENVIRONMENT"

cd "$ENV_DIR"

if [ ! -d ".terraform" ]; then
  echo "Terraform not initialized in $ENV_DIR."
  echo "Skipping workspace guard."
  exit 0
fi

CURRENT_WORKSPACE="$(terraform workspace show)"

echo "Environment folder: $ENVIRONMENT"
echo "Current workspace: $CURRENT_WORKSPACE"

if [ "$CURRENT_WORKSPACE" != "default" ]; then
  echo "ERROR: Non-default workspace inside environments/$ENVIRONMENT."
  echo
  echo "Course safety rule:"
  echo "  Use environment folders for dev/staging/prod."
  echo "  Use workspaces only in dedicated temporary workspace labs or explicit review environments."
  exit 1
fi

echo "Workspace guard passed."
```

Make executable:

```bash id="chmod-guard"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/guard-environment-workspace.sh
```

Run:

```bash id="run-guard"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/guard-environment-workspace.sh
```

---

# 21. Workspace Report Script

```bash id="report-script"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-report.sh
```

Paste:

````bash id="report-content"
#!/usr/bin/env bash
set -euo pipefail

OUT="12-terraform-ansible-iac/12.6-terraform-workspaces/reports/workspace-report.md"
mkdir -p "$(dirname "$OUT")"

{
  echo "# Terraform Workspace Report"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  echo "## Environment folders"
  echo

  for env in dev staging prod; do
    dir="12-terraform-ansible-iac/environments/$env"
    echo "### $env"
    if [ -d "$dir/.terraform" ]; then
      ws="$(cd "$dir" && terraform workspace show 2>/dev/null || echo unknown)"
      echo "- workspace: $ws"
    else
      echo "- workspace: not initialized"
    fi
    echo "- backend file: $dir/backend.tf"
    echo
  done

  echo "## Workspace local lab"
  echo

  lab="12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local"
  if [ -d "$lab/.terraform" ]; then
    echo "- current workspace: $(cd "$lab" && terraform workspace show)"
    echo
    echo '```text'
    cd "$lab" && terraform workspace list
    cd - >/dev/null
    echo '```'
  else
    echo "- not initialized"
  fi
} > "$OUT"

echo "Workspace report written to:"
echo "$OUT"
````

Make executable:

```bash id="chmod-report"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-report.sh
```

Run:

```bash id="run-report"
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-report.sh
```

---

# 22. Lesson Validation Script

```bash id="validation-script"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/validate-lesson-12-6.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.6 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.6-terraform-workspaces"
LAB="$LESSON/workspace-local"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/examples"
test -d "$LAB"

test -f "$LESSON/notes/workspace-mental-model.md"
test -f "$LESSON/notes/never-confuse-workspaces.md"
test -f "$LESSON/notes/workspace-naming-conventions.md"
test -f "$LESSON/notes/workspace-vs-environment-folder.md"
test -f "$LESSON/examples/s3-backend-workspace-example.hcl"

test -x "$LESSON/scripts/workspace-safe-plan.sh"
test -x "$LESSON/scripts/workspace-audit.sh"
test -x "$LESSON/scripts/temp-workspace-lifecycle.sh"
test -x "$LESSON/scripts/guard-environment-workspace.sh"
test -x "$LESSON/scripts/workspace-report.sh"

terraform version >/dev/null

cd "$LAB"

terraform init >/dev/null
terraform fmt -check -recursive
terraform validate

DEFAULT_WS="$(terraform workspace show)"
if [ "$DEFAULT_WS" != "default" ]; then
  terraform workspace select default >/dev/null
fi

terraform plan -out=tfplan-validation >/dev/null
terraform apply -auto-approve tfplan-validation >/dev/null

terraform output current_workspace | grep default >/dev/null

if terraform workspace list | sed 's/*//g' | awk '{$1=$1};1' | grep -qx "feature-validation"; then
  terraform workspace select feature-validation >/dev/null
else
  terraform workspace new feature-validation >/dev/null
fi

terraform plan -out=tfplan-feature-validation >/dev/null
terraform apply -auto-approve tfplan-feature-validation >/dev/null

terraform output current_workspace | grep feature-validation >/dev/null
terraform output workspace_runtime_plan | grep true >/dev/null

terraform destroy -auto-approve >/dev/null
terraform workspace select default >/dev/null
terraform workspace delete feature-validation >/dev/null

rm -f tfplan-validation tfplan-feature-validation

echo "Lesson 12.6 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/validate-lesson-12-6.sh
```

Run:

```bash id="run-validation"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/validate-lesson-12-6.sh
```

---

# 23. Cleanup Script

```bash id="cleanup-script"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/cleanup-lesson-12-6.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.6 ====="

LAB="12-terraform-ansible-iac/12.6-terraform-workspaces/workspace-local"

if [ -d "$LAB/.terraform" ]; then
  pushd "$LAB" >/dev/null

  CURRENT="$(terraform workspace show 2>/dev/null || echo default)"

  for ws in $(terraform workspace list | sed 's/*//g' | awk '{$1=$1};1' | grep -v '^default$' || true); do
    terraform workspace select "$ws" >/dev/null
    terraform destroy -auto-approve || true
    terraform workspace select default >/dev/null
    terraform workspace delete "$ws" || true
  done

  terraform workspace select default >/dev/null || true
  terraform destroy -auto-approve || true

  rm -f tfplan tfplan-* *.tfplan
  rm -rf .terraform terraform.tfstate terraform.tfstate.backup terraform.tfstate.d

  popd >/dev/null
fi

find 12-terraform-ansible-iac -name "tfplan" -delete
find 12-terraform-ansible-iac -name "tfplan-*" -delete
find 12-terraform-ansible-iac -name "*.tfplan" -delete

echo "Lesson 12.6 local workspace artifacts cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/cleanup-lesson-12-6.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/cleanup-lesson-12-6.sh
```

---

# 24. Workspace Production Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/runbooks/terraform-workspace-production-runbook.md
```

Paste:

````markdown id="runbook-content"
# Terraform Workspace Production Runbook

## 1. Always show context

Before plan/apply/destroy:

```bash
pwd
git branch --show-current
terraform workspace show
````

## 2. List workspaces

```bash id="0gxzww"
terraform workspace list
```

## 3. Create temporary workspace

```bash id="48rqla"
terraform workspace new feature-login-page
```

## 4. Select workspace

```bash id="nmam2u"
terraform workspace select feature-login-page
```

## 5. Plan and apply

```bash id="fj0dy3"
terraform plan -out=tfplan
terraform apply tfplan
```

## 6. Destroy temporary workspace resources

```bash id="fq7y6h"
terraform destroy
```

## 7. Delete temporary workspace

```bash id="8ka9uf"
terraform workspace select default
terraform workspace delete feature-login-page
```

## Recommended usage

Use CLI workspaces for:

* short-lived test copies
* review environments
* feature branches
* personal experiments

Do not use CLI workspaces alone for:

* production isolation
* AWS account separation
* team permission boundaries
* major system decomposition

## Safer production pattern

Use:

```text id="4xwd9w"
environments/dev
environments/staging
environments/prod
```

with separate backend keys and controlled credentials.

## Golden rule

If you cannot confidently answer "which workspace am I in?", do not run apply or destroy.

````id="runbook-end"

---

# 25. Wrong Workspace Incident Runbook

```bash id="incident-runbook"
nano 12-terraform-ansible-iac/12.6-terraform-workspaces/runbooks/wrong-workspace-incident-runbook.md
````

Paste:

````markdown id="incident-runbook-content"
# Wrong Workspace Incident Runbook

## Symptom

Terraform plan shows unexpected create, update, or destroy actions.

## Immediate action

Stop.

Do not apply.

## Check context

```bash
pwd
git branch --show-current
terraform workspace show
terraform workspace list
````

## Check backend

```bash id="mxadst"
cat backend.tf
ls .terraform
```

## Check state

```bash id="kzl163"
terraform state list
terraform output
```

## Common causes

* wrong workspace selected
* wrong environment folder
* wrong backend config
* wrong AWS profile
* stale local `.terraform` backend metadata
* copied folder from another environment

## Recovery

### Wrong workspace selected

```bash id="g3p0er"
terraform workspace select correct-workspace
terraform plan
```

### Wrong backend config

```bash id="xfwheq"
terraform init -reconfigure -backend-config=correct-backend.hcl
terraform plan
```

### Accidental resources created in temporary workspace

```bash id="nxs5hz"
terraform workspace select temporary-workspace
terraform destroy
terraform workspace select default
terraform workspace delete temporary-workspace
```

## Golden rule

Unexpected plan means context mismatch until proven otherwise.

````id="incident-runbook-end"

---

# 26. Common Mistakes and Fixes

## Mistake 1 — Treating workspace as environment

Bad:

```text id="bad-workspace-env"
One folder.
dev workspace.
prod workspace.
same backend credentials.
````

Better for production:

```text id="good-env-folder"
environments/dev
environments/staging
environments/prod
```

---

## Mistake 2 — Forgetting current workspace

Always run:

```bash id="always-show"
terraform workspace show
```

before:

```bash id="before-danger"
terraform apply
terraform destroy
terraform state rm
terraform state mv
```

---

## Mistake 3 — Deleting workspace before destroy

Wrong:

```bash id="wrong-delete"
terraform workspace delete feature-x
```

while resources still exist.

Correct:

```bash id="correct-delete"
terraform workspace select feature-x
terraform destroy
terraform workspace select default
terraform workspace delete feature-x
```

---

## Mistake 4 — Using `terraform.workspace` everywhere

Bad:

```hcl id="bad-workspace-everywhere"
instance_type = terraform.workspace == "prod" ? "m5.large" : "t3.micro"
```

Better:

```hcl id="better-vars"
variable "compute_config" {
  type = object({
    instance_type = string
  })
}
```

Use explicit variables for important environment decisions.

---

## Mistake 5 — Workspace name not included in resource names

If two workspaces create real resources with the same names, they can collide.

Good:

```hcl id="workspace-naming-good"
name = "${var.project_name}-${terraform.workspace}-api"
```

For temporary workspaces, include workspace in names and tags.

---

# 27. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is a Terraform CLI workspace?
What is the default workspace?
Can the default workspace be deleted?
What commands manage workspaces?
What does terraform workspace show do?
What is terraform.workspace?
How is a workspace different from an environment folder?
How is a workspace different from a Git branch?
How is a workspace different from an AWS account?
When are CLI workspaces useful?
When are CLI workspaces dangerous?
Why are workspaces not a full production isolation boundary?
How does local state store non-default workspaces?
How does S3 backend handle workspace paths conceptually?
Why should you destroy temporary workspace resources before deleting the workspace?
Why should every apply/destroy show the current workspace first?
```

Strong interview answer:

```text id="interview-answer"
Terraform CLI workspaces are separate state instances within the same working directory. The configuration stays the same, but each workspace has its own state. Every initialized directory starts with the default workspace, and I can use terraform workspace list, show, new, select, and delete to manage them.

I do not treat CLI workspaces as a complete production environment strategy. They are useful for temporary feature environments, review environments, and isolated test copies of the same configuration. For dev, staging, and production, I prefer separate root modules such as environments/dev, environments/staging, and environments/prod with separate backend keys, credentials, and approval workflows.

Before any plan, apply, destroy, or state operation, I check the working directory, Git branch, AWS profile, backend, and terraform workspace show. If the plan looks unexpected, I treat it as a context mismatch until proven otherwise. For temporary workspaces, I include the workspace name in resource names and tags, destroy the resources first, then switch back to default and delete the workspace.
```

Resume bullet:

```text id="resume-bullet"
Built Terraform workspace labs and guardrails covering default and named workspaces, workspace-specific state, terraform.workspace usage, temporary feature workspace lifecycle, local workspace state storage, S3 backend workspace path behavior, environment-folder versus workspace decision frameworks, wrong-workspace incident runbooks, safety wrapper scripts, workspace audits, and cleanup automation.
```

---

# 28. Commit Lesson 12.6

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/cleanup-lesson-12-6.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/validate-lesson-12-6.sh
```

Generate report:

```bash id="generate-report"
./12-terraform-ansible-iac/12.6-terraform-workspaces/scripts/workspace-report.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.6-terraform-workspaces -maxdepth 4 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Terraform workspace safety labs"

git push
```

---

# 29. Next Lesson

```text id="next-lesson"
12.7 — AWS VPC Infrastructure with Terraform
```

Now we start creating real AWS infrastructure in `ap-south-1`.

We will build:

```text id="next-topics"
VPC
public subnets
private subnets
internet gateway
route tables
public routes
subnet tagging
availability zone selection
NAT gateway concept and cost warning
VPC endpoints concept
networking module real AWS implementation
outputs for EC2/ALB modules
validation commands
AWS console/CLI verification
cleanup to avoid charges
common VPC Terraform errors
```

Cost note for the next lesson:

```text id="cost-note"
We will avoid NAT Gateway by default in dev because NAT Gateway creates hourly and data-processing charges.
We will design the module to support NAT later, but default dev config will keep it disabled.
```

[1]: https://developer.hashicorp.com/terraform/cli/workspaces "Manage workspaces | Terraform | HashiCorp Developer"
[2]: https://docs.hashicorp.com/terraform/language/state/workspaces "State: Workspaces | Terraform | HashiCorp Developer"
[3]: https://developer.hashicorp.com/terraform/language/backend/s3 "Backend Type: s3 | Terraform | HashiCorp Developer"
