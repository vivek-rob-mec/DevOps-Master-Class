# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 3: AWS Direct Connect Deep Dive

We have reached this architecture:

```text
Corporate Data Center
        │
        │ Site-to-Site VPN
        ▼
 Transit Gateway
        │
 ┌──────┼──────┐
 ▼      ▼      ▼
Prod    Dev   Shared
```

VPN gives us secure hybrid connectivity quickly, but large enterprises often want something more predictable and dedicated.

That leads us to:

# AWS Direct Connect — DX

---

# 36.85 The simplest Direct Connect mental model

With Site-to-Site VPN:

```text
On-Prem
   │
Corporate Router
   │
   ▼
===================
   INTERNET
===================
   │
Encrypted IPsec
   │
   ▼
AWS
```

With Direct Connect:

```text
On-Prem
   │
Corporate Router
   │
   ▼
Private network circuit
   │
   ▼
Direct Connect Location
   │
   ▼
AWS Network
```

AWS Direct Connect establishes dedicated network connectivity between your network and AWS rather than making the AWS-bound traffic traverse the public internet in the normal way. ([AWS Documentation][1])

A useful shortcut:

```text
VPN
=
encrypted tunnel
over a transport network
(commonly Internet)


Direct Connect
=
dedicated connectivity
into AWS
```

But there is one extremely important detail:

# Direct Connect is not automatically encryption.

We'll come back to that.

---

# 36.86 Why would an enterprise want Direct Connect?

Imagine a company continuously transfers:

```text
Backups
Database replication
VM migrations
Analytics datasets
SAP traffic
Oracle traffic
Video
ML datasets
Corporate applications
```

between:

```text
Corporate Data Center
        ↕
       AWS
```

An Internet VPN might work perfectly.

But the organization could want:

```text
More predictable network characteristics
Higher bandwidth
Dedicated connectivity
Consistent hybrid architecture
Large data transfers
Enterprise routing
```

Direct Connect is intended for these dedicated hybrid connectivity scenarios and can provide a more consistent network experience than Internet-based connectivity. ([AWS Documentation][2])

---

# 36.87 But Direct Connect is NOT this

A beginner often imagines:

```text
My Office
   │
   │ magical AWS cable
   │
   ▼
EC2
```

Not quite.

There are several physical and logical layers.

A more realistic architecture is:

```text
                    YOUR DATA CENTER

                  ┌─────────────────┐
                  │ Corporate Router│
                  └────────┬────────┘
                           │
                           │ Carrier / Partner circuit
                           │
                           ▼
                 ┌────────────────────┐
                 │ DX Colocation /    │
                 │ Direct Connect     │
                 │ Location           │
                 └─────────┬──────────┘
                           │
                      Cross Connect
                           │
                           ▼
                     AWS DX Router
                           │
                           ▼
                      AWS Network
                           │
                           ▼
                   Virtual Interface
                           │
                           ▼
                       DX Gateway
                           │
                           ▼
                    Transit Gateway
                           │
                 ┌─────────┼─────────┐
                 ▼         ▼         ▼
               PROD       DEV      SHARED
```

The Direct Connect location is a facility where AWS Direct Connect infrastructure and customer/partner connectivity meet. If your equipment is not already in that facility, an AWS Direct Connect Partner or carrier can extend connectivity between your site and the Direct Connect location. ([AWS Documentation][3])

---

# 36.88 There are TWO connectivity pieces

This distinction is very important.

Suppose your corporate office is in Mumbai.

Your router may be here:

```text
Corporate DC
Mumbai
```

while your Direct Connect location may be somewhere else.

Therefore you effectively need:

```text
Customer location
      │
      │ carrier circuit
      ▼
DX location
      │
      │ cross-connect
      ▼
AWS router
```

Think:

```text
Piece 1:
Your DC → DX facility

Piece 2:
Your equipment/provider → AWS inside DX facility
```

Direct Connect itself does not magically provide every carrier circuit needed to get from your building to the DX facility.

---

# 36.89 What is a Cross-Connect?

At the Direct Connect location, there needs to be a physical connection between:

```text
Your / partner equipment
        │
        │ fiber
        ▼
AWS equipment
```

That facility-level link is generally called a:

# Cross-connect

```text
Customer Router
     │
     │ cross-connect
     │
AWS DX Router
```

For dedicated Direct Connect, AWS provides a **Letter of Authorization and Connecting Facility Assignment — LOA-CFA**. You give this to your network/colocation provider so it can provision the cross-connect to the AWS-assigned facility connection. ([AWS Documentation][4])

---

# 36.90 What is LOA-CFA?

You will encounter this term in real Direct Connect deployments.

It stands for:

```text
LOA
=
Letter of Authorization

CFA
=
Connecting Facility Assignment
```

Conceptually it says:

> AWS authorizes this connection and identifies the assigned facility connection information.

Typical process:

```text
Request DX connection
       │
       ▼
AWS processes request
       │
       ▼
LOA-CFA becomes available
       │
       ▼
Give LOA-CFA to facility/provider
       │
       ▼
Provider orders cross-connect
       │
       ▼
Physical fiber installed
```

AWS explicitly requires the LOA-CFA for the provider establishing a dedicated Direct Connect cross-connect. ([AWS Documentation][4])

Interview shortcut:

```text
LOA-CFA
=
document used to authorize/provision
the physical cross-connect to AWS
```

---

# 36.91 Direct Connect has physical AND logical layers

This is one of today's biggest lessons.

The physical connection:

```text
Customer Router
      │
      │ Ethernet
      ▼
AWS Direct Connect
```

does not by itself tell AWS:

```text
which VPC?
which Transit Gateway?
which AWS services?
which routes?
```

That happens through:

# Virtual Interfaces — VIFs

So:

```text
Physical DX Connection
          │
          ├── VIF
          │
          ├── VIF
          │
          └── VIF
```

AWS requires a virtual interface before the Direct Connect connection can access the applicable AWS networking/service destination. ([AWS Documentation][5])

---

# 36.92 Dedicated vs Hosted Direct Connect

There are two major connection models:

```text
DIRECT CONNECT

├── Dedicated Connection
│
└── Hosted Connection
```

You must distinguish them.

---

# 36.93 Dedicated Connection

With a dedicated connection, the physical Ethernet connection is dedicated to your customer connection.

Conceptually:

```text
YOUR ROUTER

    │

Dedicated physical connection

    │

AWS DX ROUTER
```

As of August 2026, AWS documents dedicated Direct Connect connection speeds of:

```text
1 Gbps
10 Gbps
100 Gbps
400 Gbps
```

using supported single-mode fiber specifications. ([AWS Documentation][6])

So don't memorize the older:

```text
1 / 10 / 100 Gbps only
```

because AWS now also documents:

```text
400 Gbps
```

for dedicated connections. ([AWS Documentation][6])

---

# 36.94 Hosted Connection

Hosted connections are provided through an:

# AWS Direct Connect Partner

Conceptually:

```text
              Partner infrastructure

Customer A ─────┐
Customer B ─────┼──── Partner DX infrastructure ─── AWS
Customer C ─────┘
```

Your hosted connection represents allocated capacity delivered through the partner rather than you ordering an AWS dedicated physical port directly.

AWS currently documents hosted connection capacities of:

```text
50 Mbps
100 Mbps
200 Mbps
300 Mbps
400 Mbps
500 Mbps
1 Gbps
2 Gbps
5 Gbps
10 Gbps
25 Gbps
```

with higher hosted speeds subject to eligible Direct Connect Partner/location capabilities. ([AWS Documentation][7])

---

# 36.95 Dedicated vs Hosted

| Feature                       | Dedicated                                    | Hosted                                              |
| ----------------------------- | -------------------------------------------- | --------------------------------------------------- |
| Provisioning relationship     | AWS dedicated connection + facility/provider | DX Partner                                          |
| Physical port                 | Dedicated customer connection                | Delivered through partner infrastructure            |
| Current documented speeds     | 1/10/100/400 Gbps                            | 50 Mbps–25 Gbps options                             |
| LOA-CFA workflow              | Common dedicated workflow                    | Partner handles underlying connectivity differently |
| Multiple VIFs                 | Supported subject to quotas                  | Hosted connection has tighter VIF limits            |
| Enterprise high bandwidth     | Excellent                                    | Depends on requirement/provider                     |
| Smaller bandwidth requirement | Can be excessive                             | Often attractive                                    |

AWS currently allows up to 50 private/public VIFs on a dedicated connection, with separate transit-VIF limits and an overall VIF quota, whereas a hosted connection supports one private, public, or transit VIF per hosted connection. ([AWS Documentation][8])

Don't memorize every quota for an exam.

Remember the architecture:

```text
Dedicated
→ AWS-provisioned dedicated connection

Hosted
→ partner-provided Direct Connect capacity
```

---

# 36.96 Now the most important DX topic: VIFs

AWS Direct Connect has three VIF types you absolutely need to distinguish:

```text
PRIVATE VIF

PUBLIC VIF

TRANSIT VIF
```

AWS defines them according to the AWS resources you want to access. ([AWS Documentation][5])

Here's your never-forget table:

| VIF             | Main purpose                                               |
| --------------- | ---------------------------------------------------------- |
| **Private VIF** | Private connectivity to VPC networking                     |
| **Public VIF**  | AWS public service endpoints                               |
| **Transit VIF** | Transit Gateway / scalable multi-VPC architecture via DXGW |

Now we'll make each one crystal clear.

---

# 36.97 Private VIF

Suppose you have:

```text
Corporate DC
10.10.0.0/16
```

and:

```text
AWS Prod VPC
10.20.0.0/16
```

You want private-IP communication:

```text
10.10.5.20
      ↓
10.20.2.50
```

A **private VIF** is designed for private connectivity to Amazon VPC resources using private IP addressing. ([AWS Documentation][5])

Simple architecture:

```text
On-Prem
10.10.0.0/16
     │
     │ DX
     │
Private VIF
     │
     ▼
VGW / Direct Connect Gateway
     │
     ▼
VPC
10.20.0.0/16
```

Think:

```text
Private VIF
=
private AWS/VPC networking
```

---

# 36.98 Public VIF

Now suppose on-premises needs AWS public services/endpoints.

For example:

```text
Amazon S3 public endpoint
other supported AWS public services
```

You may use:

# Public VIF

Architecture:

```text
Corporate Network
       │
       │ DX
       ▼
    Public VIF
       │
       ▼
AWS public service endpoints
```

AWS defines a public VIF as providing access to AWS public services using public IP addresses. ([AWS Documentation][5])

Important:

# Public VIF ≠ general Internet connection.

Do not think:

```text
Public VIF
=
AWS gives my office Internet access
```

Wrong mental model.

Think:

```text
Public VIF
=
Reach AWS public IP services
through Direct Connect
```

---

# 36.99 Transit VIF

Now our architecture has:

```text
Prod VPC
Dev VPC
Shared VPC
Security VPC
Analytics VPC
```

all attached to:

```text
Transit Gateway
```

What VIF should our Direct Connect architecture use?

# TRANSIT VIF

AWS specifically defines a transit VIF for access to one or more Transit Gateways associated with a Direct Connect Gateway. ([AWS Documentation][5])

Architecture:

```text
                   ON-PREM

                      │
               Direct Connect
                      │
                Transit VIF
                      │
                      ▼
             Direct Connect Gateway
                      │
                      ▼
                Transit Gateway
                      │
            ┌─────────┼─────────┐
            ▼         ▼         ▼
          Prod       Dev      Shared
```

THIS is the architecture we care about most for our enterprise course.

---

# 36.100 Private VIF vs Transit VIF

This distinction appears constantly in interviews.

## Private VIF

Think:

```text
DX
 │
Private VIF
 │
VGW / DX Gateway
 │
VPC
```

Primarily VPC-oriented private connectivity.

---

## Transit VIF

Think:

```text
DX
 │
Transit VIF
 │
DXGW
 │
TGW
 │
├── VPC
├── VPC
├── VPC
└── VPN
```

Designed for Transit Gateway-centric connectivity. ([AWS Documentation][9])

Never-forget trick:

```text
PRIVATE VIF
→ think VPC


TRANSIT VIF
→ think TGW
```

---

# 36.101 Can I connect a Transit VIF directly to TGW?

Notice our diagram says:

```text
Transit VIF
     │
     ▼
Direct Connect Gateway
     │
     ▼
Transit Gateway
```

not:

```text
Transit VIF
     │
     ▼
TGW
```

The architecture requires:

# Direct Connect Gateway — DXGW

for Transit Gateway integration.

AWS's documented flow is:

```text
Direct Connect Connection
        ↓
Transit VIF
        ↓
Direct Connect Gateway
        ↓
Transit Gateway association
```

([AWS Documentation][9])

---

# 36.102 What is Direct Connect Gateway?

This name confuses many beginners.

A:

# Direct Connect Gateway

is not:

```text
physical router in your rack
```

