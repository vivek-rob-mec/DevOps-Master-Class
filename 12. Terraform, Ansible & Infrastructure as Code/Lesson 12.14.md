# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.14 — CI/CD for IaC

In Lesson 12.13, you connected Terraform and Ansible:

```text id="recap-12-13"
Terraform apply
Terraform output contracts
Ansible inventory generation
Ansible group_vars export
ALB validation
CloudFront validation
SSM/SSH execution modes
Makefile orchestration
post-apply handoff
```

Now we turn that workflow into a **CI/CD pipeline for Infrastructure as Code**.

We will use **GitHub Actions as the main implementation** and include **Jenkins notes** because you already use Jenkins in your DevOps projects.

Terraform supports saved plan workflows with `terraform plan -out=FILE`, and HashiCorp describes this two-step plan/apply workflow as useful for automation because the applied changes match the reviewed plan. Applying a saved plan skips the interactive approval prompt, so the approval must happen outside Terraform, for example through GitHub environment protection or Jenkins input gates. ([HashiCorp Developer][1])

---

# 1. Goal

Build a production-style IaC pipeline that can:

```text id="goal"
run Terraform fmt
run Terraform validate
run Terraform plan
save plan artifact
require manual approval before apply
apply reviewed plan
generate Ansible inventory
run Ansible syntax checks
run Ansible check mode
run post-apply validation
run drift detection
support safe destroy planning
protect AWS credentials with OIDC
```

Pipeline architecture:

```text id="pipeline-architecture"
Pull Request:
  terraform fmt
  terraform validate
  terraform plan
  ansible syntax check
  ansible sanity
  no apply

Main / Manual Dispatch:
  terraform plan
  upload plan artifact
  wait for environment approval
  terraform apply saved plan
  export outputs
  generate Ansible inventory
  run Ansible validation

Scheduled:
  drift detection plan
  no apply

Destroy:
  manual only
  destroy plan only by default
  separate approval required
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.14.1   CI/CD for IaC mental model
12.14.2   PR validation pipeline
12.14.3   plan artifact handling
12.14.4   manual approval before apply
12.14.5   GitHub Actions environments
12.14.6   AWS OIDC authentication
12.14.7   least-privilege pipeline permissions
12.14.8   Terraform fmt/validate/plan/apply
12.14.9   Ansible syntax/check mode
12.14.10  post-apply validation
12.14.11  drift detection
12.14.12  safe destroy workflow
12.14.13  concurrency control
12.14.14  pipeline artifacts
12.14.15  Jenkins equivalent pattern
12.14.16  CI/CD runbooks
```

GitHub Actions environments can require reviewers, restrict deployment branches, use environment secrets, and apply deployment protection rules before a job referencing that environment runs. ([GitHub Docs][2])

---

# 3. Never Confuse These

## CI Check vs CD Apply

```text id="ci-vs-cd"
CI check:
  validates code and creates a plan

CD apply:
  changes real infrastructure
```

PRs should not casually apply infrastructure.

---

## Plan Artifact vs Plan Text

```text id="plan-artifact-vs-text"
plan artifact:
  binary Terraform saved plan file used by terraform apply

plan text:
  human-readable terraform show output
```

You review the text, but apply the saved plan.

---

## Approval Before Plan vs Approval Before Apply

```text id="approval"
Approval before plan:
  weak control

Approval before apply:
  useful control
```

A production pipeline should review the plan before applying it.

---

## GitHub Secrets vs OIDC

```text id="secrets-vs-oidc"
GitHub secrets:
  long-lived static credentials if you store AWS keys

OIDC:
  short-lived credentials issued by AWS after GitHub identity verification
```

GitHub’s AWS OIDC documentation states that OIDC lets GitHub Actions access AWS resources without storing long-lived AWS credentials as GitHub secrets. ([GitHub Docs][3])

---

## Terraform Caller Role vs EC2 Runtime Role

```text id="caller-vs-runtime"
CI/CD role:
  used by pipeline to run Terraform

EC2 runtime role:
  attached to EC2 instance
```

The pipeline role needs permissions to create infrastructure and pass the EC2 role. The EC2 role needs runtime permissions such as SSM.

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.14-cicd-for-iac/{notes,scripts,runbooks,reports,policies,github-actions,jenkins}
mkdir -p .github/workflows
mkdir -p 12-terraform-ansible-iac/ci/scripts
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.14-cicd-for-iac
tree -L 3 .github
tree -L 3 12-terraform-ansible-iac/ci
```

---

# 5. Create CI/CD Mental Model Notes

````bash id="mental-note"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/notes/cicd-for-iac-mental-model.md <<'EOF'
# CI/CD for IaC Mental Model

## CI for IaC

CI answers:

```text
Is the infrastructure code valid, formatted, reviewable, and safe enough to consider?
````

Typical CI steps:

* terraform fmt -check
* terraform validate
* terraform plan
* ansible syntax check
* ansible check mode
* policy checks
* plan summary

## CD for IaC

CD answers:

```text
Should the approved infrastructure plan be applied?
```

Typical CD steps:

* generate saved plan
* require approval
* apply saved plan
* export outputs
* generate Ansible inventory
* run Ansible validation
* publish report

## Drift detection

Drift detection answers:

```text
Does real infrastructure differ from Terraform state/configuration?
```

## Golden rule

In IaC, the pipeline is a production change-control system, not just automation.
EOF

````

---

