# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 5: Private-IP VPN over Direct Connect — Encrypted Enterprise Hybrid Networking

We finished Part 4 with a resilient architecture:

```text
                    CORPORATE DATA CENTER

                           │
              ┌────────────┼────────────┐
              │            │            │
             DX-A         DX-B        VPN Backup
              │            │            │
              └────────────┼────────────┘
                           ▼
                          TGW
                           │
                  ┌────────┼────────┐
                  ▼        ▼        ▼
                PROD      DEV     SHARED
```

Now imagine your security/compliance team says:

> **“Direct Connect is private connectivity, but we also require cryptographic encryption between our data center and AWS.”**

This creates a new requirement:

```text
DEDICATED PRIVATE TRANSPORT
           +
IPsec ENCRYPTION
```

And AWS gives us an architecture specifically for this:

# Private-IP AWS Site-to-Site VPN over Direct Connect

AWS currently supports deploying AWS-managed IPsec Site-to-Site VPN over a **Direct Connect transit VIF**, using private IP addresses for the VPN endpoints. The architecture requires both a Direct Connect Gateway and Transit Gateway. ([AWS Documentation][1])

---

# 36.224 First understand the problem

Normal Direct Connect:

```text
On-Prem
   │
   │ Direct Connect
   │
   ▼
Transit VIF
   │
DXGW
   │
TGW
   │
AWS VPCs
```

provides:

```text
✓ Dedicated connectivity
✓ Private routing
✓ High bandwidth options
✓ BGP
✓ Predictable architecture
```

But Direct Connect itself does **not encrypt traffic in transit by default**. AWS documents MACsec and Site-to-Site VPN as encryption options for traffic traversing Direct Connect. ([AWS Documentation][2])

Therefore:

```text
Direct Connect
      ≠
automatic IPsec encryption
```

If security policy requires:

```text
Data Center
     ↓
encrypted
     ↓
AWS
```

we need another security layer.

---

# 36.225 Think in TWO layers

This is the key mental model for the entire lesson.

When VPN runs over Direct Connect, we have:

```text
UNDERLAY
────────

Direct Connect

provides the transport path.


OVERLAY
───────

IPsec VPN

provides encrypted tunneling.
```

So:

```text
Application traffic
       │
       ▼
    IPsec VPN
       │
       ▼
Direct Connect transport
       │
       ▼
AWS
```

Never confuse:

```text
TRANSPORT
```

with:

```text
ENCRYPTION OVERLAY
```

---

# 36.226 A networking analogy

Imagine a train tunnel.

```text
Direct Connect
=
railroad
```

and:

```text
IPsec
=
locked armored train
traveling over that railroad
```

The railroad determines:

```text
where the traffic travels
```

while IPsec determines:

```text
how the payload is cryptographically protected.
```

That's the underlay/overlay concept.

---

# 36.227 There are TWO major VPN-over-DX architectures

This distinction is extremely important.

You can broadly encounter:

```text
VPN OVER DIRECT CONNECT

├── Public-IP VPN over DX
│
└── Private-IP VPN over DX
```

They are not the same architecture.

---

# 36.228 Architecture A — Public-IP VPN over Direct Connect

Historically/common architecture:

```text
                 Corporate Network

                        │
                        ▼
                 Direct Connect
                        │
                        ▼
                    Public VIF
                        │
                        ▼
             AWS public VPN endpoint
                        │
                     IPsec VPN
                        │
                        ▼
                    VGW / TGW
                        │
                        ▼
                       VPC
```

A Direct Connect **public VIF** can provide dedicated connectivity from the customer network toward AWS public resources, including AWS Site-to-Site VPN endpoints. IPsec can then terminate on supported AWS VPN targets such as VGW or TGW depending on architecture. ([AWS Documentation][3])

Notice something:

```text
VPN OUTER ENDPOINTS
=
PUBLIC IP ADDRESSES
```

even though transport to those AWS public endpoints can use Direct Connect.

---

# 36.229 Public VIF does not mean Internet VPN

This can be confusing.

You may have:

```text
Public IP endpoint
```

but traffic reaches it through:

```text
Direct Connect Public VIF
```

rather than ordinary public Internet transport.

Conceptually:

```text
Corporate router
      │
      │ DX
      ▼
Public VIF
      │
      ▼
AWS public VPN endpoint
```

Then:

```text
IPsec tunnel
```

is established to the public endpoint.

So:

```text
PUBLIC IP
```

does not necessarily mean:

```text
packet must cross ordinary Internet path
```

in this design.

---

# 36.230 But public VIF introduces additional exposure considerations

AWS created Private-IP VPN over DX partly because the earlier public-VIF architecture requires public addresses for VPN endpoints and gives the customer network reachability to AWS public services through that VIF.

Private-IP VPN instead allows the encrypted architecture to use a transit VIF and private tunnel endpoint addressing. ([AWS Documentation][1])

That gives us architecture B.

---

# 36.231 Architecture B — Private-IP VPN over Direct Connect

The modern private-IP architecture looks like:

```text
                     CORPORATE DC

                          │
                    Customer Router
                          │
                          │
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
              ┌───────────┴───────────┐
              │                       │
              │   PRIVATE IPsec VPN   │
              │                       │
              └───────────┬───────────┘
                          │
                          ▼
                    VPN Attachment
                          │
                          ▼
                    TGW Routing
                          │
                 ┌────────┼────────┐
                 ▼        ▼        ▼
               PROD      DEV     SHARED
```

