# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 9: Terraform Multi-Account Governance Capstone

Now we connect **everything from Parts 1–8** into one production IaC architecture.

Our target is not merely:

```text
terraform apply
```

Our target is:

```text
Git
 │
 ▼
CI/CD
 │
 ▼
Terraform
 │
 ├── Management Account
 ├── Security Tooling
 ├── Log Archive
 ├── Network
 ├── Shared Services
 ├── AFT
 └── Workload Accounts
        │
        ▼
    governed by:
    Organizations
    Control Tower
    SCP/RCP
    Identity Center
    Security
    Networking
```

The hardest part is not writing HCL.

It is deciding:

> **Which Terraform state owns which control plane, under which AWS identity, with what blast radius?**

HashiCorp supports AWS cross-account provisioning through `AssumeRole`, and Terraform provider aliases let a root configuration use multiple AWS account/Region provider configurations. Provider configurations belong in root modules and can be explicitly passed into child modules. ([HashiCorp Developer][1])

---

# 38.980 Capstone target architecture

We will build this mental production environment:

```text
                         AWS ORGANIZATION
                               │
                        Management Account
                               │
                               ▼
                              Root
                               │
      ┌────────────────────────┼───────────────────────────┐
      │                        │                           │
      ▼                        ▼                           ▼

 Security OU            Infrastructure OU             Workloads OU
      │                        │                           │
 ┌────┴─────┐        ┌────────┼─────────┐           ┌─────┴─────┐
 ▼          ▼        ▼        ▼         ▼           ▼           ▼

Security   Log      Network  Shared     AFT       Production   NonProd
Tooling   Archive            Services
                      │
                      ├── IPAM
                      ├── TGW
                      ├── RAM
                      ├── Resolver
                      └── DNS Profiles

                                                       │
                                                       ▼
                                                 payments-prod
                                                       │
                                            ┌──────────┼──────────┐
                                            ▼          ▼          ▼
                                         Mumbai      Singapore   Security
                                         network       DR       baseline
```

AFT remains responsible for **account provisioning/customization**, not ordinary application deployment. AWS explicitly states that AFT is not intended to deploy application runtime resources such as the EC2 instances an application needs. ([AWS Documentation][2])

---

# 38.981 The first mistake: one Terraform state for the entire company

Imagine:

```text
terraform.tfstate

contains:

Organizations
OUs
SCPs
Identity Center
Security Hub
GuardDuty
TGW
IPAM
DNS
AFT
Payments
Orders
RDS
EKS
```

Now:

```bash
terraform plan
```

must reason about your entire enterprise.

And:

```text
state corruption
wrong destroy
provider failure
credential problem
locking problem
```

has an enormous blast radius.

### Never-forget:

> **Terraform module boundary and Terraform state boundary are different architectural decisions.**

---

# 38.982 State should follow lifecycle + ownership + blast radius

A strong state design might be:

```text
terraform-platform/
│
├── 00-bootstrap/
│
├── 01-organizations/
│
├── 02-org-policies/
│
├── 03-security-delegation/
│
├── 04-security-platform/
│
├── 05-network-global/
│
├── 06-network-mumbai/
│
├── 07-network-singapore/
│
├── 08-shared-services/
│
├── 09-identity-center/
│
├── 10-aft-bootstrap/
│
└── modules/
```

Then workload application repositories remain separate.

---

# 38.983 Why separate states?

Consider:

```text
Organizations
```

changes rarely.

```text
Network routing
```

changes somewhat more frequently.

```text
Applications
```

may change many times per day.

Therefore:

```text
Organizations state
≠
Application state
```

A useful rule:

```text
same lifecycle
+
same owners
+
same privilege level
+
same failure blast radius
=
possible same state
```

Otherwise strongly consider separation.

---

# 38.984 Example state ownership

| State                   | Runs as                            | Typical owner     |
| ----------------------- | ---------------------------------- | ----------------- |
| Organization            | Management-account role            | Cloud governance  |
| SCP/RCP                 | Management-account/org policy role | Security/platform |
| Security delegation     | Management-account role            | Security platform |
| Security service config | Security Tooling role              | Security          |
| Network global          | Network role                       | Network           |
| Mumbai network          | Network role                       | Network           |
| Singapore network       | Network role                       | Network           |
| Identity Center         | Identity role                      | Identity/platform |
| AFT bootstrap           | AFT/control-plane roles            | Platform          |
| App stack               | Workload account role              | Application team  |

This gives **least-privilege Terraform**, not one god-mode pipeline.

---

# 38.985 Remote state architecture

Conceptually:

```text
                    TERRAFORM STATE ACCOUNT
                             │
                             ▼
                       S3 state bucket
                             │
            ┌────────────────┼─────────────────┐
            ▼                ▼                 ▼
      organization/      network/          security/
        tfstate           tfstate           tfstate
```

You can also isolate high-risk states into separate buckets/accounts if organizational requirements justify it.

---

# 38.986 Important Terraform state update — 2026

In older Terraform architectures, including some of our earlier labs, the classic pattern was:

```text
S3
+
DynamoDB lock table
```

Current Terraform S3 backend documentation now supports **native S3 lockfiles** through:

```hcl
use_lockfile = true
```

and explicitly marks DynamoDB-based locking as **deprecated** and planned for removal in a future Terraform minor release. HashiCorp currently allows both mechanisms simultaneously during migration. ([HashiCorp Developer][3])

So for a new platform, the preferred mental model is now:

```text
S3 state
+
S3 lockfile
```

rather than automatically building a new DynamoDB lock table.

---

# 38.987 Modern S3 backend example

```hcl
terraform {
  backend "s3" {
    bucket       = "company-terraform-state"
    key          = "organizations/core.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

HashiCorp also strongly recommends enabling S3 bucket versioning for state recovery. When `use_lockfile` is enabled, Terraform uses a `.tflock` S3 object and requires the corresponding object permissions. ([HashiCorp Developer][3])

---

# 38.988 State bucket protection

Treat Terraform state as sensitive.

It may contain:

```text
resource IDs

internal topology

policy documents

database metadata

generated secrets depending on resources

account IDs

role ARNs
```

Use:

```text
S3 Block Public Access
encryption
versioning
tight bucket policy
restricted CI/CD access
CloudTrail
state locking
```

State is part of your control plane.

---

# 38.989 Bootstrap paradox

Question:

> Terraform needs an S3 backend. Who creates the S3 backend?

You need a bootstrap layer.

Example:

```text
00-bootstrap/
```

initially creates:

```text
state S3 bucket
KMS key if used
state access roles
```

Then subsequent Terraform roots use that backend.

Do not make:

```text
organization state
```

responsible for creating the bucket in which that same state already needs to exist.

---

# 38.990 Provider architecture

Let's say the CI/CD runner begins with:

```text
TerraformPipelineRole
```

in a central platform account.

That role should not contain static credentials for ten AWS accounts.

Instead:

```text
CI Runner
   │
   ▼
TerraformPipelineRole
   │
   ├── AssumeRole → Management
   ├── AssumeRole → Security
   ├── AssumeRole → Network
   └── AssumeRole → Shared Services
