# AWS Masterclass — Lesson 17

## Multi-Account AWS Architecture — Organizations, OUs, SCPs, Control Tower, IAM Identity Center, Shared Services, Logging, Security, Network, Workload Accounts, Cross-Account Roles, and Landing Zone Design

Today we move from this beginner pattern:

```text
One AWS account
  ├── IAM users
  ├── EC2
  ├── S3
  ├── RDS
  ├── dev resources
  ├── prod resources
  └── security logs
```

to this production pattern:

```text
AWS Organization
  ├── Management account
  ├── Security OU
  │   ├── Log Archive account
  │   └── Security Tooling / Audit account
  ├── Infrastructure OU
  │   ├── Network account
  │   └── Shared Services account
  ├── Workloads OU
  │   ├── Dev account
  │   ├── Staging account
  │   └── Production account
  └── Sandbox OU
      └── Experiment/Lab accounts
```

This is how serious AWS environments are organized.

AWS Organizations lets you centrally manage AWS accounts, group accounts, apply policies, enable integrated AWS services, centralize audit controls, and manage consolidated billing across accounts. AWS also says AWS accounts are natural boundaries for permissions, security, costs, and workloads, and recommends multi-account environments as you scale cloud usage. ([AWS Documentation][1])

---

## 1. Why not use one AWS account for everything?

A single account is simple at the beginning.

But it becomes dangerous as soon as you have:

```text
developers
production workloads
CI/CD pipelines
security logs
customer data
multiple apps
experiments
databases
shared networks
different environments
```

Problems with one account:

```text
Dev accidentally deletes prod resource.
Intern gets access to production data.
Security logs are stored beside workloads.
Budget/cost ownership is unclear.
Service quotas are shared by all workloads.
IAM policies become too broad.
Experiments can affect production.
Incident blast radius is large.
```

Multi-account architecture gives you hard isolation boundaries.

AWS’s multi-account guidance lists benefits such as grouping workloads by business purpose and ownership, applying different security controls by environment, constraining access to sensitive data, limiting the scope of impact from adverse events, managing costs, and distributing AWS service quotas/API request limits. ([AWS Documentation][2])

Simple rule:

```text
One account is okay for learning.

Multiple accounts are standard for production.
```

---

## 2. What is an AWS account?

An AWS account is not just a login.

It is a security, billing, quota, and resource boundary.

Think:

```text
AWS account = isolated container for AWS resources
```

Inside one account:

```text
IAM roles
EC2 instances
S3 buckets
VPCs
RDS databases
CloudTrail events
billing usage
service quotas
```

Example:

```text
dev account:
  developers can deploy freely

prod account:
  only CI/CD role can deploy
  humans get read-only or break-glass access
```

Good production thinking:

```text
Use accounts as isolation boundaries.
Use OUs as policy grouping boundaries.
Use roles for access.
Use SCPs as guardrails.
```

---

## 3. AWS Organizations

AWS Organizations is the central service for managing many AWS accounts.

It helps you:

```text
create accounts
invite existing accounts
group accounts into OUs
apply SCPs and other organization policies
enable AWS services across accounts
delegate service administration
centralize billing
centralize audit controls
```

AWS Organizations can integrate with other AWS services so you can define central configurations, security mechanisms, audit requirements, and resource sharing across accounts. ([AWS Documentation][1])

Mental model:

```text
AWS Organizations = company-level account management system
```

---

## 4. Management account

The management account is the root administrative account of the AWS Organization.

It can:

```text
create/member accounts
manage OUs
attach SCPs
enable trusted access
delegate administration
view consolidated billing
```

But production rule:

```text
Do not run workloads in the management account.
```

AWS multi-account design principles recommend avoiding deployment of workloads to the organization’s management account, because privileged operations can be performed there and SCPs do not apply to that account. ([AWS Documentation][3])

Use the management account only for:

```text
organization management
billing management
Control Tower setup
break-glass administration
delegated administrator setup
```

Bad:

```text
Management account:
  production EC2
  production RDS
  developer IAM users
  random S3 buckets
```

Good:

```text
Management account:
  very limited access
  MFA
  no workloads
  billing/org admin only
```

---

## 5. Member account

A member account is any account inside the organization except the management account.

Examples:

```text
log archive account
security tooling account
network account
shared services account
dev workload account
prod workload account
sandbox account
```

Production workloads should live in member accounts, not the management account.

---

## 6. Organizational Unit — OU

An OU is a group of accounts.

Think:

```text
OU = folder for AWS accounts
```

Example:

```text
Security OU
  ├── Log Archive account
  └── Security Tooling account
```

Another example:

```text
Workloads OU
  ├── Dev account
  ├── Staging account
  └── Prod account
```

