# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 10: Final Revision + SAA/DOP/Interview Mastery

This is the **compression lesson**.

Parts 1–9 gave us the individual systems. Now the goal is that, if someone gives you a blank whiteboard in an interview and says:

> **“Design AWS governance for a company with hundreds of accounts.”**

you can reconstruct the architecture without memorizing hundreds of disconnected AWS service names.

---

# 38.1101 The entire Lesson 38 in one sentence

> **Use AWS Organizations to create the account hierarchy and policy boundaries, Control Tower to establish and govern the landing zone, IAM Identity Center for workforce access, delegated administrator accounts for centralized service operations, dedicated Security/Network/Logging accounts for separation of duties, Account Factory/AFT for governed account vending, and Terraform with isolated state and role-based execution to automate the platform.**

AWS Control Tower itself orchestrates services including AWS Organizations and IAM Identity Center to establish a governed multi-account landing zone, while Organizations provides the underlying OU and policy hierarchy. ([AWS Documentation][1])

---

# 38.1102 The master architecture

If you remember only one diagram from Lesson 38, remember this:

```text
                         AWS ORGANIZATION
                               │
                       MANAGEMENT ACCOUNT
                               │
                  organization authority only
                               │
                               ▼
                              ROOT
                               │
      ┌────────────────────────┼────────────────────────┐
      │                        │                        │
      ▼                        ▼                        ▼

  SECURITY OU          INFRASTRUCTURE OU          WORKLOADS OU
      │                        │                        │
 ┌────┴────┐        ┌─────────┼─────────┐         ┌────┴─────┐
 ▼         ▼        ▼         ▼         ▼         ▼          ▼

Security   Log     Network   Shared     AFT     Production  NonProd
Tooling   Archive  Account   Services  Account
   │         │        │         │                   │
   │         │        │         │                   ├── Payments
   │         │        │         │                   ├── Orders
   │         │        │         │                   └── Customer
   │         │        │         │
   │         │        │         ├── DNS
   │         │        │         ├── Directory
   │         │        │         └── Shared services
   │         │        │
   │         │        ├── TGW
   │         │        ├── IPAM
   │         │        ├── DX / VPN
   │         │        ├── Egress
   │         │        └── Routing
   │         │
   │         ├── CloudTrail evidence
   │         ├── Security Lake
   │         └── immutable archive
   │
   ├── Security Hub
   ├── GuardDuty
   ├── Inspector
   ├── Macie
   ├── Access Analyzer
   └── incident automation
```

Then overlay:

```text
                ORGANIZATION-WIDE CONTROL LAYERS

                        SCP / RCP
                           │
                           ▼
                     Control Tower
                           │
                           ▼
                       Baselines
                           │
                           ▼
                         OUs
                           │
                           ▼
                       Accounts
                           │
                           ▼
                 IAM Identity Center
                           │
                           ▼
                    Permission Sets
                           │
                           ▼
                         Users
```

That is the Lesson 38 mental model.

---

# 38.1103 Why AWS accounts are architectural boundaries

A beginner thinks:

```text
AWS Account
=
billing container
```

An enterprise architect thinks:

```text
AWS Account
=
blast-radius boundary

+
administrative boundary

+
security boundary

+
quota boundary

+
cost boundary

+
workload ownership boundary
```

This is why we don't simply put:

```text
Dev
Test
Prod
Security
Network
Data
```

into one giant AWS account and attempt to solve everything with IAM.

---

# 38.1104 Organization hierarchy

Think:

```text
Organization
    │
    ▼
Root
    │
    ▼
OU
    │
    ▼
nested OU
    │
    ▼
Account
```

AWS Organizations lets you group accounts into OUs and attach policy-based controls to those OUs so descendants inherit them. ([AWS Documentation][2])

The golden shortcut:

```text
ROOT
=
everything


OU
=
policy grouping


ACCOUNT
=
workload/admin boundary
```

---

# 38.1105 Management Account

The management account is special.

It controls organization-level operations such as:

```text
Organizations

organization policies

delegated administrator designation

certain trusted service integrations
```

and should therefore contain as little day-to-day workload as possible.

AWS explicitly recommends limiting management-account use because SCPs do **not** restrict IAM users and roles in that account. ([AWS Documentation][3])

Permanent rule:

```text
MANAGEMENT ACCOUNT
=
organization authority

NOT
=
central dumping ground
```

---

# 38.1106 SCP — the fastest mental model

# SCP = **maximum permissions boundary for principals in member accounts**

An SCP:

```text
does NOT grant permission
```

It determines what permissions can potentially be exercised by identities in affected member accounts.

AWS documents that SCPs restrict users and roles in member accounts and that effective permissions must be allowed through every applicable parent level. ([AWS Documentation][4])

Think:

```text
Identity Policy
       │
       ▼
"I allow ec2:*"

       ∩

SCP
       │
       ▼
"Only these EC2 actions
are permitted"

       =
effective ceiling
```

---

# 38.1107 SCP question shortcut

Whenever someone says:

> “The IAM role has AdministratorAccess, but the API is denied.”

Your brain should immediately ask:

```text
SCP?

permissions boundary?

session policy?

resource policy?

RCP?

explicit deny?
```

Never stop troubleshooting at:

```text
AdministratorAccess
```

---

# 38.1108 SCP does not affect the management account

This is one of the most important certification/interview traps.

Suppose:

```text
Root
  │
  └── SCP:
      Deny s3:DeleteBucket
```

Member accounts:

```text
DENIED
```

Management account:

```text
not restricted by that SCP
```

AWS explicitly states SCPs affect member accounts and not users or roles in the management account. ([AWS Documentation][3])

Never forget.

---

# 38.1109 RCP — the complementary model

# RCP = Resource Control Policy

SCP asks:

> **What may this principal do?**

RCP asks:

> **What permissions may this protected resource accept?**

Mental model:

```text
SCP
=
principal-side organization guardrail


RCP
=
resource-side organization guardrail
```

RCPs are an AWS Organizations policy type and have their own supported service/resource coverage; they do not constrain service-linked roles. ([AWS Documentation][5])

---

# 38.1110 SCP vs RCP

Think of an S3 bucket.

```text
Principal
   │
   ▼
SCP
   │
   ▼
IAM permissions
   │
   ▼
Request
   │
   ▼
RCP
   │
   ▼
Bucket policy
   │
   ▼
S3
```

So an action can fail because:

```text
principal side
```

or:

```text
resource side
```

or both.

---

# 38.1111 Policy evaluation mental model

For most troubleshooting, use:

```text
                    REQUEST
                       │
                       ▼
              Is there explicit DENY?
                       │
             YES ──────┴──────► DENY
                       │
                       NO
                       ▼
              Is action allowed by
              required identity/resource
                   policy path?
                       │
                     YES
                       │
                       ▼
              Are organization controls
                  permitting it?
                       │
                       ▼
              SCP / RCP / boundaries
                       │
                       ▼
                    ALLOW
```

The exact IAM evaluation algorithm has more nuances, but this model keeps you from making the classic mistake:

```text
one Allow
=
always allowed
```

Wrong.

---

# 38.1112 Control Tower mental model

AWS Organizations gives you:

```text
raw organizational primitives
```

Control Tower gives you:

```text
governed landing-zone operating model
```

AWS describes Control Tower as a way to set up and govern a multi-account environment by orchestrating multiple AWS services. ([AWS Documentation][1])

Permanent equation:

```text
AWS CONTROL TOWER

=
Organizations

+
landing zone

+
shared accounts

+
baselines

+
controls

+
account governance

+
Account Factory
```

---

# 38.1113 Landing Zone

A landing zone is:

```text
the governed multi-account
foundation into which workloads land
```

It is **not**:

```text
one VPC

one account

one Terraform module

one network
```

It includes:

```text
account hierarchy
identity
logging
security
governance
regional setup
account provisioning
```

---

# 38.1114 Control Tower terminology you must know

```text
OU
→ REGISTER


ACCOUNT
→ ENROLL


FOUNDATION
→ BASELINE


RULE
→ CONTROL
```

That four-line memory trick covers a large portion of Control Tower terminology.

---

# 38.1115 Registered OU vs enrolled account

Suppose:

```text
Production OU
```

exists in AWS Organizations.

That does not automatically mean it is fully governed by Control Tower.

Conceptually:

```text
Production OU
     │
     ▼
REGISTER
     │
     ▼
Control Tower governance
```

Its member accounts then become enrolled as part of the managed environment.

---

# 38.1116 Baseline vs Control

Never interchange these.

```text
BASELINE
=
foundational governance
configuration


CONTROL
=
specific governance rule
```

Example:

```text
AWSControlTowerBaseline
```

might establish Control Tower governance for an OU.

A specific control may enforce or evaluate a security requirement.

Control Tower now explicitly models baselines as a distinct governance concept. ([AWS Documentation][6])

---

# 38.1117 Preventive, detective, proactive

The permanent shortcut:

```text
PREVENTIVE
=
BLOCK


DETECTIVE
=
FIND


PROACTIVE
=
CHECK BEFORE DEPLOYMENT
```

If you're asked:

> “Which control would prevent an API operation from happening?”

Think:

```text
Preventive
```

If asked:

> “Which control tells me a resource is already non-compliant?”

Think:

```text
Detective
```

---

# 38.1118 Audit vs Log Archive

Permanent mnemonic:

```text
AUDIT
=
INVESTIGATOR


LOG ARCHIVE
=
EVIDENCE
```

Do not put ordinary business applications into either.

---

# 38.1119 IAM Identity Center

The problem:

```text
1000 employees
×
100 AWS accounts
```

should not become:

```text
100,000 separately maintained
IAM-user relationships.
```

IAM Identity Center centralizes workforce access to multiple AWS accounts, and Control Tower can use it for Account Factory-created environments. ([AWS Documentation][7])

---

# 38.1120 Workforce vs workload identity

Another permanent distinction:

```text
HUMANS
      │
      ▼
IAM Identity Center


MACHINES
      │
      ▼
IAM roles
workload federation
service roles
```

Examples of workloads:

```text
Lambda
ECS task
EC2
EKS workload
CI/CD
```

Do not create Identity Center users for Lambda functions.

---

# 38.1121 Identity Center's four objects

```text
1. Identity Source
2. User / Group
3. Permission Set
4. Account Assignment
```

The permanent equation:

```text
WHO
+
WHAT PERMISSION
+
WHICH ACCOUNT
=
ACCOUNT ASSIGNMENT
```

---

# 38.1122 Permission Set vs IAM Role

Permission Set:

```text
central Identity Center template
```

IAM role:

```text
actual account-level identity
used for AWS authorization
```

Identity Center turns account assignments into managed roles in target accounts.

Mental model:

```text
Permission Set
      │
      ▼
AWSReservedSSO_* role
      │
      ▼
temporary AWS session
```

---

# 38.1123 SAML vs SCIM

This must be instant in interviews.

```text
SAML
=
SIGN IN


SCIM
=
SYNC
```

Expanded:

```text
SAML
=
authentication / federation


SCIM
=
user + group lifecycle provisioning
```

---

# 38.1124 IAM Identity Center does not bypass Organizations

Suppose:

```text
Permission Set
=
AdministratorAccess
```

but SCP says:

```text
Deny organizations:LeaveOrganization
```

Result:

```text
DENIED.
```

Identity Center changes **how the human obtains the role**, not the higher-level Organizations guardrails.

---

# 38.1125 Security architecture

The enterprise security model:

```text
                    SECURITY TOOLING
                           │
       ┌───────────────────┼───────────────────┐
       ▼                   ▼                   ▼

   GuardDuty           Inspector          Security Hub
       │                   │                   │
       ├───────────┐       │                   │
       ▼           ▼       ▼                   ▼
     Macie     Access Analyzer         Central findings
       │                                   │
       └─────────────────┬─────────────────┘
                         ▼
                    EventBridge
                         │
                         ▼
                  Response / SIEM
```

Then separate evidence:

```text
                      LOG ARCHIVE
                           │
                      CloudTrail
                           │
                    Security Lake
                           │
                    long-term logs
```

---

# 38.1126 Security services — one-line memory table

| Service         | Never-forget question                                          |
| --------------- | -------------------------------------------------------------- |
| CloudTrail      | **Who called which AWS API?**                                  |
| Config          | **What configuration did the resource have?**                  |
| GuardDuty       | **Is suspicious activity happening?**                          |
| Inspector       | **What vulnerabilities exist?**                                |
| Macie           | **Where is sensitive data in S3?**                             |
| Security Hub    | **What security findings/posture need attention?**             |
| Detective       | **What context helps investigate the event?**                  |
| Access Analyzer | **Who can access what?**                                       |
| Security Lake   | **Where can security telemetry be centralized for analytics?** |

If you remember the **question**, you'll remember the service.

---

# 38.1127 CloudTrail vs Config

Example:

A security group suddenly allows:

```text
0.0.0.0/0:22
```

Ask:

```text
Config:
What did the SG configuration become?


CloudTrail:
Who/API changed it?
```

They complement each other.

---

# 38.1128 GuardDuty vs Inspector

```text
GUARDDUTY
=
behavior / threat signal


INSPECTOR
=
known vulnerability/exposure
```

Example:

```text
Inspector:
OpenSSL CVE


GuardDuty:
Suspicious EC2 communication
```

Don't swap them in exams.

---

# 38.1129 Security Hub

Security Hub is not:

```text
a giant raw-log warehouse.
```

It is a centralized security posture/findings layer.

Current Security Hub organization capabilities include delegated administration and central configuration across accounts/Regions. ([AWS Documentation][8])

---

# 38.1130 Security Hub vs Security Lake

Permanent mnemonic:

```text
HUB
=
FINDINGS


LAKE
=
DATA
```

Security Hub:

```text
security issues/posture
```

Security Lake:

```text
security telemetry for analytics/hunting
```

---

# 38.1131 Central security account vs management account

Do not operate your day-to-day SOC from:

```text
Organizations Management Account
```

Use:

```text
Security Tooling
```

with delegated service administration.

AWS Organizations explicitly encourages delegation to reduce management-account usage. ([AWS Documentation][9])

---

# 38.1132 Trusted Access vs Delegated Administrator

This should now be automatic:

```text
TRUSTED ACCESS
=
May Service X integrate
with the Organization?


DELEGATED ADMIN
=
Which member account
administers Service X?
```

AWS Organizations distinguishes trusted service integration from delegated administrator designation. ([AWS Documentation][10])

---

# 38.1133 Service-linked role

Permanent equation:

```text
AWS SERVICE
      │
      ▼
SERVICE-LINKED ROLE
      │
      ▼
acts in the AWS account
on the service's behalf
```

Don't randomly delete:

```text
AWSServiceRoleFor...
```

because they can be part of Organizations/trusted-service integrations.

---

# 38.1134 Delegated administrator ≠ second management account

Think:

```text
MANAGEMENT ACCOUNT
=
organization authority


DELEGATED ADMIN
=
service authority
```

Security Hub DA:

```text
Security Hub authority
```

not:

```text
ability to close arbitrary accounts
and control Organizations.
```

---

# 38.1135 No universal delegation model

Important senior-level lesson:

AWS services do **not** all implement delegated administration identically.

Security Hub has a delegated admin and can centralize organization configuration. GuardDuty, Macie, Inspector, CloudTrail, Firewall Manager, Backup and others have their own service-specific organization behavior. ([AWS Documentation][11])

Therefore:

> **Never design organization service integration from a generic delegated-admin template alone.**

---

# 38.1136 Network Account

The Network account centralizes:

```text
IP planning
TGW
DX
VPN
routing
enterprise egress
inspection integration
```

but should not become:

```text
the account where all
application teams deploy.
```

Permanent principle:

```text
CENTRALIZE SHARED NETWORK POLICY

not

EVERY APPLICATION NETWORK OPERATION
```

---

# 38.1137 TGW ownership model

```text
Network Account
      │
      ▼
Transit Gateway
      │
      │ RAM share
      ▼
Workload Accounts
```

Workload accounts consume transit.

Network team owns transit routing policy.

---

# 38.1138 VPC vs TGW route tables

From Lesson 36 and now governance:

```text
VPC ROUTE TABLE
=
how does traffic leave
this VPC?


TGW ROUTE TABLE
=
after traffic enters transit,
where does it go?
```

Ownership:

```text
Workload
→ local VPC path


Network
→ transit path
```

---

# 38.1139 IPAM

The problem:

```text
Payments  10.0.0.0/16
Orders    10.0.0.0/16
Analytics 10.0.0.0/16
```

becomes catastrophic when you need routed connectivity.

IPAM solves:

```text
address planning

allocation

usage visibility

central governance
```

not packet routing.

Memory:

```text
IPAM
=
WHO GETS WHICH CIDR


TGW
=
WHERE PACKETS GO
```

---

# 38.1140 Inbound vs outbound Resolver

Never forget:

```text
INBOUND

On-prem asks AWS


OUTBOUND

AWS asks on-prem
```

If someone asks:

> “AWS workloads need to resolve `database.corp.internal` hosted on-prem.”

Answer:

```text
Outbound Resolver path
```

---

# 38.1141 Route 53 Profile mental model

At enterprise scale:

```text
DNS Profile
   │
   ├── private DNS
   ├── Resolver configuration
   ├── DNS Firewall
   └── query logging
        │
        ▼
many VPCs
```

Instead of individually associating every DNS configuration with every VPC.

---

# 38.1142 Network Firewall vs DNS Firewall

Instant distinction:

```text
DNS Firewall
=
domain query filtering


Network Firewall
=
network traffic inspection
```

---

# 38.1143 Centralized egress

Model:

```text
Workload VPC
    │
    ▼
TGW
    │
    ▼
Inspection/Egress
    │
    ▼
Network Firewall
    │
    ▼
NAT Gateway
    │
    ▼
Internet
```

Benefits:

```text
central policy
central visibility
fewer external IPs
```

Trade-offs:

```text
cost
blast radius
transit dependency
routing complexity
```

Never answer:

```text
central NAT is always best
```

because architecture is about trade-offs.

---

# 38.1144 VPC sharing vs TGW

Use this distinction:

```text
VPC SHARING

multiple accounts
deploy into
one centrally owned VPC


TGW

multiple separate VPCs
are routed together
```

Choose shared VPC when:

```text
similar trust boundaries
+
central route ownership
```

Choose separate VPC + TGW when:

```text
stronger isolation
+
independent network boundaries
```

---

# 38.1145 PrivateLink vs TGW

If Payments needs access to:

```text
one Fraud API
```

do not automatically give:

```text
Payments
↔ entire Fraud VPC
```

PrivateLink may provide narrower service-level connectivity.

Mental shortcut:

```text
BROAD NETWORK CONNECTIVITY
→ TGW


ONE PRIVATE SERVICE
→ PrivateLink
```

---

# 38.1146 Account Factory vs AFT

Another instant interview distinction:

```text
ACCOUNT FACTORY
=
Control Tower account vending


AFT
=
Terraform + GitOps
around account vending
and customization
```

Control Tower Account Factory provisions governed accounts, while AFT builds Terraform-based provisioning/customization workflows around the Control Tower environment. ([AWS Documentation][12])

---

# 38.1147 AFT does not replace Control Tower

Architecture:

```text
Control Tower
     │
     ▼
Account Factory
     │
     ▼
AFT
```

not:

```text
AFT
replaces
Control Tower.
```

AFT depends on a Control Tower landing zone. ([AWS Documentation][13])

---

# 38.1148 AFT does not replace application Terraform

Permanent rule:

```text
AFT
=
ACCOUNT FOUNDATION


APPLICATION TERRAFORM
=
APPLICATION INFRASTRUCTURE
```

Do not use one AFT customization repo as the continuous deployment system for:

```text
ECS releases
RDS changes
application ALBs
```

---

# 38.1149 AFT four-repository memory

```text
REQUEST

PROVISION

GLOBAL

ACCOUNT
```

Expanded:

```text
aft-account-request

aft-account-provisioning-customizations

aft-global-customizations

aft-account-customizations
```

You can reconstruct the names from their purpose.

---

# 38.1150 Account vending mental model

A platform team should expose:

```text
AccountName
Environment
Owner
CostCenter
Compliance
NetworkProfile
PrimaryRegion
DRRegion
```

not:

```text
TGW route table ID
KMS key ARN
Resolver rule ID
security policy ID
```

Developers specify:

# intent.

Platform implements:

# infrastructure.

That is platform engineering.

---

# 38.1151 Terraform state rule

The most important Terraform rule from Part 9:

> **One resource should have one authoritative Terraform state owner.**

Bad:

```text
state A
   │
   ▼
TGW

state B
   │
   ▼
same TGW
```

That is infrastructure split brain.

---

# 38.1152 One state vs many

Do not put:

```text
Organizations
Security
Network
Identity
AFT
500 workloads
```

into one `terraform.tfstate`.

Split according to:

```text
ownership
lifecycle
privilege
blast radius
```

This is an architecture decision, not just repo organization.

---

# 38.1153 Provider Alias

Provider alias means:

```text
same provider

different configuration
```

Examples:

```text
AWS Mumbai

AWS Singapore

AWS Management account

AWS Network account
```

HashiCorp documents aliased provider configurations and explicitly passing those providers to child modules. ([HashiCorp Developer][14])

---

# 38.1154 Cross-account Terraform

Use:

```text
CI identity
     │
     ▼
STS AssumeRole
     │
     ├── Organization role
     ├── Security role
     ├── Network role
     └── Workload role
```

not:

```text
static access keys
for every account.
```

---

# 38.1155 Modern Terraform S3 locking

A major current detail:

Terraform's S3 backend supports:

```hcl
use_lockfile = true
```

for native S3 state locking, and HashiCorp currently marks DynamoDB-based locking as deprecated. It also recommends S3 versioning for state recovery. ([HashiCorp Developer][15])

So your modern mental model should now be:

```text
S3 state

+
S3 lockfile

+
S3 versioning
```

rather than automatically assuming:

```text
S3 + DynamoDB
```

for every new backend.

---

# 38.1156 Terraform state lock ≠ deployment approval

```text
LOCK
=
prevent concurrent writers


PR REVIEW
=
prevent unauthorized/bad changes


SCP
=
prevent prohibited AWS operations
```

Different controls.

---

# 38.1157 Whiteboard answer — “Design AWS governance for 500 accounts”

A strong interview answer:

```text
First, I would establish an AWS Organization and design OUs
around policy and workload boundaries rather than company org charts.

I would keep the management account minimal.

I would deploy Control Tower as the landing-zone governance layer.

Security, networking, logging, identity and backup would be
separated into appropriate shared/platform accounts.

Workforce users would use IAM Identity Center instead of
hundreds of per-account IAM users.

Security services would use delegated administration from
the Security Tooling account.

Network transit and IP management would live in a dedicated
Network account, with resources shared through RAM where appropriate.

New workload accounts would be provisioned through Account Factory
or AFT, placed into the correct OU and automatically receive
security, identity, logging and network baselines.

Terraform would use separate state boundaries and cross-account
AssumeRole rather than one giant state and permanent access keys.
```

That is already a very strong senior-level response.

---

# 38.1158 Scenario 1 — “AdministratorAccess but AccessDenied”

Environment:

```text
User
  │
  ▼
Identity Center
  │
  ▼
AdministratorAccess
```

Command:

```text
organizations:LeaveOrganization
```

returns:

```text
AccessDenied
```

Investigate:

```text
SCP first
```

because an SCP can restrict a member-account identity even when its IAM/permission-set policy is broad. ([AWS Documentation][4])

---

# 38.1159 Scenario 2 — management account user bypasses SCP

Question:

> Why can the management account perform an action that member accounts cannot?

Because SCPs do not constrain management-account users or roles. ([AWS Documentation][3])

Architecture lesson:

```text
Protect management account
by minimizing access

not by assuming SCPs protect it.
```

---

# 38.1160 Scenario 3 — new account exists but isn't Control Tower governed

Check:

```text
Is its OU registered?

Is the account enrolled?

Did the Control Tower baseline apply?

Is there drift?
```

Existence in Organizations alone does not equal full landing-zone governance.

---

# 38.1161 Scenario 4 — developer wants 30 IAM users across accounts

Answer:

```text
Do not replicate workforce IAM users
across accounts.

Use IAM Identity Center
+
groups
+
permission sets
+
account assignments.
```

AWS recommends Identity Center-based workforce access over IAM users with long-term credentials for normal human access. ([AWS Documentation][16])

---

# 38.1162 Scenario 5 — user can sign in but sees no AWS account

Troubleshooting layers:

```text
Authentication worked.
```

So don't start with SAML.

Check:

```text
group membership

account assignment

permission set
```

Mental stack:

```text
AUTHENTICATION
      ↓
ASSIGNMENT
      ↓
AUTHORIZATION
```

---

# 38.1163 Scenario 6 — GuardDuty central administration is in management account

Would it work?

Potentially.

Would it be preferred?

Usually no.

Better:

```text
Security Tooling
=
delegated administrator
```

so routine security administration occurs in a member account that can itself be governed by SCPs. AWS recommends delegated administration to reduce management-account usage. ([AWS Documentation][9])

---

# 38.1164 Scenario 7 — trusted access enabled but nobody can administer service

Expected possibility.

Because:

```text
trusted access
```

grants the AWS service ability to integrate with Organizations.

It does not automatically grant human IAM permissions. ([AWS Documentation][10])

You still need:

```text
delegated administrator

+
permission set / IAM permissions.
```

---

# 38.1165 Scenario 8 — Security Hub configured only in Mumbai

DR fails to Singapore.

Question:

> Why don't we see Singapore security posture centrally?

Check:

```text
Security Hub enabled/configured there?

Is Singapore linked to the home Region?

Is the delegated admin configured through the central model?

Are relevant services producing findings there?
```

Security Hub central configuration is designed to configure posture across multiple accounts and Regions, and its delegated administrator model is Region-aware. ([AWS Documentation][8])

---

# 38.1166 Scenario 9 — Config shows SG changed, but who did it?

Use:

```text
AWS Config
→ determine state/configuration change


CloudTrail
→ determine API principal/action
```

That's the correct service pairing.

---

# 38.1167 Scenario 10 — critical CVE in ECR image

Primary service:

```text
Inspector
```

