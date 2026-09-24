# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 7: Account Factory + AFT — Production Account Vending with Terraform

We have built the enterprise foundation:

```text
Organizations                 ✓
Control Tower                 ✓
IAM Identity Center           ✓
Central Security              ✓
Central Networking            ✓
```

Now imagine a developer says:

> **“Our Payments team needs a new production AWS account.”**

A traditional process might look like:

```text
Ticket
  ↓
Platform engineer opens console
  ↓
Create AWS account
  ↓
Choose OU
  ↓
Configure logging
  ↓
Configure IAM
  ↓
Enable security services
  ↓
Allocate CIDR
  ↓
Create VPC
  ↓
Connect TGW
  ↓
Configure DNS
  ↓
Add monitoring
  ↓
Hopefully nothing was forgotten
```

At enterprise scale, that model fails.

We want:

```text
                     PULL REQUEST

                      payments-prod.tf
                            │
                            ▼
                     Code Review / Approval
                            │
                            ▼
                           Git
                            │
                            ▼
             Account Factory for Terraform
                           AFT
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼

     Control Tower      Global Baseline    Account-specific
     provisioning       customization      customization
          │                 │                 │
          ▼                 ▼                 ▼

      AWS Account      Security/Identity   Network/App
                          baseline           metadata
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ▼
                 GOVERNED AWS ACCOUNT
                            │
                            ▼
                    READY FOR TEAM
```

AFT uses a GitOps-style Terraform workflow for creating and updating AWS Control Tower accounts. It runs in a **dedicated AFT management account**, separate from the AWS Control Tower management account, and requires an existing Control Tower landing zone. ([AWS Documentation][1])

---

# 38.718 First: Account Factory vs AFT

These names are similar, so separate them permanently.

## AWS Control Tower Account Factory

Think:

```text
CONTROL TOWER
      │
      ▼
ACCOUNT FACTORY
      │
      ▼
Standardized AWS account
```

Account Factory is Control Tower's account-provisioning mechanism for creating governed accounts using standardized templates/configuration. ([AWS Documentation][2])

---

## Account Factory for Terraform — AFT

Think:

```text
ACCOUNT FACTORY
      +
TERRAFORM
      +
GIT
      +
PIPELINES
      +
CUSTOMIZATIONS
```

AFT provides Terraform-driven account provisioning and customization while preserving Control Tower governance. ([AWS Documentation][1])

---

# 38.719 Never-forget shortcut

```text
ACCOUNT FACTORY
=
Control Tower account vending


AFT
=
GitOps + Terraform automation
around Control Tower Account Factory
```

---

# 38.720 AFT is not your normal workload deployment pipeline

This is critical.

AWS explicitly states AFT is intended for:

```text
account provisioning
+
account customization
```

not for continuously deploying application resources such as ordinary EC2 instances required by your workloads. ([AWS Documentation][1])

So:

```text
AFT
  ↓
create Payments account
  ↓
baseline it
  ↓
network/security onboarding
```

Then separate application IaC:

```text
Payments application repository
  ↓
Terraform / CI/CD
  ↓
ALB
ECS
RDS
etc.
```

Do **not** turn AFT into:

```text
one massive monolithic
application deployment platform.
```

---

# 38.721 Account lifecycle vs workload lifecycle

This distinction is powerful:

```text
ACCOUNT LIFECYCLE

create account
move OU
baseline
security configuration
ownership metadata
decommission account
```

versus:

```text
WORKLOAD LIFECYCLE

deploy application
upgrade application
scale compute
change DB
release software
```

AFT primarily belongs to the first category.

---

# 38.722 Dedicated AFT management account

AWS recommends a dedicated account for AFT itself.

Architecture:

```text
AWS ORGANIZATION
│
├── Management Account
│
├── Security OU
│
├── Infrastructure OU
│
└── AFT OU
    │
    └── AFT Management Account
```

The AFT management account contains the framework resources used for pipelines, Terraform execution, metadata, roles, and customization orchestration; AWS explicitly distinguishes it from the Control Tower management account. ([AWS Documentation][1])

---

# 38.723 Why not deploy AFT inside the management account?

Because we already established:

```text
Organizations Management Account
=
extremely privileged
```

and should have minimal operational workloads.

AFT has:

```text
pipelines
CodeBuild
Step Functions
DynamoDB
IAM roles
state backends
repository integrations
```

so isolating those operations into a member account reduces routine dependence on the management account. AWS strongly recommends creating a separate OU and dedicated AFT management account. ([AWS Documentation][3])

---

# 38.724 AFT architecture

At a high level:

```text
                      DEVELOPER

                          │
                       git push
                          │
                          ▼
               aft-account-request repo
                          │
                          ▼
                  AFT MANAGEMENT ACCOUNT
                          │
                    Account Request
                       Pipeline
                          │
                          ▼
                CONTROL TOWER MANAGEMENT
                       ACCOUNT
                          │
                          ▼
                   Account Factory
                          │
                          ▼
                    New AWS Account
                          │
                          ▼
                AFT Provisioning Stage
                          │
                          ▼
                 Global Customizations
                          │
                          ▼
                Account Customizations
                          │
                          ▼
                 GOVERNED AWS ACCOUNT
```

AWS documents this order as: request submission, Control Tower account provisioning, global customizations, then targeted account customizations. ([AWS Documentation][4])

---

# 38.725 Four AFT repositories

This is one of the most important things to memorize.

AFT expects four Git repositories:

```text
1. aft-account-request

2. aft-account-provisioning-customizations

3. aft-global-customizations

4. aft-account-customizations
```

AWS documents these four repositories as the standard AFT repository structure. ([AWS Documentation][5])

---

# 38.726 Repository #1 — `aft-account-request`

Purpose:

# **WHAT ACCOUNTS SHOULD EXIST?**

Example:

```text
aft-account-request/
│
├── payments-prod.tf
├── payments-dev.tf
├── analytics-prod.tf
└── sandbox-team-a.tf
```

An account request Terraform file defines the account name, email, target OU, initial Identity Center user fields, tags, change metadata, custom fields, and optional account customization name. A `git push` invokes the AFT request workflow. ([AWS Documentation][6])

---

# 38.727 Repository #2 — provisioning customizations

```text
aft-account-provisioning-customizations
```

Think:

> **What organization integrations must happen as part of the provisioning framework before ordinary global/account customizations run?**

This is an advanced stage implemented through an AFT-invoked Step Functions workflow. AWS recommends using it when special non-Terraform integrations are required during account provisioning; for many normal customizations, AWS recommends the simpler global customization helpers instead. ([AWS Documentation][7])

---

# 38.728 Repository #3 — global customizations

```text
aft-global-customizations
```

Question:

> **What should every AFT-managed account receive?**

Examples:

```text
alternate contacts

baseline IAM roles

mandatory tags/config

security integrations

common SSM parameters

baseline EventBridge rules

account aliases

common resource policies
```

AFT applies global customizations automatically to AFT-provisioned accounts after its provisioning framework stage. Terraform, Bash, Python, and AWS CLI-based customization workflows are supported. ([AWS Documentation][8])

---

# 38.729 Repository #4 — account customizations

```text
aft-account-customizations
```

Question:

> **What does this particular account—or this class of accounts—need that every account does not?**

Example folders:

```text
aft-account-customizations/
│
├── ACCOUNT_TEMPLATE/
│
├── payments-prod/
│   └── terraform/
│
├── analytics/
│   └── terraform/
│
└── sandbox/
    └── terraform/
```

The folder name is referenced using the account request's `account_customizations_name`. ([AWS Documentation][8])

---

# 38.730 The four-repository shortcut

```text
ACCOUNT REQUEST
=
what account?


PROVISIONING CUSTOMIZATION
=
special provisioning workflow


GLOBAL CUSTOMIZATION
=
every AFT account


ACCOUNT CUSTOMIZATION
=
this specific class/account
```

Memorize that.

---

# 38.731 Example Git structure

```text
platform-aft/
│
├── aft-account-request/
│   ├── payments-prod.tf
│   ├── payments-dev.tf
│   └── analytics-prod.tf
│
├── aft-account-provisioning-customizations/
│   ├── customizations.asl.json
│   └── terraform/
│
├── aft-global-customizations/
│   ├── terraform/
│   └── api_helpers/
│
└── aft-account-customizations/
    ├── payments-prod/
    │   └── terraform/
    ├── nonprod-standard/
    │   └── terraform/
    └── analytics/
        └── terraform/
```

That already starts to look like an internal cloud platform.

---

# 38.732 GitOps account creation