```

HashiCorp documents this exact cross-account pattern using AWS STS `AssumeRole`. ([HashiCorp Developer][1])

---

# 38.991 Provider alias pattern

Example:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "management"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/TerraformOrganizationAdmin"
  }
}

provider "aws" {
  alias  = "security"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/TerraformSecurityAdmin"
  }
}

provider "aws" {
  alias  = "network"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/TerraformNetworkAdmin"
  }
}
```

HashiCorp recommends provider aliases when multiple AWS configurations/accounts/Regions are required in one Terraform root. ([HashiCorp Developer][1])

---

# 38.992 Add Multi-Region providers

For our architecture:

```text
Mumbai
ap-south-1

Singapore
ap-southeast-1
```

Example:

```hcl
provider "aws" {
  alias  = "network_mumbai"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/TerraformNetworkAdmin"
  }
}

provider "aws" {
  alias  = "network_singapore"
  region = "ap-southeast-1"

  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/TerraformNetworkAdmin"
  }
}
```

Now account and Region are both explicit.

---

# 38.993 Provider aliases belong in root modules

Do **not** generally embed credentials/provider configurations inside reusable child modules.

HashiCorp's current guidance is that reusable child modules should declare provider requirements, while concrete provider configurations stay in the root configuration and are passed down. ([HashiCorp Developer][4])

Good:

```text
ROOT
provider aws.network_mumbai
       │
       ▼
module transit
```

Not:

```text
module transit
   │
   └── hardcoded provider credentials
```

---

# 38.994 Pass provider explicitly

Root:

```hcl
module "mumbai_network" {
  source = "../../modules/network-region"

  providers = {
    aws = aws.network_mumbai
  }

  region_name = "mumbai"
}
```

HashiCorp documents the `providers` map for explicitly passing aliased provider configurations into child modules. ([HashiCorp Developer][4])

---

# 38.995 Module using two Regions

Suppose a module manages:

```text
Mumbai
↔
Singapore
```

The module declares:

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"

      configuration_aliases = [
        aws.primary,
        aws.dr
      ]
    }
  }
}
```

Then root:

```hcl
module "regional_connectivity" {
  source = "../../modules/regional-connectivity"

  providers = {
    aws.primary = aws.network_mumbai
    aws.dr      = aws.network_singapore
  }
}
```

Terraform requires aliased configurations to be explicitly passed where a child module expects them. ([HashiCorp Developer][4])

---

# 38.996 Critical Terraform limitation — providers are not ordinary dynamic values

A common idea is:

```hcl
module "account" {
  for_each = var.accounts

  providers = {
    aws = aws[each.key]
  }
}
```

That is **not** how Terraform provider configuration selection works.

Provider configurations are statically associated with resources/modules. HashiCorp explicitly notes that module instances created with `for_each` or `count` cannot dynamically receive different provider configurations per instance; separate module blocks/configurations are needed for distinct provider sets. ([HashiCorp Developer][4])

This is a major senior-level Terraform nuance.

---

# 38.997 So how do you manage 500 accounts?

Not:

```text
one root module
+
500 provider aliases
+
one gigantic state
```

Better approaches include:

```text
AFT per-account customization pipelines

separate Terraform roots

generated account configurations

HCP Terraform workspaces/stacks

CI/CD matrix jobs

account-specific states
```

The correct unit is usually:

```text
one controlled execution context
per account/class/state
```

rather than one giant dynamic provider graph.

---

# 38.998 Organizations Terraform root

Let's create:

```text
01-organizations/
```

Concept:

```text
Management-account provider
        │
        ▼
Organization
        │
        ▼
OUs
        │
        ▼
organizational hierarchy
```

AWS Organizations recommends organizing accounts into OUs so policies and governance can be applied to logical account groups. ([AWS Documentation][5])

---

# 38.999 OU data model

Use maps instead of hundreds of repeated resources.

Example:

```hcl
locals {
  top_level_ous = {
    security       = "Security"
    infrastructure = "Infrastructure"
    workloads      = "Workloads"
    suspended      = "Suspended"
  }
}
```

Then:

```hcl
resource "aws_organizations_organizational_unit" "top" {
  for_each = local.top_level_ous

  provider  = aws.management
  name      = each.value
  parent_id = data.aws_organizations_organization.current.roots[0].id
}
```

This is a good use of `for_each` because all resources use the **same management-account provider**.

---

# 38.1000 Nested OUs

Example hierarchy:

```text
Workloads
├── Production
├── NonProduction
└── Sandbox
```

Terraform:

```hcl
resource "aws_organizations_organizational_unit" "production" {
  provider  = aws.management
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.top["workloads"].id
}

resource "aws_organizations_organizational_unit" "nonproduction" {
  provider  = aws.management
  name      = "NonProduction"
  parent_id = aws_organizations_organizational_unit.top["workloads"].id
}
```

---

# 38.1001 Keep accounts out of this root when using AFT

Important architecture decision.

If AFT owns account creation, don't simultaneously manage the same workload account lifecycle using:

```hcl
aws_organizations_account
```

from another Terraform state.

That creates two control planes.

Use:

```text
Organizations Terraform
→ hierarchy/policies


AFT
→ workload account lifecycle
```

AWS AFT is specifically designed to use Terraform account requests to trigger Control Tower provisioning and governance. ([AWS Documentation][2])

---

# 38.1002 Policy repository

Separate:

```text
02-org-policies/
```

Directory:

```text
policies/
│
├── scp/
│   ├── deny-leave-org.json
│   ├── protect-security.json
│   └── region-boundary.json
│
└── rcp/
    ├── enforce-tls.json
    └── data-perimeter.json
```

Organization policies are intended as centrally applied controls to groups of accounts/OUs. SCPs constrain maximum principal permissions and RCPs constrain maximum permissions accepted by resources. ([AWS Documentation][6])

---

# 38.1003 Create an SCP

Terraform concept:

```hcl
resource "aws_organizations_policy" "deny_leave_org" {
  provider = aws.management

  name = "DenyLeaveOrganization"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = "organizations:LeaveOrganization"
      Resource = "*"
    }]
  })
}
```

The AWS provider's `aws_organizations_policy` manages Organizations policies, including SCP/RCP policy content, while `aws_organizations_policy_attachment` attaches policies to roots, OUs, or accounts. ([Terraform Registry][7])

---

# 38.1004 Attach the policy

```hcl
resource "aws_organizations_policy_attachment" "prod_deny_leave" {
  provider = aws.management

  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.production.id
}
```

The target can be an:

```text
Account
OU
Root
```

depending on policy design. ([Terraform Registry][8])

---

# 38.1005 Don't attach every custom SCP to Root

Possible:

```text
Root
  ├── policy A
  ├── policy B
  ├── policy C
  ├── policy D
  └── policy E
```

But this means:

```text
all descendants
```

inherit them.

Better ask:

```text
Is this universal?

Security only?

Production only?

