# AWS Masterclass — Phase 3

# Lesson 27: Amazon Route 53 and Production DNS

## 1. Lesson objective

In this lesson, you will learn how to:

* Understand DNS from browser to authoritative server.
* Register and delegate a domain.
* Create public and private hosted zones.
* Configure A, AAAA, CNAME, MX, TXT, NS and alias records.
* Connect a domain to an ALB, CloudFront distribution, S3 website or API.
* Choose the correct TTL.
* Use simple, weighted, latency, failover, geolocation, geoproximity, IP-based and multivalue routing.
* Configure DNS health checks and failover.
* Design hybrid DNS with Route 53 Resolver.
* Enable DNSSEC.
* Troubleshoot common production DNS failures.
* Manage Route 53 using Terraform and AWS CLI.

---

# 2. What is Amazon Route 53?

Amazon Route 53 provides three major groups of functionality:

```text
1. Domain registration
2. Authoritative DNS
3. Health checking and traffic routing
```

Route 53 can also provide recursive DNS resolution inside VPCs and hybrid DNS forwarding through Route 53 Resolver. ([AWS Documentation][1])

## Mental model

```text
Domain registrar:
Who owns the domain?

Authoritative DNS:
What records exist for the domain?

DNS resolver:
Find the answer for the client.

Health check:
Is the destination healthy?

Routing policy:
Which destination should receive the request?
```

---

# 3. Route 53 does not route HTTP traffic

The name “Route 53” can be confusing.

Route 53 does not normally proxy the user’s HTTP request. It answers DNS questions.

```text
Question:
What is the IP address or destination for app.example.com?

Route 53 answer:
Use this load balancer, CloudFront distribution or IP address.
```

After DNS resolution:

```text
Browser
   |
   | DNS query
   v
Route 53
   |
   | DNS answer
   v
Browser
   |
   | HTTPS request
   v
CloudFront / ALB / application
```

## Never-forget distinction

```text
Route 53:
Tells the client where to connect.

CloudFront:
Receives and caches application traffic.

ALB:
Receives and distributes application traffic.

EC2:
Processes application traffic.
```

---

# 4. How DNS resolution works

Suppose a user opens:

```text
https://app.yourdatascientist.tech
```

A simplified lookup is:

```text
Browser DNS cache
        ↓
Operating-system DNS cache
        ↓
Recursive resolver
        ↓
Root DNS server
        ↓
.tech TLD name server
        ↓
Authoritative name servers for yourdatascientist.tech
        ↓
Route 53 returns the record
        ↓
Browser connects to the destination
```

## Roles

### Stub resolver

The DNS client in the user’s operating system.

### Recursive resolver

A DNS service that performs lookups on behalf of the client.

Examples include:

```text
ISP resolver
Corporate resolver
Public DNS resolver
VPC Resolver
```

### Root name servers

Direct the resolver toward the relevant top-level domain.

### TLD name servers

For `.tech`, these servers identify the authoritative name servers configured for the domain.

### Authoritative name server

Stores the actual DNS records for the domain.

Route 53 becomes authoritative when the domain is delegated to the name servers assigned to its public hosted zone.

---

# 5. Domain registration versus hosted zone

These are separate resources.

## Domain registration

Registration establishes control of a domain such as:

```text
yourdatascientist.tech
```

The registrar maintains details such as:

* Domain owner or registrant.
* Renewal configuration.
* Registration status.
* Name-server delegation.
* Domain lock.
* DNSSEC delegation information.

## Hosted zone

A hosted zone is a container for DNS records belonging to a domain and its subdomains. The hosted-zone name normally matches the domain name. ([AWS Documentation][2])

Example:

```text
Hosted zone:
yourdatascientist.tech

Records:
yourdatascientist.tech
www.yourdatascientist.tech
api.yourdatascientist.tech
jenkins.yourdatascientist.tech
```

## Important distinction

```text
You can register a domain outside AWS
and still host DNS in Route 53.

You can register a domain in Route 53
and host its DNS somewhere else.
```

---

# 6. Public hosted zone

A public hosted zone contains DNS records that are intended to be resolved from the internet. ([AWS Documentation][3])

Example:

```text
Public hosted zone:
yourdatascientist.tech
```

Possible records:

```text
yourdatascientist.tech        → CloudFront
www.yourdatascientist.tech    → CloudFront
api.yourdatascientist.tech    → ALB
mail.yourdatascientist.tech   → mail provider
```

When Route 53 creates a public hosted zone, it automatically creates:

```text
NS record
SOA record
```

A new public hosted zone is normally assigned a unique delegation set containing four authoritative name servers. ([AWS Documentation][4])

Example:

```text
ns-123.awsdns-45.com
ns-678.awsdns-90.net
ns-111.awsdns-22.org
ns-333.awsdns-44.co.uk
```

These are examples only. You must use the exact name servers assigned to your hosted zone.

---

# 7. Domain delegation

Delegation means configuring the parent DNS system to direct queries to your authoritative name servers.

For your domain:

```text
Parent:
.tech registry

Delegation:
yourdatascientist.tech uses these four Route 53 name servers
```

If the domain is registered outside AWS:

1. Create the public hosted zone in Route 53.
2. Copy the four Route 53 name servers.
3. Open the registrar’s control panel.
4. Replace the registrar’s current name servers.
5. Wait for caches and registry updates.
6. Verify delegation before deleting the old DNS zone.

AWS recommends confirming that the new name servers answer correctly before cancelling the old DNS provider or deleting the previous hosted zone. ([AWS Documentation][5])

## Verify delegation

```bash
dig NS yourdatascientist.tech
```

