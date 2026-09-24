# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.4 — Terraform Variables, Locals, and Outputs

In Lesson 12.3, you built the Terraform state/backend foundation:

```text id="recap-12-3"
local state
remote state
S3 backend
S3 native lockfile
legacy DynamoDB lock table awareness
backend config files
state migration
state audit
drift detection
state safety runbooks
```

Now we go deep into Terraform’s **configuration contract layer**:

```text id="lesson-focus"
variables
locals
outputs
types
validation
sensitive values
tfvars
TF_VAR_ environment variables
for expressions
merge()
lookup()
try()
can()
naming and tagging contracts
```

Terraform input variables let a module accept values from the caller, local values give names to reusable expressions, and output values expose selected values from a module after Terraform evaluates it. Terraform supports type constraints and validations so module authors can reject bad inputs early. ([HashiCorp Developer][1])

---

# 1. Goal

You will upgrade your Module 12 Terraform structure with a production-style contract:

```text id="goal"
variables:
  external inputs

locals:
  internal calculated naming, tagging, maps, and policies

outputs:
  stable contracts exposed to humans, CI/CD, modules, and later Ansible
```

This lesson stays mostly safe and local using `terraform_data`. We will not create new AWS application infrastructure yet.

---

# 2. What You Will Learn

```text id="lesson-map"
12.4.1   variable mental model
12.4.2   variables.tf vs terraform.tfvars
12.4.3   variable precedence
12.4.4   primitive types
12.4.5   collection types
12.4.6   object types
12.4.7   optional object attributes
12.4.8   validation blocks
12.4.9   nullable variables
12.4.10  sensitive variables
12.4.11  locals for naming and tags
12.4.12  merge(), lookup(), try(), can()
12.4.13  for expressions
12.4.14  outputs as module contracts
12.4.15  sensitive outputs
12.4.16  tfvars strategy
12.4.17  TF_VAR_ environment variables
12.4.18  production naming/tagging contract
12.4.19  never-confuse points
12.4.20  validation, cleanup, runbooks
```

---

# 3. Never Confuse These

## Variable Declaration vs Variable Value

```text id="var-declaration-value"
variables.tf:
  declares what inputs exist, their type, validation, default, sensitivity

terraform.tfvars:
  supplies actual values for those inputs
```

Example:

```hcl id="var-decl-example"
variable "environment" {
  type    = string
  default = "dev"
}
```

Value file:

```hcl id="var-value-example"
environment = "prod"
```

Never say:

```text id="wrong-var"
variables.tf and terraform.tfvars are the same thing.
```

Correct:

```text id="correct-var"
variables.tf declares inputs.
tfvars supplies values.
```

---

## Variable vs Local vs Output

```text id="var-local-output"
variable:
  input into the module

local:
  calculated internal value inside the module

output:
  value exposed from the module
```

Example:

```hcl id="vlo-example"
variable "project_name" {
  type = string
}

locals {
  name_prefix = "${var.project_name}-dev"
}

output "name_prefix" {
  value = local.name_prefix
}
```

Never confuse them:

```text id="never-vlo"
Do not use outputs for internal reuse.
Do not use locals for user input.
Do not use variables to expose results.
```

---

## Sensitive Does Not Mean Secret Is Gone

Marking an input or output as `sensitive` redacts it from normal CLI output, but Terraform can still store sensitive values in state. HashiCorp’s docs and tutorials warn that sensitive output or variable values may still exist in state, so backend access must be protected. ([HashiCorp Developer][2])

```text id="sensitive-warning"
sensitive = true:
  hides from normal CLI display

sensitive = true does not:
  encrypt the value by itself
  remove it from state
  make it safe to expose tfstate
```

---

## `tfvars` vs Environment Variables

Terraform can read environment variables named with `TF_VAR_`, such as `TF_VAR_environment=dev`. Variable values can also come from defaults, `.tfvars`, `.auto.tfvars`, `-var-file`, and `-var`; the command-line options have the highest precedence in normal CLI workflows. ([HashiCorp Developer][1])

```bash id="tf-var-example"
export TF_VAR_environment=staging
terraform plan
```

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/{notes,scripts,runbooks,reports,examples}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs
```

---

# 5. Create Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/notes/variables-locals-outputs-mental-model.md
```

Paste:

```markdown id="mental-note-content"
# Terraform Variables, Locals, and Outputs Mental Model

## Variables

Variables are external inputs.

Use variables for values that change between:

- environments
- regions
- accounts
- teams
- modules
- deployments

Examples:

- project_name
- environment
- aws_region
- vpc_cidr
- instance_type
- allowed_ingress_ports
- enable_nat_gateway

## Locals

Locals are internal calculated values.

Use locals for:

- naming conventions
- merged tags
- derived maps
- repeated expressions
- normalized values
- environment-specific calculations

## Outputs

Outputs expose selected values.

Use outputs for:

- resource IDs
- names
- ARNs
- URLs
- Ansible inventory values
- CI/CD handoff values
- module contracts

## Golden rule

Variables come in.
Locals calculate inside.
Outputs go out.
```

---

# 6. Create “Never Forget” Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/notes/never-confuse-variables-locals-outputs.md
```

Paste:

````markdown id="never-note-content"
# Never Forget — Variables, Locals, Outputs

## 1. variables.tf declares variables

It does not need to contain the real environment values.

## 2. terraform.tfvars supplies values

Do not commit real terraform.tfvars if it contains secrets or local-only values.

## 3. terraform.tfvars.example documents expected values

Commit examples.

## 4. locals are not inputs

A user cannot override a local directly.

## 5. outputs are not variables

Outputs expose values after Terraform evaluates the configuration.

## 6. sensitive hides CLI display only

Sensitive values can still be stored in state.

## 7. validation blocks catch bad inputs early

Use validation for CIDR ranges, allowed environments, valid ports, naming rules, and production safety.

## 8. object types are production-friendly

Prefer object variables for grouped configuration.

## 9. maps are useful for environment-specific values

Example:

```hcl
instance_type_by_env = {
  dev     = "t3.micro"
  staging = "t3.small"
  prod    = "t3.medium"
}
````

## 10. sets avoid duplicate values

Use set(number) for unique ports.

## 11. list preserves order

Use list(string) when order matters.

## 12. map uses named keys

Use map(string) for tags and named values.

## 13. try() handles fallback access

Use try() for simple fallback access to maybe-missing attributes.

## 14. can() is mainly for validation

Use can() to test whether an expression can be evaluated.

## 15. outputs are contracts

Changing output names can break CI/CD, Ansible, or other Terraform configurations.

````

---

# 7. Create a Variables Deep Dive Note

```bash id="vars-note"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/notes/input-variable-types.md
````

Paste:

````markdown id="vars-note-content"
# Terraform Input Variable Types

## Primitive types

```hcl
string
number
bool
````

## Collection types

```hcl
list(string)
set(number)
map(string)
```

## Structural types

```hcl
object({
  cidr_block = string
  az_count   = number
})

tuple([string, number, bool])
```

## Production examples

### Environment

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
```

### Ports

```hcl
variable "allowed_ingress_ports" {
  type = set(number)

  validation {
    condition = alltrue([
      for port in var.allowed_ingress_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ports must be between 1 and 65535."
  }
}
```

### Object

```hcl
variable "network_config" {
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    enable_nat_gateway   = bool
  })
}
```

## Golden rule

Type your variables strongly.
Do not leave important production inputs as `any`.

````

---

# 8. Update Environment Variables

We’ll enhance the `dev`, `staging`, and `prod` root modules.

From repo root:

```bash id="cd-root"
cd ~/devops-masterclass/12-terraform-ansible-iac
````

Create a strong `variables.tf` template:

```bash id="vars-template"
cat > /tmp/module12_variables.tf <<'EOF'
variable "project_name" {
  description = "Project name used for naming and tagging."
  type        = string
  default     = "devops-masterclass"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) >= 3 && length(var.project_name) <= 32
    error_message = "project_name must be 3-32 characters and use lowercase letters, numbers, and hyphens only."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for regional resources."
  type        = string
  default     = "ap-south-1"
  nullable    = false

  validation {
    condition     = contains(["ap-south-1", "us-east-1"], var.aws_region)
    error_message = "aws_region must be ap-south-1 or us-east-1 for this course."
  }
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "vivek"
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner cannot be empty."
  }
}

variable "cost_center" {
  description = "Cost center or learning project tag."
  type        = string
  default     = "devops-learning"
  nullable    = false
}

variable "network_config" {
  description = "Network configuration contract for the environment."
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    enable_nat_gateway   = bool
  })
  nullable = false

  validation {
    condition     = can(cidrhost(var.network_config.vpc_cidr, 1))
    error_message = "network_config.vpc_cidr must be a valid CIDR block."
  }

  validation {
    condition     = length(var.network_config.public_subnet_cidrs) >= 2 && length(var.network_config.private_subnet_cidrs) >= 2
    error_message = "At least two public and two private subnet CIDRs are required."
  }

  validation {
    condition = alltrue([
      for cidr in concat(var.network_config.public_subnet_cidrs, var.network_config.private_subnet_cidrs) :
      can(cidrhost(cidr, 1))
    ])
    error_message = "All subnet CIDRs must be valid CIDR blocks."
  }
}

variable "compute_config" {
  description = "Compute configuration contract for the environment."
  type = object({
    instance_type = string
    instance_count = number
    app_port      = number
    enable_ssm    = bool
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

variable "allowed_ingress_ports" {
  description = "Unique ingress ports allowed by the environment contract."
  type        = set(number)
  default     = [80, 443]
  nullable    = false

  validation {
    condition = alltrue([
      for port in var.allowed_ingress_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ingress ports must be between 1 and 65535."
  }
}

variable "feature_flags" {
  description = "Feature toggles for environment behavior."
  type = object({
    enable_alb        = bool
    enable_cloudfront = bool
    enable_monitoring = bool
  })
  default = {
    enable_alb        = true
    enable_cloudfront = false
    enable_monitoring = true
  }
  nullable = false
}

variable "extra_tags" {
  description = "Additional user-supplied tags."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "sensitive_demo_token" {
  description = "Demo sensitive token to show sensitive variable behavior. Do not use real secrets here."
  type        = string
  default     = "demo-token-not-real"
  sensitive   = true
  nullable    = false
}
EOF
```

