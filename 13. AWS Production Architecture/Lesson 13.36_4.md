# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 4: Resilient Hybrid Routing — BGP, DX + VPN Failover, Active/Active & Active/Passive

We now have the individual building blocks:

```text
Site-to-Site VPN
Direct Connect
DXGW
Transit Gateway
BGP
VPCs
```

Now comes the production question:

> **If several network paths exist between AWS and the data center, which one will actually carry the packet?**

Consider:

```text
                         CORPORATE DC
                              │
                     ┌────────┴─────────┐
                     │                  │
                     ▼                  ▼
               Direct Connect      Site-to-Site VPN
                     │                  │
                     └────────┬─────────┘
                              ▼
                             TGW
                              │
                             PROD
```

Both paths reach the same destination.

So we need to understand **route selection**.

---

# 36.154 First principle — redundancy without routing policy is incomplete

Suppose we build:

```text
               ┌──── DX-1 ──── AWS
ON-PREM ───────┤
               ├──── DX-2 ──── AWS
               │
               └──── VPN ───── AWS
```

That gives us several physical/logical paths.

But we haven't answered:

```text
Which path is PRIMARY?

Which path is SECONDARY?

Can both DX connections carry traffic?

When does VPN take over?

How quickly is failure detected?

What happens when DX comes back?

Could forward and reverse packets choose
different paths?
```

That's what BGP policy solves. AWS recommends redundant physical connectivity combined with dynamic BGP so traffic can reroute when paths fail. ([AWS Documentation][1])

---

# 36.155 Separate two directions

This is one of the most important things today.

Imagine:

```text
ON-PREM
10.10.0.0/16

AWS
10.20.0.0/16
```

There are TWO independent routing decisions:

```text
Direction A

ON-PREM ───────────────→ AWS


Direction B

AWS ───────────────────→ ON-PREM
```

Do not assume:

```text
If DX is preferred one way
     ↓
DX must automatically be preferred
the other way.
```

Routing is directional.

This can produce:

# Asymmetric routing.

We'll come back to it.

---

# 36.156 BGP route-selection mental model

A simplified BGP decision might consider things such as:

```text
Destination prefix specificity
        ↓
Routing policy
        ↓
Local Preference
        ↓
AS_PATH
        ↓
MED
        ↓
ECMP / other tie breakers
```

But here's an important warning:

> **There is no single universal sequence you should blindly apply to every AWS routing component.**

Your corporate router has its BGP decision process.

Direct Connect has AWS-specific policies.

Transit Gateway has its own route-table evaluation rules.

For TGW specifically, AWS first selects the most-specific route. When identical CIDRs come from different attachment types, TGW applies an AWS-defined attachment-type priority. For same-CIDR BGP routes of the same attachment type, shorter AS_PATH and then lower MED are considered. ([AWS Documentation][2])

So always ask:

```text
Where is the route decision occurring?

Customer router?
Direct Connect?
TGW?
VPC route table?
```

---

# 36.157 Rule #1 — Longest Prefix Match

This remains fundamental.

Suppose a router has:

```text
10.0.0.0/8       → VPN
10.20.0.0/16     → DX
10.20.5.0/24     → DX-2
```

Destination:

```text
10.20.5.25
```

Matches all three.

But:

```text
/24
```

is the most specific.

Therefore:

```text
10.20.5.0/24 → DX-2
```

wins.

Memory trick:

```text
/32
 >
/24
 >
/16
 >
/8
 >
/0
```

TGW also begins route evaluation with the most-specific matching destination. ([AWS Documentation][2])

---

# 36.158 Why this can accidentally destroy failover

Imagine you intend:

```text
DX  = primary
VPN = backup
```

but you advertise:

### DX

```text
10.20.0.0/16
```

### VPN

```text
10.20.5.0/24
```

Traffic for:

```text
10.20.5.25
```

will prefer:

```text
VPN
```

because:

```text
/24 > /16
```

even though you called DX "primary".

Labels like:

```text
PRIMARY
BACKUP
```

have absolutely no magical networking meaning.

Routing information determines reality.

---

# 36.159 Local Preference — LOCAL_PREF

In enterprise BGP, local preference tells a routing domain:

> "Which exit path do I prefer?"

Conceptually:

```text
                 AWS

        DX-1             DX-2
          │                │
          ▼                ▼
       Route A          Route B

LOCAL_PREF 200       LOCAL_PREF 100
```

Your router prefers:

```text
200
```

over:

```text
100
```

So:

```text
DX-1 = preferred outbound path
```

A useful mental rule:

```text
Higher LOCAL_PREF
       =
more preferred
```

---

# 36.160 On-prem → AWS route preference

Suppose AWS advertises:

```text
10.20.0.0/16
```

over both DX connections.

Your corporate BGP policy could decide:

```text
Learned via DX-A:
10.20.0.0/16
LOCAL_PREF 200


Learned via DX-B:
10.20.0.0/16
LOCAL_PREF 150
```

Then:

```text
Corporate → AWS

normally uses DX-A
```

If DX-A fails:

```text
DX-A route disappears
        ↓
DX-B becomes best
        ↓
traffic shifts
```

This is an:

# Active/Passive design.

---

# 36.161 AWS → on-prem is a separate problem

Now AWS needs to reach:

```text
10.10.0.0/16
```

Your routers advertise the prefix toward AWS over multiple Direct Connect VIFs.

How do we tell AWS:

```text
DX-A preferred
DX-B backup
```

Direct Connect supports AWS local-preference BGP community tags on prefixes you advertise:

```text
7224:7100 → low
7224:7200 → medium
7224:7300 → high
```

AWS says these communities are evaluated before AS_PATH for Direct Connect local-preference handling. ([AWS Documentation][3])

Example:

```text
DX-A advertises:

10.10.0.0/16
community 7224:7300


DX-B advertises:

10.10.0.0/16
community 7224:7100
```

Result:

```text
AWS → On-Prem

DX-A preferred
DX-B passive/backup
```

([AWS Documentation][3])

---

# 36.162 Why local preference must be understood directionally

Let's summarize:

### On your router

You can use your own routing policy/local preference to decide:

```text
ON-PREM → AWS
```

### Direct Connect communities

You can tag prefixes you advertise so AWS can influence:

```text
AWS → ON-PREM
```

This is crucial.

```text
             ROUTING POLICY

        ON-PREM              AWS
           │                  │
           │                  │
  Your BGP policy       AWS DX communities
           │                  │
           ▼                  ▼

     ON-PREM → AWS      AWS → ON-PREM
```

---

# 36.163 Active/Passive Direct Connect architecture

Let's build one.

```text
                        CORPORATE DC
                             │
                       ┌─────┴─────┐
                       │           │
                    Router A    Router B
                       │           │
                       ▼           ▼
                     DX-A         DX-B
                   PRIMARY       BACKUP
                       │           │
                       └─────┬─────┘
                             ▼
                            AWS
```

### On-prem → AWS

```text
DX-A LOCAL_PREF = 200
DX-B LOCAL_PREF = 100
```

### AWS → on-prem

Advertise:

```text
DX-A:
10.10.0.0/16
community 7224:7300


DX-B:
10.10.0.0/16
community 7224:7100
```

AWS documents this high/low community pattern specifically for active/passive Direct Connect failover. ([AWS Documentation][3])

Result:

```text
NORMAL

On-Prem
   │
   ▼
 DX-A
   │
   ▼
 AWS


DX-B
standing by
```

---

# 36.164 What happens when DX-A fails?

Suppose:

```text
fiber cut
```

takes down DX-A.

Conceptually:

```text
DX-A physical connection fails
          ↓
BGP adjacency/path disappears
          ↓
routes through DX-A withdrawn
          ↓
routing table recalculates
          ↓
DX-B becomes preferred surviving route
          ↓
traffic converges onto DX-B
```

Dynamic BGP is specifically valuable because route withdrawal/recalculation allows traffic to move to another available path without manually editing route tables. ([AWS Documentation][1])

---

# 36.165 Active/Active Direct Connect

Maybe we don't want:

```text
DX-B sitting mostly idle.
```

Instead:

```text
          ON-PREM
             │
       ┌─────┴─────┐
       ▼           ▼
     DX-A         DX-B
    ACTIVE        ACTIVE
       │           │
       └─────┬─────┘
             ▼
            AWS
```

AWS Direct Connect supports active/active BGP multipath configurations where traffic can be load-shared by flow across available paths. ([AWS Documentation][4])

---

# 36.166 AWS → on-prem active/active

For AWS to consider the DX paths equally preferred, you can advertise the same prefix with the same Direct Connect local-preference community.

Example:

```text
DX-A

10.10.0.0/16
community 7224:7200


DX-B

10.10.0.0/16
community 7224:7200
```

AWS documents equal community preference as a way to support active/active load balancing across Direct Connect connections. ([AWS Documentation][3])

Conceptually:

```text
               AWS
              /   \
             /     \
          DX-A     DX-B
            \       /
             \     /
             ON-PREM
```

---

# 36.167 ECMP

This introduces:

# Equal-Cost Multi-Path

ECMP means:

```text
Multiple paths
+
equivalent routing preference
=
multiple paths may be used
```

Not:

```text
Packet 1 → DX-A
Packet 2 → DX-B
Packet 3 → DX-A
```

necessarily.

Direct Connect's active/active model distributes traffic based on flows, which helps avoid packet-by-packet reordering. ([AWS Documentation][4])

Think:

```text
TCP Flow A → DX-A
TCP Flow B → DX-B
TCP Flow C → DX-A
TCP Flow D → DX-B
```

Conceptually.

---

# 36.168 Active/Active vs Active/Passive

| Design                   | Behaviour                                          |
| ------------------------ | -------------------------------------------------- |
| Active/Passive           | One preferred, another standby                     |
| Active/Active            | Multiple paths carry traffic                       |
| Active/Passive advantage | Simpler deterministic routing                      |
| Active/Active advantage  | Uses available capacity                            |
| Active/Active challenge  | Greater sensitivity to symmetry/policy consistency |
| Both                     | Can provide failover                               |

Neither is universally correct.

You choose based on:

```text
Traffic patterns
Firewall architecture
Application sensitivity
Bandwidth
Operational complexity
Failure requirements
```

---

# 36.169 AS_PATH

Now suppose the local-preference policy isn't enough or you're working with a scenario where AS_PATH is part of your desired control.

BGP records which autonomous systems a route passed through.

Example:

```text
Route A

10.10.0.0/16
AS_PATH:
65000


Route B

10.10.0.0/16
AS_PATH:
65000 65000 65000
```

Among otherwise comparable paths:

```text
shorter AS_PATH
```

is usually preferred.

TGW also uses shorter AS_PATH when comparing same-CIDR BGP routes of the same relevant attachment type. ([AWS Documentation][2])

---

# 36.170 AS_PATH prepending

Suppose:

```text
DX-A = primary
DX-B = backup
```

On DX-B, we may deliberately advertise:

```text
65000
65000
65000
```

rather than:

```text
65000
```

Conceptually:

```text
DX-A

10.10.0.0/16
AS_PATH 65000


DX-B

10.10.0.0/16
AS_PATH 65000 65000 65000
```

This is called:

# AS_PATH prepending

It makes one route appear longer/less attractive under policies where AS_PATH is being considered.

---

# 36.171 But remember the Direct Connect community rule

For Direct Connect AWS-side local preference:

```text
LOCAL-PREFERENCE COMMUNITY
```

is evaluated before:

```text
AS_PATH
```

according to AWS Direct Connect routing policy. ([AWS Documentation][3])

So this would be a mistake:

```text
DX-A:
community LOW
AS_PATH short


DX-B:
community HIGH
AS_PATH very long
```

and expecting the short AS_PATH to automatically make DX-A win.

AWS evaluates the DX local-preference community first. ([AWS Documentation][3])

Memory:

```text
AWS DX communities
       ↓
strong path-preference control
       ↓
AS_PATH considered later
```

---

# 36.172 MED

Another BGP attribute is:

# Multi-Exit Discriminator — MED

Conceptually:

> "If you enter my network through several links, I'd prefer this entry point."

Simplified:

```text
Lower MED
=
more preferred
```

For same-CIDR routes from the same TGW attachment type, AWS TGW considers:

```text
shorter AS_PATH
then
lower MED
```

as part of route priority. ([AWS Documentation][2])

You don't need to become a CCIE today.

But recognize:

```text
LOCAL_PREF
AS_PATH
MED
Communities
```

as core BGP traffic-engineering concepts.

---

# 36.173 Now introduce VPN backup

Our enterprise design becomes:

```text
                            ON-PREM

                    ┌─────────┼─────────┐
                    │         │         │
                    ▼         ▼         ▼
                  DX-A      DX-B       VPN
                 ACTIVE    ACTIVE     BACKUP
                    │         │         │
                    └─────────┼─────────┘
                              ▼
                             TGW
                              │
                   ┌──────────┼──────────┐
                   ▼          ▼          ▼
                 PROD        DEV       SHARED
```

Now AWS receives the same on-prem prefix over:

```text
Direct Connect Gateway attachment
+
Site-to-Site VPN attachment
```

What happens?

---

# 36.174 TGW has an important built-in route priority

For an identical destination prefix coming from different attachment types, Transit Gateway has an AWS-defined route priority.

Relevant portion:

```text
VPC propagated
      ↓
DXGW propagated
      ↓
Connect propagated
      ↓
Private-IP VPN-over-DX propagated
      ↓
Site-to-Site VPN propagated
```

with static routes having still higher priority for an identical destination. ([AWS Documentation][2])

So for identical dynamically propagated prefixes:

```text
DXGW propagated route
```

is preferred over:

```text
Site-to-Site VPN propagated route
```

by TGW. ([AWS Documentation][2])

This is hugely useful.

---

# 36.175 Example: DX primary, VPN backup

On-prem advertises:

```text
10.10.0.0/16
```

over both:

```text
DX
VPN
```

TGW receives:

```text
10.10.0.0/16 → DXGW
10.10.0.0/16 → VPN
```

With both available, TGW prefers:

```text
DXGW
```

for that equal prefix under its attachment-type priority. AWS notes that TGW shows the preferred Direct Connect route and only exposes the VPN backup route when the preferred DX route is no longer advertised. ([AWS Documentation][2])

So:

```text
NORMAL

AWS
 │
TGW
 │
DXGW
 │
DX
 │
On-Prem
```

---

# 36.176 DX failure

Suppose Direct Connect stops advertising:

```text
10.10.0.0/16
```

TGW then loses:

```text
10.10.0.0/16 → DXGW
```

but still has the VPN-learned reachability.

Conceptually:

```text
BEFORE

10.10/16
   │
   ├── DXGW  ← preferred
   │
   └── VPN   ← backup


DX FAILURE

10.10/16
   │
   └── VPN
```

Traffic can therefore converge onto VPN.

AWS explicitly documents dynamically routed VPN as a backup option to Direct Connect. ([AWS Documentation][5])

---

# 36.177 But there's a trap: static VPN route

Remember TGW priority:

```text
Static route
```

has higher priority than propagated routes for the same destination. ([AWS Documentation][2])

Imagine you manually create:

```text
10.10.0.0/16 → VPN
STATIC
```

while DX dynamically propagates:

```text
10.10.0.0/16 → DXGW
```

Then your intended:

```text
DX primary
VPN backup
```

might not work as expected because the static TGW route has higher priority.

This is why AWS specifically recommends using a **BGP VPN connection and propagated routing** when you want the DXGW attachment preferred over VPN on TGW. ([AWS Documentation][2])

Excellent interview point.

---

# 36.178 Never-forget DX + VPN rule

For this design:

```text
DX primary
VPN backup
```

think:

```text
Dynamic routing
       +
BGP
       +
same prefixes
       +
TGW propagation
```

rather than blindly creating competing static routes.

---

# 36.179 What about On-prem → AWS?

TGW's AWS-side preference only solves:

```text
AWS → ON-PREM
```

On-prem still needs its own routing preference.

Suppose your corporate router learns AWS prefix:

```text
10.20.0.0/16
```

through:

```text
DX
VPN
```

You configure corporate routing policy so:

```text
DX route
LOCAL_PREF 200


VPN route
LOCAL_PREF 100
```

Then:

```text
ON-PREM → AWS
```

prefers DX.

