# AWS Masterclass — Lesson 31 Part 5

# AWS WAF, Shield, Network Firewall & Firewall Manager

## Web Protection, DDoS Defense, VPC Inspection & Organization-Wide Firewall Governance

So far in Lesson 31:

```text
KMS
→ Encryption and cryptographic keys

Secrets Manager / Parameter Store
→ Credentials and sensitive configuration

ACM / TLS
→ Encryption in transit

GuardDuty / Inspector / Macie / Security Hub
→ Detect and investigate security problems

NOW:

WAF / Shield / Network Firewall / Firewall Manager
→ PREVENT AND CONTROL NETWORK ATTACKS
```

The master architecture is:

```text
                         INTERNET
                            │
                            ▼
                        Route 53
                            │
                            ▼
                         Shield
                      DDoS protection
                            │
                            ▼
                       CloudFront
                            │
                            ▼
                         AWS WAF
                     HTTP/S inspection
                            │
                            ▼
                           ALB
                            │
                            ▼
                        Application


           VPC / EAST-WEST / EGRESS TRAFFIC
                            │
                            ▼
                  AWS Network Firewall
                            │
                  Layer 3–7 inspection
                            │
                            ▼
                        Workloads


                  MULTI-ACCOUNT CONTROL
                            │
                            ▼
                    Firewall Manager
                            │
             centrally deploy/enforce policies
```

The first thing to understand is that these services operate at **different layers**. AWS WAF inspects HTTP(S) web requests; Shield focuses on DDoS resilience; Network Firewall is a managed stateful network firewall/IDS/IPS for VPC traffic; Firewall Manager centrally manages protections across AWS Organizations. ([AWS Documentation][1])

---

# 1. The Never-Forget Comparison

```text
AWS WAF
=
"Is this HTTP request malicious or unwanted?"


AWS Shield
=
"Is someone flooding my application with a DDoS attack?"


AWS Network Firewall
=
"Should this network flow be allowed through the VPC?"


AWS Firewall Manager
=
"How do I enforce these protections
across 10 / 100 / 1,000 AWS accounts?"
```

That distinction solves a large percentage of AWS security architecture questions. ([AWS Documentation][1])

---

# PART A — AWS WAF

# 2. What Is AWS WAF?

AWS WAF is a **web application firewall** that evaluates HTTP(S) requests before they reach protected application resources. It can inspect request characteristics such as IP addresses, URI/query values, headers, body content, and other HTTP properties, then allow, block, count, challenge, or otherwise process matching requests. ([AWS Documentation][1])

Think:

```text
Internet
   │
   ▼
GET /login
POST /api/payment
GET /search?q=...
   │
   ▼
AWS WAF
   │
   ├── IP?
   ├── URI?
   ├── headers?
   ├── query?
   ├── body?
   ├── SQL injection?
   ├── XSS?
   ├── bot?
   └── request rate?
       │
       ▼
ALLOW / BLOCK / COUNT /
CAPTCHA / CHALLENGE
```

---

# 3. WAF Is NOT a General Network Firewall

AWS WAF works primarily at the **web application layer**:

```text
HTTP
HTTPS
```

It is not the service you use to inspect arbitrary:

```text
SSH
RDP
database TCP
DNS UDP
custom TCP
east-west VPC flows
```

For broader network filtering inside VPC architectures, think **AWS Network Firewall** instead. ([AWS Documentation][1])

Memory:

```text
WAF
=
HTTP-aware security

Network Firewall
=
network-flow security
```

---

# 4. Current WAF Terminology

AWS's current 2026 documentation increasingly calls a Web ACL a:

```text
Protection pack (web ACL)
```

The familiar architectural term remains:

```text
WEB ACL
```

so throughout the course I'll keep using **Web ACL** because that is still widely used in exams, APIs, Terraform resource names, and AWS architecture discussions. ([AWS Documentation][2])

---

# 5. What Can AWS WAF Protect?

Current AWS WAF supports resources including:

```text
CloudFront distributions

Application Load Balancers

API Gateway REST APIs

AppSync GraphQL APIs

Cognito user pools

App Runner services

Verified Access

Amplify

Bedrock AgentCore Gateway
```

among the currently supported resource types. ([AWS Documentation][3])

For our course, the three most important are:

```text
CloudFront

ALB

API Gateway
```

---

# 6. WAF Placement — CloudFront vs ALB

Suppose architecture:

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
EC2
```

You have two major WAF placement choices.

### WAF on CloudFront

```text
Internet
   │
   ▼
WAF
   │
   ▼
CloudFront
   │
   ▼
ALB
```

Malicious requests can be filtered at the AWS edge before reaching your Region.

### WAF on ALB

```text
Internet
   │
   ▼
ALB
   │
   ▼
WAF evaluation
   │
   ▼
Application
```

Useful when ALB is your primary public entry point.

For an internet-facing global application already using CloudFront, CloudFront WAF is usually the more natural perimeter location.

---

# 7. WAF Region Rule

This connects to our ACM lesson.

For CloudFront:

```text
WAF scope
=
CLOUDFRONT / Global

Configuration Region
=
us-east-1
```

For a Regional ALB/API Gateway resource:

```text
WAF scope
=
REGIONAL

Region
=
same Region as resource
```

A Regional Web ACL cannot simply be attached to CloudFront, and a CloudFront-scoped ACL can't be reused as a Regional ALB ACL. ([docs.aws.amazon.com][3])

---

# 8. Web ACL Mental Model

A Web ACL contains:

```text
Web ACL
│
├── Default action
│
└── Ordered rules
     │
     ├── Rule 10
     ├── Rule 20
     ├── Rule 30
     └── Rule 40
```

Example:

```text
Request
   │
   ▼
Rule 10
Known malicious IP?
   │
   ├── YES → Block
   │
   ▼
Rule 20
SQL injection?
   │
   ├── YES → Block
   │
   ▼
Rule 30
Bot?
   │
   ├── YES → Challenge
   │
   ▼
Rule 40
Too many login attempts?
   │
   ├── YES → Block
   │
   ▼
Default Action
ALLOW
```

WAF evaluates the rules according to their configured priority, and terminating actions stop further evaluation. ([AWS Documentation][4])

---

# 9. Default Action

Typical production design:

```text
Default:
ALLOW
```

and explicitly block known threats.

Example:

```text
Allow normal users

Block:
SQLi
XSS
known bad IPs
credential stuffing
excessive login requests
```

Another architecture can be:

```text
Default:
BLOCK
```

and explicitly allow approved traffic.

That can make sense for:

```text
private administrative APIs

partner-only APIs

strict allow-list environments
```

The correct choice depends on application exposure.

---

# 10. WAF Rule Actions

Important WAF actions include:

```text
ALLOW

BLOCK

COUNT

CAPTCHA

CHALLENGE
```

`Count` is non-terminating and is extremely useful for testing. CAPTCHA/Challenge behavior depends on whether the client already holds a valid WAF token; without a valid token they can terminate and challenge the request, while valid-token requests can continue evaluation. ([AWS Documentation][5])

---

# 11. The Most Important Production WAF Rule

Before enabling a large new rule set as:

```text
BLOCK
```

first test it using:

```text
COUNT
```

Example:

```text
AWS Managed Rule
      │
      ▼
COUNT
      │
      ▼
observe production traffic
      │
      ▼
false positives?
   │       │
  YES      NO
   │       │
   ▼       ▼