Query one authoritative server directly:

```bash
dig @ns-123.awsdns-45.com \
  api.yourdatascientist.tech A
```

Trace the delegation chain:

```bash
dig +trace yourdatascientist.tech
```

---

# 8. NS record

NS stands for:

```text
Name Server
```

It identifies the authoritative name servers for a DNS zone.

Example:

```dns
yourdatascientist.tech.  NS  ns-123.awsdns-45.com.
yourdatascientist.tech.  NS  ns-678.awsdns-90.net.
```

## Do not casually edit the hosted-zone NS record

The registrar delegation and the hosted-zone NS record must correspond.

A mismatch can produce:

```text
Registrar delegates to name servers A, B, C, D

Hosted zone expected or uses a different delegation set

Result:
DNS failures or inconsistent answers
```

---

# 9. SOA record

SOA stands for:

```text
Start of Authority
```

It contains administrative information about the DNS zone, including:

* Primary authoritative server.
* Responsible-party representation.
* Serial-related information.
* Refresh and retry values.
* Negative caching information.

Route 53 manages the SOA record automatically for the hosted zone.

Do not delete it.

---

# 10. A record

An A record maps a hostname to an IPv4 address.

```dns
server.yourdatascientist.tech.  A  203.0.113.10
```

Use an A record for:

* Static public IPv4 addresses.
* Elastic IP addresses.
* IPv4 endpoints.
* Alias records representing IPv4-capable AWS resources.

## Warning for ordinary EC2 public IPs

A normal EC2 public IPv4 address can change after stop and start.

Use:

```text
Elastic IP
Load balancer
CloudFront
```

instead of depending on an unstable public IP.

---

# 11. AAAA record

An AAAA record maps a hostname to an IPv6 address.

```dns
server.yourdatascientist.tech.  AAAA  2001:db8::10
```

When using an AWS alias target that supports IPv6, you commonly create:

```text
A alias record
AAAA alias record
```

This enables both IPv4 and IPv6 DNS resolution.

---

# 12. CNAME record

A CNAME record maps one hostname to another hostname.

```dns
blog.yourdatascientist.tech. CNAME hosting-provider.example.com.
```

A CNAME says:

```text
blog.yourdatascientist.tech is another name for
hosting-provider.example.com
```

## CNAME limitation at the zone apex

You cannot normally place a CNAME at the zone apex:

```text
yourdatascientist.tech
```

This is because the zone apex must also contain records such as NS and SOA, while a CNAME cannot coexist with those record types.

Route 53 alias records solve this problem for supported destinations. ([AWS Documentation][6])

---

# 13. Alias record

An alias record is a Route 53 feature that can direct DNS queries to supported AWS resources.

Common alias targets include:

* Application Load Balancers.
* Network Load Balancers.
* Classic Load Balancers.
* CloudFront distributions.
* API Gateway APIs.
* S3 website endpoints.
* Global Accelerator.
* Another Route 53 record in the same hosted zone.

Route 53 alias records can be created at the zone apex, unlike ordinary CNAME records. ([AWS Documentation][6])

## Example: apex to CloudFront

```text
yourdatascientist.tech
        |
        | A alias
        v
d123example.cloudfront.net
```

## Example: API to ALB

```text
api.yourdatascientist.tech
        |
        | A alias
        v
production-alb-123.ap-south-1.elb.amazonaws.com
```

## Alias versus CNAME

| Feature                        | Alias                         | CNAME       |
| ------------------------------ | ----------------------------- | ----------- |
| Standard DNS record            | AWS-specific feature          | Yes         |
| Allowed at zone apex           | Yes, for supported targets    | No          |
| Routes to AWS resources        | Yes                           | By hostname |
| TTL configured manually        | Usually inherited from target | Yes         |
| Can return A/AAAA-style answer | Yes                           | No          |
| Available outside Route 53     | No                            | Yes         |

For alias records, the TTL is determined by the AWS alias target rather than being entered directly as a normal record TTL. ([AWS Documentation][7])

---

# 14. MX record

MX stands for:

```text
Mail Exchange
```

It identifies mail servers responsible for receiving email for a domain.

Example:

```dns
yourdatascientist.tech. MX 10 mail1.example.com.
yourdatascientist.tech. MX 20 mail2.example.com.
```

Lower preference numbers have higher priority:

```text
10 → preferred
20 → secondary
```

Do not create an MX record pointing directly to an IP address. It must point to a hostname.

---

# 15. TXT record

TXT records store arbitrary text.

Common uses:

* Domain ownership verification.
* SPF email policies.
* DKIM information.
* DMARC policies.
* Service verification.
* Certificate validation.

Examples:

```dns
yourdatascientist.tech. TXT "v=spf1 include:example.com -all"
```

