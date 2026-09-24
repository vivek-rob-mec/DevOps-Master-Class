# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 3: AWS Control Tower & Enterprise Landing Zone — Deep Dive

We already know:

```text
AWS Organizations
        │
        ├── Accounts
        ├── OUs
        ├── SCPs
        ├── RCPs
        └── Delegated Administration
```

Now comes the next question:

> **How do we turn those raw multi-account building blocks into a standardized, continuously governed enterprise AWS environment?**

That is where:

# **AWS Control Tower**

enters.

AWS describes a Control Tower **landing zone** as a well-architected multi-account environment that orchestrates several AWS services to establish and maintain governance across accounts. ([AWS Documentation][1])

---

# 38.181 Organizations gives building blocks; Control Tower gives an operating model

Think:

```text
AWS ORGANIZATIONS

"I can create:

accounts
OUs
SCPs
RCPs
delegated admins"
```

versus:

```text
AWS CONTROL TOWER

"I want:

a landing zone
shared security accounts
central logging
account enrollment
controls
baselines
drift detection
governed account provisioning"
```

Control Tower uses AWS Organizations underneath rather than replacing it. ([AWS Documentation][2])

---

# 38.182 The fundamental Control Tower architecture

```text
                       AWS CONTROL TOWER

                           LANDING ZONE
                                │
                                ▼
                      MANAGEMENT ACCOUNT
                                │
                                ▼
                          AWS ORGANIZATION
                                │
               ┌────────────────┼─────────────────┐
               │                │                 │
               ▼                ▼                 ▼

          Security OU     Workloads OU     Infrastructure OU
               │
          ┌────┴────┐
          ▼         ▼
       Audit     Log Archive

                                │
                                ▼
                           GOVERNANCE
                                │
             ┌──────────────────┼─────────────────┐
             ▼                  ▼                 ▼
         Preventive          Detective         Proactive
          Controls            Controls          Controls

                                │
                                ▼
                         Account Factory
                                │
                                ▼
                         Governed Accounts
```

The shared Audit and Log Archive accounts are foundational Control Tower components, while additional workload/infrastructure OUs are designed according to your organization. ([AWS Documentation][3])

---

# 38.183 What exactly is a Landing Zone?

A **landing zone** is not:

```text
one VPC
```

or:

```text
one AWS account
```

or:

```text
one Terraform module.
```

It is the foundational multi-account environment into which workloads "land."

Think:

```text
LANDING ZONE

=
Account structure

+
Identity

+
Security boundaries

+
Logging

+
Governance

+
Account provisioning

+
Regional governance
```

AWS Control Tower acts as an orchestration layer over several AWS services to maintain this multi-account operating environment. ([AWS Documentation][4])

---

# 38.184 Landing Zone is the cloud foundation, not the application

Your application architecture might be:

```text
ALB
 ↓
ECS
 ↓
Aurora
```

But that application lives **inside** a platform:

```text
                   LANDING ZONE

               Production Account
                      │
                      ▼
                     VPC
                      │
                      ▼
                     ALB
                      │
                     ECS
                      │
                   Aurora
```

The landing zone answers:

```text
Which account?

Which OU?

Which Regions?

Which security controls?

Which logs?

Which workforce permissions?

Which organization policies?
```

The workload architecture answers:

```text
How does the application run?
```

Keep those layers separate.

---

# 38.185 Control Tower Home Region

One of the first Control Tower setup decisions is the:

# **Home Region**

The Region from which you establish the landing zone becomes the Control Tower home Region, and some Control Tower resources are provisioned there. AWS currently states that after deployment, the home Region cannot simply be changed as a normal setting. ([AWS Documentation][5])

Never treat this choice casually.

---

# 38.186 For our architecture

Because our preferred main workload Region has been:

```text
ap-south-1
Mumbai
```

a hypothetical enterprise design might evaluate:

```text
Control Tower Home Region
=
ap-south-1
```

But this should be an organization-level architectural decision, not merely:

```text
"Most of my EC2 happens to be there."
```

You would evaluate:

```text
organization operations

security tooling

regulatory requirements

regional service availability

future workload footprint
```

before establishing the landing zone.

---

# 38.187 Home Region ≠ only allowed workload Region

Important.

Suppose:

```text
Home Region
=
ap-south-1
```

You can still govern additional supported Regions such as:

```text
ap-southeast-1
```

for Multi-Region workloads.

Control Tower lets administrators add and remove additional governed Regions after landing-zone creation even though the home Region itself is fixed. ([AWS Documentation][5])

---

# 38.188 Home Region vs Governed Regions

Memorize:

```text
HOME REGION
=
Control Tower's primary
landing-zone Region


GOVERNED REGIONS
=
Regions in which applicable
Control Tower governance
is extended
```

For our DR architecture, conceptually:

```text
Home Region
ap-south-1

Additional Governed Region
ap-southeast-1
```

This fits nicely with the Mumbai → Singapore DR architecture we built earlier.

---

# 38.189 Critical trap — ungoverned does not mean disabled

Suppose you remove:

```text
eu-west-1
```

from Control Tower governance.

That does **not** necessarily mean users are technically unable to create resources there.

AWS explicitly states that if a Region is not governed by Control Tower, workloads may still be deployed there; they simply remain outside that Control Tower regional governance. ([AWS Documentation][5])

So:

```text
UNGOVERNED REGION
≠
FORBIDDEN REGION
```

---

# 38.190 If you need to block Regions

Then you need something such as:

```text
Region deny control

or

organization SCP
```

rather than merely excluding the Region from the governed-region list.

Control Tower has a landing-zone Region deny control that can restrict access to non-governed Regions for OUs using the Control Tower baseline. ([AWS Documentation][6])

---

# 38.191 Home Region is hard to change

AWS documentation is deliberately strong here.

Normal expectation:

```text
Choose Home Region
       │
       ▼
Deploy Landing Zone
       │
       ▼
Home Region effectively fixed
```

Changing it later is not a normal edit operation; AWS documents decommissioning/support involvement for such a change and recommends against treating it as a routine migration. ([AWS Documentation][7])

Therefore:

> **Landing-zone Region selection is architecture, not a console preference.**

---

# 38.192 Shared Accounts

Control Tower landing zones use two especially important security accounts:

```text
Security OU
│
├── Log Archive
└── Audit
```

These are called:

# Shared Accounts

AWS can create them during landing-zone setup, or you have a one-time setup option to supply appropriate existing accounts. ([AWS Documentation][8])

---

# 38.193 Log Archive Account

