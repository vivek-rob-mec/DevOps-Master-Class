# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.3 — Terraform State and Backend

In Lesson 12.2, you built the Terraform project structure:

```text id="recap-12-2"
environments/dev
environments/staging
environments/prod
modules/networking
modules/compute
modules/load-balancer
modules/storage
modules/cdn
modules/iam
global/backend
global/iam
scripts
docs
Makefile
```

Now we go deep into one of the most important Terraform topics:

```text id="state-topic"
Terraform state
remote backend
state locking
S3 backend
S3 native lockfile
DynamoDB locking legacy concept
backend migration
state commands
drift detection
state safety
```

Terraform stores infrastructure mappings in state. By default, state is local in `terraform.tfstate`; remote state lets a team share state safely through a backend such as S3, HCP Terraform, Azure Blob, Google Cloud Storage, and others. ([Sentinel | HashiCorp Developer][1])

---

# 1. Very Important 2026 Update

Current Terraform S3 backend docs say:

```text id="s3-lock-update"
S3 backend supports state locking using use_lockfile = true.
DynamoDB-based locking is deprecated and will be removed in a future minor version.
S3 and DynamoDB locking arguments can be configured together during migration from older setups.
```

So in this course:

```text id="our-choice"
Primary current pattern:
  S3 backend + use_lockfile = true

Legacy/interview pattern:
  S3 backend + DynamoDB table with LockID

We will understand both.
```

Terraform’s S3 backend stores state at the configured S3 bucket/key path and recommends enabling S3 bucket versioning for state recovery. The same docs now describe S3 lockfile locking and mark DynamoDB-based locking as deprecated. ([HashiCorp Developer][2])

---

# 2. Goal

You will build a production-style Terraform backend bootstrap:

```text id="goal"
global/backend:
  creates S3 state bucket
  enables versioning
  enables encryption
  blocks public access
  optionally creates DynamoDB lock table for legacy understanding

environments/dev:
  migrates from local state to S3 backend

environments/staging:
  gets separate S3 state key

environments/prod:
  gets separate S3 state key
```

Architecture:

```text id="backend-arch"
Terraform environment root module
  ↓
S3 backend
  ↓
S3 bucket object:
  environments/dev/terraform.tfstate

State lock:
  S3 .tflock file with use_lockfile = true

Legacy state lock concept:
  DynamoDB table with LockID partition key
```

---

# 3. What You Will Learn

```text id="lesson-map"
12.3.1   what Terraform state is
12.3.2   local state vs remote state
12.3.3   backend vs provider
12.3.4   state locking
12.3.5   S3 backend
12.3.6   S3 bucket versioning
12.3.7   S3 encryption
12.3.8   S3 native lockfile
12.3.9   DynamoDB locking legacy concept
12.3.10  backend bootstrap chicken-and-egg problem
12.3.11  backend config files
12.3.12  terraform init -migrate-state
12.3.13  terraform state list/show/pull
12.3.14  drift detection
12.3.15  state rm/mv/import concepts
12.3.16  safe backend runbook
```

---

# 4. Never Confuse These

## State vs Code

```text id="state-vs-code"
Code:
  what you want

State:
  what Terraform believes exists

Real cloud:
  what actually exists in AWS
```

These can differ.

```text id="three-way-diff"
Terraform code says:
  1 EC2

Terraform state says:
  1 EC2 with ID i-abc123

AWS says:
  EC2 deleted manually

Result:
  drift
```

---

## Backend vs Provider

```text id="backend-vs-provider"
Backend:
  stores Terraform state

Provider:
  creates/reads/updates/deletes real resources
```

Example:

```hcl id="backend-provider-example"
terraform {
  backend "s3" {
    bucket       = "my-tf-state-bucket"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"
}
```

Never say:

```text id="wrong-backend-provider"
S3 backend creates AWS resources.
```

Correct:

```text id="correct-backend-provider"
The AWS provider creates AWS resources.
The S3 backend stores Terraform state.
```

---

## Lock File vs Provider Lock File

Do not confuse:

```text id="lockfile-vs-lockfile"
.terraform.lock.hcl:
  provider dependency lock file
  commit this

S3 .tflock object:
  state lock object used during Terraform operation
  do not manually edit/delete unless emergency

DynamoDB LockID row:
  legacy state lock record
```

---

## Backend Bootstrap Problem

Terraform cannot store state in an S3 bucket before the bucket exists.

So we use:

```text id="bootstrap-flow"
Step 1:
  use local state in global/backend

Step 2:
  create S3 backend bucket

Step 3:
  configure environments/dev, staging, prod to use S3 backend

Step 4:
  run terraform init -migrate-state
```

This is normal.

---

# 5. State Safety Rules

```text id="state-rules"
Never commit tfstate.
Never edit tfstate manually unless last resort.
Never delete backend bucket casually.
Never run apply from two machines without locking.
Never run force-unlock unless you are sure no Terraform process is active.
Never use the same backend key for dev and prod.
Never expose state publicly.
Never forget state may contain sensitive values.
```

Terraform backend documentation warns that not all backends support locking; remote backends also reduce the risk of local state copies, though Terraform may write local state if a backend write fails and manual recovery is needed. ([Sentinel | HashiCorp Developer][3])

---

# 6. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.3-terraform-state-backend/{notes,scripts,runbooks,reports,backend-configs}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.3-terraform-state-backend
```

---

# 7. Create State Mental Model Notes

```bash id="state-note"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/notes/terraform-state-mental-model.md
```

Paste:

````markdown id="state-note-content"
# Terraform State Mental Model

## What is state?

Terraform state maps Terraform resource addresses to real infrastructure objects.

Example:

```text
aws_instance.web -> i-0123456789abcdef0
aws_s3_bucket.assets -> my-assets-bucket
````

## State answers

* what does Terraform manage?
* which real object belongs to which resource block?
* what attributes did Terraform last read?
* what dependencies exist between resources?

## Code vs State vs Reality

Code:
desired configuration

State:
Terraform's recorded view

Reality:
actual cloud resources

## Drift

Drift happens when reality changes outside Terraform.

Examples:

* security group changed manually
* EC2 deleted manually
* S3 bucket policy edited manually
* tag changed manually

## Golden rule

Terraform plan compares code + state + provider refresh to decide changes.

````

---

# 8. Create Backend Notes

```bash id="backend-note"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/notes/backend-remote-state-notes.md
````

Paste:

````markdown id="backend-note-content"
# Terraform Backend and Remote State Notes

## Local backend

Default behavior.

State stored in:

```text
terraform.tfstate
````

Good for:

* learning
* throwaway local tests

Bad for:

* teams
* production
* CI/CD collaboration

## Remote backend

State stored outside local machine.

Examples:

* S3
* HCP Terraform
* Azure Blob
* Google Cloud Storage
* Consul

## S3 backend

Stores state object in S3.

Example state key:

```text
environments/dev/terraform.tfstate
```

## State locking

Prevents multiple Terraform processes from writing state at the same time.

Current S3 backend pattern:

```hcl
use_lockfile = true
```

Legacy pattern:

```hcl
dynamodb_table = "terraform-locks"
```

## Important

DynamoDB locking for the S3 backend is deprecated in current Terraform docs.
Learn it because many companies still have it, but prefer S3 lockfile for new work.

````

---

# 9. AWS Prerequisites

Check AWS CLI:

```bash id="aws-check"
aws --version
````

Check identity:

```bash id="aws-identity"
aws sts get-caller-identity
```

Set region:

```bash id="aws-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

Optional profile:

```bash id="aws-profile"
export AWS_PROFILE=default
```

If credentials fail:

```text id="aws-cred-fail"
Do not continue.
Fix AWS credentials before creating backend resources.
```

Common fixes:

```bash id="aws-cred-fixes"
aws configure

aws sts get-caller-identity

aws configure list
```

---

# 10. Update Global Backend Bootstrap

Now create the actual backend bootstrap under:

```text id="backend-path"
12-terraform-ansible-iac/global/backend
```

Enter folder:

```bash id="cd-backend"
cd ~/devops-masterclass/12-terraform-ansible-iac/global/backend
```

Create files:

```bash id="touch-backend-files"
touch versions.tf providers.tf variables.tf locals.tf main.tf outputs.tf README.md terraform.tfvars.example
```

---

## `versions.tf`

```bash id="backend-versions"
cat > versions.tf <<'EOF'
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

AWS provider v6 is the current major generation of the HashiCorp AWS provider; the public registry results currently show 6.x as the latest line. ([Terraform Registry][4])

---

## `providers.tf`

```bash id="backend-providers"
cat > providers.tf <<'EOF'
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
EOF
```

---

## `variables.tf`

```bash id="backend-vars"
cat > variables.tf <<'EOF'
variable "project_name" {
  description = "Project name used for backend naming."
  type        = string
  default     = "devops-masterclass"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must use lowercase letters, numbers, and hyphens only."
  }
}