```dns
_dmarc.yourdatascientist.tech. TXT \
"v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

For ACM DNS validation, AWS normally asks you to create a specific CNAME record rather than manually proving ownership through a general TXT record.

---

# 16. TTL — Time to Live

TTL specifies how long recursive resolvers may cache a DNS answer before asking the authoritative DNS server again.

Example:

```text
TTL = 300 seconds
```

A resolver may reuse the cached answer for approximately five minutes.

AWS describes TTL as the number of seconds a resolver caches a record before requesting the latest value again. ([AWS Documentation][8])

## Low TTL

Example:

```text
60 seconds
```

Advantages:

* Faster DNS changes.
* Faster failover convergence.
* Useful before migrations.

Disadvantages:

* More DNS queries.
* Less caching.
* Clients query authoritative DNS more frequently.
* It still does not guarantee immediate change.

## High TTL

Example:

```text
3600 seconds
```

Advantages:

* More resolver caching.
* Fewer authoritative DNS queries.
* Stable records work efficiently.

Disadvantages:

* Changes take longer to become visible.
* Old values can remain cached after migration.

Longer TTLs improve caching efficiency but increase the time that previous answers may remain in recursive resolvers. ([AWS Documentation][8])

## Practical guidance

| Situation                  |                        Starting TTL |
| -------------------------- | ----------------------------------: |
| Preparing migration        |                      60–300 seconds |
| Active failover DNS        |                       30–60 seconds |
| Normal application record  |                         300 seconds |
| Stable verification record |                    300–3600 seconds |
| Stable MX or TXT records   |                        3600 seconds |
| NS delegation              | Usually keep provider/default value |

Before a planned migration:

```text
1. Lower TTL in advance.
2. Wait for the old TTL period to pass.
3. Make the DNS change.
4. Validate globally.
5. Restore a longer TTL later.
```

---

# 17. Why DNS changes are not immediate

A Route 53 change can become authoritative quickly while users continue receiving an older answer.

Why?

```text
Old record:
203.0.113.10
TTL:
3600 seconds

Resolver cached it five minutes before the change.

Remaining cache time:
55 minutes
```

During those 55 minutes, the resolver may continue returning the old value.

Other possible caches include:

```text
Browser cache
Operating-system cache
Corporate resolver
ISP resolver
Local application cache
Java DNS cache
Container runtime
```

A DNS console showing the new value does not prove that every user is receiving it.

---

# 18. Simple routing policy

Simple routing is used when one record points to one resource or one ordinary set of values.

```text
api.yourdatascientist.tech
        ↓
Production ALB
```

Use simple routing when:

* There is one application destination.
* You do not need percentage routing.
* You do not need geographic selection.
* You do not need DNS-level failover logic.

Terraform:

```hcl
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "api.yourdatascientist.tech"
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
```

---

# 19. Weighted routing policy

Weighted routing distributes DNS answers according to relative weights.

Example:

```text
Version A weight: 90
Version B weight: 10
```

Approximate DNS selection:

```text
90% → Version A
10% → Version B
```

Weighted routing is useful for:

* Canary releases.
* Blue/green migrations.
* Controlled traffic shifting.
* A/B experiments.
* Multi-provider distribution.

AWS defines weighted routing as associating multiple resources with the same name and controlling how much traffic is directed to each. ([AWS Documentation][9])

## Important limitation

Weighted DNS routing does not guarantee exact request percentages.

Why?

```text
One recursive resolver asks Route 53 once.
Route 53 returns Version A.
Thousands of clients behind that resolver reuse the answer.
```

The observed HTTP traffic distribution may therefore differ from the configured DNS weight.

## Terraform example

```hcl
resource "aws_route53_record" "blue" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "app.yourdatascientist.tech"
  type    = "A"

  set_identifier = "blue"
  weighted_routing_policy {
    weight = 90
  }

  alias {
    name                   = aws_lb.blue.dns_name
    zone_id                = aws_lb.blue.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "app.yourdatascientist.tech"
  type    = "A"

  set_identifier = "green"
  weighted_routing_policy {
    weight = 10
  }

  alias {
    name                   = aws_lb.green.dns_name
    zone_id                = aws_lb.green.zone_id
    evaluate_target_health = true
  }
}
```

---

# 20. Latency-based routing

Latency routing is used when resources exist in multiple AWS Regions and you want Route 53 to direct users toward the Region expected to provide better latency.

```text
Mumbai user
    ↓
ap-south-1

Singapore user
    ↓
ap-southeast-1

European user
    ↓
eu-west-1
```

Route 53 makes the decision using latency information between the user’s DNS resolver location and AWS Regions. It is not a direct, real-time speed test from the individual browser to every application endpoint. ([AWS Documentation][10])

Use it for:

* Active-active multi-Region applications.
* Global APIs.
* Regionally distributed websites.
* Low-latency user experiences.

## Important requirement

The application data layer must also support multi-Region operation.

DNS alone cannot solve:

* Database replication.
* Session consistency.
* Cross-Region writes.
* Conflict resolution.
* Regional deployment consistency.

---

# 21. Failover routing policy

Failover routing uses:

```text
Primary record
Secondary record
Health evaluation
```

Architecture:

```text
Primary:
ap-south-1 application
        |
        | unhealthy
        v
Secondary:
ap-southeast-1 application
```

## Normal condition

```text
Primary healthy
    ↓
Route 53 returns primary
```

## Failure condition

```text
Primary unhealthy
    ↓
Route 53 returns secondary
```

Route 53 can use direct health checks or alias target-health evaluation to decide which records should be returned. ([AWS Documentation][11])

## Critical warning

Failover routing does not move application data.

You must separately prepare:

* Secondary infrastructure.
* Database recovery or replication.
* Application artifacts.
* Secrets.
* Certificates.
* IAM roles.
* DNS targets.
* Operational promotion procedures.

---

# 22. Geolocation routing

Geolocation routing selects a resource based on the geographic location from which the DNS query appears to originate.

Possible rules include:

```text
India
United States
European continent
Default location
```

Use cases:

* Localized content.
* Regional legal requirements.
* Language-specific applications.
* Region-specific products.
* Data-sovereignty routing.

## Always configure a default record

Route 53 may not be able to map every client to a configured geographic rule.

Without a default record, some queries might receive no applicable answer.

---

# 23. Geoproximity routing

Geoproximity routing considers both:

* User location.
* Resource location.

It can also apply a bias to expand or shrink the geographic area routed to a resource. ([AWS Documentation][12])

Example:

```text
Mumbai resource:
Bias +20