Then:

```text
Security Hub
```

may aggregate the security finding.

Do not answer:

```text
GuardDuty
```

as your first vulnerability-management service.

---

# 38.1168 Scenario 11 — unknown AWS account can access S3 bucket

Think:

```text
IAM Access Analyzer
```

because the question is about resource access relative to your trust boundary.

Then investigate:

```text
bucket policy

RCP

SCP

IAM

Access Analyzer finding
```

---

# 38.1169 Scenario 12 — all VPCs invented overlapping CIDRs

Correct enterprise response:

```text
central address plan
+
IPAM
+
governed VPC vending
```

not:

```text
another TGW.
```

Transit doesn't fix overlapping addresses.

---

# 38.1170 Scenario 13 — Dev can unexpectedly reach Prod

Check transit segmentation:

```text
Dev VPC route

TGW attachment

TGW association

TGW route propagation

firewall path

Prod route

SG/NACL

return route
```

Particularly verify:

```text
Did Dev routes leak into
Prod TGW route table?
```

---

# 38.1171 Scenario 14 — AWS workload cannot resolve on-prem domain

Domain:

```text
db.corp.internal
```

You need:

```text
AWS
  ↓
Outbound Resolver
  ↓
hybrid network
  ↓
on-prem DNS
```

Never answer inbound endpoint for this direction.

---

# 38.1172 Scenario 15 — only one API needs cross-account private connectivity

Before giving full TGW routing:

```text
evaluate PrivateLink.
```

Architecture principle:

```text
least privilege
```

has a networking equivalent:

# least connectivity.

---

# 38.1173 Scenario 16 — need complete network control but separate workload accounts

Strong candidate:

```text
VPC sharing
```

Network team owns:

```text
VPC
subnets
routes
NAT
NACLs
```

Application accounts deploy resources into shared subnets.

---

# 38.1174 Scenario 17 — developers manually request account by ticket

At 5 accounts:

```text
possibly acceptable.
```

At 500 accounts:

```text
Account Factory / AFT
```

becomes compelling.

AFT provides Terraform-based account provisioning while keeping Control Tower governance. ([AWS Documentation][13])

---

# 38.1175 Scenario 18 — deleting AFT account request

Does it mean:

```text
AWS account is safely deleted?
```

No.

Account-management lifecycle and underlying AWS-account closure are separate concepts.

Always design formal:

```text
decommission
data retention
network removal
identity removal
unenrollment
closure
```

procedures.

---

# 38.1176 Scenario 19 — one Terraform pipeline can assume every admin role

Technically convenient.

Architecturally dangerous.

Better:

```text
Organization pipeline
→ Org role


Security pipeline
→ Security role


Network pipeline
→ Network role


Application pipeline
→ Workload role
```

That limits blast radius if one pipeline is compromised.

---

# 38.1177 Scenario 20 — Terraform state contains whole enterprise

Answer:

```text
split it.
```

Use:

```text
lifecycle
ownership
privilege
blast radius
```

to determine state boundaries.

Not:

```text
number of .tf files.
```

---

# 38.1178 Scenario 21 — create 500 provider aliases dynamically

Don't design one huge:

```text
for_each account
→ dynamic provider
```

configuration.

Use:

```text
AFT

account-specific pipelines

workspace/state units

generated roots

controlled execution contexts
```

instead.

---

# 38.1179 Scenario 22 — Terraform apply succeeded but account unusable

Remember:

```text
APPLY SUCCESS
≠
SYSTEM READY
```

Validate:

```text
OU

policies

Identity Center

security

network

DNS

logging

regional configuration
```

before declaring:

```text
ACCOUNT READY.
```

---

# 38.1180 Scenario 23 — DR application works, but engineers cannot log in

That's an:

```text
IDENTITY DR FAILURE.
```

Multi-Region architecture must include:

```text
workforce access

break-glass

external IdP dependency

security tooling

network access
```

not only application compute/database.

---

# 38.1181 Scenario 24 — Singapore application works but GuardDuty absent

That's:

```text
SECURITY DR FAILURE.
```

Your DR definition must include:

```text
availability

data

network

identity

security

governance
```

not just customer HTTP 200.

---

# 38.1182 Scenario 25 — DR Region uses Mumbai Resolver

Mumbai fails.

Singapore loses DNS.

That is a:

```text
hidden primary-Region dependency.
```

The same Lesson 37 question applies:

> **If I make ap-south-1 completely unreachable, what in ap-southeast-1 still secretly depends on it?**

Apply it to:

```text
DNS
network
security
identity
CI/CD
state
KMS
logging
```

not only databases.

---

# 38.1183 SAA-style decision shortcuts

For certification-style architecture questions:

```text
Need centrally group accounts
and apply policies?
→ AWS Organizations


Need governed multi-account
landing zone?
→ Control Tower


Need workforce SSO across
many AWS accounts?
→ IAM Identity Center


Need maximum permission
guardrail for principals?
→ SCP


Need resource-side
organization guardrail?
→ RCP


Need governed account vending?
→ Account Factory


Need Terraform/Git account vending?
→ AFT


Need central threat detection?
→ GuardDuty delegated admin


Need vulnerability scanning?
→ Inspector


Need sensitive S3 discovery?
→ Macie


Need cross-account network hub?
→ TGW


Need centralized CIDR governance?
→ IPAM


Need share supported resources?
→ RAM
```

---

# 38.1184 DOP-style reasoning

DevOps Professional questions often care less about:

```text
what service exists?
```

and more about:

```text
How do I automate it safely?

How do I centralize operations?

How do I minimize manual work?

How do I keep governance?

How do I detect drift?

How do I make new accounts inherit controls?
```

So your default mindset should become:

```text
ORGANIZATION POLICY

+
DELEGATED ADMIN

+
AUTOMATED ONBOARDING

+
IaC

+
CENTRAL OBSERVABILITY

+
MINIMAL MANUAL ACCESS
```

---

# 38.1185 Senior interview — “SCP vs permissions boundary”

Strong answer:

```text
SCP
=
organization-level maximum permission
guardrail applied through account hierarchy.


Permissions Boundary
=
IAM principal-level maximum permissions
for a user/role.
```

Both:

```text
do not grant permission.
```

They restrict what can become effective.

---

# 38.1186 Senior interview — “SCP vs RCP”

Strong answer:

```text
SCP
=
limits principals in organization accounts.


RCP
=
limits permissions accepted
by supported resources
in organization accounts.
```

Then add:

> I treat them as complementary principal-side and resource-side organization guardrails.

---

# 38.1187 Senior interview — “Organizations vs Control Tower”

Strong answer:

> **AWS Organizations is the underlying account hierarchy, OU, organization-policy and service-integration layer. Control Tower builds a governed landing-zone operating model on top of Organizations and other AWS services, adding standardized setup, baselines, controls, shared-account patterns and Account Factory.** ([AWS Documentation][1])

---

# 38.1188 Senior interview — “Why separate Security Tooling and Log Archive?”

Answer:

```text
Security Tooling
=
operators/admins analyze
and respond


Log Archive
=
evidence is stored
and protected
```

Separation reduces the chance that a security operator—or attacker compromising operational tooling—can easily destroy the underlying audit evidence.

---

# 38.1189 Senior interview — “Why dedicated Network account?”

Answer:

> I centralize enterprise transit, hybrid connectivity, IP governance, egress and shared DNS/network primitives there, while workload accounts retain application ownership. This creates clear routing authority and keeps each application team from inventing a separate enterprise network.

---

# 38.1190 Senior interview — “Why use delegated admin?”

Answer:

> **To move routine organization-wide service operations out of the highly privileged Organizations management account into appropriately scoped member accounts. Trusted access enables the service/Organizations integration; the delegated administrator specifies which member account operates that service centrally.** ([AWS Documentation][10])

---

# 38.1191 Senior interview — “Why not everything in Security account?”

Because:

```text
Security
Network
Backup
Identity
Logging
```

are different responsibilities and risk domains.

One account controlling all of them creates a huge administrative blast radius.

But creating a separate account for every individual security service also creates unnecessary complexity.

The architect's job is to find sensible **duty boundaries**.

---

# 38.1192 Senior interview — “How do you onboard a new account?”

Strong end-to-end answer:

```text
1.
Account request enters through AFT/Account Factory.

2.
Account is placed in correct OU.

3.
Organization policies become effective.

4.
Control Tower baseline/governance applies.

5.
Security service organization policies/
delegated administration include account.

6.
Identity Center assignments are created.

7.
Network profile allocates IP space,
VPC and TGW/DNS connectivity.

8.
Logging is centrally verified.

9.
Readiness tests run.

10.
Application team receives account
only after baseline passes.
```

That is platform account vending.

---

# 38.1193 Senior interview — “How do you govern 500 accounts?”

The wrong answer is:

```text
500 IAM admins
+
500 manual VPCs
+
500 copies of security settings.
```

The correct abstractions are:

```text
OU

SCP/RCP

Control Tower baseline

Identity Center group

delegated administrator

organization policy

RAM

IPAM

Route 53 Profile

AFT template

Terraform module
```

Enterprise architecture scales by **abstraction**, not by copying configuration faster.

---

# 38.1194 Troubleshooting decision tree

Memorize this.

```text
                    WHAT IS BROKEN?
                          │
          ┌───────────────┼─────────────────┐
          ▼               ▼                 ▼

       ACCESS           ACCOUNT           SERVICE
          │               │                 │
          ▼               ▼                 ▼

Can user sign in?     Correct OU?       Enabled Region?
      │                  │                 │
      ▼                  ▼                 ▼
Identity source       Registered OU?   Trusted access?
      │                  │                 │
      ▼                  ▼                 ▼
Group membership     Enrolled?         Delegated admin?
      │                  │                 │
      ▼                  ▼                 ▼
Permission set       Baseline?         Member included?
      │                  │                 │
      ▼                  ▼                 ▼
Assignment            Drift?           Service policy?
      │
      ▼
IAM policy
      │
      ▼
Boundary
      │
      ▼
SCP/RCP
```

Then, if networking:

```text
DNS
 ↓
source route
 ↓
TGW
 ↓
inspection
 ↓
destination
 ↓
return
```

This gives you a disciplined troubleshooting method instead of random console clicking.

---

# 38.1195 Five planes of enterprise AWS

A very useful architecture abstraction:

```text
1. ORGANIZATION PLANE

Organizations
OUs
SCP/RCP


2. IDENTITY PLANE

IAM Identity Center
permission sets


3. PLATFORM PLANE

Control Tower
AFT
Terraform


4. SHARED INFRASTRUCTURE PLANE

Network
DNS
Security
Backup
Logging


5. WORKLOAD PLANE

ECS
EKS
EC2
RDS
application services
```

Do not let the workload plane own the organization plane.

---

# 38.1196 Governance hierarchy

Think from strongest/broadest control downward:

```text
ORGANIZATION
     │
     ▼
OU
     │
     ▼
SCP / RCP
     │
     ▼
CONTROL TOWER
     │
     ▼
ACCOUNT
     │
     ▼
IAM / Identity Center
     │
     ▼
RESOURCE POLICIES
     │
     ▼
APPLICATION
```

The higher the layer:

```text
larger blast radius.
```

Therefore:

```text
higher layer
=
stronger change control.
```

---

# 38.1197 Change-control hierarchy

A change to:

```text
CloudWatch alarm
```

might require normal PR review.

A change to:

```text
application ECS task
```

requires workload CI/CD.

A change to:

```text
TGW route
```

requires Network review.

A change to:

```text
Security Hub organization configuration
```

requires Security governance review.

A change to:

```text
Root-level SCP
```

requires the highest organizational scrutiny.

Never give every Terraform repository identical approval policy.

---

# 38.1198 Blast-radius hierarchy

```text
RESOURCE
   <
VPC
   <
ACCOUNT
   <
OU
   <
ORGANIZATION
```

As you move upward:

```text
more workloads
can fail simultaneously.
```

That should influence:

```text
testing

approvals

rollout strategy

rollback planning.
```

---

# 38.1199 The enterprise AWS anti-pattern list

Avoid designs where:

```text
Management account runs applications.

All humans have IAM users.

Every team has AdministratorAccess.

Security services are enabled manually.

Every VPC invents a CIDR.

Every VPC builds its own VPN.

Prod and Dev share unrestricted transit.

Central logs are deletable by workload admins.

AFT and another Terraform state both manage accounts.

One Terraform state owns the organization and all apps.

CI stores permanent management-account keys.

DR Region depends on primary DNS/network/security.

New accounts are usable before security onboarding.

Account closure happens by "git rm".

No one knows which account owns which shared service.
```

If you see several of these together, the organization is not operating at mature enterprise scale.

---

# 38.1200 The “never forget” architecture formula

Memorize this exact chain:

```text
ORGANIZATIONS
=
structure


OU
=
grouping


SCP
=
principal ceiling


RCP
=
resource ceiling


CONTROL TOWER
=
landing-zone governance


IDENTITY CENTER
=
workforce access


DELEGATED ADMIN
=
central service operations


SECURITY TOOLING
=
detect + respond


LOG ARCHIVE
=
evidence


NETWORK ACCOUNT
=
enterprise connectivity


IPAM
=
address governance


RAM
=
resource sharing


ACCOUNT FACTORY
=
account vending


AFT
=
Terraform/Git account vending


TERRAFORM
=
repeatable infrastructure ownership
```

