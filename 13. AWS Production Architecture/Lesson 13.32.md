# AWS Masterclass — Phase 3

# Lesson 31: Advanced AWS IAM Architecture

## 1. Lesson objectives

In this lesson, you will learn how to:

* Understand AWS authentication and authorization.
* Secure the AWS account root user.
* Distinguish IAM users, groups, roles and federated identities.
* Use temporary credentials instead of long-lived access keys.
* Understand identity-based and resource-based policies.
* Write accurate IAM JSON policies.
* Understand explicit and implicit denial.
* Use role trust policies.
* Use permission boundaries, session policies, SCPs and RCPs.
* Design cross-account access.
* Use AWS STS and `AssumeRole`.
* Prevent confused-deputy attacks with external IDs.
* Understand `iam:PassRole`.
* Implement role-based and attribute-based access control.
* Use IAM Identity Center for workforce access.
* Configure workload identities for EC2 and CI/CD.
* Use IAM Access Analyzer.
* Troubleshoot real `AccessDenied` errors.
* Build production IAM resources with Terraform.

---

# 2. Production IAM architecture

A mature multi-account AWS environment commonly looks like this:

```text
                         Corporate identity provider
                      Entra ID / Okta / Google / AD
                                   |
                                   | SAML / SCIM
                                   v
                         AWS IAM Identity Center
                                   |
                    Permission sets and group mapping
                                   |
              ┌────────────────────┼────────────────────┐
              |                    |                    |
              v                    v                    v
        Development account   Staging account     Production account
              |                    |                    |
        Developer role        Operator role       Read-only role
                                                   Admin role
                                                        |
                                                        | AssumeRole
                                                        v
                                               Temporary credentials
                                                        |
                                                        v
                                                 AWS resources
```

Workloads use a different path:

```text
EC2 / ECS / Lambda / EKS / GitHub Actions
                    |
                    | Assume an IAM role
                    v
             Temporary STS credentials
                    |
                    v
         S3 / ECR / Secrets Manager / RDS
```

AWS recommends federation and temporary role credentials for human users and temporary role credentials for workloads, rather than creating long-lived IAM credentials wherever roles can be used. ([AWS Documentation][1])

---

# 3. What is IAM?

IAM stands for:

```text
Identity and Access Management
```

IAM controls two fundamental questions:

```text
Authentication:
Who are you?

Authorization:
What are you allowed to do?
```

AWS IAM manages identities and policies that control access to AWS services and resources. ([AWS Documentation][2])

## Example

```text
Authentication:
Vivek signed in through IAM Identity Center.

Authorization:
Vivek may read EC2 instances in production,
but may not terminate them.
```

---

# 4. Principal, action, resource and context

Every AWS authorization request can be understood using four major questions:

```text
Who?
What action?
On which resource?
Under what conditions?
```

Example:

```text
Principal:
arn:aws:sts::123456789012:assumed-role/DevOpsRole/vivek

Action:
ec2:TerminateInstances

Resource:
arn:aws:ec2:ap-south-1:123456789012:instance/i-0123456789

Context:
Requested Region, source IP, MFA, tags, organization, time
```

IAM evaluates the policies applicable to the request context and determines whether the action is allowed or denied.

---

# 5. The root user

The root user is created when an AWS account is created.

It has access to almost every account and AWS service operation, including some operations that cannot be completed by ordinary IAM administrators.

## Root user is not

```text
An IAM user
An IAM role
A normal daily administrator
```

## Root user should be used only for

```text
Rare account-level tasks
Account recovery
Tasks explicitly requiring root
Emergency procedures
```

AWS strongly recommends avoiding root for everyday administration, enabling MFA, not creating root access keys and tightly controlling account-recovery mechanisms. ([AWS Documentation][3])

---

# 6. Current root-security requirements

AWS currently requires MFA to be configured for the root user of standalone, management and member accounts, unless root access is centrally managed in an AWS Organizations architecture that removes recoverable root credentials from member accounts. ([AWS Documentation][4])

Recommended controls:

```text
[ ] Strong unique root password
[ ] Phishing-resistant MFA or passkey
[ ] No root access keys
[ ] Group-owned root email
[ ] Protected email recovery account
[ ] Protected billing contact
[ ] CloudTrail monitoring
[ ] Root login alarm
[ ] Multi-person approval for root access
```

---

# 7. Centralized root access

Organizations can centrally manage root access for member accounts.

After centralization, you can remove member-account root credentials such as:

```text
Root password
Root access keys
Signing certificates
Root MFA configuration
```

Privileged member-account tasks can then be performed through centrally controlled short-term root access using authorized roles and `sts:AssumeRoot`. ([AWS Documentation][5])

## Mental model

```text
Old model:
Every account has recoverable root credentials.

Centralized model:
Member accounts have no persistent root credentials.
Approved administrators request short-term privileged access.
```

This significantly reduces the number of permanent high-value credentials across a large organization.

---

# 8. IAM identity types

Important identity types include:

```text
AWS account root user
IAM user
IAM group
IAM role
IAM Identity Center user
Federated user
Assumed-role session
AWS service principal
```

---

# 9. IAM user

An IAM user represents an identity inside one AWS account.

It may have:

```text
Console password
Access key ID
Secret access key
MFA device
Identity policies
Group membership
Tags
```

## Appropriate IAM-user use cases

IAM users should now be exceptional rather than the normal design.

Possible cases:

```text
Legacy application that cannot assume a role
Specific service integration requiring long-lived credentials
Emergency break-glass identity
Workload outside AWS where Roles Anywhere or OIDC is unavailable
```

## Inappropriate use cases

```text
One IAM user for every employee
Shared administrator user
Access keys stored on EC2
Access keys committed to Git
Permanent CI/CD access keys
```

AWS recommends human users access AWS through federation or IAM Identity Center using temporary credentials. ([AWS Documentation][6])

---

# 10. IAM groups

An IAM group is a collection of IAM users.

Example:

```text
Group: Developers

Attached policies:
Read EC2
Read CloudWatch Logs
Push to selected ECR repositories
```

Important:

```text
Groups contain users.
Groups cannot contain other groups.
Roles do not join groups.
```

In a modern multi-account environment, IAM Identity Center groups and permission sets are usually a more scalable workforce-access model.

---

# 11. IAM role

An IAM role is an AWS identity with permissions, but it does not have a normal permanent password or access key.

Instead, a trusted principal assumes the role and receives temporary security credentials. ([AWS Documentation][7])

A role contains two separate policy areas:

```text
Trust policy:
Who may assume the role?

Permissions policies:
What may the role do after assumption?
```

## Never-forget distinction

```text
Trust policy:
Who can become the role?

Permission policy:
What can the role do?
```

---

# 12. Role assumption flow

```text
User or workload
      |
      | sts:AssumeRole
      v
AWS STS
      |
      | Temporary access key
      | Temporary secret key
      | Session token
      | Expiration
      v
Assumed-role session
      |
      v
AWS API calls
```

The assumed identity looks like:

```text
arn:aws:sts::123456789012:
assumed-role/ProductionDeployRole/vivek-session
```

The role session name appears in the session ARN and can be recorded in the trusting account’s CloudTrail logs. ([AWS Documentation][8])

---

# 13. Temporary credentials

Temporary credentials contain:

```text
Access key ID
Secret access key
Session token
Expiration
```

They automatically expire.

Advantages:

* No permanent secret to rotate manually.
* Reduced impact if leaked.
* Sessions can be short-lived.
* Session policies can reduce permissions.
* CloudTrail records the assumed-role identity.
* MFA can be required.
* Session tags can carry attributes.

AWS STS creates temporary credentials for trusted identities and workloads. ([AWS Documentation][9])

---

# 14. AWS Security Token Service

AWS STS provides APIs such as:

```text
AssumeRole
AssumeRoleWithSAML
AssumeRoleWithWebIdentity
GetFederationToken
GetSessionToken
AssumeRoot
```

The most common role API is:

```text
sts:AssumeRole
```

CLI example:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/ProductionReadOnly \
  --role-session-name vivek-production-readonly \
  --duration-seconds 3600
```

Response:

```json
{
  "Credentials": {
    "AccessKeyId": "ASIA...",
    "SecretAccessKey": "...",
    "SessionToken": "...",
    "Expiration": "2026-07-27T10:30:00Z"
  },
  "AssumedRoleUser": {
    "AssumedRoleId": "...",
    "Arn": "arn:aws:sts::222222222222:assumed-role/ProductionReadOnly/vivek-production-readonly"
  }
}
```

---

# 15. Role session duration

If a caller does not specify a session duration, role credentials commonly default to one hour. Roles can be configured with a maximum session duration, but role chaining has a hard maximum of one hour. ([AWS Documentation][10])

## Role chaining

```text
User
  ↓ assumes
Role A
  ↓ assumes
Role B
```

The Role B session is limited to:

```text
Maximum one hour
```

even when Role B allows a longer maximum session.

---

# 16. IAM policy types

The main authorization-policy types are:

```text
Identity-based policies
Resource-based policies
Role trust policies
Permissions boundaries
Session policies
Service control policies
Resource control policies
VPC endpoint policies
Access-control lists in applicable services
```

Each answers a different security question.

---

# 17. Identity-based policies

An identity-based policy is attached to:

```text
IAM user
IAM group
IAM role
```

It grants or denies actions that the identity can perform.

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadProductionLogs",
      "Effect": "Allow",
      "Action": [
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:ap-south-1:123456789012:log-group:/production/*"
    }
  ]
}
```

---

# 18. AWS-managed policy

An AWS-managed policy is created and maintained by AWS.

Examples:

```text
ReadOnlyAccess
AmazonS3ReadOnlyAccess
AmazonEC2ReadOnlyAccess
```

Advantages:

* Quick to deploy.
* Maintained by AWS.
* Useful for initial learning or broad job functions.

Disadvantages:

* Often broader than a specific workload requires.
* AWS may update the policy.
* May include permissions outside your desired scope.

AWS recommends using managed policies as a starting point and moving toward least-privilege policies based on actual access requirements. ([AWS Documentation][1])

---

# 19. Customer-managed policy

A customer-managed policy is created and maintained by your organization.

Advantages:

```text
Reusable
Versioned
Centrally managed
Attachable to multiple identities
More precise than broad AWS policies
```

Example:

```text
ProductionECRPushPolicy
DevelopmentEC2OperatorPolicy
TerraformStateAccessPolicy
CloudFrontDeploymentPolicy
```

---

# 20. Inline policy

An inline policy is embedded directly in one user, group or role.

```text
Role
└── Inline policy
```

Use inline policies when:

* The policy has a strict one-to-one relationship with the identity.
* Deleting the identity should delete the policy.
* Reuse is not desired.

Prefer customer-managed policies for policies that should be reused, reviewed or versioned independently.

---

# 21. Resource-based policy

A resource-based policy is attached to a resource.

Common examples:

```text
S3 bucket policy
KMS key policy
SQS queue policy
SNS topic policy
Secrets Manager resource policy
Lambda resource policy
ECR repository policy
IAM role trust policy
```

A resource policy identifies the principal that may access the resource.

