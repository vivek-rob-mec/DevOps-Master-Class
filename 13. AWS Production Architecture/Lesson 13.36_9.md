# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 9: Hybrid Network Troubleshooting & Observability

We have now designed and expressed the architecture in Terraform.

But production networking has an important rule:

> **`terraform apply` proves that AWS accepted your configuration. It does not prove that packets can successfully travel through it.**

This part is about proving what the network actually does.

---

# 36.460 The troubleshooting mindset

Suppose this fails:

```text
AWS Application
10.64.5.20

        X

Oracle Database
10.10.50.20
```

Do **not** start randomly changing:

```text
Security Groups
TGW routes
VPN tunnels
firewall rules
DNS
```

Instead follow the packet in order:

```text
SOURCE APPLICATION
       │
       ▼
DNS
       │
       ▼
SOURCE OS
       │
       ▼
SECURITY GROUP
       │
       ▼
NACL
       │
       ▼
VPC ROUTE TABLE
       │
       ▼
TGW ATTACHMENT
       │
       ▼
TGW ROUTE TABLE
       │
       ▼
INSPECTION VPC
       │
       ▼
FIREWALL
       │
       ▼
TGW
       │
       ▼
DX / VPN
       │
       ▼
CORPORATE ROUTER
       │
       ▼
CORPORATE FIREWALL
       │
       ▼
DESTINATION
       │
       ▼
RETURN PATH
```

That ordered method is far more valuable than memorizing individual console screens.

---

# 36.461 First question: DNS problem or network problem?

Application reports:

```text
Cannot connect to:

oracle-prod.corp.internal
```

Before debugging TGW, run:

```bash
dig oracle-prod.corp.internal
```

Suppose result:

```text
oracle-prod.corp.internal.
    60 IN A 10.10.50.20
```

DNS:

```text
✓ WORKING
```

Now test network/application port:

```bash
nc -vz 10.10.50.20 1521
```

If that fails:

```text
DNS ≠ problem
```

Move to packet routing.

This simple separation prevents huge amounts of wasted troubleshooting.

---

# 36.462 Our production troubleshooting hierarchy

I want you to remember this order:

```text
1. NAME
   DNS correct?

2. SOURCE
   Application actually sending?

3. LOCAL SECURITY
   SG/NACL/OS firewall?

4. VPC ROUTING
   Correct next hop?

5. TRANSIT ROUTING
   TGW attachment / RT?

6. INSPECTION
   Firewall path?

7. HYBRID TRANSPORT
   DX / VPN?

8. ON-PREM ROUTING
   Correct forward route?

9. DESTINATION
   Service listening?

10. RETURN PATH
    Can response get back?
```

When troubleshooting production networking, the final one is commonly overlooked:

# RETURN PATH.

---

# 36.463 Build a troubleshooting toolbox

For our architecture we'll use several layers of tooling.

### Linux

```text
dig
nslookup
getent

ip
ip route
ip neigh

ping
tracepath
traceroute
mtr

ss
nc
curl

tcpdump
```

### AWS

```text
VPC route tables

TGW route tables

VPC Flow Logs

TGW Flow Logs

Reachability Analyzer

Site-to-Site VPN CloudWatch metrics

Site-to-Site VPN tunnel/BGP logs

Route 53 Resolver Query Logs

CloudWatch

AWS Network Manager
```

AWS supports VPC Flow Logs for traffic at VPC network interfaces and separate Transit Gateway Flow Logs for transit-gateway traffic. Reachability Analyzer provides static configuration analysis between supported AWS networking resources. ([AWS Documentation][1])

---

# 36.464 Start locally — is the application listening?

Suppose an EC2 instance should provide HTTPS.

Run:

```bash
ss -lntp
```

Example:

```text
LISTEN 0 511 0.0.0.0:443
```

Good.

But imagine:

```text
LISTEN 0 511 127.0.0.1:443
```

Now the application listens only on localhost.

Network may be perfect:

```text
TGW ✓
VPN ✓
BGP ✓
Routes ✓
SG ✓
```

but remote clients cannot reach the application.

This is why:

```text
network troubleshooting
```

doesn't stop at AWS networking.

---

# 36.465 Test a TCP port

Use:

```bash
nc -vz 10.10.50.20 1521
```

Possible success:

```text
Connection to 10.10.50.20 1521 port [tcp/*] succeeded!
```

Now you know:

```text
TCP connection works.
```

That's much more meaningful than:

```bash
ping 10.10.50.20
```

because the actual application uses:

```text
TCP 1521
```

not ICMP.

---

# 36.466 Why `ping` can mislead you

Case A:

```text
ping fails
```

but:

```text
HTTPS works
```

because ICMP is blocked.

Case B:

```text
ping works
```

but:

```text
Oracle TCP 1521 fails
```

because TCP is blocked.

So:

```text
PING SUCCESS
≠
APPLICATION SUCCESS
```

and:

```text
PING FAILURE
≠
NETWORK COMPLETELY BROKEN
```

Always test the actual protocol.

---

# 36.467 `curl` for application-layer validation

For HTTP:

```bash
curl -v http://10.10.50.20:8080
```

HTTPS:

```bash
curl -vk https://internal-api.corp.internal
```

Why `-v`?

It can expose stages such as:

```text
DNS resolution
connection attempt
TCP connection
TLS negotiation
HTTP response
```

Example:

```text
* Trying 10.10.50.20:443...
* Connected to internal-api...
* TLS handshake...
< HTTP/1.1 200 OK
```

That's extremely useful.

---

# 36.468 `ip route`

On a Linux instance:

```bash
ip route
```

might show:

```text
default via 10.64.1.1 dev eth0
10.64.1.0/24 dev eth0
```

Remember:

An EC2 operating system generally sees its subnet's router as the local gateway.

It doesn't directly contain:

```text
10.10.0.0/16 → TGW
```

inside the Linux routing table.

The AWS VPC route table handles that routing after the packet leaves the instance.

So we have:

```text
Linux route table
        │
        ▼
VPC virtual router
        │
        ▼
AWS VPC route table
        │
        ▼
TGW
```

Keep the OS routing plane and AWS VPC routing plane distinct.

---

# 36.469 Troubleshooting TGW

Suppose:

```text
Prod
10.64.5.20

cannot reach

Shared
10.72.5.20
```

Check:

```text
1. Prod subnet route

10.72.0.0/16 → TGW
```