Apply to all environments:

```bash id="apply-vars-template"
for env in dev staging prod; do
  cp /tmp/module12_variables.tf environments/$env/variables.tf
done
```

Set environment defaults separately by creating `.tfvars.example` files instead of defaulting `environment` in the variable block.

---

# 9. Create Environment tfvars Examples

## Dev

```bash id="dev-tfvars"
cat > environments/dev/terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "dev"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"

network_config = {
  vpc_cidr             = "10.10.0.0/16"
  public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway   = false
}

compute_config = {
  instance_type  = "t2.micro"
  instance_count = 1
  app_port       = 3002
  enable_ssm     = true
}

allowed_ingress_ports = [80, 443, 3002]

feature_flags = {
  enable_alb        = true
  enable_cloudfront = false
  enable_monitoring = true
}

extra_tags = {
  Lab     = "12.4"
  Purpose = "variables-locals-outputs"
}
EOF
```

## Staging

```bash id="staging-tfvars"
cat > environments/staging/terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "staging"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"

network_config = {
  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
  enable_nat_gateway   = false
}

compute_config = {
  instance_type  = "t2.micro"
  instance_count = 2
  app_port       = 3002
  enable_ssm     = true
}

allowed_ingress_ports = [80, 443, 3002]

feature_flags = {
  enable_alb        = true
  enable_cloudfront = false
  enable_monitoring = true
}

extra_tags = {
  Lab     = "12.4"
  Purpose = "variables-locals-outputs"
}
EOF
```

## Prod

```bash id="prod-tfvars"
cat > environments/prod/terraform.tfvars.example <<'EOF'
project_name = "devops-masterclass"
environment  = "prod"
aws_region   = "ap-south-1"
owner        = "vivek"
cost_center  = "devops-learning"

network_config = {
  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]
  enable_nat_gateway   = true
}

compute_config = {
  instance_type  = "t3.micro"
  instance_count = 2
  app_port       = 3002
  enable_ssm     = true
}

allowed_ingress_ports = [80, 443]

feature_flags = {
  enable_alb        = true
  enable_cloudfront = true
  enable_monitoring = true
}

extra_tags = {
  Lab     = "12.4"
  Purpose = "variables-locals-outputs"
}
EOF
```

Important:

```text id="tfvars-note"
terraform.tfvars.example is committed.
terraform.tfvars is normally ignored and not committed.
```

---

# 10. Update Locals

Create a strong `locals.tf` template:

```bash id="locals-template"
cat > /tmp/module12_locals.tf <<'EOF'
locals {
  normalized_project = lower(trimspace(var.project_name))
  normalized_env     = lower(trimspace(var.environment))

  name_prefix = "${local.normalized_project}-${local.normalized_env}"

  mandatory_tags = {
    Project     = local.normalized_project
    Environment = local.normalized_env
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Module      = "module-12"
  }

  common_tags = merge(
    local.mandatory_tags,
    var.extra_tags
  )

  sorted_ingress_ports = sort(tolist(var.allowed_ingress_ports))

  public_subnet_map = {
    for index, cidr in var.network_config.public_subnet_cidrs :
    "public-${index + 1}" => {
      name = "${local.name_prefix}-public-${index + 1}"
      cidr = cidr
      tier = "public"
    }
  }

  private_subnet_map = {
    for index, cidr in var.network_config.private_subnet_cidrs :
    "private-${index + 1}" => {
      name = "${local.name_prefix}-private-${index + 1}"
      cidr = cidr
      tier = "private"
    }
  }

  all_subnet_map = merge(local.public_subnet_map, local.private_subnet_map)

  deployment_safety = {
    require_manual_approval = local.normalized_env == "prod" ? true : false
    allow_destroy           = local.normalized_env == "prod" ? false : true
    min_instance_count      = local.normalized_env == "prod" ? 2 : 1
  }

  cloudfront_effective = try(var.feature_flags.enable_cloudfront, false)

  alb_effective = lookup({
    dev     = true
    staging = true
    prod    = true
  }, local.normalized_env, false)
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_locals.tf environments/$env/locals.tf
done
```

Key functions used:

```text id="functions-used"
merge():
  combine maps, later maps win

lookup():
  get value from map with fallback

try():
  return fallback if expression errors

for expression:
  transform list into map
```

HashiCorp documents local values as named expressions that can reference variables, resource attributes, and other expressions to reduce repetition. The `try` and `can` functions catch only dynamic expression errors, and HashiCorp recommends using `try` mainly for simple fallback/normalization expressions rather than hiding broad errors. ([HashiCorp Developer][3])

---

# 11. Update Root Module Main

Create environment contract resources:

```bash id="main-template"
cat > /tmp/module12_main.tf <<'EOF'
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
    project_name = local.normalized_project
    environment  = local.normalized_env
    aws_region   = var.aws_region
    name_prefix  = local.name_prefix
    tags         = local.common_tags
  }
}

resource "terraform_data" "network_contract" {
  input = {
    vpc_name             = "${local.name_prefix}-vpc"
    vpc_cidr             = var.network_config.vpc_cidr
    public_subnets       = local.public_subnet_map
    private_subnets      = local.private_subnet_map
    all_subnets          = local.all_subnet_map
    enable_nat_gateway   = var.network_config.enable_nat_gateway
    sorted_ingress_ports = local.sorted_ingress_ports
  }
}

resource "terraform_data" "compute_contract" {
  input = {
    instance_type        = var.compute_config.instance_type
    instance_count       = var.compute_config.instance_count
    app_port             = var.compute_config.app_port
    enable_ssm           = var.compute_config.enable_ssm
    min_instance_count   = local.deployment_safety.min_instance_count
    allowed_ports        = local.sorted_ingress_ports
    production_safe      = local.deployment_safety
  }
}

resource "terraform_data" "feature_contract" {
  input = {
    enable_alb        = var.feature_flags.enable_alb
    enable_cloudfront = local.cloudfront_effective
    enable_monitoring = var.feature_flags.enable_monitoring
    alb_effective     = local.alb_effective
  }
}

resource "terraform_data" "sensitive_contract" {
  input = {
    token_present = length(var.sensitive_demo_token) > 0
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_main.tf environments/$env/main.tf
done
```

---

# 12. Update Outputs

Create output template:

```bash id="outputs-template"
cat > /tmp/module12_outputs.tf <<'EOF'
output "environment_contract" {
  description = "Environment metadata and tagging contract."
  value       = terraform_data.environment_contract.output
}

output "network_contract" {
  description = "Network configuration contract derived from variables and locals."
  value       = terraform_data.network_contract.output
}

output "compute_contract" {
  description = "Compute configuration contract derived from variables and locals."
  value       = terraform_data.compute_contract.output
}

output "feature_contract" {
  description = "Feature flag contract."
  value       = terraform_data.feature_contract.output
}

output "name_prefix" {
  description = "Common naming prefix."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Common tags applied across resources."
  value       = local.common_tags
}

output "subnet_names" {
  description = "Derived subnet names from public and private subnet maps."
  value       = [for subnet in values(local.all_subnet_map) : subnet.name]
}

output "sensitive_token_present" {
  description = "Whether the sensitive demo token is present. Does not expose the token."
  value       = terraform_data.sensitive_contract.output.token_present
}

output "sensitive_demo_token_echo" {
  description = "Sensitive demo output. This intentionally demonstrates sensitive output handling."
  value       = var.sensitive_demo_token
  sensitive   = true
}

output "networking_contract" {
  description = "Networking module contract."
  value       = module.networking.contract
}

output "compute_module_contract" {
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
EOF

for env in dev staging prod; do
  cp /tmp/module12_outputs.tf environments/$env/outputs.tf
done
```

