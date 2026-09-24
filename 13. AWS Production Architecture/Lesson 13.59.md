# AWS Masterclass — Phase 3

# Lesson 58: AWS Organizations, Control Tower, SCPs and Multi-Account Landing Zones

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Design a production AWS multi-account environment.
* Distinguish an organization, root, OU and AWS account.
* Protect the AWS Organizations management account.
* Design foundational and workload organizational units.
* Separate security, networking, logging, shared services and applications.
* Understand consolidated billing and account isolation.
* Use service control policies correctly.
* Understand SCP inheritance and permission evaluation.
* Design deny-list and allow-list SCP strategies.
* Use resource control policies to govern resource-based access.
* Use declarative policies to enforce supported service settings.
* Apply tag, backup and AI-services opt-out policies.
* Use delegated administrators and trusted access.
* Centralize workforce access with IAM Identity Center.
* Use CloudFormation StackSets for organization-wide deployment.
* Understand an AWS Control Tower landing zone.
* Distinguish preventive, detective and proactive controls.
* Use Account Factory and Account Factory for Terraform.
* Design an account-vending workflow.
* Detect and resolve Control Tower drift.
* Provision Organizations resources and controls using Terraform.
* Troubleshoot SCP denials, account enrollment and landing-zone failures.

---

# 2. Why one AWS account is not enough

A single account may initially seem simple:

```text
One AWS account
├── Development
├── Testing
├── Production
├── Security tools
├── Networking
├── CI/CD
└── Audit logs
```

However, all these workloads share:

* The same account security boundary.
* Similar administrative blast radius.
* Service quotas.
* Billing scope.
* IAM environment.
* Resource namespace.
* Security findings.
* Audit configuration.

A mistake in development could affect production.

A compromised production administrator could potentially reach security logs.

A misconfigured Terraform destroy could remove unrelated resources.

AWS Organizations is designed to centrally manage multiple accounts, place them into OUs and apply organization policies across those accounts. ([AWS Documentation][1])

---

# 3. AWS account as an isolation boundary

An AWS account provides a strong boundary for:

```text
IAM permissions
Resource ownership
Service quotas
Billing
API activity
Security findings
Network architecture
Encryption-key ownership
Blast radius
```

Recommended mental model:

```text
Do not organize everything only by VPC.

Use AWS accounts for major isolation boundaries.
Use VPCs for networking boundaries inside accounts.
```

Example:

```text
Production account
    !=
Development account
```

Even when both applications use identical Terraform modules.

---

# 4. Multi-account TodoApp architecture

```text
AWS Organization
│
├── Security OU
│   ├── Log Archive account
│   ├── Security Tooling account
│   └── Audit account
│
├── Infrastructure OU
│   ├── Network account
│   ├── Shared Services account
│   └── AFT Management account
│
├── Workloads OU
│   ├── Production OU
│   │   ├── TodoApp Production account
│   │   └── Data Platform Production account
│   │
│   └── NonProduction OU
│       ├── TodoApp Development account
│       ├── TodoApp Staging account
│       └── Experiment account
│
├── Sandbox OU
│   └── Developer Sandbox accounts
│
├── Policy-Staging OU
│   └── SCP test accounts
│
└── Suspended OU
    └── Accounts pending closure
```

This provides independent:

* IAM permissions.
* Network policies.
* Security controls.
* Cost reporting.
* Operational ownership.
* Failure boundaries.

---

# Part 1 — AWS Organizations fundamentals

# 5. What is AWS Organizations?

AWS Organizations is the AWS service for centrally managing multiple AWS accounts.

It provides:

* Organization-wide account management.
* Organizational units.
* Central policy application.
* Consolidated billing.
* Programmatic account creation.
* Delegated service administration.
* Integration with other AWS services.
* Organization-wide resource deployment through services such as CloudFormation StackSets. ([AWS Documentation][1])

---

# 6. Core Organizations hierarchy

```text
Organization
    |
    v
Root
    |
    ├── Organizational Unit
    │       |
    │       ├── Account
    │       └── Nested OU
    |
    └── Account
```

## Organization

The complete collection of AWS accounts.

## Root

The top-level container of the organization.

Do not confuse the Organizations root with an AWS account root user.

## Organizational unit

A logical container for accounts or nested OUs.

## Account

An individual AWS account with its own resources and identities.

Accounts inherit applicable organization policies attached from the root through the account’s OU path. ([AWS Documentation][2])

---

# 7. Management account

The management account is the account that creates and owns the organization.

It can perform high-impact operations such as:

* Create or invite member accounts.
* Create OUs.
* Move accounts.
* Enable policy types.
* Attach organization policies.
* Register delegated administrators.
* Close eligible member accounts.
* Manage consolidated billing.

AWS recommends keeping normal workloads out of the management account because SCPs and several Organizations controls do not restrict principals operating in that account. ([AWS Documentation][3])

---

# 8. What should exist in the management account?

Keep only organization-level resources that must live there.

Examples:

```text
AWS Organizations
Billing administration
Control Tower landing-zone management
Organization-level delegated administration
Break-glass governance roles
Required StackSets administration
```

Avoid:

```text
Public web applications
Application databases
Developer experiments
CI/CD runners
General Lambda workloads
Customer data
Long-running EC2 instances
```

The management account should have very limited human access.

---

# 9. Management-account security

Recommended controls:

```text
[ ] Root user protected
[ ] No root access keys
[ ] Hardware or phishing-resistant MFA
[ ] IAM Identity Center for workforce access
[ ] Very limited administrator group
[ ] No daily workload administration
[ ] CloudTrail organization trail
[ ] Security alerts for management-account activity
[ ] Billing contacts maintained
[ ] Break-glass process tested
[ ] Root email stored in controlled company mailbox
```

Because SCPs do not protect the management account, access to it must be controlled especially carefully. ([AWS Documentation][4])

---

# 10. Member accounts

Every account other than the management account is a member account.

Examples:

```text
Production workload account
Development workload account
Network account
Log Archive account
Security Tooling account
Shared Services account
Sandbox account
```

A member account can be placed in only one immediate parent OU at a time, but it inherits policies from every parent OU above it and from the organization root. ([AWS Documentation][2])

---

# 11. Centralized root-access management

AWS Organizations and IAM support centralized root-access management for member accounts.

You can remove member-account root credentials, including the root password and access keys, which prevents normal root sign-in and root-password recovery in those member accounts. Privileged root tasks can then be performed centrally through controlled organization workflows when supported. ([AWS Documentation][5])

This reduces the need to maintain:

```text
One root password per account
One MFA device per member-account root user
One independent root recovery process per account
```

The organization management account itself still needs carefully protected root credentials.

---

# 12. Account email design

Every AWS account requires a unique primary email address.

Avoid employee-owned addresses:

```text
vivek.personal@example.com
developer1@example.com
```

Prefer controlled organizational addresses:

```text
aws+todo-production@example.com
aws+network@example.com
aws+log-archive@example.com
```

The address should remain accessible after:

* Employees leave.
* Teams reorganize.
* Accounts are transferred.
* Incidents occur.

Organizations can centrally update primary email addresses for member accounts when the required root-access-management integration is enabled. ([AWS Documentation][6])

---

# 13. Account naming standard

Example:

```text
<company>-<environment>-<workload>-<purpose>
```

Examples:

```text
yds-prod-todoapp
yds-nonprod-todoapp
yds-security-log-archive
yds-infra-network
yds-shared-cicd
```

Useful account tags:

```text
Environment
BusinessUnit
Application
CostCenter
Owner
DataClassification
Criticality
ComplianceScope
AccountLifecycle
```

---

# Part 2 — Organizational-unit design

# 14. OUs are policy containers

An OU is not merely a visual folder.

Its primary purpose is to group accounts that require similar:

* SCPs.
* RCPs.
* Declarative policies.
* Backup policies.
* Tag policies.
* Security controls.
* Account lifecycle.
* Operational governance.

AWS generally recommends applying policies at OU level rather than individually attaching many policies to accounts because OU-based management is easier to scale and troubleshoot. ([AWS Documentation][7])

---

# 15. Avoid designing OUs only from the org chart

Bad:

```text
Marketing OU
Sales OU
Engineering OU
Finance OU
```

This may fail when accounts require different technical policies within one department.

Better:

```text
Production OU
NonProduction OU
Security OU
Infrastructure OU
Sandbox OU
Suspended OU
```

You can still represent ownership through account tags and billing metadata.

OUs should primarily reflect governance differences.

---

# 16. Recommended foundational OUs

A practical baseline is:

```text
Root
├── Security
├── Infrastructure
├── Workloads
├── Sandbox
├── Policy-Staging
└── Suspended
```

AWS Organizations best-practice guidance recommends foundational OUs that separate security, infrastructure and workload concerns and encourages policy application through OUs. ([AWS Documentation][7])

---

# 17. Security OU

```text
Security OU
├── Log Archive account
├── Security Tooling account
└── Audit account
```

## Log Archive account

Stores immutable or tightly controlled:

* Organization CloudTrail logs.
* AWS Config data.
* VPC Flow Logs.
* Load-balancer logs.
* Security-service exports.
* Long-term audit evidence.

## Security Tooling account

Hosts:

