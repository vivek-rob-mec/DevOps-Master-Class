# AWS Masterclass — Lesson 30 Part 3

# IAM Privilege Escalation Defense — `iam:PassRole`, Federation, OIDC, MFA, ABAC & Access Analyzer

Parts 1 and 2 taught:

```text
Part 1
WHO am I?
WHAT does the policy say?
WHY am I denied?

Part 2
What are my EFFECTIVE permissions
after boundaries, SCPs, sessions,
resource policies, RCPs, KMS, etc.?
```

Part 3 asks a more dangerous question:

> **“Even if this principal is not an administrator now, can the permissions it already has be combined to become an administrator?”**

That is the privilege-escalation problem.

---

# 1. Direct Permission vs Indirect Permission

Suppose a developer cannot call:

```text
s3:GetObject
```

against a sensitive bucket.

At first glance:

```text
Developer
   │
   X
   ▼
Sensitive S3
```

Looks secure.

But suppose the same developer can:

```text
create Lambda function
+
pass PowerfulRole to Lambda
+
control Lambda code
```

Then:

```text
Developer
    │
    ▼
Create Lambda
    │
    ▼
Pass PowerfulRole
    │
    ▼
Lambda assumes PowerfulRole
    │
    ▼
Developer-controlled code
    │
    ▼
Sensitive S3
```

The developer still never received a direct:

```text
s3:GetObject
```

allow.

But they created an execution path through a more privileged role.

AWS specifically warns that principals who can pass high-privilege roles to services capable of running their code can indirectly gain the permissions of those roles. ([AWS Documentation][1])

This is why IAM security cannot be evaluated one API action at a time.

---

# 2. `iam:PassRole` — One of the Most Important AWS Permissions

First understand what it means.

```text
iam:PassRole
```

means:

> **“This principal may designate an IAM role for an AWS service to use.”**

For example:

```text
User
 │
 │ iam:PassRole
 ▼
EC2Role
 │
 ▼
EC2 instance
```

or:

```text
CI/CD
 │
 │ iam:PassRole
 ▼
LambdaExecutionRole
 │
 ▼
Lambda
```

`iam:PassRole` is checked when a service API receives a role ARN that the service will use; it is not a separate “PassRole API call” that you invoke by itself. AWS also documents that the role being passed and the service receiving it must be in the same AWS account. ([AWS Documentation][1])

### Never forget

```text
AssumeRole
=
I become the role


PassRole
=
I tell a service
which role IT may use
```

---

# 3. `AssumeRole` vs `PassRole`

## AssumeRole

```text
Developer
   │
   ▼
sts:AssumeRole
   │
   ▼
AdminRole
   │
   ▼
Developer receives
temporary AdminRole credentials
```

## PassRole

```text
Developer
   │
   ▼
lambda:CreateFunction
   │
   ├── code = developer's code
   │
   └── role = AdminRole
              │
              ▼
           Lambda
              │
              ▼
         uses AdminRole
```

Developer did not technically assume AdminRole.

But developer-controlled code may now execute with AdminRole's privileges.

That's why `PassRole` deserves security review comparable to direct role-assumption permissions.

---

# 4. PassRole Usually Has Three Pieces

Suppose a user launches EC2 with:

```text
ProductionEC2Role
```

You need to reason about:

### Caller service API permission

For example:

```text
ec2:RunInstances
```

### PassRole permission

```text
iam:PassRole
```

on:

```text
ProductionEC2Role
```

### Role trust relationship

The role must trust:

```text
ec2.amazonaws.com
```

to assume it.

AWS documents all three concepts in its PassRole guidance: the role's permission policy, the trust policy allowing the target AWS service to assume the role, and the caller's `iam:PassRole` permission for approved roles. ([AWS Documentation][1])

---

# 5. Secure PassRole Example

Instead of:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

scope the role:

```json
{
  "Effect": "Allow",
  "Action": [
    "iam:PassRole"
  ],
  "Resource": [
    "arn:aws:iam::111122223333:role/app/EC2-App-*"
  ]
}
```

Now:

```text
Developer can pass:

app/EC2-App-Web
app/EC2-App-Worker
```

but not:

```text
AdminRole

SecurityAuditRole

OrganizationManagementRole
```

AWS recommends limiting `iam:PassRole` to approved role ARNs rather than allowing every role in the account. ([AWS Documentation][1])

---

# 6. Restrict Which AWS Service Receives the Role

AWS provides:

```text
iam:PassedToService
```

condition key.

Example:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::111122223333:role/app/EC2-App-*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

Meaning:

```text
These roles
can be passed

ONLY TO

EC2
```

not arbitrary supported services.

AWS explicitly documents `iam:PassedToService` for restricting PassRole by receiving service principal. ([AWS Documentation][2])

---

# 7. Why `PassRole: "*"` Is Dangerous

Suppose account contains:

```text
WebRole
ReadOnlyRole
BackupRole
SecurityAdminRole
OrganizationAdminRole
```

Developer receives:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

Now ask:

```text
What services can developer create/configure?

EC2?
Lambda?
ECS?
CloudFormation?
SageMaker?
Step Functions?
```

The risk isn't merely:

```text
Can developer pass a role?
```

It's:

```text
Can developer control a resource
that will EXECUTE or ACT
using that role?
```

AWS warns directly that PassRole should not permit users to pass roles with permissions the user should not indirectly exercise. ([AWS Documentation][1])

---

# 8. PassRole Privilege Escalation Pattern

Memorize this chain:

```text
LOW PRIVILEGE PRINCIPAL
        │
        ▼
Can control execution resource?
        │
        ▼
Can pass powerful role?
        │
        ▼
Service assumes powerful role
        │
        ▼
principal-controlled workload
executes with elevated authority
```

The defense is therefore not simply:

```text
remove iam:*
```

You must examine combinations.

---

# 9. Common Dangerous Combination

Conceptually:

```text
lambda:CreateFunction
+
lambda:UpdateFunctionCode
+
iam:PassRole
```

can become dangerous if PassRole includes a highly privileged Lambda execution role.

Similarly:

```text
ec2:RunInstances
+
iam:PassRole
```

can be dangerous if the caller can attach an excessively privileged instance profile and control code executed on the instance.

The correct mitigation is to constrain both **which compute resources may be created/configured and which roles may be passed to them**. AWS's own security tooling recognizes this kind of privileged executor path as an IAM exposure. ([AWS Documentation][3])

---

# 10. Permissions Boundaries Help Here

Recall Part 2:

```text
Developer-created roles
      │
      ▼
must have
WorkloadBoundary
```

Now even if the developer creates:

```text
NewAppRole
```

and attaches a broad identity policy, the boundary can cap the role.

Architecture:

```text
Security Team
    │
    ▼
WorkloadBoundary
    │
    ▼
Developer
may create roles
    │
    ▼
Every new role
must attach boundary
```

This is a classic delegated-IAM pattern.

