# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 7: Multi-Account Enterprise Hybrid Networking Architecture

We now know the individual technologies:

```text
VPC
Site-to-Site VPN
Direct Connect
DXGW
Transit Gateway
TGW Route Tables
AWS RAM
Network Firewall
Route 53 Resolver
Route 53 Profiles
BGP
IPsec
```

Now we need to answer the question that matters in a large company:

> **Who owns all of this when there are 20, 100, or 500 AWS accounts?**

A production organization normally should not allow every workload account to independently create unrelated TGWs, VPNs, CIDR ranges, DNS forwarding rules, and Internet egress paths.

AWS's multi-account guidance recommends a centralized networking account for shared networking capabilities such as Transit Gateway and VPC IPAM. ([AWS Documentation][1])

Our architecture will become:

```text
                         AWS ORGANIZATION

                 ┌────────────────────────┐
                 │   MANAGEMENT ACCOUNT   │
                 │ Organizations / Guard  │
                 └────────────┬───────────┘
                              │
       ┌──────────────────────┼───────────────────────┐
       │                      │                       │
       ▼                      ▼                       ▼

 INFRASTRUCTURE OU        SECURITY OU            WORKLOADS OU
       │                      │                       │
       │                      │                 ┌─────┼─────┐
       │                      │                 │     │     │
       ▼                      ▼                 ▼     ▼     ▼
 Network Account       Security Account       Prod  Dev    QA
       │                      │
       │                      │
      TGW              Inspection VPC
    DX / VPN            Network Firewall
     IPAM
       │
       └──────────────┐
                      │
                      ▼
              Shared Services
                   Account
                      │
               Route 53 Resolver
                 AD / DNS
                Jenkins / Tools
```

AWS's Security Reference Architecture likewise separates infrastructure/networking, shared services, security/logging, and workload responsibilities into dedicated accounts/OUs. ([AWS Documentation][2])

---

# 36.347 Why multiple AWS accounts?

Imagine one gigantic AWS account containing:

```text
Prod
Dev
QA
Networking
Security
Logging
DNS
Shared services
Analytics
Machine learning
CI/CD
```

Now a networking engineer accidentally changes:

```text
TGW route
```

or an administrator receives excessive IAM permissions.

The blast radius can become enormous.

A multi-account architecture instead gives us isolation boundaries:

```text
PROD ACCOUNT
────────────
Production workloads


DEV ACCOUNT
───────────
Development


NETWORK ACCOUNT
───────────────
Routing / hybrid connectivity


SECURITY ACCOUNT
────────────────
Inspection / security infrastructure


SHARED SERVICES
───────────────
DNS / directory / common tooling
```

The objective isn't:

> "More accounts because more accounts are enterprise."

The objective is:

```text
ownership
+
separation
+
guardrails
+
blast-radius reduction
+
delegated administration
```

---

# 36.348 Our organization structure

Let's design:

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
│   └── Shared-Services
│
├── Workloads-Prod OU
│   │
│   ├── Payments-Prod
│   ├── Orders-Prod
│   └── Data-Prod
│
└── Workloads-NonProd OU
    │
    ├── Development
    ├── QA
    └── Sandbox
```

This type of functional separation aligns closely with AWS multi-account security/reference architecture guidance. ([AWS Documentation][2])

---

# 36.349 Network Account — what should live here?

Our Network account can own:

```text
Transit Gateway

TGW Route Tables

Direct Connect integration

Direct Connect Gateway integration

Site-to-Site VPN

AWS RAM network sharing

IPAM

Central networking automation

Potential centralized ingress/egress components
```

AWS's prescriptive multi-account guidance explicitly recommends using a centralized network account for Transit Gateway and VPC IPAM. ([AWS Documentation][1])

Architecture:

```text
                 NETWORK ACCOUNT

              ┌─────────────────┐
              │ Transit Gateway │
              └───────┬─────────┘
                      │
           ┌──────────┼──────────┐
           │          │          │
           ▼          ▼          ▼
          DX         VPN       AWS RAM
           │          │          │
           ▼          ▼          ▼
        On-Prem    On-Prem    Other Accounts
```

---

# 36.350 Why centralize Transit Gateway?

Suppose each account creates its own:

```text
Prod TGW
Dev TGW
QA TGW
Analytics TGW
Shared TGW
```

Now we need:

```text
5 VPN designs

or

5 DX connectivity strategies

plus

TGW peering

plus

duplicated routing

plus

different route governance.
```

Instead:

```text
                         CENTRAL TGW

        ┌───────────────┬───────────────┬───────────────┐
        │               │               │               │
        ▼               ▼               ▼               ▼
      PROD             DEV             QA            SHARED
```

AWS Transit Gateway can be shared across accounts using AWS RAM, including across an AWS Organization. ([AWS Documentation][3])

That gives the network team centralized visibility over the transit routing plane.

---

# 36.351 AWS RAM becomes critical

Remember:

# AWS Resource Access Manager

RAM lets one account share supported AWS resources with:

```text
another AWS account
an Organizational Unit
or
the AWS Organization
```

Transit Gateway is one of the resources that supports this sharing model. ([AWS Documentation][3])

Architecture:

```text
                         NETWORK ACCOUNT

                         Transit Gateway
                                │
                                │
                             AWS RAM
                                │
              ┌─────────────────┼──────────────────┐
              │                 │                  │
              ▼                 ▼                  ▼
          PROD ACCOUNT      DEV ACCOUNT      SHARED ACCOUNT
              │                 │                  │
           Prod VPC           Dev VPC          Shared VPC
```

---

# 36.352 What gets shared?

Important distinction:

We are not moving the TGW into Prod.

The TGW still belongs to:

```text
Network Account
```

RAM simply gives another account permission to consume the shared TGW.

Conceptually:

```text
Owner
─────

Network Account
      │
      └── TGW


Consumer
────────

Prod Account
      │
      └── attaches Prod VPC
```

AWS documents that after a TGW is shared, participating accounts can attach their VPCs, while management of the TGW routing plane remains with the TGW owner. ([AWS Documentation][4])

---

# 36.353 Owner vs participant responsibilities

This distinction matters greatly.

## TGW Owner — Network Account

Controls areas such as:

```text
TGW

TGW route tables

Route associations

Route propagations

TGW routing policy

RAM share configuration
```

AWS specifically notes that a consumer of a RAM-shared TGW cannot create, modify, or delete the owner's TGW route tables, route propagations, or associations. ([AWS Documentation][5])

---

## Participant — Prod Account

Can own:

```text
Prod VPC
Prod subnets
Prod application routes
Prod SGs
Prod ECS/EKS/EC2/RDS
```

and participate in the TGW attachment lifecycle.

That is an excellent separation:

```text
Application Team
=
owns application VPC


