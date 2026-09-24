# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

# Part 11: Final Revision, Architecture Decisions & Interview Mastery

This is the **final part of Lesson 36**.

We started with:

```text
On-Prem
   │
  VPN
   │
  VPC
```

and reached:

```text
                         CORPORATE DATA CENTER
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
              Direct Connect               IPsec VPN
                    │                           │
               Transit VIF                      │
                    │                           │
                   DXGW                         │
                    └─────────────┬─────────────┘
                                  ▼
                         TRANSIT GATEWAY
                                  │
                   ┌──────────────┼──────────────┐
                   ▼              ▼              ▼
              SECURITY         SHARED          PROD
                 VPC             VPC             VPC
                  │               │               │
             Firewall        Resolver          ECS/EKS
                                  │               │
                              Hybrid DNS         RDS
```

Let's compress everything into a mental model you can reconstruct during an incident, AWS exam, or interview.

---

# 36.625 The master hybrid-networking mental model

For **every hybrid connection**, think in this order:

```text
SOURCE
   │
   ▼
SOURCE ROUTE TABLE
   │
   ▼
AWS TRANSIT / GATEWAY
   │
   ▼
HYBRID TRANSPORT
   │
   ▼
CUSTOMER ROUTER
   │
   ▼
DESTINATION NETWORK
   │
   ▼
DESTINATION
```

Then immediately reverse it:

```text
DESTINATION
   │
   ▼
RETURN ROUTE
   │
   ▼
CUSTOMER ROUTER
   │
   ▼
VPN / DX
   │
   ▼
TGW
   │
   ▼
SOURCE VPC
```

And overlay:

```text
ROUTING
+
SECURITY
+
DNS
+
APPLICATION
```

The single strongest rule from this entire lesson is:

> **A tunnel being UP does not prove application connectivity.**

Site-to-Site VPN contains two tunnels, but usable connectivity still depends on routing, filtering, return paths, and the application itself. ([AWS Documentation][1])

---

# 36.626 Customer Gateway Device vs Customer Gateway

This distinction should now be automatic.

## Customer Gateway Device

The actual:

```text
Cisco
Fortinet
Palo Alto
Juniper
pfSense
StrongSwan
SD-WAN router
```

running in your environment.

```text
CORPORATE DC

┌────────────────────┐
│ Cisco / FortiGate  │
│ Customer Gateway   │
│ Device             │
└────────────────────┘
```

## Customer Gateway — CGW

AWS-side resource describing information about that customer device.

```text
AWS

Customer Gateway Resource

Public/private endpoint information
BGP ASN
VPN configuration relationship
```

AWS explicitly distinguishes the customer gateway AWS resource from the customer gateway device and builds the Site-to-Site VPN between that customer side and a VGW or TGW. ([AWS Documentation][1])

Never forget:

```text
DEVICE
=
actual router


CGW resource
=
AWS representation of router
```

---

# 36.627 VGW vs TGW

This is one of the most common certification questions.

## Virtual Private Gateway — VGW

Think:

```text
On-Prem
   │
  VPN
   │
  VGW
   │
 ONE VPC
```

Useful mental model:

> VPN endpoint associated with an individual VPC architecture.

---

## Transit Gateway — TGW

Think:

```text
              TGW
          /    |    \
       VPC    VPC   VPC
        │
       VPN
        │
     On-Prem
```

TGW is the central transit-routing hub. It can use multiple TGW route tables to isolate attachment groups. Each attachment is associated with one TGW route table and can propagate its routes into one or more tables. ([AWS Documentation][2])

### Never-forget rule

```text
Small / direct VPC VPN architecture
→ VGW


Many VPCs / central routing
→ TGW
```

---

# 36.628 TGW attachment

An attachment answers:

> **What network/resource is connected to Transit Gateway?**

Examples:

```text
VPC attachment
VPN attachment
DXGW attachment
TGW peering
```

Conceptually:

```text
Prod VPC
   │
attachment
   │
   ▼
  TGW
```

Do not confuse:

```text
attachment exists
```

with:

```text
connectivity works
```

Because routing decisions still need to be present.

---

# 36.629 Association vs propagation

This is probably the #1 Transit Gateway interview concept.

## Association

Answers:

> **Which TGW route table does traffic arriving FROM this attachment use?**

```text
Prod Attachment
      │
      ▼
 ASSOCIATION
      │
      ▼
   PROD-RT
```

One attachment uses one associated TGW route table for ingress routing decisions. ([AWS Documentation][2])

---

## Propagation

Answers:

> **Which TGW route tables learn the routes reachable through this attachment?**

```text
Shared Attachment
       │
       ├────────→ PROD-RT
       │
       └────────→ DEV-RT
```

An attachment can propagate routes to multiple TGW route tables. ([AWS Documentation][2])

---

## Memory trick

```text
ASSOCIATION

Which book do I READ?


PROPAGATION

Which books do I WRITE/advertise
my routes into?
```

---

# 36.630 VPC route table vs TGW route table

You should never confuse these again.

Suppose:

```text
Prod
10.20.0.0/16

Dev
10.30.0.0/16
```

Prod VPC route table:

```text
10.30.0.0/16 → TGW
```

means:

> Leave the Prod VPC through Transit Gateway.

Once TGW receives the packet:

```text
TGW RT

10.30.0.0/16 → Dev Attachment
```