Singapore resource:
Bias 0
```

The positive bias can make the Mumbai resource receive traffic from a larger geographic area.

Use geoproximity when you need more control than simple country or continent rules.

---

# 24. IP-based routing

IP-based routing lets you define mappings based on the source IP network associated with DNS queries.

Example concept:

```text
203.0.113.0/24 → application endpoint A
198.51.100.0/24 → application endpoint B
Default         → application endpoint C
```

Use cases:

* Directing known corporate networks.
* ISP-specific routing.
* Partner-specific endpoints.
* Network-aware application delivery.

This differs from geolocation routing because you define CIDR mappings rather than relying only on geographic classification. ([AWS Documentation][10])

---

# 25. Multivalue answer routing

Multivalue routing returns multiple healthy values in a DNS response.

Example:

```text
api.yourdatascientist.tech

Possible answers:
203.0.113.10
203.0.113.20
203.0.113.30
```

Each resource can have a health check, and Route 53 can omit unhealthy values from the response. ([AWS Documentation][13])

## Important distinction

Multivalue routing is not a replacement for an Application Load Balancer.

An ALB provides:

* Layer 7 request routing.
* TLS termination.
* Per-request health-aware distribution.
* Host and path routing.
* Connection management.
* WAF integration.

Multivalue DNS provides multiple DNS answers but does not proxy or balance every request itself.

---

# 26. Choosing the routing policy

| Requirement                              | Routing policy |
| ---------------------------------------- | -------------- |
| One destination                          | Simple         |
| Percentage rollout                       | Weighted       |
| Lowest expected Regional latency         | Latency        |
| Primary and disaster-recovery endpoint   | Failover       |
| Country or continent rules               | Geolocation    |
| Distance plus adjustable geographic bias | Geoproximity   |
| Known CIDR-based source mapping          | IP-based       |
| Multiple healthy IP answers              | Multivalue     |

AWS currently documents simple, weighted, latency, failover, geolocation, geoproximity, IP-based and multivalue routing options. ([AWS Documentation][10])

---

# 27. Route 53 health checks

Route 53 health checks can monitor:

1. A specified endpoint.
2. The state of other health checks.
3. A CloudWatch alarm or its underlying metric stream.

Endpoint health checks can use protocols such as:

```text
HTTP
HTTPS
TCP
```

You configure values such as request interval and failure threshold. ([AWS Documentation][14])

## Example endpoint

```text
https://health.yourdatascientist.tech/health
```

Expected response:

```http
HTTP/1.1 200 OK
```

## Health-check flow

```text
Route 53 health checkers
        ↓
Request /health
        ↓
Application responds
        ↓
Route 53 determines health state
        ↓
DNS routing policy includes or excludes record
```

Route 53 health-check metrics are available through CloudWatch, and CloudWatch alarms can notify through SNS. ([AWS Documentation][15])

---

# 28. Health checking an ALB alias

For an alias record pointing to an ALB, you can configure:

```hcl
evaluate_target_health = true
```

This instructs Route 53 to evaluate the health of the alias target.

```hcl
alias {
  name                   = aws_lb.app.dns_name
  zone_id                = aws_lb.app.zone_id
  evaluate_target_health = true
}
```

When evaluating an ELB alias target, Route 53 uses the target resource’s health information rather than requiring a separate endpoint health check for every ordinary alias configuration. ([AWS Documentation][11])

## Distinguish two health layers

```text
ALB target-group health:
Should this EC2 instance receive requests?

Route 53 DNS health:
Should this entire ALB or Regional endpoint be returned?
```

---

# 29. Calculated health checks

A calculated health check combines multiple child health checks.

Example:

```text
API health          = healthy
Database health     = healthy
Dependency health   = unhealthy
```

You can define:

```text
Overall healthy when at least 2 of 3 checks are healthy.
```

Use this when a service should remain available despite a noncritical component failure.

Avoid making DNS failover depend on every optional dependency.

A minor third-party outage should not necessarily cause an entire Region to be removed from DNS.

---

# 30. DNS failover is not instantaneous

Even after Route 53 changes its authoritative response:

```text
Some resolvers still have the previous answer cached.
```

Failover time includes:

```text
Health-check detection time
Failure threshold
Route 53 record-selection change
Resolver TTL expiration
Application reconnection
Secondary system readiness
```

Therefore:

```text
DNS failover RTO ≠ only health-check detection time
```

Use low but reasonable TTLs for failover records and test using real resolvers.

---

# 31. Public versus private hosted zones

## Public hosted zone

Answers DNS queries from the internet.

```text
api.yourdatascientist.tech
        ↓
Public ALB
```

## Private hosted zone

Answers DNS queries only within associated VPCs through Route 53 VPC Resolver.

```text
database.internal.yourdatascientist.tech
        ↓
Private database endpoint
```

A private hosted zone can be associated with one or more VPCs, including supported cross-account association workflows. ([AWS Documentation][16])

---

# 32. Private hosted-zone architecture

```text
VPC A
├── EC2 application
├── ECS services
└── Route 53 VPC Resolver
          |
          v
Private hosted zone:
internal.yourdatascientist.tech

Records:
api.internal.yourdatascientist.tech
database.internal.yourdatascientist.tech
monitoring.internal.yourdatascientist.tech
```

These names are not normally resolvable from the public internet.

Example Terraform:

```hcl
resource "aws_route53_zone" "private" {
  name = "internal.yourdatascientist.tech"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Environment = "production"
  }
}
```

Private hosted zones rely on VPC Resolver and must be associated with the VPCs that should resolve their records. ([AWS Documentation][17])

---

# 33. Split-view DNS

You can create both:

```text
Public hosted zone:
yourdatascientist.tech

