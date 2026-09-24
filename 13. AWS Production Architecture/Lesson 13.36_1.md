# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 1: Hybrid Networking Mental Model + Site-to-Site VPN Deep Dive

We are now entering one of the most important areas of **real enterprise AWS architecture**.

Until now, most of our architecture looked like:

```text
Users
  │
Internet
  │
CloudFront
  │
ALB
  │
VPC
├── ECS
├── EKS
├── EC2
└── RDS
```

But large organizations rarely have everything inside AWS.

They may already have:

```text
Corporate Data Centers
VMware
Oracle databases
SAP
Mainframes
Active Directory
File servers
Factories
Branch offices
Other clouds
Legacy applications
Firewalls
Corporate DNS
```

So the architecture becomes:

```text
                       CORPORATE NETWORK
                         10.10.0.0/16
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  VPN              Direct Connect
                    │                   │
                    └─────────┬─────────┘
                              │
                       Transit Gateway
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
          Prod VPC         Dev VPC       Shared VPC
        10.20.0.0/16     10.30.0.0/16   10.40.0.0/16
             │                │                │
            ECS              EKS        DNS / Firewall
             │
            RDS
```

That is **hybrid cloud networking**.

---

# 36.1 What exactly is Hybrid Cloud?

Hybrid cloud means your infrastructure spans:

```text
Private environment
        +
Public cloud
```

For example:

```text
Company Data Center                     AWS
──────────────────                     ───

Active Directory ───────────────────── EC2
Oracle DB        ───────────────────── ECS
VMware           ───────────────────── EKS
DNS Server       ───────────────────── Route 53 Resolver
Users            ───────────────────── Internal ALB
```

AWS Site-to-Site VPN provides connectivity between a remote/on-premises network and AWS by routing traffic through a VPN connection. AWS supports a virtual private gateway as the AWS-side endpoint for a single VPC, while larger architectures can terminate VPN connectivity on Transit Gateway instead. ([AWS Documentation][1])

A very common migration situation is:

```text
Frontend        → AWS
Backend         → AWS
Database        → Data Center
Active Directory→ Data Center
DNS             → Hybrid
```

The application might therefore execute:

```text
ECS container
10.20.4.17
     │
     │ SQL
     ▼
10.10.50.20
Oracle Database
Corporate DC
```

The application doesn't need to know that the DB lives outside AWS.

Networking makes:

```text
10.20.4.17 → 10.10.50.20
```

possible.

---

# 36.2 The most important hybrid-networking mental model

Whenever you troubleshoot hybrid connectivity, think:

```text
SOURCE
  │
  ▼
SOURCE ROUTING
  │
  ▼
NETWORK GATEWAY
  │
  ▼
TUNNEL / CIRCUIT
  │
  ▼
DESTINATION ROUTING
  │
  ▼
FIREWALL / SG / NACL
  │
  ▼
DESTINATION
  │
  ▼
RETURN ROUTE
```

That final line is extremely important:

# RETURN ROUTE

Suppose:

```text
AWS VPC:
10.20.0.0/16

On-prem:
10.10.0.0/16
```

AWS may know:

```text
10.10.0.0/16 → VPN
```

but if the corporate router does not know:

```text
10.20.0.0/16 → AWS VPN
```

then:

```text
AWS → on-prem
```

may leave correctly, but:

```text
on-prem → AWS
```

cannot return correctly.

Result:

```text
Connection timeout
```

even though:

```text
VPN Tunnel = UP
```

For a VGW-based VPN, AWS requires the VPC routing layer to know that traffic for the remote network belongs through the VGW; this can be done explicitly or through route propagation. ([AWS Documentation][2])

This gives us a rule worth memorizing:

> **Tunnel UP does not mean application connectivity works.**

---

# 36.3 Four components you must distinguish

Consider:

```text
                  AWS
             ┌──────────────┐
             │     VPC      │
             │10.20.0.0/16  │
             └──────┬───────┘
                    │
                   VGW
                    │
          ===== IPsec VPN =====
                    │
             Corporate Router
                    │
             ┌──────┴───────┐
             │ 10.10.0.0/16 │
             └──────────────┘
```

We have four concepts.

| Component                 | Meaning                                                  |
| ------------------------- | -------------------------------------------------------- |
| Customer Gateway Device   | Your actual router/firewall                              |
| Customer Gateway resource | AWS representation/configuration of your side            |
| Virtual Private Gateway   | AWS VPN endpoint attached to a VPC                       |
| VPN Connection            | Logical Site-to-Site VPN relationship containing tunnels |

AWS explicitly distinguishes the **customer gateway device**, which is your physical or software VPN device, from the AWS resources involved in the Site-to-Site VPN. A virtual private gateway can act as the AWS-side endpoint attached to a VPC. ([AWS Documentation][1])

This distinction appears constantly in AWS exams and real troubleshooting.

---

# 36.4 Customer Gateway — CGW

Imagine your corporate data center has:

```text
Cisco Router
Palo Alto
FortiGate
Juniper
pfSense
Check Point
Linux VPN appliance
```

Example:

```text
                     Internet

                         │

                  203.0.113.50
                         │
                   ┌─────▼─────┐
                   │ FortiGate │
                   │ Firewall  │
                   └─────┬─────┘
                         │
                  10.10.0.0/16
```

When configuring AWS, AWS needs information representing this VPN peer, such as its externally reachable address and, for dynamic routing, its BGP ASN. AWS supports public or private ASNs within documented ranges for the customer gateway. ([AWS Documentation][3])

Conceptually:

```text
AWS Customer Gateway resource

Public IP:
203.0.113.50

BGP ASN:
65000
```

But remember:

```text
CGW resource ≠ actual router
```

It's AWS's representation of the remote VPN endpoint.

---

# 36.5 Virtual Private Gateway — VGW

Now AWS needs its own endpoint.

That's the:

# Virtual Private Gateway

```text
                         AWS

                ┌──────────────────┐
                │       VPC        │
                │   10.20.0.0/16   │
                └────────┬─────────┘
                         │
                        VGW
                         │
                       IPsec
                         │
                        CGW
```

Think:

```text
CGW = your side

VGW = AWS side
```

A VGW is attached to a VPC and can terminate the Site-to-Site VPN for that VPC. AWS currently documents IPv6 VPN traffic as unsupported when the VPN terminates on a virtual private gateway; IPv6 VPN capabilities are available with other AWS-side targets such as Transit Gateway. ([AWS Documentation][1])

This becomes one reason larger designs tend to move away from:

```text
VPN → individual VGWs
```

toward:

```text
VPN
 │
Transit Gateway
 │
├── VPC
├── VPC
├── VPC
└── VPC
```

We'll build that next.

---

# 36.6 What happens when we create the VPN?

We now connect:

```text
CGW
 │
 │
VGW
```

using:

# AWS Site-to-Site VPN

The architecture becomes:

```text
ON-PREMISES                             AWS

10.10.0.0/16                        10.20.0.0/16
     │                                    │
     ▼                                    ▼
Corporate router                         VGW
     │                                    │
     │                                    │
     └────────── IPsec VPN ───────────────┘
```

Site-to-Site VPN protects traffic using VPN tunnels between the remote gateway and AWS. AWS recommends IKEv2 where supported.

---

# 36.7 IPsec — what is actually happening?

Many beginners hear:

```text
VPN
```

and think VPN itself is a protocol.

Not exactly.

The connection uses technologies including:

```text
IKE
IPsec
Encryption
Authentication
Tunnel interfaces
Routing
```

Simplified:

```text
Original packet:

SOURCE       10.10.5.20
DESTINATION  10.20.10.50
```

It enters the VPN device.

