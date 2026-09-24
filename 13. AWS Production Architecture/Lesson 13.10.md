# AWS Masterclass — Lesson 9

## Route 53, DNS, Domain Setup, ACM Certificates, and CloudFront Foundation

Today we learn how a user reaches your AWS application using a real domain.

This lesson connects many things you asked for:

```text id="lesson-focus"
domain setup
DNS
Route 53
A record
CNAME record
Alias record
NS record
TXT record
TTL
ACM certificate
DNS validation
CloudFront
origin
cache behavior
propagation timing
common domain errors
```

Your architect course outline includes **CloudFront, Global Accelerator, Route 53, VPC, Direct Connect, PrivateLink, and Transit Gateway** under networking and content delivery, so this is a core architect topic, not an optional topic. 
Your AWS Academy Cloud Developing outline also includes caching with **CloudFront** as a learning topic. 

---

# 1. Why this lesson matters

You can build a perfect EC2 app, ALB, S3 bucket, or API, but users do not normally type:

```text id="bad-user-url"
http://13.233.10.20
```

Users type:

```text id="good-user-url"
https://app.yourdatascientist.tech
```

So you need to understand:

```text id="domain-flow"
Domain:
  yourdatascientist.tech

DNS:
  converts name to destination

Certificate:
  enables HTTPS trust

CloudFront:
  global secure entry point and cache

Origin:
  real backend such as S3, ALB, EC2, or API Gateway
```

Production flow:

```text id="prod-flow"
User
  ↓
app.yourdatascientist.tech
  ↓ DNS
CloudFront
  ↓
Origin:
  S3 / ALB / API Gateway / EC2
```

---

# 2. What is a domain?

A domain is a human-readable name.

Example:

```text id="domain-example"
yourdatascientist.tech
```

Subdomains:

```text id="subdomains"
www.yourdatascientist.tech
app.yourdatascientist.tech
api.yourdatascientist.tech
admin.yourdatascientist.tech
cdn.yourdatascientist.tech
```

Think:

```text id="domain-analogy"
Domain = company name/address that humans remember
IP address = actual network address that computers use
```

---

# 3. What is DNS?

DNS means:

```text id="dns-full"
Domain Name System
```

Simple meaning:

```text id="dns-simple"
DNS converts domain names into network destinations.
```

Example:

```text id="dns-example"
app.yourdatascientist.tech
  ↓ DNS lookup
d123abcd.cloudfront.net
  ↓ CloudFront
origin backend
```

Without DNS, users would need to remember IP addresses or AWS-generated domain names.

---

# 4. DNS lookup flow

When you open:

```text id="open-url"
https://app.yourdatascientist.tech
```

The flow is:

```text id="dns-lookup-flow"
1. Browser checks local cache.
2. Operating system checks DNS cache.
3. Resolver asks root DNS servers.
4. Resolver asks .tech TLD nameservers.
5. Resolver asks authoritative nameservers for yourdatascientist.tech.
6. Authoritative DNS returns record.
7. Browser connects to returned destination.
```

In AWS, Route 53 can be your authoritative DNS service.

Route 53 documentation defines a hosted zone as a container for records for a domain, and DNS records tell Route 53 how to respond to DNS queries for that domain or subdomain. ([AWS Documentation][1])

---

# 5. What is Route 53?

Route 53 is AWS’s DNS and domain service.

It can do three main jobs:

```text id="route53-jobs"
1. Domain registration:
   buy/manage domains

2. DNS hosting:
   host DNS records for a domain

3. DNS routing:
   route users using routing policies
```

Simple meaning:

```text id="route53-simple"
Route 53 is AWS's phonebook for domain names.
```

Example:

```text id="route53-example"
Question:
  Where should app.yourdatascientist.tech go?

Route 53 answer:
  Go to this CloudFront distribution.
```

---

# 6. Registrar vs DNS hosting

Never confuse these.

## Domain registrar

Registrar is where you buy/manage the domain registration.

Examples:

```text id="registrars"
Route 53 Domains
GoDaddy
Namecheap
Hostinger
Cloudflare Registrar
Google Domains/Squarespace Domains
```

Registrar controls:

```text id="registrar-controls"
Who owns the domain?
When does it expire?
Which nameservers are authoritative?
```

## DNS hosting provider

DNS hosting provider stores DNS records.

Examples:

```text id="dns-hosting"
Route 53 hosted zone
Cloudflare DNS
GoDaddy DNS
Namecheap DNS
```

DNS hosting controls:

```text id="dns-controls"
A records
CNAME records
TXT records
MX records
Alias records
TTL
```

Common scenario:

```text id="common-scenario"
Domain bought at GoDaddy
DNS hosted in Route 53
```

In that case:

```text id="nameserver-change"
You create a Route 53 hosted zone.
Route 53 gives you 4 nameservers.
You copy those nameservers into GoDaddy domain settings.
```

---

# 7. Nameservers and NS records

Nameservers answer DNS questions for your domain.