and it's not:

```text
another VPC
```

AWS describes DXGW as a globally available virtual Direct Connect component that participates in the routing architecture and can associate Direct Connect connectivity with VGWs or TGWs. AWS further describes it as operating outside the actual data traffic path rather than behaving like a centralized packet-forwarding appliance. ([AWS Documentation][10])

Mental model:

```text
Direct Connect
      │
      ▼
     DXGW
      │
      ├── VGW architecture
      │
      └── TGW architecture
```

For our design:

```text
DX
 │
Transit VIF
 │
DXGW
 │
TGW
```

---

# 36.103 Don't confuse DXGW and TGW

This is extremely important.

## Transit Gateway

```text
TGW
```

is the AWS network transit hub routing among:

```text
VPCs
VPN attachments
DX gateway attachment
other supported attachments
```

## Direct Connect Gateway

```text
DXGW
```

is the Direct Connect-side global routing construct used to associate DX connectivity with VGW/TGW architectures.

So:

```text
DXGW ≠ TGW
```

Our enterprise architecture uses BOTH:

```text
                    Direct Connect
                          │
                          ▼
                    Transit VIF
                          │
                          ▼
                        DXGW
                          │
                          ▼
                         TGW
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
           PROD          DEV         SHARED
```

---

# 36.104 A beautiful mental separation

Remember this:

```text
Direct Connect Connection
=
PHYSICAL CONNECTIVITY


VIF
=
LOGICAL CONNECTIVITY


DXGW
=
DIRECT CONNECT ROUTING ASSOCIATION LAYER


TGW
=
AWS TRANSIT ROUTER


VPC ROUTE TABLE
=
WORKLOAD ROUTING
```

That's the whole architecture in five layers.

---

# 36.105 Why do we need VLANs?

One physical Ethernet connection can carry multiple logical networks.

Direct Connect uses:

# IEEE 802.1Q VLAN tagging

for its virtual interface architecture, and AWS requires 802.1Q support across the applicable connectivity path. ([AWS Documentation][1])

Imagine:

```text
Physical DX cable
        │
        ├── VLAN 100
        │     └── Private VIF
        │
        ├── VLAN 200
        │     └── Public VIF
        │
        └── VLAN 300
              └── another VIF
```

Think of VLAN as:

```text
One physical wire

but multiple logically separated
Layer-2 channels.
```

---

# 36.106 Example

One 10-Gbps dedicated DX connection:

```text
             10 Gbps Physical DX

                     │

           ┌─────────┼─────────┐
           │         │         │

        VLAN 101  VLAN 102  VLAN 103

           │         │         │
           ▼         ▼         ▼

       Private    Public     Transit
         VIF        VIF        VIF
```

Subject, of course, to AWS architecture and VIF quotas.

So:

```text
Connection
```

and:

```text
VIF
```

are NOT synonyms.

---

# 36.107 Layer model

Let's place everything in networking layers:

```text
LAYER 1
Physical fiber

        ↓

LAYER 2
Ethernet
802.1Q VLAN

        ↓

LAYER 3
IP addressing
BGP routing

        ↓

AWS connectivity
DXGW / TGW / VPC
```

This makes troubleshooting much easier.

---

# 36.108 Direct Connect uses BGP

Remember BGP from our VPN lesson?

```text
Border Gateway Protocol
```

Direct Connect uses BGP between your network and AWS on a virtual interface.

Your router may say:

```text
I can reach:

10.10.0.0/16
10.11.0.0/16
10.12.0.0/16
```

AWS may advertise the AWS-side prefixes relevant to the architecture.

Your device needs to support BGP and BGP MD5 authentication; AWS also supports BFD for faster failure detection when configured appropriately on the customer router. ([AWS Documentation][1])

---

# 36.109 BGP configuration mental model

Suppose:

```text
Corporate ASN
65000
```

TGW:

```text
AWS-side routing domain
```

The Direct Connect VIF gets a BGP peering relationship.

Conceptually:

```text
      Corporate Router

          ASN 65000
              │
              │
              │ BGP
              │
              ▼
           AWS DX
```

Routes:

```text
ON-PREM → AWS

10.10.0.0/16
10.11.0.0/16


AWS → ON-PREM

10.20.0.0/16
10.30.0.0/16
10.40.0.0/16
```

Now each side learns reachability dynamically.

---

# 36.110 BGP authentication

Direct Connect VIF BGP peering uses:

```text
MD5 authentication
```

AWS enables BGP MD5 authentication for Direct Connect virtual interfaces. ([AWS Documentation][11])

So if:

```text
Physical DX = UP

VIF = ?

BGP = DOWN
```

one thing to check is:

```text
MD5 key mismatch
```

along with:

```text
ASN mismatch
peer IP mismatch
VLAN problem
routing configuration
```

AWS's Layer 3 troubleshooting guidance explicitly calls out ASN, peer addressing, and MD5 authentication when BGP doesn't establish. ([AWS Documentation][12])

---

# 36.111 Direct Connect troubleshooting layers

Suppose someone says:

> DX isn't working.

Don't randomly edit routes.

Use:

```text
Layer 1
Physical
   │
   ▼
Is DX connection UP?
   │
   ▼

Layer 2
VLAN / Ethernet
   │
   ▼

Layer 3
Peer IPs
   │
   ▼

BGP
ASN / MD5
   │
   ▼

Route advertisement
   │
   ▼

DXGW
   │
   ▼

TGW routes
   │
   ▼

VPC routes
   │
   ▼

SG / NACL / Firewall
   │
   ▼

Application
```

That's a production troubleshooting methodology.

---

# 36.112 Transit VIF packet architecture

Let's now combine everything.

On-premises:

```text
10.10.0.0/16
```

AWS:

```text
Prod   10.20.0.0/16
Dev    10.30.0.0/16
Shared 10.40.0.0/16
```

Architecture:

```text
                      CORPORATE DC
                       10.10.0.0/16
                              │
                              ▼
                      Customer Router
                         ASN 65000
                              │
                              │
                       Carrier Circuit
                              │
                              ▼
                     Direct Connect
                       Location
                              │
                              ▼
                       AWS DX Port
                              │
                              ▼
                        Transit VIF
                              │
                              ▼
                     Direct Connect
                         Gateway
                              │
                              ▼
                     Transit Gateway
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
          PROD               DEV              SHARED
       10.20/16           10.30/16           10.40/16
```

This is the architecture I want you to associate with:

# Enterprise Direct Connect.

---

# 36.113 Allowed Prefixes

When we associate:

```text
DXGW
  │
  ▼
TGW
```

we configure an:

# Allowed Prefix List

for the TGW association.

For example:

```text
10.20.0.0/16
10.30.0.0/16
10.40.0.0/16
```

These prefixes control what the Direct Connect Gateway originates/advertises toward the on-premises side for that TGW association. ([AWS Documentation][9])

Conceptually:

```text
              TGW
               │
       10.20/16
       10.30/16
       10.40/16
               │
               ▼
             DXGW

Allowed prefixes:

10.20.0.0/16
10.30.0.0/16
10.40.0.0/16

               │
               ▼
        advertised toward
            on-prem
```

---

# 36.114 Allowed Prefix is NOT a firewall rule

This is another important distinction.

Don't think:

```text
Allowed Prefix
=
security allow-list
```

Better mental model:

```text
Allowed Prefix
=
routing advertisement control
```

It controls routing information in this architecture.

Security still comes from:

```text
Firewall
Security Groups
NACL
Application authorization
TGW segmentation
```

Routing and security are different things.

---

# 36.115 Full packet walk: On-prem → Prod through DX

Let's follow:

```text
Corporate server

10.10.5.20
```

connecting to:

```text
Prod EC2

10.20.2.50
```

---

## Step 1 — Server sends packet

```text
SRC = 10.10.5.20
DST = 10.20.2.50
```

Corporate router knows through BGP:

```text
10.20.0.0/16
    ↓
Direct Connect
```

---

## Step 2 — Customer router forwards to DX

```text
10.10.5.20
      │
      ▼
Customer Router
      │
      ▼
Carrier / cross-connect
      │
      ▼
AWS DX
```

---

## Step 3 — Packet enters transit VIF

The VLAN/VIF identifies the logical Direct Connect path.

```text
DX physical connection
        │
        ▼
Transit VIF
```

---

## Step 4 — DXGW / TGW architecture

```text
Transit VIF
      │
      ▼
DXGW
      │
      ▼
TGW
```

The TGW-side routing domain receives connectivity through the Direct Connect gateway association. ([AWS Documentation][9])

---

## Step 5 — TGW route lookup

Suppose:

```text
DX/TGW associated route table

Destination         Target

10.20.0.0/16        Prod Attachment
10.30.0.0/16        Dev Attachment
10.40.0.0/16        Shared Attachment
```

Destination:

```text
10.20.2.50
```

matches:

```text
10.20.0.0/16
```

Therefore:

```text
→ Prod Attachment
```

---

## Step 6 — Prod VPC

Packet enters:

```text
Prod VPC
```

then:

```text
VPC routing
   │
   ▼
Security controls
   │
   ▼
10.20.2.50
```

---

# 36.116 Return packet

Now:

```text
10.20.2.50
      ↓
10.10.5.20
```

The Prod subnet route table needs something such as:

```text
10.10.0.0/16
     ↓
TGW
```

Then:

```text
Prod
 │
TGW
 │
DXGW association
 │
Transit VIF
 │
DX
 │
Corporate Router
 │
10.10.5.20
```

Once again:

# RETURN ROUTE MATTERS.

Exactly the same principle as VPN.

---

# 36.117 Direct Connect does NOT automatically encrypt your traffic

This is extremely important.

Many engineers incorrectly assume:

```text
Dedicated private connection
=
encrypted
```

No.

A private/dedicated path and cryptographic encryption are different security properties.

AWS supports encryption options including:

```text
MACsec
```

on supported dedicated Direct Connect connection types/locations, and you can also use IPsec-based VPN designs over Direct Connect when appropriate. ([AWS Documentation][13])

So remember:

```text
Direct Connect
      =
dedicated connectivity

NOT automatically
=
end-to-end encryption
```

---

# 36.118 MACsec

MACsec means:

# Media Access Control Security

Standard:

```text
IEEE 802.1AE
```

It operates at:

# Layer 2

Conceptually:

```text
Customer Router
      │
      │ MACsec protected Ethernet
      │
      ▼
AWS Direct Connect Router
```

AWS currently supports Direct Connect MACsec on supported **10-Gbps, 100-Gbps and 400-Gbps dedicated connections** at MACsec-capable locations; the cipher requirements differ for higher-speed links. ([AWS Documentation][13])

Important:

```text
MACsec
≠
IPsec
```

---

# 36.119 MACsec vs IPsec

## MACsec

```text
Layer 2
Ethernet protection
```

## IPsec

```text
Layer 3
IP packet protection
```

Conceptual comparison:

```text
MACsec

Ethernet Frame
     ↓
encrypted/protected at L2


IPsec

IP Packet
     ↓
encrypted/protected at L3
```

Don't mix them.

---

# 36.120 What if Direct Connect doesn't support MACsec for my design?

Or what if security policy requires IPsec?

We can use:

# VPN over Direct Connect

Conceptually:

```text
Physical Transport:
Direct Connect

            │

Inside it:
IPsec VPN tunnel

            │

Encrypted application traffic
```

So:

```text
Direct Connect
=
transport path

VPN
=
encryption overlay
```

AWS explicitly documents Direct Connect + IPsec designs and notes that VPN-over-DX adds encryption while introducing the normal VPN encapsulation/MTU considerations. ([AWS Documentation][14])

---

# 36.121 Three hybrid security models

### Architecture A — Direct Connect only

```text
On-Prem
   │
   │ DX
   ▼
AWS
```

Benefits:

```text
dedicated path
```

But don't assume encryption.

---

### Architecture B — Direct Connect + MACsec

```text
On-Prem
   │
   │ MACsec
   │ over DX
   ▼
AWS
```

Adds Layer-2 link encryption where supported.

---

### Architecture C — VPN over DX

```text
On-Prem
   │
   │ IPsec tunnel
   │
   │ transported over DX
   ▼
AWS
```

Adds IPsec encryption.

These solve somewhat different requirements.

---

# 36.122 Is one Direct Connect enough?

Production answer:

# Usually not for highly critical connectivity.

Suppose:

```text
Corporate DC
     │
     │
     ▼
DX Location A
     │
     ▼
AWS
```

What happens if:

```text
fiber cut?
router dies?
carrier failure?
DX location problem?
customer device fails?
```

Hybrid connectivity disappears.

AWS recommends redundant connectivity and multiple Direct Connect locations for high-availability designs. ([AWS Documentation][15])

---

# 36.123 Better architecture

```text
                     Corporate DC

                  Router A    Router B
                     │           │
                     │           │
                     ▼           ▼
              DX Location A   DX Location B
                     │           │
                     └─────┬─────┘
                           │
                           ▼
                         AWS
```