tune     BLOCK
```

AWS specifically supports Count/action overrides for testing managed rule groups and diagnosing false positives. ([AWS Documentation][6])

---

# 12. Why This Matters

Imagine your legitimate application sends:

```text
/search?q=select shoes
```

A poorly tuned rule might interpret:

```text
select
```

as SQL-like syntax.

If you deployed directly with:

```text
BLOCK
```

you could create your own outage.

Therefore:

```text
SECURITY RULE DEPLOYMENT

Count
  ↓
Observe
  ↓
Tune
  ↓
Block
```

is an excellent operational pattern.

---

# 13. AWS Managed Rules

You do not have to manually write every security signature.

AWS provides managed rule groups.

A common baseline is:

```text
AWSManagedRulesCommonRuleSet
```

The Core Rule Set is designed to provide general protection against a broad set of common web application vulnerabilities, including patterns associated with risks covered by OWASP guidance. ([AWS Documentation][7])

Think:

```text
Web ACL
   │
   ├── AWS Common Rule Set
   ├── Known Bad Inputs
   ├── IP Reputation
   ├── Bot Control
   └── custom application rules
```

---

# 14. Managed Rules ≠ “Security Finished”

Do not think:

```text
Enable AWSManagedRulesCommonRuleSet

=
application is secure
```

WAF helps mitigate certain web attack patterns.

You still need:

```text
secure application code

input validation

authorization

IAM

patching

Secrets Manager

database security

logging

Inspector

GuardDuty
```

Defense in depth remains required.

---

# 15. SQL Injection

Consider:

```text
GET /product?id=1' OR '1'='1
```

A SQL injection attacker tries to manipulate application input so backend SQL execution behaves differently from intended.

AWS WAF supports SQL injection match statements, and AWS managed rule groups include protections against common malicious request patterns. ([AWS Documentation][4])

But never use WAF as an excuse to write:

```text
SELECT *
FROM users
WHERE id = '${user_input}'
```

Your application must still use secure parameterized queries.

---

# 16. Cross-Site Scripting — XSS

Example malicious input:

```html
<script>
  stealCookie()
</script>
```

WAF supports cross-site scripting match logic to detect common XSS request patterns. ([AWS Documentation][4])

Again:

```text
WAF
=
additional protection

secure encoding/input handling
=
application responsibility
```

---

# 17. IP Sets

Suppose your administration endpoint should only be reached from:

```text
203.0.113.0/24
```

You can define an:

```text
IP Set
```

and build rules around it.

Example:

```text
/admin
   │
   ▼
Source IP approved?
   │
 ┌─┴─┐
YES NO
 │   │
 ▼   ▼
allow block
```

This can also be combined with other rule conditions.

---

# 18. Regex Pattern Sets

Suppose your API must reject suspicious URL patterns.

Conceptually:

```text
/admin/.*
/internal/.*
/debug/.*
```

Reusable regex pattern sets allow multiple WAF rules to refer to common regular-expression patterns rather than duplicating logic.

Be careful with complex regex logic:

```text
security benefit
vs
false positive risk
```

must be balanced.

---

# 19. Scope-Down Statements

Suppose you want Bot Control only on:

```text
/login

/signup
```

rather than every request.

A managed-rule-group reference can use a:

```text
scope-down statement
```

to restrict which requests the managed rule group evaluates. ([AWS Documentation][8])

Architecture:

```text
Bot Control
    │
    ▼
Only if URI begins:
 /login
 /signup
```

This can reduce:

```text
unnecessary evaluation

false positives

cost

application impact
```

depending on the rule group.

---

# 20. Labels — Advanced WAF Composition

WAF rules can attach metadata called:

```text
LABELS
```

to a request.

Rules later in evaluation can make decisions based on those labels. ([AWS Documentation][9])

Example:

```text
Managed Rule
detects suspicious bot
      │
      ▼
label:
bot:suspicious
      │
      ▼
later custom rule
      │
      ▼
if bot:suspicious
AND
/login
      │
      ▼
CAPTCHA
```

This lets you build multi-stage security logic.

---

# 21. Why Labels Are Powerful

Instead of:

```text
rule matches
→ immediately block
```

you can:

```text
detect
   │
   ▼
label request
   │
   ▼
combine with another signal
   │
   ▼
decide action
```

Example:

```text
IP reputation suspicious
        │
        ▼
label
        │
        +
request rate high
        │
        +
/login
        │
        ▼
BLOCK
```

This can reduce false positives.

---

# 22. Rate-Based Rules

One of the most important WAF features is:

```text
RATE-BASED RULE
```

Example:

```text
/login
```

A normal user might send:

```text
5 requests/minute
```

An attacker may send:

```text
10,000 requests/minute
```

WAF can track request rates and apply an action when a configured aggregation exceeds the threshold. ([AWS Documentation][10])

---

# 23. Current Rate Evaluation Windows

As of 2026, WAF supports rate evaluation windows of:

```text
1 minute

2 minutes

5 minutes

10 minutes
```

with:

```text
5 minutes
```

as the default. The minimum configurable rate limit is currently 10 requests per evaluation window. ([AWS Documentation][11])

This is an important update because older examples frequently assume only a five-minute conceptual window.

---

# 24. Rate Limiting Is Approximate

This is a certification/interview trap.

AWS WAF rate-based rules are **not designed as precise API quota enforcement**.

AWS states that the service estimates the request rate and applies limiting near the configured value, but doesn't guarantee an exact cutoff. Changes and detection can also involve short propagation/detection delays. ([AWS Documentation][12])

So:

```text
WAF rate-based rule
≠
exact 100-RPS API throttle
```

For exact API usage quotas, API Gateway/application-level rate limiting may also be appropriate.

---

# 25. Rate Aggregation

The simplest model:

```text
per source IP
```

But current WAF rate-based rules can aggregate using options such as:

```text
source IP

forwarded IP

ASN

HTTP method

header

cookie

query parameter

URI path

JA3/JA4 fingerprint

labels

combinations of keys
```

depending on configuration. ([AWS Documentation][13])

This means modern WAF rate limiting can be far more sophisticated than:

```text
"1000 requests from one IP."
```

---

# 26. Example — Protect Login Endpoint

Suppose:

```text
POST /login
```

Normal maximum:

```text
100 requests
per IP/user-agent
within 5 minutes
```

WAF can use:

```text
IP
+
User-Agent
+
scope-down /login
```

as the aggregation logic. AWS documents this type of composite login-rate-limit example directly. ([AWS Documentation][14])

---

# 27. Why IP-Only Rate Limiting Can Be Dangerous

Imagine:

```text
500 employees
behind one corporate NAT gateway
```

They may all appear to WAF as:

```text
one public IP
```

If your threshold is too low:

```text
one employee logs in
one employee logs in
...
```

eventually:

```text
entire corporate office blocked
```

Therefore rate limiting must understand:

```text
NAT
proxies
CDNs
mobile carriers
shared IPs
```

and your application's actual traffic model.

---

# 28. Forwarded IP Caution

WAF can aggregate using a forwarded IP header, but AWS warns that forwarded headers can be inconsistent or manipulated if your proxy architecture doesn't establish them securely. ([AWS Documentation][13])

Never blindly trust:

```text
X-Forwarded-For
```

from arbitrary internet clients.

The trust chain should be:

```text
Client
   │
   ▼
trusted proxy/CDN
   │
   ▼
WAF/application
```

---

# 29. Bot Control

AWS WAF Bot Control is an AWS managed rule group designed to classify and manage bot traffic. Bots can consume resources, distort analytics, scrape content, or perform malicious automation. ([AWS Documentation][15])

Examples:

```text
search engine crawler

