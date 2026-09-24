# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.11 — IAM Troubleshooting with Terraform

In Lesson 12.10, you built:

```text id="recap-12-10"
private S3 assets bucket
S3 encryption/versioning/public-access-block
CloudFront OAC
CloudFront distribution
S3 origin
ALB origin
bucket policy scoped to CloudFront distribution ARN
CloudFront validation and 403 debugging
```

Now we focus on one of the most important AWS production skills:

```text id="lesson-focus"
IAM troubleshooting
AccessDenied debugging
iam:PassRole
identity policies
resource policies
trust policies
permission boundaries
SCP concept
CloudFront OAC bucket policy debugging
Terraform caller permission checks
```

AWS evaluates requests by combining identity-based policies, resource-based policies, permissions boundaries, service control policies, session policies, and explicit denies. The most important rule is: **an explicit deny overrides an allow**. ([AWS Documentation][1])

---

# 1. Goal

Build a practical IAM troubleshooting toolkit for your Terraform AWS stack.

You will create:

```text id="goal"
IAM mental model notes
AccessDenied troubleshooting runbook
iam:PassRole debug workflow
encoded authorization failure decoder
Terraform caller permission checker
EC2 role permission checker
CloudFront OAC bucket policy checker
S3 bucket policy debug script
policy simulator script
least-privilege policy examples
safe broken-scenario notes
validation and cleanup scripts
```

This lesson will **not intentionally break your AWS account permissions**. Instead, you will build safe scripts and runbooks that help diagnose real failures.

---

# 2. What You Will Learn

```text id="lesson-map"
12.11.1   IAM mental model
12.11.2   principal, action, resource, condition
12.11.3   identity-based policy
12.11.4   resource-based policy
12.11.5   trust policy
12.11.6   permission boundary
12.11.7   SCP concept
12.11.8   session policy concept
12.11.9   explicit deny vs implicit deny
12.11.10  Terraform caller permissions
12.11.11  iam:PassRole debugging
12.11.12  EC2 instance role debugging
12.11.13  S3 bucket policy debugging
12.11.14  CloudFront OAC SourceArn debugging
12.11.15  encoded authorization failure message
12.11.16  AWS CLI policy simulation
12.11.17  least-privilege examples
12.11.18  production IAM runbooks
```

---

# 3. Never Confuse These

## Identity Policy vs Resource Policy

```text id="identity-vs-resource"
Identity-based policy:
  attached to IAM user, group, or role

Resource-based policy:
  attached to resource such as S3 bucket, KMS key, SQS queue, Lambda function, or role trust policy
```

For your stack:

```text id="examples"
Terraform caller needs identity permissions:
  ec2:RunInstances
  iam:CreateRole
  iam:PassRole
  s3:PutBucketPolicy
  cloudfront:CreateDistribution

S3 bucket uses resource policy:
  allow cloudfront.amazonaws.com to s3:GetObject
  only from your CloudFront distribution ARN
```

AWS documents identity-based and resource-based policies as separate policy types that can interact during authorization decisions. ([AWS Documentation][2])

---

## Trust Policy vs Permission Policy

```text id="trust-vs-permission"
Trust policy:
  who can assume this role?

Permission policy:
  what can this role do after it is assumed?
```

For EC2:

```text id="ec2-trust"
Trust policy:
  ec2.amazonaws.com can assume role

Permission policy:
  role can use Systems Manager permissions
```

Your IAM module already created this trust policy:

```json id="ec2-trust-json"
{
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  }
}
```

---

## `iam:PassRole` vs `sts:AssumeRole`

```text id="passrole-vs-assume"
iam:PassRole:
  caller is allowed to pass a role to an AWS service

sts:AssumeRole:
  principal assumes a role and receives temporary credentials
```

When Terraform launches EC2 with an instance profile, the Terraform caller needs `iam:PassRole` for the EC2 role. AWS explicitly documents that a user must be allowed to pass the role to EC2 when setting up an application that uses an EC2 instance role. ([AWS Documentation][3])

---

## Explicit Deny vs Missing Allow

```text id="deny-vs-missing"
explicit deny:
  policy says Deny

implicit deny:
  no policy allows the action
```

Both result in failure, but the fix is different:

```text id="fix-difference"
explicit deny:
  remove or narrow the deny

implicit deny:
  add the required allow
```

---

## Terraform Caller Role vs EC2 Runtime Role

```text id="caller-vs-runtime"
Terraform caller role:
  the identity running terraform apply

EC2 runtime role:
  IAM role attached to the EC2 instance through instance profile
```

Do not debug EC2 runtime permissions by only looking at your own IAM user.

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.11-iam-troubleshooting/{notes,scripts,runbooks,reports,policies,examples}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.11-iam-troubleshooting
```

---

# 5. Create IAM Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/notes/iam-mental-model.md
```

Paste:

````markdown id="mental-note-content"
# IAM Mental Model

## IAM question

Every IAM problem can be reduced to:

```text
Who is calling?
What action?
On which resource?
Under what conditions?
Which policy allowed or denied it?
````

## Request components

Principal:
IAM user, IAM role, AWS service, federated identity, or assumed role session

Action:
API operation such as ec2:RunInstances or s3:GetObject

Resource:
ARN or wildcard resource the action targets

Condition:
extra constraints such as aws:SourceArn, aws:RequestedRegion, aws:PrincipalArn, or ec2:InstanceType

## Main policy types

Identity policy:
attached to user, group, or role

Resource policy:
attached to resource

Trust policy:
resource-based policy on IAM role controlling who can assume it

Permissions boundary:
maximum permission boundary for a role/user

SCP:
organization-level maximum permission boundary

Session policy:
temporary session restriction

## Decision model

Explicit deny wins.
Then AWS looks for an allow.
If no allow exists, access is denied.

## Golden rule

Do not debug IAM by guessing.
Identify principal, action, resource, condition, and policy type.

````

---

# 6. Create Never-Forget Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/notes/never-confuse-iam-points.md
````

Paste:

```markdown id="never-note-content"
# Never Forget — IAM Troubleshooting

## 1. AccessDenied is not always IAM user policy

It can come from:

- identity policy
- resource policy
- trust policy
- permissions boundary
- SCP
- session policy
- VPC endpoint policy
- KMS key policy
- S3 block public access behavior
- service-specific condition

## 2. Explicit deny always wins

If an explicit Deny matches, adding more Allows will not fix it.

## 3. iam:PassRole is common with EC2

Launching EC2 with an IAM role requires the caller to pass that role.

## 4. EC2 role and Terraform caller are different

Terraform caller creates infrastructure.
EC2 role is used by the running instance.

## 5. Role trust policy is not permissions

Trust policy answers:
  who can assume role?

Permissions policy answers:
  what can role do?

## 6. S3 bucket policy is a resource policy

For CloudFront OAC, bucket policy must allow CloudFront service principal with correct distribution SourceArn.

## 7. CloudFront OAC policy must match distribution ARN

Wrong account ID, wrong distribution ID, or wrong bucket ARN causes 403.

## 8. Decode encoded authorization messages when available

EC2 UnauthorizedOperation can include encoded authorization failure details.

## 9. AWS region can appear in IAM conditions

A policy may allow an action only in ap-south-1.

## 10. Least privilege is iterative

Start from required actions, test, reduce scope, and document why each permission exists.
```

---

# 7. Create IAM Troubleshooting Decision Tree

```bash id="decision-tree"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/notes/iam-troubleshooting-decision-tree.md
```

Paste:

````markdown id="decision-tree-content"
# IAM Troubleshooting Decision Tree

## Step 1 — Identify caller

```bash
aws sts get-caller-identity
````

Record:

* Account
* Arn
* UserId

## Step 2 — Identify failed action

Examples:

```text
ec2:RunInstances
iam:PassRole
s3:PutBucketPolicy
cloudfront:CreateDistribution
ssm:StartSession
```

## Step 3 — Identify resource

Examples:

```text
arn:aws:ec2:ap-south-1:ACCOUNT:instance/*
arn:aws:iam::ACCOUNT:role/devops-masterclass-dev-ec2-role
arn:aws:s3:::bucket-name/*
arn:aws:cloudfront::ACCOUNT:distribution/DISTRIBUTION_ID
```

## Step 4 — Identify policy type

Ask:

* Is caller missing identity permission?
* Is resource policy denying?
* Is trust policy wrong?
* Is iam:PassRole missing?
* Is permission boundary limiting?
* Is SCP limiting?
* Is session policy limiting?
* Is service condition failing?

## Step 5 — Look for explicit deny

Search for:

```json
"Effect": "Deny"
```

## Step 6 — Simulate when possible

Use:

```bash
aws iam simulate-principal-policy
```

## Step 7 — Fix narrowly

Do not add AdministratorAccess to fix one missing action.

## Golden rule

IAM troubleshooting is evidence-driven, not trial-and-error.

````

---

# 8. Create Terraform Caller Context Script

```bash id="caller-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-caller-context.sh
````

Paste:

```bash id="caller-script-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== IAM Caller Context ====="

echo
echo "AWS CLI identity:"
aws sts get-caller-identity

echo
echo "AWS configure list:"
aws configure list

echo
echo "Region:"
echo "AWS_REGION=${AWS_REGION:-unset}"
echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-unset}"

CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

echo
echo "Caller ARN:"
echo "$CALLER_ARN"

echo
echo "Account ID:"
echo "$ACCOUNT_ID"

echo
echo "Caller type hint:"
case "$CALLER_ARN" in
  *":assumed-role/"*)
    echo "You are using an assumed role session."
    ;;
  *":user/"*)
    echo "You are using an IAM user."
    ;;
  *":root")
    echo "You are using root. Avoid root for Terraform."
    ;;
  *)
    echo "Unknown or federated caller type."
    ;;
esac
```

Make executable:

```bash id="chmod-caller"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-caller-context.sh
```

Run:

```bash id="run-caller"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-caller-context.sh
```

---

# 9. Create Encoded Authorization Message Decoder

Some AWS authorization failures include an encoded message. AWS STS provides `decode-authorization-message` to decode extra failure details, but the caller must have permission to run that STS action. ([AWS Documentation][4])

```bash id="decoder-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/decode-authorization-message.sh
```

Paste:

```bash id="decoder-content"
#!/usr/bin/env bash
set -euo pipefail

ENCODED_MESSAGE="${1:-}"