Now we have diversity across:

```text
Customer router
Physical circuit
Potential provider
DX location
AWS connection
```

That's much stronger.

---

# 36.124 Even better: DX + VPN backup

A very common architecture is:

```text
                       ON-PREM
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
      Direct Connect              Site-to-Site VPN
         PRIMARY                      BACKUP
             │                         │
             └────────────┬────────────┘
                          ▼
                         AWS
```

AWS explicitly documents VPN as a potential backup path to Direct Connect, while noting that Internet-based backup has different reliability/performance characteristics from fully redundant Direct Connect designs. ([AWS Documentation][16])

This is extremely common conceptually:

```text
Normal traffic
     ↓
Direct Connect

DX failure
     ↓
BGP changes
     ↓
VPN becomes preferred available route
```

---

# 36.125 But enterprise HA can go further

A stronger design:

```text
                         CORPORATE DC

                    Router A     Router B
                       │            │
              ┌────────┘            └────────┐
              ▼                              ▼
       DX Location A                  DX Location B
              │                              │
              └─────────────┬────────────────┘
                            │
                            ▼
                           AWS

                  + Site-to-Site VPN
                     tertiary path
```

Then you can protect against multiple failure domains.

AWS provides the **Direct Connect Resiliency Toolkit** specifically to help provision connection models aligned to resiliency/SLA objectives. ([AWS Documentation][17])

---

# 36.126 BGP chooses paths

Suppose:

```text
Path A
Direct Connect

Path B
VPN
```

Both can advertise:

```text
10.20.0.0/16
```

Routing policy determines which path becomes preferred.

Conceptually:

```text
             10.20.0.0/16

          ┌────────┴────────┐
          │                 │
          ▼                 ▼
         DX                VPN
       PRIMARY            BACKUP
```

With BGP, we can influence preference using mechanisms such as:

```text
Local preference
AS path
BGP communities
route specificity
```

Direct Connect exposes BGP routing policies and BGP communities for controlling route preference/scope in supported VIF scenarios. ([AWS Documentation][18])

We'll make route preference a dedicated mini-section shortly because it's important enough on its own.

---

# 36.127 BGP Communities

A BGP community is essentially:

```text
metadata/tag attached to a BGP route
```

that networking policy can use.

Conceptually:

```text
Route:
10.20.0.0/16

Community:
some-policy-value
```

Then routers can make routing decisions based on:

```text
prefix
+
community
+
other BGP attributes
```

Direct Connect supports AWS-defined BGP communities for routing behavior such as scope and route preference in applicable VIF types. ([AWS Documentation][18])

Don't memorize every community yet.

First understand:

```text
BGP community
=
route-policy metadata
```

---

# 36.128 AS_PATH

Remember:

```text
ASN 65000
```

BGP carries a path containing AS numbers.

Example:

```text
Route:
10.10.0.0/16

AS_PATH:
65000 65100 65200
```

Generally, among otherwise comparable BGP paths:

```text
shorter AS path
```

can be preferred.

Therefore an organization can intentionally prepend its ASN:

```text
65000

vs

65000 65000 65000
```

to make a path less attractive.

Think:

```text
Normal DX
AS_PATH = shorter

Backup
AS_PATH = longer
```

This is a classic BGP traffic-engineering idea; Direct Connect routing guidance includes AS_PATH and community-based routing controls. ([AWS Documentation][18])

---

# 36.129 Link Aggregation Group — LAG

Another DX concept:

# LAG

Suppose you have multiple dedicated DX connections:

```text
Connection 1
Connection 2
Connection 3
Connection 4
```

You may aggregate supported dedicated connections into:

```text
LAG
```

Conceptually:

```text
               LAG

       ┌────────┼────────┐
       │        │        │
      DX1      DX2      DX3
```

AWS supports LAGs for dedicated Direct Connect connections of matching bandwidth and applicable location/end-point characteristics. Current documented LAG support includes 1, 10, 100 and 400-Gbps dedicated connections. ([AWS Documentation][19])

Think:

```text
LAG
=
multiple physical DX links
treated as one aggregated interface
```

---

# 36.130 But LAG ≠ geographic resiliency

Important trap.

If:

```text
DX1
DX2
DX3
```

are all in:

```text
Same Direct Connect location
```

then:

```text
location failure
```

can affect all of them.

So LAG helps with:

```text
capacity
link-level redundancy
```

but isn't equivalent to:

```text
multiple independent DX locations
```

For higher resilience, AWS recommends geographically/site-diverse Direct Connect connectivity rather than relying on multiple connections in a single location. ([AWS Documentation][17])

Never forget:

```text
Multiple links
≠
multiple failure domains.
```

---

# 36.131 Failure-domain thinking

When designing DX HA, ask:

```text
Are the routers independent?

Are the circuits independent?

Are the providers independent?

Are the DX locations independent?

Are power paths independent?

Are BGP paths independent?
```

Don't accept:

```text
"We have two cables."
```

as proof of high availability.

Maybe those two cables:

```text
use same router
same trench
same carrier
same building
same DX location
```

Then one failure may kill both.

---

# 36.132 Direct Connect + Transit Gateway + inspection

Now combine Part 2 with Part 3.

```text
                       CORPORATE DC
                            │
                            │ DX
                            ▼
                     Transit VIF
                            │
                            ▼
                           DXGW
                            │
                            ▼
                           TGW
                            │
                  ┌─────────┴──────────┐
                  │                    │
                  ▼                    ▼
            Inspection VPC          Workloads
                  │
          Network Firewall
                  │
                  ▼
                 TGW
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
      PROD       DEV      SHARED
```

Now on-prem → Prod can be:

```text
On-Prem
   ↓
DX
   ↓
DXGW
   ↓
TGW
   ↓
Inspection VPC
   ↓
Firewall
   ↓
TGW
   ↓
Prod
```

That is a genuine enterprise hybrid-cloud architecture.

---

# 36.133 Production segmentation example

Networks:

```text
On-Prem
10.10.0.0/16

Prod
10.20.0.0/16

Dev
10.30.0.0/16

Shared
10.40.0.0/16

Security
10.50.0.0/16
```

Requirement:

```text
OnPrem → Prod      YES
OnPrem → Shared    YES
OnPrem → Dev       NO

Prod → OnPrem      YES
Dev  → OnPrem      NO

Everything sensitive
→ inspection first
```

Then TGW routing can implement:

```text
DX-RT

10.20.0.0/16 → Inspection
10.40.0.0/16 → Inspection
10.30.0.0/16 → BLACKHOLE
```

Inspection-side route table:

```text
10.20.0.0/16 → Prod
10.40.0.0/16 → Shared
10.10.0.0/16 → DX attachment
```

Now Direct Connect provides transport while TGW provides segmentation and steering.

Very important division of responsibilities:

```text
DX
=
CONNECTIVITY


TGW
=
TRANSIT ROUTING


FIREWALL
=
TRAFFIC INSPECTION / SECURITY
```

---

# 36.134 Direct Connect Gateway can be global

An important feature of DXGW is that it is a globally available Direct Connect resource and can support access to supported resources across Regions, subject to Direct Connect gateway architecture and association rules. ([AWS Documentation][10])

For example:

```text
             Corporate DC
                  │
                  DX
                  │
                 DXGW
                  │
          ┌───────┴────────┐
          │                │
          ▼                ▼
     Mumbai TGW       Singapore TGW
          │                │
        VPCs             VPCs
```

The actual architecture, prefix rules and TGW associations must be designed correctly, but this is why DXGW is more than "a gateway for one VPC."

---

# 36.135 Direct Connect does not make VPC-to-VPC routing magic

Suppose:

```text
VPC A
VPC B
```

are both reachable through a Direct Connect architecture.

Don't assume DXGW itself should be treated as:

```text
general VPC transit router
```

AWS specifically documents restrictions and behavior around communication among gateway associations; TGW is the proper transit-routing construct when you need scalable VPC-to-VPC transit architecture. ([AWS Documentation][10])

Mental model:

```text
Need many VPCs connected together?

Think:
TGW


Need dedicated hybrid connectivity?

Think:
DX


Need DX to TGW?

Think:
Transit VIF + DXGW
```

---

# 36.136 Direct Connect SiteLink — advanced preview

AWS also offers:

# Direct Connect SiteLink

SiteLink can allow supported Direct Connect locations to communicate over the AWS global network without requiring the traffic to first traverse an AWS Region in the normal architecture. AWS currently documents SiteLink support for applicable private/transit VIF scenarios with specific restrictions. ([AWS Documentation][5])

Conceptually:

```text
Branch/Data Center A
        │
      DX PoP
        │
        │ AWS global network
        │
      DX PoP
        │
Branch/Data Center B
```

Use case:

```text
Enterprise WAN connectivity
using AWS backbone
```

We won't dive deeply into SiteLink yet because it deserves a separate advanced hybrid-WAN discussion.

---

# 36.137 MTU matters too

When running high-throughput hybrid networking, packet size becomes important.

Conceptually:

```text
Large MTU
→ fewer packets for same data volume

But:

encapsulation
VPN
network appliances
intermediate links
```

can affect usable packet size.

AWS specifically notes that VPN-over-Direct-Connect adds encapsulation and can reduce effective MTU compared with a native DX path. ([AWS Documentation][20])

This can cause classic problems such as:

```text
Ping works
small HTTP works

BUT

large transfers hang
TLS behaves strangely
application intermittently stalls
```

Possible culprit:

```text
MTU / fragmentation / PMTUD
```

Later in troubleshooting labs we'll test this using:

```bash
ping -M do
tracepath
tcpdump
```

on Linux.

---

# 36.138 Direct Connect monitoring mental model

Production monitoring should ask:

```text
Is physical connection UP?

Is VIF UP?

Is BGP UP?

How many routes received?

How many routes advertised?

Are packet/error counters healthy?

Is bandwidth saturated?

Has failover occurred?
```

AWS now exposes BGP route visibility for Direct Connect VIFs, including accepted routes and routes AWS sends toward the customer side, with AS path/community information. ([AWS Documentation][21])

That is very valuable when debugging:

```text
BGP = UP

but

route = missing
```

---

# 36.139 Connection UP vs VIF UP vs BGP UP

Do NOT treat these as the same thing.

You can have:

```text
DX physical connection
        UP
```

but:

```text
VIF
DOWN
```

or:

```text
VIF Layer-2 connectivity
UP

BGP
DOWN
```

or:

```text
BGP
UP

Required route
MISSING
```

or even:

```text
Route present

Security Group blocks application.
```

Hence:

```text
Physical
   ↓
Ethernet/VLAN
   ↓
IP
   ↓
BGP
   ↓
Routes
   ↓
TGW
   ↓
VPC
   ↓
Security
   ↓
Application
```

Always troubleshoot layer by layer.

---

# 36.140 Example incident

Ticket:

> Oracle application in AWS cannot connect to Oracle database on-prem after network maintenance.

Architecture:

```text
AWS Prod
10.20.5.50

     │

TGW
     │
DXGW
     │
Transit VIF
     │
DX
     │

On-prem Oracle
10.10.50.20
```

Don't immediately blame Oracle.

Check:

```text
1. DX connection state

2. Transit VIF state

3. BGP session

4. Is 10.10.0.0/16 received?

5. PROD VPC route:
   10.10.0.0/16 → TGW

6. Prod-associated TGW RT:
   10.10.0.0/16 → DX/inspection path

7. On-prem route:
   10.20.0.0/16 → DX

8. Security Group

9. Firewall

10. Oracle listener
```

Maybe network maintenance caused:

```text
BGP MD5 mismatch
```

or:

```text
ASN changed
```

or:

```text
prefix no longer advertised
```

AWS's own Direct Connect troubleshooting guidance explicitly separates BGP-session issues from routing issues. ([AWS Documentation][12])

---

# 36.141 Site-to-Site VPN vs Direct Connect

Now you can properly compare them.

| Characteristic         | Site-to-Site VPN                   | Direct Connect                             |
| ---------------------- | ---------------------------------- | ------------------------------------------ |
| Transport              | IP network/commonly Internet       | Dedicated AWS connectivity                 |
| Encryption             | IPsec                              | Not automatic                              |
| Provisioning           | Fast                               | Physical/provider work involved            |
| Dedicated circuit      | No                                 | Yes                                        |
| BGP                    | Supported                          | Core routing mechanism                     |
| High bandwidth options | Available, but VPN-specific limits | Up to very high dedicated port speeds      |
| Backup use             | Excellent                          | Usually primary in many enterprise designs |
| Installation           | Mostly logical                     | Physical + logical                         |
| VIFs                   | No                                 | Yes                                        |
| DXGW                   | No                                 | Yes                                        |
| MACsec                 | No                                 | Supported DX option                        |
| TGW integration        | VPN attachment                     | Transit VIF → DXGW → TGW                   |