The router encrypts/protects the packet and transports it through the VPN tunnel.

Conceptually:

```text
             Internet
                │
       Encrypted VPN traffic
                │
     ┌──────────┴──────────┐
     │                     │
On-prem router          AWS VPN
     │                     │
10.10.0.0/16           10.20.0.0/16
```

Then AWS decrypts it and routes the original packet toward its VPC destination.

---

# 36.8 IKE vs IPsec

A useful mental model:

```text
IKE
 ↓
"Let's securely agree how to communicate."

IPsec
 ↓
"Now let's protect the actual traffic."
```

Think:

```text
IKE = negotiation / key establishment

IPsec = protected data transport
```

For troubleshooting, this matters because a failure may happen at different layers:

```text
IKE negotiation failed
       │
       ├── bad PSK
       ├── crypto mismatch
       ├── connectivity issue
       └── configuration mismatch

IPsec failed
       │
       ├── phase configuration mismatch
       ├── traffic selectors
       └── tunnel configuration

Tunnel up but application broken
       │
       ├── routing
       ├── firewall
       ├── SG
       ├── NACL
       └── return path
```

AWS's VPN troubleshooting documentation similarly recommends checking IKE, IPsec, and tunnel/routing state rather than treating VPN connectivity as one single status. ([AWS Documentation][4])

---

# 36.9 Why does AWS give me TWO tunnels?

This is extremely important.

One AWS Site-to-Site VPN connection contains:

```text
Tunnel 1
Tunnel 2
```

not just one tunnel.

AWS currently documents two tunnels per Site-to-Site VPN connection, using separate AWS endpoint addresses, and recommends configuring both for redundancy. If one tunnel becomes unavailable, traffic can use the other available tunnel. ([AWS Documentation][5])

Architecture:

```text
                         AWS VPN
                    ┌───────────────┐
                    │               │
                    │   AWS Side    │
                    │               │
                    └───┬───────┬───┘
                        │       │
                 Tunnel 1     Tunnel 2
                        │       │
                        └───┬───┘
                            │
                     Corporate Router
```

So:

```text
Never configure:

Tunnel 1 = yes
Tunnel 2 = ignored
```

for a serious production environment.

You lose a large part of the resilience AWS gives you.

---

# 36.10 But is two tunnels enough for enterprise HA?

Not necessarily.

Look at this:

```text
                  AWS
             Tunnel1 Tunnel2
                 \    /
                  \  /
                Router A
                   │
              Data Center
```

What happens if:

```text
Router A dies?
```

Both tunnels disappear.

Therefore a stronger architecture uses redundant customer gateway devices / VPN connections.

```text
                         AWS
                     ┌─────────┐
                     │ VPN/TGW │
                     └────┬────┘
                    ┌─────┴─────┐
                    │           │
                  VPN A       VPN B
                    │           │
                Router A     Router B
                    │           │
                    └─────┬─────┘
                          │
                      On-prem LAN
```

AWS specifically documents redundant Site-to-Site VPN connections using an additional customer gateway device as a way to protect against failure of the first device. ([AWS Documentation][6])

So enterprise HA is better thought of as:

```text
Multiple tunnels
      +
Multiple customer routers/firewalls
      +
Multiple paths
```

rather than merely:

```text
"VPN has 2 tunnels, we're done."
```

---

# 36.11 Outside IP vs Inside IP — very important

VPN tunnels effectively have two sets of addressing concepts.

## Outside tunnel IP

Used to establish the VPN across the transport network.

Conceptually:

```text
Corporate Public IP
203.0.113.50

        │
     Internet
        │

AWS VPN public endpoint
198.51.100.x
```

These are the tunnel endpoints used by the VPN transport.

---

## Inside tunnel IP

Once the tunnel exists, AWS also creates an internal point-to-point network used for tunnel/routing communication.

Example:

```text
169.254.21.0/30

AWS:
169.254.21.1

Customer router:
169.254.21.2
```