Output values are returned by `terraform output` and can act as contracts for other systems. Terraform requires sensitive root outputs to be explicitly marked when exposing sensitive values. ([HashiCorp Developer][4])

---

# 13. Update Child Module Variables for Validation

Each child module currently accepts `name_prefix` and `common_tags`. Strengthen the variable contracts.

```bash id="module-var-template"
cat > /tmp/module_variables_contract.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix from the environment root module."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name_prefix) >= 5 && can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must be at least 5 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "common_tags" {
  description = "Common tags from the environment root module."
  type        = map(string)
  nullable    = false

  validation {
    condition = alltrue([
      contains(keys(var.common_tags), "Project"),
      contains(keys(var.common_tags), "Environment"),
      contains(keys(var.common_tags), "ManagedBy")
    ])
    error_message = "common_tags must include Project, Environment, and ManagedBy."
  }
}
EOF

for module in networking compute load-balancer storage cdn iam; do
  cp /tmp/module_variables_contract.tf modules/$module/variables.tf
done
```

---

# 14. Create tfvars Strategy Note

```bash id="tfvars-note"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/notes/tfvars-strategy.md
```

Paste:

````markdown id="tfvars-note-content"
# Terraform tfvars Strategy

## Commit

```text
terraform.tfvars.example
dev.tfvars.example
prod.tfvars.example
````

## Usually do not commit

```text
terraform.tfvars
*.auto.tfvars
secret.auto.tfvars
```

## Recommended course pattern

Use:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit local values.

## CI/CD pattern

Use:

```bash
terraform plan -var-file=environment.tfvars
```

or CI variables:

```bash
export TF_VAR_environment=dev
export TF_VAR_owner=vivek
```

## Precedence summary

Common CLI precedence from lowest to highest:

1. variable default
2. TF_VAR_ environment variable
3. terraform.tfvars
4. terraform.tfvars.json
5. *.auto.tfvars / *.auto.tfvars.json
6. -var and -var-file command line options

## Golden rule

Variable declarations define schema.
Variable value files provide data.

````

---

# 15. Dev Environment Variable Lab

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
````

Because `environment`, `network_config`, and `compute_config` have no defaults, use the example file explicitly:

```bash id="dev-init"
terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

Format and validate:

```bash id="dev-fmt-validate"
terraform fmt -recursive
terraform validate
```

Plan using tfvars example:

```bash id="dev-plan"
terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-4-dev
```

Apply:

```bash id="dev-apply"
terraform apply tfplan-12-4-dev
```

Show outputs:

```bash id="dev-outputs"
terraform output name_prefix
terraform output network_contract
terraform output compute_contract
terraform output subnet_names
terraform output sensitive_token_present
```

Sensitive output behavior:

```bash id="sensitive-output"
terraform output sensitive_demo_token_echo
```

Expected:

```text id="sensitive-expected"
Terraform will still allow querying a specific sensitive output.
Be careful where this is run or logged.
```

Show JSON outputs:

```bash id="json-output"
terraform output -json > /tmp/dev-outputs.json

jq '.name_prefix.value' /tmp/dev-outputs.json
jq '.network_contract.value.vpc_cidr' /tmp/dev-outputs.json

rm -f /tmp/dev-outputs.json
```

---

# 16. Variable Override Lab

Override owner with CLI:

```bash id="override-owner"
terraform plan \
  -var-file=terraform.tfvars.example \
  -var="owner=cli-owner" \
  -out=tfplan-owner-override

terraform show tfplan-owner-override
```

Notice:

```text id="override-result"
owner in tags changes to cli-owner.
```

Discard:

```bash id="discard-override"
rm -f tfplan-owner-override
```

Use `TF_VAR_`:

```bash id="tf-var-owner"
export TF_VAR_owner="env-var-owner"

terraform plan -var-file=terraform.tfvars.example -out=tfplan-env-var

terraform show tfplan-env-var

unset TF_VAR_owner
rm -f tfplan-env-var
```

Important:

```text id="precedence-reminder"
If -var-file also supplies owner, command-line -var-file can override TF_VAR_owner depending on source precedence.
```

---

# 17. Validation Failure Lab

Try invalid environment:

```bash id="invalid-env"
terraform plan \
  -var-file=terraform.tfvars.example \
  -var="environment=production" \
  -out=tfplan-invalid-env
```

Expected:

```text id="invalid-env-expected"
Error: environment must be dev, staging, or prod.
```

Try invalid port:

```bash id="invalid-port"
terraform plan \
  -var-file=terraform.tfvars.example \
  -var='allowed_ingress_ports=[80,443,70000]' \
  -out=tfplan-invalid-port
```