Network Team
=
owns enterprise routing
```

---

# 36.354 Why this ownership model is powerful

Imagine an application developer has full control of:

```text
Payments Prod VPC
```

but security policy says:

```text
Payments Prod
must NEVER directly route to Dev.
```

If the application team controlled all TGW route tables, they might accidentally create:

```text
10.30.0.0/16 → Dev Attachment
```

Instead:

```text
Network Account
```

controls:

```text
TGW PROD-RT
```

and can keep Dev absent or explicitly blackholed.

So:

```text
Application autonomy
       +
Central routing governance
```

can coexist.

---

# 36.355 Example cross-account attachment

Network account owns:

```text
tgw-enterprise
```

Prod account owns:

```text
vpc-prod
10.20.0.0/16
```

Architecture:

```text
NETWORK ACCOUNT                         PROD ACCOUNT

Enterprise TGW                          Prod VPC
     │                                 10.20.0.0/16
     │                                      │
     └────── RAM Shared TGW ────────────────┘
                       │
                       ▼
                VPC Attachment
```

Prod still needs VPC route entries such as:

```text
Destination       Target

10.10.0.0/16      TGW
10.40.0.0/16      TGW
```

because VPC route tables and TGW route tables remain separate routing planes.

---

# 36.356 Then Network Account determines the transit policy

Network account might associate:

```text
Prod attachment
        ↓
PROD-RT
```

Where:

```text
PROD-RT

10.40.0.0/16 → Shared Services
10.10.0.0/16 → Inspection
10.30.0.0/16 → BLACKHOLE
```

Therefore:

```text
Prod → Shared       ✓
Prod → On-Prem      ✓ via inspection
Prod → Dev          ✕
```

This is the same TGW route-table segmentation from Part 2—now implemented across accounts.

---

# 36.357 Security Account / Inspection Account

Now security says:

> Every workload ↔ on-prem and selected east-west flows must be inspected.

We can use a dedicated:

```text
Security Account
```

containing:

```text
Inspection VPC
AWS Network Firewall
or
third-party appliances through GWLB
```

AWS supports centralized inspection using Transit Gateway with AWS Network Firewall in a dedicated security/inspection VPC. ([AWS Documentation][6])

Conceptually:

```text
                          TGW
                           │
                           ▼
                  SECURITY ACCOUNT

                    Inspection VPC
                         │
                  Network Firewall
```

---

# 36.358 Can Firewall live in another account from TGW?

Yes, modern cross-account architectures can share a Transit Gateway with the firewall-owning account through AWS RAM and create the appropriate firewall/TGW attachment from that account. AWS documents the cross-account workflow for a Transit Gateway-attached Network Firewall. ([AWS Documentation][7])

So we can have:

```text
NETWORK ACCOUNT
      │
     TGW
      │
   AWS RAM
      │
      ▼
SECURITY ACCOUNT
      │
Network Firewall
```

This creates clean ownership boundaries.

---

# 36.359 Network team vs security team

One possible model:

```text
NETWORK TEAM

owns:
TGW
DX
VPN
BGP
TGW route tables
IPAM


SECURITY TEAM

owns:
Network Firewall
Firewall policies
IDS/IPS policies
security logging
inspection architecture
```

Then both collaborate on:

```text
traffic steering
```

because:

```text
Network Team decides:

WHERE does packet go?


Security Team decides:

WHAT traffic is allowed/blocked/inspected?
```

That distinction should feel familiar now.

---

# 36.360 Production traffic flow — Prod → On-Prem

Let's combine ownership boundaries.

Source:

```text
Payments Prod Account

10.20.5.50
```

Destination:

```text
On-prem Oracle

10.10.50.20
```

Packet:

```text
PAYMENTS ACCOUNT

EC2/ECS
10.20.5.50
      │
      ▼
Prod VPC Route Table

10.10.0.0/16 → TGW
      │
      ▼


NETWORK ACCOUNT

Prod TGW Attachment
      │
      ▼
PROD-RT

10.10.0.0/16
→ Inspection Attachment
      │
      ▼


SECURITY ACCOUNT

Inspection VPC
      │
      ▼
Network Firewall
      │
      ▼


NETWORK ACCOUNT

TGW
      │
      ▼
DX / VPN
      │
      ▼


CORPORATE DATA CENTER

10.10.50.20
```

Notice:

```text
One packet
crossed multiple AWS accounts.
```

The application doesn't care.

Routing abstracts the ownership boundaries.

---

# 36.361 Return traffic must use the intended inspection path

On-prem response:

```text
10.10.50.20
      ↓
10.20.5.50
```

needs:

```text
On-Prem
  │
 DX
  │
 TGW
  │
 Inspection
  │
 TGW
  │
 Prod
```

not:

```text
On-Prem
  │
 TGW
  │
 Prod
```

because that bypasses the stateful inspection path.

This is why centralized firewall architectures need deliberately designed TGW route tables and, where relevant, appliance mode/stateful flow handling. AWS's centralized inspection guidance uses TGW route steering specifically for this purpose. ([AWS Documentation][6])

---

# 36.362 Shared Services Account

Some services are needed by almost every application account:

```text
Active Directory

DNS Resolver endpoints

Jenkins

Artifact systems

Monitoring collectors

Patch repositories

Internal PKI

Directory services

Time/NTP infrastructure

Other shared tools
```

Instead of rebuilding these in every account:

```text
Prod DNS
Dev DNS
QA DNS
Analytics DNS
```

we can use:

# Shared Services Account.

AWS multi-account guidance explicitly recognizes a Shared Services account for centrally consumed infrastructure and services. ([AWS Documentation][2])

---

# 36.363 Shared Services architecture

```text
                     SHARED SERVICES ACCOUNT

                      Shared Services VPC
                         10.40.0.0/16
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
              DNS/AD        Route53 Resolver   Jenkins
                                │
                      ┌─────────┴─────────┐
                      ▼                   ▼
                  Inbound              Outbound
```

Connected to:

```text
TGW
```

So:

```text
Prod → Shared
Dev  → Shared
QA   → Shared
```

can be allowed while:

```text
Prod ↔ Dev
```

remains blocked.

---

# 36.364 Shared doesn't mean unrestricted

This is important.

Shared VPC may be reachable from:

```text
Prod
Dev
QA
```

but that doesn't mean all networks should communicate freely.

For example:

```text
Prod → DNS
YES

Prod → Jenkins
MAYBE

Dev → Jenkins
YES

QA → DNS
YES

