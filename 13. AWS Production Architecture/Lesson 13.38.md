# AWS Masterclass — Phase 3

# Lesson 37: AWS Organizations, Control Tower and Enterprise Landing Zones

## 1. Lesson objectives

In this lesson, you will learn how to:

* Build a secure AWS multi-account architecture.
* Understand AWS Organizations, roots, OUs and member accounts.
* Separate security, logging, networking and workloads.
* Protect the AWS Organizations management account.
* Apply Service Control Policies and Resource Control Policies.
* Understand declarative, backup and tag policies.
* Delegate administration to specialist accounts.
* Establish a landing zone with AWS Control Tower.
* Distinguish preventive, detective and proactive controls.
* Provision accounts through Account Factory.
* Automate account vending using Account Factory for Terraform.
* Understand Control Tower baselines and drift.
* Use Landing Zone Accelerator for highly regulated environments.
* Centralize logging, security tooling, networking and backups.
* Onboard existing AWS accounts safely.
* Troubleshoot policy inheritance and account-provisioning failures.
* Implement foundational governance using Terraform and the AWS CLI.

---

# 2. The multi-account mental model

A single AWS account should not normally contain an entire enterprise.

A production organisation may look like this:

```text
AWS Organization
│
├── Management account
│
├── Security OU
│   ├── Log Archive account
│   └── Security Tooling account
│
├── Infrastructure OU
│   ├── Network account
│   ├── Shared Services account
│   └── Backup account
│
├── Workloads OU
│   ├── Production OU
│   │   ├── TodoApp Production account
│   │   └── Payments Production account
│   │
│   └── NonProduction OU
│       ├── TodoApp Development account
│       └── TodoApp Staging account
│
├── Sandbox OU
│   ├── Developer Sandbox 1
│   └── Developer Sandbox 2
│
└── Suspended OU
    └── Accounts awaiting closure
```

AWS Organizations lets you create and group AWS accounts, centrally apply policies, delegate supported service administration and consolidate billing. ([AWS Documentation][1])

---

# 3. Why use multiple AWS accounts?

An AWS account provides a strong isolation boundary for:

* IAM permissions.
* Service quotas.
* Billing.
* Resources.
* Network ownership.
* API activity.
* Security events.
* Blast radius.
* Administrative responsibility.

## Single-account problem

```text
One AWS account
├── Development
├── Staging
├── Production
├── Security tools
├── Network
└── Logs
```

One incorrect administrator action could affect everything.

Examples:

```text
Development engineer deletes production resources.

Compromised role disables security monitoring.

Application team modifies central network routes.

Production account compromise exposes audit logs.
```

## Multi-account containment

```text
Development compromise
        ↓
Development account affected

Production account:
Separate IAM, policies and resources
```

AWS recommends account separation because multi-account architectures improve workload categorization, policy flexibility and scope-of-impact containment compared with putting unrelated workloads in one account. ([AWS Documentation][2])

---

# 4. AWS account versus IAM identity

An AWS account is not the same as an IAM user.

```text
AWS account:
Resource and administrative boundary

IAM user or role:
Identity inside an account

IAM Identity Center user:
Workforce identity that receives account role sessions
```

Example:

```text
Account:
TodoApp Production

Role:
ProductionReadOnly

User:
Vivek authenticates through IAM Identity Center
and assumes ProductionReadOnly
```

Do not create a separate AWS account for every employee.

Create accounts for:

* Workloads.
* Environments.
* Security functions.
* Infrastructure functions.
* Organisational boundaries.

---

# 5. What is AWS Organizations?

AWS Organizations is the foundational account-management and policy-governance service for AWS multi-account environments.

It provides:

```text
Account creation
Account invitations
Organizational units
Policy inheritance
Delegated administration
Trusted service access
Central billing
Organization-wide service integration
```

AWS Organizations has two operating modes:

```text
Consolidated billing features only
All features
```

All-features mode includes consolidated billing plus governance capabilities such as SCPs, RCPs and integrations with supported AWS services. It is the preferred mode for enterprise governance. ([AWS Documentation][3])

---

# 6. Organization structure

The primary structural components are:

```text
Organization
Root
Organizational Unit
Account
```

## Organization

The full collection of AWS accounts.

## Root

The top-level parent container.

```text
Organization
└── Root
```

Do not confuse this with the AWS account root user.

## Organizational Unit

A logical container for accounts or nested OUs.

```text
Root
└── Production OU
    ├── Account A
    └── Account B
```

## Account

An individual AWS account containing workloads or shared services.

---

# 7. Organizational Units

OUs are primarily used to group accounts that require similar policies.

Good grouping criteria include:

```text
Security requirements
Environment
Business function
Data classification
Operational responsibility
Compliance regime
```

Example:

```text
Production OU:
Strong restrictions
No experimental services
Required logging
Restricted Regions

Sandbox OU:
Broader experimentation
Strict budgets
No production data
```

## Important design principle

```text
OU:
Policy grouping

Account:
Workload and access boundary
```

Do not use OUs merely as visual folders.

Every OU should have a clear policy purpose.

---

# 8. Nested OUs

OUs can be nested:

```text
Root
└── Workloads
    ├── Production
    │   ├── Regulated
    │   └── Standard
    │
    └── NonProduction
        ├── Development
        └── Testing
```

Policies attached to parent OUs are inherited by accounts and nested OUs beneath them, according to the behavior of the relevant policy type.

For Control Tower, preventive controls enabled on an OU also affect nested OUs and their accounts, even where nested resources have not been separately registered. Detective and proactive behavior has additional registration and Regional considerations. ([AWS Documentation][4])

---

# 9. Recommended foundational account architecture

A practical enterprise baseline is:

```text
Management account
Security Tooling account
Log Archive account
Network account
Shared Services account
Backup account
Workload accounts
Sandbox accounts
```

Not every small organisation needs every account immediately, but these functions should be intentionally considered.

---

# 10. The management account

The management account is the most privileged account in the organization.

It controls or participates in:

* Organization structure.
* Account creation.
* Organization policies.
* Consolidated billing.
* Trusted service access.
* Delegated administrators.
* Organization-level integrations.

## Critical rule

```text
Do not run normal application workloads
inside the management account.
```

A compromised workload in the management account could expose powerful organization-management permissions.

AWS recommends limiting resources and access in the management account because of its unique authority over accounts, policies, billing and service integrations. ([AWS Documentation][5])

---

# 11. Management-account access

Recommended controls:

```text
[ ] Root user protected with strong MFA
[ ] Root access keys do not exist
[ ] Daily users authenticate through IAM Identity Center
[ ] Administrative roles require MFA
[ ] Organization changes are logged
[ ] No CI/CD workloads run there
[ ] No application databases run there
[ ] No public application endpoints run there
[ ] Break-glass access is documented
```

Create separate delegated administrator accounts for supported services instead of administering everything from the management account.

---

# 12. Log Archive account

The Log Archive account stores centralized copies of logs.

Examples:

```text
Organization CloudTrail logs
AWS Config snapshots
VPC Flow Logs
Load balancer logs
CloudFront logs
WAF logs
Security-service exports
Application audit logs
```

Architecture:

```text
Member accounts
      |
      | Central log delivery
      v
Log Archive account
      |
      v
Protected S3 buckets
      |
      ├── Versioning
      ├── SSE-KMS
      ├── Object Lock
      └── Restricted access
```

Control Tower creates or accepts a dedicated Log Archive shared account during landing-zone setup, and centralized logs from enrolled accounts are stored there. ([AWS Documentation][6])

---

# 13. Why logs need a separate account

If workload administrators control their own audit logs, an attacker may:

```text
Compromise application account
        ↓
Delete resources
        ↓
Delete CloudTrail evidence
```

A separate Log Archive account reduces that risk.

Workload roles should generally not be able to:

```text
Delete centralized logs
Change retention
Disable Object Lock
Change log-bucket policies
Disable organization trails
```