Don't conclude:

```text
VPN = bad

DX = good
```

Wrong.

The correct architecture question is:

```text
What are my:

bandwidth requirements?
latency/consistency requirements?
availability requirements?
encryption requirements?
cost constraints?
deployment timeline?
```

---

# 36.142 Often the answer is BOTH

Production architecture frequently looks like:

```text
                         ON-PREM

                            │
             ┌──────────────┴──────────────┐
             │                             │
             ▼                             ▼
      Direct Connect                  IPsec VPN
          PRIMARY                       BACKUP
             │                             │
             ▼                             ▼
            DXGW                          TGW
             │                             │
             └──────────────┬──────────────┘
                            ▼
                           TGW
                            │
                 ┌──────────┼──────────┐
                 ▼          ▼          ▼
               PROD        DEV       SHARED
```

More resilient environments might instead use multiple independent DX locations plus VPN as another contingency path. AWS explicitly recommends multiple connections/locations where higher availability is required. ([AWS Documentation][15])

---

# 36.143 Exam/interview scenario

Question:

> A company has 100 VPCs attached to Transit Gateway and needs dedicated connectivity from its data center to those VPCs. Which Direct Connect virtual interface should you use?

Your mental chain:

```text
100 VPCs
   ↓
TGW
   ↓
Direct Connect to TGW
   ↓
Transit VIF
   ↓
DXGW
```

Answer:

# Transit VIF via Direct Connect Gateway.

([AWS Documentation][22])

---

# 36.144 Another interview scenario

> Company needs access from on-prem to VPC private addresses through Direct Connect, without a TGW-centric architecture.

Think:

```text
Private IP
   ↓
VPC
   ↓
Private VIF
```

Answer:

# Private VIF.

([AWS Documentation][5])

---

# 36.145 Another interview scenario

> On-prem systems need AWS public service endpoints over Direct Connect.

Think:

```text
AWS public endpoint
      ↓
Public VIF
```

Answer:

# Public VIF.

([AWS Documentation][5])

---

# 36.146 Another interview trap

> Direct Connect is dedicated, therefore all traffic is encrypted.

Answer:

# FALSE.

Explain:

> Direct Connect provides dedicated connectivity, but encryption is a separate design decision. Supported architectures can use MACsec or IPsec/VPN-over-DX when encryption is required.

([AWS Documentation][13])

---

# 36.147 Another interview trap

> We have two Direct Connect connections in one LAG, therefore we're protected from Direct Connect location failure.

Answer:

# NO.

A LAG aggregates connections terminating in the applicable same DX endpoint/location design; it does not by itself give the geographic failure-domain diversity of using separate Direct Connect locations. ([AWS Documentation][19])

---

# 36.148 Another interview trap

> Which protocol dynamically exchanges network routes over Direct Connect?

Answer:

# BGP.

Not:

```text
OSPF
RIP
STP
ARP
```

BGP is the routing protocol used for Direct Connect VIF peerings. ([AWS Documentation][1])

---

# 36.149 Terraform preview

Physical DX provisioning has external carrier/facility dependencies, but AWS-side Direct Connect resources can be represented through Infrastructure as Code.

Conceptually:

```hcl
resource "aws_dx_gateway" "enterprise" {
  name            = "enterprise-dxgw"
  amazon_side_asn = 64512
}
```

Then:

```text
Transit Gateway
      │
      │ association
      ▼
DX Gateway
```

and:

```text
DX Connection
      │
      ▼
Transit VIF
      │
      ▼
DX Gateway
```

Later we'll build the Terraform modules around:

```text
aws_dx_gateway

Transit Gateway

DXGW ↔ TGW association

allowed prefixes

TGW route tables

VPN backup routes
```

But there's an important real-world limitation:

```text
Terraform cannot magically install
the physical carrier fiber.
```

The provider/cross-connect process still exists.

Infrastructure as Code manages the cloud-side configuration; it doesn't replace the physical telecommunications workflow.

---

# 36.150 Complete enterprise architecture

You should now understand this diagram:

```text
                           CORPORATE DATA CENTER
                               10.10.0.0/16

                         ┌─────────────────────┐
                         │ Corporate Routers   │
                         │ A              B    │
                         └─────┬──────────┬────┘
                               │          │
                    ┌──────────┘          └───────────┐
                    │                                 │
                    ▼                                 ▼
           DX LOCATION A                      DX LOCATION B
                    │                                 │
                    │ Direct Connect                  │ Direct Connect
                    │                                 │
                    └──────────────┬──────────────────┘
                                   │
                            Transit VIF(s)
                                   │
                                   ▼
                          DIRECT CONNECT
                              GATEWAY
                                   │
                                   ▼
                         ┌─────────────────┐
                         │ TRANSIT GATEWAY │
                         └────────┬────────┘
                                  │
          ┌───────────────────────┼────────────────────────┐
          │                       │                        │
          ▼                       ▼                        ▼
  INSPECTION VPC              PROD VPC                DEV VPC
    10.50/16                   10.20/16                10.30/16
       │                          │                       │
 Network Firewall                ECS                     EKS
       │                          │                       │
 Appliance Mode                  RDS                     RDS
          │
          │
          └───────────────┐
                          │
                          ▼
                    SHARED VPC
                     10.40/16
                          │
                ┌─────────┼─────────┐
                ▼         ▼         ▼
                AD       DNS      Jenkins


                    Backup Connectivity

Corporate Router
       │
       │ Internet
       ▼
Site-to-Site VPN
       │
       ▼
      TGW
```

Now we have:

```text
Direct Connect
        +
Transit Gateway
        +
BGP
        +
Segmentation
        +
Central Firewall
        +
VPN Backup
```

This is very close to what real large-enterprise AWS hybrid connectivity looks like.

---

# 36.151 Never-forget Direct Connect table