scraper

credential-stuffing bot

inventory bot

headless browser

automated scanner
```

Not every bot should be blocked.

---

# 30. Bot Control Responses

You might handle:

```text
verified search engine
→ ALLOW

unknown automation
→ CHALLENGE

credential-stuffing behavior
→ BLOCK / CAPTCHA

monitoring system
→ explicitly allow
```

Targeted Bot Control protections can use rate limiting and CAPTCHA/Challenge techniques. ([AWS Documentation][16])

---

# 31. CAPTCHA vs Challenge

### CAPTCHA

```text
User sees puzzle
```

Useful when you want explicit human verification.

### Challenge

```text
silent browser challenge
```

Useful when you want to distinguish browser sessions from many automated clients without always presenting a visible puzzle.

AWS WAF supports both rule actions, and these browser challenge mechanisms require HTTPS secure contexts to obtain WAF tokens. ([AWS Documentation][5])

---

# 32. WAF Logging

A production WAF should normally have useful observability.

AWS WAF logs can be sent to:

```text
CloudWatch Logs

Amazon S3

Amazon Data Firehose
```

and records include request information plus rule evaluation/action details. ([AWS Documentation][17])

Architecture:

```text
WAF
 │
 ├────► CloudWatch Logs
 │
 ├────► S3
 │
 └────► Firehose
           │
           ▼
         SIEM
```

---

# 33. Redact Sensitive Log Data

Imagine WAF logs include:

```text
Authorization: Bearer ...
Cookie: session=...
```

You do not want security logging to become:

```text
credential exfiltration system
```

WAF logging supports redacted fields and logging filters; AWS also provides separate data-protection controls for WAF traffic data. ([AWS Documentation][18])

---

# 34. WAF Production Rollout Pattern

Use:

```text
1. Enable WAF

2. Add baseline managed rules

3. Override risky/new rules to COUNT

4. Enable logging

5. Observe traffic

6. Find false positives

7. Add scope-down/exclusions

8. Move high-confidence rules to BLOCK

9. Add rate protection

10. Add bot protection where justified
```

This is much safer than:

```text
Enable 20 managed rule groups
→ Block
→ production outage
```

---

# PART B — AWS SHIELD

# 35. DDoS Mental Model

DDoS:

# Distributed Denial of Service

The goal is usually not:

```text
steal password
```

but:

```text
overwhelm system
```

Example:

```text
              Botnet
         ┌──────┼──────┐
         ▼      ▼      ▼
      Host A  Host B  Host C
         \      |      /
          \     |     /
           ▼    ▼    ▼
            Application
                  │
                  ▼
              overwhelmed
```

AWS Shield Standard and Shield Advanced provide DDoS protection capabilities at network/transport and application-related layers depending on resource and configuration. ([AWS Documentation][19])

---

# 36. Shield Standard

All AWS customers receive:

```text
Shield Standard
```

automatically and at no additional Shield charge.

AWS describes it as defending against common, frequently occurring network and transport-layer DDoS attacks, with particular benefits for Route 53, CloudFront and Global Accelerator edge resources. ([AWS Documentation][20])

You do not create:

```text
aws_shield_standard
```

for every EC2 server.

It is an AWS baseline protection.

---

# 37. Shield Standard Does Not Mean “DDoS-Proof”

Application architecture still matters.

Example:

```text
Internet
   │
   ▼
single EC2 public IP
   │
   ▼
tiny server
```

is less resilient than:

```text
Internet
   │
   ▼
Route 53
   │
   ▼
CloudFront
   │
   ▼
WAF
   │
   ▼
ALB
   │
   ▼
Multi-AZ ASG
```

AWS explicitly notes that architectural choices influence DDoS resilience even though Shield Standard protections are automatic. ([AWS Documentation][20])

---

# 38. Shield Advanced

Shield Advanced adds higher-level DDoS features including:

```text
advanced DDoS visibility

automatic application-layer mitigation

WAF integration

Route 53 health-based detection

Shield Response Team support

protection groups

cost-protection opportunities
```

for protected resources. ([AWS Documentation][21])

Important:

```text
Shield Advanced
does NOT automatically protect every resource
just because you subscribed.
```

Protected resources must be enrolled directly or through Firewall Manager. ([AWS Documentation][22])

---

# 39. Shield Advanced Protected Resource Types

Current supported categories include:

```text
CloudFront distributions

Route 53 hosted zones

Global Accelerator standard accelerators

Elastic IP addresses

EC2 via protected Elastic IP

Application Load Balancers

other supported ELB configurations
```

with exact support depending on resource type. ([AWS Documentation][22])

---

# 40. WAF vs Shield

This is one of the most important distinctions.

### WAF

```text
GET /login?user=...
```

inspects:

```text
HTTP semantics
```

### Shield

focuses on:

```text
DDoS attack detection/mitigation
```

You frequently use:

```text
Shield
+
WAF
```

together.

---

# 41. Shield Advanced + WAF

For application-layer DDoS protection, Shield Advanced integrates with WAF.

Automatic application-layer mitigation can add/manage WAF protections in response to detected attacks, including rate-based behavior against DDoS sources. ([AWS Documentation][21])

Architecture:

```text
DDoS traffic
     │
     ▼
Shield Advanced
     │
     ▼
Detect attack
     │
     ▼
Managed WAF mitigation
     │
     ▼
Block/count attack requests
```

---

# 42. Shield Response Team — SRT

Shield Advanced customers with the required AWS Support plan can engage the:

```text
Shield Response Team
```

for assistance during DDoS attacks and for custom mitigations. ([AWS Documentation][21])

This is not simply:

```text
normal AWS support ticket
```

The SRT specializes in DDoS response.

---

# 43. Proactive Engagement

Shield Advanced can use a:

```text
Route 53 health check
```

associated with a protected resource.

If Shield detects an event and the application health becomes unhealthy, proactive engagement can allow the SRT to contact designated responders. AWS requires health-based detection for proactive engagement. ([AWS Documentation][23])

This directly connects to our Route 53 health-check lesson.

---

# 44. Health-Based Detection

Without application health knowledge:

```text
traffic spike
```

could mean:

```text
viral success
```

or:

```text
DDoS
```

Route 53 health information adds another signal:

```text
traffic abnormal
+
application unhealthy
```

which can improve Shield Advanced detection/response sensitivity. ([AWS Documentation][21])

---

# 45. DDoS Cost Protection

Shield Advanced includes mechanisms for requesting service credits for certain AWS scaling/usage costs resulting from qualifying DDoS attacks on protected resources. This is a **credit process with eligibility conditions**, not a guarantee that any cost spike is automatically refunded. ([AWS Documentation][21])

Never simplify it to:

```text
Shield Advanced
=
unlimited DDoS bill insurance
```

---

# PART C — AWS NETWORK FIREWALL

# 46. What Is AWS Network Firewall?

AWS Network Firewall is a managed:

```text
STATEFUL NETWORK FIREWALL
+
IDS/IPS
```

for VPC networking. ([AWS Documentation][24])

Architecture:

```text
Application subnet
      │
      ▼
Route Table
      │
      ▼
Network Firewall Endpoint
      │
      ▼
Internet / other VPC / on-prem
```

The key is:

```text
ROUTING SENDS TRAFFIC
THROUGH FIREWALL ENDPOINTS.
```

---

# 47. Security Group vs Network Firewall

Do not confuse them.

### Security Group

```text
Resource-level stateful access control
```

Examples:

```text
Allow ALB → EC2 : 8080