variable "environment" {
  description = "Backend environment name."
  type        = string
  default     = "global"
}

variable "aws_region" {
  description = "AWS region for backend resources."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "vivek"
}

variable "cost_center" {
  description = "Cost center tag."
  type        = string
  default     = "devops-learning"
}

variable "bucket_name_override" {
  description = "Optional globally unique S3 bucket name override."
  type        = string
  default     = ""
}

variable "create_legacy_dynamodb_lock_table" {
  description = "Whether to create a DynamoDB lock table for legacy S3 backend locking practice."
  type        = bool
  default     = true
}
EOF
```

---

## `locals.tf`

```bash id="backend-locals"
cat > locals.tf <<'EOF'
data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  generated_bucket_name = lower("${var.project_name}-${var.environment}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}")

  state_bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : local.generated_bucket_name

  lock_table_name = "${local.name_prefix}-terraform-locks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Module      = "12.3-terraform-state-backend"
  }
}
EOF
```

---

## `main.tf`

```bash id="backend-main"
cat > main.tf <<'EOF'
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-noncurrent-state-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

resource "aws_dynamodb_table" "terraform_locks" {
  count = var.create_legacy_dynamodb_lock_table ? 1 : 0

  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}
EOF
```

Why versioning and encryption?

Amazon S3 versioning keeps multiple variants of an object in the same bucket, which is useful for recovering old state versions after accidental overwrite or deletion. ([AWS Documentation][5])
Amazon S3 now applies SSE-S3 encryption by default to new object uploads, but explicitly configuring encryption in Terraform documents the security intent and makes the backend auditable. ([AWS Documentation][6])

Why DynamoDB `PAY_PER_REQUEST`?

DynamoDB has on-demand and provisioned capacity modes. On-demand is useful for variable or low/unpredictable usage because you do not have to plan read/write capacity ahead of time. ([AWS Documentation][7])

---

## `outputs.tf`

```bash id="backend-outputs"
cat > outputs.tf <<'EOF'
output "state_bucket_name" {
  description = "S3 bucket name used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "AWS region for Terraform state bucket."
  value       = var.aws_region
}

output "legacy_dynamodb_lock_table_name" {
  description = "Legacy DynamoDB lock table name. DynamoDB locking is deprecated for S3 backend in current Terraform docs."
  value       = var.create_legacy_dynamodb_lock_table ? aws_dynamodb_table.terraform_locks[0].name : null
}

output "backend_config_example_current" {
  description = "Current S3 backend config example using S3 lockfile."
  value = {
    bucket       = aws_s3_bucket.terraform_state.bucket
    region       = var.aws_region
    use_lockfile = true
  }
}
EOF
```

---

## `terraform.tfvars.example`

```bash id="backend-tfvars"
cat > terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "global"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"

# Optional only if generated bucket name collides.
bucket_name_override = ""

# Created for legacy/interview understanding.
# Current S3 backend should prefer use_lockfile = true.
create_legacy_dynamodb_lock_table = true
EOF
```

---

## `README.md`

````bash id="backend-readme"
cat > README.md <<'EOF'
# Global Backend Bootstrap

This Terraform root module creates the remote state backend resources:

- S3 bucket for Terraform state
- S3 bucket versioning
- S3 server-side encryption
- S3 public access block
- optional DynamoDB table for legacy state locking practice

## Important

This module initially uses local state because it creates the backend that other modules will use.

Do not casually destroy this backend.

The S3 bucket has prevent_destroy enabled.

## Commands

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
````

## Current backend pattern

Use S3 backend with:

```hcl
use_lockfile = true
```

## Legacy backend pattern

Older projects may still use:

```hcl
dynamodb_table = "table-name"
```

DynamoDB S3 backend locking is deprecated in current Terraform docs.
EOF

````

---

# 11. Bootstrap the Backend

From `global/backend`:

```bash id="backend-init"
cd ~/devops-masterclass/12-terraform-ansible-iac/global/backend

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
````

Show outputs:

```bash id="backend-output"
terraform output

STATE_BUCKET="$(terraform output -raw state_bucket_name)"
LOCK_TABLE="$(terraform output -raw legacy_dynamodb_lock_table_name 2>/dev/null || true)"
REGION="$(terraform output -raw state_bucket_region)"

echo "STATE_BUCKET=$STATE_BUCKET"
echo "LOCK_TABLE=$LOCK_TABLE"
echo "REGION=$REGION"
```

Validate AWS resources:

```bash id="aws-validate-backend"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET"

aws s3api get-public-access-block --bucket "$STATE_BUCKET"

aws s3api get-bucket-encryption --bucket "$STATE_BUCKET"

aws s3 ls "s3://$STATE_BUCKET"

if [ -n "$LOCK_TABLE" ] && [ "$LOCK_TABLE" != "null" ]; then
  aws dynamodb describe-table \
    --table-name "$LOCK_TABLE" \
    --query 'Table.{Name:TableName,Status:TableStatus,BillingMode:BillingModeSummary.BillingMode}'
fi
```

Expected:

```text id="backend-expected"
S3 bucket exists.
Versioning is Enabled.
Public access block exists.
Encryption exists.
DynamoDB table exists if enabled.
```

---

# 12. Generate Backend Config Files

Create script:

```bash id="gen-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/generate-backend-configs.sh
```

Paste:

```bash id="gen-content"
#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="12-terraform-ansible-iac/global/backend"
OUTPUT_DIR="12-terraform-ansible-iac/12.3-terraform-state-backend/backend-configs"

mkdir -p "$OUTPUT_DIR"

cd "$BACKEND_DIR"

STATE_BUCKET="$(terraform output -raw state_bucket_name)"
REGION="$(terraform output -raw state_bucket_region)"
LOCK_TABLE="$(terraform output -raw legacy_dynamodb_lock_table_name 2>/dev/null || true)"

cd - >/dev/null

for env in dev staging prod; do
  cat > "$OUTPUT_DIR/$env.s3.hcl" <<EOF
bucket       = "$STATE_BUCKET"
key          = "environments/$env/terraform.tfstate"
region       = "$REGION"
encrypt      = true
use_lockfile = true
EOF

  if [ -n "$LOCK_TABLE" ] && [ "$LOCK_TABLE" != "null" ]; then
    cat > "$OUTPUT_DIR/$env.s3-legacy-dynamodb.hcl" <<EOF
bucket         = "$STATE_BUCKET"
key            = "environments/$env/terraform.tfstate"
region         = "$REGION"
encrypt        = true
use_lockfile   = true
dynamodb_table = "$LOCK_TABLE"
EOF
  fi
done

echo "Generated backend configs:"
find "$OUTPUT_DIR" -type f -maxdepth 1 -print | sort
```

Make executable:

```bash id="chmod-gen"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/generate-backend-configs.sh
```

Run:

```bash id="run-gen"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/generate-backend-configs.sh
```

Check:

```bash id="check-backend-configs"
cat 12-terraform-ansible-iac/12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

Expected:

```hcl id="expected-backend-config"
bucket       = "devops-masterclass-global-tfstate-ACCOUNT-ap-south-1"
key          = "environments/dev/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

---

# 13. Add Partial Backend Blocks to Environments

Backend blocks cannot use normal input variables because Terraform reads backend configuration very early during initialization.

Add partial backend blocks:

```bash id="backend-blocks"
cd ~/devops-masterclass/12-terraform-ansible-iac

for env in dev staging prod; do
  cat > environments/$env/backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
done
```

This means backend values come from:

```text id="backend-config-source"
terraform init -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

---

# 14. Migrate Dev State to S3 Backend

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

Clean old local init files from Lesson 12.2:

```bash id="clean-dev-local"
rm -rf .terraform
rm -f tfplan tfplan-* terraform.tfstate terraform.tfstate.backup
```

Initialize with backend config:

```bash id="dev-init-backend"
terraform init \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

If Terraform asks to migrate existing state, answer:

```text id="migrate-answer"
yes
```

For this lesson, if you removed local state, there may be nothing to migrate.

Plan:

```bash id="dev-plan"
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Check state location:

```bash id="dev-state-check"
terraform state list
terraform output name_prefix
```

Check S3 object:

```bash id="dev-s3-object"
STATE_BUCKET="$(cd ../../global/backend && terraform output -raw state_bucket_name)"

aws s3 ls "s3://$STATE_BUCKET/environments/dev/"
```

Expected:

```text id="dev-s3-expected"
terraform.tfstate exists in S3.
```

Check lock behavior indirectly:

```bash id="lock-check"
terraform plan -out=tfplan-lock-test
rm -f tfplan-lock-test

aws s3 ls "s3://$STATE_BUCKET/environments/dev/" --recursive
```

The `.tflock` object is temporary and may disappear quickly after the operation finishes.

---

# 15. Configure Staging and Prod Backends

Staging:

```bash id="staging-backend"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/staging

rm -rf .terraform
rm -f tfplan tfplan-* terraform.tfstate terraform.tfstate.backup

