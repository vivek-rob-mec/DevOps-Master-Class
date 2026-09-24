# AWS Masterclass — Lesson 29 Part 1

# Amazon Route 53 & DNS Fundamentals — How DNS Actually Finds Your Application

We have spent many lessons building infrastructure:

```text
VPC
EC2
ALB
Auto Scaling
S3
CloudFront
RDS
Aurora
DynamoDB
ElastiCache
```

But none of that answers a simple user question:

> **“I typed `www.example.com`. How did my computer know where to send the request?”**

That is the DNS problem.

Amazon Route 53 is AWS's highly available, scalable DNS service. Its three core roles are **domain registration, authoritative DNS routing, and health checking**; Route 53 also includes VPC DNS/resolver capabilities for private and hybrid architectures. ([AWS Documentation][1])

---

# 1. Start With the Biggest Mental Model

A user understands:

```text
www.example.com
```

Computers ultimately need something routable such as:

```text
203.0.113.10
```

or:

```text
2001:db8::10
```

DNS is the distributed system that maps names to information needed to reach services.

Conceptually:

```text
USER
 │
 │ types
 ▼
https://www.example.com
 │
 ▼
DNS
 │
 ▼
Where is www.example.com?
 │
 ▼
IP / AWS endpoint information
 │
 ▼
network connection
 │
 ▼
Web Application
```

Route 53 can serve as the **authoritative DNS service** that holds the DNS records for your domain. ([AWS Documentation][2])

---

# 2. DNS Is Not HTTP

This distinction is essential.

When you type:

```text
https://www.example.com/products
```

several different systems are involved.

First:

```text
DNS
www.example.com
      │
      ▼
Where should I connect?
```

Then:

```text
TCP / QUIC
      │
      ▼
network connection
```

Then:

```text
TLS
      │
      ▼
HTTPS security
```

Then:

```text
HTTP
      │
      ▼
GET /products
```

So:

```text
DNS
≠
HTTP
≠
TLS
≠
routing table
```

DNS gets you toward the service endpoint.

---

# 3. Complete DNS Resolution Journey

Suppose you request:

```text
www.example.com
```

The simplified process looks like:

```text
Browser
   │
   ▼
OS DNS cache
   │
   ▼
Recursive DNS Resolver
   │
   ▼
Root DNS
   │
   ▼
.com TLD DNS
   │
   ▼
example.com authoritative DNS
   │
   ▼
www.example.com record
   │
   ▼
IP / target
```

Route 53's authoritative name servers can be the final authoritative DNS layer for `example.com`. AWS defines an authoritative server as one that has definitive DNS information for its portion of the namespace, while recursive resolvers obtain and cache answers on behalf of clients. ([AWS Documentation][2])

Let's unpack every layer.

---

# 4. Browser and Operating-System Cache

Before asking anybody on the internet, your machine might already know the answer.

Conceptually:

```text
Browser cache
      │
      ▼
OS DNS cache
```

If:

```text
www.example.com
=
203.0.113.20
```

is still cached and its TTL hasn't expired, another DNS lookup might not need to reach the authoritative server.

That is why DNS changes do not necessarily become visible to every user immediately.

---

# 5. Recursive DNS Resolver

Your machine normally asks a:

# Recursive DNS Resolver

Examples conceptually include DNS resolvers provided by:

```text
ISP
corporate network
cloud/VPC
public DNS resolver
```

Its job is essentially:

> “Find the answer for me.”

```text
Laptop
  │
  ▼
Recursive Resolver
  │
  ├── Do I have cached answer?
  │
  ├── if no → ask DNS hierarchy
  │
  └── return final answer
```

AWS distinguishes recursive resolvers from authoritative name servers explicitly. ([AWS Documentation][2])

---

# 6. Root DNS

Suppose the resolver wants:

```text
www.example.com
```

The root system doesn't normally return:

```text
203.0.113.50
```

for your web server.

It directs resolution toward the appropriate top-level-domain authority.

Conceptually:

```text
Resolver:
Where is www.example.com?

Root:
Ask the .com name servers.
```

Then:

```text
Resolver
   │
   ▼
.com
```

---

# 7. TLD — Top-Level Domain

For:

```text
example.com
```

the TLD is:

```text
.com
```

For:

```text
example.org
```

it is:

```text
.org
```

For:

```text
yourdatascientist.tech
```

it is:

```text
.tech
```

The relevant TLD infrastructure knows which authoritative name servers are responsible for registered domains beneath it. AWS's Route 53 DNS concepts describe this hierarchy and the authoritative-name-server role. ([AWS Documentation][2])

---

# 8. Authoritative Name Server

Now the resolver reaches the authoritative DNS service for:

```text
example.com
```

Perhaps that authoritative service is:

```text
Amazon Route 53
```

Route 53 checks the hosted-zone records and answers:

```text
www.example.com
        │
        ▼
203.0.113.20
```

or perhaps:

```text
www.example.com
        │
        ▼
CloudFront distribution
```

or:

```text
api.example.com
        │
        ▼
Application Load Balancer
```

This is where Route 53 becomes part of our AWS architecture.

---

# 9. Never-Forget DNS Resolution

```text
CLIENT
   │
   ▼
RECURSIVE RESOLVER
   │
   ▼
ROOT
   │
   ▼
TLD
   │
   ▼
AUTHORITATIVE DNS
   │
   ▼
DNS RECORD
   │
   ▼
APPLICATION ENDPOINT
```

Memorize that sequence.

---

# 10. Domain Registrar vs DNS Provider

This is one of the biggest DNS confusions.

These are **two separate roles**.

## Registrar

The registrar manages registration/ownership information for:

```text
example.com
```

Think:

```text
"Who registered this domain,
and which name servers are authoritative?"
```

## DNS hosting/provider

The DNS service stores records like:

```text
www     → CloudFront
api     → ALB
mail    → mail system
```

Think:

```text
"What DNS answers should
this domain return?"
```

They may be the same company.

Or different.

---

# 11. Example — Domain Registered Somewhere Else

You can have:

```text
Registrar
     │
     ▼
another domain company
```

while DNS is:

```text
Amazon Route 53
```

Architecture:

```text
Domain Registrar
      │
      │ NS delegation
      ▼
Route 53 authoritative name servers
      │
      ▼
Hosted Zone
      │
      ├── A
      ├── AAAA
      ├── Alias
      ├── MX
      └── TXT
```

To migrate authoritative DNS to Route 53, you create the hosted zone/records and update the domain registration to use the Route 53 name servers. ([AWS Documentation][3])

So:

```text
Domain registered outside AWS
```

does **not** mean:

```text
cannot use Route 53.
```

---

# 12. If You Register the Domain Through Route 53

When a domain is registered through Route 53, AWS automatically creates a hosted zone, assigns Route 53 name servers, and updates the domain registration to use them. ([AWS Documentation][4])

That means AWS can perform both roles:

```text
Route 53 Registrar
       │
       +
Route 53 DNS
```

But conceptually they remain separate responsibilities.

---

# 13. Hosted Zone

The central Route 53 object is:

# Hosted Zone

Think:

```text
Hosted Zone
=
DNS database for a DNS namespace
```

Example:

```text
yourdatascientist.tech
```

A hosted zone might contain:

```text
yourdatascientist.tech      Alias   CloudFront
www                         Alias   CloudFront
api                         Alias   ALB
mail                        MX      mail provider
_acme-validation            CNAME   ACM validation
```

Route 53 has both **public hosted zones**, for internet DNS, and **private hosted zones**, for DNS resolution within associated VPCs. ([AWS Documentation][5])

We'll study private hosted zones deeply later.

---

# 14. Public Hosted Zone

Suppose:

```text
example.com
```

must work on the internet.

Use:

```text
PUBLIC HOSTED ZONE
```

Architecture:

```text
Internet user
     │
     ▼
public DNS resolver
     │
     ▼
Route 53 public hosted zone
     │
     ▼
record
     │
     ▼
public AWS resource
```

Examples:

```text
CloudFront
ALB
API Gateway
public IP
S3 website endpoint
```

depending on architecture.

---

# 15. Private Hosted Zone

Suppose only internal systems should resolve:

```text
database.internal.example.com
```

Architecture:

```text
EC2 inside VPC
      │
      ▼
VPC Resolver
      │
      ▼
Route 53 Private Hosted Zone
      │
      ▼
10.20.30.40
```

An internet user should not resolve these private-zone records through normal public DNS.

Route 53 private hosted zones are associated with VPCs and provide DNS information for those VPC environments. ([AWS Documentation][6])

---

# 16. Important 2026 Name Change: Route 53 VPC Resolver

Current AWS documentation calls the VPC DNS resolver:

# Route 53 VPC Resolver

AWS notes that it was previously called **Route 53 Resolver**; it was renamed after Route 53 Global Resolver was introduced. VPC Resolver provides recursive resolution for VPC workloads and resolves public DNS, VPC-specific DNS names, and Route 53 private hosted-zone records. ([AWS Documentation][7])

We'll cover it in a dedicated hybrid DNS lesson.

---

# 17. NS Record

NS means:

# Name Server

The NS records say:

> **“These DNS servers are authoritative for this domain.”**

For a Route 53 public hosted zone, you'll see several AWS name servers.

Conceptually:

```text
example.com NS

ns-123.awsdns-xx.org
ns-456.awsdns-xx.net
ns-789.awsdns-xx.com
ns-012.awsdns-xx.co.uk
```

Route 53's NS records are what you configure at the domain registration/delegation layer so that the DNS hierarchy knows where to ask about the zone. ([AWS Documentation][8])