Normal developer workflow:

```text
git checkout -b create-payments-prod
```

Create:

```text
payments-prod.tf
```

Then:

```bash
git add payments-prod.tf
git commit -m "Request payments production AWS account"
git push
```

The important production model is not the exact command.

It's:

```text
ACCOUNT CHANGE
      │
      ▼
PULL REQUEST
      │
      ▼
REVIEW
      │
      ▼
MERGE
      │
      ▼
AUTOMATION
```

Instead of:

```text
console click
+
no history
+
no review.
```

---

# 38.733 Production pull-request review

Before merge, reviewers should validate:

```text
Account name

Account email

OU placement

Owner

Environment

Cost center

Compliance classification

Network requirements

Data classification

Customization template

Identity model
```

Account creation becomes a controlled change.

---

# 38.734 Exact account request structure

The current official AWS AFT example follows this shape:

```hcl
module "payments_prod" {
  source = "./modules/aft-account-request"

  control_tower_parameters = {
    AccountEmail              = "aws-payments-prod@example.com"
    AccountName               = "payments-prod"
    ManagedOrganizationalUnit = "Production (ou-abcd-12345678)"

    SSOUserEmail     = "platform-admin@example.com"
    SSOUserFirstName = "Platform"
    SSOUserLastName  = "Admin"
  }

  account_tags = {
    Environment = "Prod"
    Application = "Payments"
    Owner       = "PaymentsTeam"
    CostCenter  = "CC-4100"
    ManagedBy   = "AFT"
  }

  change_management_parameters = {
    change_requested_by = "Payments Platform Team"
    change_reason       = "New production payments workload"
  }

  custom_fields = {
    compliance       = "pci"
    primary_region   = "ap-south-1"
    dr_region        = "ap-southeast-1"
    network_profile  = "prod-restricted"
    data_class       = "restricted"
  }

  account_customizations_name = "payments-prod"
}
```

The required parameter families and nested-OU syntax here follow the current AFT account-request specification; nested OUs require the `OUName (OU-ID)` form. ([AWS Documentation][6])

---

# 38.735 Why account email matters

Every AWS account needs a unique account email identity.

Don't invent human-owned addresses such as:

```text
vivek.personal@gmail.com
```

for enterprise production accounts.

Prefer managed addresses such as:

```text
aws-payments-prod@example.com
```

or your organization's approved account-email mechanism.

The exact email-management model is an organizational process decision, but it should survive employee turnover.

---

# 38.736 OU placement

Example:

```hcl
ManagedOrganizationalUnit =
  "Production (ou-abcd-12345678)"
```

AFT supports:

```text
OUName
```

for top-level OUs, and:

```text
OUName (OU-ID)
```

for nested OUs; AWS requires the latter form for nested OUs to avoid ambiguity. ([AWS Documentation][6])

---

# 38.737 Why OU placement is critical

Remember:

```text
OU
      │
      ▼
SCPs

RCPs

Control Tower controls

Security Hub config

Inspector policies

other org policy
```

So:

```text
Payments account
→ Production OU
```

can immediately determine a large portion of its governance posture.

Account vending is therefore not merely:

```text
CreateAccount()
```

It is:

```text
CreateAccount
+
place in security context.
```

---

# 38.738 `account_tags`

Account-level tags can record business metadata.

Example:

```hcl
account_tags = {
  Environment = "Prod"
  Application = "Payments"
  Owner       = "PaymentsTeam"
  CostCenter  = "CC4100"
}
```

AFT applies account tags provided in the account request as part of its provisioning framework. ([AWS Documentation][7])

These become useful for:

```text
FinOps

automation

customization targeting

inventory

ownership

governance
```

---

# 38.739 Account metadata matters

Suppose security sees:

```text
Account ID:
123456789012
```

That tells humans very little.

Metadata can tell:

```text
Environment:
Production

Application:
Payments

Owner:
PaymentsTeam

Compliance:
PCI

Data:
Restricted
```

That turns an AWS account ID into an operational object with business context.

---

# 38.740 `change_management_parameters`

Example:

```hcl
change_management_parameters = {
  change_requested_by = "Vivek"
  change_reason       = "Production account for Payments v2"
}
```

AFT records change metadata and account-request information as part of its GitOps/account metadata workflow. ([AWS Documentation][1])

This supports:

```text
Why was the account created?

Who requested it?

Which commit introduced it?
```

---

# 38.741 `custom_fields`

This is one of AFT's best platform features.

Example:

```hcl
custom_fields = {
  compliance      = "pci"
  network_profile = "prod-restricted"
  backup_tier     = "critical"
}
```

AFT stores these fields in the target account as SSM Parameter Store values under:

```text
/aft/account-request/custom-fields/
```

and they can be consumed by later account customizations. ([AWS Documentation][6])

---

# 38.742 Custom fields turn account requests into platform APIs

Instead of asking developers for infrastructure details:

```text
Which TGW route table ID?

Which Config rule?

Which KMS key ARN?

Which Firewall Manager policy?
```

ask business/platform questions:

```text
Environment?
Prod


Compliance?
PCI


Network profile?
restricted


DR?
required
```

Then platform code translates those into technical implementation.

That's a mature internal platform interface.

---

# 38.743 Example translation

Input:

```text
network_profile=prod-restricted
```

Automation derives:

```text
IPAM Pool
→ Prod pool

TGW Route Domain
→ Prod

DNS Profile
→ Production DNS

Egress
→ inspected

Internet ingress
→ restricted
```

Developer doesn't need to memorize central infrastructure IDs.

---

# 38.744 `account_customizations_name`

Example:

```hcl
account_customizations_name = "payments-prod"
```

AFT searches the account-customizations repository for the matching template/folder and applies those targeted customizations after the global stage. ([AWS Documentation][8])

So:

```text
payments-prod
```

could deploy:

```text
special PCI Config rules

payment-service DNS integration

additional KMS configuration

special backup baseline
```

without affecting all other accounts.

---

# 38.745 Global vs account-specific customizations

Use this test:

> **Should every account receive it?**

Yes:

```text
Global customization
```

No:

```text
Account customization
```

Example:

```text
Security contact
→ GLOBAL


Payments PCI integration
→ ACCOUNT-SPECIFIC


Corporate inventory role
→ GLOBAL


Analytics data-lake role
→ ACCOUNT-SPECIFIC
```

---

# 38.746 Don't put everything in global customization

Bad:

```text
GLOBAL CUSTOMIZATION

VPN
Payments KMS
Analytics Glue
Sandbox tools
PCI rule
Finance role
```

Then every account inherits irrelevant components.

Better:

```text
GLOBAL
=
minimum organization baseline


ACCOUNT TEMPLATE
=
workload-class requirements
```

Keep global customizations boring and universal.

---

# 38.747 AFT provisioning execution role

As part of preparing a new AFT-managed account, AFT creates:

```text
AWSAFTExecution
```

inside the target account.

AFT assumes that role to carry out later customization operations. ([AWS Documentation][7])

Architecture:

```text
AFT Management Account
       │
       │ sts:AssumeRole
       ▼
New Account
AWSAFTExecution
       │
       ▼
run customizations
```

---

# 38.748 Don't casually modify AFT-managed roles

If somebody edits:

```text
AWSAFTExecution
```

or related framework permissions, AFT can lose the ability to update/customize accounts.

AWS specifically identifies modified or insufficient AFT role permissions as a common troubleshooting cause. ([AWS Documentation][9])

Think:

```text
AFT framework roles
=
platform infrastructure
```

not application roles.

---

# 38.749 AFT pipeline internal stages

After Control Tower provisions the account, AFT currently performs steps including:

```text
Validate request

Discover account ID

Store metadata in DynamoDB

Create AWSAFTExecution

Apply account tags

Apply enabled AFT features

Run provisioning customizations

Create per-account customization pipeline

Run global/account customizations

Send success/failure notification
```

AWS documents this sequence in the AFT provisioning framework. ([AWS Documentation][7])

---

# 38.750 Per-account customization pipelines

AFT creates a customization pipeline for each account it manages. ([AWS Documentation][8])

Concept:

```text
Payments
→ customization pipeline

Orders
→ customization pipeline

Analytics
→ customization pipeline
```

This gives each account a repeatable customization lifecycle.

---

# 38.751 Why separate per-account pipelines?

Because:

```text
Payments customization failure
```

should not necessarily mean:

```text
Analytics customizations
cannot run.
```

It also creates traceability:

```text
Which account pipeline failed?

Which customization?

Which Terraform state?
```