* GuardDuty delegated administration.
* Security Hub administration.
* Inspector administration.
* Macie administration.
* Detective.
* Security automation.
* SIEM integration.

## Audit account

Provides security and compliance teams with controlled cross-account audit and administrative roles.

AWS Control Tower creates or uses Log Archive and Audit shared accounts in its Security OU. ([AWS Documentation][8])

---

# 18. Infrastructure OU

```text
Infrastructure OU
├── Network account
├── Shared Services account
├── CI/CD account
└── AFT Management account
```

## Network account

May own:

* Transit Gateway.
* Network Firewall.
* Central ingress and egress.
* Route 53 Resolver endpoints.
* Direct Connect.
* Site-to-Site VPN.
* IPAM.
* Shared VPC resources.

## Shared Services account

May contain:

* Directory services.
* Artifact repositories.
* Internal DNS.
* Shared monitoring components.
* Developer tooling.

## CI/CD account

May contain:

* Jenkins controllers.
* CodePipeline.
* Build services.
* Artifact buckets.
* Deployment roles.

Keep deployment roles narrowly scoped to target accounts.

---

# 19. Workloads OU

```text
Workloads OU
├── Production
│   ├── TodoApp Production
│   └── Analytics Production
│
└── NonProduction
    ├── TodoApp Development
    ├── TodoApp Staging
    └── Analytics Development
```

Production and non-production generally need different:

* SCPs.
* Instance restrictions.
* Backup rules.
* Change controls.
* Allowed Regions.
* Security SLAs.
* Cost constraints.
* Internet-access policies.

---

# 20. Sandbox OU

Sandbox accounts are used for learning and experimentation.

Possible controls:

```text
Restrict expensive instance families
Deny organization administration
Deny public snapshots
Deny disabling security tools
Restrict Regions
Apply monthly budgets
Automatically expire accounts
Prevent production connectivity
```

A sandbox is not the same as a development workload account.

Development accounts support a real application lifecycle.

Sandbox accounts support disposable experimentation.

---

# 21. Policy-Staging OU

Never apply an untested restrictive SCP directly to the organization root.

Use:

```text
Policy-Staging OU
├── Governance test account
└── Representative workload test account
```

Process:

```text
1. Create policy.

2. Attach it to Policy-Staging.

3. Test:
   Console
   Terraform
   CI/CD
   Incident roles
   AWS services
   Break-glass access

4. Observe CloudTrail denials.

5. Move a small account group.

6. Expand gradually.
```

AWS explicitly recommends testing SCPs in an OU with a small number of accounts rather than attaching them to the organization root immediately. ([AWS Documentation][9])

---

# 22. Suspended OU

Use for accounts that are:

* Pending closure.
* Quarantined.
* No longer owned.
* Under investigation.
* Awaiting data retention expiry.

Apply restrictive controls such as:

```text
Deny creation of new resources
Deny network changes
Deny IAM changes
Deny leaving the organization
Allow only security and billing operations
```

Do not immediately close an account before:

* Exporting required logs.
* Retaining backups.
* Confirming billing.
* Preserving forensic evidence.
* Removing production dependencies.

---

# Part 3 — Service control policies

# 23. What is an SCP?

A service control policy defines the maximum AWS permissions available to principals in affected member accounts.

An SCP:

```text
Can limit permissions
Cannot directly grant permissions
```

A user still requires an IAM or resource-based policy granting the action.

SCPs act as account-level permission guardrails and can override an account administrator’s `AdministratorAccess` permission when the relevant action is outside the SCP’s permitted boundary. ([AWS Documentation][9])

---

# 24. SCP permission equation

Simplified:

```text
Effective identity permission
=
IAM identity policy
∩
Permissions boundary
∩
Session policy
∩
SCP permission boundary
∩
Applicable resource controls
-
Any explicit deny
```

Example:

```text
IAM role:
Allows ec2:RunInstances

SCP:
Denies ec2:RunInstances

Result:
Denied
```

Another example:

```text
SCP:
Allows s3:GetObject

IAM role:
Does not allow s3:GetObject

Result:
Denied
```

An SCP allow does not grant the permission. ([AWS Documentation][10])

---

# 25. SCP inheritance

```text
Root
  |
  | SCP A
  v
Production OU
  |
  | SCP B
  v
TodoApp account
  |
  | SCP C
  v
IAM role
```

The account is affected by policies attached at:

* Root.
* Every parent OU.
* Immediate OU.
* Account itself.

With an allow-list strategy, the action must remain permitted through every level in the hierarchy. An explicit deny at any applicable level blocks the action. ([AWS Documentation][11])

---

# 26. Default `FullAWSAccess`

When SCPs are enabled, AWS Organizations uses the managed `FullAWSAccess` policy as the default broad allow boundary.

A typical deny-list strategy retains:

```text
FullAWSAccess
+
Specific Deny policies
```

The SCP boundary remains broad except for explicitly denied actions.

Do not detach the only allow policy under an allow-list design without understanding the resulting denial behavior.

---

# 27. Deny-list strategy

```text
Allow all services by default
Deny specifically dangerous actions
```

Example controls:

```text
Deny leaving organization
Deny disabling CloudTrail
Deny disabling GuardDuty
Deny deleting protected backups
Deny public snapshots
Deny unapproved Regions
Deny root-user actions
```

Advantages:

* Easier adoption.
* Lower risk of breaking services.
* New AWS services remain usable unless denied.

Disadvantages:

* Newly released services are allowed automatically.
* Harder to enforce highly restrictive environments.

---

# 28. Allow-list strategy

```text
Allow only approved services
Everything else is implicitly unavailable
```

Example:

```text
Allowed:
EC2
ECS
ECR
S3
RDS
CloudWatch
IAM
KMS

Not listed:
Denied
```

Advantages:

* Strong control.
* New services are unavailable until approved.
* Useful in highly regulated workloads.

Disadvantages:

* Greater operational overhead.
* AWS service dependencies can be missed.
* New integrations may unexpectedly fail.
* Policy documents can become difficult to maintain.

Start with deny-list governance unless strict allow-list requirements justify the complexity.

---

# 29. SCP: deny leaving the organization

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization"
      ],
      "Resource": "*"
    }
  ]
}
```

This prevents administrators in member accounts from independently removing their accounts from the organization.

---

# 30. SCP: protect CloudTrail and Config

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtectAuditServices",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "config:StopConfigurationRecorder",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/SecurityAdministrationRole"
          ]
        }
      }
    }
  ]
}
```

The exception role should be:

* Centrally controlled.
* Rarely assumed.
* MFA protected where human access is possible.
* Logged.
* Tested.

Be careful: exceptions based on role ARN must match actual assumed-role authorization behavior.

---

# 31. SCP: restrict AWS Regions

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
        "budgets:*"
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

Region restrictions require extensive testing because:

* Some AWS services are global.
* Global service endpoints may use a particular requested Region.
* CloudFront ACM certificates require `us-east-1`.
* Security and billing services may need exceptions.
* Service-to-service calls may be affected.

Start with a tested AWS reference policy and update the exception list for services you actually use.

---

# 32. SCP: restrict EC2 instance types

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RestrictLargeInstancesInSandbox",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:instance/*"
      ],
      "Condition": {
        "ForAnyValue:StringNotLike": {
          "ec2:InstanceType": [
            "t3.*",
            "t4g.*"
          ]
        }
      }
    }
  ]
}
```

This is appropriate for a sandbox OU, not necessarily production.

Verify condition-key behavior and all resources involved in `RunInstances` before deployment.

---

# 33. SCP: deny public S3 configuration changes

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtectS3PublicAccessBlock",
      "Effect": "Deny",
      "Action": [
        "s3:DeleteAccountPublicAccessBlock",
        "s3:PutAccountPublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/SecurityAdministrationRole"
          ]
        }
      }
    }
  ]
}
```

For stronger organization-wide S3 resource-access control, combine identity guardrails with RCPs.

---

# 34. SCP root-user restriction

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyMemberAccountRootActions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:root"
          ]
        }
      }
    }
  ]
}
```

Before applying this policy, understand which root-only tasks remain necessary and how centralized root-access management will perform them.

---

# 35. SCP testing approach

For every SCP:

```text
1. Define threat or governance requirement.

2. Identify affected API actions.

3. Identify required exception roles.

4. Check service dependencies.

5. Review service-last-accessed data.

6. Test in Policy-Staging OU.

7. Test console and automation.

8. Test incident-response access.

9. Observe AccessDenied CloudTrail events.

10. Roll out incrementally.
```

AWS recommends using service-last-accessed data and staged testing to refine SCPs safely. ([AWS Documentation][9])

---

# 36. SCP size and composition

An SCP document currently has a maximum size of 5,120 characters. This includes policy characters and relevant whitespace when using APIs, though the console removes insignificant whitespace before calculating size. ([AWS Documentation][12])

Prefer:

```text
Several focused policies
```

over:

```text
One enormous undocumented policy
```

Example policy groups:

```text
Security service protection
Region restriction
Root-user restriction
Network governance
Sandbox cost control
Organization protection
```

---

# 37. SCP troubleshooting

When an operation receives `AccessDenied`:

```text
1. Inspect IAM identity policy.

2. Inspect permissions boundary.

3. Inspect session policy.

4. Inspect resource policy.