Sandbox only?
```

SCPs are intended as coarse organization guardrails, not a replacement for detailed IAM permissions. ([AWS Documentation][9])

---

# 38.1006 RCP example

Concept:

```hcl
resource "aws_organizations_policy" "s3_secure_transport" {
  provider = aws.management

  name = "RequireS3SecureTransport"
  type = "RESOURCE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = "*"

      Condition = {
        BoolIfExists = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}
```

RCPs require Organizations **all features** and are resource-centric guardrails. Current AWS RCP syntax is more constrained than ordinary IAM/resource policies, so always validate the current supported syntax/service coverage when creating production RCPs. ([AWS Documentation][10])

---

# 38.1007 Policy validation stage

Before:

```text
terraform apply
```

run:

```bash
terraform fmt -check
terraform validate
terraform plan
```

And for organization policies, also validate:

```text
JSON syntax
policy semantics
conditions
NotAction usage
service exceptions
break-glass paths
```

A syntactically valid SCP can still destroy operational access.

---

# 38.1008 Current 2026 policy-delegation change

One important recent Organizations change:

As of **June 30, 2026**, AWS no longer permits `NotAction` and `NotResource` in **Organizations resource-based delegation policies**. This is specifically about the policy used to delegate Organizations policy-management operations—not ordinary SCPs/RCPs. ([AWS Documentation][11])

Do not confuse:

```text
resource-based delegation policy
```

with:

```text
RCP
```

They are different policy types.

---

# 38.1009 Trusted-services state

Create a separate lifecycle:

```text
03-security-delegation/
```

Why?

Because enabling organization service integration is a high-privilege management-account action.

Examples:

```text
GuardDuty trusted access
Inspector trusted access
Security Hub integration
RAM Organizations sharing
IPAM delegated admin
```

AWS recommends using the integrated service's own setup workflow when available because the service may need to create its service-linked roles and other integration state. ([AWS Documentation][12])

---

# 38.1010 Don't model all delegated services identically

Bad Terraform abstraction:

```hcl
for_each = var.services

resource "aws_organizations_delegated_administrator" ...
```

and assume that finishes every service.

Why?

Because:

```text
GuardDuty
Security Hub
Inspector
IPAM
Security Lake
Firewall Manager
```

all have service-specific lifecycle behavior.

Organizations registration may be only part of the configuration. AWS explicitly defines delegated administration as a service-specific relationship. ([AWS Documentation][13])

---

# 38.1011 Better delegation module design

Instead of:

```text
module generic_delegated_admin
```

for everything, use:

```text
modules/
├── guardduty-org/
├── securityhub-org/
├── inspector-org/
├── ipam-org/
├── backup-org/
└── securitylake-org/
```

Each module understands:

```text
trusted access

delegated admin

regional requirements

organization policy

auto-enable

member enrollment
```

This is more code but much less hidden risk.

---

# 38.1012 Security Tooling root

Provider:

```hcl
provider "aws" {
  alias  = "security"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/TerraformSecurityAdmin"
  }
}
```

Then security state can manage:

```text
Security Hub

GuardDuty

Inspector

Macie

Access Analyzer

EventBridge response

Config aggregation
```

while organization-level registration remains in a higher-privilege delegation state.

---

# 38.1013 Why split registration from service config?

Because:

```text
REGISTER DELEGATED ADMIN
```

may require management-account authority.

But:

```text
CONFIGURE GUARDDUTY MEMBERS
```

should occur in:

```text
Security Tooling
```

So states become:

```text
management plane
        │
        ▼
delegate
        │
        ▼
security plane
        │
        ▼
operate
```

That is least privilege expressed as Terraform architecture.

---

# 38.1014 Network state

Structure:

```text
network/
├── global/
│   ├── ipam.tf
│   ├── ram.tf
│   └── prefix-lists.tf
│
├── ap-south-1/
│   ├── tgw.tf
│   ├── inspection.tf
│   ├── resolver.tf
│   └── dns-profile.tf
│
└── ap-southeast-1/
    ├── tgw.tf
    ├── inspection.tf
    ├── resolver.tf
    └── dns-profile.tf
```

This mirrors the fact that many AWS network resources, including TGW and RAM shares for Regional resources, have Region-scoped lifecycles. AWS RAM itself is Regional for Regional resources, although enabling RAM sharing with Organizations is organization-wide for supported Regions. ([AWS Documentation][14])

---

# 38.1015 IPAM delegated admin

Terraform AWS provider includes:

```text
aws_vpc_ipam_organization_admin_account
```

for enabling an organization member as the IPAM administration account. ([Terraform Registry][15])

Concept:

```hcl
resource "aws_vpc_ipam_organization_admin_account" "network" {
  provider = aws.management

  delegated_admin_account_id = var.network_account_id
}
```

Then IPAM resources should generally be managed from the Network-account provider/state.

---

# 38.1016 IPAM pools

Network state:

```text
10.0.0.0/8
   │
   ├── India
   │    └── 10.64.0.0/10
   │
   └── Singapore
        └── 10.128.0.0/10
```

Then:

```text
India
├── Prod
├── NonProd
└── Shared
```

No application team hardcodes:

```text
10.0.0.0/16
```

anymore.

---

# 38.1017 RAM Terraform

Concept:

```hcl
resource "aws_ram_resource_share" "network" {
  provider = aws.network_mumbai

  name                      = "production-network-services"
  allow_external_principals = false
}
```

The AWS provider manages RAM resource shares with `aws_ram_resource_share`; principal and resource associations are separate resources. ([Terraform Registry][16])

---

# 38.1018 Share to an OU

Conceptually:

```text
Resource Share
      │
      ▼
Production OU
      │
      ├── Payments
      ├── Orders
      └── Customer
```

With RAM Organizations sharing enabled, AWS can share supported resources directly with an OU or entire organization without individual invitation acceptance. ([AWS Documentation][14])

This is much better than:

```text
share with account 1
share with account 2
share with account 3
...
```

---

# 38.1019 What can the network share?

Current RAM-supported examples relevant to our architecture include:

```text
Transit Gateway

IPAM pools

Route 53 Profiles

Resolver rules

Resolver query logging configs

DNS Firewall rule groups

subnets

security groups

prefix lists
```

subject to the sharing rules of each resource type. ([AWS Documentation][17])

---

# 38.1020 TGW state

Network provider:

```hcl
resource "aws_ec2_transit_gateway" "regional" {
  provider = aws.network_mumbai

  description = "Mumbai enterprise transit"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}
```

Why disable automatic route-table behavior?

Because in an enterprise segmented design we want explicit:

```text
Prod route domain

NonProd route domain

Shared Services route domain

Inspection route domain
```

rather than every new attachment automatically joining one transit domain.

---

# 38.1021 Explicit TGW governance

Concept:

```text
attachment
   │
   ▼
identify account OU
   │
   ▼
Production?
   │
   ├── YES → Prod TGW RT
   │
   └── NO  → appropriate domain
```

This should be deterministic platform logic.

---

# 38.1022 Account network onboarding

AFT produces:

```text
payments-prod
account ID
```

Then network automation can consume:

```text
account_id

OU

network_profile

primary_region

DR_region
```

to create:

```text
IP allocation

VPC

TGW attachment

RAM associations

DNS profile association

Flow Logs
```

AFT itself remains the account customization/orchestration framework, not the permanent application runtime deployment engine. ([AWS Documentation][2])

---

# 38.1023 Don't tightly couple states using internal IDs everywhere

Bad:

```text
account stack reads
network state

network stack reads
security state

security state reads
account state

identity reads all three
```

Now:

```text
A depends on B
B depends on C
C depends on A
```

Your platform becomes a distributed Terraform monolith.

Prefer stable platform interfaces.

---

# 38.1024 Publish platform outputs

Examples:

```text
SSM Parameter Store