| Term                     | Meaning                                                          |
| ------------------------ | ---------------------------------------------------------------- |
| **DX**                   | AWS Direct Connect                                               |
| **DX Location**          | Facility where Direct Connect connectivity is available          |
| **Cross-connect**        | Facility physical connection to AWS equipment                    |
| **LOA-CFA**              | Authorization/facility-assignment document for the cross-connect |
| **Dedicated Connection** | Dedicated customer DX connection                                 |
| **Hosted Connection**    | DX Partner-provided connection                                   |
| **VIF**                  | Logical interface over Direct Connect                            |
| **Private VIF**          | Private VPC connectivity                                         |
| **Public VIF**           | AWS public service connectivity                                  |
| **Transit VIF**          | TGW connectivity through DXGW                                    |
| **DXGW**                 | Direct Connect Gateway                                           |
| **TGW**                  | Transit Gateway                                                  |
| **VLAN**                 | Layer-2 logical segmentation                                     |
| **802.1Q**               | VLAN tagging                                                     |
| **BGP**                  | Dynamic routing protocol                                         |
| **ASN**                  | BGP autonomous-system identifier                                 |
| **BGP Community**        | Route-policy metadata                                            |
| **AS_PATH**              | Autonomous systems traversed by BGP route                        |
| **LAG**                  | Aggregation of multiple dedicated DX links                       |
| **MACsec**               | Layer-2 encryption                                               |
| **IPsec**                | Layer-3 encryption                                               |
| **Allowed Prefixes**     | Controls DXGW/TGW-side route advertisement                       |
| **VPN backup**           | Alternative hybrid path if DX fails                              |

---

# 36.152 Five sentences to memorize

```text
1.

DIRECT CONNECT
provides the physical/dedicated AWS connectivity.


2.

A VIF determines what logical AWS connectivity
runs over that Direct Connect connection.


3.

PRIVATE VIF → think VPC.

PUBLIC VIF → think AWS public services.

TRANSIT VIF → think TGW.


4.

Transit VIF architecture:

DX → Transit VIF → DXGW → TGW → VPCs


5.

Direct Connect does NOT automatically mean encryption.
Use appropriate encryption such as MACsec or IPsec
when the security requirement demands it.
```

---

# 36.153 One final packet-flow exercise

When you see:

```text
10.10.5.50
      ↓
10.20.8.25
```

through enterprise DX, visualize:

```text
10.10.5.50
 Corporate Server
       │
       ▼
Corporate Route Table
       │
       ▼
Corporate Router
       │
       │ BGP route learned
       ▼
Carrier Circuit
       │
       ▼
DX Location
       │
       ▼
Cross Connect
       │
       ▼
AWS DX Connection
       │
       ▼
802.1Q VLAN
       │
       ▼
Transit VIF
       │
       ▼
DXGW
       │
       ▼
TGW
       │
       ▼
TGW Route Table
       │
       ▼
Prod Attachment
       │
       ▼
Prod VPC
       │
       ▼
Security Group
       │
       ▼
10.20.8.25
```

And then mentally reverse **the entire path** for the response.

That is how you troubleshoot hybrid connectivity like an engineer rather than treating Direct Connect as a mysterious AWS service.

---

# Next — Lesson 36, Part 4

## Resilient Hybrid Routing: BGP Path Selection, DX + VPN Failover & Active/Active Architecture

Now we know the individual components.

Next we need to answer the real production question:

```text
Both Direct Connect and VPN exist.

Which one does traffic actually use?
```

We're going to build:

```text
                       ON-PREM
                          │
               ┌──────────┴──────────┐
               │                     │
               ▼                     ▼
          DX PRIMARY             DX SECONDARY
               │                     │
               └─────────┬───────────┘
                         │
                         ▼
                        AWS

                          +

                    VPN BACKUP
```

Then we'll go deep into **BGP path selection, longest-prefix match, local preference, AS_PATH prepending, BGP communities, active/active vs active/passive, ECMP, BFD, failure detection, DX location failure, router failure, VPN failover, route convergence, asymmetric routing, route leaks, and production resilient architecture**.

After that we'll cover **VPN-over-DX/private-IP VPN, Route 53 Resolver hybrid DNS, multi-account networking, Terraform implementation, monitoring/troubleshooting, and finally the complete on-premises ↔ AWS enterprise hybrid-cloud lab.**

[1]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html?utm_source=chatgpt.com "What is Direct Connect?"
[2]: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-direct-connect-aws-transit-gateway.html?utm_source=chatgpt.com "AWS Direct Connect + AWS Transit Gateway"
[3]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/Colocation.html?utm_source=chatgpt.com "Requesting cross connects at Direct Connect locations"
[4]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/download-loa-cfa.html?utm_source=chatgpt.com "Download the Direct Connect LOA-CFA - AWS Documentation"
[5]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/WorkingWithVirtualInterfaces.html?utm_source=chatgpt.com "Direct Connect virtual interfaces and hosted virtual interfaces"
[6]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/dedicated_connection.html?utm_source=chatgpt.com "Dedicated Direct Connect connections - AWS Documentation"
[7]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/hosted_connection.html?utm_source=chatgpt.com "Hosted Direct Connect connections"
[8]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/limits.html?utm_source=chatgpt.com "Direct Connect quotas"
[9]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-transit-gateways.html?utm_source=chatgpt.com "Direct Connect gateways and Transit Gateway associations"
[10]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-gateways-intro.html?utm_source=chatgpt.com "Direct Connect gateways"
[11]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/devtest-resiliency-set-up.html?utm_source=chatgpt.com "Configure AWS Direct Connect for development and test ..."
[12]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/ts-layer-3.html?utm_source=chatgpt.com "Troubleshoot layer 3/4 (Network/Transport) issues"
[13]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/MACsec.html?utm_source=chatgpt.com "MAC Security in Direct Connect - AWS Documentation"
[14]: https://docs.aws.amazon.com/wellarchitected/latest/hybrid-networking-lens/aws-direct-connect-and-ipsec-vpn.html?utm_source=chatgpt.com "AWS Direct Connect and IPSec VPN"
[15]: https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html?utm_source=chatgpt.com "REL02-BP02 Provision redundant connectivity between ..."
[16]: https://docs.aws.amazon.com/whitepapers/latest/hybrid-connectivity/reliability.html?utm_source=chatgpt.com "Reliability - Hybrid Connectivity"
[17]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/disaster-recovery-resiliency.html?utm_source=chatgpt.com "Resilience in AWS Direct Connect"
[18]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/routing-and-bgp.html?utm_source=chatgpt.com "Direct Connect routing policies and BGP communities"
[19]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/lags.html?utm_source=chatgpt.com "Direct Connect link aggregation groups (LAGs)"
[20]: https://docs.aws.amazon.com/whitepapers/latest/hybrid-connectivity/performance.html?utm_source=chatgpt.com "Performance - Hybrid Connectivity"
[21]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/bgp-route-visibility.html?utm_source=chatgpt.com "BGP route visibility - AWS Direct Connect"
[22]: https://docs.aws.amazon.com/directconnect/latest/APIReference/API_CreateTransitVirtualInterface.html?utm_source=chatgpt.com "CreateTransitVirtualInterface - Direct Connect"