5. List SCPs attached to:
   Account
   Parent OU
   Higher OUs
   Root

6. Calculate effective SCP.

7. Check RCPs.

8. Check service control conditions.

9. Check CloudTrail error event.

10. Test from approved exception role.
```

Do not grant broader IAM permissions before verifying SCPs.

`AdministratorAccess` cannot override an SCP deny. ([AWS Documentation][9])

---

# Part 4 — Resource control policies

# 38. What is an RCP?

A resource control policy defines the maximum permissions available to resources in affected member accounts.

Difference:

```text
SCP:
Limits what identities can do

RCP:
Limits who can access resources
through supported resource-based authorization
```

RCPs do not grant access. They set a maximum resource-permission boundary and can block access even when a resource policy would otherwise allow it. ([AWS Documentation][13])

---

# 39. SCP versus RCP

## SCP example

```text
Can this IAM role call s3:GetObject?
```

## RCP example

```text
Can this S3 bucket grant access
to a principal outside my organization?
```

Combined:

```text
Identity authorization
    |
    v
SCP boundary

Resource authorization
    |
    v
RCP boundary
```

The request must survive all applicable authorization layers.

---

# 40. RCP: require TLS for S3

Conceptual example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

AWS documents RCP examples that deny insecure access to supported resources unless the request uses TLS. ([AWS Documentation][14])

---

# 41. RCP: restrict access to organization principals

Conceptual S3 control:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyExternalPrincipals",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalOrgID": "o-example123"
        },
        "BoolIfExists": {
          "aws:PrincipalIsAWSService": "false"
        }
      }
    }
  ]
}
```

This pattern needs exceptions for:

* Approved external partners.
* AWS service principals.
* Public assets.
* Cross-organization integrations.
* Vendor delivery roles.

AWS Control Tower includes RCP-based preventive controls for restricting S3 resources to principals in the organization or approved AWS services. ([AWS Documentation][15])

---

# 42. RCP rollout

When RCPs are enabled, AWS attaches the managed `RCPFullAWSAccess` policy so existing access continues until you introduce restrictions. ([AWS Documentation][14])

Use the same staged approach as SCPs:

```text
RCP test OU
    |
    v
Representative resources
    |
    v
CloudTrail denied-access review
    |
    v
Gradual production rollout
```

AWS strongly recommends testing RCPs before attaching them broadly. ([AWS Documentation][16])

---

# 43. Management account and authorization policies

SCPs and RCPs do not apply to the Organizations management account in the same way they apply to member accounts. AWS’s policy-type reference identifies these authorization policies as not affecting the management account. ([AWS Documentation][17])

This is another reason to avoid workload resources in that account.

---

# Part 5 — Declarative and management policies

# 44. Declarative policies

Declarative policies continuously configure supported AWS service settings through the service control plane.

They differ from SCPs:

```text
SCP:
Controls whether an API request is authorized

Declarative policy:
Enforces the configured service setting itself
```

Current EC2 declarative-policy capabilities include settings such as:

* Instance Metadata Service defaults.
* Allowed AMIs.
* EC2 serial-console access.
* EBS snapshot public-access blocking.
* VPC public-access controls.
* Encryption-in-transit-related settings where supported. ([AWS Documentation][18])

---

# 45. IMDS example

Goal:

```text
All new EC2 instances:
Require IMDSv2
```

Traditional SCP approach:

```text
Deny RunInstances unless metadata option is secure
```

Declarative approach:

```text
Set the organization-wide EC2 metadata default
and maintain the supported setting centrally
```

Declarative policies are enforced through the service control plane rather than only through request authorization. ([AWS Documentation][19])

---

# 46. Allowed AMI policy

A declarative EC2 policy can centrally constrain allowed machine images.

Use cases:

* Only approved hardened AMIs.
* Only company-owned AMIs.
* Deny unapproved Marketplace images.
* Prevent public AMIs in production.

Example lifecycle:

```text
Image Builder
    |
    v
Approved golden AMI
    |
    v
Allowed-images policy
    |
    v
Production account launches
```

This is more durable than relying only on developer convention.

---

# 47. Tag policies

Tag policies help standardize tag keys and accepted values across organization accounts.

Example:

```text
Required naming:
CostCenter
Environment
Application
Owner
```

Allowed values:

```text
Environment:
development
staging
production
```

Tag policies define organization-wide tagging standards and can enforce supported tagging rules when resources are tagged. ([AWS Documentation][20])

They do not replace:

* IAM conditions requiring tags at creation.
* Config rules checking missing tags.
* Cost allocation tag activation.
* Remediation automation.

---

# 48. Backup policies

Backup policies centrally define AWS Backup plans across organization accounts.

Example:

```text
Production OU:
Daily backup
35-day retention
Monthly archive
Cross-account copy
Cross-Region copy

Development OU:
Daily backup
7-day retention
No archive
```

AWS Organizations backup policies allow central backup-plan governance across accounts. ([AWS Documentation][21])

---

# 49. AI-services opt-out policies

AI-services opt-out policies centrally control whether supported AWS AI services can use stored customer content for service improvement.

You can define an organization-wide or service-specific effective policy. ([AWS Documentation][22])

This is a governance decision involving:

* Legal.
* Privacy.
* Security.
* Data owners.
* ML platform teams.

Do not rely on individuals to configure each account separately.

---

# 50. Organization policy categories

AWS Organizations supports multiple policy types, including:

```text
Authorization policies:
SCPs
RCPs

Management/declarative policies:
EC2 declarative policies
Tag policies
Backup policies
AI-services opt-out policies
Service-specific centralized policies
```

The currently supported policy types continue to evolve, so automation should validate availability and Region/service prerequisites before enabling them. ([AWS Documentation][17])

---

# Part 6 — Trusted access and delegated administration

# 51. Trusted access

Trusted access allows an integrated AWS service to perform organization-level operations.

Examples:

* GuardDuty organization management.
* Security Hub central management.
* CloudFormation StackSets.
* IAM root-access management.
* AWS Backup organization policies.
* Account Management.

Enable trusted access through the integrated service’s recommended workflow where possible, rather than blindly enabling integrations only through Organizations. ([Terraform Registry][23])

---

# 52. Delegated administrator

A delegated administrator is a member account authorized to administer an AWS service across the organization.

Examples:

```text
Security Tooling account:
GuardDuty
Security Hub
Inspector
Macie
Detective

Network account:
IPAM
Network Firewall Manager where appropriate

Backup account:
AWS Backup

Deployment account:
CloudFormation StackSets
```

Delegation lets the management account remain focused on organization governance instead of daily service operations. ([AWS Documentation][3])

---

# 53. Delegated administrator does not mean unlimited organization access

A delegated administrator receives service-specific organization permissions.

It does not automatically receive:

```text
Full management-account access
Full billing authority
All Organizations write permissions
Root access
```

Review the precise permissions and trusted-access relationship for each integrated service.

---

# 54. Delegated-administrator mapping

Example:

| AWS service           | Delegated account   |
| --------------------- | ------------------- |
| GuardDuty             | Security Tooling    |
| Security Hub          | Security Tooling    |
| Inspector             | Security Tooling    |
| Macie                 | Security Tooling    |
| Detective             | Security Tooling    |
| AWS Config aggregator | Audit               |
| StackSets             | Platform Deployment |
| AWS Backup            | Backup/Security     |
| IPAM                  | Network             |
| Account Management    | Platform Governance |

Document this mapping as infrastructure architecture.

---

# Part 7 — IAM Identity Center

# 55. Central workforce access

IAM Identity Center provides one place to assign workforce users and groups access to multiple AWS accounts.

```text
Corporate identity provider
        |
        v
IAM Identity Center
        |
        ├── Production account
        ├── Development account
        ├── Security account
        └── Network account
```

Users receive temporary role sessions rather than permanent IAM-user access keys. IAM Identity Center uses permission sets to define access across accounts. ([AWS Documentation][24])

---

# 56. Permission sets

A permission set defines an access profile.

Examples:

```text
Administrator
PowerUser
ReadOnly
SecurityAuditor
BillingViewer
NetworkOperator
DatabaseOperator
ApplicationDeveloper
IncidentResponder
```

One permission set can be provisioned into several accounts, and a user can receive different permission sets depending on the account. ([AWS Documentation][25])

---

# 57. Least-privilege assignments

Bad:

```text
Every DevOps engineer
    → AdministratorAccess
    → Every AWS account
```

Better:

```text
Developer group
    → PowerUser
    → Development accounts

Platform group
    → PlatformOperator
    → Production accounts

Security group
    → SecurityAudit
    → All accounts

Emergency group
    → Administrator
    → Temporary approved assignment
```

---

# 58. Permission-set session duration

Use shorter sessions for:

* Production administration.
* Security accounts.
* Network accounts.
* Management account.
* Break-glass roles.

Longer sessions may be acceptable for read-only development work.

The user should normally select the least-privileged permission set needed for the task, even if they also possess an administrative assignment. AWS IAM Identity Center recommends assigning administrators additional restrictive permission sets for routine use. ([AWS Documentation][25])

---

# 59. External identity provider

Production organizations commonly integrate IAM Identity Center with:

* Microsoft Entra ID.
* Okta.
* Google Workspace.
* Active Directory.
* Another SAML identity provider.

