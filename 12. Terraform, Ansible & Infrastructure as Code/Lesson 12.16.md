# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.16 — Final IaC Capstone

You have now built the full IaC stack:

```text id="recap"
12.1   IaC mental model
12.2   Terraform project structure
12.3   remote state backend
12.4   variables, locals, outputs
12.5   modules
12.6   workspaces
12.7   AWS VPC
12.8   EC2 and security groups
12.9   ALB and target groups
12.10  S3 and CloudFront
12.11  IAM troubleshooting
12.12  Ansible inventory and roles
12.13  Terraform + Ansible integration
12.14  CI/CD for IaC
12.15  policy checks
```

Lesson 12.16 is the **final capstone**: package everything into a production-style portfolio project with validation, reports, runbooks, cleanup, resume summary, and interview story.

Terraform’s standard automation flow is still the foundation here: create a plan, review it, apply the reviewed plan, then export outputs and validate the resulting infrastructure. Terraform’s docs describe `terraform apply` as executing actions proposed in a Terraform plan, and `terraform show -json` can expose a machine-readable plan for tools and policy gates. ([HashiCorp Developer][1])

---

# 1. Capstone Goal

Build and document a complete production-oriented AWS IaC platform:

```text id="goal"
Terraform provisions:
  VPC
  public/private subnets
  Internet Gateway
  route tables
  security groups
  IAM role and instance profile
  EC2
  ALB
  target group
  S3 private assets bucket
  CloudFront distribution
  CloudFront OAC
  S3 bucket policy

Ansible configures and validates:
  inventories
  group_vars
  common role
  nginx_hardening role
  app_runtime role
  ALB and CloudFront health checks

CI/CD validates:
  Terraform fmt
  Terraform validate
  Terraform plan
  policy checks
  Ansible sanity
  protected apply
  drift detection

Policy gate blocks:
  public SSH
  public database ports
  EC2 without IMDSv2
  S3 without public access block
  S3 without encryption
  CloudFront without HTTPS redirect
  CloudFront S3 origin without OAC
```

Final architecture:

```text id="architecture"
User
  ↓ HTTPS
CloudFront
  ├── /assets/* → private S3 bucket through OAC
  └── default  → ALB origin
                    ↓
                  Target Group
                    ↓
                  EC2 nginx/app runtime

Terraform remote state:
  S3 backend
  S3 lockfile

Ansible:
  Terraform output → inventory → roles → validation

CI/CD:
  PR check → plan artifact → policy gate → approval → apply → validation
```

---

# 2. What This Capstone Proves

By the end, you can honestly say:

```text id="proof"
I can design, provision, configure, validate, secure, troubleshoot, and document a production-style AWS infrastructure stack using Terraform, Ansible, CI/CD, and policy-as-code.
```

This is no longer just “I know Terraform.”

This is:

```text id="real-skill"
Infrastructure engineering
Cloud architecture
Automation
Security guardrails
Deployment workflow
Operational validation
Cost cleanup
Production troubleshooting
```

---

# 3. Create Capstone Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.16-final-iac-capstone/{docs,scripts,runbooks,reports,evidence,diagrams,resume,interview,checklists}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.16-final-iac-capstone
```

---

# 4. Create Capstone Architecture Document

````bash id="architecture-doc"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/docs/capstone-architecture.md <<'EOF'
# Final IaC Capstone Architecture

## Project

DevOps Masterclass — Terraform, Ansible, and IaC Capstone

## Region

Primary AWS region:

```text
ap-south-1
````

CloudFront is a global AWS service.

CloudFront custom-domain ACM certificates must be created in:

```text
us-east-1
```

## Architecture

```text
Viewer
  ↓
CloudFront Distribution
  ├── /assets/* → S3 private assets bucket through Origin Access Control
  └── default  → Application Load Balancer
                    ↓
                  Target Group
                    ↓
                  EC2 instance running nginx/app runtime
```

## Terraform ownership

Terraform owns:

* VPC
* subnets
* route tables
* Internet Gateway
* security groups
* IAM role
* IAM instance profile
* EC2
* ALB
* target group
* listener
* S3 bucket
* CloudFront distribution
* bucket policy
* OAC
* outputs

## Ansible ownership

Ansible owns:

* operating system baseline
* common packages
* nginx configuration
* app runtime directory
* metadata files
* server validation
* cloud endpoint validation

## CI/CD ownership

CI/CD owns:

* Terraform fmt
* Terraform validate
* Terraform plan
* policy check
* plan artifacts
* manual approval
* Terraform apply
* Ansible validation
* drift detection

## Policy-as-Code ownership

Policy checks block:

* public SSH
* public database ports
* EC2 without IMDSv2
* S3 without public access block
* S3 without encryption
* CloudFront without HTTPS redirect
* CloudFront S3 origin without OAC
* unapproved regions

## Security posture

* S3 bucket is private.
* CloudFront accesses S3 through OAC.
* EC2 uses IMDSv2.
* EC2 access prefers SSM over SSH.
* ALB fronts EC2.
* Terraform caller role is separate from EC2 runtime role.
* iam:PassRole is scoped.
* GitHub Actions should use OIDC instead of long-lived AWS keys.

## Cost posture

Billable resources include:

* EC2
* public IPv4
* ALB
* CloudFront usage
* S3 storage/requests

Destroy dev resources when stopping.
EOF

````

---

# 5. Create Mermaid Diagram

```bash id="mermaid"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/diagrams/iac-capstone-architecture.mmd <<'EOF'
flowchart TD
    U[User / Browser] -->|HTTPS| CF[CloudFront Distribution]

    CF -->|/assets/*| S3[(Private S3 Assets Bucket)]
    CF -->|Default behavior| ALB[Application Load Balancer]

    ALB --> TG[Target Group]
    TG --> EC2[EC2 Instance - nginx/app runtime]

    TF[Terraform] --> VPC[VPC / Subnets / Routes]
    TF --> IAM[IAM Role + Instance Profile]
    TF --> EC2
    TF --> ALB
    TF --> S3
    TF --> CF

    ANS[Ansible] -->|Inventory from Terraform outputs| EC2
    ANS -->|Endpoint validation| ALB
    ANS -->|Endpoint validation| CF

    CI[CI/CD Pipeline] --> TF
    CI --> ANS
    POL[Policy Gate] --> CI

    S3 -. OAC bucket policy .- CF
EOF
````

Optional render later:

```bash id="render-mermaid"
# If mermaid-cli is installed:
mmdc \
  -i 12-terraform-ansible-iac/12.16-final-iac-capstone/diagrams/iac-capstone-architecture.mmd \
  -o 12-terraform-ansible-iac/12.16-final-iac-capstone/diagrams/iac-capstone-architecture.png
```

---

# 6. Create Capstone Context Script

```bash id="context-script"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-context.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
ANSIBLE_DIR="$BASE/ansible"

echo "===== Final IaC Capstone Context ====="

echo
echo "AWS caller:"
aws sts get-caller-identity

echo
echo "AWS config:"
aws configure list

echo
echo "Environment:"
echo "ENVIRONMENT=$ENVIRONMENT"
echo "AWS_REGION=${AWS_REGION:-unset}"
echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-unset}"

echo
echo "Terraform:"
terraform version
cd "$TF_DIR"
echo "Terraform dir: $PWD"
echo "Workspace: $(terraform workspace show 2>/dev/null || echo not-initialized)"
terraform output name_prefix 2>/dev/null || true
terraform output alb_dns_name 2>/dev/null || true
terraform output cloudfront_distribution_domain_name 2>/dev/null || true
cd - >/dev/null

echo
echo "Ansible:"
cd "$ANSIBLE_DIR"
ansible --version | head -n 1
ansible-config dump --only-changed || true

echo
echo "Available inventories:"
find inventories -maxdepth 3 -type f | sort

echo
echo "Git:"
cd ../../
git status --short
git branch --show-current
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-context.sh
```

Run:

```bash id="run-context"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-context.sh
```

---

# 7. Create Capstone Repo Audit Script

This confirms your capstone repo has all expected sections.

```bash id="repo-audit"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-repo-audit.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Final IaC Capstone Repo Audit ====="

BASE="12-terraform-ansible-iac"

required_paths=(
  "$BASE/environments/dev"
  "$BASE/environments/staging"
  "$BASE/environments/prod"
  "$BASE/modules/networking"
  "$BASE/modules/security-group"
  "$BASE/modules/compute"
  "$BASE/modules/load-balancer"
  "$BASE/modules/storage"
  "$BASE/modules/cdn"
  "$BASE/modules/iam"
  "$BASE/global/backend"
  "$BASE/ansible"
  "$BASE/policy"
  "$BASE/ci/scripts"
  "$BASE/12.7-aws-vpc-infrastructure"
  "$BASE/12.8-ec2-security-groups"
  "$BASE/12.9-alb-target-groups"
  "$BASE/12.10-s3-cloudfront"
  "$BASE/12.11-iam-troubleshooting"
  "$BASE/12.12-ansible-inventory-roles"
  "$BASE/12.13-terraform-ansible-integration"
  "$BASE/12.14-cicd-for-iac"
  "$BASE/12.15-policy-checks"
  "$BASE/12.16-final-iac-capstone"
  ".github/workflows"
)

for path in "${required_paths[@]}"; do
  test -e "$path" || {
    echo "Missing required path: $path"
    exit 1
  }
done

required_files=(
  "$BASE/Makefile"
  "$BASE/policy/iac-policy-rules.yml"
  "$BASE/policy/terraform_plan_policy_check.py"
  "$BASE/ansible/ansible.cfg"
  "$BASE/ansible/playbooks/local-site.yml"
  "$BASE/ansible/playbooks/aws-site.yml"
  "$BASE/ansible/playbooks/validate-cloud-stack.yml"
  ".github/workflows/iac-pr-check.yml"
  ".github/workflows/iac-apply-dev.yml"
  ".github/workflows/iac-drift-detect.yml"
  ".github/workflows/iac-destroy-plan-dev.yml"
)

for file in "${required_files[@]}"; do
  test -f "$file" || {
    echo "Missing required file: $file"
    exit 1
  }
done

echo
echo "Checking Terraform module files..."
for module in networking security-group compute load-balancer storage cdn iam; do
  for file in versions.tf variables.tf main.tf outputs.tf README.md; do
    test -f "$BASE/modules/$module/$file" || {
      echo "Missing $BASE/modules/$module/$file"
      exit 1
    }
  done