Private hosted zone:
yourdatascientist.tech
```

Then the same hostname can return different answers depending on where the query originates.

Example:

```text
From internet:
api.yourdatascientist.tech → public ALB

From VPC:
api.yourdatascientist.tech → internal ALB
```

This is called:

```text
Split-view DNS
Split-horizon DNS
```

## Warning

The private hosted zone takes authority for matching names inside associated VPCs.

If a name exists only in the public zone but the private zone covers the same namespace, resolution may not automatically fall through in the way you expect.

Create all required private records or carefully delegate subdomains.

---

# 34. Route 53 VPC Resolver

VPC Resolver provides recursive DNS resolution for resources in a VPC.

It can resolve:

* Public DNS names.
* Private hosted-zone records.
* EC2 internal hostnames.
* Names forwarded through Resolver rules.
* Supported AWS service names.

Route 53 Resolver also supports hybrid DNS through inbound and outbound endpoints. ([AWS Documentation][18])

---

# 35. Inbound Resolver endpoint

An inbound endpoint allows DNS servers outside the VPC to send queries into VPC Resolver.

Architecture:

```text
On-premises DNS
        |
        | VPN or Direct Connect
        v
Resolver inbound endpoint
        |
        v
Route 53 private hosted zone
```

Example requirement:

```text
On-premises server must resolve:
database.internal.yourdatascientist.tech
```

The on-premises DNS server forwards that namespace to the private IP addresses of the inbound endpoint. These endpoint IPs are reachable through private network connectivity, not the public internet. ([AWS Documentation][19])

---

# 36. Outbound Resolver endpoint

An outbound endpoint lets resources in AWS forward selected DNS queries to external DNS servers.

Architecture:

```text
EC2 in AWS
    |
    | query: server.corp.local
    v
VPC Resolver
    |
    | forwarding rule
    v
Resolver outbound endpoint
    |
    | VPN or Direct Connect
    v
On-premises DNS server
```

Example rule:

```text
Domain:
corp.local

Forward to:
10.50.0.10
10.50.0.11
```

Resolver rules can be shared across accounts using AWS Resource Access Manager in larger multi-account environments.

For high availability, Resolver endpoints should use IP addresses in multiple subnets and Availability Zones. ([AWS Documentation][20])

---

# 37. Hybrid DNS design

A typical hybrid architecture:

```text
On-premises network
├── Active Directory DNS
└── corp.local
         |
         | VPN / Direct Connect
         |
AWS VPC
├── Resolver inbound endpoint
├── Resolver outbound endpoint
├── Private hosted zone
│   └── aws.corp.example
└── EC2 / ECS / EKS
```

Resolution directions:

```text
On-prem → AWS private names
Use inbound endpoint

AWS → on-prem names
Use outbound endpoint plus forwarding rule
```

---

# 38. DNSSEC

DNSSEC stands for:

```text
Domain Name System Security Extensions
```

DNSSEC allows validating resolvers to verify that DNS answers:

* Came from the expected authoritative zone.
* Were not modified in transit.

It uses digital signatures and a chain of trust rather than encrypting DNS content. Route 53 supports hosted-zone DNSSEC signing and DNSSEC configuration for registered domains. ([AWS Documentation][21])

## DNSSEC does not provide

```text
DNS query confidentiality
Website TLS
DDoS protection by itself
Application authentication
```

## Simplified chain

```text
Root
  ↓
.tech
  ↓
DS record for yourdatascientist.tech
  ↓
Route 53 hosted-zone signing key
  ↓
Signed DNS records
```

## Critical warning

An incorrect DNSSEC chain can make the entire domain appear nonexistent or invalid to validating resolvers.

Enable it through a controlled process:

```text
1. Prepare KMS and key-signing configuration.
2. Enable hosted-zone signing.
3. Confirm signing status is INSYNC.
4. Publish the DS record through the parent or registrar.
5. Validate externally.
6. Monitor DNSSEC health.
```

AWS specifically warns that DNSSEC errors should be resolved quickly to prevent hosted-zone availability problems. ([AWS Documentation][21])

---

# 39. Connecting Route 53 to CloudFront

For a CloudFront distribution:

```text
yourdatascientist.tech
www.yourdatascientist.tech
        |
        | Route 53 alias
        v
CloudFront distribution
```

You need:

1. ACM certificate in `us-east-1`.
2. Domain listed as an alternate domain name on CloudFront.
3. Route 53 A alias record.
4. Route 53 AAAA alias record when IPv6 is enabled.
5. CloudFront distribution deployed successfully.

Terraform:

```hcl
resource "aws_route53_record" "apex_cloudfront_ipv4" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "yourdatascientist.tech"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_cloudfront_ipv6" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "yourdatascientist.tech"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
```

---

# 40. Connecting Route 53 to an ALB

Architecture:

```text
api.yourdatascientist.tech
        |
        | Route 53 A alias
        v
Application Load Balancer
        |
        v
Target group
        |
        v
EC2 Auto Scaling instances
```

Terraform:

```hcl
resource "aws_route53_record" "api_alb" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "api.yourdatascientist.tech"
  type    = "A"

  alias {
    name                   = aws_lb.application.dns_name
    zone_id                = aws_lb.application.zone_id
    evaluate_target_health = true
  }
}
```

Do not create an A record containing the current IP addresses of an ALB.

Load-balancer IP addresses can change. Always use its DNS name through an alias record.

---

# 41. Creating records with AWS CLI

Create a simple A record:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Comment": "Create application record",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "server.yourdatascientist.tech",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "203.0.113.10"
            }
          ]
        }
      }
    ]
  }'
```