AWS recommends organizing accounts using OUs based on function, compliance requirements, or a common set of controls rather than mirroring a company reporting structure. It also recommends applying security controls to OUs rather than individual accounts where possible. ([AWS Documentation][3])

Simple rule:

```text
Do not design OUs based only on company departments.

Design OUs based on security, operations, environment, and compliance needs.
```

---

## 7. Recommended OU structure

A practical starter structure:

```text
Root
├── Security OU
├── Infrastructure OU
├── Workloads OU
├── Sandbox OU
└── Suspended OU
```

### Security OU

Contains accounts that protect and monitor the organization.

```text
Security OU
  ├── Log Archive account
  └── Security Tooling / Audit account
```

### Infrastructure OU

Contains shared infrastructure.

```text
Infrastructure OU
  ├── Network account
  └── Shared Services account
```

### Workloads OU

Contains application accounts.

```text
Workloads OU
  ├── Dev account
  ├── Staging account
  └── Prod account
```

### Sandbox OU

Contains experimentation accounts.

```text
Sandbox OU
  └── Lab / learning / proof-of-concept accounts
```

### Suspended OU

Contains accounts waiting for closure or investigation.

```text
Suspended OU
  └── old/disabled accounts
```

AWS’s recommended OUs include Security and Infrastructure patterns; the Security OU groups accounts for security policies, governance, and compliance controls, while the Infrastructure OU groups accounts that host shared infrastructure and networking services. ([AWS Documentation][4])

---

## 8. Account roles in a landing zone

A landing zone is your governed multi-account AWS foundation.

A strong starter landing zone:

| Account                  | Purpose                                                                   |
| ------------------------ | ------------------------------------------------------------------------- |
| Management               | AWS Organizations, billing, Control Tower setup                           |
| Log Archive              | Central immutable security/audit logs                                     |
| Security Tooling / Audit | GuardDuty, Security Hub, Macie, Inspector, Access Analyzer administration |
| Network                  | Transit Gateway, shared networking, inspection, egress, Route 53 Resolver |
| Shared Services          | Directory, patching, CI/CD shared tools, artifact services                |
| Dev Workload             | Developer environment                                                     |
| Staging Workload         | Pre-production testing                                                    |
| Prod Workload            | Production application                                                    |
| Sandbox                  | Safe experiments                                                          |

Control Tower can establish a multi-account landing zone and initially creates a Security OU with Log Archive and Audit accounts, plus a Sandbox OU for exploration accounts. ([AWS Documentation][5])

---

## 9. AWS Control Tower

AWS Control Tower helps set up and govern a multi-account AWS environment.

Simple meaning:

```text
Control Tower = AWS managed landing zone setup and governance service
```

It orchestrates services such as:

```text
AWS Organizations
IAM Identity Center
AWS Service Catalog
AWS CloudTrail
AWS Config
guardrails/controls
account vending
```

AWS describes Control Tower as a way to set up and govern a multi-account environment using prescriptive best practices, orchestrating services including Organizations, Service Catalog, and IAM Identity Center. ([AWS Documentation][5])

Use Control Tower when:

```text
you want AWS-native landing zone setup
you want account factory/account vending
you want guardrails/controls
you want centralized governance
you are building an enterprise-style AWS foundation
```

---

## 10. Landing zone

A landing zone is the prepared foundation where workloads can safely land.

It includes:

```text
account structure
OU structure
identity setup
network design
logging
security tooling
guardrails
billing controls
baseline IAM roles
baseline monitoring
account vending process
```

Simple analogy:

```text
Without landing zone:
  builders create resources randomly.

With landing zone:
  every workload lands in a governed, logged, secured, networked AWS environment.
```

Production rule:

```text
Build landing zone before migrating or scaling workloads.
```

---

## 11. SCP — Service Control Policy

SCP means:

```text
Service Control Policy
```

Simple meaning:

```text
SCP = maximum permission guardrail for accounts/OUs
```

SCPs do not grant permissions. They define maximum available permissions for IAM users and roles in member accounts. The actual permission still needs to come from IAM identity policies, resource policies, or other allowed policy layers. ([AWS Documentation][6])

Example:

```text
IAM role policy allows:
  ec2:RunInstances

SCP denies:
  ec2:RunInstances outside ap-south-1

Final result:
  can launch EC2 only where SCP allows
```

Important:

```text
SCPs affect member accounts.
SCPs do not affect users or roles in the management account.
```

AWS documentation explicitly notes that SCPs do not affect users or roles in the management account; they affect member accounts, including delegated administrator accounts. ([AWS Documentation][6])

---

## 12. SCP examples