DynamoDB service catalog

configuration repository

CI/CD variables

AFT custom fields
```

could publish stable identifiers such as:

```text
Prod IPAM pool ID

TGW ID

Route 53 Profile ID

Log bucket ARN

Security account ID
```

Consumers use a deliberate contract instead of reading arbitrary internal Terraform state.

---

# 38.1025 Why avoid excessive `terraform_remote_state`?

Terraform supports `terraform_remote_state` for consuming another configuration's root outputs. ([HashiCorp Developer][18])

But architecture-wise, excessive state-to-state coupling makes:

```text
state naming

backend permissions

output contracts

deployment ordering
```

part of every consumer.

Use remote state where it genuinely simplifies a tightly coupled platform boundary—but not as the universal enterprise service-discovery database.

---

# 38.1026 Identity Center state

Potential separate root:

```text
09-identity-center/
```

Own:

```text
permission sets

group/account assignments

session durations

permission boundaries
```

Do not let individual application states create centralized workforce permission sets independently.

Otherwise:

```text
Payments repo
creates SecurityAdmin permission set
```

would be an obvious governance failure.

---

# 38.1027 Group-driven assignments

Data model:

```hcl
locals {
  assignments = {
    payments_prod_sre = {
      group_name     = "AWS-Prod-SRE"
      account_id     = var.payments_prod_account_id
      permission_set = "ProdOperator"
    }

    payments_prod_dev = {
      group_name     = "AWS-Developers"
      account_id     = var.payments_prod_account_id
      permission_set = "ProdReadOnly"
    }
  }
}
```

This is the kind of mapping a central identity state should own.

---

# 38.1028 CI/CD role chain

Production Terraform pipeline:

```text
GitHub / GitLab / Jenkins
        │
        ▼
OIDC / runner identity
        │
        ▼
TerraformExecutionRole
        │
        ├── sts:AssumeRole → Org role
        ├── sts:AssumeRole → Network role
        ├── sts:AssumeRole → Security role
        └── sts:AssumeRole → Identity role
```

Do not store:

```text
management-account access key
```

inside Jenkins credentials for five years.

Use temporary-role credentials.

---

# 38.1029 Pipeline role should not assume every role

Better:

```text
Organization pipeline
→ Organization role


Network pipeline
→ Network role


Security pipeline
→ Security role
```

than:

```text
OneTerraformSuperAdmin
→ everything.
```

Compromise one workflow, lose every AWS governance plane.

Separate privilege paths.

---

# 38.1030 Repository separation

One possible production Git layout:

```text
aws-platform/
│
├── organization/
│   ├── hierarchy/
│   ├── policies/
│   └── delegations/
│
├── security/
│   ├── guardduty/
│   ├── inspector/
│   ├── securityhub/
│   └── logging/
│
├── networking/
│   ├── global/
│   ├── ap-south-1/
│   └── ap-southeast-1/
│
├── identity/
│
├── aft/
│
└── modules/
```

Or separate repositories by ownership.

The important requirement is not monorepo vs polyrepo.

It is:

```text
clear owner
clear state
clear execution identity
clear blast radius
```

---

# 38.1031 Module architecture

Reusable modules:

```text
modules/
│
├── organizations-ou/
├── organizations-scp/
├── organizations-rcp/
├── network-region/
├── tgw-routing-domain/
├── ipam-pool/
├── ram-share/
├── resolver-profile/
├── security-org/
└── account-baseline/
```

A module should implement a reusable building block.

The **root state** should implement an environment.

---

# 38.1032 Do not make a "CompanyEverything" module

Bad:

```text
module company {
  organization = ...
  network      = ...
  security     = ...
  identity     = ...
  payments     = ...
}
```

This recreates the giant-state problem inside a module.

Modularity does not magically reduce state blast radius.

---

# 38.1033 Terraform execution ordering

Our platform dependency graph roughly becomes:

```text
BOOTSTRAP
   │
   ▼
ORGANIZATION
   │
   ├───────────────┐
   ▼               ▼
OUs/POLICIES    SHARED ACCOUNTS
   │               │
   └───────┬───────┘
           ▼
      DELEGATIONS
           │
   ┌───────┼──────────┐
   ▼       ▼          ▼
Security Network    Identity
   │       │          │
   └───────┼──────────┘
           ▼
          AFT
           │
           ▼
     ACCOUNT VENDING
           │
           ▼
     ACCOUNT BASELINE
           │
           ▼
   APPLICATION PIPELINE
```

This graph matters more than Terraform file names.

---

# 38.1034 Organization bootstrap is special

You cannot fully bootstrap:

```text
Management role trust

Organizations

AFT

Control Tower

state roles
```

from absolutely nothing with no privileged seed identity.

There is always some initial bootstrap authority.

The goal is:

```text
bootstrap once
      │
      ▼
establish role-based automation
      │
      ▼
stop using human super-admin
for daily IaC
```

---

# 38.1035 `payments-prod` end-to-end capstone

Now let's trace one account.

Git request:

```text
AccountName       = payments-prod
OU                = Production
Environment       = Prod
Application       = Payments
Compliance        = PCI
PrimaryRegion     = ap-south-1
DRRegion          = ap-southeast-1
NetworkProfile    = prod-restricted
OwnerGroup        = Payments
```

AFT supports account-request files that trigger GitOps-style account provisioning and subsequent customizations. ([AWS Documentation][2])

---

# 38.1036 Phase A — account creation

```text
Git PR
  │
  ▼
AFT
  │
  ▼
Control Tower Account Factory
  │
  ▼
payments-prod
```

Then:

```text
Production OU
```

placement causes inherited organization governance.

---

# 38.1037 Phase B — organization policies

Because account belongs to:

```text
Workloads
  ↓
Production
```

it receives applicable:

```text
SCPs

RCPs

Control Tower controls

organization security policies
```

SCP/RCP effective permissions operate together with ordinary IAM/resource policies rather than directly granting permissions. ([AWS Documentation][9])

---

# 38.1038 Phase C — security administration

Delegated Security Tooling account recognizes/configures the new member through organization service integration:

```text
Security Hub

GuardDuty

Inspector

Config

Access Analyzer
```

depending on service auto-enable/policy configuration.

AFT should not duplicate a configuration that is already owned by an Organizations policy or delegated security service.

---

# 38.1039 Phase D — IPAM

Input:

```text
PrimaryRegion=ap-south-1
NetworkProfile=prod-restricted
```

maps to:

```text
Mumbai Production IPAM pool
```

Network pipeline allocates:

```text
10.64.x.x/20
```

for the account.

Now:

```text
address = centrally governed
```

not developer-selected.

---

# 38.1040 Phase E — VPC

Network-vending Terraform assumes:

```text
payments-prod:
TerraformNetworkProvisioningRole
```

and builds:

```text
VPC

private application subnets

database subnets

VPC endpoints

Flow Logs

route tables
```

within the workload account.

This state is now specific to:

```text
payments-prod networking
```

rather than coupled to global Organizations state.

---

# 38.1041 Phase F — TGW attachment

The workload account creates or receives the VPC attachment to the centrally shared Transit Gateway.

Network state associates it with:

```text
Prod TGW Route Table
```

and explicitly propagates only required destinations.

RAM supports centrally owned TGWs being shared to organization accounts/OUs. ([AWS Documentation][17])

---

# 38.1042 Phase G — DNS

Attach:

```text
Production Route 53 Profile
```

which can centrally provide:

```text
private hosted-zone associations