The AWS Security Reference Architecture recommends centralizing security-relevant logs such as CloudTrail, Config, VPC Flow Logs, GuardDuty and WAF logs in a dedicated Log Archive account. ([AWS Documentation][7])

---

# 14. Security Tooling or Audit account

The security account is used to centrally administer and aggregate security services.

Possible services:

```text
Security Hub
GuardDuty
Amazon Inspector
Macie
Detective
IAM Access Analyzer
Firewall Manager
AWS Config aggregation
Security Lake
```

Architecture:

```text
Security Tooling account
        |
        ├── Delegated GuardDuty administrator
        ├── Delegated Security Hub administrator
        ├── Firewall Manager administrator
        ├── Inspector administrator
        └── Organization-wide findings
```

Control Tower creates an Audit shared account intended for security and compliance teams, with cross-account capabilities for auditing governed accounts. ([AWS Documentation][6])

---

# 15. Log Archive versus Security Tooling

These accounts solve different problems.

```text
Log Archive:
Stores evidence.

Security Tooling:
Analyses and responds to evidence.
```

Avoid giving security-analysis tools unrestricted ability to alter historical logs unless required.

A common flow is:

```text
Workload account event
        ↓
Security finding aggregated
        ↓
Security Tooling account

Raw activity log
        ↓
Log Archive account
```

---

# 16. Network account

The Network account centralizes shared networking services.

Possible resources:

```text
Transit Gateway
Cloud WAN
Direct Connect gateways
Site-to-Site VPN
Network Firewall
Route 53 Resolver endpoints
DNS Firewall
Inspection VPC
Centralized egress
Shared VPC resources
```

Architecture:

```text
On-premises
     |
Direct Connect / VPN
     |
Network account
     |
Transit Gateway
     |
├── Production VPCs
├── Development VPCs
└── Shared Services VPC
```

The AWS Security Reference Architecture recommends isolating networking ownership from individual workloads to reduce blast radius and centralize network administration. ([AWS Documentation][8])

---

# 17. Shared Services account

The Shared Services account can contain common organisational services.

Examples:

```text
Microsoft Active Directory
DNS services
Package repositories
CI/CD shared tooling
Artifact repositories
Patch repositories
License servers
Certificate services
Operations tooling
```

Do not place every shared service in one account without considering risk.

For example:

```text
Identity infrastructure:
May deserve a dedicated account.

CI/CD:
May deserve a dedicated deployment account.

Network services:
Usually remain in the Network account.
```

---

# 18. Backup account

A dedicated Backup account can hold:

* Cross-account AWS Backup copies.
* Locked vaults.
* Recovery automation.
* Cross-Region copies.
* Recovery roles.

Architecture:

```text
Production accounts
       |
       | Cross-account backup
       v
Backup account
       |
       ├── Compliance Vault Lock
       ├── Separate KMS keys
       └── Restricted deletion
```

This prevents production administrators from controlling both live data and all recovery copies.

---

# 19. Workload accounts

A workload account should normally have one clear purpose.

Examples:

```text
TodoApp Development
TodoApp Staging
TodoApp Production
Payments Production
Analytics Production
```

Benefits:

* Clear cost ownership.
* Clear IAM access.
* Separate quotas.
* Separate networking.
* Easier incident containment.
* Easier resource discovery.
* Environment-specific policies.

---

# 20. Separate production from nonproduction

Recommended:

```text
TodoApp Development account
TodoApp Staging account
TodoApp Production account
```

Not recommended:

```text
One TodoApp account
├── dev-vpc
├── staging-vpc
└── prod-vpc
```

Separate accounts provide stronger protection than naming conventions or VPC separation alone.

For example, an SCP can deny production account users from disabling security services without affecting development experimentation.

---

# 21. Sandbox accounts

Sandbox accounts allow controlled experimentation.

Typical controls:

```text
Limited budgets
Automatic expiration
No production data
No production connectivity
Restricted Regions
Restricted expensive services
No organization-level administration
```

A sandbox should not become an ungoverned permanent production account.

Implement:

* Account owner.
* Expiration date.
* Monthly budget.
* Allowed-service controls.
* Automated cleanup.
* Data-classification policy.

---

# 22. Suspended or Quarantine OU

Use a dedicated OU for:

```text
Accounts pending investigation
Accounts awaiting closure
Accounts removed from normal operation
Compromised accounts
```

Example:

```text
Suspended OU
    |
    ├── SCP denying almost all actions
    ├── Security investigation access
    └── Billing and logging retained
```

Do not immediately close an account during an active security investigation before preserving evidence.

---

# 23. Consolidated billing

AWS Organizations provides centralized billing across member accounts.

Benefits include:

```text
Single billing relationship
Central cost visibility
Account-level cost separation
Potential aggregation of qualifying usage
Centralised cost-allocation reporting
```

Resources remain owned by their individual member accounts even though billing is consolidated. AWS Organizations itself does not add a separate service charge, although the AWS services and resources deployed in the accounts still incur costs. ([AWS Documentation][9])

---

# 24. Cost allocation

Use account boundaries together with tags.

Example:

```text
Account:
TodoApp Production

Tags:
Application = TodoApp
Environment = Production
Owner = ApplicationEngineering
CostCenter = CC-104
```

Account-level separation answers:

```text
Which major workload incurred the cost?
```

Tags answer:

```text
Which component, team or environment
inside that account incurred it?
```

---

# 25. Trusted access

Some AWS services integrate with Organizations through trusted access.

Trusted access permits the integrated AWS service to perform specific organisation-wide operations.

Examples include organisation-wide administration for:

* CloudTrail.
* Config.
* GuardDuty.
* Security Hub.
* Backup.
* Firewall Manager.
* IAM Access Analyzer.
* Inspector.

Enabling trusted access is a significant governance decision because the service may create roles or interact with member accounts.

Review:

```text
Why is trusted access required?
Which service-linked roles are created?
Which account is delegated administrator?
How is it disabled safely?
```

---

# 26. Delegated administrator

A delegated administrator is a member account authorized to manage an integrated AWS service for the organization.

Example:

```text
Management account:
Registers Security Tooling account
as GuardDuty delegated administrator.

Security Tooling account:
Enables GuardDuty across member accounts.
```

Benefits:

* Reduces daily use of the management account.
* Assigns ownership to specialist teams.
* Centralizes findings.
* Supports separation of duties.

AWS Organizations lets the management account register member accounts as delegated administrators for supported integrated services. ([AWS Documentation][10])

---

# 27. Service Control Policies

An SCP is an organization policy that limits the maximum permissions available to IAM users and roles in member accounts.

```text
SCP:
Permission ceiling
```

An SCP does not grant permissions.

Example:

```text
IAM role policy:
Allow ec2:TerminateInstances

SCP:
Deny ec2:TerminateInstances

Result:
Denied
```

SCPs require Organizations all-features mode. They do not affect the management account, and they do not grant access by themselves. ([AWS Documentation][11])

---

# 28. SCP evaluation

Think of effective access as:

```text
IAM Allow
∩
Permissions boundary
∩
Session policy
∩
SCP permission ceiling
=
Potentially allowed
```

Then consider:

```text
Explicit Deny anywhere
=
Denied
```

## Example

```text
Identity policy:
AdministratorAccess

SCP:
Deny organizations:LeaveOrganization

Result:
Administrator cannot leave the organization.
```

---

# 29. SCP inheritance

```text
Root policy
    ∩
Parent OU policy
    ∩
Child OU policy
    ∩
Account policy
```

For allow-list SCP models, a permission must remain permitted throughout the path.

For explicit-deny models, a denial at any inherited level applies.

Example:

```text
Root:
Allow *

Production OU:
Deny disabling CloudTrail

Account:
Allow CloudTrail administration

Result:
Stopping CloudTrail remains denied.
```

---