But the administrator must also prevent developers from:

```text
removing the boundary
changing the boundary
using an unrestricted existing role
passing another privileged role
```

So boundaries are one piece of the design—not the whole solution.

---

# 11. Creating Roles Is Itself Security-Sensitive

Consider permissions such as:

```text
iam:CreateRole

iam:AttachRolePolicy

iam:PutRolePolicy
```

Individually they may look like:

```text
"I just need them for Terraform."
```

Together, without proper boundaries, they might allow creating a role with much greater authority.

AWS guidance explicitly notes that a principal able to create roles and attach arbitrary policies can escalate privileges, which is why approved service roles and restricted `PassRole` are important. ([AWS Documentation][4])

---

# 12. IAM Policy Management Can Also Be an Escalation Surface

Be cautious with permissions that let principals modify IAM authorization itself.

Examples include broad abilities to:

```text
create policies

change policy versions

attach policies

modify role policies

modify trust policies

remove permissions boundaries
```

The dangerous question isn't:

```text
Does this permission access production data?
```

It's:

```text
Can this permission MODIFY
the permission system
so that another permission becomes available?
```

That's the mental model security reviews must use.

---

# 13. Trust Policies Can Also Become Escalation Paths

Suppose user cannot assume:

```text
AdminRole
```

today.

But can modify:

```text
AdminRole trust policy
```

to add themselves.

Then:

```text
Before

AdminRole
trusts SecurityTeam only
```

becomes:

```text
After

AdminRole
trusts SecurityTeam
+
DeveloperRole
```

Now the developer may be able to assume it.

Therefore:

```text
iam:UpdateAssumeRolePolicy
```

is a highly security-sensitive permission.

Trust-policy management is privilege management.

---

# 14. The Enterprise Question

When reviewing a role, don't ask only:

```text
What can this role access directly?
```

Also ask:

```text
Can it create identities?

Can it modify policies?

Can it change role trust?

Can it remove boundaries?

Can it pass stronger roles?

Can it create code-execution resources
that use stronger roles?
```

That is privilege-escalation analysis.

---

# 15. Modern AWS Authentication: Prefer Federation

Now let's solve the opposite problem:

> How can humans and CI/CD systems access AWS **without permanent AWS access keys?**

Modern AWS architecture increasingly uses:

```text
External identity
      │
      ▼
Federation
      │
      ▼
AWS STS
      │
      ▼
Temporary credentials
```

AWS IAM best practices recommend temporary credentials and federation rather than long-lived IAM-user credentials whenever possible. ([AWS Documentation][5])

---

# 16. Federation Mental Model

Instead of AWS maintaining your employee password:

```text
Employee
   │
   ▼
IAM User password
```

use:

```text
Employee
   │
   ▼
Corporate Identity Provider
   │
   ▼
authenticated identity assertion
   │
   ▼
AWS
   │
   ▼
IAM Role
   │
   ▼
temporary credentials
```

Examples of federation standards include:

```text
SAML 2.0

OIDC
```

---

# 17. SAML Federation

SAML is widely used for enterprise workforce federation.

Architecture:

```text
Employee
   │
   ▼
Corporate IdP
   │
   ├── Microsoft identity platform
   ├── Okta
   └── other SAML IdP
   │
   ▼
SAML assertion
   │
   ▼
AWS STS
AssumeRoleWithSAML
   │
   ▼
IAM Role
   │
   ▼
temporary credentials
```

AWS `AssumeRoleWithSAML` exchanges a valid SAML authentication response for temporary AWS security credentials, enabling enterprise identity stores to map users to AWS roles without user-specific long-lived AWS credentials. ([AWS Documentation][6])

---

# 18. SAML Does Not Mean “Create AWS User”

A federated employee doesn't require:

```text
IAM user:
vivek
```

in every AWS account.

Instead:

```text
Corporate user
       │
       ▼
Identity Provider
       │
       ▼
AWS role
```

Policies assigned to that role determine the user's AWS permissions after federation. ([AWS Documentation][7])

This scales much better across:

```text
10 accounts
100 accounts
1,000 accounts
```

than duplicating IAM users.

---

# 19. OIDC — OpenID Connect

OIDC is especially important for modern applications and CI/CD.

Architecture:

```text
External Platform
      │
      ▼
OIDC token
JWT
      │
      ▼
AWS STS
AssumeRoleWithWebIdentity
      │
      ▼
IAM Role
      │
      ▼
temporary credentials
```

AWS explicitly supports OIDC-compatible identity providers—including GitHub Actions—as sources that exchange JWTs for temporary credentials mapped to an IAM role. ([AWS Documentation][8])

---

# 20. Long-Lived CI/CD Keys — Old Model

Example:

```text
GitHub Repository Secrets

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

or:

```text
Jenkins Credential Store

AKIA...
secret key
```

Problems:

```text
credentials don't automatically expire quickly

rotation required

secret can leak

same key might be reused

repository/admin compromise may expose key
```

Better:

```text
CI system identity
      │
      ▼
federation
      │
      ▼
STS temporary role
```

---

# 21. GitHub Actions + AWS OIDC

The modern architecture:

```text
GitHub Actions
      │
      ▼
GitHub OIDC Provider
token.actions.githubusercontent.com
      │
      ▼
OIDC JWT
      │
      ▼
AWS STS
AssumeRoleWithWebIdentity
      │
      ▼
GitHubDeployRole
      │
      ▼
temporary AWS credentials
```

AWS and GitHub both document OIDC as the recommended pattern for GitHub Actions so workflows don't need permanent AWS credentials stored as repository secrets. ([AWS Documentation][9])

---

# 22. The IAM OIDC Provider

AWS account configures an OIDC provider representing:

```text
https://token.actions.githubusercontent.com
```

Then an IAM role trust policy identifies that provider as:

```text
Principal:
Federated
```

and allows:

```text
sts:AssumeRoleWithWebIdentity
```

AWS requires creating the IAM OIDC provider before configuring the GitHub role trust relationship. ([AWS Documentation][10])

---

# 23. BAD GitHub OIDC Trust

Never create something conceptually like:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated":
      "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity"
}
```

without restricting GitHub claims.

Why?

You want:

```text
YOUR repository
```

to assume the role.

Not:

```text
arbitrary GitHub repositories.
```

AWS explicitly warns that GitHub OIDC trust should restrict the `sub` claim to repositories/branches under your control. ([AWS Documentation][9])

---

# 24. Secure GitHub Trust Policy

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",

      "Principal": {
        "Federated":
          "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
      },

      "Action":
        "sts:AssumeRoleWithWebIdentity",

      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud":
            "sts.amazonaws.com",

          "token.actions.githubusercontent.com:sub":
            "repo:my-org/my-app:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

This allows:

```text
Organization:
my-org

Repository:
my-app

Branch:
main
```

rather than all GitHub workflows.