Example S3 policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountRead",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/AnalyticsRole"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::production-reports/*"
    }
  ]
}
```

The `Principal` element is used in resource-based policies and role trust policies, not ordinary identity permission policies. ([AWS Documentation][11])

---

# 22. Role trust policy

Every assumable IAM role has a trust policy.

Example for EC2:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

This means:

```text
EC2 service may assume this role.
```

It does not mean:

```text
The role may perform every EC2 operation.
```

The role’s attached permission policies determine what it can do after assumption.

---

# 23. IAM policy structure

A standard policy document contains:

```json
{
  "Version": "2012-10-17",
  "Statement": []
}
```

Common statement elements:

```text
Sid
Effect
Principal or NotPrincipal
Action or NotAction
Resource or NotResource
Condition
```

The element order does not change policy meaning. Mutually exclusive pairs such as `Action` and `NotAction` cannot appear together in the same statement. ([AWS Documentation][12])

---

# 24. `Version`

Use:

```json
"Version": "2012-10-17"
```

This is the policy-language version, not:

```text
Creation date
Deployment date
Policy revision number
```

---

# 25. `Sid`

`Sid` is an optional statement identifier.

Example:

```json
"Sid": "AllowReadOnlyAccessToTerraformState"
```

Use descriptive identifiers:

```text
AllowApplicationReadSecret
DenyUnencryptedS3Uploads
AllowCloudFrontReadBucket
DenyOutsideApprovedRegions
```

---

# 26. `Effect`

Values:

```text
Allow
Deny
```

Example:

```json
"Effect": "Allow"
```

An explicit `Deny` overrides applicable `Allow` statements. ([AWS Documentation][13])

---

# 27. `Action`

`Action` identifies allowed or denied API operations.

Example:

```json
"Action": [
  "s3:GetObject",
  "s3:PutObject"
]
```

Service prefix:

```text
s3
```

API actions:

```text
GetObject
PutObject
```

Wildcard example:

```json
"Action": "s3:Get*"
```

This may include more operations than initially expected, so validate wildcard use carefully.

---

# 28. `Resource`

`Resource` identifies the ARN to which a statement applies.

Example:

```json
"Resource": "arn:aws:s3:::production-artifacts/*"
```

S3 bucket ARN:

```text
arn:aws:s3:::production-artifacts
```

Objects in bucket:

```text
arn:aws:s3:::production-artifacts/*
```

Those are different resources.

Some AWS actions do not support resource-level permissions and require:

```json
"Resource": "*"
```

Consult the service authorization reference to determine which actions support specific ARNs. ([AWS Documentation][14])

---

# 29. `Condition`

Conditions restrict when a statement applies.

Example:

```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": "ap-south-1"
  }
}
```

Useful condition keys include:

```text
aws:RequestedRegion
aws:SourceIp
aws:SourceVpc
aws:SourceVpce
aws:PrincipalArn
aws:PrincipalOrgID
aws:PrincipalTag/*
aws:ResourceTag/*
aws:RequestTag/*
aws:TagKeys
aws:SecureTransport
aws:MultiFactorAuthPresent
aws:SourceArn
aws:SourceAccount
sts:ExternalId
sts:SourceIdentity
iam:PassedToService
```

---

# 30. Secure transport condition

Example S3 bucket policy that rejects non-TLS requests:

```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::production-artifacts",
    "arn:aws:s3:::production-artifacts/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

Meaning:

```text
HTTP request
    → Explicitly denied

HTTPS request
    → Evaluated by remaining policies
```

---

# 31. Region restriction

Example:

```json
{
  "Sid": "DenyOutsideApprovedRegions",
  "Effect": "Deny",
  "NotAction": [
    "iam:*",
    "route53:*",
    "cloudfront:*",
    "support:*"
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
```

This pattern needs careful service-specific review because some AWS services are global and may be called through a particular control-plane Region.

`NotAction` is an advanced element that matches every applicable action except the listed actions, and improper use can create unexpectedly broad permission or denial behavior. ([AWS Documentation][15])

---

# 32. Default deny

AWS authorization starts with:

```text
Implicit deny
```

If no policy allows an operation, it is denied.

Example:

```text
Policy permits:
s3:GetObject

Request:
s3:DeleteObject

Result:
Implicit deny
```

No explicit `Deny` statement is required.

---

# 33. Explicit deny

Example:

```json
{
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "*"
}
```

Even when another policy says:

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

the result is:

```text
Denied
```

## Core rule

```text
Explicit Deny wins over Allow.
```

---

# 34. IAM evaluation mental model

Use this simplified model:

```text
1. Start with implicit deny.

2. Search for an applicable explicit deny.
   If found → Deny.

3. Search for an applicable allow.

4. Check restricting policy layers:
   - Permission boundary
   - Session policy
   - SCP
   - RCP
   - VPC endpoint policy
   - Service-specific policy

5. If all required layers permit → Allow.

6. Otherwise → Deny.
```

AWS evaluates identity policies, resource policies, permission boundaries, session policies and Organizations policies together; explicit denial in any applicable policy overrides permission grants. ([AWS Documentation][16])

---

# 35. Policy-set relationship

Within one account, identity and resource permissions often behave like a union:

```text
Identity policy Allow
        OR
Resource policy Allow
        ↓
Potential permission
```

Restriction policies then reduce the maximum result:

```text
Potential permission
        ∩
Permission boundary
        ∩
Session policy
        ∩
SCP
        ∩
RCP
        ↓
Effective permission
```

An explicit denial at any applicable layer wins.

---

# 36. Important resource-policy nuance

Resource-based policies have advanced evaluation behavior depending on whether the policy grants access to:

```text
IAM user ARN
IAM role ARN
Assumed-role session ARN
Federated session ARN
```

For example, within the same account, a grant directly to an assumed-role session ARN can grant permission directly to that session and may not be restricted by implicit denial in the role’s identity policy, permissions boundary or session policy. Explicit denies still apply. ([AWS Documentation][17])

## Production advice

Prefer granting resource-policy access to:

```text
IAM role ARN
```

rather than dynamically generated session ARNs, unless you understand the evaluation consequence.

---

# 37. Permissions boundary

A permissions boundary defines the maximum permission an IAM user or role can receive from identity-based policies.

It does not grant access by itself. ([AWS Documentation][18])

Example:

```text
Identity policy:
AdministratorAccess

Permission boundary:
Only S3, EC2 and CloudWatch

Effective permissions:
Only S3, EC2 and CloudWatch
```

## Formula

```text
Effective identity permission =
Identity policy
∩
Permission boundary
```

---

# 38. Permissions-boundary use case

Suppose application teams may create roles.

Without a boundary:

```text
Developer creates role
    ↓
Attaches AdministratorAccess
    ↓
Privilege escalation
```

With a mandatory boundary:

```text
Developer creates role
    ↓
Must attach CompanyDeveloperBoundary
    ↓
Role can never exceed approved maximum
```

## Example boundary

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ApprovedServices",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "logs:*",
        "cloudwatch:*",
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Even if the role receives:

```text
AdministratorAccess
```

it still cannot perform IAM or EC2 operations outside the boundary.

---

# 39. Enforce a boundary during role creation

Delegated administrator policy concept:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CreateBoundedRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "iam:TagRole"
      ],
      "Resource": "arn:aws:iam::123456789012:role/application/*",
      "Condition": {
        "StringEquals": {
          "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/ApplicationBoundary"
        }
      }
    }
  ]
}
```

Also prevent developers from removing or replacing the required boundary.

---

# 40. Session policy

A session policy is passed when creating a temporary STS session.

It further restricts the role’s normal permissions.

Example role permission:

```text
Read all S3 production reports
```

Session policy:

```text
Read only reports/2026/july/*
```

Effective session:

```text
Role permissions
∩
Session policy
```

Session policies cannot grant permissions that the role itself does not possess.

---

# 41. Assume role with session policy

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/ReportReader \
  --role-session-name july-audit \
  --policy '{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Effect":"Allow",
        "Action":"s3:GetObject",
        "Resource":"arn:aws:s3:::reports/2026/july/*"
      }
    ]
  }'
```

This creates a narrower temporary session without modifying the base role.

---

# 42. Service control policy

An SCP is an AWS Organizations guardrail that limits the maximum permissions available to IAM users and roles in member accounts.

An SCP does not grant permissions. ([AWS Documentation][19])

## Example

```text
IAM policy:
Allow ec2:TerminateInstances

SCP:
Deny ec2:TerminateInstances

Result:
Denied
```

## Formula

```text
Effective permission =
Account IAM permissions
∩
SCP permissions
```

---

# 43. SCP inheritance

Organizations hierarchy:

```text
Organization root
      |
      ├── Security OU
      |
      ├── Development OU
      |      └── Development account
      |
      └── Production OU
             └── Production account
```

An account is affected by applicable SCPs attached to:

```text
Organization root
Parent OU
Child OU
Account
```

An explicit denial anywhere in that inherited path applies to the account.

---

# 44. SCP example: protect security services

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDisablingCloudTrail",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/OrganizationSecurityAdmin"
          ]
        }
      }
    }
  ]
}
```

Use cases:

```text
Prevent disabling CloudTrail
Prevent leaving the organization
Restrict unauthorized Regions
Prevent public S3 changes
Protect GuardDuty
Prevent creation of root access keys
Require approved organization boundaries
```

Always test SCPs in a noncritical OU before applying them broadly.

---

# 45. Management-account exception

SCPs do not restrict identities in the Organizations management account.

Therefore:

```text
Management account
```

should contain very few workloads and tightly controlled administrative access.

Do not treat an SCP as a universal control over the management account.

---

# 46. Resource control policy

Resource control policies, or RCPs, are Organizations guardrails that restrict the maximum permissions available on resources in member accounts.

They complement SCPs:

```text
SCP:
Limits what identities can do.

RCP:
Limits how organization resources may be accessed.
```

RCPs do not grant access. They limit access that would otherwise be allowed through identity or resource policies. ([AWS Documentation][20])

---

# 47. RCP use case

Suppose an S3 bucket administrator accidentally grants:

```json
"Principal": "*"
```

An RCP can centrally deny access unless the principal belongs to your organization.

Conceptual guardrail:

```text
Deny access to supported organization resources
when aws:PrincipalOrgID does not equal your organization.
```

This helps protect resources from accidental external sharing.

RCPs affect supported resources in member accounts but do not affect resources in the Organizations management account. ([AWS Documentation][20])

---

# 48. SCP versus RCP

| Feature                     | SCP                             | RCP                              |
| --------------------------- | ------------------------------- | -------------------------------- |
| Main subject                | Identities                      | Resources                        |
| Limits                      | Actions available to principals | Access available on resources    |
| Grants permissions          | No                              | No                               |
| Attached to                 | Root, OU, account               | Root, OU, account                |
| Management account affected | No                              | No                               |
| Typical use                 | Deny unapproved services        | Prevent external resource access |

## Memory trick

```text
SCP guards the actor.
RCP guards the resource.
```

---

# 49. Cross-account access

Cross-account role access normally requires permission on both sides.

```text
Account A:
Caller identity policy allows sts:AssumeRole

Account B:
Role trust policy trusts Account A
```

AWS performs authorization evaluation in both the trusted account and the trusting account. Both sides must return `Allow`. ([AWS Documentation][21])

---

# 50. Cross-account trust architecture

```text
Account A: CI/CD account
Role: JenkinsControllerRole
          |
          | sts:AssumeRole
          v
Account B: Production account
Role: ProductionDeploymentRole
          |
          v
ECS / S3 / CloudFront / Lambda
```

## Account B trust policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/JenkinsControllerRole"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Account A identity policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::222222222222:role/ProductionDeploymentRole"
    }
  ]
}
```

---

# 51. Do not trust an entire account unnecessarily

Broad trust:

```json
"Principal": {
  "AWS": "arn:aws:iam::111111111111:root"
}
```

This delegates trust to identities in that account that are granted permission to assume the role.

More precise:

```json
"Principal": {
  "AWS": "arn:aws:iam::111111111111:role/JenkinsControllerRole"
}
```

Prefer the narrowest trusted principal that satisfies the requirement.

---

# 52. External ID

An external ID helps prevent the confused-deputy problem when a third party assumes roles for multiple customers.

Example:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::999999999999:role/VendorAccessRole"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "customer-vivek-7f93a4"
    }
  }
}
```

The third party includes:

```bash
--external-id customer-vivek-7f93a4
```

AWS recommends an external ID when a third party that serves multiple customers assumes a role in your account. ([AWS Documentation][22])

## External ID is not

```text
A password
A replacement for trust policy
A replacement for the principal restriction
```

It is an additional context requirement.

---

# 53. Source identity

`sts:SourceIdentity` helps preserve the original human or workload identity across role usage.

Example trust requirement:

```json
{
  "Condition": {
    "StringLike": {
      "sts:SourceIdentity": "employee-*"
    }
  }
}
```

Assumption:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/ProductionOperator \
  --role-session-name vivek-session \
  --source-identity employee-vivek
```

Source identity can improve attribution in CloudTrail and can be required in the role trust policy. ([AWS Documentation][23])

---

# 54. MFA-protected role assumption

Trust policy concept:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/vivek"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

Assume role:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/SensitiveAdmin \
  --role-session-name vivek-sensitive-admin \
  --serial-number arn:aws:iam::123456789012:mfa/vivek \
  --token-code 123456
```

For workforce identities, enforce MFA centrally through the identity provider and IAM Identity Center rather than creating many isolated IAM-user MFA configurations.

---

# 55. Session tags

Session tags are temporary key-value attributes attached to an STS session.

Example:

```text
Department = DevOps
Environment = Production
Project = TodoApp
```

They can be used in ABAC conditions:

```json
"Condition": {
  "StringEquals": {
    "aws:ResourceTag/Project": "${aws:PrincipalTag/Project}"
  }
}
```

AWS supports up to 50 session tags, and selected tags can be transitive across role chaining. ([AWS Documentation][24])

---

# 56. Role-based access control

RBAC stands for:

```text
Role-Based Access Control
```

Access is based primarily on job roles.

Example:

```text
Developer role:
Deploy to development

Operator role:
Restart production services

Auditor role:
Read configuration and logs

Security administrator:
Manage security controls
```

RBAC works well when job functions are stable and the number of distinct access patterns is manageable.

---

# 57. Attribute-based access control

ABAC stands for:

```text
Attribute-Based Access Control
```

Access is based on attributes such as tags.

Example:

```text
Principal tag:
Project = TodoApp

Resource tag:
Project = TodoApp

Result:
Access permitted
```

AWS supports using principal, session, request and resource tags in IAM conditions for services that support tag-based authorization. ([AWS Documentation][25])

---

# 58. ABAC example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageMatchingProjectInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:RebootInstances"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Project": "${aws:PrincipalTag/Project}"
        }
      }
    }
  ]
}
```

A principal tagged:

```text
Project = TodoApp
```

can manage EC2 instances tagged:

```text
Project = TodoApp
```

but not:

```text
Project = BankingAPI
```

---

# 59. ABAC privilege-escalation risk

Suppose users may tag resources freely.

A developer could change:

```text
Project = OtherTeam
```

to:

```text
Project = TodoApp
```

and gain access.

Therefore ABAC requires controls on:

```text
Who may apply tags
Which tag keys may be used
Which tag values may be used
Whether tags may be modified
Whether tags are required at creation
```

Example condition keys:

```text
aws:RequestTag/Project
aws:TagKeys
```

---

# 60. IAM Identity Center

IAM Identity Center is AWS’s centralized workforce access solution.

It can:

* Connect to an external identity provider.
* Synchronize users and groups.
* Manage its own identity directory.
* Assign users or groups to AWS accounts.
* Assign permission sets.
* Provide a central AWS access portal.
* Provide temporary credentials for CLI and console sessions.

IAM Identity Center is AWS’s recommended service for multi-account workforce access. ([AWS Documentation][26])

---

# 61. Permission sets

A permission set is a reusable access definition in IAM Identity Center.

Example:

```text
Permission set:
ProductionReadOnly

Policies:
ReadOnlyAccess
Custom deny for secret values

Session duration:
2 hours
```

When assigned to an account, IAM Identity Center creates and manages an IAM role in that account.

Typical generated role name:

```text
AWSReservedSSO_ProductionReadOnly_<unique-suffix>
```

Users do not need individual IAM users in each account.

---

# 62. Workforce-access pattern

```text
Employee joins company
        ↓
User added to identity-provider group
        ↓
Group synchronized to IAM Identity Center
        ↓
Group assigned permission set
        ↓
Employee receives access to approved AWS accounts
```

Offboarding:

```text
User disabled in identity provider
        ↓
Future AWS access stops centrally
```

This is safer and more scalable than removing independent IAM users and keys from many accounts.

---

# 63. Identity federation

Federation lets users authenticate through an external identity provider and obtain AWS sessions.

Common protocols:

```text
SAML 2.0
OpenID Connect
OAuth-related application flows
```

## SAML

Common for workforce federation:

```text
Entra ID
Okta
AD FS
Ping Identity
```

Flow:

```text
User authenticates with corporate IdP
        ↓
IdP sends SAML assertion
        ↓
AWS STS AssumeRoleWithSAML
        ↓
Temporary AWS role session
```

## OIDC

Common for:

```text
CI/CD systems
Web identities
Kubernetes workloads
GitHub Actions
Mobile and web applications
```

Flow:

```text
OIDC provider issues signed token
        ↓
AWS validates issuer, audience and claims
        ↓
STS AssumeRoleWithWebIdentity
        ↓
Temporary AWS credentials
```

---

# 64. GitHub Actions OIDC architecture

Avoid:

```text
GitHub secret:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Prefer:

```text
GitHub Actions
      |
      | OIDC token
      v
AWS IAM OIDC provider
      |
      | AssumeRoleWithWebIdentity
      v
Deployment role
      |
      v
ECR / ECS / S3 / CloudFront
```

Trust policy concept:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-org/todo-app:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

This restricts assumption to:

```text
Repository:
your-org/todo-app

Branch:
main
```

Do not use a broad subject such as:

```text
repo:*/*
```

for a production deployment role.

---

# 65. Workload roles

Different compute services use roles differently:

| Workload           | IAM identity                         |
| ------------------ | ------------------------------------ |
| EC2                | Instance profile role                |
| Lambda             | Execution role                       |
| ECS                | Task role and execution role         |
| EKS                | Pod identity or service-account role |
| CodeBuild          | Service role                         |
| GitHub Actions     | OIDC-assumed role                    |
| On-premises server | IAM Roles Anywhere                   |
| CloudFormation     | Service role                         |

Never reuse one broad role for every workload.

---

# 66. EC2 role and instance profile

EC2 uses an instance profile as the container through which an IAM role is attached to an instance. ([AWS Documentation][27])

```text
IAM role:
Defines permissions