More precisely, AWS documents Private-IP VPN as:

```text
Direct Connect
      ↓
Transit VIF
      ↓
Direct Connect Gateway
      ↓
Transit Gateway
      ↓
AWS-managed Site-to-Site VPN
with private outer tunnel IPs
```

The VPN terminates on the **Transit Gateway** on the AWS side and on the customer gateway device on-premises. ([AWS Documentation][1])

---

# 36.232 Important: Private-IP VPN requires Transit Gateway

For this AWS-managed feature, think:

```text
Private-IP VPN over DX
        ↓
       TGW
```

not:

```text
Private-IP VPN
        ↓
       VGW
```

The documented architecture requires:

```text
Transit Gateway
+
Direct Connect Gateway
+
Transit VIF
```

before the private-IP VPN is created. ([AWS Documentation][4])

This is a very good certification/interview distinction.

---

# 36.233 The prerequisite chain

Before creating Private-IP VPN, AWS expects this foundation:

```text
1. Transit Gateway
       │
       ▼
2. TGW private CIDR block
       │
       ▼
3. Direct Connect Gateway
       │
       ▼
4. DXGW ↔ TGW association
       │
       ▼
5. Transit VIF
       │
       ▼
6. Customer Gateway
       │
       ▼
7. Private-IP Site-to-Site VPN
```

AWS specifically requires a TGW CIDR for the private-IP VPN design, and that CIDR needs to be included in the DXGW association's allowed prefixes so the on-premises network can reach the AWS private VPN tunnel endpoints. ([AWS Documentation][4])

---

# 36.234 Why does TGW need its own CIDR?

Normally we think of TGW as:

```text
router
```

rather than:

```text
network with IP addresses
```

But some TGW features require TGW-owned addresses.

Examples include:

```text
Private-IP VPN
TGW Connect
Client VPN-related integrations
```

AWS allows an IPv4 TGW CIDR of `/24` or larger for these functions. These addresses must not overlap VPC attachments or on-premises networks, and `169.254.0.0/16` cannot be used as the TGW CIDR. ([AWS Documentation][5])

Example:

```text
TGW CIDR

10.254.0.0/24
```

This is **not**:

```text
Prod VPC CIDR
```

and not:

```text
Dev VPC CIDR.
```

It belongs to TGW itself.

---

# 36.235 Example enterprise IP plan

Let's use:

```text
ON-PREM

10.10.0.0/16


PROD

10.20.0.0/16


DEV

10.30.0.0/16


SHARED

10.40.0.0/16


TGW CIDR

10.254.0.0/24
```

Then the TGW CIDR:

```text
10.254.0.0/24
```

provides an address pool from which AWS can assign its Private-IP VPN outer tunnel endpoints. AWS documents TGW CIDR blocks as the shared address pool used for Private-IP VPN outer tunnel addresses and other TGW features. ([AWS Documentation][5])

---

# 36.236 Outer tunnel addresses vs inner tunnel addresses

This is where many engineers get lost.

There are **two different addressing layers**.

## Outer addresses

These identify:

```text
the actual IPsec tunnel endpoints
```

For Private-IP VPN, these are private IPv4 addresses.

Conceptually:

```text
CUSTOMER SIDE

10.253.0.10
      │
      │ IPsec transport
      │
10.254.0.x

AWS SIDE
```

The customer endpoint can use an RFC1918 address; AWS also documents RFC6598 as available for private endpoint addressing in the architecture. ([AWS Documentation][1])

---

# 36.237 Inner addresses

Inside the IPsec tunnel we still need point-to-point addressing for routing/BGP.

Example:

```text
Tunnel 1

169.254.21.1
      │
      │ BGP
      │
169.254.21.2
```

AWS Site-to-Site VPN supports `/30` IPv4 inside-tunnel CIDRs from the `169.254.0.0/16` range, subject to reserved ranges and uniqueness considerations. ([AWS Documentation][6])

Therefore:

```text
OUTER IP
=
creates/transports the tunnel


INNER IP
=
routing relationship inside the tunnel
```

---

# 36.238 Never mix these four IP categories

You'll now potentially see:

```text
1. Workload IP

10.20.5.50


2. Customer VPN outer endpoint

10.253.0.10


3. AWS VPN outer endpoint

10.254.0.x


4. VPN inside/BGP address

169.254.x.x
```

These serve completely different purposes.

---

# 36.239 A complete nested packet

Imagine:

```text
Prod EC2
10.20.5.50
```

needs to reach:

```text
Oracle
10.10.50.20
```

Original application packet:

```text
SRC = 10.20.5.50
DST = 10.10.50.20
```

IPsec encapsulates it.

Conceptually:

```text
OUTER PACKET

SRC = AWS private VPN endpoint
DST = customer private VPN endpoint


PAYLOAD

[encrypted]

    SRC = 10.20.5.50
    DST = 10.10.50.20
```

Then the outer packet itself travels over:

```text
TGW transport
   ↓
DXGW
   ↓
Transit VIF
   ↓
Direct Connect
```

This is exactly why we call Direct Connect the **underlay** and IPsec the **overlay**.

---

# 36.240 Physical picture

Visualize all layers at once:

```text
APPLICATION

10.20.5.50
    │
    │ SQL packet
    ▼

IPsec OVERLAY
══════════════════════════════
Encrypted workload packet
Private VPN endpoints
══════════════════════════════

    │
    ▼

DIRECT CONNECT UNDERLAY
──────────────────────────────
Transit VIF
DXGW
Physical DX
──────────────────────────────

    │
    ▼

CUSTOMER ROUTER
    │
    ▼
10.10.50.20
```

Never-forget sentence:

> **DX carries the encrypted VPN packet; the VPN carries the application packet.**

---

# 36.241 Customer Gateway endpoint choice

AWS explicitly warns that for Private-IP VPN you should not use the Direct Connect point-to-point BGP interface address as your VPN tunnel endpoint.

Instead, AWS recommends an address such as a:

```text
loopback interface
```

or:

```text
LAN interface
```

on the customer router. ([AWS Documentation][4])

Why?

Because we want the VPN endpoint to represent a stable router endpoint rather than tie the overlay unnecessarily to a single point-to-point Direct Connect interface.

Conceptually:

```text
Router

Loopback:
10.253.0.10
      │
      │ used as VPN endpoint
      ▼
DX transport
```

---

# 36.242 Why loopbacks are useful

Suppose:

```text
Router physical interface A
fails
```

If your VPN identity/end point is tightly tied to that interface address, your design may become more fragile.

A loopback is logically associated with the router rather than one physical Ethernet link.

Conceptually:

```text
         Router
           │
       Loopback
      10.253.0.10
        /      \
       /        \
    DX-A        DX-B
```

The exact redundancy design depends on your routing/device topology, but this is why stable loopback addresses are so commonly used in network infrastructure.

---

# 36.243 Two BGP layers can exist

This is advanced but very important.

Private-IP VPN over DX can involve:

## Underlay BGP

Between:

```text
Customer Router
      ↕
Direct Connect VIF
```

This establishes Direct Connect routing.

And:

## Overlay BGP

Inside:

```text
Site-to-Site VPN tunnel
```

between your customer gateway and AWS VPN/TGW side.

So:

```text
       BGP #1
Customer ───── AWS DX

        ↓

Direct Connect transport exists

        ↓

        IPsec

        ↓

       BGP #2
Customer ───── AWS VPN
```

Don't merge these into one BGP session in your head.

---

# 36.244 Underlay BGP's job

The Direct Connect BGP relationship must ensure that the **private VPN outer endpoints can reach each other**.

Example:

```text
Customer VPN outer endpoint

10.253.0.10
```

needs reachability toward:

```text
TGW VPN endpoint pool

10.254.0.0/24
```

The TGW private CIDR is placed into the Direct Connect Gateway allowed-prefix configuration and advertised toward the customer network. ([AWS Documentation][4])

Without that underlay reachability:

```text
IPsec tunnel
```

cannot even establish.

---

# 36.245 Overlay BGP's job

Once IPsec is established, VPN BGP exchanges actual workload routes.

For example:

On-prem advertises:

```text
10.10.0.0/16
```

AWS advertises:

```text
10.20.0.0/16
10.30.0.0/16
10.40.0.0/16
```

Conceptually:

```text
BGP inside encrypted VPN

ON-PREM                           AWS

10.10/16  ─────────────────────→

          ←───────────────────── 10.20/16
          ←───────────────────── 10.30/16
          ←───────────────────── 10.40/16
```

Dynamic routing is supported for Private-IP Site-to-Site VPN just like other appropriate TGW VPN architectures. ([AWS Documentation][4])

---

# 36.246 Underlay routes vs overlay routes

Another never-forget distinction:

```text
UNDERLAY ROUTES
───────────────

How do VPN endpoints reach each other?

Example:
10.254.0.0/24


OVERLAY ROUTES
──────────────

What business networks should travel
inside the encrypted VPN?

Example:
10.10.0.0/16
10.20.0.0/16
```

If:

```text
underlay broken
```

then:

```text
VPN = DOWN
```

If:

```text
underlay works
VPN = UP
overlay BGP broken
```

then:

```text
tunnel may be UP
but workloads still cannot communicate.
```

Same principle again:

# UP does not mean usable.

---

# 36.247 Transport Attachment ID

When AWS creates the Private-IP VPN connection, you select:

```text
Outside IP address type
=
PrivateIpv4
```

and identify the **transport attachment**, which is the TGW attachment corresponding to the appropriate Direct Connect Gateway. ([AWS Documentation][4])

Conceptually:

```text
Private-IP VPN

uses

DXGW TGW attachment
        │
        ▼
as underlying transport
```

That's how AWS knows:

> “This VPN's outer packets should traverse this Direct Connect attachment.”

---

# 36.248 Direct Connect underlay and VPN overlay both appear around TGW

This architecture can look strange:

```text
                  TGW

              ┌────┴────┐
              │         │
             DX        VPN
          Attachment Attachment
```

But the VPN itself is transported over the DX attachment.

Think:

```text
DX attachment
=
transport

VPN attachment
=
encrypted logical routing path
```

AWS allows the route table associated with the VPN attachment to be different from the route table associated with the underlying Direct Connect attachment. ([AWS Documentation][1])

This is extremely powerful.

---

# 36.249 Why separate TGW route tables?

Suppose you want:

```text
Production traffic
=
MUST be encrypted


Backup replication
=
may use ordinary DX
```

You could design routing domains so:

```text
Prod-associated TGW RT

10.10.0.0/16
→ Private-IP VPN attachment
```

while another route table could choose:

```text
10.10.0.0/16
→ DXGW attachment
```