AWS's documented GitHub example uses exactly this pattern: `aud = sts.amazonaws.com` plus a restricted `sub` claim identifying organization/repository/branch. ([AWS Documentation][9])

---

# 25. 2026 GitHub OIDC Security Improvement in IAM

Current IAM behavior includes a specific protection for the recognized GitHub shared OIDC provider.

When you create or modify the trust policy, AWS verifies that:

```text
token.actions.githubusercontent.com:sub
```

exists and isn't merely an unrestricted wildcard or null value. ([AWS Documentation][9])

That doesn't mean every trust policy is automatically safe.

You should still scope:

```text
organization
repository
branch
environment
workflow
```

as tightly as your deployment architecture requires. AWS exposes GitHub OIDC claims such as `aud`, `sub`, `ref`, `workflow`, and `environment` as IAM condition keys. ([AWS Documentation][2])

---

# 26. Current GitHub Actions Workflow

A GitHub Actions job needs permission to request the OIDC token:

```yaml
permissions:
  id-token: write
  contents: read
```

Then it can configure temporary AWS credentials:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::111122223333:role/GitHubDeployRole
          aws-region: ap-south-1

      - name: Verify identity
        run: aws sts get-caller-identity
```

The official AWS credentials action currently uses OIDC as its recommended quick-start pattern; its latest surfaced release is `6.2.3` as of August 14, 2026, while using the major tag `@v6` follows its published major-version release convention. ([GitHub][11])

---

# 27. What Is Stored in GitHub Now?

Old model:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

New OIDC model:

```text
No long-lived AWS secret required.
```

GitHub obtains an OIDC token for the workflow, and AWS STS exchanges valid identity claims for temporary AWS credentials. ([GitHub Docs][12])

That's a major security improvement.

---

# 28. Separate Deployment Roles

Don't create:

```text
GitHubRole
=
AdministratorAccess everywhere
```

Instead:

```text
GitHubDevDeployRole
        │
        ▼
Dev account


GitHubStagingDeployRole
        │
        ▼
Staging


GitHubProdDeployRole
        │
        ▼
Production
```

Then different trust conditions can apply.

Example:

```text
feature branches
→ Dev only

main
→ Staging

protected production environment
→ Production
```

AWS specifically recommends limiting GitHub OIDC role trust to controlled organizations, repositories, branches, and protected environments. ([AWS Documentation][9])

---

# 29. GitHub Environment Pattern

Production:

```text
GitHub workflow
      │
      ▼
Environment:
production
      │
      ├── reviewer protection
      ├── deployment branch restrictions
      └── environment controls
      │
      ▼
AWS production role
```

AWS recommends GitHub environment protection rules when environments are part of the OIDC/deployment design. ([AWS Documentation][9])

This gives you:

```text
Git branch controls
+
GitHub deployment approval
+
AWS IAM trust
+
AWS role permissions
```

multiple layers.

---

# 30. Terraform GitHub OIDC Provider

Conceptually:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}
```

Then trust the provider in your deployment role.

The IAM OIDC provider represents the trust relationship between AWS and the external OIDC-compatible identity provider. ([AWS Documentation][10])

---

# 31. Terraform GitHub Trust

```hcl
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:my-org/my-app:ref:refs/heads/main"
      ]
    }
  }
}
```

Then:

```hcl
resource "aws_iam_role" "github_deploy" {
  name = "github-production-deploy"

  assume_role_policy =
    data.aws_iam_policy_document.github_trust.json
}
```

The most important security control here is not Terraform.

It's:

```text
sub condition.
```

---

# 32. Jenkins Workload Identity

GitHub OIDC is specific to the GitHub identity provider.

For Jenkins, choose the workload identity according to where Jenkins runs.

For example:

```text
Jenkins agent on EC2
      │
      ▼
EC2 instance role
```

or:

```text
Jenkins workload on AWS container platform
      │
      ▼
platform workload role
```

The principle remains:

```text
workload identity
+
temporary credentials
```

rather than storing a permanent IAM-user key whenever an appropriate AWS role/federation mechanism is available. AWS IAM best practices recommend temporary credentials for workloads. ([AWS Documentation][5])

---

# 33. OIDC Troubleshooting

GitHub workflow says:

```text
Not authorized to perform:
sts:AssumeRoleWithWebIdentity
```

Check:

```text
1. OIDC provider exists?

2. Provider ARN correct?

3. aud = sts.amazonaws.com?

4. sub matches actual repository?

5. branch correct?

6. using GitHub Environment?
   subject format may differ.

7. workflow has:
   id-token: write?

8. role trust action:
   sts:AssumeRoleWithWebIdentity?

9. SCP/other guardrail?
```

AWS's GitHub OIDC trust model specifically relies on matching token claims such as `aud` and `sub`. ([AWS Documentation][9])

---

# 34. Confused Deputy Problem

Now let's discuss one of the most important trust-policy concepts.

Suppose you hire:

```text
MonitoringCompany
```

They monitor:

```text
Customer A
Customer B
Customer C
```

Your role trusts MonitoringCompany's AWS account:

```text
YourAccount
   │
   ▼
MonitoringRole
trusts
MonitoringCompany
```

An attacker/customer discovers your role ARN.

They tell MonitoringCompany:

> “Please use this role for my job.”

If MonitoringCompany can't distinguish:

```text
whose role belongs to whom
```

it may inadvertently use **your role** while processing another customer's request.

That is the:

# Confused Deputy Problem

AWS defines it as a less-privileged actor coercing or misdirecting a more privileged entity into using authority on the actor's behalf. ([AWS Documentation][13])

---

# 35. Cross-Account Confused Deputy Solution — External ID

Use:

```text
sts:ExternalId
```

Example trust:

```json
{
  "Effect": "Allow",

  "Principal": {
    "AWS":
      "arn:aws:iam::999988887777:root"
  },

  "Action": "sts:AssumeRole",

  "Condition": {
    "StringEquals": {
      "sts:ExternalId":
        "customer-7f36b835"
    }
  }
}
```

Now third party must supply:

```text
correct role ARN
+
correct ExternalId
```

AWS identifies this as the primary use of ExternalId for protecting third-party cross-account role delegation from confused-deputy scenarios. ([AWS Documentation][14])

---

# 36. External ID Is NOT a Password

AWS explicitly says:

```text
ExternalId
is not treated as a secret.
```

It may be visible to people who can inspect the role. ([AWS Documentation][14])

Its security value is:

```text
unique customer binding
```

not:

```text
secret knowledge.
```

The third-party service should generate/manage unique identifiers for its customers so it knows which customer context it is operating under. ([AWS Documentation][13])

---

# 37. Cross-Service Confused Deputy

There's another version:

```text
AWS Service A
```

accesses:

```text
your AWS resource
```

using its service principal.

Example conceptual relationship:

```text
CloudTrail
   │
   ▼
S3 bucket
```

If bucket policy trusts:

```text
cloudtrail.amazonaws.com
```