if [ -z "$ENCODED_MESSAGE" ]; then
  echo "Usage:"
  echo "$0 '<encoded-authorization-failure-message>'"
  echo
  echo "Example:"
  echo "$0 'AQICAHj...'"
  exit 1
fi

echo "===== Decode AWS Authorization Message ====="

aws sts decode-authorization-message \
  --encoded-message "$ENCODED_MESSAGE" \
  --query DecodedMessage \
  --output text | jq .
```

Make executable:

```bash id="chmod-decoder"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/decode-authorization-message.sh
```

Usage:

```bash id="run-decoder"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/decode-authorization-message.sh "PASTE_ENCODED_MESSAGE_HERE"
```

If this fails with AccessDenied:

```text id="decode-denied"
Your caller needs sts:DecodeAuthorizationMessage.
```

Minimal permission example:

```json id="decode-policy"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDecodeAuthorizationMessages",
      "Effect": "Allow",
      "Action": "sts:DecodeAuthorizationMessage",
      "Resource": "*"
    }
  ]
}
```

---

# 10. Create Terraform Caller Permission Policy Example

This is not automatically applied. It is a learning/reference policy for your Module 12 dev stack.

```bash id="caller-policy"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/policies/terraform-caller-dev-policy-example.json
```

Paste:

```json id="caller-policy-content"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformReadContext",
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
      "Sid": "TerraformVpcEc2AlbManagementForDev",
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
      "Sid": "TerraformAlbManagementForDev",
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
      "Sid": "TerraformS3AssetsManagementForDev",
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
      "Sid": "TerraformCloudFrontManagementForDev",
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
      "Sid": "TerraformIamEc2RoleManagementForDev",
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
      "Sid": "AllowPassOnlyDevEc2RoleToEc2",
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
      "Sid": "AllowDecodeAuthorizationMessages",
      "Effect": "Allow",
      "Action": "sts:DecodeAuthorizationMessage",
      "Resource": "*"
    }
  ]
}
```

Important:

```text id="policy-warning"
This is a lab reference policy.
Do not blindly attach it in production.
Review, scope, and adapt it to your account and organization controls.
```

---

# 11. Create `iam:PassRole` Debug Script

```bash id="passrole-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

Paste:

```bash id="passrole-content"
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

echo "===== iam:PassRole Context Check ====="
echo "Environment: $ENVIRONMENT"

CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_NAME="$(terraform output -json iam_contract | jq -r '.instance_role_name')"
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

echo "Caller ARN: $CALLER_ARN"
echo "Role name: $ROLE_NAME"
echo "Role ARN: $ROLE_ARN"
echo

echo "IAM role trust policy:"
aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json | jq .

echo
echo "Attached role policies:"
aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --output table

echo
echo "Simulating caller ability to pass role to EC2:"
aws iam simulate-principal-policy \
  --policy-source-arn "$CALLER_ARN" \
  --action-names iam:PassRole \
  --resource-arns "$ROLE_ARN" \
  --context-entries ContextKeyName=iam:PassedToService,ContextKeyValues=ec2.amazonaws.com,ContextKeyType=string \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision,Missing:MissingContextValues,Matched:MatchedStatements}' \
  --output json
```

Make executable:

```bash id="chmod-passrole"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

Run after your dev stack exists:

```bash id="run-passrole"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

If the simulation says:

```text id="implicit-deny"
EvalDecision = implicitDeny
```

then the caller does not have an Allow for `iam:PassRole` on that role.

If it says:

```text id="explicit-deny"
EvalDecision = explicitDeny
```

then there is a matching deny. Adding another allow will not fix it.

---

# 12. Create EC2 Runtime Role Debug Script

```bash id="ec2-role-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh
```

Paste:

```bash id="ec2-role-content"
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

echo "===== EC2 Runtime Role Check ====="
echo "Environment: $ENVIRONMENT"

INSTANCE_ID="$(terraform output -raw first_ec2_instance_id)"
ROLE_NAME="$(terraform output -json iam_contract | jq -r '.instance_role_name')"
PROFILE_NAME="$(terraform output -json iam_contract | jq -r '.instance_profile_name')"

echo "Instance ID: $INSTANCE_ID"
echo "Role name: $ROLE_NAME"
echo "Instance profile: $PROFILE_NAME"

echo
echo "Instance IAM profile attachment:"
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --output json

echo
echo "Instance profile:"
aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --output json | jq '.InstanceProfile | {InstanceProfileName, Arn, Roles: [.Roles[].RoleName]}'

echo
echo "Role trust policy:"
aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json | jq .

echo
echo "Attached role policies:"
aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --output table

echo
echo "SSM managed instance status:"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,PlatformName:PlatformName,AgentVersion:AgentVersion}' \
  --output table || true

echo
echo "Expected attached managed policy:"
echo "AmazonSSMManagedInstanceCore"
```

Make executable:

```bash id="chmod-ec2-role"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh
```

Run:

```bash id="run-ec2-role"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh
```

EC2 uses instance profiles as the container for IAM role information attached to instances. ([AWS Documentation][5])

---

# 13. Create CloudFront OAC Bucket Policy Debug Script

```bash id="oac-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh
```

Paste:

```bash id="oac-content"
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

echo "===== CloudFront OAC Bucket Policy Check ====="
echo "Environment: $ENVIRONMENT"

CF_ID="$(terraform output -raw cloudfront_distribution_id)"
S3_BUCKET="$(terraform output -raw assets_bucket_name)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
EXPECTED_SOURCE_ARN="arn:aws:cloudfront::$ACCOUNT_ID:distribution/$CF_ID"

echo "CloudFront ID: $CF_ID"
echo "S3 bucket: $S3_BUCKET"
echo "Expected SourceArn: $EXPECTED_SOURCE_ARN"

echo
echo "Distribution origins:"
aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'DistributionConfig.Origins.Items[].{Id:Id,DomainName:DomainName,OriginAccessControlId:OriginAccessControlId}' \
  --output json

echo
echo "Bucket policy:"
POLICY="$(aws s3api get-bucket-policy --bucket "$S3_BUCKET" --query Policy --output text)"
echo "$POLICY" | jq .

echo
echo "Checking expected CloudFront service principal..."
echo "$POLICY" | jq -e '.Statement[] | select(.Principal.Service=="cloudfront.amazonaws.com")' >/dev/null
echo "OK: cloudfront.amazonaws.com principal found."

echo
echo "Checking expected SourceArn..."
echo "$POLICY" | jq -e --arg arn "$EXPECTED_SOURCE_ARN" '.Statement[] | select(.Condition.StringEquals."AWS:SourceArn"==$arn)' >/dev/null
echo "OK: expected AWS:SourceArn found."

echo
echo "Checking s3:GetObject action..."
echo "$POLICY" | jq -e '.Statement[] | select((.Action=="s3:GetObject") or (.Action[]?=="s3:GetObject"))' >/dev/null
echo "OK: s3:GetObject found."

echo
echo "Checking direct S3 access should not be public:"
set +e
curl -I "https://$S3_BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html"
set -e

echo
echo "Checking CloudFront access:"
CF_DOMAIN="$(terraform output -raw cloudfront_distribution_domain_name)"
curl -fsSI "https://$CF_DOMAIN/assets/index.html"

echo
echo "CloudFront OAC bucket policy check completed."
```

Make executable:

```bash id="chmod-oac"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh
```

Run:

```bash id="run-oac"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh
```

For CloudFront OAC with S3, AWS’s example bucket policy uses the CloudFront service principal and an `AWS:SourceArn` condition scoped to the distribution ARN. ([AWS Documentation][6])

---

# 14. Create S3 Policy Simulator Script

This checks whether the current caller can read or modify the assets bucket policy.

```bash id="s3-sim-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/simulate-s3-policy-access.sh
```

Paste:

```bash id="s3-sim-content"
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

CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
S3_BUCKET="$(terraform output -raw assets_bucket_name)"

echo "===== S3 Policy Access Simulation ====="
echo "Environment: $ENVIRONMENT"
echo "Caller: $CALLER_ARN"
echo "Bucket: $S3_BUCKET"

aws iam simulate-principal-policy \
  --policy-source-arn "$CALLER_ARN" \
  --action-names \
    s3:GetBucketPolicy \
    s3:PutBucketPolicy \
    s3:GetObject \
    s3:PutObject \
    s3:ListBucket \
  --resource-arns \
    "arn:aws:s3:::$S3_BUCKET" \
    "arn:aws:s3:::$S3_BUCKET/*" \
  --query 'EvaluationResults[].{Action:EvalActionName,Resource:EvalResourceName,Decision:EvalDecision,Missing:MissingContextValues}' \
  --output table
```

Make executable:

```bash id="chmod-s3-sim"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/simulate-s3-policy-access.sh
```

Run:

```bash id="run-s3-sim"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/simulate-s3-policy-access.sh
```

---

# 15. Create Terraform Apply Permission Precheck Script

This is a practical precheck before running Terraform plans/applies.

```bash id="precheck-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/terraform-permission-precheck.sh
```

Paste:

```bash id="precheck-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${AWS_REGION:-ap-south-1}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

echo "===== Terraform Permission Precheck ====="
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/devops-masterclass-$ENVIRONMENT-ec2-role"

echo "Caller: $CALLER_ARN"
echo "Expected EC2 role ARN: $ROLE_ARN"

ACTIONS=(
  "ec2:DescribeVpcs"
  "ec2:CreateVpc"
  "ec2:RunInstances"
  "ec2:CreateSecurityGroup"
  "elasticloadbalancing:CreateLoadBalancer"
  "elasticloadbalancing:CreateTargetGroup"
  "s3:CreateBucket"
  "s3:PutBucketPolicy"
  "cloudfront:CreateDistribution"
  "cloudfront:CreateOriginAccessControl"
  "iam:CreateRole"
  "iam:CreateInstanceProfile"
  "iam:PassRole"
  "sts:DecodeAuthorizationMessage"
)

echo
echo "Simulating broad action access."
echo "Note: This does not perfectly model every service condition/resource combination, but catches many obvious denies."

aws iam simulate-principal-policy \
  --policy-source-arn "$CALLER_ARN" \
  --action-names "${ACTIONS[@]}" \
  --resource-arns "*" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision,Missing:MissingContextValues}' \
  --output table || true

echo
echo "Simulating iam:PassRole specifically with iam:PassedToService condition:"
aws iam simulate-principal-policy \
  --policy-source-arn "$CALLER_ARN" \
  --action-names iam:PassRole \
  --resource-arns "$ROLE_ARN" \
  --context-entries ContextKeyName=iam:PassedToService,ContextKeyValues=ec2.amazonaws.com,ContextKeyType=string \
  --query 'EvaluationResults[].{Action:EvalActionName,Resource:EvalResourceName,Decision:EvalDecision,Missing:MissingContextValues}' \
  --output table || true

echo
echo "Precheck completed."
```