### Deny leaving approved regions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyOutsideApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "route53:*",
        "cloudfront:*",
        "support:*",
        "sts:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-south-1",
            "us-east-1"
          ]
        }
      }
    }
  ]
}
```

Why include `us-east-1`?

```text
CloudFront ACM certificates must be in us-east-1.
Some global service control planes also behave through global/us-east-1 patterns.
```

### Deny disabling CloudTrail

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailTampering",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

### Deny public S3 policy changes

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyS3PublicAccessChanges",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketPublicAccessBlock",
        "s3:DeletePublicAccessBlock",
        "s3:PutBucketAcl",
        "s3:PutBucketPolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

Use caution: do not attach strict SCPs to the root without testing. AWS strongly recommends testing SCP impact first, such as by applying policies to an OU and moving accounts in gradually. ([AWS Documentation][6])

---

## 13. SCP vs IAM policy

Never confuse them.

| Feature            | IAM policy                     | SCP                              |
| ------------------ | ------------------------------ | -------------------------------- |
| Grants permission? | Yes, when attached and allowed | No                               |
| Attached to        | user, group, role, resource    | org root, OU, account            |
| Controls           | identity/resource access       | maximum allowed access           |
| Scope              | account/resource level         | organization level               |
| Example            | allow S3 read                  | deny all regions except approved |

Simple formula:

```text
Final permission =
  IAM allows
  AND resource policy allows if needed
  AND SCP allows
  AND permission boundary allows if present
  AND no explicit deny
```

---

## 14. IAM Identity Center

IAM Identity Center is the recommended AWS service for central workforce access across accounts.

Instead of creating IAM users in every account:

```text
User logs in through Identity Center
  ↓
chooses AWS account
  ↓
chooses permission set
  ↓
gets temporary role credentials
```

AWS recommends enabling IAM Identity Center with AWS Organizations because an organization instance supports all IAM Identity Center features and central management capabilities. ([AWS Documentation][7])

Good pattern:

```text
IAM Identity Center
  ├── DevOpsAdmin permission set
  ├── SecurityAudit permission set
  ├── DeveloperReadOnly permission set
  ├── BillingReadOnly permission set
  └── BreakGlassAdmin permission set
```

Avoid:

```text
IAM users manually created in every account
long-term access keys for humans
shared admin credentials
```

---

## 15. Permission set

A permission set is an Identity Center template that creates access in accounts.

Example:

```text
Permission set:
  DevOpsPowerUser

Attached policies:
  PowerUserAccess
  custom deny production destructive actions
  session duration 4 hours
```

Mapping:

```text
Group:
  DevOps-Team

Permission set:
  DevOpsPowerUser

Accounts:
  dev, staging
```

Result:

```text
DevOps team can access dev/staging with temporary credentials.
```

For production:

```text
DevOps team:
  read-only daily

CI/CD role:
  deploy permission

Break-glass:
  emergency admin with approval/MFA
```

---

## 16. Cross-account role

A cross-account role lets a principal in one account assume a role in another account.

Example:

```text
CI/CD account role
  ↓ assumes
Prod deployment role
  ↓ deploys ECS service
```

Trust policy in prod role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/cicd-deploy-role"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Permission policy on prod role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition",
        "elasticloadbalancing:DescribeTargetHealth",
        "cloudwatch:DescribeAlarms"
      ],
      "Resource": "*"
    }
  ]
}
```

Mental model:

```text
Trust policy:
  who can assume this role?

Permission policy:
  what can this role do after assuming it?
```

---

## 17. Delegated administrator

A delegated administrator account manages an AWS service for the organization without requiring daily use of the management account.

Examples:

```text
Security Tooling account:
  delegated admin for GuardDuty
  delegated admin for Security Hub
  delegated admin for Inspector
  delegated admin for Macie

Network account:
  manages shared network resources

Backup account:
  manages org backup policies
```

AWS Organizations supports registering member accounts as delegated administrators for integrated AWS services. This enables those accounts to have administrative permissions for the service and read-only Organizations actions, reducing the need to operate from the management account. ([AWS Documentation][8])

Production rule:

```text
Use delegated admins.
Keep management account quiet.
```

---

## 18. Log Archive account

The Log Archive account is dedicated to central logs.

Store:

```text
CloudTrail organization trail logs
AWS Config snapshots/history
VPC Flow Logs
CloudFront logs
ALB logs
WAF logs
Security Lake data
central backup/audit evidence
```

AWS Security Reference Architecture guidance describes the Log Archive account as dedicated to ingesting and archiving security-related logs and backups, with objectives such as immutable storage, controlled automated access, monitoring, and durability. ([AWS Documentation][9])

Production bucket controls:

```text
S3 versioning
S3 Object Lock if required
MFA Delete where applicable
Block Public Access
SSE-KMS
least-privilege write access
very limited read access
lifecycle/archive policy
cross-region replication if required
```

---

## 19. Security Tooling / Audit account