means:

> Leave Transit Gateway through the Dev attachment.

VPC route tables direct traffic out of VPC subnets, while TGW route tables route traffic among TGW attachments. ([AWS Documentation][3])

Never-forget:

```text
VPC Route Table
=
How do I leave this VPC?


TGW Route Table
=
After reaching TGW,
which attachment do I leave through?
```

---

# 36.631 Static route vs propagated route

### Static

You manually define:

```text
10.10.0.0/16 → VPN attachment
```

### Propagated

TGW learns reachability from an attachment.

Example:

```text
VPN via BGP
      │
      ▼
10.10.0.0/16
```

For Site-to-Site VPN, AWS supports both static and dynamic/BGP routing models depending on configuration. ([AWS Documentation][4])

---

# 36.632 Blackhole routes

TGW lets you explicitly create:

```text
10.30.0.0/16 → BLACKHOLE
```

which means matching traffic is discarded. ([AWS Documentation][2])

Use case:

```text
Prod → Dev
must never route.
```

Example:

```text
PROD-RT

10.30.0.0/16 → BLACKHOLE
```

But remember:

```text
TGW blackhole route
≠
firewall
```

It is routing-layer isolation.

---

# 36.633 Longest-prefix match

Suppose:

```text
10.0.0.0/8      → VPN
10.20.0.0/16    → DX
10.20.5.0/24    → TGW attachment B
```

Destination:

```text
10.20.5.50
```

Most specific:

```text
/24
```

wins.

Never forget:

```text
/32 > /24 > /16 > /8 > /0
```

This rule explains countless "why is traffic using the wrong path?" incidents.

---

# 36.634 Site-to-Site VPN

Core architecture:

```text
Customer Gateway Device
        │
    IPsec Tunnel
        │
        ▼
     VGW / TGW
```

AWS Site-to-Site VPN provides **two tunnels** per VPN connection for high availability, and AWS recommends configuring both. ([AWS Documentation][1])

Think:

```text
Tunnel 1
Tunnel 2
```

not:

```text
one VPN tunnel forever
```

---

# 36.635 Static VPN vs BGP VPN

## Static

Routes manually configured.

Best mental model:

```text
small
simple
fairly stable
```

## Dynamic

Uses:

# BGP

Routes can be exchanged dynamically.

AWS documents both static and dynamic Site-to-Site VPN routing and uses BGP for dynamically routed connections. ([AWS Documentation][4])

Enterprise mental shortcut:

```text
Dynamic enterprise network
→ strongly think BGP
```

---

# 36.636 ASN

ASN:

# Autonomous System Number

Used by BGP to identify routing domains.

Example:

```text
Corporate Router
ASN 65000
```

Conceptual BGP session:

```text
Corporate ASN 65000
        │
        │ BGP
        ▼
AWS routing side
```

Do not confuse ASN with:

```text
IP address
VPC CIDR
subnet ID
route table
```

It belongs to the BGP routing domain.

---

# 36.637 Direct Connect

Direct Connect answers a different question from VPN.

VPN:

```text
How do I build an encrypted
hybrid tunnel?
```

Direct Connect:

```text
How do I obtain dedicated
connectivity into AWS?
```

Important:

```text
DX
≠
automatic encryption
```

It is dedicated connectivity; encryption is a separate design decision.

---

# 36.638 Physical DX mental model

```text
Corporate Router
       │
       ▼
Carrier / Partner
       │
       ▼
Direct Connect Location
       │
   Cross-connect
       │
       ▼
AWS DX equipment
```

Then the logical networking begins.

---

# 36.639 Connection vs VIF

A physical DX connection alone isn't enough.

You create a:

# Virtual Interface — VIF

AWS currently defines private, public, and transit VIFs as distinct logical connectivity types on Direct Connect. ([AWS Documentation][5])

Memory:

```text
DX Connection
=
physical connectivity


VIF
=
logical AWS networking over DX
```

---

# 36.640 Private VIF

Use when you think:

```text
private VPC connectivity
```

AWS defines a private VIF for accessing Amazon VPC resources using private IP addresses. ([AWS Documentation][5])

Mental map:

```text
DX
 │
Private VIF
 │
VGW / DXGW
 │
VPC
```

---

# 36.641 Public VIF

Think:

```text
AWS public services
```

AWS defines a public VIF for accessing AWS public services using public IP addresses. ([AWS Documentation][5])

Do **not** think:

```text
Public VIF
=
generic ISP / full Internet connection
```

---

# 36.642 Transit VIF

Think:

# Transit Gateway.

AWS says a transit VIF is used to reach one or more Transit Gateways associated with a Direct Connect Gateway. ([AWS Documentation][6])

Architecture:

```text
Direct Connect
      │
Transit VIF
      │
     DXGW
      │
     TGW
      │
 ┌────┼────┐
 VPC VPC VPC
```

### Never forget:

```text
Private VIF
→ think VPC


Public VIF
→ think AWS public services


Transit VIF
→ think TGW
```

---

# 36.643 DXGW vs TGW

Another very common confusion.

## Direct Connect Gateway — DXGW

Think:

```text
Direct Connect side
```

It associates Direct Connect VIF connectivity with gateway architectures.

## Transit Gateway — TGW

Think:

```text
central AWS transit router
```

A transit VIF communicates with associated TGWs through a Direct Connect Gateway. ([AWS Documentation][7])

