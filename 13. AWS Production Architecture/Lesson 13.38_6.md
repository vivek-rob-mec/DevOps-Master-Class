# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 6: Central Network Account, Shared Services & Enterprise Connectivity

We have now built:

```text
AWS Organizations              ✓
SCP / RCP governance           ✓
Control Tower                  ✓
IAM Identity Center            ✓
Central security/logging       ✓
```

Now we combine **Lesson 36 networking** with **Lesson 38 governance**.

The enterprise question is no longer:

> “How do I connect one VPC to another?”

It becomes:

> **Who owns IP addresses, Transit Gateway, hybrid connectivity, DNS, firewalls, Internet egress, shared endpoints, and routing when 100+ application accounts exist?**

A mature starting architecture is:

```text
                            AWS ORGANIZATION
                                  │
                         Infrastructure OU
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼

     NETWORK ACCOUNT       SHARED SERVICES          PLATFORM
                               ACCOUNT              ACCOUNT
          │                       │
          │                       ├── DNS
          │                       ├── AD
          │                       ├── Private CA
          │                       └── shared tools
          │
          ├── Transit Gateway
          ├── IPAM
          ├── Direct Connect
          ├── VPN
          ├── inspection
          ├── centralized egress
          └── network automation
                    │
              AWS RAM sharing
                    │
       ┌────────────┼───────────────┐
       ▼            ▼               ▼
   Payments      Orders         Analytics
   Account       Account         Account
```

AWS supports sharing a Transit Gateway, IPAM pools, Route 53 Profiles, Resolver rules, subnets, prefix lists, and many other supported resources across AWS accounts through AWS Resource Access Manager. ([AWS Documentation][1])

---

# 38.580 First rule — centralize policy, not every operation

A bad interpretation of centralized networking is:

```text
NETWORK TEAM
must create every:

security group
EC2 interface
application route
load balancer
DNS record
```

That becomes a ticket bottleneck.

A better model is:

```text
CENTRAL NETWORK TEAM

owns:
enterprise address space
transit
hybrid connectivity
central inspection
shared DNS infrastructure
egress policy
enterprise network standards


APPLICATION TEAM

owns:
application resources
application SGs
local workload configuration
service-specific connectivity
within approved boundaries
```

The goal is **central control of shared network primitives with decentralized application delivery**.

---

# 38.581 Account responsibilities

A useful split:

| Account          | Primary responsibility                      |
| ---------------- | ------------------------------------------- |
| Network          | Connectivity and enterprise network control |
| Shared Services  | DNS, directories, common internal services  |
| Security Tooling | Security policy/monitoring                  |
| Workload         | Application resources                       |
| Platform         | Developer/platform automation               |

Do not merge everything into a Network account simply because it uses an IP address.

---

# 38.582 Why a dedicated Network account?

Without one:

```text
Payments
  TGW?

Orders
  VPN?

Analytics
  DNS?

Dev
  NAT?

Security
  DX?
```

Ownership becomes unclear.

With a dedicated Network account:

```text
                  NETWORK ACCOUNT

                     TGW
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼

       Prod VPC     Dev VPC    Shared VPC
```

you gain:

```text
one transit owner

central route governance

consistent hybrid connectivity

clear incident ownership

central network observability
```

Transit Gateway is specifically designed to act as a hub connecting VPCs and on-premises networks. ([AWS Documentation][2])

---

# 38.583 Transit Gateway ownership

Suppose:

```text
Network Account
owns:

tgw-prod
```

Workload accounts own:

```text
Payments VPC
Orders VPC
Analytics VPC
```

AWS RAM can share the Transit Gateway with those accounts.

```text
NETWORK ACCOUNT

Transit Gateway
      │
      │ AWS RAM
      ▼
Organization / OUs
      │
   ┌──┼───────────────┐
   ▼  ▼               ▼
Pay Orders         Analytics
```

A shared Transit Gateway lets participant accounts create VPC attachments to it, while the Transit Gateway owner retains control of Transit Gateway route tables and their associations/propagations. ([AWS Documentation][3])

---

# 38.584 This creates an important governance boundary

### Workload account

May create:

```text
VPC
      │
      ▼
TGW VPC attachment
```

### Network account

Controls:

```text
Transit Gateway

TGW route tables

TGW associations

TGW propagations

routing domains
```

So:

```text
APPLICATION TEAM
controls connection request


NETWORK TEAM
controls where packets can go
after entering transit
```

That is an excellent enterprise separation of duties. ([AWS Documentation][3])

---

# 38.585 Remember Lesson 36

We learned:

```text
VPC ROUTE TABLE
=
How packet leaves the VPC


TGW ROUTE TABLE
=
Once packet reaches TGW,
where should transit send it?
```

Now add account ownership:

```text
WORKLOAD ACCOUNT
often owns VPC route intent

NETWORK ACCOUNT
owns transit routing intent
```

That is the governance layer around the packet walk.

---

# 38.586 Shared TGW packet flow

Example:

```text
Payments VPC
10.10.0.0/16

Orders VPC
10.20.0.0/16
```

Payment instance sends:

```text
10.10.1.50
      │
      ▼
10.20.5.10
```

Packet path:

```text
Payments EC2
     │
     ▼
Payments subnet route table

10.20.0.0/16
→ TGW
     │
     ▼
Payments TGW attachment
     │
     ▼
TGW route table
     │
10.20.0.0/16
→ Orders attachment
     │
     ▼
Orders VPC
     │
     ▼
Orders EC2
```

The shared-resource model does not eliminate any of the routing logic from Lesson 36—it only places control of those layers in different AWS accounts.

---

# 38.587 Critical shared-TGW limitation

A participant account that consumes a shared TGW cannot:

```text
create TGW route tables

change TGW route tables

change TGW route-table associations

change TGW route-table propagations
```

Those are owner-side responsibilities. ([AWS Documentation][3])

This is exactly why centralizing the TGW is useful.

---

# 38.588 But participants can create attachments

A consuming workload account can use the shared Transit Gateway to create and describe attachments for VPCs it owns. ([AWS Documentation][3])

So the workflow can be:

```text
Payments Terraform
      │
      ▼
Create VPC
      │
      ▼
Create TGW attachment
      │
      ▼
Network automation detects attachment
      │
      ▼
associate with correct
TGW route domain
```

That enables self-service without surrendering transit policy.

---

# 38.589 TGW routing domains

Enterprise network:

```text
                 TGW

         ┌────────┼─────────┐
         ▼        ▼         ▼

      PROD RT   DEV RT   SHARED RT
```

Production attachment:

```text
Payments
→ PROD RT
```

Development attachment:

```text
Dev
→ DEV RT
```

Security Shared Services:

```text
DNS
→ SHARED RT
```

This lets a single TGW implement segmentation instead of creating a full mesh between every VPC.

---

# 38.590 Example segmentation

Requirement:

```text
Prod ↔ Shared Services     YES

Dev ↔ Shared Services      YES

Prod ↔ Dev                 NO
```

Use:

```text
Prod RT
  ├── Prod routes
  └── Shared routes


Dev RT
  ├── Dev routes
  └── Shared routes
```

Do not propagate:

```text
Dev CIDRs
```

into:

```text
Prod RT
```

unless the architecture requires it.

---

# 38.591 AWS RAM — the sharing layer

AWS Resource Access Manager answers:

> **How can Account A centrally own an AWS resource while Account B is permitted to consume it?**

Examples include:

```text
Transit Gateway

IPAM pools

Route 53 Profiles

Resolver rules

subnets

prefix lists

DNS Firewall rule groups

shared security groups
```

depending on each resource type's supported sharing model. ([AWS Documentation][1])

---

# 38.592 RAM with Organizations

When RAM sharing with AWS Organizations is enabled:

```text
Network Account
      │
      ▼
Resource Share
      │
      ├── Organization
      ├── Production OU
      └── specific accounts
```

resources can be made available to organization principals without sending individual RAM invitations. AWS requires RAM's Organizations sharing integration to be enabled for this seamless organization sharing model. ([AWS Documentation][4])

---

# 38.593 Important setup nuance

AWS explicitly warns that simply enabling trusted access from the Organizations side is not equivalent to enabling RAM organization sharing correctly.

Use RAM's integration flow, for example:

```bash
aws ram enable-sharing-with-aws-organization
```

