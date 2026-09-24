## How much of the AWS Production Architecture module is left?

We are well into it now. My **working roadmap is about 9 major lessons after Route 53**, with several lessons split into multiple parts because you asked for production-level depth.

```text
CURRENT
──────────────────────────────────────────
Lesson 29  Route 53 & DNS              ← NOW

STILL TO COME
──────────────────────────────────────────
Lesson 30  AWS IAM & Enterprise Security Architecture
Lesson 31  KMS, Secrets, Certificates & Security Services
Lesson 32  Lambda, API Gateway & Serverless Architecture
Lesson 33  SQS, SNS, EventBridge, Step Functions & Event-Driven AWS
Lesson 34  ECS, Fargate & Production Container Architecture
Lesson 35  CloudWatch, CloudTrail, Config, Systems Manager & AWS Operations
Lesson 36  Hybrid Cloud, VPN, Direct Connect & Enterprise Networking
Lesson 37  AWS Migration, DMS, MGN, DataSync, Storage Gateway & Transfer
Lesson 38  Multi-Account, DR, Well-Architected + AWS Production Capstone
```

So roughly:

```text
Route 53 remaining
+
9 major lessons
=
AWS Production Architecture complete
```

After that we move into the next approved masterclass module:

```text
Module 14
GitOps with ArgoCD
```

I won't rush these remaining lessons. We'll keep the same beginner → intermediate → advanced → production → troubleshooting → certification style.

---

# AWS Masterclass — Lesson 29 Part 3

# Private DNS, Route 53 VPC Resolver & Hybrid DNS Architecture

Part 1 taught:

```text
Internet DNS
```

Part 2 taught:

```text
DNS traffic management
```

Now Part 3 answers:

> How does DNS work **inside a VPC**, between VPCs, and between AWS and an on-premises data center?

This is where DNS becomes real enterprise networking.

---

# 1. Public DNS Is Not Enough

Imagine your production application:

```text
Internet
   │
   ▼
CloudFront
   │
   ▼
ALB
   │
   ▼
Application
   │
   ▼
Database
```

Externally, users might resolve:

```text
api.example.com
```

But internally, applications may need names such as:

```text
orders.internal.example.com

payments.internal.example.com

database.internal.example.com

jenkins.internal.example.com

vault.internal.example.com
```

You don't want these published to normal internet DNS.

Instead:

```text
                 AWS VPC

EC2 ────────────────┐
ECS ────────────────┤
Lambda VPC ─────────┤
                    ▼
             Route 53 VPC Resolver
                    │
                    ▼
              Private Hosted Zone
                    │
                    ▼
         service.internal.example.com
                    │
                    ▼
                 10.x.x.x
```

A Route 53 private hosted zone stores DNS information that is resolvable inside associated VPCs rather than through normal public internet DNS. ([AWS Documentation][1])

---

# 2. Private Hosted Zone Mental Model

A:

# Private Hosted Zone

means approximately:

```text
DNS namespace
visible to selected VPCs
```

Example:

```text
Hosted zone:

internal.yourdatascientist.tech
```

Records:

```text
api.internal.yourdatascientist.tech
      ↓
10.24.11.50

jenkins.internal.yourdatascientist.tech
      ↓
10.24.12.20

database.internal.yourdatascientist.tech
      ↓
private DB endpoint
```

Only associated VPCs—and properly connected hybrid networks using Resolver endpoints—can resolve that private namespace through Route 53 VPC Resolver. ([AWS Documentation][1])

---

# 3. Public Hosted Zone vs Private Hosted Zone

Imagine both exist:

```text
PUBLIC HOSTED ZONE
example.com

PRIVATE HOSTED ZONE
example.com
```

Internet:

```text
www.example.com
      │
      ▼
203.x.x.x
```

Inside your VPC:

```text
www.example.com
      │
      ▼
10.0.20.15
```

That is possible.

AWS calls this:

# Split-view / split-horizon DNS

Route 53 supports public and private hosted zones with the same domain name, allowing different answers depending on where the DNS request originates. ([AWS Documentation][2])

---

# 4. Split-Horizon Example

Outside AWS:

```text
Employee laptop
     │
     ▼
www.example.com
     │
     ▼
PUBLIC DNS
     │
     ▼
CloudFront
```

Inside production VPC:

```text
EC2
 │
 ▼
www.example.com
 │
 ▼
PRIVATE DNS
 │
 ▼
Internal ALB
```

Diagram:

```text
                     www.example.com
                           │
              ┌────────────┴────────────┐
              │                         │
       Internet request             VPC request
              │                         │
              ▼                         ▼
        Public Hosted Zone       Private Hosted Zone
              │                         │
              ▼                         ▼
          CloudFront                Internal ALB
```

Same DNS name.

Different answer.

---

# 5. Who Resolves DNS Inside a VPC?

AWS provides a DNS resolver inside every VPC environment:

# Route 53 VPC Resolver

It has also historically been called:

```text
Amazon DNS server
AmazonProvidedDNS
Route 53 Resolver
```

AWS currently documents it at these addresses:

```text
169.254.169.253
```

and:

```text
VPC primary IPv4 CIDR + 2
```

For example:

```text
VPC:
10.24.0.0/16

Resolver:
10.24.0.2
```

IPv6 environments can also use:

```text
fd00:ec2::253
```

AWS describes the Resolver as built into every Availability Zone and reachable through these addresses. ([AWS Documentation][3])

---

# 6. Why `VPC + 2`?

Example:

```text
VPC CIDR

10.24.0.0/16
```

Then:

```text
10.24.0.2
```

represents the Route 53 Resolver address for that VPC.

Thus:

```text
EC2
 │
 │ DNS query
 ▼
10.24.0.2
 │
 ▼
Route 53 VPC Resolver
```

The application usually doesn't manually configure:

```text
nameserver 10.24.0.2
```

itself.

AWS DHCP/DNS configuration normally gives workloads the expected VPC DNS behavior.

---

# 7. What Can VPC Resolver Resolve?

Think:

```text
                      VPC Resolver
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
       Public DNS      Private Zone      AWS/VPC names
```

For example:

```text
google.com
```

can be recursively resolved publicly.

```text
db.internal.example.com
```

can come from your private hosted zone.

And AWS-generated DNS names can also be resolved according to VPC configuration. ([AWS Documentation][3])

---

# 8. Two Important VPC DNS Attributes