Lifecycle:

```text
Employee joins
    |
    v
Corporate directory group assignment
    |
    v
IAM Identity Center provisioning
    |
    v
AWS account access
```

Employee leaves:

```text
Directory disabled
    |
    v
AWS workforce access removed centrally
```

---

# Part 8 — CloudFormation StackSets

# 60. Why StackSets?

StackSets deploy the same CloudFormation resources into multiple accounts and Regions.

Example:

```text
Organization
    |
    v
StackSet
    |
    ├── CloudWatch baseline in every account
    ├── IAM security role in every account
    ├── VPC Flow Logs configuration
    ├── Config rules
    └── Security notification topics
```

Service-managed StackSets integrate with Organizations and can deploy automatically to accounts in selected OUs. ([AWS Documentation][26])

---

# 61. Self-managed versus service-managed StackSets

## Self-managed

You create and manage administration and execution roles.

Can target accounts where the necessary trust roles exist.

## Service-managed

Uses AWS Organizations trusted access.

AWS manages the required StackSets permissions model, and deployments can follow OU membership. ([AWS Documentation][27])

For a governed organization, service-managed StackSets are normally preferred.

---

# 62. Automatic deployment

Example:

```text
New account moved into Production OU
        |
        v
StackSet automatic deployment
        |
        ├── Security role
        ├── Logging configuration
        ├── Backup role
        └── Monitoring baseline
```

This helps ensure new accounts receive required baseline infrastructure without manual installation.

---

# 63. Delegated StackSets administration

A member account can be registered as a delegated StackSets administrator.

This allows a platform deployment account to manage organization-wide StackSets without daily use of the management account. StackSet operations still use the Organizations service-managed model. ([AWS Documentation][28])

---

# 64. StackSet deployment safety

Use:

```text
Failure tolerance
Maximum concurrency
Region ordering
OU-based targeting
Deployment windows
Change review
Drift detection
Rollback planning
```

Do not deploy an IAM or networking StackSet simultaneously to every production account as the first test.

---

# Part 9 — AWS Control Tower

# 65. What is AWS Control Tower?

AWS Control Tower establishes and governs an AWS multi-account landing zone using services including:

* AWS Organizations.
* IAM Identity Center.
* AWS Config.
* CloudTrail.
* CloudFormation StackSets.
* Service Catalog.
* S3.
* CloudWatch.
* Organization policies.

It provides shared accounts, controls, account provisioning, baselines, governance views and drift management. ([AWS Documentation][29])

---

# 66. Landing zone

A landing zone is the governed multi-account foundation.

```text
AWS Control Tower landing zone
├── Organization structure
├── Shared accounts
├── Identity integration
├── Central logging
├── Governance controls
├── Governed Regions
├── Account Factory
└── Baselines
```

A landing zone is not the application itself.

It is the secure foundation on which application accounts are created.

---

# 67. Control Tower shared accounts

Control Tower sets up or uses:

```text
Management account
Log Archive account
Audit account
```

During landing-zone creation, it creates or uses Security and optional Sandbox structures and establishes the shared security accounts. ([AWS Documentation][8])

---

# 68. Log Archive account

The Log Archive account stores centralized audit and governance logs.

Examples:

```text
Organization CloudTrail data
AWS Config history
Log-access records
Control Tower-managed audit data
```

AWS Control Tower stores centralized logs in S3 resources owned by the Log Archive account. ([AWS Documentation][30])

Protect it with:

* Restricted access.
* S3 Block Public Access.
* KMS.
* Versioning.
* Object Lock where required.
* SCP/RCP controls.
* Long retention.
* Limited deletion authority.

---

# 69. Audit account

The Audit account is intended for security and compliance teams.

It can contain roles and resources for:

* Read-only audit.
* Security administration.
* Config aggregation.
* Security findings.
* Compliance evaluation.
* Custom Config rules.

Control Tower configures audit-related cross-account roles for security and compliance workflows. ([AWS Documentation][31])

---

# 70. Governed Regions

Control Tower landing-zone governance applies across selected governed Regions.

When adding a Region, consider:

```text
Control deployment
AWS Config recording
CloudTrail behavior
Service quotas
Regional security services
Data-residency requirements
Cost
```

A workload launched outside governed Regions may not receive every Control Tower detective capability, which is why an SCP or declarative policy is often used to restrict unapproved Regions.

---

# 71. Control types

AWS Control Tower implements three control behaviors:

```text
Preventive
Detective
Proactive
```

Current implementations include:

```text
Preventive:
SCPs
RCPs
Declarative policies

Detective:
AWS Config rules

Proactive:
CloudFormation hooks
```

([AWS Documentation][32])

---

# 72. Preventive controls

Preventive controls block actions or maintain settings that would violate governance.

Example:

```text
User attempts prohibited API call
        |
        v
Preventive control
        |
        v
Request denied
```

Examples:

* Prevent changes to protected logging resources.
* Deny public snapshot sharing.
* Restrict S3 access outside the organization.
* Maintain approved EC2 settings.

Preventive controls apply through Organizations policy mechanisms. ([AWS Documentation][33])

---

# 73. Detective controls

Detective controls evaluate existing resources.

```text
Resource created
      |
      v
AWS Config evaluates it
      |
      ├── Compliant
      └── Noncompliant
```

Example:

```text
EBS volume attached without encryption
    → Detective control reports noncompliance
```

Detective controls do not necessarily stop creation.

They detect and report the violation. ([AWS Documentation][32])

---

# 74. Proactive controls

Proactive controls evaluate resources before CloudFormation provisions them.

```text
CloudFormation template
        |
        v
CloudFormation hook
        |
        ├── Pass → Provision
        └── Fail → Block
```

They apply to resources provisioned through supported CloudFormation paths and are implemented with CloudFormation hooks managed through Control Tower. ([AWS Documentation][34])

They do not automatically inspect every resource created outside CloudFormation.

---

# 75. Preventive versus proactive versus detective

| Control    | When evaluated                     | Result                                 |
| ---------- | ---------------------------------- | -------------------------------------- |
| Preventive | API action/service setting         | Blocks or maintains setting            |
| Proactive  | Before CloudFormation provisioning | Rejects noncompliant template/resource |
| Detective  | After/current resource state       | Reports compliance failure             |

Use all three:

```text
Proactive:
Stop bad infrastructure templates

Preventive:
Stop forbidden API operations

Detective:
Find drift and unsupported creation paths
```

---

# 76. Mandatory and optional controls

Control Tower classifies controls by guidance and applicability, and their enabled behavior can depend on landing-zone version and configuration.

Do not assume every available control is enabled automatically.

For each OU, explicitly document:

```text
Enabled controls
Disabled controls
Reason
Owner
Exception expiry
```

Control Tower’s current control reference identifies control behavior and guidance separately. ([AWS Documentation][35])

---

# 77. Baselines

A baseline represents a Control Tower resource configuration applied to an OU or shared account.

Examples include configurations for:

* Central security roles.
* AWS Config governance.
* IAM Identity Center.
* Control Tower account enrollment.

Current Control Tower uses enabled-baseline resources to represent applied baseline versions and settings. ([AWS Documentation][36])

---

# 78. Registered OU

An OU registered with Control Tower becomes governed by the applicable Control Tower baseline and can have controls enabled.

When accounts are added to or moved into the OU, their enrollment and baseline status must be monitored.

Do not assume creating an OU directly in Organizations automatically registers it with Control Tower.

---

# 79. Enrolling existing accounts

An existing account can be enrolled into Control Tower.

Common prerequisites include:

* Appropriate `AWSControlTowerExecution` role.
* Compatible AWS Config setup.
* Compatible CloudTrail setup.
* Required account email and metadata.
* No conflicting governed resources.
* Target OU with the appropriate baseline.

Control Tower Account Factory and enrollment workflows depend on the Control Tower execution role and OU baseline. ([AWS Documentation][37])

---

# 80. Control Tower drift

Drift occurs when a Control Tower-managed resource or configuration changes outside the expected state.

Examples:

```text
Shared account moved
Control Tower role deleted
Managed StackSet modified
SCP changed manually
Config recorder changed
Logging bucket policy changed
OU structure changed
```

Control Tower detects several governance-drift categories and provides update, reset or re-registration workflows to resolve them. ([AWS Documentation][38])

---

# 81. Drift response

```text
1. Identify drift category.

2. Determine who changed the resource.

3. Check CloudTrail.

4. Assess security impact.

5. Do not manually patch blindly.

6. Use supported:
   Update landing zone
   Reset landing zone
   Re-register OU
   Update account
   Reset baseline/control

7. Validate account and OU status.
```

---

# 82. Control Tower is not a replacement for Terraform

Control Tower manages the landing-zone governance foundation.

Terraform can manage:

* Workload accounts.
* VPCs.
* ECS/EKS.
* Databases.
* IAM roles.
* Organization policies.
* Control Tower controls.
* Account customizations.
* Security baselines.

Use clear ownership:

```text
Control Tower:
Landing-zone managed resources

Terraform platform repository:
Organization extensions

Application repositories:
Workload resources
```

Do not let multiple tools manage the same resource.

---

# Part 10 — Account Factory

# 83. Account Factory

Account Factory provisions governed AWS accounts through Control Tower.