Resolver rules

DNS Firewall rules

query logging
```

depending on Profile design. Route 53 Profiles are currently shareable through RAM to accounts/OUs. ([AWS Documentation][17])

---

# 38.1043 Phase H — Identity

Central identity state creates:

```text
AWS-Prod-SRE
       │
       ▼
ProdOperator
       │
       ▼
payments-prod


AWS-Developers
       │
       ▼
ProdReadOnly
       │
       ▼
payments-prod
```

No human IAM users are required for routine workforce access.

---

# 38.1044 Phase I — validation

Before status becomes:

```text
READY
```

run a machine validation suite.

Example:

```text
Organizations
  correct OU                 ✓

Policies
  expected SCPs             ✓

Security
  GuardDuty                  ✓
  Inspector                  ✓
  Security Hub               ✓

Logging
  CloudTrail                 ✓
  Flow Logs                  ✓

Network
  VPC                        ✓
  TGW attachment             ✓
  DNS                        ✓

Identity
  SRE assignment             ✓
  Dev read-only              ✓
```

Only then hand account to the application team.

---

# 38.1045 Then application Terraform begins

Separate repository:

```text
payments-platform/
```

or:

```text
payments-infra/
```

deploys:

```text
ALB

ECS

Aurora

SQS

CloudWatch

Secrets Manager
```

using a role such as:

```text
TerraformApplicationRole
```

inside:

```text
payments-prod.
```

Application state has **no Organizations management permission**.

That is the security payoff of this architecture.

---

# 38.1046 Application pipeline cannot change organization

Even if application Terraform has:

```text
broad application permissions
```

its role should not have:

```text
organizations:*

ram organization administration

Control Tower administration

central IPAM administration

Security Hub organization admin
```

And SCPs can provide additional guardrails.

---

# 38.1047 Production CI/CD pipeline

Flow:

```text
Pull Request
    │
    ▼
terraform fmt
    │
    ▼
terraform validate
    │
    ▼
security/policy checks
    │
    ▼
terraform plan
    │
    ▼
plan artifact
    │
    ▼
review / approval
    │
    ▼
terraform apply
```

For high-risk stacks such as:

```text
Organizations
SCPs
TGW
Identity
```

manual approval before apply is reasonable.

---

# 38.1048 Never auto-apply every Organization policy change

Imagine PR:

```text
Action = "*"
Effect = "Deny"
```

accidentally attached to:

```text
Root.
```

A fully automatic:

```text
merge → apply
```

pipeline could cause a major outage.

Use:

```text
static validation

policy tests

plan review

test OU

approval

controlled rollout
```

for high-blast-radius organization controls.

---

# 38.1049 Canary OUs

Create something like:

```text
Policy-Test OU
```

with non-critical test accounts.

Deployment flow:

```text
new SCP
   │
   ▼
Policy-Test OU
   │
   ▼
test pipelines
   │
   ▼
NonProd
   │
   ▼
Production
```

AWS recommends testing SCP changes before broad deployment. ([AWS Documentation][9])

---

# 38.1050 Policy-as-code tests

Example assertions:

```text
Prod role:

ec2:RunInstances Mumbai
→ ALLOW


ec2:RunInstances unapproved Region
→ DENY


organizations:LeaveOrganization
→ DENY


s3:GetObject approved resource
→ ALLOW
```

Do not test only:

```text
terraform validate
```

because Terraform validates HCL/schema—not business intent.

---

# 38.1051 Network tests

After network change:

```text
Payments → Shared DNS         PASS

Payments → Orders approved    PASS

Payments → Dev                FAIL expected

Payments → Internet
through inspection            PASS

Singapore DR → DNS            PASS

Singapore → Mumbai dependency
when Mumbai isolated          NONE
```

Infrastructure should have behavioral tests.

---

# 38.1052 Security tests

After account creation:

```text
GuardDuty enabled?

Inspector enabled?

Security Hub central view?

CloudTrail delivered?

Config recording?

Access Analyzer coverage?

security EventBridge route?
```

This proves the delegation chain actually works.

---

# 38.1053 Identity tests

Example:

```text
Developer:

Dev Admin            ✓
Prod ReadOnly        ✓
Prod Admin           ✕


SRE:

ProdOperator         ✓


Security:

SecurityAudit        ✓
```

And:

```text
Application developer
cannot enter
Management Account.
```

---

# 38.1054 State-drift detection

Schedule CI:

```text
terraform plan
```

for critical platform states.

If plan says:

```text
0 add
0 change
0 destroy
```

good.

If:

```text
1 change
```

without a PR:

```text
someone changed AWS manually
```

or provider/service behavior changed.

Investigate.

---

# 38.1055 Don't automatically apply drift fixes

Suppose Terraform sees:

```text
Security Hub delegated admin
changed manually
```

Automatically forcing it back may interfere with an active incident/migration.

Better:

```text
detect drift
      │
      ▼
alert
      │
      ▼
understand cause
      │
      ▼
approved remediation
```

Critical control-plane drift should not always be self-healed blindly.

---

# 38.1056 Import is a first-class production skill

If a resource already exists:

```text
TGW

OU

policy

RAM share
```

and Terraform should become owner:

```text
IMPORT IT
```

rather than:

```text
destroy manually
+
recreate
```

where downtime/risk exists.

Brownfield IaC is often:

```text
discover
→ import
→ reconcile
→ normalize
```

not greenfield creation.

---

# 38.1057 Avoid resource ownership collision

Example:

```text
Control Tower owns:
mandatory SCP
```

Do not have Terraform state B also try to own that exact same policy.

Example:

```text
AFT owns:
AWSAFTExecution
```

Do not redefine it manually in workload Terraform.

Rule:

# **One authoritative owner per managed resource.**

---

# 38.1058 Dependency ownership matrix

| Resource                   | Authority                           |
| -------------------------- | ----------------------------------- |
| Control Tower baseline     | Control Tower                       |
| AFT execution roles        | AFT                                 |
| Custom SCP                 | Organization Terraform              |
| IPAM                       | Network Terraform                   |
| TGW                        | Network Terraform                   |
| Security service config    | Security Terraform/service policies |
| Identity assignments       | Identity Terraform                  |
| Application infrastructure | App Terraform                       |

Write this matrix before deployment.

---

# 38.1059 Common failure — wrong AWS account

Terraform says:

```text
Apply complete
```

but resource is nowhere in expected account.

First command:

```bash
aws sts get-caller-identity
```

And when using aliased providers, expose temporary sanity checks/data sources if needed.

Never assume:

```text
provider alias name = correct credentials.
```

---

# 38.1060 Common failure — AssumeRole denied

Flow:

```text
CI role
   │
   ▼
sts:AssumeRole
   X
```

Check:

```text
Caller IAM permission

Target role trust policy

SCP

session policy

permissions boundary

role ARN