Dev → Active Directory
YES
```

Transit routing determines reachability.

Security groups/firewalls determine allowed services.

Application authentication determines identity.

Again:

```text
ROUTING
≠
AUTHORIZATION
```

---

# 36.365 Multi-account hybrid DNS

Part 6 gave us:

```text
Route 53 inbound endpoint
Route 53 outbound endpoint
Resolver rules
Private Hosted Zones
Route 53 Profiles
```

A centralized model can place hybrid Resolver endpoints in the Shared Services VPC:

```text
                     CORPORATE DNS
                       10.10.1.53
                           │
                           ▼
                       DX / VPN
                           │
                          TGW
                           │
                           ▼
                 SHARED SERVICES VPC

                     Route53 Resolver
                     IN           OUT
                           │
                           ▼
                     Route53 Profile
                           │
                          RAM
                           │
                ┌──────────┼──────────┐
                ▼          ▼          ▼
               Prod       Dev        QA
```

Route 53 Profiles can centrally group and associate DNS resources such as private hosted zones, Resolver rules, and DNS Firewall configurations, and Profiles can be shared through AWS RAM. ([AWS Documentation][8])

---

# 36.366 Why Route 53 Profiles matter at scale

Without Profiles:

```text
100 VPCs

×
15 Resolver rules

×
10 PHZ relationships

×
DNS Firewall policy
```

becomes significant association management.

With a Profile:

```text
                 Corporate-DNS-Profile
                         │
             ┌───────────┼───────────┐
             │           │           │
             ▼           ▼           ▼
        Resolver rules   PHZ    DNS Firewall
                         │
                         ▼
                      AWS RAM
                         │
           ┌─────────────┼──────────────┐
           ▼             ▼              ▼
          Prod          Dev             QA
```

Route 53 currently supports associating Resolver rules and private hosted zones with a Profile and then associating Profiles with VPCs. ([AWS Documentation][9])

That gives us:

```text
DNS policy as centrally managed infrastructure
```

rather than manually configuring every VPC.

---

# 36.367 IP address management becomes mandatory at scale

Now imagine teams independently choose CIDRs:

```text
Payments:
10.20.0.0/16

Orders:
10.20.0.0/16

Dev:
10.20.0.0/16

Analytics:
10.20.0.0/16
```

Everything works while isolated.

Then we attach them all to TGW.

Disaster:

```text
OVERLAPPING CIDRs
```

So enterprise architecture needs:

# Amazon VPC IP Address Manager — IPAM.

AWS IPAM integrates with AWS Organizations, and an organization member account can be delegated as the IPAM administrator responsible for creating IPAMs/pools and managing organizational address usage. ([AWS Documentation][10])

---

# 36.368 IPAM mental model

Without IPAM:

```text
Developer:

"I think 10.20.0.0/16 is free."
```

With IPAM:

```text
Enterprise Address Pool
        │
        ▼
Controlled allocations
```

For example:

```text
CORPORATE
10.0.0.0/8

        │
        ├── On-Prem
        │     10.0.0.0/10
        │
        └── Cloud
              10.64.0.0/10
                    │
          ┌─────────┼──────────┐
          ▼         ▼          ▼
       AWS Prod   AWS Dev   AWS Shared
```

---

# 36.369 Hierarchical IPAM architecture

Let's design an example.

Top-level AWS pool:

```text
10.64.0.0/10
```

Split by Region:

```text
AWS

10.64.0.0/10
      │
      ├── ap-south-1
      │      10.64.0.0/12
      │
      ├── ap-southeast-1
      │      10.80.0.0/12
      │
      └── eu-west-1
             10.96.0.0/12
```

Then Mumbai:

```text
ap-south-1
10.64.0.0/12
      │
      ├── Prod
      │     10.64.0.0/14
      │
      ├── NonProd
      │     10.68.0.0/14
      │
      ├── Shared
      │     10.72.0.0/16
      │
      └── Security
            10.73.0.0/16
```

AWS provides hierarchical, multi-Region IPAM pool models and recommends a network/hub-style delegated account for centralized IP management. ([AWS Documentation][11])

---

# 36.370 Then individual VPC allocation

For example:

```text
PROD POOL
10.64.0.0/14
      │
      ├── Payments Prod
      │     10.64.0.0/16
      │
      ├── Orders Prod
      │     10.65.0.0/16
      │
      └── Data Prod
            10.66.0.0/16
```

Developers don't randomly type a CIDR anymore.

They request an allocation from the appropriate pool.

This dramatically reduces the chance of:

```text
overlapping CIDRs
```

which are particularly painful once networks need TGW/hybrid connectivity.

---

# 36.371 IPAM + AWS RAM

IPAM pools can also be shared with organization accounts using AWS RAM. AWS's multi-account connectivity guidance explicitly recommends sharing IPAM pools along with network resources such as Transit Gateway. ([AWS Documentation][1])

Conceptually:

```text
NETWORK ACCOUNT

IPAM
 │
 ├── PROD POOL
 └── NONPROD POOL
        │
      AWS RAM
        │
   ┌────┴────┐
   ▼         ▼
Prod      NonProd
accounts   accounts
```

Now:

```text
Prod account
```

receives allocations from:

```text
Prod pool
```

rather than inventing addresses.

---

# 36.372 CIDR governance rule

One of the strongest architectural rules:

> **Never allocate AWS CIDRs without considering future connectivity.**

Because today's:

```text
isolated sandbox
```

may become tomorrow's:

```text
production migration
TGW attachment
Direct Connect dependency
company acquisition integration
multi-cloud network
```

Renumbering production networks is far more painful than planning correctly from the start.

---

# 36.373 Centralized egress

Now another enterprise decision.

Suppose we have:

```text
40 workload VPCs
```

Option A:

```text
Every VPC
   │
NAT Gateway
   │
Internet Gateway
   │
Internet
```

Option B:

```text
Workload VPCs
      │
      ▼
     TGW
      │
      ▼
Central Egress / Inspection VPC
      │
Firewall
      │
NAT Gateway
      │
IGW
      │
Internet
```

AWS TGW architectures support centralized security/inspection patterns for multiple VPCs. ([AWS Documentation][6])

---

# 36.374 Centralized egress flow

Prod EC2:

```text
10.64.5.50
```

connects to:

```text
github.com
```

Flow could be:

```text
Prod Private Subnet
       │
       │ 0.0.0.0/0 → TGW
       ▼
      TGW
       │
       ▼
Egress/Inspection VPC
       │
       ▼
Network Firewall
       │
       ▼
NAT Gateway
       │
       ▼
Internet Gateway
       │
       ▼
Internet
```

Return path:

```text
Internet
   │
IGW
   │
NAT Gateway
   │
Firewall
   │
TGW
   │
Prod
```

Again:

```text
symmetry
```

matters for stateful inspection.

---

# 36.375 Why centralize egress?

Potential benefits:

```text
central firewall policies