Users can request an account with inputs such as:

```text
Account name
Primary email
Target OU
IAM Identity Center user
Account configuration
```

Account Factory uses the Control Tower account-provisioning workflow and can manage updates and lifecycle operations for provisioned accounts. ([AWS Documentation][37])

---

# 84. Account-vending workflow

```text
Account request
      |
      v
Validation
      |
      v
Approval
      |
      v
AWS account creation
      |
      v
Move to target OU
      |
      v
Apply Control Tower baseline
      |
      v
Apply organization policies
      |
      v
Deploy account customizations
      |
      v
Assign IAM Identity Center access
      |
      v
Register in CMDB and billing
```

This is sometimes called an account-vending machine.

---

# 85. Account request fields

Recommended:

```text
Account name
Account email
Business owner
Technical owner
Cost center
Environment
Application
Target OU
Data classification
Compliance scope
Required Regions
Network pattern
Backup tier
Internet-access requirement
Expiry date for sandbox
```

Automated validation should reject:

* Duplicate email.
* Invalid target OU.
* Missing cost center.
* Unsupported Region.
* Unapproved public workload.
* Missing owner.

---

# Part 11 — Account Factory for Terraform

# 86. What is AFT?

Account Factory for Terraform sets up a Terraform-based pipeline for provisioning and customizing accounts within a Control Tower landing zone.

AFT supports:

* Terraform Community Edition.
* HCP Terraform.
* Terraform Enterprise.
* Git-based account requests.
* Global customizations.
* OU-level customizations.
* Account-specific customizations. ([AWS Documentation][39])

---

# 87. AFT architecture

```text
Git repository
    |
    | Account request
    v
AFT management account
    |
    v
AFT provisioning workflow
    |
    v
Control Tower Account Factory
    |
    v
New AWS account
    |
    ├── Global customizations
    ├── OU customizations
    └── Account customizations
```

AFT uses a GitOps model: an account-request Terraform file triggers provisioning and subsequent customization workflows. ([AWS Documentation][40])

---

# 88. Dedicated AFT management account

AWS recommends deploying AFT into a dedicated AFT management account rather than the Organizations management account. ([AWS Documentation][41])

Reasons:

* Separate operational permissions.
* Lower management-account risk.
* Independent CI/CD resources.
* Easier pipeline administration.
* Better blast-radius control.

---

# 89. AFT repositories

AFT commonly uses repositories for:

```text
Account requests
Global customizations
Account customizations
Account-provisioning customizations
```

## Global customizations

Applied broadly to AFT-managed accounts.

Examples:

```text
Security notification role
Baseline CloudWatch log group
Standard tags
Monitoring agent
```

## OU customizations

Applied according to account OU.

Examples:

```text
Production backup policy resources
Sandbox budget
Network configuration
```

## Account customizations

Unique to one account or account template.

AFT supports global and targeted account customization workflows. ([AWS Documentation][42])

---

# 90. AFT account request example

Conceptual Terraform:

```hcl
module "todoapp_production" {
  source = "./modules/aft-account-request"

  control_tower_parameters = {
    AccountEmail              = "aws+todoapp-prod@example.com"
    AccountName               = "yds-prod-todoapp"
    ManagedOrganizationalUnit = "Production"
    SSOUserEmail              = "platform@example.com"
    SSOUserFirstName          = "Platform"
    SSOUserLastName           = "Team"
  }

  account_tags = {
    Environment        = "production"
    Application        = "TodoApp"
    CostCenter         = "CC-1004"
    Owner              = "Platform"
    DataClassification = "confidential"
  }

  change_management_parameters = {
    change_requested_by = "platform@example.com"
    change_reason       = "Create TodoApp production account"
  }

  account_customizations_name = "production-workload"
}
```

Exact AFT module inputs should be pinned to the installed AFT release. AFT account requests identify the account, target OU, tags and optional account-customization template. ([AWS Documentation][43])

---

# 91. AFT customization order

Conceptually:

```text
Account provisioning
      |
      v
Account-provisioning framework
      |
      v
Global customizations
      |
      v
OU customizations
      |
      v
Account customizations
```

Use each level for its intended scope.

Do not duplicate the same resource at global, OU and account levels.

---

# 92. AFT observability

AFT emits pipeline and customization information into CloudWatch Logs and uses request/customization identifiers for tracing workflows. ([AWS Documentation][39])

Monitor:

```text
Account request validation failures
Control Tower provisioning failures
Customization pipeline failures
Terraform apply failures
State/backend errors
Account metadata inconsistencies
```

---

# 93. AFT failure handling

Do not submit repeated account requests blindly.

Investigate:

```text
AFT request table
CodePipeline execution
Step Functions execution
CloudWatch Logs
Control Tower account status
Service Catalog provisioned product
Organizations account status
Customization repository commit
```

An AFT request manages provisioning metadata rather than directly representing the AWS account itself in Terraform state. ([AWS Documentation][44])

---

# Part 12 — Central networking

# 94. Network account pattern

```text
Internet
   |
   v
Central ingress
   |
   v
Network account
├── Transit Gateway
├── Network Firewall
├── NAT/egress controls
├── Route 53 Resolver
├── Direct Connect
├── VPN
└── IPAM
   |
   v
Shared with workload accounts
```

Workload accounts retain application VPCs while centralized resources govern connectivity.

---

# 95. Centralized versus distributed VPCs

## Distributed VPC ownership

Each workload account owns its VPC.

Advantages:

* Strong ownership.
* Account isolation.
* Independent deployment.
* Lower central bottleneck.

## Shared VPC model

Network account owns VPC subnets and shares them through AWS RAM.

Advantages:

* Central IP allocation.
* Central routing.
* Consistent network controls.

Tradeoffs:

* Greater coordination.
* Shared-resource dependencies.
* More complex IAM and troubleshooting.

AWS Organizations integrates with AWS RAM for organization-wide resource sharing. ([AWS Documentation][1])

---

# 96. Recommended hybrid model

```text
Network account:
Transit Gateway
Inspection
DNS
Egress
IPAM

Workload account:
Application VPC
Subnets
Security groups
Load balancers
Application endpoints
```

This centralizes enterprise connectivity while preserving workload ownership.

---

# Part 13 — Central logging and security

# 97. Organization CloudTrail

```text
All member accounts
        |
        v
Organization trail
        |
        v
Log Archive account
        |
        v
Protected S3 bucket
```

The organization trail should generally cover:

* All Regions.
* Management events.
* Required data events.
* Log-file validation.
* KMS encryption.
* Central retention.

Control Tower configures centralized logging as part of its landing-zone foundation. ([AWS Documentation][45])

---

# 98. Security administration

```text
Member accounts
      |
      ├── GuardDuty findings
      ├── Inspector findings
      ├── Macie findings
      ├── Config compliance
      └── Access Analyzer
              |
              v
     Security Tooling account
```

Use delegated administrators rather than operating every service from the management account.

---

# Part 14 — Billing and FinOps governance

# 99. Consolidated billing

Organizations provides consolidated billing across member accounts.

Benefits include:

* One payer relationship.
* Account-level cost visibility.
* Aggregated usage in eligible pricing models.
* Central budgets and reporting.
* Cost allocation by account and tag.

However:

```text
Consolidated billing
does not mean
every team can ignore cost ownership.
```

Assign:

* Cost center.
* Business owner.
* Technical owner.
* Budget.
* Forecast.
* Environment.
* Application.

---

# 100. Account as a cost boundary

Example:

```text
TodoApp Production account:
₹X monthly

TodoApp Development account:
₹Y monthly

Security account:
₹Z monthly
```

This is easier to understand than separating every environment only through tags inside one shared account.

Tags remain important for team, service and product-level allocation inside the account.

---

# 101. Sandbox cost controls

Use:

```text
AWS Budgets
Cost Anomaly Detection
Instance-type SCP
Region restrictions
Automatic resource expiry
Scheduled shutdown
Account expiration
Service quotas
```

Do not rely only on an email budget alert after the cost has already accumulated.

---

# Part 15 — Terraform implementation

# 102. Organizations resource

Creating an organization is a one-time high-impact operation.

```hcl
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "RESOURCE_CONTROL_POLICY",
    "TAG_POLICY",
    "BACKUP_POLICY"
  ]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com"
  ]

  lifecycle {
    prevent_destroy = true
  }
}
```

The AWS provider supports organization policy-type configuration, but AWS recommends enabling many service integrations through the integrated service’s own workflow. ([Terraform Registry][23])

---

# 103. Terraform OU structure

```hcl
locals {
  root_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id

  tags = {
    Purpose = "Security and audit accounts"
  }
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "nonproduction" {
  name      = "NonProduction"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "policy_staging" {
  name      = "Policy-Staging"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = local.root_id
}
```

The provider’s OU resource accepts a parent root or OU ID, enabling nested OU structures. ([Terraform Registry][46])

---

# 104. Terraform SCP

```hcl
resource "aws_organizations_policy" "protect_security_services" {
  name = "ProtectSecurityServices"

  description = (
    "Prevents unauthorized disabling of core security services"
  )

  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ProtectSecurityServices"
        Effect = "Deny"

        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromAdministratorAccount",
          "securityhub:DisableSecurityHub",
          "config:StopConfigurationRecorder",
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]

        Resource = "*"

        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/SecurityAdministrationRole"
            ]
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Security governance"
  }
}
```