This account is used by the security team and delegated security services.

Typical services:

```text
GuardDuty delegated admin
Security Hub CSPM delegated admin
Inspector delegated admin
Macie delegated admin
IAM Access Analyzer
Detective
central dashboards
security automation
incident response tooling
```

Purpose:

```text
security team can monitor all accounts
without logging into every account manually
```

Bad:

```text
security tools scattered in each workload account
no central visibility
```

Good:

```text
member accounts send findings to delegated security account
security team investigates centrally
```

---

## 20. Network account

The Network account contains centralized networking.

Typical resources:

```text
Transit Gateway
centralized ingress/egress
inspection VPC
AWS Network Firewall
Route 53 Resolver endpoints
shared VPCs/subnets
Direct Connect gateway attachments
VPN attachments
PrivateLink endpoint services
central DNS patterns
```

AWS Security Reference Architecture guidance places network services in a Network account and discusses centralized networking management while preserving account-level isolation and separation of duties. ([AWS Documentation][10])

Use the Network account when:

```text
many accounts need shared network connectivity
hybrid connectivity must be controlled
central egress/inspection is required
DNS resolver endpoints are shared
security team needs network visibility
```

---

## 21. Shared Services account

The Shared Services account contains common platform services.

Examples:

```text
directory services
patch management tooling
central CI/CD tooling
artifact mirrors
license servers
internal package repositories
golden AMI/image pipeline
shared automation
monitoring collectors
```

AWS guidance distinguishes Shared Services from Network accounts to support separation of duties and recommends federation patterns for human access rather than managing separate IAM users everywhere. ([AWS Documentation][11])

---

## 22. Workload accounts

Workload accounts host applications.

Recommended separation:

```text
app1-dev account
app1-staging account
app1-prod account
```

or for smaller teams:

```text
dev account
staging account
prod account
```

AWS recommends separating production from non-production workloads and assigning either a single workload or a small set of closely related workloads to each production account. ([AWS Documentation][3])

Production account rule:

```text
No experiments.
No broad human write access.
Deploy through pipeline.
Logs sent to central account.
Security findings sent to security account.
Backups protected.
```

---

## 23. Sandbox accounts

Sandbox accounts are for learning and experiments.

They should have:

```text
strict budget alarms
restricted regions
restricted expensive services
automatic cleanup
no production data
short-lived resources
```

Good Sandbox SCP examples:

```text
deny large instance families
deny creating public RDS
deny leaving approved regions
deny disabling budget alarms
deny IAM admin changes except allowed roles
```

Sandbox is where builders can safely explore.

---

## 24. Multi-account network pattern

Production architecture:

```text
Network account
  ├── Transit Gateway
  ├── Route 53 Resolver endpoints
  ├── VPN / Direct Connect
  └── inspection VPC

Workload prod account
  ├── VPC
  ├── private app subnets
  ├── private DB subnets
  └── TGW attachment

Shared services account
  ├── directory
  ├── patching
  └── internal tooling
```

Traffic example:

```text
Prod app account
  ↓ TGW
Network account inspection VPC
  ↓
Internet / on-prem / shared services
```

Do not over-centralize too early. Start simple and grow when required.

---

## 25. Multi-account CI/CD pattern

A production deployment pipeline may live in a CI/CD or Shared Services account.

Flow:

```text
GitHub
  ↓
CI/CD account pipeline
  ↓ build image
ECR
  ↓
assume role into dev account
  ↓ deploy dev
  ↓ tests pass
assume role into staging account
  ↓ deploy staging
  ↓ approval
assume role into prod account
  ↓ deploy prod
```

Cross-account deployment roles:

```text
dev-deploy-role
staging-deploy-role
prod-deploy-role
```

Production rule:

```text
Pipeline deploys.
Humans approve.
Workload accounts stay isolated.
```

---

## 26. Multi-account cost model

Multi-account helps cost allocation.

Common tags:

```text
Project
Environment
Owner
CostCenter
Application
ManagedBy
DataClassification
```

Account-level cost grouping:

```text
dev account:
  dev spend

prod account:
  prod spend

sandbox account:
  experiment spend
```

Use:

```text
AWS Budgets
Cost Explorer
Cost allocation tags
SCPs for expensive service restrictions
billing reports
```

AWS Organizations provides consolidated billing and lets you view usage across accounts and track costs using services such as Cost Explorer. ([AWS Documentation][1])

---

## 27. Multi-account security baseline

Every account should have a baseline.

```text
CloudTrail enabled
AWS Config decision
GuardDuty enabled where required
Security Hub / Inspector where required
IAM password policy / Identity Center access
root MFA
no root access keys
S3 Block Public Access
default EBS encryption
public access review
budget alarm
VPC Flow Logs decision
backup policy
required tags
```