terraform init \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/staging.s3.hcl

terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
rm -f tfplan
```

Prod:

```bash id="prod-backend"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/prod

rm -rf .terraform
rm -f tfplan tfplan-* terraform.tfstate terraform.tfstate.backup

terraform init \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/prod.s3.hcl

terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
rm -f tfplan
```

For now, do not apply staging/prod unless you intentionally want their local `terraform_data` contracts written to remote state.

---

# 16. State Commands Deep Dive

Run from dev:

```bash id="state-cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

List state:

```bash id="state-list"
terraform state list
```

Show one object:

```bash id="state-show"
terraform state show terraform_data.environment_contract
```

Pull remote state:

```bash id="state-pull"
terraform state pull > /tmp/dev-terraform-state.json

jq '.resources | length' /tmp/dev-terraform-state.json
jq '.lineage, .serial' /tmp/dev-terraform-state.json
```

Important:

```text id="state-pull-warning"
terraform state pull can expose sensitive values.
Do not save pulled state in your repo.
```

Delete temp pulled state:

```bash id="state-pull-clean"
rm -f /tmp/dev-terraform-state.json
```

Terraform docs describe `terraform state pull` and `terraform state push`, but warn that pushing state is dangerous because it overwrites remote state and should be avoided except for special recovery situations. ([Sentinel | HashiCorp Developer][3])

---

# 17. Drift Detection Lab

Drift means:

```text id="drift-meaning"
Something changed outside Terraform.
```

For this safe local contract resource, simulate code drift by changing input.

From dev:

```bash id="drift-plan"
terraform plan -var="owner=changed-owner" -out=tfplan-drift
terraform show tfplan-drift
```

Interpretation:

```text id="drift-result"
Terraform sees desired code/input changed.
It proposes an update.
```

Discard:

```bash id="drift-discard"
rm -f tfplan-drift
```

Real AWS drift examples later:

```text id="real-drift"
manual security group rule added
manual S3 bucket policy changed
manual EC2 tag changed
manual ALB health check edited
```

Safe drift workflow:

```bash id="drift-workflow"
terraform plan -refresh-only -out=tfplan-refresh
terraform show tfplan-refresh
rm -f tfplan-refresh
```

Use refresh-only when you want to inspect drift without proposing config-driven changes.

---

# 18. State Modification Commands — Concept Only

These commands are powerful.

Do not run them casually.

## `terraform state rm`

Removes a resource from state but does not delete the real cloud resource.

```bash id="state-rm-example"
terraform state rm aws_instance.example
```

Meaning:

```text id="state-rm-meaning"
Terraform forgets the resource.
AWS resource remains.
```

Use cases:

```text id="state-rm-use"
resource should no longer be managed by this Terraform state
migration to another state
emergency detach from Terraform
```

---

## `terraform state mv`

Moves a resource address inside state.

```bash id="state-mv-example"
terraform state mv aws_instance.web module.compute.aws_instance.web
```

Use cases:

```text id="state-mv-use"
refactoring resources into modules
renaming resources without replacement
moving resources between addresses
```

---

## `terraform import`

Imports an existing real resource into state.

```bash id="import-example"
terraform import aws_s3_bucket.example my-existing-bucket
```

Use cases:

```text id="import-use"
resource created manually
resource created by old scripts
resource created in console
bring existing infra under Terraform
```

Production rule:

```text id="import-rule"
Import is not complete until code matches imported resource.
State alone is not enough.
```

---

# 19. Create Backend Migration Script

```bash id="migration-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/init-env-backend.sh
```

Paste:

```bash id="migration-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="$BASE/12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"

test -d "$ENV_DIR"
test -f "$BACKEND_CONFIG"

echo "===== Init Terraform Backend ====="
echo "Environment: $ENVIRONMENT"
echo "Directory: $ENV_DIR"
echo "Backend config: $BACKEND_CONFIG"

cd "$ENV_DIR"

terraform init -reconfigure -backend-config="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"

terraform validate

echo "Backend initialized for $ENVIRONMENT."
```

Make executable:

```bash id="chmod-migration"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/init-env-backend.sh
```

Run:

```bash id="run-migration-script"
ENVIRONMENT=dev ./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/init-env-backend.sh
ENVIRONMENT=staging ./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/init-env-backend.sh
ENVIRONMENT=prod ./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/init-env-backend.sh
```

---

# 20. Create State Audit Script

```bash id="audit-script"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/state-audit.sh
```

Paste:

```bash id="audit-content"
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

echo "===== Terraform State Audit ====="
echo "Environment: $ENVIRONMENT"

echo
echo "Backend files:"
ls -la .terraform/terraform.tfstate 2>/dev/null || true

echo
echo "State resources:"
terraform state list || true

echo
echo "Outputs:"
terraform output || true

echo
echo "Remote state metadata:"
TMP_STATE="$(mktemp)"
terraform state pull > "$TMP_STATE"

jq '{version, terraform_version, serial, lineage}' "$TMP_STATE" || true

rm -f "$TMP_STATE"

echo
echo "Checking unsafe local files:"
find . \
  -name "terraform.tfstate" \
  -o -name "terraform.tfstate.backup" \
  -o -name "tfplan" \
  -o -name "tfplan-*" || true
```

Make executable:

```bash id="chmod-audit"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/state-audit.sh
```

Run:

```bash id="run-audit"
ENVIRONMENT=dev ./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/state-audit.sh
```

---

# 21. Create Backend Validation Script

```bash id="backend-validation"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-backend.sh
```

Paste:

```bash id="backend-validation-content"
#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="12-terraform-ansible-iac/global/backend"

cd "$BACKEND_DIR"

echo "===== Backend Validation ====="

terraform output state_bucket_name >/dev/null

STATE_BUCKET="$(terraform output -raw state_bucket_name)"
REGION="$(terraform output -raw state_bucket_region)"
LOCK_TABLE="$(terraform output -raw legacy_dynamodb_lock_table_name 2>/dev/null || true)"

echo "State bucket: $STATE_BUCKET"
echo "Region: $REGION"
echo "Legacy lock table: $LOCK_TABLE"

echo
echo "S3 bucket versioning:"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET"

echo
echo "S3 public access block:"
aws s3api get-public-access-block --bucket "$STATE_BUCKET"

echo
echo "S3 encryption:"
aws s3api get-bucket-encryption --bucket "$STATE_BUCKET"

if [ -n "$LOCK_TABLE" ] && [ "$LOCK_TABLE" != "null" ]; then
  echo
  echo "DynamoDB lock table:"
  aws dynamodb describe-table \
    --table-name "$LOCK_TABLE" \
    --query 'Table.{Name:TableName,Status:TableStatus,KeySchema:KeySchema,BillingMode:BillingModeSummary.BillingMode}'
fi

echo
echo "Backend validation passed."
```

Make executable:

```bash id="chmod-backend-validation"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-backend.sh
```

Run:

```bash id="run-backend-validation"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-backend.sh
```

---

# 22. Create Lesson Validation Script

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-lesson-12-3.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.3 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.3-terraform-state-backend"
BACKEND="$BASE/global/backend"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/backend-configs"

test -f "$LESSON/notes/terraform-state-mental-model.md"
test -f "$LESSON/notes/backend-remote-state-notes.md"

test -x "$LESSON/scripts/generate-backend-configs.sh"
test -x "$LESSON/scripts/init-env-backend.sh"
test -x "$LESSON/scripts/state-audit.sh"
test -x "$LESSON/scripts/validate-backend.sh"

test -f "$BACKEND/versions.tf"
test -f "$BACKEND/providers.tf"
test -f "$BACKEND/variables.tf"
test -f "$BACKEND/locals.tf"
test -f "$BACKEND/main.tf"
test -f "$BACKEND/outputs.tf"
test -f "$BACKEND/README.md"

terraform version >/dev/null
aws sts get-caller-identity >/dev/null

cd "$BACKEND"

terraform init >/dev/null
terraform fmt -check -recursive
terraform validate

cd - >/dev/null

echo "Lesson 12.3 file and config validation passed."
echo
echo "Note: AWS backend resource validation requires you to run:"
echo "./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-backend.sh"
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-lesson-12-3.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-lesson-12-3.sh
```

---

# 23. Cleanup and Cost Safety

This lesson creates:

```text id="created-resources"
1 S3 bucket
optional 1 DynamoDB table
```

Normally, do **not** destroy the backend immediately because future lessons use it.

If you truly want to clean up backend resources:

```text id="destroy-warning"
Only destroy after all environment state files are removed or backed up.
The S3 bucket has prevent_destroy enabled.
You must intentionally remove prevent_destroy before destroying.
```

Safe cleanup for local files only:

```bash id="local-clean"
cd ~/devops-masterclass/12-terraform-ansible-iac

find . -name "tfplan" -delete
find . -name "tfplan-*" -delete
find . -name ".terraform" -type d -prune -exec rm -rf {} +
```

Create cleanup script:

```bash id="cleanup-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/cleanup-lesson-12-3-local.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.3 Local Artifacts Only ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete

echo "Local plan files removed."
echo
echo "Remote backend resources were NOT destroyed."
echo "This is intentional because future Module 12 lessons will reuse the backend."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/cleanup-lesson-12-3-local.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/cleanup-lesson-12-3-local.sh
```

---

# 24. Backend Troubleshooting Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/runbooks/terraform-backend-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# Terraform Backend Troubleshooting Runbook

## 1. Check AWS identity

```bash
aws sts get-caller-identity
aws configure list
````

## 2. Check backend bucket

```bash
aws s3 ls s3://BUCKET_NAME
aws s3api get-bucket-versioning --bucket BUCKET_NAME
aws s3api get-bucket-encryption --bucket BUCKET_NAME
aws s3api get-public-access-block --bucket BUCKET_NAME
```

## 3. Check backend config

```bash
cat backend-configs/dev.s3.hcl
```

Check:

* bucket
* key
* region
* use_lockfile

## 4. Reconfigure backend

```bash
terraform init -reconfigure -backend-config=PATH_TO_BACKEND_CONFIG
```

## 5. Migrate local state to remote

```bash
terraform init -migrate-state -backend-config=PATH_TO_BACKEND_CONFIG
```

## 6. Check remote state

```bash
terraform state list
terraform state pull
```

Do not save pulled state in the repository.

## 7. Common errors

### Bucket does not exist

Fix:

* create backend with global/backend
* verify bucket name
* verify region

### AccessDenied

Check IAM permissions:

* s3:ListBucket
* s3:GetObject
* s3:PutObject
* s3:DeleteObject for .tflock when using use_lockfile
* dynamodb permissions if using legacy DynamoDB locking

### Backend config changed

Use:

```bash
terraform init -reconfigure
```

### Need migration

Use:

```bash
terraform init -migrate-state
```

### Lock stuck

First confirm no Terraform process is running.

Then use:

```bash
terraform force-unlock LOCK_ID
```

Do not force-unlock casually.

## Golden rule

Backend problems are production problems. Protect state first.

````

---

# 25. State Safety Runbook

```bash id="state-runbook"
nano 12-terraform-ansible-iac/12.3-terraform-state-backend/runbooks/terraform-state-safety-runbook.md
````

Paste:

````markdown id="state-runbook-content"
# Terraform State Safety Runbook

## Never commit

- terraform.tfstate
- terraform.tfstate.backup
- *.tfstate
- tfplan
- pulled state JSON
- secrets

## Always protect

- remote backend bucket
- state object versioning
- state encryption
- backend IAM permissions
- lock mechanism

## Safe commands

```bash
terraform state list
terraform state show RESOURCE
terraform state pull
````

## Dangerous commands

```bash
terraform state push
terraform state rm
terraform state mv
terraform import
terraform force-unlock
```

These are not bad commands, but they require intention, backup, and review.

## Before state surgery

1. Stop all Terraform runs.
2. Pull backup:

```bash
terraform state pull > /secure/location/state-backup.json
```

3. Confirm resource address.
4. Document reason.
5. Run command.
6. Run plan.
7. Validate no unintended create/destroy.

## Drift detection

```bash
terraform plan -refresh-only
```

## Golden rule

State is production data.
Treat it like a database.

````

---

# 26. Common Backend Errors and Fixes

## Error 1 — Bucket name already exists

```text id="bucket-exists"
BucketAlreadyExists
````

Cause:

```text id="bucket-exists-cause"
S3 bucket names are globally unique.
Someone else owns that name.
```

Fix:

```hcl id="bucket-override"
bucket_name_override = "devops-masterclass-global-tfstate-youruniquevalue-ap-south-1"
```

Then:

```bash id="bucket-override-apply"
cd 12-terraform-ansible-iac/global/backend
terraform plan -var='bucket_name_override=your-unique-bucket-name' -out=tfplan
terraform apply tfplan
```

---

## Error 2 — AccessDenied on S3 backend

Likely missing permissions:

```text id="s3-permissions"
s3:ListBucket
s3:GetObject
s3:PutObject
s3:DeleteObject for .tflock
```

Terraform S3 backend docs list required S3 permissions for the state object; when `use_lockfile` is enabled, the lock file path also needs read/write/delete object permissions. ([HashiCorp Developer][2])

---

## Error 3 — State lock stuck

Typical message:

```text id="lock-stuck"
Error acquiring the state lock
```

First:

```bash id="lock-investigate"
ps aux | grep terraform
```

Then:

```text id="lock-rule"
Only force-unlock if you are sure no Terraform process is still running.
```

Command:

```bash id="force-unlock"
terraform force-unlock LOCK_ID
```

Terraform locking prevents concurrent state writes when the backend supports locking. ([HashiCorp Developer][8])

---

## Error 4 — Backend config changed

Fix:

```bash id="reconfigure"
terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