---

# 38.752 Customization languages

AFT customization stages can use:

```text
Terraform

Bash

Python

AWS CLI
```

depending on the stage and repository structure. ([AWS Documentation][8])

Prefer Terraform where:

```text
declarative resource lifecycle
```

makes sense.

Use scripts/API helpers for tasks that don't map cleanly into Terraform resources.

---

# 38.753 AFT provisioning customizations are advanced

The provisioning customization repository can invoke a custom:

```text
AWS Step Functions state machine
```

with integrations such as:

```text
Lambda

ECS/Fargate

SNS/SQS

custom workers
```

before global customizations. AWS explicitly labels this approach advanced and recommends global helpers as the simpler alternative for many needs. ([AWS Documentation][7])

Use it only when the workflow genuinely requires orchestration.

---

# 38.754 Example advanced provisioning integration

Suppose every account must be registered in an external CMDB.

Flow:

```text
Account provisioned
      │
      ▼
AFT provisioning state machine
      │
      ▼
Lambda
      │
      ▼
Enterprise CMDB API
      │
      ▼
Record:

Account ID
Owner
OU
Environment
Cost center
```

That is a reasonable non-Terraform integration.

---

# 38.755 Don't force APIs into Terraform resources

If your customization must:

```text
call ServiceNow API

send approval event

invoke CMDB

create non-AWS record
```

a Step Functions/Lambda integration may be cleaner than inventing brittle Terraform shell provisioners.

Tool choice should match lifecycle semantics.

---

# 38.756 Account Factory workflow for `payments-prod`

Let's build the full production journey.

Developer requests:

```text
Account:
payments-prod

OU:
Production

Primary Region:
ap-south-1

DR:
ap-southeast-1

Compliance:
PCI

Network:
restricted
```

---

# 38.757 Step 1 — Pull Request

Create:

```text
aft-account-request/payments-prod.tf
```

Reviewers:

```text
Platform

Security

FinOps

Payments owner
```

depending on governance model.

Review verifies:

```text
business owner

budget

OU

compliance

email

network class

backup tier
```

---

# 38.758 Step 2 — Merge

After merge:

```text
Git
 │
 ▼
AFT account request pipeline
```

AFT uses the account-request file to create or update the corresponding Control Tower account workflow. ([AWS Documentation][6])

---

# 38.759 Step 3 — Account Factory creates governed account

Control Tower provisions:

```text
payments-prod
```

and places it into:

```text
Production OU
```

The account receives the Control Tower governance associated with its managed OU/account enrollment. AFT account creation preserves Control Tower governance rather than bypassing it. ([AWS Documentation][1])

---

# 38.760 Step 4 — Organization inheritance happens

By being in:

```text
Production OU
```

the account may inherit applicable:

```text
SCPs

RCPs

Control Tower controls

Security Hub policies

Inspector policies

other Organizations policies
```

according to the governance layers we studied earlier.

So one OU placement has enormous effect.

---

# 38.761 Step 5 — AFT applies metadata

AFT stores account metadata, tags the account, prepares execution roles, and makes custom-field values available for later customization. ([AWS Documentation][7])

Now:

```text
Environment=Prod

Application=Payments

Compliance=PCI
```

become automation inputs.

---

# 38.762 Step 6 — Global customizations

Every account receives baseline customization such as:

```text
security contacts

operations contacts

base IAM roles

organization inventory integration

baseline log configuration

required SSM metadata
```

The exact resources are organization-specific.

AFT applies global customizations to all AFT-managed accounts after the provisioning framework. ([AWS Documentation][8])

---

# 38.763 Example alternate contacts

Global customization might consume custom fields and create:

```text
Billing contact

Operations contact

Security contact
```

AWS documentation specifically shows using account-request custom fields with Terraform's account alternate-contact resources during global customization. ([AWS Documentation][10])

This is a great example of business metadata driving configuration.

---

# 38.764 Step 7 — Security onboarding

Now security automation ensures:

```text
GuardDuty expected configuration

Inspector expected scanning

Security Hub association

Config

Access Analyzer where required

central logs

incident-response role
```

Some of these may already be inherited through organization-wide delegated administration and policies rather than explicitly created by AFT.

That's important:

> **AFT should orchestrate or complement centralized organization policies—not duplicate them unnecessarily.**

---

# 38.765 Organization policy vs AFT customization

If Inspector organization policy already says:

```text
Production OU
→ enable Inspector
```

don't also write:

```text
AFT Terraform
→ manually enable Inspector
```

unless there is a specific reason.

Otherwise:

```text
two control planes
```

manage one configuration.

Remember Part 3:

```text
one authoritative owner
per configuration.
```

---

# 38.766 Step 8 — Identity onboarding

Example:

```text
AWS-Prod-SRE group
      │
      ▼
ProdOperator permission set
      │
      ▼
payments-prod account
```

Identity Center assignments can be automated using your identity/platform IaC after the account is created.

The key is:

```text
account exists
      ↓
account ID discovered
      ↓
identity assignment created
```

not manually logging into the account to create IAM users.

---

# 38.767 Step 9 — IPAM allocation

From Part 6:

```text
network_profile=prod-restricted
```

could map to:

```text
IPAM:
Mumbai Prod pool
```

Then account networking automation requests:

```text
/20
```

and receives:

```text
10.64.32.0/20
```

for example.

Now the team doesn't invent CIDRs.

---

# 38.768 Step 10 — VPC vending

Network automation could create:

```text
VPC

public subnets if required

private app subnets

private DB subnets

route tables

VPC endpoints

Flow Logs
```

using a separate approved network Terraform module.

Remember:

```text
AFT
```

does not need to become the permanent workload VPC lifecycle owner.

A cleaner architecture might have AFT trigger/bootstrap the account so a dedicated network-vending pipeline can take over.

---

# 38.769 Step 11 — Transit onboarding

Automation:

```text
VPC
  │
  ▼
shared TGW
  │
  ▼
VPC attachment
  │
  ▼
Network account automation
  │
  ▼
associate:

Production TGW Route Table
```

Now:

```text
Prod ↔ Shared
```

can be enabled while:

```text
Prod ↔ Dev
```

remains blocked.

---

# 38.770 Step 12 — DNS onboarding

Attach:

```text
Production Route 53 Profile
```

or equivalent enterprise DNS configuration.

Result:

```text
corporate domains resolve

shared private zones available

DNS Firewall active

Resolver query logs configured
```

Again, one account request can trigger standardized platform services.

---

# 38.771 Step 13 — DR metadata

The account request included:

```text
primary_region=ap-south-1

dr_region=ap-southeast-1
```

This doesn't automatically deploy application DR.

But platform automation can use it to establish:

```text
regional network foundations

regional logging

regional security posture

regional IP allocations

DR-specific governance
```

before application deployment.

---

# 38.772 Account ready state

At the end:

```text
payments-prod
```

should ideally satisfy:

```text
Control Tower enrolled          ✓
Correct OU                      ✓
Account metadata                ✓
Security baseline               ✓
Central logging                 ✓
Identity access                 ✓
Network allocated               ✓
TGW attached                    ✓
DNS available                   ✓
Cost owner known                ✓
Contacts configured             ✓
DR metadata known               ✓
```

Then:

```text
READY FOR APPLICATION DEPLOYMENT
```

---

# 38.773 The account is the product

A platform engineer should start thinking:

```text
"We sell EC2 to developers"
```

less often.

Instead:

```text
"We provide a governed AWS
application account."
```

The account itself becomes an internal platform product.

Inputs:

```text
Owner
Environment
Compliance
Network profile
Regions
Cost center
```

Output:

```text
secure usable cloud environment
```

---

# 38.774 Golden account vs golden account vending

Do not maintain one manually configured:

```text
GoldenAccount
```

and clone tribal knowledge from it.

Prefer:

```text
Golden Account Definition
```

encoded as:

```text
Control Tower baseline

Organizations policies

AFT customizations

Terraform modules

identity mappings
```

Then new accounts are reproducible.

---

# 38.775 AFT bootstrap

Before vending accounts, AFT itself must be deployed.

Current prerequisites include:

```text
Control Tower landing zone

Control Tower home Region

dedicated AFT management account

Terraform distribution/version

VCS provider

runtime environment
```

AWS recommends referencing the official AFT Terraform module rather than maintaining a locally forked copy when possible. ([AWS Documentation][3])

---

# 38.776 AFT Terraform support

Current AWS documentation supports:

```text
Terraform Community Edition

HCP Terraform

Terraform Enterprise
```