Expected:

```text id="invalid-port-expected"
Error: All ingress ports must be between 1 and 65535.
```

Try invalid project name:

```bash id="invalid-project"
terraform plan \
  -var-file=terraform.tfvars.example \
  -var="project_name=Bad_Project_Name" \
  -out=tfplan-invalid-project
```

Expected:

```text id="invalid-project-expected"
Error: project_name must use lowercase letters, numbers, and hyphens only.
```

Cleanup failed plans:

```bash id="cleanup-invalid-plans"
rm -f tfplan-invalid-*
```

---

# 18. for Expressions Lab

You already created this local:

```hcl id="for-expression-local"
public_subnet_map = {
  for index, cidr in var.network_config.public_subnet_cidrs :
  "public-${index + 1}" => {
    name = "${local.name_prefix}-public-${index + 1}"
    cidr = cidr
    tier = "public"
  }
}
```

Meaning:

```text id="for-expression-meaning"
Input:
  ["10.10.1.0/24", "10.10.2.0/24"]

Output:
  {
    public-1 = {
      name = "devops-masterclass-dev-public-1"
      cidr = "10.10.1.0/24"
      tier = "public"
    }
    public-2 = {
      name = "devops-masterclass-dev-public-2"
      cidr = "10.10.2.0/24"
      tier = "public"
    }
  }
```

Check:

```bash id="check-for-expression"
terraform output network_contract
```

---

# 19. Create Variable Matrix Script

```bash id="matrix-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/variable-matrix.sh
```

Paste:

```bash id="matrix-content"
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

echo "===== Terraform Variable Matrix ====="
echo "Environment: $ENVIRONMENT"

echo
echo "Variable declarations:"
grep -n '^variable ' variables.tf || true

echo
echo "Local values:"
grep -n '^  [a-zA-Z0-9_]* =' locals.tf || true

echo
echo "Outputs:"
grep -n '^output ' outputs.tf || true

echo
echo "tfvars example:"
cat terraform.tfvars.example

echo
echo "Derived output preview:"
terraform output environment_contract || true
terraform output name_prefix || true
terraform output subnet_names || true
```

Make executable:

```bash id="chmod-matrix"
chmod +x 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/variable-matrix.sh
```

Run:

```bash id="run-matrix"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/variable-matrix.sh
```

---

# 20. Create Multi-Environment Contract Plan Script

```bash id="contract-plan-script"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/plan-env-contracts.sh
```

Paste:

```bash id="contract-plan-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="12-terraform-ansible-iac"

echo "===== Plan Environment Contracts ====="

for env in dev staging prod; do
  echo
  echo "===== $env ====="

  pushd "$BASE/environments/$env" >/dev/null

  terraform init -backend=false >/dev/null
  terraform fmt -check -recursive
  terraform validate

  terraform plan \
    -var-file=terraform.tfvars.example \
    -out="tfplan-$env-contract" >/dev/null

  terraform show -no-color "tfplan-$env-contract" > "../../12.4-terraform-variables-locals-outputs/reports/$env-plan.txt"

  rm -f "tfplan-$env-contract"

  popd >/dev/null
done

echo
echo "Plans saved to:"
find "$BASE/12.4-terraform-variables-locals-outputs/reports" -name "*-plan.txt" -print | sort
```

Make executable:

```bash id="chmod-contract-plan"
chmod +x 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/plan-env-contracts.sh
```

Run:

```bash id="run-contract-plan"
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/plan-env-contracts.sh
```

---

# 21. Create Output Export Script for Future Ansible

Later, Ansible will consume Terraform outputs to build inventory.

Create:

```bash id="output-export-script"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/export-terraform-outputs.sh
```

Paste:

```bash id="output-export-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"
OUT_DIR="$BASE/12.4-terraform-variables-locals-outputs/reports"

mkdir -p "$OUT_DIR"

cd "$ENV_DIR"

echo "===== Export Terraform Outputs ====="
echo "Environment: $ENVIRONMENT"

terraform output -json > "../../12.4-terraform-variables-locals-outputs/reports/$ENVIRONMENT-outputs.json"

echo "Saved:"
echo "$OUT_DIR/$ENVIRONMENT-outputs.json"

echo
echo "Preview:"
jq 'keys' "../../12.4-terraform-variables-locals-outputs/reports/$ENVIRONMENT-outputs.json"
```

Make executable:

```bash id="chmod-output-export"
chmod +x 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/export-terraform-outputs.sh
```

Run:

```bash id="run-output-export"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/export-terraform-outputs.sh
```