AWS currently allows an IPv4 `/30` from the `169.254.0.0/16` link-local range for VPN inside-tunnel addressing, subject to documented reserved ranges and uniqueness requirements. ([AWS Documentation][7])

Visualize it as:

```text
OUTSIDE

203.0.113.50
     │
 Internet
     │
AWS VPN endpoint


INSIDE VPN

169.254.21.2
     │
     │ encrypted tunnel
     │
169.254.21.1
```

The inside addresses are particularly important when we configure:

# BGP

---

# 36.12 Static routing vs Dynamic routing

This is one of the core hybrid-cloud topics.

AWS Site-to-Site VPN supports static routing or dynamic routing using BGP depending on the gateway type/device capability. AWS recommends using a BGP-capable customer gateway when available because BGP provides route advertisements and better liveness/failover behavior. ([AWS Documentation][8])

Suppose:

```text
AWS:
10.20.0.0/16

On-prem:
10.10.0.0/16
```

### Static approach

You manually say:

```text
AWS:
10.10.0.0/16 → VPN

On-prem:
10.20.0.0/16 → VPN
```

Simple.

But now your company acquires another network:

```text
10.50.0.0/16
```

Someone must change routing.

Then:

```text
10.60.0.0/16
10.70.0.0/16
172.20.0.0/16
```

More manual updates.

---

# 36.13 Enter BGP

BGP means:

# Border Gateway Protocol

At a simplified level, BGP allows routers to tell each other:

```text
"I know how to reach these networks."
```

For example:

```text
Corporate Router:

I can reach:
10.10.0.0/16
10.50.0.0/16
10.60.0.0/16
```

AWS tells your router:

```text
I can reach:
10.20.0.0/16
```

Now routes can be exchanged dynamically instead of manually maintaining every network prefix. AWS's dynamic VPN configuration uses BGP advertisements between the customer side and AWS. ([AWS Documentation][8])

Architecture:

```text
              BGP session

On-premises  <──────────────> AWS
ASN 65000                    ASN 64512

Advertises:                  Advertises:
10.10.0.0/16                 10.20.0.0/16
10.50.0.0/16
```

---

# 36.14 What exactly is ASN?

ASN:

# Autonomous System Number

Think of it as an identifier for a routing domain participating in BGP.

Example:

```text
Corporate network
ASN 65000

AWS VGW
ASN 64512
```

Then:

```text
ASN 65000
    │
    │ BGP
    │
ASN 64512
```

For a VGW, AWS allows you to specify an Amazon-side ASN when the VGW is created; if you don't specify one, AWS currently uses `64512` by default. ([AWS Documentation][9])

On the customer side, private ASNs can be used when you don't have an assigned public ASN; AWS documents both 16-bit and 32-bit private ranges for customer gateways. ([AWS Documentation][3])

Do **not** confuse:

```text
ASN
```

with:

```text
IP address
CIDR
VLAN
Port
Security Group
```

They're completely different concepts.

---

# 36.15 Static routing vs BGP — production comparison

| Feature               |    Static |           BGP |
| --------------------- | --------: | ------------: |
| Configuration         |    Manual |       Dynamic |
| Small lab             | Excellent |  More complex |
| Route learning        |        No |           Yes |
| Route withdrawal      |    Manual |     Automatic |
| Failover intelligence |   Limited |        Better |
| Large networks        |   Painful | Better suited |
| Multiple sites        |    Harder |   Much better |
| Enterprise preference | Sometimes |        Common |

AWS recommends BGP-capable devices where available for Site-to-Site VPN because BGP can help with route liveness and tunnel failover. ([AWS Documentation][8])

So my production mental shortcut for you is:

```text
Tiny network / learning
        ↓
Static routes can be fine


Enterprise hybrid network
        ↓
Strongly think BGP
```

---

# 36.16 Route propagation

Remember normal VPC routing?