For private hosted zones, you should know:

```text
enableDnsSupport
```

and:

```text
enableDnsHostnames
```

AWS specifically requires both to be set to `true` for the VPC when using Route 53 private hosted zones as expected. ([AWS Documentation][4])

Mental model:

```text
enableDnsSupport
=
Can VPC resources use AWS DNS resolution?
```

```text
enableDnsHostnames
=
Can relevant EC2 resources receive AWS DNS hostnames?
```

These are easy Terraform settings to overlook.

---

# 9. Terraform VPC DNS Baseline

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.24.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "production-vpc"
  }
}
```

For a normal production AWS VPC, these settings should immediately make sense because private DNS and AWS hostname resolution depend on the VPC DNS configuration. ([AWS Documentation][4])

---

# 10. Creating a Private Hosted Zone

Suppose:

```text
internal.yourdatascientist.tech
```

should exist only internally.

Terraform:

```hcl
resource "aws_route53_zone" "internal" {
  name = "internal.yourdatascientist.tech"

  vpc {
    vpc_id = aws_vpc.main.id
  }
}
```

Now:

```text
Route 53 Private Hosted Zone
             │
             ▼
associated with production VPC
```

Only associated VPCs—or clients reaching Route 53 through the appropriate hybrid Resolver path—can use that private namespace. ([AWS Documentation][1])

---

# 11. Add an Internal Application Record

Suppose an internal ALB fronts the application.

```hcl
resource "aws_route53_record" "internal_api" {
  zone_id = aws_route53_zone.internal.zone_id

  name = "api.internal.yourdatascientist.tech"
  type = "A"

  alias {
    name                   = aws_lb.internal.dns_name
    zone_id                = aws_lb.internal.zone_id
    evaluate_target_health = true
  }
}
```

Architecture:

```text
EC2
 │
 ▼
api.internal.yourdatascientist.tech
 │
 ▼
Route 53 VPC Resolver
 │
 ▼
Private Hosted Zone
 │
 ▼
Internal ALB
```

No public internet DNS record is required.

---

# 12. One Private Hosted Zone Can Serve Multiple VPCs

Suppose:

```text
Production VPC
Development VPC
Shared Services VPC
```

all need:

```text
internal.example.com
```

You can associate multiple VPCs with the private hosted zone. ([AWS Documentation][5])

Architecture:

```text
                   Private Hosted Zone
                   internal.example.com
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
          Prod VPC      Dev VPC    Shared Services VPC
```

This can provide consistent internal naming across environments.

---

# 13. But DNS Resolution Does Not Create Network Connectivity

Very important.

Suppose:

```text
VPC-A can resolve:

db.internal.example.com
→ 10.50.1.20
```

Does that mean VPC-A can connect to:

```text
10.50.1.20:5432
```

?

Not necessarily.

You still need:

```text
VPC Peering
Transit Gateway
PrivateLink
VPN
Direct Connect
routing
security groups
NACLs
```

as appropriate.

Never forget:

```text
DNS
=
Where?

Routing/security
=
Can I reach it?
```

---

# 14. DNS Success but Connection Failure

Example:

```bash
dig api.internal.example.com
```

returns:

```text
10.50.11.20
```

but:

```bash
curl https://api.internal.example.com
```

times out.

Then:

```text
DNS
=
WORKING
```

Move to:

```text
route table
SG
NACL
TGW/peering
application listener
```

Do not keep modifying Route 53.

This layering habit will save you huge amounts of debugging time.

---

# 15. The Hybrid DNS Problem

Now introduce an on-premises data center.

```text
On-Premises

Active Directory
DNS Server
Database
Legacy Apps
```

and:

```text
AWS

VPC
EC2
ECS
RDS
Private Hosted Zones
```

We need both directions:

```text
ON-PREM
   │
   ▼
resolve AWS private names
```

and:

```text
AWS
 │
 ▼
resolve on-premises names
```

Architecture:

```text
              HYBRID DNS

 On-Premises                    AWS
 ─────────────────────────────────────────

 Corporate DNS              Route 53 VPC Resolver
      │                           │
      │                           │
      └──── VPN / Direct Connect ─┘
```

Native VPC DNS itself isn't something on-premises hosts simply query directly over VPN/DX; Route 53 Resolver endpoints provide the supported hybrid DNS bridge. ([AWS Documentation][6])

---

# 16. Two Resolver Endpoint Directions

This is one of the most important Route 53 topics.

There are:

```text
INBOUND Resolver Endpoint
```

and:

```text
OUTBOUND Resolver Endpoint
```

Memory trick:

```text
INBOUND
=
DNS query comes INTO AWS
```

```text
OUTBOUND
=
DNS query goes OUT OF AWS
```

AWS describes inbound endpoints as accepting DNS queries into VPC Resolver from your network or another VPC, and outbound endpoints as forwarding VPC-originated DNS queries toward your network or another DNS environment. ([AWS Documentation][7])

---

# 17. Inbound Resolver Endpoint

Requirement:

> On-premises machines need to resolve AWS private names.

Example:

```text
On-prem laptop
      │
      ▼
db.internal.example.com
```

Private record exists only in AWS.

Architecture:

```text
On-Premises Client
       │
       ▼
Corporate DNS
       │
 conditional forward
       ▼
VPN / Direct Connect
       │
       ▼
Route 53 INBOUND Endpoint
       │
       ▼
Route 53 VPC Resolver
       │
       ▼
Private Hosted Zone
       │
       ▼
db.internal.example.com
       │
       ▼
10.24.21.50
```

AWS documents this as the standard inbound Resolver flow for hybrid DNS. ([AWS Documentation][8])

---

# 18. Why We Need an Inbound Endpoint

You might ask:

> Why doesn't the on-prem DNS server query `10.24.0.2` directly through VPN?

Because the native VPC Resolver address isn't the supported on-premises access mechanism.

Instead, create:

```text
Inbound Resolver Endpoint
```

with actual private IP addresses in subnets.

Example:

```text
10.24.11.53
10.24.12.53
```

On-premises DNS forwards queries there.

AWS creates endpoint network interfaces for the configured inbound IP addresses. ([AWS Documentation][9])

---

# 19. Highly Available Inbound Endpoint

Production design:

```text
             AWS VPC

      AZ-A                 AZ-B
       │                    │