# 30. Deny-list SCP strategy

Most organisations begin with:

```text
FullAWSAccess attached
+
Explicit Deny guardrails
```

Examples:

```text
Deny leaving the organization
Deny disabling security services
Deny unapproved Regions
Deny closing accounts
Deny public-access changes
```

Advantages:

* Easier adoption.
* Fewer service interruptions.
* New AWS services are usable unless explicitly denied.

Risk:

* Any action not explicitly denied may be delegated by account IAM administrators.

---

# 31. Allow-list SCP strategy

An allow-list model detaches broad `FullAWSAccess` at a selected hierarchy and explicitly permits approved services or actions.

```text
Allow:
EC2
S3
RDS
CloudWatch

Everything else:
Implicitly unavailable
```

Advantages:

* Strong control.
* Useful for highly regulated environments.
* Reduces service surface.

Disadvantages:

* Significant operational burden.
* New AWS capabilities must be deliberately permitted.
* Service dependencies can be difficult to identify.
* Incorrect configuration can cause outages.

AWS SCP documentation notes that allow-list policies are effective only after broad inherited allow policies such as `FullAWSAccess` are removed from the relevant path. ([AWS Documentation][12])

---

# 32. SCP: prevent leaving or closing accounts

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtectOrganizationMembership",
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization",
        "account:CloseAccount"
      ],
      "Resource": "*"
    }
  ]
}
```

AWS specifically recommends organization-level controls to prevent unauthorized member-account departure and closure. ([AWS Documentation][5])

---

# 33. SCP: protect CloudTrail

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

## Warning

Role exemptions must be tightly controlled.

Someone who can assume the exempt role can bypass the guardrail.

---

# 34. SCP: restrict Regions

Example:

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

The global-service exception list must be tested carefully.

For your architecture:

```text
ap-south-1:
Primary deployment Region

us-east-1:
CloudFront ACM, global-service control-plane needs
```

Do not copy a generic Region-deny policy into production without validating every required global service.

---

# 35. SCP limitations

SCPs:

* Do not grant permissions.
* Do not affect the management account.
* Do not automatically protect resources from external principals.
* Do not replace resource policies.
* Do not replace IAM least privilege.
* Do not apply to service-linked roles in the same way as ordinary IAM identities.
* Can cause broad outages if tested poorly.

Use staged deployment:

```text
1. Test in policy-sandbox account.
2. Apply to small test OU.
3. Monitor failures.
4. Expand to nonproduction.
5. Apply to production.
```

---

# 36. Resource Control Policies

RCPs centrally restrict the maximum permissions available on supported resources in member accounts.

```text
SCP:
Controls what organisation principals may do.

RCP:
Controls how organisation resources may be accessed.
```

RCPs are especially useful for data-perimeter controls that restrict access from principals outside your organization.

RCPs do not grant access; they restrict access that identity and resource policies might otherwise allow. ([AWS Documentation][13])

---

# 37. SCP versus RCP example

Suppose an S3 bucket policy accidentally allows an external account.

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject"
}
```

An SCP focuses on principals inside your organisation.

An RCP can centrally restrict access to supported resources so external principals are denied unless they match an approved exception.

## Memory trick

```text
SCP protects from the actor side.

RCP protects from the resource side.
```

---

# 38. RCP conceptual example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyExternalOrganizationAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEqualsIfExists": {
          "aws:PrincipalOrgID": "o-exampleorgid"
        }
      }
    }
  ]
}
```

Real data-perimeter policies require exceptions for:

* AWS service principals.
* Approved external partners.
* Public resources.
* Logging delivery.
* Backup services.
* Support workflows.

Use AWS-provided control examples and test extensively before enforcement.

---

# 39. Other Organizations policy types

AWS Organizations supports policy types beyond SCPs and RCPs.

Examples include:

```text
Tag policies
Backup policies
AI services opt-out policies
Chat applications policies
Security Hub policies
Upgrade rollout policies
Declarative policies
```

Authorization policies such as SCPs and RCPs limit permissions. Other policies standardize configuration or centrally manage service behavior. ([AWS Documentation][14])

---

# 40. Tag policies

Tag policies help standardize tag keys and accepted values.

Example standard:

```text
Environment:
Development
Staging
Production

Owner:
Approved team name

CostCenter:
CC- followed by number
```

Conceptual policy:

```json
{
  "tags": {
    "Environment": {
      "tag_key": {
        "@@assign": "Environment"
      },
      "tag_value": {
        "@@assign": [
          "Development",
          "Staging",
          "Production"
        ]
      }
    }
  }
}
```

Tag policies help identify noncompliant tagging, but they do not automatically make every service creation fail unless enforcement is supported and configured for the relevant resource types. ([AWS Documentation][15])

---

# 41. Backup policies

Organization backup policies allow centralized AWS Backup rules across accounts and OUs.

Example:

```text
Production OU:
Daily backup
35-day retention
Cross-account copy
Cross-Region copy

Development OU:
Daily backup
7-day retention
```

A backup policy is configuration governance.

It does not replace:

* Backup vault policies.
* KMS access.
* Restore testing.
* Vault Lock.
* Resource-specific backup support.

---

# 42. Declarative policies

Declarative policies enforce selected AWS service settings directly through the relevant service control plane.

This differs from SCPs:

```text
SCP:
Denies or permits API authorization.

Declarative policy:
Declares the required service configuration.
```

Current EC2 declarative policy areas include settings such as:

```text
Allowed AMIs
Instance Metadata defaults
```

Declarative policies can be attached at the root, OU or account level and inherited by accounts in scope. ([AWS Documentation][16])

---

# 43. Declarative policy example: IMDS defaults

A declarative EC2 policy can establish organisation-wide defaults for newly launched instances.

Security objective:

```text
Require IMDSv2 by default
for new EC2 launches.
```

This is often more reliable than hoping every Terraform module independently sets:

```hcl
metadata_options {
  http_tokens = "required"
}
```

Use both:

```text
Declarative organizational default
+
Infrastructure-as-Code configuration
```

to create defense in depth.

---

# 44. What is AWS Control Tower?

AWS Control Tower is an AWS-managed service for establishing and governing a multi-account landing zone.

It orchestrates services such as:

```text
AWS Organizations
IAM Identity Center
CloudTrail
AWS Config
Service Catalog
CloudFormation
```

It provides:

* Landing-zone setup.
* Shared accounts.
* Baselines.
* Controls.
* Account Factory.
* Account enrollment.
* Governance visibility.
* Drift detection.

AWS Control Tower builds on AWS Organizations and automates application of governance controls to provisioned and enrolled accounts. ([AWS Documentation][17])

---

# 45. What is a landing zone?

A landing zone is the governed multi-account foundation where workloads are deployed.

It includes:

```text
Organization structure
Shared accounts
Identity
Logging
Security controls
Regions
Account provisioning
Baseline configurations
```

A landing zone is not one VPC.

It is the organisational and technical foundation for the AWS environment.

---

# 46. Control Tower landing-zone architecture

```text
AWS Control Tower management account
│
├── Security OU
│   ├── Log Archive account
│   └── Audit account
│
├── Sandbox OU
│   └── Sandbox accounts
│
└── Additional registered OUs
    ├── Infrastructure
    ├── Production
    └── NonProduction
```

During setup, Control Tower can create the Security and optional Sandbox OUs and create or enroll the Log Archive and Audit shared accounts. ([AWS Documentation][18])

---

# 47. Control Tower shared accounts

## Log Archive account

Stores centralized logs.

## Audit account

Supports security and compliance operations.

These accounts require unique email addresses during setup.

Examples:

```text
aws-log-archive@example.com
aws-security@example.com
```

Use organisational mailboxes rather than one employee’s personal address.

Control Tower checks shared accounts for conflicting resources before accepting them during landing-zone configuration. ([AWS Documentation][19])

---

# 48. Control Tower controls

Control Tower controls, historically called guardrails, are high-level governance rules.

Three behavior types are:

```text
Preventive
Detective
Proactive
```

Guidance categories include:

```text
Mandatory
Strongly recommended
Elective
```

([AWS Documentation][17])

---

# 49. Preventive controls

Preventive controls stop disallowed actions.

Implementation mechanisms include:

```text
SCPs
RCPs
```

Example:

```text
User attempts to disable CloudTrail
        ↓