Its primary purpose:

> **Centralize copies of audit/configuration logs away from ordinary workload accounts.**

Architecture:

```text
Account A ─────┐
Account B ─────┤
Account C ─────┤
Production ────┤
Dev ───────────┘
               │
               ▼
          LOG ARCHIVE
            ACCOUNT
               │
               ▼
               S3
```

Control Tower's Log Archive account contains centralized S3 storage for CloudTrail and AWS Config log data from landing-zone accounts. ([AWS Documentation][3])

---

# 38.194 Why separate logging?

Imagine:

```text
Payments Account compromised
```

If the attacker also controls:

```text
the only audit-log bucket
```

they may try to damage evidence.

Instead:

```text
Payments account
       │
       │ centralized delivery
       ▼
Log Archive account
```

Now application administration and audit-log ownership are separated.

This is:

# Separation of duties.

---

# 38.195 Organization-wide CloudTrail

Modern Control Tower landing zones use a:

# CloudTrail organization trail

AWS documents that Control Tower creates an organization-level trail that captures events for the management account and organization member accounts, rather than requiring an independently managed trail in every member account. ([AWS Documentation][9])

Mental flow:

```text
All Organization Accounts
        │
        ▼
CloudTrail Organization Trail
        │
        ▼
Log Archive
```

---

# 38.196 Why organization trail matters

Without centralized design:

```text
Account A trail
Account B trail
Account C trail
Account D trail
```

You must manage them separately.

With organization-level logging:

```text
Organization
     │
     ▼
Central trail
     │
     ▼
Central audit storage
```

Much easier to reason about at enterprise scale. ([AWS Documentation][9])

---

# 38.197 Existing CloudTrail warning

Suppose an existing account already has its own trail.

Then you enroll it into Control Tower.

Now you may have:

```text
existing account trail

+

Control Tower organization trail
```

which can create duplicated event delivery/cost depending on configuration. AWS explicitly warns about this during account enrollment. ([AWS Documentation][10])

So before enrollment:

```text
inventory existing CloudTrail
```

rather than blindly adding another logging layer.

---

# 38.198 Audit Account

The second major shared account is:

# Audit Account

Conceptually:

```text
                     AUDIT ACCOUNT

                  Security / Compliance
                          Teams
                            │
             ┌──────────────┼─────────────┐
             ▼              ▼             ▼

         Prod Account    Dev Account    Network Account
          audit role      audit role      audit role
```

AWS describes this account as the security/compliance access location for auditing and certain organization-wide security operations. ([AWS Documentation][3])

---

# 38.199 Audit vs Log Archive

Never confuse them.

```text
LOG ARCHIVE

"Where does centralized
audit/configuration evidence live?"


AUDIT

"Where do security/compliance
operators perform cross-account
audit/security operations?"
```

Simple mental shortcut:

```text
LOG ARCHIVE
=
EVIDENCE


AUDIT
=
INVESTIGATOR
```

---

# 38.200 Do not move shared accounts casually

AWS explicitly warns not to move/delete the required shared accounts arbitrarily after landing-zone establishment. Moving them outside their expected foundational structure creates Control Tower drift that requires remediation. ([AWS Documentation][8])

Bad:

```text
Security OU
   │
Log Archive

       ↓

Engineer moves it to
Production OU
```

Result:

```text
Control Tower drift
```

---

# 38.201 Governed OU concept

An OU created purely in AWS Organizations may exist as:

```text
Production OU
```

but Control Tower may not yet govern it.

Control Tower terminology commonly distinguishes:

```text
UNREGISTERED OU
```

from:

```text
REGISTERED OU
```

Registering an existing OU extends Control Tower governance to it. ([AWS Documentation][11])

---

# 38.202 Registered OU

Concept:

```text
AWS Organizations

Production OU
     │
     ▼
Register with Control Tower
     │
     ▼
Control Tower baseline
     │
     ▼
Governance applied
```

When an OU is registered, AWS Control Tower enrolls its member accounts and applies the applicable governance configuration/controls. ([AWS Documentation][12])

---

# 38.203 Enrolled Account

OU state:

```text
Registered
```

Account state:

```text
Enrolled
```

Mental shortcut:

```text
OU
→ REGISTER


ACCOUNT
→ ENROLL
```

Very useful terminology.

---

# 38.204 Example

Before:

```text
AWS Organizations

Production OU
│
├── Payments
├── Orders
└── Customer
```

But Control Tower:

```text
OU = unregistered

accounts = unmanaged by
Control Tower baseline
```

After registering:

```text
Production OU
REGISTERED

Payments
ENROLLED

Orders
ENROLLED

Customer
ENROLLED
```

and Control Tower governance applies according to that OU's enabled configuration. ([AWS Documentation][12])

---

# 38.205 Important 2026 baseline model

Modern Control Tower uses:

# Baselines

A baseline is a group of specific resources/configurations applied to a target, most commonly an OU.

For example:

```text
AWSControlTowerBaseline
```

is the baseline used to bring an OU under standard Control Tower governance. ([AWS Documentation][13])

---

# 38.206 Baseline mental model

Think:

```text
OU
 │
 │ enable baseline
 ▼

┌─────────────────────────┐
│ Governance foundation   │
│                         │
│ roles                   │
│ configuration           │
│ controls integration    │
│ account inheritance     │
└─────────────────────────┘
```

Then member accounts inherit governance configuration from that OU baseline.

---

# 38.207 Baseline ≠ Control

This is an important modern distinction.

```text
BASELINE

establishes a foundational
governance configuration
for a target


CONTROL

expresses one specific
governance rule
```

Example:

```text
Baseline:
register Production OU


Control:
prevent public RDS snapshots
```

Do not use those terms interchangeably.

---

# 38.208 Control Tower 4.x-era model

Current Control Tower documentation notes that in newer landing-zone versions, controls can be enabled directly on an OU, while detective controls require the appropriate AWS Config recording foundation. Registering an OU enables the broader `AWSControlTowerBaseline`. ([AWS Documentation][12])

The important conceptual evolution is:

```text
BASELINE
and
CONTROL
```

are now more explicit resources/configuration layers.

---

# 38.209 Three Control Types

Control Tower currently categorizes controls into:

```text
PREVENTIVE

DETECTIVE

PROACTIVE
```

These are implementation types—not severity levels. ([AWS Documentation][14])

---

# 38.210 Preventive Control

Mental model:

# BLOCK IT

```text
User/API
   │
   ▼
Forbidden action
   │
   ▼
Preventive Control
   │
   X
 DENIED
```