done

echo
echo "Checking Ansible roles..."
for role in common nginx_hardening app_runtime; do
  test -f "$BASE/ansible/roles/$role/tasks/main.yml"
  test -f "$BASE/ansible/roles/$role/defaults/main.yml"
  test -f "$BASE/ansible/roles/$role/meta/main.yml"
done

echo
echo "Repo audit passed."
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-repo-audit.sh
```

Run:

```bash id="run-repo-audit"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-repo-audit.sh
```

---

# 8. Create Full Local Validation Script

This validates code without applying AWS changes.

```bash id="local-validation"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-local-validate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Final IaC Capstone Local Validation ====="

BASE="12-terraform-ansible-iac"

"$BASE/12.16-final-iac-capstone/scripts/capstone-repo-audit.sh"

echo
echo "Terraform fmt:"
terraform fmt -recursive -check "$BASE"

echo
echo "Terraform validate for environments:"
for env in dev staging prod; do
  echo "---- $env ----"
  pushd "$BASE/environments/$env" >/dev/null
  terraform init -backend=false >/dev/null
  terraform validate
  popd >/dev/null
done

echo
echo "Ansible sanity:"
pushd "$BASE/ansible" >/dev/null
./scripts/ansible-sanity.sh
popd >/dev/null

echo
echo "Policy script compile:"
python3 -m py_compile "$BASE/policy/terraform_plan_policy_check.py"

echo
echo "Shell script syntax checks:"
find "$BASE" -path "*/scripts/*.sh" -type f -print0 | while IFS= read -r -d '' script; do
  bash -n "$script"
done

echo
echo "GitHub workflow audit:"
"$BASE/12.14-cicd-for-iac/scripts/audit-github-actions-iac.sh"

echo
echo "Final IaC capstone local validation passed."
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-local-validate.sh
```

Run:

```bash id="run-local-validate"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-local-validate.sh
```

---

# 9. Create Capstone Plan + Policy Script

This runs Terraform plan and policy gate together.

```bash id="plan-policy"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-plan-policy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
PLAN_NAME="${PLAN_NAME:-tfplan-capstone}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT"
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="$BASE/12.16-final-iac-capstone/reports"
POLICY_REPORT_DIR="$BASE/12.15-policy-checks/reports"

mkdir -p "$REPORT_DIR" "$POLICY_REPORT_DIR"

echo "===== Final IaC Capstone Plan + Policy ====="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -recursive
terraform validate

terraform plan \
  -var-file=terraform.tfvars.example \
  -out="$PLAN_NAME"

terraform show -no-color "$PLAN_NAME" > "../../12.16-final-iac-capstone/reports/$ENVIRONMENT-capstone-plan.txt"
terraform show -json "$PLAN_NAME" > "../../12.16-final-iac-capstone/reports/$ENVIRONMENT-capstone-plan.json"

cd - >/dev/null

python3 "$BASE/policy/terraform_plan_policy_check.py" \
  --plan-json "$REPORT_DIR/$ENVIRONMENT-capstone-plan.json" \
  --rules "$BASE/policy/iac-policy-rules.yml" \
  --region "$AWS_REGION" \
  --report-json "$POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.json" \
  --report-md "$POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.md"

echo
echo "Plan file:"
echo "$TF_DIR/$PLAN_NAME"
echo
echo "Plan report:"
echo "$REPORT_DIR/$ENVIRONMENT-capstone-plan.txt"
echo
echo "Policy report:"
echo "$POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.md"
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-plan-policy.sh
```

Run:

```bash id="run-plan-policy"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-plan-policy.sh
```

---

# 10. Create Capstone Apply + Validate Script

This applies the saved capstone plan, exports outputs, generates Ansible inventory, and validates ALB/CloudFront.

```bash id="apply-validate"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-apply-validate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
CONNECTION_MODE="${CONNECTION_MODE:-ssm}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
PLAN_NAME="${PLAN_NAME:-tfplan-capstone}"

if [ "$ENVIRONMENT" != "dev" ]; then
  echo "For this course, capstone apply is limited to dev."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/dev"
REPORT_DIR="$BASE/12.16-final-iac-capstone/reports"

echo "===== Final IaC Capstone Apply + Validate ====="
echo "Environment: $ENVIRONMENT"
echo "Connection mode: $CONNECTION_MODE"
echo "Region: $AWS_REGION"

aws sts get-caller-identity

cd "$TF_DIR"

test -f "$PLAN_NAME" || {
  echo "Missing saved plan: $TF_DIR/$PLAN_NAME"
  echo "Run capstone-plan-policy.sh first."
  exit 1
}

echo
echo "Applying saved Terraform plan..."
terraform apply "$PLAN_NAME"
rm -f "$PLAN_NAME"

terraform output -json > "../../12.16-final-iac-capstone/reports/dev-terraform-outputs.json"

cd - >/dev/null

echo
echo "Running post-apply Ansible handoff..."
ENVIRONMENT=dev CONNECTION_MODE="$CONNECTION_MODE" AWS_REGION="$AWS_REGION" \
"./$BASE/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh"