### Never forget

```text
Registrar
     │
     ▼
NS delegation
     │
     ▼
Hosted Zone
```

---

# 18. The Most Common DNS Disaster

Imagine you create:

```text
Route 53 hosted zone:
example.com
```

AWS gives you:

```text
NS-A
NS-B
NS-C
NS-D
```

But your registrar still points to:

```text
OldDNS-1
OldDNS-2
```

You create beautiful Route 53 records:

```text
www → ALB
```

but the internet keeps asking:

```text
OldDNS
```

Route 53 receives no authoritative queries.

Result:

```text
"Route 53 is not working!"
```

Actually:

```text
delegation is wrong.
```

This is why the first DNS troubleshooting command is often:

```bash
dig NS example.com
```

---

# 19. SOA Record

SOA means:

# Start of Authority

Route 53 automatically creates an SOA record for a hosted zone.

It contains administrative information about the DNS zone, including information relevant to secondary DNS behavior and negative caching. ([AWS Documentation][9])

You normally don't spend your day manually editing SOA values, but you should know what it is.

Think:

```text
NS
=
WHO is authoritative?
```

```text
SOA
=
metadata about that authority/zone
```

---

# 20. Negative DNS Caching

Suppose someone asks:

```text
does-not-exist.example.com
```

Route 53 responds:

```text
NXDOMAIN
```

A recursive resolver may cache that negative response.

That means if you create:

```text
does-not-exist.example.com
```

thirty seconds later, some resolvers might temporarily keep believing:

```text
doesn't exist
```

until the negative-cache duration expires. Route 53's SOA configuration helps control negative caching; AWS currently documents the effective negative-cache duration as the lesser of the SOA minimum TTL and the SOA record's TTL. ([AWS Documentation][9])

This is an advanced reason why:

```text
"I created the record,
but it still doesn't work!"
```

can occur.

---

# 21. A Record

A means an IPv4 address mapping.

```text
app.example.com
       │
       ▼
203.0.113.10
```

Example:

```text
Type: A
Name: app.example.com
Value: 203.0.113.10
```

Route 53 uses A records to map a name to an IPv4 address. ([AWS Documentation][8])

---

# 22. AAAA Record

AAAA maps a DNS name to an:

# IPv6 address

Example:

```text
app.example.com
       │
       ▼
2001:db8::1234
```

Route 53 supports AAAA records for IPv6 destinations. ([AWS Documentation][8])

Memory trick:

```text
A
=
IPv4

AAAA
=
IPv6
```

---

# 23. CNAME Record

CNAME means:

# Canonical Name

It maps:

```text
one DNS name
```

to:

```text
another DNS name
```

Example:

```text
www.example.com
        │
        ▼
d123456abcdef.cloudfront.net
```

Conceptually:

```text
www.example.com CNAME d123.cloudfront.net
```

Route 53 supports CNAME records for subdomains. ([AWS Documentation][8])

---

# 24. CNAME Is Not an IP Address

This:

```text
www.example.com
→ 203.0.113.20
```

is:

```text
A
```

This:

```text
www.example.com
→ other.example.net
```

is:

```text
CNAME
```

The resolver may then need to resolve:

```text
other.example.net
```

to an A/AAAA record.

---

# 25. The Zone Apex Problem

Suppose your domain is:

```text
example.com
```

This name itself is called the:

# Zone Apex

or root of that hosted zone.

You can create:

```text
www.example.com
```

CNAME.

But standard DNS rules do **not** allow a CNAME at:

```text
example.com
```

because the zone apex needs other DNS records such as NS and SOA. Route 53 documents this CNAME restriction explicitly. ([AWS Documentation][8])

So:

```text
www.example.com
CNAME
```

works.

But:

```text
example.com
CNAME
```

doesn't.

This creates a problem because AWS resources often give us DNS names rather than fixed IPs.

---

# 26. Example — Application Load Balancer

An ALB might give you something like:

```text
my-alb-123456.ap-south-1.elb.amazonaws.com
```

You want:

```text
yourdatascientist.tech
```

to point to it.

You cannot safely hardcode an ALB IP because load-balancer addresses are managed by AWS.

And standard DNS CNAME cannot exist at the zone apex.

So how do we solve this?

# Route 53 Alias Record

---

# 27. Alias Record — One of the Most Important AWS DNS Features

An Alias is a Route 53-specific DNS extension that can route traffic to supported AWS resources.

For example:

```text
yourdatascientist.tech
         │
         ▼
Route 53 Alias A
         │
         ▼
Application Load Balancer
```

or:

```text
yourdatascientist.tech
         │
         ▼
Route 53 Alias A
         │
         ▼
CloudFront
```

Unlike a CNAME, an Alias can be created at the zone apex. ([AWS Documentation][10])

### Never forget