Instance profile:
Attaches role to EC2
```

Architecture:

```text
EC2 instance
    |
    v
Instance profile
    |
    v
IAM role
    |
    v
Temporary credentials through IMDS
```

---

# 67. EC2 temporary credentials

Applications on EC2 can obtain temporary role credentials through the Instance Metadata Service.

AWS SDKs and the AWS CLI automatically use these credentials through the standard credential-provider chain. ([AWS Documentation][28])

Do not write this on EC2:

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
```

Use:

```text
EC2 role
+
Instance profile
+
IMDSv2
```

---

# 68. IMDSv2

Require IMDSv2:

```hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

Manual metadata retrieval:

```bash
TOKEN=$(curl -sS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

ROLE_NAME=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/)

curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME"
```

Applications should normally let the AWS SDK perform this automatically.

---

# 69. ECS task role versus execution role

## Task execution role

Used by the ECS infrastructure to:

```text
Pull image from ECR
Write logs
Retrieve startup secrets
```

## Task role

Used by your application code to:

```text
Read S3
Publish SQS
Read DynamoDB
Call Secrets Manager
```

Do not place application data permissions only in the execution role and assume the application container automatically receives them.

---

# 70. Lambda execution role

A Lambda execution role permits the Lambda service to assume the role:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "lambda.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

Attached permissions might allow:

```text
CloudWatch Logs
S3 object access
DynamoDB access
Secrets Manager
VPC ENI operations where required
```

Use a separate execution role for each function or group of functions with the same justified access needs.

---

# 71. Service role

A service role is assumed by an AWS service to perform actions on your behalf.

Examples:

```text
CodeBuild service role
CloudFormation execution role
ECS task execution role
EventBridge target role
Step Functions execution role
```

Its trust policy names the AWS service principal.

---

# 72. Service-linked role

A service-linked role is predefined and linked to one AWS service.

Examples:

```text
AWSServiceRoleForAutoScaling
AWSServiceRoleForRDS
AWSServiceRoleForElasticLoadBalancing
```

The service controls how it uses the role, and modifying or deleting it can break required service operations. ([AWS Documentation][29])

## Example

When Auto Scaling replaces an EC2 instance, it may use its service-linked role to interact with:

```text
EC2
Elastic Load Balancing
CloudWatch
KMS
```

---

# 73. `iam:PassRole`

`iam:PassRole` allows an identity to pass an IAM role to an AWS service.

Example:

```text
Terraform user creates EC2 instance
and specifies an instance profile role.
```

Terraform caller needs:

```text
ec2:RunInstances
iam:PassRole
```

The role itself must trust:

```text
ec2.amazonaws.com
```

AWS documents `iam:PassRole` as a frequent cause of service configuration failures such as creating EC2, Auto Scaling or other service resources with a role. ([AWS Documentation][30])

---

# 74. Secure `PassRole` policy

Bad:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

This may permit passing an administrator role to a controllable service and escalating privileges.

Better:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::123456789012:role/application/*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

The `iam:PassedToService` condition can restrict which service receives the role. ([AWS Documentation][31])

---

# 75. `PassRole` privilege escalation

Suppose a developer can:

```text
1. Pass AdminRole to Lambda.
2. Create or update Lambda code.
3. Invoke Lambda.
```

The developer can indirectly execute AWS operations with `AdminRole`.

Therefore, review combinations such as:

```text
iam:PassRole
+
lambda:CreateFunction
lambda:UpdateFunctionCode
ec2:RunInstances
ecs:RegisterTaskDefinition
cloudformation:CreateStack
states:CreateStateMachine
glue:CreateJob
```

IAM security requires examining permission combinations, not only individual actions.

---

# 76. KMS key-policy interaction

KMS is a common source of IAM confusion.

An identity policy allowing:

```text
kms:Decrypt
```

may still be insufficient when the KMS key policy does not permit the identity or delegate permission to the account.

Authorization may involve:

```text
IAM identity policy
KMS key policy
KMS grant
SCP
RCP
VPC endpoint policy
Encryption context
```

Always check the key policy separately when encrypted S3, EBS, RDS, Secrets Manager or CloudFront operations fail.

---

# 77. VPC endpoint policies

An interface or gateway endpoint can have an endpoint policy.

Example:

```text
IAM role allows s3:GetObject
Bucket policy allows s3:GetObject
Endpoint policy denies the bucket