with no context restriction, you may unintentionally trust service operations initiated on behalf of resources/accounts you didn't intend.

AWS recommends constraining service-principal access using global context keys such as:

```text
aws:SourceArn

aws:SourceAccount

aws:SourceOrgID

aws:SourceOrgPaths
```

where supported. ([AWS Documentation][13])

---

# 38. `aws:SourceArn`

Use when access should originate on behalf of:

```text
one specific AWS resource
```

Example conceptually:

```json
"Condition": {
  "ArnEquals": {
    "aws:SourceArn":
      "arn:aws:cloudtrail:ap-south-1:111122223333:trail/prod"
  }
}
```

Meaning:

```text
CloudTrail service principal
may use resource

ONLY when acting for
that specific trail.
```

AWS recommends `aws:SourceArn` when you can identify the exact source resource. ([AWS Documentation][13])

---

# 39. `aws:SourceAccount`

If you want to permit:

```text
resources from this AWS account
```

rather than one specific resource:

```json
"Condition": {
  "StringEquals": {
    "aws:SourceAccount":
      "111122223333"
  }
}
```

AWS recommends `aws:SourceAccount` when the desired trust boundary is the source AWS account rather than a single source ARN. ([AWS Documentation][13])

---

# 40. Organization-Level Service Trust

In large Organizations, AWS also supports source context such as:

```text
aws:SourceOrgID

aws:SourceOrgPaths
```

for supported service-principal requests.

This lets you say conceptually:

```text
Allow service requests

ONLY when the service
acts for resources belonging
to my AWS Organization
```

or even a specific OU path. ([AWS Documentation][13])

That's very useful in centralized logging/security architectures.

---

# 41. MFA — Multi-Factor Authentication

Authentication factor 1:

```text
Something you know/have
such as password/session identity
```

plus another independent factor:

```text
security key
passkey
TOTP
```

AWS recommends MFA for stronger account protection and currently prefers phishing-resistant methods such as passkeys/security keys where possible. ([AWS Documentation][15])

---

# 42. MFA Can Be an Authorization Condition

IAM can use:

```text
aws:MultiFactorAuthPresent
```

to make certain API permissions require MFA-backed temporary credentials in contexts where that key is available.

AWS documents this condition specifically for MFA-protected API access and cross-account role trust. ([AWS Documentation][16])

Example concept:

```text
Normal operations
→ no MFA condition

High-risk role assumption
→ MFA required
```

---

# 43. MFA-Protected Role Assumption

Trust policy concept:

```json
{
  "Effect": "Allow",

  "Principal": {
    "AWS":
      "arn:aws:iam::111122223333:user/admin"
  },

  "Action":
    "sts:AssumeRole",

  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent":
        "true"
    }
  }
}
```

Now:

```text
password/access alone
     X

MFA-backed session
     ✓
```

AWS supports requiring MFA in role assumption and API-policy contexts. ([AWS Documentation][17])

---

# 44. MFA Is Not a Substitute for Least Privilege

This policy is still bad:

```text
MFA
+
AdministratorAccess
for everyone
```

if nobody needs admin.

Think:

```text
Identity assurance
+
authorization scope
```

as separate controls.

MFA strengthens:

```text
Who is using this identity?
```

Least privilege constrains:

```text
What can that identity do?
```

You want both.

---

# 45. RBAC — Role-Based Access Control

Traditional model:

```text
DeveloperRole

DatabaseAdminRole

SecurityAuditorRole

NetworkAdminRole
```

Permissions follow job function.

```text
Role
  │
  ▼
specific policies
```

This works extremely well.

But as resource count and teams grow, policy management can become large.

---

# 46. ABAC — Attribute-Based Access Control

ABAC uses attributes—often AWS tags—to decide permission.

Imagine:

Principal:

```text
Project = TodoApp
Environment = Dev
```

Resource:

```text
Project = TodoApp
Environment = Dev
```

Policy:

```text
allow when
PrincipalTag Project
=
ResourceTag Project
```

and:

```text
PrincipalTag Environment
=
ResourceTag Environment
```

AWS supports ABAC patterns that compare principal tags with resource tags for services/actions that support tag-based authorization. ([AWS Documentation][18])

---

# 47. ABAC Example

Policy concept:

```json
{
  "Effect": "Allow",

  "Action": [
    "ec2:StartInstances",
    "ec2:StopInstances"
  ],

  "Resource": "*",

  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Project":
        "${aws:PrincipalTag/Project}"
    }
  }
}
```

Developer tagged:

```text
Project = ProjectA
```

can manage:

```text
EC2 tagged ProjectA
```

but not:

```text
ProjectB
```

assuming the API/resource supports that tag authorization pattern. AWS provides a full ABAC tutorial using matching principal/resource tags. ([AWS Documentation][18])

---

# 48. RBAC vs ABAC

## RBAC

```text
Role:
ProjectADeveloper

Policy:
ProjectA resources
```

New project:

```text
create another role/policy
```

## ABAC

```text
GenericDeveloperRole

PrincipalTag:
Project=A
```

Resource:

```text
Project=A
```

New project:

```text
Project=B
```

often requires changing attributes/tags rather than writing another fully separate permissions policy.

This can make large environments more scalable.

---

# 49. ABAC Does Not Work Magically Everywhere

You must verify whether each:

```text
AWS service
action
resource type
```

supports relevant:

```text
resource tag
request tag
principal tag
```

condition keys.

AWS explicitly directs architects to the Service Authorization Reference for determining action/resource/tag-condition support. ([AWS Documentation][18])

---

# 50. Important ABAC Context Keys

Common concepts:

```text
aws:PrincipalTag/<key>
```

Who is calling?

```text
aws:ResourceTag/<key>
```

How is existing resource tagged?

```text
aws:RequestTag/<key>
```

Which tags are being supplied during the request?

These keys let IAM make authorization decisions using attributes instead of enumerating every ARN. ([AWS Documentation][19])

---

# 51. Prevent Tag-Based Privilege Escalation

Imagine authorization depends on:

```text
ResourceTag/Environment = Dev
```

Developer is allowed only Dev resources.

But developer can freely change:

```text
Production resource tag
Environment=Prod
```

to:

```text
Environment=Dev
```

then your ABAC model is broken.

Therefore ABAC must control:

```text
Who can add tags?

Which tag keys?

Which values?

Who may modify authorization tags?
```

AWS supports policies controlling tag keys and values during IAM/resource operations. ([AWS Documentation][20])

### Never forget

```text
If tags determine permission,
tag modification is a security operation.
```

---

# 52. Require Tags at Creation

Suppose every Lambda function should have:

```text
Project
Environment
Owner
```

If resources can be created untagged, ABAC enforcement can become inconsistent.

AWS's Lambda ABAC guidance explicitly recommends requiring tags on resource creation when your access-control model depends on them. ([AWS Documentation][21])

Production principle:

```text
No authorization metadata
=
creation denied
```

where practical.

---

# 53. Session Tags

Federated or assumed sessions can carry:

```text
Project=Payments

CostCenter=123

Environment=Prod
```

as:

# Session Tags

Those tags become principal attributes for requests made with the session credentials. ([AWS Documentation][22])

Architecture:

```text
Corporate IdP
    │
    ▼
employee attributes
    │
    ▼
AWS role session
    │
    ├── Department=Engineering
    ├── Project=Payments
    └── Environment=Prod
```

Then IAM can use:

```text
aws:PrincipalTag/Project
```

during authorization.

---

# 54. Transitive Session Tags

Suppose:

```text
Identity Center / Federation
       │
       ▼
Role A
Project=Payments
       │
       ▼
Role B
```

You may want:

```text
Project=Payments
```

to survive role chaining.

AWS supports marking session tags as **transitive**, allowing them to persist into subsequent role sessions. ([AWS Documentation][22])

---

# 55. Source Identity

Role sessions often look like:

```text
arn:aws:sts::111122223333:
assumed-role/ProdAdminRole/session123
```

But:

```text
Who was session123?
```

For stronger auditability, AWS supports:

# Source Identity

A trust policy can require:

```text
sts:SourceIdentity
```

and CloudTrail can preserve the source identity so you can trace activity back to the original user/federated identity. ([AWS Documentation][23])

---

# 56. Why Source Identity Matters

Without:

```text
source identity
```

CloudTrail may tell you:

```text
ProdAdminRole
performed action
```

With it:

```text
ProdAdminRole
performed action

source identity:
vivek@example.com
```

or another stable enterprise identifier.

CloudTrail records `sourceIdentity` for role-based actions when it is set, helping identify the original actor behind a session. ([AWS Documentation][24])

---

# 57. Source Identity + Session Tags

These solve related but different problems.

```text
SourceIdentity
=
WHO originally assumed?
```

```text
Session Tags
=
WHAT ATTRIBUTES
apply to the session?
```

Example:

```text
SourceIdentity
=
employee-5827

Project
=
Payments

Department
=
Engineering
```

This gives both:

```text
audit identity
+
authorization attributes
```

---

# 58. IAM Access Analyzer

Now we need tools to answer:

> “Have we accidentally granted too much access?”

IAM Access Analyzer can analyze:

```text
external access

internal access

unused access
```

and provides policy validation/generation capabilities. ([AWS Documentation][25])

---

# 59. External Access Analysis

Suppose S3 bucket policy permits:

```text
external AWS account
```

or IAM role trust allows:

```text
external principal
```

Access Analyzer can identify supported resources shared outside your zone of trust, helping you find unintended external exposure. ([AWS Documentation][26])

Think:

```text
Resource policy
      │
      ▼
mathematical/policy analysis
      │
      ▼
Can external principal access?
      │
      ▼
Finding
```

---

# 60. Internal Access Analysis

Current Access Analyzer also supports internal-access analysis, identifying access paths between principals and specified resources inside the organization/account scope. ([AWS Documentation][25])

This helps answer questions such as:

```text
Which roles can reach this resource?
```

rather than manually reading hundreds of policies.

---

# 61. Unused Access Analyzer

Another powerful function:

```text
Who still has permissions
they no longer use?
```

Current IAM Access Analyzer unused-access analysis monitors IAM roles/users and can identify:

```text
unused roles

unused IAM-user access keys

unused IAM-user passwords

unused services

unused actions
```

within the configured usage window. ([AWS Documentation][27])

This directly helps with least-privilege cleanup.

---

# 62. Permissions Decay

A common enterprise problem:

```text
Day 1
Developer needs:
S3
EC2
Lambda
```

Later project changes:

```text
Day 400
Developer actually uses:
S3 only
```

but still has:

```text
EC2
Lambda
```

permissions.

This is:

```text
permission accumulation
```

or privilege creep.

Unused-access analysis gives you evidence to remove stale permissions. ([AWS Documentation][27])

---

# 63. IAM Access Analyzer Policy Validation

Before saving policies, Access Analyzer can check for:

```text
errors

security warnings

general warnings

suggestions
```

against IAM grammar and AWS best practices. ([AWS Documentation][28])

Current AWS documentation states that IAM Access Analyzer provides **more than 100 policy checks**. ([AWS Documentation][29])

That makes it one of your best tools for catching:

```text
wildcard mistakes
invalid conditions
overly broad trust
GitHub OIDC risks
```

before deployment.

---

# 64. GitHub Trust Validation

IAM Access Analyzer specifically warns about unsafe GitHub OIDC subjects—for example a `sub` wildcard broad enough to allow more repositories/sources than intended. ([AWS Documentation][30])

So this:

```text
IAM Access Analyzer
```

should be part of your Terraform/CI security validation.

---

# 65. Policy Generation From Real Usage

Another Access Analyzer capability:

```text
Start with broader permission
       │
       ▼
run workload
       │
       ▼
CloudTrail history
       │
       ▼
Access Analyzer
       │
       ▼
policy template
based on observed API usage
```

AWS policy generation can analyze up to **90 days** of CloudTrail history together with service last-accessed information to create a permissions-policy template. ([AWS Documentation][31])

This is extremely useful for moving from:

```text
AdministratorAccess
```

toward:

```text
measured least privilege.
```

---

# 66. But Generated Policy Isn't Final Truth

Suppose workload testing didn't execute:

```text
rare disaster recovery path
```

or:

```text
monthly cleanup job
```

Then generated usage history may omit those permissions.

So use generated policies as:

```text
evidence
+
starting point
```

and validate against expected operational paths.

Never assume:

```text
not seen in last 30 days
=
never needed.
```

---

# 67. IAM Credential Report

For IAM users, AWS can generate an account-level CSV containing credential status such as:

```text
password enabled?

password last used?

MFA active?

access key active?

access-key lifecycle information?
```

Credential reports are designed for security/audit review of IAM-managed credentials. ([AWS Documentation][32])

Commands:

```bash
aws iam generate-credential-report
```

then:

```bash
aws iam get-credential-report
```

The required IAM permissions are:

```text
iam:GenerateCredentialReport

iam:GetCredentialReport
```

according to current AWS documentation. ([AWS Documentation][32])

---

# 68. What Credential Reports Are Good For

Find:

```text
IAM users without MFA

old access keys

unused passwords

unnecessary IAM users

human users with programmatic credentials
```

This supports periodic:

```text
IAM hygiene reviews.
```

But note that the report focuses on IAM-managed credentials and does not include every possible service-specific credential type. ([AWS Documentation][32])

---

# 69. CloudTrail + IAM

Authorization tells you:

```text
What MAY happen?
```

CloudTrail helps tell you:

```text
What DID happen?
```

Strong IAM operations combine:

```text
IAM policies
+
CloudTrail
+
Access Analyzer
+
credential/access reviews
```