central logging

central allowlists

central domain controls

consistent egress IP addresses

less duplicated networking infrastructure

simpler security governance
```

But centralized egress also introduces:

```text
TGW processing cost

cross-AZ considerations

shared dependency/blast radius

more complicated routing

central capacity requirements
```

So centralized is not automatically better.

Architecture is always trade-offs.

---

# 36.376 Distributed vs centralized egress

## Distributed

```text
Prod → own NAT

Dev → own NAT

QA → own NAT
```

Benefits:

```text
simple VPC-local routing
smaller blast radius
workload autonomy
```

Costs:

```text
duplicated NAT/firewalls/policies
```

---

## Centralized

```text
Prod ─┐
Dev  ─┼→ TGW → Egress VPC
QA   ─┘
```

Benefits:

```text
central governance
central inspection
shared controls
```

Trade-offs:

```text
transit complexity
central dependency
cost path needs analysis
```

A mature architect chooses based on the organization's needs rather than assuming either model is always correct.

---

# 36.377 Centralized ingress

Inbound Internet applications introduce another architecture question.

Suppose:

```text
Internet
   │
CloudFront/WAF
   │
ALB
   │
Prod
```

One design keeps ingress inside each application account.

Another design may centralize parts of edge/network security.

AWS's Security Reference Architecture describes centralized network/edge infrastructure in a Network account, while actual workload ownership remains separated. ([AWS Documentation][12])

Important:

```text
Ingress architecture
```

and:

```text
East-west TGW architecture
```

are related but not identical.

Do not force all Internet traffic through TGW simply because TGW exists.

---

# 36.378 North-South vs East-West

Network terminology:

## North-South traffic

Traffic entering/leaving the environment:

```text
Internet ↔ AWS

On-Prem ↔ AWS

Partner ↔ AWS
```

## East-West traffic

Traffic between internal workloads:

```text
Prod VPC ↔ Shared VPC

Service A ↔ Service B

VPC A ↔ VPC B
```

Then our controls can differ:

```text
North-South
→ strong perimeter controls


East-West
→ segmentation + workload controls
```

---

# 36.379 Environment segmentation

Let's implement:

```text
TGW Route Tables

PROD-RT
NONPROD-RT
SHARED-RT
SECURITY-RT
HYBRID-RT
```

Associations:

```text
Prod Accounts
      ↓
PROD-RT


Dev / QA Accounts
      ↓
NONPROD-RT


Shared Services
      ↓
SHARED-RT


Inspection VPC
      ↓
SECURITY-RT


DX / VPN
      ↓
HYBRID-RT
```

Now route propagation decides:

```text
who learns whose networks.
```

---

# 36.380 Example route policy

Business requirement:

```text
Prod → Shared        YES
Prod → On-Prem       YES
Prod → Dev           NO

Dev → Shared         YES
Dev → On-Prem        LIMITED
Dev → Prod           NO

On-Prem → Prod       YES
On-Prem → Dev        NO

Everything to On-Prem
→ inspected
```

Possible logical TGW policy:

### PROD-RT

```text
Shared CIDRs → Shared Attachment

On-Prem CIDRs → Inspection

NonProd CIDRs → Blackhole
```

### NONPROD-RT

```text
Shared CIDRs → Shared Attachment

Prod CIDRs → Blackhole

Selected On-Prem CIDRs → Inspection
```

### HYBRID-RT

```text
Prod CIDRs → Inspection

NonProd CIDRs → Blackhole

Shared CIDRs → Inspection
```

### SECURITY-RT

```text
Prod → Prod attachment

NonProd → NonProd attachment

Shared → Shared attachment

On-Prem → DX/VPN
```

This is enterprise routing policy.

---

# 36.381 Blast-radius control

Suppose a Dev engineer accidentally creates:

```text
0.0.0.0/0 → TGW
```

inside a Dev VPC.

Could this suddenly route all Prod traffic through Dev?

No—because:

```text
VPC route table
```

only controls traffic originating from that VPC/subnet.

And the central network team still controls:

```text
TGW route tables
associations
propagations
```

This is one reason separation of control planes helps limit blast radius.

---

# 36.382 Another blast-radius example

Suppose Dev account is compromised.

Attacker owns:

```text
Dev VPC
Dev EC2
Dev SGs
```

but TGW NONPROD-RT contains:

```text
10.64.0.0/14
→ BLACKHOLE
```

for production ranges.

Then the attacker cannot simply add:

```text
Prod route
```

to the centrally owned TGW routing domain.

Defense in depth still requires IAM, SGs, firewalls and application authorization—but centralized routing adds another barrier.

---

# 36.383 Service Control Policies — SCPs

Now we go one level above IAM.

AWS Organizations provides:

# Service Control Policies

SCPs are organization-level **permission guardrails**.

They do not grant permission themselves; rather, they constrain the maximum permissions available to accounts/principals under the applicable organization hierarchy. ([AWS Documentation][13])

Memory trick:

```text
IAM Policy
=
"What may this identity be allowed to do?"


SCP
=
"What can identities in this account/OU
ever be allowed to do?"
```

---

# 36.384 Networking guardrail examples

An organization could use SCP-style governance to restrict actions such as:

```text
creating unauthorized Internet Gateways

creating VPC peerings

modifying specific organization networking patterns

using non-approved Regions

creating unwanted network infrastructure
```

AWS publishes an example SCP pattern that prevents Internet access at account/OU level by restricting actions such as creating/attaching Internet Gateways and certain peering operations. ([AWS Documentation][14])

This is powerful for:

```text
regulated workloads
isolated environments
internal-only application OUs
```

---

# 36.385 Important: SCP does NOT create routes

Never think:

```text
SCP
=
network firewall.
```

No.

SCP controls:

```text
AWS API permissions
```

It doesn't inspect packets.

So:

```text
SCP
→ governance/control-plane guardrail


TGW route table
→ network routing


Network Firewall
→ traffic inspection


Security Group
→ workload-level traffic control
```

These are different layers.

---

# 36.386 Control plane vs data plane

This distinction is extremely useful.

## Control plane

Commands such as:

```text
CreateTransitGatewayRoute
CreateVpc
AttachInternetGateway
CreateVpcPeeringConnection
ModifyVpcAttribute
```

These configure infrastructure.

SCP/IAM can control these API operations.

---

## Data plane

Actual packet:

```text
10.64.5.50
      ↓
10.10.50.20
```

Packet handling is determined by:

```text
routes
TGW
firewalls
SG
NACL
network services
```

So:

```text
Control plane
=
configure network


Data plane
=
network actually carries packets
```

---

# 36.387 Network change governance

For production TGW routing, I would want a workflow such as:

```text
Terraform change
     │
     ▼