Check change status:

```bash
aws route53 get-change \
  --id /change/C1234567890ABC
```

Expected transition:

```text
PENDING
   ↓
INSYNC
```

`INSYNC` means Route 53’s authoritative DNS system has applied the change. It does not mean every recursive resolver has discarded its previous cached value.

---

# 42. Terraform hosted-zone example

```hcl
resource "aws_route53_zone" "public" {
  name = "yourdatascientist.tech"

  tags = {
    Name        = "yourdatascientist.tech"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

output "route53_name_servers" {
  value = aws_route53_zone.public.name_servers
}
```

## Important warning

Creating another hosted zone with the same domain produces another hosted-zone ID and commonly another delegation set.

```text
Old hosted zone:
Name servers A, B, C, D

New hosted zone:
Name servers E, F, G, H
```

If the registrar still delegates to A, B, C and D, records placed only in the new zone will not be used.

Always verify:

```bash
dig NS yourdatascientist.tech
```

against:

```bash
terraform output route53_name_servers
```

---

# 43. Import an existing hosted zone into Terraform

Find the zone:

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name yourdatascientist.tech
```

Import:

```bash
terraform import \
  aws_route53_zone.public \
  Z1234567890ABC
```

Then run:

```bash
terraform plan
```

Importing the hosted zone does not automatically import every existing DNS record.

Records normally need separate Terraform resources and imports or a carefully controlled migration process.

---

# 44. Useful DNS troubleshooting commands

## `dig`

```bash
dig api.yourdatascientist.tech
```

## Query a specific record type

```bash
dig api.yourdatascientist.tech A
dig api.yourdatascientist.tech AAAA
dig yourdatascientist.tech MX
dig yourdatascientist.tech TXT
dig yourdatascientist.tech NS
```

## Show concise answer

```bash
dig +short api.yourdatascientist.tech
```

## Query a specific resolver

```bash
dig @8.8.8.8 api.yourdatascientist.tech
```

```bash
dig @1.1.1.1 api.yourdatascientist.tech
```

## Query an authoritative name server

```bash
dig @ns-123.awsdns-45.com \
  api.yourdatascientist.tech
```

## Trace delegation

```bash
dig +trace yourdatascientist.tech
```

## `nslookup`

```bash
nslookup api.yourdatascientist.tech
```

## `host`

```bash
host api.yourdatascientist.tech
```

## Check HTTP destination

```bash
curl -I https://api.yourdatascientist.tech
```

## Test certificate and TLS

```bash
openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech
```

---

# 45. Troubleshooting: `NXDOMAIN`

`NXDOMAIN` means:

```text
The queried name does not exist according to DNS.
```

Possible causes:

* Record was never created.
* Wrong hosted zone.
* Incorrect hostname.
* Public and private hosted-zone conflict.
* Domain delegates to different name servers.
* Record was deleted.
* Negative answer remains cached.

Check:

```bash
dig NS yourdatascientist.tech
```

Then query the authoritative server:

```bash
dig @<authoritative-name-server> \
  api.yourdatascientist.tech
```

---

# 46. Troubleshooting: `SERVFAIL`

`SERVFAIL` means the resolver could not obtain or validate a usable answer.

Possible causes:

* DNSSEC validation failure.
* Broken authoritative delegation.
* Authoritative server problem.
* Resolver forwarding failure.
* Resolver rule loop.
* Connectivity failure to hybrid DNS servers.
* Invalid or unreachable DNSSEC chain.

Check:

```bash
dig +dnssec yourdatascientist.tech
```

```bash
dig +trace yourdatascientist.tech
```

For DNSSEC-specific problems, inspect:

* Hosted-zone DNSSEC status.
* KSK status.
* KMS key availability.
* DS record at the parent.
* Signature validity.

Loss of access to the KMS key used by a Route 53 key-signing key can put the KSK into an action-needed state. ([AWS Documentation][22])

---

# 47. Troubleshooting: domain works with ALB URL but not custom domain

Suppose this works:

```text
production-alb-123.ap-south-1.elb.amazonaws.com
```

But this does not:

```text
api.yourdatascientist.tech
```

Check:

```text
1. Does the record exist?
2. Is it in the authoritative hosted zone?
3. Does the domain delegate to that hosted zone?
4. Is the alias target correct?
5. Does the ALB listener support the requested protocol?
6. Does the certificate include the custom hostname?
7. Does the ALB security group allow traffic?
8. Is the target group healthy?
```

DNS can be correct while HTTPS still fails because the certificate or load balancer is misconfigured.

---

# 48. Troubleshooting: certificate-name mismatch

Error:

```text
Certificate is not valid for api.yourdatascientist.tech
```

Possible cause:

```text
Certificate contains:
yourdatascientist.tech

But does not contain:
api.yourdatascientist.tech
```

A certificate for:

```text
*.yourdatascientist.tech
```

covers:

```text
api.yourdatascientist.tech
www.yourdatascientist.tech
jenkins.yourdatascientist.tech
```

but it does not normally cover the apex:

```text
yourdatascientist.tech
```

A common ACM request includes both:

```text
yourdatascientist.tech
*.yourdatascientist.tech
```

---

# 49. Troubleshooting: ACM validation remains pending

Check:

* CNAME validation name is exact.
* CNAME value is exact.
* Record is in the correct public hosted zone.
* The registrar delegates to that hosted zone.
* An external DNS provider has not automatically appended the domain twice.
* No proxying feature is altering the record.
* The validation record is publicly resolvable.

Verify:

```bash
dig CNAME \
  _validation-token.yourdatascientist.tech
