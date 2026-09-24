# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 1: Enterprise Multi-Account Architecture & AWS Organizations Mental Model

Lesson 37 answered:

> **How does an application survive infrastructure, AZ, and Region-level failures?**

Lesson 38 asks a different production question:

> **How do hundreds of AWS accounts, teams, environments, security boundaries, permissions, logs, networks, and policies remain governable without turning the cloud estate into chaos?**

This is where we move from:

```text
ONE AWS ACCOUNT

VPC
EC2
RDS
ECS
IAM
S3
```

to:

```text
                    AWS ORGANIZATION

                          Root
                            │
          ┌─────────────────┼──────────────────┐
          │                 │                  │
          ▼                 ▼                  ▼
      Security OU     Infrastructure OU    Workloads OU
          │                 │                  │
    ┌─────┴─────┐      ┌────┴─────┐      ┌────┴────────┐
    ▼           ▼      ▼          ▼      ▼             ▼
Security    Log Archive Network  Shared  Production   NonProd
Account       Account   Account Services    Accounts    Accounts
```

AWS recommends a multi-account approach as AWS environments grow because accounts provide natural administrative, billing, quota, access-control, and workload-isolation boundaries. Organizational units let administrators group those accounts and manage them as units. ([AWS Documentation][1])

---

# 38.1 Lesson 38 roadmap

We'll build this progressively:

```text
Part 1
AWS Organizations mental model
+ enterprise account strategy          ← NOW

Part 2
OUs + SCPs + RCPs
+ policy evaluation deep dive

Part 3
AWS Control Tower
+ Landing Zone architecture

Part 4
IAM Identity Center
+ enterprise workforce access

Part 5
Centralized Logging,
Security & Audit Accounts

Part 6
Network Account,
Shared Services & Platform Patterns

Part 7
Account Factory,
AFT + self-service account vending

Part 8
Delegated Administration
+ organization-wide security services

Part 9
Terraform Multi-Account
Governance Capstone

Part 10
Final Revision +
SAA/DOP/Interview Mastery
```

By the end, you should be able to design the AWS account structure for an enterprise from a blank whiteboard.

---

# 38.2 Why not put everything in one AWS account?

Imagine this:

```text
ONE AWS ACCOUNT

Production EC2
Production RDS
Dev EC2
Dev RDS
Security tools
Network infrastructure
CI/CD
Shared DNS
Developers
Auditors
Security engineers
Finance
Data scientists
```

Technically possible.

Operationally dangerous.

Suppose a developer accidentally runs:

```bash
terraform destroy
```

against the wrong state.

Or an IAM administrator grants:

```json
"Action": "*",
"Resource": "*"
```

Or Dev creates:

```text
500 expensive GPU instances
```

Or a compromised Dev credential obtains broad resource access.

With everything inside the same account:

```text
DEV FAILURE
      │
      ▼
Potentially impacts
PRODUCTION
```

A multi-account architecture creates stronger administrative and workload isolation boundaries.

---

# 38.3 AWS Account as a security boundary

Think of an AWS account as more than:

```text
"the thing containing my EC2 instances"
```

It is also a boundary around things such as:

```text
IAM identities

service quotas

API activity

billing attribution

resources

service configurations

security controls
```

This makes accounts useful as:

# **Blast-radius boundaries.**

Mental shortcut:

```text
VPC
=
network isolation boundary


AWS ACCOUNT
=
administrative / security /
resource ownership boundary


AWS ORGANIZATION
=
governance boundary across accounts
```

---

# 38.4 Example — Dev should not share Prod's administrative blast radius

Bad:

```text
Account A

├── Prod
├── Dev
└── QA
```

Better:

```text
AWS Organization

├── Prod Account
├── Dev Account
└── QA Account
```

Now an accidental Dev operation occurs inside:

```text
DEV ACCOUNT
```

instead of sharing the same account boundary as:

```text
PRODUCTION.
```

This doesn't mean cross-account attacks or bad organization-wide policies are impossible.

It means we've created a much stronger isolation primitive.

---

# 38.5 Environment isolation is only one reason

Accounts can be divided by:

```text
Environment

Business unit

Product

Security boundary

Compliance requirement

Data sensitivity

Ownership

Operational team

Lifecycle
```

Example:

```text
Payments-Prod

Payments-Dev

Analytics-Prod

Security-Tooling

Network

Log-Archive
```

The correct design is not:

```text
"one account per EC2 instance"
```

or:

```text
"one account for everything."
```

We want meaningful ownership and failure boundaries.

---

# 38.6 AWS Organizations

Now introduce the central service.

# AWS Organizations

provides centralized management of multiple AWS accounts.

Conceptually:

```text
AWS ORGANIZATIONS

      │
      ├── Accounts
      ├── Organizational Units
      ├── Organization policies
      ├── Delegated administration
      └── Consolidated account hierarchy
```

AWS Organizations lets accounts be grouped hierarchically into organizational units and enables organization-wide governance mechanisms such as Service Control Policies and Resource Control Policies when the organization has the required features enabled. ([AWS Documentation][2])

---

# 38.7 Organization hierarchy

The basic hierarchy:

```text
ORGANIZATION
     │
     ▼
    ROOT
     │
     ├── OU
     │    │
     │    ├── Account
     │    └── Account
     │
     └── OU
          │
          ├── Account
          └── Nested OU
```