Preventive controls operate through organization authorization policies such as SCPs and, for applicable controls, RCPs. ([AWS Documentation][15])

---

# 38.211 Example preventive intent

Requirement:

> Production accounts must not disable organization-managed logging.

Desired outcome:

```text
API call
Delete critical logging configuration
        │
        ▼
Preventive Control
        │
        X
      DENY
```

Nothing needs to be remediated afterward because the prohibited operation never succeeded.

---

# 38.212 Detective Control

Mental model:

# DETECT IT AFTER/AS IT EXISTS

```text
Resource
created/configured
      │
      ▼
AWS Config evaluation
      │
      ├── COMPLIANT
      └── NON_COMPLIANT
```

Control Tower detective controls use AWS Config-based evaluation. ([AWS Documentation][13])

---

# 38.213 Example detective intent

Suppose policy says:

```text
EBS volumes must be encrypted.
```

A detective control checks the resource posture and reports:

```text
COMPLIANT
```

or:

```text
NON_COMPLIANT.
```

Notice:

```text
DETECTIVE
```

does not inherently mean:

```text
AUTOMATICALLY FIXED.
```

Detection and remediation are separate concepts unless an additional remediation workflow exists.

---

# 38.214 Proactive Control

Mental model:

# CHECK BEFORE PROVISIONING

```text
CloudFormation resource
        │
        ▼
Proactive Control
        │
    compliant?
      /    \
    YES     NO
     │       │
 deploy      X
```

AWS Control Tower proactive controls evaluate supported resources in CloudFormation before provisioning and use CloudFormation hooks. ([AWS Documentation][14])

---

# 38.215 The permanent shortcut

```text
PREVENTIVE
=
BLOCK API behavior


DETECTIVE
=
FIND NON-COMPLIANCE


PROACTIVE
=
CHECK CLOUDFORMATION
BEFORE RESOURCE CREATION
```

Never forget.

---

# 38.216 Control guidance categories

Separate from control type, AWS currently categorizes Control Tower controls by guidance such as:

```text
MANDATORY

STRONGLY RECOMMENDED

ELECTIVE
```

This indicates AWS's guidance level, not whether the implementation is preventive, detective, or proactive. ([AWS Documentation][16])

So a control has conceptually two dimensions:

```text
TYPE:
Preventive / Detective / Proactive

GUIDANCE:
Mandatory / Strongly Recommended / Elective
```

---

# 38.217 Common exam trap

Do not think:

```text
Mandatory
=
Preventive
```

or:

```text
Elective
=
Detective.
```

They're different classification axes.

---

# 38.218 Region behavior differs by control type

Current AWS behavior has an important nuance:

```text
Preventive controls
→ global policy enforcement behavior

Detective/proactive controls
→ operate only in supported
Control Tower Regions where
their underlying capabilities exist
```

AWS explicitly documents this difference. ([AWS Documentation][5])

---

# 38.219 Why this matters

Suppose you govern:

```text
ap-south-1
ap-southeast-1
```

but assume:

```text
every detective control
works identically
everywhere.
```

That may be wrong because individual controls can have Region/service dependency limitations.

AWS recommends checking the deployable Regions for each control. ([AWS Documentation][17])

---

# 38.220 Control Tower is not magic global enforcement

Always ask:

```text
What type of control?

Which Regions?

Which resource type?

What underlying service implements it?

Does this Region support that dependency?
```

That is the production mindset.

---

# 38.221 Existing AWS Organization adoption

Imagine your enterprise already has:

```text
AWS Organizations

Root
│
├── Prod OU
├── Dev OU
├── Network OU
└── Security OU
```

and later decides:

```text
We want Control Tower.
```

Does Control Tower destroy/rearrange everything?

# No.

AWS states that when Control Tower is added to an existing organization, it establishes its landing-zone structure without automatically reorganizing all pre-existing OUs and accounts. ([AWS Documentation][2])

---

# 38.222 Existing organization flow

Conceptually:

```text
EXISTING ORGANIZATION

Prod OU
Dev OU
Network OU
Security OU

       │

Enable Control Tower Landing Zone

       │
       ▼

Control Tower foundation
+
shared accounts / foundational structure

       │
       ▼

Existing OUs still exist

       │
       ▼

Register desired OUs
       │
       ▼
Enroll accounts
```

This allows gradual migration into governance.

---

# 38.223 Do not assume "visible in Control Tower" = governed

An OU created outside Control Tower can appear in the organization hierarchy but remain:

```text
UNREGISTERED
```

and therefore not receive the normal Control Tower governance baseline. ([AWS Documentation][18])

This is a very common operational misunderstanding.

---

# 38.224 Governance status matters

Possible mental states:

```text
OU

Unregistered
   ↓
Registered


Account

Unenrolled
   ↓
Enrolled
```

Always check actual governance status, not merely:

```text
"Account exists under the organization."
```

---

# 38.225 Registering an existing OU

When an existing OU is registered:

```text
Existing OU
     │
     ▼
Control Tower prechecks
     │
     ▼
baseline / governance deployment
     │
     ▼
member-account enrollment
```

Control Tower currently supports registering existing OUs containing up to 1,000 accounts. ([AWS Documentation][11])

You don't need to memorize that number for architecture interviews, but know that registration is an actual managed operation—not just attaching a label.

---

# 38.226 Enrollment can fail account-by-account

Suppose OU contains:

```text
100 accounts
```

Registration can succeed at the OU level while some member accounts encounter enrollment/precheck issues requiring remediation.

AWS surfaces account-specific precheck failures for these cases. ([AWS Documentation][19])

So:

```text
OU Registered
```

doesn't automatically mean:

```text
every child account
perfectly healthy
```

without validation.

---

# 38.227 Existing AWS Config is a classic enrollment complication

Control Tower uses AWS Config for detective governance.

If an account already has AWS Config resources/configuration, enrollment can require additional preparation because Control Tower must avoid conflicting ownership/configuration. AWS documents a specific workflow for such accounts. ([AWS Documentation][20])

This is a common brownfield challenge.

---

# 38.228 Brownfield vs Greenfield

### Greenfield

```text
No existing organization

        ↓

Control Tower

        ↓

build landing zone
from beginning
```

Easier.

---

### Brownfield

```text
Existing Organization
Existing OUs
Existing accounts
Existing CloudTrail
Existing Config
Existing IAM
Existing networks

        ↓

adopt Control Tower carefully
```

Harder.