For assumed roles, source identity further improves attribution in CloudTrail. ([AWS Documentation][33])

---

# 70. Production CI/CD IAM Architecture

A mature deployment might be:

```text
                           GitHub
                             │
                          OIDC JWT
                             │
                             ▼
                         AWS STS
                             │
                             ▼
                     GitHubDeployRole
                             │
                  Permissions Boundary
                             │
                             ▼
                     deployment actions
                             │
           ┌─────────────────┼──────────────────┐
           ▼                 ▼                  ▼
         ECR               ECS/EKS             S3
           │
           ▼
      restricted
      PassRole only
      approved roles
```

Organization-level:

```text
SCP
   │
   ├── block IAM-user creation
   ├── protect logging
   └── Region restrictions
```

Audit:

```text
CloudTrail
+
Access Analyzer
```

This is much stronger than:

```text
GitHub secret:
permanent AdministratorAccess key
```

---

# 71. Production PassRole Pattern

Suppose deployment pipeline manages ECS.

You might allow:

```text
ecs:RegisterTaskDefinition

ecs:UpdateService
```

and:

```text
iam:PassRole
```

only for:

```text
arn:aws:iam::<account>:role/ecs/app/*
```

with:

```text
iam:PassedToService
=
ecs-tasks.amazonaws.com
```

Conceptual architecture:

```text
DeployRole
   │
   ├── update ECS
   │
   └── pass approved AppTaskRole
             │
             ▼
        ECS Tasks
```

Not:

```text
DeployRole
   │
   └── PassRole *
```

---

# 72. Separation of Duties

Security team owns:

```text
permissions boundary

SCP

production role templates

KMS policies

high-privilege roles
```

Application team owns:

```text
application deployment

resource configuration

allowed app roles
```

CI/CD owns:

```text
deployment automation
```

This reduces the risk that one compromised pipeline can redesign every security control.

---

# 73. Production OIDC Role Permission Policy

Trust decides:

```text
which GitHub workflow may assume?
```

Permission policy decides:

```text
what may that workflow do?
```

Never confuse the two.

Example:

```text
TRUST

repo:company/api
branch:main
```

Permissions:

```text
ECR push

ECS deploy

CloudWatch read

iam:PassRole
only approved ECS roles
```

That's a well-bounded deployment identity.

---

# 74. Terraform `PassRole` Example

```hcl
data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "DeployApplication"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PassApprovedECSTaskRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::111122223333:role/ecs/app/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}
```

This encodes:

```text
WHAT roles?
+
WHICH service?
```

rather than:

```text
iam:PassRole on *
```

AWS recommends exactly these forms of resource and service restrictions for PassRole. ([AWS Documentation][1])

---

# 75. IAM Security Review Checklist

When reviewing a role, investigate:

```text
Direct access
────────────────────────
What actions?
Which resources?
Conditions?


Permission-management
────────────────────────
Can it create roles?
Change policies?
Change trust?
Remove boundaries?


Delegation
────────────────────────
Can it PassRole?
Which roles?
To which services?


Federation
────────────────────────
Who can assume it?
OIDC claims constrained?
ExternalId needed?


Attributes
────────────────────────
Can it change tags
that drive ABAC?


Guardrails
────────────────────────
Boundary?
SCP?
RCP?


Audit
────────────────────────
CloudTrail?
SourceIdentity?
Access Analyzer?
```

That's a genuine enterprise IAM review.

---

# 76. Incident Scenario — Pipeline Has No S3 Access But S3 Data Was Modified

Initial conclusion:

```text
Impossible.
DeployRole has no s3:PutObject.
```

Better investigation:

```text
Does DeployRole have PassRole?

What roles can it pass?

Can it create Lambda/EC2/ECS?

Can it modify execution code?

Did a workload role have S3 access?

What does CloudTrail show?
```

Direct permissions aren't the entire attack/access graph.

---

# 77. Scenario — GitHub OIDC Works From Every Repository

Problem likely:

```text
trust policy too broad
```

For example:

```text
sub condition:
repo:my-org/*
```

or worse.

Fix:

```text
restrict:
organization
repository
branch/environment/workflow
```

according to deployment requirements. AWS explicitly recommends narrowly scoped GitHub `sub` claims. ([AWS Documentation][9])

---

# 78. Scenario — GitHub OIDC Works on Main but Not Feature Branch

Trust:

```text
sub =
repo:my-org/my-app:ref:refs/heads/main
```

Feature branch produces a different subject.

Therefore:

```text
AssumeRoleWithWebIdentity denied.
```

This may be intentional.

If feature branches need dev access:

```text
create separate DevRole
```

rather than loosening production trust unnecessarily.

---

# 79. Scenario — Third-Party SaaS Assumes Your Role

Ask immediately:

```text
Does role require ExternalId?

Who generated it?

Is it unique per customer?

What permissions does role have?
```

AWS recommends ExternalId specifically when a third party assumes roles for multiple customers. ([AWS Documentation][14])

---

# 80. Scenario — S3 Bucket Trusts AWS Service

Policy:

```text
Principal:
cloudtrail.amazonaws.com
```

Ask:

```text
SourceArn restriction?

SourceAccount?

SourceOrgID?
```

because service principals can act on behalf of different customer resources/accounts, creating confused-deputy risk without contextual constraints. ([AWS Documentation][13])

---

# 81. Scenario — ABAC User Can Modify `Project` Tag

Red flag.

If:

```text
Project tag
```

defines authorization, the user must not be able to arbitrarily set:

```text
Project=AnythingIWant
```

on principals/resources.

Protect:

```text
RequestTag

TagKeys

resource tag mutation
```

using IAM controls. AWS supports condition keys for controlling tag operations and values. ([AWS Documentation][20])

---

# 82. Scenario — Nobody Knows Who Used AdminRole

CloudTrail shows:

```text
assumed-role/AdminRole/session
```

but actor attribution is weak.

Improve design with:

```text
federated workforce identity

meaningful role session names

source identity

CloudTrail
```

AWS specifically recommends source identity when you want durable attribution across assumed-role activity. ([AWS Documentation][23])

---

# 83. Scenario — 200 Roles Have Permissions Nobody Understands

Use:

```text
IAM Access Analyzer
unused access
```

and:

```text
last accessed information
```

to identify:

```text
unused roles
unused services
unused actions
```

before reducing permissions carefully. ([AWS Documentation][27])

---

# 84. Scenario — Need Least-Privilege Policy for Existing Application

A practical approach:

```text
1. Run workload with controlled broader permissions.

2. Capture CloudTrail activity.

3. Generate Access Analyzer policy template.

4. Review missing rare paths.

5. Validate policy.

6. Test in staging.

7. Deploy narrower policy.

8. Monitor AccessDenied.

9. Refine.
```

IAM Access Analyzer can generate policy templates from up to 90 days of CloudTrail activity and service-last-accessed data. ([AWS Documentation][31])