If you can recreate that from memory, most Lesson 38 questions become easy.

---

# 38.1201 The “one word” memory test

I'll give the requirement; your brain should produce the service/concept immediately.

```text
Account hierarchy?
→ Organizations


Group accounts?
→ OU


Principal organization guardrail?
→ SCP


Resource organization guardrail?
→ RCP


Landing zone?
→ Control Tower


Human SSO?
→ Identity Center


API audit?
→ CloudTrail


Configuration history?
→ Config


Threat detection?
→ GuardDuty


Vulnerabilities?
→ Inspector


Sensitive S3 data?
→ Macie


Security findings?
→ Security Hub


Security data lake?
→ Security Lake


Central transit?
→ TGW


IP allocation?
→ IPAM


Cross-account resource sharing?
→ RAM


Account vending?
→ Account Factory


Terraform account vending?
→ AFT
```

This should become reflexive.

---

# 38.1202 The five hardest distinctions

If these five are crystal clear, you're ahead of many AWS practitioners:

```text
SCP
vs
IAM policy


SCP
vs
RCP


Organizations
vs
Control Tower


Permission Set
vs
IAM Role


Trusted Access
vs
Delegated Administrator
```

Let's compress each one.

---

# 38.1203 SCP vs IAM policy

```text
IAM POLICY
=
grants/denies permissions
to identity/resource


SCP
=
organization-level
maximum-permission guardrail
```

SCP alone cannot make an action usable.

---

# 38.1204 SCP vs RCP

```text
SCP
=
principal perspective


RCP
=
resource perspective
```

---

# 38.1205 Organizations vs Control Tower

```text
Organizations
=
multi-account primitive


Control Tower
=
governed landing zone
built on those primitives
```

---

# 38.1206 Permission Set vs IAM Role

```text
Permission Set
=
central template


IAM Role
=
actual account identity
```

---

# 38.1207 Trusted Access vs Delegated Administrator

```text
Trusted Access
=
service may integrate


Delegated Admin
=
member account may administer
```

---

# 38.1208 The production account creation story

Imagine tomorrow you are the AWS platform architect.

Payments team says:

> “We need production.”

Your answer should **not** be:

```text
Send me your CIDR.
```

Instead:

```text
Tell me:

Application
Owner
Environment
Compliance
Cost Center
Primary Region
DR requirement
Network profile
```

Platform pipeline then determines:

```text
OU

policies

security

network

identity

logging

backup

DNS
```

That is the difference between:

```text
infrastructure team
```

and:

# platform engineering.

---

# 38.1209 The ideal developer experience

Developer sees:

```text
┌─────────────────────────────────┐
│ Request AWS Environment         │
├─────────────────────────────────┤
│ Application: Payments           │
│ Environment: Production         │
│ Region: Mumbai                  │
│ DR: Singapore                   │
│ Compliance: PCI                 │
│ Network: Private / Inspected    │
└─────────────────────────────────┘

            REQUEST
               │
               ▼
            APPROVAL
               │
               ▼
              AFT
               │
               ▼
           AWS ACCOUNT
               │
               ▼
              READY
```

Developer does not need to know:

```text
OU ID

TGW ID

IPAM pool ID

Resolver Profile ID

Security Hub admin account ID
```

That's the platform team's job.

---

# 38.1210 Final production reference architecture

Here is the complete whiteboard.

```text
                              CORPORATE IdP
                                   │
                              SAML / SCIM
                                   │
                                   ▼
                         IAM IDENTITY CENTER
                                   │
                             Permission Sets
                                   │
                                   ▼
                            AWS ORGANIZATION
                                   │
                            MANAGEMENT ACCOUNT
                                   │
                                   ▼
                                  ROOT
                                   │
       ┌───────────────────────────┼────────────────────────────┐
       │                           │                            │
       ▼                           ▼                            ▼

   SECURITY OU             INFRASTRUCTURE OU               WORKLOADS OU
       │                           │                            │
 ┌─────┴──────┐         ┌─────────┼──────────┐            ┌────┴───────┐
 ▼            ▼         ▼         ▼          ▼            ▼            ▼

Security     Log      Network   Shared       AFT      Production     NonProd
Tooling     Archive   Account   Services    Account        │
   │            │        │         │          │            ├── Payments
   │            │        │         │          │            ├── Orders
   │            │        │         │          │            └── Customer
   │            │        │         │          │
   │            │        │         │          ▼
   │            │        │         │    Account Factory
   │            │        │         │          │
   │            │        │         │          ▼
   │            │        │         │     Account Vending
   │            │        │         │
   │            │        │         ├── Resolver
   │            │        │         ├── Route 53 Profiles
   │            │        │         └── Directory
   │            │        │
   │            │        ├── IPAM
   │            │        ├── TGW
   │            │        ├── RAM
   │            │        ├── DX/VPN
   │            │        └── Egress
   │            │
   │            ├── CloudTrail
   │            ├── Security Lake
   │            └── immutable S3
   │
   ├── GuardDuty
   ├── Inspector
   ├── Security Hub
   ├── Macie
   ├── Access Analyzer
   └── Incident automation

                    ORGANIZATION POLICY PLANE

                           SCP / RCP
                               │
                        Control Tower
                               │
                           Baselines
                               │
                           Controls


                     TERRAFORM CONTROL PLANE

                              Git
                               │
                               ▼
                              CI
                               │
                        temporary identity
                               │
                               ▼
                         STS AssumeRole
                               │
        ┌──────────────────────┼───────────────────────┐
        ▼                      ▼                       ▼

  Organization State      Security State         Network State

                               │
                               ▼
                       Application States
```

If you can draw this and explain **why each account exists**, you're operating at a very strong AWS architecture level.

---

# 38.1211 Final troubleshooting mantra

When something fails, don't ask:

> “Which AWS service is broken?”

Walk the layers:

```text
IDENTITY
   │
   ▼
PERMISSION
   │
   ▼
ORGANIZATION POLICY
   │
   ▼
ACCOUNT / OU
   │
   ▼
REGION
   │
   ▼
SERVICE CONFIGURATION
   │
   ▼
NETWORK
   │
   ▼
RESOURCE
```

For connectivity:

```text
RESOLVE
  ↓
ROUTE
  ↓
TRANSIT
  ↓
INSPECT
  ↓
DELIVER
  ↓
RETURN
```

For delegated services:

```text
TRUST
  ↓
DELEGATION
  ↓
IAM
  ↓
REGION
  ↓
SERVICE STATE
```

For AFT:

```text
REQUEST
  ↓
PROVISION
  ↓
CUSTOMIZE
  ↓
AUTHORIZE
```

These troubleshooting frameworks are much more valuable than memorizing console screenshots.

---

# 38.1212 Final 30 never-forget points

```text
01.
AWS accounts are security and
blast-radius boundaries.


02.
OUs group accounts for governance.


03.
SCPs do not grant permission.


04.
SCPs don't restrict management-account
users or roles.


05.
RCPs are resource-side organization guardrails.


06.
Control Tower sits on top of
Organizations.


07.
Landing Zone is the enterprise
cloud foundation.


08.
OU → register.
Account → enroll.


09.
Baseline ≠ control.


10.
Preventive = block.
Detective = detect.
Proactive = pre-check.


11.
Audit = investigator.
Log Archive = evidence.


12.
Use IAM Identity Center for
workforce access.


13.
SAML = sign in.
SCIM = sync.


14.
Permission Set is a template.
IAM Role is the account implementation.


15.
GuardDuty = threat detection.


16.
Inspector = vulnerability management.


17.
Macie = S3 sensitive-data security.


18.
Security Hub = findings/posture.


19.
Security Lake = security data.


20.
Trusted access enables
service ↔ Organizations integration.


21.
Delegated admin chooses
the operating member account.


22.
Network Account owns shared transit,
not applications.


23.
IPAM governs addresses.


24.
RAM shares centrally owned resources.


25.
Inbound DNS:
On-prem → AWS.


26.
Outbound DNS:
AWS → On-prem.


27.
Account Factory = account vending.


28.
AFT = Terraform/Git account vending.


29.
One resource must have one
authoritative IaC owner.


30.
DR includes governance,
identity, security and networking—
not merely application compute.
```

---

# 38.1213 Lesson 38 final interview answer

If the interviewer asks:

> **“Describe your ideal AWS enterprise multi-account architecture.”**

You can answer:

> I would start with AWS Organizations and design OUs around governance and workload boundaries. I would keep the management account minimal because it has exceptional organization authority and is not restricted by SCPs. Control Tower would provide the governed landing zone and account baseline. Workforce users would authenticate centrally through IAM Identity Center using group-based permission sets rather than per-account IAM users. Security, logging, networking and other shared responsibilities would live in dedicated member accounts, with supported AWS services using trusted access and delegated administration rather than day-to-day operations from the management account. Security findings would be centralized in the Security Tooling account and audit evidence protected in a separate Log Archive account. A Network account would own IPAM, Transit Gateway, hybrid connectivity and shared network policy, with supported resources exposed through RAM. New workload accounts would be vended through Account Factory or AFT, automatically placed into the correct OU and integrated with security, identity, logging and networking. Terraform would be split into states according to privilege, lifecycle and blast radius and would use temporary cross-account role assumptions rather than permanent management-account credentials.

That answer connects almost the entire lesson.

---

# 38.1214 Lesson 38 mastery checkpoint

At this point you should be able to reason through:

```text
✓ AWS Organizations

✓ Root

✓ OUs

✓ Management account

✓ Member accounts

✓ SCP

✓ RCP

✓ policy evaluation

✓ Control Tower

✓ landing zones

✓ baselines

✓ controls

✓ Audit account

✓ Log Archive

✓ IAM Identity Center

✓ permission sets

✓ account assignments

✓ SAML

✓ SCIM

✓ RBAC / ABAC

✓ GuardDuty

✓ Inspector

✓ Macie

✓ Security Hub

✓ Security Lake

✓ Detective

✓ Access Analyzer

✓ CloudTrail

✓ Config

✓ Network account

✓ Shared Services

✓ TGW

✓ IPAM

✓ RAM

✓ hybrid DNS

✓ Route 53 Profiles

✓ Network Firewall

✓ centralized egress

✓ PrivateLink

✓ VPC sharing

✓ trusted access

✓ service-linked roles

✓ delegated administrators

✓ Account Factory

✓ AFT

✓ account vending

✓ Terraform state boundaries

✓ provider aliases

✓ AssumeRole

✓ multi-account CI/CD

✓ policy testing

✓ drift detection

✓ account readiness

✓ governance DR
```

---

# ✅ Lesson 38 — COMPLETE

```text
Part 1
Enterprise Multi-Account Architecture
+ AWS Organizations                     ✓

Part 2
SCP + RCP + IAM Policy Evaluation       ✓

Part 3
AWS Control Tower Landing Zone          ✓

Part 4
IAM Identity Center                     ✓

Part 5
Central Security + Logging              ✓

Part 6
Network + Shared Services Accounts      ✓

Part 7
Account Factory + AFT                   ✓

Part 8
Delegated Administration                ✓

Part 9
Terraform Governance Capstone           ✓

Part 10
Final Revision + SAA/DOP/
Interview Mastery                       ✓
```

# 🎯 Module 13 — AWS Production Architecture Progress

We have now completed another major production architecture chapter.

The next chapter will move us from **multi-account governance** into the next AWS production architecture domain, while continuing the same beginner → intermediate → advanced → production → troubleshooting → certification/interview format.

[1]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS ..."
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_ous.html?utm_source=chatgpt.com "Managing organizational units (OUs) with AWS ..."
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html?utm_source=chatgpt.com "Delegated administrator for AWS Organizations"
[4]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[5]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[6]: https://docs.aws.amazon.com/controltower/latest/userguide/types-of-baselines.html?utm_source=chatgpt.com "Types of baselines - AWS Control Tower"
[7]: https://docs.aws.amazon.com/controltower/latest/userguide/sso.html?utm_source=chatgpt.com "Working with AWS IAM Identity Center and AWS Control ..."
[8]: https://docs.aws.amazon.com/securityhub/latest/userguide/central-configuration-intro.html?utm_source=chatgpt.com "Understanding central configuration in Security Hub CSPM"
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with ..."
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html?utm_source=chatgpt.com "Using AWS Organizations with other AWS services"
[11]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-v2-set-da.html?utm_source=chatgpt.com "Designating a delegated administrator in Security Hub"
[12]: https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html?utm_source=chatgpt.com "Provision and manage accounts with Account Factory"
[13]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html?utm_source=chatgpt.com "Overview of AWS Control Tower Account Factory for ..."
[14]: https://developer.hashicorp.com/terraform/tutorials/aws/aws-control-tower-aft?utm_source=chatgpt.com "Manage AWS accounts using Control Tower ..."
[15]: https://developer.hashicorp.com/terraform/language/backend/s3?utm_source=chatgpt.com "Backend Type: s3 | Terraform"
[16]: https://docs.aws.amazon.com/controltower/latest/userguide/auth-access.html?utm_source=chatgpt.com "Identity and access management in AWS Control Tower"