10.24.11.53           10.24.12.53
       │                    │
       └──── Inbound Endpoint ────┘
```

AWS requires Resolver endpoints to use at least two IP addresses, and recommends placing endpoint IPs in different Availability Zones for resilient DNS resolution. ([AWS Documentation][10])

Your on-premises DNS might configure:

```text
internal.example.com

forward to:
10.24.11.53
10.24.12.53
```

---

# 20. Security Group for Inbound Endpoint

DNS normally uses:

```text
UDP 53
```

but also:

```text
TCP 53
```

for cases such as larger DNS responses and retry behavior.

Therefore the inbound Resolver endpoint's security group should allow:

```text
UDP 53
TCP 53
```

from trusted DNS resolvers/network CIDRs. AWS explicitly requires TCP and UDP port 53 access for standard inbound endpoints; DNS-over-HTTPS configurations additionally involve port 443. ([AWS Documentation][11])

Example:

```text
Source:
10.200.10.10/32
10.200.10.11/32

UDP 53
TCP 53
```

not:

```text
0.0.0.0/0
all ports
```

---

# 21. Outbound Resolver Endpoint

Now solve the opposite direction.

AWS application needs:

```text
sql01.corp.example.com
```

But that domain is hosted by:

```text
on-premises Active Directory DNS
```

Architecture:

```text
EC2
 │
 ▼
sql01.corp.example.com
 │
 ▼
Route 53 VPC Resolver
 │
 ▼
Resolver Rule
corp.example.com
 │
 ▼
OUTBOUND Resolver Endpoint
 │
 ▼
VPN / Direct Connect
 │
 ▼
On-Premises DNS
 │
 ▼
10.200.30.40
```

AWS documents outbound Resolver endpoints plus forwarding rules as the standard VPC-to-on-premises DNS flow. ([AWS Documentation][7])

---

# 22. Outbound Endpoint Alone Isn't Enough

Creating:

```text
Outbound Resolver Endpoint
```

does not tell AWS:

```text
which domains
should use that endpoint.
```

You also create:

# Resolver Rules

Example:

```text
Domain:
corp.example.com

Action:
FORWARD

Target DNS servers:
10.200.1.53
10.200.2.53

Outbound Endpoint:
hybrid-outbound
```

Resolver forwarding rules specify the domain to forward and the destination DNS server addresses. They must be associated with the VPCs that should use them. ([AWS Documentation][12])

---

# 23. Conditional DNS Forwarding

This is one of the most important enterprise DNS concepts.

Rather than saying:

```text
Send ALL DNS to on-prem
```

say:

```text
corp.example.com
→ on-prem DNS
```

while:

```text
amazonaws.com
google.com
internal.aws.example.com
```

continue using the appropriate Route 53 resolution behavior.

Architecture:

```text
                     EC2 DNS Query
                           │
                           ▼
                  Route 53 VPC Resolver
                           │
             ┌─────────────┼──────────────┐
             │             │              │
corp.example.com      AWS private       public DNS
             │          hosted zone        │
             ▼             │              ▼
Resolver Rule             Route53        Internet
             │
             ▼
Outbound Endpoint
             │
             ▼
On-Prem DNS
```

This is called conditional forwarding because forwarding depends on the queried DNS suffix.

---

# 24. Example Hybrid Domains

Suppose:

```text
AWS domain:

aws.example.com
```

and:

```text
On-prem domain:

corp.example.com
```

On-prem DNS configuration:

```text
aws.example.com
    │
    ▼
forward to AWS inbound endpoint
```

AWS Resolver configuration:

```text
corp.example.com
    │
    ▼
forward via AWS outbound endpoint
```

Result:

```text
               BIDIRECTIONAL DNS

On-prem app                       AWS app

db.aws.example.com          sql.corp.example.com
        │                            │
        ▼                            ▼
 AWS inbound                  AWS outbound
```

This is the basic hybrid DNS pattern AWS documents for connected environments. ([AWS Documentation][7])

---

# 25. Connectivity Still Required

Resolver endpoints use private IP addresses.

Therefore:

```text
On-Premises
   │
   ▼
AWS Inbound Endpoint
```

needs network connectivity such as:

```text
AWS Site-to-Site VPN
```

or:

```text
AWS Direct Connect
```

AWS explicitly describes Direct Connect or Site-to-Site VPN as connectivity options for hybrid Resolver endpoint traffic. ([AWS Documentation][8])

We'll cover both deeply in Lesson 36.

---

# 26. Outbound Resolver Security Group

For outbound endpoints, traffic leaves the endpoint toward your DNS servers.

You normally need:

```text
Outbound:

UDP 53
TCP 53

Destination:
on-prem DNS server(s)
```

AWS documents outbound endpoint security groups as requiring egress for the DNS protocol/port used by the destination resolvers. ([AWS Documentation][11])

Example:

```text
10.200.1.53
10.200.2.53
```

rather than open egress toward every destination unnecessarily.

---

# 27. Highly Available Hybrid DNS

Production:

```text
                   AWS VPC

              AZ-A          AZ-B

Inbound      ENI-A          ENI-B

Outbound     ENI-C          ENI-D
```

And on-premises:

```text
DNS-1
DNS-2
```

Connected by:

```text
redundant VPN/DX paths
```

Your DNS architecture should not depend on:

```text
one Resolver IP
one DNS server
one network tunnel
```

because DNS is a dependency for practically everything else.

---

# 28. DNS Dependency Cascade

Imagine:

```text
DNS outage
```

Applications might report:

```text
Database unavailable

API unavailable

AWS service unavailable

Authentication unavailable

Monitoring unavailable
```

even though every destination is actually healthy.

Why?

```text
application
   │
   ▼
can't resolve hostname
   │
   ▼
can't initiate connection
```

This is why DNS belongs near the bottom of your dependency stack.

---

# 29. Resolver Rule Matching

Suppose:

```text
Resolver rule:

example.com
→ DNS-A
```

and another:

```text
internal.example.com
→ DNS-B
```

Query:

```text
db.internal.example.com
```

The more specific matching DNS namespace should drive the decision.

Think:

```text
internal.example.com
```

rather than:

```text
example.com
```

Route 53 Resolver uses domain-rule matching and associated DNS configurations to choose the applicable rule. Route 53 Profiles also use most-specific-name logic when determining applicable DNS settings. ([AWS Documentation][13])

---

# 30. Important Rule-Precedence Trap

Suppose the VPC has:

```text
Private Hosted Zone:

example.com
```

and:

```text
Resolver forwarding rule:

example.com
→ on-prem
```

Which wins?

Current AWS behavior:

# Resolver rule wins.

Queries are forwarded to your network rather than answered from that private hosted zone. ([AWS Documentation][2])

This can create an extremely confusing incident:

```text
Private record exists in Route 53
```

but:

```text
AWS keeps querying on-prem DNS.
```

Always inspect Resolver rules.

---

# 31. Another Private Hosted Zone Trap

Suppose you have:

```text
Private Hosted Zone:

example.com
```

associated with the VPC.

Inside that zone you have:

```text
db.example.com
```

but **not**:

```text
missing.example.com
```

When a VPC client asks for:

```text
missing.example.com
```

Route 53 doesn't simply fall back to public `example.com` for that exact private namespace.

It can return:

```text
NXDOMAIN
```

because the associated private hosted zone owns that namespace for the VPC. AWS documents this behavior explicitly. ([AWS Documentation][2])

### Never forget

```text
Private zone exists
+
record missing
≠
automatically ask public zone
```

This catches many engineers.

---

# 32. Split-Horizon Missing Record Example

Public zone:

```text
example.com

www.example.com
api.example.com
docs.example.com
```

Private zone:

```text
example.com

api.example.com
```

Inside the VPC:

```text
api.example.com
→ private answer
```

But:

```text
docs.example.com
```

can fail if the private `example.com` zone is considered authoritative in that context and no matching private record exists.

A cleaner architecture is often:

```text
Public:

example.com
```

and:

```text
Private:

internal.example.com
```

unless you specifically need identical split-horizon names.

---

# 33. Cross-VPC Private DNS

Suppose:

```text
VPC-A
10.10.0.0/16
```

and:

```text
VPC-B
10.20.0.0/16
```

Both need:

```text
service.internal.example.com
```

Simplest Route 53 approach:

```text
associate both VPCs
with the private hosted zone
```

provided the overall architecture supports those associations.

Then:

```text
                   Private Hosted Zone
                         │
                    ┌────┴────┐
                    ▼         ▼
                  VPC-A     VPC-B
```

The DNS association controls name resolution; the VPC connectivity layer still controls whether the returned destination can actually be reached. ([AWS Documentation][5])

---

# 34. Multi-Account Problem

Real enterprises might have:

```text
Networking Account

Production Account

Development Account

Security Account

Shared Services Account
```

Do you want every team manually building:

```text
Resolver endpoint
DNS firewall
forwarding rule
private zone association
```

in every account?

Usually no.

You centralize DNS architecture.

---

# 35. AWS RAM and Resolver Rules

Resolver rules can be shared across AWS accounts using AWS Resource Access Manager in centralized DNS architectures. AWS's hybrid multi-account guidance describes creating centralized Resolver endpoints/rules in a shared-services/networking account and sharing them with workload accounts. ([AWS Documentation][14])

Architecture:

```text
                 Network Account

             Resolver Endpoints
                    │
              Resolver Rules
                    │
                  AWS RAM
          ┌─────────┼─────────┐
          ▼         ▼         ▼
       Prod Acct  Dev Acct  QA Acct
```

This reduces duplicate hybrid DNS infrastructure.

---

# 36. Modern Route 53 Profiles

A newer enterprise feature you should know is:

# Route 53 Profiles

Profiles allow administrators to group and apply DNS-related configurations such as:

```text
Private hosted zones

Resolver rules

DNS Firewall rule groups

query logging configurations
```

across VPCs more consistently. AWS Profiles integrate with AWS RAM for cross-account sharing. ([AWS Documentation][13])

Conceptually:

```text
             Route 53 Profile
                    │
        ┌───────────┼────────────┐
        ▼           ▼            ▼
   Private zones  Resolver    DNS Firewall
                    rules
        │
        ▼
   Query logging
        │
        ▼
      VPCs
```

This is highly relevant in large multi-account AWS organizations.

---

# 37. Centralized Enterprise DNS Architecture

A good enterprise model might be:

```text
                       AWS ORGANIZATION
                              │
                    Network Services Account
                              │
                    Shared Services VPC
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
          Inbound EP      Outbound EP     DNS Firewall
               │              │
               └──────┬───────┘
                      ▼
                Resolver Rules
                      │
              Route 53 Profiles/RAM
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
      Prod           Dev           Data
      VPCs           VPCs          VPCs
                      │
                Transit Gateway
                      │
                 VPN / Direct Connect
                      │
                      ▼
                On-Premises DNS
```

AWS publishes this centralized/shared-services pattern for hybrid multi-account DNS environments. ([AWS Documentation][14])

---

# 38. Transit Gateway Does Not Automatically Solve DNS

Suppose:

```text
VPC-A
   │
   ▼
Transit Gateway
   │
   ▼
VPC-B
```

Network connectivity exists.

That doesn't automatically mean all private hosted zones and Resolver forwarding behavior are magically shared exactly how you need them.

You still must design:

```text
Private hosted zone associations

Resolver rule associations

Profiles/RAM

endpoint placement
```

The networking plane and DNS control plane remain separate.

---

# 39. Route 53 Resolver Query Logging

You should be able to answer:

> Which DNS names are workloads inside my VPC actually querying?

VPC Resolver Query Logging can record DNS queries originating from associated VPCs. AWS notes that the VPC Resolver caches DNS answers and query logs record **unique queries that reach the Resolver**, not every answer that can be served from cache. ([AWS Documentation][15])

Architecture:

```text
EC2/ECS/Lambda
      │
      ▼
DNS query
      │
      ▼
VPC Resolver
      │
      ├── DNS answer
      │
      └── Query Log
             │
        ┌────┼────┐
        ▼    ▼    ▼
 CloudWatch  S3  Firehose
```

depending on configured destination/support.

---

# 40. Why DNS Query Logs Are Valuable

Security team sees:

```text
api.strange-domain.example

malware-control.example

random-xyz-92384.example
```

being queried from workloads.

DNS logs can help detect:

```text
malware callbacks

misconfigured applications

unexpected external dependencies

DNS exfiltration behavior

wrong internal names
```

They are also extremely helpful for troubleshooting:

```text
"Which DNS name is this application
actually trying to resolve?"
```

---

# 41. Don't Expect Every DNS Request in the Log

Remember Resolver caching:

```text
first query
   │
   ▼
