# AWS Masterclass — Lesson 2

## AWS Account Safety, IAM, MFA, Users, Roles, and Policies

Today’s goal is simple:

```text id="goal"
Before creating servers, databases, VPCs, or CloudFront,
you must first secure the AWS account.
```

This is the first real production habit.

AWS strongly recommends that you do **not** use the root user for everyday tasks, and that you configure an administrative user through IAM Identity Center for daily access. ([AWS Documentation][1])

---

# 1. What is an AWS Account?

An AWS account is the top-level container for your AWS resources.

Inside one AWS account, you can create:

```text id="account-resources"
EC2 servers
S3 buckets
VPC networks
IAM users and roles
RDS databases
CloudFront distributions
Billing budgets
CloudWatch alarms
```

Think of an AWS account like:

```text id="account-analogy"
A company-owned building.

Inside the building:
  rooms = VPCs
  computers = EC2
  file storage = S3
  employees = IAM users
  access cards = IAM permissions
  CCTV = CloudTrail/CloudWatch
  monthly bill = AWS Billing
```

---

# 2. What is the Root User?

When you first create an AWS account, AWS creates one very powerful identity:

```text id="root-user"
AWS account root user
```

The root user is the account owner identity. It has complete access to the AWS account.

Root user login uses:

```text id="root-login"
email address
password
MFA device if enabled
```

Never use root for daily work.

Use root only for account-level tasks, such as:

```text id="root-tasks"
closing the AWS account
changing root email/password
changing account-level settings
some billing/account recovery operations
emergency access
```

AWS root user best practices include securing root credentials, using a strong password, enabling MFA, not creating root access keys, and avoiding root use for everyday tasks. ([AWS Documentation][2])

---

# 3. Root User vs IAM User vs IAM Role

This table must be clear from day one.

| Identity                 | Simple meaning                    | Used for                                 | Long-term or temporary? |
| ------------------------ | --------------------------------- | ---------------------------------------- | ----------------------- |
| Root user                | Account owner                     | Emergency/account-level tasks            | Long-term               |
| IAM user                 | Named identity inside AWS account | Human or app access, older/simple setups | Long-term credentials   |
| IAM role                 | Assumable identity                | AWS services, apps, CI/CD, federation    | Temporary credentials   |
| IAM Identity Center user | Central workforce identity        | Human login to one/many accounts         | Temporary role sessions |

Best-practice direction:

```text id="best-direction"
Human login:
  IAM Identity Center / federation

AWS service access:
  IAM roles

Application access:
  IAM roles or temporary credentials

Avoid:
  long-lived access keys where possible
```

AWS IAM best practices recommend federation for human users, temporary credentials through IAM roles for workloads, MFA, least privilege, and protecting root credentials. ([AWS Documentation][3])

---

# 4. What is IAM?

IAM means:

```text id="iam"
Identity and Access Management
```

IAM answers one main question:

```text id="iam-question"
Who can do what on which AWS resource?
```

Example:

```text id="iam-example"
User Vivek
  can start EC2 instances
  in ap-south-1
  but cannot delete S3 buckets
```

IAM has four major pieces:

```text id="iam-pieces"
Identity:
  user, group, role

Policy:
  permission document

Permission:
  allowed or denied action

Resource:
  AWS thing being accessed
```

---

# 5. IAM Policy — The Permission Document

An IAM policy is usually a JSON document.

Example:

```json id="simple-policy"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::example-bucket"
    }
  ]
}
```

Meaning:

```text id="policy-meaning"
Effect:
  Allow or Deny

Action:
  what API call is allowed

Resource:
  where the action is allowed

Statement:
  one rule inside policy
```

AWS policies are JSON documents that define permissions when attached to an identity or resource. ([AWS Documentation][4])

---

# 6. Identity-Based Policy vs Resource-Based Policy

This is very important.

## Identity-based policy

Attached to:

```text id="identity-policy"
IAM user
IAM group
IAM role
```

Example:

```text id="identity-policy-example"
Attach policy to Vivek:
  Vivek can list S3 buckets.
```

## Resource-based policy

Attached to resource.

Examples:

```text id="resource-policy"
S3 bucket policy
KMS key policy
SQS queue policy
IAM role trust policy
```

Example:

```text id="resource-policy-example"
Attach policy to S3 bucket:
  CloudFront can read objects from this bucket.
```

AWS defines identity-based policies as policies attached to users, groups, or roles, and resource-based policies as policies attached to resources such as S3 buckets. ([AWS Documentation][5])

Never confuse:

```text id="identity-vs-resource"
Identity policy:
  what this identity can do

Resource policy:
  who can access this resource
```

---

# 7. IAM Group

An IAM group is a collection of IAM users.

Example:

```text id="group-example"
Group:
  Developers

Users:
  Vivek
  Rahul
  Priya

Policy attached to group:
  ReadOnlyAccess
```

If a policy is attached to the group, all users in that group get those permissions.

Important:

```text id="group-note"
IAM groups are for IAM users.
IAM roles do not belong to IAM groups.
```

---

# 8. IAM Role

An IAM role is an identity that can be assumed.

A role does not normally have a permanent password.

A role is used when:

```text id="role-uses"
EC2 needs permission to access S3
Lambda needs permission to write logs
GitHub Actions needs permission to run Terraform
User needs temporary admin access
Cross-account access is required
```

AWS says an IAM role is similar to an IAM user because it is an AWS identity with permission policies, but it is intended to be assumable and often uses temporary credentials. ([AWS Documentation][6])

Example:

```text id="role-example"
EC2 instance
  assumes EC2Role

EC2Role policy says:
  allow s3:GetObject from bucket

Now app running on EC2 can read S3.
```

---

# 9. Trust Policy vs Permission Policy

Every role has two important ideas.

## Trust policy

Trust policy answers:

```text id="trust"
Who can assume this role?
```

Example:

```json id="trust-policy"
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

Meaning:

```text id="trust-meaning"
EC2 service is allowed to assume this role.
```

## Permission policy

Permission policy answers:

```text id="permission"
After assuming the role, what can it do?
```

Example:

```json id="permission-policy"
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

Never confuse:

```text id="never-confuse-trust"
Trust policy:
  who can become this role?

Permission policy:
  what can this role do?
```

---

# 10. MFA — Multi-Factor Authentication

MFA means:

```text id="mfa"
password + second proof
```

Example:

```text id="mfa-example"
Password:
  something you know

Authenticator app / security key:
  something you have
```

Enable MFA for:

```text id="mfa-enable"
root user
administrator user
IAM Identity Center users
important IAM users
```

AWS supports MFA for root users, IAM users, IAM Identity Center users, AWS Builder ID, and federated users. ([AWS Documentation][7])

MFA is not optional in production.

It is basic account safety.

---

# 11. Access Keys

Access keys are used for programmatic access.

They have two parts:

```text id="access-keys"
Access key ID:
  username-like identifier

Secret access key:
  password-like secret
```

Example use:

```bash id="cli-example"
aws s3 ls
```

Access keys are dangerous if leaked.

Rules:

```text id="access-key-rules"
Never create root access keys.
Never commit access keys to GitHub.
Rotate keys if used.
Prefer IAM roles and temporary credentials.
Use AWS CLI profiles carefully.
```

AWS root user best practices explicitly say not to create root access keys. ([AWS Documentation][2])

---

# 12. Permission Evaluation — How AWS Decides Access

When a request comes in, AWS asks:

```text id="request"
Principal:
  who is calling?

Action:
  what API action?

Resource:
  on what AWS resource?

Condition:
  under what condition?
```

Example:

```text id="request-example"
Principal:
  arn:aws:iam::123456789012:user/vivek

Action:
  ec2:RunInstances

Resource:
  EC2 instance/subnet/security group/AMI

Condition:
  region = ap-south-1
```

AWS evaluates identity-based policies, resource-based policies, permissions boundaries, service control policies, and other policy types. The most important rule: **explicit deny wins**. ([AWS Documentation][8])

