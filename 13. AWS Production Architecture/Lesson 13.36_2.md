# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 2: AWS Transit Gateway Deep Dive

We finished Part 1 with:

```text
On-Premises
     │
     │ Site-to-Site VPN
     ▼
    VGW
     │
     ▼
 One VPC
```

That works beautifully when the environment is small.

But now imagine the organization grows to:

```text
                 Corporate Data Center
                       10.10.0.0/16

        Prod AWS Account
        Dev AWS Account
        QA AWS Account
        Security AWS Account
        Shared Services Account
        Analytics Account
        ML Account

        30–100+ VPCs
```

Creating separate VPNs and complex VPC peering between everything quickly becomes difficult to operate.

This is exactly the class of problem **AWS Transit Gateway — TGW** is designed to solve. AWS describes Transit Gateway as a network transit hub for connecting VPCs and on-premises networks. ([AWS Documentation][1])

---

# 36.26 First: the Transit Gateway mental model

Think of Transit Gateway as a:

# Cloud Router / Network Transit Hub

Instead of this:

```text
                     VPC-A
                    /
On-Prem ───── VPC-B
                    \
                     VPC-C
```

or a VPC-peering mesh:

```text
         VPC-A ───────── VPC-B
           │   \        /   │
           │     \    /     │
           │       \/       │
           │       /\       │
           │     /    \     │
           │   /        \   │
         VPC-C ───────── VPC-D
```

we create:

```text
                 ┌─────────────────┐
                 │ Transit Gateway │
                 │      TGW        │
                 └────────┬────────┘
                          │
        ┌─────────────────┼────────────────┐
        │                 │                │
        ▼                 ▼                ▼
     Prod VPC          Dev VPC        Shared VPC
```

Add on-premises:

```text
                      CORPORATE DC
                       10.10.0.0/16
                             │
                            VPN
                             │
                             ▼
                    ┌────────────────┐
                    │ Transit Gateway│
                    └───────┬────────┘
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
           PROD            DEV          SHARED
       10.20.0.0/16    10.30.0.0/16   10.40.0.0/16
```

Much cleaner.

---

# 36.27 What Transit Gateway is NOT

This is important.

TGW is not:

```text
❌ Another VPC
❌ An Internet Gateway
❌ A NAT Gateway
❌ A load balancer
❌ A firewall by itself
❌ A VPN by itself
```

Its primary job is:

```text
Receive packet
      ↓
Examine destination
      ↓
Consult TGW route table
      ↓
Choose another attachment
      ↓
Forward packet
```

AWS Transit Gateway routes IPv4 and IPv6 packets between its attachments using Transit Gateway route tables. ([AWS Documentation][2])

Never-forget shortcut:

```text
VPC Route Table
     =
"How do I leave this VPC?"


TGW Route Table
     =
"Once I reach TGW, where do I go next?"
```

This distinction is absolutely critical.

---

# 36.28 The most important TGW concept: Attachment

A Transit Gateway doesn't magically connect to a VPC.

You create an:

# Transit Gateway Attachment

Conceptually:

```text
VPC
 │
 │ Attachment
 ▼
TGW
```

Example:

```text
Prod VPC
10.20.0.0/16
      │
      │ tgw-attach-prod
      │
      ▼
Transit Gateway
```

For multiple networks:

```text
                      TGW
                       │
       ┌───────────────┼───────────────┐
       │               │               │
     attach          attach          attach
       │               │               │
       ▼               ▼               ▼
    Prod VPC         Dev VPC       Shared VPC
```

Transit Gateway supports several attachment types, including VPC, Site-to-Site VPN, Direct Connect gateway, peering, Connect, and other supported attachment types. ([AWS Documentation][3])

So eventually:

```text
                           TGW
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
    VPC Attachment    VPN Attachment    DXGW Attachment
          │                 │                 │
          ▼                 ▼                 ▼
        VPC            On-Prem VPN       Direct Connect
```

---

# 36.29 VPC attachment — what actually gets created?

Suppose:

```text
Prod VPC
10.20.0.0/16

AZ-a
├── Public subnet
├── App subnet
└── DB subnet

AZ-b
├── Public subnet
├── App subnet
└── DB subnet
```

When creating a TGW VPC attachment, you select subnets that TGW will use.

AWS allows one attachment subnet per Availability Zone for a VPC attachment. ([AWS Documentation][4])

For example:

```text
                 PROD VPC
             10.20.0.0/16

       AZ-A                     AZ-B
         │                        │
         │                        │
 TGW Subnet A                TGW Subnet B
 10.20.250.0/28              10.20.250.16/28
         │                        │
         └─────────┬──────────────┘
                   │
                   ▼
             TGW Attachment
                   │
                   ▼
                  TGW
```

Using small dedicated TGW attachment subnets is a common clean architecture, although dedicated subnets are an architectural choice rather than a requirement.

AWS creates Transit Gateway network interfaces in the attachment subnets used by the VPC attachment. Traffic from VPC subnets also needs appropriate VPC route-table entries to reach the TGW. ([AWS Documentation][5])

---

# 36.30 You now have TWO routing layers

This is where many people get confused.

Suppose:

```text
Prod VPC
10.20.0.0/16

Dev VPC
10.30.0.0/16
```

We want:

```text
10.20.1.50
     ↓
10.30.2.60
```

There are two major routing decisions.

## Routing decision #1 — VPC route table

Inside Prod:

```text
Destination       Target

10.20.0.0/16      local
10.30.0.0/16      tgw-123456
```

That says:

> To reach Dev, send traffic to TGW.

AWS requires an appropriate route in the VPC subnet route table to send traffic through Transit Gateway. ([AWS Documentation][2])

Then TGW receives it.

But TGW asks:

> Okay... which attachment should I use?

That's routing decision #2.

---

# 36.31 TGW route table

Transit Gateway has its own routing tables.

Example:

```text
TGW ROUTE TABLE

Destination         Target

10.20.0.0/16        Prod Attachment
10.30.0.0/16        Dev Attachment
10.40.0.0/16        Shared Attachment
10.10.0.0/16        VPN Attachment
```

So:

```text
Packet destination:

10.30.2.60
```

TGW looks up:

```text
10.30.0.0/16 → Dev Attachment
```

and forwards the packet.

Transit Gateway route tables contain static and/or propagated routes pointing toward attachments. ([AWS Documentation][2])

---

# 36.32 Full packet journey: Prod → Dev

Let's follow one packet.

Source:

```text
Prod EC2
10.20.1.50
```

Destination:

```text
Dev EC2
10.30.2.60
```

Architecture:

```text
Prod EC2
10.20.1.50
     │
     ▼
Prod VPC Route Table
10.30.0.0/16 → TGW
     │
     ▼
Prod TGW Attachment
     │
     ▼
Transit Gateway
     │
     ▼
TGW Route Table
10.30.0.0/16 → Dev Attachment
     │
     ▼
Dev TGW Attachment
     │
     ▼
Dev VPC
     │
     ▼
10.30.2.60
```

And then:

```text
RETURN PACKET

Dev
 │
Dev Route Table
 │
TGW
 │
TGW Route Table
 │
Prod Attachment
 │
Prod
```

Same lesson from VPN:

# Forward path + return path.

---

# 36.33 TGW Route Association vs Route Propagation

This is probably the single most important Transit Gateway concept.

Students constantly mix these two up.

They are completely different.

---

## Association

Association answers:

# "Which TGW route table should packets arriving FROM this attachment use?"

Example:

```text
Prod Attachment
      │
      ▼
Associated with
      │
      ▼
PROD-TGW-RT
```

So when traffic arrives:

```text
Prod VPC → TGW
```

TGW consults:

```text
PROD-TGW-RT
```

In standard TGW route-table operation, an attachment uses one associated TGW route table for its routing lookup, while a route table can serve multiple attachments. ([AWS Documentation][2])

Memory trick:

# Association = INPUT decision.

```text
Traffic enters FROM where?
           ↓
Which route table should TGW consult?
```

---

# 36.34 Propagation

Propagation answers:

# "Into which TGW route tables should this attachment advertise/install its reachable prefixes?"

Suppose:

```text
Shared VPC
10.40.0.0/16
```

Its attachment can propagate:

```text
10.40.0.0/16
```

into:

```text
Prod TGW Route Table

and

Dev TGW Route Table
```

AWS permits an attachment's routes to be propagated into one or more TGW route tables. For a VPC attachment, the VPC's CIDR blocks can be propagated. ([AWS Documentation][2])

So:

```text
Shared Attachment
        │
        ├──── propagate ───→ PROD-RT
        │
        └──── propagate ───→ DEV-RT
```

Memory trick:

# Propagation = ROUTE ADVERTISEMENT.

---

# 36.35 Association vs Propagation — never forget this

```text
                   ATTACHMENT
                       │
          ┌────────────┴────────────┐
          │                         │
    ASSOCIATION                PROPAGATION
          │                         │
          ▼                         ▼
 Which table does             Which tables
 incoming traffic             learn my routes?
 consult?
```

Or even simpler:

```text
Association
   =
"Which table do I READ?"


Propagation
   =
"Which tables do I WRITE my routes into?"
```

That shortcut will help tremendously.

---

# 36.36 Example with Prod + Dev + Shared

Let's build a realistic architecture.

```text
                              TGW
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
       PROD VPC             DEV VPC            SHARED VPC
     10.20.0.0/16        10.30.0.0/16         10.40.0.0/16

                                                    │
                                              Active Directory
                                              DNS
                                              Monitoring
                                              Jenkins
                                              Security tools
```

Requirement:

```text
Prod → Shared       YES
Dev  → Shared       YES

Prod → Dev          NO
Dev  → Prod         NO
```

How can TGW enforce that?

# Multiple TGW route tables.

---

# 36.37 TGW segmentation

Create:

```text
PROD-RT

DEV-RT

SHARED-RT
```

Associate:

```text
Prod Attachment
      ↓
PROD-RT


Dev Attachment
      ↓
DEV-RT


Shared Attachment
      ↓
SHARED-RT
```

Now propagate Shared into both:

```text
Shared
  │
  ├────→ PROD-RT
  │
  └────→ DEV-RT
```

Therefore:

### PROD-RT

```text
Destination         Target

10.40.0.0/16        Shared Attachment
```

Notice:

```text
10.30.0.0/16
```

is absent.

Therefore Prod cannot route to Dev through TGW.

---

### DEV-RT

```text
Destination         Target

10.40.0.0/16        Shared Attachment
```

Notice:

```text
10.20.0.0/16
```

is absent.

Therefore Dev cannot route to Prod.

---

### SHARED-RT

Shared must return traffic to both environments:

```text
Destination         Target

10.20.0.0/16        Prod Attachment
10.30.0.0/16        Dev Attachment
```

Now:

```text
Prod ↔ Shared
```

works.

And:

```text
Dev ↔ Shared
```

works.

But:

```text
Prod ✕ Dev
```

remains isolated.

This is one of the major reasons multiple TGW route tables are useful: AWS explicitly supports isolated routing domains by associating different attachment groups with different route tables. ([AWS Documentation][2])

---

# 36.38 Enterprise segmentation example

Now let's make this more realistic.

```text
                    ┌─────────────────┐
                    │ Transit Gateway │
                    └────────┬────────┘
                             │
        ┌────────────────────┼───────────────────┐
        │                    │                   │
        ▼                    ▼                   ▼
      PROD                  DEV              SECURITY
   10.20.0.0/16        10.30.0.0/16        10.50.0.0/16
                                                 │
                                                 │
                                           AWS Network
                                             Firewall
```

Plus:

```text
On-Prem
10.10.0.0/16
```

Business policy:

```text
Prod → Security       YES
Dev → Security        YES

Prod → On-Prem        YES

Dev → On-Prem         MAYBE

Prod → Dev            NO

Dev → Prod            NO
```

TGW route tables become your routing segmentation mechanism.

---

# 36.39 Blackhole routes

Transit Gateway supports:

# Blackhole Routes

A blackhole route says:

```text
If destination matches this route
          ↓
DROP THE PACKET
```

For example:

```text
PROD-TGW-RT

Destination        Target

10.30.0.0/16       blackhole
```

Then even if some broader route exists:

```text
10.0.0.0/8 → something
```

the more-specific route:

```text
10.30.0.0/16 → blackhole
```

wins.

AWS TGW route tables support explicit blackhole routes for intentionally dropping matching traffic. ([AWS Documentation][2])

This can provide strong routing guardrails.

But remember:

```text
TGW blackhole
     =
routing-level isolation
```

It is not a substitute for:

```text
Security Groups
Firewall
IAM
Application authorization
```

Defense in depth still matters.

---

# 36.40 Longest prefix match still matters

Suppose TGW contains:

```text
10.0.0.0/8         → VPN

10.30.0.0/16       → Dev Attachment
```

Destination:

```text
10.30.5.10
```

Both routes match.

But:

```text
/16
```

is more specific than:

```text
/8
```

Therefore:

```text
10.30.0.0/16
```

wins.

This is fundamental routing behavior and also the first stage in TGW route evaluation. ([AWS Documentation][2])

Never forget:

```text
MORE SPECIFIC CIDR
        =
HIGHER ROUTING PREFERENCE
```

Example:

```text
/32 > /24 > /16 > /8 > /0
```

for destination specificity.

---

# 36.41 Static routes vs propagated routes in TGW

TGW route tables may contain:

```text
Static routes
      +
Propagated routes
```

Example:

```text
10.20.0.0/16 → Prod Attachment
               propagated


10.10.0.0/16 → VPN Attachment
               BGP propagated


0.0.0.0/0 → Security Attachment
             static
```

For identical destination prefixes, AWS defines route evaluation priorities; static routes have priority over propagated routes for the same destination. ([AWS Documentation][2])

Example:

```text
10.10.0.0/16 → VPN-A     propagated

10.10.0.0/16 → VPN-B     static
```

The static route has priority for that identical prefix.

But always remember:

```text
Longest-prefix match
```

comes first.

---

# 36.42 TGW + Site-to-Site VPN

Now connect our Part 1 knowledge.

Earlier:

```text
On-Prem
   │
VPN
   │
VGW
   │
VPC
```

Now:

```text
                  Corporate DC
                   10.10.0.0/16
                         │
                    VPN Router
                         │
                  IPsec Tunnel(s)
                         │
                         ▼
                 ┌────────────────┐
                 │ Transit Gateway│
                 └───────┬────────┘
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
         PROD           DEV          SHARED
```

Here the Site-to-Site VPN terminates against Transit Gateway rather than an individual VPC's VGW.

Transit Gateway VPN attachments support both static and BGP-based dynamic VPN connectivity. ([AWS Documentation][6])

Now on-premises can potentially reach many VPCs through one central routing hub.

---

# 36.43 Example BGP propagation

On-prem router:

```text
ASN 65000

Advertises:

10.10.0.0/16
10.11.0.0/16
10.12.0.0/16
```

VPN attachment receives these through BGP.

Conceptually:

```text
Corporate Router
     │
     │ BGP
     ▼
VPN Attachment
     │
     │ Propagation
     ▼
TGW Route Table
```

Result:

```text
10.10.0.0/16 → VPN attachment
10.11.0.0/16 → VPN attachment
10.12.0.0/16 → VPN attachment
```

With dynamic VPN routing, routes learned through BGP can propagate from the VPN attachment into selected TGW route tables. ([AWS Documentation][2])

---

# 36.44 On-prem → Prod packet flow

Let's trace a real packet.

```text
Corporate Laptop/Server

10.10.5.50
```

needs:

```text
Prod application
10.20.2.100
```

Architecture:

```text
10.10.5.50
    │
    ▼
Corporate Router
    │
10.20.0.0/16 → VPN
    │
    ▼
IPsec VPN
    │
    ▼
VPN Attachment
    │
    ▼
Transit Gateway
    │
    ▼
TGW route table associated
with VPN attachment
    │
10.20.0.0/16
→ Prod Attachment
    │
    ▼
Prod Attachment
    │
    ▼
Prod VPC
    │
    ▼
10.20.2.100
```

But for this to work, we need ALL of these:

```text
Corporate route
      ✓

VPN/BGP
      ✓

TGW route
      ✓

Prod VPC routes
      ✓

Security Group
      ✓

NACL
      ✓

OS/application
      ✓

RETURN ROUTE
      ✓
```

The same troubleshooting principle continues.

---

# 36.45 One subtle point: TGW attachment subnet

Suppose Prod VPC:

```text
AZ-A

App subnet
10.20.1.0/24

TGW subnet
10.20.250.0/28
```

When app traffic leaves:

```text
App
 ↓
App subnet route table
 ↓
TGW target
```

TGW attachment infrastructure exists through the selected attachment subnet for that AZ.

AWS requires that traffic use an Availability Zone where the VPC has an attachment subnet, and the involved subnet route tables must contain the appropriate routes. ([AWS Documentation][5])

This is why a production VPC frequently looks like:

```text
                    PROD VPC
                  10.20.0.0/16

            AZ-A                 AZ-B

       Public-A              Public-B
          │                     │

       Private-A             Private-B
          │                     │

         DB-A                  DB-B
          │                     │

      TGW-Subnet-A          TGW-Subnet-B
          │                     │
          └─────────┬───────────┘
                    │
                    ▼
                   TGW
```

---

# 36.46 TGW high availability

You might ask:

> Should I deploy one TGW per Availability Zone?

No.