Make executable:

```bash id="chmod-precheck"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/terraform-permission-precheck.sh
```

Run:

```bash id="run-precheck"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/terraform-permission-precheck.sh
```

---

# 16. Create IAM Error Classifier Script

```bash id="classifier-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/classify-iam-error.sh
```

Paste:

```bash id="classifier-content"
#!/usr/bin/env bash
set -euo pipefail

ERROR_TEXT="${1:-}"

if [ -z "$ERROR_TEXT" ]; then
  echo "Usage:"
  echo "$0 'paste error text here'"
  exit 1
fi

echo "===== IAM Error Classifier ====="
echo "$ERROR_TEXT"
echo

case "$ERROR_TEXT" in
  *"iam:PassRole"*|*"PassRole"*)
    cat <<'EOF'
Likely issue:
  Terraform caller is missing iam:PassRole for the EC2 role.

Check:
  ./scripts/check-passrole-context.sh

Fix:
  Allow iam:PassRole on the specific role, with iam:PassedToService = ec2.amazonaws.com.
EOF
    ;;
  *"UnauthorizedOperation"*|*"encoded authorization failure message"*)
    cat <<'EOF'
Likely issue:
  EC2 authorization failure.

Check:
  Look for encoded authorization failure message.
  Decode with:
    ./scripts/decode-authorization-message.sh '<encoded-message>'

Fix:
  Add missing EC2 permission or remove matching explicit deny.
EOF
    ;;
  *"AccessDenied"*s3*|*s3*"AccessDenied"*)
    cat <<'EOF'
Likely issue:
  S3 identity policy, bucket policy, or block-public-access/resource policy mismatch.

Check:
  ./scripts/simulate-s3-policy-access.sh
  ./scripts/check-cloudfront-oac-policy.sh

Fix:
  Verify caller permissions and bucket policy.
EOF
    ;;
  *"cloudfront"*|"CloudFront"*|*"CreateDistribution"*)
    cat <<'EOF'
Likely issue:
  Missing CloudFront permissions or invalid OAC/distribution policy.

Check:
  cloudfront:GetDistribution
  cloudfront:GetDistributionConfig
  CloudFront OAC config
  S3 bucket policy SourceArn

Fix:
  Add least-privilege CloudFront actions required by Terraform.
EOF
    ;;
  *"AccessDenied"*|"not authorized"*)
    cat <<'EOF'
Generic AccessDenied.

Workflow:
  1. aws sts get-caller-identity
  2. identify failed action
  3. identify resource ARN
  4. check explicit deny
  5. simulate principal policy if possible
  6. inspect resource policy if resource supports one
EOF
    ;;
  *)
    cat <<'EOF'
No specific classifier matched.

Use generic IAM workflow:
  who -> action -> resource -> condition -> policy type -> deny/allow result.
EOF
    ;;
esac
```

Make executable:

```bash id="chmod-classifier"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/classify-iam-error.sh
```

Example:

```bash id="run-classifier"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/classify-iam-error.sh \
"User is not authorized to perform iam:PassRole on resource"
```

---

# 17. Create IAM Troubleshooting Report Script

```bash id="report-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-troubleshooting-report.sh
```

Paste:

````bash id="report-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"
OUT="$BASE/12.11-iam-troubleshooting/reports/$ENVIRONMENT-iam-report.md"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

CALLER_JSON="$(aws sts get-caller-identity --output json)"
CALLER_ARN="$(echo "$CALLER_JSON" | jq -r '.Arn')"
ACCOUNT_ID="$(echo "$CALLER_JSON" | jq -r '.Account')"

{
  echo "# IAM Troubleshooting Report — $ENVIRONMENT"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Caller"
  echo
  echo '```json'
  echo "$CALLER_JSON" | jq .
  echo '```'
  echo

  if [ -d "$ENV_DIR/.terraform" ]; then
    echo "## Terraform Outputs"
    echo
    pushd "$ENV_DIR" >/dev/null

    echo "### IAM contract"
    echo '```json'
    terraform output -json iam_contract 2>/dev/null | jq . || true
    echo '```'
    echo

    echo "### Security group contract"
    echo '```json'
    terraform output -json security_group_contract 2>/dev/null | jq . || true
    echo '```'
    echo

    echo "### Storage contract"
    echo '```json'
    terraform output -json storage_contract 2>/dev/null | jq . || true
    echo '```'
    echo

    echo "### CDN contract"
    echo '```json'
    terraform output -json cdn_contract 2>/dev/null | jq . || true
    echo '```'
    echo

    popd >/dev/null
  else
    echo "Terraform env not initialized: $ENV_DIR"
  fi

  echo "## Permission Simulation Summary"
  echo
  echo '```text'
  echo "Caller: $CALLER_ARN"
  echo "Account: $ACCOUNT_ID"
  echo "Run terraform-permission-precheck.sh for live simulation."
  echo '```'
} > "$OUT"

echo "IAM troubleshooting report written to:"
echo "$OUT"
````