---

# 85. SAA-C03 Scenario

> GitHub Actions needs AWS access without storing permanent AWS credentials.

Think:

```text
GitHub OIDC
+
IAM OIDC Provider
+
IAM Role
+
sts:AssumeRoleWithWebIdentity
```

with narrow claim conditions. ([AWS Documentation][8])

---

# 86. DOP-C02 Scenario

> Pipeline must deploy ECS services but must not use arbitrary IAM roles.

Use:

```text
iam:PassRole
```

scoped to:

```text
approved ECS role ARNs
```

and optionally:

```text
iam:PassedToService
=
ecs-tasks.amazonaws.com
```

rather than wildcard PassRole. ([AWS Documentation][1])

---

# 87. Scenario

> SaaS vendor manages AWS resources for thousands of customers.

Use:

```text
cross-account IAM role
+
unique ExternalId
```

per customer to mitigate confused-deputy risk. ([AWS Documentation][14])

---

# 88. Scenario

> AWS service principal should access resource only on behalf of your account.

Think:

```text
aws:SourceAccount
```

If one specific source resource is known:

```text
aws:SourceArn
```

is generally more precise. ([AWS Documentation][13])

---

# 89. Scenario

> Developer should manage only resources belonging to their project, without creating a different role policy for every project.

Strong candidate:

```text
ABAC
```

using:

```text
principal tags
+
resource tags
```

when supported by the relevant service/actions. ([AWS Documentation][18])

---

# 90. Scenario

> Security wants to find external access, internal access paths, and unused IAM permissions.

Think:

```text
IAM Access Analyzer
```

Current Access Analyzer supports external, internal, and unused access findings. ([AWS Documentation][25])

---

# 91. Scenario

> Security team wants to audit which IAM users have MFA and active access keys.

Use:

```text
IAM Credential Report
```

which includes IAM-user password/access-key/MFA status fields. ([AWS Documentation][32])

---

# 92. The Privilege Escalation Mental Model

Burn this into memory:

```text
                 CURRENT PERMISSION
                        │
                        ▼
                 Can change IAM?
                        │
                  ┌─────┴─────┐
                 YES          NO
                  │            │
                  ▼            ▼
        policy/trust/boundary   Can pass role?
        escalation possible       │
                              ┌────┴────┐
                             YES       NO
                              │         │
                              ▼         ▼
                     Can control service
                     using passed role?
                              │
                         ┌────┴────┐
                        YES       NO
                         │         │
                         ▼         ▼
                      HIGH RISK   lower risk
```

This is how security engineers think about IAM permissions as a graph rather than isolated strings.

---

# 93. The Federation Mental Model

```text
             EXTERNAL IDENTITY
                    │
        ┌───────────┴────────────┐
        ▼                        ▼
      SAML                      OIDC
        │                        │
        ▼                        ▼
AssumeRoleWithSAML      AssumeRoleWithWebIdentity
        │                        │
        └────────────┬───────────┘
                     ▼
                   STS
                     │
                     ▼
                IAM ROLE
                     │
                     ▼
          TEMPORARY CREDENTIALS
                     │
                     ▼
                   AWS
```

No permanent AWS key required for the federated identity itself. ([AWS Documentation][34])

---

# 94. The ABAC Mental Model

```text
                 PRINCIPAL
                     │
           Project = TodoApp
                     │
                     ▼
                 IAM POLICY
                     │
           compare attributes
                     │
                     ▼
                 RESOURCE
                     │
           Project = TodoApp
                     │
                     ▼
                   ALLOW
```

Different project:

```text
Resource:
Project = Finance
```

Result:

```text
DENY
```

assuming no other applicable permission grant overrides the implicit-deny path and the service/action supports the tag condition. ([AWS Documentation][18])

---

# 95. Production IAM Architecture

```text
                         AWS ORGANIZATION
                                │
                       ┌────────┴─────────┐
                       ▼                  ▼
                      SCP                RCP
                       │                  │
                       └────────┬─────────┘
                                ▼

                    HUMAN IDENTITIES
                                │
                        Corporate IdP
                                │
                     IAM Identity Center
                                │
                                ▼
                        Temporary Roles

                                +

                    WORKLOAD IDENTITIES
                                │
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
           EC2                 ECS               Lambda
            │                   │                   │
            └────────────── IAM Roles ──────────────┘

                                +

                         CI/CD IDENTITY
                                │
                             OIDC
                                │
                                ▼
                           DeployRole
                                │
                       Restricted PassRole

                                +

                          IAM CONTROLS
                                │
             ┌──────────────────┼─────────────────┐
             ▼                  ▼                 ▼
        Boundaries            ABAC          Trust Conditions
                                                   │
                              ExternalId / SourceArn /
                              SourceAccount / MFA

                                +

                        SECURITY ANALYSIS
                                │
                  ┌─────────────┼─────────────┐
                  ▼             ▼             ▼
             CloudTrail    Access Analyzer   Reports
```

That is a modern AWS identity architecture.

---

# 96. 30 Rules to Burn Into Memory

```text
1. Privilege is not only direct API permissions.

2. Permission combinations can create escalation paths.

3. iam:PassRole lets a principal designate a role
   for an AWS service to use.

4. PassRole is not AssumeRole.

5. PassRole is not a standalone API operation.

6. PassRole should almost never be Resource "*"
   for normal workloads.

7. Scope PassRole to approved role ARNs.

8. Use iam:PassedToService where appropriate.

9. A role passed to a service must trust that service.

10. Creating/modifying roles and policies is
    privilege-management authority.

11. Updating a role trust policy can create escalation.

12. Permissions boundaries help constrain
    developer-created roles.

13. Temporary credentials are preferable
    to permanent workload keys.

14. SAML is a major enterprise federation mechanism.

15. OIDC is important for modern CI/CD and workloads.

16. GitHub Actions can federate to AWS via OIDC.

17. GitHub OIDC uses AssumeRoleWithWebIdentity.

18. Restrict GitHub trust by repository/branch/environment.

19. Do not store permanent AWS keys in GitHub
    when OIDC is suitable.

20. ExternalId protects third-party cross-account
    delegation from confused-deputy risk.

21. ExternalId is not a password/secret.

22. SourceArn limits a service principal
    to a specific source resource.

23. SourceAccount limits service access
    to a specific source account.

24. MFA strengthens identity assurance,
    but does not replace least privilege.

25. ABAC uses attributes/tags for authorization.

26. Protect tags that control authorization.

27. Session tags can carry federated attributes.

28. SourceIdentity improves role-session auditability.

29. Access Analyzer finds excessive/external/unused access.

30. IAM security must analyze ACCESS PATHS,
    not individual policy statements.
```

The most important security lesson:

```text
A principal doesn't need
"AdministratorAccess"

to become dangerous.

It only needs a PATH
to administrator-level authority.
```

And that path could be:

```text
PassRole
+
compute creation
```

or:

```text
role creation
+
policy attachment
```

or:

```text
trust-policy modification
```

or:

```text
authorization-tag manipulation.
```

---

# ✅ Lesson 30 Part 3 Complete

You now understand:

```text
✓ IAM privilege escalation mental model
✓ direct vs indirect permissions
✓ iam:PassRole
✓ PassRole vs AssumeRole
✓ PassRole same-account behavior
✓ iam:PassedToService
✓ PassRole ARN restrictions
✓ compute-role escalation risk
✓ IAM role/policy modification risks
✓ permissions-boundary delegation

✓ federation
✓ SAML
✓ AssumeRoleWithSAML
✓ OIDC
✓ AssumeRoleWithWebIdentity
✓ GitHub Actions OIDC
✓ GitHub aud/sub conditions
✓ branch/repository restrictions
✓ protected deployment environments
✓ modern keyless CI/CD
✓ Terraform OIDC roles

✓ confused deputy problem
✓ ExternalId
✓ SourceArn
✓ SourceAccount
✓ SourceOrgID / SourceOrgPaths

✓ MFA
✓ MFA-protected API/role access
✓ RBAC
✓ ABAC
✓ PrincipalTag
✓ ResourceTag
✓ RequestTag
✓ tag escalation
✓ session tags
✓ transitive session tags
✓ SourceIdentity

✓ IAM Access Analyzer
✓ external access
✓ internal access
✓ unused access
✓ policy validation
✓ >100 policy checks
✓ policy generation from CloudTrail
✓ credential reports
✓ CloudTrail attribution
✓ production CI/CD IAM architecture
```

# Next — Lesson 30 Part 4

# **IAM Enterprise Operations — Identity Center, Multi-Account Access, Access Analyzer Labs & Full IAM Capstone**

Part 4 will complete IAM by building the enterprise operating model:

```text
AWS Organizations
       │
       ▼
IAM Identity Center
       │
       ├── users / groups
       ├── external IdP
       ├── permission sets
       ├── account assignments
       └── temporary sessions

Multi-Account
       │
       ├── Management
       ├── Security
       ├── Shared Services
       ├── Dev
       ├── Staging
       └── Production

Security Guardrails
       │
       ├── SCP
       ├── RCP
       ├── boundaries
       ├── MFA
       ├── ABAC
       └── least privilege

Operations
       │
       ├── CloudTrail
       ├── Access Analyzer
       ├── credential auditing
       ├── unused access cleanup
       └── incident response
```

We'll also do a **full production IAM troubleshooting lab** covering a Terraform role that receives `AccessDenied` from **EC2 + ECR + S3 + KMS + PassRole**, and work each denial down to its exact policy layer. After Part 4, **Lesson 30/IAM will be complete** and we'll move into **Lesson 31 — KMS, Secrets Manager, ACM & AWS Security Services**.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_passrole.html "Grant a user permissions to pass a role to an AWS service - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html?utm_source=chatgpt.com "IAM and AWS STS condition context keys"
[3]: https://docs.aws.amazon.com/securityhub/latest/userguide/exposure-iam-user.html?utm_source=chatgpt.com "Remediating exposures for IAM users - AWS Security Hub"
[4]: https://docs.aws.amazon.com/prescriptive-guidance/latest/least-privilege-cloudformation/service-roles-for-cloudformation.html?utm_source=chatgpt.com "Service roles for CloudFormation"
[5]: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html?utm_source=chatgpt.com "Security best practices in IAM - AWS Identity and Access ..."
[6]: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithSAML.html?utm_source=chatgpt.com "AssumeRoleWithSAML - AWS Security Token Service"
[7]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_saml.html?utm_source=chatgpt.com "Create a SAML identity provider in IAM - AWS Documentation"
[8]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html?utm_source=chatgpt.com "OIDC federation - AWS Identity and Access Management"
[9]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html "Create a role for OpenID Connect federation (console) - AWS Identity and Access Management"
[10]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html?utm_source=chatgpt.com "Create an OpenID Connect (OIDC) identity provider in IAM"
[11]: https://github.com/aws-actions/configure-aws-credentials?utm_source=chatgpt.com "Configure AWS credential environment variables for use ..."
[12]: https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services?utm_source=chatgpt.com "Configuring OpenID Connect in Amazon Web Services"
[13]: https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html "The confused deputy problem - AWS Identity and Access Management"
[14]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_third-party.html "Access to AWS accounts owned by third parties - AWS Identity and Access Management"
[15]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa.html?utm_source=chatgpt.com "AWS Multi-factor authentication in IAM"
[16]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_configure-api-require.html?utm_source=chatgpt.com "Secure API access with MFA"
[17]: https://docs.aws.amazon.com/IAM/latest/UserGuide/sts_example_sts_Scenario_AssumeRoleMfa_section.html?utm_source=chatgpt.com "Assume an IAM role that requires an MFA token with ..."
[18]: https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_attribute-based-access-control.html "IAM tutorial: Define permissions to access AWS resources based on tags - AWS Identity and Access Management"
[19]: https://docs.aws.amazon.com/tag-editor/latest/userguide/tags-in-iam-policies.html?utm_source=chatgpt.com "Using tags in IAM permission policies"
[20]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_iam-tags.html?utm_source=chatgpt.com "Controlling access to and for IAM users and roles using tags"
[21]: https://docs.aws.amazon.com/lambda/latest/dg/attribute-based-access-control-example.html?utm_source=chatgpt.com "Secure your functions by tag - AWS Lambda"
[22]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_session-tags.html?utm_source=chatgpt.com "Pass session tags in AWS STS"
[23]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html?utm_source=chatgpt.com "Monitor and control actions taken with assumed roles"
[24]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-user-identity.html?utm_source=chatgpt.com "CloudTrail userIdentity element - AWS Documentation"
[25]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-findings.html?utm_source=chatgpt.com "IAM Access Analyzer findings"
[26]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html?utm_source=chatgpt.com "AWS Identity and Access Management Access Analyzer ..."
[27]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html "Using AWS Identity and Access Management Access Analyzer - AWS Identity and Access Management"
[28]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html?utm_source=chatgpt.com "Validate policies with IAM Access Analyzer"
[29]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html?utm_source=chatgpt.com "Policies and permissions in AWS Identity and Access ..."
[30]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html?utm_source=chatgpt.com "IAM policy validation check reference - AWS Documentation"
[31]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html?utm_source=chatgpt.com "IAM Access Analyzer policy generation - AWS Documentation"
[32]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_getting-report.html "Generate credential reports for your AWS account - AWS Identity and Access Management"
[33]: https://docs.aws.amazon.com/IAM/latest/UserGuide/cloudtrail-integration.html?utm_source=chatgpt.com "Logging IAM and AWS STS API calls with AWS CloudTrail"
[34]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_saml.html?utm_source=chatgpt.com "SAML 2.0 federation - AWS Identity and Access Management"