Then:

```text
2. Prod TGW attachment status

AVAILABLE?
```

Then:

```text
3. Which TGW RT is associated
with Prod attachment?
```

Then:

```text
4. Does that TGW RT contain:

10.72.0.0/16 → Shared attachment?
```

Then reverse the whole exercise.

```text
Shared subnet route:

10.64.0.0/16 → TGW
```

And:

```text
SHARED-RT:

10.64.0.0/16 → Prod attachment
```

No return path means no successful connection.

---

# 36.470 A common TGW failure

Terraform created:

```text
Prod attachment ✓
Shared attachment ✓
```

But connectivity fails.

Why?

You forgot:

```text
association
```

or:

```text
route propagation
```

Remember:

```text
ATTACHMENT
=
physical/logical TGW connection


ASSOCIATION
=
which TGW route table incoming traffic reads


PROPAGATION
=
which TGW tables learn this attachment's prefixes
```

Creating attachments alone does not prove the appropriate transit routes exist.

---

# 36.471 Another common TGW failure — wrong association

Suppose:

```text
Prod Attachment
```

should be associated with:

```text
PROD-RT
```

but someone associates it with:

```text
NONPROD-RT
```

Then:

```text
Prod traffic enters TGW
       │
       ▼
reads NONPROD-RT
```

Potential result:

```text
Shared reachable?
Maybe.

On-Prem?
Maybe not.

Prod segmentation?
Broken.
```

Always ask:

> **Which TGW route table does traffic arriving from this attachment actually consult?**

---

# 36.472 Another TGW failure — blackhole wins

Suppose PROD-RT contains:

```text
10.10.0.0/16 → Inspection
```

but someone adds a more-specific route:

```text
10.10.50.0/24 → BLACKHOLE
```

Destination:

```text
10.10.50.20
```

uses:

```text
10.10.50.0/24
```

because it's more specific.

Result:

```text
other on-prem networks work

BUT

10.10.50.x fails.
```

This symptom should immediately make you think:

```text
specific-route problem
```

rather than total VPN failure.

---

# 36.473 Use AWS Reachability Analyzer

Reachability Analyzer is not a packet generator.

It analyzes AWS network configuration and determines whether a configured path should be reachable between supported resources. When unreachable, it can identify a blocking component such as a route/security configuration issue. ([AWS Documentation][2])

Think:

```text
Reachability Analyzer

does NOT ask:

"Did a real packet arrive?"


It asks:

"Given this AWS configuration,
is a path possible?"
```

That's an important distinction.

---

# 36.474 Example Reachability Analyzer use

Suppose:

```text
EC2-A
       ↓
TGW
       ↓
EC2-B
```

should work.

Reachability Analyzer can evaluate supported AWS components along the virtual path, including Transit Gateway. AWS describes its output as either a hop-by-hop reachable path or an explanation of the blocking configuration. ([AWS Documentation][3])

So if it reports:

```text
route table missing destination
```

you've found a configuration problem before even reaching for `tcpdump`.

---

# 36.475 Reachability Analyzer limitation mental model

It analyzes:

```text
AWS configuration
```

It does **not** prove:

```text
application listens on TCP 443

Oracle process is healthy

on-prem firewall behaves correctly

remote router is configured correctly
```

Therefore:

```text
Reachability Analyzer = configuration proof

real traffic testing = runtime proof
```

You need both.

---

# 36.476 VPC Flow Logs

VPC Flow Logs capture metadata about IP traffic going to and from network interfaces in a VPC. AWS supports publishing the records to destinations including CloudWatch Logs, Amazon S3, and Data Firehose. ([AWS Documentation][1])

Conceptually:

```text
EC2 ENI
   │
   ▼
VPC FLOW LOG

SRC
DST
SRC PORT
DST PORT
PROTOCOL
ACCEPT / REJECT
BYTES
PACKETS
...
```

This gives us evidence that traffic reached an ENI-level observation point.

---

# 36.477 Example VPC Flow Log thought process

Suppose:

```text
10.10.50.20
      ↓
10.64.5.20:443
```

You see:

```text
srcaddr=10.10.50.20
dstaddr=10.64.5.20
dstport=443
action=ACCEPT
```

That tells you traffic reached the AWS network interface and the captured network policy disposition was accepted.

But application still fails.

Now suspect:

```text
OS firewall
application listener
application failure
return path
```

rather than blindly changing TGW routes.

---

# 36.478 `REJECT` flow logs

Suppose:

```text
srcaddr 10.10.50.20
dstaddr 10.64.5.20
dstport 443
action REJECT
```

Now investigate:

```text
Security Group
NACL
```

based on where the rejection occurs.

Flow Logs dramatically narrow the search space.

---

# 36.479 TGW Flow Logs

Transit Gateway Flow Logs provide visibility into traffic traversing Transit Gateway and can publish log data to supported destinations including CloudWatch Logs or S3. AWS notes that TGW Flow Logs are not a real-time stream and may take several minutes after configuration before records begin appearing. ([AWS Documentation][4])

Conceptually:

```text
Prod Attachment
      │
      ▼
      TGW
      │
      ▼
VPN Attachment

         │
         ▼

TGW FLOW LOG

source attachment
destination attachment
source address
destination address
protocol
traffic metadata
```

This is extremely useful when troubleshooting:

```text
Did packet actually cross TGW?
```

---

# 36.480 VPC Flow Logs vs TGW Flow Logs

Never mix them.

```text
VPC FLOW LOG
=
visibility around VPC ENI traffic


TGW FLOW LOG
=
visibility around Transit Gateway traffic
```

Example:

```text
EC2
 │
 │ VPC Flow Log
 ▼
TGW Attachment
 │
 │ TGW Flow Log
 ▼
TGW
 │
 ▼
VPN
```

They observe different parts of the path.

---

# 36.481 Why both are useful

Imagine:

```text
Source VPC flow log
shows ACCEPT
```

but:

```text
TGW Flow Log
shows no expected flow
```

Now inspect:

```text
VPC route to TGW
TGW attachment/subnet path
routing configuration
```

Alternatively:

```text
TGW flow exists
```

but:

```text
destination EC2 VPC flow log
doesn't show arrival
```

Now inspect:

```text
TGW destination selection
destination VPC routing
attachment/subnet routing
```

Observability lets us binary-search the packet path.

---

# 36.482 Think of troubleshooting as binary search