Resolver
   │
   ▼
logs query
   │
   ▼
caches answer


next query
   │
   ▼
Resolver cache
   │
   ▼
answer
```

AWS documents that queries answered from Resolver cache don't appear as new unique Resolver query-log entries. ([AWS Documentation][15])

So:

```text
100,000 application DNS lookups
```

doesn't necessarily mean:

```text
100,000 query-log entries.
```

---

# 42. Route 53 Resolver DNS Firewall

Now imagine malicious software on an EC2 instance tries:

```text
evil-control.example
```

DNS Firewall can inspect DNS queries passing through Route 53 VPC Resolver and apply domain-based filtering rules. AWS DNS Firewall supports allow/block/alert-style controls and advanced protections including DNS tunneling and DGA-related threats. ([AWS Documentation][16])

Architecture:

```text
EC2
 │
 ▼
DNS query
 │
 ▼
Route 53 VPC Resolver
 │
 ▼
DNS Firewall
 │
 ├── allowed?
 │      │
 │      ▼
 │   resolve
 │
 └── blocked?
        │
        X
```

---

# 43. DNS Firewall ≠ Network Firewall

Don't confuse:

```text
Route 53 DNS Firewall
```

with:

```text
AWS Network Firewall
```

DNS Firewall decides:

```text
Should this DNS name resolve?
```

Network Firewall can inspect/control network traffic at the IP/transport/application traffic layer according to its capabilities.

Blocking DNS resolution can reduce access to malicious domains, but it is not a complete replacement for outbound network controls.

---

# 44. DNS Firewall Rule Example

Conceptually:

```text
Rule 100
ALLOW
*.company-approved.example
```

```text
Rule 200
BLOCK
known-malicious-domains
```

```text
Rule 300
ALERT
suspicious-domains
```

AWS recommends testing managed lists/rules in non-production or Alert mode before enforcing them broadly, then moving to blocking once you're confident in behavior. ([AWS Documentation][17])

This is a good security deployment pattern generally:

```text
OBSERVE
   ↓
ALERT
   ↓
VALIDATE
   ↓
BLOCK
```

---

# 45. DNS Firewall Can Break Production

Imagine application needs:

```text
api.vendor.com
```

Security blocks:

```text
*.vendor.com
```

Now:

```text
application
   │
   ▼
DNS failure
   │
   ▼
vendor API unreachable
```

The app might report:

```text
Connection failure
```

even though:

```text
route table = correct
SG = correct
internet/NAT = correct
```

The problem is:

```text
DNS Firewall.
```

Always include it in enterprise DNS troubleshooting.

---

# 46. Hybrid DNS Complete Flow — On-Prem → AWS

Let's walk the packet logically.

User:

```text
workstation.corp
```

needs:

```text
api.aws.example.com
```

Step 1:

```text
Workstation
    │
    ▼
Corporate DNS
```

Step 2:

Corporate DNS sees:

```text
aws.example.com
```

conditional forward rule.

Step 3:

```text
Corporate DNS
    │
    ▼
10.24.11.53
10.24.12.53
```

Route 53 inbound endpoint.

Step 4:

```text
Inbound Endpoint
    │
    ▼
VPC Resolver
```

Step 5:

```text
VPC Resolver
    │
    ▼
Private Hosted Zone
```

Step 6:

```text
api.aws.example.com
→ 10.24.30.20
```

Step 7:

Answer goes back:

```text
Private Hosted Zone
      ↓
Resolver
      ↓
Inbound Endpoint
      ↓
Corporate DNS
      ↓
Workstation
```

AWS's inbound Resolver documentation describes this exact hybrid resolution path. ([AWS Documentation][9])

---

# 47. Hybrid DNS Complete Flow — AWS → On-Prem

EC2 needs:

```text
sql.corp.example.com
```

Step 1:

```text
EC2
 │
 ▼
VPC Resolver
```

Step 2:

Resolver finds:

```text
Forwarding rule:
corp.example.com
```

Step 3:

```text
VPC Resolver
    │
    ▼
Outbound Endpoint
```

Step 4:

```text
Outbound Endpoint
    │
    ▼
VPN / Direct Connect
```

Step 5:

```text
On-Prem DNS
```

answers:

```text
sql.corp.example.com
→ 10.200.30.25
```

Step 6:

answer follows the reverse path back to EC2. ([AWS Documentation][7])

---

# 48. Hybrid DNS Diagram to Burn Into Memory

```text
                 ON-PREMISES
                     │
               Corporate DNS
                     │
        ┌────────────┴────────────┐
        │                         ▲
        │ AWS names               │ On-prem names
        ▼                         │
  VPN / Direct Connect      VPN / Direct Connect
        │                         ▲
        ▼                         │
   INBOUND EP                 OUTBOUND EP
        │                         ▲
        ▼                         │
        └──── Route 53 VPC Resolver ────┐
                     │                   │
             ┌───────┴───────┐           │
             ▼               ▼           │
       Private Hosted      Forwarding ────┘
           Zones             Rules
```

The memory trick remains:

```text
INBOUND
=
on-prem → AWS DNS
```

```text
OUTBOUND
=
AWS → on-prem DNS
```

---

# 49. Newer Delegation Endpoints

Current Route 53 VPC Resolver also includes newer **delegation** capabilities in addition to traditional forwarding.

AWS documents:

```text
default inbound endpoint
```

and:

```text
delegation inbound endpoint
```

for scenarios where DNS authority for a subdomain is delegated toward VPC Resolver rather than merely conditionally forwarded. ([AWS Documentation][18])

For example:

```text
example.com
```

on premises could delegate:

```text
aws.example.com
```

toward Resolver inbound delegation endpoints.

This is more advanced enterprise DNS authority design; you should know it exists, while traditional conditional forwarding remains the first architecture to master.

---

# 50. Internal ALB Architecture

A common internal service:

```text
payments.internal.example.com
```

Architecture:

```text
ECS / EC2
    │
    ▼
payments.internal.example.com
    │
    ▼
Private Hosted Zone
    │
    ▼
Internal ALB
    │
    ▼