so RAM creates the service-linked role it needs. ([AWS Documentation][4])

This is a great troubleshooting fact.

---

# 38.594 No RAM share ≠ no network

Do not confuse:

```text
RAM
```

with:

```text
routing protocol.
```

RAM determines:

```text
who can consume the shared resource
```

Transit Gateway determines:

```text
where packets route.
```

Different layers.

---

# 38.595 RAM does not grant all IAM permissions either

Suppose Network account shares:

```text
Transit Gateway
```

to Payments.

That does not automatically mean every IAM role in Payments can use every relevant API.

The Payments account administrator still must grant appropriate local IAM permissions to its principals. AWS explicitly notes that receiving a RAM share does not automatically authorize all identities in the consuming account. ([AWS Documentation][5])

Sound familiar?

```text
RESOURCE SHARE
≠
IAM GRANT
```

Same mental discipline as SCPs.

---

# 38.596 IPAM — enterprise address governance

Now imagine 100 accounts independently creating:

```text
10.0.0.0/16
```

because:

> “That's our standard VPC CIDR.”

Soon:

```text
Payments
10.0.0.0/16

Orders
10.0.0.0/16

Analytics
10.0.0.0/16
```

Then you attempt Transit Gateway connectivity.

Problem:

# Overlapping CIDRs.

This is where:

# **Amazon VPC IP Address Manager — IPAM**

becomes important.

---

# 38.597 IPAM mental model

Think:

```text
ENTERPRISE IP SPACE

10.0.0.0/8
     │
     ├── India
     │     └── 10.64.0.0/10
     │
     ├── Singapore
     │     └── 10.128.0.0/10
     │
     └── On-Prem
           └── separate plan
```

Then:

```text
Prod pool
Dev pool
Shared Services pool
```

allocate smaller blocks.

---

# 38.598 IPAM delegated administrator

AWS Organizations can delegate a member account as the organization's IPAM administrator.

The delegated IPAM account can:

```text
manage IPAM

monitor address usage
across organization accounts

share pools
through RAM
```

and automatically discover existing organization VPC CIDRs. AWS does not allow the Organizations management account itself to be the delegated IPAM account. ([AWS Documentation][6])

A common choice is:

```text
Network Account
=
IPAM delegated administrator
```

---

# 38.599 IPAM architecture

```text
                    NETWORK ACCOUNT

                         IPAM
                          │
                   Private Scope
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼

   India Pool       Singapore Pool      Shared Pool

10.64.0.0/10       10.128.0.0/10     10.192.0.0/12
        │                 │
        ▼                 ▼
      Prod              Prod
      Dev               Dev
```

Then share selected child pools through RAM.

AWS supports organization members allocating CIDRs from shared IPAM pools. ([AWS Documentation][6])

---

# 38.600 VPC provisioning changes

Old:

```hcl
cidr_block = "10.20.0.0/16"
```

which every developer invents manually.

Better conceptual model:

```text
VPC request
      │
      ▼
IPAM Pool:
Mumbai-Production
      │
      ▼
allocate /20
      │
      ▼
10.64.32.0/20
```

Now IP allocation becomes governed instead of guessed.

---

# 38.601 IPAM benefit — existing resource discovery

Once an organization member account is delegated as IPAM administrator, IPAM can monitor and import address usage from member accounts across the organization rather than seeing only the account in which IPAM was created. ([AWS Documentation][6])

That helps answer:

```text
Which CIDRs are already used?

Where are overlaps?

Which pools are close to exhaustion?

Which account owns 10.64.16.0/20?
```

---

# 38.602 IPAM is not DHCP

Another trap.

IPAM manages:

```text
address planning
CIDR allocations
utilization
organizational visibility
```

It is not:

```text
a packet-level DHCP replacement
for every EC2 instance.
```

Think:

```text
IPAM
=
network address governance.
```

---

# 38.603 Central DNS ownership

Networking works with IP addresses.

Applications work with names.

Enterprise example:

```text
database.payments.internal

api.orders.internal

ldap.corp.example.com
```

You need a deliberate:

# DNS architecture.

The modern multi-account AWS pattern commonly places centralized hybrid DNS components in a **Shared Services VPC/account**. AWS Prescriptive Guidance uses centralized Route 53 Resolver inbound/outbound endpoints in a Shared Services VPC for hybrid DNS across accounts. ([AWS Documentation][7])

---

# 38.604 Current terminology note

AWS now refers to the traditional VPC recursive DNS capability as:

# **Route 53 VPC Resolver**

The service was previously commonly called simply Route 53 Resolver; the VPC Resolver naming became explicit after Route 53 Global Resolver was introduced. ([AWS Documentation][8])

For the networking pattern we're discussing here:

```text
Route 53 VPC Resolver
```

is the key service.

---

# 38.605 DNS direction recap

Lesson 36 shortcut:

```text
INBOUND Resolver endpoint

On-Prem
   ↓
asks AWS DNS


OUTBOUND Resolver endpoint

AWS
   ↓
asks On-Prem DNS
```

That rule remains permanent. ([AWS Documentation][7])

---

# 38.606 AWS → on-prem DNS flow

Application:

```text
Payments EC2
```

queries:

```text
oracle.corp.example.com
```

Packet/query flow:

```text
Payments EC2
     │
     ▼
VPC Resolver
     │
     ▼
Resolver forwarding rule
corp.example.com
     │
     ▼
central outbound Resolver endpoint
Shared Services VPC
     │
     ▼
TGW / DX / VPN
     │
     ▼
On-Prem DNS
     │
     ▼
answer
```

AWS's centralized hybrid DNS guidance uses this exact pattern: workload VPC Resolver rules forward queries through shared outbound endpoints to on-premises DNS over hybrid connectivity. ([AWS Documentation][7])

---

# 38.607 On-prem → AWS DNS flow

On-prem host asks:

```text
db.payments.aws.example.com
```

Flow:

```text
On-Prem host
     │
     ▼
Corporate DNS
     │
 conditional forward
     ▼
Route 53 inbound
Resolver endpoint
     │
     ▼
AWS private namespace
     │
     ▼
answer
```

AWS recommends inbound endpoints in the central Shared Services VPC for this hybrid-resolution direction. ([AWS Documentation][7])

---

# 38.608 Private Hosted Zones

A Route 53 private hosted zone contains DNS records that resolve within associated VPCs.

Example:

```text
payments.internal

api.payments.internal
db.payments.internal
redis.payments.internal
```

A private hosted zone can be associated with one or more VPCs. ([AWS Documentation][9])

---

# 38.609 Centralized vs decentralized private DNS

### Centralized

Shared Services owns:

```text
payments.internal
orders.internal
corp.internal
```

Advantages:

```text
central standards
central visibility
```

Potential disadvantage:

```text
application DNS changes
become central-team tickets
```

---

### Delegated model

Each workload team owns:

```text
payments.aws.example.com

orders.aws.example.com
```

while central DNS owns:

```text
aws.example.com
```

and enterprise forwarding.

That can provide a healthier operating model in large organizations.

AWS's multi-account DNS guidance explicitly recognizes both centralized private hosted zones and workload-owned/delegated namespaces as viable patterns. ([AWS Documentation][7])

---

# 38.610 Route 53 Profiles

This is now extremely important.

Before Profiles, enterprise DNS management often required lots of individual:

```text
PHZ ↔ VPC associations

Resolver rule ↔ VPC associations

DNS Firewall ↔ VPC associations
```

For hundreds of VPCs:

```text
operational pain.
```

Route 53 Profiles let you package DNS-related configuration and associate/share it across many VPCs and AWS accounts in a Region. ([AWS Documentation][10])

---

# 38.611 What can a Route 53 Profile currently contain?

Current Route 53 documentation lists Profile-associated resources including:

```text
Private Hosted Zones

Resolver forwarding/system rules

DNS Firewall rule groups

Interface VPC endpoints

VPC Resolver query logging
configurations
```

and Profile-managed DNS settings including reverse-DNS, DNS Firewall failure mode, and DNSSEC validation settings. ([AWS Documentation][10])

This makes Profiles much broader than:

```text
"just shared DNS zones."
```

---

# 38.612 Profile mental model

```text
                 SHARED SERVICES

                Route 53 Profile
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼

   PHZ settings   Resolver rules   DNS Firewall

                       │
                     AWS RAM
                       │
         ┌─────────────┼────────────┐
         ▼             ▼            ▼
      Pay VPC       Orders VPC    Dev VPC
```