```text
CNAME
cannot be apex

Alias
can be apex
```

---

# 28. Alias Does Not Appear as a Special DNS Type to Clients

This is subtle.

In the Route 53 console you may configure:

```text
Type: A
Alias: Yes
Target: ALB
```

When clients use:

```bash
dig example.com
```

they see an ordinary DNS response such as:

```text
A
```

They do not see:

```text
ALIAS
```

as a standard DNS record type.

Alias behavior is a Route 53 implementation feature. ([AWS Documentation][10])

---

# 29. Alias vs CNAME

This table is worth memorizing:

| Feature                                 | CNAME             | Route 53 Alias                                       |
| --------------------------------------- | ----------------- | ---------------------------------------------------- |
| Standard DNS type                       | Yes               | Route 53 extension                                   |
| Maps name → another name/resource       | Yes               | Yes                                                  |
| Can be at zone apex                     | **No**            | **Yes**                                              |
| Useful for AWS resources                | Yes in some cases | Usually preferred                                    |
| Resolver may require another DNS lookup | Often             | Route 53 responds as target type                     |
| You manually configure TTL              | Yes               | AWS-resource alias uses target/resource TTL behavior |

Route 53 also doesn't charge DNS query fees for alias queries to supported AWS resources, whereas normal CNAME queries are charged according to Route 53 DNS query pricing. ([AWS Documentation][10])

For AWS architectures:

```text
Route 53
   │
   ▼
CloudFront / ALB / AWS target
```

think:

```text
ALIAS
```

first.

---

# 30. Alias TTL

When an Alias points to an AWS resource, you don't specify the ordinary DNS TTL yourself; Route 53 uses the target resource's applicable default TTL behavior. If an Alias instead points to another Route 53 record in the same hosted zone, it inherits that target record's TTL. ([AWS Documentation][10])

This is another Alias/CNAME distinction.

---

# 31. CloudFront + Route 53

Our previous S3/CloudFront architecture now becomes:

```text
User
 │
 ▼
yourdatascientist.tech
 │
 ▼
Route 53
 │
 │ Alias
 ▼
CloudFront
 │
 │ OAC
 ▼
Private S3
```

AWS specifically recommends a Route 53 Alias when routing a Route 53-managed domain to a CloudFront distribution; this works for both apex domains and subdomains. ([AWS Documentation][11])

This connects directly to Lesson 27.

---

# 32. ALB + Route 53

Dynamic application:

```text
User
 │
 ▼
api.example.com
 │
 ▼
Route 53
 │
 │ Alias
 ▼
ALB
 │
 ▼
Target Group
 │
 ▼
EC2 Auto Scaling
```

Route 53 Alias records can target Elastic Load Balancers, including at the root domain. ([AWS Documentation][12])

Again:

```text
DNS points to ALB

NOT

DNS directly to EC2
```

for our normal production HA architecture.

---

# 33. MX Record

MX means:

# Mail Exchange

It tells mail systems:

> “Where should email for this domain go?”

Example:

```text
example.com

MX

10 mail1.example.com
20 mail2.example.com
```

Lower numerical priority is preferred. Route 53 supports multiple MX values and uses the priority numbers to indicate mail-server preference. ([AWS Documentation][8])

Architecture:

```text
someone@example.com
       │
       ▼
DNS MX lookup
       │
       ▼
mail server
```

MX is about:

```text
EMAIL
```

not your web application.

---

# 34. TXT Record

TXT records store textual DNS data.

They are commonly used for things such as:

```text
domain verification
email security policies
service verification
ACM/provider verification workflows
```

Modern SPF policies should also be published using TXT rather than the obsolete dedicated SPF DNS record type; Route 53's documentation explicitly recommends TXT for SPF data. ([AWS Documentation][8])

Example:

```text
example.com TXT
"v=spf1 include:example.net -all"
```

---

# 35. CAA Record

CAA means:

# Certification Authority Authorization

It lets a domain specify which certificate authorities may issue TLS certificates for it. Route 53 supports CAA records and documents tags such as `issue` and `issuewild`. ([AWS Documentation][8])

Conceptually:

```text
example.com
   │
   ▼
CAA
   │
   ▼
"Only these CA(s) may issue certificates"
```

This becomes relevant with:

```text
ACM
TLS
CloudFront
ALB HTTPS
```

---

# 36. DS Record

DS means:

# Delegation Signer

It is part of:

```text
DNSSEC
```

and helps establish a cryptographic chain of trust between DNS zones. Route 53 supports DS records for DNSSEC delegation. ([AWS Documentation][8])

We will cover DNSSEC separately because it deserves a dedicated security discussion.

---

# 37. Modern DNS Record Types

Current Route 53 supports more than the traditional A/AAAA/CNAME/MX/TXT set. Its supported list now includes types such as:

```text
HTTPS
SVCB
SSHFP
TLSA
DS
SRV
NAPTR
```

alongside the traditional record types. ([AWS Documentation][8])

For example, the modern HTTPS record type can advertise service connection parameters including HTTP/2, HTTP/3, alternative ports, IP hints, and related information. ([AWS Documentation][8])

For now, however, your AWS daily-use essentials are:

```text
A
AAAA
Alias
CNAME
MX
TXT
CAA
NS
SOA
```

---

# 38. DNS TTL

TTL means:

# Time To Live

Suppose:

```text
api.example.com
A
203.0.113.10

TTL = 300
```

That means a recursive resolver can cache the answer for:

```text
300 seconds
=
5 minutes
```

before it needs to ask authoritative DNS again.

AWS defines TTL exactly as the amount of time a DNS resolver can cache a Route 53 record value. ([AWS Documentation][2])

---

# 39. Long TTL

Example:

```text
TTL = 86400
```

which is:

```text
24 hours
```

Benefits:

```text
fewer DNS queries
more resolver cache hits
lower DNS query load/cost
```

But if you change:

```text
203.0.113.10
```

to:

```text
203.0.113.20
```

a resolver may keep using the old value until its cached TTL expires.

AWS recommends considering the tradeoff between query frequency/reliability and responsiveness to record changes; its current best-practices documentation recommends TTLs broadly in the **60–172,800 second** range depending on use case. ([AWS Documentation][13])

---

# 40. Short TTL

Example:

```text
TTL = 60
```

Benefits:

```text
DNS changes recognized sooner
better for controlled traffic shifts/failover patterns
```

Tradeoff:

```text
more DNS queries
less resolver caching
```

There is no magical universal TTL.

Choose it based on:

```text
change frequency
failover requirement
query volume
cost
architecture
```

---

# 41. TTL Does Not Mean Route 53 Needs 5 Minutes to Update

This distinction is crucial.

Suppose:

```text
TTL = 3600
```

and you change a record in Route 53.

AWS currently says Route 53 record changes generally propagate to all Route 53 authoritative name servers within about **60 seconds**. ([AWS Documentation][14])

But a recursive resolver that already cached the old value may keep serving it until its:

```text
3600-second TTL
```

expires.

So there are two different processes:

```text
Route 53 authoritative update
        │
        ▼
generally ~60 seconds

PLUS

recursive resolver cache
        │
        ▼
up to remaining TTL
```

This is one of the most important DNS troubleshooting distinctions.

---

# 42. “DNS Propagation” Is Often a Misleading Phrase

Engineer says:

> “DNS is still propagating.”

Ask:

```text
WHAT exactly?
```

Possible:

### Route 53 change hasn't reached all Route 53 servers

Usually short-lived. ([AWS Documentation][14])

### Resolver has cached an old record

Wait for TTL.

### Registrar still points at old name servers

Delegation issue.

### Negative NXDOMAIN was cached

SOA/negative TTL issue.

### Local machine/browser cached DNS

Client caching issue.

“DNS propagation” is not a diagnosis.

---

# 43. Practical DNS Troubleshooting — `dig`

This command should become muscle memory:

```bash
dig example.com
```

For a specific type:

```bash
dig A example.com
```

```bash
dig AAAA example.com
```

```bash
dig MX example.com
```

```bash
dig TXT example.com
```

```bash
dig NS example.com
```

---

# 44. Read a `dig` Result

Simplified:

```text
;; ANSWER SECTION:
example.com.  300  IN  A  203.0.113.10
```

Interpret:

```text
example.com.
      │
      ├── TTL = 300
      │
      ├── class = IN
      │
      ├── type = A
      │
      └── value = 203.0.113.10
```

That is much better than saying:

> “The domain works.”

You can inspect exactly what DNS is returning.

---

# 45. Check Authoritative Name Servers

Run:

```bash
dig NS yourdatascientist.tech
```

You want to determine:

```text
Which DNS provider
is actually authoritative?
```

If Route 53 is authoritative, you'd expect the delegated name servers to correspond to your Route 53 hosted-zone name servers.

Then compare them to:

```bash
aws route53 list-hosted-zones
```

and:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id ZXXXXXXXXXXXX
```

Do not modify DNS until you have confirmed which hosted zone/delegation is actually live.

---

# 46. Ask a Specific Authoritative Server

Suppose:

```text
dig NS example.com
```

returns:

```text
ns-123.awsdns-45.net
```

You can query that server directly:

```bash
dig @ns-123.awsdns-45.net example.com A
```

Now you're bypassing your normal recursive resolver's cached answer and asking the authoritative server directly.

This is extremely useful during DNS migration troubleshooting.

---

# 47. Trace DNS Resolution

Linux:

```bash
dig +trace example.com
```

Conceptually you'll see:

```text
.
 │
 ▼
TLD
 │
 ▼