external ID if required
```

HashiCorp's cross-account AWS provider flow depends on the caller being authorized to assume the destination role and the role trusting the caller. ([HashiCorp Developer][1])

---

# 38.1061 Common failure — provider alias not passed

Root:

```text
aws.network
```

exists.

Child module unexpectedly uses:

```text
default aws
```

and creates resource in wrong account/Region.

Use:

```hcl
providers = {
  aws = aws.network
}
```

Aliased providers are not automatically inherited by child modules; HashiCorp requires them to be explicitly passed. ([HashiCorp Developer][4])

---

# 38.1062 Common failure — missing provider during destroy

Terraform state remembers the provider configuration associated with resources.

If you delete:

```hcl
provider "aws" {
  alias = "singapore"
}
```

before destroying/migrating resources associated with it, Terraform can fail because it still needs that provider configuration to operate on the tracked resources. HashiCorp explicitly documents this behavior. ([HashiCorp Developer][4])

---

# 38.1063 Common failure — dynamic providers with `for_each`

Engineer tries:

```text
500 accounts
→ one module for_each
→ dynamically choose 500 aliases
```

Terraform cannot dynamically switch provider configurations per module instance in that way. ([HashiCorp Developer][4])

Use separate account execution units or AFT customization pipelines instead.

---

# 38.1064 Common failure — old DynamoDB locking assumption

New platform:

```text
terraform-lock table
```

created automatically because old tutorial said so.

Current Terraform S3 backend:

```text
use_lockfile = true
```

can provide native S3 state locking, while DynamoDB locking is deprecated. ([HashiCorp Developer][3])

Existing deployments can migrate deliberately; don't delete an old lock mechanism in the middle of active pipeline operations without a migration plan.

---

# 38.1065 Common failure — RAM resource invisible

Check:

```text
RAM Organizations sharing enabled?

resource actually shared?

correct OU/account?

correct Region?

participant IAM permission?

resource type supported?
```

AWS notes that organization sharing avoids invitations, but receiving a resource share still doesn't automatically grant every consuming principal the IAM permissions required to use that resource. ([AWS Documentation][14])

---

# 38.1066 Common failure — SCP blocks Terraform

Terraform error:

```text
AccessDenied
```

Role:

```text
AdministratorAccess
```

Still denied.

Check:

```text
SCP
RCP
permissions boundary
session policy
resource policy
```

SCPs are maximum-permission guardrails and don't disappear just because the execution role has administrator permissions. ([AWS Documentation][6])

---

# 38.1067 Common failure — AFT and Terraform both own account

Symptoms:

```text
AFT moved account

organization Terraform:
wants move it back
```

You created:

```text
control-plane conflict.
```

Pick one lifecycle owner.

For normal Control Tower account vending in this architecture:

```text
AFT
=
account lifecycle
```

([AWS Documentation][2])

---

# 38.1068 Common failure — network Terraform waits on account Terraform

Account state expects:

```text
TGW attachment
```

Network state expects:

```text
account VPC
```

but both require outputs from the other.

Solve the architecture:

```text
Account creation
       ↓
VPC
       ↓
attachment request
       ↓
central route association
```

Make workflow stages unidirectional.

---

# 38.1069 Common failure — DR Region has no provider/state

Main region Terraform:

```text
everything ✓
```

Singapore:

```text
manual setup
```

During disaster:

```text
drift everywhere.
```

Multi-Region infrastructure deserves explicit Regional state/configuration:

```text
network-mumbai
network-singapore
```

and shared reusable modules.

---

# 38.1070 Production change hierarchy

Classify Terraform stacks by blast radius.

### Tier 1 — Organization critical

```text
Organizations
SCP/RCP
Control Tower
Identity administration
delegation
```

Requires strongest review.

### Tier 2 — Shared platform

```text
TGW
IPAM
DNS
Firewall
Security Hub
Backup
```

Requires platform approval.

### Tier 3 — Workload

```text
ECS
RDS
ALB
SQS
```

Application-team ownership.

One CI/CD policy should not treat all three tiers identically.

---

# 38.1071 Plan review question set

For every high-risk plan ask:

```text
What accounts?

What OUs?

What Regions?

What providers?

Any destroy?

Any replacement?

Any IAM trust change?

Any SCP/RCP change?

Any TGW route change?

Any KMS key-policy change?

Any security-service disable?

Any management-account change?
```

If a plan changes:

```text
Root SCP
```

that deserves more scrutiny than:

```text
one CloudWatch alarm.
```

---

# 38.1072 `terraform plan` should be an artifact

CI:

```text
terraform plan
      │
      ▼
saved plan artifact
      │
      ▼
review
      │
      ▼
approved apply of same plan
```

Do not ideally:

```text
plan
```

on developer laptop and then later:

```text
apply
```

an entirely new plan in production without review.

---

# 38.1073 Secrets in Terraform

Avoid passing permanent:

```text
AWS access keys
```

through Terraform variables.

Use:

```text
OIDC
IAM role
STS
Identity Center for humans
```

and let AWS authentication remain outside the state where possible.

Remember:

```text
Terraform sensitive = hides display

not necessarily
"never stored in state."
```

Design secret ownership accordingly.

---

# 38.1074 Platform permissions hierarchy

Conceptually:

```text
BootstrapAdmin
     │
     ▼
OrganizationTerraformRole
     │
     ├── org hierarchy
     ├── policies
     └── delegations


SecurityTerraformRole
     │
     └── security services


NetworkTerraformRole
     │
     └── network


IdentityTerraformRole
     │
     └── workforce assignments


ApplicationTerraformRole
     │
     └── one workload
```

This is the cloud equivalent of:

```text
root access
→ delegated subsystem administration
```

---

# 38.1075 Why this architecture scales

Suppose company grows from:

```text
10 accounts
```

to:

```text
500 accounts.
```

You don't need 500 handcrafted platform configurations.

You scale through:

```text
OUs

organization policies

delegated administrators

RAM shares

IPAM pools

Route 53 Profiles

AFT account templates

Identity groups

reusable Terraform modules
```

The organizational abstractions scale better than individual resource configuration.

---

# 38.1076 Failure injection — SCP

Test account in:

```text
Policy-Test OU
```

Attempt prohibited action.

Expected:

```text
AccessDenied
```

Then attempt required CI/CD workflow.

Expected:

```text
Success
```

A guardrail test only passes when:

```text
bad behavior fails

AND

required behavior still works.
```

---

# 38.1077 Failure injection — cross-account role

Temporarily use a deliberately incorrect/non-production trust policy.

Expected:

```text
Terraform provider initialization/use
→ AssumeRole denied
```

Then verify your monitoring explains:

```text
which role
which account
which pipeline
```

Don't perform permission-failure experiments against the real production management role.

---

# 38.1078 Failure injection — network

In controlled non-production:

```text
remove TGW route
```

through code.

Validate:

```text
synthetic connectivity fails

alarm fires

route diagnosis identifies TGW

rollback restores connectivity
```

Now your Terraform rollback/runbook is tested.

---

# 38.1079 Failure injection — Singapore isolation

Pretend Mumbai is unavailable.

Ask:

```text
Can Singapore Terraform run?

Can CI assume Singapore roles?

Is Singapore network state independent?

Does DNS exist?

Does security work?

Does backend depend only on Mumbai?
```

This uncovers hidden Region dependence in the **platform control plane itself**.

---

# 38.1080 Terraform state DR

Your DR strategy should also consider:

```text
What if primary state backend
is temporarily unavailable?
```

At minimum:

```text
S3 versioning