Suppose full path:

```text
A → B → C → D → E → F → G
```

Don't test every component randomly.

Find:

```text
Packet visible at D?
```

If yes:

```text
A–D probably okay
problem likely D–G
```

Then test:

```text
Packet visible at F?
```

and keep narrowing.

Flow logs and packet captures are essentially tools for asking:

> **How far did my packet get?**

This is one of the most important troubleshooting ideas in networking.

---

# 36.483 Transit Gateway Flow Log alerting

AWS documents using CloudWatch metric filters against TGW Flow Log records to create alarms for selected traffic patterns, such as repeated rejected connection attempts. ([AWS Documentation][5])

So flow logs are not only for incident response.

They can also contribute to:

```text
security detection
operational alerting
traffic analytics
capacity investigation
```

---

# 36.484 Site-to-Site VPN observability

For VPN, monitor at least:

```text
Tunnel 1 state
Tunnel 2 state

bytes in/out

BGP behavior

tunnel activity
```

AWS automatically publishes Site-to-Site VPN metrics to CloudWatch and currently supports detailed Site-to-Site VPN tunnel and BGP activity logs in CloudWatch Logs. ([AWS Documentation][6])

This is much better than relying only on:

```text
Console says tunnel UP.
```

---

# 36.485 VPN incident #1 — tunnel DOWN

Architecture:

```text
AWS
 │
Tunnel 1
 │
Customer Router
```

Tunnel state:

```text
DOWN
```

Think bottom-up.

```text
1. Is customer gateway's external/private
endpoint reachable?

2. Is IKE negotiation succeeding?

3. PSK correct?

4. IKE version/proposal compatible?

5. IPsec proposal compatible?

6. Firewall allows required VPN traffic?

7. Is customer gateway configured
with correct AWS tunnel parameters?
```

AWS's Site-to-Site VPN logging can capture tunnel activity and BGP routing information, making it a useful first diagnostic source alongside CloudWatch tunnel metrics. ([AWS Documentation][7])

---

# 36.486 Tunnel DOWN vs BGP DOWN

Don't confuse:

```text
IPsec Tunnel
```

with:

```text
BGP Session
```

You might have:

```text
Tunnel = UP
BGP = DOWN
```

Meaning:

```text
encrypted transport exists
```

but:

```text
dynamic routing adjacency does not.
```

Check:

```text
BGP ASN
inside-tunnel IPs
BGP authentication/configuration
route policies
customer router BGP process
```

Site-to-Site VPN logs can now include BGP tunnel logs in CloudWatch Logs, which helps distinguish tunnel negotiation from routing-adjacency issues. ([AWS Documentation][7])

---

# 36.487 Tunnel UP + BGP UP + application DOWN

This is the dangerous scenario because people say:

> "VPN looks healthy, so it can't be networking."

Wrong.

You can have:

```text
IPsec ✓
BGP ✓
```

but:

```text
required prefix not advertised
wrong TGW propagation
wrong return route
firewall denial
SG denial
application failure
```

Therefore always inspect:

```text
route actually learned?
```

not merely:

```text
BGP session established?
```

---

# 36.488 Example

BGP is UP.

On-prem advertises:

```text
10.10.0.0/16
```

but application lives in:

```text
172.20.10.0/24
```

Nobody advertises:

```text
172.20.10.0/24
```

So:

```text
BGP = UP
```

while:

```text
application unreachable.
```

That isn't contradictory.

BGP session health and route content are separate.

---

# 36.489 Direct Connect troubleshooting

Use the layered model from Part 3:

```text
LAYER 1
Physical DX connection

      ↓

LAYER 2
Ethernet / VLAN

      ↓

LAYER 3
VIF peer IP

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
```

Never jump directly from:

```text
DX Status = available
```

to:

```text
application should work.
```

---

# 36.490 DX incident #1

Suppose:

```text
DX connection = UP
Transit VIF = DOWN
```

Physical connectivity exists.

Investigate the logical layer:

```text
VLAN ID
VIF configuration
customer router interface
802.1Q tagging
peer addressing
```

Don't start editing VPC security groups.

The failure occurs earlier.

---

# 36.491 DX incident #2

```text
DX = UP
VIF = UP
BGP = DOWN
```

Now investigate:

```text
ASN
peer IP
BGP MD5
BGP neighbor configuration
```

Again, not:

```text
TGW blackhole
```

because the routing adjacency isn't established yet.

---

# 36.492 DX incident #3

```text
DX = UP
VIF = UP
BGP = UP
```

but:

```text
10.10.0.0/16
```

isn't reachable.

Now ask:

```text
Did customer advertise it?

Did AWS accept it?

Is DXGW/TGW association correct?

Are allowed prefixes correct?

Did TGW learn/contain the route?

Does VPC point toward TGW?
```

The issue has moved from connection health to:

# Route content.

---

# 36.493 BGP route troubleshooting principle

When someone says:

> "BGP isn't working."

Ask:

```text
Do you mean:

1. Neighbor session is DOWN?

or

2. Neighbor is UP but prefix missing?

or

3. Prefix exists but wrong path wins?
```

These are three completely different problems.

---

# 36.494 Wrong path selection — DX vs VPN

Suppose the business expects:

```text
DX = primary
VPN = backup
```

but traffic uses VPN.

Investigate:

```text
1. Prefix lengths identical?

2. Is VPN advertising a more-specific prefix?

3. Is there a static TGW route toward VPN?

4. Is the DXGW route actually propagated?

5. Which TGW RT is being used?

6. Which prefix/attachment is selected?

7. On-prem BGP LOCAL_PREF correct?

8. DX BGP communities correct?

9. AS_PATH policy correct?
```

The phrase:

```text
"DX is primary"
```

is documentation.

The routing table is reality.

---

# 36.495 Never trust architecture diagrams over routing state

Diagram:

```text
DX PRIMARY
VPN BACKUP
```

Actual route table:

```text
10.10.50.0/24 → VPN
10.10.0.0/16  → DX
```

Traffic toward:

```text
10.10.50.20
```

uses:

```text
VPN
```

because `/24` is more specific.

Networking follows routing logic, not labels.

---

# 36.496 Firewall troubleshooting

Now assume traffic should traverse:

```text
Prod
 ↓
TGW
 ↓
Inspection VPC
 ↓
Firewall
 ↓
TGW
 ↓
On-Prem
```

Symptoms:

```text
SYN leaves Prod
but no successful connection.
```

Possible causes:

```text
wrong TGW route

wrong inspection VPC subnet route

firewall policy deny

return traffic bypasses firewall

wrong AZ path

appliance mode misconfiguration

NAT unexpectedly changing addresses
```

This is why centralized inspection is one of the more advanced AWS networking patterns.

---

# 36.497 Stateful firewall symmetry

Suppose forward:

```text
10.64.5.20
   ↓
Firewall A
   ↓
10.10.50.20
```

but return:

```text
10.10.50.20
   ↓
Firewall B
   ↓
10.64.5.20
```

Firewall B may lack the state created by Firewall A.

Potential symptom:

```text
SYN
   →
SYN-ACK
   ←
DROP
```

or an application that behaves intermittently.

Immediately think:

```text
ASYMMETRIC ROUTING
```

when stateful middleboxes are involved.

---

# 36.498 `tcpdump` becomes extremely powerful

On a Linux endpoint:

```bash
sudo tcpdump -ni any host 10.10.50.20
```

For specific port:

```bash
sudo tcpdump -ni any host 10.10.50.20 and port 1521
```

You may see:

```text
10.64.5.20.53022 > 10.10.50.20.1521: SYN
```

repeatedly.

But no:

```text
SYN-ACK
```

This tells you:

```text
source is sending
```

but:

```text
reply isn't arriving.
```

Now concentrate downstream or on return routing.

---

# 36.499 Compare with this capture

```text
SYN →
← SYN-ACK
ACK →
```

Three-way handshake succeeds.

But application fails later.

Now network-layer reachability exists.

Move upward toward:

```text
TLS
application protocol
authentication
application service
```

Again, observe before changing.

---

# 36.500 The TCP handshake is your friend

For TCP:

```text
CLIENT                         SERVER

SYN
──────────────────────────────→

               SYN-ACK
←──────────────────────────────

ACK
──────────────────────────────→

CONNECTION ESTABLISHED
```

If you know which of these packets are present, troubleshooting becomes much easier.

---

# 36.501 Return-route failure in tcpdump

Classic symptom:

```text
Client:

SYN →
SYN →
SYN →
SYN →
```

No reply.

Possible:

```text
forward traffic blocked
destination not listening
return route missing
return firewall blocking
```

Now capture on the destination side.

If destination sees:

```text
SYN arrive
```

and sends:

```text
SYN-ACK
```

then:

```text
forward path works
```

and the problem is likely:

```text
return path.
```

That's how packet captures isolate directionality.

---

# 36.502 VPC Flow Logs + tcpdump together

Suppose source tcpdump:

```text
SYN leaves
```

TGW Flow Logs:

```text
flow appears
```

Destination VPC Flow Logs:

```text
ACCEPT
```

Destination tcpdump:

```text
SYN arrives
```

but:

```text
no SYN-ACK generated
```

Now stop changing TGW.

Problem is on:

```text
destination OS/application.
```

This is what evidence-driven troubleshooting looks like.

---

# 36.503 DNS troubleshooting — Resolver Query Logs

Route 53 VPC Resolver query logging can capture DNS queries made by VPC resources and queries that use Resolver endpoints; AWS notes that Resolver caches answers and query logging logs unique queries rather than every cache-served repeat query. ([AWS Documentation][8])

This means DNS query logs can answer:

```text
Did AWS receive the query?

What hostname was queried?

What record type?

What response/result occurred?

Which source generated it?
```

---

# 36.504 Resolver Query Logs caveat

Suppose application makes:

```text
1000 queries
```

for the same cached hostname.

You may not see:

```text
1000 identical Resolver log entries
```

because VPC Resolver caches responses and the logging behavior records unique queries rather than cache hits. ([AWS Documentation][8])

Do not mistake caching for missing logging.

---

# 36.505 DNS failure #1 — timeout

```bash
dig oracle.corp.internal
```

Result:

```text
;; connection timed out
```

Think:

```text
Resolver endpoint path?

UDP/TCP 53 allowed?

Outbound endpoint routes?

TGW route?

VPN/DX?

Corporate firewall?

DNS server reachable?
```

This is primarily a:

```text
transport/reachability
```

symptom.

---

# 36.506 DNS failure #2 — NXDOMAIN

Result:

```text
status: NXDOMAIN
```

Very different.

A DNS server responded:

> "That name does not exist."

Now investigate:

```text
wrong authoritative namespace?

wrong forwarding rule?

record missing?

private hosted zone shadowing?

typo in hostname?

query forwarded to wrong DNS system?
```

Do not debug VPN tunnels first.

---

# 36.507 DNS failure #3 — SERVFAIL

```text
status: SERVFAIL
```

The resolver couldn't successfully complete resolution.

Investigate:

```text
upstream resolver failure
DNS delegation problem
forwarding loop
authoritative DNS issue
DNSSEC where applicable
resolver processing failure
```

Different symptom, different branch.

---

# 36.508 Query a specific resolver

Instead of:

```bash
dig oracle.corp.internal
```

ask corporate DNS directly:

```bash
dig @10.10.1.53 oracle.corp.internal
```

If this works:

```text
Corporate DNS ✓
```

but normal AWS query fails:

```text
VPC Resolver
   ↓
Outbound endpoint
   ↓
Corporate DNS
```

then investigate the forwarding path.

Excellent isolation technique.

---

# 36.509 Test inbound Resolver from on-prem

On-prem:

```bash
dig @10.72.10.10 jenkins.aws.internal
```

If:

```text
ANSWER:
jenkins.aws.internal → 10.72.5.20
```

then the AWS inbound endpoint path is functional.

If corporate clients still cannot resolve:

```text
jenkins.aws.internal
```

the problem may be:

```text
on-prem conditional forwarder.
```

---

# 36.510 DNS forwarding-loop symptom

Architecture mistake:

```text
AWS:

corp.internal
 → corporate DNS


Corporate DNS:

corp.internal
 → AWS Resolver
```

Possible result:

```text
query bouncing
until failure/timeout.
```

Ask:

```text
Who is AUTHORITATIVE
for corp.internal?
```

There should be a clear answer.

Namespace ownership comes before forwarding rules.

---

# 36.511 MTU troubleshooting

Now one of the more subtle failures.

Symptoms:

```text
ping works

SSH maybe works

small HTTP works

BUT

large HTTPS transfers hang

database replication stalls

large file copy fails
```