Preventive control denies API request
```

Preventive controls can apply globally through inherited organization policies. ([AWS Documentation][20])

---

# 50. Detective controls

Detective controls identify noncompliant resources after they exist.

Implementation:

```text
AWS Config rules
```

Example:

```text
User creates unencrypted EBS volume
        ↓
Resource exists
        ↓
AWS Config evaluates it
        ↓
Marked noncompliant
        ↓
Alert or remediation runs
```

Detective does not necessarily mean prevention.

---

# 51. Proactive controls

Proactive controls evaluate CloudFormation resources before provisioning.

Implementation:

```text
CloudFormation hooks
```

Example:

```text
CloudFormation proposes public S3 bucket
        ↓
Proactive control evaluates template
        ↓
Provisioning fails before resource creation
```

Control Tower implements preventive controls using organization policies, detective controls using Config rules and proactive controls using CloudFormation hooks. ([AWS Documentation][20])

---

# 52. Defense-in-depth controls

For encrypted storage:

```text
Preventive:
Deny disabling mandatory encryption controls.

Proactive:
Reject noncompliant CloudFormation resource.

Detective:
Find manually created unencrypted resource.

Remediation:
Encrypt, replace or quarantine resource.
```

No single control catches every creation path or operational error.

---

# 53. Mandatory, strongly recommended and elective

## Mandatory

Automatically applied as part of Control Tower governance and required for landing-zone operation.

## Strongly recommended

AWS recommends enabling them for common enterprise governance scenarios.

## Elective

Useful for selected requirements but not universally appropriate.

Do not enable every control blindly.

Consider:

* Region support.
* Workload compatibility.
* Cost.
* Existing security tooling.
* Exception processes.
* Operational ownership.

---

# 54. Control Tower baselines

A baseline is a defined collection of resources and configurations deployed to a target such as an OU or shared account.

When enabled, Control Tower represents it as an `EnabledBaseline` resource.

Examples include:

```text
AWSControlTowerBaseline
IdentityCenterBaseline
Shared-account baselines
```

Baselines are versioned and may need updates as the landing zone evolves. ([AWS Documentation][21])

---

# 55. Governed and ungoverned OUs

An OU created only in Organizations is not automatically governed by Control Tower.

To bring it under governance:

```text
Register the OU
```

Registration enrolls eligible accounts and applies the relevant Control Tower baselines and controls.

Control Tower can register existing OUs containing up to the documented account limit, and the accounts within the OU are enrolled during registration. ([AWS Documentation][22])

---

# 56. Enrolling existing accounts

Existing accounts can be enrolled into a governed OU.

During enrollment, Control Tower deploys required baseline resources.

Important considerations:

* Account must belong to the same organization.
* Conflicting Config or CloudTrail resources can require remediation.
* The required Control Tower execution role may be necessary.
* Existing VPCs are not automatically replaced.
* Existing workloads must be tested against new controls.

Control Tower does not create a new VPC when an existing account is enrolled. ([AWS Documentation][23])

---

# 57. Account Factory

Account Factory is Control Tower’s account-vending capability.

It allows authorised users to provision standardized new AWS accounts.

Inputs can include:

```text
Account name
Account email
OU
IAM Identity Center user information
Network configuration
Account customization
```

Control Tower Account Factory applies the landing-zone baselines and controls while provisioning the member account. ([AWS Documentation][24])

---

# 58. Account-vending workflow

```text
Account request submitted
        ↓
AWS Organizations creates member account
        ↓
Account placed into selected OU
        ↓
Control Tower baseline applied
        ↓
Mandatory controls applied
        ↓
Identity access configured
        ↓
Customizations deployed
        ↓
Account delivered to owner
```

A new account should not be handed to an application team before baseline completion.

---

# 59. Account request fields

A production account request should include:

```text
Account name
Unique account email
Business owner
Technical owner
Environment
Application
Cost center
Requested OU
Data classification
Primary Region
Network connectivity
Backup tier
Security tier
Expiration date if temporary
```

Example:

```text
Account:
TodoApp Production

OU:
Workloads/Production

Owner:
Application Engineering

Cost center:
CC-104

Primary Region:
ap-south-1

Backup:
Gold

Classification:
Confidential
```

---

# 60. Account Factory for Terraform

Account Factory for Terraform, or AFT, adds a Terraform- and Git-based account-provisioning workflow to Control Tower.

AFT uses a dedicated management account and creates automation pipelines for provisioning and customizing accounts. ([AWS Documentation][25])

Architecture:

```text
Git account-request repository
        |
        | git push
        v
AFT pipeline
        |
        v
Control Tower Account Factory
        |
        v
New AWS account
        |
        ├── Global customizations
        ├── OU customizations
        └── Account-specific customizations
```

---

# 61. AFT GitOps workflow

AFT follows a GitOps-style process:

```text
1. Engineer creates account-request Terraform file.
2. Pull request is reviewed.
3. Change is merged.
4. Pipeline processes request.
5. Account is provisioned.
6. Global customizations run.
7. Targeted customizations run.
8. Account pipeline reports status.
```

AFT account provisioning starts from an account-request Terraform file committed to the account-request repository. ([AWS Documentation][26])

---

# 62. Example AFT account request

Illustrative structure:

```hcl
module "todoapp_production" {
  source = "./modules/aft-account-request"

  control_tower_parameters = {
    AccountEmail              = "aws-todoapp-prod@example.com"
    AccountName               = "TodoApp Production"
    ManagedOrganizationalUnit = "Production"
    SSOUserEmail              = "cloud-admin@example.com"
    SSOUserFirstName          = "Cloud"
    SSOUserLastName           = "Admin"
  }

  account_tags = {
    Application = "TodoApp"
    Environment = "Production"
    CostCenter  = "CC-104"
    Owner       = "ApplicationEngineering"
  }

  change_management_parameters = {
    change_requested_by = "DevOps Platform Team"
    change_reason       = "Create production workload account"
  }

  account_customizations_name = "production-workload"
}
```

Exact module inputs depend on the deployed AFT version and repository structure.

---

# 63. AFT customizations

AFT supports:

```text
Global customizations
Account provisioning customizations
Account-specific customizations
```

Customizations can run:

* Terraform.
* Python.
* Bash.
* AWS CLI operations.

Examples:

```text
Create IAM roles
Configure budgets
Deploy Config rules
Create VPCs
Configure backup selections
Register security services
Create Route 53 resolvers
Deploy KMS keys
```

AFT creates per-account customization pipelines and supports scripts and Terraform-based customizations. ([AWS Documentation][27])

---

# 64. Account Factory Customization

Account Factory Customization, or AFC, allows Control Tower account provisioning or enrollment to include CloudFormation-based customization blueprints.

Use AFC when:

* CloudFormation is preferred.
* Account-specific blueprints are required.
* Account provisioning should deploy additional AWS resources.

AFC differs from AFT:

```text
AFT:
Terraform-based GitOps account vending.