Transit Gateway itself is an AWS-managed, highly available regional service. AWS specifically recommends that you do not create extra TGWs merely to obtain intra-Region high availability. ([AWS Documentation][7])

Instead, design attachments across multiple AZs where appropriate:

```text
TGW
 │
 ├── attachment subnet AZ-A
 │
 └── attachment subnet AZ-B
```

So think:

```text
ALB
→ multi-AZ

NAT Gateway
→ normally one per AZ for resilient design

TGW
→ regional managed transit service
```

Different services have different HA architectures.

---

# 36.47 Multi-account architecture

Now suppose:

```text
AWS Organization

Management
│
├── Networking Account
├── Security Account
├── Prod Account
├── Dev Account
├── QA Account
└── Shared Services Account
```

Where should TGW live?

A common enterprise model is:

```text
NETWORKING ACCOUNT
      │
      └── Transit Gateway
```

Then other accounts attach VPCs.

How?

# AWS Resource Access Manager — RAM

AWS RAM allows a Transit Gateway to be shared across accounts or across an AWS Organization. ([AWS Documentation][8])

Architecture:

```text
                     AWS ORGANIZATION

                  NETWORK ACCOUNT
                        │
                Transit Gateway
                        │
            Shared using AWS RAM
                        │
       ┌────────────────┼────────────────┐
       │                │                │
       ▼                ▼                ▼
 PROD ACCOUNT       DEV ACCOUNT     SHARED ACCOUNT
    VPC                 VPC               VPC
```

Now the networking team controls:

```text
TGW
TGW route tables
VPN
Direct Connect
central network architecture
```

while application teams control:

```text
Their VPC
Their EC2
Their EKS
Their ECS
Their application
```

That's a much more realistic enterprise ownership model.

---

# 36.48 Central networking account mental model

Imagine:

```text
Account 111111
Network Team
```

owns:

```text
Transit Gateway
VPN
DXGW
inspection architecture
central networking
```

Prod account:

```text
Account 222222

Prod VPC
10.20.0.0/16
```

Dev:

```text
Account 333333

Dev VPC
10.30.0.0/16
```

Shared:

```text
Account 444444

Shared VPC
10.40.0.0/16
```

Result:

```text
                    Networking Account

                      Transit Gateway
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          │ AWS RAM         │ AWS RAM         │ AWS RAM
          ▼                 ▼                 ▼
    Prod Account       Dev Account        Shared Account
         │                  │                  │
       Prod VPC           Dev VPC          Shared VPC
```

This is far more scalable organizationally than giving every account its own unrelated hybrid network.

---

# 36.49 TGW route tables become security zones

Now we can create:

```text
PROD-RT
NONPROD-RT
SHARED-RT
ONPREM-RT
SECURITY-RT
```

Conceptually:

```text
                         TGW

            ┌─────────────┼──────────────┐
            │             │              │
          PROD        NON-PROD       SHARED
            │             │              │
      Prod accounts    Dev/QA       AD/DNS/Tools
```

This resembles classic enterprise networking:

```text
Routing domains
VRFs
Network zones
Segmentation
```

Not identical to a traditional VRF implementation, but the mental model is useful:

> Separate TGW route tables can behave like separate routing domains.

AWS explicitly documents using multiple TGW route tables to isolate sets of attachments. ([AWS Documentation][2])

---

# 36.50 Centralized egress

Now here's an advanced production pattern.

Suppose we have 50 VPCs.

Do we really want:

```text
50 × NAT architecture
50 × separate egress policies
50 × firewall stacks
```

Sometimes yes.

But sometimes enterprises want centralized egress.

Architecture:

```text
     Prod VPC
         │
         │ 0.0.0.0/0
         ▼
        TGW
         │
         ▼
    Egress VPC
         │
      Firewall
         │
    NAT Gateway
         │
        IGW
         │
      Internet
```

For multiple VPCs:

```text
 Prod ─────┐
 Dev ──────┤
 QA ───────┤
 Analytics ├────→ TGW
 ML ───────┘       │
                   ▼
               Egress VPC
                   │
               Firewall
                   │
               NAT Gateway
                   │
                   ▼
                Internet
```

Now outbound controls can be centralized.

---

# 36.51 Why centralized inspection?

Imagine security says:

> Every packet between Prod, Dev, on-prem and the Internet must be inspected.

You can build a:

# Security / Inspection VPC

```text
                         TGW
                          │
                          ▼
                   Inspection VPC
                          │
                 AWS Network Firewall
                    or third-party
                       firewall
```

Then route traffic through it.

For example:

```text
Prod
 │
 ▼
TGW
 │
 ▼
Inspection VPC
 │
 ▼
Firewall
 │
 ▼
TGW
 │
 ▼
On-Prem
```

Or:

```text
Prod
 │
TGW
 │
Firewall
 │
NAT
 │
Internet
```

This introduces a very important networking concept:

# Stateful inspection.

---

# 36.52 What does stateful mean?

Suppose:

```text
Prod
10.20.1.50
```

opens:

```text
TCP connection
```

to:

```text
10.10.5.50
```

Firewall sees:

```text
10.20.1.50:53120
       →
10.10.5.50:443
```

It stores connection state.

When response comes:

```text
10.10.5.50:443
       →
10.20.1.50:53120
```

the same stateful firewall path needs to recognize that flow.

If forward traffic hits:

```text
Firewall AZ-A
```

but return traffic hits:

```text
Firewall AZ-B
```

some stateful appliances may see:

```text
UNKNOWN CONNECTION
```

and drop it.

That's an:

# Asymmetric routing problem.

---

# 36.53 Asymmetric routing

Normal desired flow:

```text
CLIENT
  │
  ▼
Firewall A
  │
  ▼
SERVER


SERVER
  │
  ▼
Firewall A
  │
  ▼
CLIENT
```

Same stateful path.

Bad case:

```text
Forward:

CLIENT
  │
Firewall A
  │
SERVER


Return:

SERVER
  │
Firewall B
  │
CLIENT
```