domain delegation
 │
 ▼
authoritative DNS
```

This helps find delegation mistakes.

---

# 48. Browser Works but `dig` Doesn't?

Possible layers:

```text
browser DNS cache
OS cache
DNS-over-HTTPS resolver
VPN
corporate DNS
proxy
```

Remember:

```text
different applications
can use different resolver paths.
```

Don't assume every lookup goes through the same DNS resolver.

---

# 49. `NXDOMAIN`

If you see:

```text
status: NXDOMAIN
```

that means:

```text
requested name
does not exist
```

according to the DNS response.

Possible causes:

```text
record absent
wrong hosted zone
delegation wrong
subdomain misspelled
negative cache
```

Do not start debugging:

```text
ALB security group
```

because DNS hasn't even provided the application destination.

---

# 50. DNS Does Not Check Your Application by Default

Suppose:

```text
api.example.com
→ ALB
```

DNS can resolve perfectly.

But ALB may return:

```text
503
```

So:

```text
DNS HEALTHY
```

does not necessarily mean:

```text
APPLICATION HEALTHY.
```

This separation is important:

```text
DNS
 │
 ▼
ALB
 │
 ▼
Target Group
 │
 ▼
Application
```

Route 53 health checks and advanced routing can integrate application health into DNS decisions, which we'll cover later. Route 53 supports health checks and DNS failover explicitly. ([AWS Documentation][1])

---

# 51. DNS Routing vs Network Routing

Another major distinction.

Route 53 “routing policies” do not forward IP packets.

Route 53 answers:

```text
DNS queries
```

with different DNS responses.

For example:

```text
User India
   │
   ▼
DNS query
   │
   ▼
Route 53
   │
   ▼
Mumbai endpoint


User Germany
   │
   ▼
DNS query
   │
   ▼
Route 53
   │
   ▼
Frankfurt endpoint
```

Then the client independently connects to the returned destination.

Current Route 53 routing policies include **simple, failover, geolocation, geoproximity, latency, IP-based, multivalue answer, and weighted** routing. ([AWS Documentation][15])

We'll build each of those in Part 2.

---

# 52. DNS Control Plane vs Data Plane

Route 53 also gives us an excellent AWS architecture lesson.

AWS currently describes Route 53's public/private DNS control plane as centered in `us-east-1`, while the authoritative DNS **data plane is globally distributed** across more than 200 Points of Presence. ([AWS Documentation][2])

Conceptually:

```text
CONTROL PLANE
────────────────────
Create record
Delete record
Change hosted zone

       │
       ▼

DATA PLANE
────────────────────
answer DNS query
answer DNS query
answer DNS query
globally
```

AWS designs the DNS data plane for high availability independently from control-plane management operations. ([AWS Documentation][2])

This is another example of:

```text
MANAGEMENT
≠
SERVING TRAFFIC
```

---

# 53. Basic Production Website Architecture

Now combine everything you've learned:

```text
                       USER
                        │
                        ▼
              www.example.com
                        │
                        ▼
                 Recursive DNS
                        │
                        ▼
                    Route 53
                        │
                      Alias
                        │
                        ▼
                  CloudFront
                        │
                       OAC
                        │
                        ▼
                  Private S3
```

or dynamic site:

```text
                       USER
                        │
                        ▼
                  api.example.com
                        │
                        ▼
                    Route 53
                        │
                      Alias
                        │
                        ▼
                       ALB
                        │
                        ▼
                   Target Group
                        │
                        ▼
                  EC2 Auto Scaling
                        │
                        ▼
                     Aurora
```

DNS is now the front door connecting human-readable names to everything we've built.

---

# 54. Recommended Naming Pattern

A realistic environment might use:

```text
example.com
```

for the primary site,

```text
www.example.com
```

for website aliasing,

```text
api.example.com
```

for application API,

```text
assets.example.com
```

for CDN/static content,

```text
auth.example.com
```

for authentication,

and internally:

```text
database.internal.example.com
service.internal.example.com
```

through private DNS.

DNS naming itself becomes part of architecture.

---

# 55. Hands-On Read-Only Lab

Before changing anything, inspect DNS.

For your domain:

```bash
DOMAIN="yourdatascientist.tech"
```

Check the authoritative delegation:

```bash
dig NS "$DOMAIN"
```

Check IPv4:

```bash
dig A "$DOMAIN"
```

Check IPv6:

```bash
dig AAAA "$DOMAIN"
```

Check common `www` record:

```bash
dig www."$DOMAIN"
```

Check mail:

```bash
dig MX "$DOMAIN"
```

Check TXT:

```bash
dig TXT "$DOMAIN"
```

Trace delegation:

```bash
dig +trace "$DOMAIN"
```

Then inspect Route 53 in AWS:

```bash
aws route53 list-hosted-zones \
  --output table
