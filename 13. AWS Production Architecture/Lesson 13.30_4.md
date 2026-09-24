# AWS Masterclass — Lesson 30 Part 4

# IAM Enterprise Operations — Identity Center, Multi-Account Governance, Access Analyzer & Production IAM Capstone

This is the **final part of Lesson 30**.

We now combine everything from:

```text
Part 1
IAM identities, roles, policies, STS
        ↓
Part 2
SCPs, RCPs, boundaries,
session policies, KMS,
effective permissions
        ↓
Part 3
PassRole, privilege escalation,
OIDC, federation, MFA, ABAC
        ↓
Part 4
ENTERPRISE OPERATING MODEL
```

The goal is no longer merely:

> “Can I write an IAM policy?”

The goal becomes:

> **“How would I operate identity and authorization securely across 10, 100, or 1,000 AWS accounts?”**

---

# 1. Why One AWS Account Eventually Becomes a Problem

Imagine everything is in:

```text
AWS Account
│
├── Production
├── Staging
├── Development
├── Security
├── Networking
├── Logging
├── CI/CD
└── Experiments
```

Then somebody with broad permissions may potentially affect:

```text
production
security logging
networking
development
```

from the same account.

A mature AWS architecture normally introduces **multiple AWS accounts**, organized through AWS Organizations, so account boundaries become part of the security and operational model. AWS Organizations provides centralized account management, OUs, delegated administration, and organization policies such as SCPs and RCPs. ([AWS Documentation][1])

---

# 2. Enterprise Multi-Account Mental Model

A realistic structure might look like:

```text
                    AWS ORGANIZATION
                          │
                          ▼
                    Management Account
                          │
              ┌───────────┼───────────┐
              │           │           │
              ▼           ▼           ▼

          Security OU   Platform OU   Workloads OU
              │           │           │
        ┌─────┴────┐      │       ┌───┴────────┐
        ▼          ▼      ▼       ▼            ▼
    Security    Log     Shared   Dev        Production
    Tooling    Archive Services  Account     Account

                                       ┌────────┴───────┐
                                       ▼                ▼
                                  Prod-App          Prod-Data
```

OUs let you group accounts according to workload, security, business function, lifecycle, or other organizational boundaries and attach policies higher in the hierarchy. ([AWS Documentation][1])

---

# 3. The Management Account

The Organizations:

```text
Management Account
```

is special.

It can perform organization-level operations such as:

```text
create/manage accounts
manage OUs
attach organization policies
designate delegated administrators
```

AWS explicitly recommends carefully protecting this account because it has organization-wide administrative capabilities. ([AWS Documentation][2])

### Production rule

```text
MANAGEMENT ACCOUNT
≠
application workload account
```

Avoid running normal:

```text
EC2 applications
customer APIs
databases
CI workloads
```

there unless there is a compelling reason.

---

# 4. Member Accounts

Most workloads should live in:

```text
MEMBER ACCOUNTS
```

For example:

```text
Account 1
Security

Account 2
Log Archive

Account 3
Shared Services

Account 4
Development

Account 5
Staging

Account 6
Production
```

Then organization-wide controls can constrain those accounts using:

```text
SCPs
RCPs
centralized security services
```

SCPs affect member-account principals, not users and roles in the Organizations management account. ([AWS Documentation][3])

---

# 5. IAM Identity Center Solves Human Access

Without centralized workforce access:

```text
Vivek
│
├── IAM user in Dev
├── IAM user in Staging
├── IAM user in Prod
├── IAM user in Security
└── IAM user in Networking
```

Problems:

```text
multiple passwords
multiple access keys
multiple MFA configurations
manual onboarding
manual offboarding
permission drift
```

Modern architecture:

```text
                    EMPLOYEE
                       │
                       ▼
               Corporate Identity
                       │
                       ▼
              IAM Identity Center
                       │
                Users / Groups
                       │
                       ▼
                Permission Sets
                       │
              ┌────────┼────────┐
              ▼        ▼        ▼
             Dev    Staging   Production
```

IAM Identity Center provides a centralized place to assign workforce users and groups permission sets across multiple AWS accounts. ([AWS Documentation][4])

---

# 6. What Is a Permission Set?

A:

# Permission Set

defines the permissions a workforce user receives when accessing an AWS account through IAM Identity Center.

Example:

```text
Permission Set:
DeveloperAccess
```

might include:

```text
EC2 read
ECS deploy
CloudWatch read
S3 artifact access
```

Another:

```text
ProductionReadOnly
```

might contain:

```text
CloudWatch read
EC2 describe
RDS describe
ECS describe
```

IAM Identity Center stores permission sets centrally, and one permission set can be assigned across multiple AWS accounts. ([AWS Documentation][5])

---

# 7. Permission Set Is Not an IAM Group

Don't confuse:

```text
IAM Identity Center Permission Set
```

with:

```text
IAM User Group
```

Permission set:

```text
centralized workforce access definition
```

IAM group:

```text
collection of IAM users
inside one AWS account
```

Different systems.

---

# 8. Account Assignment

A permission set alone doesn't give someone account access.

You combine:

```text
PRINCIPAL
+
ACCOUNT
+
PERMISSION SET
```

Example:

```text
Developers Group
      │
      ├── Dev Account
      │      └── DeveloperAccess
      │
      └── Staging Account
             └── ReadOnly
```

IAM Identity Center refers to this as assigning a user/group access to an AWS account using a permission set. ([AWS Documentation][6])

---

# 9. One User Can Have Multiple Permission Sets

Suppose you're an administrator.

You shouldn't always operate with:

```text
AdministratorAccess
```

You could have:

```text
ProductionReadOnly

ProductionDeploy

ProductionAdmin
```

and intentionally choose the lowest privilege needed for the current task.

AWS recommends this type of model; the Identity Center documentation notes that administrative users can have additional, more restrictive permission sets for ordinary work. ([AWS Documentation][5])

This is excellent security hygiene:

```text
DAILY ACCESS
=
LOW PRIVILEGE

ELEVATED ACCESS
=
ONLY WHEN REQUIRED
```

---

# 10. Group-Based Assignment

Don't assign 800 developers one by one.

Instead:

```text
Identity Center Group
Engineering-Developers
       │
       ▼
DeveloperAccess
       │
       ▼
Development Account
```

Add employee:

```text
Group membership +
```

Remove employee:

```text
Group membership -
```

Access changes with the group assignment. IAM Identity Center specifically recommends groups for scalable account/application assignments. ([AWS Documentation][7])

---

# 11. External Corporate Identity Provider

Enterprises often already use:

```text
Microsoft Entra ID
Okta
Active Directory
another identity provider
```

Then:

```text
Corporate IdP
      │
      ▼
IAM Identity Center
      │
      ▼
AWS accounts
```

instead of maintaining an entirely independent workforce directory in every AWS account. IAM Identity Center can use its own identity store or integrate with external identity sources. ([AWS Documentation][4])

---

# 12. Enterprise Human Access Architecture

```text
                   EMPLOYEE LAPTOP
                         │
                         ▼
                Corporate Identity
                         │
                  MFA / SSO / IdP
                         │
                         ▼
                IAM Identity Center
                         │
                  Identity Group
                         │
                         ▼
                 Permission Set
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
             DEV      STAGING     PROD
              │          │          │
           Role A      Role B      Role C
              │          │          │
              ▼          ▼          ▼
        Temporary    Temporary   Temporary
        Credentials  Credentials Credentials
```

This is far superior to:

```text
100 employees
×
10 AWS accounts
=
1,000 manually managed IAM users
```

---

# 13. Separate Job Functions

Example permission-set model:

| Permission Set       | Typical Use                                    |
| -------------------- | ---------------------------------------------- |
| `Developer`          | Dev application work                           |
| `DevOpsDeploy`       | CI/CD and deployments                          |
| `ProductionReadOnly` | Production inspection                          |
| `NetworkAdmin`       | VPC/TGW/Route 53                               |
| `DatabaseAdmin`      | DB administration                              |
| `SecurityAudit`      | Security inspection                            |
| `IncidentResponder`  | Temporary production incident access           |
| `Administrator`      | Restricted break-glass/elevated administration |

The point isn't these exact names.

The point is:

```text
JOB FUNCTION
      ↓
PERMISSION SET
      ↓
ACCOUNT ASSIGNMENT
```

rather than:

```text
PERSON
      ↓
random permissions
```

---

# 14. Environment Separation

Developers could receive:

```text
Dev:
DeveloperAccess
```

```text
Staging:
DeploymentAccess
```

```text
Production:
ReadOnly
```

Production changes could instead require:

```text
ProductionDeploy
```

through a more restricted workflow.

Now the same human identity can have **different authority in different AWS accounts** without separate permanent IAM-user credentials.

---

# 15. Multi-Account Guardrail Architecture

Now combine Identity Center with Organizations:

```text
                     AWS ORGANIZATION
                           │
                    ┌──────┴───────┐
                    ▼              ▼
                   SCP            RCP
          principal guardrail   resource guardrail
                    │              │
                    └──────┬───────┘
                           ▼
                   MEMBER ACCOUNTS
                           ▲
                           │
               IAM Identity Center
                           │
                    Permission Sets
                           │
                           ▼
                   Workforce Access
```

SCPs and RCPs centrally restrict permissions/resources in member accounts; IAM Identity Center handles the workforce-access assignment model. ([AWS Documentation][8])

---

# 16. Important Mental Separation

```text
IDENTITY CENTER
=
WHO gets which role-like account access
```

```text
IAM
=
permissions inside accounts
```

```text
SCP
=
maximum permissions for member-account principals
```

```text
RCP
=
resource-side organization guardrails
```

These systems complement one another.

---

# 17. Example Production SCP

Production OU guardrails might prevent:

```text
disabling CloudTrail

leaving the Organization

certain unapproved Regions

modifying central security controls
```

even if a local account administrator receives broad IAM permissions.

SCPs provide maximum permission guardrails and can override local allows through explicit deny. ([AWS Documentation][3])

---

# 18. RCP Example

Suppose sensitive S3 resources should never accept access from outside your approved trust boundary.

RCP:

```text
Organization-level
resource guardrail
```

can restrict access to supported resources even when somebody accidentally writes an overly permissive resource policy. AWS describes RCPs as centrally controlled limits on access to resources in member accounts. ([AWS Documentation][9])

---

# 19. IAM Boundary Still Has a Place

Organizations controls:

```text
accounts
OUs
resources
```

Permissions boundaries are useful **inside accounts** when delegating IAM creation.

Example:

```text
Developer
    │
    ▼
may create application roles
    │
    ▼
BUT every app role
must have
WorkloadBoundary
```

So:

```text
SCP
=
organization/account guardrail
```

```text
Boundary
=
identity-specific permission ceiling
```

Both can exist together.

---

# 20. Workload Access Model

Humans:

```text
Identity Center
```

Workloads:

```text
IAM Roles
```

Examples:

```text
EC2
→ Instance Role

Lambda
→ Execution Role

ECS
→ Task Role

GitHub
→ OIDC Deploy Role
```

A mature AWS architecture tries to avoid turning workforce and workload identity into one giant shared IAM user/key model.

---

# 21. CloudTrail Completes the IAM Story

IAM tells you:

```text
WHAT IS ALLOWED?
```

CloudTrail tells you:

```text
WHAT ACTUALLY HAPPENED?
```

CloudTrail records API activity made through the console, CLI, SDKs, and other AWS API paths, including information about the calling identity. ([AWS Documentation][10])

This is why IAM incident response nearly always touches CloudTrail.

---

# 22. CloudTrail `userIdentity`

Suppose:

```text
ec2:TerminateInstances
```

occurred.

CloudTrail's:

```text
userIdentity
```

information can help determine whether the request originated from:

```text
IAM user
assumed role
AWS service
federated user/session
```

and which credentials/session context were used. ([AWS Documentation][11])

---

# 23. Assumed Role Audit Trail

Example conceptually:

```text
userIdentity:
  type: AssumedRole

sessionIssuer:
  ProductionAdminRole
```

Now you know:

```text
role used
```

but also want:

```text
which original person?
```

This is where:

```text
SourceIdentity
```

from Part 3 becomes valuable.

AWS supports requiring source identity during role assumption and carrying it into CloudTrail logs. ([AWS Documentation][12])

---

# 24. Source Identity Architecture

```text
Employee
vivek@example.com
      │
      ▼
Assume ProductionAdminRole
      │
SourceIdentity:
vivek@example.com
      │
      ▼
Role session
      │
      ▼
Terminate instance
      │
      ▼
CloudTrail

ProductionAdminRole
+
sourceIdentity:
vivek@example.com
```

Now the incident investigator can trace:

```text
role activity
```

back toward:

```text
original actor.
```

---

# 25. CloudTrail Is Also Needed for Identity Center Administration

IAM Identity Center API operations are integrated with CloudTrail, including changes made through supported console/API paths. ([AWS Documentation][13])

That lets you audit:

```text
Who changed permission set?

Who assigned ProductionAdmin?

Who removed account assignment?

Who changed Identity Center configuration?
```

Identity administration itself should be auditable.

---

# 26. IAM Access Analyzer — Enterprise Perspective

IAM Access Analyzer now has three major analysis categories:

```text
External Access

Internal Access

Unused Access
```

and also provides IAM policy validation capabilities. ([AWS Documentation][14])

These solve different questions.

---

# 27. External Access Analyzer

Question:

> **“Which supported resources can principals outside my zone of trust access?”**

Example:

```text
S3 bucket
   │
   ▼
bucket policy
   │
   ▼
External Account
```

Access Analyzer can identify supported resource policies/trust policies that create external access paths. ([AWS Documentation][14])

This is excellent for finding:

```text
unexpected cross-account trust
public sharing
external role trust
```

---

# 28. Internal Access Analyzer

Question:

> **“Which principals inside my organization can access this important resource?”**

Example:

```text
Sensitive Resource
       ▲
       │
 ┌─────┼──────────┐
 ▼     ▼          ▼
RoleA RoleB      UserC
```

Internal access analyzers can identify possible access paths between IAM principals within the selected scope and selected resources. ([AWS Documentation][15])

This flips IAM troubleshooting around.

Normally:

```text
What can Role A access?
```

Now:

```text
WHO can access Resource X?
```

---

# 29. Unused Access Analyzer

Question:

> **“Which permissions exist but are no longer being used?”**

It can identify findings involving:

```text
unused roles

unused IAM user access keys

unused IAM user passwords

unused services

unused actions
```

based on the analyzer's configured usage window. ([AWS Documentation][14])

This is invaluable for reducing:

```text
permission creep.
```

---

# 30. Important Access Analyzer Regional Detail

Current AWS documentation states that IAM Access Analyzer is Regional.

For:

```text
external access

internal access
```

you enable analyzers independently in the Regions you need to analyze.

Unused-access findings, however, are not meaningfully different per Region in the same way, so an unused-access analyzer does not need to be duplicated simply for every Region containing workloads. ([AWS Documentation][16])

This is worth remembering for enterprise deployments.

---

# 31. Unused Access Window

Current Access Analyzer CLI supports configuring an unused access age between:

```text
1 and 365 days
```

for applicable unused access analyzers. ([AWS Documentation][17])

Example:

```text
Unused if not exercised
for 90 days
```

might be a reasonable starting point for one organization.

But:

```text
90 days
```

is not universally safe.

Consider:

```text
quarterly tasks

annual certificate operations

disaster recovery roles

break-glass roles
```

before removing permission.

---

# 32. Access Analyzer CLI Inspection

List analyzers:

```bash
aws accessanalyzer list-analyzers \
  --region ap-south-1
```

For newer internal/unused analyzers, findings can be queried with:

```bash
aws accessanalyzer list-findings-v2 \
  --analyzer-arn <ANALYZER_ARN> \
  --region ap-south-1
```

Current AWS CLI documentation requires `list-findings-v2` for internal and unused-access analyzers; the older `list-findings` operation is for external-access analyzers. ([AWS Documentation][18])

---

# 33. IAM Credential Report

For IAM users:

```bash
aws iam generate-credential-report
```

Then:

```bash
aws iam get-credential-report
```

Use the report to inspect IAM-user credential posture, including password/access-key/MFA-related status information.

This is especially helpful while migrating from:

```text
old IAM users
```

toward:

```text
Identity Center + roles.
```

---

# 34. Account Authorization Inventory

Another useful IAM command:

```bash
aws iam get-account-authorization-details
```

It can return account IAM authorization information covering:

```text
users
groups
roles
managed policies
```

in the account. ([AWS Documentation][19])

This can be large, but it's useful during:

```text
security audits
migration assessments
IAM cleanup
```

---

# 35. Inspect a Specific Role

Trust:

```bash
aws iam get-role \
  --role-name TerraformRole
```

Attached managed policies:

```bash
aws iam list-attached-role-policies \
  --role-name TerraformRole
```

Inline policies:

```bash
aws iam list-role-policies \
  --role-name TerraformRole
```

AWS CLI provides these operations specifically to inspect role trust/configuration and attached policy relationships. ([AWS Documentation][20])

---

# 36. IAM Policy Simulator

For an existing principal:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<ACCOUNT>:role/TerraformRole \
  --action-names \
    ec2:DescribeSecurityGroups \
    ecr:CreateRepository
```

The simulator evaluates the specified principal's IAM policy behavior for requested actions/resources. ([AWS Documentation][21])

But remember Part 2:

```text
SIMULATOR
≠
EVERY POSSIBLE AWS AUTHORIZATION LAYER
```

You may still need to inspect:

```text
SCP
RCP
resource policy
KMS
VPC endpoint policy
cross-account policy
```

---

# 37. Organization Investigation Commands

Find organization roots:

```bash
aws organizations list-roots
```

Find OUs:

```bash
aws organizations list-organizational-units-for-parent \
  --parent-id <ROOT_OR_OU_ID>
```

Find accounts directly beneath an OU:

```bash
aws organizations list-accounts-for-parent \
  --parent-id <OU_ID>
```

AWS CLI documents these operations for navigating the Organizations hierarchy. ([AWS Documentation][22])

---

# 38. Which SCP Is Attached?

```bash
aws organizations list-policies-for-target \
  --target-id <ACCOUNT_OR_OU_ID> \
  --filter SERVICE_CONTROL_POLICY
```

This lists policies **directly attached** to that target. ([AWS Documentation][23])

But remember:

```text
direct attachment
+
inherited parent policies
```

both matter.

So debugging SCPs often requires walking:

```text
Account
    ↑
OU
    ↑
Parent OU
    ↑
Root
```

---

# 39. IAM Identity Center CLI

The IAM Identity Center administrative API is exposed through:

```text
aws sso-admin
```

for multi-account permission-set/account-assignment administration. ([AWS Documentation][24])

You can inspect permission sets:

```bash
aws sso-admin list-permission-sets \
  --instance-arn <INSTANCE_ARN> \
  --region <IDENTITY_CENTER_REGION>
```

`list-permission-sets` is a paginated operation against a particular IAM Identity Center instance. ([AWS Documentation][25])

---

# 40. Inspect Account Assignments

For a known:

```text
ACCOUNT_ID
PERMISSION_SET_ARN
```

you can use:

```bash
aws sso-admin list-account-assignments \
  --instance-arn <INSTANCE_ARN> \
  --account-id <ACCOUNT_ID> \
  --permission-set-arn <PERMISSION_SET_ARN> \
  --region <IDENTITY_CENTER_REGION>