---

# 22. Create Validation Script

```bash id="validation-script"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/validate-lesson-12-4.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.4 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.4-terraform-variables-locals-outputs"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/examples"

test -f "$LESSON/notes/variables-locals-outputs-mental-model.md"
test -f "$LESSON/notes/never-confuse-variables-locals-outputs.md"
test -f "$LESSON/notes/input-variable-types.md"
test -f "$LESSON/notes/tfvars-strategy.md"

test -x "$LESSON/scripts/variable-matrix.sh"
test -x "$LESSON/scripts/plan-env-contracts.sh"
test -x "$LESSON/scripts/export-terraform-outputs.sh"

terraform version >/dev/null

for env in dev staging prod; do
  echo
  echo "===== Validating $env ====="

  ENV_DIR="$BASE/environments/$env"

  test -f "$ENV_DIR/variables.tf"
  test -f "$ENV_DIR/locals.tf"
  test -f "$ENV_DIR/outputs.tf"
  test -f "$ENV_DIR/terraform.tfvars.example"

  pushd "$ENV_DIR" >/dev/null

  terraform init -backend=false >/dev/null
  terraform fmt -check -recursive
  terraform validate

  terraform plan \
    -var-file=terraform.tfvars.example \
    -out=tfplan-validation >/dev/null

  terraform show -no-color tfplan-validation >/dev/null
  rm -f tfplan-validation

  popd >/dev/null
done

echo
echo "Lesson 12.4 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/validate-lesson-12-4.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/validate-lesson-12-4.sh
```

---

# 23. Create Cleanup Script

```bash id="cleanup-script"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/cleanup-lesson-12-4.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.4 ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

rm -f "$BASE/12.4-terraform-variables-locals-outputs/reports/"*-outputs.json

echo "Lesson 12.4 local plan/output artifacts cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/cleanup-lesson-12-4.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/cleanup-lesson-12-4.sh
```

---

# 24. Variables, Locals, Outputs Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/runbooks/variables-locals-outputs-runbook.md
```

Paste:

````markdown id="runbook-content"
# Terraform Variables, Locals, and Outputs Runbook

## Variables

Use variables for external inputs.

```hcl
variable "environment" {
  type = string
}
````

## Locals

Use locals for calculated internal values.

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

## Outputs

Use outputs for values other systems need.

```hcl
output "name_prefix" {
  value = local.name_prefix
}
```

## Safe workflow

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars.example -out=tfplan
terraform show tfplan
terraform apply tfplan
terraform output
```

## Debug input values

```bash
terraform plan -var-file=terraform.tfvars.example
terraform plan -var="environment=dev"
TF_VAR_owner=vivek terraform plan -var-file=terraform.tfvars.example
```

## Validate outputs

```bash
terraform output
terraform output -json
terraform output name_prefix
```

## Common errors

### No value for required variable

Fix:

* add default
* pass `-var`
* pass `-var-file`
* set `TF_VAR_name`

### Invalid value for variable

Fix:

* read validation error
* update value
* update validation only if requirement changed

### Sensitive output error

Fix:

```hcl
output "secret" {
  value     = var.secret
  sensitive = true
}
```

### Wrong type

Fix:

* check object/list/map syntax
* check quotes
* check number vs string

## Golden rule

Use variables to define the input contract.
Use locals to normalize the implementation.
Use outputs to define the handoff contract.

````id="runbook-end"

---

# 25. Production Naming and Tagging Runbook

```bash id="tag-runbook"
nano 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/runbooks/production-naming-tagging-runbook.md
````

Paste:

````markdown id="tag-runbook-content"
# Production Naming and Tagging Runbook

## Naming pattern

```text
<project>-<environment>-<component>-<purpose>
````

Examples:

```text
devops-masterclass-dev-vpc
devops-masterclass-prod-alb
devops-masterclass-staging-api-sg
```

## Required tags

```hcl
Project
Environment
Owner
CostCenter
ManagedBy
Module
```

## Terraform local pattern

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  mandatory_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }

  common_tags = merge(local.mandatory_tags, var.extra_tags)
}
```

## Why this matters

Tags help with:

* ownership
* cost allocation
* incident response
* cleanup
* security review
* audit
* automation

## Production rules

* Every resource should have tags where supported.
* Never use random inconsistent names.
* Include environment in names.
* Include owner and cost center tags.
* Do not put secrets in tags.

````

---

# 26. Common Mistakes and Fixes

## Mistake 1 — Using `any` everywhere

Bad:

```hcl id="bad-any"
variable "network_config" {
  type = any
}
````

Good:

```hcl id="good-object"
variable "network_config" {
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    enable_nat_gateway   = bool
  })
}
```

---

## Mistake 2 — Hardcoding environment inside modules

Bad child module:

```hcl id="bad-hardcode"
name = "dev-vpc"
```

Good child module:

```hcl id="good-input"
name = "${var.name_prefix}-vpc"
```

---

## Mistake 3 — Using locals as hidden variables

Bad:

```hcl id="bad-local-hidden"
locals {
  instance_type = "t3.micro"
}
```

Better:

```hcl id="good-variable-input"
variable "compute_config" {
  type = object({
    instance_type = string
  })
}
```

Use locals for derived values, not important user choices.

---

## Mistake 4 — Outputting secrets casually

Bad:

```hcl id="bad-secret-output"
output "token" {
  value = var.sensitive_demo_token
}
```

Better:

```hcl id="good-secret-output"
output "token" {
  value     = var.sensitive_demo_token
  sensitive = true
}
```

Best:

```text id="best-secret-output"
Do not output secrets unless another system truly needs them.
```

---

## Mistake 5 — Assuming sensitive means encrypted

Wrong:

```text id="wrong-sensitive"
sensitive = true makes the value safe everywhere.
```

Correct:

```text id="correct-sensitive"
sensitive = true hides normal CLI display, but state protection is still required.
```

---

## Mistake 6 — Forgetting variable precedence

A value from `-var` can override what you thought was coming from `terraform.tfvars`.

Always check your exact command.

---

# 27. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is an input variable?
What is a local value?
What is an output value?
What is the difference between variables.tf and terraform.tfvars?
Which tfvars files are auto-loaded?
What does TF_VAR_name do?
What is variable precedence?
What is a validation block?
What does nullable=false do?
What does sensitive=true do?
Does sensitive=true remove values from state?
When should you use object types?
When should you use list vs set vs map?
What does merge() do?
What does lookup() do?
What does try() do?
What does can() do?
Why are outputs module contracts?
Why can changing outputs break CI/CD or Ansible?
```

Strong interview answer:

```text id="interview-answer"
In Terraform, variables define the input contract of a module, locals define internal calculated values, and outputs define the values exposed after evaluation. I use strongly typed variables with validation blocks to catch mistakes early, especially for environments, CIDR blocks, ports, feature flags, and production safety rules.

I use locals for naming conventions, merged tags, normalized values, subnet maps, and derived environment behavior. Outputs act as stable contracts for humans, CI/CD, other Terraform modules, and tools like Ansible. I avoid outputting secrets unless absolutely necessary, and if I must expose a sensitive value, I mark it sensitive while still protecting the state backend because sensitive values can still exist in state.

For variable values, I understand the difference between declarations in variables.tf and values in tfvars files, TF_VAR_ environment variables, and CLI overrides. In production, I prefer explicit tfvars files, clear naming/tagging contracts, validation, and reviewed plans.
```

Resume bullet:

```text id="resume-bullet"
Built production-grade Terraform variable, local, and output contracts using strong type constraints, object inputs, validation blocks, nullable and sensitive settings, tfvars examples, TF_VAR override testing, naming/tagging locals, for expressions, merge/lookup/try/can patterns, output exports for future Ansible integration, multi-environment contract planning, and validation/runbook automation.
```

---

# 28. Commit Lesson 12.4

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/cleanup-lesson-12-4.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs/scripts/validate-lesson-12-4.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.4-terraform-variables-locals-outputs -maxdepth 4 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Terraform variables locals outputs contracts"

git push
```

---

# 29. Next Lesson

```text id="next-lesson"
12.5 — Terraform Modules
```

We will go deep into:

```text id="next-topics"
root module vs child module
module inputs
module outputs
module composition
module source paths
module versioning
provider passing
module contracts
when to create modules
when not to create modules
module anti-patterns
networking module design
compute module design
security group module design
module validation
module documentation
module testing mindset
module refactoring and state mv
production module runbooks
```

[1]: https://developer.hashicorp.com/terraform/language/values/variables?utm_source=chatgpt.com "Use input variables to add module arguments | Terraform | HashiCorp Developer"
[2]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables?utm_source=chatgpt.com "Protect sensitive input variables | Terraform | HashiCorp Developer"
[3]: https://developer.hashicorp.com/terraform/language/values/locals?utm_source=chatgpt.com "Use locals to reuse expressions | Terraform | HashiCorp Developer"
[4]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/outputs?utm_source=chatgpt.com "Output data from Terraform | Terraform | HashiCorp Developer"