Simple logic:

```text id="eval-logic"
If explicit Deny exists:
  denied

Else if Allow exists:
  allowed

Else:
  denied by default
```

This is called:

```text id="implicit-deny"
implicit deny
```

Meaning:

```text id="implicit-meaning"
Nothing allowed it,
so AWS denies it.
```

---

# 13. Least Privilege

Least privilege means:

```text id="least"
Give only the permissions needed,
nothing extra.
```

Bad:

```json id="bad-admin"
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Good:

```json id="good-least"
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": "arn:aws:s3:::my-app-assets/*"
}
```

AWS recommends applying least-privilege permissions and regularly reviewing/removing unused users, roles, permissions, policies, and credentials. ([AWS Documentation][3])

Beginner truth:

```text id="beginner-truth"
In learning labs, you may temporarily use broad permissions.
In production, you must reduce permissions.
```

---

# 14. First Production Account Setup Checklist

Before you create any big resources, do this:

```text id="setup-checklist"
1. Secure root user password.
2. Enable MFA on root user.
3. Do not create root access keys.
4. Create admin access through IAM Identity Center or IAM admin user.
5. Enable MFA for admin identity.
6. Configure AWS CLI using non-root identity.
7. Set default region to ap-south-1.
8. Create AWS Budget alert.
9. Understand where billing dashboard is.
10. Never commit credentials.
```

AWS Budgets supports cost budgets with alert notifications, including email recipients and SNS topics; email budget notifications require recipients to confirm the subscription email. ([AWS Documentation][9])

---

# 15. Hands-On Lab 2A — Check Your Current Identity

This creates no AWS resources.

## Step 1 — Check AWS CLI

```bash id="aws-version"
aws --version
```

Expected:

```text id="aws-version-output"
aws-cli/...
```

## Step 2 — Check who you are

```bash id="sts"
aws sts get-caller-identity
```

Output:

```json id="sts-output"
{
  "UserId": "...",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/vivek"
}
```

Meaning:

```text id="sts-meaning"
Account:
  your AWS account ID

Arn:
  exact AWS identity currently being used

UserId:
  internal identity ID
```

## Step 3 — Check configured region

```bash id="configure-list"
aws configure list
```

Set region:

```bash id="set-region"
aws configure set region ap-south-1
aws configure set output json
```

Verify:

```bash id="verify-region"
aws configure list
```

---

# 16. Hands-On Lab 2B — Create a Budget Alert

Use console for this one first.

Go to:

```text id="budget-path"
AWS Console
  → Billing and Cost Management
  → Budgets
  → Create budget
```

Choose:

```text id="budget-settings"
Budget type:
  Cost budget

Period:
  Monthly

Budget amount:
  $5 or ₹ equivalent comfort level

Alert:
  80% actual spend
  100% forecasted spend

Email:
  your email
```

Important:

```text id="confirm-email"
If AWS sends a confirmation email,
confirm it.
Otherwise alerts may not reach you.
```

---

# 17. Hands-On Lab 2C — Understand Your IAM Identity

Run:

```bash id="identity-script"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
```

If output contains:

```text id="iam-user"
:user/
```

You are using IAM user credentials.

If output contains:

```text id="assumed-role"
:assumed-role/
```

You are using a role session.

If output is root-like, stop and reconfigure. Do not use root for CLI work.

---

# 18. Optional CLI Safety Script

Create:

```bash id="create-script"
mkdir -p ~/aws-masterclass/scripts

cat > ~/aws-masterclass/scripts/aws-safety-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== AWS Safety Check ====="

echo
echo "AWS CLI:"
aws --version

echo
echo "Caller identity:"
aws sts get-caller-identity

echo
echo "AWS config:"
aws configure list

echo
echo "Region check:"
REGION="$(aws configure get region || true)"
if [ "$REGION" != "ap-south-1" ]; then
  echo "WARNING: configured region is '$REGION', expected 'ap-south-1' for this course."
else
  echo "OK: region is ap-south-1"
fi

echo
echo "Identity type:"
ARN="$(aws sts get-caller-identity --query Arn --output text)"
case "$ARN" in
  *":root")
    echo "DANGER: You appear to be using root credentials. Do not use root for CLI."
    exit 1
    ;;
  *":user/"*)
    echo "IAM user credentials detected."
    ;;
  *":assumed-role/"*)
    echo "Assumed role credentials detected."
    ;;
  *)
    echo "Unknown identity type: $ARN"
    ;;
esac

echo
echo "Safety check completed."
EOF

chmod +x ~/aws-masterclass/scripts/aws-safety-check.sh
```

Run:

```bash id="run-script"
~/aws-masterclass/scripts/aws-safety-check.sh
```

---

# 19. IAM JSON Explained Like a Beginner

Take this policy:

```json id="policy-full"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListS3Buckets",
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    }
  ]
}
```

Meaning:

```text id="policy-explain"
Version:
  policy language version, usually 2012-10-17

Statement:
  list of permission rules

Sid:
  optional statement name

Effect:
  Allow or Deny

Action:
  AWS API permission

Resource:
  where permission applies
```

In AWS, almost everything is an API action.

When you click in console, the console calls APIs behind the scenes.

Example:

```text id="api-example"
Click "Launch EC2 instance"
  ↓
Console calls:
  ec2:RunInstances
  ec2:CreateTags
  iam:PassRole
```

This is why IAM matters everywhere.

---

# 20. Important IAM Actions You Will See Often

| Action                                    | Meaning                        |
| ----------------------------------------- | ------------------------------ |
| `ec2:RunInstances`                        | create EC2 instance            |
| `ec2:DescribeInstances`                   | list/read EC2 instances        |
| `s3:ListBucket`                           | list objects in a bucket       |
| `s3:GetObject`                            | read object                    |
| `s3:PutObject`                            | upload object                  |
| `iam:PassRole`                            | pass role to AWS service       |
| `sts:AssumeRole`                          | assume a role                  |
| `cloudfront:CreateDistribution`           | create CloudFront distribution |
| `elasticloadbalancing:CreateLoadBalancer` | create load balancer           |

`iam:PassRole` will become very important later when Terraform creates EC2 with an instance profile.

---

# 21. Real Production Example

You want EC2 to read files from S3.

Bad design:

```text id="bad-design"
Put AWS access keys inside EC2 server.
```

Good design:

```text id="good-design"
Create IAM role:
  EC2AppRole

Attach permission:
  s3:GetObject on required bucket

Attach role to EC2 instance.

App uses temporary credentials automatically.
```

Why good?

```text id="why-good"
No hardcoded keys.
Credentials rotate automatically.
Permission is scoped.
If instance is deleted, access goes away.
```

---

# 22. Certification Angle

## CLF-C02

You must know:

```text id="clf"
root user
IAM users
IAM groups
IAM roles
policies
MFA
least privilege
shared responsibility
billing alerts
```

## SAA-C03

You must know:

```text id="saa"
roles for AWS services
resource policies
cross-account access
IAM with S3/KMS/Lambda/EC2
least privilege architecture
secure access to private resources
```

## DOP-C02

You must know:

```text id="dop"
CI/CD role permissions
iam:PassRole
temporary credentials
automation roles
policy troubleshooting
permission boundaries
CloudTrail audit
SSM access
least privilege in pipelines
```

---

# 23. Common Beginner Errors

## Error 1 — Using root for AWS CLI

Fix:

```text id="root-cli-fix"
Delete root access keys if any exist.
Create/use IAM Identity Center or IAM user/role for CLI.
Enable MFA.
```

## Error 2 — AccessDenied

Meaning:

```text id="accessdenied"
Your identity does not have permission.
```

Debug:

```bash id="accessdenied-debug"
aws sts get-caller-identity
```

Then identify:

```text id="debug-identify"
Who is calling?
What action failed?
Which resource?
Is there explicit deny?
```

## Error 3 — Wrong region

Example:

```text id="wrong-region"
You created EC2 in ap-south-1
but CLI is checking us-east-1.
```

Fix:

```bash id="wrong-region-fix"
aws configure set region ap-south-1
```

Or pass explicitly:

```bash id="region-explicit"
aws ec2 describe-instances --region ap-south-1
```

## Error 4 — Budget email not confirmed

Fix:

```text id="budget-fix"
Open AWS notification email.
Click Confirm subscription.
```

---

# 24. Never-Forget Summary

```text id="summary"
Root user:
  account owner, emergency only

IAM:
  who can do what

IAM user:
  identity with long-term credentials

IAM group:
  collection of IAM users

IAM role:
  assumable identity with temporary credentials

Policy:
  JSON permission document

Trust policy:
  who can assume a role

Permission policy:
  what the identity can do

MFA:
  password + second factor

Least privilege:
  only required permissions

AccessDenied:
  policy did not allow action, or explicit deny blocked it
```

---

# 25. Quick Quiz

Answer mentally:

```text id="quiz"
1. Should root user be used every day?
2. What is IAM?
3. What is an IAM policy?
4. What is an IAM role?
5. What is a trust policy?
6. What is a permission policy?
7. What is MFA?
8. What is least privilege?
9. What is AccessDenied?
10. Why should EC2 use IAM role instead of hardcoded access keys?
```

Answers:

```text id="quiz-answers"
1. No, root is for emergency/account-level tasks.
2. IAM controls identity and access.
3. IAM policy is a JSON permission document.
4. IAM role is an assumable identity with temporary credentials.
5. Trust policy says who can assume a role.
6. Permission policy says what the role/user can do.
7. MFA is password plus second proof.
8. Least privilege means only required permissions.
9. AccessDenied means no matching allow or explicit deny.
10. IAM role avoids hardcoded keys and provides temporary scoped credentials.
```

---

# 26. Interview Answer

Memorize this:

```text id="interview-answer"
IAM is AWS Identity and Access Management. It controls who can perform which actions on which AWS resources. The root user owns the account and should not be used for daily work. For human access, AWS recommends IAM Identity Center or federated access with MFA. For AWS services and applications, IAM roles are preferred because they provide temporary credentials.

An IAM policy is a JSON document that defines permissions. Identity-based policies are attached to users, groups, or roles, while resource-based policies are attached to resources such as S3 buckets. A role has a trust policy that defines who can assume it and permission policies that define what it can do.

AWS access evaluation starts with default deny. If an explicit deny matches, the request is denied. If no deny matches and an allow exists, the request is allowed. The best practice is least privilege, meaning every identity should have only the permissions it needs.
```

---

# Next Lesson

```text id="next"
AWS Lesson 3 — Networking From Absolute Zero:
IP address, CIDR, public IP, private IP, ports, protocols, DNS, VPC, subnet
```

This is the foundation for understanding VPC, EC2, ALB, CloudFront, Route 53, hybrid cloud, and migration.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html?utm_source=chatgpt.com "AWS account root user - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html?utm_source=chatgpt.com "Root user best practices for your AWS account - AWS Identity and Access Management"
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html?utm_source=chatgpt.com "Security best practices in IAM - AWS Identity and Access Management"
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access.html?utm_source=chatgpt.com "Access management for AWS resources - AWS Identity and Access Management"
[5]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html?utm_source=chatgpt.com "Identity-based policies and resource-based policies - AWS Identity and Access Management"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html?utm_source=chatgpt.com "IAM roles - AWS Identity and Access Management"
[7]: https://docs.aws.amazon.com/IAM/latest/UserGuide/gs-identities-mfa.html?utm_source=chatgpt.com "Use multi-factor authentication with your identities - AWS Identity and Access Management"
[8]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access Management"
[9]: https://docs.aws.amazon.com/cost-management/latest/userguide/create-cost-budget.html?utm_source=chatgpt.com "Creating a cost budget - AWS Cost Management"