This is why enterprise migrations require inventory and phased enrollment.

---

# 38.229 Account Factory

Now new accounts.

Instead of:

```text
AWS Console
→ manually create account
→ manually configure IAM
→ manually configure logging
→ manually configure networking
```

Control Tower provides:

# Account Factory

for governed account provisioning. ([AWS Documentation][21])

---

# 38.230 Account Factory mental model

```text
ACCOUNT REQUEST

Name:
payments-dev

OU:
NonProduction

Owner:
Payments Team
      │
      ▼
ACCOUNT FACTORY
      │
      ▼
AWS Organizations
creates account
      │
      ▼
Control Tower
applies governance
      │
      ▼
GOVERNED ACCOUNT
```

This is commonly called:

# Account vending.

---

# 38.231 Why "account vending"?

Developers aren't being given:

```text
random AWS root credentials
```

They request an organizationally compliant workspace:

```text
new AWS account
```

and the platform gives them one with:

```text
governance

identity

logging

baseline configuration
```

already established.

This is the beginning of internal platform engineering.

---

# 38.232 Account Factory and IAM Identity Center

Control Tower Account Factory can allow appropriate IAM Identity Center users to provision new landing-zone accounts when granted the required Account Factory permissions/groups. ([AWS Documentation][21])

Concept:

```text
Platform Engineer
       │
       ▼
IAM Identity Center
       │
       ▼
Account Factory
       │
       ▼
New governed account
```

We will go deeply into Identity Center in Part 4.

---

# 38.233 AFT preview

Standard Account Factory is useful.

But DevOps/platform teams often want:

```text
Git

Terraform

Pull Requests

CI/CD

custom account baseline

network attachment

tags

security tooling
```

That leads to:

# Account Factory for Terraform — AFT.

We'll build it deeply in Part 7.

---

# 38.234 Control Tower Drift

Now one of the biggest enterprise concepts:

# Drift

Suppose Control Tower expects:

```text
Production OU
   │
Security controls
   │
AWSControlTowerExecution role
   │
Log Archive relationship
```

An administrator manually changes/deletes some of it.

Now:

```text
ACTUAL
≠
EXPECTED
```

That's drift.

Control Tower continuously identifies several types of governance drift in its managed environment. ([AWS Documentation][22])

---

# 38.235 Drift examples

Examples include:

```text
Moving an enrolled account
to the wrong OU

Deleting required Control Tower roles

Modifying Control Tower-managed SCPs

Changing baseline configuration

Disabling trusted access

Removing shared accounts
from required structure
```

Control Tower identifies a number of these governance drift conditions and provides remediation paths. ([AWS Documentation][23])

---

# 38.236 Account move drift

Example:

```text
Production OU
│
└── Payments Account
```

Someone uses AWS Organizations directly:

```text
MoveAccount
```

and moves Payments to:

```text
Sandbox OU
```

Control Tower governance inherited from its original placement may no longer match the actual organization hierarchy.

This can create:

# Inheritance Drift.

([AWS Documentation][22])

---

# 38.237 Why direct Organizations changes can be dangerous

Remember:

```text
Organizations
and
Control Tower
```

are closely linked, but they are not the same control plane.

If administrators make arbitrary structural changes directly through Organizations without respecting Control Tower state, Control Tower can detect governance drift. AWS specifically cautions about moving enrolled accounts or OUs outside normal Control Tower workflows. ([AWS Documentation][24])

---

# 38.238 Auto-enrollment

Modern Control Tower supports an optional **auto-enrollment** mechanism for moved accounts in supported landing-zone versions.

When configured, moving an account into a registered OU can cause Control Tower to apply that OU's baseline and control inheritance automatically. ([AWS Documentation][25])

Mental model:

```text
Account
  │
Move to registered OU
  │
  ▼
Control Tower detects move
  │
  ▼
auto-enroll/remediate inheritance
```

---

# 38.239 Without auto-enrollment

A move may leave:

```text
Organization hierarchy:
new OU

Control Tower state:
old inheritance
```

Result:

```text
DRIFT
```

Then administrators may need:

```text
Update Account

Re-register OU

Reset baseline/control
```

depending on the drift type. ([AWS Documentation][26])

---

# 38.240 Drift is not one thing

AWS currently identifies categories including:

```text
Account / OU governance drift

Landing-zone drift

Control drift

Baseline inheritance drift

Control inheritance drift
```

([AWS Documentation][22])

This matters because remediation differs.

---

# 38.241 Control Drift example

Expected:

```text
Production OU

Preventive control:
enabled
```

Someone modifies the corresponding Control Tower-managed Organizations policy outside the expected workflow.

Control Tower detects that its required policy content no longer matches.

Concept:

```text
DESIRED CONTROL
      │
      X
ACTUAL SCP/RCP state
```

That's control drift.

---

# 38.242 Baseline Drift

Expected account foundation:

```text
baseline version/configuration A
```

Actual:

```text
account differs from
parent OU baseline
```

Then Control Tower can report inheritance/baseline drift. ([AWS Documentation][22])

---

# 38.243 Landing Zone Drift

Even the central landing-zone configuration can drift.

For example:

```text
trusted access
```

between Organizations and Control Tower is required so the systems remain synchronized.

AWS documents disabling that trusted access as a landing-zone drift condition. ([AWS Documentation][22])

---

# 38.244 Important limitation — Control Tower doesn't detect every possible resource drift

This is critical.

Control Tower drift detection focuses on its governance model.

AWS explicitly states that it does **not** detect every possible modification to every underlying AWS resource merely because that resource participates in the landing zone. ([AWS Documentation][22])

Therefore:

```text
Control Tower drift detection
≠
Terraform drift detection
≠
AWS Config compliance
≠
every-resource audit
```

Different layers.

---

# 38.245 Drift-remediation toolbox

Depending on the problem:

```text
Re-register OU

Update account

Reset enabled control

Reset enabled baseline

Reset landing zone
```

may be appropriate.

AWS documents these remediation paths for different categories of governance drift. ([AWS Documentation][26])

---

# 38.246 Re-register OU mental model

```text
Registered OU
       │
       │ drift
       ▼
governance mismatch
       │
       ▼
RE-REGISTER
       │
       ▼
Control Tower
reapplies expected governance
```

This is not equivalent to:

```text
delete OU
create it again.
```

---

# 38.247 Control Tower versions

The landing zone itself has a:

```text
Landing Zone Version
```

and AWS periodically introduces updated versions/capabilities.