Never forget:

```text
DX → Transit VIF → DXGW → TGW
```

Not:

```text
DX → TGW
```

directly in that architecture.

---

# 36.644 VPN vs Direct Connect decision matrix

| Requirement                            |           VPN |                      Direct Connect |
| -------------------------------------- | ------------: | ----------------------------------: |
| Rapid setup                            |             ✅ | ❌ slower physical/provider workflow |
| IPsec encryption                       |             ✅ |                       Not automatic |
| Dedicated connectivity                 |             ❌ |                                   ✅ |
| Low initial complexity                 |             ✅ |                                   ❌ |
| Large predictable enterprise transport |      Possible |                        ✅ strong fit |
| BGP                                    | ✅ dynamic VPN |                                   ✅ |
| Physical cross-connect                 |             ❌ |                                   ✅ |
| Backup path                            |   ✅ excellent | Usually primary/redundant transport |
| TGW integration                        |             ✅ |              ✅ via DXGW/transit VIF |

The correct architecture is often:

```text
DX
+
VPN
```

rather than choosing only one.

---

# 36.645 DX primary + VPN backup

Common architecture:

```text
                    On-Prem
                       │
              ┌────────┴────────┐
              │                 │
             DX                VPN
          PRIMARY             BACKUP
              │                 │
              └────────┬────────┘
                       ▼
                      TGW
```

With dynamic routing and correct policy, failure of the preferred route can allow a backup path to become usable. BGP-based VPNs support route exchange and rerouting when paths fail. ([AWS Documentation][8])

---

# 36.646 BGP path-selection concepts

You don't need CCIE-level depth for AWS architecture, but you must recognize:

```text
LOCAL_PREF
AS_PATH
MED
BGP Communities
prefix specificity
```

Mental shortcuts:

```text
LOCAL_PREF
higher is preferred


AS_PATH
shorter often preferred


MED
lower commonly preferred


Community
metadata/policy tag


Prefix length
more specific wins
```

Always remember that the exact path-selection sequence depends on **which routing system is making the decision**.

---

# 36.647 Directionality

This is extremely important.

```text
On-Prem → AWS
```

can choose a different path from:

```text
AWS → On-Prem
```

So:

```text
forward routing policy
≠
reverse routing policy
```

This creates potential:

# Asymmetric routing.

---

# 36.648 Asymmetric routing

Example:

```text
FORWARD

Prod
 ↓
Firewall A
 ↓
On-Prem
```

Return:

```text
On-Prem
 ↓
Firewall B
 ↓
Prod
```

IP routing itself may tolerate different forward/reverse paths.

Stateful firewalling may not.

Hence:

```text
stateful firewall
+
multi-path
```

should immediately make you think about:

```text
symmetry
flow affinity
appliance mode
```

---

# 36.649 Appliance mode

Think:

```text
TGW
+
stateful network appliance
+
multi-AZ
```

→ investigate/use TGW appliance-mode architecture as appropriate.

Its purpose is to support consistent flow handling through appliance VPC architectures.

Never answer an interview question with:

> "Appliance mode is for firewall."

Better:

> It is relevant when TGW sends flows through stateful network appliances and the architecture needs consistent flow/AZ handling so return traffic does not break stateful inspection.

---

# 36.650 ECMP

ECMP:

# Equal-Cost Multi-Path.

Think:

```text
multiple equivalent routes
         ↓
multiple paths may carry flows
```

Used for:

```text
redundancy
+
capacity utilization
```

But active/active paths introduce more routing/symmetry complexity than simple active/passive architectures.

---

# 36.651 Active/active vs active/passive

## Active/passive

```text
DX-A
PRIMARY

DX-B
BACKUP
```

Advantages:

```text
simple
predictable
easy to reason about
```

Trade-off:

```text
backup capacity may sit mostly unused
```

---

## Active/active

```text
DX-A ACTIVE
DX-B ACTIVE
```

Advantages:

```text
uses both links
capacity utilization
```

Trade-offs:

```text
more policy complexity
possible asymmetric paths
firewall considerations
```

Never say one is automatically better.

---

# 36.652 High availability has FOUR dimensions

Memorize:

```text
1. PATH redundancy
   DX-A / DX-B / VPN


2. FAILURE-DOMAIN redundancy
   separate routers/carriers/locations


3. ROUTING redundancy
   BGP + alternate paths


4. CAPACITY redundancy
   surviving link can handle traffic
```

Having two cables doesn't automatically equal high availability.

---

# 36.653 Private-IP VPN over DX

Mental model:

```text
UNDERLAY
Direct Connect


OVERLAY
IPsec VPN
```

So:

```text
Application Packet
       │
       ▼
IPsec encryption
       │
       ▼
DX transport
```

Never forget:

> **DX carries the encrypted VPN packet; the VPN carries the application packet.**

---

# 36.654 Outer vs inner VPN IPs

### Outer addresses

Identify VPN tunnel endpoints.

### Inside tunnel addresses

Used for routing adjacency such as BGP inside the tunnel.

Think:

```text
OUTER IP
=
how tunnel endpoints reach each other


INSIDE IP
=
routing relationship inside tunnel
```

Do not confuse either with:

```text
application addresses
```

such as:

```text
10.20.5.50
```

---

# 36.655 Hybrid DNS master rule

Application says:

```text
oracle.corp.internal
```