Use automation:

```text
Control Tower controls
CloudFormation StackSets
Terraform account baseline
AWS Config rules
SCPs
Security Hub standards
```

AWS Organizations can centralize CloudTrail across accounts so member accounts cannot turn off or modify the central audit log, and can use Config and Backup policies across accounts and Regions. ([AWS Documentation][1])

---

## 28. Hands-On Lab 17A — Multi-Account Landing Zone Design Pack

This lab creates **local files only**.

No AWS resources. No charges.

Goal:

```text
Build an interview-ready and production-style multi-account landing zone design.
```

Create folder:

```bash
mkdir -p ~/aws-masterclass/multi-account/{diagrams,policies,runbooks,scripts,reports,notes}
cd ~/aws-masterclass/multi-account
```

---

## Step 1 — Create OU and account plan

```bash
cat > notes/ou-account-plan.md <<'EOF'
# AWS Multi-Account OU and Account Plan

## Management account

Purpose:
- AWS Organizations management
- Billing
- Control Tower setup
- Delegated administrator registration
- Break-glass only

Rules:
- No application workloads
- No developer IAM users
- MFA required
- Very limited access

## Security OU

Accounts:
- Log Archive
- Security Tooling / Audit

Controls:
- Central CloudTrail logs
- GuardDuty/Security Hub/Inspector/Macie delegated administration
- Security read-only visibility
- Strict access controls

## Infrastructure OU

Accounts:
- Network
- Shared Services

Controls:
- Transit Gateway / central DNS / VPN / Direct Connect
- Shared tools and directory services
- Restricted admin access
- Change-controlled networking

## Workloads OU

Accounts:
- Dev
- Staging
- Prod

Controls:
- Dev: flexible but guarded
- Staging: production-like
- Prod: deployment via CI/CD only
- Logs and findings centralized

## Sandbox OU

Accounts:
- Lab/Sandbox accounts

Controls:
- Budget alarms
- Region restriction
- Expensive services restricted
- No production data
- Auto-cleanup policy

## Suspended OU

Purpose:
- Closed/inactive/quarantined accounts
- No active workload
EOF
```

---

## Step 2 — Create architecture diagram

```bash
cat > diagrams/multi-account-landing-zone.mmd <<'EOF'
flowchart TD
  Org[AWS Organization] --> Mgmt[Management Account]

  Org --> SecurityOU[Security OU]
  SecurityOU --> LogArchive[Log Archive Account]
  SecurityOU --> SecurityTooling[Security Tooling / Audit Account]

  Org --> InfraOU[Infrastructure OU]
  InfraOU --> Network[Network Account]
  InfraOU --> Shared[Shared Services Account]

  Org --> WorkloadsOU[Workloads OU]
  WorkloadsOU --> Dev[Dev Workload Account]
  WorkloadsOU --> Staging[Staging Workload Account]
  WorkloadsOU --> Prod[Prod Workload Account]

  Org --> SandboxOU[Sandbox OU]
  SandboxOU --> Sandbox[Sandbox / Lab Account]

  Org --> SuspendedOU[Suspended OU]

  Network --> TGW[Transit Gateway]
  Network --> DNS[Route 53 Resolver]
  Network --> VPN[VPN / Direct Connect]

  SecurityTooling --> GuardDuty[GuardDuty Admin]
  SecurityTooling --> SecurityHub[Security Hub CSPM]
  SecurityTooling --> Inspector[Inspector Admin]

  Dev --> Logs1[CloudTrail/Config Logs]
  Staging --> Logs2[CloudTrail/Config Logs]
  Prod --> Logs3[CloudTrail/Config Logs]

  Logs1 --> LogArchive
  Logs2 --> LogArchive
  Logs3 --> LogArchive

  Shared --> CICD[CI/CD Tools]
  CICD --> Dev
  CICD --> Staging
  CICD --> Prod
EOF
```

---

## Step 3 — Create SCP examples

```bash
cat > policies/scp-deny-outside-approved-regions.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyOutsideApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "route53:*",
        "cloudfront:*",
        "support:*",
        "sts:*",
        "acm:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-south-1",
            "us-east-1"
          ]
        }
      }
    }
  ]
}
EOF
```

```bash
cat > policies/scp-deny-cloudtrail-tampering.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailTampering",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

```bash
cat > policies/scp-deny-public-rds.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicRDS",
      "Effect": "Deny",
      "Action": [
        "rds:CreateDBInstance",
        "rds:ModifyDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "rds:PubliclyAccessible": "true"
        }
      }
    }
  ]
}
EOF
```

---

## Step 4 — Create cross-account deployment role trust policy

```bash
cat > policies/prod-deploy-role-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCICDAccountAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/shared-cicd-pipeline-role"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create limited prod deploy permission example:

```bash
cat > policies/prod-ecs-deploy-permissions.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcsDeploy",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "elasticloadbalancing:DescribeTargetHealth",
        "cloudwatch:DescribeAlarms"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassOnlyApprovedEcsRoles",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::222222222222:role/prod-ecs-task-execution-role",
        "arn:aws:iam::222222222222:role/prod-ecs-task-role"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
```

---

## Step 5 — Create account baseline checklist

```bash
cat > reports/account-baseline-checklist.md <<'EOF'
# AWS Account Baseline Checklist

## Identity

- [ ] Root MFA enabled
- [ ] No root access keys
- [ ] IAM Identity Center access configured
- [ ] Break-glass access documented
- [ ] No unnecessary IAM users
- [ ] Permission sets mapped to groups

## Logging and audit

- [ ] Organization CloudTrail enabled
- [ ] CloudTrail logs sent to Log Archive account
- [ ] CloudTrail log validation enabled
- [ ] AWS Config decision documented
- [ ] VPC Flow Logs decision documented
- [ ] Service logs centralization plan documented

## Security

- [ ] GuardDuty enabled or delegated
- [ ] Security Hub CSPM decision documented
- [ ] Inspector decision documented
- [ ] S3 Block Public Access enabled
- [ ] Default EBS encryption enabled
- [ ] KMS key strategy documented
- [ ] Public access review completed

## Network

- [ ] VPC CIDR does not overlap
- [ ] Public/private subnet strategy documented
- [ ] Route tables reviewed
- [ ] No public database subnet exposure
- [ ] Security groups reviewed
- [ ] DNS strategy documented

## Cost

- [ ] Budget alert configured
- [ ] Cost allocation tags activated
- [ ] Owner tag required
- [ ] Environment tag required
- [ ] Sandbox restrictions applied

## Operations

- [ ] Backup strategy documented
- [ ] Monitoring alarms configured
- [ ] Incident contacts documented
- [ ] Deployment path documented
- [ ] Cleanup/decommission process documented
EOF
```

---

## Step 6 — Create landing zone runbook

```bash
cat > runbooks/landing-zone-build-runbook.md <<'EOF'
# Landing Zone Build Runbook

## Goal

Create a secure, scalable AWS multi-account foundation.

## Phase 1 — Planning

- Define management account owner.
- Define OU structure.
- Define account list.
- Define identity provider.
- Define break-glass process.
- Define primary AWS Region: ap-south-1.
- Define global/security exceptions: us-east-1 for CloudFront ACM/global controls.
- Define log retention and compliance needs.

## Phase 2 — Organization setup

- Create or choose management account.
- Enable AWS Organizations all features.
- Enable IAM Identity Center organization instance.
- Create initial OUs.
- Create or enroll accounts.

## Phase 3 — Security baseline

- Enable organization CloudTrail.
- Send logs to Log Archive account.
- Enable GuardDuty/Security Hub/Inspector as required.
- Configure delegated administrators.
- Enable S3 Block Public Access.
- Configure AWS Config where required.
- Apply tested SCPs to OUs.

## Phase 4 — Network baseline

- Create network account.
- Define CIDR plan.
- Create shared Transit Gateway if needed.
- Configure Route 53 Resolver endpoints if hybrid DNS is needed.
- Configure VPC Flow Logs where required.

## Phase 5 — Workload onboarding

- Create dev/staging/prod accounts.
- Apply baseline controls.
- Create CI/CD deploy roles.
- Create logging and monitoring integration.
- Deploy workload through pipeline, not manual console.

## Phase 6 — Validation

- Confirm IAM Identity Center access.
- Confirm SCP behavior.
- Confirm CloudTrail delivery.
- Confirm GuardDuty/security findings aggregation.
- Confirm budget alerts.
- Confirm deployment role works.
- Confirm logs and metrics flow correctly.
EOF
```

---

## Step 7 — Create local validation script

```bash
cat > scripts/validate-landing-zone-design.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Validating local landing zone design files..."

required_files=(
  "notes/ou-account-plan.md"
  "diagrams/multi-account-landing-zone.mmd"
  "policies/scp-deny-outside-approved-regions.json"
  "policies/scp-deny-cloudtrail-tampering.json"
  "policies/scp-deny-public-rds.json"
  "policies/prod-deploy-role-trust-policy.json"
  "policies/prod-ecs-deploy-permissions.json"
  "reports/account-baseline-checklist.md"
  "runbooks/landing-zone-build-runbook.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing: $file"
    exit 1
  fi
  echo "OK: $file"
done

echo
echo "Validating JSON policy files..."
for policy in policies/*.json; do
  python3 -m json.tool "$policy" >/dev/null
  echo "Valid JSON: $policy"
done

echo
echo "Landing zone design pack validation passed."
EOF

chmod +x scripts/validate-landing-zone-design.sh

./scripts/validate-landing-zone-design.sh
```