Example:

```text
Root
│
├── Security OU
│   ├── Security-Tooling
│   └── Log-Archive
│
├── Infrastructure OU
│   ├── Network
│   └── Shared-Services
│
├── Production OU
│   ├── Payments-Prod
│   ├── Orders-Prod
│   └── Analytics-Prod
│
└── NonProduction OU
    ├── Payments-Dev
    ├── Payments-QA
    └── Sandbox
```

OUs exist specifically to group accounts so administrators can manage groups of accounts rather than configuring governance one account at a time. ([AWS Documentation][3])

---

# 38.8 Important: Organization Root ≠ AWS root user

These names cause confusion.

## AWS Organizations Root

```text
Organization
     │
     ▼
    ROOT
```

is:

> the top-level container in the AWS Organizations hierarchy.

It contains:

```text
OUs
and/or
accounts
```

---

## AWS account root user

This is:

```text
email/password
associated with
one AWS account
```

Completely different concept.

Never say:

```text
"Attach this OU to the root user."
```

That's nonsense.

---

# 38.9 Management Account

Every organization has a:

# Management Account

Think:

```text
AWS ORGANIZATION

Management Account
      │
      ▼
Organizations administration
```

Historically you'll also encounter the old term:

```text
master account
```

but modern AWS terminology is:

```text
management account.
```

The management account is extremely privileged within the organization.

AWS recommends using it only for operations that must be performed there and placing normal workloads in member accounts. A critical reason is that Organizations SCPs do **not** restrict users and roles in the management account. ([AWS Documentation][4])

---

# 38.10 Huge production rule

# Do not run normal production workloads in the management account.

Bad:

```text
MANAGEMENT ACCOUNT

Organizations
Control Tower

+

Production RDS
Production ECS
Production S3
```

Better:

```text
MANAGEMENT ACCOUNT

Organizations / governance
only as necessary


PAYMENTS PROD ACCOUNT

Application resources
```

AWS Control Tower documentation likewise explicitly recommends not running production workloads from the Control Tower management account. ([AWS Documentation][5])

---

# 38.11 Why protect the management account?

Imagine its credentials are compromised.

The attacker may have access to powerful organization-level operations involving:

```text
account management

organizational policies

service integration

delegated administrators

organization structure
```

That makes it one of your most sensitive cloud administrative boundaries.

Therefore:

```text
Management Account
=
minimal daily usage

strong MFA

minimal standing access

no ordinary workloads

high monitoring
```

---

# 38.12 Member Accounts

Every normal account that belongs to the organization is generally called a:

# Member Account

Example:

```text
Organization
│
├── Management Account
│
├── Payments-Prod      ← member
├── Payments-Dev       ← member
├── Network            ← member
├── Security           ← member
└── Log-Archive        ← member
```

Workloads should generally live in:

```text
member accounts.
```

---

# 38.13 Organizational Unit — OU

An OU is essentially:

> **A logical container for AWS accounts.**

Example:

```text
Production OU
│
├── Payments-Prod
├── Orders-Prod
└── Analytics-Prod
```

Instead of configuring governance independently on:

```text
Payments
Orders
Analytics
```

you can target:

```text
Production OU.
```

This is one of the central scaling mechanisms in AWS Organizations. ([AWS Documentation][3])

---

# 38.14 OU is not a network object

Important beginner trap.

OU does **not** mean:

```text
VPC

subnet

network

firewall

security group
```

It is an:

```text
organizational / governance
container.
```

Example:

```text
Prod OU
```

doesn't automatically make:

```text
Payments VPC
```

connect to:

```text
Orders VPC.
```

Network topology remains a separate architectural layer.

Remember Lesson 36:

```text
Accounts/OUs
=
governance


TGW/VPC/DX/VPN
=
networking
```

---

# 38.15 OUs can be nested

Example:

```text
Root
│
└── Workloads OU
    │
    ├── Production OU
    │   ├── Payments
    │   └── Orders
    │
    └── NonProduction OU
        ├── Dev
        └── QA
```

Nested OUs allow policy structures to represent business or security hierarchy. AWS Organizations supports hierarchical OU structures, and Control Tower also supports nested OU governance with specific inheritance behavior depending on control type. ([AWS Documentation][3])

---

# 38.16 Don't copy your company org chart blindly

Suppose corporate structure:

```text
CEO
 │
 ├── Finance
 ├── Marketing
 ├── Sales
 └── Engineering
```

That doesn't mean your cloud organization should automatically be:

```text
Finance OU
Marketing OU
Sales OU
Engineering OU
```

Ask:

```text
Which accounts require
similar governance?

Which share
security controls?

Which share
compliance rules?

Which need different
access boundaries?
```

OU architecture should primarily reflect:

# governance requirements,

not office politics.

---

# 38.17 Example enterprise OU architecture

A strong starting model:

```text
AWS ORGANIZATION
│
├── Security OU
│   │
│   ├── Security-Tooling
│   └── Log-Archive
│
├── Infrastructure OU
│   │
│   ├── Network
│   ├── Shared-Services
│   └── Platform
│
├── Workloads OU
│   │
│   ├── Production OU
│   │   ├── Payments-Prod
│   │   ├── Orders-Prod
│   │   └── Analytics-Prod
│   │
│   └── NonProduction OU
│       ├── Payments-Dev
│       ├── Payments-QA
│       └── Sandbox
│
└── Suspended / Quarantine OU
```