Allow App → DB : 5432
```

### Network Firewall

Can perform broader centralized inspection such as:

```text
IP/protocol filtering

stateful inspection

IDS/IPS signatures

domain filtering

Suricata rules

TLS inspection
```

depending on policy configuration. ([AWS Documentation][24])

They complement each other.

---

# 48. NACL vs Network Firewall

### Network ACL

```text
stateless subnet-level packet filter
```

### Network Firewall

```text
managed inspection engine
with stateless + stateful processing
```

including Suricata-compatible stateful rules. ([AWS Documentation][25])

Therefore:

```text
NACL
≠
full intrusion prevention system
```

---

# 49. The Two Network Firewall Engines

Network Firewall has:

```text
STATELESS ENGINE
```

and:

```text
STATEFUL ENGINE
```

Traffic can be processed by stateless logic first, with selected/default traffic forwarded to the stateful inspection engine. ([AWS Documentation][26])

Mental model:

```text
Packet
  │
  ▼
Stateless rules
  │
  ├── Pass
  ├── Drop
  └── Forward to stateful
               │
               ▼
         Stateful engine
               │
               ▼
         Suricata / domain /
         managed rules
```

---

# 50. Stateless Inspection

Stateless filtering evaluates individual packets without maintaining the complete connection context.

Think:

```text
source IP

destination IP

source port

destination port

protocol
```

Example:

```text
Block all traffic
from 203.0.113.25
```

The stateful engine, by contrast, understands flows and directions across the connection. ([AWS Documentation][25])

---

# 51. Stateful Inspection

Stateful inspection tracks:

```text
connection state
```

Example:

```text
Client → Server
SYN
   │
   ▼
connection established
   │
   ▼
Firewall understands
subsequent packets belong
to same flow
```

This enables richer:

```text
IDS/IPS

application protocol

domain

signature
```

logic. ([AWS Documentation][25])

---

# 52. Suricata-Compatible Rules

Network Firewall's stateful engine supports Suricata-compatible IPS rules. ([AWS Documentation][27])

Conceptually:

```text
drop tcp $HOME_NET any -> $EXTERNAL_NET 443 (
  msg:"Blocked traffic";
  ...
)
```

You don't need to memorize Suricata syntax today.

Understand:

```text
Suricata
=
rule language for deep
stateful intrusion detection/prevention
```

---

# 53. AWS Managed Network Firewall Rules

You don't have to build every IPS signature manually.

AWS provides managed Network Firewall rule groups, including categories for threat signatures, domain/IP intelligence, and other managed filtering. ([AWS Documentation][28])

Architecture:

```text
Network Firewall Policy
      │
      ├── AWS Managed Threat Rules
      ├── custom Suricata rules
      ├── domain rules
      └── IP rules
```

---

# 54. Stateful Rule Evaluation Order

Network Firewall supports different stateful evaluation behavior.

With **strict order**, you explicitly control rule-group priority, and rule groups are evaluated in configured order from lower priority values onward; rules inside them are processed in the sequence defined. ([AWS Documentation][29])

Think:

```text
Priority 10
Allow required repositories

Priority 20
Block malware domains

Priority 30
General policy
```

Rule ordering can materially change behavior.

---

# 55. Network Firewall Routing Is Critical

You can build the world's perfect firewall policy and still inspect:

```text
ZERO TRAFFIC
```

if route tables bypass the firewall.

Correct:

```text
Private Subnet
     │
     ▼
Route table
0.0.0.0/0
     │
     ▼
Firewall endpoint
     │
     ▼
NAT Gateway
     │
     ▼
Internet
```

Wrong:

```text
Private Subnet
     │
     ▼
NAT Gateway
```

while firewall exists unused elsewhere.

---

# 56. Symmetric Routing Matters

Stateful firewalls need to see both directions of a connection correctly.

```text
Forward path
App → Firewall A → destination

Return path
destination → Firewall A → App
```

Good.

```text
Forward
→ Firewall AZ-A

Return
→ Firewall AZ-B / bypass
```

can cause stateful inspection problems.

AWS provides Network Firewall troubleshooting guidance specifically for verifying symmetric routing. ([AWS Documentation][30])

---

# 57. Firewall Subnets

In the traditional VPC firewall model, you designate firewall subnets that host Network Firewall endpoints.

AWS explicitly recommends these subnets be used for firewall endpoints rather than ordinary application workloads. ([AWS Documentation][24])

Example:

```text
VPC
│
├── firewall-subnet-a
├── firewall-subnet-b
│
├── private-app-a
├── private-app-b
│
├── public-nat-a
└── public-nat-b
```

---

# 58. Multi-AZ Inspection

Production architecture:

```text
               AZ-A                     AZ-B

App subnet A                            App subnet B
     │                                      │
     ▼                                      ▼
Firewall EP A                          Firewall EP B
     │                                      │
     ▼                                      ▼
NAT A                                  NAT B
     │                                      │
     └────────── Internet ──────────────────┘
```

The routing should generally preserve AZ-local inspection where the architecture supports it to avoid unnecessary cross-AZ complexity/cost and keep traffic symmetric.

---

# 59. Egress Filtering

A very strong Network Firewall use case:

```text
CONTROL WHAT SERVERS
CAN REACH ON THE INTERNET
```

Example:

```text
EC2 application
    │
    ├──► github.com           allowed
    ├──► package repository  allowed
    ├──► malware.example     blocked
    └──► unknown destination controlled
```

This reduces the chance that a compromised server can freely establish outbound command-and-control connections.

---

# 60. Why Egress Security Matters

Many environments focus only on:

```text
What can come IN?
```

but forget:

```text
What can go OUT?
```

A compromised server often needs outbound access to:

```text
download payloads

contact C2

exfiltrate data

scan external targets
```

Network Firewall can form part of an egress-control strategy.

---

# 61. East-West Inspection

Suppose:

```text
App VPC
      │
      ▼
Data VPC
```

or:

```text
VPC A
 ↔
VPC B
```

You may want central inspection between VPCs.

Traditionally:

```text
Spoke VPCs
   │
   ▼
Transit Gateway
   │
   ▼
Inspection VPC
   │
   ▼
Network Firewall
```

AWS documents centralized VPC-to-VPC and on-premises inspection architectures using Transit Gateway and Network Firewall. ([AWS Documentation][31])

---

# 62. Important 2026 Update — Transit Gateway-Attached Firewall

Current AWS Network Firewall now also supports a **Transit Gateway-attached firewall** model.

The Network Firewall can be directly attached to a Transit Gateway as a TGW attachment, including cross-account ownership patterns through AWS RAM, reducing some of the networking configuration historically required for centralized firewall deployments. ([AWS Documentation][32])

Conceptually:

```text
Spoke VPC A ──┐
              │
Spoke VPC B ──┼──► Transit Gateway
              │          │
On-prem ──────┘          ▼
                  Network Firewall
                    TGW attachment
```

This is a newer architecture worth knowing because older training material may show only the inspection-VPC endpoint model.

---

# 63. Traditional Inspection VPC vs TGW-Attached Firewall

### Traditional

```text
Transit Gateway
       │
       ▼
Inspection VPC
       │
       ▼
Firewall endpoints
```

### Newer direct integration

```text
Transit Gateway
       │
       ▼
