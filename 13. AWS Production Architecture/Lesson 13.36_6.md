# Lesson 36 — AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

## Part 6: Route 53 VPC Resolver Hybrid DNS — On-Prem ↔ AWS Name Resolution

We have now solved the **network path**:

```text
AWS workload
   │
   ▼
TGW
   │
   ├── VPN
   └── Direct Connect
   │
   ▼
On-Premises
```

So this might work:

```bash
ping 10.10.50.20
```

But the application probably doesn't use:

```text
10.10.50.20
```

It uses something like:

```text
oracle-prod.corp.internal
```

Now we have an entirely different problem:

# DNS resolution.

A hybrid architecture is incomplete until both environments can answer:

```text
AWS → "What IP is oracle-prod.corp.internal?"

On-Prem → "What IP is payments.prod.aws.internal?"
```

AWS provides **Route 53 VPC Resolver** for this. AWS recently uses the name *Route 53 VPC Resolver* to distinguish it from newer Route 53 Global Resolver functionality; VPC Resolver is available by default inside VPCs. ([AWS Documentation][1])

---

# 36.286 First mental model — routing and DNS are different

Suppose AWS can successfully reach:

```text
10.10.50.20
```

but:

```bash
nslookup oracle-prod.corp.internal
```

fails.

Then:

```text
NETWORK ROUTING = working

DNS = broken
```

Never mix these two troubleshooting layers.

Think:

```text
Application
     │
     ▼
DNS lookup
     │
     ▼
IP address obtained
     │
     ▼
Network routing
     │
     ▼
TCP connection
```

DNS happens **before** the application can route toward the destination when the application uses a hostname.

---

# 36.287 What DNS already exists inside every VPC?

Suppose your VPC is:

```text
10.20.0.0/16
```

AWS provides a VPC DNS Resolver reachable through the reserved VPC `+2` address:

```text
10.20.0.2
```

AWS also exposes the Amazon-provided resolver through:

```text
169.254.169.253
```

and the VPC Resolver recursively handles public DNS, AWS/VPC-specific names, and Route 53 private hosted zones. ([AWS Documentation][2])

So:

```text
VPC CIDR
10.20.0.0/16

Network       10.20.0.0
...
Resolver      10.20.0.2
```

Memory trick:

# VPC + 2 = Amazon-provided DNS Resolver.

---

# 36.288 Example

EC2:

```text
10.20.1.50
```

runs:

```bash
dig amazon.com
```

Conceptually:

```text
EC2
10.20.1.50
     │
     │ DNS query
     ▼
10.20.0.2
VPC Resolver
     │
     ▼
DNS resolution
```

You normally don't configure every EC2 instance manually with the `VPC+2` IP because VPC/DHCP configuration makes Amazon-provided DNS available automatically in normal VPC setups. AWS's `enableDnsSupport` VPC setting controls whether queries to the Amazon-provided resolver succeed; this setting is enabled by default. ([AWS Documentation][2])

---

# 36.289 Two VPC DNS attributes

You should recognize:

```text
enableDnsSupport
enableDnsHostnames
```

### enableDnsSupport

Controls whether VPC DNS resolution through the Amazon-provided DNS server is supported.

### enableDnsHostnames

Controls whether instances with public IP addressing can receive corresponding public DNS hostnames and participates in VPC DNS hostname behavior. AWS documents these as separate VPC DNS attributes. ([AWS Documentation][2])

Terraform often contains:

```hcl
resource "aws_vpc" "prod" {
  cidr_block = "10.20.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true
}
```

For our production VPCs, DNS support will normally remain enabled.

---

# 36.290 Route 53 Private Hosted Zone

Suppose AWS applications should use:

```text
payments.prod.aws.internal
```

and that hostname should resolve to:

```text
10.20.5.100
```

We can create:

# Route 53 Private Hosted Zone — PHZ

```text
Zone:

aws.internal
```

with:

```text
payments.prod.aws.internal
       A
       ↓
10.20.5.100
```

A private hosted zone contains DNS records that Route 53 resolves only in associated VPC/hybrid contexts rather than publishing them as ordinary Internet DNS records. ([AWS Documentation][3])

Architecture:

```text
                 Route 53

             Private Hosted Zone
                aws.internal
                     │
             ┌───────┴─────────┐
             │                 │
payments.prod.aws.internal   db.aws.internal
       │                       │
10.20.5.100                10.20.8.20
```

---

# 36.291 Private Hosted Zone association

A private hosted zone isn't automatically visible to every VPC in AWS.

You associate it with one or more VPCs.

Example:

```text
aws.internal
     │
     ├── associated → Prod VPC
     ├── associated → Shared VPC
     └── associated → Dev VPC
```

VPCs associated with the PHZ can resolve its records through VPC Resolver. AWS supports associating multiple VPCs with a private hosted zone, including cross-account association through the documented authorization workflow. ([AWS Documentation][4])

---

# 36.292 Our hybrid problem

Now suppose:

### On-prem DNS owns:

```text
corp.internal
```

Records:

```text
oracle-prod.corp.internal
     ↓
10.10.50.20

ad01.corp.internal
     ↓
10.10.1.10
```

### Route 53 owns:

```text
aws.internal
```

Records:

```text
payments.prod.aws.internal
      ↓
10.20.5.100

jenkins.aws.internal
      ↓
10.40.4.20
```

We want:

```text
AWS
   ↔
On-Prem
```

DNS resolution in **both directions**.