Notice:

```text
Security

Infrastructure

Production

NonProduction
```

have very different governance needs.

---

# 38.18 Security OU

Purpose:

```text
central security functions
```

Example:

```text
Security OU
│
├── Security-Tooling
└── Log-Archive
```

Why separate them from applications?

Because application administrators shouldn't necessarily control:

```text
organization audit data

security findings

central detection infrastructure
```

This is separation of duties.

---

# 38.19 Log Archive Account

A dedicated:

# Log Archive Account

is one of the foundational enterprise patterns.

Concept:

```text
Account A ──┐
Account B ──┤
Account C ──┤
Account D ──┘
            │
            ▼
      LOG ARCHIVE
        ACCOUNT
```

AWS Control Tower creates or uses a dedicated Log Archive shared account for centralized logs across the landing zone; its documentation describes that account as the central repository for API activity and resource-configuration logs. ([AWS Documentation][6])

---

# 38.20 Why not store audit logs in the application account?

Imagine attacker compromises:

```text
Payments Prod
```

If the same administrators can also easily delete:

```text
the audit evidence
```

your forensic position is weaker.

Better:

```text
Payments Account

   │ log delivery
   ▼

Separate Log Archive Account
```

Now operational and audit ownership are separated.

---

# 38.21 Security Tooling / Audit Account

Another centralized security account may host or coordinate functions such as:

```text
security investigation

security service administration

compliance visibility

cross-account audit access
```

AWS Control Tower's default shared-account architecture includes an **Audit account** and a **Log Archive account** inside a Security OU. The Audit account is intended for security/compliance access and auditing activities. ([AWS Documentation][7])

---

# 38.22 Infrastructure OU

Example:

```text
Infrastructure OU
│
├── Network
├── Shared-Services
└── Platform
```

This separates common infrastructure from business workloads.

---

# 38.23 Network Account

Remember Lesson 36.

A centralized Network account might own:

```text
Transit Gateway

Direct Connect integration

VPN

central DNS infrastructure

network inspection

IPAM

shared networking automation
```

Then workload accounts attach to centrally managed networking.

Concept:

```text
                 NETWORK ACCOUNT

                      TGW

             ┌─────────┼─────────┐
             ▼         ▼         ▼

        Payments    Orders     Shared
        Account     Account    Account
```

Account ownership and network ownership become distinct.

That's a good thing.

---

# 38.24 Shared Services Account

Common services might include:

```text
directory services

DNS

artifact services

CI/CD support

internal PKI

monitoring

common tools
```

Instead of duplicating all of them in every application account.

Architecture:

```text
                   Shared Services
                         │
                 ┌───────┼────────┐
                 ▼       ▼        ▼
                DNS     AD      Tooling
```

Workloads consume those services through intentional cross-account/network paths.

---

# 38.25 Platform Account

A modern organization might also have:

```text
Platform Account
```

for:

```text
developer platform services

CI/CD platform

GitOps infrastructure

shared container tooling

internal developer portals

automation
```

The exact boundaries depend on team ownership.

Don't create accounts merely because a diagram looks sophisticated.

---

# 38.26 Production OU

Example:

```text
Production OU

├── Payments-Prod
├── Orders-Prod
├── Customer-Prod
└── Data-Prod
```

Possible guardrail goals:

```text
No unapproved AWS Regions

No disabling central security services

No leaving the organization

No destructive changes
to protected controls

Restricted Internet exposure

Stronger tagging/compliance
requirements
```

We'll implement such ideas using:

```text
SCPs

RCPs

Control Tower controls

Config

IAM
```

in later parts.

---

# 38.27 NonProduction OU

Example:

```text
NonProduction OU

├── Payments-Dev
├── Payments-QA
├── Load-Test
└── Sandbox
```

Here you may permit:

```text
more experimentation
```

while still blocking:

```text
dangerous organization-level behavior

unapproved Regions

security-control removal

extremely expensive services
```

depending on business policy.

The OU architecture lets us express:

```text
different rules
for different risk classes.
```

---

# 38.28 Sandbox OU

A Sandbox account is not:

```text
"no rules."
```

It means:

```text
safe experimentation
inside broad boundaries.
```

For example:

```text
Allowed:
EC2
Lambda
S3
DynamoDB
Terraform labs


Blocked:
disabling security controls
creating organization resources
using prohibited Regions
some expensive service families
```

Governance should allow engineers to move quickly without giving them the ability to damage the organization.

---

# 38.29 Quarantine / Suspended OU

A useful operational pattern:

```text
Quarantine OU
```

for accounts that need restricted access.

Example:

```text
Compromised Account
       │
       ▼
Quarantine OU
       │
       ▼
restrict capabilities
while incident investigated
```

Or:

```text
account scheduled for decommissioning
```

can be isolated from normal workload OUs.

The exact implementation must be carefully tested because aggressive SCP restrictions can also block incident-response operations.

---

# 38.30 Now the governance problem

Suppose there are:

```text
300 AWS accounts.
```

You need to guarantee:

> Nobody in normal workload accounts may disable the organization's security monitoring.

Would you manually edit IAM in:

```text
Account 1
Account 2
Account 3
...
Account 300?
```