Update the Profile's DNS configuration and it propagates to associated VPCs. ([AWS Documentation][10])

---

# 38.613 Profiles reduce association sprawl

Without Profile:

```text
Rule A → VPC 1
Rule A → VPC 2
Rule A → VPC 3

Zone A → VPC 1
Zone A → VPC 2
Zone A → VPC 3

Firewall → VPC 1
Firewall → VPC 2
...
```

With Profile:

```text
DNS Profile
     │
     ├── Rule A
     ├── Zone A
     └── Firewall Group
           │
           ▼
         VPCs
```

AWS Prescriptive Guidance recommends Profiles as the enhanced approach to reduce operational overhead in large multi-account hybrid DNS deployments. ([AWS Documentation][7])

---

# 38.614 Profiles are Regional

Do not create:

```text
Route 53 Profile
ap-south-1
```

and assume it automatically governs Singapore VPCs.

Resolver endpoints, rules, and Profiles are Regional constructs and need corresponding regional designs for multi-Region organizations. ([AWS Documentation][7])

For our architecture:

```text
Mumbai Profile
ap-south-1

Singapore Profile
ap-southeast-1
```

may be required.

---

# 38.615 DNS Firewall

Route 53 DNS Firewall lets you filter DNS queries leaving VPC Resolver.

Examples:

```text
Allow company SaaS domains

Block known malware domains

Block suspicious DNS categories

Alert on blocked queries
```

DNS Firewall is part of Route 53 VPC Resolver and can also be centrally managed with AWS Firewall Manager. ([AWS Documentation][11])

---

# 38.616 DNS Firewall is not Network Firewall

Never confuse:

```text
DNS FIREWALL
=
DNS query control


NETWORK FIREWALL
=
IP/network traffic inspection
```

Blocking:

```text
evil.example.com
```

at DNS is different from blocking:

```text
203.0.113.50:443
```

at packet/flow level.

---

# 38.617 Centralized Internet egress

Now application VPCs need:

```text
apt updates

container registries

external APIs

SaaS
```

Bad enterprise model:

```text
100 VPCs

100 independent
Internet egress designs

100 arbitrary NAT configurations
```

Possible centralized pattern:

```text
WORKLOAD VPC
      │
      ▼
Transit Gateway
      │
      ▼
EGRESS / INSPECTION VPC
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

AWS documents centralized egress architectures combining Transit Gateway, NAT Gateway, and Network Firewall for outbound inspection. ([AWS Documentation][12])

---

# 38.618 Centralized egress packet flow

Suppose:

```text
Payments EC2
10.64.10.50

wants:
api.vendor.com
203.0.113.20
```

Flow:

```text
EC2
 │
 ▼
Payments route table

0.0.0.0/0
→ TGW
 │
 ▼
TGW
 │
 ▼
Inspection/Egress VPC
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
Vendor API
```

Return traffic must traverse a compatible reverse path.

---

# 38.619 Why centralized egress?

Benefits can include:

```text
central Internet policy

central firewall rules

fewer external IP ranges
for third-party allowlists

consistent logging

central domain/IP restrictions
```

But centralization also introduces:

```text
data-processing cost

cross-AZ considerations

TGW costs

network dependency

larger failure domain
```

So centralized egress is a design choice—not an automatic best answer for every workload.

---

# 38.620 Distributed egress is still valid

Alternative:

```text
Payments VPC
→ NAT Gateway
→ Internet

Orders VPC
→ NAT Gateway
→ Internet
```

Advantages:

```text
failure isolation
simpler local routing
potentially lower transit dependency
```

Trade-off:

```text
many NATs

many EIPs

distributed policy

many third-party allowlist IPs
```

Choose based on scale, security, reliability, and cost requirements.

---

# 38.621 AWS Network Firewall

Network Firewall provides managed network traffic filtering.

A classic centralized architecture uses:

```text
Transit Gateway
     │
     ▼
Inspection VPC
     │
     ▼
Network Firewall endpoints
```

AWS documentation still supports this centralized inspection-VPC model. ([AWS Documentation][13])

---

# 38.622 Inspection VPC pattern

```text
                    TGW

          ┌──────────┼─────────┐
          │          │         │
          ▼          ▼         ▼
       Pay VPC    Orders    Shared

                    │
                    ▼
             Inspection VPC

             ┌─────────────┐
             │ AWS Network │
             │  Firewall   │
             └─────────────┘
```

TGW route tables intentionally steer inspected flows through the Security/Inspection attachment.

---

# 38.623 Symmetric routing is critical

Stateful firewalls track flows.

Bad:

```text
REQUEST

Payments
  ↓
Firewall AZ-A
  ↓
Orders


RETURN

Orders
  ↓
Firewall AZ-B
  ↓
Payments
```

The second firewall path may not have the expected state.

AWS recommends symmetric routing for centralized Network Firewall designs and specifically calls for Transit Gateway appliance mode where appropriate so forward and return traffic remain on the appropriate firewall path. ([AWS Documentation][14])

---

# 38.624 Appliance Mode

Remember from Lesson 36:

```text
TGW Appliance Mode
```

helps maintain flow symmetry through stateful appliances in centralized inspection architectures.

Mental shortcut:

```text
STATEFUL INSPECTION
→ think SYMMETRY
→ think APPLIANCE MODE
```

AWS specifically documents TGW appliance mode as part of avoiding asymmetric routing with centralized Network Firewall. ([AWS Documentation][14])

---

# 38.625 Important modern update — TGW-attached Network Firewall

AWS now also supports a more direct integration:

# **Transit gateway-attached Network Firewall**

Instead of always building multiple firewall endpoints inside a conventional inspection VPC, Network Firewall can be provisioned directly as a Transit Gateway attachment. AWS describes this model as reducing the networking configuration required by the traditional firewall deployment. ([AWS Documentation][15])

---

# 38.626 New mental model

Traditional:

```text
TGW
 │
 ▼
Inspection VPC attachment
 │
 ▼
Firewall endpoint subnets
```

Modern alternative:

```text
TGW
 │
 ▼
Network Firewall
TGW attachment
```

Both patterns exist.

Do not assume an older AWS course showing only:

```text
Inspection VPC
```

covers every current design option.

---

# 38.627 Cross-account firewall ownership

Current Network Firewall + TGW integration supports:

```text
TGW owner
=
Network Account

Firewall owner
=
Security Account
```

or they can be the same account.

A firewall owner can create a transit-gateway-attached firewall against a TGW that has been shared with that account. ([AWS Documentation][15])

This creates a very interesting separation:

```text
NETWORK TEAM
owns transit


SECURITY TEAM
owns firewall
```

Exactly the enterprise governance model we want.

---

# 38.628 Architecture example

```text
Infrastructure OU
│
├── Network Account
│      └── Transit Gateway
│
└── Security Network Account
       └── Network Firewall
              │
              │ TGW-attached firewall
              ▼
            TGW
```

Then:

```text
network controls routing

security controls inspection rules
```

without requiring both teams to own the same account.

---

# 38.629 Firewall Manager

What if you have:

```text
300 VPCs
```

and need consistent firewall policy?

# AWS Firewall Manager

provides centralized policy administration for supported protection types across AWS Organizations.

For Network Firewall, Firewall Manager currently supports:

```text
Distributed

Centralized

Import existing firewalls
```

management models. ([AWS Documentation][16])

---

# 38.630 Distributed Firewall Manager model

```text
Organization
   │
   ▼
Firewall Manager
   │
   ├── VPC A → Network Firewall
   ├── VPC B → Network Firewall
   └── VPC C → Network Firewall
```

Each in-scope VPC receives its own firewall deployment according to policy. ([AWS Documentation][16])

Use when isolation/local inspection is more important than centralizing the actual firewall endpoints.

---

# 38.631 Centralized Firewall Manager model

```text
Organization
      │
      ▼
Firewall Manager
      │
      ▼
one centralized
Network Firewall
      │
      ▼