When you create a public hosted zone in Route 53, Route 53 creates NS and SOA records automatically. The NS record lists the authoritative nameservers for the hosted zone. ([AWS Documentation][2])

Example Route 53 nameservers:

```text id="ns-example"
ns-123.awsdns-15.com
ns-456.awsdns-24.net
ns-789.awsdns-35.org
ns-101.awsdns-44.co.uk
```

Meaning:

```text id="ns-meaning"
These AWS DNS servers are responsible for answering DNS queries for your domain.
```

Important:

```text id="ns-important"
Creating records inside Route 53 does nothing for internet users
unless your domain registrar points the domain to the Route 53 nameservers.
```

This is a huge beginner mistake.

---

# 8. Hosted zone

A hosted zone is a container of DNS records.

Example:

```text id="hosted-zone"
Hosted zone:
  yourdatascientist.tech

Records inside:
  app.yourdatascientist.tech
  api.yourdatascientist.tech
  www.yourdatascientist.tech
  _acm-validation.yourdatascientist.tech
```

There are two types:

```text id="zone-types"
Public hosted zone:
  internet DNS

Private hosted zone:
  internal DNS inside VPC
```

Public hosted zone example:

```text id="public-hosted-zone"
app.yourdatascientist.tech
  accessible from internet
```

Private hosted zone example:

```text id="private-hosted-zone"
db.internal.yourdatascientist.tech
  resolvable only inside selected VPCs
```

Route 53 hosted zones and DNS queries can incur charges; as of the current Route 53 pricing page, the first 25 hosted zones are listed at **$0.50 per hosted zone per month**, prorated for partial months. ([Amazon Web Services, Inc.][3])

---

# 9. DNS record types

## A record

A record maps name to IPv4 address.

Example:

```text id="a-record"
app.example.com
  → 13.233.10.20
```

Use when:

```text id="a-record-use"
you want a domain to point to an IPv4 address
```

---

## AAAA record

AAAA maps name to IPv6 address.

Example:

```text id="aaaa-record"
app.example.com
  → 2406:da1a:abcd::123
```

---

## CNAME record

CNAME maps one name to another name.

Example:

```text id="cname-record"
www.example.com
  → example.com
```

Or:

```text id="cloudfront-cname"
app.example.com
  → d123abcd.cloudfront.net
```

Important DNS rule:

```text id="cname-rule"
CNAME cannot normally be used at the root/apex domain.
```

Example root/apex:

```text id="apex"
yourdatascientist.tech
```

Route 53 documentation says the DNS protocol does not allow a CNAME at the zone apex, and Route 53 alias records solve this by letting you route apex records to supported AWS resources such as CloudFront distributions and S3 buckets. ([AWS Documentation][4])

---

## Alias record

Alias is Route 53’s AWS-special record.

Use Alias to point to:

```text id="alias-targets"
CloudFront
ALB
NLB
S3 website endpoint
API Gateway
Elastic Beanstalk
some other AWS resources
```

Example:

```text id="alias-example"
yourdatascientist.tech
  A Alias → CloudFront distribution

www.yourdatascientist.tech
  A Alias → CloudFront distribution
```

Why Alias is important:

```text id="alias-important"
It works at root domain.
It integrates nicely with AWS resources.
It can point to CloudFront/ALB even though those use DNS names, not fixed IPs.
```

---

## TXT record

TXT record stores text.

Used for:

```text id="txt-use"
domain verification
SPF email policy
DKIM
DMARC
some SaaS verifications
```

Example:

```text id="txt-example"
_acme-challenge.example.com
  TXT = verification-token
```

---

## MX record

MX record is for email routing.

Example:

```text id="mx-example"
example.com
  MX → mail server
```

Use when setting up:

```text id="mx-use"
Google Workspace
Microsoft 365
mail hosting
```

---

## CAA record

CAA controls which certificate authorities can issue certificates for your domain.

Example:

```text id="caa-example"
Only Amazon can issue certs for this domain.
```

This is more advanced, but useful in security-conscious production environments.

---

# 10. TTL — Time To Live

TTL means:

```text id="ttl"
Time To Live
```

It tells DNS resolvers how long to cache a DNS answer.

Example:

```text id="ttl-example"
TTL = 300 seconds
```

Meaning:

```text id="ttl-meaning"
DNS resolver can cache this answer for 5 minutes.
```

Route 53 concepts documentation says TTL is the number of seconds DNS resolvers cache record values before requesting fresh values again. ([AWS Documentation][1])

Low TTL:

```text id="low-ttl"
Faster changes
More DNS queries
Useful during migration
```

High TTL:

```text id="high-ttl"
Slower changes
Fewer DNS queries
Useful for stable records
```

Practical recommendation:

```text id="ttl-practical"
Before migration:
  lower TTL to 300 seconds

After stable:
  use 300–3600 seconds depending requirement
```

Important:

```text id="ttl-important"
TTL does not force all users to update instantly.
It controls resolver caching behavior.
Some resolvers may still behave differently.
```