---

# 36.293 The two Route 53 Resolver endpoints

There are two critical endpoint types:

```text
INBOUND ENDPOINT

OUTBOUND ENDPOINT
```

The easiest memory trick:

```text
INBOUND
=
DNS queries coming INTO AWS


OUTBOUND
=
DNS queries leaving AWS
toward another DNS system
```

AWS documents inbound endpoints as accepting DNS queries from on-premises/other connected networks into VPC Resolver, while outbound endpoints forward selected VPC-originated queries toward DNS resolvers on-premises or in another network. ([AWS Documentation][1])

---

# 36.294 Inbound Resolver endpoint

Question:

> How can corporate DNS resolve `payments.prod.aws.internal`?

We create an:

# INBOUND Resolver endpoint.

Architecture:

```text
ON-PREM                                      AWS

User
 │
 ▼
Corporate DNS
10.10.1.53
 │
 │ query:
 │ payments.prod.aws.internal
 │
 ▼
DX / VPN
 │
 ▼
Route 53 INBOUND Endpoint
10.40.10.10
10.40.20.10
 │
 ▼
VPC Resolver
 │
 ▼
Private Hosted Zone
aws.internal
 │
 ▼
10.20.5.100
```

Inbound endpoint IP addresses are private addresses inside a VPC, so the on-premises resolver needs network connectivity to those addresses through VPN, Direct Connect, or another connected private path. ([AWS Documentation][5])

---

# 36.295 What the corporate DNS server must do

On your on-premises DNS infrastructure—perhaps:

```text
Microsoft Active Directory DNS
BIND
Infoblox
BlueCat
```

—you configure conditional forwarding.

Conceptually:

```text
Domain:

aws.internal

Forward to:

10.40.10.10
10.40.20.10
```

So corporate DNS learns:

```text
"If someone asks me about *.aws.internal,
send the query to AWS Resolver."
```

The endpoint then allows VPC Resolver to resolve AWS private names such as private hosted-zone records. ([AWS Documentation][6])

---

# 36.296 Full On-Prem → AWS DNS packet flow

User/application:

```text
10.10.20.50
```

asks:

```text
payments.prod.aws.internal
```

### Step 1

Client sends query to corporate DNS:

```text
10.10.1.53
```

### Step 2

Corporate DNS checks its conditional forwarding rules:

```text
aws.internal
    ↓
Route 53 inbound endpoint
```

### Step 3

Query travels over:

```text
Corporate network
     ↓
DX / VPN
     ↓
TGW
     ↓
Shared Services VPC
```

### Step 4

Inbound endpoint receives:

```text
payments.prod.aws.internal?
```

### Step 5

VPC Resolver checks the relevant private DNS namespace.

### Step 6

Private hosted zone returns:

```text
10.20.5.100
```

### Step 7

Response returns:

```text
Route 53
   ↓
Inbound endpoint
   ↓
On-prem DNS
   ↓
Client
```

This is the standard inbound hybrid-resolution pattern AWS documents. ([AWS Documentation][7])

---

# 36.297 Important: inbound means direction of DNS query

Some students see:

```text
Inbound endpoint
```

and think:

> "Inbound traffic to an EC2 instance?"

No.

The word is specifically referring to:

```text
DNS query direction
```

```text
On-Prem
   │
   │ DNS query
   ▼
AWS

=
INBOUND
```

---

# 36.298 Outbound Resolver endpoint

Now reverse the problem.

AWS EC2:

```text
10.20.5.50
```

needs:

```text
oracle-prod.corp.internal
```

The record exists only on:

```text
Corporate DNS
10.10.1.53
```

We need an:

# OUTBOUND Resolver endpoint.

```text
AWS                                         ON-PREM

EC2
 │
 │ oracle-prod.corp.internal?
 ▼
VPC Resolver
 │
 │ Resolver rule
 │ corp.internal
 ▼
OUTBOUND endpoint
 │
 │ DX/VPN
 ▼
Corporate DNS
10.10.1.53
 │
 ▼
10.10.50.20
```

AWS outbound forwarding uses both an outbound endpoint and Resolver forwarding rules that identify which domain names should be sent to which target DNS server IP addresses. ([AWS Documentation][8])

---

# 36.299 Resolver Rule

An outbound endpoint alone doesn't know:

```text
which DNS namespace
```

should go to:

```text
which DNS server.
```

So we create a:

# Resolver forwarding rule.

Example:

```text
Rule name:
corp-internal

Domain:
corp.internal

Target DNS servers:
10.10.1.53
10.10.1.54

Outbound endpoint:
rslvr-out-xxxx
```

Then associate the rule with the VPCs that should use it. AWS forwards matching queries only after the rule is associated with the VPC. ([AWS Documentation][9])

Memory:

```text
Outbound endpoint
=
network exit for DNS


Resolver rule
=
which DNS namespace uses that exit
and where it is sent
```

---

# 36.300 Full AWS → On-Prem DNS flow

EC2:

```text
10.20.5.50
```

runs:

```bash
dig oracle-prod.corp.internal
```

### Step 1 — EC2 asks VPC Resolver

```text
10.20.0.2
```

### Step 2 — Resolver evaluates rules

It finds:

```text
corp.internal
   ↓
FORWARD
   ↓
10.10.1.53
10.10.1.54
```

### Step 3 — Resolver uses outbound endpoint

```text
Shared VPC outbound endpoint
       │
       ▼
TGW
       │
       ▼
DX / VPN
```