backup/replication strategy as required

bootstrap documentation

role reconstruction process
```

But be careful:

```text
two writable independent Terraform states
```

for the same resources can cause split-brain infrastructure management.

Never solve state DR by having:

```text
Mumbai state
and
Singapore state
```

both independently managing the same object set.

---

# 38.1081 Terraform split brain

Very dangerous:

```text
Pipeline A
State A
   │
   ▼
TGW


Pipeline B
State B
   │
   ▼
same TGW
```

Now both believe:

```text
I own this resource.
```

The infrastructure equivalent of database split brain.

Never-forget:

# **One resource → one authoritative Terraform state owner.**

---

# 38.1082 State lock purpose

Locking does not protect against:

```text
bad Terraform code.
```

It protects against concurrent state modification.

Example:

```text
Pipeline A
terraform apply

Pipeline B
terraform apply
```

Same state.

Lock:

```text
only one writer
```

Current S3 backend supports native lockfiles when `use_lockfile = true`. ([HashiCorp Developer][3])

---

# 38.1083 Lock ≠ approval

State locking:

```text
prevents concurrent writes.
```

PR approval:

```text
prevents unauthorized/unreviewed change.
```

SCP:

```text
prevents prohibited AWS behavior.
```

Different controls.

---

# 38.1084 Platform governance layers

```text
                       GIT REVIEW
                           │
                           ▼
                     TERRAFORM PLAN
                           │
                           ▼
                      STATE LOCK
                           │
                           ▼
                 IAM EXECUTION ROLE
                           │
                           ▼
                         SCP
                           │
                           ▼
                         RCP
                           │
                           ▼
                    AWS SERVICE API
```

Defense in depth applies to IaC too.

---

# 38.1085 Full capstone deployment sequence

Use this as the complete mental model:

```text
PHASE 0
Bootstrap state + pipeline identities
       │
       ▼
PHASE 1
Organizations + OUs
       │
       ▼
PHASE 2
SCP/RCP
       │
       ▼
PHASE 3
Shared/platform accounts
       │
       ▼
PHASE 4
Trusted services + delegated admins
       │
       ▼
PHASE 5
Security platform
       │
       ▼
PHASE 6
IPAM + network hubs
       │
       ▼
PHASE 7
Shared DNS / RAM
       │
       ▼
PHASE 8
Identity Center
       │
       ▼
PHASE 9
Control Tower / AFT
       │
       ▼
PHASE 10
Account request
       │
       ▼
PHASE 11
Account security/network/identity baseline
       │
       ▼
PHASE 12
Runtime validation
       │
       ▼
PHASE 13
Application Terraform
```

---

# 38.1086 Complete provider-flow diagram

```text
                       CI/CD PLATFORM
                             │
                     temporary identity
                             │
                             ▼
                 TerraformPipelineRole
                             │
       ┌─────────────────────┼──────────────────────┐
       │                     │                      │
       ▼                     ▼                      ▼

 AssumeRole              AssumeRole             AssumeRole

 Management              Security               Network
 Terraform Role          Terraform Role         Terraform Role
       │                     │                      │
       ▼                     ▼                      ▼
 Organizations         Security Hub                TGW
 SCP/RCP               GuardDuty                   IPAM
 Delegation            Inspector                   RAM
                       Macie                       DNS
```

No static management-account credential needs to live in the pipeline.

---

# 38.1087 Complete state-flow diagram

```text
                    STATE BACKEND

              S3 + Versioning + Lockfile
                        │
      ┌─────────────────┼────────────────────┐
      ▼                 ▼                    ▼

 organizations/      security/             network/
 core.tfstate        core.tfstate       mumbai.tfstate

                                             │
                                             ▼
                                      singapore.tfstate


             separate lifecycle/state

                         │
                         ▼
                       AFT

                         │
                         ▼
               per-account customization

                         │
                         ▼
                 Application States
```

---

# 38.1088 Complete `payments-prod` flow

```text
Developer
   │
   ▼
Git PR
payments-prod
   │
   ▼
Approval
   │
   ▼
AFT
   │
   ▼
Control Tower
   │
   ▼
AWS Account
   │
   ▼
Production OU
   │
   ├── SCP/RCP
   ├── controls
   └── org policies
   │
   ▼
Security integration
   │
   ▼
IPAM allocation
   │
   ▼
VPC
   │
   ▼
TGW
   │
   ▼
Route 53 Profile
   │
   ▼
Identity Center assignments
   │
   ▼
Readiness Tests
   │
   ▼
ACCOUNT READY
   │
   ▼
Payments application Terraform
```

That is the complete platform journey.

---

# 38.1089 Senior interview question — how would you structure Terraform for 200 AWS accounts?

Strong answer:

> **I would avoid one monolithic Terraform state and instead separate states according to lifecycle, ownership, privilege, and blast radius—for example Organizations/policies, security delegation, security services, network hubs, identity, AFT, and workload infrastructure. CI/CD would authenticate with temporary credentials and assume narrowly scoped roles in each target account. Provider aliases would be used only where a root genuinely needs multiple account or Region configurations, and reusable child modules would receive providers explicitly. For large fleet customization I would use AFT or per-account pipeline/state units rather than trying to dynamically select hundreds of provider aliases through a single `for_each`.**

HashiCorp's provider architecture and AFT's account-level pipeline model align with this design. ([HashiCorp Developer][4])

---

# 38.1090 Interview — Why separate state?

Answer:

```text
smaller blast radius

independent lifecycle

different permissions

independent deployments

less locking contention

clear ownership
```

State boundaries are security and operating-model boundaries, not merely folder organization.

---

# 38.1091 Interview — provider alias

> A provider alias gives a Terraform root multiple configurations of the same provider—for example AWS in another account or Region. Child modules that require aliased providers need those configurations passed explicitly through the module's `providers` map. ([HashiCorp Developer][4])

---

# 38.1092 Interview — AssumeRole

> The Terraform AWS provider can start with a source credential/session and use STS `AssumeRole` to obtain temporary credentials in a destination account, letting a central CI system deploy cross-account without holding permanent credentials for every AWS account. ([HashiCorp Developer][1])

---

# 38.1093 Interview — why not dynamically create providers?

Because provider configurations are part of Terraform's static dependency graph rather than normal first-class runtime values. Different `for_each` module instances cannot dynamically map to arbitrary different provider configurations. ([HashiCorp Developer][4])

---

# 38.1094 Interview — modern S3 locking

Current Terraform:

```text
S3 backend
+
use_lockfile=true
```

supports S3-based state locking.

DynamoDB-backed state locking is currently deprecated. ([HashiCorp Developer][3])

This is a useful modern answer because many older Terraform courses still teach DynamoDB as mandatory.

---

# 38.1095 Interview — AFT vs application Terraform

```text
AFT
=
account lifecycle and baseline


Application Terraform
=
application infrastructure
```

AWS explicitly states AFT is not intended to be the pipeline for runtime application resources. ([AWS Documentation][2])

---

# 38.1096 Interview — why use RAM with OUs?

Because:

```text
Network resource
      │
      ▼