echo
echo "Running AWS validation scripts..."
ENVIRONMENT=dev "$BASE/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh"
ENVIRONMENT=dev "$BASE/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh"
ENVIRONMENT=dev "$BASE/12.9-alb-target-groups/scripts/validate-alb-aws.sh"
ENVIRONMENT=dev "$BASE/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh"

echo
echo "Capstone apply and validation completed."
echo "Reports directory: $REPORT_DIR"
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-apply-validate.sh
```

Run only after reviewing the plan and policy report:

```bash id="run-apply-validate"
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-apply-validate.sh
```

The Ansible portion uses inventories and roles you already built. Ansible roles provide reusable automation structure, and inventories define the managed nodes and their variables. ([Ansible][2])

---

# 11. Create Evidence Report Script

This creates a final Markdown evidence pack.

````bash id="evidence-script"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-evidence-report.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
ANSIBLE_DIR="$BASE/ansible"
OUT="$BASE/12.16-final-iac-capstone/evidence/$ENVIRONMENT-capstone-evidence.md"

mkdir -p "$(dirname "$OUT")"

echo "===== Final IaC Capstone Evidence Report ====="
echo "Environment: $ENVIRONMENT"

CALLER_JSON="$(aws sts get-caller-identity --output json)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_BRANCH="$(git branch --show-current)"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

{
  echo "# Final IaC Capstone Evidence — $ENVIRONMENT"
  echo
  echo "Generated: $NOW"
  echo
  echo "## Git"
  echo
  echo "- Branch: \`$GIT_BRANCH\`"
  echo "- Commit: \`$GIT_COMMIT\`"
  echo
  echo "## AWS Caller"
  echo
  echo '```json'
  echo "$CALLER_JSON" | jq .
  echo '```'
  echo
  echo "## Terraform Outputs"
  echo
  pushd "$TF_DIR" >/dev/null
  echo '```json'
  terraform output -json 2>/dev/null | jq . || true
  echo '```'
  popd >/dev/null
  echo
  echo "## Ansible Inventory"
  echo
  if [ -f "$ANSIBLE_DIR/inventories/$ENVIRONMENT/hosts.yml" ]; then
    echo '```yaml'
    cat "$ANSIBLE_DIR/inventories/$ENVIRONMENT/hosts.yml"
    echo '```'
  else
    echo "No generated inventory found."
  fi
  echo
  echo "## Policy Report"
  echo
  if [ -f "$BASE/12.15-policy-checks/reports/$ENVIRONMENT-policy-report.md" ]; then
    cat "$BASE/12.15-policy-checks/reports/$ENVIRONMENT-policy-report.md"
  else
    echo "No policy report found."
  fi
  echo
  echo "## Validation Commands"
  echo
  echo '```bash'
  echo "ENVIRONMENT=$ENVIRONMENT ./12-terraform-ansible-iac/12.7-aws-vpc-infrastructure/scripts/validate-vpc-aws.sh"
  echo "ENVIRONMENT=$ENVIRONMENT ./12-terraform-ansible-iac/12.8-ec2-security-groups/scripts/validate-ec2-aws.sh"
  echo "ENVIRONMENT=$ENVIRONMENT ./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/validate-alb-aws.sh"
  echo "ENVIRONMENT=$ENVIRONMENT ./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh"
  echo '```'
} > "$OUT"

echo "Evidence report written to:"
echo "$OUT"
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-evidence-report.sh
````

Run after validation:

```bash id="run-evidence"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-evidence-report.sh

cat 12-terraform-ansible-iac/12.16-final-iac-capstone/evidence/dev-capstone-evidence.md
```

---

# 12. Create Cost Check Script

```bash id="cost-script"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Final IaC Capstone Cost Check ====="

echo
echo "EC2 running/stopped instances:"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table || true

echo
echo "ALBs:"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Type:Type,Scheme:Scheme}' \
  --output table || true

echo
echo "CloudFront distributions:"
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}' \
  --output table || true

echo
echo "S3 buckets matching devops-masterclass:"
aws s3api list-buckets \
  --query 'Buckets[?contains(Name, `devops-masterclass`)].Name' \
  --output table || true

echo
echo "Reminder:"
echo "Destroy dev stack when stopping to avoid EC2, public IPv4, ALB, CloudFront, and storage charges."
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

Run:

```bash id="run-cost"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

---

# 13. Create Safe Destroy Script

This intentionally reuses your 12.10 full-stack cleanup.

```bash id="destroy-script"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Final IaC Capstone Dev Destroy ====="

echo
echo "This will destroy the dev capstone stack managed by Terraform."
echo "Expected resources may include:"
echo "- CloudFront"
echo "- S3 bucket and objects"
echo "- ALB"
echo "- target group"
echo "- EC2"
echo "- security groups"
echo "- IAM role and instance profile"
echo "- VPC networking"
echo
echo "Type DESTROY_FINAL_IAC_CAPSTONE_DEV to continue:"
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY_FINAL_IAC_CAPSTONE_DEV" ]; then
  echo "Destroy cancelled."
  exit 0
fi

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh

echo
echo "Running cost check after destroy attempt..."
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh
```

Run only when done:

```bash id="run-destroy"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh
```

---

# 14. Create Final Capstone Runbook