### Step 4 — Corporate DNS answers

```text
oracle-prod.corp.internal
      ↓
10.10.50.20
```

### Step 5 — result returns to EC2

```text
10.20.5.50
```

AWS documents exactly this model for hybrid DNS resolution from VPC resources toward on-premises DNS. ([AWS Documentation][7])

---

# 36.301 Bidirectional hybrid DNS

Now combine both paths.

```text
                         SHARED SERVICES VPC

                    ┌────────────────────────┐
                    │ Route 53 VPC Resolver  │
                    └───────────┬────────────┘
                                │
                    ┌───────────┴────────────┐
                    │                        │
                 INBOUND                 OUTBOUND
                    │                        │
                    │                        │
             On-Prem → AWS            AWS → On-Prem
                    │                        │
                    └───────────┬────────────┘
                                │
                            DX / VPN
                                │
                                ▼
                       CORPORATE DNS
```

Memory:

```text
INBOUND
On-Prem asks AWS


OUTBOUND
AWS asks On-Prem
```

---

# 36.302 High availability — never deploy one Resolver IP

For Resolver endpoints, AWS requires multiple IP addresses; for inbound endpoints at least two endpoint IP addresses are required, and AWS recommends using at least two Availability Zones. AWS gives the same minimum-two-IP model for outbound endpoints and recommends distributing them across AZs. ([AWS Documentation][10])

So don't build:

```text
Inbound endpoint
10.40.10.10 only
```

Better:

```text
             Shared VPC

       AZ-A                AZ-B

10.40.10.10            10.40.20.10
Inbound ENI            Inbound ENI

10.40.10.20            10.40.20.20
Outbound ENI           Outbound ENI
```

Resolver creates VPC network interfaces for endpoint IP addresses. ([AWS Documentation][11])

---

# 36.303 Important endpoint-subnet architecture

A clean enterprise Shared Services VPC might contain:

```text
                 SHARED SERVICES VPC
                     10.40.0.0/16

        AZ-A                          AZ-B

Resolver subnet A                Resolver subnet B
10.40.10.0/24                    10.40.20.0/24

Inbound .10                      Inbound .10
Outbound .20                     Outbound .20

       │                              │
       └──────────────┬───────────────┘
                      │
                     TGW
                      │
                  On-Prem
```

Those endpoint subnets need appropriate routing toward the on-premises DNS servers through TGW/DX/VPN, and on-premises routing must have a return path to the Resolver endpoint IPs.

Again:

# DNS still depends on network routing.

---

# 36.304 Security Groups matter for Resolver endpoints

Inbound endpoints must permit DNS requests to reach them. AWS requires the associated security group to allow **TCP and UDP port 53** for standard DNS inbound traffic. ([AWS Documentation][12])

Conceptually:

```text
INBOUND ENDPOINT SG

Inbound:

UDP 53
Source: 10.10.0.0/16

TCP 53
Source: 10.10.0.0/16
```

Why both?

Because DNS can use:

```text
UDP
and
TCP
```

depending on response/query characteristics and DNS behavior.

Never configure:

```text
UDP 53 only
```

as a universal DNS rule and assume you're finished.

---

# 36.305 Outbound endpoint SG

The outbound endpoint needs egress toward your corporate DNS resolver on the DNS port you're using—normally TCP/UDP 53. AWS documents outbound Resolver endpoint security groups as requiring outbound access to the target DNS resolver ports. ([AWS Documentation][12])

Conceptually:

```text
OUTBOUND ENDPOINT SG

Outbound:

UDP 53 → 10.10.1.53
TCP 53 → 10.10.1.53

UDP 53 → 10.10.1.54
TCP 53 → 10.10.1.54
```

---

# 36.306 The DNS troubleshooting stack

Suppose:

```bash
dig oracle-prod.corp.internal
```

times out.

Do not immediately blame Route 53.

Check:

```text
1. Does forwarding rule exist?
        ↓
2. Is rule associated with this VPC?
        ↓
3. Is outbound endpoint healthy?
        ↓
4. Does endpoint SG allow DNS?
        ↓
5. Does endpoint subnet route to TGW?
        ↓
6. Does TGW RT reach on-prem?
        ↓
7. Is DX/VPN healthy?
        ↓
8. Does corporate firewall allow TCP/UDP 53?
        ↓
9. Is corporate DNS listening?
        ↓
10. Does corporate DNS actually own the zone?
        ↓
11. Does return routing exist?
```

This is the correct production debugging mindset.

---

# 36.307 Private Hosted Zone vs Resolver Rule — important trap

Suppose VPC has a private hosted zone:

```text
corp.internal
```

and you also associate a forwarding Resolver rule:

```text
corp.internal
→ on-prem DNS
```

Which one wins?

AWS documents that when a VPC Resolver forwarding rule and a private hosted zone exist for the **same domain**, the Resolver rule takes precedence and queries are forwarded toward the target network instead of being answered from the PHZ. ([AWS Documentation][13])

That's a very important certification and production detail.

---

# 36.308 Example of an accidental outage

You have:

```text
Private Hosted Zone:

corp.internal

Record:

app.corp.internal
→ 10.20.5.50
```

Then someone creates:

```text
Resolver Rule:

corp.internal
→ 10.10.1.53
```

Now AWS workloads querying:

```text
app.corp.internal
```

may be forwarded to:

```text
10.10.1.53
```

instead of using the AWS PHZ. ([AWS Documentation][13])