traffic from selected VPCs
```

Firewall Manager supports creating a centralized Network Firewall in one VPC for policy scope. ([AWS Documentation][16])

This aligns with central inspection architectures.

---

# 38.632 Firewall Manager administrator

Firewall Manager supports delegated administrative accounts, including multiple administrators with scoped administrative responsibility; one default administrator retains full scope. ([AWS Documentation][17])

A common pattern:

```text
Security Tooling Account
=
Firewall Manager admin
```

rather than using the Organizations management account for normal firewall operations.

---

# 38.633 Security vs networking ownership

A realistic ownership matrix:

| Component                    | Owner                          |
| ---------------------------- | ------------------------------ |
| Transit Gateway              | Network                        |
| DX/VPN                       | Network                        |
| IPAM                         | Network                        |
| Resolver infrastructure      | Shared Services / Network      |
| Network Firewall rules       | Security                       |
| Firewall routing integration | Network + Security             |
| Application SGs              | Application                    |
| DNS application records      | Application or Shared Services |
| Organization network policy  | Platform/Security              |

Enterprise architecture is partly technical and partly an ownership design.

---

# 38.634 Direct Connect ownership

Hybrid connectivity should normally have clear centralized ownership.

Concept:

```text
ON-PREM
   │
   ▼
Direct Connect
   │
   ▼
Direct Connect Gateway
   │
   ▼
Transit Gateway
   │
   ▼
AWS VPCs
```

AWS Direct Connect Gateway supports associations to Transit Gateways and can operate across account boundaries through the documented association-proposal model. ([AWS Documentation][18])

---

# 38.635 Transit VIF architecture

For a TGW-based DX design:

```text
Customer Router
      │
      ▼
DX Connection
      │
      ▼
Transit VIF
      │
      ▼
Direct Connect Gateway
      │
      ▼
Transit Gateway
      │
      ▼
VPCs
```

AWS documents transit virtual interfaces as the Direct Connect VIF type used to reach Transit Gateway through Direct Connect Gateway. ([AWS Documentation][19])

---

# 38.636 Cross-account DX gateway design

Possible:

```text
Network Account A
owns DX Gateway

Network Account B
owns TGW
```

Association proposal:

```text
TGW owner
     │
     ▼
association proposal
     │
     ▼
DXGW owner accepts
```

AWS supports DX Gateway and Transit Gateway association across AWS accounts. ([AWS Documentation][18])

This can be useful when corporate connectivity and cloud transit have different ownership boundaries.

---

# 38.637 VPN ownership nuance

For a shared Transit Gateway, AWS currently requires a Site-to-Site VPN attachment to be created in the **same AWS account that owns the Transit Gateway**. ([AWS Documentation][3])

So if:

```text
Network Account
owns TGW
```

then:

```text
Network Account
```

also owns the TGW-attached Site-to-Site VPN.

That makes the Network account an even more natural hybrid-edge owner.

---

# 38.638 Hybrid enterprise architecture

```text
                  DATA CENTER

                 ┌──────┴──────┐
                 ▼             ▼
                DX             VPN
                 │             │
                 └──────┬──────┘
                        ▼
                  NETWORK ACCOUNT

                       TGW
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼

      Prod VPC      Shared Services   Dev VPC
```

Lesson 36 taught the protocols.

Lesson 38 teaches the ownership.

---

# 38.639 Direct Connect + VPN

Remember:

```text
DX
≠
automatic encryption
```

and:

```text
DX
≠
complete redundancy
```

Production architectures often combine independent DX paths and/or VPN backup depending on availability/encryption requirements.

The governance implication is:

```text
Network Account
must own the complete
hybrid connectivity strategy
```

rather than each workload inventing its own.

---

# 38.640 Customer-managed prefix lists

Another useful central resource is:

# Prefix List

Example:

```text
Corporate networks:

10.10.0.0/16
10.11.0.0/16
172.20.0.0/16
```

Central Network account can maintain:

```text
corp-networks
```

and share the prefix list through RAM to workload accounts. AWS supports sharing customer-managed prefix lists with individual accounts, OUs, or the organization. ([AWS Documentation][20])

Then application SG:

```text
HTTPS from:
corp-networks
```

instead of copying 40 CIDRs into every SG.

---

# 38.641 Prefix-list benefit

Without:

```text
SG-A:
10.10/16
10.11/16
10.12/16

SG-B:
10.10/16
10.11/16
10.12/16

SG-C:
...
```

With:

```text
Shared Prefix List:
pl-corporate

   │
   ├── SG-A
   ├── SG-B
   └── route table
```

One central update can propagate through references.

---

# 38.642 VPC sharing

Now another architecture pattern:

Instead of:

```text
one VPC
per account
```

AWS supports sharing subnets of a centrally owned VPC to other accounts in the same Organizations organization.

Participant accounts can then deploy supported application resources into those shared subnets. ([AWS Documentation][21])

Architecture:

```text
NETWORK ACCOUNT

VPC
│
├── Shared Subnet A ───► Payments Account
├── Shared Subnet B ───► Orders Account
└── Shared Subnet C ───► Analytics Account
```

---

# 38.643 Shared VPC ownership split

### VPC owner controls:

```text
VPC

subnets

route tables

NACLs

IGW

NAT Gateway

VPC endpoints

Resolver endpoints

TGW attachments
```

### Participant controls:

```text
its application resources

its ENIs

its security groups
```

within supported shared-subnet rules. ([AWS Documentation][22])

This is a very strong centralized-network-control model.

---

# 38.644 Participant can't modify routes

If Payments deploys EC2 into a shared subnet, Payments cannot go modify that subnet's route table.

Only the VPC owner controls the route table. ([AWS Documentation][22])

That gives:

```text
Network Team
=
routing authority


Payments
=
application authority
```

Strong separation.

---

# 38.645 Participant can own SGs

A participant can create and manage security groups that it owns in the shared VPC and can use shared owner security groups when those groups have themselves been shared appropriately. ([AWS Documentation][22])

So:

```text
Network
does not necessarily have to
manage every application SG.
```

Again:

```text
central routing
+
decentralized app security
```

can coexist.

---

# 38.646 Shared VPC is not always superior

Choose shared VPC when workloads:

```text
share trust boundaries

need high interconnectivity

benefit from centralized network lifecycle
```

AWS documentation highlights shared VPCs particularly for applications with close interconnectivity and similar trust boundaries. ([AWS Documentation][21])

Do not put:

```text
untrusted Dev

PCI production

third-party vendor workload
```

into the same shared VPC merely to save VPCs.

---

# 38.647 Separate VPCs + TGW vs Shared VPC

| Model                | Isolation                 | Network ownership | Complexity          |
| -------------------- | ------------------------- | ----------------- | ------------------- |
| Separate VPC/account | Stronger network boundary | Mixed             | More transit        |
| Shared VPC/subnets   | Shared network boundary   | Centralized       | Fewer VPCs          |
| Hybrid               | Depends                   | Flexible          | Often best at scale |

No universal winner.

---

# 38.648 PrivateLink

Sometimes application A only needs:

```text
one service
```

from application B.

Don't automatically create full:

```text
VPC ↔ TGW ↔ VPC
```

routing.

Consider:

# AWS PrivateLink

for service-oriented private connectivity.

Mental model:

```text
Service Provider
      │
      ▼
Endpoint Service
      │
      ▼
Interface Endpoint
      │
      ▼
Consumer VPC
```

This reduces broad network reachability when only one application service needs exposure.

---

# 38.649 Connectivity choice

Ask:

```text
Need broad routed network connectivity?
→ TGW


Need access to one service?
→ PrivateLink


Need same VPC trust boundary?
→ VPC sharing may fit


Need two simple VPCs only?
→ Peering may still fit
```

Don't use Transit Gateway for every private connection simply because it's enterprise-grade.

---

# 38.650 Interface VPC endpoints

Workloads frequently need AWS services such as:

```text
Secrets Manager

ECR APIs

CloudWatch Logs

SSM

KMS
```

without sending traffic through Internet egress.

Interface VPC endpoints can provide private VPC access to supported services through AWS PrivateLink.

At enterprise scale, decide:

```text
per-VPC endpoints

vs

centralized endpoint strategy
```

carefully.

---

# 38.651 Endpoint centralization trade-off

Central endpoint VPC:

```text
Workload
   │
   ▼
TGW
   │
   ▼
Shared Endpoint VPC
   │
   ▼
Interface Endpoint
```

Possible benefits:

```text
fewer endpoints

central policy

central DNS
```

Possible problems:

```text
transit costs

cross-AZ traffic

