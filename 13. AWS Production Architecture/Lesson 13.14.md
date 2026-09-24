# AWS Masterclass — Lesson 13

## Security and IAM in Production — IAM, Permission Boundaries, SCPs, KMS, Secrets Manager, SSM Parameter Store, WAF, Shield, GuardDuty, Inspector, CloudTrail, Config, and AccessDenied Troubleshooting

Today’s lesson is one of the most important AWS production topics.

In real companies, many AWS incidents happen because of:

```text
over-permissive IAM
public S3 buckets
exposed access keys
open security groups
missing CloudTrail
missing encryption
wrong KMS key policy
no backup/restore test
no alerting
bad secret handling
unreviewed infrastructure changes
```

Security in AWS is not one service. It is a layered system.

```text
Identity security:
  IAM, roles, policies, SCPs, permission boundaries

Data security:
  KMS, encryption, Secrets Manager, SSM Parameter Store

Network/application security:
  Security Groups, NACLs, WAF, Shield, private subnets

Detection:
  GuardDuty, Inspector, CloudTrail, Config

Response:
  alerts, isolation, key rotation, rollback, remediation runbooks
```

---

# 1. The production security mental model

Think of AWS security in five layers:

```text
1. Who can access?
   IAM

2. What can they access?
   Policies, resource policies, SCPs, boundaries

3. Is data protected?
   KMS, encryption, backups, secrets

4. Is traffic protected?
   VPC, SG, NACL, WAF, Shield, TLS

5. Can we detect and prove what happened?
   CloudTrail, Config, GuardDuty, Inspector, logs
```

Never think:

```text
I enabled IAM, so AWS is secure.
```

Correct thinking:

```text
IAM controls access.
KMS protects data.
WAF/Shield protect public apps.
CloudTrail records actions.
Config tracks resource changes.
GuardDuty detects suspicious behavior.
Inspector finds vulnerabilities.
```

---

# 2. IAM request model

Every AWS request has four important parts:

```text
Principal:
  who is making the request

Action:
  what API operation is requested

Resource:
  which AWS resource is targeted

Condition:
  under what conditions
```

Example:

```text
Principal:
  arn:aws:iam::123456789012:role/GitHubTerraformRole

Action:
  ec2:RunInstances

Resource:
  EC2, subnet, security group, AMI, key pair, IAM instance profile

Condition:
  aws:RequestedRegion = ap-south-1
```

IAM policies are evaluated across multiple policy types, including identity-based policies, resource-based policies, permission boundaries, SCPs, session policies, VPC endpoint policies, and others. AWS’s evaluation logic has one rule you must never forget: **explicit deny overrides allow**. ([AWS Documentation][1])

---

# 3. The golden IAM rule

Memorize this:

```text
Default:
  deny

If allow exists:
  maybe allowed

If explicit deny exists:
  denied

If permission boundary/SCP does not allow:
  denied

If resource policy/KMS key policy does not allow:
  denied

Final result:
  only allowed when every required layer permits it
```

Simple version:

```text
Allow is not enough.
Deny always wins.
Boundaries and SCPs limit maximum permission.
Resource policies can also be required.
```

---

# 4. IAM policy types in production

## Identity-based policy

Attached to:

```text
IAM user
IAM group
IAM role
```

Meaning:

```text
What can this identity do?
```