---

# 11. DNS propagation timing

There are two common timing cases.

## Record change inside already-active Route 53 hosted zone

Example:

```text id="record-change"
app.yourdatascientist.tech
old target → new target
TTL = 300
```

Expected behavior:

```text id="record-time"
Many resolvers update after old TTL expires.
If TTL was 300, many clients see change in minutes.
```

## Changing nameservers at registrar

Example:

```text id="ns-change"
Domain was using GoDaddy DNS.
Now you change nameservers to Route 53.
```

This can take longer because parent/TLD/recursive resolvers may cache old delegation data.

AWS troubleshooting documentation says that if DNS service was transferred to Route 53 in the last 48 hours, DNS might still be using the previous DNS service, and TTL caching can also cause resolvers to keep old values. ([AWS Documentation][5])

Practical expectation:

```text id="propagation-expectation"
Record changes:
  often minutes to TTL-based timing

Nameserver changes:
  can take minutes to 48 hours
```

---

# 12. ACM — AWS Certificate Manager

ACM means:

```text id="acm-full"
AWS Certificate Manager
```

Simple meaning:

```text id="acm-simple"
ACM creates and manages SSL/TLS certificates for HTTPS.
```

HTTPS needs a certificate because the browser must trust that:

```text id="https-trust"
this server is allowed to serve this domain
and communication is encrypted
```

Example:

```text id="cert-example"
Domain:
  app.yourdatascientist.tech

Certificate proves:
  this service is trusted for app.yourdatascientist.tech
```

ACM handles creating, storing, and renewing public and private SSL/TLS certificates for AWS websites and applications. ([AWS Documentation][6])

---

# 13. Certificate scope: exact, wildcard, SAN

## Exact domain certificate

```text id="exact-cert"
app.yourdatascientist.tech
```

Works for:

```text id="exact-works"
app.yourdatascientist.tech
```

Does not work for:

```text id="exact-not"
api.yourdatascientist.tech
www.yourdatascientist.tech
```

---

## Wildcard certificate

```text id="wildcard-cert"
*.yourdatascientist.tech
```

Works for:

```text id="wildcard-works"
app.yourdatascientist.tech
api.yourdatascientist.tech
www.yourdatascientist.tech
```

Does not cover the apex/root itself:

```text id="wildcard-not"
yourdatascientist.tech
```

So production certificate often includes:

```text id="cert-names"
yourdatascientist.tech
*.yourdatascientist.tech
```

---

## SAN certificate

SAN means:

```text id="san"
Subject Alternative Name
```

A certificate can include multiple names:

```text id="san-example"
yourdatascientist.tech
www.yourdatascientist.tech
app.yourdatascientist.tech
api.yourdatascientist.tech
```

CloudFront checks that the alternate domain name is covered by the certificate attached to the distribution. ([AWS Documentation][7])

---

# 14. The most important ACM region rule

This is a must-remember AWS rule:

```text id="cloudfront-acm-rule"
For CloudFront custom domains,
ACM certificate must be in us-east-1.
```

Even if your S3 bucket, ALB, EC2, or API is in:

```text id="origin-region"
ap-south-1
```

CloudFront viewer certificate must be in:

```text id="cert-region"
us-east-1
```

AWS CloudFront documentation states that to use an ACM certificate with CloudFront, you must request or import the certificate in the US East/N. Virginia Region, `us-east-1`. ([AWS Documentation][7])

For ALB:

```text id="alb-cert-rule"
ALB certificate must be in the same region as the ALB.
```

Example:

```text id="alb-ap-south"
ALB in ap-south-1
  → ACM certificate in ap-south-1
```

Never confuse:

```text id="never-confuse-cert"
CloudFront certificate:
  us-east-1

ALB certificate:
  same region as ALB

API Gateway regional custom domain:
  same region as API

API Gateway edge-optimized custom domain:
  us-east-1 style CloudFront-backed behavior
```

---

# 15. DNS validation for ACM

ACM must verify that you control the domain.

Recommended validation method:

```text id="dns-validation"
DNS validation
```

ACM gives you a CNAME record like:

```text id="acm-cname"
Name:
  _abc123.app.yourdatascientist.tech

Value:
  _xyz987.acm-validations.aws
```

You add that CNAME into your DNS provider.

Then ACM sees the record and validates the certificate.

ACM DNS validation uses CNAME records that you add to your DNS database to prove domain control. ([AWS Documentation][8])

Timing:

```text id="acm-timing"
If DNS is correct:
  often minutes

If DNS/NS is wrong:
  can stay Pending validation

If registrar nameservers are not pointing correctly:
  ACM cannot see the validation record
```

---

# 16. Domain + CloudFront full production flow

For your domain:

```text id="your-domain"
yourdatascientist.tech
```

A production web setup might be:

```text id="production-domain-flow"
User opens:
  https://app.yourdatascientist.tech

DNS:
  app.yourdatascientist.tech → CloudFront

CloudFront:
  uses ACM cert from us-east-1
  receives HTTPS request
  checks cache behavior

Origin:
  /assets/* → private S3
  /api/*    → ALB in ap-south-1
  default   → frontend S3 or ALB
```