If corporate DNS doesn't contain that record:

```text
NXDOMAIN
```

Application outage.

The network is fine.

The DNS **namespace design** is wrong.

---

# 36.309 Most-specific DNS forwarding match

Suppose Resolver rules include:

```text
internal
→ DNS-A

corp.internal
→ DNS-B

prod.corp.internal
→ DNS-C
```

Query:

```text
db.prod.corp.internal
```

Resolver uses the most-specific matching rule:

```text
prod.corp.internal
```

rather than the broader domain rules. AWS documents this most-specific-match behavior for Resolver forwarding rules. ([AWS Documentation][14])

This is DNS's version of thinking carefully about specificity.

---

# 36.310 Conditional forwarding

This is such an important concept that you should define it yourself in an interview.

Conditional forwarding means:

> Send DNS queries for a particular DNS namespace to a particular DNS server.

Example:

```text
IF query ends with:

corp.internal

THEN send to:

10.10.1.53
```

Another:

```text
IF query ends with:

partner.internal

THEN send to:

172.20.1.53
```

So:

```text
AWS Resolver

corp.internal
   ↓
Corporate DNS

partner.internal
   ↓
Partner DNS
```

Each forwarding rule identifies the namespace and target DNS servers. ([AWS Documentation][9])

---

# 36.311 Do not forward everything blindly

You could theoretically design broad forwarding like:

```text
.
→ corporate DNS
```

where `.` means essentially all DNS namespaces not overridden.

But now a huge amount of DNS traffic could leave AWS unnecessarily.

AWS automatically provides system rules for AWS/private namespaces and documents considerations when broader forwarding rules such as `.` or `com` are configured. ([AWS Documentation][15])

For most hybrid environments, think:

```text
corp.internal
→ on-prem

legacy.example.com
→ on-prem

partner.internal
→ partner
```

rather than immediately forwarding all DNS.

---

# 36.312 DNS forwarding loop — production nightmare

Suppose:

```text
AWS rule:

corp.internal
→ On-Prem DNS
```

but corporate DNS says:

```text
corp.internal
→ AWS inbound endpoint
```

Now:

```text
AWS
 ↓
On-Prem
 ↓
AWS
 ↓
On-Prem
 ↓
...
```

You've created a:

# DNS forwarding loop.

Symptoms may include:

```text
timeouts
SERVFAIL
high query volume
strange intermittent DNS behavior
```

So always document:

```text
Who is AUTHORITATIVE for each zone?
```

---

# 36.313 DNS authority map

For our company:

```text
ZONE                         AUTHORITY

corp.internal                On-Prem DNS

aws.internal                 Route 53 PHZ

ad.corp.internal             Active Directory DNS

partner.internal             Partner DNS
```

Then forwarding follows authority:

```text
AWS asks corp.internal
     ↓
On-Prem


On-Prem asks aws.internal
     ↓
AWS
```

That's the clean mental model.

---

# 36.314 Active Directory hybrid DNS

This pattern is extremely common.

On-prem:

```text
Microsoft Active Directory

Domain:
corp.internal

DNS:
10.10.1.53
10.10.1.54
```

AWS workloads may need names such as:

```text
_dc._tcp.corp.internal
ldap.corp.internal
dc01.corp.internal
```

Your Resolver rule forwards:

```text
corp.internal
     ↓
10.10.1.53
10.10.1.54
```

That enables AWS workloads to query the corporate AD DNS namespace through the outbound Resolver architecture.

---

# 36.315 What if AWS also runs Active Directory?

Imagine AWS Managed Microsoft AD or self-managed DCs exist in a Shared Services VPC.

Architecture may become:

```text
             ON-PREM AD

              corp.internal
                  │
                  │
                 TGW
                  │
                  ▼
           Shared Services VPC
                  │
              AWS AD/DNS
                  │
          Route 53 Resolver
```

Then DNS delegation/conditional forwarding rules require careful planning so you don't accidentally create:

```text
loops
duplicate zones
conflicting authorities
split-brain surprises
```

Hybrid DNS design is fundamentally about:

```text
namespace ownership
+
forwarding
+
network reachability
```

---

# 36.316 Split-horizon / split-view DNS

Suppose:

```text
app.example.com
```

for Internet users resolves to:

```text
203.0.113.100
```

but inside AWS:

```text
app.example.com
```

resolves to:

```text
10.20.5.100
```

This is commonly called:

```text
Split-horizon DNS
or
Split-view DNS
```

You can accomplish this by having:

```text
Public Hosted Zone
example.com

and

Private Hosted Zone
example.com
```

with different records.

Within associated VPCs, the private hosted-zone view can answer the internal name, while Internet DNS uses the public hosted-zone view. AWS supports private hosted zones using domain names that may also exist publicly. ([AWS Documentation][3])

---

# 36.317 Example

Internet:

```text
payments.example.com
       ↓
CloudFront
       ↓
public architecture
```

Internal AWS:

```text
payments.example.com
       ↓
10.20.10.50
       ↓
internal ALB
```

This can be useful for internal/private routing.

But namespace ownership must be intentional because a private hosted zone can change what associated VPCs see for that domain.

---

# 36.318 Private Hosted Zone does not "fall through"

This is a subtle concept.

Suppose PHZ:

```text
example.com
```

exists and is associated with the VPC.

It contains:

```text
app.example.com
```

but does **not** contain:

```text
missing.example.com
```

You should not simply assume Resolver will query the public Internet version of `missing.example.com`.