Result:
Denied
```

Endpoint policies are another authorization filter and can cause confusing access failures even when IAM policies appear correct.

---

# 78. IAM Access Analyzer

IAM Access Analyzer helps identify and refine access.

Its capabilities include:

```text
External access findings
Internal access findings
Unused access findings
Policy validation
Custom policy checks
Policy generation from CloudTrail activity
```

IAM Access Analyzer can identify unused roles, access keys, passwords, services and actions, and it can analyse resource sharing outside an account or organization. ([AWS Documentation][32])

---

# 79. External access findings

Access Analyzer can identify resources that allow access from outside the trusted boundary.

Examples:

```text
Public S3 bucket
Cross-account KMS key
Externally assumable IAM role
Public SQS queue policy
External Secrets Manager policy
```

You define the trust boundary as:

```text
One AWS account
or
An AWS organization
```

Anything outside that boundary can generate a finding.

---

# 80. Unused access analysis

Unused-access findings can reveal:

```text
Role not used
IAM user access key not used
Console password not used
Service permission not used
Specific action permission not used
```

Use these findings to reduce permissions gradually rather than deleting access blindly.

Unused-access analysis is a chargeable IAM Access Analyzer capability based on the identities analysed. ([AWS Documentation][33])

---

# 81. Policy validation

IAM Access Analyzer validates policies for:

```text
Syntax errors
Security warnings
General warnings
Suggestions
AWS best-practice issues
```

Example CLI:

```bash
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://policy.json
```

Policy validation checks policy grammar and AWS security guidance before deployment. ([AWS Documentation][34])

---

# 82. Generate least-privilege policy

IAM Access Analyzer can analyse CloudTrail activity and generate a policy template based on actions an identity actually used during a selected period. ([AWS Documentation][35])

Workflow:

```text
1. Begin with broader temporary policy.
2. Run the workload.
3. Collect representative CloudTrail activity.
4. Generate policy.
5. Review generated actions.
6. Add missing rare operations.
7. Test.
8. Deploy narrower policy.
```

Do not assume the generated policy includes operations that did not occur during the selected period.

---

# 83. IAM policy simulator

The policy simulator can test whether identity policies and permissions boundaries allow an action.

CLI:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/TerraformRole \
  --action-names \
    ec2:RunInstances \
    iam:PassRole \
  --resource-arns "*"
```