Before networking can route to it:

```text
DNS must produce:
10.10.50.20
```

Therefore always distinguish:

```text
NAME RESOLUTION
```

from:

```text
PACKET ROUTING
```

---

# 36.656 Route 53 VPC Resolver

AWS provides VPC Resolver for recursive DNS resolution in VPCs and for hybrid DNS through inbound/outbound endpoints. ([AWS Documentation][9])

The mental model:

```text
AWS workload
     │
     ▼
VPC Resolver
```

Then:

```text
Private Hosted Zone
public DNS
forwarding rule
```

depending on namespace.

---

# 36.657 Inbound vs outbound Resolver

This must be automatic.

## Inbound

```text
On-Prem DNS
      │
      ▼
AWS Resolver
```

Use when:

> On-premises needs to resolve AWS/private Route 53 names.

AWS states that inbound endpoints allow DNS resolvers in connected networks to forward DNS queries to VPC Resolver through private endpoint addresses reachable via VPN or Direct Connect. ([AWS Documentation][10])

Memory:

```text
On-Prem → AWS
=
INBOUND
```

---

## Outbound

```text
AWS Resolver
      │
      ▼
On-Prem DNS
```

Use when:

> AWS workloads need names owned by corporate DNS.

AWS's Resolver architecture uses forwarding rules and outbound endpoints to send matching VPC queries to external DNS servers. ([AWS Documentation][9])

Memory:

```text
AWS → On-Prem
=
OUTBOUND
```

---

# 36.658 Private Hosted Zone — PHZ

Think:

```text
private DNS namespace
available in associated VPC environments
```

Example:

```text
aws.internal

payments.aws.internal
→ 10.20.5.20
```

Route 53 private hosted zones contain private DNS records for associated VPC resolution. ([AWS Documentation][11])

---

# 36.659 Hybrid DNS direction diagram

```text
AWS → ON-PREM DNS
──────────────────

EC2
 │
VPC Resolver
 │
Resolver Rule
 │
OUTBOUND ENDPOINT
 │
VPN / DX
 │
Corporate DNS


ON-PREM → AWS DNS
──────────────────

Corporate Client
 │
Corporate DNS
 │
Conditional Forwarder
 │
VPN / DX
 │
INBOUND ENDPOINT
 │
VPC Resolver
 │
Private Hosted Zone
```

If you remember that diagram, hybrid DNS becomes straightforward.

---

# 36.660 Route 53 namespace question

Whenever DNS fails, ask:

> **Who is authoritative for this domain?**

Example:

```text
corp.internal
→ On-Prem AD DNS


aws.internal
→ Route 53 PHZ
```

Then ask:

```text
Which resolver was queried?

Which forwarding rule matched?

Can it reach the authoritative server?
```

Those questions solve most hybrid DNS problems faster than changing random Resolver endpoints.

---

# 36.661 VPC Peering vs TGW

## VPC Peering

```text
VPC-A
  │
direct
  │
VPC-B
```

Good mental fit:

```text
small number
simple point-to-point connectivity
```

## Transit Gateway

```text
         TGW
      /   |   \
    VPC  VPC  VPC
```

Good mental fit:

```text
many VPCs
central transit
hybrid networking
routing segmentation
```

TGW centralizes transit routing across attached VPCs and other attachments. ([AWS Documentation][12])

---

# 36.662 Why VPC peering does not scale elegantly as a mesh

For `n` VPCs, full-mesh pair relationships are:

```text
n(n - 1)
────────
    2
```

Example:

```text
10 VPCs
=
45 potential pairwise peerings
```

Where TGW's hub-and-spoke architecture changes the operational model to attaching networks to a transit hub.

---

# 36.663 Multi-account network ownership

Typical enterprise mental model:

```text
NETWORK ACCOUNT
→ TGW
→ VPN
→ DX
→ IPAM


SECURITY ACCOUNT
→ Inspection
→ Network Firewall


SHARED SERVICES
→ Route 53 Resolver
→ AD/DNS
→ shared tooling


WORKLOAD ACCOUNTS
→ applications
→ VPCs
→ ECS/EKS/RDS
```

The precise split can vary by company.

The important concept is:

```text
central governance
+
workload isolation
```

---

# 36.664 AWS RAM

AWS RAM lets resources such as TGW be shared across accounts while the resource remains owned by the owning account.

Mental model:

```text
NETWORK ACCOUNT

owns:
TGW
 │
AWS RAM
 │
 ├── Prod Account
 ├── Dev Account
 └── Shared Account
```

Never think:

```text
RAM share
=
resource ownership transferred
```

It is cross-account consumption/sharing.

---

# 36.665 IPAM

Amazon VPC IPAM answers:

> **Who is allowed to allocate which IP ranges?**

It does NOT:

```text
route packets
filter packets
resolve DNS
```

Think:

```text
IPAM
=
address governance
```

At enterprise scale:

```text
10.0.0.0/8
     │
     ├── On-Prem
     │
     └── AWS
           │
      ┌────┼────┐
     Prod Dev Shared
```

The key benefit is preventing unmanaged overlaps before TGW/DX/VPN make those overlaps painful.

---

# 36.666 Route tables are not security groups

Route:

```text
10.10.0.0/16 → TGW
```

answers:

> Where should traffic go?

Security Group:

```text
TCP 443 from 10.10.0.0/16
```