AWS documents that if an applicable private hosted zone exists but there is no matching record/type, Resolver returns `NXDOMAIN` rather than automatically falling through to public DNS. ([AWS Documentation][13])

Very important.

---

# 36.319 Multi-account problem

Our AWS Organization might be:

```text
Network Account
Security Account
Shared Services Account
Prod Account
Dev Account
QA Account
Analytics Account
```

Do we create separate outbound Resolver endpoints in every VPC?

Usually we should first consider a centralized Shared Services architecture.

AWS Prescriptive Guidance documents central inbound/outbound Resolver endpoints in a Shared Services VPC for multi-account hybrid DNS. ([AWS Documentation][7])

Architecture:

```text
                         ON-PREM DNS
                       10.10.1.53/.54
                              │
                            TGW
                              │
                              ▼
                    SHARED SERVICES VPC

               ┌────────────────────────┐
               │ Route 53 VPC Resolver  │
               │                        │
               │ Inbound      Outbound  │
               └──────────┬─────────────┘
                          │
                          │ Resolver rules
                          │
                    AWS Organization
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
            PROD         DEV          QA
```

---

# 36.320 Sharing Resolver rules using AWS RAM

Suppose the Shared Services account owns:

```text
corp.internal
    ↓
10.10.1.53
10.10.1.54
```

forwarding rule.

Rather than recreating that rule in:

```text
Prod
Dev
QA
Analytics
```

it can be shared using:

# AWS Resource Access Manager — RAM.

AWS RAM supports sharing Route 53 Resolver rules across AWS accounts/Organizations so other accounts can associate centrally managed rules with their VPCs. ([AWS Documentation][16])

Conceptually:

```text
SHARED SERVICES ACCOUNT

Resolver Rule
corp.internal
      │
    AWS RAM
      │
 ┌────┼────────┐
 ▼    ▼        ▼
Prod Dev    Analytics
```

---

# 36.321 Modern multi-account option — Route 53 Profiles

There's also an important modern capability:

# Route 53 Profiles.

AWS Route 53 Profiles can package DNS configurations including:

```text
Private Hosted Zone associations
Resolver forwarding rules
DNS Firewall rule groups
```

into a centrally managed profile that can be shared with accounts through AWS RAM and associated with VPCs. ([AWS Documentation][7])

This is very useful for large organizations.

Instead of thinking:

```text
"Associate 20 different DNS things manually
with 100 VPCs."
```

you can increasingly think:

```text
Corporate DNS Profile
       │
       ├── PHZ associations
       ├── Resolver rules
       ├── Firewall policy
       │
       └── share
             ↓
          many VPCs
```

---

# 36.322 Old/basic vs Profile-based mental model

### Traditional/basic approach

```text
Resolver Rules
    │
AWS RAM
    │
VPC associations

+

PHZ associations

+

DNS Firewall associations
```

### Route 53 Profiles approach

```text
Route 53 Profile
      │
      ├── Resolver rules
      ├── PHZ
      └── DNS Firewall
      │
      ↓
shared/associated with VPCs
```

AWS's current multi-account hybrid DNS guidance describes both the direct sharing model and the newer Route 53 Profiles model. ([AWS Documentation][7])

---

# 36.323 DNS Firewall

Now security asks:

> "Can compromised EC2 instances query arbitrary malicious domains?"

Route 53 provides:

# Resolver DNS Firewall.

DNS Firewall can allow, block, or alert on DNS queries according to configured domain/rule policies for VPC Resolver traffic. AWS explicitly describes it as a way to control outbound DNS and reduce risks such as DNS-based data exfiltration. ([AWS Documentation][17])

Conceptually:

```text
Application
    │
    ▼
VPC Resolver
    │
    ▼
DNS Firewall
    │
    ├── good.example → ALLOW
    │
    ├── malware.xyz  → BLOCK
    │
    └── suspicious   → ALERT
```

---

# 36.324 DNS exfiltration

Attackers sometimes abuse DNS because DNS is widely allowed.

Conceptually:

```text
stolen-data-abc123.attacker.example
```

could encode information into DNS query names.

If unrestricted DNS leaves your environment:

```text
compromised server
     ↓
DNS
     ↓
attacker-controlled authoritative DNS
```

data can potentially be leaked through DNS.

Resolver DNS Firewall exists partly to help enforce domain controls around these patterns. ([AWS Documentation][18])

---

# 36.325 Network Firewall vs DNS Firewall

Do not confuse them.

### AWS Network Firewall

Primarily:

```text
network/application traffic inspection
```

### Route 53 Resolver DNS Firewall

Primarily:

```text
DNS query filtering through VPC Resolver
```

AWS notes that Network Firewall does not have visibility into queries made through VPC Resolver in the same way Resolver DNS Firewall does, making DNS Firewall the purpose-built DNS control. ([AWS Documentation][19])

---

# 36.326 Hybrid DNS centralized architecture

Now let's combine everything:

```text
                          CORPORATE DATA CENTER

                     Active Directory / DNS
                     10.10.1.53
                     10.10.1.54
                            │
                    Conditional Forward
                            │
                 aws.internal → AWS
                            │
                            ▼
                       DX / VPN
                            │
                            ▼
                           TGW
                            │
                            ▼
                ┌────────────────────────┐
                │  SHARED SERVICES VPC   │
                │                        │
                │  Resolver Subnet A/B   │
                │                        │
                │  INBOUND ENDPOINT      │
                │  OUTBOUND ENDPOINT     │
                │                        │
                │  Private Hosted Zones  │
                │  Resolver Rules        │
                │  DNS Firewall          │
                └───────────┬────────────┘
                            │
                     Route 53 Profile /
                         AWS RAM
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
         PROD VPC         DEV VPC        QA VPC
        10.20/16         10.30/16       10.60/16
```