```

The Identity Center API supports enumerating the users/groups assigned a particular permission set in a particular AWS account. ([AWS Documentation][26])

There is also current CLI support for listing account assignments for a particular principal. ([AWS Documentation][27])

---

# 41. Recommended Workforce Design

Suppose enterprise has:

```text
Engineering
Security
Platform
Finance
```

Use identity groups such as:

```text
Engineering-Developers

Platform-Engineers

Security-Auditors

Production-Responders
```

Then permission sets:

```text
DevDeveloper

StagingDeployer

ProdReadOnly

ProdIncidentResponder

SecurityAudit
```

Then assignments:

```text
GROUP
   +
ACCOUNT
   +
PERMISSION SET
```

This is much easier to reason about than user-by-user direct permissions.

---

# 42. Break-Glass Access

You also need an answer for:

> “What if federation/Identity Center is unavailable or a critical emergency requires unusually privileged action?”

That is where carefully designed:

```text
break-glass access
```

comes in.

Characteristics should include:

```text
rarely used
strong MFA
high monitoring
restricted custody
documented procedure
immediate incident review after use
```

It should **not** become:

```text
the account everyone uses every Friday.
```

---

# 43. Root Access in Multi-Account Environments

AWS now recommends centralized root-access management for Organizations and specifically recommends removing member-account root credentials where appropriate. ([AWS Documentation][28])

Mental model:

```text
MANAGEMENT ACCOUNT
root extremely protected

MEMBER ACCOUNTS
centralized/root controls
where organization model supports it
```

Root should not be your normal recovery mechanism.

---

# 44. Production Identity Lifecycle

Consider employee lifecycle.

## Joiner

```text
Employee added to corporate IdP
      │
      ▼
group membership
      │
      ▼
Identity Center assignment
      │
      ▼
AWS temporary access
```

## Mover

```text
Engineer
→ Security team
```

Update:

```text
group membership
```

instead of finding 25 IAM-user policies manually.

## Leaver

```text
disable identity
      │
      ▼
federated AWS access removed
```

This is one of centralized identity's biggest operational advantages.

---

# 45. Privileged Access Should Be Temporary

Instead of:

```text
Admin group
365 days/year
```

stronger patterns aim toward:

```text
normal role
       │
       ▼
read/deploy access

exception
       │
       ▼
time-limited privileged access
       │
       ▼
strong approval/audit
```

Even if your specific identity provider implements just-in-time elevation outside AWS, the AWS role architecture should make such separation possible.

---

# 46. The Full IAM Troubleshooting Lab

Now let's solve a realistic problem.

Terraform pipeline fails with:

```text
5 different authorization errors
```

We will fix them one by one rather than attaching:

```text
AdministratorAccess
```

to everything.

Architecture:

```text
Jenkins / GitHub / Terraform
          │
          ▼
     TerraformRole
          │
          ├── EC2
          ├── ECR
          ├── S3
          ├── KMS
          └── PassRole
```

---

# 47. LAB ERROR 1 — `ec2:DescribeSecurityGroups`

Terraform:

```text
Error:
UnauthorizedOperation

not authorized to perform:
ec2:DescribeSecurityGroups
```

Step one:

```bash
aws sts get-caller-identity
```

Suppose result:

```text
assumed-role/TerraformRole/build-405
```

Good.

We confirmed:

```text
WHO?
=
TerraformRole
```

---

# 48. Inspect the Role

```bash
aws iam list-attached-role-policies \
  --role-name TerraformRole
```

Suppose policy contains:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:RunInstances",
    "ec2:CreateTags"
  ],
  "Resource": "*"
}
```

But missing:

```text
ec2:DescribeSecurityGroups
```

Then this is likely simply:

```text
IMPLICIT DENY
```

because there is no applicable allow.

---

# 49. Fix EC2 Discovery Permissions

Add the read APIs Terraform actually needs, for example depending on the configuration:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeVpcs",
    "ec2:DescribeImages",
    "ec2:DescribeInstances",
    "ec2:DescribeInstanceTypes"
  ],
  "Resource": "*"
}
```

Do not blindly copy every permission forever.

Use provider behavior and AccessDenied evidence to build the actual least-privilege set.

---

# 50. LAB ERROR 2 — `ecr:CreateRepository`

Next:

```text
AccessDeniedException:

not authorized to perform:
ecr:CreateRepository
```

Caller:

```text
TerraformRole
```

Policy has:

```text
ecr:GetAuthorizationToken

ecr:BatchCheckLayerAvailability

ecr:PutImage
```

but not:

```text
ecr:CreateRepository
```

Again:

```text
IMPLICIT DENY
```

not some mysterious AWS failure.

---

# 51. Fix ECR Create Permission

Conceptually:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:CreateRepository",
    "ecr:DescribeRepositories"
  ],
  "Resource": "*"
}
```

Then scope repository operations more tightly where the relevant ECR actions/resource authorization permit it.

This illustrates the same rule:

```text
PUSH TO REPOSITORY
≠
CREATE REPOSITORY
```

Different AWS APIs need different IAM actions.

---

# 52. LAB ERROR 3 — S3 State Access Denied

Terraform now fails:

```text
AccessDenied

s3:GetObject
```

on:

```text
terraform-state/prod/terraform.tfstate
```

TerraformRole policy clearly contains:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource":
    "arn:aws:s3:::my-state-bucket/*"
}
```

So:

```text
identity policy Allow
exists.
```

Now the investigation changes.

---

# 53. Check Bucket Policy

Perhaps bucket policy says:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::my-state-bucket",
    "arn:aws:s3:::my-state-bucket/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

This is good if your request uses TLS.

But maybe another statement says:

```text
Deny unless principal
comes through approved VPC endpoint
```

If Terraform executes outside that VPC endpoint:

```text
EXPLICIT DENY
```

wins.

Adding another IAM Allow will not fix it.

---

# 54. The S3 Troubleshooting Layers

For S3:

```text
Identity policy
     │
     ▼
Permissions boundary
     │
     ▼
Session policy
     │
     ▼
SCP
     │
     ▼
Bucket policy
     │
     ▼
RCP
     │
     ▼
VPC endpoint policy
     │
     ▼
KMS if encrypted
```

One S3 `AccessDenied` may come from any of these applicable layers.

That is why:

```text
"attach AmazonS3FullAccess"
```

is a weak troubleshooting methodology.

---

# 55. LAB ERROR 4 — KMS Decrypt Denied

Terraform state uses:

```text
SSE-KMS
```

S3 permissions succeed, but now:

```text
AccessDeniedException