answers:

> Is this traffic allowed at the workload?

Firewall:

```text
inspect/allow/block traffic
```

answers another security policy question.

Never blur:

```text
routing
```

and:

```text
authorization
```

---

# 36.667 Security Group vs NACL

### Security Group

Stateful workload/ENI-level control.

### NACL

Stateless subnet-level filtering.

This distinction matters for hybrid return traffic because restrictive NACLs must account for both directions and ephemeral ports.

Never diagnose everything as:

```text
SG issue
```

without checking where the packet actually disappeared.

---

# 36.668 Control plane vs data plane

## Control plane

Terraform/AWS API creates:

```text
TGW
route
VPN
attachment
Resolver rule
```

## Data plane

Actual:

```text
10.20.5.50
      →
10.10.50.20
```

packet moves.

This explains why:

```text
terraform apply
=
success
```

does not imply:

```text
application connectivity
=
success
```

---

# 36.669 The production troubleshooting order

Memorize:

```text
1. DNS
2. Source application
3. Source SG/NACL
4. VPC route
5. TGW attachment
6. TGW association
7. TGW route
8. Inspection firewall
9. DX/VPN
10. BGP
11. On-prem routing/firewall
12. Destination service
13. RETURN PATH
```

Never jump randomly from step 2 to step 11.

---

# 36.670 Tunnel UP but application DOWN

This is the most important troubleshooting scenario.

VPN says:

```text
UP
```

But application fails.

Check:

```text
BGP established?

Required prefix advertised?

TGW propagation?

VPC route?

Firewall?

SG?

NACL?

return route?

application listener?
```

AWS's VPN troubleshooting guidance explicitly separates tunnel/BGP/routing/device troubleshooting rather than treating tunnel state as proof of end-to-end application connectivity. ([AWS Documentation][13])

---

# 36.671 DX UP but application DOWN

Same idea:

```text
DX physical link
UP
```

doesn't prove:

```text
VIF
BGP
routes
DXGW
TGW
security
application
```

are correct.

Think in layers:

```text
Physical
 ↓
VLAN/VIF
 ↓
BGP
 ↓
Routes
 ↓
DXGW
 ↓
TGW
 ↓
VPC
 ↓
Application
```

---

# 36.672 DNS resolves but TCP fails

Suppose:

```bash
dig oracle.corp.internal
```

returns:

```text
10.10.50.20
```

but:

```bash
nc -vz oracle.corp.internal 1521
```

fails.

Then:

```text
DNS = working.
```

Move to:

```text
route
TGW
VPN/DX
firewall
application
```

Do not continue debugging DNS.

---

# 36.673 IP works but hostname fails

Opposite situation:

```bash
curl http://10.10.50.20
```

works.

But:

```bash
curl http://oracle.corp.internal
```

fails.

Then:

```text
network path = probably working

DNS = investigate
```

Check:

```text
Resolver rule
endpoint
conditional forwarder
zone authority
record
```

---

# 36.674 Small traffic works, large traffic fails

Immediately suspect:

```text
MTU
MSS
encapsulation overhead
VPN
```

especially when IPsec is present.

Do not start debugging IAM.

---

# 36.675 Flow Logs mental model

### VPC Flow Logs

Think:

```text
traffic visibility at VPC/ENI level
```

### TGW Flow Logs

Think:

```text
traffic visibility through Transit Gateway
```

### Resolver Query Logs

Think:

```text
DNS visibility
```

### VPN telemetry/logging

Think:

```text
tunnel/routing visibility
```

Different observability points answer different questions.

---

# 36.676 tcpdump mental model

`tcpdump` answers:

> **Did the packet reach this host/interface?**

Classic pattern:

```text
SYN
SYN
SYN
```

No SYN-ACK:

```text
destination did not respond
OR
response never returned
```

If destination capture shows:

```text
SYN arrives
SYN-ACK leaves
```

but source never receives it:

# Return-path problem.

This should now be instinctive.

---

# 36.677 Architecture Decision Scenario #1

### Requirement

One VPC must privately connect to a corporate data center quickly with encryption.

No large multi-VPC hub.

Think:

```text
one VPC
+
encrypted hybrid
+
fast setup
```

Good starting answer:

# Site-to-Site VPN.

Potentially:

```text
CGW ↔ VPN ↔ VGW
```

depending on architecture.

---

# 36.678 Scenario #2

### Requirement

50 VPCs across several accounts must connect to the same corporate network.

Think:

```text
many VPCs
central routing
hybrid
```

Answer:

# Transit Gateway.

Architecture:

```text
VPCs
  │
 TGW
  │
VPN / DX
  │
On-Prem
```

TGW is designed as the central transit hub for such attachment-based routing. ([AWS Documentation][12])

---

# 36.679 Scenario #3

### Requirement

100 VPCs attached to TGW require dedicated private connectivity to on-prem.

Think:

```text
TGW
+
Direct Connect
```

Answer architecture:

```text
DX
 ↓
Transit VIF
 ↓
DXGW
 ↓
TGW
```

A transit VIF is specifically intended for one or more TGWs associated with DXGW. ([AWS Documentation][7])

---

# 36.680 Scenario #4

### Requirement

On-prem must access AWS public services over DX.

Think:

```text
AWS public service
```

Answer:

# Public VIF.

AWS defines the public VIF for AWS public services using public IP addressing. ([AWS Documentation][5])