```text
Destination         Target

10.20.0.0/16        local
0.0.0.0/0           nat-xxxx
```

Hybrid requires something like:

```text
10.10.0.0/16        vgw-xxxx
```

You could manually maintain that route.

But with VGW route propagation enabled, applicable routes learned/defined through the VPN can be propagated into the VPC route table automatically, subject to route-table limits and AWS route-selection behavior. ([AWS Documentation][2])

Conceptually:

```text
On-prem
advertises

10.10.0.0/16
     │
     │ BGP
     ▼
    VGW
     │
     │ route propagation
     ▼
VPC Route Table

10.10.0.0/16 → VGW
```

That's far cleaner than manually maintaining dozens of routes.

---

# 36.17 Complete packet walk — memorize this

Let's do a real flow.

AWS:

```text
EC2
10.20.1.50
```

needs to connect to:

```text
Corporate Oracle DB
10.10.5.20
```

Architecture:

```text
EC2
10.20.1.50
    │
    ▼
Subnet Route Table
    │
10.10.0.0/16 → VGW
    │
    ▼
VGW
    │
    ▼
IPsec Tunnel
    │
    ▼
Corporate Firewall
    │
    ▼
Corporate Router
    │
    ▼
10.10.5.20
Oracle
```

### Step 1 — EC2 creates packet

```text
SRC = 10.20.1.50
DST = 10.10.5.20
```

### Step 2 — VPC route lookup

AWS examines:

```text
10.10.5.20
```

and matches:

```text
10.10.0.0/16 → VGW
```

AWS route tables use routing rules, including destination-prefix matching, to determine the next hop. ([AWS Documentation][2])

### Step 3 — Packet reaches VGW

VGW knows that the on-premises network is reachable through the VPN.

### Step 4 — Packet traverses IPsec

```text
AWS
 ↓
encrypted transport
 ↓
Corporate gateway
```

### Step 5 — corporate routing

Corporate router knows:

```text
10.10.0.0/16 → LAN
```

and delivers the packet to:

```text
10.10.5.20
```

### Step 6 — RETURN TRAFFIC

Oracle replies:

```text
SRC = 10.10.5.20
DST = 10.20.1.50
```

Corporate network must know:

```text
10.20.0.0/16 → AWS VPN
```

Then:

```text
Oracle
  │
Corporate Router
  │
VPN
  │
VGW
  │
EC2
```

This is why I keep repeating:

# ALWAYS CHECK BOTH ROUTING DIRECTIONS.

---

# 36.18 Security Groups still matter

A VPN does not magically bypass normal application security.

Suppose:

```text
On-prem client
10.10.20.50
```

connects to:

```text
EC2
10.20.1.50:443
```

The network path could be perfect while the EC2 security group rejects the traffic.

For example you may need a rule conceptually equivalent to:

```text
Inbound:

HTTPS
TCP 443
Source: 10.10.0.0/16
```

Then potentially check:

```text
Security Group
NACL
OS firewall
Corporate firewall
Application listener
```

So your troubleshooting stack becomes:

```text
Tunnel
   ↓
BGP
   ↓
Route
   ↓
NACL
   ↓
Security Group
   ↓
OS Firewall
   ↓
Application
```

---

# 36.19 One extremely important distinction

## Route table

answers:

```text
WHERE should this packet go?
```

## Security Group / Firewall

answers:

```text
SHOULD this packet be allowed?
```

Do not mix those concepts.

Example:

```text
Route:

10.10.0.0/16 → VPN
```

does **not** mean:

```text
10.10.0.0/16 is allowed.
```

Routing is not authorization.

That distinction will save you many hours in production.

---

# 36.20 Simple Site-to-Site architecture

The architecture we have learned so far is:

```text
                         AWS ACCOUNT

                   ┌──────────────────┐
                   │    Prod VPC      │
                   │   10.20.0.0/16   │
                   │                  │
                   │ EC2   ECS   RDS  │
                   └────────┬─────────┘
                            │
                           VGW
                            │
                       ┌────┴────┐
                       │         │
                   Tunnel 1   Tunnel 2
                       │         │
                       └────┬────┘
                            │
                          CGW
                            │
                  Corporate Firewall
                            │
                   ┌────────┴────────┐
                   │                 │
             10.10.0.0/16       10.50.0.0/16
             Corporate LAN       Database LAN
```

For one VPC, this can be perfectly reasonable.

But now management says:

> “Vivek, we have 40 AWS VPCs.”

Uh-oh.

Imagine:

```text
On-prem
  │
  ├── VPN → Prod VPC
  ├── VPN → Dev VPC
  ├── VPN → QA VPC
  ├── VPN → Security VPC
  ├── VPN → Shared VPC
  ├── VPN → Analytics VPC
  ├── VPN → Data VPC
  ├── VPN → ML VPC
  └── ...
```

This becomes an operational nightmare.

Which leads directly to one of the most important networking services in AWS:

# AWS TRANSIT GATEWAY

---

# 36.21 Why Transit Gateway changes the architecture

Instead of:

```text
             On-prem

        ┌──────┼──────┬──────┐
        │      │      │      │
       VPN    VPN    VPN    VPN
        │      │      │      │
       VPC    VPC    VPC    VPC
```

we introduce a transit hub:

```text
                    ON-PREM
                       │
                      VPN
                       │
                       ▼
               ┌───────────────┐
               │    Transit    │
               │    Gateway    │
               └───────┬───────┘
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
           Prod       Dev      Shared
            VPC        VPC       VPC
```

Transit Gateway routes traffic between attachments using TGW route tables; those attachments can include VPCs, VPN connectivity, and Direct Connect gateway connectivity. AWS supports static routes as well as propagated routes within Transit Gateway route tables. ([AWS Documentation][10])

And unlike our simple VGW design, we can create separate TGW route tables to implement network segmentation.

For example:

```text
                    Transit Gateway

             ┌──────────┼───────────┐
             │          │           │
        Prod Route   Dev Route   Shared Route
          Table        Table        Table
```

Then we can enforce architecture such as:

```text
Prod → Shared Services       YES
Dev  → Shared Services       YES

Dev  → Prod                  NO

On-prem → Prod               YES
On-prem → Dev                MAYBE
```

That is where hybrid networking becomes **enterprise networking**.

---

# 36.22 And then Direct Connect enters

Site-to-Site VPN is excellent for:

```text
Fast deployment
Encrypted hybrid connectivity
Backup connectivity
Smaller environments
Initial migrations
```

But enterprises may eventually need a dedicated private network path rather than depending on ordinary internet transport.

Enter:

# AWS Direct Connect

Conceptually:

```text
Corporate DC
     │
     │ private network circuit
     │
Direct Connect Location
     │
     ▼
AWS
```

AWS Direct Connect provides dedicated connectivity into AWS and supports virtual interfaces for different connectivity use cases. A **transit VIF**, for example, connects through a Direct Connect Gateway toward Transit Gateways. ([AWS Documentation][11])

Eventually our architecture becomes:

```text
                       CORPORATE DC
                        10.10.0.0/16
                             │
                 ┌───────────┴───────────┐
                 │                       │
           Site-to-Site VPN       Direct Connect
              backup                 primary
                 │                       │
                 └──────────┬────────────┘
                            │
                     Direct Connect /
                     Transit Gateway
                            │
                    ┌───────┴────────┐
                    │ Transit Gateway│
                    └───────┬────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
             Prod          Dev         Shared
              │             │             │
             ECS           EKS      DNS/Firewall
```

And yes—we can also combine VPN and Direct Connect when encryption plus Direct Connect's network characteristics are required. AWS documents IPsec VPN running over Direct Connect, including private-IP VPN designs with Transit Gateway. ([AWS Documentation][12])