```

If a hosted zone exists, inspect it:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id ZXXXXXXXXXXXX \
  --output table
```

At this stage, don't modify anything. We're building the habit:

```text
OBSERVE
   ↓
UNDERSTAND
   ↓
THEN CHANGE
```

---

# 56. Production Troubleshooting Flow

User says:

> “`api.example.com` doesn't work.”

Use this flow:

```text
1. Does DNS name resolve?

          │
          ▼
dig api.example.com


2. Correct authoritative NS?

          │
          ▼
dig NS example.com


3. Correct record type/value?

          │
          ▼
A / AAAA / Alias / CNAME


4. Old cached answer?

          │
          ▼
check TTL


5. Ask authoritative server directly

          │
          ▼
dig @authoritative-server


6. DNS correct?

          │
          ▼
NOW troubleshoot application:

ALB
SG
listener
target group
EC2
app
```

This separates:

```text
DNS FAILURE
```

from:

```text
APPLICATION FAILURE
```

---

# 57. Scenario — Route 53 Shows Correct Record, Internet Shows Old IP

Most likely first thought:

```text
DNS CACHE / TTL
```

Check:

```bash
dig example.com
```

and:

```bash
dig @authoritative-name-server example.com
```

If authoritative DNS has the new value but recursive DNS still returns the old one:

```text
TTL/cache
```

is the likely explanation.

Route 53 authoritative changes generally reach its name servers quickly, while recursive resolvers can keep previously cached answers until TTL expires. ([AWS Documentation][14])

---

# 58. Scenario — Route 53 Record Exists but Nobody Sees It

Check:

```bash
dig NS example.com
```

If internet delegation points to another provider:

```text
Route 53 hosted zone
=
not authoritative
```

Creating records in an unused hosted zone changes nothing for internet clients.

This is one of the most common Route 53 mistakes.

---

# 59. Scenario — Need `example.com` → ALB

Don't create:

```text
CNAME example.com
```

because apex CNAME is not valid.

Use:

```text
A
Alias = Yes
Target = ALB
```

Route 53 Alias records are designed specifically for this type of zone-apex AWS routing. ([AWS Documentation][10])

---

# 60. Scenario — Need `www.example.com` → CloudFront

You technically have multiple DNS options depending on DNS provider, but with Route 53 the typical AWS-native choice is:

```text
A / AAAA Alias
       │
       ▼
CloudFront
```

Route 53 explicitly supports Alias routing to CloudFront for both root domains and subdomains. ([AWS Documentation][11])

---

# 61. Scenario — ALB IP Changed

Your architecture uses:

```text
A record
→ hardcoded old ALB IP
```

That's the wrong model.

Use:

```text
Route 53 Alias
→ ALB DNS resource
```

Route 53 tracks the AWS-resource target rather than depending on you to manage its changing IP addresses manually. ([AWS Documentation][10])

---

# 62. Scenario — Changed DNS but User Still Resolves Deleted Record

Check TTL.

If the answer is:

```text
cached
```

Route 53 cannot remotely force every recursive resolver on the internet to immediately forget its previously valid cached answer.

That is why planned migrations often lower TTL **before** the change, allow the old higher TTL to expire, and only then perform the cutover. AWS's migration guidance explicitly includes lowering TTL before changing authoritative DNS. ([AWS Documentation][3])

---

# 63. Scenario — Record Was Missing, Added It, Still NXDOMAIN

Think:

```text
negative caching
```

The resolver may have cached the earlier:

```text
NXDOMAIN
```

response.

Route 53's SOA settings govern negative-cache behavior. ([AWS Documentation][9])

---

# 64. SAA-C03 Quick Questions

| Requirement                      | First thought           |
| -------------------------------- | ----------------------- |
| Domain → IPv4                    | **A**                   |
| Domain → IPv6                    | **AAAA**                |
| Subdomain → another hostname     | **CNAME**               |
| Apex → ALB                       | **Route 53 Alias**      |
| Apex → CloudFront                | **Route 53 Alias**      |
| Email destination                | **MX**                  |
| Text/domain verification         | **TXT**                 |
| Restrict certificate authorities | **CAA**                 |
| Authoritative name servers       | **NS**                  |
| Zone authority metadata          | **SOA**                 |
| Internet DNS                     | **Public Hosted Zone**  |
| Internal VPC DNS                 | **Private Hosted Zone** |
| Cache time at recursive resolver | **TTL**                 |

These record behaviors and hosted-zone roles are defined by Route 53's current DNS implementation. ([AWS Documentation][8])

---

# 65. Never-Forget DNS Diagram

```text
                     APPLICATION USER
                           │
                           ▼
                   www.example.com
                           │
                           ▼
                      DNS CACHE
                           │
                           ▼
                 RECURSIVE RESOLVER
                           │
                           ▼
                         ROOT
                           │
                           ▼
                       .com TLD
                           │
                           ▼
                 AUTHORITATIVE DNS
                      Route 53
                           │
                    Hosted Zone
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
              A           Alias        MX/TXT
              │            │
              ▼            ▼
             IP      CloudFront / ALB
```