and requires Terraform `1.6.1` or later for AFT. ([AWS Documentation][11])

The current official AFT module itself declares Terraform `>=1.6.1,<2.0.0` and AWS provider `>=6.0.0,<7.0.0`. ([GitHub][12])

Never freeze these numbers mentally forever—verify them when deploying.

---

# 38.777 Terraform OSS mode

When using Terraform Community Edition, AFT manages Terraform backend state for its AFT operations in S3 in the AFT management account and can replicate that backend state to a secondary Region when configured. ([AWS Documentation][11])

Concept:

```text
AFT State
   │
   ▼
Primary S3
AFT Region
   │
   │ replication
   ▼
Secondary Region
```

Notice the same DR principle appears in our platform tooling.

---

# 38.778 Important bootstrap state nuance

The Terraform state created when you initially deploy the AFT **module itself** must also be preserved/protected by your deployment workflow; the official module documentation warns that the module bootstrap does not automatically manage that external bootstrap state for you. ([GitHub][12])

So there are two ideas:

```text
AFT-managed workflow state

vs

Terraform state used to deploy AFT itself
```

Do not confuse them.

---

# 38.779 Example AFT bootstrap configuration

A representative bootstrap could look like:

```hcl
module "aft" {
  source = "github.com/aws-ia/terraform-aws-control_tower_account_factory"

  ct_management_account_id = var.management_account_id
  audit_account_id         = var.audit_account_id
  log_archive_account_id   = var.log_archive_account_id
  aft_management_account_id = var.aft_management_account_id

  ct_home_region = "ap-south-1"

  terraform_distribution = "oss"
  terraform_version      = "1.6.1"

  tf_backend_secondary_region = "ap-southeast-1"

  vcs_provider = "github"

  account_request_repo_name =
    "company/aft-account-request"

  account_provisioning_customizations_repo_name =
    "company/aft-account-provisioning-customizations"

  global_customizations_repo_name =
    "company/aft-global-customizations"

  account_customizations_repo_name =
    "company/aft-account-customizations"
}
```

The current official module exposes these inputs, including the Control Tower/AFT account IDs, home Region, Terraform distribution/version, secondary backend Region, and repository names. Pin an approved AFT release/ref in real production rather than consuming an unpinned moving branch. ([GitHub][12])

---

# 38.780 VCS choices

AFT supports Git-backed workflows. Current AWS documentation includes CodeCommit and alternative VCS integrations through CodeConnections, with supported external providers including options such as GitHub, GitLab, Bitbucket, GitHub Enterprise, and others supported by the AFT deployment configuration. ([AWS Documentation][1])

Important current setup nuance:

AWS documentation says that for a first-time AFT deployment without an existing CodeCommit repository, you should select an external supported VCS. ([AWS Documentation][3])

So don't blindly follow an old tutorial assuming every new customer will start with CodeCommit.

---

# 38.781 Why Git matters

The value isn't merely:

```text
Terraform files live somewhere.
```

It's:

```text
account creation
=
version-controlled change.
```

Git gives:

```text
review

approval

history

diff

ownership

rollback context
```

You can answer:

> Who requested the production account?

with:

```text
Pull Request #842
```

instead of:

```text
"I think John created it."
```

---

# 38.782 Feature options

AFT currently has optional framework features including capabilities around:

```text
CloudTrail data events

default VPC deletion

Enterprise Support enrollment
```

depending on configuration. ([AWS Documentation][1])

Treat these as platform-level choices.

---

# 38.783 Default VPC deletion nuance

Do not assume:

```text
aft_feature_delete_default_vpcs_enabled
```

means:

```text
Every vended account's default VPCs
will automatically disappear.
```

AWS's current AFT documentation notes that the feature removes default VPCs in the AFT management account itself but does not automatically remove default VPCs from every account AFT provisions; customizations may still be required there. ([AWS Documentation][13])

This is exactly why we verify current behavior instead of trusting feature names.

---

# 38.784 Account updates

Accounts aren't static.

Requirements change:

```text
Dev
→ Prod

NonPCI
→ PCI

Team A
→ Team B

CostCenter 4100
→ 4200
```

AFT can process updates through the account-request Git workflow. ([AWS Documentation][10])

---

# 38.785 What can you update?

Current AWS guidance says within `control_tower_parameters`, the primary field AFT allows you to change later is:

```text
ManagedOrganizationalUnit
```

Other request metadata such as `custom_fields` can also be updated. ([AWS Documentation][10])

Do not assume every original account-creation parameter is freely mutable later.

---

# 38.786 Moving Dev to Prod

Initial:

```hcl
ManagedOrganizationalUnit =
  "Development (ou-dev-1234)"
```

Later:

```hcl
ManagedOrganizationalUnit =
  "Production (ou-prod-5678)"
```

Merge.

Conceptually:

```text
Account
  │
  ▼
move OU
  │
  ▼
new OU policies
  │
  ▼
production customizations
```

But this transition should be carefully governed because moving OUs changes inherited organization controls.

---

# 38.787 Modern customization triggers

AFT now supports customization triggers for certain account-move events.

With the current `account_move` customization trigger enabled, an AFT/Account Factory OU move can automatically re-run global/account customizations so the target account receives configuration appropriate to its new OU. ([AWS Documentation][14])

Example:

```text
Development OU
      │
      ▼
move
      │
      ▼
Production OU
      │
      ▼
customization trigger
      │
      ▼
production customization
```

---

# 38.788 Important trigger limitation

AFT's current account-move customization trigger depends on the relevant Control Tower `UpdateManagedAccount` lifecycle event.

AWS explicitly warns that direct account moves in AWS Organizations and some Auto Enroll paths don't emit the event needed for that trigger; in those cases, customizations may need to be re-invoked manually. ([AWS Documentation][14])

So:

```text
OU changed
```

does not automatically guarantee:

```text
AFT customization re-ran
```

for every possible move path.

---

# 38.789 Never move governed accounts casually

Bad:

```text
Organizations console
      │
      ▼
drag account
Dev → Prod
```

without considering:

```text
Control Tower

AFT state

customization triggers

new SCPs

new RCPs

security policy

network model
```

OU movement is a production change.

---

# 38.790 Re-invoking customizations

AFT provides a Step Functions workflow:

```text
aft-invoke-customizations
```

that can re-run customizations for selected accounts. Current filtering supports targeting categories such as:

```text
all

OU

account tags

specific account IDs
```

with include/exclude semantics. ([AWS Documentation][8])

This is extremely useful when a global baseline changes.

---

# 38.791 Example global baseline update

You add:

```text
New organization inventory agent
```

to:

```text
aft-global-customizations
```

Now you need all 200 AFT accounts updated.

Instead of:

```text
log into account 1
log into account 2
...
```

invoke customizations across the selected managed fleet.

That is cloud platform scalability.

---

# 38.792 Target by OU

Example:

```text
Production OU only
```

Then re-run:

```text
new production incident-response configuration
```

across production accounts.

You avoid changing:

```text
Sandbox
```

unless required.

---

# 38.793 Target by tags

Example:

```text
Compliance=PCI
```

Select accounts such as:

```text
payments-prod

billing-prod

card-data-prod
```

Then apply PCI-specific customization.

This is why account tags should be trustworthy and standardized.

---

# 38.794 Target by account ID

Useful for:

```text
one-account repair

pilot deployment

canary customization
```

Pattern:

```text
Account 1
   ↓
validate
   ↓
Production OU
   ↓
All
```

The same progressive rollout philosophy we used for applications applies to governance changes.

---

# 38.795 Customization tracing

Current AFT supports customization request tracing using a unique tracing token propagated through the AFT customization Step Functions workflow and CloudWatch Logs. ([AWS Documentation][1])

This helps answer:

```text
Which request failed?

Where?

Which account?

Which workflow execution?

Which logs?
```

A very useful operational capability.

---

# 38.796 AFT metadata store

AFT stores account metadata in DynamoDB in the AFT management account during the provisioning workflow. ([AWS Documentation][7])

That metadata becomes part of AFT's state/event-driven account management model.

Important implication:

```text
AFT
does not simply map
one Terraform aws_organizations_account resource
directly to one account.
```

It orchestrates Account Factory/Control Tower through its workflow.

---

# 38.797 Important drift implication

AWS's AFT troubleshooting documentation notes that manual OU changes can fall outside AFT's normal event-driven state flow because the Terraform-managed account-request representation is tied to AFT metadata/workflows rather than simply managing an Organizations account directly. ([AWS Documentation][9])

This reinforces:

```text
Manage AFT accounts
through AFT-approved lifecycle paths.
```

---

# 38.798 Multiple account requests

You can submit multiple account requests, but current AFT processing queues account requests and handles them in a controlled pipeline workflow; AWS documentation describes requests being queued first-in, first-out. ([AWS Documentation][15])

Do not think:

```text
git commit with 500 accounts
=
500 accounts appear instantly.
```

Account provisioning is an asynchronous control-plane workflow.

---

# 38.799 Provisioning concurrency

The current AFT module also exposes concurrency settings for account factory operations and customization pipelines, allowing controlled parallelism rather than unbounded execution. ([GitHub][12])

This matters at large scale because organization/account APIs and downstream services have quotas.

---

# 38.800 Common failure #1 — bad account request

Example:

```text
Wrong OU

duplicate email

invalid fields

wrong customization name
```

Start with:

```text
AFT account request pipeline

CodeBuild logs

request validation

AFT metadata
```

AFT validates request input before the later customization stages. ([AWS Documentation][7])

---

# 38.801 Common failure #2 — repository not populated correctly

AFT expects the four repositories and required directory structure to be populated after deployment.

AWS explicitly identifies incorrectly populated repositories as a common AFT setup/troubleshooting issue. ([AWS Documentation][9])

So if:

```text
AFT deploy succeeded
```

but:

```text
account customizations don't run
```

check repository structure early.

---

# 38.802 Common failure #3 — modified framework IAM role

Symptoms:

```text
Account exists

customization pipeline:
AccessDenied
```

Check:

```text
AWSAFTExecution

AWSAFTAdmin

AWSAFTService
```

and related AFT-managed roles/policies.

AWS lists insufficient/modified AFT role permissions as a common cause of pipeline failures. ([AWS Documentation][9])

---

# 38.803 Common failure #4 — quotas

AFT depends on services with quotas including components such as:

```text
CodeBuild

Organizations

Systems Manager
```

and quota exhaustion can cause provisioning/customization failures. ([AWS Documentation][9])

At enterprise scale, platform teams should monitor:

```text
account creation limits

pipeline concurrency

CodeBuild

API throttling

customization concurrency
```

rather than discovering limits during a large migration.

---

# 38.804 Common failure #5 — customization works in some accounts only

Debug:

```text
1. Is account managed by AFT?

2. Is it present in account-request repo?

3. Correct customizations_name?

4. Folder exists?

5. Global customization succeeded?

6. AWSAFTExecution healthy?

7. SCP blocks Terraform?

8. Permissions boundary?

9. Region/service availability?

10. Terraform state healthy?
```

Do not immediately blame Terraform syntax.

---

# 38.805 Common failure #6 — SCP blocks AFT

Remember Part 2.

Suppose customization wants:

```text
ec2:DeleteVpc
```

but Production SCP denies it.

AFT assumes a role in the member account, and that member-account role remains subject to applicable organization guardrails.

So:

```text
Terraform code correct
+
AFT role powerful
+
SCP Deny
=
DENIED
```

This is expected governance behavior.

---

# 38.806 Do not weaken SCP just to "make pipeline green"

Bad incident response:

```text
AFT failed

→ detach production SCP
```

Now your automation succeeds while governance disappears.

Better:

```text
Identify exact action

Does customization actually need it?

Should an approved exception exist?

Can design avoid the action?

Can change happen in correct delegated account?
```

Pipelines must operate **inside** governance.

---

# 38.807 Auto Enroll interaction

Current AFT documentation includes an important limitation around Control Tower Auto Enroll.

Accounts enrolled through Auto Enroll can lack the Service Catalog provisioned-product relationship AFT expects for some import/update workflows; AWS documents using OU registration as part of the workaround for bringing such accounts into compatible lifecycle management. ([AWS Documentation][10])

This is a brownfield detail worth remembering.

---

# 38.808 Importing existing accounts

AFT can manage existing Control Tower accounts that weren't originally provisioned by AFT, provided prerequisites are met, including that the account already belongs to the Control Tower organization and is enrolled in Control Tower. ([AWS Documentation][16])

Concept:

```text
Existing account
      │
      ▼
Control Tower enrolled
      │
      ▼
add matching AFT account request
      │
      ▼
AFT manages updates/customizations
```

This is useful during migration from older account-vending systems.

---

# 38.809 Don't import blindly

Before onboarding an existing account into AFT, inventory:

```text
existing Terraform

manual IAM

existing network

existing Config

existing contacts

existing account tags

custom DNS

security services
```

Otherwise global AFT customization may conflict with resources another tool already owns.

Ownership reconciliation comes first.

---

# 38.810 AFT vs Account Factory Customization — AFC

Modern Control Tower also has:

# Account Factory Customization — AFC

AFC provides Control Tower-based account customization through configurable blueprints and is a different mechanism from AFT's Git/Terraform pipeline approach. AWS lists AFC alongside other Control Tower provisioning approaches. ([AWS Documentation][17])

Mental model:

```text
AFC
=
Control Tower customization approach


AFT
=
Terraform/GitOps account platform
```

Do not confuse the acronyms.

---

# 38.811 When AFT fits well

AFT is especially attractive when your organization already operates:

```text
Terraform

Git pull requests

CI/CD

platform engineering

Infrastructure as Code
```

and wants account creation governed through the same engineering model.

If your organization does not use Terraform, other Account Factory/Control Tower provisioning approaches may be simpler.

---

# 38.812 Why AFT is a platform-engineering tool

AFT lets a platform team expose:

```text
simple inputs
```

such as:

```text
account_name
owner
environment
compliance
network_profile
```

while hiding:

```text
Organizations API

Service Catalog internals

Control Tower enrollment

execution roles

Terraform state

security integration

network IDs
```

That is exactly what a platform should do:

> **Offer a simple interface over complex infrastructure.**

---

# 38.813 Account lifecycle state machine

Think:

```text
REQUESTED
    │
    ▼
APPROVED
    │
    ▼
PROVISIONING
    │
    ▼
CONTROL_TOWER_ENROLLED
    │
    ▼
BASELINE_APPLYING
    │
    ▼
NETWORK_ONBOARDING
    │
    ▼
IDENTITY_ONBOARDING
    │
    ▼
READY
```

Later:

```text
READY
  │
  ▼
OU_MOVE
  │
  ▼
REBASELINE
```

And eventually:

```text
READY
  │
  ▼
DECOMMISSION_REQUESTED
  │
  ▼
DATA_RETENTION
  │
  ▼
UNENROLL
  │
  ▼
CLOSE
```

Account lifecycle deserves the same rigor as application lifecycle.

---

# 38.814 Account decommissioning is not `git rm`

This is critical.

Deleting an account request from the AFT repository can remove the account from the **AFT pipeline**, but AWS explicitly states that removing an account from AFT does **not** close the AWS account and is irreversible from AFT's state perspective. ([AWS Documentation][18])

So:

```text
git rm payments-prod.tf
```

does **not** mean:

```text
AWS account safely destroyed.
```

---

# 38.815 Remove from AFT vs unenroll vs close

Three distinct operations:

```text
REMOVE FROM AFT

AFT stops managing it.


UNENROLL FROM CONTROL TOWER

Control Tower stops governing it.


CLOSE AWS ACCOUNT

Account enters closure lifecycle.
```

These are different control planes and should not be conflated. AWS explicitly distinguishes removing an account from AFT from unmanaging/closing the underlying account. ([AWS Documentation][18])

---

# 38.816 Safe account-retirement sequence

A production runbook might be:

```text
1. Business owner approves retirement.

2. Stop new deployments.

3. Inventory resources.

4. Export required data.

5. Retain backups.

6. Confirm legal/compliance retention.

7. Disable external integrations.

8. Remove network exposure.

9. Remove identity assignments.

10. Preserve security logs.

11. Remove account from AFT
    at appropriate lifecycle point.

12. Unenroll/unmanage from Control Tower
    if closing.

13. Close through Organizations/account
    lifecycle.

14. Monitor closure status.

15. Retain CMDB/audit record.
```

AWS recommends unenrolling a Control Tower account before closure; closing it while still enrolled can leave it shown as suspended/enrolled and can interfere with OU re-registration workflows. ([AWS Documentation][19])

---

# 38.817 Suspended OU pattern

A useful organizational pattern:

```text
Production
   │
   ▼
Account retired
   │
   ▼
Suspended OU
```

with highly restrictive policies while:

```text
retention checks

closure process

final audit
```

complete.

This prevents a retired account from remaining mixed with active production.

---