````bash id="capstone-runbook"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/runbooks/final-iac-capstone-runbook.md <<'EOF'
# Final IaC Capstone Runbook

## 1. Context

```bash
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-context.sh
````

## 2. Local validation

```bash
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-local-validate.sh
```

## 3. Plan and policy check

```bash
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-plan-policy.sh
```

Review:

```text
12-terraform-ansible-iac/12.16-final-iac-capstone/reports/dev-capstone-plan.txt
12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md
```

## 4. Apply and validate

```bash
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-apply-validate.sh
```

## 5. Generate evidence report

```bash
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-evidence-report.sh
```

## 6. Cost check

```bash
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

## 7. Destroy when finished

```bash
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh
```

## Golden rule

Do not apply until local validation and policy checks pass.
Do not stop for the day without running the cost check.
EOF

````

---

# 15. Create Troubleshooting Runbook

```bash id="troubleshoot-runbook"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/runbooks/final-capstone-troubleshooting-runbook.md <<'EOF'
# Final Capstone Troubleshooting Runbook

## Failure layer map

```text
Terraform init:
  backend, AWS auth, region, lock

Terraform validate:
  syntax, module inputs, provider config

Terraform plan:
  AWS permissions, data sources, variable validation

Policy check:
  risky planned resource

Terraform apply:
  AWS service error, IAM permission, dependency, quota

Ansible inventory:
  Terraform output missing or generator bug

Ansible connection:
  SSH/SSM connectivity

ALB validation:
  target group, security group, nginx, health path

CloudFront validation:
  distribution status, OAC, bucket policy, behavior, origin

Cost cleanup:
  dependency violation, CloudFront deletion delay
````

## Terraform debugging

```bash
cd 12-terraform-ansible-iac/environments/dev
terraform init -reconfigure -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
terraform validate
terraform plan -var-file=terraform.tfvars.example
```

## IAM debugging

```bash
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-caller-context.sh
ENVIRONMENT=dev ./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

## Policy debugging

```bash
cat 12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md
```

## ALB debugging

```bash
ENVIRONMENT=dev ./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/debug-target-health.sh
```

## CloudFront debugging

```bash
ENVIRONMENT=dev ./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/debug-cloudfront.sh
```

## Ansible debugging

```bash
cd 12-terraform-ansible-iac/ansible
ansible-inventory -i inventories/dev/hosts.yml --graph
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssm-readiness.yml -vvv
```

## Cost debugging

```bash
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

## Golden rule

Debug by layer:
state → plan → policy → apply → inventory → config → endpoint.
EOF

````

---

# 16. Create Final Checklist

```bash id="final-checklist"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/checklists/final-iac-capstone-checklist.md <<'EOF'
# Final IaC Capstone Checklist

## Repository

- [ ] environment roots exist for dev/staging/prod
- [ ] reusable modules exist
- [ ] backend module exists
- [ ] Ansible folder exists
- [ ] CI scripts exist
- [ ] policy folder exists
- [ ] GitHub workflows exist
- [ ] capstone docs exist

## Terraform

- [ ] fmt passes
- [ ] validate passes
- [ ] dev plan succeeds
- [ ] backend uses S3 remote state
- [ ] VPC module creates networking
- [ ] EC2 module enforces IMDSv2
- [ ] ALB module creates listener and target group
- [ ] S3 bucket blocks public access
- [ ] CloudFront uses OAC for S3
- [ ] outputs expose Ansible inventory contract

## Ansible

- [ ] ansible.cfg exists
- [ ] local inventory works
- [ ] generated dev inventory works
- [ ] common role exists
- [ ] nginx_hardening role exists
- [ ] app_runtime role exists
- [ ] sanity check passes
- [ ] cloud validation playbook works

## CI/CD

- [ ] PR check workflow exists
- [ ] apply workflow exists
- [ ] drift workflow exists
- [ ] destroy plan workflow exists
- [ ] OIDC trust policy example exists
- [ ] dev environment approval documented
- [ ] plan artifacts uploaded
- [ ] policy reports uploaded

## Policy

- [ ] policy rules YAML exists
- [ ] plan checker compiles
- [ ] public SSH blocked
- [ ] public DB ports blocked
- [ ] S3 controls checked
- [ ] CloudFront controls checked
- [ ] EC2 IMDSv2 checked
- [ ] reports generated

## Operations

- [ ] VPC validation works
- [ ] EC2 validation works
- [ ] ALB validation works
- [ ] CloudFront validation works
- [ ] IAM debug scripts exist
- [ ] troubleshooting runbooks exist
- [ ] cost check exists
- [ ] destroy script exists

## Portfolio

- [ ] architecture doc exists
- [ ] evidence report generated
- [ ] resume bullets written
- [ ] interview story prepared
EOF
````

---

# 17. Create Resume Project Summary

```bash id="resume-summary"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/resume/iac-capstone-resume-summary.md <<'EOF'
# Resume Summary — Terraform, Ansible, and IaC Capstone

## Project Title

Production-Style AWS Infrastructure Platform with Terraform, Ansible, CI/CD, and Policy-as-Code

## One-line Summary

Built a production-style AWS infrastructure platform using Terraform modules, Ansible configuration management, GitHub Actions/Jenkins CI/CD patterns, policy-as-code guardrails, remote state, validation automation, and operational runbooks.