Make executable:

```bash id="chmod-report"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-troubleshooting-report.sh
```

Run:

```bash id="run-report"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-troubleshooting-report.sh
```

---

# 18. Create Safe Broken Scenario Notes

```bash id="scenario-note"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/examples/broken-iam-scenarios.md
```

Paste:

````markdown id="scenario-content"
# Broken IAM Scenarios

These are safe scenario descriptions.
Do not intentionally break production IAM.

## Scenario 1 — EC2 RunInstances UnauthorizedOperation

Error:

```text
UnauthorizedOperation: You are not authorized to perform this operation.
Encoded authorization failure message: ...
````

Likely causes:

* missing ec2:RunInstances
* missing ec2:CreateTags
* missing ec2 permissions on subnet/security group/AMI/volume
* explicit deny
* region condition mismatch
* permission boundary or SCP

Debug:

```bash
aws sts get-caller-identity
./scripts/decode-authorization-message.sh '<encoded-message>'
```

## Scenario 2 — iam:PassRole denied

Error:

```text
User is not authorized to perform iam:PassRole
```

Likely cause:

Terraform caller cannot pass EC2 role to EC2.

Fix pattern:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/devops-masterclass-dev-ec2-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

## Scenario 3 — SSM instance not online

Likely causes:

* instance profile missing
* EC2 role missing AmazonSSMManagedInstanceCore
* no outbound internet path
* SSM agent not running
* private subnet without NAT/VPC endpoints

Debug:

```bash
./scripts/check-ec2-runtime-role.sh
```

## Scenario 4 — CloudFront S3 403

Likely causes:

* missing object
* bucket policy SourceArn wrong
* OAC not attached
* wrong origin domain
* using website endpoint
* object encrypted with KMS key CloudFront cannot use

Debug:

```bash
./scripts/check-cloudfront-oac-policy.sh
```

## Scenario 5 — Terraform can create bucket but cannot add policy

Likely cause:

Caller has s3:CreateBucket but lacks s3:PutBucketPolicy.

Debug:

```bash
./scripts/simulate-s3-policy-access.sh
```

## Golden rule

Classify the failure before changing permissions.

````

---

# 19. Create Production IAM Runbook

```bash id="prod-runbook"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/runbooks/production-iam-troubleshooting-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production IAM Troubleshooting Runbook

## 1. Capture the error

Save:

- full error message
- timestamp
- AWS account
- region
- Terraform command
- Terraform workspace
- caller ARN
- failed action
- resource ARN
- encoded authorization message if present

## 2. Identify caller

```bash
aws sts get-caller-identity
````

## 3. Identify action and resource

Example:

```text
Action: iam:PassRole
Resource: arn:aws:iam::ACCOUNT:role/devops-masterclass-dev-ec2-role
```

## 4. Determine policy type

Check:

* identity policy
* resource policy
* trust policy
* permission boundary
* SCP
* session policy
* service-specific condition
* VPC endpoint policy
* KMS key policy

## 5. Decode authorization message

```bash
aws sts decode-authorization-message \
  --encoded-message 'ENCODED_MESSAGE' \
  --query DecodedMessage \
  --output text | jq .
```

## 6. Simulate principal policy

```bash
aws iam simulate-principal-policy \
  --policy-source-arn CALLER_ARN \
  --action-names ACTION \
  --resource-arns RESOURCE_ARN
```

## 7. Fix narrowly

Bad fix:

```text
Attach AdministratorAccess.
```

Better fix:

```text
Add the exact missing action on the exact required resource with required condition.
```

## 8. Validate

Run:

```bash
terraform plan
terraform apply
aws cli validation command
```

## 9. Document

Record:

* root cause
* policy change
* risk
* rollback
* validation evidence

## Golden rule

Every IAM fix should be explainable as:
principal needs action on resource under condition.

````

---

# 20. Create `iam:PassRole` Runbook

```bash id="passrole-runbook"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/runbooks/iam-passrole-runbook.md
````

Paste:

````markdown id="passrole-runbook-content"
# iam:PassRole Troubleshooting Runbook

## Symptom

```text
User is not authorized to perform iam:PassRole
````

## Meaning

The caller is trying to pass an IAM role to an AWS service.

In this module, Terraform passes the EC2 role to EC2 through an instance profile.

## Check caller

```bash
aws sts get-caller-identity
```

## Check role

```bash
aws iam get-role --role-name ROLE_NAME
```

## Check instance profile

```bash
aws iam get-instance-profile --instance-profile-name PROFILE_NAME
```

## Simulate

```bash
aws iam simulate-principal-policy \
  --policy-source-arn CALLER_ARN \
  --action-names iam:PassRole \
  --resource-arns ROLE_ARN \
  --context-entries ContextKeyName=iam:PassedToService,ContextKeyValues=ec2.amazonaws.com,ContextKeyType=string
```

## Least-privilege fix pattern

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/devops-masterclass-dev-ec2-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

## Do not

```text
Allow iam:PassRole on *
```

unless there is a carefully governed platform role reason.

## Golden rule

iam:PassRole should usually be scoped to specific roles and services.

````

---

# 21. Create CloudFront OAC IAM Runbook

```bash id="oac-runbook"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/runbooks/cloudfront-oac-bucket-policy-runbook.md
````