DNS complexity

central failure dependency
```

Sometimes distributed endpoints in each workload VPC are cleaner.

---

# 38.652 Route 53 Profiles + interface endpoints

A notable current Route 53 Profiles capability is associating **interface VPC endpoints** with a Profile alongside DNS resources. ([AWS Documentation][10])

That gives platform teams another tool for scaling consistent private-service DNS/endpoint configuration across VPCs.

---

# 38.653 Centralized DNS query logging

Profiles can also include VPC Resolver query logging configurations. ([AWS Documentation][10])

Architecture:

```text
Workload VPCs
     │
     ▼
Route 53 Profile
     │
     ▼
central query logging config
     │
     ▼
security/logging destination
```

This connects Part 6 directly to Part 5's central security architecture.

---

# 38.654 DNS as a security layer

Queries such as:

```text
malware-control.example

strange-exfil-domain.example
```

may be visible through DNS query logs.

Security can combine:

```text
Resolver Query Logs
+
DNS Firewall
+
GuardDuty/Security Lake
```

to understand suspicious domain behavior.

Network and security architecture should not be developed independently.

---

# 38.655 Multi-Region network architecture

Now apply this to:

```text
Mumbai
+
Singapore
```

A strong model:

```text
                  GLOBAL ORGANIZATION

             ┌─────────────┴─────────────┐
             ▼                           ▼

       ap-south-1                  ap-southeast-1

        TGW Mumbai                  TGW Singapore
             │                           │
        Network VPCs                 Network VPCs
             │                           │
        Resolver                    Resolver
             │                           │
        Firewall                    Firewall
```

Transit Gateways are Regional resources, so multi-Region designs typically use a TGW in each Region and connect them where inter-Region transit is required. ([AWS Documentation][23])

---

# 38.656 TGW peering

Regional TGWs can be interconnected:

```text
Mumbai TGW
    │
    │ TGW peering
    ▼
Singapore TGW
```

Then VPC-to-VPC traffic across Regions can traverse the peering attachment when both sides' transit route tables and VPC route tables are configured appropriately.

---

# 38.657 Don't use one Region as the network dependency for another

Bad:

```text
Singapore DR VPC
      │
      ▼
Mumbai DNS
      │
      ▼
Mumbai firewall
      │
      ▼
Internet
```

Then Mumbai fails.

Singapore:

```text
application compute ✓

network dependencies ✕
```

Regional DR should minimize hidden dependency on the failed Region.

---

# 38.658 Region-local network dependencies

For each recovery Region ask:

```text
Does Region B have:

TGW?                ✓
DNS Resolver?       ✓
Firewall?           ✓
NAT/egress?         ✓
DX/VPN path?        ✓
IP address plan?    ✓
logging?            ✓
private endpoints?  ✓
```

This is exactly the Region-isolation principle from Lesson 37 applied to networking.

---

# 38.659 Multi-Region Route 53 Profiles

Because Resolver/Profile constructs are Regional:

```text
Mumbai DNS Profile
```

does not replace:

```text
Singapore DNS Profile.
```

AWS explicitly notes Resolver endpoints, rules, and Profiles may need deployment in multiple Regions for global organizations. ([AWS Documentation][7])

Use IaC to maintain equivalent configuration where required.

---

# 38.660 Multi-Region IPAM

IPAM can be the enterprise source of address governance, with pools broken down regionally.

Example:

```text
Private:
10.0.0.0/8

├── Mumbai
│     10.64.0.0/10
│
└── Singapore
      10.128.0.0/10
```

Now regional VPC creation remains globally non-overlapping.

That becomes especially important when Regions are later connected.

---

# 38.661 Network quotas are architecture dependencies

A 100-account network can encounter limits involving:

```text
TGW attachments

TGW routes

Resolver endpoints

Resolver rules

Profile associations

NAT

VPC endpoints

security groups
```

Do not wait for production expansion to discover a hard service quota.

AWS's multi-account DNS guidance explicitly notes Resolver/Profile/private-zone quotas as design considerations at scale. ([AWS Documentation][7])

---

# 38.662 Network ownership matrix

A useful enterprise artifact:

| Resource               | Owner                   | Consumers       |
| ---------------------- | ----------------------- | --------------- |
| IPAM                   | Network                 | All accounts    |
| TGW                    | Network                 | Workload VPCs   |
| DX/VPN                 | Network                 | Organization    |
| DNS Resolver endpoints | Shared Services/Network | All VPCs        |
| Route 53 Profiles      | Shared Services         | All VPCs        |
| Network Firewall       | Security                | Network transit |
| NAT/egress             | Network                 | Workloads       |
| App SGs                | App teams               | Application     |
| PHZ subdomains         | App teams / DNS team    | Apps            |
| VPC endpoints          | Network or workload     | Applications    |

Write this down.

Ownership ambiguity causes outages.

---

# 38.663 SCP network guardrails

Organizations can protect the network architecture.

Conceptually block workload admins from actions such as:

```text
creating arbitrary Internet gateways

modifying central networking

deleting Flow Logs

creating unapproved TGWs

changing shared network controls
```

depending on your operating model.

Do not simply deny:

```text
ec2:*
```

because the application team still needs EC2/VPC APIs for normal workload resources.

Guardrails need precision.

---

# 38.664 Protect central network accounts differently

Network OU might have:

```text
NetworkAdmins
```

capable of:

```text
TGW

DX

VPN

IPAM
```

while workload OUs receive SCP restrictions preventing local creation of competing enterprise transit infrastructure.

The goal:

```text
one clear enterprise topology
```

rather than shadow network backbones.

---

# 38.665 Network automation pipeline

A scalable model:

```text
Application Terraform
      │
      ▼
VPC created from IPAM
      │
      ▼
TGW attachment requested
      │
      ▼
Network pipeline
      │
      ├── validate CIDR
      ├── identify OU
      ├── assign TGW route table
      ├── enable propagation
      ├── attach DNS Profile
      ├── attach logging
      └── validate connectivity
```

This creates:

```text
self-service
+
central governance.
```

---

# 38.666 Network vending

Similar to Account Factory, think:

```text
ACCOUNT VENDING

and

NETWORK VENDING
```

New application requests:

```text
Prod VPC
Mumbai
size /20
needs Shared Services
needs Internet egress
no Dev connectivity
```

Automation produces:

```text
IPAM allocation

VPC

subnets

TGW attachment

routing

DNS

logging

baseline SG/NACL settings
```

Now networking becomes a platform product.

---

# 38.667 Shared Services is also a platform product

Instead of:

```text
"Send the DNS team a ticket."
```

developers consume:

```text
DNS profile

certificate service

directory integration

private endpoint catalog

internal service discovery
```

through reusable modules/APIs.

This is where infrastructure architecture turns into platform engineering.

---

# 38.668 Central network observability

At minimum observe:

```text
TGW attachment state

VPN tunnel state

BGP state

DX virtual interfaces

NAT traffic

Firewall drops

Flow Logs

Resolver query failures

DNS Firewall blocks

IPAM utilization
```

A central network without central telemetry is difficult to operate.

---

# 38.669 Packet troubleshooting in a multi-account environment

When Payments cannot reach Orders:

```text
1. DNS resolves?

2. Source SG allows?

3. Source subnet route?

4. TGW attachment healthy?

5. Correct TGW route-table association?

6. Correct route propagation/static route?

7. Inspection path?

8. Firewall permits?

9. Destination VPC route?

10. Destination SG/NACL?

11. Return route?

12. Is traffic crossing accounts/Regions
    as intended?
```

This is still:

# **Resolve → Route → Transit → Inspect → Deliver → Return**

from Lesson 36.

---

# 38.670 Multi-account changes who you ask

Example failure:

```text
Payments EC2
cannot reach
Orders API
```

The issue may belong to:

```text
Payments Team
source SG


Network Team
TGW


Security Team
Firewall


Orders Team
destination SG
```

So observability should help identify the failing ownership domain quickly.

---

# 38.671 TGW troubleshooting

Check:

```text
WORKLOAD ACCOUNT

VPC route:
destination → TGW

attachment:
available
```

Then:

```text
NETWORK ACCOUNT

TGW route-table association

propagation

specific route