Production OU
```

can automatically make a centrally owned supported resource available to accounts in that organizational grouping instead of maintaining individual account shares. AWS RAM supports sharing to OUs/organizations when Organizations integration is enabled. ([AWS Documentation][14])

---

# 38.1097 Interview — one authoritative owner

If:

```text
Control Tower
Terraform
AFT
manual console
```

all manage the same configuration:

```text
drift
conflicts
unexpected rollback
```

Design each important resource with one lifecycle authority.

This principle is more important than choosing Terraform versus CloudFormation.

---

# 38.1098 Never-forget Terraform governance rules

```text
1.
Do not put the entire enterprise
into one Terraform state.


2.
State boundaries should follow
ownership, lifecycle, privilege
and blast radius.


3.
Use temporary role credentials
for cross-account Terraform.


4.
Provider aliases represent
different AWS configurations.


5.
Keep provider configurations
in root modules.


6.
Pass aliased providers explicitly
to child modules.


7.
You cannot dynamically choose
arbitrary provider aliases per
for_each module instance.


8.
For hundreds of accounts,
prefer separate execution/state units
or AFT pipelines.


9.
Organization/account lifecycle
must have one owner.


10.
AFT owns account vending;
application Terraform owns workloads.


11.
SCP/RCP should have their own
high-review control plane.


12.
Organization policies are guardrails,
not workload IAM.


13.
Trusted-access configuration and
service configuration are not always
the same Terraform operation.


14.
Use service-specific organization
modules where lifecycle differs.


15.
Security service configuration
belongs in Security Tooling.


16.
Network configuration belongs
in Network.


17.
Identity assignments belong
in centralized identity state.


18.
Use IPAM instead of arbitrary CIDRs.


19.
Use RAM for centrally shared
network/DNS resources.


20.
Use explicit TGW routing domains.


21.
Publish stable platform contracts;
avoid uncontrolled state coupling.


22.
Modern S3 backend supports
use_lockfile=true.


23.
DynamoDB locking is now deprecated
for the Terraform S3 backend.


24.
Terraform state locking
does not replace PR approval.


25.
One resource must have
one authoritative Terraform state owner.
```

---

# 38.1099 Capstone checklist

Before declaring the enterprise Terraform platform production-ready:

```text
ORGANIZATION
✓ OUs
✓ account ownership
✓ SCP
✓ RCP
✓ policy testing


IDENTITY
✓ temporary CI credentials
✓ AssumeRole
✓ Identity Center
✓ least privilege


STATE
✓ remote backend
✓ encryption
✓ versioning
✓ lockfile
✓ access controls
✓ recovery plan


SECURITY
✓ delegated admins
✓ security service baseline
✓ central logs
✓ incident roles


NETWORK
✓ IPAM
✓ RAM
✓ TGW
✓ routing domains
✓ DNS
✓ Multi-Region


AFT
✓ account request
✓ metadata
✓ customizations
✓ validation


CI/CD
✓ fmt
✓ validate
✓ policy tests
✓ plan
✓ approval
✓ apply
✓ drift monitoring


DR
✓ Mumbai
✓ Singapore
✓ no hidden primary dependency
✓ state/control-plane recovery
```

---

# 38.1100 Part 9 checkpoint

You can now explain and design:

```text
✓ Enterprise Terraform repository structure

✓ State segmentation

✓ State security

✓ S3 backend

✓ S3 native state lockfiles

✓ DynamoDB locking deprecation

✓ Bootstrap state

✓ AssumeRole

✓ Provider aliases

✓ Multi-Region providers

✓ Provider inheritance

✓ Provider passing

✓ configuration_aliases

✓ dynamic-provider limitation

✓ Organizations Terraform

✓ OU for_each patterns

✓ SCP creation/attachment

✓ RCP creation

✓ policy testing

✓ service delegation states

✓ Security Tooling Terraform

✓ Network Terraform

✓ IPAM delegated admin

✓ RAM sharing

✓ TGW governance

✓ Route 53 Profile sharing

✓ Identity state

✓ AFT/account lifecycle ownership

✓ CI/CD roles

✓ high-risk approval flows

✓ policy canary OUs

✓ drift detection

✓ brownfield imports

✓ platform contracts

✓ payments-prod account vending

✓ account readiness validation

✓ Multi-Region control-plane design
```

---

# ✅ Lesson 38 — Part 9 Complete

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
Interview Mastery                       NEXT
```

# Next — Lesson 38, Part 10

## Final Revision + SAA/DOP/Interview Mastery

Next we'll compress the entire Lesson 38 into a **never-forget enterprise architecture map** and then pressure-test it with scenarios such as:

```text
"Developer has AdministratorAccess
but gets AccessDenied — why?"

"Should Security Hub run
in the management account?"

"Organizations vs Control Tower?"

"SCP vs RCP?"

"Audit vs Log Archive?"

"Registered OU vs enrolled account?"

"Permission Set vs IAM Role?"

"SAML vs SCIM?"

"GuardDuty vs Inspector vs Macie?"

"Trusted access vs delegated admin?"

"Network account vs Shared Services?"

"TGW sharing vs VPC sharing?"

"Account Factory vs AFT?"

"One Terraform state or many?"

"How would you govern
500 AWS accounts?"

"How does your governance model
survive a Region failure?"
```

We'll also build a **whiteboard-quality reference architecture**, certification traps, senior interview answers, troubleshooting drills, and a final decision tree so Lesson 38 becomes something you can reconstruct from memory rather than memorize blindly.

[1]: https://developer.hashicorp.com/terraform/tutorials/aws/aws-assumerole?utm_source=chatgpt.com "Provision AWS resources across accounts using ..."
[2]: https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html "Overview of AWS Control Tower Account Factory for Terraform (AFT) - AWS Control Tower"
[3]: https://developer.hashicorp.com/terraform/language/backend/s3 "Backend Type: s3 | Terraform | HashiCorp Developer"
[4]: https://developer.hashicorp.com/terraform/language/modules/develop/providers "Providers Within Modules - Configuration Language | Terraform | HashiCorp Developer"
[5]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_ous_best_practices.html?utm_source=chatgpt.com "Best practices for managing organizational units (OUs) with ..."
[6]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[7]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy?utm_source=chatgpt.com "aws_organizations_policy | Resources | hashicorp/aws"
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment?utm_source=chatgpt.com "aws_organizations_policy_attac..."
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html?utm_source=chatgpt.com "Service control policy examples - AWS Organizations"
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[11]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs-policy-delegate.html?utm_source=chatgpt.com "Create a resource-based delegation policy with ..."
[12]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html?utm_source=chatgpt.com "Using AWS Organizations with other AWS services"
[13]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "Delegated administrator for AWS services that work with ..."
[14]: https://docs.aws.amazon.com/ram/latest/userguide/getting-started-sharing.html?utm_source=chatgpt.com "Sharing your AWS resources"
[15]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_organization_admin_account?utm_source=chatgpt.com "aws_vpc_ipam_organization_ad..."
[16]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share?utm_source=chatgpt.com "aws_ram_resource_share | Resources | hashicorp/aws"
[17]: https://docs.aws.amazon.com/ram/latest/userguide/shareable.html?utm_source=chatgpt.com "Shareable AWS resources - AWS Resource Access Manager"
[18]: https://developer.hashicorp.com/terraform/language/state/remote-state-data?utm_source=chatgpt.com "The terraform_remote_state Data Source | Terraform"