Pull Request
     │
     ▼
Peer Review
     │
     ▼
Terraform Plan
     │
     ▼
Security/Network validation
     │
     ▼
Approved pipeline
     │
     ▼
Production TGW change
```

Not:

```text
Engineer logs into console
      ↓
clicks route table
      ↓
changes random route
      ↓
"Let's see what happens."
```

A central Network account makes controlled IaC ownership easier.

---

# 36.388 Terraform repository ownership

Possible structure:

```text
enterprise-networking/
│
├── organizations/
│
├── ipam/
│
├── transit-gateway/
│
├── direct-connect/
│
├── vpn/
│
├── inspection/
│
├── hybrid-dns/
│
└── ram/
```

Separate workload repo:

```text
payments-infrastructure/
│
├── vpc/
├── ecs/
├── alb/
├── rds/
└── application/
```

Then responsibility is clear:

```text
networking repository
=
platform/network team


application repository
=
workload team
```

---

# 36.389 Cross-account IaC model

The networking pipeline may assume a role into:

```text
Network Account
Security Account
Shared Services Account
```

while application pipelines assume roles into:

```text
Prod
Dev
QA
```

Conceptually:

```text
                    CI/CD PLATFORM

                    Terraform Pipeline
                           │
            ┌──────────────┼───────────────┐
            ▼              ▼               ▼
      Network Account Security Account Shared Services
```

Later we'll build the Terraform structure around provider aliases and roles.

---

# 36.390 Tags matter enormously

Every attachment should identify:

```text
Account
Environment
Application
Owner
CostCenter
CIDR
RoutingDomain
Criticality
```

For example:

```text
Name          = payments-prod
Environment   = prod
Account       = payments
RoutingDomain = prod
CIDR          = 10.64.0.0/16
Owner         = payments-platform
```

In large TGWs, a console full of:

```text
tgw-attach-071...
tgw-attach-032...
tgw-attach-092...
```

without meaningful governance quickly becomes painful.

AWS even provides prescriptive patterns for automatically tagging TGW attachments in organizational environments. ([AWS Documentation][15])

---

# 36.391 Regional design

A Transit Gateway is a:

# Regional resource.

AWS explicitly describes TGW as a regional transit hub. ([AWS Documentation][12])

So don't design:

```text
One TGW in Mumbai
   │
magically attaches VPC directly
in every AWS Region
```

Instead:

```text
                 ap-south-1

                 Mumbai TGW
                  /      \
              VPCs       DX


             ap-southeast-1

               Singapore TGW
                  /      \
              VPCs       ...
```

Then connect regions where required.

---

# 36.392 Multi-Region architecture

Example:

```text
                     CORPORATE DC
                          │
                         DXGW
                          │
                ┌─────────┴─────────┐
                │                   │
                ▼                   ▼
          Mumbai TGW          Singapore TGW
            │ │ │                │ │ │
            │ │ │                │ │ │
          Prod Dev Shared      DR Data Apps
```

And potentially:

```text
Mumbai TGW
    │
TGW Peering
    │
Singapore TGW
```

depending on inter-Region application requirements.

Your IPAM hierarchy should reserve non-overlapping address space per Region from day one.

---

# 36.393 Why not one enormous global routing domain?

Because global connectivity creates:

```text
larger failure domains

more routes

more opportunities for accidental reachability

more complicated troubleshooting

greater impact from route leaks
```

Sometimes you want:

```text
Regional autonomy
```

and only selected prefixes to cross Regions.

A strong enterprise design asks:

> **Which networks actually need to communicate?**

not:

> **How can I make everything communicate?**

That mindset is extremely important.

---

# 36.394 Multi-Region route segmentation

Imagine:

```text
Mumbai Prod
10.64.0.0/14

Singapore DR
10.80.0.0/14
```

DR requirement:

```text
Mumbai Prod → Singapore DR
YES


Mumbai Dev → Singapore Prod
NO
```

Then TGW peering route tables should include only required prefixes.

Do not simply add:

```text
10.0.0.0/8
→ TGW Peering
```

unless that's intentionally your architecture.

Specific routing improves control and understanding.

---

# 36.395 On-prem hybrid architecture at organization scale

Let's connect our data center:

```text
                         CORPORATE DATA CENTER

                             Router A
                             Router B
                                │
                   ┌────────────┴─────────────┐
                   │                          │
               Direct Connect             VPN Backup
                   │                          │
                   ▼                          ▼
                  DXGW                  VPN Attachment
                   │                          │
                   └─────────────┬────────────┘
                                 ▼
                           NETWORK ACCOUNT
                                 │
                                TGW
                                 │
               ┌─────────────────┼───────────────────┐
               │                 │                   │
               ▼                 ▼                   ▼
         SECURITY ACCOUNT   SHARED SERVICES     WORKLOADS
              Firewall       Resolver/AD      Prod/Dev/QA
```

That's the hybrid hub.

---

# 36.396 Full organization architecture

Now put everything together:

```text
                              AWS ORGANIZATION

┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│                      MANAGEMENT ACCOUNT                            │
│                Organizations / SCPs / Governance                   │
│                                                                    │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
         ┌─────────────────────┼───────────────────────┐
         │                     │                       │
         ▼                     ▼                       ▼

   INFRASTRUCTURE OU       SECURITY OU             WORKLOAD OUs
         │                     │                       │
         │                     │                       │
 ┌───────┴────────┐            │            ┌─────────┼─────────┐
 ▼                ▼            ▼            ▼         ▼         ▼
NETWORK       SHARED SVCS    SECURITY      PROD      DEV        QA
ACCOUNT        ACCOUNT       ACCOUNT      ACCOUNT   ACCOUNT    ACCOUNT
 │                │            │            │         │         │
 │                │            │            │         │         │
 │              Resolver    Inspection    VPC       VPC       VPC
 │              AD / DNS      VPC           │         │         │
 │              Jenkins        │            │         │         │
 │                             │            └─────────┼─────────┘
 │                             │                      │
 │                             └──────────┐           │
 │                                        │           │
 ▼                                        ▼           ▼
Transit Gateway ◄──────────────── Network Firewall   TGW Attachments
 │
 ├── PROD-RT
 ├── NONPROD-RT
 ├── SHARED-RT
 ├── SECURITY-RT
 └── HYBRID-RT
 │
 ├── Direct Connect Gateway
 │
 └── Site-to-Site VPN
 │
 ▼
CORPORATE DATA CENTER
```

This is now an actual enterprise platform architecture rather than a collection of AWS services.

---

# 36.397 Add IPAM

```text
                         NETWORK ACCOUNT

                              IPAM
                               │
                        AWS 10.64/10
                               │
             ┌─────────────────┼────────────────┐
             │                 │                │
             ▼                 ▼                ▼
         Mumbai Pool      Singapore Pool     EU Pool
             │
        ┌────┼────┐
        ▼    ▼    ▼
      Prod  Dev Shared