No.

That's where:

# Organization Policies

come in.

---

# 38.31 Service Control Policies — SCPs

This is one of the most important AWS governance concepts.

An:

# SCP

defines the **maximum available permissions** for IAM users and roles in member accounts.

Crucially:

# **SCPs do not grant permissions.**

AWS explicitly describes SCPs as permission guardrails rather than permission grants. IAM or resource policies still need to grant the underlying action. ([AWS Documentation][8])

---

# 38.32 SCP mental model

Suppose an IAM role has:

```text
IAM says:

Allow:
ec2:*
s3:*
rds:*
```

But organization SCP permits:

```text
EC2 ✓
S3  ✓
RDS ✕
```

Effective result:

```text
EC2 ✓
S3  ✓
RDS ✕
```

Think:

```text
IAM
=
What this principal is granted


SCP
=
Maximum organizational boundary
within which those grants may operate
```

---

# 38.33 One never-forget equation

Simplified mental model:

```text
EFFECTIVE PERMISSION

≈

IAM ALLOW
∩
SCP ALLOW BOUNDARY
```

with other policy types, explicit denies, resource policies, permission boundaries, session policies, RCPs, and service-specific evaluation rules also potentially participating.

The important concept:

```text
SCP does not ADD permission.
```

---

# 38.34 Example

Developer role:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Looks terrifying.

But Production OU has an SCP that denies:

```text
organizations:LeaveOrganization
```

The developer still cannot perform that denied organization action from the member account even though its IAM policy says:

```text
"*"
```

The organization guardrail wins where the SCP restricts the action.

---

# 38.35 Explicit Deny mental model

A powerful rule from IAM evaluation generally applies:

```text
EXPLICIT DENY
beats
ALLOW
```

So if an organization policy says:

```text
DENY dangerous action
```

you cannot override that simply by adding:

```text
AdministratorAccess
```

inside the member account.

That's why SCPs are useful as guardrails.

---

# 38.36 Critical SCP trap

Question:

> "We attached an SCP with `Allow ec2:*`. Why can't the developer launch EC2?"

Because:

```text
SCP
does not grant access.
```

You still need IAM permissions.

Mental model:

```text
SCP:
YOU MAY go this far.


IAM:
YOU ARE GRANTED these actions.
```

Both must permit the request.

AWS documentation explicitly calls SCPs coarse-grained guardrails and says normal IAM/resource policies are still required to grant permissions. ([AWS Documentation][9])

---

# 38.37 SCP scope

SCPs can be attached at organization hierarchy levels such as:

```text
Root

OU

Account
```

and their restrictions affect member accounts under those targets according to Organizations policy evaluation. ([AWS Documentation][9])

Example:

```text
ROOT
 │
 │ Region Restriction SCP
 ▼
all descendant workload OUs/accounts

Production OU
 │
 │ stronger production SCP
 ▼
Prod Accounts
```

This gives us hierarchical governance.

---

# 38.38 Critical management-account exception

Remember:

> SCPs do not restrict users or roles in the AWS Organizations management account.

AWS explicitly calls this out and recommends keeping resources and normal workloads out of that account. ([AWS Documentation][4])

This is one reason the management account needs especially tight human/process controls.

---

# 38.39 Modern AWS governance — RCPs

AWS Organizations also supports:

# Resource Control Policies — RCPs

SCPs are largely:

```text
principal-centric
```

RCPs are:

```text
resource-centric.
```

AWS describes RCPs as centralized controls over the maximum available permissions for resources in member accounts. Like SCPs, they are guardrails and don't themselves grant permissions. ([AWS Documentation][10])

---

# 38.40 SCP vs RCP

Mental shortcut:

```text
SCP
=
"What may principals in
these accounts do?"


RCP
=
"What access may resources
in these accounts accept?"
```

AWS's current Organizations documentation explicitly describes SCPs as principal-centric and RCPs as resource-centric authorization policies. ([AWS Documentation][11])

This is a major modern governance concept.

---

# 38.41 Example RCP problem

Imagine an S3 bucket resource policy accidentally says:

```json
Principal: "*"
```

You may want an organization-level resource guardrail preventing organization-owned resources from accepting certain external access patterns.

That's the kind of governance problem RCPs are designed to address.

Think:

```text
SCP
protect principals


RCP
protect resources
```

We'll go very deeply into this in Part 2.

---

# 38.42 Organizations "all features"

SCPs and RCPs require an AWS Organization operating with the relevant full feature set; current Organizations documentation says both are available when **all features** are enabled. ([AWS Documentation][10])

So there is an important conceptual difference between using Organizations only for basic billing/account grouping and using it as a full governance platform.

---

# 38.43 Delegated Administrator

Now another production concept.

Bad architecture:

```text
MANAGEMENT ACCOUNT

Organizations
Security Hub administration
GuardDuty administration
Config administration
Backup administration
Every other organization service
```

This makes the management account a daily operational account.

Better:

```text
MANAGEMENT ACCOUNT
      │
      │ delegates service administration
      ▼
SECURITY ACCOUNT
      │
      ├── security service A
      ├── security service B
      └── organization security operations
```

Many AWS services integrated with Organizations support registering a member account as a **delegated administrator** so routine service administration doesn't have to occur from the management account. ([AWS Documentation][12])

---

# 38.44 Delegated Administrator mental model