Payment Service
```

No public IP required.

No public DNS required.

This is a very common production AWS microservice pattern.

---

# 51. RDS Private DNS

RDS already gives you an AWS DNS endpoint such as:

```text
prod-db.xxxxxx.ap-south-1.rds.amazonaws.com
```

You might choose to have applications use that directly.

Or create an internal abstraction:

```text
postgres.internal.example.com
```

pointing to the appropriate managed DB endpoint where your DNS architecture supports it.

Why abstract?

```text
application config
     │
     ▼
organization-owned DNS name
     │
     ▼
current DB target
```

This can simplify certain migrations.

But remember:

```text
RDS/Aurora native cluster endpoints
already provide important failover semantics.
```

Never accidentally remove those semantics with an incorrectly designed static record.

---

# 52. PrivateLink DNS Connection

When using interface VPC endpoints for AWS services, enabling private DNS can cause standard AWS service names to resolve to private interface-endpoint IPs inside the applicable VPC. AWS documents this using AWS-managed private DNS behavior around interface endpoints. ([AWS Documentation][19])

Conceptually:

Outside:

```text
service.amazonaws.com
      │
      ▼
public AWS endpoint
```

Inside VPC with private DNS endpoint:

```text
service.amazonaws.com
      │
      ▼
private VPC endpoint IP
```

Same familiar AWS hostname.

Different network path.

This is another form of private DNS abstraction.

---

# 53. Common Incident — Works in VPC-A, Fails in VPC-B

Check:

```text
1. Is private hosted zone
   associated with VPC-B?

2. Is appropriate Route 53 Profile
   associated?

3. Is Resolver rule associated?

4. DNS attributes enabled?

5. Does VPC-B have network connectivity
   to the returned IP?

6. Security group?

7. DNS Firewall?

8. Resolver query logs?
```

Don't assume because both VPCs:

```text
belong to same AWS account
```

they automatically see all private DNS namespaces.

---

# 54. Common Incident — AWS Cannot Resolve On-Prem Name

Error:

```text
NXDOMAIN
```

or:

```text
SERVFAIL
```

for:

```text
sql.corp.example.com
```

Check:

```text
Resolver forwarding rule exists?
      │
      ▼
associated with VPC?
      │
      ▼
correct domain suffix?
      │
      ▼
outbound endpoint healthy?
      │
      ▼
SG allows TCP/UDP 53?
      │
      ▼
VPN/DX routing?
      │
      ▼
on-prem firewall?
      │
      ▼
on-prem DNS answering?
```

That is the correct troubleshooting order for the AWS→on-prem DNS path. ([AWS Documentation][12])

---

# 55. Common Incident — On-Prem Cannot Resolve AWS Name

Check:

```text
On-prem conditional forwarder?
      │
      ▼
points to correct inbound endpoint IPs?
      │
      ▼
VPN/DX route?
      │
      ▼
AWS SG TCP/UDP 53?
      │
      ▼
Private Hosted Zone associated?
      │
      ▼
record exists?
```

AWS's inbound Resolver flow depends on each of these layers being intact. ([AWS Documentation][9])

---

# 56. Common Incident — Name Resolves to Public IP Internally

Expected:

```text
api.example.com
→ 10.0.10.20
```

but received:

```text
api.example.com
→ public CloudFront/ALB
```

Investigate:

```text
private hosted zone exists?
associated with correct VPC?
correct zone name?
record present?
client actually using VPC Resolver?
custom DNS server forwarding correctly?
```

Split-horizon resolution requires the private hosted zone association/resolver path to be correct. ([AWS Documentation][2])

---

# 57. Common Incident — Private Record Exists but Returns NXDOMAIN

Check whether:

```text
query name
```

actually matches:

```text
zone + record type
```

Then inspect:

```text
Resolver forwarding rule
```

because a rule for the same namespace can take precedence over the private hosted zone. ([AWS Documentation][2])

This is one of the strongest things to remember from this lesson.

---

# 58. `dig` Inside the VPC

From an EC2 instance:

```bash
dig api.internal.example.com
```

Explicitly ask the VPC Resolver:

```bash
dig @169.254.169.253 \
  api.internal.example.com
```

or for our example VPC:

```bash
dig @10.24.0.2 \
  api.internal.example.com
```

AWS currently documents both resolver addresses. ([AWS Documentation][3])

---

# 59. Test TCP DNS Too

Most people test only UDP.

Use:

```bash
dig +tcp api.internal.example.com
```

If:

```text
UDP works
TCP fails
```

inspect security/firewall rules.

DNS requires TCP support in real-world environments, which is why Resolver endpoint security-group guidance explicitly calls for both TCP and UDP. ([AWS Documentation][11])

---

# 60. Test On-Prem DNS Directly From AWS

Assuming routing/security permit:

```bash
dig @10.200.1.53 \
  sql.corp.example.com
```

If this fails:

```text
problem is below Resolver forwarding logic
```

possibly:

```text
routing
firewall
DNS server
```

If it works directly but fails through normal VPC resolution:

```text
investigate:
Resolver rule
association
outbound endpoint
```

This is layer-by-layer debugging.

---

# 61. Query Logging Investigation

Suppose application claims:

```text
database hostname won't resolve.
```

Instead of guessing, inspect Resolver query logs.

You might discover the application is asking for:

```text
prod-db.corp.local
```

while engineers thought it was querying:

```text
prod-db.corp.example.com
```

DNS logs turn:

```text
"I think the app is doing..."
```

into:

```text
"The app actually queried..."
```

Resolver query logging is intended specifically to provide visibility into DNS queries originating from associated VPCs. ([AWS Documentation][15])

---

# 62. Terraform — Private Hosted Zone

```hcl
resource "aws_route53_zone" "private" {
  name = "internal.example.com"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  comment = "Internal service discovery"
}
```

Internal record:

```hcl
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id

  name = "api.internal.example.com"
  type = "A"

  alias {
    name                   = aws_lb.internal.dns_name
    zone_id                = aws_lb.internal.zone_id
    evaluate_target_health = true
  }
}
```

---

# 63. Terraform — Resolver Endpoint Concept

Inbound:

```hcl
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "hybrid-inbound"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.resolver_inbound.id
  ]

  ip_address {
    subnet_id = aws_subnet.private_a.id
  }

  ip_address {
    subnet_id = aws_subnet.private_b.id
  }
}
```

Architecture:

```text
On-prem DNS
    │
    ▼
inbound endpoint
    │
    ▼