```

Then:

```text
AWS RAM
```

shares the appropriate pool with each account/OU. AWS supports organizational IPAM administration and sharing of centrally managed IP address resources. ([AWS Documentation][10])

---

# 36.398 Add DNS governance

```text
                  SHARED SERVICES ACCOUNT

                    Route 53 Profile
                           │
          ┌────────────────┼────────────────┐
          │                │                │
       Resolver          Private         DNS
        Rules             Zones         Firewall
          │                │                │
          └────────────────┼────────────────┘
                           │
                         AWS RAM
                           │
               ┌───────────┼───────────┐
               ▼           ▼           ▼
              Prod        Dev          QA
```

Route 53 Profiles currently support centrally associating VPC DNS resources and sharing those Profiles through AWS RAM. ([AWS Documentation][16])

---

# 36.399 Add organizational guardrails

```text
                     ORGANIZATIONS
                          │
                         SCP
                          │
                 ┌────────┼────────┐
                 ▼        ▼        ▼
                Prod     Dev      QA

Examples:

No unauthorized IGW
No unauthorized peering
Approved Regions
Restrict critical network modification
```

Remember: SCPs define maximum permission boundaries at the organization level; identities still require IAM permissions to perform allowed operations. ([AWS Documentation][13])

---

# 36.400 One of the most important architecture principles

Avoid this:

```text
ACCOUNT
  │
  └── owns everything
```

Prefer clear responsibility:

```text
NETWORK ACCOUNT
→ connectivity


SECURITY ACCOUNT
→ inspection/security


SHARED SERVICES
→ shared infrastructure/DNS


WORKLOAD ACCOUNT
→ application


ORGANIZATIONS
→ governance


IPAM
→ address governance
```

That makes failures, ownership and permissions much easier to reason about.

---

# 36.401 Production incident — "Prod cannot reach on-prem"

Now troubleshooting spans accounts.

Don't panic.

Follow the packet.

### Workload Account

```text
1. Prod subnet route → TGW?
2. SG correct?
3. NACL correct?
```

### Network Account

```text
4. TGW attachment available?
5. Correct route-table association?
6. Correct TGW route to inspection?
```

### Security Account

```text
7. Firewall attachment healthy?
8. Firewall policy allows traffic?
9. Return path symmetric?
```

### Network Account again

```text
10. TGW route toward DX/VPN?
11. DX/VPN healthy?
12. BGP route present?
```

### On-Prem

```text
13. Firewall?
14. Return route?
15. Application?
```

Same packet-flow principle—just across organizational ownership boundaries.

---

# 36.402 Incident — "New VPC can't connect to anything"

New account:

```text
Analytics
10.74.0.0/16
```

Developer says:

> "I attached it to TGW."

Check:

```text
VPC route table?
     ↓
TGW attachment?
     ↓
attachment accepted/available?
     ↓
TGW RT association?
     ↓
propagation?
     ↓
return routes?
     ↓
security?
```

The biggest beginner mistake remains:

```text
Attachment exists
=
connectivity should work.
```

No.

An attachment only establishes the connection object.

Routing policy still determines actual reachability.

---

# 36.403 Incident — "Prod suddenly can reach Dev"

This is a security incident.

Check:

```text
PROD-RT
```

Did someone add:

```text
10.68.0.0/14 → NonProd attachment?
```

Or enable a propagation that should not exist?

Then ask:

```text
Who changed it?
Was it console?
Terraform?
Pipeline?
Which IAM role?
```

This is why centralized ownership + IaC + logging is much stronger than manually managed routing.

---

# 36.404 Incident — "New VPC CIDR overlaps an acquisition"

Example:

```text
AWS Analytics
10.100.0.0/16

Acquired Company
10.100.0.0/16
```

Now Direct Connect integration begins.

Problem:

```text
two destinations
same address space.
```

Potential solutions become much more complicated:

```text
renumbering
NAT
segmentation
proxy patterns
application migration
```

IPAM won't magically fix an old overlap, but centralized allocation can prevent many new ones.

Prevention is much cheaper.

---

# 36.405 Incident — "DNS resolves but application times out"

Example:

```bash
dig oracle.corp.internal
```

returns:

```text
10.10.50.20
```

DNS:

```text
✓
```

Then:

```bash
nc -vz oracle.corp.internal 1521
```

fails.

Now stop debugging DNS.

Move down:

```text
VPC route
TGW
Firewall
DX/VPN
On-prem route
Oracle listener
```

This troubleshooting separation should now be instinctive.

---

# 36.406 Incident — "VPC got an unexpected CIDR"

If VPC allocation is centrally governed:

```text
IPAM Pool
```

check:

```text
Which pool was used?

Which Region?

Which environment?

Was the correct RAM-shared pool selected?

Did the Terraform module request the correct allocation?
```

Much better than manually searching a spreadsheet named:

```text
aws-ip-ranges-final-v7-really-final.xlsx
```

for what somebody thinks is still free.

---

# 36.407 Enterprise ownership matrix

| Component                 | Typical owner                         |
| ------------------------- | ------------------------------------- |
| AWS Organizations         | Cloud governance/platform             |
| SCPs                      | Governance/security                   |
| IPAM                      | Network team                          |
| TGW                       | Network account/team                  |
| TGW route tables          | Network team                          |
| Direct Connect            | Network team                          |
| VPN                       | Network team                          |
| BGP                       | Network team + corporate network team |
| Inspection VPC            | Security/network architecture         |
| Network Firewall policy   | Security                              |
| Shared DNS                | Shared services/network               |
| Resolver endpoints        | Shared services/network               |
| Route 53 Profiles         | DNS/network platform                  |
| Workload VPC              | Application/platform team             |
| Application SGs           | Workload/platform/security            |
| ECS/EKS/RDS               | Workload team                         |
| Application authorization | Application team                      |

This is an architectural pattern, not an AWS-enforced requirement; organizations may assign ownership differently. The important thing is clear separation and governance.

---

# 36.408 Never-forget AWS RAM distinction

```text
RAM SHARING
does not mean:

"consumer owns the resource"
```

Think:

```text
Network Account
       │
       │ owns
       ▼
      TGW
       │
       │ shares usage
       ▼
Prod Account
```

The TGW owner retains control of the central TGW routing plane. ([AWS Documentation][5])

---

# 36.409 Never-forget IPAM distinction

IPAM isn't a router.

It doesn't forward:

```text
10.64.5.50 → 10.10.20.20
```

Its job is:

```text
plan
allocate
track
monitor
govern