AWS explicitly supports using different route tables for the Private-IP VPN and its underlying Direct Connect attachment, allowing encrypted and unencrypted routing to coexist. ([AWS Documentation][1])

This is advanced routing policy.

---

# 36.250 Example

Imagine:

```text
PROD VPC
10.20.0.0/16
```

must always use encryption.

Prod TGW route table:

```text
Destination       Target

10.10.0.0/16      Private-IP VPN
```

But:

```text
BACKUP VPC
10.60.0.0/16
```

could use raw Direct Connect.

Backup TGW route table:

```text
Destination       Target

10.10.0.0/16      DXGW Attachment
```

Therefore:

```text
Prod
 ↓
IPsec
 ↓
DX
 ↓
On-Prem
```

while:

```text
Backup
 ↓
DX
 ↓
On-Prem
```

can coexist.

---

# 36.251 TGW route priority becomes important

Remember the route priority we learned?

For the same prefix, Transit Gateway currently orders several propagated attachment types such that:

```text
Direct Connect Gateway propagated
       >
Private-IP Site-to-Site VPN over DX propagated
       >
ordinary Site-to-Site VPN propagated
```

with static routes and some other attachment types above them according to TGW's documented route evaluation sequence. ([AWS Documentation][7])

This means:

```text
If raw DX route and Private-IP VPN route
for the exact same CIDR
are both propagated into the SAME RT
```

TGW may prefer:

```text
DXGW propagated route
```

rather than your encrypted Private-IP VPN route. ([AWS Documentation][7])

That's very important.

---

# 36.252 So how do we force encrypted traffic?

Don't simply dump everything into one TGW route table and hope.

Design routing deliberately.

For example:

```text
PROD-RT

10.10.0.0/16
     ↓
VPN Attachment
```

and avoid competing unwanted direct-DX reachability in that routing domain.

This returns us to our Part 2 principle:

# TGW route tables are policy boundaries.

---

# 36.253 Encryption is not the same as routing preference

Never say:

> “Because this is a VPN route, AWS will automatically prefer encrypted traffic.”

That's incorrect.

Routing doesn't know:

```text
encrypted = morally better
```

It knows:

```text
prefix
route type
route priority
BGP attributes
route tables
```

If encrypted transport is mandatory:

```text
design the routing tables
so cleartext/direct alternatives
cannot bypass that requirement.
```

---

# 36.254 Full Private-IP VPN packet flow

Let's trace:

```text
Prod EC2
10.20.5.50
```

to:

```text
Corporate Oracle
10.10.50.20
```

---

## Step 1 — application creates packet

```text
SRC 10.20.5.50
DST 10.10.50.20
```

---

## Step 2 — Prod VPC route lookup

```text
10.10.0.0/16
       ↓
TGW
```

---

## Step 3 — TGW receives packet

Prod attachment is associated with:

```text
PROD-RT
```

and PROD-RT contains:

```text
10.10.0.0/16
       ↓
Private-IP VPN attachment
```

---

## Step 4 — packet enters VPN overlay

AWS encrypts the original packet using IPsec.

Conceptually:

```text
ORIGINAL

10.20.5.50 → 10.10.50.20

       ↓

IPsec encryption

       ↓

ENCRYPTED PAYLOAD
```

---

## Step 5 — outer packet is created

Conceptually:

```text
AWS private VPN endpoint
       ↓
Customer private VPN endpoint
```

These are private outer IPv4 addresses for Private-IP VPN. AWS supports the `PrivateIpv4` outside-tunnel type specifically for Site-to-Site VPN over Direct Connect. ([AWS Documentation][6])

---

## Step 6 — outer packet follows Direct Connect underlay

```text
Private VPN endpoint
      │
      ▼
TGW transport attachment
      │
      ▼
DXGW
      │
      ▼
Transit VIF
      │
      ▼
Direct Connect
      │
      ▼
Customer Router
```

---

## Step 7 — Customer Gateway decrypts packet

Customer device removes IPsec encapsulation.

Original packet reappears:

```text
SRC 10.20.5.50
DST 10.10.50.20
```

Then corporate routing sends it toward:

```text
Oracle
10.10.50.20
```

---

# 36.255 Return path

Oracle responds:

```text
SRC 10.10.50.20
DST 10.20.5.50
```

Corporate routing sends:

```text
10.20.0.0/16
      ↓
VPN
```

Customer Gateway encrypts it:

```text
IPsec
```

Outer packet travels through:

```text
Direct Connect
  ↓
Transit VIF
  ↓
DXGW
  ↓
TGW transport
```

AWS VPN decrypts it.

Then:

```text
TGW
 ↓
Prod attachment
 ↓
10.20.5.50
```

Forward and return routing still both matter.

---

# 36.256 Why would a bank or regulated organization want this?

Consider the requirement:

```text
Traffic must:

1. Avoid normal Internet path
2. Use private addressing
3. Be cryptographically protected
4. Reach many AWS VPCs centrally
```

Private-IP VPN gives:

```text
Direct Connect
        +
Transit VIF
        +
private outer tunnel addresses
        +
AWS-managed IPsec
        +
Transit Gateway
```

AWS specifically identifies regulated industries such as financial, healthcare, and government/federal environments as major use cases for the private-IP VPN feature. ([AWS Documentation][1])

---

# 36.257 Public-IP VPN over DX vs Private-IP VPN over DX