AWS private DNS
```

AWS requires multiple endpoint IPs and supports TCP/UDP DNS through the endpoint security groups. ([AWS Documentation][10])

---

# 64. Terraform — Outbound Endpoint

```hcl
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "hybrid-outbound"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.resolver_outbound.id
  ]

  ip_address {
    subnet_id = aws_subnet.private_a.id
  }

  ip_address {
    subnet_id = aws_subnet.private_b.id
  }
}
```

Architecture:

```text
AWS
 │
 ▼
outbound endpoint
 │
 ▼
on-prem DNS
```

---

# 65. Terraform — Forwarding Rule

```hcl
resource "aws_route53_resolver_rule" "corp" {
  domain_name = "corp.example.com"

  name      = "forward-corp-dns"
  rule_type = "FORWARD"

  resolver_endpoint_id =
    aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = "10.200.1.53"
  }

  target_ip {
    ip = "10.200.2.53"
  }
}
```

Associate it:

```hcl
resource "aws_route53_resolver_rule_association" "corp" {
  resolver_rule_id =
    aws_route53_resolver_rule.corp.id

  vpc_id = aws_vpc.main.id
}
```

Forwarding rules become effective for VPC DNS queries after they are associated with the VPC. ([AWS Documentation][12])

---

# 66. Terraform — Resolver Security Group

Inbound:

```hcl
resource "aws_security_group" "resolver_inbound" {
  name   = "resolver-inbound"
  vpc_id = aws_vpc.main.id
}
```

Then allow trusted on-prem CIDRs:

```text
UDP 53
TCP 53
```

Outbound Resolver SG:

```text
UDP 53
TCP 53
```

toward:

```text
10.200.1.53
10.200.2.53
```

AWS's endpoint-scaling/security guidance explicitly distinguishes inbound ingress from outbound egress behavior for these endpoints. ([AWS Documentation][11])

---

# 67. Production Hybrid Architecture

Now combine everything:

```text
                       INTERNET
                           │
                           ▼
                     Public Route 53
                           │
                           ▼
                      CloudFront
                           │
                           ▼
                          ALB

────────────────────────────────────────────────────────

                        AWS VPC

                     Application
                           │
                           ▼
                  Route 53 VPC Resolver
                           │
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
       Public DNS      Private Hosted     Resolver Rule
                            Zone               │
                             │                  ▼
                             ▼            Outbound EP
                       internal ALB             │
                                               ▼
                                        Direct Connect
                                             / VPN
                                               │
                                               ▼
                                         Corporate DNS
                                               │
                                               ▼
                                         On-Prem Apps

────────────────────────────────────────────────────────

                  On-Premises Clients
                           │
                           ▼
                    Corporate DNS
                           │
                    aws.example.com
                     conditional
                      forwarding
                           │
                           ▼
                     Inbound EP
                           │
                           ▼
                  Route 53 VPC Resolver
                           │
                           ▼
                   AWS Private DNS
```

That is enterprise hybrid DNS.

---

# 68. Never-Forget Resolver Diagram

```text
                    Route 53 VPC Resolver
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
     Private Hosted       Public DNS        Resolver Rules
         Zones                                  │
                                                ▼
                                          Outbound Endpoint
                                                │
                                                ▼
                                            On-Prem DNS


On-Prem DNS
     │
     ▼
Inbound Endpoint
     │
     ▼
Route 53 VPC Resolver
     │
     ▼
Private Hosted Zones
```

If you can draw that from memory, you understand hybrid DNS.

---

# 69. Certification Scenario

> On-premises servers need to resolve names stored in a Route 53 private hosted zone.

Answer:

```text
Route 53 Resolver
INBOUND ENDPOINT
```

with connectivity such as:

```text
VPN / Direct Connect
```

and an on-prem forwarding/delegation configuration. ([AWS Documentation][8])

---

# 70. Certification Scenario

> EC2 instances must resolve `corp.example.com`, which is hosted by on-premises DNS.

Answer:

```text
OUTBOUND RESOLVER ENDPOINT
+
FORWARDING RULE
```

([AWS Documentation][7])

---

# 71. Certification Scenario

> Same domain should resolve to public IPs on the internet and private IPs inside the VPC.

Answer:

```text
PUBLIC HOSTED ZONE
+
PRIVATE HOSTED ZONE
with same namespace
```

This is:

```text
split-horizon DNS
```

([AWS Documentation][2])

---

# 72. Certification Scenario

> Multiple AWS accounts need the same centrally managed Resolver rule.

Think:

```text
AWS RAM
```

or modern:

```text
Route 53 Profiles + AWS RAM
```

depending on the scope of DNS configuration you are centralizing. ([AWS Documentation][14])

---

# 73. Certification Scenario

> Security needs to block DNS lookups to known malicious domains from VPC workloads.

Answer:

```text
Route 53 Resolver DNS Firewall
```

([AWS Documentation][16])

---

# 74. Certification Scenario

> Security wants records of DNS queries generated by VPC workloads.

Answer:

```text
Route 53 VPC Resolver
Query Logging
```

([AWS Documentation][15])

---

# 75. Certification Trap

> VPC Peering is configured, so private hosted zones automatically become visible between both VPCs.

Answer:

```text
NO.
```

Network connectivity and private hosted-zone association/resolver configuration are separate concerns.

Think:

```text
PEERING/TGW
=
NETWORK REACHABILITY

PRIVATE HOSTED ZONE
=
DNS VISIBILITY
```

---

# 76. Certification Trap

> On-prem servers should query the VPC's `10.24.0.2` resolver directly over Direct Connect.

Don't design it that way.

Use:

```text
Route 53 Resolver
Inbound Endpoint
```

for supported hybrid inbound DNS access. AWS specifically notes that the native VPC `+2` resolver isn't the on-premises hybrid endpoint mechanism. ([AWS Documentation][6])

---

# 77. Production Troubleshooting Decision Tree

```text
                     DNS FAILURE
                         │
                         ▼
                   WHERE IS CLIENT?
                   │            │
                  AWS        ON-PREM
                   │            │
                   ▼            ▼

                AWS client    On-prem client
                   │            │
                   ▼            ▼

          private or on-prem?   AWS private?
            │          │            │
            ▼          ▼            ▼
           PHZ     Resolver rule   Forwarder
                       │             │
                       ▼             ▼
                  Outbound EP     Inbound EP
                       │             │
                       ▼             ▼
                   VPN / DX       VPN / DX
                       │             │
                       ▼             ▼
                 On-prem DNS     VPC Resolver