blackhole
```

A participant cannot fix TGW route-table associations itself because those are owner-controlled. ([AWS Documentation][3])

That tells you when to escalate to the network platform team.

---

# 38.672 Shared VPC troubleshooting

If participant EC2 cannot reach Internet:

Do **not** ask the participant to:

```text
modify NAT Gateway
```

because participant accounts cannot manage NAT gateways, subnet route tables, IGWs, or NACLs in the owner-managed shared VPC. ([AWS Documentation][22])

Instead:

```text
Participant checks:
instance
SG
ENI


VPC owner checks:
route table
NAT
IGW
NACL
```

Ownership-aware troubleshooting saves enormous time.

---

# 38.673 DNS troubleshooting

For:

```text
db.corp.example.com
```

failing:

```text
1. What VPC?

2. Which Resolver Profile/rule?

3. Is rule associated?

4. Is outbound endpoint healthy?

5. SG allows DNS?

6. TGW/DX/VPN route?

7. On-prem DNS reachable?

8. Conditional forwarder correct?

9. Return path?

10. DNS loop?
```

AWS explicitly warns against Resolver forwarding configurations that create recursive DNS loops. ([AWS Documentation][7])

---

# 38.674 Firewall troubleshooting

If:

```text
routing looks correct
but connection times out
```

check:

```text
Was traffic actually routed
through correct firewall?

Forward path firewall endpoint?

Return path same stateful path?

Network Firewall logs?

Correct HOME_NET?

Rule group priority?

Stateless action?

Stateful rule?
```

AWS calls out routing symmetry and HOME_NET considerations specifically for centralized Network Firewall deployments. ([AWS Documentation][14])

---

# 38.675 Centralized egress troubleshooting

Application cannot reach Internet:

```text
App SG
  ↓
VPC default route
  ↓
TGW
  ↓
TGW egress route
  ↓
inspection
  ↓
firewall rule
  ↓
NAT Gateway
  ↓
IGW
  ↓
Internet
```

Then reverse.

Do not jump straight to:

```text
DNS is broken.
```

Walk the packet.

---

# 38.676 Architecture scenario — 5 accounts

Requirement:

```text
5 AWS accounts

minimal hybrid needs

small team
```

Don't automatically deploy:

```text
TGW

central firewall

IPAM delegation

three network accounts

Cloud WAN
```

A simpler:

```text
VPC peering

local NAT

basic Resolver
```

architecture might be sufficient.

Enterprise patterns should solve enterprise problems.

---

# 38.677 Scenario — 150 accounts

Requirement:

```text
150 accounts

hybrid network

strong segmentation

shared DNS

standard IP allocation
```

Strong candidates:

```text
Network Account

TGW

RAM

IPAM

central Resolver/Profile architecture

shared prefix lists

central inspection
```

This is the scale where central network governance becomes especially valuable.

---

# 38.678 Scenario — workloads need one shared API

Requirement:

```text
Payments needs Fraud API

No general network access
between accounts
```

Evaluate:

```text
PrivateLink
```

rather than giving Payments a fully routed path to the entire Fraud VPC.

Least connectivity can be as important as least privilege.

---

# 38.679 Scenario — strict shared network control

Requirement:

```text
Network team must own:

routes
NAT
subnets
NACLs

Application accounts should own:
EC2/RDS/Lambda
```

Evaluate:

# VPC subnet sharing.

AWS's owner/participant model maps almost directly onto this requirement. ([AWS Documentation][22])

---

# 38.680 Scenario — centralized stateful inspection

Requirement:

```text
all Prod ↔ Internet
and
Prod ↔ On-Prem

must pass central firewall
```

Evaluate:

```text
TGW
+
central Network Firewall
+
symmetric route design
```

using either the traditional inspection-VPC design or the newer TGW-attached Network Firewall architecture depending on requirements. ([AWS Documentation][24])

---

# 38.681 Scenario — security team owns firewall, network owns TGW

This is now a first-class design option:

```text
NETWORK ACCOUNT
TGW

       │ RAM
       ▼

SECURITY ACCOUNT
TGW-attached Network Firewall
```

AWS explicitly allows TGW and firewall ownership to be in separate accounts. ([AWS Documentation][15])

---

# 38.682 Scenario — standardized hybrid DNS

Requirement:

```text
All AWS accounts
resolve:

*.corp.example.com

All on-prem users
resolve:

*.aws.example.com
```

Strong pattern:

```text
Shared Services VPC
  ├── inbound Resolver
  ├── outbound Resolver
  ├── Resolver rules
  ├── private zones
  └── Route 53 Profiles

RAM
  ↓
workload VPCs
```

AWS documents this exact centralized hybrid multi-account DNS pattern. ([AWS Documentation][7])

---

# 38.683 TGW vs Cloud WAN preview

At very large global scale you may also evaluate:

# AWS Cloud WAN

Mental difference:

```text
Transit Gateway

Regional transit hub


Cloud WAN

global policy-driven
WAN/core-network architecture
```

Cloud WAN can also be shared through RAM and can integrate VPC, Transit Gateway route-table, and Direct Connect Gateway attachments depending on architecture. ([AWS Documentation][25])

For most current lessons we'll keep TGW as our primary mental model.

---

# 38.684 Do not choose Cloud WAN because "global sounds better"

Use it where you actually need:

```text
global network policy

multiple Regions

branches

large-scale segment policy

centrally orchestrated global WAN
```

For a few VPCs in one Region:

```text
TGW
```

may be substantially simpler.

---

# 38.685 Network account anti-patterns

Avoid:

```text
1. Every application creates its own TGW.

2. Every VPC invents its own CIDR.

3. Network team manages every app SG manually.

4. One shared VPC contains unrelated trust zones.

5. Dev and Prod routes leak automatically.

6. Central firewall has asymmetric paths.

7. DR Region depends on primary-Region DNS.

8. DX exists but VPN backup never tested.

9. All workload Internet egress bypasses controls.

10. Shared DNS rules create loops.

11. IPAM exists but teams still hard-code CIDRs.

12. RAM sharing exists but no IAM permission.

13. PrivateLink use case gets full routed connectivity.

14. Network account runs business applications.

15. One giant route table connects everything.
```

Those are excellent architecture-review red flags.

---

# 38.686 Network account should contain network resources

Avoid:

```text
NETWORK ACCOUNT

TGW
DX
VPN

Payments database
Jenkins
customer application
random EC2
```

Keep the ownership boundary clear.

Infrastructure accounts are most valuable when they have a narrow mission.

---

# 38.687 Shared Services should not become "miscellaneous account"

A Shared Services account can easily degrade into:

```text
DNS

AD

Jenkins

random database

one forgotten FTP server

legacy app

developer test machine
```

Then it becomes a high-risk dependency.

Maintain:

```text
service catalog

owners

SLOs

patching

backup

lifecycle
```

for anything considered shared infrastructure.

---

# 38.688 Central services need higher reliability

If 150 accounts depend on:

```text
central Resolver endpoints
```

their failure has a much larger blast radius than one application's local DNS component.

So central services require:

```text
Multi-AZ

capacity planning

monitoring

DR design

change control

testing
```

Centralization increases importance as well as efficiency.

---

# 38.689 Resolver endpoint availability

AWS recommends creating inbound Resolver endpoint IP addresses across at least two Availability Zones for high availability and adding capacity where query volume requires it. ([AWS Documentation][7])

Do not build:

```text
central enterprise DNS

one endpoint ENI
one AZ
```

and call the architecture resilient.

---

# 38.690 DNS and network are separate planes

AWS Prescriptive Guidance makes an important point: DNS resolution between VPCs can be configured separately from the Layer-3 application connectivity between those VPCs. ([AWS Documentation][7])

So:

```text
DNS resolves ✓
```

does not prove:

```text
TCP connection works ✓
```

and:

```text
TGW route exists ✓
```

does not prove:

```text
DNS resolves ✓.
```

Always troubleshoot both planes.

---

# 38.691 Enterprise packet-flow mental model

Now combine all layers:

```text
APPLICATION
    │
    ▼
DNS NAME
    │
    ▼
Route 53 VPC Resolver / Profile
    │
    ▼
DESTINATION IP
    │
    ▼
Source SG
    │
    ▼
VPC Route Table
    │
    ▼
TGW Attachment
    │
    ▼
TGW Route Table
    │
    ▼
Inspection
    │
    ▼
Network Firewall
    │
    ▼
Destination Attachment
    │
    ▼