```text
MANAGEMENT ACCOUNT

owns organization authority
       │
       │ delegate service
       ▼

SECURITY ACCOUNT

administers Service X
across organization
```

The security account does **not** become:

```text
the AWS Organizations management account.
```

It becomes:

```text
delegated administrator
for a specific integrated service.
```

Important distinction.

---

# 38.45 Why delegated administration matters

It improves:

```text
separation of duties

management-account protection

operational delegation

security ownership
```

Example:

```text
Cloud Platform Team
owns Organizations


Security Team
owns organization-wide
security service administration
```

Without everyone working inside the highest-privileged management account.

---

# 38.46 IAM Identity Center preview

Now imagine:

```text
500 employees
×
50 AWS accounts.
```

You don't want to manually create:

```text
vivek-user
john-user
alice-user
...
```

inside every AWS account.

Instead:

# IAM Identity Center

provides centralized workforce access to multiple AWS accounts.

Concept:

```text
Corporate User / Group
       │
       ▼
IAM Identity Center
       │
       ▼
Permission Set
       │
       ├── Account A
       ├── Account B
       └── Account C
```

AWS Identity Center supports defining permission sets centrally and assigning users/groups to multiple AWS accounts in the organization. ([AWS Documentation][13])

We'll dedicate Part 4 to this.

---

# 38.47 Permission Set preview

Think:

```text
Permission Set:
ReadOnly

Assigned:
Developers
      │
      ▼
Production accounts
```

and:

```text
Permission Set:
Administrator

Assigned:
PlatformEngineering
      │
      ▼
Dev accounts
```

One user can have:

```text
different access
in different accounts.
```

That's much cleaner than thousands of individually maintained IAM users.

---

# 38.48 Control Tower preview

AWS Organizations gives us:

```text
hierarchy
accounts
OUs
policies
service integration
```

Then what does:

# AWS Control Tower

do?

Think:

> **Control Tower provides an opinionated managed landing-zone and governance layer on top of a multi-account AWS environment.**

It helps establish and govern a multi-account landing zone and includes mechanisms such as shared accounts, controls, and Account Factory. ([AWS Documentation][14])

---

# 38.49 Organizations vs Control Tower

This distinction must become permanent.

## AWS Organizations

```text
account hierarchy

OUs

organization policies

delegated administration

organization integration
```

## AWS Control Tower

```text
opinionated landing zone

shared-account setup

controls

governed account provisioning

drift/governance workflows
```

Control Tower uses AWS Organizations as part of its underlying multi-account foundation. Existing organizations can also be used when establishing a Control Tower landing zone. ([AWS Documentation][7])

---

# 38.50 Control Tower shared accounts

A standard Control Tower landing zone includes shared accounts such as:

```text
Management Account

Log Archive Account

Audit Account
```

The Log Archive and Audit accounts typically sit in the Security OU. ([AWS Documentation][7])

Architecture:

```text
AWS CONTROL TOWER LANDING ZONE
│
├── Management Account
│
└── Security OU
    │
    ├── Log Archive
    └── Audit
```

Then additional workload OUs/accounts are enrolled under governance.

---

# 38.51 Control Tower Controls

Historically you'll hear:

```text
Guardrails
```

Modern terminology:

```text
Controls.
```

Control Tower currently has three enforcement/assessment types:

```text
Preventive

Detective

Proactive
```

and guidance categories such as mandatory, strongly recommended, and elective. ([AWS Documentation][14])

---

# 38.52 Preventive control

Think:

# **STOP it from happening.**

Example conceptually:

```text
User tries forbidden API action
          │
          ▼
Preventive control
          │
          X
        denied
```

Control Tower implements preventive controls using organization authorization-policy mechanisms including SCPs and, for applicable controls, RCPs. ([AWS Documentation][15])

---

# 38.53 Detective control

Think:

# **Let AWS observe whether the resource became non-compliant.**

Flow:

```text
Resource created
      │
      ▼
AWS Config-based check
      │
      ├── COMPLIANT
      └── NON_COMPLIANT
```

Current Control Tower detective controls are implemented with AWS Config rules; AWS updated these to service-linked Config rules for newer deployments in 2025. ([AWS Documentation][15])

---

# 38.54 Proactive control

Think:

# **Evaluate infrastructure before provisioning completes.**

Concept:

```text
CloudFormation deployment
        │
        ▼
Proactive control
        │
        ├── valid
        │    ↓
        │  deploy
        │
        └── invalid
             X
```

Control Tower implements proactive controls using CloudFormation hooks. ([AWS Documentation][15])

---

# 38.55 Never-forget control types

```text
PREVENTIVE
=
BLOCK


DETECTIVE
=
DETECT


PROACTIVE
=
CHECK BEFORE PROVISIONING
```

Simple.

---

# 38.56 Account Factory

Enterprise:

```text
Engineer:
"We need a new Payments QA account."
```

Bad:

```text
Someone manually signs up
for an AWS account.

Random email.

No baseline.

No tags.

No network.

No governance.
```

Better:

```text
Account Request
      │
      ▼
Account Factory
      │
      ▼
Governed AWS Account
```

AWS Control Tower Account Factory provisions and manages member accounts inside a Control Tower landing zone. ([AWS Documentation][16])

---

# 38.57 Account vending mental model