---

# 36.681 Scenario #5

### Requirement

On-prem must access one private VPC architecture through DX.

Think:

```text
private VPC addresses
```

Answer:

# Private VIF.

AWS defines private VIFs for private access to VPC resources. ([AWS Documentation][5])

---

# 36.682 Scenario #6

### Requirement

Prod and Dev use the same TGW.

Both should reach Shared Services.

But:

```text
Prod ↔ Dev
```

must never route.

Answer:

```text
separate TGW route tables

PROD-RT
NONPROD-RT
SHARED-RT
```

Control:

```text
association
propagation
blackhole routes if desired
```

TGW explicitly supports additional route tables to isolate subsets of attachments. ([AWS Documentation][2])

---

# 36.683 Scenario #7

### Requirement

AWS workloads must resolve:

```text
database.corp.internal
```

which is hosted in on-prem AD DNS.

Think:

```text
AWS asks On-Prem
```

Answer:

```text
Route 53 VPC Resolver
OUTBOUND endpoint
+
Resolver forwarding rule
```

The Resolver forwarding architecture sends matching VPC queries through an outbound endpoint toward the configured network DNS server. ([AWS Documentation][9])

---

# 36.684 Scenario #8

### Requirement

On-prem clients must resolve:

```text
app.aws.internal
```

from a Route 53 Private Hosted Zone.

Think:

```text
On-Prem asks AWS
```

Answer:

# Resolver inbound endpoint.

AWS states that inbound endpoints allow on-prem DNS resolvers to forward queries into VPC Resolver over VPN or Direct Connect connectivity. ([AWS Documentation][10])

---

# 36.685 Scenario #9

### Requirement

Direct Connect exists, but regulations require encrypted hybrid traffic.

Possible architectures include:

```text
DX
+
IPsec VPN
```

or supported link-encryption designs depending on exact requirement.

Mental answer:

```text
Private connectivity
≠
cryptographic encryption
```

Treat encryption as its own architecture requirement.

---

# 36.686 Scenario #10

Traffic flow:

```text
Prod → On-Prem
```

passes through Firewall A.

Return:

```text
On-Prem → Prod
```

passes through Firewall B.

Connections intermittently fail.

Think:

# Asymmetric routing / stateful inspection.

Investigate:

```text
TGW routing
appliance path
multi-AZ flow affinity
firewall state
```

not only SGs.

---

# 36.687 Scenario #11

VPN:

```text
Tunnel UP
BGP UP
```

but one subnet is unreachable.

Think:

```text
specific prefix missing?
more-specific blackhole?
route propagation?
return route?
```

A healthy BGP session does not mean every required route exists.

---

# 36.688 Scenario #12

Direct Connect works but traffic unexpectedly uses VPN.

Check:

```text
prefix specificity

static TGW route

DX route propagation

BGP attributes

routing direction
```

Don't believe the architecture diagram saying:

```text
DX PRIMARY
```

Inspect actual routing state.

---

# 36.689 Interview rapid-fire

### Q: What does TGW association mean?

**A:** Which TGW route table an attachment's incoming traffic uses.

---

### Q: What does propagation mean?

**A:** Which TGW route tables learn routes from an attachment.

---

### Q: Can one TGW attachment propagate to multiple route tables?

**A:** Yes. ([AWS Documentation][2])

---

### Q: Can one attachment be associated with multiple TGW RTs simultaneously?

**A:** No; each attachment is associated with one TGW route table for ingress routing. ([AWS Documentation][2])

---

### Q: What's a TGW blackhole route?

**A:** A TGW route that deliberately drops traffic matching that prefix. ([AWS Documentation][14])

---

### Q: Does VPN tunnel UP mean applications can communicate?

**A:** No.

---

### Q: How many tunnels does an AWS Site-to-Site VPN connection normally provide?

**A:** Two. ([AWS Documentation][1])

---

### Q: Which routing protocol is used for dynamically routed S2S VPN?

**A:** BGP. ([AWS Documentation][4])

---

### Q: Transit VIF is used for?

**A:** Direct Connect connectivity toward one or more TGWs through a DXGW. ([AWS Documentation][15])

---

### Q: Private VIF?

**A:** Private VPC connectivity. ([AWS Documentation][5])

---

### Q: Public VIF?

**A:** AWS public services using public IP addressing. ([AWS Documentation][5])

---

### Q: On-prem DNS querying Route 53 private names needs?

**A:** Resolver inbound endpoint. ([AWS Documentation][10])

---

### Q: AWS workloads querying corporate DNS need?

**A:** Resolver outbound endpoint plus forwarding rule. ([AWS Documentation][9])

---

# 36.690 SAA/DOP exam traps

### Trap 1

> "Multiple VPCs need central hybrid connectivity."

Don't immediately choose:

```text
VPC Peering mesh
```

Think:

```text
TGW
```

---

### Trap 2

> "Direct Connect provides encryption."

Not necessarily.

Dedicated/private transport and encryption are separate concepts.

---

### Trap 3

> "The VPN has two tunnels, so redundancy is automatically complete."

No.

Both must be configured appropriately on the customer side and tested. AWS provides two tunnels specifically for HA. ([AWS Documentation][16])

---

### Trap 4

> "TGW attachment exists, therefore VPCs communicate."

No.

Need:

```text
VPC route
association
TGW route/propagation
return route
security
```

---

### Trap 5

> "BGP neighbor is Established, therefore application routing is correct."

No.

The required prefix may still be:

```text
missing
filtered
less preferred
blackholed
not propagated
```

---

### Trap 6

> "Route table permits traffic."

Wrong terminology.

Route table doesn't permit.

It determines:

```text
WHERE
```

Security mechanisms determine:

```text
WHETHER
```

---

### Trap 7

> "On-Prem → AWS DNS means outbound Resolver."

Wrong.

Direction is relative to AWS Resolver:

```text
On-Prem → AWS
=
INBOUND


AWS → On-Prem
=
OUTBOUND
```

---

# 36.691 The 15-second architecture decision tree

When somebody asks:

> Which AWS network service should I use?

Think:

```text
Need connect two VPCs directly?
        │
        └── VPC Peering


Need many VPCs / central transit?
        │
        └── Transit Gateway


Need encrypted on-prem connectivity?
        │
        └── Site-to-Site VPN


Need dedicated on-prem connectivity?
        │
        └── Direct Connect


Need DX → TGW?
        │
        └── Transit VIF + DXGW


Need on-prem → AWS DNS?
        │
        └── Resolver INBOUND


Need AWS → on-prem DNS?
        │
        └── Resolver OUTBOUND


Need central IP governance?
        │
        └── IPAM


Need share central network resource?
        │
        └── AWS RAM
```

That's your quick decision map.

---

# 36.692 The packet-flow decision tree

If traffic fails:

```text
Does hostname resolve?
      │
 ┌────┴────┐
 NO       YES
 │         │
DNS     Can app port connect?
          │
     ┌────┴────┐
     NO       YES
     │         │
 Network    Application
     │
     ▼
Source route?
     │
TGW attachment?
     │
Association?
     │
TGW route?
     │
Firewall?
     │
VPN / DX?
     │
BGP route?
     │
On-prem route?
     │
Destination?
     │
RETURN ROUTE?
```

That flow is far more valuable than memorizing 100 AWS console pages.

---

# 36.693 The five-word troubleshooting framework

Remember:

# Resolve → Route → Transit → Deliver → Return

### Resolve

```text
DNS
```

### Route

```text
VPC route table
```

### Transit

```text
TGW / VPN / DX / firewall
```

### Deliver

```text
SG/NACL/OS/application
```

### Return

```text
reverse everything
```

---

# 36.694 The one-page "never forget" map

```text
                         HYBRID AWS NETWORKING
                                  │
           ┌──────────────────────┼──────────────────────┐
           │                      │                      │
           ▼                      ▼                      ▼
        CONNECTIVITY           ROUTING                 DNS
           │                      │                      │
     ┌─────┴─────┐          ┌─────┴──────┐       ┌─────┴─────┐
     │           │          │            │       │           │
    VPN          DX        VPC RT       TGW RT   INBOUND   OUTBOUND
     │           │                         │       │           │
    IPsec      VIFs                    Association OnPrem→AWS AWS→OnPrem
     │           │                     Propagation
     │       ┌───┼────┐                Blackhole
     │     Private Public Transit
     │                    │
     │                   DXGW
     │                    │
     └───────────────→    TGW
                           │
                ┌──────────┼──────────┐
                ▼          ▼          ▼
              PROD        DEV       SHARED

                         SECURITY
                            │
                  ┌─────────┼─────────┐
                  │                   │
                  ▼                   ▼
             SG / NACL          Firewall
                                     │
                               Appliance Mode

                        GOVERNANCE
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
            RAM            IPAM       Organizations
```

---

# 36.695 The one packet you should be able to explain in an interview

Question:

> Explain how an AWS workload reaches an on-prem database through a Transit Gateway and Direct Connect.

Strong answer:

```text
1. Workload resolves the database hostname.

2. Its subnet/VPC route table matches
   the on-prem CIDR and targets TGW.

3. Traffic enters the VPC's TGW attachment.

4. TGW uses the route table associated with
   that incoming attachment.

5. TGW selects the route toward the DXGW
   or inspection attachment according to
   the architecture.

6. If inspection is required, traffic traverses
   the firewall path and returns to TGW.

7. Traffic leaves AWS transit toward DXGW.

8. DXGW connects the TGW routing domain
   to a Direct Connect transit VIF.

9. BGP routing over DX provides on-prem
   network reachability.

10. Corporate routing delivers traffic
    to the database.

11. Security controls and the database listener
    must allow the connection.

12. The entire reverse route must exist
    for the response.
```

That answer demonstrates actual understanding.

---

# 36.696 The architecture progression to remember

### Stage 1

```text
VPC
```

### Stage 2

```text
VPC ↔ VPC
```

### Stage 3

```text
Multiple VPCs
     │
    TGW
```

### Stage 4

```text
On-Prem
   │
  VPN
   │
  TGW
```

### Stage 5

```text
On-Prem
   │
 DX + VPN
   │
  TGW
```

### Stage 6

```text
On-Prem
   │
 DX/VPN
   │
  TGW
   │
Firewall
   │
Multi-account VPCs
   │
Hybrid DNS
```

### Stage 7

```text
Organizations
   │
Network Account
Security Account
Shared Services
Workload Accounts
   │
IPAM / RAM / IaC / Observability
```

That is the path from beginner networking to enterprise hybrid architecture.