kms:Decrypt
```

IAM role:

```text
Allow kms:Decrypt
```

exists.

What next?

Check:

```text
KMS Key Policy
```

because KMS authorization is not based solely on a generic IAM allow.

If key policy does not permit the role/account authorization model, the decrypt request can still fail.

---

# 56. KMS Investigation Flow

```text
kms:Decrypt denied
       │
       ▼
Correct key ARN?
       │
       ▼
IAM allow?
       │
       ▼
Key policy?
       │
       ▼
Grant?
       │
       ▼
SCP?
       │
       ▼
RCP?
       │
       ▼
Boundary?
       │
       ▼
Endpoint policy?
```

This was one of the biggest lessons from Part 2:

```text
KMS
=
IAM
+
KEY AUTHORIZATION MODEL
```

not merely IAM.

---

# 57. LAB ERROR 5 — `iam:PassRole`

Terraform launches EC2:

```hcl
iam_instance_profile = aws_iam_instance_profile.app.name
```

Then:

```text
AccessDenied:

iam:PassRole
```

Why?

Terraform is asking EC2:

> Launch this instance **using this application role**.

Terraform itself doesn't need to become the application role.

It needs permission to:

```text
PASS
```

that role to EC2.

---

# 58. BAD PassRole Fix

Do not use:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

That may allow TerraformRole to pass highly privileged roles to services it can control.

---

# 59. GOOD PassRole Fix

Example:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource":
    "arn:aws:iam::111122223333:role/app/*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService":
        "ec2.amazonaws.com"
    }
  }
}
```

Now:

```text
TerraformRole
can pass only:

role/app/*
```

and only to:

```text
EC2
```

This greatly reduces privilege-escalation risk.

---

# 60. But EC2 Role Trust Must Also Be Correct

Application role trust:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

So the full path is:

```text
TerraformRole
   │
   │ iam:PassRole
   ▼
AppEC2Role
   │
   │ trust EC2
   ▼
EC2 Service
   │
   ▼
EC2 workload receives role
```

If either:

```text
PassRole permission
```

or:

```text
role trust
```

is wrong, the design fails.

---

# 61. What If We Still Get AccessDenied?

Suppose TerraformRole now has all five needed permissions.

Yet:

```text
ec2:RunInstances
```

still denied.

Now inspect:

```text
permissions boundary?
SCP?
session policy?
```

Perhaps organization SCP says:

```text
EC2 launches allowed only
in ap-south-1
```

but Terraform provider is configured:

```text
eu-west-1
```

Then:

```text
AdministratorAccess
+
required EC2 permissions
```

still won't matter.

---

# 62. Investigate SCPs Systematically

You need to determine:

```text
Which account?
Which OU?
Parent OU?
Root?
```

Then inspect policies attached through the hierarchy.

Commands such as:

```bash
aws organizations list-roots
```

```bash
aws organizations list-organizational-units-for-parent \
  --parent-id <PARENT_ID>
```

and:

```bash
aws organizations list-policies-for-target \
  --target-id <ID> \
  --filter SERVICE_CONTROL_POLICY
```

help reconstruct that policy ancestry. ([AWS Documentation][22])

---

# 63. The Complete AccessDenied Decision Tree

```text
                    ACCESS DENIED
                         │
                         ▼
              aws sts get-caller-identity
                         │
                         ▼
                  Correct principal?
                   │           │
                  NO          YES
                   │           │
                   ▼           ▼
            fix credential   Exact action?
            selection             │
                                  ▼
                            Exact resource?
                                  │
                                  ▼
                         Identity Allow exists?
                           │             │
                          NO            YES
                           │             │
                           ▼             ▼
                    implicit deny    Boundary?
                                           │
                                      Session policy?
                                           │
                                           ▼
                                          SCP?
                                           │
                                           ▼
                                     Resource policy?
                                           │
                                           ▼
                                          RCP?
                                           │
                                           ▼
                                  Endpoint policy?
                                           │
                                           ▼
                                  KMS/service policy?
                                           │
                                           ▼
                                     Condition match?
```

This is your permanent AWS IAM incident runbook.

---

# 64. Don't Forget Credential Source

One of the most common CLI problems:

```text
You THINK:
TerraformRole

Actually:
developer default profile
```

Run:

```bash
aws sts get-caller-identity
```

from the exact environment executing Terraform.

For Jenkins:

```text
run inside Jenkins agent
```

For GitHub:

```text
run inside workflow
```

For EC2:

```text
run on EC2
```

Not from your laptop.

---

# 65. CloudTrail Investigation

Suppose deployment unexpectedly deletes a security group.

Ask:

```text
Which API?
DeleteSecurityGroup

Who?
CloudTrail userIdentity

Which role?
sessionIssuer

Which source identity?
sourceIdentity

When?
eventTime

Where?
sourceIPAddress

What request?
requestParameters
```

CloudTrail event records contain identity and request metadata that make this type of investigation possible. ([AWS Documentation][11])

---

# 66. IAM Incident Response

Suppose an IAM role may be compromised.

Response considerations:

```text
1. Determine current sessions.

2. Identify trust policy.

3. Identify who can assume role.

4. Inspect CloudTrail.

5. Inspect SourceIdentity/session name.

6. Review permissions.

7. Review PassRole capabilities.

8. Review recently changed policies.

9. Reduce/disable access as appropriate.

10. Rotate underlying external credentials
    if applicable.

11. Remediate root cause.

12. Restore minimum required access.
```

Don't immediately delete every IAM object before collecting evidence.

---

# 67. Access Analyzer Cleanup Workflow

A mature least-privilege cycle:

```text
                IAM PERMISSIONS
                     │
                     ▼
                APPLICATION
                     │
                     ▼
                CloudTrail
                     │
                     ▼
              Access Analyzer
                     │
         ┌───────────┴──────────┐
         ▼                      ▼
    unused access          external access
         │                      │
         ▼                      ▼
       review                  review
         │                      │
         └──────────┬───────────┘
                    ▼
             reduce permissions
                    │
                    ▼
                 retest
```

Least privilege is a **continuous process**, not a one-time policy-writing activity.

---

# 68. Permission Review Cadence

For sensitive environments, periodically review:

```text
Identity Center assignments

high privilege roles

IAM users

access keys

permissions boundaries

role trust policies

PassRole permissions

unused roles

external resource access

cross-account trust

SCP/RCP changes
```

Your frequency depends on:

```text
risk
compliance
change rate
organization size
```

not an arbitrary universal number.