Account creation becomes:

```text
REQUEST

Account Name:
payments-prod

OU:
Production

Owner:
Payments Team

Region:
approved list

       │
       ▼

AUTOMATION

       │
       ▼

NEW ACCOUNT

governance baseline
identity access
logging
security
networking/customization
```

This is the beginning of:

# Cloud platform engineering.

---

# 38.58 Account Factory for Terraform — AFT

Because we're learning production DevOps, this matters.

# AFT

stands for:

# Account Factory for Terraform.

AWS documents AFT as a Terraform-based pipeline for provisioning and customizing accounts governed by AWS Control Tower. ([AWS Documentation][17])

Mental model:

```text
Git
 │
 ▼
Terraform account request
 │
 ▼
AFT pipeline
 │
 ▼
Control Tower
 │
 ▼
AWS Account
 │
 ▼
customizations
```

Later we'll build this.

---

# 38.59 Production multi-account architecture

Combine everything we've learned:

```text
                            AWS ORGANIZATION

                         MANAGEMENT ACCOUNT
                                │
                                ▼
                              ROOT
                                │
       ┌────────────────────────┼─────────────────────────┐
       │                        │                         │
       ▼                        ▼                         ▼

   SECURITY OU           INFRASTRUCTURE OU            WORKLOADS OU
       │                        │                         │
   ┌───┴────┐             ┌─────┼─────┐          ┌──────┴────────┐
   ▼        ▼             ▼     ▼     ▼          ▼               ▼

 Audit     Log          Network Shared Platform    Production      NonProd
Account   Archive       Account Services Account      OU             OU
                                                    │               │
                                              ┌─────┼─────┐     ┌───┼────┐
                                              ▼     ▼     ▼     ▼   ▼    ▼
                                            Pay   Orders Data   Dev QA Sandbox
                                            Prod   Prod   Prod
```

Now overlay governance:

```text
Organizations
     │
     ├── SCPs
     ├── RCPs
     ├── Delegated Admin
     │
     ▼
Control Tower
     │
     ├── Controls
     ├── Account Factory
     ├── Audit Account
     └── Log Archive
     │
     ▼
IAM Identity Center
     │
     └── workforce access
```

That's the enterprise AWS control plane.

---

# 38.60 How this connects to Lesson 36

Lesson 36 gave us:

```text
NETWORK ACCOUNT
      │
      ▼
Transit Gateway
      │
 ┌────┼─────────┐
 ▼    ▼         ▼
Prod Dev     Shared
```

Lesson 38 now explains:

```text
WHY
the Network Account exists.

WHO
owns it.

HOW
workload accounts are organized.

HOW
central governance stops workloads
from bypassing architecture.
```

Networking alone doesn't create organizational governance.

---

# 38.61 How this connects to Lesson 37

Lesson 37 gave us:

```text
Mumbai
  │
  ▼
Singapore DR
```

In a large enterprise, those resources may span:

```text
Network Account

Security Account

Application Account

Backup Account

DNS/Shared Services Account
```

So Multi-Region DR also depends on:

```text
cross-account access

centralized logging

delegated administration

guardrails

identity
```

Lesson 38 provides that governance foundation.

---

# 38.62 Control plane vs data plane

Another useful mental model.

### Data plane

Resources actually serving workloads:

```text
EC2

ECS

RDS

S3

VPC

ALB
```

### Governance/control plane

Things deciding:

```text
who may create what

where

under which guardrails

with which identities

with which audit trail
```

Examples:

```text
Organizations

Control Tower

IAM Identity Center

SCPs

RCPs
```

A production AWS platform needs both.

---

# 38.63 Example policy question

Requirement:

> Developers may be administrators in Dev, but they must never use unapproved Regions.

Don't create 50 different IAM policies manually.

Instead architect:

```text
Developer
   │
   ▼
IAM Identity Center
Admin permission in Dev
   │
   ▼
Dev Account

BUT

Organization Region SCP
   │
   ▼
unapproved Region API
DENIED
```

This beautifully demonstrates:

```text
IAM permission
+
Organization guardrail.
```

---

# 38.64 Example security requirement

Requirement:

> Nobody in workload accounts should make organization-controlled S3 resources publicly/external accessible beyond defined organization rules.

Potential control layers:

```text
RCP

SCP

S3 Block Public Access

resource policies

Control Tower controls

AWS Config
```

The correct architecture often uses multiple layers.

Never expect one policy mechanism to solve every security problem.

---

# 38.65 IAM vs SCP vs RCP

Memorize:

| Mechanism           | Main mental question                                            |
| ------------------- | --------------------------------------------------------------- |
| IAM identity policy | What is this principal granted?                                 |
| Resource policy     | Who may access this resource?                                   |
| Permission boundary | What is the max an IAM principal can receive?                   |
| SCP                 | What is the organization max for principals in this account/OU? |
| RCP                 | What is the organization max for access accepted by resources?  |

AWS Organizations currently categorizes SCPs as principal-centric organization authorization policies and RCPs as resource-centric controls. ([AWS Documentation][11])

We will do the complete IAM policy-evaluation flow in Part 2.

---

# 38.66 Management Account anti-pattern

Never do:

```text
All DevOps engineers
=
AdministratorAccess
in management account
```

for routine work.

Better:

```text
normal operations
      │
      ▼
member/delegated accounts


rare organization administration
      │
      ▼
management account
```

Treat management-account access like:

```text
break-glass/high privilege.
```

AWS recommends keeping use of the management account limited to functions that require it. ([AWS Documentation][4])

---

# 38.67 Consolidated billing misconception

Organizations can centralize account relationships and billing administration, but do not conclude:

```text
"All accounts are therefore
one security boundary."
```

They remain distinct AWS accounts.

That is precisely why multi-account isolation remains valuable.

---

# 38.68 Another beginner trap

> "If accounts are in the same OU, they can access each other."

No.

OU membership does not grant network or IAM access.

If:

```text
Payments Account
```

needs S3 in:

```text
Shared Services Account
```

you still need deliberate mechanisms such as:

```text
resource policy

role assumption

network route

service endpoint

RAM sharing
```

depending on the service.

---

# 38.69 Another trap

> "SCP AdministratorAccess grants administrator."

No.

Again:

```text
SCP DOES NOT GRANT.
```

IAM still must grant.

This appears constantly in interviews.

---

# 38.70 Another trap

> "SCP protects the management account."

No.

Organizations SCPs don't restrict roles/users in the management account. ([AWS Documentation][4])

So management-account security relies strongly on:

```text
access discipline

identity controls

MFA

monitoring

minimal usage
```

---

# 38.71 Another trap

> "Control Tower replaces Organizations."

No.

Think:

```text
Organizations
=
foundation


Control Tower
=
managed landing-zone/
governance framework
built around that
multi-account foundation
```

AWS Control Tower uses the organization's management account and AWS Organizations hierarchy rather than creating a separate parallel account system. ([AWS Documentation][7])

---

# 38.72 Another trap

> "Preventive and detective controls are the same."

No.

```text
Preventive:
action prevented


Detective:
resource/action can exist
and compliance evaluation
detects violation
```

Current Control Tower implementation uses SCP/RCP-based preventive controls and AWS Config-based detective controls. ([AWS Documentation][15])

---

# 38.73 Another trap

> "Every employee needs IAM users in every account."

No.

For workforce access across an organization, AWS recommends IAM Identity Center multi-account access patterns, where permission sets can be assigned centrally to users/groups across accounts. ([AWS Documentation][18])

IAM users still have specific use cases, but creating thousands of long-lived per-account workforce users is not the modern enterprise default.

---

# 38.74 Architecture interview scenario

Interviewer:

> You have 50 AWS accounts across production, development, security, networking, and shared services. How would you govern them?

Strong answer:

> I would place the accounts in AWS Organizations and design OUs around governance requirements rather than merely mirroring the corporate org chart. I would isolate security/logging, infrastructure, production, non-production, and sandbox accounts where appropriate. I would use SCPs to define organization-level maximum permissions for principals and evaluate RCPs where resource-centric organization controls are required. I would minimize use of the management account and delegate supported service administration to dedicated member accounts. Workforce access would be centralized with IAM Identity Center. For a standardized landing-zone operating model, I would evaluate AWS Control Tower for shared Audit/Log Archive accounts, controls, governed account provisioning, and Account Factory. ([AWS Documentation][8])

That's a strong production answer.

---

# 38.75 Why account strategy matters before Terraform

Suppose you begin Terraform immediately:

```text
module "vpc" {}

module "eks" {}

module "rds" {}
```

But haven't decided:

```text
Which account owns VPC?

Which account owns logs?

Which account owns DNS?

Which account owns security tooling?

Which account owns backups?

Which account owns CI/CD?
```

Then the architecture is incomplete.

Correct order:

```text
BUSINESS / SECURITY MODEL
        │
        ▼
ACCOUNT STRATEGY
        │
        ▼
OU STRATEGY
        │
        ▼
GOVERNANCE
        │
        ▼
IDENTITY
        │
        ▼
NETWORK
        │
        ▼
WORKLOAD
        │
        ▼
TERRAFORM
```

Terraform should encode architecture—not invent it accidentally.

---

# 38.76 Never-forget five layers

```text
ORGANIZATION
=
collection of AWS accounts


ROOT
=
top organizational container


OU
=
group of accounts
with similar governance


ACCOUNT
=
security/resource ownership
boundary


POLICIES
=
organization-wide guardrails
```

---

# 38.77 Never-forget SCP

```text
SCP
=
MAXIMUM PERMISSIONS
for principals

NOT
granted permissions.
```

---

# 38.78 Never-forget RCP

```text
RCP
=
RESOURCE-CENTRIC
organization guardrail.
```

---

# 38.79 Never-forget delegated administration

```text
MANAGEMENT ACCOUNT
      │
      │ delegate service
      ▼
SECURITY / PLATFORM ACCOUNT
      │
      ▼
organization-wide service administration
```

Goal:

```text
reduce daily dependence
on management account.
```

---

# 38.80 Never-forget Control Tower

```text
AWS ORGANIZATIONS
=
multi-account governance foundation


CONTROL TOWER
=
managed landing-zone
and governance experience


IAM IDENTITY CENTER
=
central workforce access


ACCOUNT FACTORY
=
governed account provisioning
```

---

# 38.81 Part 1 final architecture