# 38.818 Decommissioning must consider backups

Closing an account without checking:

```text
AWS Backup

S3 retention

RDS snapshots

CloudTrail evidence

KMS dependencies
```

can destroy recovery or compliance assumptions.

Account closure is a data-governance event, not merely billing cleanup.

---

# 38.819 AFT's own DR

Interesting production question:

> **What happens if the Region hosting AFT has a serious problem?**

AFT can replicate Terraform OSS backend state to a configured secondary Region. ([AWS Documentation][11])

But that does **not** automatically mean the full AFT execution platform is active-active.

Think:

```text
STATE DR
≠
FULL SERVICE DR
```

You still need a documented recovery process for:

```text
source repositories

AFT bootstrap state

pipeline recreation

AFT management account

secrets/tokens

external VCS connections
```

---

# 38.820 Protect AFT bootstrap state

Because AFT controls the lifecycle of many AWS accounts, its bootstrap Terraform state is high-value infrastructure state.

Protect it using appropriate:

```text
S3 versioning

encryption

restricted IAM

state locking where applicable

backup

audit
```

and avoid exposing sensitive variables.

The official AFT module documentation explicitly warns that the Terraform bootstrap state can contain sensitive values and must be protected. ([GitHub][12])

---

# 38.821 AFT is a crown-jewel platform account

If attacker compromises:

```text
AFT Management Account
```

they may potentially influence:

```text
new account provisioning

global customization

managed account pipelines
```

Therefore protect it similarly to:

```text
Security Tooling

Network

Management
```

with:

```text
strong Identity Center permissions

minimal administrators

short privileged sessions

CloudTrail

SCP boundaries

no ordinary workloads
```

---

# 38.822 Separate AFT operator roles

Possible groups:

```text
AFT-Readers

AFT-Account-Request-Approvers

AFT-Platform-Admins

AFT-Emergency-Admins
```

Do not make all developers:

```text
AdministratorAccess
```

inside the AFT management account.

Usually, developers should submit account requests through Git, not log into AFT infrastructure.

---

# 38.823 Developer interface should be Git, not AWS console

Ideal:

```text
Developer
   │
   ▼
Pull Request
```

Not:

```text
Developer
   │
   ▼
AFT Management Account
   │
   ▼
click random CodePipeline buttons
```

The abstraction boundary protects both developers and the platform.

---

# 38.824 Validation after account creation

Never stop at:

```text
Pipeline = SUCCESS
```

Validate:

```text
Organizations account exists

correct OU

Control Tower enrollment healthy

expected SCPs/RCPs

expected account tags

Identity Center access

CloudTrail delivery

Config

GuardDuty

Inspector

Security Hub

IPAM/VPC

TGW attachment

DNS

Flow Logs

billing/cost ownership
```

A pipeline success proves pipeline execution—not necessarily platform usability.

---

# 38.825 Account readiness endpoint — concept

Just like applications have:

```text
/health/ready
```

your cloud platform should conceptually have:

```text
AccountReady?
```

with machine-checkable results:

```text
ControlTower = PASS

Identity      = PASS

Security      = PASS

Logging       = PASS

Networking    = PASS

FinOps        = PASS
```

Only then expose:

```text
Status = READY
```

to the requester.

---

# 38.826 Account-vending SLO

A mature platform might track:

```text
Account provisioning success rate

Median account-ready time

95th percentile ready time

Customization failure rate

Security onboarding failures

Manual intervention rate

AFT pipeline availability
```

Do not only measure:

```text
number of accounts created.
```

Measure platform quality.

---

# 38.827 Account-vending error budget

Suppose:

```text
100 account requests
```

and:

```text
20 require human repair.
```

That's not healthy automation.

The platform team should treat frequent provisioning failures as product reliability problems:

```text
Find cause
   ↓
automate fix
   ↓
reduce toil
```

This is where Platform Engineering and SRE principles begin intersecting.

---

# 38.828 Account catalog

Developers shouldn't need infinite custom account configurations.

Offer a small catalog:

```text
Sandbox

Standard Dev

Standard Prod

PCI Prod

Data Platform

Security Tooling
```

Each maps to:

```text
OU

network profile

security baseline

backup requirements

identity assignments

cost controls
```

This keeps platform variability manageable.

---

# 38.829 Example templates

```text
SANDBOX

OU:
Sandbox

Network:
limited Internet

Security:
baseline

Backup:
none/minimal


STANDARD PROD

OU:
Production

Network:
inspected

Security:
full baseline

Backup:
required

DR:
optional


PCI PROD

OU:
Regulated/Production

Network:
restricted

Security:
enhanced

Backup:
immutable

Logging:
extended
```

The request interface becomes understandable to teams.

---

# 38.830 Platform policy: no handcrafted accounts

Once AFT is mature, an organization can establish:

```text
All standard workload accounts
must be requested through
approved account-vending workflow.
```

This prevents:

```text
random Organizations CreateAccount calls

console-created unmanaged accounts

missing security

missing billing owner

missing network baseline
```

Exceptions should have explicit governance.

---

# 38.831 Account vending + FinOps

Every request should capture:

```text
CostCenter

Owner

Environment

Project
```

before resources are deployed.

Then FinOps can answer:

```text
Who pays for account 123456789012?
```

without chasing teams.

Account boundaries often make cost attribution much cleaner.

---

# 38.832 Account vending + security

Security input:

```text
DataClassification=Restricted
```

can trigger:

```text
stronger controls

security contacts

additional logging

restricted egress

special Macie policy

backup requirements
```

Now security becomes an automated property of the environment.

---

# 38.833 Account vending + networking

Input:

```text
NetworkProfile=private-prod
```

can trigger:

```text
No public subnets

TGW attachment

central egress

production Route 53 Profile

PrivateLink endpoints

corporate prefixes
```

Developers specify intent.

Platform determines implementation.

---

# 38.834 Account vending + Identity Center

Input:

```text
OwnerGroup=Payments
```

can map to:

```text
PaymentsDevelopers
→ DevAdmin in dev account

PaymentsSRE
→ ProdOperator in prod account

SecurityAuditors
→ Audit in both
```

No IAM-user creation required.

---

# 38.835 Account vending + observability

Baseline can ensure:

```text
CloudTrail

Config

security findings

network Flow Logs

platform events

account provisioning logs
```

are available before workloads arrive.

That is dramatically easier than retrofitting them after the first incident.

---

# 38.836 Account vending + DR

For a critical application:

```text
DRRequired=true
```

can trigger platform preparation:

```text
secondary-region network allocation

security enablement

regional DNS

backup policy

DR account metadata
```

without attempting to deploy the application's actual database/compute.

Account platform creates the runway.

Application platform flies the plane.

---

# 38.837 AFT rollout strategy

Do not immediately use AFT for 500 production accounts.

Use:

```text
Phase 1
Sandbox account


Phase 2
NonProd account


Phase 3
Low-risk production


Phase 4
Standard production classes


Phase 5
regulated/special accounts
```

At every phase validate:

```text
provisioning

updates

OU moves

customization reruns

failure recovery

decommissioning
```

---

# 38.838 Brownfield adoption

Existing organization:

```text
300 accounts
```

You don't need to recreate them.

AFT can onboard eligible existing Control Tower-managed accounts, but you should first establish consistent metadata and reconcile existing configuration ownership. ([AWS Documentation][16])

A sensible migration:

```text
Inventory
   ↓
enroll Control Tower where needed
   ↓
pilot existing account
   ↓
add AFT request definition
   ↓
run baseline
   ↓
validate
   ↓
expand
```

---

# 38.839 Do not let global customization destroy brownfield resources

Example:

```text
Existing account:
custom IAM role already exists
```

Global AFT code:

```text
create same role
```

Terraform:

```text
AlreadyExists
```

or worse, conflicting ownership.

Brownfield migrations require:

```text
import

adopt

rename

or intentionally leave unmanaged
```

rather than assuming greenfield state.

---

# 38.840 AFT troubleshooting model

Remember:

# **R-P-C-A**

```text
R
REQUEST

Did Git/account request work?


P
PROVISION

Did Control Tower create/enroll account?


C
CUSTOMIZE

Did global/account customization work?


A
AUTHORIZE

Did IAM/SCP/RCP allow it?
```

Then examine network/service dependencies.

---

# 38.841 Troubleshooting — account not created

Check:

```text
Git push received?

CodeConnection healthy?

Account request pipeline?

Terraform validation?

Account email unique?

OU valid?

Control Tower healthy?

Service quotas?

Organizations/account limits?

Service Catalog?
```