Paste:

````markdown id="oac-runbook-content"
# CloudFront OAC Bucket Policy Runbook

## Symptom

CloudFront returns 403 for S3 asset path.

Example:

```bash
curl -I https://CLOUDFRONT_DOMAIN/assets/index.html
````

## Step 1 — Confirm object exists

```bash
aws s3 ls s3://BUCKET/assets/ --recursive
```

## Step 2 — Confirm direct S3 is private

```bash
curl -I https://BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html
```

Private bucket should not be publicly readable.

## Step 3 — Confirm distribution origin

```bash
aws cloudfront get-distribution-config \
  --id DISTRIBUTION_ID \
  --query 'DistributionConfig.Origins.Items'
```

Check:

* S3 origin domain is bucket regional domain
* OriginAccessControlId exists

## Step 4 — Confirm bucket policy

```bash
aws s3api get-bucket-policy --bucket BUCKET --query Policy --output text | jq .
```

Required:

```json
{
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::BUCKET/*",
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT:distribution/DISTRIBUTION_ID"
    }
  }
}
```

## Step 5 — Confirm behavior

```bash
aws cloudfront get-distribution-config \
  --id DISTRIBUTION_ID \
  --query 'DistributionConfig.CacheBehaviors.Items'
```

Check:

```text
/assets/* -> S3 origin
```

## Golden rule

OAC requires both CloudFront origin configuration and matching S3 bucket policy.

````

---

# 22. Create Lesson Validation Script

```bash id="validation-script"
nano 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/validate-lesson-12-11.sh
````

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.11 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.11-iam-troubleshooting"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/policies"
test -d "$LESSON/examples"

test -f "$LESSON/notes/iam-mental-model.md"
test -f "$LESSON/notes/never-confuse-iam-points.md"
test -f "$LESSON/notes/iam-troubleshooting-decision-tree.md"

test -f "$LESSON/policies/terraform-caller-dev-policy-example.json"
test -f "$LESSON/examples/broken-iam-scenarios.md"

test -f "$LESSON/runbooks/production-iam-troubleshooting-runbook.md"
test -f "$LESSON/runbooks/iam-passrole-runbook.md"
test -f "$LESSON/runbooks/cloudfront-oac-bucket-policy-runbook.md"

test -x "$LESSON/scripts/iam-caller-context.sh"
test -x "$LESSON/scripts/decode-authorization-message.sh"
test -x "$LESSON/scripts/check-passrole-context.sh"
test -x "$LESSON/scripts/check-ec2-runtime-role.sh"
test -x "$LESSON/scripts/check-cloudfront-oac-policy.sh"
test -x "$LESSON/scripts/simulate-s3-policy-access.sh"
test -x "$LESSON/scripts/terraform-permission-precheck.sh"
test -x "$LESSON/scripts/classify-iam-error.sh"
test -x "$LESSON/scripts/iam-troubleshooting-report.sh"

jq . "$LESSON/policies/terraform-caller-dev-policy-example.json" >/dev/null

terraform version >/dev/null
aws sts get-caller-identity >/dev/null

echo
echo "Running caller context check..."
"$LESSON/scripts/iam-caller-context.sh" >/dev/null

echo
echo "Lesson 12.11 validation passed."
echo
echo "Optional live checks after dev stack exists:"
echo "ENVIRONMENT=dev $LESSON/scripts/terraform-permission-precheck.sh"
echo "ENVIRONMENT=dev $LESSON/scripts/check-passrole-context.sh"
echo "ENVIRONMENT=dev $LESSON/scripts/check-ec2-runtime-role.sh"
echo "ENVIRONMENT=dev $LESSON/scripts/check-cloudfront-oac-policy.sh"
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/validate-lesson-12-11.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/validate-lesson-12-11.sh
```

---

# 23. Optional Live Validation Commands

If your dev stack from lessons 12.7–12.10 is still deployed, run:

```bash id="live-checks"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/terraform-permission-precheck.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-troubleshooting-report.sh
```

If the dev stack is destroyed, only run:

```bash id="safe-no-stack"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-caller-context.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/terraform-permission-precheck.sh
```

---

# 24. Common IAM Errors and Fixes

## Error 1 — `UnauthorizedOperation` on EC2

Example:

```text id="ec2-unauthorized"
Error: creating EC2 Instance: UnauthorizedOperation
```

Debug:

```bash id="ec2-unauth-debug"
aws sts get-caller-identity
```

If the error includes encoded message:

```bash id="decode-example"
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/decode-authorization-message.sh \
"ENCODED_MESSAGE"
```

Common missing permissions:

```text id="ec2-missing"
ec2:RunInstances
ec2:CreateTags
ec2:DescribeImages
ec2:DescribeSubnets
ec2:DescribeSecurityGroups
iam:PassRole
```

---

## Error 2 — `iam:PassRole` denied

Example:

```text id="passrole-error"
User is not authorized to perform iam:PassRole
```

Debug:

```bash id="passrole-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-passrole-context.sh
```

Fix pattern:

```json id="passrole-fix"
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/devops-masterclass-dev-ec2-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

---

## Error 3 — SSM not online

Debug:

```bash id="ssm-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-ec2-runtime-role.sh
```

Common causes:

```text id="ssm-causes"
EC2 role missing
instance profile missing
AmazonSSMManagedInstanceCore missing
no outbound internet path
private subnet without NAT/VPC endpoints
SSM agent not running
```

---

## Error 4 — CloudFront S3 403

Debug:

```bash id="oac-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/check-cloudfront-oac-policy.sh
```

Common causes:

```text id="oac-causes"
wrong bucket policy SourceArn
wrong distribution ID
wrong S3 bucket ARN
OAC not attached to origin
object key missing
wrong cache behavior
using S3 website endpoint instead of regional domain
```

---

## Error 5 — Explicit Deny

Symptom:

```text id="explicit-deny-symptom"
Simulation or decoded message shows explicitDeny.
```

Fix:

```text id="explicit-deny-fix"
Find the matching Deny.
Remove it, narrow it, or change request so condition no longer matches.
Adding another Allow will not fix explicit Deny.
```

---

# 25. Production IAM Checklist

```text id="checklist"
Before applying Terraform in production:

1. Confirm caller ARN.
2. Confirm AWS account.
3. Confirm region.
4. Confirm Terraform workspace.
5. Confirm backend key.
6. Confirm no broad AdministratorAccess dependency.
7. Confirm iam:PassRole is scoped.
8. Confirm S3 bucket policy SourceArn is scoped.
9. Confirm EC2 role trust policy is service-specific.
10. Confirm no wildcard secrets/resource policies unless justified.
11. Confirm SCP or permission boundary does not block required actions.
12. Confirm plan does not create unexpected IAM privilege escalation.
```

---

# 26. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is a principal?
What is an IAM action?
What is a resource ARN?
What is an IAM condition?
What is an identity-based policy?
What is a resource-based policy?
What is a trust policy?
What is a permission boundary?
What is an SCP?
What is an explicit deny?
What is an implicit deny?
Why does explicit deny override allow?
What is iam:PassRole?
Why does Terraform need iam:PassRole for EC2?
What is the difference between Terraform caller role and EC2 runtime role?
How do you decode an encoded authorization failure message?
How do you simulate a principal policy?
How do you debug CloudFront OAC S3 AccessDenied?
How do you debug SSM not online?
Why should iam:PassRole not be wildcarded casually?
```

Strong interview answer:

```text id="interview-answer"
When troubleshooting AWS IAM, I first identify the caller, action, resource, condition, and policy type involved. I distinguish identity policies from resource policies, role trust policies from permission policies, and Terraform caller permissions from EC2 runtime role permissions. I also check for permission boundaries, SCPs, session policies, and explicit denies because an explicit deny overrides any allow.

For Terraform EC2 deployments, I know the caller needs iam:PassRole to pass the EC2 role to the EC2 service, ideally scoped to the exact role and iam:PassedToService = ec2.amazonaws.com. For runtime access, I verify that the EC2 role trust policy allows ec2.amazonaws.com, the instance profile is attached, and policies such as AmazonSSMManagedInstanceCore are attached when using SSM.

For CloudFront and S3, I debug 403s by checking the object key, CloudFront behavior, OAC attachment, and S3 bucket policy. The bucket policy must allow cloudfront.amazonaws.com to s3:GetObject and scope access to the exact CloudFront distribution ARN using AWS:SourceArn. I use AWS CLI commands, authorization-message decoding, and policy simulation instead of guessing.
```

Resume bullet:

```text id="resume-bullet"
Built an AWS IAM troubleshooting toolkit for Terraform-managed infrastructure, including caller identity diagnostics, encoded authorization failure decoding, iam:PassRole simulation, EC2 runtime role validation, SSM role checks, CloudFront OAC S3 bucket policy verification, S3 policy access simulation, IAM error classification, least-privilege Terraform caller policy examples, AccessDenied runbooks, and production IAM decision workflows.
```

---

# 27. Commit Lesson 12.11

Validate:

```bash id="validate-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/validate-lesson-12-11.sh
```

Generate report if dev stack exists:

```bash id="generate-report"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.11-iam-troubleshooting/scripts/iam-troubleshooting-report.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.11-iam-troubleshooting -maxdepth 4 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add AWS IAM troubleshooting toolkit"

git push
```

---

# 28. Next Lesson

```text id="next-lesson"
12.12 — Ansible Inventory and Roles
```

Now we start the Ansible deep dive.

We will build:

```text id="next-topics"
Ansible mental model
inventory files
static inventory
dynamic inventory from Terraform outputs
ansible.cfg
group_vars
host_vars
roles
tasks
handlers
templates
facts
idempotency
SSH vs SSM connection model
nginx hardening role
app runtime role
validation playbooks
Ansible troubleshooting runbooks
```

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html?utm_source=chatgpt.com "Identity-based policies and resource-based policies - AWS Identity and Access Management"
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_passrole.html?utm_source=chatgpt.com "Grant a user permissions to pass a role to an AWS service - AWS Identity and Access Management"
[4]: https://docs.aws.amazon.com/cli/latest/reference/sts/decode-authorization-message.html?utm_source=chatgpt.com "decode-authorization-message — AWS CLI 2.35.19 Command Reference"
[5]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html?utm_source=chatgpt.com "IAM roles for Amazon EC2 - Amazon Elastic Compute Cloud"
[6]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html?utm_source=chatgpt.com "Restrict access to an Amazon S3 origin - Amazon CloudFront"