The simulator has limitations, including incomplete cross-account and resource-policy simulation support. ([AWS Documentation][36])

Treat simulation as a useful diagnostic tool, not proof of end-to-end permission in every service context.

---

# 84. Real troubleshooting workflow

When you receive:

```text
AccessDenied
UnauthorizedOperation
not authorized to perform
```

follow this sequence.

## Step 1: Identify the caller

```bash
aws sts get-caller-identity
```

Example:

```json
{
  "UserId": "AROAXXX:vivek",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/TerraformRole/vivek"
}
```

Do not troubleshoot the wrong identity.

---

# 85. Step 2: Identify the exact action

Error:

```text
not authorized to perform:
ec2:DescribeInstanceTypes
```

Required action:

```text
ec2:DescribeInstanceTypes
```

Do not assume:

```text
ec2:DescribeInstances
```

also permits it.

Every API operation normally has its own IAM action.

---

# 86. Step 3: Identify the resource

Error:

```text
not authorized to perform s3:GetObject
on arn:aws:s3:::production-bucket/config/app.json
```

Check whether the policy permits:

```text
arn:aws:s3:::production-bucket/*
```

not only:

```text
arn:aws:s3:::production-bucket
```

---

# 87. Step 4: Check identity policies

For a role:

```bash
aws iam list-attached-role-policies \
  --role-name TerraformRole
```

Inline policies:

```bash
aws iam list-role-policies \
  --role-name TerraformRole
```

Read an inline policy:

```bash
aws iam get-role-policy \
  --role-name TerraformRole \
  --policy-name InlineDeploymentPolicy
```

---

# 88. Step 5: Check trust policy

```bash
aws iam get-role \
  --role-name ProductionDeploymentRole \
  --query 'Role.AssumeRolePolicyDocument'
```

Check:

```text
Correct principal
Correct service
Correct external ID
Correct OIDC subject
Correct audience
Correct MFA condition
Correct source identity
```

A role can have perfect permission policies but still be impossible to assume because its trust policy is wrong.

---

# 89. Step 6: Check restriction layers

Inspect:

```text
Permissions boundary
Session policy
SCP
RCP
VPC endpoint policy
Resource policy
KMS key policy
Organization conditions
```

An error may mention only one denial source even when multiple layers would deny the request. ([AWS Documentation][37])

---

# 90. Step 7: Check `iam:PassRole`

Example error:

```text
User is not authorized to perform:
iam:PassRole
```

Ask:

```text
Which role is being passed?
To which service?
Does the caller's PassRole policy cover that ARN?
Does iam:PassedToService match?
Does the role trust the service?
```

---

# 91. Step 8: Check resource policies

For S3:

```bash
aws s3api get-bucket-policy \
  --bucket production-artifacts
```

For ECR:

```bash
aws ecr get-repository-policy \
  --repository-name todo-backend \
  --region ap-south-1
```

For KMS:

```bash
aws kms get-key-policy \
  --key-id alias/production \
  --policy-name default \
  --region ap-south-1
```

---

# 92. Step 9: Check CloudTrail

Search for the denied event:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=RunInstances \
  --max-results 20
```

Inspect:

```text
userIdentity
eventSource
eventName
errorCode
errorMessage
requestParameters
resources
sourceIPAddress
sessionContext
```

CloudTrail often reveals that the caller, Region, resource or session is different from what you assumed.

---

# 93. Decode authorization messages

Some AWS errors, particularly EC2 authorization failures, include an encoded authorization message.

Decode it:

```bash
aws sts decode-authorization-message \
  --encoded-message "$ENCODED_MESSAGE"
```

The caller requires:

```text
sts:DecodeAuthorizationMessage
```

The decoded result can identify missing permissions and matched policy context. ([AWS Documentation][38])

---

# 94. User’s previous EC2 permission example

Error:

```text
UnauthorizedOperation:
ec2:DescribeInstanceTypes
```

Required policy:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstanceTypes"
  ],
  "Resource": "*"
}
```

Another error:

```text
ec2:DescribeSecurityGroups
```

Add:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeSecurityGroups"
  ],
  "Resource": "*"
}
```

Many EC2 `Describe` operations require:

```json
"Resource": "*"
```

because they do not support narrowing to one resource ARN.

---

# 95. User’s previous ECR example

Error:

```text
AccessDeniedException:
ecr:CreateRepository
```

Required permission:

```json
{
  "Effect": "Allow",
  "Action": "ecr:CreateRepository",
  "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/dev-*"
}
```

Pushing an image also requires actions such as:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

`ecr:GetAuthorizationToken` normally requires:

```json
"Resource": "*"
```

while repository operations can be scoped to repository ARNs.

---

# 96. Common IAM errors

## `AccessDenied`

A policy decision denied the request.

## `InvalidClientTokenId`

Possible causes:

```text
Wrong access key
Expired temporary credentials
Missing session token
Wrong profile
Environment-variable override
```

## `ExpiredToken`

The STS session expired.

## `UnrecognizedClientException`

Credentials are invalid or malformed.

## `MalformedPolicyDocument`

Policy JSON or an ARN is invalid.

## `NoSuchEntity`

Wrong user, role, policy or instance-profile name.

## `AccessDenied` on assume role

Possible causes:

```text
Caller lacks sts:AssumeRole
Role trust policy rejects caller
External ID mismatch
OIDC claim mismatch
MFA missing
SCP denies sts:AssumeRole
```

---

# 97. Credential-provider confusion

AWS tools search for credentials through a provider chain.

Possible sources:

```text
Environment variables
CLI profile
IAM Identity Center profile
Credential process
Web identity token
ECS task credentials
EC2 instance profile
```

Check:

```bash
aws configure list
```

Check profile:

```bash
aws sts get-caller-identity \
  --profile production
```

Unset stale environment credentials:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
```

Environment variables may override a correctly configured profile and cause confusing identity results.

---

# 98. Terraform IAM role example

```hcl
resource "aws_iam_role" "application" {
  name = "production-todo-application"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  permissions_boundary = aws_iam_policy.application_boundary.arn

  tags = {
    Environment = "production"
    Project     = "TodoApp"
    ManagedBy   = "Terraform"
  }
}
```

---

# 99. Terraform permissions policy

```hcl
data "aws_iam_policy_document" "application" {
  statement {
    sid = "ReadApplicationSecret"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.application.arn
    ]
  }

  statement {
    sid = "ReadDeploymentArtifacts"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.artifacts.arn}/production/*"
    ]
  }

  statement {
    sid = "WriteApplicationLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.application.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "application" {
  name   = "production-todo-application"
  policy = data.aws_iam_policy_document.application.json
}

resource "aws_iam_role_policy_attachment" "application" {
  role       = aws_iam_role.application.name
  policy_arn = aws_iam_policy.application.arn
}
```