Destination VPC Route
    │
    ▼
Destination SG
    │
    ▼
APPLICATION
    │
    ▼
RETURN PATH
```

That is the enterprise networking version of everything we learned in Lesson 36.

---

# 38.692 Enterprise ownership-flow mental model

Overlay accounts:

```text
APP TEAM
  DNS request
       │
       ▼
SHARED SERVICES
  enterprise DNS
       │
       ▼
APP TEAM
  source VPC
       │
       ▼
NETWORK TEAM
  TGW
       │
       ▼
SECURITY TEAM
  inspection
       │
       ▼
NETWORK TEAM
  destination transit
       │
       ▼
DESTINATION APP TEAM
  application
```

Many production network incidents cross organizational boundaries.

---

# 38.693 Senior interview — Why central Network account?

Strong answer:

> **I use a dedicated Network account when enterprise scale requires centralized ownership of shared connectivity such as Transit Gateway, IPAM, Direct Connect, VPN, enterprise DNS infrastructure, centralized egress, and inspection. Workload accounts retain application ownership, while RAM enables them to consume shared network resources. This provides a clear blast-radius and ownership boundary without forcing the network team to manage every application resource.**

AWS supports the underlying TGW, IPAM, Resolver/Profile, subnet, and prefix-list resource-sharing models through Organizations and RAM. ([AWS Documentation][3])

---

# 38.694 Interview — TGW owner vs participant

Answer:

```text
TGW owner:
manages TGW
route tables
associations
propagations


Participant:
can consume shared TGW
and create VPC attachments
for its VPCs
```

Participant accounts cannot modify the shared TGW's transit route tables. ([AWS Documentation][3])

---

# 38.695 Interview — RAM

> **AWS Resource Access Manager lets resource owners share supported AWS resources with other accounts, OUs, or an organization while retaining centralized ownership. When Organizations sharing is enabled, in-organization sharing can occur without per-account invitation acceptance.**

([AWS Documentation][4])

---

# 38.696 Interview — IPAM

> **VPC IPAM centralizes IP address planning, allocation, utilization monitoring, and organization-wide discovery. An Organizations member account can be delegated as IPAM administrator and share IPAM pools to workload accounts through RAM.**

([AWS Documentation][6])

---

# 38.697 Interview — inbound vs outbound Resolver

```text
INBOUND

On-Prem
→ AWS DNS


OUTBOUND

AWS
→ On-Prem DNS
```

([AWS Documentation][7])

Never reverse these.

---

# 38.698 Interview — Route 53 Profile

> **A Route 53 Profile packages DNS-related configuration such as private hosted zones, Resolver rules, DNS Firewall groups, interface endpoints, and query-logging configuration so the configuration can be associated and shared across multiple VPCs/accounts in a Region.**

([AWS Documentation][10])

---

# 38.699 Interview — Network Firewall vs DNS Firewall

```text
Network Firewall
=
packet/flow inspection


DNS Firewall
=
DNS-query filtering
```

DNS Firewall is a Route 53 VPC Resolver capability, whereas AWS Network Firewall handles broader network traffic filtering. ([AWS Documentation][11])

---

# 38.700 Interview — Firewall Manager

> **AWS Firewall Manager provides organization-wide policy management for supported security controls. For Network Firewall, it can centrally manage distributed firewalls, a centralized firewall deployment, or imported existing firewalls across in-scope organization VPCs/accounts.**

([AWS Documentation][16])

---

# 38.701 Interview — VPC sharing

Strong answer:

> **VPC sharing allows a VPC owner to share subnets with participant accounts in the same AWS Organization. The owner retains control of VPC network resources such as subnets, route tables, NACLs, NAT, IGWs and TGW attachments, while participants deploy their own supported application resources and can manage resources such as their own security groups and ENIs.**

([AWS Documentation][22])

---

# 38.702 Interview trap — shared TGW lets participant modify TGW routing

# Wrong.

Participant may create VPC attachments, but Transit Gateway route tables and their associations/propagations remain owner-controlled. ([AWS Documentation][3])

---

# 38.703 Interview trap — RAM gives IAM permission

# Wrong.

RAM makes the shared resource available to the consumer.

The consuming account still needs to grant its own IAM principals permission to use the shared resource APIs. ([AWS Documentation][5])

---

# 38.704 Interview trap — IPAM automatically routes networks

Wrong.

IPAM solves:

```text
address governance.
```

TGW/VPC route tables solve:

```text
packet routing.
```

---

# 38.705 Interview trap — Route 53 Profile is global

Wrong.

Route 53 Profiles and the Resolver architecture around them are Regional; multi-Region environments must design corresponding Regional DNS configuration. ([AWS Documentation][7])

---

# 38.706 Interview trap — inbound Resolver means AWS → on-prem

Wrong.

```text
Inbound
=
queries enter AWS


Outbound
=
queries leave AWS
toward another DNS system
```

([AWS Documentation][7])

---

# 38.707 Interview trap — central egress is always cheaper

Wrong.

Centralized egress may improve policy/visibility but introduces TGW and traffic-processing paths and can create different cost and resiliency trade-offs.

Cost must be modeled from actual traffic patterns.

---

# 38.708 Interview trap — inspection VPC is the only modern Network Firewall design

Outdated.

AWS now also supports transit-gateway-attached Network Firewall, including cross-account TGW/firewall ownership. ([AWS Documentation][15])

---

# 38.709 Interview trap — VPC participant can change route table

Wrong.

In VPC subnet sharing, the owner controls route tables; participants can describe but cannot modify them. ([AWS Documentation][22])

---

# 38.710 Interview trap — shared VPC means shared IAM/resources

No.

Participant resources remain owned by their respective accounts, and participants cannot generally modify another participant's resources merely because they use the same shared VPC. ([AWS Documentation][21])

---

# 38.711 Interview trap — one central DNS endpoint for all Regions

Risky/wrong assumption.

Route 53 Resolver endpoints, rules, and Profiles are Regional and may require equivalent deployment in multiple Regions. ([AWS Documentation][7])

---

# 38.712 The enterprise Network Account build order

For a new organization:

```text
1. Design account ownership.

2. Design global IP plan.

3. Delegate IPAM.

4. Build Regional network accounts/
   Regional networking.

5. Create TGW.

6. Create TGW routing domains.

7. Enable RAM Organizations sharing.

8. Share TGW/IPAM/prefix lists.

9. Build hybrid DX/VPN.

10. Build central DNS.

11. Create Route 53 Profiles.

12. Build inspection.

13. Build egress.

14. Enable logging.

15. Apply organization guardrails.

16. Onboard pilot workload VPC.

17. Validate packet and DNS paths.

18. Automate onboarding.

19. Test failure scenarios.

20. Expand to organization.
```

That order reduces the chance that 100 workload accounts appear before the enterprise network model exists.

---

# 38.713 Brownfield migration

Existing environment:

```text
50 VPCs

random CIDRs

many peerings

local DNS rules

local NATs

multiple VPNs
```

Do not immediately rip everything out.

Use:

```text
Inventory
   ↓
CIDR analysis
   ↓
IPAM discovery
   ↓
identify overlaps
   ↓
build transit
   ↓
migrate VPCs in waves
   ↓
centralize DNS
   ↓
centralize hybrid connectivity
   ↓
inspection where required
   ↓
remove old peerings
```

Brownfield network transformation is usually incremental.

---

# 38.714 The complete enterprise architecture

```text
                          AWS ORGANIZATION

                                ROOT
                                 │
                      Infrastructure OU
                                 │
        ┌────────────────────────┼──────────────────────┐
        ▼                        ▼                      ▼

   NETWORK ACCOUNT        SHARED SERVICES          PLATFORM
        │                        │
        │                        ├── Route 53 Profiles
        │                        ├── VPC Resolver
        │                        ├── Private DNS
        │                        ├── AD
        │                        └── Shared endpoints
        │
        ├── IPAM
        │
        ├── TGW
        │
        ├── DX
        │
        ├── VPN
        │
        ├── Egress
        │
        └── Routing
             │
             │ AWS RAM
             ▼
      ┌───────────────┐
      │ Workload OUs  │
      └───────┬───────┘
              │
    ┌─────────┼────────────┐
    ▼         ▼            ▼