Firewall B may not know about the session created through Firewall A.

Result:

```text
Dropped connection
Intermittent timeout
Broken TCP sessions
Very painful troubleshooting
```

And now we reach:

# TGW Appliance Mode.

---

# 36.54 Appliance Mode

When a VPC contains a stateful network appliance, the TGW VPC attachment can use:

# Appliance Mode Support

AWS documents appliance mode as maintaining the same Availability Zone for a traffic flow through the appliance VPC for the lifetime of that flow, which is important for stateful inspection. ([AWS Documentation][2])

Architecture:

```text
                    Inspection VPC

                  AZ-A          AZ-B

                Firewall-A    Firewall-B
                    │             │
                    └──────┬──────┘
                           │
                     TGW Attachment

                     Appliance Mode
                         ENABLED
```

Think:

```text
Without appliance mode

forward path → AZ-A
return path  → potentially different AZ/path


With appliance mode

flow affinity is maintained
for the appliance VPC attachment
```

AWS Network Firewall multi-AZ TGW architectures use appliance-mode concepts for stateful traffic inspection. ([AWS Documentation][9])

---

# 36.55 Appliance mode never-forget rule

Whenever you hear:

```text
TGW
+
stateful firewall
+
multiple AZs
```

immediately think:

# Appliance Mode

Interview question:

> Why is Transit Gateway appliance mode required?

Strong answer:

> It provides flow/AZ affinity for traffic traversing a VPC containing stateful appliances so that bidirectional flows can be inspected consistently instead of being routed asymmetrically across appliance paths.

That is much stronger than saying:

> "It's for firewalls."

---

# 36.56 Centralized inspection architecture

Here's a proper mental model:

```text
                  CORPORATE DC
                       │
                      VPN
                       │
                       ▼
                      TGW
                       │
               ┌───────┴─────────┐
               │                 │
               ▼                 ▼
          Inspection VPC       Workloads
               │
        Network Firewall
               │
        Appliance Mode
```

But logically we route:

```text
On-prem
   │
   ▼
TGW
   │
   ▼
Inspection VPC
   │
Firewall
   │
   ▼
TGW
   │
   ▼
Prod
```

TGW route tables are deliberately configured to steer traffic through the security attachment instead of directly between the source and destination.

---

# 36.57 Why route tables are so powerful here

Suppose:

```text
Prod → On-prem
```

If Prod route table says:

```text
10.10.0.0/16 → VPN
```

then firewall is bypassed.

Instead we may design:

```text
PROD-TGW-RT

10.10.0.0/16
      ↓
Inspection Attachment
```

Then inspection-side routing sends it onward toward VPN.

Conceptually:

```text
Prod
 ↓
TGW
 ↓
Security VPC
 ↓
Firewall
 ↓
TGW
 ↓
VPN
 ↓
On-Prem
```

This is:

# Service insertion / traffic steering.

---

# 36.58 ECMP — another enterprise concept

Now imagine:

```text
On-Prem
   │
multiple VPN paths
   │
TGW
```

Transit Gateway supports **Equal Cost Multi-Path — ECMP** for suitable VPN designs. AWS specifically supports ECMP for dynamic-routing Site-to-Site VPN connections on Transit Gateway; static-routing VPN connections do not get that ECMP behavior. ([AWS Documentation][10])

ECMP means:

```text
Same destination
Same routing cost
Multiple available paths
```

Example:

```text
                    TGW
                  /     \
                 /       \
           Tunnel A     Tunnel B
              │            │
              └─────┬──────┘
                    │
                  On-Prem
```

Traffic can potentially use equal-cost paths instead of having one path sit completely unused.

This is particularly important for:

```text
Resilience
+
aggregate VPN capacity
```

depending on the VPN configuration.

---

# 36.59 Important 2026 VPN note

AWS now documents **Large Bandwidth Tunnels** for Site-to-Site VPN connections attached to Transit Gateway or Cloud WAN, supporting up to **5 Gbps per tunnel**, compared with the standard **1.25 Gbps** tunnel class. ([AWS Documentation][11])

This is a good example of why we don't memorize:

```text
"AWS VPN always means 1.25 Gbps forever."
```

Service capabilities evolve.

For architecture interviews, however, the fundamental lesson remains:

```text
VPN
→ encrypted connectivity

TGW + BGP/ECMP
→ scalable VPN routing/resilience options

Direct Connect
→ dedicated connectivity option
```

We'll compare those carefully in the Direct Connect lesson.

---

# 36.60 Overlapping CIDRs — enterprise nightmare

Imagine:

```text
Prod VPC
10.20.0.0/16
```

and another acquired company has:

```text
Legacy VPC
10.20.0.0/16
```

Now TGW receives:

```text
Destination:
10.20.5.50
```

Which VPC is it?

That's ambiguous.

AWS Transit Gateway does not route normally between attached VPCs with identical or overlapping CIDRs; if a new VPC attachment overlaps an already attached VPC's CIDR, its routes aren't propagated into the TGW route table as normal. ([AWS Documentation][5])

This is why:

# IP Address Management matters enormously.

Before building hybrid cloud:

```text
Corporate IP ranges
AWS VPC ranges
Branch ranges
VPN ranges
Acquired-company ranges
Other cloud ranges
```

must be planned.

Later we'll discuss:

```text
AWS VPC IPAM
```

in broader enterprise network governance.

---

# 36.61 Bad architecture

Imagine someone creates:

```text
VPC1 = 10.0.0.0/16

VPC2 = 10.0.0.0/16

VPC3 = 10.0.0.0/16
```

because:

> "They're in different accounts so it's fine."

Then six months later:

> "Connect everything through TGW."

Now you have a major networking problem.

Always think ahead:

```text
CIDR allocation
      ↓
future connectivity
      ↓
future mergers
      ↓
hybrid networking
      ↓
multi-region
```

Network architecture begins before the first EC2 instance is launched.

---

# 36.62 Transit Gateway Peering

What if we have:

```text
Mumbai
ap-south-1
```

and:

```text
Singapore
ap-southeast-1
```

Each Region may have its own TGW:

```text
Mumbai TGW

Singapore TGW
```

They can be connected with:

# Transit Gateway Peering

```text
              Mumbai

       Prod ───────┐
       Dev ────────┤
                   ▼
               Mumbai TGW
                    │
                    │ TGW Peering
                    │
               Singapore TGW
                   ▲
       Analytics ──┤
       DR ─────────┘

              Singapore
```

AWS supports both same-Region and inter-Region TGW peering; TGW peering route tables use static routes pointing toward the peering attachment. ([AWS Documentation][12])

Example:

```text
Mumbai TGW Route Table

10.80.0.0/16
     →
Singapore TGW Peering Attachment
```

---

# 36.63 TGW peering vs VPC peering

Don't confuse these.

## VPC Peering

```text
VPC A
  │
  │ direct peering
  │
VPC B
```

Good for:

```text
small number of direct VPC relationships
```

---

## TGW

```text
             TGW
          /   |   \
       VPC   VPC   VPC
```

Better suited for:

```text
large hub-and-spoke networks
hybrid networking
central routing
segmentation
multi-account architecture
```

---

## TGW Peering

```text
TGW-A
  │
  │ peering
  │
TGW-B
```

Connects two transit domains.

---

# 36.64 VPC Peering scaling problem

Suppose:

```text
3 VPCs
```

Full mesh requires:

```text
3 peerings
```

With:

```text
10 VPCs
```

potential full mesh:

```text
45 peer relationships
```

Because mathematically:

```text
n(n-1)
──────
  2
```

For 100 VPCs:

```text
100 × 99
────────
    2

= 4950
```

potential pairwise connections.

TGW changes the connectivity model toward:

```text
100 VPCs
     ↓
100 hub attachments
```

rather than maintaining a full mesh.

That doesn't mean TGW is always automatically superior—it has cost, routing, and architecture tradeoffs—but its operational model is far more suited to many large hub-and-spoke environments.

---

# 36.65 Production route-table example

Let's build our enterprise architecture.

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

Architecture:

```text
                       On-Prem
                     10.10.0.0/16
                           │
                          VPN
                           │
                           ▼
                   ┌───────────────┐
                   │      TGW      │
                   └───────┬───────┘
                           │
        ┌──────────┬───────┼───────┬──────────┐
        │          │       │       │          │
        ▼          ▼       ▼       ▼          ▼
      PROD        DEV    SHARED  SECURITY     VPN
```

---

# 36.66 PROD route table

Associated with:

```text
Prod attachment
```

Routes:

```text
10.40.0.0/16 → Shared
10.50.0.0/16 → Security
10.10.0.0/16 → Security
10.30.0.0/16 → BLACKHOLE
```

Meaning:

```text
Prod → Shared       YES
Prod → Security     YES

Prod → OnPrem
must pass Security

Prod → Dev          NO
```

---

# 36.67 DEV route table

```text
10.40.0.0/16 → Shared
10.50.0.0/16 → Security

10.20.0.0/16 → BLACKHOLE
```

Meaning:

```text
Dev → Shared      YES
Dev → Security    YES

Dev → Prod        NO
```

---

# 36.68 Security route table

Associated with inspection attachment.

It could contain reachability toward:

```text
10.20.0.0/16 → Prod
10.30.0.0/16 → Dev
10.40.0.0/16 → Shared
10.10.0.0/16 → VPN
```

The security path therefore acts as the controlled transit point.

---

# 36.69 On-prem route table

VPN attachment can have its own association.

Example:

```text
10.20.0.0/16 → Security
10.40.0.0/16 → Shared/Security depending on policy
10.30.0.0/16 → BLACKHOLE
```

Maybe corporate users may reach Prod but should never reach Dev.

Routing enforces that design at the transit layer.

---

# 36.70 Packet walk: Prod → On-prem via Firewall

Source:

```text
Prod EC2

10.20.1.50
```

Destination:

```text
Corporate Oracle

10.10.5.20
```

Flow:

```text
10.20.1.50
      │
      ▼
Prod VPC Route Table

10.10.0.0/16 → TGW
      │
      ▼
Prod Attachment
      │
      ▼
PROD TGW ROUTE TABLE

10.10.0.0/16
     → Inspection Attachment
      │
      ▼
Security VPC
      │
      ▼
AWS Network Firewall
      │
      ▼
TGW
      │
      ▼
Security-side routing
      │
      ▼
VPN Attachment
      │
      ▼
IPsec
      │
      ▼
Corporate Router
      │
      ▼
10.10.5.20
```

Return:

```text
10.10.5.20
      │
Corporate Router
      │
VPN
      │
TGW
      │
Inspection
      │
Firewall
      │
TGW
      │
Prod
```

Now you can see why enterprise networking becomes mostly:

# Route-table design.

---

# 36.71 Production troubleshooting: four route tables?

When troubleshooting TGW, you often need to inspect more routing locations than beginners expect.

Example:

```text
Prod → OnPrem
```

Check:

### 1. Source subnet VPC route table

```text
10.10.0.0/16 → TGW ?
```

### 2. TGW route table associated with source attachment

```text
10.10.0.0/16 → correct attachment?
```

### 3. Destination/inspection VPC routing

If entering another VPC:

```text
does its attachment subnet route correctly?
```

### 4. Return side routing

```text
Does On-Prem know:

10.20.0.0/16 → AWS ?
```

Then repeat for the reverse TGW path.

This is why blindly checking:

```text
ping
```

isn't enough.

---

# 36.72 My TGW troubleshooting sequence for you

When:

```text
VPC A cannot reach VPC B
```

use this sequence:

```text
1. CIDRs overlap?
         │
         ▼
2. Both TGW attachments AVAILABLE?
         │
         ▼
3. Source subnet RT points to TGW?
         │
         ▼
4. Correct attachment association?
         │
         ▼
5. Correct TGW route exists?
         │
         ▼
6. Is it blackholed?
         │
         ▼
7. Correct destination attachment?
         │
         ▼
8. Destination VPC return route?
         │
         ▼
9. Reverse TGW route exists?
         │
         ▼
10. SG?
         │
         ▼
11. NACL?
         │
         ▼
12. OS firewall?
         │
         ▼
13. Application listening?
```

That is how I want you to think in a production incident.

---

# 36.73 Important distinction: TGW routing vs VPC routing

Memorize this picture:

```text
┌──────────────── PROD VPC ──────────────┐

EC2
 │
 ▼
VPC ROUTE TABLE
 │
 │ target = TGW
 │
└─┼──────────────────────────────────────┘
  │
  ▼
TGW ATTACHMENT
  │
  ▼
┌──────────────── TGW ───────────────────┐

TGW ROUTE TABLE
 │
 │ target = DEV attachment
 │
└─┼──────────────────────────────────────┘
  │
  ▼
DEV ATTACHMENT
  │
  ▼
┌──────────────── DEV VPC ───────────────┐

VPC routing
 │
 ▼
EC2

└────────────────────────────────────────┘
```

If you understand that diagram, you understand much of TGW.

---

# 36.74 TGW does NOT automatically make everything reachable

Creating:

```text
Prod Attachment
Dev Attachment
```

does not mean:

```text
Prod ↔ Dev
```

is automatically guaranteed.

You still need:

```text
VPC routes
TGW associations
TGW routes/propagation
return routes
security controls
```

AWS's documentation specifically requires VPC subnet routes pointing to the TGW for VPC traffic that should traverse it. ([AWS Documentation][2])

This is excellent because it gives us explicit control.

---

# 36.75 Default TGW route table

By default, a Transit Gateway can have a default association/propagation route table depending on how you configure those default behaviors. You can also create additional TGW route tables for isolation and custom routing. ([AWS Documentation][2])

For a tiny environment:

```text
Single TGW route table
```

may be okay.

For an enterprise:

```text
Prod
NonProd
Shared
Security
Hybrid
```

may justify multiple route tables.

But don't create 40 route tables simply because you can.

AWS's current design guidance recommends limiting the number of TGW route tables unless the network design actually requires additional segmentation. ([AWS Documentation][7])

---

# 36.76 Route propagation production pattern

For example:

```text
Prod VPC
10.20.0.0/16
```

can propagate:

```text
10.20.0.0/16
```

into:

```text
Shared-RT
OnPrem-RT
Security-RT
```

but not:

```text
Dev-RT
```

if Dev should not know a route to Prod.

Thus propagation itself becomes part of architecture policy.

Think:

```text
Who should know that this network exists?
```

That's a powerful way to think about route propagation.

---

# 36.77 Interview trap

Question:

> If a VPC attachment is associated with TGW route table A, can it propagate routes to TGW route table B?

# YES.

Association and propagation are independent concepts.

Example:

```text
Prod Attachment

Association:
     ↓
PROD-RT


Propagation:
     ↓
SHARED-RT
     ↓
ONPREM-RT
```

An attachment can be associated with one route table for its ingress lookup while propagating its routes into multiple route tables. ([AWS Documentation][2])

Never forget that.

---

# 36.78 Another interview trap

> Does route propagation from a VPC mean the VPC's own subnet route tables automatically learn TGW routes?

# No.

These are different routing planes.

Propagation we're discussing is:

```text
VPC Attachment
      ↓
TGW Route Table
```

But inside the VPC, you still configure routes such as:

```text
10.10.0.0/16 → tgw-xxxx
```

AWS explicitly requires a VPC subnet route pointing to Transit Gateway when that traffic should traverse the attachment. ([AWS Documentation][2])

Very important.

---

# 36.79 Terraform mental preview

Later we'll build the full thing, but I want you to start recognizing the Terraform resources.

Conceptually:

```hcl
resource "aws_ec2_transit_gateway" "main" {
  description = "Enterprise Transit Gateway"
}
```

Then:

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.prod.id

  subnet_ids = [
    aws_subnet.prod_tgw_a.id,
    aws_subnet.prod_tgw_b.id
  ]
}
```

Then:

```hcl
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}
```

Then conceptually:

```text
ASSOCIATE

Prod Attachment
      ↓
Prod Route Table
```

and:

```text
PROPAGATE

Shared Attachment
      ↓
Prod Route Table
```

Later our Terraform will build:

```text
TGW
│
├── VPC Attachments
├── VPN Attachment
├── Route Tables
├── Associations
├── Propagations
├── Static Routes
├── RAM Sharing
└── Inspection architecture
```

rather than treating TGW as one single resource.

---

# 36.80 The architecture you should now understand

```text
                             CORPORATE DC
                              10.10.0.0/16
                                    │
                                    │ BGP
                                    ▼
                              Site-to-Site
                                  VPN
                                    │
                                    ▼
                    ┌────────────────────────┐
                    │     TRANSIT GATEWAY    │
                    │                        │
                    │   Multiple TGW RTs     │
                    └────────────┬───────────┘
                                 │
             ┌───────────────────┼────────────────────┐
             │                   │                    │
             ▼                   ▼                    ▼
          PROD VPC            DEV VPC          INSPECTION VPC
        10.20.0.0/16        10.30.0.0/16        10.50.0.0/16
             │                   │                    │
            ECS                 EKS             Network Firewall
             │                   │                    │
            RDS                RDS              Appliance Mode

                                 │
                                 ▼
                           SHARED SERVICES
                            10.40.0.0/16
                                 │
                         ┌───────┼────────┐
                         │       │        │
                        AD      DNS     Jenkins
```

And across AWS accounts:

```text
NETWORK ACCOUNT
      │
      │ owns TGW
      │
    AWS RAM
      │
 ┌────┼─────────┬─────────┐
 │    │         │         │