TGW-attached
Network Firewall
```

The right choice depends on your current architecture, account ownership model, routing design, supported Region/features, and operational constraints. ([AWS Documentation][32])

---

# 64. TLS Inspection

Normally encrypted TLS traffic looks approximately like:

```text
Source
Destination
Port 443
Encrypted payload
```

The firewall cannot inspect the full application payload without decryption.

Network Firewall supports TLS inspection configurations where it terminates/decrypts applicable TLS traffic before stateful inspection, subject to the certificate/trust architecture and supported constraints. ([AWS Documentation][33])

Architecture:

```text
Client
   │
   │ TLS
   ▼
Network Firewall
   │
   ▼
decrypt / inspect
   │
   ▼
re-establish TLS
   │
   ▼
Destination
```

This is security-powerful but operationally complex.

---

# 65. TLS Inspection Tradeoffs

TLS inspection creates serious considerations around:

```text
certificate trust

privacy

performance

certificate pinning

application compatibility

regulated traffic

operational complexity
```

Do not enable:

```text
decrypt every TLS connection
```

without a deliberate design.

---

# 66. Network Firewall Logs

Network Firewall's stateful engine can produce:

```text
FLOW logs

ALERT logs

TLS logs
```

and send them to:

```text
CloudWatch Logs

Amazon S3

Amazon Data Firehose
```

depending on the configured log type/destination. ([AWS Documentation][34])

---

# 67. Flow vs Alert Logs

### Flow logs

Describe network flow activity.

### Alert logs

Describe traffic that triggered stateful rules with actions such as:

```text
DROP

ALERT

REJECT
```

### TLS logs

Relate to configured TLS inspection behavior. ([AWS Documentation][34])

This gives your SOC visibility into **why** a network connection was blocked.

---

# PART D — AWS FIREWALL MANAGER

# 68. Why Firewall Manager Exists

Imagine:

```text
100 accounts
```

Each team manually manages:

```text
WAF

Shield Advanced

Security Groups

NACLs

Network Firewall
```

Soon:

```text
Account 1
good configuration

Account 2
forgot WAF

Account 3
no Network Firewall

Account 4
public SG rule

Account 5
old WAF
```

Firewall Manager solves organization-scale consistency.

---

# 69. Firewall Manager Mental Model

```text
AWS Organizations
       │
       ▼
Firewall Manager Admin
       │
       ▼
Central Policy
       │
       ├────► Account A
       ├────► Account B
       ├────► Account C
       └────► new Account D
```

Firewall Manager can automatically apply and maintain protections across accounts/resources as the organization changes. ([AWS Documentation][35])

---

# 70. Firewall Manager Policy Types

Firewall Manager can centrally manage protections including:

```text
AWS WAF

Shield Advanced

Network Firewall

Security Groups

Network ACLs

Route 53 Resolver DNS Firewall
```

among its supported policy categories. ([AWS Documentation][36])

This makes Firewall Manager much broader than:

```text
"central WAF manager"
```

---

# 71. Policy Scope

A Firewall Manager policy can target:

```text
all accounts/resources

specific accounts/OUs

selected resource types

tagged resources
```

according to policy scope. ([AWS Documentation][37])

Example:

```text
Production OU
      │
      ▼
All ALBs tagged:
Environment=Production
      │
      ▼
Must have corporate WAF policy
```

---

# 72. Automatic Protection of New Resources

This is one of Firewall Manager's greatest strengths.

Suppose tomorrow a developer creates:

```text
new production ALB
```

If it falls within Firewall Manager policy scope:

```text
Firewall Manager
        │
        ▼
detects in-scope resource
        │
        ▼
applies/assesses required protection
```

instead of relying on a developer remembering security configuration manually. ([AWS Documentation][35])

---

# 73. Firewall Manager Prerequisites

Firewall Manager operates with AWS Organizations and organization-level administration.

AWS also requires AWS Config to be enabled for relevant organization accounts and Regions used for Firewall Manager-managed resource evaluation. ([AWS Documentation][38])

So a central Firewall Manager architecture typically looks like:

```text
AWS Organizations
       │
       ▼
Firewall Manager Administrator
       │
       ▼
AWS Config resource visibility
       │
       ▼
Firewall Manager Policies
```

---

# 74. Delegated Administrator

Only the Organizations management account establishes Firewall Manager administrators; the default administrator becomes an Organizations delegated administrator for Firewall Manager. Current Firewall Manager also supports multiple administrators with scoped administrative responsibilities. ([AWS Documentation][39])

Better architecture:

```text
Management Account
   │
   ▼
designates
Security Account
   │
   ▼
Firewall Manager admin
```

rather than running daily security operations from the management account.

---

# 75. Firewall Manager Security Group Policies

Firewall Manager can centrally:

```text
apply common security groups

audit overly permissive rules

audit unused/redundant groups
```

across scoped organization resources. ([AWS Documentation][40])

Example policy:

```text
Production ALBs
must have:
CorporateInboundSG
```

or:

```text
No production EC2 SG
may allow SSH 0.0.0.0/0
```

depending on policy model.

---

# 76. Firewall Manager + Network Firewall

Firewall Manager can deploy centrally controlled Network Firewall policies across in-scope organization accounts/VPCs. ([AWS Documentation][41])

Architecture:

```text
Security Account
       │
       ▼
Firewall Manager
       │
       ▼
Corporate Network Firewall Policy
       │
  ┌────┼──────────────┐
  ▼    ▼              ▼
Dev   Staging        Prod
VPCs   VPCs           VPCs
```

Now networking teams don't have to hand-build firewall resources independently in every account.

---

# PART E — TERRAFORM

# 77. Terraform — WAF Baseline

Current HashiCorp AWS provider exposes:

```text
aws_wafv2_web_acl
```

for AWS WAF v2 Web ACLs. The resource requires either `REGIONAL` or `CLOUDFRONT` scope. ([Terraform Registry][42])

Regional ALB example:

```hcl
resource "aws_wafv2_web_acl" "app" {
  name  = "prod-app-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common-rules"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "prod-app-waf"
    sampled_requests_enabled   = true
  }
}
```

The managed common rule set is an AWS baseline protection rule group. ([AWS Documentation][7])

---

# 78. Associate WAF With ALB

Conceptually:

```hcl
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn
}
```

Now:

```text
Internet
   │
   ▼
ALB
   │
   ▼
Web ACL evaluation
   │
   ▼