Example:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-app-bucket/*"
}
```

---

## Resource-based policy

Attached to a resource.

Examples:

```text
S3 bucket policy
KMS key policy
SQS queue policy
SNS topic policy
Lambda resource policy
IAM role trust policy
```

Meaning:

```text
Who can access this resource?
```

Example S3 bucket policy idea:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-private-bucket/*"
}
```

---

## Permission boundary

A permission boundary does **not** grant permissions.

It sets the maximum permissions an IAM user or role can receive.

Example:

```text
Developer role policy says:
  allow ec2:*

Permission boundary says:
  allow only ec2:Describe*

Final result:
  only ec2:Describe* allowed
```

AWS IAM documentation describes permission boundaries as setting the maximum permissions an identity-based policy can grant to a user or role; permissions are effectively the intersection of identity policies and the boundary. ([AWS Documentation][2])

Use boundaries when:

```text
developers can create roles
CI/CD can create roles
platform team wants guardrails
teams should not accidentally create admin identities
```

---

## SCP — Service Control Policy

SCP belongs to AWS Organizations.

It controls maximum permissions for accounts or organizational units.

Important:

```text
SCP does not grant permission.
SCP only limits permission.
```

Example:

```text
IAM role has AdministratorAccess.

SCP denies:
  ec2:TerminateInstances

Final result:
  role cannot terminate EC2 instances.
```

Use SCPs for organization-wide guardrails:

```text
deny disabling CloudTrail
deny leaving approved regions
deny deleting backup vaults
deny public S3 changes
deny root access key creation
deny removing security tooling
```

---

## Session policy

Session policy limits a temporary session.

Used with:

```text
AssumeRole
federation
temporary credentials
CI/CD role sessions
```

Example:

```text
Role allows S3 read/write.
Session policy allows only S3 read.
Final session can only read.
```

---

## VPC endpoint policy

Attached to VPC endpoints.

Example:

```text
Private EC2 accesses S3 through S3 Gateway Endpoint.
Endpoint policy can restrict which buckets are reachable.
```

Use it as an extra network-side control.

---

# 5. IAM role, trust policy, permission policy

Every IAM role has two security sides.

## Trust policy

Answers:

```text
Who can assume this role?
```

Example EC2 trust policy:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

Meaning:

```text
EC2 service can assume this role.
```

---

## Permission policy

Answers:

```text
After assuming the role, what can it do?
```

Example:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": "arn:aws:s3:::my-app-config/*"
}
```

Never confuse:

```text
Trust policy:
  who can become this role?

Permission policy:
  what can this role do after becoming it?
```

---

# 6. `iam:PassRole` — the hidden production problem

`iam:PassRole` is needed when one identity gives a role to an AWS service.

Example:

```text
Terraform user creates EC2 instance with instance profile.

Terraform calls:
  ec2:RunInstances
  iam:PassRole
```

Without `iam:PassRole`, EC2 creation fails even if `ec2:RunInstances` is allowed.

Common error:

```text
AccessDenied:
  User is not authorized to perform iam:PassRole
```

Production rule:

```text
Allow iam:PassRole only for specific role ARNs.
Limit which services can receive the role.
```

Example safer pattern:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::123456789012:role/dev-ec2-app-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

---

# 7. Least privilege

Least privilege means:

```text
Give only the permissions needed for the job.
Nothing extra.
```

Bad:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Better:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": "arn:aws:s3:::my-app-config/*"
}
```

Production least privilege is built in stages:

```text
1. Start with required use case.
2. Identify exact AWS APIs.
3. Restrict resources by ARN.
4. Add conditions for region, tags, source VPC, MFA, service principal.
5. Test.
6. Monitor CloudTrail.
7. Remove unused permissions.
```

---

# 8. ABAC — Attribute-Based Access Control

ABAC means access based on tags/attributes.

Example:

```text
User/team has tag:
  Team = devops

Resource has tag:
  Team = devops

Policy allows access only when tags match.
```

Use cases:

```text
multi-team accounts
platform engineering
environment isolation
cost ownership
developer sandboxes
```

Example idea:

```json
{
  "Effect": "Allow",
  "Action": "ec2:StartInstances",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Owner": "${aws:PrincipalTag/Owner}"
    }
  }
}
```

ABAC is powerful but requires strong tag governance.

---

# 9. KMS — Key Management Service

KMS protects encryption keys.

Simple meaning:

```text
KMS manages encryption keys used to protect data.
```

KMS concepts:

```text
KMS key:
  encryption key managed by KMS

Key policy:
  resource policy attached to KMS key

Encrypt:
  turn plaintext into ciphertext

Decrypt:
  turn ciphertext back into plaintext

GenerateDataKey:
  create a data key for envelope encryption
```

AWS KMS uses key policies as the primary way to control access to KMS keys, and every KMS key has a key policy. IAM policies can also be used together with key policies, grants, and VPC endpoint policies to control access. ([AWS Documentation][3])

---

# 10. KMS key policy vs IAM policy

KMS is special because IAM permission alone may not be enough.

To use a customer-managed KMS key, access usually needs to be allowed by:

```text
KMS key policy
and/or IAM policy depending on key policy design
```

Common KMS AccessDenied example:

```text
IAM policy allows s3:GetObject.
S3 object is encrypted with KMS.
But KMS key policy does not allow kms:Decrypt.
Result:
  AccessDenied
```

Fix:

```text
Allow s3:GetObject on bucket/object.
Allow kms:Decrypt on the correct KMS key.
Ensure key policy permits the principal/account to use IAM permissions.
```

Example KMS decrypt permission:

```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "arn:aws:kms:ap-south-1:123456789012:key/abcd-1234"
}
```

---

# 11. Envelope encryption

Envelope encryption means:

```text
Data is encrypted with a data key.
The data key is encrypted with a KMS key.
```

Flow:

```text
Application asks KMS for data key.
KMS returns plaintext data key + encrypted data key.
Application encrypts data with plaintext data key.
Application stores encrypted data + encrypted data key.
Later, application asks KMS to decrypt encrypted data key.
```

Simple analogy:

```text
KMS key:
  master locker key

Data key:
  individual file lock key

Envelope encryption:
  file is locked with data key,
  data key is locked with KMS key.
```

---

# 12. AWS-managed key vs customer-managed key

| Key type             | Managed by  | Control level                            | Use case                                  |
| -------------------- | ----------- | ---------------------------------------- | ----------------------------------------- |
| AWS owned key        | AWS         | least visible/control                    | default service-side encryption           |
| AWS managed key      | AWS service | limited control                          | simple encryption per service             |
| Customer managed key | you         | full key policy, rotation, grants, audit | compliance, cross-account, strict control |

Use customer-managed KMS keys when:

```text
you need custom key policy
cross-account access
audit control
key rotation control
separation of duties
compliance requirement
```

Use AWS-managed encryption when:

```text
simple workload
no special key control required
learning/dev setup
```

---

# 13. Secrets Manager

Secrets Manager stores and rotates secrets.

Examples:

```text
database password
API key
OAuth client secret
third-party token
private app credentials
```

AWS Secrets Manager helps manage, retrieve, and rotate credentials and secrets; for many non-managed secrets, rotation uses a Lambda function, while managed rotation options exist for supported secrets. ([AWS Documentation][4])

Bad:

```text
DB_PASSWORD=mysecret in GitHub
DB_PASSWORD inside Dockerfile
password written in Terraform variables file
password stored in EC2 user_data
```

Good:

```text
Store secret in Secrets Manager.
Give app IAM role permission to read only that secret.
Rotate secret.
Audit access through CloudTrail.
```

---

# 14. Secrets Manager vs SSM Parameter Store

| Feature    | Secrets Manager             | SSM Parameter Store                             |
| ---------- | --------------------------- | ----------------------------------------------- |
| Main use   | secrets with rotation       | config values and simple secrets                |
| Rotation   | built-in rotation workflows | not the same built-in rotation experience       |
| Cost       | usually higher              | Standard parameters often cheaper/simple        |
| Examples   | DB passwords, API keys      | app config, feature flags, non-sensitive config |
| Encryption | KMS-supported               | SecureString uses KMS                           |
| Best for   | production credentials      | config management and simple secure parameters  |

Simple rule:

```text
Secrets Manager:
  passwords and secrets that may need rotation

SSM Parameter Store:
  app config and simpler parameters

Never:
  commit secrets to Git
```

---

# 15. WAF — Web Application Firewall

WAF protects HTTP/HTTPS applications.

It can inspect requests and apply rules.

Use WAF for:

```text
SQL injection protection
cross-site scripting protection
rate limiting
IP blocking
country blocking
managed rule groups
bot control patterns
custom request filtering
```

AWS WAF web ACLs provide fine-grained control over HTTP(S) requests and can be associated with CloudFront, API Gateway, ALB, AppSync, Cognito, App Runner, Amplify, and other supported resources. ([AWS Documentation][5])

Common production setup:

```text
Route 53
  ↓
CloudFront + WAF
  ↓
ALB
  ↓
App
```

For CloudFront, WAF is global-scope and uses the US East/N. Virginia control-plane behavior. AWS documentation notes that a global web ACL can be associated with a CloudFront distribution and uses a hard-coded US East/N. Virginia Region. ([AWS Documentation][6])

---

# 16. Shield

Shield protects against DDoS attacks.

There are two levels:

```text
Shield Standard
Shield Advanced
```

AWS Shield documentation states that AWS provides two levels of DDoS protection: Shield Standard and Shield Advanced. Shield Standard provides automatic protection to AWS customers at no additional charge, while Shield Advanced requires a subscription and provides enhanced protections and response features. ([AWS Documentation][7])

Use mental model:

```text
WAF:
  protects HTTP request layer

Shield:
  protects against DDoS attacks

CloudFront:
  helps absorb/distribute traffic globally

ALB:
  regional load balancing

Auto Scaling:
  capacity response
```

For most beginner/public apps:

```text
CloudFront + WAF + Shield Standard + ALB + autoscaling
```

For high-risk enterprise apps:

```text
Shield Advanced + WAF + CloudFront + incident response process
```

---

# 17. GuardDuty

GuardDuty is threat detection.

Simple meaning:

```text
GuardDuty watches AWS activity and logs for suspicious behavior.
```

Amazon GuardDuty continuously monitors and analyzes AWS data sources and logs in your environment, including foundational sources like CloudTrail management events, VPC Flow Logs, DNS logs, and additional protection-plan sources depending on what you enable. It uses threat intelligence and machine learning to identify potentially unauthorized or malicious activity. ([AWS Documentation][8])

Examples of things GuardDuty can detect:

```text
compromised IAM credentials
unusual API calls
crypto mining behavior
communication with known malicious IPs
suspicious S3 activity
unusual container/runtime activity, when enabled
```

GuardDuty output is called:

```text
finding
```

Production response:

```text
1. Read finding.
2. Identify affected principal/resource.
3. Check CloudTrail timeline.
4. Isolate resource if needed.
5. Rotate credentials.
6. Remove unauthorized access.
7. Patch/root-cause.
8. Document incident.
```

---

# 18. Inspector

Inspector is vulnerability management.

Simple meaning:

```text
Inspector scans workloads for vulnerabilities and unintended network exposure.
```

Amazon Inspector automatically discovers workloads and continually scans EC2 instances, ECR container images, and Lambda functions for software vulnerabilities and unintended network exposure; it creates findings when issues are detected. ([AWS Documentation][9])

Use Inspector for:

```text
EC2 package vulnerabilities
container image vulnerabilities in ECR
Lambda function vulnerabilities
network exposure findings
security prioritization
```

Never confuse:

```text
GuardDuty:
  suspicious behavior/threat detection

Inspector:
  vulnerabilities/exposure

CloudTrail:
  who did what

Config:
  what changed and compliance state
```

---

# 19. CloudTrail

CloudTrail records AWS API activity.

Simple meaning:

```text
CloudTrail answers:
  who did what, when, from where, using which identity?
```

AWS CloudTrail records AWS API calls for your account and can deliver log files to S3; CloudTrail events are essential for security auditing and incident investigation. ([AWS Documentation][10])

Example questions CloudTrail helps answer:

```text
Who deleted this S3 bucket policy?
Who created this access key?
Who changed this security group?
Who disabled this CloudTrail trail?
Which IP address made the API call?
Was it console, CLI, Terraform, or SDK?
```

Important event types:

```text
management events:
  control-plane actions like CreateBucket, RunInstances, PutRolePolicy

data events:
  object-level/data-plane actions like S3 GetObject or Lambda Invoke

insight events:
  unusual API activity patterns, when enabled
```

Production rule:

```text
Enable organization/account-level CloudTrail.
Store logs in protected S3 bucket.
Restrict deletion.
Monitor security-sensitive API calls.
```

---

# 20. Config

AWS Config tracks resource configuration and compliance.

Simple meaning:

```text
Config answers:
  what changed, when, and is it compliant?
```

AWS Config records configuration changes for supported AWS resources and creates configuration items when changes are detected; it can record continuously or at a configured frequency. ([AWS Documentation][11])

CloudTrail vs Config:

| Service    | Main question                                             |
| ---------- | --------------------------------------------------------- |
| CloudTrail | Who made the API call?                                    |
| Config     | What is the resource configuration and how did it change? |

Example:

```text
CloudTrail:
  Vivek changed security group at 10:30.

Config:
  Security group now allows 0.0.0.0/0 on port 22.
```

Use Config rules for:

```text
S3 bucket should not be public
EBS volumes should be encrypted
RDS should not be public
CloudTrail should be enabled
security groups should not allow public SSH
IAM root MFA should be enabled
```

Cost note:

```text
AWS Config can generate charges for configuration items and rule evaluations.
Use deliberately in labs and clean up if enabled only for testing.
```

---

# 21. Security service comparison

| Service             | Main job                          | Best question it answers                  |
| ------------------- | --------------------------------- | ----------------------------------------- |
| IAM                 | access control                    | Who can do what?                          |
| KMS                 | key management/encryption         | Who can use encryption keys?              |
| Secrets Manager     | secret storage/rotation           | Where are credentials stored and rotated? |
| SSM Parameter Store | config/secure parameters          | Where is app config stored?               |
| WAF                 | HTTP request filtering            | Should this web request be blocked?       |
| Shield              | DDoS protection                   | Is app protected from DDoS?               |
| GuardDuty           | threat detection                  | Is suspicious activity happening?         |
| Inspector           | vulnerability management          | Is this workload vulnerable/exposed?      |
| CloudTrail          | audit logging                     | Who did what?                             |
| Config              | configuration tracking/compliance | What changed and is it compliant?         |

---

# 22. AccessDenied troubleshooting framework

When AWS says `AccessDenied`, do not guess.

Use this exact method:

```text
1. Who is calling?
2. What exact action failed?
3. Which resource ARN?
4. Which region/account?
5. Is there an explicit deny?
6. Is identity policy missing allow?
7. Is permission boundary limiting?
8. Is SCP limiting?
9. Is session policy limiting?
10. Is resource policy missing/denying?
11. Is KMS key policy missing?
12. Is VPC endpoint policy limiting?
13. Is service-linked role missing?
14. Does iam:PassRole apply?
15. Is MFA/condition/tag required?
```

AWS provides IAM troubleshooting guidance for AccessDenied errors and recommends checking policy types such as SCPs, permission boundaries, and other relevant policies when an error indicates access is denied. ([AWS Documentation][12])

---

# 23. Debug commands for IAM

## Check caller identity

```bash
aws sts get-caller-identity
```

Expected:

```json
{
  "UserId": "...",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/SomeRole/session"
}
```

This tells you:

```text
which account
which role/user
which session
```

---

## Check configured region

```bash
aws configure list
```

Region matters because many resources are regional.

Example:

```text
You created EC2 in ap-south-1.
CLI is checking us-east-1.
You think permission/resource is missing.
Actually region is wrong.
```

---

## Simulate IAM policy

For IAM users:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/vivek \
  --action-names ec2:DescribeInstances \
  --resource-arns "*"
```

For roles, use role ARN:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/dev-terraform-role \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::my-bucket/test.txt
```

---

## Decode authorization message

Some AWS errors include encoded authorization failure messages.

```bash
aws sts decode-authorization-message \
  --encoded-message "ENCODED_MESSAGE_HERE"
```

You need permission:

```text
sts:DecodeAuthorizationMessage
```

---

# 24. Common AccessDenied examples

## Example 1 — EC2 creation fails

Error:

```text
UnauthorizedOperation: You are not authorized to perform ec2:RunInstances
```

Possible missing actions:

```text
ec2:RunInstances
ec2:CreateTags
ec2:DescribeImages
ec2:DescribeSubnets
ec2:DescribeSecurityGroups
ec2:DescribeInstanceTypes
iam:PassRole, if instance profile is attached
```

Fix:

```text
Add least-privilege EC2 permissions.
Add iam:PassRole only for required instance profile role.
Check SCP/boundary.
```

---

## Example 2 — S3 object read fails

Error:

```text
AccessDenied when calling GetObject
```

Possible causes:

```text
identity lacks s3:GetObject
bucket policy denies
object encrypted with KMS and lacks kms:Decrypt
wrong bucket/object ARN
VPC endpoint policy blocks access
S3 Block Public Access blocks public access pattern
```

Fix:

```text
Check IAM policy.
Check bucket policy.
Check KMS key policy and kms:Decrypt.
Check endpoint policy.
```

---

## Example 3 — Lambda cannot read secret

Error:

```text
AccessDeniedException: secretsmanager:GetSecretValue
```

Possible causes:

```text
Lambda execution role lacks secretsmanager:GetSecretValue
secret encrypted with KMS key and role lacks kms:Decrypt
secret resource policy denies
wrong region
```

Fix:

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:ap-south-1:123456789012:secret:prod/db-*"
}
```

Also allow KMS decrypt if customer-managed KMS key is used.

---

## Example 4 — CloudFront cannot read S3

Error:

```text
CloudFront 403
```

Possible causes:

```text
OAC not attached
S3 bucket policy missing CloudFront service principal
SourceArn distribution ID mismatch
object does not exist
wrong S3 origin endpoint
KMS-encrypted object without correct KMS permissions
```

Fix:

```text
Check OAC.
Check bucket policy.
Check object key.
Check KMS key policy if SSE-KMS.
```

---

# 25. Hands-On Lab 13A — IAM AccessDenied Troubleshooting Toolkit

This lab creates no AWS resources.

It gives you a reusable script for every future AWS issue.

## Step 1 — Create folder

```bash
mkdir -p ~/aws-masterclass/security/scripts
cd ~/aws-masterclass/security/scripts
```

## Step 2 — Create identity/debug script

```bash
cat > aws-security-context.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== AWS Security Context ====="

echo
echo "AWS CLI:"
aws --version

echo
echo "Caller identity:"
aws sts get-caller-identity

echo
echo "Configured profile/region:"
aws configure list

echo
echo "Environment variables:"
env | grep -E '^AWS_' || true

echo
echo "Account alias:"
aws iam list-account-aliases --query 'AccountAliases' --output table || true

echo
echo "Current ARN type:"
ARN="$(aws sts get-caller-identity --query Arn --output text)"
echo "$ARN"

case "$ARN" in
  *":root")
    echo "DANGER: root identity detected. Do not use root for CLI work."
    ;;
  *":user/"*)
    echo "IAM user detected."
    ;;
  *":assumed-role/"*)
    echo "Assumed role session detected."
    ;;
  *)
    echo "Unknown/federated identity pattern."
    ;;
esac

echo
echo "Security context check completed."
EOF

chmod +x aws-security-context.sh
```

Run:

```bash
./aws-security-context.sh
```

---

## Step 3 — Create AccessDenied checklist file

```bash
cat > access-denied-checklist.md <<'EOF'
# AWS AccessDenied Troubleshooting Checklist

## 1. Identity

Command:

aws sts get-caller-identity

Record:

- Account:
- ARN:
- User/Role:
- Session name:
- Region:

## 2. Error details

Record:

- Service:
- API action:
- Resource ARN:
- Region:
- Full error message:

## 3. Policy layers to check

- Identity-based policy
- Resource-based policy
- Permission boundary
- SCP
- Session policy
- VPC endpoint policy
- KMS key policy
- Service-linked role
- iam:PassRole requirement
- MFA/condition/tag requirement

## 4. Common final causes

- Missing Allow
- Explicit Deny
- Wrong resource ARN
- Wrong region/account
- Boundary/SCP limit
- Resource policy deny
- KMS key policy deny
- PassRole missing
- VPC endpoint policy deny
- Wrong principal/session
EOF
```

---

## Step 4 — Create IAM simulator helper

```bash
cat > simulate-action.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

POLICY_SOURCE_ARN="${1:-}"
ACTION_NAME="${2:-}"
RESOURCE_ARN="${3:-*}"

if [ -z "$POLICY_SOURCE_ARN" ] || [ -z "$ACTION_NAME" ]; then
  echo "Usage:"
  echo "  $0 <policy-source-arn> <action-name> [resource-arn]"
  echo
  echo "Example:"
  echo "  $0 arn:aws:iam::123456789012:user/vivek s3:ListBucket arn:aws:s3:::my-bucket"
  exit 1
fi

aws iam simulate-principal-policy \
  --policy-source-arn "$POLICY_SOURCE_ARN" \
  --action-names "$ACTION_NAME" \
  --resource-arns "$RESOURCE_ARN" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision,MissingContext:MissingContextValues,MatchedStatements:MatchedStatements}' \
  --output json
EOF

chmod +x simulate-action.sh
```

Usage:

```bash
./simulate-action.sh \
  arn:aws:iam::123456789012:user/vivek \
  s3:ListBucket \
  arn:aws:s3:::my-bucket
```

---

# 26. Optional Lab 13B — Create a Safe Secrets Manager Secret

This lab can create small charges. Do it only when you are ready to clean up.

## Create secret

```bash
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

SECRET_NAME="aws-masterclass/dev/sample-db-password"

aws secretsmanager create-secret \
  --name "$SECRET_NAME" \
  --description "AWS Masterclass sample secret" \
  --secret-string '{"username":"appuser","password":"temporary-lab-password"}' \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Read secret:

```bash
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --query SecretString \
  --output text
```

Delete secret immediately after lab:

```bash
aws secretsmanager delete-secret \
  --secret-id "$SECRET_NAME" \
  --force-delete-without-recovery
```

Production note:

```text
Do not use force delete for production secrets unless you are absolutely sure.
Use recovery window for safety.
```

---

# 27. Optional Lab 13C — Check whether GuardDuty is enabled

This does not create GuardDuty by itself.

```bash
aws guardduty list-detectors \
  --region ap-south-1
```

If output has detector IDs, GuardDuty is enabled in that region.

Check detector:

```bash
DETECTOR_ID="$(aws guardduty list-detectors \
  --region ap-south-1 \
  --query 'DetectorIds[0]' \
  --output text)"

aws guardduty get-detector \
  --region ap-south-1 \
  --detector-id "$DETECTOR_ID"
```

Cost warning:

```text
Enabling GuardDuty can generate charges after free/trial allowances depending on account and usage.
Use intentionally.
```

---

# 28. Optional Lab 13D — CloudTrail lookup

CloudTrail event history can be searched for recent management events.

Check recent events:

```bash
aws cloudtrail lookup-events \
  --max-results 10 \
  --query 'Events[].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}' \
  --output table
```

Find security group changes:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --max-results 10 \
  --output table
```

Use this when someone asks:

```text
Who opened port 22 to the world?
Who changed this policy?
Who deleted this resource?
```

---

# 29. Production security baseline

For a real AWS account, minimum baseline:

```text
Identity:
  root MFA enabled
  no root access keys
  IAM Identity Center/federation for humans
  roles for workloads
  least privilege
  access key rotation/reduction

Network:
  private subnets for apps/databases
  no public DB
  no public SSH where possible
  SSM Session Manager
  SG-to-SG references
  WAF for public apps

Data:
  S3 Block Public Access
  encryption enabled
  KMS where needed
  Secrets Manager for credentials
  backup and restore testing

Detection:
  CloudTrail enabled
  GuardDuty enabled for important accounts
  Config for compliance tracking
  Inspector for EC2/ECR/Lambda vulnerability scanning
  CloudWatch alarms

Governance:
  SCPs for guardrails
  tagging policy
  CI/CD policy checks
  Terraform plan review
  break-glass access process
```

---

# 30. Security anti-patterns

Avoid these:

```text
AdministratorAccess everywhere
long-lived access keys in CI/CD
AWS keys inside EC2/container/Lambda code
root user for daily work
public S3 buckets for app assets
RDS publicly accessible
SSH open to 0.0.0.0/0
KMS key policy with unknown broad principals
no CloudTrail
no backup testing
no incident runbook
no budget alerts
manual console-only infrastructure changes
```

---

# 31. Security incident mini-runbook

When suspicious activity appears:

```text
1. Do not panic.
2. Identify affected account/region/resource.
3. Check CloudTrail.
4. Check GuardDuty finding.
5. Disable/rotate suspected credentials.
6. Isolate affected EC2/container if needed.
7. Remove public access or bad policy.
8. Preserve evidence/logs.
9. Patch vulnerability or misconfiguration.
10. Restore from known-good backup if required.
11. Document timeline and root cause.
12. Add preventive control: SCP, Config rule, IAM fix, WAF rule, CI policy.
```

Example: leaked access key

```text
1. Identify access key ID.
2. Disable key immediately.
3. Check CloudTrail for actions by that key.
4. Rotate application credentials.
5. Remove key from Git/history/secrets.
6. Replace with IAM role/OIDC.
7. Add secret scanning to CI.
```

---

# 32. Certification angle

## CLF-C02

Know:

```text
IAM controls access.
MFA protects accounts.
KMS manages encryption keys.
Secrets Manager stores secrets.
CloudTrail records API activity.
WAF protects web apps.
Shield protects against DDoS.
GuardDuty detects threats.
Inspector finds vulnerabilities.
Config tracks configuration/compliance.
```

## SAA-C03

Know deeply:

```text
identity policy vs resource policy
role trust policy vs permission policy
permission boundary vs SCP
KMS key policy and kms:Decrypt issues
Secrets Manager vs Parameter Store
WAF on CloudFront/ALB/API Gateway
private subnet and SG design
S3 Block Public Access and OAC
CloudTrail/Config/GuardDuty/Inspector roles in architecture
least privilege and cross-account access
```

## DOP-C02

Know operationally:

```text
CI/CD role design
GitHub OIDC / pipeline role assumption
iam:PassRole troubleshooting
CloudTrail incident investigation
Config rule remediation
GuardDuty finding response
Inspector vulnerability workflows
Secrets rotation
KMS key access troubleshooting
SCP guardrails
policy-as-code checks
break-glass access
```

---

# 33. Interview answer

Memorize this:

```text
In AWS production security, I use a layered approach. IAM controls who can do what, using least-privilege roles, identity policies, resource policies, permission boundaries, and SCP guardrails. A role has a trust policy that defines who can assume it and permission policies that define what it can do. I treat iam:PassRole carefully because it controls which roles can be passed to services like EC2, Lambda, or ECS.

For data protection, I use encryption with KMS where key control is required. I remember that KMS access depends heavily on key policy, not only IAM policy. For secrets, I use Secrets Manager or SSM Parameter Store instead of storing passwords in code, Docker images, Terraform files, or EC2 user data.

For public application protection, I use CloudFront or ALB with WAF rules, and AWS Shield provides DDoS protection. For detection and governance, I use CloudTrail to answer who did what, AWS Config to track resource configuration and compliance, GuardDuty to detect suspicious activity, and Inspector to find vulnerabilities in EC2, ECR images, and Lambda functions.

When troubleshooting AccessDenied, I identify the caller with sts get-caller-identity, capture the exact action and resource ARN, then check identity policies, resource policies, permission boundaries, SCPs, session policies, KMS key policies, VPC endpoint policies, and iam:PassRole conditions. I know that explicit deny always wins and that boundaries and SCPs set maximum permissions rather than granting access.
```

---

# 34. Quick quiz

```text
1. What does IAM control?
2. What is explicit deny?
3. What is a permission boundary?
4. Does a permission boundary grant permissions?
5. What is an SCP?
6. Does an SCP grant permissions?
7. What is a role trust policy?
8. What is a role permission policy?
9. What is iam:PassRole?
10. What is KMS?
11. Why can KMS cause AccessDenied even when S3 allows access?
12. What is Secrets Manager?
13. What is the difference between Secrets Manager and Parameter Store?
14. What is WAF?
15. What is Shield?
16. What is GuardDuty?
17. What is Inspector?
18. What is CloudTrail?
19. What is Config?
20. What is the first command in AccessDenied troubleshooting?
```

Answers:

```text
1. Who can do what on which AWS resources.
2. A deny statement that overrides any allow.
3. Maximum-permission limit for IAM user/role.
4. No.
5. AWS Organizations guardrail that limits account/OU permissions.
6. No.
7. Policy that defines who can assume the role.
8. Policy that defines what the role can do.
9. Permission to pass an IAM role to an AWS service.
10. AWS key management/encryption service.
11. Object may be encrypted with KMS and caller lacks kms:Decrypt/key policy permission.
12. Service for storing and rotating secrets.
13. Secrets Manager is best for credentials/rotation; Parameter Store is good for config/simple secure parameters.
14. Web Application Firewall.
15. AWS DDoS protection service.
16. Threat detection service.
17. Vulnerability management/scanning service.
18. API activity audit service.
19. Resource configuration/compliance tracking service.
20. aws sts get-caller-identity.
```

# Next Lesson

```text
AWS Lesson 14 — Observability and Operations:
CloudWatch metrics, logs, alarms, dashboards, X-Ray tracing, VPC Flow Logs, ALB logs, CloudFront logs, SLO/SLI basics, incident response, and production runbooks
```

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html?utm_source=chatgpt.com "Permissions boundaries for IAM entities - AWS Identity and Access Management"
[3]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html?utm_source=chatgpt.com "Key policies in AWS KMS - AWS Key Management Service"
[4]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html?utm_source=chatgpt.com "What is AWS Secrets Manager? - AWS Secrets Manager"
[5]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-anti-ddos.html?utm_source=chatgpt.com "AWS WAF Distributed Denial of Service (DDoS) prevention - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[6]: https://docs.aws.amazon.com/waf/latest/developerguide/getting-started-ddos.html?utm_source=chatgpt.com "Setting up AWS Shield Advanced - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[7]: https://docs.aws.amazon.com/shield/?utm_source=chatgpt.com "AWS Shield Documentation"
[8]: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html?utm_source=chatgpt.com "What is Amazon GuardDuty? - Amazon GuardDuty"
[9]: https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html?utm_source=chatgpt.com "What is Amazon Inspector? - Amazon Inspector"
[10]: https://docs.aws.amazon.com/awscloudtrail/latest/APIReference/Welcome.html?utm_source=chatgpt.com "Welcome - AWS CloudTrail"
[11]: https://docs.aws.amazon.com/config/latest/developerguide/select-resources.html?utm_source=chatgpt.com "Recording AWS Resources with AWS Config - AWS Config"
[12]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_access-denied.html?utm_source=chatgpt.com "Troubleshoot access denied error messages - AWS Identity and Access Management"