---

# 105. Attach SCP to an OU

```hcl
resource "aws_organizations_policy_attachment" "production_security" {
  policy_id = aws_organizations_policy.protect_security_services.id

  target_id = (
    aws_organizations_organizational_unit.production.id
  )
}
```

Organizations policies can be attached to roots, OUs or individual accounts through the provider’s policy-attachment resource. ([Terraform Registry][47])

---

# 106. Region restriction policy

```hcl
resource "aws_organizations_policy" "approved_regions" {
  name = "ApprovedRegions"

  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DenyUnapprovedRegions"
        Effect = "Deny"

        NotAction = [
          "account:*",
          "aws-portal:*",
          "billing:*",
          "budgets:*",
          "cloudfront:*",
          "iam:*",
          "organizations:*",
          "route53:*",
          "support:*",
          "waf:*"
        ]

        Resource = "*"

        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "ap-south-1",
              "us-east-1"
            ]
          }
        }
      }
    ]
  })
}
```

Treat this as a starting template—not a production-ready universal exception list.

---

# 107. Terraform RCP

```hcl
resource "aws_organizations_policy" "require_secure_transport" {
  name = "RequireSecureTransport"

  description = "Requires TLS for supported organization resources"

  type = "RESOURCE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "DenyInsecureS3Transport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "*"

        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

RCPs are supported as Organizations policy resources, but supported services and policy effects must be validated before broad deployment. ([AWS Documentation][13])

---

# 108. Terraform Control Tower control

```hcl
resource "aws_controltower_control" "example" {
  control_identifier = var.control_arn

  target_identifier = (
    aws_organizations_organizational_unit.production.arn
  )
}
```

The Control Tower provider resource enables a named control on a target OU and can support configurable parameters for controls that expose them. ([Terraform Registry][48])

Do not hard-code control ARNs without documenting:

* Control name.
* Behavior.
* Guidance.
* Supported Regions.
* Remediation process.

---

# 109. Terraform baseline

Conceptual:

```hcl
resource "aws_controltower_baseline" "production" {
  baseline_identifier = var.aws_control_tower_baseline_arn
  baseline_version    = var.baseline_version

  target_identifier = (
    aws_organizations_organizational_unit.production.arn
  )

  parameters {
    key   = "IdentityCenterEnabledBaselineArn"
    value = var.identity_center_baseline_arn
  }
}
```

The exact parameters depend on the selected baseline. The provider supports an `aws_controltower_baseline` resource for enabled baselines. ([Terraform Registry][49])

---

# 110. Terraform module structure

```text
organization/
├── main.tf
├── providers.tf
├── variables.tf
├── outputs.tf
│
├── modules/
│   ├── organizational-units/
│   ├── service-control-policies/
│   ├── resource-control-policies/
│   ├── tag-policies/
│   ├── delegated-administrators/
│   ├── stacksets/
│   └── control-tower-controls/
│
├── policies/
│   ├── deny-leave-organization.json
│   ├── protect-security-services.json
│   ├── restrict-regions.json
│   └── require-secure-transport.json
│
└── tests/
    ├── policy-validation/
    ├── expected-denials/
    └── exception-role-tests/
```

Use a dedicated state backend with:

* Versioning.
* KMS encryption.
* State locking.
* Very restricted access.
* Separate plan and apply roles.

---

# Part 16 — Safe hands-on lab

# 111. Lab objective

Safely inspect an existing organization and create an unattached SCP.

Do **not** attach it to production during the lab.

Required context:

```text
Execution account:
Organizations management account
or delegated policy administrator

Region:
Organizations is a global service
```

---

# 112. Inspect the organization

```bash
aws organizations describe-organization
```

List roots:

```bash
aws organizations list-roots
```

List OUs under the root:

```bash
ROOT_ID=$(
  aws organizations list-roots \
    --query 'Roots[0].Id' \
    --output text
)

aws organizations list-organizational-units-for-parent \
  --parent-id "$ROOT_ID"
```

---

# 113. List accounts

```bash
aws organizations list-accounts \
  --query 'Accounts[].{
    Name:Name,
    Id:Id,
    Email:Email,
    Status:Status
  }' \
  --output table
```

Do not share full account emails and IDs in public logs.

---

# 114. List SCPs

```bash
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --output table
```

List policies attached to an OU:

```bash
aws organizations list-policies-for-target \
  --target-id "$TARGET_OU_ID" \
  --filter SERVICE_CONTROL_POLICY
```

---

# 115. Create policy document locally

```bash
cat > /tmp/deny-leave-organization.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

Review:

```bash
jq . /tmp/deny-leave-organization.json
```

---

# 116. Create unattached SCP

```bash
POLICY_ID=$(
  aws organizations create-policy \
    --name "LabDenyLeaveOrganization" \
    --description "Lab policy; do not attach to production" \
    --type SERVICE_CONTROL_POLICY \
    --content file:///tmp/deny-leave-organization.json \
    --query 'Policy.PolicySummary.Id' \
    --output text
)

echo "$POLICY_ID"
```

Inspect:

```bash
aws organizations describe-policy \
  --policy-id "$POLICY_ID"
```

---

# 117. Optional test attachment

Only attach when you have:

```text
An empty Policy-Staging OU
or
A disposable test account
```

```bash
aws organizations attach-policy \
  --policy-id "$POLICY_ID" \
  --target-id "$POLICY_STAGING_OU_ID"
```

Verify:

```bash
aws organizations list-policies-for-target \
  --target-id "$POLICY_STAGING_OU_ID" \
  --filter SERVICE_CONTROL_POLICY
```

Never use the organization root for the first test.

---

# 118. Cleanup

Detach first:

```bash
aws organizations detach-policy \
  --policy-id "$POLICY_ID" \
  --target-id "$POLICY_STAGING_OU_ID"
```

Delete policy:

```bash
aws organizations delete-policy \
  --policy-id "$POLICY_ID"
```

Remove local file:

```bash
rm -f /tmp/deny-leave-organization.json
```

---

# Part 17 — Troubleshooting

# 119. `AccessDenied` despite AdministratorAccess

Likely causes:

```text
SCP
RCP
Permissions boundary
Session policy
Resource policy
KMS key policy
VPC endpoint policy
Explicit IAM deny
```

Steps:

```text
1. Find exact denied API in CloudTrail.

2. Check principal ARN.

3. Review IAM policy.

4. Review account/OU/root SCPs.

5. Review RCPs.

6. Review condition values.

7. Test approved exception role.

8. Avoid adding broader IAM policies blindly.
```

---

# 120. New account cannot use an AWS service

Check:

* SCP allow-list.
* SCP explicit deny.
* Target OU.
* Parent OU inheritance.
* Region restriction.
* IAM Identity Center permission set.
* Service-linked role creation.
* Declarative policy.
* Control Tower preventive control.
* Required service trusted access.

A newly created service may not yet appear in an older allow-list SCP.

---

# 121. Account moved to OU and workloads fail

Moving an account immediately changes its inherited organization policies. ([AWS Documentation][2])

Check:

```text
Old OU SCPs
New OU SCPs
Parent OU policies
RCPs
Region controls
Backup policies
Tag policies
Control Tower controls
StackSet automatic deployments
```

Treat account movement as a production change.

---

# 122. Cannot detach SCP

AWS Organizations requires an applicable SCP allowance path, and managed default policies may be necessary to maintain valid SCP configuration.

Check:

* Is the policy the last required SCP?
* Is `FullAWSAccess` attached?
* Does the caller have Organizations policy permissions?
* Is policy management delegated?
* Are you operating in the management account?

---

# 123. Region restriction broke CloudFront or IAM

Global services can require exceptions in Region-restriction SCPs.

Check:

```text
aws:RequestedRegion in CloudTrail
Global service endpoint behavior
ACM us-east-1 requirement
STS endpoint configuration
CloudFront dependencies
Route 53
IAM
Organizations
Support and billing APIs
```

Update the exception list only after proving the service requirement.

---

# 124. Control Tower account enrollment fails

Common causes:

* Missing `AWSControlTowerExecution` role.
* Existing conflicting AWS Config resources.
* Existing CloudTrail configuration.
* Invalid account email.
* Account already enrolled elsewhere.
* Unsupported Region.
* Target OU baseline missing.
* Service Catalog provisioned-product failure.
* SCP blocks required Control Tower actions.
* Account quota or Organizations issue.

Control Tower specifically warns that existing or conflicting AWS Config resources can prevent landing-zone and account enrollment operations. ([AWS Documentation][50])

---

# 125. Control Tower landing-zone update fails

Check:

* Landing-zone drift.
* Shared accounts moved.
* Closed accounts.
* Modified Config resources.
* Modified CloudTrail resources.
* StackSet failures.
* SCP restrictions.
* IAM Identity Center configuration.
* Enabled Regions.
* KMS and S3 policies.

Use the Control Tower update/reset process rather than manually recreating managed resources.

---

# 126. OU shows drift

Possible causes:

* OU moved.
* Account moved manually.
* Baseline version outdated.
* Control manually changed.
* StackSet modified.
* Account not updated.
* Control Tower role removed.

Resolve through:

```text
Re-register OU
Reset enabled baseline
Reset enabled controls
Update accounts
Update landing zone
```

according to the displayed drift type. ([AWS Documentation][38])

---

# 127. AFT account request fails

Check:

```text
Account email uniqueness
Target OU name/ID
OU baseline status
AFT request repository syntax
CodePipeline execution
Step Functions execution
CloudWatch Logs
DynamoDB request item
Control Tower Account Factory status
Service Catalog product
AFT Terraform version
Customization repository
```

AFT account provisioning must target an OU with the applicable Control Tower baseline enabled. ([AWS Documentation][40])

---

# 128. AFT customizations fail after account creation

The account may exist even when customization fails.

Do not submit a second account request using another email.

Instead:

```text
1. Confirm Organizations account ID.

2. Check Control Tower enrollment.

3. Find AFT customization request ID.

4. Inspect Step Functions.

5. Inspect CodeBuild/CodePipeline logs.

6. Correct Terraform customization.

7. Re-run customization.

8. Validate state.
```

---

# 129. StackSet operation failed

Check:

* Trusted access.
* Delegated administrator.
* Target OU/account.
* Target Region.
* Service quotas.
* CloudFormation template.
* SCP deny.
* Execution role.
* Resource already exists.
* Failure tolerance.
* Concurrency.
* Region ordering.

A service-managed StackSet does not deploy into the Organizations management account even if that account appears under a targeted organizational hierarchy. ([AWS Documentation][51])

---

# 130. IAM Identity Center assignment missing

Check:

* Correct IAM Identity Center instance.
* User or group synchronized.
* Permission set provisioned.
* Account assignment exists.
* Target account active.
* Session expired after permission change.
* Identity-provider group mapping.
* Permission-set inline policy.
* SCP denial.

Permission-set changes may need reprovisioning to target accounts before they become effective.

---

# 131. Management account accidentally contains workloads

Migration process:

```text
1. Inventory resources.

2. Identify dependencies.

3. Create target member account.

4. Establish network and identity.

5. Migrate application data.

6. Recreate resources through IaC.

7. Redirect traffic.

8. Validate audit and security controls.

9. Remove old workload resources.

10. Retain only organization governance.
```

Do not try to move AWS resources directly between accounts unless the service explicitly supports it.

---

# Part 18 — Production governance checklist

# 132. Organization checklist

```text
[ ] Organization uses all-features mode
[ ] Management account contains no normal workloads
[ ] Management-account access is highly restricted
[ ] Root access keys do not exist
[ ] Management root has strong MFA
[ ] Member-account root-access management is enabled
[ ] Primary account emails are organization controlled
[ ] Alternate contacts are maintained
[ ] Account naming standard exists
[ ] Account tags identify owner and cost center
```

---

# 133. OU checklist

```text
[ ] OUs reflect governance requirements
[ ] Security OU exists
[ ] Infrastructure OU exists
[ ] Production and non-production are separated
[ ] Sandbox OU exists
[ ] Policy-Staging OU exists
[ ] Suspended OU exists
[ ] Policies are attached mainly at OU level
[ ] Account movement follows change control
[ ] OU ownership is documented
```

---

# 134. Policy checklist

```text
[ ] SCP strategy is documented
[ ] SCPs never serve as permission grants
[ ] Root-level policies were staged first
[ ] Region restriction includes required global services
[ ] Security services are protected
[ ] Leaving the organization is denied
[ ] Member-account root activity is controlled
[ ] RCPs protect resource-based access
[ ] TLS is required for supported resources
[ ] External-principal exceptions are documented
[ ] Declarative policies enforce approved service settings
[ ] Tag policy exists
[ ] Backup policy exists
[ ] AI-services opt-out decision is documented
[ ] Every exception has an owner and expiry
```

---

# 135. Control Tower checklist

```text
[ ] Landing zone is current
[ ] Log Archive account is protected
[ ] Audit account is restricted
[ ] Governed Regions are documented
[ ] OUs are registered
[ ] Baseline versions are monitored
[ ] Preventive controls are documented
[ ] Detective controls have remediation owners
[ ] Proactive controls cover CloudFormation workflows
[ ] Drift notifications are monitored
[ ] Landing-zone updates are tested
[ ] Control Tower resources are not modified manually
```

---

# 136. Account-vending checklist

```text
[ ] Account requests are stored in Git
[ ] Request requires owner and cost center
[ ] Emails are generated consistently
[ ] Target OU is validated
[ ] Security baseline is automatic
[ ] IAM Identity Center assignment is automatic
[ ] Network onboarding is automatic
[ ] Logging and security services are automatic
[ ] Budget is automatic
[ ] Backup tier is automatic
[ ] CMDB/inventory registration is automatic
[ ] Account expiry is set for sandboxes
[ ] Failed requests are reconciled
```

---

# 137. Identity checklist

```text
[ ] IAM Identity Center is the workforce entry point
[ ] Corporate IdP is integrated
[ ] Permission sets are role based
[ ] Administrator assignments are rare
[ ] Users have lower-privilege daily permission sets
[ ] Production sessions are short
[ ] Break-glass access is tested
[ ] No human IAM access keys are used
[ ] Departed users are removed centrally
```

---

# 138. Infrastructure-as-code checklist

```text
[ ] Organizations state is isolated
[ ] Terraform state is encrypted
[ ] Terraform apply role is restricted
[ ] prevent_destroy protects organization resources
[ ] SCP JSON is version controlled
[ ] Policy tests exist
[ ] CloudTrail captures policy changes
[ ] StackSets use delegated administration
[ ] AFT has a dedicated management account
[ ] AFT versions are pinned
[ ] No two tools manage the same resource
```

---

# 139. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Organizations:
Central multi-account management

OU:
Account grouping for policies

Consolidated billing:
Centralized account billing

Control Tower:
Managed landing-zone governance
```

## Solutions Architect Associate

Understand:

```text
Management and member accounts
OU policy inheritance
SCPs do not grant permissions
Log Archive and Audit accounts
IAM Identity Center permission sets
Control Tower controls
Account Factory
CloudFormation StackSets
```

## DevOps Engineer Professional

Understand:

```text
SCP evaluation
Allow-list versus deny-list
RCPs
Declarative policies
Delegated administrators
Trusted access
Control Tower baselines
Drift
AFT GitOps provisioning
Organization-wide StackSets
Central logging and networking
Policy testing and incident access
```

---

# 140. Interview questions

## Question 1: What is AWS Organizations?

**Answer:**

It is a service for centrally managing multiple AWS accounts, organizational units, organization policies, delegated administration and consolidated billing.

## Question 2: What is an organizational unit?

**Answer:**

An OU is a container for AWS accounts or nested OUs that share organization policies and governance requirements.

## Question 3: What is the management account?

**Answer:**

It is the account that creates and owns the organization and performs high-impact organization and billing operations.

## Question 4: Why should workloads not run in the management account?

**Answer:**

The account has organization-wide authority, and SCPs do not restrict it like member accounts. Workloads increase its attack surface and operational risk.

## Question 5: What is an SCP?

**Answer:**

An SCP is an Organizations policy that defines the maximum permissions available to identities in affected member accounts.

## Question 6: Does an SCP grant permissions?

**Answer:**

No. IAM or resource policies must still grant the action. An SCP only limits the maximum available permission.

## Question 7: Can AdministratorAccess override an SCP?

**Answer:**

No. An explicit or inherited SCP restriction still denies the operation.

## Question 8: What is the difference between deny-list and allow-list SCPs?

**Answer:**

A deny-list strategy broadly permits services and blocks selected actions. An allow-list strategy permits only explicitly approved services and implicitly blocks everything else.

## Question 9: What is an RCP?

**Answer:**

A resource control policy sets a maximum permission boundary for supported resources and resource-based access across member accounts.

## Question 10: What is the difference between an SCP and RCP?

**Answer:**

An SCP limits identity permissions. An RCP limits the permissions available through resource-based authorization.

## Question 11: What is a declarative policy?

**Answer:**

It centrally configures and continuously enforces supported AWS service settings rather than merely allowing or denying API actions.

## Question 12: What is delegated administration?

**Answer:**

It allows a member account to centrally administer a specific AWS service across the organization without daily use of the management account.

## Question 13: What is trusted access?

**Answer:**

It permits an integrated AWS service to perform required organization-level operations.

## Question 14: What is AWS Control Tower?

**Answer:**

It is an AWS service that establishes and governs a multi-account landing zone using Organizations, IAM Identity Center, CloudTrail, Config and related services.

## Question 15: What are Control Tower’s control behaviors?

**Answer:**

Preventive, detective and proactive.

## Question 16: How are those controls implemented?

**Answer:**

Preventive controls use SCPs, RCPs or declarative policies; detective controls use Config rules; proactive controls use CloudFormation hooks.

## Question 17: What is Account Factory?

**Answer:**

It is the Control Tower capability for provisioning and managing governed AWS accounts.

## Question 18: What is AFT?

**Answer:**

Account Factory for Terraform creates a Terraform and Git-based pipeline for requesting, provisioning and customizing Control Tower accounts.

## Question 19: What is Control Tower drift?

**Answer:**

It is a change to a Control Tower-managed resource or governance configuration that differs from its expected managed state.

## Question 20: Why use a Policy-Staging OU?

**Answer:**

It allows restrictive organization policies to be tested on disposable or representative accounts before wider rollout.

---

# 141. Never-forget revision

```text
Organization:
Collection of AWS accounts.