# 6. Create Never-Forget CI/CD Notes

```bash id="never-note"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/notes/never-confuse-cicd-iac-points.md <<'EOF'
# Never Forget — CI/CD for IaC

## 1. Never auto-apply unreviewed infrastructure plans

A plan should be reviewed before apply.

## 2. Use saved plans for apply

Use:

```bash
terraform plan -out=tfplan
terraform apply tfplan
````

## 3. Do not store long-lived AWS keys in GitHub secrets if OIDC is available

Prefer short-lived credentials through OIDC.

## 4. Restrict workflow permissions

Use least-privilege GitHub Actions permissions.

## 5. Protect apply jobs

Use environments, required reviewers, and branch restrictions.

## 6. Use concurrency

Avoid two applies running against the same state at the same time.

## 7. Drift detection should not auto-fix

Detect drift first.
Review before changing infrastructure.

## 8. Destroy must be separate and manual

Destroy is too dangerous to hide inside a normal deploy pipeline.

## 9. Ansible check mode belongs before Ansible apply

Use:

```bash
ansible-playbook --check --diff
```

## 10. Pipeline logs are audit evidence

Keep plan output, apply logs, Ansible logs, and validation reports.
EOF

````

---

# 7. Create AWS OIDC Trust Policy Example

Create a placeholder trust policy for GitHub Actions.

```bash id="oidc-policy"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/policies/github-actions-oidc-trust-policy-example.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsAssumeRoleWithOIDC",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<GITHUB_OWNER>/<GITHUB_REPO>:ref:refs/heads/main",
            "repo:<GITHUB_OWNER>/<GITHUB_REPO>:environment:dev"
          ]
        }
      }
    }
  ]
}
EOF
````

Create an OIDC setup note:

````bash id="oidc-note"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/notes/aws-oidc-setup-notes.md <<'EOF'
# AWS OIDC Setup Notes for GitHub Actions

## Why OIDC?

OIDC avoids storing long-lived AWS access keys in GitHub secrets.

## AWS-side resources

You need:

- IAM OIDC provider for token.actions.githubusercontent.com
- IAM role trusted by GitHub OIDC
- IAM permissions policy attached to that role

## GitHub workflow requirements

Workflow/job permissions need:

```yaml
permissions:
  id-token: write
  contents: read
````

## GitHub repo variables/secrets

Recommended repository variables:

```text
AWS_REGION=ap-south-1
AWS_ROLE_ARN=arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
```

## Trust policy scope

Restrict trust policy by:

* repository
* branch
* environment
* audience

## Golden rule

The CI/CD role should be powerful enough to deploy the stack, but not a general-purpose admin role.
EOF

````

In GitHub Actions, a workflow needs `id-token: write` permission to request an OIDC token, and AWS credential configuration actions can exchange that token for AWS credentials. :contentReference[oaicite:3]{index=3}

---

# 8. Create CI/CD Role Permission Example

Use your 12.11 policy as the base, but create a CI/CD-specific example.

```bash id="cicd-policy"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/policies/github-actions-iac-dev-policy-example.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadContext",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "ec2:Describe*",
        "elasticloadbalancing:Describe*",
        "cloudfront:Get*",
        "cloudfront:List*",
        "s3:GetBucket*",
        "s3:ListBucket",
        "s3:GetObject",
        "iam:Get*",
        "iam:List*",
        "ssm:DescribeInstanceInformation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageDevVpcEc2SecurityGroups",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageDevAlb",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageDevS3Assets",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketTagging",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketOwnershipControls",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::devops-masterclass-*",
        "arn:aws:s3:::devops-masterclass-*/*"
      ]
    },
    {
      "Sid": "ManageDevCloudFront",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:UpdateOriginAccessControl",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
        "cloudfront:CreateInvalidation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageDevIamForEc2Only",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::*:role/devops-masterclass-dev-*",
        "arn:aws:iam::*:instance-profile/devops-masterclass-dev-*"
      ]
    },
    {
      "Sid": "PassOnlyDevEc2RoleToEc2",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::*:role/devops-masterclass-dev-ec2-role",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ec2.amazonaws.com"
        }
      }
    },
    {
      "Sid": "DecodeAuthorizationMessages",
      "Effect": "Allow",
      "Action": "sts:DecodeAuthorizationMessage",
      "Resource": "*"
    }
  ]
}
EOF
````

Important:

```text id="policy-warning"
This is a lab policy example.
Review and scope it before attaching it in a real AWS account.
```

---

# 9. Create Terraform CI Plan Script

```bash id="tf-plan-script"
cat > 12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
PLAN_NAME="${PLAN_NAME:-tfplan}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="$BASE/12.14-cicd-for-iac/reports"

mkdir -p "$REPORT_DIR"

echo "===== Terraform CI Plan ====="
echo "Environment: $ENVIRONMENT"
echo "AWS region: $AWS_REGION"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -check -recursive
terraform validate

terraform plan \
  -var-file=terraform.tfvars.example \
  -out="$PLAN_NAME"

terraform show -no-color "$PLAN_NAME" > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-plan.txt"
terraform show -json "$PLAN_NAME" > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-plan.json"