```

For CloudFront, the ACM certificate must be in `us-east-1`. For a Regional ALB, the certificate must be in the same AWS Region as the ALB.

---

# 50. Troubleshooting: private name does not resolve inside VPC

Check:

```text
VPC is associated with private hosted zone
VPC DNS support is enabled
VPC DNS hostnames are enabled where required
Record exists in private zone
Application uses VPC Resolver
No conflicting Resolver rule overrides the domain
No overlapping private zone captures the query unexpectedly
```

From EC2:

```bash
cat /etc/resolv.conf
```

```bash
dig database.internal.yourdatascientist.tech
```

Test the VPC resolver directly when appropriate:

```bash
dig @<vpc-resolver-address> \
  database.internal.yourdatascientist.tech
```

---

# 51. Troubleshooting: old IP is still returned

Possible causes:

* Resolver TTL has not expired.
* Browser cached the result.
* Operating system cached the result.
* Application runtime caches DNS.
* Multiple hosted zones exist.
* Different resolvers receive different authoritative answers.
* Weighted routing intentionally returns different records.

Compare:

```bash
dig @8.8.8.8 api.yourdatascientist.tech
dig @1.1.1.1 api.yourdatascientist.tech
dig @<authoritative-ns> api.yourdatascientist.tech
```

If the authoritative server returns the new value but recursive resolvers return the old value, caching is the likely explanation.

---

# 52. Resolver query logging

Route 53 Resolver query logging can record DNS queries originating from VPC resources.

Possible destinations include supported AWS logging services such as:

* CloudWatch Logs.
* S3.
* Kinesis Data Firehose.

Resolver query logging helps answer:

```text
Which instance queried this domain?
Which hostname is failing?
Is malware querying suspicious domains?
Is an application still using an old hostname?
How many queries does a namespace receive?
```

DNS resolvers cache answers according to TTL, so query logs represent resolver activity rather than necessarily every application-level request. ([AWS Documentation][23])

---

# 53. Production DNS migration procedure

When migrating DNS providers:

```text
1. Export the current DNS zone.
2. Create the new Route 53 hosted zone.
3. Recreate every required record.
4. Compare old and new zones.
5. Lower relevant TTLs in advance.
6. Test Route 53 name servers directly.
7. Update registrar delegation.
8. Monitor public resolvers.
9. Keep the old DNS service active.
10. Verify email, website, API and certificate records.
11. Restore normal TTLs.
12. Remove old DNS only after full validation.
```

Do not forget records that may not appear related to the website:

```text
MX
SPF
DKIM
DMARC
ACM validation
Google or Microsoft verification
GitHub verification
Subdomain delegations
CAA records
```

---

# 54. Production Route 53 checklist

```text
[ ] Registrar delegation matches Route 53 name servers
[ ] Only the intended hosted zone is authoritative
[ ] Public and private zones are clearly separated
[ ] Apex uses an alias instead of an invalid CNAME
[ ] ALB and CloudFront records use aliases
[ ] IPv6 AAAA records exist where intended
[ ] TTL values match change and failover requirements
[ ] Health checks test meaningful application health
[ ] Failover endpoints are independently operational
[ ] Secondary Region has current data and configuration
[ ] ACM certificate covers every custom hostname
[ ] CloudFront certificate is in us-east-1
[ ] ALB certificate is in the ALB Region
[ ] Private hosted zones are associated with correct VPCs
[ ] Hybrid Resolver endpoints span multiple AZs
[ ] Resolver forwarding rules avoid loops
[ ] Query logging is considered
[ ] DNSSEC is enabled through a tested process
[ ] KMS keys used by DNSSEC are protected
[ ] Terraform does not create accidental duplicate zones
[ ] Existing zones and records are imported before management
[ ] DNS migration and rollback runbooks exist
[ ] Domain expiration and auto-renewal are monitored
```

---

# 55. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Route 53 provides domain registration,
DNS resolution and health checking.
```

## Solutions Architect Associate

Understand:

```text
Public versus private hosted zones
Alias versus CNAME
Zone apex
Routing policies
TTL
Health checks
Failover routing
Latency routing
Multi-Region design
```

## DevOps Engineer Professional

Understand:

```text
Automated DNS deployment
Weighted canary releases
Multi-Region failover
Health-check automation
Resolver endpoints and rules
Cross-account private DNS
DNS query logging
DNSSEC operations
Terraform imports and migrations
```

---

# 56. Interview questions

## Question 1: What is the difference between a domain registration and a hosted zone?

**Answer:**

Domain registration establishes ownership and registrar-level configuration. A hosted zone stores DNS records and provides authoritative DNS responses for the domain.

## Question 2: What is the difference between an alias and a CNAME?

**Answer:**

A CNAME is a standard DNS record mapping one hostname to another and cannot normally be used at the zone apex. A Route 53 alias can point the apex or a subdomain to supported AWS resources.

## Question 3: Why should an ALB use an alias instead of an A record containing its IP?

**Answer:**

An ALB’s underlying IP addresses can change. The alias follows the load balancer’s managed DNS name.

## Question 4: What does TTL control?

**Answer:**

TTL controls how long recursive resolvers may cache a DNS answer before querying authoritative DNS again.

## Question 5: Does Route 53 weighted routing provide exact traffic percentages?

**Answer:**

No. DNS caching and resolver behaviour mean the resulting request percentage is approximate.

## Question 6: What is latency-based routing?

**Answer:**