Think:

# MTU / MSS.

Especially when:

```text
IPsec
VPN over DX
GRE
multiple encapsulations
```

are involved.

---

# 36.512 Test packet size

Linux:

```bash
ping -M do -s 1400 10.10.50.20
```

Then try different sizes.

For example:

```bash
ping -M do -s 1300 10.10.50.20
```

The objective is not:

> "1400 is always correct."

The objective is:

```text
Find where the usable packet size changes.
```

Different IPsec cipher/configuration choices can change effective overhead, so validate the actual path rather than hard-coding a number based solely on memory.

---

# 36.513 `tracepath`

Use:

```bash
tracepath 10.10.50.20
```

It can help investigate:

```text
path
MTU behavior
routing changes
```

though intermediate network devices may limit what is visible.

---

# 36.514 MSS clamping

In VPN environments, customer routers/firewalls often support TCP MSS adjustment/clamping.

Conceptually:

```text
Client says:

"I can send MSS 1460"
```

but encrypted path can only safely carry a smaller segment.

Network device rewrites MSS:

```text
1460
 ↓
smaller safe MSS
```

which reduces fragmentation/black-hole problems.

Don't blindly configure an MSS value without understanding the tunnel overhead and AWS VPN configuration.

---

# 36.515 Overlapping CIDRs troubleshooting

Scenario:

```text
Prod VPC
10.64.0.0/16

Acquired company
10.64.0.0/16
```

Application:

```text
10.64.5.20
```

Which one?

Routing cannot uniquely represent two identical address spaces in one ordinary routed domain.

Symptoms may include:

```text
route propagation absent

unreachable networks

traffic reaching wrong network

TGW attachment route conflicts
```

At this point troubleshooting becomes architecture remediation:

```text
renumbering
NAT
proxy
segmentation
migration strategy
```

not simply changing one TGW route.

---

# 36.516 CIDR overlap should be detected before production

This is where:

```text
IPAM
Terraform validation
CI checks
architecture review
```

should stop bad address allocation before it becomes:

```text
"production networking incident."
```

Prevention is dramatically easier than renumbering deployed systems.

---

# 36.517 Security Group troubleshooting rule

Remember:

```text
Security Groups are stateful.
```

When an allowed connection is initiated, response traffic is automatically allowed as part of the tracked connection even if an explicit reverse inbound rule is not separately added.

NACLs operate differently and are stateless, so appropriate rules must account for both directions.

For hybrid networking, always separate:

```text
SG logic
```

from:

```text
NACL logic.
```

---

# 36.518 NACL ephemeral-port problem

Example:

```text
Client:
10.10.50.20:53000

Server:
10.64.5.20:443
```

Forward:

```text
53000 → 443
```

Return:

```text
443 → 53000
```

If a restrictive NACL allows:

```text
443
```

but doesn't accommodate required ephemeral return traffic appropriately:

```text
connection can fail.
```

This is a classic stateless-firewall problem.

---

# 36.519 One useful TCP mental model

Client initiates:

```text
10.10.50.20:53000
        →
10.64.5.20:443
```

Response:

```text
10.64.5.20:443
        →
10.10.50.20:53000
```

Notice:

```text
server destination port = 443

client return destination port = 53000
```

This is why ephemeral ports matter to stateless controls.

---

# 36.520 Observability architecture

For our enterprise platform I want something like:

```text
                     NETWORK OBSERVABILITY

                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼

     VPC Flow Logs        TGW Flow Logs        VPN Logs
         │                    │                    │
         │                    │                    │
         └───────────────┬────┴───────┬────────────┘
                         ▼            ▼
                  CloudWatch Logs     S3
                         │
                         ▼
                    Analysis/Alerts

                              +

                    Route53 Resolver
                      Query Logging
                            │
                            ▼
                     DNS Visibility
```

AWS supports CloudWatch/S3-based logging paths for the relevant flow-log and Resolver/VPN logging capabilities described above. ([AWS Documentation][4])

---

# 36.521 Why send large-volume flow logs to S3?

For high-volume long-term network analytics:

```text
TGW Flow Logs
VPC Flow Logs
        │
        ▼
       S3
        │
        ▼
      Athena
```

is often attractive.

AWS specifically documents TGW Flow Logs stored in S3 and querying/processing those records, including partitioning considerations for large datasets. ([AWS Documentation][9])

Think:

```text
CloudWatch
→ operational investigation / alarms

S3 + query tooling
→ longer-term analytics
```

depending on requirements.

---

# 36.522 Example questions logs can answer

Imagine an incident.

You can query:

```text
Which VPC talked to 10.10.50.20?

How many bytes traversed TGW?

Which attachment carried traffic?

Did traffic suddenly shift to VPN?

Which clients generated rejected traffic?

Which DNS names are being requested?

Which source queried a suspicious domain?
```

This is why observability must be designed **before** incidents.

---

# 36.523 Network Access Analyzer vs Reachability Analyzer

These are related but different tools.

### Reachability Analyzer

Think:

```text
Specific source → destination

Can this path exist?
Why is it blocked?
```

AWS describes it as connectivity/configuration analysis between specified resources. ([AWS Documentation][10])

### Network Access Analyzer

Think more broadly:

```text
Which network paths exist
that match a security/access scope?
```

AWS describes Network Access Analyzer as a way to understand network access to resources based on configured network paths and scopes. ([AWS Documentation][11])

Memory:

```text
Reachability Analyzer
=
debug one path


Network Access Analyzer
=
audit classes of network access
```

---

# 36.524 AWS Network Manager Route Analyzer

For Transit Gateway environments, AWS Network Manager Route Analyzer can analyze TGW routing paths between a source and destination and help verify the TGW route-table configuration. ([AWS Documentation][12])

This is particularly useful when your network has become:

```text
TGW
├── VPCs
├── VPN
├── DX
├── peerings
└── multiple route tables
```

and manually reading every route becomes difficult.

---

# 36.525 The production incident runbook

Let's create a deterministic process.

User reports:

```text
"Payments cannot reach Oracle."
```

Source:

```text
10.64.5.20
```

Destination:

```text
oracle.corp.internal
10.10.50.20:1521
```

---

## Phase 1 — DNS

```bash
dig oracle.corp.internal
```

Expected:

```text
10.10.50.20
```

If no:

```text
debug DNS.
```

If yes:

```text
continue.
```

---

# 36.526 Phase 2 — application port

```bash
nc -vz 10.10.50.20 1521
```

If success:

```text
network likely okay
debug Oracle/application.
```

If timeout:

```text
continue.
```

---

# 36.527 Phase 3 — source packet

```bash
sudo tcpdump -ni any host 10.10.50.20 and port 1521
```

Do we see:

```text
SYN leaving?
```

If no:

```text
source/application/OS issue.
```

If yes:

```text
continue.
```

---

# 36.528 Phase 4 — source VPC

Inspect:

```text
Prod route table

10.10.0.0/16 → TGW
```

Then:

```text
SG
NACL
VPC Flow Logs
```

If flow never leaves AWS source VPC correctly:

```text
fix source VPC.
```

---

# 36.529 Phase 5 — Transit Gateway

Ask:

```text
Prod attachment AVAILABLE?

Associated with PROD-RT?

PROD-RT contains:

10.10.0.0/16 → Inspection?
```

Then use:

```text
TGW Flow Logs
Reachability Analyzer / Route Analyzer
```

where applicable.

TGW Flow Logs and AWS routing-analysis tools give complementary runtime metadata and configuration-path analysis. ([AWS Documentation][4])

---

# 36.530 Phase 6 — Firewall

Check:

```text
forward packet enters inspection path?

policy allows TCP 1521?

source address expected?

destination expected?

return flow through same stateful path?

appliance mode configured appropriately?
```

Don't assume:

```text
Network Firewall healthy
```

means:

```text
rule allows your traffic.
```

---

# 36.531 Phase 7 — hybrid path

If using DX:

```text
DX UP?
VIF UP?
BGP UP?
10.10.0.0/16 learned?
```

If using VPN:

```text
Tunnel 1?
Tunnel 2?
BGP?
route advertised?
```

CloudWatch VPN metrics and VPN tunnel/BGP logs are designed to provide this operational visibility. ([AWS Documentation][6])

---

# 36.532 Phase 8 — on-prem

Corporate networking team checks:

```text
AWS prefix learned?

firewall allows source?

Oracle VLAN reachable?

route to 10.10.50.20?

return route:

10.64.0.0/16 → AWS?
```

Now we're approaching the destination.

---

# 36.533 Phase 9 — destination

On Oracle host:

```bash
ss -lntp | grep 1521
```

or platform-specific equivalent.

Then packet capture:

```bash
tcpdump host 10.64.5.20
```

If SYN arrives and Oracle doesn't respond:

```text
destination/application issue.
```

If SYN-ACK leaves but never returns to AWS:

```text
return path problem.
```

---

# 36.534 This is the entire method

```text
RESOLVE
  ↓
GENERATE
  ↓
ROUTE
  ↓
TRANSIT
  ↓
INSPECT
  ↓
TRANSPORT
  ↓
DELIVER
  ↓
RETURN
```

Remember those words.

---

# 36.535 Scenario lab #1 — missing VPC route

Problem:

```text
Prod → Shared fails.
```

Configuration:

```text
TGW PROD-RT

10.72.0.0/16 → Shared ✓
```

But Prod VPC route table:

```text
10.64.0.0/16 → local

no 10.72/16 route
```

Failure occurs before TGW.

Fix:

```text
Prod VPC RT

10.72.0.0/16 → TGW
```

Never start with TGW route tables until source VPC forwarding is correct.

---

# 36.536 Scenario lab #2 — missing TGW propagation

VPC route:

```text
10.72.0.0/16 → TGW ✓
```

But PROD-RT has no:

```text
10.72.0.0/16
```

because Shared attachment propagation wasn't configured.

Packet reaches TGW:

```text
TGW
 ↓
No matching route
 ↓
DROP
```

Fix propagation or explicit route.

---

# 36.537 Scenario lab #3 — reverse route missing

Forward:

```text
Prod → Shared
```

works until destination.

But SHARED-RT lacks:

```text
10.64.0.0/16 → Prod
```

Result:

```text
SYN arrives

SYN-ACK cannot return.
```

This is why every connectivity test must mentally include two paths:

```text
A → B

B → A
```

---

# 36.538 Scenario lab #4 — SG blocks application

Routes perfect.

Flow:

```text
On-Prem → EC2:443
```

EC2 SG only allows:

```text
443 from 10.64.0.0/16
```

but source is:

```text
10.10.50.20
```

Result:

```text
routing ✓
VPN ✓
TGW ✓
SG ✕
```

Fix according to required policy:

```text
443 from approved on-prem CIDR
```

not:

```text
0.0.0.0/0
```

just to make the test pass.

Troubleshooting should not destroy security.

---

# 36.539 Scenario lab #5 — NACL return issue

Forward:

```text
client ephemeral → server 443
```

passes.

Return ephemeral-port traffic is not permitted by the stateless NACL policy.

Symptom:

```text
TCP connection timeout.
```

Fix the stateless ACL rules appropriately rather than adding random SG entries.

---

# 36.540 Scenario lab #6 — VPN tunnel 1 down

Tunnel status:

```text
Tunnel 1 DOWN
Tunnel 2 UP
```

Applications:

```text
still working.
```

Is that okay?

Potentially yes—the redundant second tunnel is doing its job.

But don't ignore it.

Investigate and restore redundancy because now:

```text
one more failure
=
outage.
```

High availability means maintaining redundancy, not waiting until both paths fail.

---

# 36.541 Scenario lab #7 — both tunnels UP but only one configured properly

AWS provides two tunnels.

Customer configured:

```text
Tunnel 1 ✓
Tunnel 2 ✕
```

Dashboard might look acceptable under normal conditions.

Then AWS tunnel maintenance or failure occurs:

```text
Tunnel 1 unavailable
```

and the whole connection fails.

Lesson:

> **Redundancy must be configured and tested—not merely provisioned.**

---

# 36.542 Scenario lab #8 — DX route missing

DX:

```text
connection UP
VIF UP
BGP UP
```

But corporate router stopped advertising:

```text
10.10.50.0/24
```

Only advertises:

```text
10.10.0.0/20
```

which doesn't include the target network.

Application fails.

Lesson:

```text
BGP adjacency health
≠
correct route advertisements.
```

---

# 36.543 Scenario lab #9 — VPN unexpectedly preferred

Routes:

```text
DX:
10.10.0.0/16

VPN:
10.10.50.0/24
```