Architecture:

```text id="architecture"
User
  ↓
Route 53 DNS
  ↓
CloudFront + ACM certificate
  ├── private S3 origin
  └── ALB origin in ap-south-1
        ↓
      EC2/ECS app
```

---

# 17. What is CloudFront?

CloudFront is AWS’s CDN.

CDN means:

```text id="cdn"
Content Delivery Network
```

Simple meaning:

```text id="cloudfront-simple"
CloudFront delivers content through AWS edge locations close to users.
```

Example:

```text id="cloudfront-example"
Origin:
  S3 bucket in Mumbai

User:
  Delhi, Singapore, London, New York

CloudFront:
  caches and serves content from nearby edge locations
```

Amazon CloudFront is a content delivery network service that securely delivers data, videos, applications, and APIs globally with low latency and high transfer speeds. ([AWS Documentation][9])

---

# 18. CloudFront core terms

## Distribution

A distribution is the CloudFront resource.

```text id="distribution"
CloudFront distribution:
  global CDN configuration
```

It has:

```text id="distribution-parts"
domain name:
  d123abcd.cloudfront.net

alternate domain names:
  app.yourdatascientist.tech

certificate:
  ACM cert

origins:
  S3, ALB, API Gateway, EC2

cache behaviors:
  path routing and cache rules
```

---

## Origin

Origin is the real backend CloudFront fetches from.

Origins can be:

```text id="origins"
S3 bucket
ALB
EC2 public endpoint
API Gateway
MediaPackage
custom HTTP server
```

Example:

```text id="origin-example"
CloudFront:
  public entry

Origin:
  private S3 bucket
```

or:

```text id="alb-origin"
CloudFront:
  public global edge

Origin:
  ALB in ap-south-1
```

---

## Cache behavior

Cache behavior tells CloudFront:

```text id="cache-behavior"
For this path pattern,
use this origin,
with these cache rules.
```

Examples:

```text id="cache-examples"
/assets/*:
  S3 origin
  cache longer

/api/*:
  ALB origin
  cache disabled or short

/images/*:
  S3 origin
  cache longer

default:
  frontend origin
```

CloudFront cache behavior settings decide how CloudFront processes requests and can map different path patterns to different origins. ([AWS Documentation][10])

---

## Viewer

Viewer means:

```text id="viewer"
user/browser/client requesting content from CloudFront
```

## Viewer protocol policy

This controls HTTP/HTTPS between user and CloudFront.

Common options:

```text id="viewer-policy"
allow-all:
  allow HTTP and HTTPS

redirect-to-https:
  HTTP redirects to HTTPS

https-only:
  only HTTPS accepted
```

Production default:

```text id="viewer-default"
redirect-to-https
```

---

## Origin protocol policy

This controls CloudFront → origin protocol.

Example:

```text id="origin-policy"
CloudFront → ALB:
  HTTP only
  HTTPS only
  match viewer
```

Production API/app:

```text id="origin-prod"
Use HTTPS to origin when possible.
```

For internal ALB origin, HTTP may be acceptable in some labs, but production should evaluate encryption requirements.

---

# 19. CloudFront caching

CloudFront cache means:

```text id="cache-simple"
CloudFront keeps a copy of content at edge locations.
```

Example:

```text id="cache-flow"
First user requests /logo.png
  CloudFront fetches from S3
  CloudFront caches it

Second user requests /logo.png
  CloudFront serves from cache
  S3 is not contacted
```

Benefits:

```text id="cache-benefits"
lower latency
less origin load
lower origin bandwidth
better global performance
```

Bad caching decisions can break apps.

Example:

```text id="bad-cache"
Cache /api/login for 1 hour
```

Bad because:

```text id="bad-cache-why"
different users may need different responses
dynamic authenticated APIs should not be cached casually
```

Good caching:

```text id="good-cache"
Static assets:
  cache long

HTML:
  cache short or controlled

APIs:
  no cache or carefully configured cache

Images:
  cache long

Versioned files:
  cache very long
```

---

# 20. Cache invalidation

Invalidation tells CloudFront:

```text id="invalidation"
Remove cached copy and fetch fresh from origin next time.
```

Example:

```bash id="invalidation-command"
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/index.html"
```

Use when:

```text id="invalidation-use"
you updated file but CloudFront still serves old version
```

Better production approach:

```text id="versioned-assets"
Use versioned filenames:
  app.abc123.js
  style.def456.css

Then cache long without frequent invalidation.
```

---

# 21. CloudFront + S3 security: OAC

OAC means:

```text id="oac"
Origin Access Control
```

Simple meaning:

```text id="oac-simple"
CloudFront can privately access S3, while users cannot access S3 directly.
```

Without OAC:

```text id="without-oac"
User may access S3 directly
or bucket might need public access
```

With OAC:

```text id="with-oac"
User
  ↓
CloudFront
  ↓ signed request
Private S3 bucket
```

Production rule:

```text id="oac-rule"
For public static websites on AWS:
  use CloudFront + private S3 + OAC
```

---

# 22. CloudFront + ALB origin

CloudFront can also point to an ALB.

Flow:

```text id="cf-alb-flow"
User
  ↓
CloudFront
  ↓
ALB in ap-south-1
  ↓
EC2/ECS targets
```

Use this when:

```text id="alb-origin-use"
you want global edge entry
TLS at CloudFront
WAF at CloudFront
cache for some paths
single public domain
route /api/* to backend
```

Common setup:

```text id="common-cloudfront-setup"
/assets/*:
  private S3

/api/*:
  ALB

/*:
  frontend S3 or ALB
```

---

# 23. Route 53 record to CloudFront

For root domain:

```text id="root-record"
yourdatascientist.tech
  A Alias → CloudFront
```

For subdomain:

```text id="sub-record"
app.yourdatascientist.tech
  A Alias → CloudFront
```

Could also use CNAME for subdomain:

```text id="sub-cname"
app.yourdatascientist.tech
  CNAME → d123abcd.cloudfront.net
```

But Route 53 Alias is usually preferred when DNS is in Route 53.

Important CloudFront requirement:

```text id="alternate-name-requirement"
The domain name must be added as an alternate domain name on the CloudFront distribution.
The certificate must cover that domain.
```

CloudFront documentation says when adding an alternate domain name, CloudFront verifies the name using the certificate attached to the distribution. ([AWS Documentation][11])

---

# 24. End-to-end setup order

This is the order you should follow.

```text id="setup-order"
1. Own domain:
   yourdatascientist.tech

2. Decide DNS hosting:
   Route 53 or current provider

3. If using Route 53:
   create public hosted zone

4. Copy Route 53 nameservers:
   update registrar nameservers

5. Request ACM certificate:
   in us-east-1 for CloudFront

6. Add DNS validation CNAME:
   in authoritative DNS provider

7. Wait for certificate:
   Issued

8. Create origin:
   S3 bucket or ALB

9. Create CloudFront distribution:
   attach ACM cert
   add alternate domain name
   add origins and behaviors

10. Create Route 53 Alias:
    app.yourdatascientist.tech → CloudFront

11. Test:
    DNS
    HTTPS
    CloudFront
    origin
```

Never start randomly. Follow order.

---

# 25. Hands-On Lab 9A — No-Cost DNS Learning With Existing Internet Tools

This lab creates no AWS resources.

You only inspect DNS.

## Step 1 — Install tools

Ubuntu:

```bash id="install-tools"
sudo apt-get update
sudo apt-get install -y dnsutils curl
```

Check:

```bash id="check-tools"
dig -v
curl --version
```

---

## Step 2 — Check DNS for your domain

```bash id="dig-domain"
dig yourdatascientist.tech
```

Check nameservers:

```bash id="dig-ns"
dig NS yourdatascientist.tech
```

Check trace:

```bash id="dig-trace"
dig +trace yourdatascientist.tech
```

Meaning:

```text id="trace-meaning"
+trace shows the chain:
root → .tech → authoritative nameservers
```

---

## Step 3 — Check a subdomain

```bash id="dig-app"
dig app.yourdatascientist.tech
```

If no record exists, result may show no answer.

That is fine.

---

## Step 4 — Check with Google resolver

```bash id="google-resolver"
dig @8.8.8.8 yourdatascientist.tech
dig @8.8.8.8 NS yourdatascientist.tech
```

Check with Cloudflare resolver:

```bash id="cloudflare-resolver"
dig @1.1.1.1 yourdatascientist.tech
dig @1.1.1.1 NS yourdatascientist.tech
```

Why?

```text id="resolver-why"
Different DNS resolvers may have different cached results until TTL expires.
```

---

## Step 5 — Check HTTPS certificate of a site

Example:

```bash id="openssl"
echo | openssl s_client -servername aws.amazon.com -connect aws.amazon.com:443 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

Meaning:

```text id="openssl-meaning"
subject:
  certificate domain

issuer:
  certificate authority

dates:
  validity period
```

This helps debug real domain certificate issues later.

---

# 26. Hands-On Lab 9B — Plan Your Domain Setup

No resources required. Create a planning file.

```bash id="domain-plan"
mkdir -p ~/aws-masterclass/domain

cat > ~/aws-masterclass/domain/yourdatascientist-tech-plan.md <<'EOF'
# Domain Plan — yourdatascientist.tech

## Domain

yourdatascientist.tech

## DNS provider

Current:
  TODO

Target:
  Route 53 or existing DNS provider

## Planned records

Root:
  yourdatascientist.tech
  A Alias → CloudFront

WWW:
  www.yourdatascientist.tech
  A Alias → CloudFront

App:
  app.yourdatascientist.tech
  A Alias → CloudFront