| Characteristic                     | Public-IP VPN over DX          | Private-IP VPN over DX                  |
| ---------------------------------- | ------------------------------ | --------------------------------------- |
| DX VIF                             | Public VIF                     | Transit VIF                             |
| VPN outer endpoints                | Public IP                      | Private IPv4                            |
| Internet required for DX transport | No                             | No                                      |
| DXGW                               | Depends on architecture        | Required                                |
| TGW                                | Optional depending design      | Required for AWS-managed Private-IP VPN |
| IPsec                              | Yes                            | Yes                                     |
| Public AWS reachability via VIF    | Public VIF model               | Not required                            |
| Best mental model                  | DX path to public VPN endpoint | Private encrypted TGW architecture      |

AWS recommends public-VIF-based IPsec when public VPN endpoint addressing is acceptable, while Private-IP VPN provides a transit-VIF-based option when private endpoint addressing and multi-VPC TGW connectivity are desired. ([AWS Documentation][3])

---

# 36.258 MACsec vs Private-IP VPN

Now compare another option.

## MACsec

```text
Customer router
      │
      │ encrypted Layer 2
      ▼
AWS DX edge
```

AWS describes Direct Connect MACsec as Layer-2 point-to-point encryption between the customer edge device and AWS Direct Connect edge device. It does not itself provide end-to-end encryption across arbitrary subsequent network segments. ([AWS Documentation][8])

---

## IPsec over DX

```text
On-premises network
       │
       │ encrypted Layer 3 tunnel
       ▼
AWS VPN / TGW
```

So:

```text
MACsec
=
link protection


IPsec
=
network-layer tunnel protection
```

---

# 36.259 Which one should I use?

Don't memorize:

```text
IPsec > MACsec
```

or:

```text
MACsec > IPsec
```

They solve different requirements.

### Consider MACsec when:

```text
Layer-2 DX link encryption is required
supported DX connection/location exists
minimal VPN encapsulation overhead is desirable
```

### Consider Private-IP VPN when:

```text
IPsec is required
private VPN endpoint addresses are required
TGW-based centralized architecture is desired
encryption should be applied as a routed overlay
```

AWS explicitly notes that VPN-over-DX adds encryption but can introduce MTU/throughput considerations, while MACsec does not impose the same Site-to-Site VPN encapsulation considerations. ([AWS Documentation][9])

---

# 36.260 Can you use MACsec AND IPsec?

Conceptually yes, where supported and architecturally justified:

```text
Application
    │
    ▼
IPsec
    │
    ▼
MACsec
    │
    ▼
DX physical link
```

But now you're layering:

```text
application encryption maybe TLS
+
IPsec
+
MACsec
```

That may be entirely justified for a particular security/compliance model—or unnecessary complexity.

Never add encryption layers simply because more encryption sounds better.

Ask:

```text
What threat are we protecting against?

Where are encryption boundaries required?

What does compliance require?

What operational complexity follows?
```

---

# 36.261 MTU — where VPN-over-DX becomes interesting

Direct Connect may support larger frames in appropriate configurations, but IPsec adds headers.

Simplified original packet:

```text
┌───────────────────────┐
│ Original IP packet    │
└───────────────────────┘
```

After VPN encapsulation:

```text
┌──────────────┐
│ Outer IP     │
├──────────────┤
│ ESP / IPsec  │
├──────────────┤
│ Original IP  │
│ + payload    │
└──────────────┘
```

We added bytes.

Therefore the amount of actual application data that fits without fragmentation decreases.

---

# 36.262 Current AWS Site-to-Site VPN MTU guidance

AWS currently documents Site-to-Site VPN with a maximum MTU of **1446 bytes** and corresponding maximum TCP MSS of **1406 bytes**, while noting that specific cryptographic algorithms can reduce the practical values further. Site-to-Site VPN also does not support Path MTU Discovery. ([AWS Documentation][10])

Therefore don't blindly configure:

```text
MTU = 1500 everywhere
```

and assume every encrypted flow will behave perfectly.

---

# 36.263 What is MSS?

MTU:

```text
Maximum Transmission Unit
```

roughly asks:

> How large may the IP packet/frame payload be for this path?

MSS:

```text
Maximum Segment Size
```

asks:

> How much TCP application payload should one TCP segment carry?

Conceptually:

```text
MTU

┌─────────────────────────────┐
│ IP Header                   │
│ TCP Header                  │
│ Application Data            │
└─────────────────────────────┘


MSS

             ┌───────────────┐
             │Application Data│
             └───────────────┘
```

MSS is smaller because protocol headers consume some of the available MTU.

---

# 36.264 Classic MTU symptom

Imagine:

```text
ping 10.10.50.20
```

works.

Small HTTP requests work.

But:

```text
large HTTPS transfer
database export
file copy
```

hangs.

You may think:

```text
Security Group?
Firewall?
RDS?
```

But the problem may be:

```text
MTU / fragmentation / MSS
```

This is a classic hybrid-networking troubleshooting category.

---

# 36.265 Why PMTUD deserves attention

Ordinary networking can sometimes use:

```text
Path MTU Discovery
```

to discover the maximum usable packet size.

However, AWS explicitly states that Site-to-Site VPN does **not support Path MTU Discovery**. ([AWS Documentation][11])

Therefore you should treat MTU/MSS planning on the customer gateway seriously instead of assuming the network will always self-correct.

---

# 36.266 Linux troubleshooting preview

Later in the lab we'll use commands such as:

```bash
ping -M do -s 1400 <destination>
```

and:

```bash
tracepath <destination>
```

plus:

```bash
tcpdump -ni any host <destination>
```

to investigate:

```text
fragmentation
TCP handshakes
retransmissions
MSS
ICMP
```

The exact safe packet sizes depend on the VPN algorithms/configuration, so we'll validate rather than blindly hard-code one value.

---

# 36.267 Private-IP VPN route scale

A useful current feature difference: AWS documents Private-IP VPN connections with route limits of **5,000 outbound routes and 1,000 inbound routes**, compared with lower route limits for Direct Connect alone in that specific comparison. ([AWS Documentation][1])

Why could this matter?

Large enterprise networks may have:

```text
hundreds of VPC CIDRs
many branch networks
acquisition networks
regional networks
data-center prefixes
```

So route scale can become a real architectural criterion.

As always with service quotas, verify the current quota when designing production because AWS capabilities evolve.

---

# 36.268 Private-IP VPN supports static or dynamic routing

When creating the connection, AWS currently allows:

```text
Dynamic routing
→ BGP

or

Static routing
```

depending on your customer gateway capability. ([AWS Documentation][4])

For our enterprise architecture:

```text
BGP
```

is normally the more interesting choice because we need:

```text
route learning
failover
withdrawal
redundancy
```

But the static option exists.

---

# 36.269 Two tunnels still exist

Private-IP VPN doesn't remove the Site-to-Site VPN redundancy model.

We're still thinking:

```text
VPN CONNECTION

       ┌───────────┐
       │           │
   Tunnel 1    Tunnel 2
       │           │
       └─────┬─────┘
             │
        Customer Gateway
```

The distinction is that the outer VPN tunnel endpoints use:

```text
PrivateIpv4
```

and the transport is Direct Connect rather than ordinary public-IP VPN transport. ([AWS Documentation][6])

---

# 36.270 Private-IP VPN + dual Direct Connect

Now let's make the design resilient.

```text
                       CORPORATE DC

                 Router A       Router B
                     │             │
                     ▼             ▼
                   DX-A           DX-B
                     │             │
                     └──────┬──────┘
                            ▼
                       Transit VIF
                            │
                           DXGW
                            │
                            ▼
                           TGW
                            │
                 PRIVATE IPsec VPN
                            │
                       VPN Attachment
                            │
                  ┌─────────┼─────────┐
                  ▼         ▼         ▼
                PROD       DEV      SHARED
```

Now we need both:

```text
underlay resiliency
```

and:

```text
overlay resiliency.
```

---

# 36.271 Underlay resiliency

Ask:

```text
If DX-A dies:

Can the private VPN outer endpoints
still reach each other through DX-B?
```

If yes, the underlying path may reconverge while the overlay remains or reestablishes according to device/session behavior.

If no:

```text
IPsec goes DOWN.
```

This is why redundancy needs to be designed at every layer.

---

# 36.272 Overlay resiliency

Even with perfect Direct Connect redundancy:

```text
DX-A ✓
DX-B ✓
```

the VPN itself can fail because of:

```text
IKE mismatch
PSK problem
IPsec problem
BGP problem
tunnel maintenance
incorrect routes
endpoint reachability
```

So:

```text
transport health
```

and:

```text
VPN health
```

need separate monitoring.

---

# 36.273 Three layers of health

For Private-IP VPN over DX, check:

```text
LAYER 1 — DIRECT CONNECT

Connection UP?
VIF UP?
DX BGP UP?


LAYER 2 — VPN UNDERLAY

Can private outer endpoints reach?
Correct TGW CIDR advertised?
DXGW association correct?


LAYER 3 — VPN OVERLAY

IKE UP?
IPsec UP?
Tunnel UP?
VPN BGP UP?
Routes learned?
```

And then:

```text
LAYER 4 — APPLICATION

TGW route?
VPC route?
Security Group?
NACL?
Firewall?
DNS?
Application?
```

That's the troubleshooting hierarchy I want you to use.

---

# 36.274 Incident example

Ticket:

> **“Private VPN tunnel suddenly went DOWN after networking changed the Direct Connect route filters.”**

You should immediately suspect the underlay.

Check:

```text
1. DX connection
      ↓
2. Transit VIF
      ↓
3. Direct Connect BGP
      ↓
4. TGW private CIDR advertised?
      ↓
5. Customer VPN endpoint route?
      ↓
6. AWS VPN endpoint reachable?
```

Perhaps someone removed:

```text
10.254.0.0/24
```

from the allowed-prefix/routing path.

Then:

```text
private outer endpoints
cannot communicate
```

so:

```text
IKE cannot establish
```

even though:

```text
Direct Connect itself remains UP.
```

---

# 36.275 Another incident

Ticket:

> **“VPN tunnel is UP and BGP is UP, but Prod traffic travels unencrypted through Direct Connect.”**

This is very interesting.

Possible cause:

```text
PROD TGW route table
```

contains a preferred route directly through:

```text
DXGW attachment
```

rather than through:

```text
Private-IP VPN attachment.
```

Remember TGW route priority: for an identical propagated prefix, Direct Connect Gateway routes currently rank above Private-IP VPN-over-DX propagated routes. ([AWS Documentation][7])

So the VPN can be perfectly healthy while traffic bypasses it.

This is why routing policy is part of the encryption architecture.

---

# 36.276 Another incident