Oracle:

```text
10.10.50.20
```

uses VPN.

Why?

```text
/24 > /16
```

Nothing is "wrong" with BGP.

The route advertisements caused exactly that result.

---

# 36.544 Scenario lab #10 — firewall asymmetry

Forward:

```text
Prod
 → Firewall AZ-A
 → On-Prem
```

Return:

```text
On-Prem
 → Firewall AZ-B
 → Prod
```

Stateful firewall drops response.

Fix requires architectural routing symmetry/appliance design—not:

```text
"allow all TCP."
```

This is the type of incident where packet-flow diagrams save hours.

---

# 36.545 Scenario lab #11 — DNS outbound rule missing

AWS:

```bash
dig oracle.corp.internal
```

fails.

Direct query:

```bash
dig @10.10.1.53 oracle.corp.internal
```

works.

Therefore:

```text
on-prem DNS works
network to DNS works
```

but:

```text
Route53 forwarding path is wrong.
```

Check:

```text
Resolver rule
rule association
outbound endpoint
```

---

# 36.546 Scenario lab #12 — DNS SG allows UDP only

Most simple DNS queries work.

But some queries fail.

Security Group:

```text
UDP 53 ✓
TCP 53 ✕
```

DNS can use both UDP and TCP, so Resolver endpoint security should account for both where standard DNS is required.

This causes nasty intermittent-looking DNS incidents.

---

# 36.547 Scenario lab #13 — PHZ shadowing

Public DNS has:

```text
api.example.com
```

AWS VPC has private hosted zone:

```text
example.com
```

but private zone does not contain:

```text
api.example.com
```

Application receives unexpected NXDOMAIN behavior instead of the public record.

Lesson:

```text
DNS namespace ownership
```

is architecture, not merely configuration.

---

# 36.548 Scenario lab #14 — MTU black hole

Symptoms:

```text
ping ✓
nc ✓
small curl ✓
large upload ✕
```

Direct Connect + IPsec architecture.

Investigate:

```text
MTU
MSS
encapsulation overhead
customer router
```

Not:

```text
IAM.
```

Learn to recognize symptom patterns.

---

# 36.549 Scenario lab #15 — Terraform says success, traffic fails

Terraform:

```text
Apply complete!
```

But PROD-RT accidentally has:

```text
10.10.0.0/16 → blackhole
```

Terraform is doing exactly what you asked.

It doesn't know your architectural intent unless you encode and test that intent.

Therefore mature Infrastructure as Code needs:

```text
validation
policy checks
post-deploy network tests
```

not only syntactically valid HCL.

---

# 36.550 Monitoring strategy

For production, I'd think in four categories:

```text
AVAILABILITY

VPN tunnels
DX
BGP


CONNECTIVITY

Flow logs
Reachability tests
synthetic checks


SECURITY

REJECT traffic
Firewall logs
DNS Firewall/query patterns


PERFORMANCE

bytes
packet volume
latency
packet loss
bandwidth utilization
application latency
```

A network can be:

```text
UP
```

while:

```text
performance is unusable.
```

---

# 36.551 Synthetic connectivity tests

An advanced operational approach is to continuously test critical paths such as:

```text
Prod → Oracle:1521

Prod → AD:389/636

On-Prem → Internal API:443

AWS → Corp DNS:53

On-Prem → AWS Resolver:53
```

For example:

```text
network is technically healthy
```

but:

```text
Oracle path fails.
```

A service-specific synthetic check catches what interface-only monitoring may miss.

---

# 36.552 What should trigger alarms?

Examples:

```text
VPN tunnel DOWN

both VPN tunnels degraded

DX/VIF/BGP state change

unexpected traffic rejects

large jump in TGW traffic

network firewall deny anomaly

DNS SERVFAIL spike

DNS NXDOMAIN spike

hybrid DNS resolution failure

synthetic on-prem reachability failure
```

The goal is:

```text
detect before user tickets
```

where practical.

---

# 36.553 Observability without context is noisy

A million flow-log records are not automatically useful.

You need metadata:

```text
Attachment ID
       ↓
Which account?

Which application?

Which environment?

Which CIDR?

Which owner?
```

Hence the tags we discussed in Part 7:

```text
Name
Environment
Account
Owner
RoutingDomain
Application
```

become operationally important.

---

# 36.554 Build a network source map

Maintain something conceptually like:

| Prefix         | Environment   | Account   | Attachment    | Routing domain |
| -------------- | ------------- | --------- | ------------- | -------------- |
| `10.10.0.0/16` | On-Prem       | Corporate | DX/VPN        | Hybrid         |
| `10.64.0.0/16` | Payments Prod | Prod      | Prod Attach   | Prod           |
| `10.68.0.0/16` | Dev           | Dev       | Dev Attach    | NonProd        |
| `10.72.0.0/16` | Shared        | Shared    | Shared Attach | Shared         |
| `10.73.0.0/16` | Security      | Security  | Inspection    | Security       |

Then if a flow log says:

```text
src=10.64.5.20
dst=10.10.50.20
```

you immediately understand:

```text
Payments Prod → Corporate DC
```

instead of staring at anonymous addresses.

---

# 36.555 The most important troubleshooting command isn't a command

It's:

> **Draw the packet path.**

Before touching the console, write:

```text
10.64.5.20
   ↓
Prod RT
   ↓
TGW Prod attachment
   ↓
PROD-RT
   ↓
Inspection attachment
   ↓
Firewall
   ↓
SECURITY-RT
   ↓
DXGW
   ↓
DX
   ↓
Corporate router
   ↓
10.10.50.20
```

Then underneath:

```text
RETURN

10.10.50.20
   ↓
Corporate router
   ↓
DX
   ↓
TGW
   ↓
Inspection
   ↓
TGW
   ↓
Prod
   ↓
10.64.5.20
```

Now inspect every arrow.

That's production networking.

---

# 36.556 Never-forget troubleshooting matrix