Prod Dev     Security   Shared
```

That is a genuine enterprise AWS networking architecture.

---

# 36.81 Never-forget TGW table

| Concept             | Meaning                                                            |
| ------------------- | ------------------------------------------------------------------ |
| **TGW**             | Regional transit routing hub                                       |
| **Attachment**      | Connection between TGW and another network/resource                |
| **VPC Attachment**  | Connects VPC to TGW                                                |
| **VPN Attachment**  | Terminates Site-to-Site VPN on TGW                                 |
| **DXGW Attachment** | Connects Direct Connect Gateway toward TGW                         |
| **TGW Route Table** | Decides next attachment                                            |
| **Association**     | Which TGW RT incoming traffic uses                                 |
| **Propagation**     | Which TGW RTs learn an attachment's routes                         |
| **Static Route**    | Manually configured TGW route                                      |
| **Blackhole Route** | Explicitly discard matching traffic                                |
| **AWS RAM**         | Share TGW across AWS accounts                                      |
| **Appliance Mode**  | Preserve appropriate flow/AZ affinity for stateful appliance paths |
| **ECMP**            | Use multiple equal-cost network paths                              |
| **TGW Peering**     | Connect transit gateways                                           |

---

# 36.82 Three route-table questions

Every time you see a packet entering Transit Gateway, ask these three questions:

```text
QUESTION 1

Which attachment did the packet ENTER FROM?

               ↓

QUESTION 2

Which TGW route table is ASSOCIATED
with that attachment?

               ↓

QUESTION 3

What route inside that table matches
the destination?

               ↓

TARGET ATTACHMENT
```

That's the TGW routing algorithm in your head.

Example:

```text
Packet:
10.20.1.50 → 10.10.5.20


Entered from:
Prod Attachment
       ↓

Association:
PROD-RT
       ↓

Lookup:
10.10.0.0/16
       ↓

Target:
Security Attachment
```

Then the next routing stage begins.

---

# 36.83 The single diagram I want you to remember

```text
               SOURCE VPC

                  EC2
                   │
                   ▼
            VPC ROUTE TABLE
                   │
                   ▼
               TGW TARGET
                   │
                   ▼
            TGW ATTACHMENT
                   │
                   ▼
      ┌────────────────────────┐
      │    TRANSIT GATEWAY     │
      │                        │
      │ Attachment             │
      │ Association            │
      │      ↓                 │
      │ TGW ROUTE TABLE        │
      │      ↓                 │
      │ Route Lookup           │
      │      ↓                 │
      │ Destination Attachment │
      └────────────┬───────────┘
                   │
                   ▼
          DESTINATION VPC
                   │
                   ▼
             VPC ROUTING
                   │
                   ▼
               WORKLOAD
```

When troubleshooting, reverse that entire diagram for the reply.

---

# 36.84 Never-forget sentence

```text
A Transit Gateway attachment tells AWS WHAT IS CONNECTED.

Association tells TGW WHICH ROUTE TABLE TO READ.

Propagation tells route tables WHICH NETWORKS TO LEARN.

The TGW route tells the packet WHICH ATTACHMENT TO LEAVE THROUGH.
```

If these four concepts are clear, you have crossed one of the hardest conceptual barriers in AWS networking.

---

# Next — Lesson 36, Part 3

## AWS Direct Connect Deep Dive

Now we have:

```text
On-Prem
   │
VPN
   │
TGW
   │
Many VPCs
```

Next we're going to replace/augment the Internet-based VPN transport with true enterprise connectivity:

```text
                   CORPORATE DATA CENTER
                            │
                            │
                     Customer Router
                            │
                            ▼
                   DIRECT CONNECT
                            │
                     DX Location
                            │
                            ▼
                 Direct Connect Gateway
                            │
                            ▼
                     Transit Gateway
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
           PROD           DEV          SHARED
```

We'll go deep into **Direct Connect physical architecture, dedicated vs hosted connections, 1/10/100/400 Gbps connection options where applicable, LOA-CFA, cross-connects, VLANs, 802.1Q, BGP, private VIF vs public VIF vs transit VIF, Direct Connect Gateway, TGW integration, allowed prefixes, private ASN/public ASN, BGP communities, route preference, MACsec, resilient DX designs, dual DX locations, VPN backup, VPN-over-DX, and packet-by-packet architecture** before we build the Terraform and full hybrid enterprise lab. ([AWS Documentation][13])

[1]: https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html?utm_source=chatgpt.com "What is AWS Transit Gateway for Amazon VPC?"
[2]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html?utm_source=chatgpt.com "How AWS Transit Gateway works - Amazon VPC"
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-route-tables.html?utm_source=chatgpt.com "Transit gateway route tables in AWS Transit Gateway"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/create-vpc-attachment.html?utm_source=chatgpt.com "Create a VPC attachment in AWS Transit Gateway"
[5]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html?utm_source=chatgpt.com "Amazon VPC attachments in AWS Transit Gateway"
[6]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/vpn.html?utm_source=chatgpt.com "VPN - Building a Scalable and Secure Multi-VPC ..."
[7]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html?utm_source=chatgpt.com "AWS Transit Gateway design best practices - Amazon VPC"
[8]: https://docs.aws.amazon.com/vpc/latest/tgw/working-with-transit-gateways.html?utm_source=chatgpt.com "Work with AWS Transit Gateway - Amazon VPC"
[9]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/vpc-config-tgw-multi-az.html?utm_source=chatgpt.com "Transit gateway attachment configuration for AWS Network ..."
[10]: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-transit-gateway-vpn.html?utm_source=chatgpt.com "AWS Transit Gateway + AWS Site-to-Site VPN"
[11]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html?utm_source=chatgpt.com "Tunnel options for your AWS Site-to-Site VPN connection"
[12]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-peering.html?utm_source=chatgpt.com "Transit gateway peering attachments in ..."
[13]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/routing-and-bgp.html?utm_source=chatgpt.com "Direct Connect routing policies and BGP communities"