Management account:
Owns and governs the organization.

Member account:
Normal workload or shared-service account.

Root:
Top Organizations container.

OU:
Policy and governance container.

SCP:
Maximum identity permission boundary.

RCP:
Maximum resource permission boundary.

Declarative policy:
Continuously enforced service setting.

Tag policy:
Organization-wide tagging standard.

Backup policy:
Organization-wide backup-plan governance.

Delegated administrator:
Member account managing an organization-integrated service.

Trusted access:
Permission for an AWS service to work with Organizations.

Permission set:
IAM Identity Center account-access template.

StackSet:
Deploys CloudFormation across accounts and Regions.

Landing zone:
Governed multi-account foundation.

Preventive control:
Blocks or maintains policy.

Detective control:
Reports noncompliance.

Proactive control:
Checks CloudFormation before provisioning.

Account Factory:
Vends governed AWS accounts.

AFT:
Terraform-based Account Factory pipeline.

Drift:
Control Tower-managed configuration changed unexpectedly.
```

## One-line memory trick

```text
Use accounts for isolation.
Use OUs for governance.
Use SCPs to limit identities.
Use RCPs to limit resources.
Use declarative policies to maintain settings.
Use Control Tower to establish the landing zone.
Use AFT to vend accounts through Git and Terraform.
```

## Lesson 58 outcome

You can now design governance where:

```text
Development must not affect production
    → Separate AWS accounts provide isolation.

Several production accounts need identical guardrails
    → A Production OU inherits organization policies.

An administrator has AdministratorAccess
    → An SCP still blocks prohibited operations.

An S3 bucket policy grants external access
    → An RCP can centrally restrict the resource.

Every new EC2 instance must require secure metadata
    → A declarative policy maintains the default.

Security services need organization-wide management
    → A security account becomes delegated administrator.

Employees need controlled access to many accounts
    → IAM Identity Center uses permission sets.

Every account needs the same baseline resources
    → Service-managed StackSets deploy by OU.

A new application needs an AWS account
    → Account Factory provisions a governed account.

Account provisioning must be Git-driven
    → AFT runs Terraform-based account workflows.

A managed landing-zone resource changes manually
    → Control Tower detects drift and supports reset.
```

**Next lesson: Lesson 59 — AWS Backup, Backup Vault Lock, cross-account and cross-Region backups, restore testing, Elastic Disaster Recovery and production disaster-recovery architecture.**

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html?utm_source=chatgpt.com "What is AWS Organizations? - AWS Organizations"
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/move_account_to_ou.html?utm_source=chatgpt.com "Moving accounts to an organizational unit (OU) or between ..."
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with Organizations - AWS Organizations"
[4]: https://docs.aws.amazon.com/en_en/organizations/latest/userguide/orgs_delegate_policies.html?utm_source=chatgpt.com "Delegated administrator for AWS Organizations - AWS Organizations"
[5]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html?utm_source=chatgpt.com "Accessing member accounts in an organization with AWS ..."
[6]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_update_primary_email.html?utm_source=chatgpt.com "Updating the root user email address for a member ..."
[7]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_ous_best_practices.html?utm_source=chatgpt.com "Best practices for managing organizational units (OUs) with AWS Organizations - AWS Organizations"
[8]: https://docs.aws.amazon.com/controltower/latest/userguide/how-control-tower-works.html?utm_source=chatgpt.com "How AWS Control Tower works"
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_syntax.html?utm_source=chatgpt.com "SCP syntax - AWS Organizations"
[11]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_evaluation.html?utm_source=chatgpt.com "SCP evaluation - AWS Organizations"
[12]: https://docs.aws.amazon.com/organizations/latest/userguide/org_troubleshoot_policies.html?utm_source=chatgpt.com "Troubleshooting service control policies (SCPs) with AWS Organizations - AWS Organizations"
[13]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[14]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_syntax.html?utm_source=chatgpt.com "RCP syntax - AWS Organizations"
[15]: https://docs.aws.amazon.com/controltower/latest/controlreference/rcp-controls.html?utm_source=chatgpt.com "Controls implemented with resource control policies (RCPs) - AWS Control Tower"
[16]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_evaluation.html?utm_source=chatgpt.com "RCP evaluation - AWS Organizations"
[17]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies.html?utm_source=chatgpt.com "Managing organization policies with AWS Organizations - AWS Organizations"
[18]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_declarative_policies.html?utm_source=chatgpt.com "Declarative policies in AWS Organizations - AWS Organizations"
[19]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_management_policies.html?utm_source=chatgpt.com "Declarative policies in AWS Organizations - AWS Organizations"
[20]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html?utm_source=chatgpt.com "Tag policies - AWS Organizations"
[21]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_backup.html?utm_source=chatgpt.com "Backup policies - AWS Organizations"
[22]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_ai-opt-out.html?utm_source=chatgpt.com "AI services opt-out policies - AWS Organizations"
[23]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization?utm_source=chatgpt.com "aws_organizations_organization | Resources | hashicorp/aws | Terraform | Terraform Registry"
[24]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
[25]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html?utm_source=chatgpt.com "Manage AWS accounts with permission sets"
[26]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-activate-trusted-access.html?utm_source=chatgpt.com "Activate trusted access for StackSets with AWS Organizations"
[27]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-prereqs.html?utm_source=chatgpt.com "Prerequisites for using CloudFormation StackSets"
[28]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-delegated-admin.html?utm_source=chatgpt.com "Register a delegated administrator member account"
[29]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS Control Tower"
[30]: https://docs.aws.amazon.com/controltower/latest/userguide/logging-and-monitoring.html?utm_source=chatgpt.com "Logging and monitoring in AWS Control Tower - AWS Control Tower"
[31]: https://docs.aws.amazon.com/controltower/latest/userguide/special-accounts.html?utm_source=chatgpt.com "About the shared accounts - AWS Control Tower"
[32]: https://docs.aws.amazon.com/controltower/latest/userguide/how-controls-work.html?utm_source=chatgpt.com "How controls work - AWS Control Tower"
[33]: https://docs.aws.amazon.com/controltower/latest/controlreference/preventive-controls.html?utm_source=chatgpt.com "Preventive controls - AWS Control Tower"
[34]: https://docs.aws.amazon.com/controltower/latest/controlreference/proactive-controls.html?utm_source=chatgpt.com "Proactive controls - AWS Control Tower"
[35]: https://docs.aws.amazon.com/controltower/latest/controlreference/control-behavior.html?utm_source=chatgpt.com "Control behavior and guidance - AWS Control Tower"
[36]: https://docs.aws.amazon.com/controltower/latest/userguide/types-of-baselines.html?utm_source=chatgpt.com "Types of baselines - AWS Control Tower"
[37]: https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html?utm_source=chatgpt.com "Provision and manage accounts with Account Factory - AWS Control Tower"
[38]: https://docs.aws.amazon.com/controltower/latest/userguide/governance-drift.html?utm_source=chatgpt.com "Types of governance drift - AWS Control Tower"
[39]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html?utm_source=chatgpt.com "Overview of AWS Control Tower Account Factory for Terraform (AFT) - AWS Control Tower"
[40]: https://docs.aws.amazon.com/controltower/latest/userguide/taf-account-provisioning.html?utm_source=chatgpt.com "Provision accounts with AWS Control Tower Account Factory for Terraform (AFT) - AWS Control Tower"
[41]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-getting-started.html?utm_source=chatgpt.com "Deploy AWS Control Tower Account Factory for Terraform (AFT) - AWS Control Tower"
[42]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-account-customization-options.html?utm_source=chatgpt.com "Account customizations - AWS Control Tower"
[43]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-provision-account.html?utm_source=chatgpt.com "Provision a new account with AFT - AWS Control Tower"
[44]: https://docs.aws.amazon.com/controltower/latest/userguide/account-troubleshooting-guide.html?utm_source=chatgpt.com "Account Factory for Terraform (AFT) troubleshooting guide - AWS Control Tower"
[45]: https://docs.aws.amazon.com/controltower/latest/userguide/about-logging.html?utm_source=chatgpt.com "About logging in AWS Control Tower - AWS Control Tower"
[46]: https://registry.terraform.io/providers/hashicorp/aws/6.21.0/docs/resources/organizations_organizational_unit?utm_source=chatgpt.com "aws_organizations_organizational_unit | Resources | hashicorp/aws | Terraform | Terraform Registry"
[47]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment?utm_source=chatgpt.com "aws_organizations_policy_attachment | Resources | hashicorp/aws | Terraform | Terraform Registry"
[48]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/controltower_control?utm_source=chatgpt.com "aws_controltower_control | Resources | hashicorp/aws | Terraform | Terraform Registry"
[49]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/controltower_baseline?utm_source=chatgpt.com "aws_controltower_baseline | Resources | hashicorp/aws | Terraform | Terraform Registry"
[50]: https://docs.aws.amazon.com/controltower/latest/userguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting - AWS Control Tower"
[51]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html?utm_source=chatgpt.com "Create CloudFormation StackSets with service-managed ..."