| Symptom                           | First suspects                        |
| --------------------------------- | ------------------------------------- |
| Hostname doesn't resolve          | Resolver/rules/DNS                    |
| NXDOMAIN                          | Wrong/missing DNS record or namespace |
| DNS timeout                       | DNS network path/endpoint/SG          |
| Ping fails, HTTPS works           | ICMP blocked                          |
| Ping works, app fails             | Port/app/security                     |
| SYN only                          | Forward/destination/return path       |
| SYN + SYN-ACK but no ACK          | Return/firewall/client path           |
| VPN DOWN                          | IKE/IPsec/endpoint                    |
| VPN UP, BGP DOWN                  | ASN/inside IP/BGP                     |
| BGP UP, prefix absent             | Advertisement/filter/propagation      |
| DX UP, VIF DOWN                   | VLAN/VIF/L2                           |
| VIF UP, BGP DOWN                  | ASN/peer/MD5                          |
| Only one subnet fails             | Specific route/NACL/SG                |
| Large packets fail                | MTU/MSS                               |
| Intermittent stateful flows       | Asymmetry/appliance path              |
| Prod reaches Dev unexpectedly     | TGW propagation/association           |
| Terraform succeeds, traffic fails | Data-plane validation missing         |

---

# 36.557 Seven tools to remember

If I ask you in an interview:

> **How would you troubleshoot an AWS hybrid-networking outage?**

A strong answer could mention:

```text
1. Reachability Analyzer
   → static AWS path analysis

2. VPC Flow Logs
   → VPC/interface traffic visibility

3. TGW Flow Logs
   → transit traffic visibility

4. CloudWatch VPN metrics/logs
   → VPN tunnel/BGP health

5. Route 53 Resolver Query Logs
   → DNS resolution visibility

6. tcpdump / nc / curl / dig
   → endpoint runtime validation

7. AWS Network Manager Route Analyzer
   → TGW route-path analysis
```

AWS currently supports each of those AWS-side observability/analysis capabilities for the roles described. ([AWS Documentation][10])

---

# 36.558 The senior-engineer mental model

Junior troubleshooting:

```text
"It's probably the security group."
```

Better troubleshooting:

```text
"The TCP SYN leaves 10.64.5.20,
appears in the source VPC flow logs,
crosses the Prod TGW attachment,
is visible on the inspection path,
but no corresponding traffic appears
after the firewall.

Let's inspect firewall policy/routing."
```

That is the difference between:

```text
guessing
```

and:

```text
evidence.
```

---

# 36.559 Lesson 36 progress

We now have:

```text
Part 1   Site-to-Site VPN              ✓
Part 2   Transit Gateway               ✓
Part 3   Direct Connect                ✓
Part 4   BGP & resiliency              ✓
Part 5   Private VPN over DX           ✓
Part 6   Hybrid DNS                    ✓
Part 7   Multi-account networking      ✓
Part 8   Terraform implementation      ✓
Part 9   Troubleshooting/observability ✓

Part 10  Enterprise hands-on capstone  NEXT
Part 11  Final revision/interviews
```

We are now approximately:

```text
████████████████████████░░
~85–90%
```

through **Lesson 36**.

---

# Next — Lesson 36, Part 10

# Complete Enterprise Hybrid-Cloud Hands-On Capstone

Now we'll combine **everything**.

The capstone architecture will be:

```text
                       SIMULATED CORPORATE DC
                             10.10.0.0/16

                         Linux VPN Router
                          ASN 65000
                              │
                         IPsec / BGP
                              │
                              ▼
                     AWS TRANSIT GATEWAY
                              │
               ┌──────────────┼──────────────┐
               │              │              │
               ▼              ▼              ▼
           PROD VPC       SHARED VPC     SECURITY VPC
           10.64/16        10.72/16        10.73/16
               │              │              │
              EC2         Resolver        Inspection
                              │
                              ▼
                        Hybrid DNS
```

Because a real Direct Connect circuit requires a carrier/colocation workflow and physical connectivity, **we won't create chargeable imaginary DX fiber in the lab**. Instead, we'll build the parts we can genuinely reproduce in AWS and clearly mark the exact point where Direct Connect/DXGW/transit-VIF would replace or augment the simulated transport.

The hands-on will include:

```text
Terraform repository

VPCs

TGW

separate TGW route tables

associations

propagations

blackhole segmentation

Site-to-Site VPN model

BGP mental/config mapping

Shared Resolver architecture

test EC2 hosts

VPC Flow Logs

TGW Flow Logs

DNS tests

TCP tests

intentional failure injection

route troubleshooting

return-path troubleshooting

cleanup to avoid charges
```

Then **Part 11** will close Lesson 36 with the final **VPN vs DX vs TGW vs VPC Peering decision matrix, architecture interview questions, SAA/DOP exam traps, production checklist, and never-forget revision map**.

[1]: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html?utm_source=chatgpt.com "Logging IP traffic using VPC Flow Logs"
[2]: https://docs.aws.amazon.com/vpc/latest/reachability/how-reachability-analyzer-works.html?utm_source=chatgpt.com "How Reachability Analyzer works"
[3]: https://docs.aws.amazon.com/vpc/latest/userguide/reachability-analyzer.html?utm_source=chatgpt.com "Troubleshoot reachability issues using Reachability Analyzer"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-flow-logs.html?utm_source=chatgpt.com "AWS Transit Gateway Flow Logs - Amazon VPC"
[5]: https://docs.aws.amazon.com/vpc/latest/tgw/process-records-cwl.html?utm_source=chatgpt.com "Process AWS Transit Gateway Flow Logs records in Amazon ..."
[6]: https://docs.aws.amazon.com/vpn/latest/s2svpn/monitoring-cloudwatch-vpn.html?utm_source=chatgpt.com "Monitor AWS Site-to-Site VPN tunnels using ..."
[7]: https://docs.aws.amazon.com/vpn/latest/s2svpn/monitoring-logs.html?utm_source=chatgpt.com "AWS Site-to-Site VPN logs"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-query-logs.html?utm_source=chatgpt.com "Resolver query logging - Amazon Route 53"
[9]: https://docs.aws.amazon.com/vpc/latest/tgw/flow-logs-s3.html?utm_source=chatgpt.com "AWS Transit Gateway Flow Logs records in Amazon S3"
[10]: https://docs.aws.amazon.com/vpc/latest/reachability/what-is-reachability-analyzer.html?utm_source=chatgpt.com "What is Reachability Analyzer?"
[11]: https://docs.aws.amazon.com/vpc/latest/network-access-analyzer/getting-started.html?utm_source=chatgpt.com "Getting started with Network Access Analyzer"
[12]: https://docs.aws.amazon.com/network-manager/latest/tgwnm/route-analyzer.html?utm_source=chatgpt.com "Route Analyzer for AWS Network Manager"