AFT provisioning is a chain, so locate the failed stage before editing random Terraform.

---

# 38.842 Troubleshooting — account exists, but customization absent

Check:

```text
AFT metadata registered?

AWSAFTExecution exists?

per-account pipeline created?

global customization ran?

account_customizations_name matches folder?

folder structure correct?

trigger/reinvoke needed?
```

AFT's current framework creates the account execution role and per-account pipeline after provisioning before later customization stages run. ([AWS Documentation][7])

---

# 38.843 Troubleshooting — OU move but Prod baseline missing

Ask:

```text
How was account moved?
```

If:

```text
AFT/Account Factory
```

and account-move trigger enabled:

```text
customization may auto-run.
```

If:

```text
direct AWS Organizations move
```

the current AFT event trigger may not run; manually re-invoke as required. ([AWS Documentation][14])

This is a very strong interview-level nuance.

---

# 38.844 Troubleshooting — state problems

Terraform OSS AFT stores state in AFT-managed S3 backends for its ongoing workflows. ([AWS Documentation][11])

If state goes missing/corrupt:

```text
Do not blindly recreate resources.
```

First determine:

```text
Which state?

AFT bootstrap?

Global customization?

Account customization?

Pipeline state?

Primary or secondary backend?
```

State loss in an account-management platform can have wide blast radius.

---

# 38.845 Removing account from AFT is irreversible

AWS explicitly warns:

```text
remove account from AFT
```

can cause loss of AFT state and cannot simply be reversed through normal AFT lifecycle. ([AWS Documentation][18])

Therefore do not use removal as a troubleshooting trick.

Bad:

```text
Pipeline broken

→ remove account from AFT
→ re-add
```

without understanding consequences.

---

# 38.846 AFT platform security review

Review:

```text
AFT management account access

Git repository protections

CodeConnections

Terraform tokens

backend S3 permissions

KMS

AWSAFT roles

CodeBuild roles

Step Functions roles

SNS notifications

CloudWatch logs

SCP exceptions
```

Account automation is privileged infrastructure.

---

# 38.847 Protect repositories

A malicious merge to:

```text
aft-global-customizations
```

could potentially modify every managed account during customization rollout.

Therefore require:

```text
branch protection

PR review

security/platform approvals

signed commits if appropriate

restricted merge permissions

CI validation
```

Treat these repositories like production infrastructure code.

---

# 38.848 Global customization is high blast radius

Compare:

```text
application repo error
→ one service
```

versus:

```text
aft-global-customizations error
→ potentially many accounts
```

Therefore:

```text
canary rollout

test accounts

validation

controlled re-invoke
```

are especially important.

---

# 38.849 AFT is not "set and forget"

AWS maintains AFT as an evolving solution/module and recommends keeping the framework version current; outdated versions are explicitly listed among troubleshooting considerations. ([AWS Documentation][9])

Maintain:

```text
AFT version

Terraform version

AWS provider compatibility

Control Tower compatibility

VCS integration

pipeline health
```

just like other production platform software.

---

# 38.850 Do not locally fork AFT casually

AWS notes that if you modify the AFT core source code yourself, support for that modified deployment is limited/best-effort. ([AWS Documentation][9])

Prefer:

```text
supported extension points
```

such as:

```text
customization repositories

module configuration

Step Functions integrations
```

instead of editing framework internals.

---

# 38.851 Platform engineering maturity levels

### Level 1

```text
Manual console account creation
```

### Level 2

```text
Control Tower Account Factory
```

### Level 3

```text
AFT + Git requests
```

### Level 4

```text
AFT + security + identity
+ network automation
```

### Level 5

```text
Self-service portal/API
      │
      ▼
AFT backend
      │
      ▼
fully governed account
```

At Level 5, developers might never even know AFT exists.

---

# 38.852 Internal developer portal model

Developer sees:

```text
CREATE AWS ENVIRONMENT

Application:
Payments

Environment:
Production

Compliance:
PCI

Primary Region:
Mumbai

DR:
Singapore

Network:
Private
```

Click:

```text
REQUEST
```

Portal backend creates:

```text
Git pull request
```

or invokes approved platform automation.

After approvals:

```text
AFT
→ Account
→ Baselines
→ Network
→ Security
```

This is true platform self-service.

---

# 38.853 Human approval still has value

Don't remove all approval because:

```text
automation exists.
```

Production accounts can create:

```text
cost

security scope

regulatory obligations

operational ownership
```

A mature workflow may automate execution while preserving:

```text
business approval

security approval

FinOps validation
```

where justified.

Automation eliminates toil—not governance.

---

# 38.854 Senior interview — What is AFT?

Strong answer:

> **AWS Control Tower Account Factory for Terraform is a Terraform- and Git-based framework for provisioning and customizing Control Tower-governed AWS accounts. It runs from a dedicated AFT management account, processes version-controlled account requests, uses Control Tower Account Factory for the account lifecycle, and then applies provisioning, global, and account-specific customizations. It is intended for account lifecycle automation rather than ordinary application deployment.** ([AWS Documentation][1])

---

# 38.855 Interview — Account Factory vs AFT

```text
Account Factory
=
Control Tower account provisioning


AFT
=
Terraform/GitOps framework
around account provisioning
and customization
```

---

# 38.856 Interview — Why separate AFT management account?

Answer:

> To isolate AFT pipelines, execution roles, metadata, state, and customization infrastructure from the highly privileged Organizations/Control Tower management account and from application workloads. AWS recommends a dedicated AFT management account and even recommends a dedicated OU for it. ([AWS Documentation][3])

---

# 38.857 Interview — four repositories

Answer:

```text
aft-account-request

aft-account-provisioning-customizations

aft-global-customizations

aft-account-customizations
```

AWS currently requires these four functional repositories in the AFT workflow. ([AWS Documentation][5])

---

# 38.858 Interview — global vs account customizations

```text
GLOBAL
=
every AFT-managed account


ACCOUNT
=
specific account/template
```

Global customizations execute before targeted account customizations. ([AWS Documentation][4])

---

# 38.859 Interview — custom fields

> AFT account-request custom fields let a platform attach arbitrary account metadata which AFT stores in SSM Parameter Store under the AFT custom-fields path. Later customizations can consume that metadata to drive configuration. ([AWS Documentation][6])

This is one of the key mechanisms for turning AFT into an intent-driven account platform.

---

# 38.860 Interview — OU update

Current AFT account updates allow changing the account's `ManagedOrganizationalUnit`, while most original Control Tower creation fields are not freely mutable after creation. ([AWS Documentation][10])

---

# 38.861 Interview — AFT and Auto Enroll

Current nuance:

> Accounts enrolled through Control Tower Auto Enroll can require additional handling before AFT can manage them through its normal import/update lifecycle, because AFT depends on Account Factory/Service Catalog lifecycle artifacts. ([AWS Documentation][10])

This is an advanced brownfield question.

---

# 38.862 Interview — Does deleting request close account?

# No.

Removing the request from AFT stops AFT's management and removes related AFT metadata/pipeline state, but does not itself close the underlying Control Tower/AWS account. ([AWS Documentation][18])

---

# 38.863 Interview — Can AFT deploy applications?

Technically customization code can create AWS resources, but AWS explicitly states the AFT pipeline is **not intended** as the application-resource deployment pipeline for resources applications require to run. ([AWS Documentation][1])

Correct architecture:

```text
AFT
→ account foundation


Workload IaC
→ application
```

---

# 38.864 Interview trap — AFT management = Control Tower management

Wrong.

They are separate accounts. ([AWS Documentation][1])

---

# 38.865 Interview trap — one repository

Wrong.

AFT's standard operating model has four repository responsibilities. ([AWS Documentation][5])

---

# 38.866 Interview trap — all customization belongs in account-specific repo

Wrong.

Universal configuration belongs in:

```text
global customizations
```

while account-specific differences belong in:

```text
account customizations.
```

---

# 38.867 Interview trap — OU move always triggers customization

Wrong.

Current automatic customization triggers depend on supported Control Tower lifecycle event paths; direct Organizations moves and certain Auto Enroll workflows do not automatically trigger account-move customization re-execution. ([AWS Documentation][14])

---

# 38.868 Interview trap — AFT replaces Organizations policies

Wrong.

Use:

```text
SCP/RCP
```

for organization-level guardrails.

Use:

```text
AFT
```

for account provisioning/customization.

Do not encode every organization policy as a per-account Terraform customization.

---

# 38.869 Interview trap — AFT replaces Control Tower

Wrong.