```

Then check:

```text
DNS attributes
associations
rules
SGs
routing
firewall
DNS Firewall
query logs
```

---

# 78. 20 Rules to Burn Into Memory

```text
1. Private hosted zones provide private DNS namespaces.

2. Private hosted zones are associated with VPCs.

3. DNS resolution does not create network connectivity.

4. VPC Resolver is built into AWS VPC DNS.

5. VPC Resolver is reachable at 169.254.169.253
   and the primary VPC IPv4 CIDR + 2.

6. enableDnsSupport matters for VPC DNS.

7. enableDnsHostnames matters for AWS hostname behavior.

8. Public + private zones can create split-horizon DNS.

9. Private-zone missing records don't necessarily
   fall back to public DNS.

10. Resolver forwarding rules can take precedence
    over a private hosted zone for the same namespace.

11. INBOUND = network/on-prem → AWS DNS.

12. OUTBOUND = AWS DNS → external/on-prem DNS.

13. Resolver endpoints use private IP addresses.

14. Hybrid Resolver endpoints need private connectivity,
    such as VPN or Direct Connect.

15. DNS endpoints should span multiple AZs.

16. Normal DNS requires both UDP and TCP port 53.

17. Resolver rules define which domains are forwarded.

18. AWS RAM / Route 53 Profiles help centralize DNS
    across multi-account environments.

19. Resolver Query Logging provides DNS visibility.

20. DNS Firewall provides DNS-layer domain filtering.
```

And the shortest memory trick:

```text
PRIVATE HOSTED ZONE
=
AWS PRIVATE NAMES
```

```text
INBOUND
=
ON-PREM ASKS AWS
```

```text
OUTBOUND
=
AWS ASKS ON-PREM
```

If you permanently remember those three sentences, most Route 53 hybrid questions become much easier.

---

# ✅ Lesson 29 Part 3 Complete

You now understand:

```text
✓ Private Hosted Zones
✓ public vs private DNS
✓ split-horizon DNS
✓ VPC Resolver
✓ AmazonProvidedDNS
✓ 169.254.169.253
✓ VPC + 2 resolver
✓ enableDnsSupport
✓ enableDnsHostnames
✓ private-zone associations
✓ cross-VPC DNS concepts
✓ DNS vs network connectivity
✓ hybrid DNS
✓ inbound Resolver endpoints
✓ outbound Resolver endpoints
✓ forwarding rules
✓ conditional forwarding
✓ VPN / Direct Connect DNS
✓ multiple-AZ Resolver endpoints
✓ TCP / UDP 53
✓ Resolver rule precedence
✓ private zone NXDOMAIN behavior
✓ AWS RAM
✓ centralized enterprise DNS
✓ Route 53 Profiles
✓ Resolver Query Logging
✓ DNS Firewall
✓ AWS PrivateLink DNS concepts
✓ Terraform
✓ hybrid troubleshooting
✓ SAA-C03 scenarios
✓ enterprise architecture
```

# Next — Lesson 29 Part 4

## Route 53 Security, DNSSEC, Migration, Terraform & Production Capstone

We'll finish Route 53 with:

```text
DNSSEC
   │
   ├── signing
   ├── KSK / ZSK concepts
   ├── DS records
   ├── chain of trust
   └── DNS spoofing protection

Route 53 domain security
   │
   ├── registrar locking
   ├── IAM controls
   ├── Route 53 change permissions
   └── query logging

DNS migrations
   │
   ├── external DNS → Route 53
   ├── lowering TTL safely
   ├── copying records
   ├── changing NS delegation
   └── zero/low-downtime cutover

Production troubleshooting
   │
   ├── SERVFAIL
   ├── NXDOMAIN
   ├── stale TTL
   ├── wrong NS
   ├── DNSSEC failures
   ├── Alias problems
   ├── private DNS issues
   └── hybrid failures

Final capstone
   │
   ▼
Internet + CloudFront + ALB
+
Multi-Region Route 53
+
Private DNS
+
Hybrid DNS
+
DNS Firewall
+
Terraform
```

After Part 4, **Lesson 29/Route 53 will be fully complete**, and we'll begin **Lesson 30 — AWS IAM & Enterprise Security Architecture**.

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html?utm_source=chatgpt.com "Considerations when working with a private hosted zone"
[3]: https://docs.aws.amazon.com/vpc/latest/userguide/AmazonDNS-concepts.html?utm_source=chatgpt.com "Understanding Amazon DNS - Amazon Virtual Private Cloud"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-creating.html?utm_source=chatgpt.com "Creating a private hosted zone - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-associate-vpcs.html?utm_source=chatgpt.com "Associating more VPCs with a private hosted zone - Amazon Route 53"
[6]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/dns.html?utm_source=chatgpt.com "DNS - Building a Scalable and Secure Multi-VPC ..."
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-inbound-queries.html?utm_source=chatgpt.com "Forwarding inbound DNS queries to your VPCs"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-forward-network-to-vpc.html?utm_source=chatgpt.com "How DNS resolvers on your network forward DNS queries ..."
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-choose-vpc.html?utm_source=chatgpt.com "Considerations when creating inbound and outbound ..."
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-resolver-endpoint-scaling.html?utm_source=chatgpt.com "Resolver endpoint scaling - Amazon Route 53"
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-rules-managing.html?utm_source=chatgpt.com "Managing forwarding rules - Amazon Route 53"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/profiles.html?utm_source=chatgpt.com "What are Amazon Route 53 Profiles?"
[14]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/set-up-dns-resolution-for-hybrid-networks-in-a-multi-account-aws-environment.html?utm_source=chatgpt.com "Set up DNS resolution for hybrid networks in a multi- ..."
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-query-logs.html?utm_source=chatgpt.com "Resolver query logging - Amazon Route 53"
[16]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall-overview.html?utm_source=chatgpt.com "How Resolver DNS Firewall works - Amazon Route 53"
[17]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall-managed-domain-lists.html?utm_source=chatgpt.com "Managed Domain Lists - Amazon Route 53 - AWS Documentation"
[18]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-DSN-queries-to-vpc.html?utm_source=chatgpt.com "Resolving DNS queries between VPCs and your network"
[19]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-access-to-vpc-private-endpoints.html?utm_source=chatgpt.com "Centralized access to VPC private endpoints"