---

# 36.697 Lesson 36 final checklist

You should now be comfortable explaining:

```text
✓ Customer Gateway
✓ Customer Gateway Device
✓ Virtual Private Gateway
✓ Site-to-Site VPN
✓ IPsec / IKE
✓ Two VPN tunnels
✓ Static routing
✓ BGP
✓ ASN
✓ Route propagation

✓ Transit Gateway
✓ TGW attachments
✓ TGW route tables
✓ Association
✓ Propagation
✓ Static routes
✓ Blackhole
✓ Segmentation
✓ Appliance mode
✓ ECMP

✓ Direct Connect
✓ DX location
✓ Cross-connect
✓ LOA-CFA
✓ Dedicated vs Hosted
✓ VLAN / 802.1Q

✓ Private VIF
✓ Public VIF
✓ Transit VIF
✓ DXGW
✓ TGW + DX
✓ DX + VPN failover

✓ Private-IP VPN over DX
✓ underlay vs overlay

✓ Route 53 VPC Resolver
✓ inbound endpoint
✓ outbound endpoint
✓ forwarding rule
✓ Private Hosted Zone
✓ hybrid DNS

✓ AWS RAM
✓ IPAM
✓ multi-account network model

✓ Terraform network architecture
✓ Flow Logs
✓ troubleshooting methodology
✓ return-path debugging
✓ MTU/MSS symptoms
✓ DNS vs routing isolation
```

---

# 36.698 Final "never forget" sentences

Memorize these:

```text
1.
A VPN tunnel being UP does not mean
the application can communicate.


2.
A VPC route tells the packet how
to leave the VPC.


3.
A TGW route tells the packet which
attachment to leave through.


4.
Association tells TGW which route
table incoming traffic reads.


5.
Propagation tells TGW route tables
which attachment routes they learn.


6.
Direct Connect gives dedicated connectivity;
encryption is a separate requirement.


7.
Private VIF → VPC.
Public VIF → AWS public services.
Transit VIF → TGW via DXGW.


8.
On-Prem → AWS DNS = inbound Resolver.
AWS → On-Prem DNS = outbound Resolver.


9.
Routing tells traffic WHERE to go.
Security determines WHETHER it may pass.


10.
Every forward route requires
a valid return path.


11.
Redundancy that has never been tested
is only an assumption.


12.
When troubleshooting:
follow the packet, don't guess.
```

---

# ✅ Lesson 36 COMPLETE

We have now officially completed:

# **Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect**

All **11 parts are finished**:

```text
Part 1   Hybrid mental model + VPN          ✓
Part 2   Transit Gateway                    ✓
Part 3   Direct Connect                     ✓
Part 4   BGP + resilient routing            ✓
Part 5   Private VPN over DX                ✓
Part 6   Hybrid DNS                         ✓
Part 7   Multi-account architecture         ✓
Part 8   Terraform implementation           ✓
Part 9   Troubleshooting + observability    ✓
Part 10  Enterprise hands-on capstone       ✓
Part 11  Final revision + interview mastery ✓
```

You have now covered hybrid AWS networking from **basic VPN concepts all the way to enterprise TGW/DX/BGP/DNS/multi-account architecture and production troubleshooting**.

## Next: Lesson 37

We can now leave Lesson 36 behind and continue the **AWS Production Architecture module** with **Lesson 37**, without repeating any of the hybrid-networking material we just completed.

[1]: https://docs.aws.amazon.com/vpn/latest/s2svpn/how_it_works.html?utm_source=chatgpt.com "How AWS Site-to-Site VPN works"
[2]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html?utm_source=chatgpt.com "How AWS Transit Gateway works - Amazon VPC"
[3]: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html?utm_source=chatgpt.com "Configure route tables - Amazon Virtual Private Cloud"
[4]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-static-dynamic.html?utm_source=chatgpt.com "Static and dynamic routing in AWS Site-to-Site VPN"
[5]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/WorkingWithVirtualInterfaces.html?utm_source=chatgpt.com "Direct Connect virtual interfaces and hosted virtual interfaces"
[6]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/create-transit-vif-for-gateway.html?utm_source=chatgpt.com "Create a transit virtual interface to the Direct Connect gateway"
[7]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-transit-gateways.html?utm_source=chatgpt.com "Direct Connect gateways and Transit Gateway associations"
[8]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-redundant-connection.html?utm_source=chatgpt.com "Redundant AWS Site-to-Site VPN connections for failover"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-inbound-queries.html?utm_source=chatgpt.com "Forwarding inbound DNS queries to your VPCs"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[12]: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-direct-connect-aws-transit-gateway.html?utm_source=chatgpt.com "AWS Direct Connect + AWS Transit Gateway"
[13]: https://docs.aws.amazon.com/vpn/latest/s2svpn/Generic_Troubleshooting.html?utm_source=chatgpt.com "Troubleshoot AWS Site-to-Site VPN connectivity when ..."
[14]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-create-static-route.html?utm_source=chatgpt.com "Create a static route in AWS Transit Gateway - Amazon VPC"
[15]: https://docs.aws.amazon.com/directconnect/latest/APIReference/API_CreateTransitVirtualInterface.html?utm_source=chatgpt.com "CreateTransitVirtualInterface - Direct Connect"
[16]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html?utm_source=chatgpt.com "AWS Site-to-Site VPN"