echo "Plan file: $TF_DIR/$PLAN_NAME"
echo "Plan text: $REPORT_DIR/$ENVIRONMENT-plan.txt"
echo "Plan JSON: $REPORT_DIR/$ENVIRONMENT-plan.json"
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh
```

Terraform `fmt` rewrites configuration into canonical style, and `validate` checks syntax and argument correctness. In CI, use `fmt -check` so the job fails instead of rewriting files on the runner. ([HashiCorp Developer][4])

---

# 10. Create Terraform CI Apply Script

```bash id="tf-apply-script"
cat > 12-terraform-ansible-iac/ci/scripts/terraform-ci-apply.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
PLAN_NAME="${PLAN_NAME:-tfplan}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"

echo "===== Terraform CI Apply ====="
echo "Environment: $ENVIRONMENT"
echo "Plan: $PLAN_NAME"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"

test -f "$PLAN_NAME" || {
  echo "Missing saved plan file: $PLAN_NAME"
  exit 1
}

terraform apply "$PLAN_NAME"

terraform output -json > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-outputs.json"

echo "Terraform apply completed."
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/terraform-ci-apply.sh
```

---

# 11. Create Ansible CI Check Script

```bash id="ansible-check-script"
cat > 12-terraform-ansible-iac/ci/scripts/ansible-ci-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

BASE="12-terraform-ansible-iac"
ANSIBLE_DIR="$BASE/ansible"

echo "===== Ansible CI Check ====="
echo "Environment: $ENVIRONMENT"

cd "$ANSIBLE_DIR"

ansible --version
ansible-config dump --only-changed

./scripts/ansible-sanity.sh

if [ -f "inventories/$ENVIRONMENT/hosts.yml" ]; then
  ansible-inventory -i "inventories/$ENVIRONMENT/hosts.yml" --graph
fi

echo "Ansible CI check completed."
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/ansible-ci-check.sh
```

---

# 12. Create Post-Apply CI Validation Script

```bash id="post-apply-script"
cat > 12-terraform-ansible-iac/ci/scripts/post-apply-ci-validate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
CONNECTION_MODE="${CONNECTION_MODE:-ssm}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

BASE="12-terraform-ansible-iac"

echo "===== Post-Apply CI Validation ====="
echo "Environment: $ENVIRONMENT"
echo "Connection mode: $CONNECTION_MODE"
echo "AWS region: $AWS_REGION"

ENVIRONMENT="$ENVIRONMENT" CONNECTION_MODE="$CONNECTION_MODE" AWS_REGION="$AWS_REGION" \
"./$BASE/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh"

echo "Post-apply CI validation completed."
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/post-apply-ci-validate.sh
```

---

# 13. Create Drift Detection Script

Use Terraform’s detailed exit code:

```text id="detailed-exitcode"
0 = no changes
1 = error
2 = changes present
```

```bash id="drift-script"
cat > 12-terraform-ansible-iac/ci/scripts/terraform-drift-detect.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="$BASE/12.14-cicd-for-iac/reports"

mkdir -p "$REPORT_DIR"

echo "===== Terraform Drift Detection ====="
echo "Environment: $ENVIRONMENT"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -check -recursive
terraform validate

set +e
terraform plan \
  -var-file=terraform.tfvars.example \
  -detailed-exitcode \
  -out=tfplan-drift \
  > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-drift-plan.txt"

EXIT_CODE="$?"
set -e

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "No drift detected."
  rm -f tfplan-drift
  exit 0
elif [ "$EXIT_CODE" -eq 2 ]; then
  echo "Drift or pending changes detected."
  terraform show -no-color tfplan-drift >> "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-drift-plan.txt"
  rm -f tfplan-drift
  exit 2
else
  echo "Terraform plan failed."
  rm -f tfplan-drift
  exit 1
fi
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/terraform-drift-detect.sh
```

---

# 14. Create Safe Destroy Plan Script

This creates a destroy plan but does **not** apply it.

```bash id="destroy-plan-script"
cat > 12-terraform-ansible-iac/ci/scripts/terraform-destroy-plan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [ "$ENVIRONMENT" != "dev" ]; then
  echo "Destroy plan script is limited to ENVIRONMENT=dev for this course."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/dev"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl"
REPORT_DIR="$BASE/12.14-cicd-for-iac/reports"

mkdir -p "$REPORT_DIR"

echo "===== Terraform Destroy Plan ====="
echo "Environment: dev"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform validate

terraform plan \
  -destroy \
  -var-file=terraform.tfvars.example \
  -out=tfplan-destroy-dev

terraform show -no-color tfplan-destroy-dev > "../../12.14-cicd-for-iac/reports/dev-destroy-plan.txt"

echo "Destroy plan created but not applied."
echo "Review report: $REPORT_DIR/dev-destroy-plan.txt"
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/terraform-destroy-plan.sh
```

---

# 15. Create GitHub Actions PR Check Workflow

```bash id="pr-workflow"
cat > .github/workflows/iac-pr-check.yml <<'EOF'
name: IaC PR Check

on:
  pull_request:
    paths:
      - "12-terraform-ansible-iac/**"
      - ".github/workflows/iac-*.yml"

permissions:
  contents: read
  id-token: write

concurrency:
  group: iac-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

env:
  AWS_REGION: ap-south-1
  ENVIRONMENT: dev
  PLAN_NAME: tfplan-pr

jobs:
  terraform-plan:
    name: Terraform fmt validate plan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform CI plan
        run: |
          ./12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh

      - name: Upload Terraform plan reports
        uses: actions/upload-artifact@v4
        with:
          name: terraform-pr-plan-${{ github.run_id }}
          path: |
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.txt
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.json
          retention-days: 7

  ansible-check:
    name: Ansible syntax and sanity
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Ansible
        run: |
          python3 -m pip install --user ansible pyyaml
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Ansible CI check
        run: |
          ./12-terraform-ansible-iac/ci/scripts/ansible-ci-check.sh