> **“VPN UP. BGP UP. Ping works. Database replication fails only with large transfers.”**

Think:

```text
MTU
MSS
fragmentation
```

before spending four hours changing IAM policies.

AWS specifically warns that VPN-over-Direct-Connect encryption reduces usable MTU and can affect throughput. ([AWS Documentation][9])

---

# 36.277 Another incident

> **“DX BGP is UP, but private VPN will not establish.”**

Separate BGP sessions.

You could have:

```text
DX BGP
     UP
```

but:

```text
VPN outer endpoint route
     missing
```

or:

```text
IKE
     failed
```

or:

```text
PrivateIpv4 outside tunnel
configuration wrong
```

or:

```text
CGW private endpoint
wrong.
```

Do not conclude:

```text
BGP UP
=
VPN should work.
```

Ask:

> **Which BGP session is UP?**

---

# 36.278 Private-IP VPN vs normal VPN backup

Now consider:

```text
Private-IP VPN over DX
```

plus:

```text
ordinary Internet Site-to-Site VPN
```

Architecture:

```text
                      ON-PREM

                ┌───────┴────────┐
                │                │
                ▼                ▼

          Direct Connect       Internet
                │                │
                ▼                ▼
        Private-IP VPN      Public-IP VPN
                │                │
                └───────┬────────┘
                        ▼
                       TGW
```

This gives different failure domains:

```text
Encrypted private DX path
        +
Encrypted Internet backup path
```

But route-policy design must again determine:

```text
which VPN wins?
what happens when DX disappears?
how does failback happen?
```

---

# 36.279 Interesting TGW route priority

For the same CIDR, TGW currently prefers:

```text
Private-IP VPN over Direct Connect propagated route
```

over:

```text
ordinary Site-to-Site VPN propagated route
```

according to AWS's attachment-type route priority. ([AWS Documentation][7])

That can help create:

```text
Private-IP VPN over DX
       =
primary

Internet VPN
       =
backup
```

when the design is entirely dynamic and aligned with AWS route priority.

Again, check for static routes—they can change the outcome.

---

# 36.280 Enterprise architecture

We're now capable of understanding this:

```text
                      CORPORATE DATA CENTER
                           10.10.0.0/16

                    ┌─────────────────────┐
                    │ Customer Routers    │
                    │   A            B    │
                    └───┬────────────┬────┘
                        │            │
                        ▼            ▼
                     DX-A          DX-B
                        │            │
                 DX Location A  DX Location B
                        │            │
                        └─────┬──────┘
                              │
                       Transit VIF(s)
                              │
                              ▼
                             DXGW
                              │
                              ▼
                ┌─────────────────────┐
                │   TRANSIT GATEWAY   │
                │    10.254.0.0/24    │
                └──────────┬──────────┘
                           │
                           │
                   PRIVATE-IP IPsec
                           │
                       VPN Attachment
                           │
                 ┌─────────┼─────────┐
                 ▼         ▼         ▼
              PROD       SHARED   SECURITY
           10.20/16     10.40/16   10.50/16
                │          │          │
               ECS        AD/DNS   Firewall
                │
               RDS


Backup path:

Customer routers
      │
      ▼
Internet
      │
Public IPsec VPN
      │
      ▼
TGW
```

Now we have:

```text
✓ Dual Direct Connect

✓ Private endpoint addressing

✓ IPsec encryption

✓ TGW multi-VPC routing

✓ BGP

✓ Internet VPN backup

✓ Centralized segmentation
```

That is a serious enterprise hybrid design.

---

# 36.281 Never-forget comparison

| Architecture        | Transport      | VPN outer IP                              | VIF             | Encryption              |
| ------------------- | -------------- | ----------------------------------------- | --------------- | ----------------------- |
| Normal DX           | Direct Connect | N/A                                       | Private/Transit | Not by DX automatically |
| Public VPN over DX  | Direct Connect | Public                                    | Public VIF      | IPsec                   |
| Private VPN over DX | Direct Connect | Private IPv4                              | Transit VIF     | IPsec                   |
| Internet S2S VPN    | Internet       | Usually public/other supported outer type | None            | IPsec                   |
| DX + MACsec         | Direct Connect | N/A                                       | DX VIF          | Layer-2 MACsec          |

---

# 36.282 Never-forget component mapping

```text
DIRECT CONNECT
=
underlay transport


TRANSIT VIF
=
logical DX connection toward TGW architecture


DXGW
=
Direct Connect gateway/routing association layer


TGW TRANSPORT ATTACHMENT
=
underlay reaches AWS side


PRIVATE VPN OUTER IP
=
IPsec endpoint identity


IPsec
=
encryption overlay


VPN INSIDE /30
=
routing adjacency inside tunnel


BGP
=
advertises workload networks


TGW VPN ATTACHMENT
=
encrypted network routing path


TGW ROUTE TABLE
=
decides which workloads use that encrypted path
```

If you understand that mapping, this advanced architecture becomes far less intimidating.

---

# 36.283 The most important diagram from Part 5

```text
             ORIGINAL APPLICATION PACKET

       10.20.5.50 ─────────→ 10.10.50.20

                       │
                       ▼

               ┌────────────────┐
               │     IPsec      │
               │    OVERLAY     │
               └───────┬────────┘

                       │
            encrypted inner packet
                       │
                       ▼

              PRIVATE OUTER IPS

           AWS endpoint ── Customer endpoint

                       │
                       ▼

             ┌────────────────────┐
             │   DIRECT CONNECT   │
             │      UNDERLAY      │
             │                    │
             │ TGW → DXGW → VIF   │
             └─────────┬──────────┘

                       │
                       ▼

                CUSTOMER ROUTER

                       │
                  IPsec decrypt
                       │
                       ▼

       10.20.5.50 ─────────→ 10.10.50.20
```