---

# 66. The 18 Rules to Permanently Remember

```text
1. DNS translates human-friendly names into
   information clients use to reach services.

2. DNS resolution normally involves a recursive resolver.

3. Root DNS directs toward the appropriate TLD.

4. TLD DNS directs toward the domain's authoritative servers.

5. Route 53 can be the authoritative DNS provider.

6. Registrar and DNS provider are different roles.

7. Your domain can be registered elsewhere
   while Route 53 hosts DNS.

8. Hosted Zone = DNS namespace/record container.

9. Public Hosted Zone = internet DNS.

10. Private Hosted Zone = VPC/private DNS.

11. NS records identify authoritative name servers.

12. A = IPv4.

13. AAAA = IPv6.

14. CNAME = name → another DNS name.

15. Standard CNAME cannot exist at the zone apex.

16. Route 53 Alias can route an apex to supported AWS resources.

17. TTL controls resolver caching.

18. Route 53 update time and recursive resolver
    cache expiration are two different things.
```

And perhaps the most useful troubleshooting rule:

```text
IF THE NAME DOES NOT RESOLVE,

DO NOT START TROUBLESHOOTING
THE APPLICATION SERVER.
```

First fix:

```text
DNS.
```

---

# ✅ Lesson 29 Part 1 Complete

You now understand:

```text
✓ DNS purpose
✓ DNS vs HTTP/TLS
✓ recursive resolver
✓ authoritative DNS
✓ root DNS
✓ TLD
✓ registrar vs DNS provider
✓ Route 53 responsibilities
✓ public hosted zones
✓ private hosted zones
✓ current Route 53 VPC Resolver terminology
✓ NS records
✓ SOA
✓ negative caching
✓ A
✓ AAAA
✓ CNAME
✓ zone apex
✓ Route 53 Alias
✓ Alias vs CNAME
✓ Alias → ALB
✓ Alias → CloudFront
✓ MX
✓ TXT
✓ CAA
✓ DS preview
✓ modern HTTPS/SVCB records
✓ TTL
✓ DNS caching
✓ Route 53 propagation vs resolver TTL
✓ `dig`
✓ `dig +trace`
✓ authoritative queries
✓ NXDOMAIN
✓ production DNS troubleshooting
```

# Next — Lesson 29 Part 2

# **Route 53 Routing Policies, Health Checks & DNS Failover**

Now we'll turn Route 53 from a simple DNS database into a traffic-management system:

```text
                       Route 53
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
        ▼                 ▼                  ▼
      SIMPLE           WEIGHTED           FAILOVER
                          │                  │
                       90 / 10          Primary/Secondary

        ┌─────────────────┼──────────────────┐
        ▼                 ▼                  ▼
     LATENCY         GEOLOCATION        GEOPROXIMITY

        ┌─────────────────┼──────────────────┐
        ▼                 ▼                  ▼
     IP-BASED        MULTIVALUE          HEALTH CHECKS
```

We'll build real scenarios such as:

```text
Blue → 90%
Green → 10%
```

for canary releases;

```text
Mumbai
vs
Singapore
```

for latency routing;

```text
Primary ALB
   X
Secondary ALB
```

for DNS failover;

and we'll dissect **TTL during failover, Evaluate Target Health, CloudWatch-based health checks, calculated health checks, fail-open behavior, multivalue answers, geolocation vs geoproximity, weighted zero traffic, active-active vs active-passive, Terraform, and a full multi-Region Route 53 lab**.

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html "What is Amazon Route 53? - Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/route-53-concepts.html "Amazon Route 53 concepts - Amazon Route 53"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html?utm_source=chatgpt.com "Making Route 53 the DNS service for a domain that's in use"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-name-servers-glue-records.html?utm_source=chatgpt.com "Adding or changing name servers and glue records for a domain"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html?utm_source=chatgpt.com "Working with hosted zones - Amazon Route 53"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html "Supported DNS record types - Amazon Route 53"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/SOA-NSrecords.html "NS and SOA records that Amazon Route 53 creates for a public hosted zone - Amazon Route 53"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html?utm_source=chatgpt.com "Choosing between alias and non-alias records"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-cloudfront-distribution.html?utm_source=chatgpt.com "Routing traffic to an Amazon CloudFront distribution by using ..."
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html?utm_source=chatgpt.com "Routing traffic to an ELB load balancer - Amazon Route 53"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-dns.html?utm_source=chatgpt.com "Best practices for Amazon Route 53 DNS"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-creating.html?utm_source=chatgpt.com "Creating records by using the Amazon Route 53 console"
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html "Choosing a routing policy - Amazon Route 53"