Payments   Orders      Analytics
  VPC        VPC          VPC
    │         │            │
    └─────────┼────────────┘
              ▼
             TGW
              │
              ▼
         INSPECTION
              │
       Network Firewall
              │
          ┌───┴────┐
          ▼        ▼
       On-Prem   Internet
```

Now overlay Security:

```text
Security Tooling
      │
      ├── Firewall Manager
      ├── GuardDuty
      ├── Flow analysis
      └── security policy
```

That is a real enterprise AWS network operating model.

---

# 38.715 Ten ownership questions for architecture reviews

Ask:

```text
1. Who owns CIDRs?

2. Who owns TGW?

3. Who controls TGW routes?

4. Who owns hybrid connectivity?

5. Who controls outbound Internet?

6. Who owns DNS forwarding?

7. Who owns private namespaces?

8. Who owns inspection rules?

9. Who owns workload SGs?

10. Who responds when connectivity fails?
```

If the answers are unclear:

```text
the network design is incomplete.
```

---

# 38.716 Twenty never-forget Part 6 rules

```text
1.
Network Account
owns enterprise connectivity,
not business applications.


2.
Shared Services
owns reusable internal services,
not random workloads.


3.
TGW is a Regional transit hub.


4.
Share TGW through RAM;
don't duplicate transit everywhere.


5.
Participant accounts can attach VPCs;
TGW owner controls transit routing.


6.
RAM shares resources;
it does not replace IAM.


7.
IPAM prevents address chaos.


8.
Delegate IPAM to a member
network account, not management.


9.
Use RAM to share IPAM pools.


10.
Inbound Resolver:
On-Prem asks AWS.


11.
Outbound Resolver:
AWS asks On-Prem.


12.
Route 53 Profiles scale
multi-VPC DNS configuration.


13.
Profiles are Regional.


14.
DNS resolution and Layer-3
connectivity are different planes.


15.
Central egress is a trade-off,
not automatically superior.


16.
Stateful inspection requires
symmetric routing.


17.
TGW appliance mode matters
for traditional stateful
inspection architecture.


18.
Network Firewall can now also
attach directly to TGW.


19.
VPC sharing centralizes
network ownership while preserving
separate application accounts.


20.
DR Region needs local networking,
DNS, inspection and egress—
not hidden dependency on primary.
```

---

# 38.717 Part 6 checkpoint

You can now explain:

```text
✓ Network Account architecture

✓ Shared Services Account

✓ centralized vs decentralized ownership

✓ TGW sharing

✓ TGW owner vs participant

✓ AWS RAM

✓ Organizations sharing

✓ IPAM delegated admin

✓ IPAM pools

✓ enterprise CIDR allocation

✓ Route 53 VPC Resolver

✓ inbound endpoints

✓ outbound endpoints

✓ hybrid DNS

✓ private hosted zones

✓ Route 53 Profiles

✓ DNS Firewall

✓ Resolver query logging

✓ centralized Internet egress

✓ distributed egress trade-offs

✓ Network Firewall

✓ inspection VPC

✓ symmetric routing

✓ appliance mode

✓ TGW-attached Network Firewall

✓ Firewall Manager

✓ Direct Connect Gateway

✓ Transit VIF

✓ Site-to-Site VPN ownership

✓ shared prefix lists

✓ VPC subnet sharing

✓ VPC owner/participant boundaries

✓ PrivateLink decision pattern

✓ interface endpoints

✓ Multi-Region network design

✓ TGW peering

✓ network DR independence

✓ network onboarding automation

✓ ownership-aware troubleshooting
```

---

# ✅ Lesson 38 — Part 6 Complete

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
Account Factory + AFT                   NEXT

Part 8
Delegated Administration

Part 9
Terraform Governance Capstone

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 7

## Account Factory + AFT — Production Account Vending with Terraform

Now we'll turn the landing zone into a **self-service platform**.

Instead of:

```text
Developer:

"Please create an AWS account."


Platform Team:

opens console
creates account
creates IAM
creates VPC
enables security
configures logging
configures TGW
configures DNS
...
```

we'll build:

```text
                    GIT PULL REQUEST

                         account request
                               │
                               ▼
                     ACCOUNT FACTORY
                               │
                               ▼
                            AFT
                  Account Factory for Terraform
                               │
         ┌─────────────────────┼────────────────────┐
         ▼                     ▼                    ▼

   Create Account        Global Baseline      Account Customization
         │                     │                    │
         ▼                     ▼                    ▼

      Control Tower          Security             Network
      Enrollment             Logging              TGW/IPAM
         │                   Identity              DNS
         └─────────────────────┼────────────────────┘
                               ▼

                       GOVERNED AWS ACCOUNT
                               │
                               ▼
                        READY FOR TEAM
```

We'll cover **Account Factory vs AFT, account request repositories, AFT management account, Terraform pipelines, global customizations, account-specific customizations, Control Tower enrollment, IAM Identity Center assignments, IPAM/TGW/DNS onboarding, security service enrollment, GitOps-style account creation, account metadata, OU placement, tagging, failure handling, update lifecycle, account closure/decommissioning, and a complete `payments-prod` account vending walkthrough**.

[1]: https://docs.aws.amazon.com/ram/latest/userguide/shareable.html?utm_source=chatgpt.com "Shareable AWS resources - AWS Resource Access Manager"
[2]: https://docs.aws.amazon.com/vpc/latest/userguide/extend-tgw.html?utm_source=chatgpt.com "Connect your VPC to other VPCs and networks using a ..."
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/working-with-transit-gateways.html "Work with AWS Transit Gateway - Amazon VPC"
[4]: https://docs.aws.amazon.com/ram/latest/userguide/getting-started-sharing.html?utm_source=chatgpt.com "Sharing your AWS resources"
[5]: https://docs.aws.amazon.com/ram/latest/userguide/tshoot-cant-see-shared.html?utm_source=chatgpt.com "Can't see shared resources in the destination account"
[6]: https://docs.aws.amazon.com/vpc/latest/ipam/enable-integ-ipam.html "Integrate IPAM with accounts in an AWS Organization - Amazon Virtual Private Cloud"
[7]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/set-up-dns-resolution-for-hybrid-networks-in-a-multi-account-aws-environment.html "Set up DNS resolution for hybrid networks in a multi-account AWS environment - AWS Prescriptive Guidance"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/profiles.html "What are Amazon Route 53 Profiles? - Amazon Route 53"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall.html?utm_source=chatgpt.com "Using DNS Firewall to filter outbound DNS traffic"
[12]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/using-nat-gateway-with-firewall.html?utm_source=chatgpt.com "Using the NAT gateway with AWS Network Firewall ..."
[13]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/troubleshooting-general-issues.html?utm_source=chatgpt.com "Troubleshooting general issues in AWS Network Firewall"
[14]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/asymmetric-routing.html?utm_source=chatgpt.com "Avoiding asymmetric routing with AWS Network Firewall"
[15]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/tgw-firewall.html "Transit gateway-attached firewalls in Network Firewall - AWS Network Firewall"
[16]: https://docs.aws.amazon.com/waf/latest/developerguide/network-firewall-policies.html "Using AWS Network Firewall policies in Firewall Manager - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[17]: https://docs.aws.amazon.com/waf/latest/developerguide/fms-administrators.html?utm_source=chatgpt.com "Using AWS Firewall Manager administrators"
[18]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html "Direct Connect gateways - AWS Direct Connect"
[19]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/create-vif.html?utm_source=chatgpt.com "Direct Connect virtual interfaces"
[20]: https://docs.aws.amazon.com/vpc/latest/userguide/sharing-managed-prefix-lists.html?utm_source=chatgpt.com "Share customer-managed prefix lists"
[21]: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-sharing.html "Share your VPC subnets with other accounts - Amazon Virtual Private Cloud"
[22]: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-share-limitations.html "Responsibilities and permissions for owners and participants - Amazon Virtual Private Cloud"
[23]: https://docs.aws.amazon.com/ram/latest/userguide/working-with-regional-vs-global.html?utm_source=chatgpt.com "Sharing Regional resources compared to global resources"
[24]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-network-security-for-vpc-to-vpc-and-on-premises-to-vpc-traffic.html?utm_source=chatgpt.com "Centralized network security for VPC-to-VPC and on- ..."
[25]: https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-share-network.html?utm_source=chatgpt.com "Shared AWS Cloud WAN core network"