---

# 36.23 Hybrid DNS is another hidden requirement

Imagine networking works:

```text
AWS → 10.10.5.20
```

Great.

But your application doesn't use:

```text
10.10.5.20
```

It uses:

```text
oracle-db.corp.internal
```

AWS now has another problem:

```text
Who resolves corp.internal?
```

Probably your corporate DNS server.

Conversely, on-premises users may need:

```text
api.internal.aws.example
```

from an AWS Route 53 private hosted zone.

This is where:

# Route 53 Resolver

comes in.

Conceptually:

```text
                       Hybrid DNS

      ON-PREM                                  AWS

Corporate DNS                           Route 53 Resolver
10.10.1.53                                     │
     │                                         │
     ├──────── outbound endpoint ◄─────────────┤
     │                                         │
     └──────── inbound endpoint ──────────────►│
```

Inbound Resolver endpoints allow on-premises DNS resolvers to send appropriate queries into AWS, while outbound endpoints and forwarding rules allow VPC DNS queries to be forwarded toward on-premises DNS servers. AWS recommends multiple endpoint IPs across Availability Zones for resilience. ([AWS Documentation][13])

We'll implement that after TGW and Direct Connect because the DNS architecture makes much more sense once the network path is clear.

---

# 36.24 Production troubleshooting framework

When someone says:

```text
"VPN is not working."
```

do not randomly click AWS Console settings.

Use this sequence:

```text
1. Customer gateway reachable?
              │
              ▼
2. IKE established?
              │
              ▼
3. IPsec established?
              │
              ▼
4. Tunnel UP?
              │
              ▼
5. BGP session established?
              │
              ▼
6. Correct routes advertised?
              │
              ▼
7. AWS route present?
              │
              ▼
8. On-prem return route present?
              │
              ▼
9. Security groups correct?
              │
              ▼
10. NACL correct?
              │
              ▼
11. Corporate firewall correct?
              │
              ▼
12. DNS resolving?
              │
              ▼
13. Application actually listening?
```

AWS exposes VPN connection/tunnel state and routing details, and its troubleshooting documentation specifically works upward through VPN negotiation, tunnel connectivity, and routing. ([AWS Documentation][14])

That troubleshooting mindset is much more valuable than memorizing console screens.

---

# 36.25 Never-forget diagram

Memorize this progression:

```text
LEVEL 1
───────

On-prem
   │
  CGW
   │
IPsec VPN
   │
  VGW
   │
  VPC


LEVEL 2
───────

On-prem
   │
  VPN
   │
  TGW
   │
 ┌─┼─────────┐
 │ │         │
VPC VPC     VPC


LEVEL 3
───────

                 On-prem
                    │
        ┌───────────┴───────────┐
        │                       │
       VPN                     DX
        │                       │
        └──────────┬────────────┘
                   │
                  TGW
                   │
         ┌─────────┼─────────┐
         │         │         │
       Prod       Dev      Shared
                            │
                        Firewall
                            │
                     Route53 Resolver
```

---

# Interview / SAA / DevOps exam quick distinctions

| Term                        | Never-forget meaning                               |
| --------------------------- | -------------------------------------------------- |
| **CGW**                     | Your-side VPN representation / gateway             |
| **Customer Gateway Device** | Actual corporate router/firewall                   |
| **VGW**                     | AWS VPN endpoint for a VPC                         |
| **VPN Connection**          | Connection containing redundant tunnels            |
| **IPsec**                   | Protects VPN traffic                               |
| **IKE**                     | Establishes/negotiates VPN security                |
| **BGP**                     | Dynamically exchanges routes                       |
| **ASN**                     | Identifier of a BGP autonomous system              |
| **Static Route**            | Manually configured destination/next hop           |
| **Route Propagation**       | Dynamically places learned VPN routes into routing |
| **TGW**                     | Regional transit networking hub                    |
| **DX**                      | AWS Direct Connect                                 |
| **DXGW**                    | Direct Connect Gateway                             |
| **VIF**                     | Logical interface carried over Direct Connect      |
| **Route 53 Resolver**       | Hybrid DNS resolution/forwarding                   |