---

# 69. Production IAM KPIs

Useful operational measurements include:

```text
Number of IAM users with long-lived keys

Number of privileged identities

Privileged identities without MFA

Unused roles

Unused keys

External-access findings

Open Access Analyzer findings

Wildcard PassRole policies

Wildcard IAM policy actions

Roles without clear ownership

Expired/departed workforce assignments
```

This is how you turn IAM into an operational security program rather than a JSON-file collection.

---

# 70. Account Ownership Metadata

Every important role/policy should ideally answer:

```text
Owner?

Application?

Environment?

Purpose?

Ticket/repository?

Review date?
```

Use:

```text
tags

naming standards

IaC metadata

documentation
```

where appropriate.

A role named:

```text
temp-role-final-new2
```

will eventually become an incident-response problem.

---

# 71. IAM Naming Example

Better:

```text
prod-todo-api-ecs-task-role

prod-todo-api-deploy-role

security-audit-crossaccount-role

platform-terraform-execution-role
```

You can infer:

```text
environment
application
function
identity type
```

from the name.

Naming is not authorization—but it greatly improves operations.

---

# 72. Separate Execution Role and Application Role

For ECS, for example:

```text
Task Execution Role
```

and:

```text
Task Role
```

solve different concerns.

Conceptually:

```text
ECS platform
    │
    ▼
Execution Role
    │
    ├── pull image
    └── publish logs
```

while:

```text
Application container
    │
    ▼
Task Role
    │
    ├── DynamoDB
    ├── S3
    └── Secrets Manager
```

This is the same broader IAM principle:

```text
different responsibilities
=
different identities
```

We'll revisit this in the ECS/Fargate lesson.

---

# 73. Separate Terraform Plan and Apply Authority

Advanced CI/CD architecture can distinguish:

```text
Plan pipeline
```

from:

```text
Apply pipeline
```

Plan might need:

```text
broad read/describe
```

Apply needs:

```text
controlled mutation
```

Then production apply could require:

```text
approval
protected environment
stronger role
```

This prevents every pull-request job from automatically owning full production mutation permission.

---

# 74. Terraform State Security

Terraform state can contain:

```text
resource identifiers
infrastructure topology
generated values
sometimes sensitive values
```

Therefore the state backend role and S3/KMS access deserve high protection.

Your existing architecture:

```text
Terraform
  │
  ▼
S3 Backend
  │
  └── KMS / locking controls
```

should be secured with:

```text
restricted bucket access
TLS
encryption
least privilege
versioning/recovery controls
CloudTrail visibility
```

not treated as a normal public artifact bucket.

---

# 75. Cross-Account Terraform Architecture

A strong organization can use:

```text
CI Account
    │
    ▼
Terraform Pipeline
    │
    ▼
OIDC / Workload Role
    │
    ▼
AssumeRole
    │
 ┌──┼───────────────┐
 ▼  ▼               ▼
DevExecution   StageExecution   ProdExecution
Role           Role             Role
```

Now:

```text
CI's base role
```

does not need direct permanent administrative access to every target account.

Each target account provides a controlled deployment role.

---

# 76. Production Trust Policy

Production role could trust only:

```text
Central Deployment Role
```

and potentially require:

```text
External/identity conditions
source identity
specific organization
```

depending on the architecture.

Then:

```text
Developer laptop
```

cannot automatically assume the production Terraform execution role unless separately authorized.

---

# 77. Identity Center + CI/CD Are Separate Identity Domains

Humans:

```text
IAM Identity Center
```

Machines:

```text
OIDC / IAM Roles
```

Do not use:

```text
employee's AWS credentials
```

inside CI/CD.

Bad:

```text
Jenkins uses Vivek's Admin credentials.
```

Better:

```text
Jenkins
→ dedicated workload identity
→ controlled execution role
```

The automation should remain functional and auditable even when an employee leaves the company.

---

# 78. Multi-Account Production Security Model

```text
                           ORGANIZATION
                                │
                     ┌──────────┴──────────┐
                     ▼                     ▼
                    SCP                   RCP
                     │                     │
                     └──────────┬──────────┘
                                ▼
                           MEMBER ACCOUNT
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼

       HUMANS                 CI/CD               WORKLOADS
          │                     │                     │
          ▼                     ▼                     ▼
   Identity Center            OIDC                 IAM Roles
          │                     │                     │
   Permission Set          Deploy Role          EC2/ECS/Lambda
          │                     │                     │
          └─────────────────────┼─────────────────────┘
                                ▼
                         IAM POLICIES
                                │
                   Permissions Boundaries
                                │
                                ▼
                         AWS RESOURCES
                                │
          ┌─────────────────────┼───────────────────┐
          ▼                     ▼                   ▼
      Resource Policy       KMS Policy       Endpoint Policy

                                │
                                ▼
                           CloudTrail
                                │
                                ▼
                         Access Analyzer
```

This is the IAM architecture I want you to be able to draw from memory.

---

# 79. SAA-C03 Scenario

> Company has 80 AWS accounts and wants one place to assign developers access using corporate identities.

Think:

```text
AWS IAM Identity Center
+
AWS Organizations
```

IAM Identity Center provides centralized multi-account workforce permission assignments. ([AWS Documentation][4])

---

# 80. Scenario

> Same developer needs admin in Dev but read-only in Production.

Use separate:

```text
permission set/account assignments
```

such as:

```text
Dev
→ DeveloperAdmin

Prod
→ ProductionReadOnly
```

A single Identity Center user can receive multiple permission sets and different assignments across accounts. ([AWS Documentation][5])

---

# 81. Scenario

> Security wants to stop member accounts from disabling an organization security service even when local administrators have AdministratorAccess.

Think:

```text
Organizations SCP
```

because SCPs create centralized maximum permission guardrails for member-account principals. ([AWS Documentation][3])

---

# 82. Scenario

> Security wants to restrict how supported resources in member accounts may be accessed even if a resource policy is overly permissive.

Think:

```text
RCP
```

for resources/services currently supported by Resource Control Policies. ([AWS Documentation][9])

---

# 83. Scenario

> Developers can create roles but every created role must remain under an approved maximum permission set.

Think:

```text
permissions boundary
```

plus policy controls that:

```text
require boundary
prevent boundary removal
protect boundary policy
restrict PassRole
```

not merely the boundary by itself.

---

# 84. Scenario

> Security wants to know which external principals can access supported resources.

Think:

```text
IAM Access Analyzer
External Access Analyzer
```

([AWS Documentation][14])

---

# 85. Scenario