When DX disappears:

```text
VPN becomes best.
```

Now both directions have intentional failover.

---

# 36.180 Complete active/passive design

```text
                    CORPORATE NETWORK

                         Router
                           │
            ┌──────────────┴──────────────┐
            │                             │
            ▼                             ▼
       DIRECT CONNECT                VPN / Internet
            │                             │
            │ PRIMARY                     │ BACKUP
            │                             │
            └──────────────┬──────────────┘
                           ▼
                          TGW
                           │
                          PROD
```

### On-prem routing

```text
AWS prefixes via DX
LOCAL_PREF 200

AWS prefixes via VPN
LOCAL_PREF 100
```

### AWS/TGW routing

```text
On-prem prefix via DXGW
preferred propagated attachment type

On-prem prefix via VPN
backup propagated route
```

This gives us intentional bidirectional preference. ([AWS Documentation][2])

---

# 36.181 Why BGP is much better than manually changing routes

Without dynamic routing:

```text
DX fails
   ↓
someone receives alert
   ↓
engineer logs in
   ↓
changes route
   ↓
tests route
   ↓
business traffic resumes
```

With BGP:

```text
DX fails
   ↓
BGP path removed
   ↓
routing converges
   ↓
backup path becomes usable
```

This is exactly why dynamic BGP is so important for resilient private connectivity. ([AWS Documentation][1])

---

# 36.182 BFD — Bidirectional Forwarding Detection

Now there's another problem.

How quickly do we detect that the path has failed?

Enter:

# BFD

BFD is a lightweight failure-detection mechanism designed to detect forwarding-path failures rapidly.

With Direct Connect, asynchronous BFD is automatically enabled on the AWS side of each virtual interface, but it only becomes effective when BFD is also configured on your router. ([AWS Documentation][6])

Mental model:

```text
BGP
=
exchange routes


BFD
=
rapidly test whether forwarding path
is alive
```

---

# 36.183 Why BFD matters

Without fast failure detection:

```text
Physical path dies

but router doesn't immediately realize
        ↓
traffic continues toward dead path
        ↓
packets disappear
        ↓
eventually routing converges
```

With appropriate BFD:

```text
Path failure
    ↓
BFD detects failure
    ↓
routing session reacts
    ↓
route withdrawn
    ↓
alternate path selected
```

Direct Connect supports BFD specifically to improve detection of path failures when configured on the customer device. ([AWS Documentation][7])

---

# 36.184 Do not confuse BFD and BGP

```text
BGP
   =
routing information


BFD
   =
path health detection
```

Analogy:

```text
BGP:
"I know this road reaches Mumbai."


BFD:
"Is this road physically usable right now?"
```

Different responsibilities.

---

# 36.185 VPN failure detection is different

Site-to-Site VPN has its own tunnel health and IPsec mechanisms.

A VPN connection has two tunnels, and dynamically routed designs can use BGP so availability changes can affect routing. AWS recommends BGP where available for redundant VPN designs. ([AWS Documentation][8])

So don't assume:

```text
DX failover mechanics
=
VPN failover mechanics
```

They are related through routing but are not identical technologies.

---

# 36.186 ECMP with Site-to-Site VPN

Suppose:

```text
TGW
 │
 ├── VPN tunnel/path A
 │
 ├── VPN tunnel/path B
 │
 ├── VPN tunnel/path C
 │
 └── VPN tunnel/path D
```

Transit Gateway can use ECMP with dynamically routed Site-to-Site VPN connections. AWS explicitly notes that TGW VPN ECMP requires dynamic routing/BGP rather than static VPN routing. ([AWS Documentation][9])

This can provide:

```text
more usable aggregate bandwidth
+
path redundancy
```

for suitable VPN architectures.

---

# 36.187 2026 update — Large Bandwidth Tunnels

As of August 2026, AWS also offers:

# Site-to-Site VPN Large Bandwidth Tunnels

with up to:

```text
5 Gbps per tunnel
```

versus the standard:

```text
1.25 Gbps per tunnel
```

for supported TGW/Cloud WAN VPNs. AWS explicitly lists Direct Connect backup as one use case for these higher-capacity tunnels. ([AWS Documentation][10])

And if more than 5 Gbps per tunnel is required, multiple VPN connections can still use ECMP. ([AWS Documentation][10])

So our modern mental model is no longer:

```text
VPN = tiny slow backup only
```

VPN capabilities have evolved significantly.

---

# 36.188 Active/active DX + VPN backup

Now let's build a stronger enterprise architecture:

```text
                           CORPORATE DC

                     Router A       Router B
                        │              │
                 ┌──────┘              └──────┐
                 ▼                            ▼
              DX-A                           DX-B
             ACTIVE                         ACTIVE
                 │                            │
                 └───────────┬────────────────┘
                             │
                             │ Primary transport
                             ▼
                            TGW
                             ▲
                             │
                        VPN BACKUP
                             │
                             ▼
                    Corporate Firewalls
```

Normal state:

```text
DX-A + DX-B
both carry traffic
```

Failure of one DX:

```text
remaining DX handles traffic
```

Failure of both DX paths:

```text
VPN becomes available backup path
```

This is substantially more resilient than:

```text
one DX + one VPN
```

assuming the two DX circuits genuinely use diverse failure domains.

---

# 36.189 Maximum resiliency thinking

Remember from Part 3:

```text
Two connections
```

does not automatically mean:

```text
high availability.
```

Suppose:

```text
DX-A ──┐
       ├── same router
DX-B ──┘
```

Router failure kills both.

Or:

```text
DX-A
DX-B

same DX location
```

A facility-level event could affect both.

A stronger design separates failure domains:

```text
                        CORPORATE DC

                  Router A        Router B
                     │               │
                     ▼               ▼
               Carrier A         Carrier B
                     │               │
                     ▼               ▼
            DX Location A     DX Location B
                     │               │
                     └───────┬───────┘
                             ▼
                            AWS
```

AWS's resiliency guidance emphasizes redundant Direct Connect connections and failure-domain diversity rather than simply adding another cable. ([AWS Documentation][1])

---

# 36.190 Failure scenario #1 — DX-A fails

Starting:

```text
DX-A ACTIVE
DX-B ACTIVE
VPN BACKUP
```

Failure:

```text
DX-A
  X
```

Result:

```text
DX-B
 │
 ▼
AWS
```

No VPN required yet.

---

# 36.191 Failure scenario #2 — entire DX location A fails

Architecture:

```text
Location A
   X

Location B
   │
   ▼
AWS
```

Still running.

This is why:

```text
two links at one facility
```

and:

```text
links at two independent facilities
```

are not the same resilience architecture.

---

# 36.192 Failure scenario #3 — both Direct Connect paths disappear

Now:

```text
DX-A X
DX-B X
```

BGP paths through DX disappear.

Backup remains:

```text
Site-to-Site VPN
```

Routing converges:

```text
ON-PREM
   │
Internet/IP transport
   │
IPsec
   │
TGW
   │
AWS
```

VPN can serve as backup to Direct Connect, although AWS notes that Internet-based backup provides different reliability/performance characteristics than redundant private DX connectivity. ([AWS Documentation][5])

---

# 36.193 Failure scenario #4 — VPN tunnel 1 fails

Remember:

```text
VPN Connection
      │
 ┌────┴────┐
 │         │
Tunnel 1 Tunnel 2
```

A production customer gateway should generally configure both tunnels.

If:

```text
Tunnel 1 X
```

the other available tunnel can continue connectivity, and BGP-based routing can react to path availability. ([AWS Documentation][11])

---

# 36.194 Failure scenario #5 — customer router dies

This exposes another failure domain.

Bad:

```text
DX-A ───┐
        │
      Router A
        │
VPN ────┘
```

Router A dies:

```text
DX lost
VPN lost
```

Even though AWS had redundant connectivity technologies.

Better:

```text
           Router A             Router B
              │                    │
              ▼                    ▼
             DX                   VPN
```

Better still:

```text
Router A → DX-A + VPN-A

Router B → DX-B + VPN-B
```

subject to your exact enterprise topology.

---

# 36.195 Failure scenario #6 — route leak

This is subtler.

Suppose your branch accidentally advertises:

```text
0.0.0.0/0
```

or an overly broad:

```text
10.0.0.0/8
```

instead of:

```text
10.10.0.0/16
```

This can cause unexpected traffic attraction.

Hence production BGP requires:

```text
prefix filters
maximum-prefix limits
route policies
allowed-prefix controls
monitoring
```

Do not blindly accept everything a neighbor advertises.

---

# 36.196 Route advertisements should be intentional

Example corporate policy:

```text
AWS may receive ONLY:

10.10.0.0/16
10.11.0.0/16
10.50.0.0/16
```

Not:

```text
0.0.0.0/0
```

unless you deliberately intend it.

Similarly, Direct Connect Gateway allowed prefixes participate in controlling what AWS-side prefixes can be advertised toward the customer network from a TGW association. ([AWS Documentation][2])

---

# 36.197 Asymmetric routing

Now one of the most important production issues.

Imagine:

### Forward

```text
On-Prem
   │
 DX-A
   │
 TGW
   │
Firewall A
   │
Prod
```

### Return

```text
Prod
 │
Firewall B
 │
TGW
 │
DX-B
 │
On-Prem
```

Is that automatically bad?

Not always.

IP routing itself can tolerate asymmetric paths.

But stateful devices may not.

---

# 36.198 Why firewalls care

Firewall A sees:

```text
10.10.1.50:50000
       →
10.20.2.60:443
```

and creates state.

But response arrives through Firewall B:

```text
10.20.2.60:443
       →
10.10.1.50:50000
```

Firewall B may say:

```text
I have no state for this TCP connection.
```

and drop it.

Result:

```text
SYN leaves

SYN-ACK returns

but gets dropped
```

Application shows:

```text
TIMEOUT
```

Yet:

```text
Routes look valid.
```

This is why stateful inspection and symmetry matter.

---

# 36.199 TGW Appliance Mode connects back to this

Remember Part 2?

```text
TGW
+
stateful firewall
+
multi-AZ
```

Think:

# Appliance Mode

Appliance mode helps maintain the appropriate AZ affinity for flows traversing stateful appliances.

So today's routing policy must align with yesterday's inspection architecture.

Enterprise networking isn't:

```text
BGP configuration
```

in isolation.

It's:

```text
BGP
+
TGW routing
+
Firewall state
+
AZ topology
+
return routing
```

---

# 36.200 Active/active isn't automatically superior

Engineers sometimes think:

```text
2 active links
>
1 active + 1 standby
```

Not always.

Active/active can introduce:

```text
More routing complexity
More symmetry considerations
More troubleshooting paths
More firewall-state considerations
```

Active/passive can provide:

```text
Simpler deterministic traffic path
```

at the cost of potentially unused standby bandwidth.

Correct architecture depends on requirements.

---

# 36.201 A useful design decision

### Choose Active/Passive when:

```text
You strongly value deterministic routing

Stateful middleboxes make symmetry important

Backup bandwidth doesn't need to be used normally

Operational simplicity matters
```

### Consider Active/Active when:

```text
Both circuits should carry traffic

Capacity utilization matters

Network devices support multipath correctly

Inspection architecture supports it

Operations team understands ECMP
```

---

# 36.202 Don't use one route policy for all traffic blindly

Imagine:

```text
Corporate Users
Databases
Backups
Replication
Voice
Administrative traffic
```

You may eventually want different routing policies.

For example:

```text
Production application traffic
       →
DX-A preferred


Bulk backup traffic
       →
DX-B preferred
```

This can be achieved through carefully designed prefix advertisement and BGP policy.

But do not over-engineer prematurely.

For most environments:

```text
clear primary/backup
```

or:

```text
clean active/active
```

is easier to operate.

---

# 36.203 Convergence

You will hear:

# Routing Convergence

It means the network reaching a new consistent routing state after a change.

Example:

```text
T0

DX-A = preferred


T1

DX-A fails


T2

Failure detected


T3

BGP withdraws route


T4

Routers calculate new best path


T5

DX-B selected


T6

Traffic resumes through DX-B
```

The time between failure and stable alternate routing is part of your:

```text
convergence behaviour
```

BFD can improve failure detection on Direct Connect, while BGP performs route recalculation. ([AWS Documentation][6])

---

# 36.204 Failback

Now DX-A returns.

Question:

> Should traffic automatically move back?

Potentially yes, depending on your routing policy.

```text
DX-A returns
   ↓
BGP session establishes
   ↓
preferred route advertised again
   ↓
routing policy selects DX-A
   ↓
traffic moves back
```

This is:

# Failback

But uncontrolled failback can be dangerous when a circuit is:

```text
UP
DOWN
UP
DOWN
UP
DOWN
```

This is called:

# Flapping

Repeated convergence can disrupt traffic.

---

# 36.205 Route flapping

Example:

```text
12:00 DX UP
12:01 DX DOWN
12:02 DX UP
12:03 DX DOWN
```

Your network keeps switching:

```text
DX → VPN → DX → VPN → DX
```

Potential result:

```text
TCP resets
unstable application traffic
firewall state problems
user-visible interruptions
```

So resiliency testing and operational policies matter as much as simply having backup links.

---

# 36.206 Direct Connect Resiliency Toolkit

AWS provides the **Direct Connect Resiliency Toolkit**, including failover testing capabilities, specifically so you can verify that connectivity and routing behave as intended during failures. ([AWS Documentation][12])

This matters because:

```text
Architecture diagram says:

DX-B is backup
```

doesn't prove:

```text
DX-B actually carries traffic
when DX-A fails.
```

Production principle:

> **Redundancy you haven't tested is an assumption.**

---

# 36.207 What should we test?

For our architecture:

```text
DX-A
DX-B
VPN
```

we should test at least:

```text
DX-A failure

DX-B failure

Both DX paths unavailable

VPN tunnel 1 failure

VPN tunnel 2 failure

Customer Router A failure

Customer Router B failure

BGP neighbor failure

Incorrect route advertisement

Recovery/failback
```

And during each:

```text
Can Prod reach on-prem?

Can on-prem reach Prod?

Does DNS still work?

Does firewall inspection remain symmetric?

What is packet loss?

How quickly does traffic recover?
```

---

# 36.208 Monitoring matters during failover

Observe:

```text
Direct Connect connection state
VIF state
BGP state

VPN tunnel state
BGP state

TGW routes

Traffic metrics
packet loss
latency

Application health
```

Don't only monitor:

```text
Interface = UP
```

because you could have:

```text
Interface UP
BGP UP
Route wrong
Application DOWN
```

Infrastructure health and service health are different.

---

# 36.209 Full enterprise resilient architecture

Now let's combine everything:

```text
                         CORPORATE DATA CENTER

                 ┌────────────────────────────┐
                 │                            │
             Router A                    Router B
              ASN 65000                  ASN 65000
                 │                            │
          ┌──────┴───────┐            ┌──────┴───────┐
          │              │            │              │
          ▼              ▼            ▼              ▼
        DX-A          VPN-A          DX-B          VPN-B
          │              │            │              │
          │              │            │              │
          ▼              │            ▼              │
    DX Location A        │      DX Location B        │
          │              │            │              │
          └──────┐       │      ┌─────┘              │
                 ▼       │      ▼                    │
                   Transit VIFs                      │
                        │                            │
                        ▼                            │
                       DXGW                          │
                        │                            │
                        └─────────────┬──────────────┘
                                      ▼
                             TRANSIT GATEWAY
                                      │
                 ┌────────────────────┼────────────────────┐
                 │                    │                    │
                 ▼                    ▼                    ▼
           INSPECTION VPC          PROD VPC             SHARED
                 │                 10.20/16              10.40/16
          Network Firewall             │                    │
          Appliance Mode              ECS               AD/DNS
                 │                     │
                 │                    RDS
                 │
                 └──────────── DEV VPC
                               10.30/16
```

Normal routing:

```text
DX-A + DX-B
→ Active/Active
```

Backup:

```text
VPN-A + VPN-B
```

And TGW controls:

```text
segmentation
route propagation
inspection path
DX vs VPN reachability
```

---

# 36.210 Packet walk — normal operation

Source:

```text
Prod EC2

10.20.5.50
```

Destination:

```text
Corporate Oracle

10.10.50.20
```

Flow:

```text
10.20.5.50
     │
     ▼
Prod VPC Route Table

10.10.0.0/16 → TGW
     │
     ▼
TGW
     │
     ▼
Inspection route
     │
     ▼
Network Firewall
     │
     ▼
TGW
     │
     ▼
10.10.0.0/16 → DXGW
     │
     ▼
DXGW
     │
     ▼
Transit VIF
     │
     ▼
DX-A or DX-B
     │
     ▼
Corporate Router
     │
     ▼
10.10.50.20
```

TGW can prefer the Direct Connect gateway propagated path over a normal Site-to-Site VPN propagated path for the same CIDR. ([AWS Documentation][2])

---

# 36.211 Packet walk — Direct Connect failure

Both DX routes disappear.

TGW now has:

```text
10.10.0.0/16
      ↓
VPN attachment
```

Flow becomes:

```text
Prod
 │
TGW
 │
Inspection
 │
TGW
 │
VPN
 │
IPsec
 │
Corporate Router
 │
Oracle
```

No application configuration changed.

Only the network path changed.

That's the power of dynamic routing.

---

# 36.212 Never-forget route-selection separation

Memorize this:

```text
ON-PREM → AWS
────────────────

Your router decides.

Use:
BGP policy
Local preference
AS_PATH
multipath/etc.


AWS → ON-PREM
────────────────

AWS networking decides.

DX:
BGP communities / AWS policy

TGW:
TGW route priority + BGP attributes

VPN:
BGP propagated routing
```

Never say:

> "BGP chooses DX."

That's too vague.

Ask:

> **Which BGP speaker/router, in which direction, with which routes and attributes?**

That's how a network engineer thinks.

---

# 36.213 Troubleshooting scenario

Ticket:

> "Direct Connect is healthy, but some traffic is still using VPN."

Don't immediately assume AWS bug.

Check:

```text
1. Are DX and VPN advertising the same prefix?

2. Is VPN advertising a more-specific prefix?

3. Is there a static TGW route toward VPN?

4. Is DX route propagated into the correct TGW RT?

5. Is VPN propagated into another route table?

6. What route does TGW actually show?

7. What routes does on-prem BGP receive?

8. What LOCAL_PREF is configured?

9. What communities are present?

10. What AS_PATH is present?

11. Is policy different in the reverse direction?
```

That's a production troubleshooting workflow.

---

# 36.214 Another scenario

> "Traffic goes AWS → on-prem through DX-A but returns through DX-B."

Possible explanation:

```text
AWS routing preference
≠
on-prem routing preference
```

Forward:

```text
AWS community policy
→ DX-A
```

Return:

```text
Corporate local-pref
→ DX-B
```

If there's no stateful middlebox, that might still work.

If there is a stateful firewall:

```text
connection may break.
```

Fix the routing policy rather than randomly changing security groups.

---

# 36.215 Another scenario

> "After Direct Connect failure, VPN never takes over."

Check:

```text
Is VPN tunnel UP?

Is VPN BGP UP?

Is on-prem prefix advertised through VPN?

Is VPN propagation enabled into TGW RT?

Did someone create a conflicting static route?

Does on-prem prefer VPN after DX withdrawal?

Does the VPC still have TGW reachability?

Does inspection route correctly toward VPN?
```

Again:

```text
Tunnel UP
```

does not guarantee:

```text
usable failover.
```

---

# 36.216 Another scenario

> "VPN backup works, but performance drops substantially during DX failure."

That may be completely expected.

Suppose normal DX capacity is:

```text
10 Gbps
```

while backup VPN capacity is significantly smaller.

During failover:

```text
10 Gbps demand
     ↓
much smaller backup path
```

The backup link may become saturated.

So resiliency planning requires:

```text
Connectivity redundancy
        +
capacity planning
```

not just:

```text
Can packets technically pass?
```

AWS's current Large Bandwidth Tunnel option can provide up to 5 Gbps per VPN tunnel in supported TGW/Cloud WAN designs, and ECMP can scale across multiple VPN connections for larger requirements. ([AWS Documentation][10])

---

# 36.217 Capacity during failure is called out explicitly

Suppose:

```text
DX-A = 10 Gbps
DX-B = 10 Gbps

Normal Active/Active load:
~16 Gbps
```

If DX-A fails:

```text
remaining capacity
=
10 Gbps
```

But demand remains:

```text
16 Gbps
```

You've achieved:

```text
availability
```

but not:

```text
full-capacity availability.
```

Important enterprise distinction.

---

# 36.218 N+1 thinking

Suppose peak traffic:

```text
8 Gbps
```

You could provision:

```text
DX-A = 10 Gbps
DX-B = 10 Gbps
```

Then if either dies:

```text
one 10-Gbps path
```

can still theoretically carry peak demand.

That's a much better resiliency model than:

```text
2 × 5 Gbps
```

carrying:

```text
8 Gbps
```

normally.

Because loss of one leaves only:

```text
5 Gbps
```

for an 8-Gbps workload.

This is capacity engineering.

---

# 36.219 Four dimensions of hybrid resiliency

Never judge architecture only by number of links.

You need:

```text
1. PATH REDUNDANCY

DX-A
DX-B
VPN


2. FAILURE-DOMAIN REDUNDANCY

routers
carriers
DX locations


3. ROUTING REDUNDANCY

BGP
route withdrawal
alternate routes


4. CAPACITY REDUNDANCY

remaining links can carry
required failure-state traffic
```

That's how a senior architect evaluates hybrid connectivity.

---

# 36.220 Never-forget BGP table