---

# The single sentence to remember today

```text
Hybrid connectivity works only when:

TUNNEL
  +
FORWARD ROUTE
  +
RETURN ROUTE
  +
SECURITY
  +
DNS

all agree.
```

A green:

```text
Tunnel Status = UP
```

is only one part of the puzzle.

---

# Next — Lesson 36, Part 2

## AWS Transit Gateway Deep Dive

Next we move from the simple:

```text
On-prem → VPN → VGW → one VPC
```

to:

```text
                    On-prem
                       │
                      VPN
                       │
                       ▼
               TRANSIT GATEWAY
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
    Prod VPC         Dev VPC       Security VPC
       │               │               │
      ECS             EKS          Firewall
```

There we'll go deep into **TGW attachments, association vs propagation, TGW route tables, packet flow, VPC routes vs TGW routes, multi-account sharing with AWS RAM, segmentation, blackhole routes, east-west connectivity, centralized egress, centralized inspection, appliance mode, asymmetric routing, ECMP, TGW VPN termination, and production hub-and-spoke architecture**.

After that we'll move into **Direct Connect → dedicated vs hosted connections → private/public/transit VIFs → Direct Connect Gateway → BGP → MACsec → DX + VPN resiliency → Route 53 hybrid DNS → Terraform → complete enterprise lab**. ([AWS Documentation][15])

[1]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html?utm_source=chatgpt.com "AWS Site-to-Site VPN"
[2]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-route-priority.html?utm_source=chatgpt.com "Route tables and AWS Site-to-Site VPN route priority"
[3]: https://docs.aws.amazon.com/vpn/latest/s2svpn/cgw-options.html?utm_source=chatgpt.com "Customer gateway options for your AWS Site-to-Site VPN ..."
[4]: https://docs.aws.amazon.com/vpn/latest/s2svpn/Generic_Troubleshooting_noBGP.html?utm_source=chatgpt.com "Troubleshoot AWS Site-to-Site VPN connectivity without ..."
[5]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html?utm_source=chatgpt.com "Tunnel options for your AWS Site-to-Site VPN connection"
[6]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-redundant-connection.html?utm_source=chatgpt.com "Redundant AWS Site-to-Site VPN connections for failover"
[7]: https://docs.aws.amazon.com/vpn/latest/s2svpn/tunnel-configure.html?utm_source=chatgpt.com "Configure tunnel options for AWS Site-to-Site VPN"
[8]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-static-dynamic.html?utm_source=chatgpt.com "Static and dynamic routing in AWS Site-to-Site VPN"
[9]: https://docs.aws.amazon.com/vpn/latest/s2svpn/how_it_works.html?utm_source=chatgpt.com "How AWS Site-to-Site VPN works"
[10]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html?utm_source=chatgpt.com "How AWS Transit Gateway works - Amazon VPC"
[11]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/WorkingWithVirtualInterfaces.html?utm_source=chatgpt.com "Direct Connect virtual interfaces and hosted virtual interfaces"
[12]: https://docs.aws.amazon.com/wellarchitected/latest/hybrid-networking-lens/aws-direct-connect-and-ipsec-vpn.html?utm_source=chatgpt.com "AWS Direct Connect and IPSec VPN"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[14]: https://docs.aws.amazon.com/vpn/latest/s2svpn/viewing-vpn-connections.html?utm_source=chatgpt.com "View AWS Site-to-Site VPN connections"
[15]: https://docs.aws.amazon.com/vpc/latest/tgw/create-vpc-attachment.html?utm_source=chatgpt.com "Create a VPC attachment in AWS Transit Gateway"