```text
                     ENTERPRISE AWS

                           │
                           ▼
                   AWS ORGANIZATIONS

                           │
                    Management Account
                           │
                           ▼
                          ROOT
                           │
       ┌───────────────────┼────────────────────┐
       │                   │                    │
       ▼                   ▼                    ▼

   SECURITY OU      INFRASTRUCTURE OU       WORKLOADS OU
       │                   │                    │
  ┌────┴────┐       ┌──────┼──────┐       ┌────┴────────┐
  ▼         ▼       ▼      ▼      ▼       ▼             ▼

Audit      Logs   Network Shared Platform Production   NonProd
                                         │             │
                                       Apps        Dev/QA/Sandbox

                           │
             ┌─────────────┼──────────────┐
             ▼             ▼              ▼

            SCP           RCP       Delegated Admin
             │             │              │
             └─────────────┼──────────────┘
                           ▼
                      GOVERNANCE

                           │
                           ▼
                     CONTROL TOWER
                           │
            ┌──────────────┼─────────────┐
            ▼              ▼             ▼
         Controls      Account Factory  Landing Zone

                           │
                           ▼
                  IAM IDENTITY CENTER

                           │
                           ▼
                PEOPLE → RIGHT ACCOUNTS
                         → RIGHT ROLES
```

That is the fundamental enterprise AWS governance mental model.

---

# 38.82 Part 1 checkpoint

You should now be able to explain:

```text
✓ Why enterprises use multiple AWS accounts

✓ Account vs VPC isolation

✓ AWS Organizations

✓ Organization Root

✓ Management Account

✓ Member Accounts

✓ Organizational Units

✓ Nested OUs

✓ Security OU

✓ Log Archive Account

✓ Audit/Security Account

✓ Infrastructure OU

✓ Network Account

✓ Shared Services Account

✓ Production vs NonProduction

✓ SCP mental model

✓ Why SCP doesn't grant permission

✓ Management-account SCP exception

✓ RCP mental model

✓ SCP vs RCP

✓ Delegated Administrator

✓ IAM Identity Center role

✓ Organizations vs Control Tower

✓ Control Tower controls

✓ Account Factory

✓ AFT preview
```

---

# ✅ Lesson 38 — Part 1 Complete

```text
Part 1
Enterprise Multi-Account Architecture
+ AWS Organizations                     ✓

Part 2
SCP + RCP + IAM Policy Evaluation       NEXT

Part 3
AWS Control Tower Landing Zone

Part 4
IAM Identity Center

Part 5
Central Security + Logging

Part 6
Network + Shared Services Accounts

Part 7
Account Factory + AFT

Part 8
Delegated Administration

Part 9
Terraform Governance Capstone

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 2

## SCPs, RCPs & AWS Permission Evaluation — Deep Dive

This next part will answer one of the hardest AWS IAM/governance questions:

> **A user has `AdministratorAccess`, but AWS still returns `AccessDenied`. Why?**

We'll build the complete permission-evaluation mental model:

```text
Request
  │
  ▼
Identity Policy
  │
Permission Boundary
  │
Session Policy
  │
SCP
  │
RCP
  │
Resource Policy
  │
Explicit Deny?
  │
  ▼
ALLOW / DENY
```

Then we'll implement production guardrails such as:

```text
Deny unapproved Regions

Prevent leaving the Organization

Protect CloudTrail

Protect GuardDuty/Security Hub

Restrict IAM privilege escalation

Prevent public resources

Control external resource access

Prod vs NonProd SCPs

Break-glass exceptions

aws:PrincipalArn conditions

aws:PrincipalOrgID

aws:RequestedRegion

NotAction patterns

SCP debugging with CloudTrail
and IAM simulation
```

That will take us from **"I know what an SCP is"** to **"I can actually troubleshoot enterprise AWS permission failures."**

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_ous_best_practices.html?utm_source=chatgpt.com "Best practices for managing organizational units (OUs) with ..."
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html?utm_source=chatgpt.com "What is AWS Organizations? - AWS ..."
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_ous.html?utm_source=chatgpt.com "Managing organizational units (OUs) with AWS ..."
[4]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html?utm_source=chatgpt.com "Delegated administrator for AWS Organizations"
[5]: https://docs.aws.amazon.com/controltower/latest/userguide/what-shared.html?utm_source=chatgpt.com "What are the shared accounts? - AWS Control Tower"
[6]: https://docs.aws.amazon.com/controltower/latest/userguide/logging-and-monitoring.html?utm_source=chatgpt.com "Logging and monitoring in AWS Control Tower"
[7]: https://docs.aws.amazon.com/controltower/latest/userguide/planning-your-deployment.html?utm_source=chatgpt.com "Plan your AWS Control Tower landing zone"
[8]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html?utm_source=chatgpt.com "Service control policy examples - AWS Organizations"
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[11]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html?utm_source=chatgpt.com "Authorization policies in AWS Organizations"
[12]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with ..."
[13]: https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-accounts.html?utm_source=chatgpt.com "Configure access to AWS accounts - AWS IAM Identity Center"
[14]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS ..."
[15]: https://docs.aws.amazon.com/controltower/latest/userguide/how-controls-work.html?utm_source=chatgpt.com "How controls work - AWS Control Tower"
[16]: https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html?utm_source=chatgpt.com "Provision and manage accounts with Account Factory"
[17]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html?utm_source=chatgpt.com "Overview of AWS Control Tower Account Factory for ..."
[18]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