Control Tower exposes landing-zone updates, and administrators need to deliberately update their landing zone when necessary. ([AWS Documentation][27])

Important operational rule:

```text
Control Tower
is not
"configure once and never maintain."
```

---

# 38.248 Landing-zone update vs Account update

Different scopes:

```text
LANDING ZONE UPDATE
=
update central Control Tower foundation


OU RE-REGISTRATION
=
refresh governance for OU/accounts


ACCOUNT UPDATE
=
refresh an individual enrolled account
```

Don't confuse them.

---

# 38.249 Adding a new governed Region requires follow-through

Suppose landing zone originally governs:

```text
ap-south-1
```

and you later add:

```text
ap-southeast-1
```

Updating the landing zone extends Control Tower's regional setup, but existing accounts/OUs must then be updated/re-registered for applicable regional detective governance to become active there. AWS explicitly documents this sequence. ([AWS Documentation][5])

So:

```text
Landing Zone Region added
```

is not always the entire migration.

---

# 38.250 Multi-Region governance flow

For our Mumbai/Singapore architecture:

```text
Initial:

Home:
ap-south-1


Later:
add ap-southeast-1
       │
       ▼
Update landing zone
       │
       ▼
Re-register/update OUs/accounts
       │
       ▼
Regional governance extended
```

That is the correct conceptual workflow. ([AWS Documentation][5])

---

# 38.251 Region deny vs Region governance

Permanent distinction:

```text
GOVERN REGION
=
apply Control Tower's applicable
regional governance


DENY REGION
=
prevent workload/API usage
according to the deny control
```

These are not the same operation.

---

# 38.252 Control Tower and AWS Config

Detective controls fundamentally depend on:

```text
AWS Config
```

to record/evaluate resource configurations. ([AWS Documentation][13])

Think:

```text
Resource changes
      │
      ▼
AWS Config
      │
      ▼
Detective Control
      │
      ▼
COMPLIANT / NON_COMPLIANT
```

---

# 38.253 Control Tower and CloudFormation

Proactive controls fundamentally use:

```text
CloudFormation Hooks
```

to evaluate supported CloudFormation-provisioned resources before deployment. ([AWS Documentation][14])

Flow:

```text
CloudFormation Template
        │
        ▼
Hook evaluation
        │
        ├── PASS
        │     ↓
        │   CREATE
        │
        └── FAIL
              X
```

---

# 38.254 But what about Terraform?

Important question.

If Terraform directly calls AWS APIs:

```text
Terraform
   │
   ▼
AWS API
```

a CloudFormation-hook-based **proactive** control does not magically transform Terraform into CloudFormation.

However, organization-level **preventive** policies can still constrain those underlying AWS API calls regardless of whether they originate from Terraform, console, CLI, or SDK.

Mental shortcut:

```text
Preventive organizational control
→ API guardrail


Proactive CloudFormation control
→ CloudFormation provisioning path
```

This is why policy architecture must consider the actual provisioning mechanism. ([AWS Documentation][14])

---

# 38.255 Terraform must not fight Control Tower

Bad architecture:

```text
Control Tower manages:
Organization SCP A

Terraform separately manages:
same exact SCP A

Engineer manually edits:
same exact SCP A
```

Now three control planes fight.

Result:

```text
drift

failed applies

unexpected remediation

confusion
```

Ownership must be explicit.

---

# 38.256 Define management ownership

For every enterprise resource ask:

```text
WHO OWNS IT?
```

Possible answers:

```text
Control Tower

Terraform

CloudFormation

Security service

Platform automation

Application team
```

Prefer:

```text
one authoritative lifecycle owner
```

per resource/configuration.

---

# 38.257 Good responsibility split

Example:

```text
CONTROL TOWER

Landing-zone baseline
Control Tower mandatory controls
Account enrollment
Shared accounts


TERRAFORM

Application VPC
EKS/ECS
RDS
application IAM
custom organization infrastructure


AFT

Account provisioning
account-specific customization
```

Clear boundaries reduce governance drift.

---

# 38.258 Control Tower doesn't replace Terraform

Control Tower is excellent for:

```text
landing zone

governance

account lifecycle

controls
```

Terraform remains excellent for:

```text
network infrastructure

application infrastructure

custom policies

platform components
```

They are complementary.

---

# 38.259 Control Tower doesn't replace IAM Identity Center

Control Tower can integrate with IAM Identity Center, but workforce identity still needs a deliberate access model.

We'll study:

```text
Users

Groups

Permission Sets

Account Assignments

Federation

External IdP

SCIM
```

in Part 4.

---

# 38.260 Control Tower doesn't replace security services

Control Tower establishes governance.

It does not replace:

```text
GuardDuty

Security Hub

Inspector

Macie

Detective

AWS Config

CloudTrail

IAM Access Analyzer
```

Many of those services can be centrally delegated/aggregated across the organization.

That's Part 5 and Part 8.

---

# 38.261 Control Tower doesn't replace Organizations

If you need:

```text
SCP

RCP

OU hierarchy

delegated administrator
```

Control Tower still depends on the Organizations foundation.

Don't think:

```text
Control Tower = newer Organizations
```

Wrong mental model.

---

# 38.262 Greenfield enterprise deployment sequence

A clean design might follow:

```text
1. Establish management account

2. Enable AWS Organizations

3. Choose Control Tower home Region

4. Launch landing zone

5. Establish Audit + Log Archive

6. Design OU hierarchy

7. Select governed Regions

8. Configure Region restrictions

9. Register OUs

10. Enable required controls

11. Configure IAM Identity Center

12. Delegate security services

13. Configure central networking

14. Build Account Factory/AFT

15. Provision workload accounts

16. Deploy workloads
```

The exact sequence can vary, but governance comes **before hundreds of workloads appear**.

---

# 38.263 Brownfield adoption sequence

Existing enterprise:

```text
Organizations already exists
        │
        ▼
inventory OUs/accounts
        │
        ▼
inventory CloudTrail/Config/IAM
        │
        ▼
choose Control Tower home Region
        │
        ▼
establish landing zone
        │
        ▼
preserve existing org hierarchy
        │
        ▼
test one OU
        │
        ▼
register OU
        │
        ▼
fix account enrollment issues
        │
        ▼
expand progressively
```

Control Tower explicitly supports adding a landing zone to an existing AWS Organization. ([AWS Documentation][2])

---

# 38.264 Never migrate everything on Friday evening

Imagine:

```text
250 existing production accounts
```

Do not:

```text
register every OU simultaneously
```

without testing.

Use:

```text
Sandbox OU
     ↓
NonProd pilot
     ↓
small Production subset
     ↓
broader rollout
```

because existing:

```text
Config

CloudTrail

IAM

network

automation

policies
```

may interact with Control Tower prerequisites/governance.

---

# 38.265 Control Tower pre-launch checks

Before establishing the landing zone, Control Tower runs automated checks against the management account to ensure prerequisites are satisfied. ([AWS Documentation][28])

This reinforces:

```text
LANDING ZONE SETUP
≠
simple wizard with no dependencies
```

It is an organization-wide foundation deployment.

---

# 38.266 Control Tower Production Architecture

Let's combine everything:

```text
                           AWS ORGANIZATION

                           MANAGEMENT ACCOUNT
                                  │
                                  ▼
                           CONTROL TOWER
                            LANDING ZONE
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼

         SECURITY OU       INFRASTRUCTURE OU       WORKLOADS OU
             │                    │                    │
      ┌──────┴──────┐       ┌─────┴─────┐        ┌────┴─────────┐
      ▼             ▼       ▼           ▼        ▼              ▼

    Audit       Log Archive Network    Platform Production     NonProd
      │             │        │           │       │              │
      │             │        │           │    Payments       Dev/QA
      │             │        │           │     Orders        Sandbox
      │             │        │           │
      └────Security─┼────────┼───────────┘
                    │
                    ▼
                 GOVERNANCE

        ┌───────────┼───────────┐
        ▼           ▼           ▼
    Preventive   Detective    Proactive
      policies      Config       Hooks

                    │
                    ▼
                BASELINES
                    │
                    ▼
            REGISTERED OUs
                    │
                    ▼
            ENROLLED ACCOUNTS

                    │
                    ▼
              ACCOUNT FACTORY
```

That is Control Tower's place in the enterprise AWS architecture.

---

# 38.267 Control Tower does not mean all accounts are identical

Production might have:

```text
stricter controls
```

NonProduction:

```text
more freedom
```

Sandbox:

```text
broad experimentation
but strong cost/security boundaries
```

Security:

```text
special administrative permissions
```

Control Tower gives a framework within which different OUs can carry different control sets.

---

# 38.268 Production OU example controls

Conceptually:

```text
Production OU

Prevent:
disabling central controls

Prevent:
using prohibited Regions

Detect:
unencrypted resources

Detect:
public exposure

Proactive:
reject non-compliant
CloudFormation resources
```

The exact Control Tower control identifiers should be selected from the current control catalog rather than memorized from an old course. AWS's available controls and Regional support continue evolving. ([AWS Documentation][17])

---

# 38.269 Sandbox OU philosophy

Do not create:

```text
Sandbox
=
AdministratorAccess with zero controls
```

Better:

```text
Sandbox

Developers:
broad AWS experimentation

Organization:
Region boundaries
security protection
logging
cost controls
no org escape
```

Freedom inside a safe boundary.

---

# 38.270 Control Tower troubleshooting sequence

When someone says:

> "This account isn't behaving like the other governed accounts."

Use:

```text
1. Which Organization?

2. Which OU?

3. Is OU registered?

4. Is account enrolled?

5. Which baseline version/state?

6. Is there baseline/control drift?

7. Which controls are enabled?

8. Which Regions are governed?

9. Has the account been updated
   after a landing-zone Region change?

10. Is AWS Config operating
    where detective controls require it?

11. Are Control Tower roles intact?

12. Has the account recently moved OUs?

13. Is trusted access enabled?

14. Are shared accounts still
    in expected locations?
```

That is much faster than randomly rebuilding the account.

---

# 38.271 Scenario — control works in Mumbai but not Singapore

Ask:

```text
Was Singapore added
as governed Region?

Was landing zone updated?

Were affected OUs/accounts
re-registered or updated?

Does this particular control
support Singapore and its dependency?
```

Because Control Tower documents that expanding governed Regions can require subsequent account/OU updates before detective governance operates there. ([AWS Documentation][5])

---

# 38.272 Scenario — account exists but controls don't apply

Check:

```text
OU registered?
```

and:

```text
account enrolled?
```

An account can exist in Organizations and still not be under Control Tower governance. ([AWS Documentation][18])

---

# 38.273 Scenario — account moved to Production but still has Sandbox governance

Likely:

```text
inheritance drift
```

especially if account movement occurred outside normal Control Tower governance handling.

Remediation might require:

```text
auto-enrollment

Update account

Re-register OU
```

depending on state. ([AWS Documentation][26])

---

# 38.274 Scenario — detective control says nothing

Check:

```text
Does AWS Config recording
exist/operate correctly?

Is the Region governed?

Does the control support
that resource/Region?

Is the account current
with the OU baseline?
```

Detective controls rely on the AWS Config recording/evaluation foundation. ([AWS Documentation][12])

---

# 38.275 Scenario — Terraform creates something despite proactive control

Ask:

```text
Was Terraform deploying
through CloudFormation?
```

If not:

```text
CloudFormation-hook proactive control
```

is not equivalent to an organization-wide deny policy.

For broad API-level prevention, look toward:

```text
preventive controls / SCP / RCP
```

depending on the requirement. ([AWS Documentation][14])

---

# 38.276 Scenario — CloudTrail cost doubled after account enrollment

Possible cause:

```text
existing account trail
+
Control Tower organization trail
```

AWS specifically warns that existing trails may duplicate logging/cost after enrollment. ([AWS Documentation][10])

---

# 38.277 Interview question — Organizations vs Control Tower

Strong answer:

> **AWS Organizations provides the underlying multi-account hierarchy, organizational units, organization policies, and service integrations. AWS Control Tower orchestrates a governed landing-zone operating model on top of that foundation, including shared security accounts, baselines, controls, account enrollment, drift visibility, and Account Factory.** ([AWS Documentation][2])

---

# 38.278 Interview question — What is a landing zone?

> **A landing zone is the governed foundational multi-account AWS environment into which workloads are deployed. It defines organizational, security, identity, logging, and governance foundations rather than merely providing application infrastructure.** ([AWS Documentation][1])

---

# 38.279 Interview question — registered OU vs enrolled account

```text
OU
→ REGISTERED

Account
→ ENROLLED
```

Registering an OU extends Control Tower governance to it and causes its member accounts to be enrolled subject to prerequisites. ([AWS Documentation][12])

---

# 38.280 Interview question — Audit vs Log Archive

```text
Audit
=
security/compliance operational account


Log Archive
=
centralized storage of audit/config logs
```