AFC:
Control Tower account provisioning with
CloudFormation blueprint customization.
```

---

# 65. Customizations for Control Tower

Customizations for AWS Control Tower, historically CfCT, can deploy CloudFormation resources and SCP customizations across governed OUs and accounts.

It is intended mainly for customizing an existing landing zone rather than being the primary account-creation mechanism. ([AWS Documentation][28])

---

# 66. Control Tower drift

Drift occurs when required Control Tower-managed resources or configurations are changed outside the expected management workflow.

Examples:

```text
Required IAM role deleted
SCP modified manually
StackSet instance removed
Account moved outside expected OU
Baseline resource altered
Service Catalog resource changed
```

Drift can prevent operations such as account enrollment.

Control Tower detects several categories of landing-zone, OU, account and control drift and provides reset, update or re-registration processes for supported cases. ([AWS Documentation][29])

---

# 67. Avoid manually modifying Control Tower resources

Resources with names such as:

```text
AWSControlTower*
aws-controltower-*
aws-guardrails-*
```

may be managed by Control Tower.

Before modifying one:

```text
1. Identify its owning service.
2. Check Control Tower documentation.
3. Use supported update mechanisms.
4. Avoid direct deletion.
```

Manual changes may create drift and prevent future landing-zone updates.

---

# 68. Landing-zone updates

Control Tower releases new landing-zone and baseline versions.

Updates can affect:

* Shared-account resources.
* Regions.
* controls.
* Account Factory.
* CloudTrail.
* Config.
* IAM roles.

Landing-zone and account update status should be reviewed regularly; accounts may show that an update is available after landing-zone changes. ([AWS Documentation][30])

Do not postpone updates indefinitely without:

* Security review.
* Compatibility review.
* Test environment.
* Change plan.

---

# 69. Region governance

Control Tower lets you define governed Regions.

Important behavior:

```text
Preventive controls:
Generally operate globally through policy enforcement.

Detective and proactive controls:
Depend on Control Tower and underlying-service
support in governed Regions.
```

([AWS Documentation][31])

For your environment:

```text
Primary workload Region:
ap-south-1

Required global-service Region:
us-east-1

Other Regions:
Restricted unless explicitly approved
```

---

# 70. Landing Zone Accelerator on AWS

Landing Zone Accelerator, or LZA, is an AWS solution that deploys a highly configurable multi-account cloud foundation.

It is designed particularly for organisations with:

* Highly regulated workloads.
* Complex compliance requirements.
* Advanced network topologies.
* Detailed configuration-as-code requirements.
* AWS GovCloud requirements.
* Existing enterprise landing zones.

LZA is a fully automated implementation aligned with AWS Security Reference Architecture guidance. ([AWS Documentation][32])

---

# 71. LZA and Control Tower

LZA can operate with:

```text
AWS Control Tower
or
AWS Organizations
```

AWS recommends using Control Tower where supported because it automatically establishes governance and security configurations, while LZA adds broader customization and automation. ([AWS Documentation][33])

## Common pattern

```text
AWS Organizations
        ↓
AWS Control Tower
        ↓
Landing Zone Accelerator
        ↓
Highly customized enterprise foundation
```

---

# 72. What LZA deploys

Depending on configuration, LZA can automate:

```text
OU and account structure
Identity and access
Centralized networking
Transit Gateway
Direct Connect integration
Network Firewall
Route 53 Resolver
Centralized logging
Security services
AWS Config
Backup
KMS keys
S3 buckets
SCPs
Tagging
Budgets
Service Catalog portfolios
```

LZA uses CloudFormation and a deployment pipeline to manage configuration-driven infrastructure across accounts and Regions. ([AWS Documentation][34])

---

# 73. LZA configuration-as-code

A typical LZA configuration repository contains files conceptually representing:

```text
accounts-config
organization-config
global-config
iam-config
network-config
security-config
customizations-config
```

Changes follow:

```text
Configuration updated
        ↓
Version control review
        ↓
Accelerator pipeline
        ↓
Validation
        ↓
CloudFormation deployment
        ↓
Accounts and Regions updated
```

Do not make uncontrolled manual changes to LZA-managed resources.

---

# 74. Control Tower versus LZA

| Requirement                      | Control Tower    | Landing Zone Accelerator                 |
| -------------------------------- | ---------------- | ---------------------------------------- |
| Rapid standard landing zone      | Strong fit       | More complex                             |
| Managed controls                 | Yes              | Uses CT/Organizations plus configuration |
| Account Factory                  | Yes              | Integrates with account structure        |
| Highly customized network        | Limited alone    | Strong fit                               |
| Regulated reference architecture | Baseline         | Strong fit                               |
| Configuration-as-code depth      | Moderate         | Extensive                                |
| GovCloud-oriented deployment     | Evaluate support | Strong use case                          |
| Operational complexity           | Lower            | Higher                                   |

## Selection principle

```text
Need a standard governed multi-account foundation?
    → Control Tower

Need advanced regulated configuration and networking?
    → Control Tower + LZA

Need custom Organizations-only foundation?
    → LZA can support it, but operational maturity is required
```

---

# 75. Centralized identity architecture

```text
Corporate identity provider
        |
        v
IAM Identity Center
        |
        ├── Developer permission set
        ├── Production ReadOnly
        ├── Production Operator
        └── Security Administrator
                |
                v
        Roles in member accounts
```

Avoid independent IAM users in every account.

Benefits:

* Central onboarding.
* Central offboarding.
* Temporary credentials.
* Group-based access.
* MFA at the identity provider.
* Consistent account access.

---

# 76. Permission-set assignment model

Example:

```text
Group:
TodoApp-Developers

Assignments:
TodoApp Development → Administrator
TodoApp Staging → PowerUser
TodoApp Production → ReadOnly
```

Production deployment may use a CI/CD role rather than direct human administration.

This supports:

```text
Humans:
Review and operate

Pipelines:
Deploy through controlled roles
```

---

# 77. Centralized security service delegation

Recommended ownership example:

| Service                       | Delegated administrator           |
| ----------------------------- | --------------------------------- |
| GuardDuty                     | Security Tooling                  |
| Security Hub                  | Security Tooling                  |
| Inspector                     | Security Tooling                  |
| Macie                         | Security Tooling                  |
| Firewall Manager              | Security Tooling                  |
| Config aggregator             | Security Tooling or Audit         |
| Backup                        | Backup account                    |
| CloudTrail organization trail | Log Archive or management pattern |

Exact delegated-administrator availability depends on the service.

---

# 78. Central network architecture

```text
Workload VPCs
      |
      v
Transit Gateway
      |
      ├── Inspection VPC
      │   └── Network Firewall
      │
      ├── Egress VPC
      │   └── NAT gateways
      │
      ├── Shared Services VPC
      │
      └── Direct Connect / VPN
```

Ownership:

```text
Network account:
Transit and perimeter infrastructure

Workload accounts:
Application VPC resources
```

Use AWS RAM where supported to share centrally owned network resources.

---

# 79. Account vending baseline

Before a workload team receives an account, automate:

```text
Organization and OU placement
IAM Identity Center access
CloudTrail
Config
GuardDuty
Security Hub
Inspector
Central log delivery
Backup enrollment
Budgets
Required tags
VPC or network attachment
DNS
KMS baseline
Patch-management roles
CI/CD roles
```

The result should be:

```text
Ready-to-use governed account
```

not:

```text
Empty AWS account requiring weeks of manual configuration
```

---

# 80. Account email management

Every AWS account requires a unique root email address.

Use controlled aliases or distribution addresses:

```text
aws+todoapp-prod@example.com
aws+todoapp-dev@example.com
```

Requirements:

* Mail must be monitored.
* Recovery messages must be protected.
* Account ownership must not depend on one employee.
* Email lifecycle must outlive employee turnover.
* Security team must know the recovery process.

AWS Organizations requires a unique email address that is not already associated with another AWS account when creating a member account. ([AWS Documentation][35])

---

# 81. Create an account using AWS CLI

```bash
aws organizations create-account \
  --email aws-todoapp-prod@example.com \
  --account-name "TodoApp Production" \
  --role-name OrganizationAccountAccessRole
```

Account creation is asynchronous.

Check status:

```bash
aws organizations describe-create-account-status \
  --create-account-request-id car-example