EOF
```

The `hashicorp/setup-terraform` action installs Terraform CLI in GitHub Actions workflows. ([GitHub][5])

---

# 16. Create GitHub Actions Dev Apply Workflow

This is manual and uses the `dev` GitHub environment for approval.

```bash id="apply-workflow"
cat > .github/workflows/iac-apply-dev.yml <<'EOF'
name: IaC Apply Dev

on:
  workflow_dispatch:
    inputs:
      connection_mode:
        description: "Ansible connection mode"
        required: true
        default: "ssm"
        type: choice
        options:
          - ssm
          - ssh

permissions:
  contents: read
  id-token: write

concurrency:
  group: iac-apply-dev
  cancel-in-progress: false

env:
  AWS_REGION: ap-south-1
  ENVIRONMENT: dev
  PLAN_NAME: tfplan-dev

jobs:
  plan:
    name: Terraform plan dev
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform plan
        run: |
          ./12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh

      - name: Upload saved plan and reports
        uses: actions/upload-artifact@v4
        with:
          name: terraform-dev-plan-${{ github.run_id }}
          path: |
            12-terraform-ansible-iac/environments/dev/tfplan-dev
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.txt
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.json
          retention-days: 3

  apply:
    name: Terraform apply dev
    runs-on: ubuntu-latest
    needs: plan
    environment: dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Download saved plan
        uses: actions/download-artifact@v4
        with:
          name: terraform-dev-plan-${{ github.run_id }}
          path: downloaded-plan

      - name: Restore plan file
        run: |
          cp downloaded-plan/12-terraform-ansible-iac/environments/dev/tfplan-dev \
             12-terraform-ansible-iac/environments/dev/tfplan-dev

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform apply saved plan
        run: |
          ./12-terraform-ansible-iac/ci/scripts/terraform-ci-apply.sh

      - name: Install Ansible
        run: |
          python3 -m pip install --user ansible pyyaml
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          cd 12-terraform-ansible-iac/ansible
          ansible-galaxy collection install -r requirements.yml || true

      - name: Post-apply Ansible validation
        env:
          CONNECTION_MODE: ${{ inputs.connection_mode }}
        run: |
          ./12-terraform-ansible-iac/ci/scripts/post-apply-ci-validate.sh

      - name: Upload apply reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: iac-dev-apply-reports-${{ github.run_id }}
          path: |
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/**
            12-terraform-ansible-iac/ansible/inventories/dev/**
          retention-days: 14
EOF
```

Before using this workflow, create a GitHub environment named `dev` and configure required reviewers or other deployment protection rules. Jobs referencing a protected environment wait for approval before running. ([GitHub Docs][2])

---

# 17. Create GitHub Actions Drift Detection Workflow

```bash id="drift-workflow"
cat > .github/workflows/iac-drift-detect.yml <<'EOF'
name: IaC Drift Detect

on:
  workflow_dispatch:
  schedule:
    - cron: "30 2 * * *"

permissions:
  contents: read
  id-token: write

concurrency:
  group: iac-drift-dev
  cancel-in-progress: true

env:
  AWS_REGION: ap-south-1
  ENVIRONMENT: dev

jobs:
  drift:
    name: Terraform drift detection
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Run drift detection
        id: drift
        continue-on-error: true
        run: |
          ./12-terraform-ansible-iac/ci/scripts/terraform-drift-detect.sh

      - name: Upload drift report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: terraform-drift-report-${{ github.run_id }}
          path: |
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-drift-plan.txt
          retention-days: 14

      - name: Fail if drift detected
        if: steps.drift.outcome == 'failure'
        run: |
          echo "Drift detection found changes or an error. Review artifact."
          exit 1
EOF
```

---

# 18. Create GitHub Actions Destroy Plan Workflow

This creates a destroy plan only.

```bash id="destroy-workflow"
cat > .github/workflows/iac-destroy-plan-dev.yml <<'EOF'
name: IaC Destroy Plan Dev

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

concurrency:
  group: iac-destroy-plan-dev
  cancel-in-progress: false

env:
  AWS_REGION: ap-south-1
  ENVIRONMENT: dev

jobs:
  destroy-plan:
    name: Terraform destroy plan dev
    runs-on: ubuntu-latest
    environment: dev

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Create destroy plan only
        run: |
          ./12-terraform-ansible-iac/ci/scripts/terraform-destroy-plan.sh

      - name: Upload destroy plan report
        uses: actions/upload-artifact@v4
        with:
          name: terraform-dev-destroy-plan-${{ github.run_id }}
          path: |
            12-terraform-ansible-iac/environments/dev/tfplan-destroy-dev
            12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-destroy-plan.txt
          retention-days: 3
EOF
```

---

# 19. Create GitHub Actions Setup Runbook

````bash id="gha-runbook"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/runbooks/github-actions-iac-setup-runbook.md <<'EOF'
# GitHub Actions IaC Setup Runbook

## 1. Create AWS OIDC provider

Provider URL:

```text
https://token.actions.githubusercontent.com
````

Audience:

```text
sts.amazonaws.com
```

## 2. Create AWS IAM role

Example role name:

```text
devops-masterclass-github-actions-iac-role
```

Trust policy:

```text id="vu9b5j"
12-terraform-ansible-iac/12.14-cicd-for-iac/policies/github-actions-oidc-trust-policy-example.json
```

## 3. Attach permission policy

Example policy:

```text id="lnx9x8"
12-terraform-ansible-iac/12.14-cicd-for-iac/policies/github-actions-iac-dev-policy-example.json
```

## 4. Add GitHub repository variable

Repository variable:

```text id="m2qzky"
AWS_ROLE_ARN=arn:aws:iam::<ACCOUNT_ID>:role/devops-masterclass-github-actions-iac-role
```

## 5. Create GitHub environment

Environment name:

```text id="xgxc6f"
dev
```

Recommended protection:

* required reviewers
* restrict deployment branch to main
* prevent self-review where appropriate

## 6. Run PR check

Open a pull request touching:

```text id="5qjwjy"
12-terraform-ansible-iac/**
```

Expected workflows:

```text id="3zpedh"
IaC PR Check
```

## 7. Run dev apply

Manually trigger:

```text id="8cukg1"
IaC Apply Dev
```

Review plan artifact before approving environment deployment.

## 8. Run drift detection

Manually trigger or wait for schedule:

```text id="7dj5cb"
IaC Drift Detect
```

## Golden rule

The pipeline role should be scoped, audited, and protected by GitHub environment approvals.
EOF

````

---

# 20. Create Jenkins Pipeline Example

Since you already use Jenkins, create a Jenkinsfile example for the same flow.

```bash id="jenkinsfile"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/jenkins/Jenkinsfile.iac <<'EOF'
pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev'], description: 'Target environment')
    choice(name: 'CONNECTION_MODE', choices: ['ssm', 'ssh'], description: 'Ansible connection mode')
    booleanParam(name: 'APPLY', defaultValue: false, description: 'Apply Terraform plan after approval')
  }

  environment {
    AWS_REGION = 'ap-south-1'
    AWS_DEFAULT_REGION = 'ap-south-1'
    PLAN_NAME = 'tfplan-jenkins'
  }

  stages {
    stage('Context') {
      steps {
        sh '''
          aws sts get-caller-identity
          terraform version
          ansible --version
        '''
      }
    }

    stage('Terraform Plan') {
      steps {
        sh '''
          ENVIRONMENT="${ENVIRONMENT}" PLAN_NAME="${PLAN_NAME}" AWS_REGION="${AWS_REGION}" \
          ./12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: '12-terraform-ansible-iac/12.14-cicd-for-iac/reports/*plan*', allowEmptyArchive: true
        }
      }
    }

    stage('Approval') {
      when {
        expression { return params.APPLY == true }
      }
      steps {
        input message: 'Apply reviewed Terraform plan?', ok: 'Apply'
      }
    }

    stage('Terraform Apply') {
      when {
        expression { return params.APPLY == true }
      }
      steps {
        sh '''
          ENVIRONMENT="${ENVIRONMENT}" PLAN_NAME="${PLAN_NAME}" \
          ./12-terraform-ansible-iac/ci/scripts/terraform-ci-apply.sh
        '''
      }
    }

    stage('Ansible Check') {
      steps {
        sh '''
          ./12-terraform-ansible-iac/ci/scripts/ansible-ci-check.sh
        '''
      }
    }

    stage('Post Apply Validation') {
      when {
        expression { return params.APPLY == true }
      }
      steps {
        sh '''
          ENVIRONMENT="${ENVIRONMENT}" CONNECTION_MODE="${CONNECTION_MODE}" AWS_REGION="${AWS_REGION}" \
          ./12-terraform-ansible-iac/ci/scripts/post-apply-ci-validate.sh
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '12-terraform-ansible-iac/12.14-cicd-for-iac/reports/**', allowEmptyArchive: true
      archiveArtifacts artifacts: '12-terraform-ansible-iac/ansible/inventories/dev/**', allowEmptyArchive: true
    }
  }
}
EOF
````

Create Jenkins notes:

```bash id="jenkins-note"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/jenkins/jenkins-iac-pipeline-notes.md <<'EOF'
# Jenkins IaC Pipeline Notes

## Recommended stages

1. Context
2. Terraform fmt
3. Terraform validate
4. Terraform plan
5. Archive plan/report
6. Manual input approval
7. Terraform apply saved plan
8. Ansible syntax check
9. Ansible check mode
10. Post-apply validation
11. Archive reports

## AWS credentials

Preferred:

- Jenkins agent assumes IAM role through instance profile or web identity
- no long-lived AWS keys in Jenkins credentials if avoidable

Fallback:

- Jenkins credentials binding for AWS keys
- restricted IAM policy
- rotate keys frequently

## Approval

Use Jenkins `input` step before apply.

## Artifact handling

Archive:

- plan text
- plan JSON
- Terraform outputs
- Ansible inventory
- validation reports

## Golden rule

Jenkins should not apply infrastructure unless plan was reviewed and approved.
EOF
```

---

# 21. Create Pipeline Security Notes

````bash id="security-note"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/notes/pipeline-security-guardrails.md <<'EOF'
# Pipeline Security Guardrails

## GitHub Actions permissions

Use explicit workflow permissions:

```yaml
permissions:
  contents: read
  id-token: write
````

Add more only when required.

## AWS authentication

Prefer OIDC over long-lived access keys.

## Environments

Use protected environments for apply jobs.

## Concurrency

Use concurrency groups to prevent overlapping applies.

## Branch protection

Require:

* PR review
* status checks
* no direct pushes to main
* CODEOWNERS for IaC files where possible

## Plan safety

Save:

* binary plan artifact
* text plan output
* JSON plan output

Review plan before apply.

## Sensitive output warning

Do not upload artifacts containing secrets.

Terraform plan JSON and output JSON can expose sensitive data if your configuration outputs secrets.

## Destroy safety

Destroy must be:

* manual
* environment protected
* separate workflow
* plan-only by default
* reviewed carefully
  EOF

````

---

# 22. Create CI/CD Troubleshooting Runbook

```bash id="troubleshoot-runbook"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/runbooks/cicd-iac-troubleshooting-runbook.md <<'EOF'
# CI/CD for IaC Troubleshooting Runbook

## 1. GitHub OIDC fails

Symptoms:

```text
Could not assume role with OIDC
Not authorized to perform sts:AssumeRoleWithWebIdentity
````

Check:

* workflow has `permissions: id-token: write`
* AWS OIDC provider exists
* trust policy repository matches owner/repo
* trust policy branch/environment condition matches workflow
* `AWS_ROLE_ARN` variable is correct

## 2. Terraform init fails

Check:

* backend bucket exists
* backend config path is correct
* S3 lockfile permission exists
* AWS region is correct
* OIDC role has S3 backend access

## 3. Terraform plan fails

Check:

```bash
terraform fmt -check -recursive
terraform validate
aws sts get-caller-identity
```

Common causes:

* missing AWS permission
* missing tfvars
* bad module source
* provider version issue
* wrong backend

## 4. Terraform apply fails after approval

Check:

* downloaded plan exists
* plan file path is correct
* apply job uses same code commit
* backend state lock
* AWS permissions
* CloudFront deployment timing

## 5. Ansible check fails

Check:

* Ansible installed
* PyYAML installed
* inventory exists
* role files exist
* collection installed for SSM

## 6. Post-apply validation fails

Separate:

```text
ALB direct
CloudFront /assets/*
CloudFront /health
S3 direct
Target group health
```

## 7. Drift detection fails

Exit code:

```text
0 = no drift
1 = error
2 = changes detected
```

If drift is detected, do not auto-apply.
Open issue or PR and review plan.

## Golden rule

Pipeline failure should produce an actionable artifact: plan, log, report, or validation output.
EOF

````

---

# 23. Create CI/CD Production Runbook

```bash id="prod-runbook"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/runbooks/production-cicd-iac-runbook.md <<'EOF'
# Production CI/CD for IaC Runbook

## PR workflow

Required:

```text
terraform fmt -check
terraform validate
terraform plan
ansible syntax check
policy checks
security checks
````

## Apply workflow

Required:

```text
manual trigger or protected branch
saved plan
plan artifact
environment approval
apply saved plan
post-apply validation
report artifact
```

## Environment protection

Use:

* required reviewers
* branch restrictions
* separate environments for dev/staging/prod
* separate IAM roles per environment

## AWS account strategy

Recommended:

```text
dev account
staging account
prod account
```

or at least separate roles and strong approval gates.

## State strategy

Recommended:

* separate backend keys per environment
* state locking
* encryption
* versioning
* no local state in CI

## Destroy strategy

Destroy should be:

* separate workflow
* manual
* protected environment
* plan-only first
* require explicit approval
* heavily logged

## Drift strategy

Drift detection should:

* run on schedule
* create report
* notify team
* not auto-remediate without approval

## Golden rule

The closer the environment is to production, the slower and more controlled the pipeline should become.
EOF

````

---

# 24. Create Workflow Audit Script

```bash id="audit-script"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/audit-github-actions-iac.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== GitHub Actions IaC Workflow Audit ====="

WORKFLOW_DIR=".github/workflows"

test -d "$WORKFLOW_DIR" || {
  echo "Missing .github/workflows"
  exit 1
}

required_workflows=(
  "iac-pr-check.yml"
  "iac-apply-dev.yml"
  "iac-drift-detect.yml"
  "iac-destroy-plan-dev.yml"
)

for workflow in "${required_workflows[@]}"; do
  file="$WORKFLOW_DIR/$workflow"
  echo "Checking $file"
  test -f "$file" || {
    echo "Missing workflow: $workflow"
    exit 1
  }

  grep -q "permissions:" "$file" || {
    echo "Missing permissions block in $workflow"
    exit 1
  }

  grep -q "id-token: write" "$file" || {
    echo "Missing id-token: write in $workflow"
    exit 1
  }

  grep -q "concurrency:" "$file" || {
    echo "Missing concurrency in $workflow"
    exit 1
  }
done

grep -q "environment: dev" "$WORKFLOW_DIR/iac-apply-dev.yml" || {
  echo "Apply workflow missing environment: dev"
  exit 1
}

echo
echo "GitHub Actions IaC workflow audit passed."
EOF

chmod +x 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/audit-github-actions-iac.sh
````

Run:

```bash id="run-audit"
./12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/audit-github-actions-iac.sh
```

---

# 25. Create Lesson Validation Script

```bash id="lesson-validation"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/validate-lesson-12-14.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.14 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.14-cicd-for-iac"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/policies"
test -d "$LESSON/github-actions"
test -d "$LESSON/jenkins"
test -d "$BASE/ci/scripts"
test -d ".github/workflows"

test -f "$LESSON/notes/cicd-for-iac-mental-model.md"
test -f "$LESSON/notes/never-confuse-cicd-iac-points.md"
test -f "$LESSON/notes/aws-oidc-setup-notes.md"
test -f "$LESSON/notes/pipeline-security-guardrails.md"

test -f "$LESSON/policies/github-actions-oidc-trust-policy-example.json"
test -f "$LESSON/policies/github-actions-iac-dev-policy-example.json"

test -f "$LESSON/runbooks/github-actions-iac-setup-runbook.md"
test -f "$LESSON/runbooks/cicd-iac-troubleshooting-runbook.md"
test -f "$LESSON/runbooks/production-cicd-iac-runbook.md"

test -f "$LESSON/jenkins/Jenkinsfile.iac"
test -f "$LESSON/jenkins/jenkins-iac-pipeline-notes.md"

test -x "$BASE/ci/scripts/terraform-ci-plan.sh"
test -x "$BASE/ci/scripts/terraform-ci-apply.sh"
test -x "$BASE/ci/scripts/ansible-ci-check.sh"
test -x "$BASE/ci/scripts/post-apply-ci-validate.sh"
test -x "$BASE/ci/scripts/terraform-drift-detect.sh"
test -x "$BASE/ci/scripts/terraform-destroy-plan.sh"

test -x "$LESSON/scripts/audit-github-actions-iac.sh"

test -f ".github/workflows/iac-pr-check.yml"
test -f ".github/workflows/iac-apply-dev.yml"
test -f ".github/workflows/iac-drift-detect.yml"
test -f ".github/workflows/iac-destroy-plan-dev.yml"

jq . "$LESSON/policies/github-actions-oidc-trust-policy-example.json" >/dev/null
jq . "$LESSON/policies/github-actions-iac-dev-policy-example.json" >/dev/null

terraform version >/dev/null
ansible --version >/dev/null
python3 --version >/dev/null

"$LESSON/scripts/audit-github-actions-iac.sh"

echo
echo "Checking shell scripts syntax..."
bash -n "$BASE/ci/scripts/terraform-ci-plan.sh"
bash -n "$BASE/ci/scripts/terraform-ci-apply.sh"
bash -n "$BASE/ci/scripts/ansible-ci-check.sh"
bash -n "$BASE/ci/scripts/post-apply-ci-validate.sh"
bash -n "$BASE/ci/scripts/terraform-drift-detect.sh"
bash -n "$BASE/ci/scripts/terraform-destroy-plan.sh"

echo
echo "Lesson 12.14 validation passed."
EOF

chmod +x 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/validate-lesson-12-14.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/validate-lesson-12-14.sh
```

---

# 26. Create Cleanup Script

```bash id="cleanup-script"
cat > 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/cleanup-lesson-12-14-local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.14 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete
rm -rf "$BASE/ansible/.ansible_facts"
find "$BASE/ansible" -name "*.retry" -delete

echo "Local CI/CD artifacts cleaned."
echo "AWS resources were not destroyed."
EOF

chmod +x 12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/cleanup-lesson-12-14-local.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/cleanup-lesson-12-14-local.sh
```

---

# 27. Local Simulation Commands

Before pushing workflows, simulate the important pieces locally.

```bash id="local-sim"
cd ~/devops-masterclass

export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
export ENVIRONMENT=dev
export PLAN_NAME=tfplan-local-ci

./12-terraform-ansible-iac/ci/scripts/ansible-ci-check.sh

./12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh
```

Apply locally only after reviewing:

```bash id="local-apply"
./12-terraform-ansible-iac/ci/scripts/terraform-ci-apply.sh

./12-terraform-ansible-iac/ci/scripts/post-apply-ci-validate.sh
```

Drift detection locally:

```bash id="local-drift"
./12-terraform-ansible-iac/ci/scripts/terraform-drift-detect.sh
```

Destroy plan only:

```bash id="local-destroy-plan"
./12-terraform-ansible-iac/ci/scripts/terraform-destroy-plan.sh
```

---

# 28. GitHub Repository Setup Checklist

Before pushing:

```text id="github-checklist"
1. AWS OIDC provider exists.
2. GitHub Actions IAM role exists.
3. Trust policy matches your GitHub owner/repo.
4. IAM permission policy is attached.
5. GitHub repository variable AWS_ROLE_ARN exists.
6. GitHub environment dev exists.
7. Environment dev has required reviewers.
8. Branch protection requires PR checks.
9. Backend S3 bucket and lockfile permissions are working.
10. Terraform dev backend config exists.
```

Push:

```bash id="push"
git add .github 12-terraform-ansible-iac

git commit -m "feat: add CI/CD pipelines for Terraform and Ansible IaC"

git push
```

---

# 29. Common Errors and Fixes

## Error 1 — OIDC assume role failed

```text id="oidc-error"
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Check:

```text id="oidc-checks"
workflow has id-token: write
AWS_ROLE_ARN variable is correct
OIDC provider exists
trust policy repo matches exactly
branch/environment condition matches exactly
```

---

## Error 2 — Apply job never starts

Cause:

```text id="apply-wait"
GitHub environment approval is pending.
```

Fix:

```text id="apply-fix"
Approve the deployment in GitHub Actions UI.
Check environment protection rules.
```

---

## Error 3 — Terraform plan succeeds but apply fails

Check:

```text id="apply-fail-checks"
saved plan was uploaded
saved plan was downloaded to correct path
apply job uses same commit
backend state lock is available
AWS role still has permissions
CloudFront/S3/ALB permissions exist
```

---

## Error 4 — Drift workflow fails

Interpretation:

```text id="drift-interpret"
exit 0:
  no drift

exit 1:
  plan error

exit 2:
  drift or pending changes
```

Do not auto-apply drift fixes.

---

## Error 5 — Ansible validation fails after apply

Separate the stack:

```bash id="validation-debug"
curl -I "http://ALB_DNS/health"
curl -I "https://CLOUDFRONT_DOMAIN/assets/index.html"
curl -I "https://CLOUDFRONT_DOMAIN/health"
```

Then debug:

```text id="validation-layers"
ALB direct:
  target group, EC2, SG, nginx

CloudFront /assets:
  S3, OAC, bucket policy, behavior

CloudFront /health:
  ALB origin, cache behavior, origin protocol
```

---

# 30. Cost Safety

CI/CD can accidentally keep billable resources alive.

Check:

```bash id="cost-check"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table

aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code}' \
  --output table

aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}' \
  --output table
```

Destroy full dev stack when stopping:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

---

# 31. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is CI for IaC?
What is CD for IaC?
Why should PRs run plan but not apply?
Why use terraform plan -out?
Why apply a saved plan?
Why does saved-plan apply need external approval?
What are GitHub Actions environments?
Why use required reviewers?
What is OIDC?
Why avoid long-lived AWS keys?
What GitHub permission is required for OIDC?
Why use concurrency groups?
What should drift detection do?
Why should drift detection not auto-apply?
What should a destroy workflow do?
How does Ansible fit after Terraform apply?
What artifacts should an IaC pipeline keep?
How would you implement the same flow in Jenkins?
```

Strong interview answer:

```text id="interview-answer"
For IaC CI/CD, I split validation from deployment. Pull requests run Terraform fmt, validate, plan, and Ansible syntax checks, but they do not apply infrastructure. For deployment, I generate a saved Terraform plan, publish plan artifacts, require environment approval, and then apply the exact saved plan. After apply, I export Terraform outputs, generate Ansible inventory and group variables, and run Ansible-based post-apply validation against ALB and CloudFront endpoints.

For AWS authentication, I prefer GitHub Actions OIDC instead of storing long-lived AWS access keys. The workflow gets short-lived credentials by assuming a scoped AWS IAM role, and the workflow declares least-privilege GitHub permissions such as contents read and id-token write. I use GitHub environments, required reviewers, branch protection, and concurrency groups to prevent unreviewed or overlapping applies.

I also add separate drift detection and destroy-plan workflows. Drift detection reports differences but does not auto-remediate. Destroy is manual, protected, and plan-only by default. The pipeline archives Terraform plan text, JSON, outputs, generated Ansible inventory, and validation reports so every infrastructure change has review and audit evidence.
```

Resume bullet:

```text id="resume-bullet"
Built production-style CI/CD pipelines for Terraform and Ansible IaC using GitHub Actions and Jenkins patterns, including OIDC-based AWS authentication, least-privilege workflow permissions, Terraform fmt/validate/plan, saved plan artifacts, protected environment approval before apply, Ansible sanity and post-apply validation, ALB/CloudFront endpoint checks, drift detection, safe destroy planning, concurrency controls, CI/CD runbooks, pipeline security guardrails, and audit-ready artifact handling.
```

---

# 32. Commit Lesson 12.14

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/cleanup-lesson-12-14-local.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.14-cicd-for-iac/scripts/validate-lesson-12-14.sh
```

Review:

```bash id="review"
git status

find .github/workflows -maxdepth 1 -type f | sort
find 12-terraform-ansible-iac/12.14-cicd-for-iac -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/ci -maxdepth 3 -type f | sort
```

Commit:

```bash id="commit"
git add .github 12-terraform-ansible-iac

git commit -m "feat: add CI/CD for Terraform and Ansible IaC"

git push
```

---

# 33. Next Lesson

```text id="next-lesson"
12.15 — Policy Checks for IaC
```

We will build:

```text id="next-topics"
policy-as-code mental model
Terraform plan JSON checks
deny public SSH
deny broad sensitive ports
require tags
require encrypted S3
require S3 public access block
require IMDSv2
require approved regions
detect CloudFront/S3 unsafe settings
OPA/Conftest-style policy concept
Checkov/tfsec-style scanner concept
custom Python policy gate
CI/CD policy gate integration
policy violation reports
production guardrail runbooks
```

[1]: https://developer.hashicorp.com/terraform/cli/commands/plan?utm_source=chatgpt.com "terraform plan command reference | Terraform | HashiCorp Developer"
[2]: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments?utm_source=chatgpt.com "Deployments and environments - GitHub Docs"
[3]: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws?ref=engineering.ziphq.com&utm_source=chatgpt.com "Configuring OpenID Connect in Amazon Web Services - GitHub Docs"
[4]: https://developer.hashicorp.com/terraform/cli/code?utm_source=chatgpt.com "Format and validate Terraform configuration using the Terraform CLI | Terraform | HashiCorp Developer"
[5]: https://github.com/hashicorp/setup-terraform?utm_source=chatgpt.com "GitHub - hashicorp/setup-terraform: Sets up Terraform CLI in your GitHub Actions workflow. · GitHub"