| Concept                    | Meaning                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| **BGP**                    | Dynamic route exchange                                           |
| **LOCAL_PREF**             | Internal preference for outbound path; higher preferred          |
| **AS_PATH**                | ASNs traversed by route                                          |
| **AS_PATH prepend**        | Make path appear longer/less attractive                          |
| **MED**                    | BGP hint between multiple entry points; lower commonly preferred |
| **BGP community**          | Metadata used by routing policy                                  |
| **DX community 7224:7100** | Low AWS preference                                               |
| **DX community 7224:7200** | Medium AWS preference                                            |
| **DX community 7224:7300** | High AWS preference                                              |
| **ECMP**                   | Use multiple equal-cost paths                                    |
| **BFD**                    | Rapid forwarding-path failure detection                          |
| **Convergence**            | Network reaching new stable routing state                        |
| **Failover**               | Shift traffic to alternate path                                  |
| **Failback**               | Return traffic to preferred recovered path                       |
| **Route flap**             | Repeated route/path up/down                                      |
| **Asymmetric routing**     | Forward and return paths differ                                  |

The three AWS Direct Connect community values above are the current documented local-preference communities. ([AWS Documentation][3])

---

# 36.221 The five questions to ask whenever multiple paths exist

Whenever you see:

```text
DX
+
VPN
+
multiple routers
```

ask:

```text
1. WHAT PREFIXES are being advertised?

2. WHICH PATH is preferred AWS → on-prem?

3. WHICH PATH is preferred on-prem → AWS?

4. WHAT EVENT causes failover?

5. CAN the surviving path handle production traffic?
```

If you can answer those five questions, the architecture is becoming understandable.

---

# 36.222 Never-forget diagram

```text
                         HYBRID ROUTING

                           ON-PREM
                              │
                    ┌─────────┼─────────┐
                    │         │         │
                    ▼         ▼         ▼
                  DX-A      DX-B       VPN
                    │         │         │
                    │         │         │
               BGP / ECMP    │      BGP/IPsec
                    │         │         │
                    └─────────┼─────────┘
                              ▼
                             TGW
                              │
                    TGW ROUTE TABLE
                              │
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
              PROD           DEV          SHARED


Normal:
DX-A + DX-B

DX-A fails:
DX-B

Both DX fail:
VPN
```

---

# 36.223 One sentence to remember forever

> **High availability does not come from having multiple links; it comes from having independent links, correct routing policy, automatic failure detection, sufficient backup capacity, and tested failover.**

That principle applies far beyond AWS.

It applies to:

```text
BGP
MPLS
SD-WAN
Multi-cloud
Internet edge
Data-center networking
Cloud WAN
```

---

# Next — Lesson 36, Part 5

## Private-IP VPN over Direct Connect + Encryption Architecture

Now we solve an interesting enterprise requirement:

> **“We want Direct Connect's private connectivity, but company policy requires IPsec encryption as well.”**

We'll move from:

```text
On-Prem
   │
   │ Direct Connect
   ▼
DXGW
   │
TGW
```

to:

```text
                 CORPORATE DC
                      │
                 Direct Connect
                      │
                 Transit VIF
                      │
                     DXGW
                      │
                      ▼
                Private-IP VPN
                IPsec overlay
                      │
                      ▼
                     TGW
                      │
            ┌─────────┼─────────┐
            ▼         ▼         ▼
          PROD       DEV      SHARED
```

We'll cover **public-IP VPN-over-DX vs private-IP VPN-over-DX, why you would combine IPsec and DX, outer vs inner IPs, BGP sessions, TGW Connect-style mental separation, encryption boundaries, MACsec vs IPsec, MTU/MSS overhead, failure behavior, route priority, dual-DX + encrypted VPN architecture, and packet-by-packet troubleshooting**.

After that comes one of the final major pieces of Lesson 36:

**Route 53 Resolver hybrid DNS → inbound/outbound endpoints → conditional forwarding → Active Directory DNS → multi-account DNS → Terraform → monitoring → complete enterprise on-prem ↔ AWS hands-on architecture.**

[1]: https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_network_topology_ha_conn_private_networks.html "REL02-BP02 Provision redundant connectivity between private networks in the cloud and on-premises environments - AWS Well-Architected Framework"
[2]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html "How AWS Transit Gateway works - Amazon VPC"
[3]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/routing-and-bgp.html "Direct Connect routing policies and BGP communities - AWS Direct Connect"
[4]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/toolkit-classic.html "Configure a Direct Connect Classic connection - AWS Direct Connect"
[5]: https://docs.aws.amazon.com/whitepapers/latest/hybrid-connectivity/reliability.html?utm_source=chatgpt.com "Reliability - Hybrid Connectivity"
[6]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html?utm_source=chatgpt.com "What is Direct Connect?"
[7]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/connection_options.html?utm_source=chatgpt.com "Direct Connect connection options"
[8]: https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-redundant-connection.html?utm_source=chatgpt.com "Redundant AWS Site-to-Site VPN connections for failover"
[9]: https://docs.aws.amazon.com/whitepapers/latest/aws-vpc-connectivity-options/aws-transit-gateway-vpn.html?utm_source=chatgpt.com "AWS Transit Gateway + AWS Site-to-Site VPN"
[10]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html?utm_source=chatgpt.com "Tunnel options for your AWS Site-to-Site VPN connection"
[11]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html?utm_source=chatgpt.com "AWS Site-to-Site VPN"
[12]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/resiliency_toolkit.html?utm_source=chatgpt.com "AWS Direct Connect Resiliency Toolkit"