AFT **depends on** Control Tower; an existing Control Tower landing zone is a prerequisite. ([AWS Documentation][1])

---

# 38.870 Interview trap — AFT automatically makes account production-ready

Not necessarily.

AFT can automate your readiness requirements, but only if you encode:

```text
security

identity

network

logging

metadata

validation
```

correctly.

Automation merely executes the platform definition you designed.

---

# 38.871 Interview trap — pipeline success means account is usable

Wrong.

Validate:

```text
governance

security

network

identity

DNS

logging
```

at runtime.

This is the same principle we've repeatedly learned:

```text
Terraform apply success
≠
system readiness.
```

---

# 38.872 Complete account vending architecture

```text
                          DEVELOPER

                              │
                              ▼
                       SELF-SERVICE FORM
                         or Git change
                              │
                              ▼
                         PULL REQUEST
                              │
                    Review / Approval
                              │
                              ▼
                    aft-account-request
                              │
                              ▼
                     AFT MANAGEMENT
                         ACCOUNT
                              │
                              ▼
                      CONTROL TOWER
                       ACCOUNT FACTORY
                              │
                              ▼
                        NEW ACCOUNT
                              │
                     Correct Production OU
                              │
         ┌────────────────────┼───────────────────┐
         ▼                    ▼                   ▼

   ORGANIZATION          CONTROL TOWER           AFT
     POLICIES              BASELINE          CUSTOMIZATION
         │                    │                   │
       SCP/RCP              Controls              │
                                                  ▼
                                       Global Customization
                                                  │
                                                  ▼
                                       Account Customization

                                                  │
         ┌────────────────────────────────────────┼─────────────┐
         ▼                                        ▼             ▼

      SECURITY                                  NETWORK      IDENTITY
         │                                        │             │
   GuardDuty/Hub                              IPAM/VPC      Permission
   Config/Logs                               TGW/DNS          Sets
         │                                        │             │
         └────────────────────────────────────────┼─────────────┘
                                                  ▼
                                          ACCOUNT READY
                                                  │
                                                  ▼
                                      APPLICATION CI/CD
```

That is the full enterprise account-vending model.

---

# 38.873 Account Factory mental equation

```text
GOVERNED ACCOUNT
=
ACCOUNT FACTORY

+
OU PLACEMENT

+
ORGANIZATION POLICIES

+
CONTROL TOWER BASELINE

+
AFT GLOBAL CUSTOMIZATIONS

+
ACCOUNT CUSTOMIZATIONS

+
IDENTITY

+
SECURITY

+
NETWORK

+
VALIDATION
```

---

# 38.874 Never-forget Part 7 rules

```text
1.
Account Factory vends
Control Tower accounts.


2.
AFT adds Terraform + GitOps.


3.
AFT requires a Control Tower
landing zone first.


4.
AFT uses a dedicated
AFT management account.


5.
The AFT management account
is not the Control Tower
management account.


6.
AFT is for account lifecycle
and customization,
not normal application deployment.


7.
AFT uses four repository roles:
request,
provisioning customization,
global customization,
account customization.


8.
Account requests should
enter through reviewed Git changes.


9.
OU placement defines
major governance inheritance.


10.
Account tags provide
business metadata.


11.
Custom fields provide
automation metadata.


12.
Global customization
should stay truly global.


13.
Account customization
handles exceptions/classes.


14.
AWSAFTExecution is part
of the AFT account-control path.


15.
AFT framework roles should
not be manually altered casually.


16.
AFT customizations must still
obey SCP/RCP governance.


17.
OU moves are real
production governance changes.


18.
Customization triggers do not
cover every possible move path.


19.
Re-invoke customizations
when baseline changes require it.


20.
AFT account removal
does not equal AWS account closure.


21.
Account decommissioning needs
a formal lifecycle.


22.
AFT repositories are
high-blast-radius infrastructure code.


23.
Protect AFT Terraform state.


24.
Treat the AFT management account
as a crown-jewel platform account.


25.
The account should be considered
READY only after runtime validation.
```

---

# 38.875 Part 7 checkpoint

You can now explain:

```text
✓ Account Factory

✓ AFT

✓ Account Factory vs AFT

✓ AFT management account

✓ GitOps account vending

✓ four AFT repositories

✓ account request structure

✓ Control Tower parameters

✓ account tags

✓ change metadata

✓ custom fields

✓ account customizations name

✓ global customizations

✓ account-specific customizations

✓ provisioning customization framework

✓ AWSAFTExecution

✓ AFT pipeline stages

✓ per-account pipelines

✓ Terraform/Bash/Python helpers

✓ AFT bootstrap

✓ Terraform versions/distributions

✓ OSS state backend

✓ secondary backend Region

✓ VCS integration

✓ account updates

✓ OU moves

✓ customization triggers

✓ re-invocation

✓ OU/tag/account targeting

✓ brownfield account adoption

✓ Auto Enroll nuance

✓ security onboarding

✓ identity onboarding

✓ network onboarding

✓ IPAM/TGW/DNS integration

✓ account readiness

✓ account decommissioning

✓ AFT platform security

✓ AFT troubleshooting
```

---

# ✅ Lesson 38 — Part 7 Complete

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
Delegated Administration                NEXT

Part 9
Terraform Governance Capstone

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 8

## AWS Organizations Delegated Administration — Deep Dive

Next we'll connect every centralized AWS service to the **correct account ownership model**:

```text
                      MANAGEMENT ACCOUNT
                              │
                    Organizations authority
                              │
              ┌───────────────┼────────────────┐
              │               │                │
              ▼               ▼                ▼

       SECURITY TOOLING    NETWORK          LOG ARCHIVE
              │               │                │
      Security Hub         IPAM            Security Lake
      GuardDuty            Firewall Mgr
      Inspector
      Macie
      Access Analyzer
              │
              └───────────────┼────────────────┘
                              ▼
                     MEMBER ACCOUNTS
```

We'll go deeply into **trusted access vs delegated administrator, service-linked roles, registering/deregistering delegated admins, organization service integrations, why the management account should remain minimal, service-specific Regional behavior, GuardDuty/Security Hub/Inspector/Macie/IPAM/Firewall Manager/CloudTrail/Config/Backup delegated administration, multiple delegated admins where supported, cross-account failure modes, least privilege, SCP interaction, and a complete enterprise delegation matrix**.

[1]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html "Overview of AWS Control Tower Account Factory for Terraform (AFT) - AWS Control Tower"
[2]: https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html?utm_source=chatgpt.com "What Is AWS Control Tower? - AWS ..."
[3]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-getting-started.html?utm_source=chatgpt.com "Deploy AWS Control Tower Account Factory for Terraform ..."
[4]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-architecture.html "AFT Architecture - AWS Control Tower"
[5]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-post-deployment.html?utm_source=chatgpt.com "Post-deployment steps - AWS Control Tower"
[6]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-provision-account.html "Provision a new account with AFT - AWS Control Tower"
[7]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-provisioning-framework.html "AFT account provisioning pipeline - AWS Control Tower"
[8]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-account-customization-options.html "Account customizations - AWS Control Tower"
[9]: https://docs.aws.amazon.com/controltower/latest/userguide/account-troubleshooting-guide.html?utm_source=chatgpt.com "Account Factory for Terraform (AFT) troubleshooting guide"
[10]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-update-account.html "Update an existing account - AWS Control Tower"
[11]: https://docs.aws.amazon.com/controltower/latest/userguide/version-supported.html "Terraform and AFT versions - AWS Control Tower"
[12]: https://github.com/aws-ia/terraform-aws-control_tower_account_factory "GitHub - aws-ia/terraform-aws-control_tower_account_factory: AWS Control Tower Account Factory · GitHub"
[13]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-feature-options.html?utm_source=chatgpt.com "Enable feature options - AWS Control Tower"
[14]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-customization-triggers.html "Customization triggers - AWS Control Tower"
[15]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-multiple-account-requests.html?utm_source=chatgpt.com "Submit multiple account requests - AWS Control Tower"
[16]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-update-account.html?utm_source=chatgpt.com "Update an existing account - AWS Control Tower"
[17]: https://docs.aws.amazon.com/controltower/latest/userguide/methods-of-provisioning.html?utm_source=chatgpt.com "Provision accounts within AWS Control Tower"
[18]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-remove-account.html?utm_source=chatgpt.com "Remove an account from AFT - AWS Control Tower"
[19]: https://docs.aws.amazon.com/controltower/latest/userguide/delete-account.html?utm_source=chatgpt.com "Close an account created in Account Factory"