IP address space
```

Routing remains TGW/VPC/BGP.

---

# 36.410 Never-forget SCP distinction

SCP:

```text
controls what APIs may be permitted
```

TGW route table:

```text
controls where packets go
```

Network Firewall:

```text
controls which traffic passes inspection
```

Route 53:

```text
controls how names resolve
```

IPAM:

```text
controls IP allocations
```

Keep those layers separate in your mental model.

---

# 36.411 Terraform preview — RAM shared TGW

Network account conceptually:

```hcl
resource "aws_ram_resource_share" "network" {
  name = "enterprise-network"
}
```

Then associate TGW:

```hcl
resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.network.arn
}
```

Then organization/OU/account principals can be associated with that resource share according to your design.

AWS RAM is the supported mechanism for sharing TGWs across accounts and organization boundaries. ([AWS Documentation][3])

---

# 36.412 Terraform preview — TGW segmentation

Conceptually:

```hcl
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}
```

Then:

```text
attachments
       ↓
associations
       ↓
propagations
       ↓
routes
```

We'll build this properly in Part 8 rather than leave it as pseudocode.

---

# 36.413 Terraform preview — IPAM

Architecture:

```text
IPAM
 │
 └── Private Scope
       │
       └── AWS Pool
             │
             ├── Mumbai
             ├── Singapore
             └── EU
```

Terraform resources you'll eventually recognize include:

```text
aws_vpc_ipam
aws_vpc_ipam_pool
aws_vpc_ipam_pool_cidr
```

Then workload VPCs can allocate their CIDRs from centralized pools instead of hard-coding overlapping networks.

---

# 36.414 Complete packet ownership map

Suppose:

```text
Payments ECS
10.64.5.20
```

calls:

```text
oracle.corp.internal
```

Watch every organizational component participate:

```text
1. DNS
────────────────────────

Payments Account
    │
VPC Resolver
    │
Route53 Profile
    │
Shared Services
    │
Outbound Resolver
    │
TGW
    │
Corporate DNS
    │
10.10.50.20


2. APPLICATION CONNECTION
─────────────────────────

Payments Account
10.64.5.20
    │
VPC Route
    │
    ▼

Network Account
TGW
    │
    ▼

Security Account
Firewall
    │
    ▼

Network Account
TGW
    │
DXGW
    │
Direct Connect
    │
    ▼

Corporate Data Center
10.10.50.20
```

That's the beauty of the full architecture:

```text
DNS
routing
inspection
hybrid transport
organization boundaries
```

all cooperate.

---

# 36.415 What happens when a new production account is created?

Imagine:

```text
New Application:
Fraud Detection
```

Instead of manually inventing everything:

### Step 1

Create:

```text
Fraud-Prod AWS Account
```

inside:

```text
Workloads-Prod OU
```

### Step 2

Account inherits organizational guardrails.

### Step 3

Allocate CIDR from:

```text
Prod IPAM pool
```

Example:

```text
10.67.0.0/16
```

### Step 4

Create VPC/subnets.

### Step 5

Attach VPC to shared TGW.

### Step 6

Network automation associates attachment with:

```text
PROD-RT
```

### Step 7

Associate corporate Route 53 Profile.

### Step 8

Security policies apply.

### Step 9

Workload receives controlled reachability to:

```text
Shared services
On-prem
approved production services
```

but not:

```text
Dev
QA
unapproved networks
```

That is:

# Platform engineering for networking.

---

# 36.416 This is where networking becomes a platform

Instead of developers submitting tickets:

> “Can you create a VPC?”

> “Which CIDR should I use?”

> “Can you add a DNS rule?”

> “Can you connect us to TGW?”

> “Can you add an on-prem route?”

we can create a standardized network product:

```text
new production VPC
      │
      ▼
Terraform module
      │
      ├── IPAM allocation
      ├── VPC
      ├── subnets
      ├── route tables
      ├── TGW attachment
      ├── DNS profile
      ├── logging
      ├── baseline security
      └── tags
```

Now network architecture becomes:

```text
self-service
+
guardrails
```

rather than:

```text
manual tickets.
```

We'll revisit this heavily when we reach the **Platform Engineering module** later in the masterclass.

---

# 36.417 One enterprise rule you should remember

A workload team should ideally be able to say:

```text
"I need a production VPC."
```

without having to understand:

```text
which IP block is free
which TGW RT to use
which Resolver forwarding rules exist
which DX prefixes must be advertised
which firewall path is required
```

The platform should encode those rules safely.

That's Infrastructure as Code maturity.

---

# 36.418 Our final target architecture

You should now be able to understand this entire diagram:

```text
                           CORPORATE DATA CENTER
                              10.10.0.0/16

                    ┌─────────────────────────┐
                    │ Routers A / B           │
                    └───────┬─────────┬───────┘
                            │         │
                           DX        VPN
                            │         │
                            └────┬────┘
                                 ▼
                               DXGW
                                 │
                                 ▼

┌──────────────────────────────────────────────────────────────┐
│                      AWS ORGANIZATION                        │
│                                                              │
│                  NETWORK ACCOUNT                             │
│                                                              │
│                         TGW                                  │
│                    ┌─────┼─────┐                             │
│                    │     │     │                             │
│                 PROD   NONPROD HYBRID                        │
│                   RT      RT    RT                           │
│                    │      │     │                            │
│                    └──────┼─────┘                            │
│                           │                                  │
├───────────────────────────┼──────────────────────────────────┤
│                           │                                  │
│ SECURITY ACCOUNT          │                                  │
│                           ▼                                  │
│                   Inspection VPC                             │
│                   Network Firewall                           │
│                   Appliance Mode                             │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ SHARED SERVICES ACCOUNT                                     │
│                                                              │
│                   Shared Services VPC                        │
│                   ├── Resolver IN                            │
│                   ├── Resolver OUT                           │
│                   ├── Route53 Profile                        │
│                   ├── AD/DNS                                 │
│                   └── Shared tools                           │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ WORKLOAD ACCOUNTS                                            │
│                                                              │
│        PROD              DEV             QA                  │
│        VPC               VPC             VPC                 │
│         │                 │               │                  │
│        ECS               EKS             EC2                 │
│        RDS               RDS                                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘

                 NETWORK ACCOUNT ALSO OWNS

                        VPC IPAM
                           │
              ┌────────────┼─────────────┐
              ▼            ▼             ▼
             PROD        NONPROD       SHARED
             POOL          POOL          POOL

                         AWS RAM
                           │
           TGW + IPAM + DNS resources shared
                           │
                           ▼
                      Member Accounts