That is the mental picture to keep.

---

# 36.284 Interview questions you should now answer easily

**Question:** Does Direct Connect encrypt traffic automatically?

```text
No.
```

AWS Direct Connect does not provide transit encryption by default; MACsec or VPN-based encryption can be added. ([AWS Documentation][2])

**Question:** Which VIF does AWS-managed Private-IP VPN over DX use?

```text
Transit VIF.
```

([AWS Documentation][1])

**Question:** Does Private-IP VPN use public outer tunnel addresses?

```text
No.

Outside tunnel IP type:
PrivateIpv4
```

([AWS Documentation][6])

**Question:** What AWS VPN target is required for this architecture?

```text
Transit Gateway.
```

([AWS Documentation][4])

**Question:** Why does TGW need its own CIDR?

```text
Among other supported functions,
AWS uses it as an address pool for
Private-IP VPN tunnel endpoints.
```

([AWS Documentation][5])

**Question:** Should I use the DX point-to-point BGP address as my customer VPN endpoint?

```text
No.

AWS recommends using
a loopback or LAN address.
```

([AWS Documentation][4])

**Question:** Does VPN-over-DX affect MTU?

```text
Yes.

IPsec encapsulation introduces overhead.
```

([AWS Documentation][9])

---

# 36.285 Five lines to remember forever

```text
1.

Direct Connect gives me the transport.


2.

IPsec gives me the encrypted overlay.


3.

Private-IP VPN over DX uses:

Transit VIF → DXGW → TGW.


4.

Outer private IPs build the VPN;
inside tunnel IPs run routing inside it.


5.

Encryption only happens if routing
actually sends the workload through
the VPN attachment.
```

Number five is especially important.

---

# Next — Lesson 36, Part 6

## Route 53 Resolver Hybrid DNS — On-Prem ↔ AWS Name Resolution

Networking is now working:

```text
10.20.5.50
      ↓
Direct Connect / VPN
      ↓
10.10.50.20
```

But real applications don't normally connect using:

```text
10.10.50.20
```

They connect using something like:

```text
oracle-prod.corp.internal
```

And on-premises users may need:

```text
payments.prod.aws.internal
```

So our next problem becomes:

```text
AWS knows how to ROUTE to on-prem...

but does AWS know how to RESOLVE
on-prem DNS names?
```

Next we'll build:

```text
                 CORPORATE DATA CENTER

                   AD / DNS Servers
                    10.10.1.53
                          │
                          │
                   DX / VPN / TGW
                          │
                          ▼

               SHARED SERVICES VPC

              Route 53 Resolver
              ┌─────────┴─────────┐
              │                   │
         INBOUND              OUTBOUND
         ENDPOINT              ENDPOINT
              │                   │
              ▼                   ▼

On-Prem → AWS DNS         AWS → On-Prem DNS

corp → Route53            corp.internal
Private Hosted Zone       → AD DNS
```

We'll go deep into **AmazonProvidedDNS, VPC Resolver, Route 53 Private Hosted Zones, inbound endpoints, outbound endpoints, conditional forwarding, Resolver rules, Active Directory DNS, shared-services VPC architecture, AWS RAM rule sharing, multi-account DNS, split-horizon DNS, DNS security/firewalls, failure scenarios, cross-Region design, Terraform, and packet-by-packet DNS troubleshooting**.

[1]: https://docs.aws.amazon.com/vpn/latest/s2svpn/private-ip-dx.html "Private IP AWS Site-to-Site VPN with Direct Connect - AWS Site-to-Site VPN"
[2]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/encryption-in-transit.html "Encryption in AWS Direct Connect - AWS Direct Connect"
[3]: https://docs.aws.amazon.com/wellarchitected/latest/hybrid-networking-lens/aws-direct-connect-and-ipsec-vpn.html "AWS Direct Connect and IPSec VPN - Hybrid Networking Lens - AWS Well-Architected Framework"
[4]: https://docs.aws.amazon.com/vpn/latest/s2svpn/private-ip-dx-steps.html "Create a private IP AWS Site-to-Site VPN over Direct Connect - AWS Site-to-Site VPN"
[5]: https://docs.aws.amazon.com/vpc/latest/tgw/create-tgw.html?utm_source=chatgpt.com "Create a transit gateway in AWS Transit Gateway - Amazon VPC"
[6]: https://docs.aws.amazon.com/vpn/latest/s2svpn/tunnel-configure.html "Configure tunnel options for AWS Site-to-Site VPN - AWS Site-to-Site VPN"
[7]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html "How AWS Transit Gateway works - Amazon VPC"
[8]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/MACsec.html "MAC Security in Direct Connect - AWS Direct Connect"
[9]: https://docs.aws.amazon.com/whitepapers/latest/hybrid-connectivity/performance.html?utm_source=chatgpt.com "Performance - Hybrid Connectivity"
[10]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-limits.html?utm_source=chatgpt.com "AWS Site-to-Site VPN quotas"
[11]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html?utm_source=chatgpt.com "AWS Site-to-Site VPN"