---

## 29. Optional read-only AWS Organizations discovery commands

Only run these if your current identity has Organizations permissions.

These commands only read.

```bash
aws sts get-caller-identity

aws organizations describe-organization

aws organizations list-roots

aws organizations list-accounts \
  --query 'Accounts[].{Name:Name,Id:Id,Email:Email,Status:Status,Joined:JoinedTimestamp}' \
  --output table
```

List OUs under root:

```bash
ROOT_ID="$(aws organizations list-roots --query 'Roots[0].Id' --output text)"

aws organizations list-organizational-units-for-parent \
  --parent-id "$ROOT_ID" \
  --query 'OrganizationalUnits[].{Name:Name,Id:Id}' \
  --output table
```

List SCPs:

```bash
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[].{Name:Name,Id:Id,AwsManaged:AwsManaged,Description:Description}' \
  --output table
```

List delegated administrators:

```bash
aws organizations list-delegated-administrators \
  --query 'DelegatedAdministrators[].{Name:Name,Id:Id,Email:Email,Status:Status}' \
  --output table
```

---

## 30. Common multi-account mistakes

### Mistake 1 — Running workloads in management account

Bad:

```text
prod app inside management account
```

Fix:

```text
move workloads to member accounts
limit management account usage
use delegated admin accounts
```

### Mistake 2 — Too many nested OUs

Bad:

```text
Root
  └── India
      └── Engineering
          └── Backend
              └── Dev
                  └── TeamA
```

Fix:

```text
keep OU structure shallow
group by controls and operational needs
```

AWS recommends avoiding overly deep OU hierarchies because they are difficult to understand and maintain. ([AWS Documentation][3])

### Mistake 3 — SCPs attached without testing

Bad:

```text
attach strict deny policy to root
break production
```

Fix:

```text
test in sandbox OU
move one account first
review service last accessed data
roll out gradually
```

### Mistake 4 — IAM users in every account

Bad:

```text
vivek user in dev
vivek user in staging
vivek user in prod
```

Fix:

```text
IAM Identity Center
federated access
temporary role sessions
permission sets
```

AWS recommends federated access through IAM Identity Center to avoid managing individual users in each account and to allow humans to use temporary credentials instead of long-term access keys. ([AWS Documentation][3])

### Mistake 5 — Logs stored in workload accounts only

Bad:

```text
attacker compromises workload account
deletes CloudTrail logs
```

Fix:

```text
organization trail
central Log Archive account
restricted access
S3 Object Lock where needed
```

### Mistake 6 — No prod/non-prod separation

Bad:

```text
dev and prod in same account
same IAM roles
same VPC
same pipelines
```

Fix:

```text
separate dev/staging/prod accounts
different guardrails
different deployment roles
different budgets
```

---

## 31. Production multi-account checklist

Before saying your AWS foundation is production-ready:

```text
1. Management account has MFA and no workloads.
2. IAM Identity Center is enabled.
3. OUs are organized by security/operation needs.
4. Security OU exists.
5. Log Archive account exists.
6. Security Tooling account exists.
7. Network account exists if centralized networking is needed.
8. Workload accounts are separated by environment.
9. Organization CloudTrail is enabled.
10. GuardDuty/Security Hub/Inspector delegation is planned.
11. SCPs are tested before rollout.
12. Prod and non-prod are separated.
13. CI/CD uses cross-account roles.
14. iam:PassRole is restricted.
15. Budget alerts exist per account.
16. Required tags are defined.
17. Central logging retention is defined.
18. Backup ownership is defined.
19. Break-glass access exists and is tested.
20. Account vending/onboarding process is documented.
```

---

## 32. Certification angle

### CLF-C02

Know:

```text
AWS Organizations centrally manages multiple AWS accounts.
OUs group accounts.
SCPs set maximum permissions but do not grant permissions.
Consolidated billing aggregates billing.
IAM Identity Center centralizes workforce access.
Control Tower helps set up and govern a landing zone.
```

### SAA-C03

Know deeply:

```text
management account vs member account
OU structure
prod vs non-prod separation
Security/Infrastructure/Workloads OU patterns
Log Archive and Security Tooling accounts
SCP evaluation and limitations
cross-account roles
centralized network account
shared services account
landing zone design
Control Tower account factory idea
```

### DOP-C02

Know operationally:

```text
multi-account CI/CD
cross-account deploy roles
delegated administrator setup
organization-wide CloudTrail
security finding aggregation
SCP rollout/testing
IAM Identity Center permission sets
break-glass process
account baseline automation
StackSets/Terraform account vending
central logs and incident response
```