---

# 100. Terraform instance profile

```hcl
resource "aws_iam_instance_profile" "application" {
  name = "production-todo-application"
  role = aws_iam_role.application.name
}
```

Attach it:

```hcl
resource "aws_launch_template" "application" {
  name_prefix = "production-todo-"

  iam_instance_profile {
    name = aws_iam_instance_profile.application.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}
```

---

# 101. Terraform permissions boundary

```hcl
data "aws_iam_policy_document" "application_boundary" {
  statement {
    sid = "ApprovedApplicationServices"

    actions = [
      "s3:*",
      "logs:*",
      "cloudwatch:*",
      "ecr:*",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyIAMAdministration"
    effect = "Deny"

    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:UpdateAssumeRolePolicy"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "application_boundary" {
  name   = "ApplicationPermissionsBoundary"
  policy = data.aws_iam_policy_document.application_boundary.json
}
```

The boundary still requires careful review because an allowed service may provide an indirect privilege-escalation route.

---

# 102. Terraform cross-account role

Production account:

```hcl
resource "aws_iam_role" "deployment" {
  name = "ProductionDeploymentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::111111111111:role/JenkinsControllerRole"
        }

        Action = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.deployment_external_id
          }
        }
      }
    ]
  })
}
```

Do not put the external ID into a public repository when it is being used as part of a third-party trust design.

---

# 103. Policy-development workflow

Use this sequence:

```text
1. Define the exact job.
2. List required AWS API operations.
3. Identify resource ARNs.
4. Add meaningful conditions.
5. Write policy using Terraform or JSON.
6. Run Access Analyzer validation.
7. Test in nonproduction.
8. Observe CloudTrail.
9. Remove unused permissions.
10. Add boundary or SCP guardrails.
11. Peer review.
12. Deploy through CI/CD.
```

---

# 104. Least-privilege maturity model

## Stage 1: Broad managed policy

```text
AdministratorAccess
AmazonS3FullAccess
AmazonEC2FullAccess
```

Suitable only for controlled initial setup or learning.

## Stage 2: Service-scoped access

```text
Only EC2 and S3
```

## Stage 3: Action-scoped access

```text
Only required EC2 and S3 operations
```

## Stage 4: Resource-scoped access

```text
Only selected instances, buckets and repositories
```

## Stage 5: Condition-scoped access

```text
Only in approved Region
Only with matching tags
Only from approved VPC endpoint
Only through MFA
```

## Stage 6: Continuous least privilege

```text
Access Analyzer
CloudTrail review
Unused-access removal
Automated policy validation
Regular recertification
```

---

# 105. Production IAM checklist

```text
[ ] Root MFA is configured
[ ] Root access keys do not exist
[ ] Root usage is alarmed
[ ] Member-account root access is centralized where appropriate
[ ] Human users access through IAM Identity Center
[ ] IAM users are exceptional and documented
[ ] Workloads use IAM roles
[ ] Long-lived access keys are avoided
[ ] Access keys are rotated when unavoidable
[ ] Every role has a narrow trust policy
[ ] Cross-account trust targets specific roles
[ ] Third-party access uses external IDs
[ ] Source identity is used for audit-sensitive roles
[ ] Sensitive role assumption requires MFA
[ ] Session durations are appropriate
[ ] Role chaining limits are understood
[ ] PassRole permissions are tightly scoped
[ ] iam:PassedToService is used where possible
[ ] Permission boundaries protect delegated role creation
[ ] SCPs protect organization guardrails
[ ] RCPs protect supported resources
[ ] Resource policies use narrow principals
[ ] KMS key policies are reviewed
[ ] Endpoint policies are reviewed
[ ] ABAC tag modification is controlled
[ ] IMDSv2 is required on EC2
[ ] ECS task and execution roles are separated
[ ] CI/CD uses OIDC or role assumption
[ ] Access Analyzer is enabled
[ ] Policies are validated before deployment
[ ] Unused identities and permissions are removed
[ ] CloudTrail is enabled centrally
[ ] Emergency access is documented and tested
```

---

# 106. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
IAM controls authentication and authorization.
Users and roles are identities.
Policies define permissions.
MFA improves account security.
Least privilege limits access.
```

## Solutions Architect Associate

Understand:

```text
IAM users versus roles
Trust policies
Identity versus resource policies
Temporary credentials
STS AssumeRole
Cross-account roles
Permission boundaries
SCPs
PassRole
Instance profiles
IAM Identity Center
```

## DevOps Engineer Professional

Understand:

```text
Multi-account federation
Permission sets
OIDC CI/CD roles
Session tags
ABAC
Source identity
External IDs
Permissions boundaries
SCP and RCP guardrails
Access Analyzer
Policy simulation
CloudTrail troubleshooting
Privilege-escalation paths
IAM policies as code
```

---

# 107. Interview questions

## Question 1: What is the difference between authentication and authorization?

**Answer:**

Authentication determines who the caller is. Authorization determines which actions the authenticated caller may perform on which resources and under which conditions.

## Question 2: What is the difference between an IAM user and role?

**Answer:**

An IAM user can have long-lived credentials and is associated with one identity. A role has no standard long-lived credentials and is assumed temporarily by trusted users, workloads or AWS services.

## Question 3: What is a role trust policy?

**Answer:**

It is the resource-based policy attached to a role that defines which principals may assume the role and under which conditions.

## Question 4: What is the difference between a trust policy and a permissions policy?

**Answer:**

The trust policy defines who may assume the role. Permissions policies define what the role can do after it is assumed.

## Question 5: What happens when one policy allows an action and another explicitly denies it?

**Answer:**

The explicit denial wins.

## Question 6: What is an implicit deny?

**Answer:**

Every operation is denied by default unless an applicable policy grants it.

## Question 7: What is a permissions boundary?

**Answer:**

It is a maximum-permission guardrail for an IAM user or role. It does not grant permission by itself.

## Question 8: What is an SCP?

**Answer:**

An SCP is an AWS Organizations guardrail that limits the maximum permissions available to IAM users and roles in member accounts. It does not grant permissions.

## Question 9: What is an RCP?

**Answer:**

An RCP is an Organizations guardrail that limits access available on supported resources in member accounts. It complements SCPs and does not grant access.

## Question 10: What is a session policy?

**Answer:**

A policy supplied during an STS session that further restricts the permissions of the assumed role or federated session.

## Question 11: What is cross-account role access?

**Answer:**

One account’s principal receives permission to assume a role in another account. The caller policy and the destination role trust policy must both permit the assumption.

## Question 12: What is an external ID?

**Answer:**

A value required during role assumption to prevent a third party from using a customer’s role unintentionally in a confused-deputy scenario.

## Question 13: What is `iam:PassRole`?

**Answer:**

It permits an identity to pass a role to an AWS service so the service can use the role. It must be tightly scoped because it can create privilege-escalation paths.

## Question 14: What is an EC2 instance profile?

**Answer:**

It is the container used to attach an IAM role to an EC2 instance.

## Question 15: What is IAM Identity Center?

**Answer:**

It is AWS’s centralized workforce identity and multi-account access service, supporting users, groups, permission sets and integration with external identity providers.

## Question 16: What is ABAC?

**Answer:**

Attribute-based access control grants access using attributes such as principal, session or resource tags rather than maintaining a separate fixed role for every resource combination.

## Question 17: What is role chaining?

**Answer:**

It occurs when credentials from one assumed role are used to assume another role. The chained session is limited to one hour.

## Question 18: How would you troubleshoot `AccessDenied`?

**Answer:**

Identify the caller and exact action, inspect identity and resource policies, trust policy, boundary, session policy, SCP, RCP, endpoint and KMS policies, then confirm the actual request in CloudTrail.

## Question 19: What does IAM Access Analyzer do?

**Answer:**

It identifies external, internal and unused access, validates policies and can generate policy templates based on CloudTrail activity.

## Question 20: Why should CI/CD use OIDC instead of access keys?

**Answer:**

OIDC allows the CI/CD system to assume a narrowly scoped role using short-lived credentials, removing the need to store long-lived AWS access keys.

---

# 108. Never-forget revision

```text
Root user:
Account owner identity for rare privileged tasks.