API:
  api.yourdatascientist.tech
  A Alias → CloudFront or ALB

## ACM certificates

For CloudFront:
  Region: us-east-1
  Names:
    yourdatascientist.tech
    *.yourdatascientist.tech

For ALB in ap-south-1:
  Region: ap-south-1
  Names:
    api.yourdatascientist.tech if terminating TLS at ALB

## TTL strategy

Before migration:
  300 seconds

Stable records:
  300 to 3600 seconds

## CloudFront origins

/assets/*:
  private S3 bucket with OAC

/api/*:
  ALB in ap-south-1

default:
  frontend origin

## Important checks

- Registrar nameservers point to correct DNS provider.
- ACM validation CNAME exists in authoritative DNS.
- CloudFront alternate domain name includes app/root/www.
- Certificate covers the alternate domain name.
- Route 53 Alias points to correct CloudFront distribution.
- CloudFront status is Deployed.
EOF
```

View:

```bash id="cat-plan"
cat ~/aws-masterclass/domain/yourdatascientist-tech-plan.md
```

---

# 27. Optional Lab 9C — Request ACM Certificate for CloudFront

Only do this if you own/control the domain DNS.

Region must be:

```text id="acm-region"
us-east-1
```

Request certificate:

```bash id="request-cert"
CERT_ARN="$(aws acm request-certificate \
  --region us-east-1 \
  --domain-name yourdatascientist.tech \
  --subject-alternative-names "*.yourdatascientist.tech" \
  --validation-method DNS \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev \
  --query CertificateArn \
  --output text)"

echo "$CERT_ARN"
```

Get DNS validation records:

```bash id="cert-validation"
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "$CERT_ARN" \
  --query 'Certificate.DomainValidationOptions[].ResourceRecord' \
  --output table
```

Add those CNAME records to your DNS provider.

If DNS is hosted in Route 53 in the same account, we can automate this later.

Check status:

```bash id="cert-status"
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "$CERT_ARN" \
  --query 'Certificate.{Status:Status,DomainName:DomainName,SubjectAlternativeNames:SubjectAlternativeNames}'
```

Wait until:

```text id="issued"
ISSUED
```

Cleanup if not needed:

```bash id="delete-cert"
aws acm delete-certificate \
  --region us-east-1 \
  --certificate-arn "$CERT_ARN"
```

You cannot delete a certificate while it is attached to CloudFront or another AWS service.

---

# 28. Optional Lab 9D — Create Route 53 Hosted Zone

Only do this if you accept Route 53 hosted zone charges.

Create hosted zone:

```bash id="create-zone"
CALLER_REF="aws-masterclass-$(date +%Y%m%d%H%M%S)"

HOSTED_ZONE_ID="$(aws route53 create-hosted-zone \
  --name yourdatascientist.tech \
  --caller-reference "$CALLER_REF" \
  --hosted-zone-config Comment="AWS Masterclass hosted zone",PrivateZone=false \
  --query 'HostedZone.Id' \
  --output text | sed 's#/hostedzone/##')"

echo "$HOSTED_ZONE_ID"
```

Get Route 53 nameservers:

```bash id="get-ns"
aws route53 get-hosted-zone \
  --id "$HOSTED_ZONE_ID" \
  --query 'DelegationSet.NameServers' \
  --output table
```

Then update those nameservers at your registrar.

Do not create multiple hosted zones for the same domain unless you know exactly which one the registrar points to. Multiple hosted zones with the same name are a common cause of DNS confusion.

Cleanup if you do not need it:

```bash id="delete-zone"
aws route53 delete-hosted-zone \
  --id "$HOSTED_ZONE_ID"
```

You must delete non-default records first before deleting a hosted zone.

---

# 29. Common domain setup patterns

## Pattern 1 — Static website

```text id="static-pattern"
Route 53
  ↓
CloudFront
  ↓ OAC
Private S3
```

Use for:

```text id="static-use"
portfolio website
React build
documentation site
landing page
static assets
```

---

## Pattern 2 — Dynamic web app

```text id="dynamic-pattern"
Route 53
  ↓
CloudFront
  ↓
ALB
  ↓
EC2/ECS/EKS
  ↓
RDS/DynamoDB
```

Use for:

```text id="dynamic-use"
Node.js app
Django app
Spring Boot app
microservices app
API backend
```

---

## Pattern 3 — Split frontend and API

```text id="split-pattern"
app.yourdatascientist.tech
  → CloudFront
  → S3 frontend

api.yourdatascientist.tech
  → CloudFront or ALB
  → API backend
```

---

## Pattern 4 — One CloudFront, multiple origins

```text id="multi-origin"
/assets/*:
  S3

/api/*:
  ALB

/admin/*:
  admin ALB or admin service

/default:
  frontend S3
```

This is very common in production.

---

# 30. Common errors and fixes

## Error 1 — Domain not resolving

Check:

```bash id="domain-debug"
dig NS yourdatascientist.tech
dig +trace yourdatascientist.tech
```

Possible causes:

```text id="domain-causes"
registrar nameservers not updated
wrong hosted zone updated
DNS propagation still using old provider
record missing
record created in private hosted zone instead of public hosted zone
```

Fix:

```text id="domain-fix"
Confirm authoritative nameservers.
Update the correct DNS provider.
Wait for old TTL/delegation cache if recently changed.
```

---

## Error 2 — ACM stuck in Pending validation

Check:

```bash id="acm-debug"
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn "$CERT_ARN" \
  --query 'Certificate.DomainValidationOptions[].ResourceRecord'
```

Then check DNS:

```bash id="check-cname"
dig CNAME _abc123.yourdatascientist.tech
```

Possible causes:

```text id="acm-causes"
CNAME record missing
CNAME added to wrong DNS provider
extra domain appended by DNS UI
wrong hosted zone
registrar still points to old nameservers
CAA record blocks Amazon CA
```

Fix:

```text id="acm-fix"
Add exact CNAME name and value.
Verify with dig.
Make sure domain authoritative DNS is correct.
```

---

## Error 3 — CloudFront says certificate not available

Cause:

```text id="cert-not-available"
Certificate is not in us-east-1
or certificate is not ISSUED
or certificate does not cover alternate domain name.
```

Fix:

```text id="cert-fix"
Request/import ACM certificate in us-east-1.
Include exact domain/SAN/wildcard.
Wait for ISSUED.
```

---

## Error 4 — CloudFront 403

Possible causes:

```text id="cf-403-causes"
S3 bucket policy wrong
OAC not attached
object does not exist
wrong origin path
CloudFront behavior routes to wrong origin
default root object missing
viewer request path wrong
```

Debug:

```text id="cf-403-debug"
Test S3 object existence.
Check CloudFront behavior path.
Check OAC and bucket policy.
Check distribution status.
```

---

## Error 5 — CloudFront 502

Possible causes:

```text id="cf-502-causes"
origin TLS certificate mismatch
origin unreachable
ALB security group blocks CloudFront/origin request
origin protocol policy mismatch
origin closed connection
bad DNS origin name
```

For ALB origin, always check:

```text id="alb-origin-debug"
Can CloudFront reach ALB?
Does ALB respond directly?
Are targets healthy?
Is TLS certificate valid if HTTPS origin?
```

---

## Error 6 — Route 53 Alias target not showing CloudFront

Possible causes:

```text id="alias-target-causes"
CloudFront distribution not deployed yet
alternate domain name missing on CloudFront
wrong account/region confusion
certificate mismatch
```

Fix:

```text id="alias-target-fix"
Add alternate domain name to CloudFront.
Attach correct us-east-1 certificate.
Wait for Deployed.
Then create Alias.
```

---

# 31. Domain troubleshooting checklist

Use this exact order:

```text id="troubleshooting-checklist"
1. Who is the domain registrar?
2. Which nameservers are set at registrar?
3. Which DNS provider is authoritative?
4. Does public hosted zone exist?
5. Are you editing the correct hosted zone?
6. Does record exist?
7. What is TTL?
8. What does dig +trace show?
9. What does Google DNS return?
10. What does Cloudflare DNS return?
11. Is ACM certificate ISSUED?
12. Is ACM certificate in correct region?
13. Does certificate cover the domain?
14. Is CloudFront alternate domain name configured?
15. Is Route 53 Alias pointing to correct CloudFront distribution?
16. Is CloudFront Deployed?
17. Is origin healthy?
18. Is cache serving old response?
19. Do you need invalidation?
20. Are you using HTTP instead of HTTPS?
```

---

# 32. Production best practices

For domain and CloudFront:

```text id="best-practices"
Use Route 53 public hosted zone if you want AWS-native DNS.
Use Alias records for CloudFront and ALB.
Use ACM DNS validation.
Use us-east-1 ACM cert for CloudFront.
Use ap-south-1 ACM cert for ap-south-1 ALB.
Use CloudFront in front of public apps when global delivery/security/caching is needed.
Use private S3 with OAC.
Use redirect-to-https viewer policy.
Use WAF for public production apps where needed.
Use versioned static assets.
Use short TTL before migration.
Avoid multiple hosted zones with same domain unless carefully managed.
Document registrar, nameservers, certificate ARNs, CloudFront distribution ID, and DNS records.
```

---

# 33. Certification angle

## CLF-C02

Know:

```text id="clf"
Route 53 is DNS/domain service.
CloudFront is CDN.
ACM manages SSL/TLS certificates.
DNS maps domain names to destinations.
TTL controls DNS cache time.
```

## SAA-C03

Know deeply:

```text id="saa"
A vs CNAME vs Alias
hosted zone
public vs private hosted zone
Route 53 routing policies
CloudFront origins and cache behaviors
CloudFront with S3/ALB/API Gateway
ACM us-east-1 requirement for CloudFront
OAC for private S3
HTTP to HTTPS redirect
domain migration TTL planning
```

## DOP-C02

Know operationally:

```text id="dop"
DNS cutover planning
certificate renewal and validation
CloudFront invalidation
CloudFront 403/502 troubleshooting
origin health debugging
DNS propagation debugging
Route 53 automation
blue/green DNS strategies
WAF/CloudFront logging
deployment cache busting
```

---

# 34. Interview answer

Memorize this:

```text id="interview-answer"
Route 53 is AWS’s DNS and domain service. A public hosted zone stores DNS records for an internet domain, and records such as A, CNAME, TXT, MX, and Route 53 Alias decide how users reach services. A CNAME points one DNS name to another name but cannot normally be used at the root domain, so for AWS resources like CloudFront and ALB I prefer Route 53 Alias records, including for apex domains.

For HTTPS, I use AWS Certificate Manager. If the certificate is for CloudFront, it must be requested or imported in us-east-1, even if the origin is in another region such as ap-south-1. For an ALB, the certificate must be in the same region as the ALB. I usually use DNS validation with ACM because ACM provides a CNAME record that proves domain ownership and supports managed renewal.

For production web apps, I often route the domain to CloudFront, attach a valid ACM certificate, add the domain as an alternate domain name, and configure origins such as private S3 with OAC for static content and ALB for dynamic API traffic. I use cache behaviors to route paths like /assets/* to S3 and /api/* to ALB, redirect viewers to HTTPS, and use invalidations or versioned filenames when content changes. For troubleshooting, I verify registrar nameservers, Route 53 hosted zone records, TTL, ACM validation, CloudFront deployment status, alternate domain names, certificate coverage, and origin health.
```

---

# 35. Quick quiz

```text id="quiz"
1. What is DNS?
2. What is Route 53?
3. What is a hosted zone?
4. What is the difference between registrar and DNS hosting?
5. What is an NS record?
6. What is an A record?
7. What is a CNAME record?
8. Why can CNAME be a problem at root domain?
9. What is Route 53 Alias?
10. What is TTL?
11. What is ACM?
12. Which ACM region is required for CloudFront?
13. Which ACM region is required for ALB?
14. What is DNS validation?
15. What is CloudFront?
16. What is an origin?
17. What is a cache behavior?
18. What is OAC?
19. What causes ACM Pending validation?
20. What causes CloudFront 403?
```

Answers:

```text id="answers"
1. DNS converts domain names to network destinations.
2. AWS DNS and domain service.
3. Container for DNS records for a domain.
4. Registrar owns/manages domain registration; DNS hosting stores DNS records.
5. Nameserver record showing authoritative DNS servers.
6. Name to IPv4 address.
7. Name to another DNS name.
8. DNS protocol does not allow CNAME at zone apex.
9. AWS-specific record that points to AWS resources like CloudFront/ALB.
10. DNS cache duration in seconds.
11. AWS Certificate Manager for SSL/TLS certificates.
12. us-east-1.
13. Same region as ALB.
14. Proving domain ownership by adding ACM CNAME record.
15. AWS CDN.
16. Backend CloudFront fetches from, such as S3 or ALB.
17. Rule that maps path/request behavior to origin and cache settings.
18. Origin Access Control for private CloudFront access to S3.
19. Missing/wrong validation CNAME or wrong authoritative DNS.
20. Wrong S3/OAC/bucket policy/object path/behavior/origin access.
```

---

# Next Lesson

```text id="next"
AWS Lesson 10 — CloudFront In Depth:
CDN architecture, S3 origin, ALB origin, cache policies, origin request policies, response headers policies, OAC, invalidation, signed URLs, WAF integration, logs, and production troubleshooting
```

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/route-53-concepts.html?utm_source=chatgpt.com "Amazon Route 53 concepts - Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/SOA-NSrecords.html?utm_source=chatgpt.com "NS and SOA records that Amazon Route 53 creates for a public hosted zone - Amazon Route 53"
[3]: https://aws.amazon.com/route53/pricing//?utm_source=chatgpt.com "Amazon Route 53 pricing - Amazon Web Services"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html?utm_source=chatgpt.com "Supported DNS record types - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/troubleshooting-new-dns-settings-not-in-effect.html?utm_source=chatgpt.com "I changed DNS settings, but they haven't taken effect - Amazon Route 53"
[6]: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html?utm_source=chatgpt.com "What is AWS Certificate Manager? - AWS Certificate Manager"
[7]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html?utm_source=chatgpt.com "Requirements for using SSL/TLS certificates with CloudFront - Amazon CloudFront"
[8]: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html?utm_source=chatgpt.com "AWS Certificate Manager DNS validation - AWS Certificate Manager"
[9]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-alternate-domain-names.html?utm_source=chatgpt.com "Use alternate domain names and HTTPS - Amazon CloudFront"
[10]: https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_CacheBehavior.html?utm_source=chatgpt.com "CacheBehavior - Amazon CloudFront"
[11]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html?utm_source=chatgpt.com "Use custom URLs by adding alternate domain names (CNAMEs) - Amazon CloudFront"