## Resume Bullet — Short

Built an AWS IaC platform using Terraform, Ansible, GitHub Actions, and policy-as-code to provision and validate VPC, EC2, ALB, S3, CloudFront, IAM, security groups, remote state, CI/CD workflows, drift detection, and cost-safe cleanup.

## Resume Bullet — Strong

Designed and built a production-style AWS infrastructure platform with Terraform and Ansible, including modular VPC, EC2, ALB, S3, CloudFront, IAM, and security group provisioning; S3 remote state; CloudFront OAC; ALB target health validation; Ansible inventory generation from Terraform outputs; reusable Ansible roles; GitHub Actions/Jenkins IaC pipelines; OIDC-based AWS authentication patterns; policy-as-code gates for public SSH, S3 security, IMDSv2, CloudFront HTTPS/OAC, and approved regions; drift detection; runbooks; evidence reports; and cost-safe destroy workflows.

## Resume Bullet — Interview Focus

Implemented end-to-end Infrastructure as Code for AWS using Terraform modules and Ansible roles, with CI/CD approval workflows, policy gates, IAM troubleshooting, CloudFront/S3 private-origin security, ALB health validation, remote state management, drift detection, and operational documentation suitable for production DevOps/SRE workflows.

## Technologies

- Terraform
- AWS
- Ansible
- GitHub Actions
- Jenkins
- IAM
- VPC
- EC2
- ALB
- S3
- CloudFront
- OAC
- Systems Manager
- Bash
- Python
- jq
- YAML
- Policy-as-Code
EOF
```

---

# 18. Create Interview Story

```bash id="interview-story"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/interview/iac-capstone-interview-story.md <<'EOF'
# Interview Story — Final IaC Capstone

## 30-second version

I built a production-style AWS Infrastructure as Code platform using Terraform, Ansible, CI/CD, and policy-as-code. Terraform provisions the core AWS stack: VPC, subnets, EC2, security groups, IAM, ALB, S3, CloudFront, and OAC. Ansible consumes Terraform outputs to generate inventory, configure hosts, and validate endpoints. GitHub Actions/Jenkins workflows run fmt, validate, plan, policy checks, approval-based apply, Ansible validation, and drift detection. I also created IAM troubleshooting scripts, CloudFront/S3 debugging workflows, cost cleanup scripts, and operational runbooks.

## 2-minute version

The goal was to build an infrastructure platform that looks like a real production DevOps/SRE workflow rather than a simple Terraform demo.

I started by designing the Terraform repository with separate environment roots for dev, staging, and prod, and reusable modules for networking, compute, load balancers, storage, CDN, IAM, and security groups. I added remote state on S3, state locking, variables, locals, outputs, and module contracts.

Then I implemented real AWS infrastructure in ap-south-1: a VPC with public and private subnets, route tables, Internet Gateway, security groups, EC2 with IMDSv2, IAM role and instance profile, ALB with target group and health checks, S3 private assets bucket, and CloudFront with two origins — private S3 through Origin Access Control and ALB as a dynamic origin.

After provisioning, I added Ansible. Terraform outputs are exported into an inventory contract, then a script generates Ansible inventory and group variables. Ansible roles configure common packages, nginx, app runtime directories, templates, and validation playbooks.

For CI/CD, I created GitHub Actions and Jenkins-style workflows. Pull requests run Terraform fmt, validate, plan, Ansible checks, and policy gates. Apply workflows use saved plans and require protected environment approval. I also added drift detection and safe destroy planning.

For security and operations, I added policy-as-code checks that block public SSH, public database ports, EC2 without IMDSv2, insecure S3 buckets, CloudFront without HTTPS redirect, and S3 origins without OAC. I also created IAM debugging scripts for iam:PassRole, EC2 runtime roles, CloudFront OAC bucket policies, and AccessDenied decoding.

The final project includes validation scripts, evidence reports, runbooks, troubleshooting workflows, cost checks, and cleanup automation.

## Deep technical talking points

### Terraform

- Separate root modules for dev/staging/prod.
- Reusable child modules.
- Remote S3 backend.
- Strong variable types.
- Locals for naming and tagging.
- Outputs as contracts.
- Plan/apply workflow.
- Policy gate from plan JSON.

### AWS

- VPC design with public/private subnets.
- ALB in public subnets.
- EC2 target behind ALB.
- S3 private bucket for static assets.
- CloudFront with S3 and ALB origins.
- OAC for private S3 origin.
- IAM role and instance profile.
- SSM-preferred access model.

### Ansible

- Inventory generated from Terraform outputs.
- group_vars exported from Terraform outputs.
- common/nginx/app roles.
- handlers and templates.
- check and diff workflows.
- endpoint validation.

### CI/CD

- PR checks.
- saved plan artifacts.
- manual approval before apply.
- OIDC-based AWS credentials pattern.
- drift detection.
- destroy plan workflow.

### Security

- Policy-as-code gate.
- IMDSv2 enforcement.
- S3 public access block.
- S3 encryption.
- CloudFront HTTPS redirect.
- CloudFront OAC.
- public SSH/database port denial.
- IAM least-privilege examples.

## Best interview closing line