Target Group
```

Each supported AWS resource can have only one associated Web ACL, while one Web ACL can protect multiple compatible resources subject to WAF association rules. ([AWS Documentation][43])

---

# 79. Terraform Rate Limit

Example login protection:

```hcl
rule {
  name     = "login-rate-limit"
  priority = 20

  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit                 = 100
      evaluation_window_sec = 300
      aggregate_key_type    = "IP"

      scope_down_statement {
        byte_match_statement {
          positional_constraint = "STARTS_WITH"
          search_string         = "/login"

          field_to_match {
            uri_path {}
          }

          text_transformation {
            priority = 0
            type     = "NONE"
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "login-rate-limit"
    sampled_requests_enabled   = true
  }
}
```

Remember: this is **approximate abuse protection**, not mathematically exact 100-request enforcement. ([AWS Documentation][11])

---

# 80. CloudFront WAF Terraform

For CloudFront:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name  = "cloudfront-global-waf"
  scope = "CLOUDFRONT"

  # rules...
}
```

This matches AWS's CloudFront WAF requirement that CloudFront-scoped WAF resources are managed through `us-east-1` / Global scope. ([AWS Documentation][3])

Notice how this mirrors:

```text
CloudFront ACM
→ us-east-1

CloudFront WAF
→ us-east-1 / global scope
```

but for different architectural reasons.

---

# 81. Terraform — Network Firewall Rule Group

The current AWS provider exposes:

```text
aws_networkfirewall_rule_group

aws_networkfirewall_firewall_policy

aws_networkfirewall_firewall
```

for Network Firewall construction. ([Terraform Registry][44])

A simplified stateful rule group:

```hcl
resource "aws_networkfirewall_rule_group" "stateful" {
  capacity = 100
  name     = "prod-egress-rules"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
alert tcp any any -> any any (
  msg:"Example monitored TCP traffic";
  sid:1000001;
  rev:1;
)
EOF
    }
  }
}
```

Suricata-compatible rules should always be thoroughly tested before production enforcement. AWS explicitly warns its examples are illustrative and must be adapted to your use case. ([AWS Documentation][45])

---

# 82. Terraform — Firewall Policy

Conceptually:

```hcl
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "prod-network-policy"

  firewall_policy {
    stateless_default_actions = [
      "aws:forward_to_sfe"
    ]

    stateless_fragment_default_actions = [
      "aws:forward_to_sfe"
    ]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful.arn
    }
  }
}
```

This forwards stateless-default traffic into the stateful firewall engine and attaches the stateful rules. The provider resource and AWS policy model both support this architecture. ([Terraform Registry][46])

---

# 83. Terraform — Firewall

Simplified:

```hcl
resource "aws_networkfirewall_firewall" "main" {
  name                = "prod-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.main.id

  subnet_mapping {
    subnet_id = aws_subnet.firewall_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.firewall_b.id
  }
}
```

But remember:

```text
creating firewall
≠
traffic automatically inspected.
```

You must update route tables so relevant paths traverse the firewall endpoints. AWS explicitly describes route-table configuration as part of Network Firewall traffic filtering. ([AWS Documentation][24])

---

# PART F — PRODUCTION CAPSTONE

# 84. Internet-Facing Production Architecture

Let's combine everything we've learned.

```text
                               USERS
                                 │
                                 ▼
                             Route 53
                                 │
                                 ▼
                         Shield Standard
                                 │
                      + Shield Advanced
                       where justified
                                 │
                                 ▼
                            CloudFront
                                 │
                                 ▼
                           GLOBAL WAF
                                 │
                  ┌──────────────┼──────────────┐
                  │              │              │
                  ▼              ▼              ▼
              Managed         Rate           Bot
               Rules          Rules         Control
                  │              │              │
                  └──────────────┼──────────────┘
                                 ▼
                              ALB
                                 │
                                 ▼
                         Private EC2/ECS
                                 │
                  ┌──────────────┴───────────────┐
                  ▼                              ▼
             Application                     Database

                   OUTBOUND / EAST-WEST TRAFFIC
                                 │
                                 ▼
                        Network Firewall
                                 │
                     Stateful IDS / IPS
                                 │
                                 ▼
                            NAT / TGW
                                 │
                                 ▼
                       Internet / other VPCs

                   MULTI-ACCOUNT GOVERNANCE
                                 │
                                 ▼
                         Firewall Manager
```

---

# 85. Which Layer Blocks Which Attack?

### SQL injection

```text
AWS WAF
```

### XSS

```text
AWS WAF
```

### Credential-stuffing bot

```text
WAF Bot Control
+
rate-based rule
+
application authentication controls
```

### HTTP request flood

```text
WAF rate rules
+
Shield Advanced application-layer protection
```

### Massive volumetric DDoS

```text
Shield
```

### EC2 reaching malware C2 domain

```text
Network Firewall
+
GuardDuty detection
```

### CVE in container

```text
Inspector
```

### Sensitive customer data in S3

```text
Macie
```

### Enforce WAF on every production ALB

```text
Firewall Manager
```

This is why AWS security architecture uses multiple layers rather than one “firewall service.”

---

# 86. Attack Scenario — Credential Stuffing

Attacker has:

```text
1 million stolen username/password pairs
```

They send:

```text
POST /login
POST /login
POST /login
...
```

Defense:

```text
Internet
   │
   ▼
WAF Bot Control
   │
   ▼
rate-based rule
   │
   ▼
CAPTCHA / Challenge
   │
   ▼
Application
   │
   ▼
MFA
```

Never rely solely on IP blocking because modern attackers distribute attempts across:

```text
botnets
proxies
cloud providers
residential IPs
```

Application authentication controls remain essential.

---

# 87. Attack Scenario — SQL Injection

```text
Attacker
  │
  ▼
?id=1' OR '1'='1
  │
  ▼
CloudFront
  │
  ▼
WAF
  │
  ▼
SQLi rule
  │
  ▼
BLOCK
```

But if the WAF is accidentally bypassed through a publicly reachable ALB origin:

```text
Attacker
   │
   └────────► ALB directly
```

then your CloudFront WAF may not help that bypass path.

This is why **origin protection** is part of WAF architecture—not merely enabling the Web ACL.

---

# 88. Protect the CloudFront Origin

If:

```text
CloudFront
→ ALB
```

is intended to be the only path, design the ALB so arbitrary users cannot casually bypass CloudFront.

Possible architecture controls include:

```text
network/origin access controls

trusted CloudFront-origin mechanisms

custom secret headers where appropriate

security-group architecture

WAF/origin validation
```

depending on the service design.

The security principle is:

```text
DO NOT BUILD A SECURE FRONT DOOR
AND LEAVE THE BACK DOOR OPEN.
```

---

# 89. False Positive Incident

You deploy managed WAF rule:

```text
Block
```

Suddenly `/api/search` receives:

```text
403
```

Runbook:

```text
1. Check WAF metrics.

2. Check sampled requests.

3. Check WAF logs.

4. Identify terminating rule.

5. Identify matching field.

6. Temporarily override specific rule to Count.

7. Confirm legitimate request.

8. Add narrow exclusion/scope.

9. Retest.

10. Restore Block where appropriate.
```

AWS recommends Count/action overrides specifically for managed-rule tuning and false-positive investigation. ([AWS Documentation][6])

---

# 90. Network Firewall Incident

Application can no longer access:

```text
api.vendor.com:443
```

After firewall deployment.

Troubleshoot in order:

```text
DNS works?

Route goes through correct endpoint?

Forward path correct?

Return path symmetric?

Stateless rule?

Stateful rule?

Domain/Suricata rule?

TLS inspection?

Alert logs?
```

Network Firewall logging and AWS's symmetric-routing troubleshooting guidance are central to this workflow. ([AWS Documentation][34])

---

# 91. Never Start by Disabling the Firewall

Bad:

```text
App broken
   │
   ▼
disable all firewall security
```

Better:

```text
identify path
     │
     ▼
logs
     │
     ▼
matched rule
     │
     ▼
minimal exception
     │
     ▼
validate
```

The goal is:

```text
restore required traffic
without creating
0.0.0.0/0 ANY ANY
```

everywhere.

---

# 92. Observability Stack

Production network-security logging might be:

```text
WAF
 └────► S3 / CloudWatch / Firehose

Network Firewall
 └────► S3 / CloudWatch / Firehose

Shield
 └────► CloudWatch / Shield events

CloudFront
 └────► access logs

ALB
 └────► access logs

VPC Flow Logs
 └────► network visibility

GuardDuty
 └────► threat findings

Security Hub
 └────► centralized findings
```

WAF and Network Firewall both support dedicated log delivery options, while Shield Advanced provides detailed DDoS event/metric visibility. ([AWS Documentation][17])

---

# 93. SAA-C03 Scenario

> Protect public application from SQL injection and XSS.

Think:

```text
AWS WAF
```

not:

```text
Network Firewall
```

because the requirement is HTTP application-request inspection. ([AWS Documentation][1])

---

# 94. SAA-C03 Scenario

> Protect against common DDoS attacks without purchasing an additional service.

Think:

```text
AWS Shield Standard
```

which is automatic for AWS customers. ([AWS Documentation][20])

---

# 95. Scenario

> Business-critical public financial application requires advanced DDoS visibility and expert response assistance.

Evaluate:

```text
Shield Advanced
```

with protected resources, health-based detection and appropriate SRT/support configuration. ([AWS Documentation][21])

---

# 96. Scenario

> Block connections from application VPCs to malicious external domains/IPs and inspect network flows centrally.

Think:

```text
AWS Network Firewall
```

possibly through:

```text
central inspection VPC
```

or the newer:

```text
Transit Gateway-attached firewall
```

depending on architecture. ([AWS Documentation][31])

---

# 97. Scenario

> Security team needs every new production ALB in every AWS account to automatically receive corporate WAF controls.

Think:

```text
AWS Organizations
+
Firewall Manager
+
WAF policy
```

Firewall Manager is specifically designed to maintain protections as new in-scope resources/accounts are introduced. ([AWS Documentation][35])

---

# 98. Scenario

> Web API should allow traffic but record how many requests would be blocked by a new managed rule set.

Use:

```text
COUNT
```

first. ([AWS Documentation][6])

---

# 99. Scenario

> Requirement says “exactly 100 API calls per minute per user.”

Do not automatically choose:

```text
WAF rate-based rule
```

because WAF rate enforcement is approximate, not a precise quota system. ([AWS Documentation][12])

Think instead about:

```text
API Gateway usage/rate controls
or
application/API-specific throttling
```

depending on requirements.

---

# 100. Scenario

> Need to inspect HTTPS payloads inside VPC network flows for security signatures.

Potential solution:

```text
Network Firewall TLS inspection
```

but only after evaluating certificate trust, privacy, compatibility and operational impact. ([AWS Documentation][33])

---

# 101. The Firewall Mental Model

```text
                       SECURITY CONTROL

                           Layer 7
                              │
                              ▼
                           AWS WAF
                              │
                 HTTP request inspection


                        DDoS perimeter
                              │
                              ▼
                         AWS Shield
                              │
                    availability defense


                        Network Layer
                              │
                              ▼
                    AWS Network Firewall
                              │
                    VPC flow inspection


                      Organization Layer
                              │
                              ▼
                      Firewall Manager
                              │
                   centralized enforcement
```

---

# 102. Never-Forget Rule Placement

```text
SQL injection
→ WAF

XSS
→ WAF

HTTP bot
→ WAF

Login flood
→ WAF rate rule


Network volumetric DDoS
→ Shield

Advanced DDoS response
→ Shield Advanced


Malicious outbound domain
→ Network Firewall

VPC-to-VPC inspection
→ Network Firewall


Apply WAF to 100 accounts
→ Firewall Manager
```

---

# 103. 30 Rules to Burn Into Memory

```text
1. AWS WAF protects HTTP(S) applications.

2. WAF is not a general-purpose VPC firewall.

3. Web ACL = ordered collection of WAF rules.

4. AWS now also calls Web ACLs
   protection packs in newer documentation.

5. CloudFront WAF uses CLOUDFRONT/global scope.

6. CloudFront WAF is managed through us-east-1.

7. Regional ALB/API Gateway uses REGIONAL WAF.

8. Managed rule groups provide baseline protection.

9. Managed rules do not replace secure code.

10. Test new rules using Count first.

11. WAF can detect SQLi and XSS patterns.

12. IP sets support reusable address controls.

13. Scope-down statements reduce rule scope.

14. Labels enable multi-stage rule decisions.

15. Rate-based rules are for abuse/DDoS-style rate control.

16. WAF rate limiting is approximate, not exact.

17. Current rate windows include 1/2/5/10 minutes.

18. Bot Control handles automated request traffic.

19. CAPTCHA is visible user verification.

20. Challenge can silently verify browser clients.

21. Shield Standard is automatic baseline DDoS protection.

22. Shield Advanced must protect designated resources.

23. Shield Advanced integrates with WAF for Layer 7 defense.

24. Network Firewall is managed stateful IDS/IPS/firewall.

25. Network Firewall uses stateless and stateful engines.

26. Stateful rules support Suricata-compatible syntax.

27. Routing must actually send traffic through the firewall.

28. Stateful inspection requires correct symmetric flows.

29. Firewall Manager centralizes protections
    across Organizations.

30. Security Groups + WAF + Shield + Network Firewall
    solve DIFFERENT problems.
```

And the single strongest rule:

```text
DO NOT ASK:

"Which AWS firewall is best?"
```

Ask:

```text
WHICH LAYER AM I PROTECTING?

HTTP application?
        → WAF

DDoS availability?
        → Shield

VPC network flows?
        → Network Firewall

organization-wide enforcement?
        → Firewall Manager
```

That is how an AWS architect chooses the correct control.

---

# ✅ Lesson 31 Part 5 Complete

You now understand:

```text
✓ AWS WAF
✓ Web ACL / protection pack
✓ Global vs Regional scope
✓ CloudFront vs ALB WAF
✓ supported WAF resources
✓ default actions
✓ ordered rules
✓ terminating vs non-terminating actions

✓ AWS Managed Rules
✓ Core Rule Set
✓ SQL injection
✓ XSS
✓ IP sets
✓ regex concepts
✓ scope-down statements
✓ WAF labels
✓ label chaining

✓ rate-based rules
✓ 1/2/5/10-minute evaluation windows
✓ approximate throttling
✓ custom aggregation keys
✓ login protection
✓ forwarded-IP pitfalls

✓ Bot Control
✓ CAPTCHA
✓ Challenge
✓ false-positive tuning
✓ Count-before-Block
✓ WAF logging
✓ log filtering/redaction

✓ Shield Standard
✓ Shield Advanced
✓ DDoS architecture
✓ application-layer DDoS mitigation
✓ Route 53 health-based detection
✓ Shield Response Team
✓ proactive engagement
✓ DDoS cost-protection concept

✓ AWS Network Firewall
✓ stateless engine
✓ stateful engine
✓ IDS/IPS
✓ Suricata-compatible rules
✓ AWS managed rule groups
✓ rule evaluation order
✓ egress filtering
✓ east-west filtering
✓ firewall endpoints
✓ symmetric routing
✓ inspection VPC
✓ Transit Gateway architecture
✓ new TGW-attached firewall model
✓ TLS inspection
✓ flow/alert/TLS logging

✓ Firewall Manager
✓ Organizations integration
✓ delegated administrator
✓ AWS Config prerequisite
✓ WAF policies
✓ Shield policies
✓ Network Firewall policies
✓ security-group policies
✓ Network ACL policies
✓ organization-wide enforcement

✓ Terraform WAF
✓ Terraform rate rules
✓ Terraform CloudFront scope
✓ Terraform Network Firewall
✓ production capstone
✓ SAA-C03/DOP-C02 scenarios
```

# ✅ Lesson 31 — AWS Security Architecture COMPLETE

Across Parts 1–5, we have completed:

```text
KMS
     │
     ▼
Encryption / cryptographic keys

Secrets Manager
Parameter Store
     │
     ▼
Secrets / configuration

ACM
TLS
     │
     ▼
Encryption in transit

GuardDuty
Inspector
Macie
Security Hub
     │
     ▼
Detection / vulnerability /
data security / central findings

WAF
Shield
Network Firewall
Firewall Manager
     │
     ▼
Perimeter / DDoS /
network inspection /
organization enforcement
```

So Lesson 31 is now fully closed.

# Next — Lesson 32

# **AWS Observability & Operational Monitoring — CloudWatch, CloudTrail, Config, EventBridge & Production Incident Visibility**

Next we'll connect every AWS service we've learned into one observability/control plane:

```text
                    APPLICATION
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Metrics          Logs           Traces
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                     CloudWatch
                         │
                  ┌──────┼───────┐
                  ▼      ▼       ▼
               Alarms  Logs   Dashboards


AWS API activity
      │
      ▼
CloudTrail


AWS resource configuration
      │
      ▼
AWS Config


AWS events / state changes
      │
      ▼
EventBridge
      │
      ▼
Lambda / SNS / SSM / Step Functions


                       INCIDENT
                          │
                          ▼
             Observe → Detect → Alert
                          │
                          ▼
              Diagnose → Automate
                          │
                          ▼
                       Recover
```

We’ll begin **Lesson 32 Part 1 with CloudWatch from first principles**: namespaces, metrics, dimensions, statistics, percentiles, high-resolution metrics, metric math, Logs, Logs Insights, alarms, composite alarms, anomaly detection, dashboards, agent architecture, application/system/custom metrics, ALB/EC2/RDS/EBS monitoring, Terraform, and production troubleshooting.

[1]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html?utm_source=chatgpt.com "AWS WAF"
[2]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html?utm_source=chatgpt.com "Configuring protection in AWS WAF"
[3]: https://docs.aws.amazon.com/waf/latest/developerguide/how-aws-waf-works-resources.html?utm_source=chatgpt.com "Resources that you can protect with AWS WAF"
[4]: https://docs.aws.amazon.com/waf/latest/developerguide/logging-fields.html?utm_source=chatgpt.com "Log fields for protection pack (web ACL) traffic - AWS Documentation"
[5]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-action.html?utm_source=chatgpt.com "Using rule actions in AWS WAF"
[6]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-rule-group-override-options.html?utm_source=chatgpt.com "Overriding rule group actions in AWS WAF"
[7]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html?utm_source=chatgpt.com "Baseline rule groups - AWS WAF"
[8]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statements-rule-group.html?utm_source=chatgpt.com "Using rule group rule statements in AWS WAF"
[9]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-label-overview.html?utm_source=chatgpt.com "How labeling works in AWS WAF"
[10]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html?utm_source=chatgpt.com "Using rate-based rule statements in AWS WAF"
[11]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-high-level-settings.html?utm_source=chatgpt.com "Rate-based rule high-level settings in AWS WAF"
[12]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-caveats.html?utm_source=chatgpt.com "Rate-based rule caveats in AWS WAF"
[13]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-aggregation-options.html?utm_source=chatgpt.com "Aggregating rate-based rules in AWS WAF"
[14]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rate-based-example-limit-login-page-keys.html?utm_source=chatgpt.com "Rate limit the requests to a login page from any IP address ..."
[15]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html?utm_source=chatgpt.com "AWS WAF Bot Control rule group"
[16]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-bot-control-rg-using.html?utm_source=chatgpt.com "Adding the AWS WAF Bot Control managed rule group to ..."
[17]: https://docs.aws.amazon.com/waf/latest/developerguide/logging.html "Logging AWS WAF protection pack (web ACL) traffic - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[18]: https://docs.aws.amazon.com/waf/latest/developerguide/logging-management-configure.html?utm_source=chatgpt.com "Configuring logging for a protection pack (web ACL) - AWS WAF ..."
[19]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-overview.html?utm_source=chatgpt.com "How AWS Shield and Shield Advanced work"
[20]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-standard-summary.html "AWS Shield Standard overview - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[21]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-advanced-summary-capabilities.html "AWS Shield Advanced capabilities and options - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[22]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-protections-by-resource-type.html?utm_source=chatgpt.com "List of resources that AWS Shield Advanced protects"
[23]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-advanced-health-checks.html?utm_source=chatgpt.com "Health-based detection using health checks with Shield ..."
[24]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html?utm_source=chatgpt.com "AWS Network Firewall - AWS Documentation"
[25]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-rules-engines.html?utm_source=chatgpt.com "Network Firewall stateless and stateful rules engines"
[26]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-policy-creating.html?utm_source=chatgpt.com "Creating a firewall policy in AWS Network Firewall"
[27]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/stateful-rule-groups-ips.html?utm_source=chatgpt.com "Working with stateful rule groups in AWS Network Firewall"
[28]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/nwfw-managed-rule-groups.html?utm_source=chatgpt.com "Managed rule groups in AWS Network Firewall"
[29]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/suricata-rule-evaluation-order.html?utm_source=chatgpt.com "Managing evaluation order for Suricata compatible rules in ..."
[30]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/troubleshooting-general-issues.html?utm_source=chatgpt.com "Troubleshooting general issues in AWS Network Firewall"
[31]: https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/centralized-network-security-for-vpc-to-vpc-and-on-premises-to-vpc-traffic.html?utm_source=chatgpt.com "Centralized network security for VPC-to-VPC and on- ..."
[32]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/tgw-firewall.html "Transit gateway-attached firewalls in Network Firewall - AWS Network Firewall"
[33]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/tls-inspection-considerations.html?utm_source=chatgpt.com "Considerations when working with TLS inspection ..."
[34]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-logging.html?utm_source=chatgpt.com "Logging network traffic from AWS Network Firewall"
[35]: https://docs.aws.amazon.com/waf/latest/developerguide/fms-chapter.html "AWS Firewall Manager - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[36]: https://docs.aws.amazon.com/waf/latest/developerguide/fms-chapter.html?utm_source=chatgpt.com "AWS Firewall Manager"
[37]: https://docs.aws.amazon.com/waf/latest/developerguide/policy-scope.html?utm_source=chatgpt.com "Using the AWS Firewall Manager policy scope"
[38]: https://docs.aws.amazon.com/waf/latest/developerguide/enable-config.html?utm_source=chatgpt.com "Enabling AWS Config for using Firewall Manager"
[39]: https://docs.aws.amazon.com/waf/latest/developerguide/enable-integration.html?utm_source=chatgpt.com "Creating an AWS Firewall Manager default administrator ..."
[40]: https://docs.aws.amazon.com/waf/latest/developerguide/security-group-policies.html?utm_source=chatgpt.com "Using security group policies in Firewall Manager to ..."
[41]: https://docs.aws.amazon.com/waf/latest/developerguide/getting-started-fms-network-firewall.html?utm_source=chatgpt.com "Setting up AWS Firewall Manager​ AWS Network Firewall ..."
[42]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl?utm_source=chatgpt.com "aws_wafv2_web_acl | Resources | hashicorp/aws | Terraform"
[43]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-associating-aws-resource.html?utm_source=chatgpt.com "Associating or disassociating protection with an AWS ..."
[44]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkfirewall_firewall?utm_source=chatgpt.com "aws_networkfirewall_firewall | Resources | hashicorp/aws"
[45]: https://docs.aws.amazon.com/network-firewall/latest/developerguide/suricata-examples.html?utm_source=chatgpt.com "Examples of stateful rules for Network Firewall"
[46]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkfirewall_firewall_policy?utm_source=chatgpt.com "aws_networkfirewall_firewall_pol..."