---

## Error 5 — Need to migrate local state

Fix:

```bash id="migrate-state"
terraform init -migrate-state \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

---

# 27. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is Terraform state?
Why is local state dangerous for teams?
What is a backend?
What is remote state?
What is state locking?
What does S3 backend store?
What does use_lockfile=true do?
Why is DynamoDB locking now considered legacy/deprecated for S3 backend?
Why enable S3 versioning?
Why explicitly configure S3 encryption?
Why should backend bootstrap initially use local state?
Why can backend config not depend on variables?
What does terraform init -reconfigure do?
What does terraform init -migrate-state do?
What does terraform state list show?
What does terraform state pull do?
Why is terraform state push dangerous?
What is drift?
```

Strong interview answer:

```text id="interview-answer"
Terraform state is the mapping between Terraform resource addresses and real infrastructure objects. It is critical because Terraform uses state to decide what to create, update, replace, or destroy. Local state is risky for teams because multiple engineers or CI jobs can run with different copies, causing conflicts or data loss. For production, I use a remote backend such as S3 with locking and secure access control.

For current Terraform S3 backend usage, I prefer native S3 state locking with use_lockfile=true. I still understand DynamoDB locking because many older projects use it, but current Terraform documentation marks DynamoDB-based locking for S3 as deprecated. I enable S3 versioning for state recovery, encryption for security, public access blocking, and least-privilege IAM access.

I bootstrap the backend carefully because Terraform cannot store state in a bucket before that bucket exists. So the backend bootstrap module initially uses local state to create the S3 bucket, then environment root modules use backend config files and terraform init -migrate-state or -reconfigure to move to remote state. I treat state like production data and avoid manual state surgery unless there is a documented recovery or refactoring reason.
```

Resume bullet:

```text id="resume-bullet"
Built a production-style Terraform remote state backend on AWS using S3, versioning, server-side encryption, public access blocking, S3 native lockfile configuration, legacy DynamoDB lock-table awareness, backend config generation, environment state migration, state audit scripts, validation automation, drift detection workflows, and backend/state safety runbooks.
```

---

# 28. Commit Lesson 12.3

Clean local plans:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/cleanup-lesson-12-3-local.sh
```

Validate files:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-lesson-12-3.sh
```

Validate backend resources:

```bash id="validate-backend-before-commit"
./12-terraform-ansible-iac/12.3-terraform-state-backend/scripts/validate-backend.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.3-terraform-state-backend -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/global/backend -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Terraform remote state backend foundation"

git push
```

---

# 29. Next Lesson

```text id="next-lesson"
12.4 — Terraform Variables, Locals, and Outputs
```

We will go deep into:

```text id="next-topics"
input variables
type constraints
validation blocks
sensitive variables
nullable variables
default values
locals for naming and tags
outputs as contracts
sensitive outputs
tfvars strategy
CLI variable overrides
environment variables TF_VAR_
object/map/list/set types
for expressions
merge()
lookup()
try()
can()
production naming/tagging contract
never-confuse variable vs local vs output
```

[1]: https://docs.hashicorp.com/terraform/language/state/remote "State: Remote Storage | Terraform | HashiCorp Developer"
[2]: https://developer.hashicorp.com/terraform/language/backend/s3 "Backend Type: s3 | Terraform | HashiCorp Developer"
[3]: https://docs.hashicorp.com/terraform/language/state/backends "Backends: State Storage and Locking | Terraform | HashiCorp Developer"
[4]: https://registry.terraform.io/providers/hashicorp/aws?utm_source=chatgpt.com "hashicorp/aws | Terraform Registry"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html?utm_source=chatgpt.com "Retaining multiple versions of objects with S3 Versioning - Amazon Simple Storage Service"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html "Protecting data with server-side encryption - Amazon Simple Storage Service"
[7]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CostOptimization_TableCapacityMode.html "Evaluate your DynamoDB table's capacity mode - Amazon DynamoDB"
[8]: https://developer.hashicorp.com/terraform/language/state/locking?utm_source=chatgpt.com "State: Locking | Terraform | HashiCorp Developer"