```

After creation:

```text
Move account to correct OU
Apply policies
Enroll in Control Tower
Run customizations
```

For production environments, Account Factory or AFT is safer than manually chaining these operations.

---

# 82. AWS Organizations CLI commands

List roots:

```bash
aws organizations list-roots
```

List OUs beneath a parent:

```bash
aws organizations list-organizational-units-for-parent \
  --parent-id r-example
```

List accounts in an OU:

```bash
aws organizations list-accounts-for-parent \
  --parent-id ou-example-production
```

List policies attached to an OU:

```bash
aws organizations list-policies-for-target \
  --target-id ou-example-production \
  --filter SERVICE_CONTROL_POLICY
```

Describe effective SCPs:

```bash
aws organizations list-policies-for-target \
  --target-id 123456789012 \
  --filter SERVICE_CONTROL_POLICY
```

Remember that inherited policies from parent OUs and the root must also be evaluated.

---

# 83. Terraform Organizations structure

```hcl
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
    "BACKUP_POLICY"
  ]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com"
  ]
}
```

Changing trusted access and policy types can have organisation-wide consequences.

Review each integration before adding or removing it.

---

# 84. Terraform OU hierarchy

```hcl
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "nonproduction" {
  name      = "NonProduction"
  parent_id = aws_organizations_organizational_unit.workloads.id
}
```

---

# 85. Terraform SCP

```hcl
data "aws_iam_policy_document" "protect_organization" {
  statement {
    sid    = "DenyLeavingOrganization"
    effect = "Deny"

    actions = [
      "organizations:LeaveOrganization",
      "account:CloseAccount"
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_policy" "protect_organization" {
  name        = "ProtectOrganizationMembership"
  description = "Prevents member accounts leaving or closing directly"

  type    = "SERVICE_CONTROL_POLICY"
  content = data.aws_iam_policy_document.protect_organization.json
}

resource "aws_organizations_policy_attachment" "production" {
  policy_id = aws_organizations_policy.protect_organization.id
  target_id = aws_organizations_organizational_unit.production.id
}
```

Test policy attachments in a nonproduction OU before production use.

---

# 86. Terraform Region-restriction SCP

```hcl
data "aws_iam_policy_document" "approved_regions" {
  statement {
    sid    = "DenyUnapprovedRegions"
    effect = "Deny"

    not_actions = [
      "iam:*",
      "organizations:*",
      "route53:*",
      "cloudfront:*",
      "support:*",
      "budgets:*",
      "account:*"
    ]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"

      values = [
        "ap-south-1",
        "us-east-1"
      ]
    }
  }
}
```

Before deployment, validate:

* ACM CloudFront certificates.
* Global services.
* Billing operations.
* Identity Center.
* Route 53.
* Organizations.
* Support.
* Global Accelerator.
* WAF CloudFront scope.

---

# 87. Terraform account resource

```hcl
resource "aws_organizations_account" "todoapp_production" {
  name  = "TodoApp Production"
  email = "aws-todoapp-prod@example.com"

  parent_id = (
    aws_organizations_organizational_unit.production.id
  )

  role_name = "OrganizationAccountAccessRole"

  tags = {
    Application = "TodoApp"
    Environment = "Production"
    CostCenter  = "CC-104"
    Owner       = "ApplicationEngineering"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

## Important warning

Destroying or removing an account resource from Terraform is not equivalent to an ordinary resource deletion.

Account closure has operational, billing and recovery consequences.

Use explicit account-lifecycle processes rather than casual `terraform destroy`.

---

# 88. Moving an account

```bash
aws organizations move-account \
  --account-id 123456789012 \
  --source-parent-id ou-example-old \
  --destination-parent-id ou-example-production
```

Moving an account changes inherited policies immediately.

Before moving:

```text
1. Compare source and destination SCPs.
2. Compare RCPs.
3. Compare Control Tower controls.
4. Check backup policy.
5. Check tag policy.
6. Check network connectivity.
7. Check delegated security configuration.
```

AWS Organizations permits management-account operators to move member accounts between roots and OUs; the resulting inherited policies can change effective permissions. ([AWS Documentation][36])

---

# 89. Account offboarding

A safe offboarding process:

```text
1. Confirm business owner approval.
2. Stop workload traffic.
3. Preserve logs and backups.
4. Export required billing data.
5. Remove external integrations.
6. Revoke IAM Identity Center assignments.
7. Isolate account in Suspended OU.
8. Apply restrictive SCP.
9. Observe.
10. Close account through approved process.
```

Closed member accounts remain represented as closed for a post-closure period before permanent removal. ([AWS Documentation][37])

---

# 90. Do not use account closure as cleanup automation

AWS accounts are durable administrative boundaries.

Do not create and close accounts for every small CI test.

Use:

* Temporary resources.
* Ephemeral VPCs.
* Namespaces.
* Dedicated sandbox accounts.
* Automated resource cleanup.

AWS advises against using the Organizations account-creation API as a mechanism for large numbers of temporary accounts, and account creation and closure are subject to quotas. ([AWS Documentation][38])

---

# 91. Troubleshooting: IAM policy allows but action is denied

Error:

```text
AccessDenied:
Explicit deny in service control policy
```

Troubleshooting:

```text
1. Identify caller:
   aws sts get-caller-identity

2. Identify account and OU path.

3. List SCPs attached to:
   Root
   Parent OUs
   Account

4. Search every policy for explicit Deny.

5. Check requested Region and conditions.

6. Check permissions boundary and session policy.

7. Confirm whether resource policy also applies.
```

Do not keep adding IAM `Allow` policies.

An IAM Allow cannot override an SCP Deny.

---

# 92. Troubleshooting: account provisioning fails

Possible causes:

```text
Account email already exists
Organization account quota reached
Control Tower landing zone drift
Target OU baseline not enabled
Service Catalog permission missing
Account Factory portfolio access missing
AFT pipeline failure
Conflicting Config resources
Missing Control Tower execution role
```

Account Factory targets must have the appropriate Control Tower baseline, and provisioners require access to the Account Factory Service Catalog portfolio. ([AWS Documentation][39])

---

# 93. Troubleshooting: AFT request remains stuck

Check:

```text
AFT account-request repository
CodePipeline execution
CodeBuild logs
AFT management account permissions
Control Tower landing-zone health
Account email uniqueness
Target OU name
Terraform version
Customization repositories
```

AFT uses a dedicated management account and runs account-request, provisioning and customization pipelines. ([AWS Documentation][40])

---

# 94. Troubleshooting: Control Tower enrollment fails

Possible causes:

* Landing zone is in drift.
* Account belongs to another organization.
* Existing Config recorder conflicts.
* Existing CloudTrail configuration conflicts.
* Required execution role is missing.
* Account Factory portfolio permission missing.
* Account is already enrolled elsewhere.
* OU is not registered.
* Baseline deployment failed.

Resolve drift first, then use supported enrollment, update or OU re-registration processes. ([AWS Documentation][41])

---

# 95. Troubleshooting: security service missing new account

Symptoms:

```text
New account created
but GuardDuty or Security Hub not enabled.
```

Check:

```text
Trusted access enabled?
Delegated administrator configured?
Auto-enable for new members enabled?
Account in expected Organization?
Region enabled?
Service supports the Region?
Control Tower baseline completed?
```

Account provisioning and security-service onboarding should be one automated workflow.

---

# 96. Troubleshooting: centralized logs missing

Check:

```text
Organization trail enabled
Member account enrolled
Destination bucket policy
KMS key policy
Log Archive account ownership
CloudTrail service principal
Config delivery role
Region coverage
S3 Object Ownership
Lifecycle policy
```

Also check whether someone created an independent account-level trail that does not deliver to the central bucket.

---

# 97. OU design anti-patterns

## Anti-pattern 1: OU per team only

```text
Frontend OU
Backend OU
Database OU
```

This may separate components that require the same production controls.

## Anti-pattern 2: OU per account

```text
Every account has its own OU
```

This creates unnecessary complexity unless each account truly needs distinct policies.

## Anti-pattern 3: deeply nested hierarchy

```text
Root/Region/BusinessUnit/Team/App/Environment/Tier
```

Policy inheritance becomes difficult to understand.

## Better principle

Design OUs around:

```text
Common governance requirements
```

not solely around reporting structure.

---

# 98. Policy design anti-patterns

## Anti-pattern 1: deny everything before testing

Can block:

* Control Tower.
* CloudFormation.
* Security services.
* Billing.
* Support.
* Account recovery.

## Anti-pattern 2: exception by username

Temporary users and assumed roles make username-based exceptions fragile.

## Anti-pattern 3: broad privileged exemption

```json
"ArnNotLike": {
  "aws:PrincipalArn": "arn:aws:iam::*:role/*Admin*"
}
```

Too many roles may match.

## Anti-pattern 4: managing every detail with SCPs

SCPs are permission ceilings—not full configuration-management tools.

Use:

* Declarative policies.
* Control Tower controls.
* Config rules.
* CloudFormation hooks.
* IAM policies.
* Infrastructure as Code.

---

# 99. Production account-vending workflow

```text
1. Team submits account request.

2. Platform team reviews:
   - Purpose
   - Owner
   - Environment
   - Cost center
   - Data classification

3. Request merged to Git.

4. AFT provisions account.

5. Account moved into correct OU.

6. SCPs, RCPs and policies inherit.

7. Control Tower baseline completes.

8. Security services auto-enable.

9. Network attachment deploys.

10. Backup and budgets deploy.

11. IAM Identity Center assignments deploy.

12. Validation pipeline runs.

13. Account delivered to team.
```

---

# 100. Account validation checks

Before handing over the account:

```text
[ ] Account is in correct OU
[ ] Root email is controlled
[ ] Root access is secured
[ ] IAM Identity Center access works
[ ] CloudTrail organization trail works
[ ] Config recording works
[ ] GuardDuty is enabled
[ ] Security Hub is enabled
[ ] Inspector is enabled where required
[ ] Logs reach Log Archive
[ ] Backup policy applies
[ ] Budget exists
[ ] Required tags exist
[ ] VPC connectivity works
[ ] DNS resolution works
[ ] Region restrictions work
[ ] Break-glass process is documented
```

---

# 101. Enterprise governance checklist

```text
[ ] Organizations uses all-features mode
[ ] Management account contains no workload
[ ] Management root is protected
[ ] Shared accounts have controlled email addresses
[ ] Log Archive is separate
[ ] Security Tooling is separate
[ ] Network infrastructure is centralized appropriately
[ ] Backup copies are isolated
[ ] Production and nonproduction accounts are separate
[ ] Sandbox accounts have expiration and budget controls
[ ] Suspended OU exists
[ ] OU structure follows governance requirements
[ ] SCP strategy is documented
[ ] SCPs are tested before production
[ ] RCP data perimeter is evaluated
[ ] Tag policies are enabled
[ ] Backup policies are enabled
[ ] Declarative policies are evaluated
[ ] Delegated administrators are documented
[ ] Trusted access integrations are reviewed
[ ] IAM Identity Center is centralized
[ ] Control Tower landing zone is current
[ ] Control Tower drift is monitored
[ ] Account Factory is used
[ ] AFT is evaluated for Terraform GitOps
[ ] LZA is evaluated for regulated workloads
[ ] Central logging is immutable
[ ] Organization-wide security services are enabled
[ ] Account vending is automated
[ ] Account offboarding is documented
[ ] Restore and security incident exercises are performed
```

---

# 102. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Organizations:
Central account management and billing

Organizational Unit:
Logical group of accounts

SCP:
Maximum permission guardrail

Control Tower:
Managed multi-account landing zone
```

## Solutions Architect Associate

Understand:

```text
Management versus member accounts
OUs and policy inheritance
Consolidated billing
SCPs
Delegated administration
Control Tower shared accounts
Preventive and detective controls
Account Factory
```

## DevOps Engineer Professional

Understand:

```text
AFT GitOps provisioning
Control Tower baselines
Drift remediation
SCP and RCP design
Declarative policies
Organization-wide CloudTrail
Central security administration
Multi-account CI/CD
LZA configuration pipeline
Account lifecycle automation
```

---

# 103. Interview questions

## Question 1: What is AWS Organizations?

**Answer:**

AWS Organizations centrally manages AWS accounts, groups them into OUs, applies organization policies, delegates supported services and consolidates billing.

## Question 2: What is the Organizations management account?

**Answer:**

It is the most privileged account in the organization and controls account creation, policies, billing and service integrations. Normal workloads should not run there.

## Question 3: What is an OU?

**Answer:**

An Organizational Unit is a logical container for accounts or nested OUs that require common inherited governance policies.

## Question 4: What is an SCP?

**Answer:**

A Service Control Policy limits the maximum permissions available to IAM principals in member accounts. It does not grant permissions.

## Question 5: Does an SCP affect the management account?

**Answer:**

No. SCPs do not restrict identities in the Organizations management account.

## Question 6: What is an RCP?

**Answer:**

A Resource Control Policy limits access available on supported resources in member accounts, especially for controlling external-principal access.

## Question 7: What is the difference between SCP and RCP?

**Answer:**

SCPs are principal-centric and limit what identities can do. RCPs are resource-centric and limit how resources can be accessed.

## Question 8: What is a delegated administrator?

**Answer:**

It is a member account authorised to manage a supported AWS service across the organization.

## Question 9: Why separate Log Archive and Security Tooling?

**Answer:**

Log Archive protects raw evidence, while Security Tooling analyses findings and administers security services. Separation reduces the chance that one compromise affects both.

## Question 10: What is AWS Control Tower?

**Answer:**

AWS Control Tower automates creation and governance of an AWS multi-account landing zone using Organizations, Identity Center, CloudTrail, Config and related services.

## Question 11: What are Control Tower controls?

**Answer:**

They are high-level governance rules implemented as preventive, detective or proactive controls.

## Question 12: How are preventive controls implemented?

**Answer:**

They are implemented using SCPs and, for supported resource controls, RCPs.

## Question 13: How are detective controls implemented?

**Answer:**

They are implemented using AWS Config rules that identify noncompliant resources.

## Question 14: How are proactive controls implemented?

**Answer:**

They are implemented using CloudFormation hooks that evaluate resources before provisioning.

## Question 15: What is Account Factory?

**Answer:**

It is the Control Tower capability for provisioning standardized governed AWS accounts.

## Question 16: What is AFT?

**Answer:**

Account Factory for Terraform provides a Terraform- and GitOps-based pipeline for provisioning and customizing Control Tower accounts.

## Question 17: What is Control Tower drift?

**Answer:**

Drift occurs when Control Tower-managed resources or configurations are changed outside the expected management workflow.

## Question 18: What is Landing Zone Accelerator?

**Answer:**

It is an AWS solution that deploys a highly configurable, security-focused, multi-account foundation aligned with the AWS Security Reference Architecture.

## Question 19: Why use separate production and development accounts?

**Answer:**

Separate accounts provide stronger IAM, quota, billing and blast-radius isolation than separating environments only through names, tags or VPCs.

## Question 20: How should a new AWS account be provisioned?

**Answer:**

Through an automated account-vending process that places it in the correct OU, applies baselines and controls, enables identity, logging, security, networking, backup and cost management before workloads are deployed.

---

# 104. Never-forget revision

```text
AWS Organizations:
Central multi-account management.

Management account:
Most privileged organization account.

Member account:
Account managed within the organization.

Root:
Top organization container.

OU:
Policy grouping for accounts.

SCP:
Maximum permissions for member-account principals.

RCP:
Maximum access available on supported resources.

Tag policy:
Standardizes organizational tags.

Backup policy:
Centralizes backup configuration.

Declarative policy:
Enforces selected service settings.

Delegated administrator:
Member account managing a service organization-wide.

Trusted access:
Allows integrated service organization capabilities.

AWS Control Tower:
Managed landing-zone governance.

Landing zone:
Multi-account cloud foundation.

Log Archive account:
Stores centralized audit evidence.

Audit/Security account:
Administers security and compliance.

Account Factory:
Vends standardized accounts.

AFT:
Terraform GitOps account vending.

Preventive control:
Blocks disallowed actions.

Detective control:
Finds noncompliance after creation.

Proactive control:
Rejects noncompliant CloudFormation resources.

Drift:
Unauthorized or unexpected change to governed resources.

LZA:
Advanced configurable landing-zone automation.
```

## One-line memory trick

```text
Accounts isolate workloads.
OUs group common policies.
Organizations defines the boundaries.
Control Tower establishes the baseline.
AFT vends accounts.
LZA adds enterprise customization.
SCPs guard principals.
RCPs guard resources.
```

## Lesson 37 outcome

You can now design an environment where:

```text
New application needs AWS
    → AFT provisions a governed workload account.

Developer experiments
    → Sandbox account limits cost and blast radius.

Production administrator has AdministratorAccess
    → SCP still prevents security-service tampering.

Bucket policy accidentally trusts the internet
    → RCP data perimeter restricts external access.

New account is created
    → Security services and central logging enable automatically.

Account configuration is modified manually
    → Control Tower identifies drift.

Highly regulated organisation needs advanced networking
    → Control Tower and LZA deploy the governed foundation.

Production account is compromised
    → Central logs and isolated backups remain protected.
```

**Next lesson: Lesson 38 — Amazon CloudWatch, CloudTrail, AWS Config, X-Ray, OpenTelemetry and production observability architecture across multiple AWS accounts.**

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html?utm_source=chatgpt.com "What is AWS Organizations? - AWS Organizations"
[2]: https://docs.aws.amazon.com/prescriptive-guidance/latest/addf-security-and-operations/built-in-security-features.html?utm_source=chatgpt.com "Built-in security features - AWS Prescriptive Guidance"
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_org_support-all-features.html?utm_source=chatgpt.com "Enabling all features for an organization with AWS Organizations - AWS Organizations"
[4]: https://docs.aws.amazon.com/controltower/latest/userguide/nested-ous.html?utm_source=chatgpt.com "Nested OUs in AWS Control Tower"
[5]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices_mgmt-acct.html?utm_source=chatgpt.com "Best practices for the management account - AWS Organizations"
[6]: https://docs.aws.amazon.com/controltower/latest/userguide/special-accounts.html?utm_source=chatgpt.com "About the shared accounts - AWS Control Tower"
[7]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/log-archive.html?utm_source=chatgpt.com "Security OU – Log Archive account - AWS Prescriptive Guidance"
[8]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/network.html?utm_source=chatgpt.com "Infrastructure OU – Network account - AWS Prescriptive Guidance"
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/pricing.html?utm_source=chatgpt.com "Billing and pricing for AWS Organizations - AWS Organizations"
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with Organizations - AWS Organizations"
[11]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[12]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_syntax.html?utm_source=chatgpt.com "SCP syntax - AWS Organizations"
[13]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[14]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies.html?utm_source=chatgpt.com "Managing organization policies with AWS Organizations - AWS Organizations"
[15]: https://docs.aws.amazon.com/organizations/latest/userguide/services-that-can-integrate-tag-policies.html?utm_source=chatgpt.com "Tag policies and AWS Organizations - AWS Organizations"
[16]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_declarative_policies.html?utm_source=chatgpt.com "Declarative policies in AWS Organizations"
[17]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS Control Tower"
[18]: https://docs.aws.amazon.com/controltower/latest/userguide/how-control-tower-works.html?utm_source=chatgpt.com "How AWS Control Tower works"
[19]: https://docs.aws.amazon.com/controltower/latest/userguide/accounts.html?utm_source=chatgpt.com "About AWS accounts in AWS Control Tower"
[20]: https://docs.aws.amazon.com/controltower/latest/userguide/how-controls-work.html?utm_source=chatgpt.com "How controls work - AWS Control Tower"
[21]: https://docs.aws.amazon.com/controltower/latest/userguide/types-of-baselines.html?utm_source=chatgpt.com "Types of baselines - AWS Control Tower"
[22]: https://docs.aws.amazon.com/controltower/latest/userguide/importing-existing.html?utm_source=chatgpt.com "Register an existing organizational unit with AWS Control Tower - AWS Control Tower"
[23]: https://docs.aws.amazon.com/controltower/latest/userguide/enroll-account.html?utm_source=chatgpt.com "About enrolling existing accounts - AWS Control Tower"
[24]: https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html?utm_source=chatgpt.com "Provision and manage accounts with Account Factory - AWS Control Tower"
[25]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html?utm_source=chatgpt.com "Overview of AWS Control Tower Account Factory for ..."
[26]: https://docs.aws.amazon.com/controltower/latest/userguide/taf-account-provisioning.html?utm_source=chatgpt.com "Provision accounts with AWS Control Tower ..."
[27]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-account-customization-options.html?utm_source=chatgpt.com "Account customizations - AWS Control Tower"
[28]: https://docs.aws.amazon.com/controltower/latest/userguide/customize-landing-zone.html?utm_source=chatgpt.com "Customize your AWS Control Tower landing zone - AWS Control Tower"
[29]: https://docs.aws.amazon.com/controltower/latest/userguide/drift.html?utm_source=chatgpt.com "Detect and resolve drift in AWS Control Tower - AWS Control Tower"
[30]: https://docs.aws.amazon.com/controltower/latest/userguide/update-controltower.html?utm_source=chatgpt.com "Update your landing zone - AWS Control Tower"
[31]: https://docs.aws.amazon.com/controltower/latest/userguide/region-how.html?utm_source=chatgpt.com "How AWS Regions Work With AWS Control Tower"
[32]: https://docs.aws.amazon.com/solutions/latest/landing-zone-accelerator-on-aws/solution-overview.html?utm_source=chatgpt.com "Deploy a cloud foundation to support highly-regulated workloads and complex compliance requirements - Landing Zone Accelerator on AWS"
[33]: https://docs.aws.amazon.com/solutions/latest/landing-zone-accelerator-on-aws/deployment-options.html?utm_source=chatgpt.com "Deployment options - Landing Zone Accelerator on AWS"
[34]: https://docs.aws.amazon.com/solutions/latest/landing-zone-accelerator-on-aws/deploy-the-solution.html?utm_source=chatgpt.com "Deploy the solution - Landing Zone Accelerator on AWS"
[35]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_create.html?utm_source=chatgpt.com "Creating a member account in an organization with AWS Organizations - AWS Organizations"
[36]: https://docs.aws.amazon.com/organizations/latest/userguide/move_account_to_ou.html?utm_source=chatgpt.com "Moving accounts to an organizational unit (OU) or between the root and OUs with AWS Organizations - AWS Organizations"
[37]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_close.html?utm_source=chatgpt.com "Closing a member account in an organization with AWS Organizations - AWS Organizations"
[38]: https://docs.aws.amazon.com/cli/latest/reference/organizations/create-account.html?utm_source=chatgpt.com "create-account — AWS CLI 2.35.23 Command Reference"
[39]: https://docs.aws.amazon.com/controltower/latest/userguide/af-guidance.html?utm_source=chatgpt.com "Account Factory guidance - AWS Control Tower"
[40]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-getting-started.html?utm_source=chatgpt.com "Deploy AWS Control Tower Account Factory for Terraform ..."
[41]: https://docs.aws.amazon.com/controltower/latest/userguide/quick-account-provisioning.html?utm_source=chatgpt.com "Enroll an existing account from the AWS Control Tower console - AWS Control Tower"