This project taught me to think beyond writing Terraform resources. I learned how to build the full operational loop: provision, configure, validate, secure, troubleshoot, document, and clean up infrastructure in a repeatable production-style workflow.
EOF
```

---

# 19. Create Final Validation Script

```bash id="validate-lesson"
cat > 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/validate-lesson-12-16.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.16 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.16-final-iac-capstone"

test -d "$LESSON/docs"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/evidence"
test -d "$LESSON/diagrams"
test -d "$LESSON/resume"
test -d "$LESSON/interview"
test -d "$LESSON/checklists"

test -f "$LESSON/docs/capstone-architecture.md"
test -f "$LESSON/diagrams/iac-capstone-architecture.mmd"
test -f "$LESSON/runbooks/final-iac-capstone-runbook.md"
test -f "$LESSON/runbooks/final-capstone-troubleshooting-runbook.md"
test -f "$LESSON/checklists/final-iac-capstone-checklist.md"
test -f "$LESSON/resume/iac-capstone-resume-summary.md"
test -f "$LESSON/interview/iac-capstone-interview-story.md"

test -x "$LESSON/scripts/capstone-context.sh"
test -x "$LESSON/scripts/capstone-repo-audit.sh"
test -x "$LESSON/scripts/capstone-local-validate.sh"
test -x "$LESSON/scripts/capstone-plan-policy.sh"
test -x "$LESSON/scripts/capstone-apply-validate.sh"
test -x "$LESSON/scripts/capstone-evidence-report.sh"
test -x "$LESSON/scripts/capstone-cost-check.sh"
test -x "$LESSON/scripts/capstone-destroy-dev.sh"

bash -n "$LESSON/scripts/capstone-context.sh"
bash -n "$LESSON/scripts/capstone-repo-audit.sh"
bash -n "$LESSON/scripts/capstone-local-validate.sh"
bash -n "$LESSON/scripts/capstone-plan-policy.sh"
bash -n "$LESSON/scripts/capstone-apply-validate.sh"
bash -n "$LESSON/scripts/capstone-evidence-report.sh"
bash -n "$LESSON/scripts/capstone-cost-check.sh"
bash -n "$LESSON/scripts/capstone-destroy-dev.sh"

"$LESSON/scripts/capstone-repo-audit.sh"

echo
echo "Lesson 12.16 validation passed."
EOF

chmod +x 12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/validate-lesson-12-16.sh
```

Run:

```bash id="run-validate-lesson"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/validate-lesson-12-16.sh
```

---

# 20. Capstone Execution Flow

Run this sequence for the final project demo.

## Step 1 — Context

```bash id="step-context"
cd ~/devops-masterclass

ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-context.sh
```

## Step 2 — Local validation

```bash id="step-local"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-local-validate.sh
```

## Step 3 — Plan and policy

```bash id="step-plan"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-plan-policy.sh
```

Review:

```bash id="review-plan-policy"
cat 12-terraform-ansible-iac/12.16-final-iac-capstone/reports/dev-capstone-plan.txt
cat 12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md
```

## Step 4 — Apply and validate

```bash id="step-apply"
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-apply-validate.sh
```

## Step 5 — Evidence report

```bash id="step-evidence"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-evidence-report.sh
```

## Step 6 — Cost check

```bash id="step-cost"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

## Step 7 — Destroy when finished

```bash id="step-destroy"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh
```

---

# 21. Final Common Errors and Fixes

## Error 1 — Policy gate fails before apply

Open:

```bash id="policy-report"
cat 12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md
```

Fix the exact finding. Do not bypass the policy just to apply.

---

## Error 2 — Terraform cannot pass EC2 role

Run:

```bash id="passrole-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

Fix `iam:PassRole` for the exact EC2 role and service.

---

## Error 3 — EC2 works but ALB returns 503

Run:

```bash id="alb-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.9-alb-target-groups/scripts/debug-target-health.sh
```

Most common causes:

```text id="alb-causes"
target unhealthy
EC2 SG does not allow ALB SG
nginx not listening
wrong health check path
wrong target group port
```

---

## Error 4 — ALB works but CloudFront `/health` fails

Run:

```bash id="cf-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/debug-cloudfront.sh
```

Check:

```text id="cf-health-checks"
CloudFront distribution deployed
ALB origin domain correct
origin protocol policy correct
default behavior points to ALB
```

---

## Error 5 — CloudFront `/assets/*` returns 403

Run:

```bash id="oac-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh
```

Check:

```text id="oac-checks"
object exists
OAC attached
bucket policy SourceArn correct
S3 regional domain used
/assets/* behavior points to S3 origin
```

---

## Error 6 — Ansible SSM connection fails

Run:

```bash id="ssm-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh
```

Check:

```text id="ssm-checks"
EC2 role attached
AmazonSSMManagedInstanceCore attached
SSM agent online
control identity has SSM session permissions
correct region
amazon.aws collection installed
```

---

# 22. Final Cost Safety

This capstone can create billable AWS resources.

Run this before stopping:

```bash id="cost-before-stop"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

Destroy when done:

```bash id="destroy-final"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-destroy-dev.sh
```

Then confirm again:

```bash id="cost-after-destroy"
./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/capstone-cost-check.sh
```

---

# 23. Final Revision Questions

You should now be able to answer these confidently:

```text id="revision"
What does Terraform own in this project?
What does Ansible own?
What does CI/CD own?
What does the policy gate own?
Why use remote state?
Why use reusable modules?
Why use outputs as contracts?
Why generate Ansible inventory from Terraform outputs?
Why prefer SSM over public SSH?
Why does EC2 need an instance profile?
Why does Terraform need iam:PassRole?
Why put ALB in public subnets?
Why keep S3 private?
Why use CloudFront OAC?
Why does CloudFront custom-domain ACM need us-east-1?
What causes ALB 503?
What causes CloudFront 403?
Why run policy checks before apply?
Why use saved Terraform plans in CI/CD?
Why use OIDC for GitHub Actions?
How do you detect drift?
How do you clean up billable resources?
How would you explain this project in an interview?
```

GitHub Actions OIDC is a strong talking point: GitHub’s AWS OIDC guidance says OIDC allows workflows to access AWS without storing long-lived AWS credentials, and GitHub recommends environment protection rules when environments are used in OIDC policies. ([GitHub Docs][3])

---

# 24. Final Resume Bullet

```text id="final-resume-bullet"
Built a production-style AWS Infrastructure as Code platform using Terraform, Ansible, GitHub Actions, Jenkins patterns, and policy-as-code, provisioning VPC, EC2, IAM, ALB, S3, CloudFront, private S3 origins with OAC, remote state, security groups, and validation workflows; integrated Terraform outputs with Ansible inventory and roles; implemented CI/CD plan/apply approval gates, drift detection, IAM troubleshooting, CloudFront/ALB/S3 validation, security policy checks, evidence reports, runbooks, and cost-safe cleanup automation.
```

---

# 25. Final Interview Answer

```text id="final-interview-answer"
I built a full AWS IaC capstone that goes beyond basic Terraform provisioning. Terraform owns the infrastructure layer: VPC, subnets, routing, EC2, security groups, IAM, ALB, S3, CloudFront, OAC, and remote state. I structured the repo with reusable modules, separate environment roots, strong variables, locals, outputs, and module contracts.

Ansible consumes Terraform outputs to generate inventory and group variables, then uses reusable roles for common packages, nginx hardening, app runtime setup, and validation. For AWS access, I designed the project around SSM-preferred administration instead of broad public SSH.

I added CI/CD workflows using GitHub Actions and Jenkins patterns. Pull requests run fmt, validate, plan, policy checks, and Ansible sanity. Apply workflows use saved Terraform plans and approval gates before changing infrastructure. After apply, the pipeline exports outputs, generates Ansible inventory, and validates ALB and CloudFront endpoints.

For security, I implemented policy-as-code checks that block public SSH, public database ports, EC2 without IMDSv2, insecure S3 buckets, CloudFront without HTTPS redirect, S3 origins without OAC, and unapproved regions. I also built IAM troubleshooting scripts for iam:PassRole, EC2 runtime roles, S3 bucket policies, CloudFront OAC, and encoded authorization messages.

Operationally, the project includes evidence reports, troubleshooting runbooks, drift detection, cost checks, and safe destroy workflows. The biggest learning was building the full production loop: provision, configure, validate, secure, troubleshoot, document, and clean up infrastructure.
```

---

# 26. Commit Final Capstone

```bash id="commit-final"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.16-final-iac-capstone/scripts/validate-lesson-12-16.sh

git status

find 12-terraform-ansible-iac/12.16-final-iac-capstone -maxdepth 4 -type f | sort

git add 12-terraform-ansible-iac

git commit -m "feat: complete final Terraform Ansible IaC capstone"

git push
```

---

# 27. Module 12 Completion Tag

After committing:

```bash id="tag-module-12"
cd ~/devops-masterclass

git tag -a v0.12.0 -m "Complete Module 12 Terraform Ansible and IaC"

git push origin v0.12.0
```

---

# 28. Module 12 Completed

```text id="module-complete"
Module 12 — Terraform, Ansible, and Infrastructure as Code is complete.
```

You now have a complete resume-ready project:

```text id="project-complete"
Terraform modules
AWS infrastructure
remote state
Ansible roles
Terraform-to-Ansible integration
CI/CD pipelines
policy-as-code gates
IAM troubleshooting
CloudFront/S3/ALB validation
drift detection
cost cleanup
runbooks
evidence reports
resume and interview packaging
```

---

# 29. Next Module

```text id="next-module"
Module 13 — AWS Production Architecture
```

We will go deeper into:

```text id="module-13-topics"
multi-account AWS architecture
landing zone concepts
VPC design patterns
private workloads
NAT vs VPC endpoints
Route 53
ACM
CloudFront production patterns
ALB production patterns
Auto Scaling Groups
RDS basics
Secrets Manager
SSM Parameter Store
KMS
CloudWatch
AWS WAF
backup and disaster recovery
cost controls
production reference architecture
```

[1]: https://developer.hashicorp.com/terraform/cli/commands/apply?utm_source=chatgpt.com "terraform apply command reference | Terraform | HashiCorp Developer"
[2]: https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html?utm_source=chatgpt.com "Roles — Ansible Community Documentation"
[3]: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws?ref=nalth.is&utm_source=chatgpt.com "Configuring OpenID Connect in Amazon Web Services - GitHub Docs"