---

## 33. Interview answer

Memorize this:

```text
In AWS production environments, I prefer a multi-account architecture because AWS accounts provide strong isolation for security, cost, quotas, workloads, and blast-radius control. I use AWS Organizations to manage accounts centrally, group them into OUs, apply service control policies, enable AWS services across accounts, and manage consolidated billing.

A typical landing zone has a management account for organization and billing administration, a Security OU with Log Archive and Security Tooling accounts, an Infrastructure OU with Network and Shared Services accounts, and separate workload accounts for dev, staging, and production. I avoid deploying workloads in the management account because it has privileged organization-level capabilities and SCPs do not apply to it.

For human access, I use IAM Identity Center with permission sets instead of creating IAM users in every account. For automation, I use cross-account roles so a CI/CD pipeline in a shared account can assume deployment roles in dev, staging, or prod. I restrict iam:PassRole and keep deployment permissions least-privilege.

For governance, I use SCPs as permission guardrails. SCPs do not grant permissions; they only define maximum allowed permissions for member accounts. I apply SCPs at OU level where possible, test them in sandbox first, and avoid attaching strict policies directly to the organization root without validation. For observability and security, I centralize CloudTrail and service logs in a Log Archive account and delegate security services like GuardDuty, Security Hub, Inspector, and Macie to a Security Tooling account.
```

---

## 34. Quick quiz

```text
1. Why use multiple AWS accounts?
2. What is AWS Organizations?
3. What is the management account?
4. Should workloads run in the management account?
5. What is a member account?
6. What is an OU?
7. What is a landing zone?
8. What is Control Tower?
9. What is an SCP?
10. Does an SCP grant permissions?
11. Do SCPs affect the management account?
12. What is IAM Identity Center used for?
13. What is a permission set?
14. What is a cross-account role?
15. What is delegated administrator?
16. What is the Log Archive account for?
17. What is the Security Tooling account for?
18. What is the Network account for?
19. Why separate prod and non-prod accounts?
20. Why should SCPs be tested before rollout?
```

Answers:

```text
1. Security, cost, quota, workload, and blast-radius isolation.
2. AWS service for centrally managing multiple AWS accounts.
3. The account that owns and manages the AWS Organization.
4. No, avoid workloads there.
5. Any account inside the organization except the management account.
6. Organizational Unit, a group/folder of accounts.
7. Governed multi-account AWS foundation.
8. AWS service for setting up and governing a landing zone.
9. Service Control Policy, an organization-level permission guardrail.
10. No.
11. No, they affect member accounts.
12. Central workforce access across accounts.
13. Template of permissions assigned to users/groups for accounts.
14. IAM role assumed from another AWS account.
15. Member account authorized to administer an AWS service for the organization.
16. Central immutable/security log storage.
17. Central security operations and delegated security services.
18. Shared network services such as TGW, resolver, VPN/DX, inspection.
19. Different risk, access, cost, and change-control requirements.
20. A wrong SCP can accidentally block important services or operations.
```

# Next Lesson

```text
AWS Lesson 18 — Cost Optimization and FinOps:
Budgets, Cost Explorer, tags, CUR, Savings Plans, Reserved Instances, right-sizing, S3 lifecycle, EBS cleanup, NAT Gateway cost traps, CloudWatch log retention, idle resource detection, and production cost governance
```

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html "What is AWS Organizations? - AWS Organizations"
[2]: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/benefits-of-using-multiple-aws-accounts.html?utm_source=chatgpt.com "Benefits of using multiple AWS accounts - Organizing Your AWS Environment Using Multiple Accounts"
[3]: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/design-principles-for-your-multi-account-strategy.html "Design principles for your multi-account strategy - Organizing Your AWS Environment Using Multiple Accounts"
[4]: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/recommended-ous-and-accounts.html?utm_source=chatgpt.com "Recommended OUs and accounts - Organizing Your AWS Environment Using Multiple Accounts"
[5]: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/how-does-aws-control-tower-establish-your-multi-account-environment.html "How does AWS Control Tower establish your multi-account environment? - Organizing Your AWS Environment Using Multiple Accounts"
[6]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html "Service control policies (SCPs) - AWS Organizations"
[7]: https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-and-orgs.html "IAM Identity Center and AWS Organizations - AWS IAM Identity Center"
[8]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with Organizations - AWS Organizations"
[9]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/log-archive.html?utm_source=chatgpt.com "Security OU – Log Archive account - AWS Prescriptive Guidance"
[10]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/network.html?utm_source=chatgpt.com "Infrastructure OU – Network account - AWS Prescriptive Guidance"
[11]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/shared-services.html?utm_source=chatgpt.com "Infrastructure OU – Shared Services account - AWS Prescriptive Guidance"