This is the sort of enterprise centralized hybrid-DNS pattern AWS documents for multi-account environments. ([AWS Documentation][7])

---

# 36.327 DNS query flow — Prod → corporate AD

Application:

```text
prod-api
10.20.5.50
```

needs:

```text
ldap.corp.internal
```

Flow:

```text
10.20.5.50
    │
    ▼
VPC Resolver
10.20.0.2
    │
    │ Resolver rule:
    │ corp.internal
    ▼
Shared outbound endpoint
    │
    ▼
TGW
    │
    ▼
Direct Connect
    │
    ▼
Corporate DNS
10.10.1.53
    │
    ▼
ldap.corp.internal
=
10.10.10.25
```

Then the application opens the actual connection:

```text
10.20.5.50
      ↓
10.10.10.25
```

DNS and application traffic are separate flows.

---

# 36.328 DNS query flow — corporate laptop → AWS private service

Corporate laptop:

```text
10.10.20.50
```

needs:

```text
jenkins.aws.internal
```

Flow:

```text
Corporate Laptop
      │
      ▼
Corporate DNS
10.10.1.53
      │
conditional forward:
aws.internal
      │
      ▼
AWS inbound endpoint
10.40.10.10 / 10.40.20.10
      │
      ▼
VPC Resolver
      │
      ▼
Private Hosted Zone
aws.internal
      │
      ▼
jenkins.aws.internal
=
10.40.5.25
```

Then the laptop connects through hybrid routing to:

```text
10.40.5.25
```

That's full hybrid name resolution.

---

# 36.329 DNS and TGW segmentation

Suppose Dev isn't allowed to reach on-prem applications.

But perhaps Dev still needs to resolve:

```text
artifact.corp.internal
```

Network/security policy must match DNS policy.

Otherwise:

```text
DNS resolves successfully

artifact.corp.internal
→ 10.10.50.100

BUT

TGW blackholes Dev → on-prem
```

Result:

```text
DNS works
application fails.
```

That's not a DNS failure.

This is why our troubleshooting layers remain:

```text
DNS
 ↓
Route
 ↓
Firewall
 ↓
Application
```

---

# 36.330 Reverse DNS

Normal lookup:

```text
oracle.corp.internal
      ↓
10.10.50.20
```

is:

# Forward DNS.

Reverse DNS asks:

```text
10.10.50.20
      ↓
what hostname?
```

using reverse zones like:

```text
in-addr.arpa
```

Route 53 Resolver has special/system behavior for reverse-DNS namespaces and supports forwarding rules for reverse lookups where required. ([AWS Documentation][15])

This matters for:

```text
Active Directory
logging
Kerberos-related environments
security tools
mail systems
legacy enterprise software
```

where PTR lookups may matter.

---

# 36.331 DNS caching

Another troubleshooting trap:

You change:

```text
oracle-prod.corp.internal

10.10.50.20
      ↓
10.10.50.30
```

but clients continue using:

```text
10.10.50.20
```

Why?

Possibly:

```text
DNS caching
+
TTL
```

at:

```text
application
OS resolver
local DNS server
recursive resolver
```

Always distinguish:

```text
authoritative record is correct
```

from:

```text
client is still using cached old answer.
```

---

# 36.332 Resolver endpoint high availability

For production:

```text
Inbound:

AZ-A endpoint IP
AZ-B endpoint IP


Outbound:

AZ-A endpoint IP
AZ-B endpoint IP
```

AWS recommends at least two endpoint IPs in separate Availability Zones for resilience, and you can add more endpoint IPs if additional query-processing capacity is needed. ([AWS Documentation][10])

Also configure on-premises DNS to know **both inbound IPs**, not just one.

Bad:

```text
aws.internal
→ 10.40.10.10 only
```

Better:

```text
aws.internal
→ 10.40.10.10
→ 10.40.20.10
```

---

# 36.333 Resolver endpoints cost money

One practical architecture point: Resolver endpoint pricing includes endpoint IP-hour usage plus DNS queries processed, so creating endpoint pairs independently in dozens of VPCs can add both management complexity and cost. AWS specifically describes pricing around endpoint IP addresses and processed queries. ([AWS Documentation][20])

That's another reason centralized hybrid Resolver endpoints are attractive in large environments.

---

# 36.334 Query logging

In production, DNS troubleshooting without logs can be painful.

Route 53 Resolver supports query logging configurations, and AWS RAM also supports centrally sharing query-logging configurations with other accounts. ([AWS Documentation][21])

You want visibility into questions such as:

```text
Which hostname was queried?

Which VPC generated it?

Was the domain blocked?

Was NXDOMAIN returned?

Are applications querying unexpected domains?

Did query volume spike?
```

This becomes useful for:

```text
operations
security monitoring
incident investigation
DNS migration
```

---

# 36.335 Production troubleshooting framework

Someone says:

> `api.prod` cannot connect to `oracle-prod.corp.internal`.

Do this:

```text
1. Does hostname resolve?
              │
       ┌──────┴──────┐
       │             │
      NO            YES
       │             │
       ▼             ▼
 DNS path          Network path
       │             │
       ▼             ▼
Resolver rule?    Route?
Endpoint?         TGW?
SG?               Firewall?
Corporate DNS?    App port?
```

This first split saves enormous time.

---

# 36.336 DNS troubleshooting commands

From Linux:

```bash
dig oracle-prod.corp.internal
```

More detail:

```bash
dig oracle-prod.corp.internal A
```

Check a specific DNS server:

```bash
dig @10.10.1.53 oracle-prod.corp.internal
```

Test inbound AWS endpoint from on-prem:

```bash
dig @10.40.10.10 payments.prod.aws.internal
```

Check resolver config:

```bash
cat /etc/resolv.conf
```

With systemd-resolved:

```bash
resolvectl status
```

Test basic name resolution:

```bash
getent hosts oracle-prod.corp.internal
```

These tools let us separate:

```text
DNS server unreachable

from

DNS server reachable but no record

from

wrong answer
```

---

# 36.337 Important `dig` differences

Suppose:

```bash
dig oracle-prod.corp.internal
```

returns:

```text
;; connection timed out
```

Think:

```text
DNS transport/network problem
```

But:

```text
status: NXDOMAIN
```

means:

```text
DNS server answered

but says name does not exist.
```

And:

```text
SERVFAIL
```

usually means:

```text
resolver encountered failure
while trying to resolve the query.
```

These statuses lead you in different troubleshooting directions.

---

# 36.338 Terraform preview — inbound endpoint

Later we'll build the full lab, but begin recognizing resources.

```hcl
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "hybrid-inbound"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.resolver_inbound.id
  ]

  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }

  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
}
```

This represents the AWS side where on-premises DNS queries enter.

---

# 36.339 Terraform preview — outbound endpoint

```hcl
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "hybrid-outbound"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.resolver_outbound.id
  ]

  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }

  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
}
```

---

# 36.340 Terraform preview — forwarding rule

Conceptually:

```hcl
resource "aws_route53_resolver_rule" "corp" {
  domain_name          = "corp.internal"
  name                 = "corp-internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = "10.10.1.53"
  }

  target_ip {
    ip = "10.10.1.54"
  }
}
```

Then:

```hcl
resource "aws_route53_resolver_rule_association" "prod" {
  resolver_rule_id = aws_route53_resolver_rule.corp.id
  vpc_id           = aws_vpc.prod.id
}
```

This corresponds directly to AWS's model: a forwarding rule identifies a domain and target resolvers, and it must be associated with a VPC before that VPC uses it. ([AWS Documentation][9])

---

# 36.341 Terraform preview — Private Hosted Zone

```hcl
resource "aws_route53_zone" "aws_internal" {
  name = "aws.internal"

  vpc {
    vpc_id = aws_vpc.shared.id
  }
}
```

Then:

```hcl
resource "aws_route53_record" "jenkins" {
  zone_id = aws_route53_zone.aws_internal.zone_id
  name    = "jenkins.aws.internal"
  type    = "A"
  ttl     = 60

  records = ["10.40.5.25"]
}
```

Later we'll structure this through modules instead of keeping everything in one Terraform file.

---

# 36.342 Full enterprise hybrid architecture so far

We have now reached:

```text
                          CORPORATE DATA CENTER

                  ┌───────────────────────────┐
                  │                           │
              Router A                   Router B
                  │                           │
                 DX-A                        DX-B
                  │                           │
                  └───────────┬───────────────┘
                              │
                             DXGW
                              │
                              ▼
                        TRANSIT GATEWAY
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
          PROD VPC         DEV VPC       SHARED SERVICES
          10.20/16         10.30/16          10.40/16
             │                │                │
            ECS              EKS       ┌──────┴──────┐
             │                │        │             │
            RDS               │     Resolver      AD/Tools
                              │     Endpoints
                              │       │    │
                              │      IN    OUT
                              │       │    │
                              └───────┼────┘
                                      │
                                      ▼
                               CORPORATE DNS
                              10.10.1.53/.54

Backup connectivity:
Site-to-Site VPN → TGW
```

And now:

```text
Routing ✓
Encryption ✓
Redundancy ✓
Segmentation ✓
Hybrid DNS ✓
```

We're getting very close to the complete enterprise architecture.

---

# 36.343 Never-forget Route 53 Resolver table

| Concept                    | Meaning                                              |
| -------------------------- | ---------------------------------------------------- |
| **VPC Resolver**           | AWS recursive DNS service available inside VPCs      |
| **VPC + 2**                | Common IPv4 address for the VPC Resolver             |
| **PHZ**                    | Private Hosted Zone                                  |
| **Inbound endpoint**       | On-Prem → AWS DNS                                    |
| **Outbound endpoint**      | AWS → On-Prem DNS                                    |
| **Resolver rule**          | Namespace forwarding policy                          |
| **Target IP**              | DNS server receiving forwarded queries               |
| **Conditional forwarding** | Forward one namespace to designated DNS servers      |
| **AWS RAM**                | Share Resolver rules/configurations across accounts  |
| **Route 53 Profiles**      | Bundle/share multiple VPC DNS configurations         |
| **DNS Firewall**           | Filter/alert/block VPC Resolver DNS queries          |
| **Split-horizon DNS**      | Same name can have different internal/public answers |
| **NXDOMAIN**               | DNS says name does not exist                         |
| **SERVFAIL**               | Resolver failed processing/resolving query           |
| **Forward DNS**            | Name → IP                                            |
| **Reverse DNS**            | IP → name                                            |