```

This is no longer merely:

```text
"an AWS VPC setup."
```

It is:

# An enterprise cloud network platform.

---

# 36.419 Never-forget multi-account table

| Component                   | Purpose                               |
| --------------------------- | ------------------------------------- |
| **AWS Organizations**       | Account hierarchy/governance          |
| **OU**                      | Group accounts by governance boundary |
| **SCP**                     | Maximum-permission guardrail          |
| **Network Account**         | Central networking ownership          |
| **Security Account**        | Central security/inspection ownership |
| **Shared Services Account** | Common infrastructure                 |
| **Workload Account**        | Application isolation                 |
| **AWS RAM**                 | Cross-account resource sharing        |
| **TGW**                     | Central transit routing               |
| **TGW RT**                  | Routing-domain segmentation           |
| **IPAM**                    | Enterprise IP address governance      |
| **DX/DXGW**                 | Dedicated hybrid connectivity         |
| **VPN**                     | Encrypted hybrid connectivity/backup  |
| **Network Firewall**        | Central traffic inspection            |
| **Route 53 Resolver**       | Hybrid DNS forwarding                 |
| **Route 53 Profile**        | Centralized VPC DNS policy bundle     |
| **Terraform**               | Repeatable network configuration      |

---

# 36.420 Six questions a senior cloud/network architect asks

Whenever designing a multi-account environment, ask:

```text
1. WHO OWNS ROUTING?

Network Account?


2. WHO OWNS SECURITY INSPECTION?

Security Account?


3. WHO OWNS ADDRESS SPACE?

IPAM / Network team?


4. WHO OWNS DNS?

Shared Services / DNS platform?


5. WHICH NETWORKS MAY COMMUNICATE?

TGW segmentation policy?


6. WHAT HAPPENS WHEN ANY ONE COMPONENT FAILS?

DX?
VPN?
TGW attachment?
Firewall?
Resolver?
Region?
```

If those six questions don't have clear answers, the network architecture isn't finished.

---

# 36.421 Never-forget architecture progression

Look how far we've come.

### Beginner AWS

```text
EC2
 │
VPC
 │
IGW
```

### Intermediate

```text
Public + Private Subnets
        │
       NAT
        │
       ALB
```

### Advanced

```text
Multiple VPCs
     │
    TGW
```

### Hybrid

```text
On-Prem
  │
VPN / DX
  │
 TGW
```

### Enterprise

```text
                    Organization

                      Network
                        │
                 DX/VPN/TGW/IPAM
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
    Security          Shared          Workloads
    Firewall          DNS             Prod/Dev
```

And next we stop drawing it theoretically.

# We build it.

---

# Next — Lesson 36, Part 8

## Terraform Enterprise Hybrid Network Build

Next we'll translate this architecture into Infrastructure as Code.

We'll build the Terraform structure for:

```text
AWS Organization-style account separation
        │
        ├── Network provider
        ├── Security provider
        └── Workload providers

VPC IPAM
        │
        ├── Prod pool
        ├── NonProd pool
        └── Shared pool

Transit Gateway
        │
        ├── PROD-RT
        ├── NONPROD-RT
        ├── SHARED-RT
        ├── SECURITY-RT
        └── HYBRID-RT

AWS RAM
        │
        └── TGW sharing

VPC Attachments
        │
        ├── Prod
        ├── Dev
        ├── Shared
        └── Inspection

Route associations
Route propagation
Blackhole routes

Site-to-Site VPN
BGP configuration model

Direct Connect / DXGW architecture

Inspection VPC

Route 53 Resolver
        │
        ├── Inbound
        ├── Outbound
        └── corp.internal forwarding

Private Hosted Zones

Security groups

Outputs

Validation
```

And importantly, I won't just give you a giant Terraform file.

We'll build it like a production repository:

```text
hybrid-cloud/
│
├── modules/
│   ├── ipam/
│   ├── vpc/
│   ├── transit-gateway/
│   ├── inspection/
│   ├── hybrid-dns/
│   └── vpn/
│
├── environments/
│   └── ap-south-1/
│
├── providers.tf
├── backend.tf
├── variables.tf
├── locals.tf
└── outputs.tf
```

We'll understand **why every resource exists, what account owns it, what packet flow it creates, what routes it changes, and how to troubleshoot it when Terraform says `Apply complete` but connectivity still doesn't work.**

[1]: https://docs.aws.amazon.com/prescriptive-guidance/latest/transitioning-to-multiple-aws-accounts/network-connectivity.html?utm_source=chatgpt.com "Network connectivity - AWS Prescriptive Guidance"
[2]: https://docs.aws.amazon.com/prescriptive-guidance/latest/aws-security-reference-architecture-payment-card-industry-pci-data-security-standard-dss/best-practices.html?utm_source=chatgpt.com "AWS Organization Architecture – OU and Account structure"
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/working-with-transit-gateways.html?utm_source=chatgpt.com "Work with AWS Transit Gateway - Amazon VPC"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-transit-gateways.html?utm_source=chatgpt.com "Transit gateways in AWS Transit Gateway - Amazon VPC"
[5]: https://docs.aws.amazon.com/prescriptive-guidance/latest/integrate-third-party-services/architecture-3-1.html?utm_source=chatgpt.com "Architecture 3.1: Transit Gateway with AWS RAM"
[6]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-network-security-for-vpc-to-vpc-and-on-premises-to-vpc-traffic.html?utm_source=chatgpt.com "Centralized network security for VPC-to-VPC and on- ..."
[7]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/create-tgw-firewall.html?utm_source=chatgpt.com "Create a transit gateway-attached firewall from a shared ..."
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/profiles.html?utm_source=chatgpt.com "What are Amazon Route 53 Profiles?"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/profile-associate-resolver-rules.html?utm_source=chatgpt.com "Associate Resolver rules to a Route 53 Profile"
[10]: https://docs.aws.amazon.com/vpc/latest/ipam/enable-integ-ipam.html?utm_source=chatgpt.com "Integrate IPAM with accounts in an AWS Organization"
[11]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/multi-region-ipam-architecture.html?utm_source=chatgpt.com "Create a hierarchical, multi-Region IPAM architecture on ..."
[12]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/network.html?utm_source=chatgpt.com "Infrastructure OU – Network account"
[13]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html?utm_source=chatgpt.com "Service control policy examples - AWS Organizations"
[14]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/prevent-internet-access-at-the-account-level-by-using-a-service-control-policy.html?utm_source=chatgpt.com "Prevent internet access at the account level by using a ..."
[15]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/tag-transit-gateway-attachments-automatically-using-aws-organizations.html?utm_source=chatgpt.com "Tag Transit Gateway attachments automatically using ..."
[16]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/sharing-profiles.html?utm_source=chatgpt.com "Working with shared Route 53 Profiles - AWS Documentation"