> Security wants to know which internal roles can reach a sensitive resource.

Think:

```text
IAM Access Analyzer
Internal Access Analyzer
```

([AWS Documentation][15])

---

# 86. Scenario

> Organization wants to find IAM roles unused for months.

Think:

```text
IAM Access Analyzer
Unused Access Analyzer
```

([AWS Documentation][14])

---

# 87. Scenario

> Need to determine which role actually terminated an instance.

Think:

```text
CloudTrail
```

and inspect:

```text
userIdentity
sessionIssuer
sourceIdentity
```

where available. ([AWS Documentation][11])

---

# 88. Scenario

> Terraform role has `ec2:*` but `RunInstances` still fails.

Check:

```text
SCP
boundary
session policy
conditions
PassRole
```

before attaching another Allow.

---

# 89. Scenario

> Terraform can launch EC2 but fails only when attaching an instance profile.

Think:

```text
iam:PassRole
```

and role trust:

```text
ec2.amazonaws.com
```

before increasing general EC2 permissions.

---

# 90. Scenario

> S3 object read fails even though `s3:GetObject` is allowed.

If SSE-KMS:

```text
S3 permission
+
KMS authorization
```

both matter.

Then inspect:

```text
bucket policy
SCP
RCP
endpoint policy
KMS key policy
```

as applicable.

---

# 91. Scenario

> User says “I am Administrator.”

The correct engineering response is:

```text
Let's identify your effective authorization path.
```

not:

```text
Then AWS must be broken.
```

Because `AdministratorAccess` is still only one identity-based permission source and may be constrained by other guardrails.

---

# 92. Never-Forget IAM Troubleshooting Formula

```text
                  ACCESS DENIED

WHO?
│
└── aws sts get-caller-identity

WHAT?
│
└── exact Action

WHERE?
│
└── exact Resource ARN

IDENTITY ALLOW?
│
├── managed policy
└── inline policy

CEILING?
│
└── permissions boundary

SESSION?
│
└── session policy

ORGANIZATION?
│
├── SCP
└── RCP

RESOURCE?
│
└── bucket/key/queue/trust policy

NETWORK PATH?
│
└── VPC endpoint policy

ENCRYPTION?
│
└── KMS key policy / grants

CONDITION?
│
└── tags, region, source,
    MFA, org, endpoint

AUDIT?
│
└── CloudTrail

ANALYZE?
│
└── Access Analyzer /
    policy simulator
```

If you follow this every time, IAM stops feeling random.

---

# 93. Never-Forget Enterprise Identity Map

```text
                   HUMAN ACCESS
                       │
                       ▼
               Corporate Identity
                       │
                       ▼
              IAM Identity Center
                       │
                       ▼
                Permission Set
                       │
                       ▼
                Account Access


                  MACHINE ACCESS
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
           EC2        ECS       Lambda
            │          │          │
            └────── IAM Roles ─────┘


                   CI/CD ACCESS
                       │
                       ▼
                  OIDC / Role
                       │
                       ▼
                 Deploy Role


                   GOVERNANCE
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
           SCP        RCP      Boundary


                    AUDITING
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
        CloudTrail          Access Analyzer
```

---

# 94. 30 Final IAM Rules to Burn Into Memory

```text
1. Humans and workloads should not share identities.

2. Workforce access should favor federation/
   IAM Identity Center.

3. Workloads should favor IAM roles and
   temporary credentials.

4. Multi-account architecture provides
   important security boundaries.

5. Organizations groups accounts through OUs.

6. Protect the management account heavily.

7. Avoid normal workloads in the management account.

8. Permission sets centralize workforce authorization.

9. Permission set + principal + account
   creates the practical access assignment.

10. Group-based access scales better
    than individual assignments.

11. Different accounts can give the same user
    different permission levels.

12. SCP = member-account principal guardrail.

13. RCP = supported resource-side guardrail.

14. Boundaries constrain IAM identities
    inside accounts.

15. AdministratorAccess is not absolute authority.

16. PassRole must be tightly scoped.

17. Identity policies don't bypass resource policies.

18. KMS authorization needs key-policy awareness.

19. Endpoint policies can further restrict requests.

20. `aws sts get-caller-identity`
    should be your first AccessDenied command.

21. Read the exact denied action.

22. Read the exact resource.

23. Distinguish implicit deny from explicit deny.

24. CloudTrail shows what actually happened.

25. SourceIdentity improves assumed-role attribution.

26. Access Analyzer detects external access paths.

27. Access Analyzer can analyze internal access paths.

28. Unused access analysis helps remove stale privilege.

29. Least privilege is an ongoing operational process.

30. IAM security is about the entire ACCESS PATH,
    not one policy document.
```

And the **biggest mental model from all four IAM parts**:

```text
                  AWS AUTHORIZATION

                       WHO?
                        │
                        ▼
                    PRINCIPAL
                        │
                        ▼
                      WHAT?
                        │
                        ▼
                     ACTION
                        │
                        ▼
                      WHERE?
                        │
                        ▼
                    RESOURCE
                        │
                        ▼
                 UNDER WHAT CONTEXT?
                        │
                        ▼
                   CONDITIONS
                        │
                        ▼
               WHAT POLICIES APPLY?
                        │
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
     Identity        Resource         Boundary
     Policy          Policy
        │
        ├──────── Session Policy
        │
        ├──────── SCP
        │
        ├──────── RCP
        │
        ├──────── Endpoint Policy
        │
        └──────── KMS / service policy
                        │
                        ▼
                 EXPLICIT DENY?
                   │         │
                  YES       NO
                   │         │
                   ▼         ▼
                  DENY    VALID ALLOW?
                              │
                         ┌────┴────┐
                        YES       NO
                         │         │
                         ▼         ▼
                       ALLOW     DENY
```

Once this diagram is permanent in your head, AWS IAM becomes **logical rather than mysterious**.

---

# ✅ Lesson 30 — AWS IAM & Enterprise Security Architecture COMPLETE

Across all four parts, you have now covered:

```text
✓ authentication vs authorization
✓ root user security
✓ IAM users
✓ IAM groups
✓ IAM roles
✓ STS
✓ AssumeRole
✓ temporary credentials
✓ instance profiles
✓ trust policies
✓ permission policies

✓ policy JSON
✓ Action
✓ Resource
✓ Principal
✓ Condition
✓ ARN
✓ implicit deny
✓ explicit deny
✓ resource policies
✓ cross-account access

✓ permissions boundaries
✓ session policies
✓ role chaining
✓ SCP
✓ RCP
✓ service-linked roles
✓ NotAction
✓ NotResource
✓ VPC endpoint policies
✓ KMS interaction

✓ PassRole
✓ privilege escalation
✓ restricted service roles
✓ federation
✓ SAML
✓ OIDC
✓ GitHub Actions OIDC
✓ keyless CI/CD
✓ confused deputy
✓ ExternalId
✓ SourceArn
✓ SourceAccount
✓ MFA
✓ RBAC
✓ ABAC
✓ session tags
✓ SourceIdentity

✓ AWS Organizations
✓ management/member accounts
✓ OUs
✓ Identity Center
✓ permission sets
✓ account assignments
✓ centralized workforce access
✓ break-glass model

✓ IAM Access Analyzer
✓ external access
✓ internal access
✓ unused access
✓ policy validation
✓ credential auditing

✓ CloudTrail IAM auditing
✓ Terraform IAM debugging
✓ EC2 AccessDenied
✓ ECR AccessDenied
✓ S3 AccessDenied
✓ KMS AccessDenied
✓ PassRole AccessDenied
✓ multi-layer troubleshooting
✓ enterprise IAM capstone
```

---

# Next — Lesson 31

# **AWS KMS, Secrets Manager, ACM & Security Services**

IAM answered:

```text
WHO MAY ACCESS?
```

Lesson 31 answers:

```text
HOW DO WE PROTECT
THE DATA,
SECRETS,
KEYS,
CERTIFICATES,
AND SECURITY POSTURE
AFTER ACCESS IS AUTHORIZED?
```

We'll start with the foundation:

```text
                       APPLICATION DATA
                              │
                              ▼
                         ENCRYPTION
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              AT REST               IN TRANSIT
                    │                   │
                    ▼                   ▼
                   KMS               TLS / ACM
                    │
             ┌──────┴────────┐
             ▼               ▼
        Data Keys         Key Policies
             │
             ▼
       Envelope Encryption


                      SECRETS
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
           DB Password API Key  OAuth Secret
              │
              ▼
        Secrets Manager
              │
              ├── encryption with KMS
              ├── rotation
              ├── versions/stages
              └── IAM/resource policies


                  SECURITY SERVICES
                         │
         ┌───────────────┼─────────────────┐
         ▼               ▼                 ▼
      GuardDuty      Security Hub     Inspector
         │               │                 │
         ▼               ▼                 ▼
   threat detection   aggregation      vulnerability
                                         management

               plus:

       Macie
       WAF
       Shield
       Firewall Manager
       Detective
       AWS Config integration
```

We'll begin Lesson 31 Part 1 with **KMS from first principles**—plaintext, ciphertext, symmetric vs asymmetric keys, AWS-owned/AWS-managed/customer-managed keys, envelope encryption, data keys, key policies, grants, encryption context, rotation, multi-Region keys, `GenerateDataKey`, `Encrypt`, `Decrypt`, `ReEncrypt`, Terraform, and production troubleshooting.

That will connect directly to everything you've already used: **S3, EBS, RDS/Aurora, DynamoDB, Secrets Manager, CloudFront certificates, Terraform state, and IAM**.

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html?utm_source=chatgpt.com "What is AWS Organizations? - AWS ..."
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_getting-started_concepts.html?utm_source=chatgpt.com "Terminology and concepts for AWS Organizations"
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[4]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
[5]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html?utm_source=chatgpt.com "Manage AWS accounts with permission sets"
[6]: https://docs.aws.amazon.com/singlesignon/latest/userguide/assignusers.html?utm_source=chatgpt.com "Assign user or group access to AWS accounts"
[7]: https://docs.aws.amazon.com/singlesignon/latest/userguide/users-groups-provisioning.html?utm_source=chatgpt.com "Users, groups, and provisioning in IAM Identity Center"
[8]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html?utm_source=chatgpt.com "Authorization policies in AWS Organizations"
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[10]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html?utm_source=chatgpt.com "What Is AWS CloudTrail? - AWS CloudTrail"
[11]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html?utm_source=chatgpt.com "CloudTrail userIdentity element - AWS Documentation"
[12]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html?utm_source=chatgpt.com "Monitor and control actions taken with assumed roles"
[13]: https://docs.aws.amazon.com/singlesignon/latest/userguide/logging-using-cloudtrail.html?utm_source=chatgpt.com "Logging IAM Identity Center API calls with AWS CloudTrail"
[14]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html?utm_source=chatgpt.com "AWS Identity and Access Management Access Analyzer ..."
[15]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-findings.html?utm_source=chatgpt.com "IAM Access Analyzer findings"
[16]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html?utm_source=chatgpt.com "Permissions required to use IAM Access Analyzer"
[17]: https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/list-analyzers.html?utm_source=chatgpt.com "list-analyzers — AWS CLI 2.36.17 Command Reference"
[18]: https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/list-findings-v2.html?utm_source=chatgpt.com "list-findings-v2 — AWS CLI 2.36.21 Command Reference"
[19]: https://docs.aws.amazon.com/cli/latest/reference/iam/get-account-authorization-details.html?utm_source=chatgpt.com "get-account-authorization-details"
[20]: https://docs.aws.amazon.com/cli/latest/reference/iam/list-attached-role-policies.html?utm_source=chatgpt.com "list-attached-role-policies - iam"
[21]: https://docs.aws.amazon.com/cli/latest/reference/iam/simulate-principal-policy.html?utm_source=chatgpt.com "simulate-principal-policy - iam"
[22]: https://docs.aws.amazon.com/cli/latest/reference/organizations/list-roots.html?utm_source=chatgpt.com "list-roots — AWS CLI 2.36.21 Command Reference"
[23]: https://docs.aws.amazon.com/cli/latest/reference/organizations/list-policies-for-target.html?utm_source=chatgpt.com "list-policies-for-target"
[24]: https://docs.aws.amazon.com/cli/latest/reference/sso-admin/?utm_source=chatgpt.com "sso-admin — AWS CLI 2.36.22 Command Reference"
[25]: https://docs.aws.amazon.com/cli/latest/reference/sso-admin/list-permission-sets.html?utm_source=chatgpt.com "list-permission-sets — AWS CLI 2.36.21 Command ..."
[26]: https://docs.aws.amazon.com/cli/latest/reference/sso-admin/list-account-assignments.html?utm_source=chatgpt.com "list-account-assignments"
[27]: https://docs.aws.amazon.com/cli/latest/reference/sso-admin/list-account-assignments-for-principal.html?utm_source=chatgpt.com "list-account-assignments-for-principal"
[28]: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html?utm_source=chatgpt.com "Root user best practices for your AWS account"