---

# 36.344 The four DNS questions

Whenever DNS breaks, ask:

```text
QUESTION 1

Who is authoritative
for this namespace?

             ↓

QUESTION 2

Which DNS resolver
did the client ask?

             ↓

QUESTION 3

Which forwarding rule
matched the query?

             ↓

QUESTION 4

Can the forwarding path
reach the authoritative server?
```

If you answer those four correctly, most hybrid-DNS problems become much easier.

---

# 36.345 Never-forget traffic diagram

```text
AWS → ON-PREM DNS
─────────────────

EC2
 │
 ▼
VPC Resolver
 │
Resolver Rule
 │
 ▼
OUTBOUND ENDPOINT
 │
 ▼
TGW
 │
DX / VPN
 │
 ▼
CORPORATE DNS


ON-PREM → AWS DNS
─────────────────

Corporate Client
 │
 ▼
Corporate DNS
 │
Conditional Forwarder
 │
 ▼
DX / VPN
 │
TGW
 │
 ▼
INBOUND ENDPOINT
 │
 ▼
VPC Resolver
 │
 ▼
PRIVATE HOSTED ZONE
```

That's the core of hybrid DNS.

---

# 36.346 One sentence to remember forever

> **Inbound Resolver endpoints let external/private networks ask AWS DNS questions; outbound Resolver endpoints let AWS forward DNS questions to external/private DNS servers.**

Everything else builds around that.

---

# Next — Lesson 36, Part 7

## Multi-Account Enterprise Hybrid Networking Architecture

Next we'll combine all the pieces into a proper AWS Organization:

```text
                      AWS ORGANIZATION

                    NETWORK ACCOUNT
                          │
                          TGW
                       DX / VPN
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
       SECURITY       SHARED SVCS      PROD
        ACCOUNT         ACCOUNT       ACCOUNT
           │              │              │
     Inspection VPC   Resolver VPC    Prod VPC
     Network FW       AD / DNS        ECS / RDS
                          │
                     Route53 Profile
                          │
                       AWS RAM
                          │
                ┌─────────┼─────────┐
                ▼         ▼         ▼
               DEV       QA      ANALYTICS
```

We'll go deep into **network account ownership, shared-services account, security account, TGW sharing using AWS RAM, centralized ingress/egress, centralized inspection, DNS Profiles, multi-account PHZ strategy, SCP/network governance, CIDR allocation/IPAM, environment segmentation, cross-account route propagation, blast-radius control, regional design, and the final production reference architecture**.

After that we'll do **Terraform implementation + actual troubleshooting lab + full Lesson 36 capstone**, where we'll assemble the entire on-prem ↔ VPN/DX ↔ TGW ↔ firewall ↔ multiple VPCs ↔ hybrid DNS architecture ourselves.

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[2]: https://docs.aws.amazon.com/vpc/latest/userguide/AmazonDNS-concepts.html?utm_source=chatgpt.com "Understanding Amazon DNS - Amazon Virtual Private Cloud"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-associate-vpcs.html?utm_source=chatgpt.com "Associating more VPCs with a private hosted zone"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-inbound-queries.html?utm_source=chatgpt.com "Forwarding inbound DNS queries to your VPCs"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-DSN-queries-to-vpc.html?utm_source=chatgpt.com "Resolving DNS queries between VPCs and your network"
[7]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/set-up-dns-resolution-for-hybrid-networks-in-a-multi-account-aws-environment.html?utm_source=chatgpt.com "Set up DNS resolution for hybrid networks in a multi- ..."
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-outbound-queries.html?utm_source=chatgpt.com "Forwarding outbound DNS queries to your network"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-rules-managing.html?utm_source=chatgpt.com "Managing forwarding rules - Amazon Route 53"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-resolver-endpoint-high-availability.html?utm_source=chatgpt.com "High availability for Resolver endpoints - Amazon Route 53"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-forward-vpc-to-network.html?utm_source=chatgpt.com "How Resolver endpoints forward DNS queries from your ..."
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-resolver-endpoint-scaling.html?utm_source=chatgpt.com "Resolver endpoint scaling - Amazon Route 53"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html?utm_source=chatgpt.com "Considerations when working with a private hosted zone"
[14]: https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Route53Resolver.html?utm_source=chatgpt.com "Class: AWS.Route53Resolver — AWS SDK for JavaScript"
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-forward-vpc-to-network-autodefined-rules.html?utm_source=chatgpt.com "Domain names that VPC Resolver creates autodefined ..."
[16]: https://docs.aws.amazon.com/ram/latest/userguide/shareable.html?utm_source=chatgpt.com "Shareable AWS resources - AWS Resource Access Manager"
[17]: https://docs.aws.amazon.com/vpc/latest/userguide/resolver-dns-firewall.html?utm_source=chatgpt.com "Filter DNS traffic using Route 53 Resolver DNS Firewall"
[18]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/dns.html?utm_source=chatgpt.com "DNS - Building a Scalable and Secure Multi-VPC ..."
[19]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall.html?utm_source=chatgpt.com "Using DNS Firewall to filter outbound DNS traffic"
[20]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-choose-vpc.html?utm_source=chatgpt.com "Considerations when creating inbound and outbound ..."
[21]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/query-logging-configurations-managing-sharing.html?utm_source=chatgpt.com "Sharing Resolver query logging configurations with other ..."