IAM user:
Long-lived account identity; use only when necessary.

IAM role:
Assumable identity with temporary credentials.

Trust policy:
Who can assume the role?

Permission policy:
What can the role do?

Identity policy:
Attached to user, group or role.

Resource policy:
Attached to an AWS resource.

Permissions boundary:
Maximum identity permissions.

Session policy:
Reduces permissions for one STS session.

SCP:
Maximum identity permissions across organization accounts.

RCP:
Maximum access allowed on organization resources.

Explicit deny:
Overrides every allow.

Implicit deny:
Default when no allow applies.

STS:
Issues temporary credentials.

External ID:
Protects third-party cross-account role assumption.

Source identity:
Preserves original caller attribution.

PassRole:
Allows a role to be assigned to an AWS service.

Instance profile:
Connects an IAM role to EC2.

RBAC:
Access according to job role.

ABAC:
Access according to attributes and tags.

IAM Identity Center:
Central workforce access for AWS accounts.

Access Analyzer:
Finds and helps reduce risky or unused access.
```

## One-line memory trick

```text
Identity policy says what the actor may do.
Resource policy says who may access the resource.
Boundary, SCP, RCP and session policy limit the result.
Explicit deny always wins.
STS turns trust into temporary credentials.
```

## Lesson 31 outcome

You can now design access where:

```text
Employee signs in
    → IAM Identity Center issues temporary role access.

EC2 needs S3
    → Instance profile supplies temporary credentials.

GitHub deploys production
    → OIDC assumes a narrowly scoped deployment role.

Vendor accesses your account
    → Cross-account role requires an external ID.

Developer creates application roles
    → Permissions boundary prevents privilege escalation.

Member account grants excessive permissions
    → SCP or RCP guardrail blocks the operation.

Terraform gets AccessDenied
    → Caller, action, policy layers and CloudTrail are inspected systematically.
```

**Next lesson: Lesson 32 — AWS KMS, envelope encryption, key policies, grants, encryption context, multi-Region keys, Secrets Manager and Parameter Store security architecture.**

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html?utm_source=chatgpt.com "Security best practices in IAM - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html?utm_source=chatgpt.com "What is IAM? - AWS Identity and Access Management"
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html?utm_source=chatgpt.com "Root user best practices for your AWS account - AWS Identity and Access Management"
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-mfa-for-root.html?utm_source=chatgpt.com "Multi-factor authentication for AWS account root user - AWS Identity and Access Management"
[5]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-enable-root-access.html?utm_source=chatgpt.com "Centralize root access for member accounts - AWS Identity and Access Management"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_identity-management.html?utm_source=chatgpt.com "Compare IAM identities and credentials - AWS Identity and Access Management"
[7]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html?utm_source=chatgpt.com "IAM roles - AWS Identity and Access Management"
[8]: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html?utm_source=chatgpt.com "AssumeRole - AWS Security Token Service"
[9]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html?utm_source=chatgpt.com "Temporary security credentials in IAM - AWS Identity and Access Management"
[10]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_update-role-settings.html?utm_source=chatgpt.com "Update settings for a role - AWS Identity and Access Management"
[11]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html?utm_source=chatgpt.com "AWS JSON policy elements: Principal - AWS Documentation"
[12]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html?utm_source=chatgpt.com "IAM JSON policy element reference - AWS Identity and Access Management"
[13]: https://docs.aws.amazon.com/IAM/latest/UserGuide/intro-structure.html?utm_source=chatgpt.com "How IAM works - AWS Identity and Access Management"
[14]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_resource.html?utm_source=chatgpt.com "IAM JSON policy elements: Resource - AWS Identity and Access Management"
[15]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_notaction.html?utm_source=chatgpt.com "IAM JSON policy elements: NotAction - AWS Identity and Access Management"
[16]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access ..."
[17]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_policy-eval-denyallow.html?utm_source=chatgpt.com "How AWS enforcement code logic evaluates requests to ..."
[18]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html?utm_source=chatgpt.com "Policies and permissions in AWS Identity and Access ..."
[19]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[20]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[21]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic-cross-account.html?utm_source=chatgpt.com "Cross-account policy evaluation logic"
[22]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_third-party.html?utm_source=chatgpt.com "Access to AWS accounts owned by third parties"
[23]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_permissions-to-switch.html?utm_source=chatgpt.com "Grant a user permissions to switch roles - AWS Documentation"
[24]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_session-tags.html?utm_source=chatgpt.com "Pass session tags in AWS STS - AWS Identity and Access Management"
[25]: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_attribute-based-access-control.html?utm_source=chatgpt.com "Define permissions based on attributes with ABAC authorization - AWS Identity and Access Management"
[26]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
[27]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_tags_instance-profiles.html?utm_source=chatgpt.com "Tag instance profiles for Amazon EC2 roles - AWS Identity and Access Management"
[28]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html?utm_source=chatgpt.com "Use an IAM role to grant permissions to applications running on Amazon EC2 instances - AWS Identity and Access Management"
[29]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create-service-linked-role.html?utm_source=chatgpt.com "Create a service-linked role - AWS Identity and Access Management"
[30]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_roles.html?utm_source=chatgpt.com "Troubleshoot IAM roles - AWS Identity and Access Management"
[31]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-reference-policy-checks.html?utm_source=chatgpt.com "IAM policy validation check reference - AWS Identity and Access Management"
[32]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html?utm_source=chatgpt.com "AWS Identity and Access Management Access Analyzer ..."
[33]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-findings-view.html?utm_source=chatgpt.com "Review IAM Access Analyzer findings - AWS Documentation"
[34]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html?utm_source=chatgpt.com "Validate policies with IAM Access Analyzer"
[35]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html?utm_source=chatgpt.com "IAM Access Analyzer policy generation - AWS Documentation"
[36]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html?utm_source=chatgpt.com "IAM policy testing with the IAM policy simulator - AWS Identity and Access Management"
[37]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_access-denied.html?utm_source=chatgpt.com "Troubleshoot access denied error messages - AWS Identity and Access Management"
[38]: https://docs.aws.amazon.com/STS/latest/APIReference/API_DecodeAuthorizationMessage.html?utm_source=chatgpt.com "DecodeAuthorizationMessage - AWS Security Token Service"