([AWS Documentation][3])

---

# 38.281 Interview question — preventive vs detective vs proactive

```text
PREVENTIVE
=
block prohibited behavior


DETECTIVE
=
evaluate/report existing
resource compliance


PROACTIVE
=
evaluate supported CloudFormation
resources before provisioning
```

([AWS Documentation][14])

---

# 38.282 Interview trap — ungoverned Region means disabled Region

# Wrong.

The Region can still be used unless a separate deny mechanism blocks it. Control Tower explicitly states that resources can exist in Regions you choose not to govern. ([AWS Documentation][5])

---

# 38.283 Interview trap — Control Tower changes existing OUs automatically when enabled

# Wrong.

When adding Control Tower to an existing organization, AWS does not automatically reorganize the pre-existing OUs/accounts; governance is extended deliberately through registration/enrollment. ([AWS Documentation][2])

---

# 38.284 Interview trap — every account in Organizations is Control Tower governed

# Wrong.

An account/OU may exist in Organizations but remain unregistered/unenrolled from Control Tower's perspective. ([AWS Documentation][18])

---

# 38.285 Interview trap — Control Tower eliminates drift

# Wrong.

It can detect/remediate several categories of governance drift, but administrators can still create drift by manipulating managed organization/account configuration outside expected workflows. ([AWS Documentation][22])

---

# 38.286 Interview trap — Control Tower detects every Terraform change

# Wrong.

Control Tower drift detection covers its governance model, not arbitrary drift for every AWS resource in every workload. ([AWS Documentation][22])

---

# 38.287 Interview trap — preventive, detective and proactive controls all have identical Region behavior

# Wrong.

Preventive controls are policy-based/global in behavior, while detective and proactive controls depend on supported Regions and underlying services. ([AWS Documentation][5])

---

# 38.288 Senior architecture scenario

Requirement:

> An enterprise already has 80 AWS accounts and wants to adopt Control Tower without disrupting production.

Good approach:

```text
Inventory existing organization
       ↓
inventory CloudTrail/Config
       ↓
choose home Region carefully
       ↓
establish Control Tower landing zone
       ↓
do not assume existing OUs
are automatically governed
       ↓
select test OU
       ↓
resolve prerequisites
       ↓
register OU
       ↓
validate enrolled accounts
       ↓
validate controls/logging
       ↓
expand gradually
```

This matches AWS's supported brownfield model of adding Control Tower to an existing organization and then extending governance deliberately. ([AWS Documentation][2])

---

# 38.289 Senior architecture scenario — Multi-Region workload

Requirement:

```text
Primary:
Mumbai

DR:
Singapore
```

Control Tower design:

```text
Home Region:
Mumbai

Governed Regions:
Mumbai + Singapore

Production OU:
registered

Accounts:
enrolled

Preventive controls:
organization-wide guardrails

Detective controls:
both governed Regions,
where supported

DR account:
same baseline/control
posture as primary
```

Then a game day should test not just application recovery but that Singapore has the expected security/governance posture too.

---

# 38.290 Governance itself needs DR thinking

Interesting connection.

Imagine Singapore is your DR application Region, but you never extended:

```text
AWS Config

security controls

logging configuration

required baselines
```

to it.

Then:

```text
Application DR succeeds

Governance DR fails.
```

A production Multi-Region architecture needs:

```text
WORKLOAD parity

+

SECURITY parity

+

GOVERNANCE parity.
```

---

# 38.291 Terraform + Control Tower architecture

Eventually we'll create something like:

```text
Git Repository
     │
     ▼
Terraform
     │
     ├── Organization custom policies
     ├── delegated admin setup
     ├── shared networking
     └── security integration
     │
     ▼
Control Tower Landing Zone
     │
     ▼
AFT
     │
     ▼
Account requests
     │
     ▼
Governed accounts
```

The most important design principle:

> **Don't make Terraform and Control Tower compete for ownership of the same Control Tower-managed resources.**

---

# 38.292 One-page Control Tower mental model

```text
                   AWS CONTROL TOWER

                        LANDING ZONE
                             │
                             ▼
                      HOME REGION
                             │
                             ▼
                     AWS ORGANIZATIONS
                             │
            ┌────────────────┼─────────────────┐
            ▼                ▼                 ▼

        Security OU     Infrastructure     Workloads
            │                                  │
      ┌─────┴─────┐                      ┌─────┴─────┐
      ▼           ▼                      ▼           ▼
    Audit     Log Archive             Prod        NonProd

                             │
                             ▼
                         BASELINES

                             │
                             ▼
                      REGISTERED OUs

                             │
                             ▼
                     ENROLLED ACCOUNTS

                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼

          PREVENTIVE      DETECTIVE       PROACTIVE
             │               │               │
          SCP/RCP         AWS Config      CFN Hooks

                             │
                             ▼
                         DRIFT CHECKS

                             │
                             ▼
                      ACCOUNT FACTORY

                             │
                             ▼
                     NEW GOVERNED ACCOUNT
```

If you can reconstruct that from memory, you understand the core Control Tower architecture.

---

# 38.293 Never-forget rules

```text
1.
Organizations is the foundation;
Control Tower is the governed
landing-zone operating layer.


2.
Landing Zone is the enterprise
AWS foundation, not one VPC.


3.
Home Region is a major design
decision and isn't normally changeable
after deployment.


4.
Home Region does not mean
only workload Region.


5.
Governed Region
does not mean
only permitted Region.


6.
Audit Account
=
security/compliance operations.


7.
Log Archive
=
centralized log evidence.


8.
OU
→ register.


9.
Account
→ enroll.


10.
Baseline
establishes governance foundation.


11.
Control
represents a governance rule.


12.
Preventive
=
block.


13.
Detective
=
detect compliance.


14.
Proactive
=
check before supported
CloudFormation provisioning.


15.
Existing Organizations accounts
are not automatically governed.


16.
Control Tower can detect
governance drift,
not every possible resource drift.


17.
Don't manually move/delete
Control Tower foundational resources.


18.
Terraform and Control Tower
need clear ownership boundaries.


19.
Account Factory
=
governed account vending.


20.
Multi-Region DR should include
governance parity,
not just application parity.
```

---

# 38.294 Part 3 checkpoint

You now understand:

```text
✓ Landing Zone

✓ Home Region

✓ Additional governed Regions

✓ Region deny vs Region governance

✓ Security OU

✓ Audit Account

✓ Log Archive Account

✓ Organization CloudTrail

✓ Registered OU

✓ Enrolled Account

✓ Baselines

✓ Baseline vs control

✓ Preventive controls

✓ Detective controls

✓ Proactive controls

✓ Guidance categories

✓ Regional control differences

✓ Brownfield Control Tower adoption

✓ Existing OU registration

✓ Enrollment prerequisites

✓ Account Factory

✓ Drift

✓ Control drift

✓ Baseline drift

✓ Inheritance drift

✓ Landing-zone drift

✓ Auto-enrollment

✓ OU re-registration

✓ Landing-zone updates

✓ Terraform ownership boundaries

✓ Multi-Region governance
```

---

# ✅ Lesson 38 — Part 3 Complete

```text
Part 1
Enterprise Multi-Account Architecture
+ AWS Organizations                     ✓

Part 2
SCP + RCP + IAM Policy Evaluation       ✓

Part 3
AWS Control Tower Landing Zone          ✓

Part 4
IAM Identity Center                     NEXT

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

# Next — Lesson 38, Part 4

## IAM Identity Center — Enterprise Workforce Access Deep Dive

Next we'll solve the enterprise identity problem:

```text
1,000 employees
      ×
100 AWS accounts

WITHOUT

100,000 manually managed
IAM users
```

We'll build:

```text
Corporate Identity Provider
          │
          ▼
IAM Identity Center
          │
     Users / Groups
          │
          ▼
     Permission Sets
          │
          ▼
   Account Assignments
          │
   ┌──────┼─────────┐
   ▼      ▼         ▼
Prod     Dev      Security
Read     Admin    Audit
Only
```

Then we'll go into **permission sets, generated IAM roles, session duration, MFA, external IdPs, Microsoft Entra ID/Okta concepts, SAML, SCIM provisioning, ABAC, attributes for access control, cross-account CLI access, AWS access portal, break-glass access, least privilege, group design, permission-set boundaries, SCP interaction, and enterprise troubleshooting**.

[1]: https://docs.aws.amazon.com/controltower/latest/userguide/how-control-tower-works.html?utm_source=chatgpt.com "How AWS Control Tower works"
[2]: https://docs.aws.amazon.com/controltower/latest/userguide/planning-your-deployment.html?utm_source=chatgpt.com "Plan your AWS Control Tower landing zone"
[3]: https://docs.aws.amazon.com/controltower/latest/userguide/special-accounts.html?utm_source=chatgpt.com "About the shared accounts - AWS Control Tower"
[4]: https://docs.aws.amazon.com/controltower/latest/userguide/aws-multi-account-landing-zone.html?utm_source=chatgpt.com "AWS multi-account strategy for your AWS Control Tower ..."
[5]: https://docs.aws.amazon.com/controltower/latest/userguide/region-how.html?utm_source=chatgpt.com "How AWS Regions Work With AWS Control Tower"
[6]: https://docs.aws.amazon.com/controltower/latest/userguide/region-deny.html?utm_source=chatgpt.com "Configure the Region deny control - AWS Control Tower"
[7]: https://docs.aws.amazon.com/controltower/latest/userguide/step-two.html?utm_source=chatgpt.com "Step 2. Configure and launch your landing zone"
[8]: https://docs.aws.amazon.com/controltower/latest/userguide/configure-shared-accounts.html?utm_source=chatgpt.com "Step 2c. Configure your shared accounts, logging, and ..."
[9]: https://docs.aws.amazon.com/controltower/latest/userguide/about-logging.html?utm_source=chatgpt.com "About logging in AWS Control Tower"
[10]: https://docs.aws.amazon.com/controltower/latest/userguide/enrollment-prerequisites.html?utm_source=chatgpt.com "Prerequisites for enrollment - AWS Control Tower"
[11]: https://docs.aws.amazon.com/controltower/latest/userguide/how-to-register-existing-ou.html?utm_source=chatgpt.com "Register an existing OU - AWS Control Tower"
[12]: https://docs.aws.amazon.com/controltower/latest/userguide/importing-existing.html?utm_source=chatgpt.com "Register an existing organizational unit with AWS Control ..."
[13]: https://docs.aws.amazon.com/controltower/latest/userguide/terminology.html?utm_source=chatgpt.com "Terminology - AWS Control Tower"
[14]: https://docs.aws.amazon.com/controltower/latest/userguide/how-controls-work.html?utm_source=chatgpt.com "How controls work - AWS Control Tower"
[15]: https://docs.aws.amazon.com/controltower/latest/userguide/2024-all.html?utm_source=chatgpt.com "January - December 2024 - AWS Control Tower"
[16]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS ..."
[17]: https://docs.aws.amazon.com/controltower/latest/userguide/regional-differences.html?utm_source=chatgpt.com "Regional differences for AWS Control Tower functionality"
[18]: https://docs.aws.amazon.com/controltower/latest/userguide/external-resources.html?utm_source=chatgpt.com "If you manage resources outside of AWS Control Tower"
[19]: https://docs.aws.amazon.com/controltower/latest/userguide/common-eg-failures.html?utm_source=chatgpt.com "Common causes of failure during registration or re- ..."
[20]: https://docs.aws.amazon.com/controltower/latest/userguide/existing-config-resources.html?utm_source=chatgpt.com "Enroll accounts that have existing AWS Config resources"
[21]: https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html?utm_source=chatgpt.com "Provision and manage accounts with Account Factory"
[22]: https://docs.aws.amazon.com/controltower/latest/userguide/governance-drift.html?utm_source=chatgpt.com "Types of governance drift - AWS Control Tower"
[23]: https://docs.aws.amazon.com/controltower/latest/userguide/drift.html?utm_source=chatgpt.com "Detect and resolve drift in AWS Control Tower"
[24]: https://docs.aws.amazon.com/controltower/latest/userguide/orgs-guidance.html?utm_source=chatgpt.com "AWS Organizations guidance - AWS Control Tower"
[25]: https://docs.aws.amazon.com/controltower/latest/userguide/account-auto-enrollment.html?utm_source=chatgpt.com "Move and enroll accounts with auto-enrollment - AWS Control Tower"
[26]: https://docs.aws.amazon.com/controltower/latest/userguide/resolving-drift.html?utm_source=chatgpt.com "Resolving drift - AWS Control Tower"
[27]: https://docs.aws.amazon.com/controltower/latest/userguide/update-controltower.html?utm_source=chatgpt.com "Update your landing zone - AWS Control Tower"
[28]: https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-prereqs.html?utm_source=chatgpt.com "Automated pre-launch checks for your management account"