It routes DNS queries toward an AWS Region expected to provide lower latency for the user’s resolver location.

## Question 7: What is the difference between geolocation and geoproximity routing?

**Answer:**

Geolocation selects responses using geographic rules such as country or continent. Geoproximity considers user and resource locations and permits bias adjustments.

## Question 8: What is a private hosted zone?

**Answer:**

It is a DNS zone whose records are resolved through VPC Resolver within associated VPCs rather than through normal public internet DNS.

## Question 9: What are Resolver inbound and outbound endpoints?

**Answer:**

Inbound endpoints let external networks resolve AWS private DNS names. Outbound endpoints let AWS resources forward selected DNS namespaces to external DNS servers.

## Question 10: Does DNS failover guarantee zero downtime?

**Answer:**

No. Health detection, DNS caching, connection recovery and secondary-system readiness all affect actual failover time.

## Question 11: What is DNSSEC?

**Answer:**

DNSSEC digitally signs DNS data so validating resolvers can verify its origin and integrity. It does not encrypt DNS queries.

## Question 12: What does `INSYNC` mean after a Route 53 change?

**Answer:**

It means Route 53’s authoritative DNS servers have applied the change. Recursive resolvers may still return older cached answers until their TTL expires.

---

# 57. Never-forget revision

```text
Registrar:
Controls domain registration and delegation.

Hosted zone:
Contains DNS records.

NS:
Identifies authoritative name servers.

SOA:
Contains zone-authority metadata.

A:
Hostname to IPv4.

AAAA:
Hostname to IPv6.

CNAME:
Hostname to another hostname.

Alias:
Route 53 mapping to supported AWS resources.

MX:
Mail destination.

TXT:
Verification and policy text.

TTL:
How long resolvers cache an answer.

Simple:
One destination.

Weighted:
Approximate percentage distribution.

Latency:
Route toward the best expected AWS Region latency.

Failover:
Primary and secondary routing.

Geolocation:
Route by user geography.

Geoproximity:
Route by user/resource distance plus bias.

IP-based:
Route by defined source CIDR.

Multivalue:
Return multiple healthy answers.

Private hosted zone:
DNS visible through associated VPCs.

Resolver inbound:
On-premises to AWS private DNS.

Resolver outbound:
AWS to external DNS.

DNSSEC:
Validates DNS origin and integrity.
```

## One-line memory trick

```text
Registrar delegates the domain.
Hosted zone stores the records.
Route 53 answers the question.
TTL controls how long the answer is remembered.
Routing policy chooses which answer is returned.
```

## Lesson 27 outcome

You can now design DNS where:

```text
Root domain
    → CloudFront

API subdomain
    → Application Load Balancer

Internal database name
    → Private hosted zone

Primary Region fails
    → Failover record returns secondary Region

Canary deployment begins
    → Weighted records shift a small percentage

On-premises needs AWS private DNS
    → Resolver inbound endpoint

AWS needs on-premises DNS
    → Resolver outbound endpoint
```

**Next lesson: Lesson 28 — Amazon CloudFront production architecture, edge caching, origins, cache policies, Origin Access Control, signed URLs, invalidations, WAF, failover and troubleshooting.**

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html?utm_source=chatgpt.com "Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html?utm_source=chatgpt.com "Working with hosted zones - Amazon Route 53"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/AboutHZWorkingWith.html?utm_source=chatgpt.com "Working with public hosted zones - Amazon Route 53"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-public-considerations.html?utm_source=chatgpt.com "Considerations when working with public hosted zones - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-name-servers-glue-records.html?utm_source=chatgpt.com "Adding or changing name servers and glue records for a domain - Amazon Route 53"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html?utm_source=chatgpt.com "Choosing between alias and non-alias records - Amazon Route 53"
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/troubleshooting-new-dns-settings-not-in-effect.html?utm_source=chatgpt.com "I changed DNS settings, but they haven't taken effect - Amazon Route 53"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-dns.html?utm_source=chatgpt.com "Best practices for Amazon Route 53 DNS - Amazon Route 53"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-weighted.html?utm_source=chatgpt.com "Weighted routing"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html?utm_source=chatgpt.com "Choosing a routing policy"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html?utm_source=chatgpt.com "How Amazon Route 53 chooses records when health ..."
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geoproximity.html?utm_source=chatgpt.com "Geoproximity routing"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-multivalue.html?utm_source=chatgpt.com "Multivalue answer routing - Amazon Route 53"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html?utm_source=chatgpt.com "Creating Amazon Route 53 health checks"
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/monitoring-health-checks.html?utm_source=chatgpt.com "Monitoring health checks using CloudWatch - Amazon Route 53"
[16]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html?utm_source=chatgpt.com "Working with private hosted zones - Amazon Route 53"
[17]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html?utm_source=chatgpt.com "Considerations when working with a private hosted zone"
[18]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[19]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-inbound-queries.html?utm_source=chatgpt.com "Forwarding inbound DNS queries to your VPCs"
[20]: https://docs.aws.amazon.com/whitepapers/latest/hybrid-cloud-dns-options-for-vpc/route-53-resolver-endpoints-and-forwarding-rules.html?utm_source=chatgpt.com "Route 53 Resolver endpoints and forwarding rules"
[21]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec.html?utm_source=chatgpt.com "Configuring DNSSEC signing in Amazon Route 53 - Amazon Route 53"
[22]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-troubleshoot.html?utm_source=chatgpt.com "Troubleshooting DNSSEC signing - Amazon Route 53"
[23]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-query-logs.html?utm_source=chatgpt.com "Resolver query logging - Amazon Route 53"
