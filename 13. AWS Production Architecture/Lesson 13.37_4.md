# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 4: Active/Passive Multi-Region — Route 53 Failover, Health Checks & Traffic Cutover

We now have the recovery environment.

```text
PRIMARY — Mumbai
ap-south-1
████████████

STANDBY — Singapore
ap-southeast-1
████
```

But there is one enormous unanswered question:

> **How do users stop reaching Mumbai and start reaching Singapore when the primary environment fails?**

That is today's topic.

---

# 37.252 The complete active/passive mental model

Our normal state:

```text
                         USERS
                           │
                           ▼
                        Route 53
                           │
                           │
                           ▼
                     PRIMARY RECORD
                           │
                           ▼
                      ap-south-1
                         Mumbai
                           │
                          ALB
                           │
                       Application
                           │
                        Database


                    ap-southeast-1
                       Singapore

                          ALB
                           │
                     Warm Standby
                           │
                       DR Database
```

Normal traffic:

```text
Users
  │
  └──────────────→ Mumbai
```

Singapore is:

```text
READY
but
PASSIVE
```

When Mumbai becomes unusable:

```text
Mumbai
  X

  ↓

Singapore promoted/validated

  ↓

traffic shifts

  ↓

Users → Singapore
```

Route 53 supports failover routing with **primary** and **secondary** records. When the primary is healthy, Route 53 returns it; when the primary is unhealthy and the secondary is healthy, Route 53 returns the secondary. ([AWS Documentation][1])

---

# 37.253 Active/passive does NOT mean secondary is off

This is important.

Active/passive describes:

```text
WHO SERVES NORMAL PRODUCTION TRAFFIC?
```

It does not necessarily describe:

```text
WHETHER INFRASTRUCTURE EXISTS.
```

For example:

```text
PRIMARY

Mumbai
ALB         ✓
ECS × 20    ✓
DB Primary  ✓


SECONDARY

Singapore
ALB         ✓
ECS × 2     ✓
DB Replica  ✓
```

Singapore can be:

```text
fully functional
+
continuously tested
+
not normally serving users
```

That's a classic:

# Warm Standby + Active/Passive traffic model.

---

# 37.254 Route 53 Failover Routing Policy

Suppose our public hostname is:

```text
api.example.com
```

We create two Route 53 records with the same name/type:

```text
api.example.com
        │
        ├── PRIMARY
        │      ↓
        │   Mumbai ALB
        │
        └── SECONDARY
               ↓
           Singapore ALB
```

Routing policy:

```text
FAILOVER
```

Route 53 failover routing is specifically designed to route to one resource while it is healthy and to a different resource when the primary becomes unhealthy. ([AWS Documentation][2])

---

# 37.255 Basic decision logic

Conceptually:

```text
                    DNS QUERY
                       │
                       ▼
               Is PRIMARY healthy?
                    /      \
                  YES       NO
                  │          │
                  ▼          ▼
               PRIMARY   SECONDARY
```

So:

```text
Mumbai healthy
    ↓
api.example.com
    ↓
Mumbai ALB
```

Failure:

```text
Mumbai unhealthy
    ↓
api.example.com
    ↓
Singapore ALB
```

Simple concept.

Production implementation is much more interesting.

---

# 37.256 Alias record vs normal DNS record

When routing an AWS DNS name such as an ALB through Route 53, you normally use a Route 53:

# Alias record.

Example:

```text
api.example.com

ALIAS
   ↓
Mumbai ALB
```

Route 53 alias records can point directly at supported AWS resources such as ELB load balancers and can also be used at the DNS zone apex, where a normal CNAME cannot. ([AWS Documentation][3])

---

# 37.257 Failover alias architecture

Example:

```text
api.example.com
     │
     ├── PRIMARY ALIAS
     │       │
     │       ▼
     │   Mumbai ALB
     │
     └── SECONDARY ALIAS
             │
             ▼
         Singapore ALB
```

For alias targets such as ALBs, Route 53 can use:

```text
Evaluate Target Health = Yes
```

so that the health of the underlying AWS target participates in DNS failover. ([AWS Documentation][4])

---

# 37.258 Evaluate Target Health

This setting is extremely important.

```text
EvaluateTargetHealth = true
```

conceptually tells Route 53:

> Don't blindly return this alias target. Consider the health of the resource behind the alias.

For Application and Network Load Balancers, Route 53 evaluates the load balancer based on the health of its associated target groups. A target group with registered targets needs at least one healthy target; a target group with no registered targets is considered unhealthy. ([AWS Documentation][4])

---

# 37.259 Architecture example

Mumbai ALB:

```text
Target Group:

App-A ✓
App-B ✓
App-C ✓
```

Route 53 sees the alias target as usable.

But suppose:

```text
App-A ✕
App-B ✕
App-C ✕
```

Now ALB target health becomes bad enough that Route 53 can stop selecting that alias in the failover configuration and use another healthy branch, such as Singapore. ([AWS Documentation][4])

---

# 37.260 Critical trap: load balancer health is not necessarily business health

Consider:

```text
GET /health
```

returns:

```text
200 OK
```

because the application process is running.

But:

```text
Database       ✕
Payment API    ✕
Critical queue ✕
```

Customers still cannot checkout.

Yet your load balancer might continue seeing:

```text
target = healthy
```

So Route 53 may see:

```text
PRIMARY = healthy
```

while the business application is effectively broken.

This is why:

# Your health signal must represent the failure you actually want to fail over for.

---

# 37.261 Infrastructure health vs application health

A poor health check:

```text
GET /health

if process running:
    return 200
```

This proves:

```text
web process exists
```

but perhaps not:

```text
application can perform
its critical business function.
```

A deeper health check could verify selected dependencies:

```text
App process
     ✓

Database reachable
     ✓

Critical configuration
     ✓

Critical internal dependency
     ✓
```

But be careful.

---

# 37.262 Health checks can cause cascading failovers

Imagine your application depends on:

```text
third-party analytics API
```

Analytics becomes unavailable.

Your `/health` endpoint marks the entire Region:

```text
UNHEALTHY
```

Route 53 fails to Singapore.

Singapore depends on the same analytics provider.

Singapore becomes:

```text
UNHEALTHY
```

Now you've performed a Regional failover for a dependency that could never be fixed by switching Regions.

Bad health criteria can therefore turn a small dependency outage into a larger recovery event.

So health checks should primarily represent:

> **Can this Region safely serve the critical workload?**

not:

> Is every optional dependency perfect?

---

# 37.263 Health-check categories

You can conceptually separate:

```text
LIVENESS

Is the process alive?


READINESS

Can this instance receive traffic?


REGIONAL READINESS

Can this Region serve production?


BUSINESS FUNCTION

Can critical transactions succeed?
```

Do not make all four identical.

This same mental model will return later when we study Kubernetes readiness/liveness and SRE.

---

# 37.264 Route 53 endpoint health checks

For non-alias resources or custom application health logic, Route 53 can perform health checks against endpoints.

AWS currently supports health-check request intervals of:

```text
30 seconds
```

or the faster:

```text
10 seconds
```

option, with an additional charge for fast health checks. ([AWS Documentation][5])

---

# 37.265 Failure Threshold

You also configure:

```text
Failure Threshold
```

meaning:

> How many consecutive checks must pass or fail before an individual Route 53 health checker changes its view of the endpoint?

AWS currently permits a failure threshold between **1 and 10 consecutive checks**. ([AWS Documentation][5])

Conceptually:

```text
Request interval = 30 sec
Failure threshold = 3
```

Do **not** simplistically calculate:

```text
failover exactly after 90 seconds
```

because Route 53 uses multiple distributed health checkers and aggregates their results.

---

# 37.266 Distributed Route 53 health checking

Route 53 doesn't have:

```text
one server somewhere
checking your endpoint.
```

Health checkers operate from multiple locations.

AWS aggregates their results and currently considers an endpoint healthy if **more than 18%** of health checkers report it healthy; 18% or fewer means unhealthy. AWS notes that this percentage can change. ([AWS Documentation][6])

Why distributed checking?

Imagine Mumbai is healthy but one network path from one part of the world has a transient issue.

You don't want:

```text
one checker fails
      ↓
entire Region declared dead.
```

Distributed observations make the health decision more resilient to localized network conditions. ([AWS Documentation][6])

---

# 37.267 Failure threshold trade-off

Suppose:

```text
threshold = 1
```

You react faster.

But a transient failure can trigger an unnecessary recovery action.

Suppose:

```text
threshold = 10
```

More confidence.

But genuine outage detection may be slower.

So:

```text
LOW THRESHOLD

faster
but
more sensitive


HIGH THRESHOLD

slower
but
more tolerant
```

This is an SRE trade-off:

# Detection speed vs false positives.

---

# 37.268 Fast health check trade-off

Similarly:

```text
10-second interval
```

may detect problems faster than:

```text
30-second interval
```

but it costs more and does not eliminate:

```text
DNS caching
application recovery actions
database promotion
```

from your overall RTO. AWS charges extra for the faster 10-second health-check interval. ([AWS Documentation][5])

So never promise:

> "10-second health check means 10-second DR."

No.

---

# 37.269 Failover time has several components

Think:

```text
TOTAL RECOVERY

Failure happens
      │
      ▼
Failure detected
      │
      ▼
Health state changes
      │
      ▼
Data layer made safe
      │
      ▼
DR scaled/promoted
      │
      ▼
DNS starts returning DR
      │
      ▼
DNS caches expire
      │
      ▼
Clients reconnect
      │
      ▼
Application stable
```

Therefore:

```text
RTO
≠
health-check interval
```

---

# 37.270 DNS TTL

TTL:

# Time To Live

tells DNS resolvers how long an answer may be cached.

Example:

```text
TTL = 300 seconds
```

Resolver asks:

```text
api.example.com?
```

and caches:

```text
Mumbai endpoint
```

for potentially:

```text
300 seconds
```

before needing a new authoritative answer.

AWS recommends choosing TTL according to how quickly you need DNS changes to take effect; shorter TTLs increase responsiveness but also increase DNS query frequency. ([AWS Documentation][7])

---

# 37.271 Failover + non-alias TTL guidance

For Route 53 failover **non-alias records** associated with health checks, AWS recommends:

```text
TTL ≤ 60 seconds
```

so clients can respond relatively quickly when health changes. ([AWS Documentation][8])

Do not turn this into:

```text
60-second TTL
=
exactly 60-second failover.
```

There are still other pieces of the recovery sequence.

---

# 37.272 Alias TTL is different

For an alias record pointing to an AWS resource:

```text
you do not configure the TTL yourself
```

Route 53 uses the target AWS resource's TTL.

For ELB load balancers, the relevant TTL is currently **60 seconds**. ([AWS Documentation][9])

This is a common certification/interview nuance.

---

# 37.273 DNS change propagation vs DNS caching

These are different.

### Route 53 change propagation

You update a record.

Route 53 generally propagates record changes to its authoritative name servers within about:

```text
60 seconds
```

according to current AWS documentation. ([AWS Documentation][3])

### Resolver/client caching

A recursive resolver may already have the old answer cached according to TTL.

That cached answer can continue to be used until it expires.

So:

```text
AUTHORITATIVE DNS UPDATED
```

doesn't mean:

```text
EVERY CLIENT IMMEDIATELY HAS NEW IP.
```

---

# 37.274 "DNS propagation takes 48 hours" myth

You'll often hear:

> "DNS changes take 24–48 hours."

That's an oversimplification.

Different DNS records have different TTLs and caching behavior. Long-lived NS/delegation caching can indeed last much longer, but ordinary Route 53 record changes generally propagate quickly to Route 53's own name servers; the main client-visible delay for an existing record is often cached DNS data. ([AWS Documentation][10])

For DR, think:

```text
authoritative update
+
resolver caching
+
client connection behavior
```

not vague "DNS propagation."

---

# 37.275 Existing TCP connections do not magically move

Suppose user already has:

```text
TCP connection
      ↓
Mumbai ALB
```

Then Route 53 starts returning:

```text
Singapore
```

for **new DNS queries**.

The existing established connection does not teleport to Singapore.

The client/application typically needs to:

```text
disconnect/retry/re-resolve
```

according to its own connection behavior.

This is especially important for:

```text
long-lived WebSockets
database connections
streaming sessions
persistent HTTP connections
```

DNS failover primarily influences endpoint resolution for subsequent connection attempts.

---

# 37.276 Connection pools can extend recovery behavior

Example Java application:

```text
DNS TTL = 60 sec
```

but it maintains a backend connection pool for:

```text
30 minutes
```

Changing DNS does not necessarily force those existing pooled connections to reopen immediately.

So Multi-Region recovery must consider:

```text
DNS cache
+
application DNS cache
+
connection pool
+
retry logic
+
backoff
```

Client behavior is part of architecture.

---

# 37.277 Route 53 failover sequence — naive version

Naive design:

```text
Mumbai unhealthy
       ↓
Route 53
       ↓
Singapore
```

But for stateful applications this can be dangerous.

What if:

```text
Singapore DB
```

is still:

```text
READ REPLICA
```

when traffic starts arriving?

Customers receive:

```text
read-only errors
```

or worse.

Therefore traffic failover often must be coordinated with:

# Data promotion.

---

# 37.278 Safer stateful failover sequence

Conceptually:

```text
STEP 1
Detect primary failure

      ↓

STEP 2
Determine disaster is genuine

      ↓

STEP 3
Fence/stop writes to old primary
where required/possible

      ↓

STEP 4
Verify replication state

      ↓

STEP 5
Promote DR data layer

      ↓

STEP 6
Update DR application configuration
if required

      ↓

STEP 7
Scale/verify DR application

      ↓

STEP 8
Smoke test

      ↓

STEP 9
SHIFT USER TRAFFIC

      ↓

STEP 10
Monitor
```

This is why blindly tying every Region-level failover to a simplistic endpoint check can be unsafe for stateful systems.

---

# 37.279 Split-brain risk

Imagine:

```text
Mumbai DB
still accepting writes
```

while you promote:

```text
Singapore DB
```

and users reach both.

Now:

```text
Mumbai writes
+
Singapore writes
```

can diverge.

Conceptually:

```text
                  NETWORK PARTITION

               /                     \
              ▼                       ▼
         Mumbai Primary          Singapore Promoted
           WRITES ✓                 WRITES ✓

               \                     /
                \                   /
                   DATA CONFLICT
```

This is:

# Split brain.

Avoiding it is one of the central challenges of stateful Multi-Region recovery.

---

# 37.280 Fencing

A useful distributed-systems term:

# Fencing

means making sure an old primary can no longer perform conflicting operations before the replacement is allowed to become authoritative.

Conceptually:

```text
OLD PRIMARY

writes
  X

      ↓

NEW PRIMARY

writes
  ✓
```

The exact mechanism depends on the database/service architecture.

But the principle is universal:

> Before creating a new writer, know what happened to the old writer.

---

# 37.281 Automatic traffic failover is easier for stateless workloads

For a static web frontend:

```text
Mumbai frontend X
Singapore frontend ✓
```

automated Route 53 failover is relatively straightforward.

For:

```text
financial database writer
```

automatic failover may require much stronger controls because changing traffic may also imply:

```text
changing data authority.
```

So:

```text
stateless traffic failover
```

and:

```text
stateful writer promotion
```

should not be mentally treated as the same thing.

---

# 37.282 Secondary health checking

Should we monitor Singapore too?

Absolutely.

Otherwise the logic could be:

```text
Mumbai ✕
     ↓
Route 53
     ↓
Singapore
```

but Singapore is also broken.

Route 53 supports health evaluation of both primary and secondary records. ([AWS Documentation][11])

This gives us:

```text
Primary healthy?
Secondary healthy?
```

rather than assuming secondary readiness.

---

# 37.283 Very important Route 53 fail-open behavior

Here is a surprising current behavior.

With health checks on both failover records:

```text
Primary unhealthy
Secondary unhealthy
```

Route 53 returns the:

# PRIMARY record.

AWS documents this explicitly. ([AWS Documentation][11])

Why?

Route 53 routing algorithms include a last-resort/fail-open behavior rather than returning no usable record solely because every configured endpoint is marked unhealthy. ([AWS Documentation][12])

---

# 37.284 Never assume "everything unhealthy = DNS stops answering"

It does not necessarily work that way.

This is a very good interview trap.

```text
Primary unhealthy
Secondary unhealthy
```

does not mean:

```text
Route 53 returns nothing
```

in the standard failover behavior described above.

For primary/secondary failover health checks, Route 53 can return primary as the fail-open outcome. ([AWS Documentation][11])

Architecture implication:

> Your application still needs graceful failure behavior even when the routing layer has no healthy destination.

---

# 37.285 What if the secondary has no health check?

AWS permits the secondary failover record to omit a health check.

In that configuration, if the primary is unhealthy, Route 53 treats the secondary as available and returns it—even if the secondary itself is actually broken. ([AWS Documentation][11])

Production lesson:

```text
NO HEALTH CHECK
=
Route 53 has no evidence
that endpoint is unhealthy.
```

So don't confuse:

```text
not monitored
```

with:

```text
healthy.
```

---

# 37.286 Route 53 health checks and ALB health checks are different

ALB target health:

```text
ALB
  │
  ▼
checks targets
```

Route 53 health checking:

```text
Route 53
   │
   ▼
checks endpoint / health signal
```

When aliasing Route 53 to an ALB, AWS recommends using:

```text
Evaluate Target Health
```

rather than creating separate Route 53 health checks for the individual EC2 targets already registered with the ELB. ([AWS Documentation][4])

Don't duplicate the wrong layer of checking.

---

# 37.287 Calculated health checks

Suppose regional readiness depends on:

```text
API health
Database health
Queue health
Authentication health
```

Route 53 supports calculated health checks that monitor the health state of other health checks. ([AWS Documentation][13])

Conceptually:

```text
Regional Health
       │
       ├── API ✓
       ├── DB  ✓
       ├── Auth ✓
       └── Queue ✓
```

You can build more sophisticated health logic than checking one machine.

But complexity should be deliberate.

---

# 37.288 Don't make DR health too fragile

Bad:

```text
Region healthy only if

100% of:
metrics
analytics
recommendations
email
reporting
batch
search
all pass
```

One low-priority service fails:

```text
email ✕
```

Entire Region:

```text
FAILOVER!
```

That's often poor resilience design.

Better to define:

```text
CRITICAL SERVICE HEALTH
```

separately from:

```text
NONCRITICAL DEGRADATION.
```

This is graceful degradation.

---

# 37.289 Example regional health endpoint

Suppose:

```text
https://dr-health.example.com/region
```

checks:

```text
Application critical path  ✓
Database read/write status ✓
Authentication             ✓
```

but does not fail the Region merely because:

```text
analytics export ✕
```

That's closer to business-oriented readiness.

---

# 37.290 Route 53 failover Terraform preview

Conceptually:

```hcl
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  set_identifier = "mumbai-primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }
}
```

Secondary:

```hcl
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  set_identifier = "singapore-secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_lb.dr.dns_name
    zone_id                = aws_lb.dr.zone_id
    evaluate_target_health = true
  }
}
```

The resource structure maps directly to Route 53's primary/secondary failover-record model and alias target-health evaluation. ([AWS Documentation][4])

---

# 37.291 Terraform doesn't solve the data-order problem

Terraform can create:

```text
Route 53 records ✓

ALBs ✓

Singapore stack ✓
```

but Terraform doesn't inherently know:

> Is it safe to make Singapore the primary writer right now?

That requires recovery orchestration.

This is why DR usually combines:

```text
Infrastructure as Code
+
operational workflow
+
health signals
+
data promotion
+
traffic control
```

not Terraform alone.

---

# 37.292 Manual failover model

One safe model for critical applications:

```text
Monitoring detects outage
        │
        ▼
Incident declared
        │
        ▼
Human verifies failure scope
        │
        ▼
Promote DR data
        │
        ▼
Scale application
        │
        ▼
Smoke test
        │
        ▼
Traffic shift approved
```

Advantages:

```text
more control
less risk of false regional promotion
```

Disadvantages:

```text
slower
human response time
potential mistakes
```

---

# 37.293 Automatic failover model

```text
Health failure
     │
     ▼
Automation
     │
     ├── data operation
     ├── app scaling
     ├── validation
     └── traffic shift
```

Advantages:

```text
faster
repeatable
```

Risks:

```text
false failover
split brain
automation bug
bad health signal
```

The more aggressive your RTO, the more automation tends to matter—but safety controls become more important too.

---

# 37.294 Controlled failover is often better than blind failover

For critical stateful systems:

```text
DETECT AUTOMATICALLY
```

doesn't necessarily imply:

```text
PROMOTE WRITER AUTOMATICALLY.
```

A mature workflow might:

```text
Detect automatically
       ↓
page incident team
       ↓
collect evidence automatically
       ↓
pre-stage recovery
       ↓
controlled approval
       ↓
promote
       ↓
traffic cutover
```

That's often safer than a simplistic:

```text
one failed health check
→ global database promotion.
```

---

# 37.295 Weighted routing for canary recovery

Failover routing is:

```text
PRIMARY
or
SECONDARY
```

But sometimes after recovery we want:

```text
1% traffic
      ↓
DR

99%
      ↓
Primary
```

Then:

```text
10 / 90

25 / 75

50 / 50

100 / 0
```

Route 53 **weighted routing** allows you to assign relative weights among records with the same name/type. ([AWS Documentation][14])

This can help with:

```text
controlled migration
canary testing
failback
regional validation
```

---

# 37.296 Weighted DNS is not exact per-request traffic splitting

Suppose:

```text
Mumbai weight = 90

Singapore weight = 10
```

Do not assume:

```text
exactly every 10th HTTP request
goes to Singapore.
```

Route 53 operates at the DNS-answer level, and recursive resolvers can cache answers.

Therefore actual request distribution can differ from the configured DNS weights.

Think:

```text
DNS RESPONSE DISTRIBUTION
```

rather than:

```text
L7 request load balancer.
```

---

# 37.297 Canary failback

Imagine Singapore became primary during disaster.

Mumbai is restored.

Don't immediately:

```text
Singapore 100%
   ↓
Mumbai 100%
```

You could instead validate:

```text
Mumbai 1%
Singapore 99%

       ↓

Mumbai 10%
Singapore 90%

       ↓

Mumbai 50%
Singapore 50%

       ↓

Mumbai 100%
```

provided your application/data architecture safely supports this traffic pattern.

This is particularly useful when the application tier can accept gradual traffic while the database/write architecture remains safely controlled.

---

# 37.298 Route 53 is DNS-based traffic control

This means it depends on:

```text
DNS resolution
TTL
resolver caching
client behavior
```

For many workloads, that's entirely appropriate.

But AWS has another important Multi-Region traffic service:

# AWS Global Accelerator.

---

# 37.299 Global Accelerator mental model

Instead of exposing regional endpoints directly to clients:

```text
User
   │
   ▼
Global Accelerator
Static Anycast IPs
   │
   ├──────────→ Mumbai
   │
   └──────────→ Singapore
```

Global Accelerator provides static anycast addresses advertised from the AWS edge network. A standard IPv4 accelerator currently receives **two static IPv4 addresses**; dual-stack adds two IPv6 addresses as well. ([AWS Documentation][15])

---

# 37.300 Why static addresses matter

With Route 53 Regional endpoints:

```text
DNS
 ↓
regional destination
```

Failover affects future DNS answers.

With Global Accelerator:

```text
client
  ↓
same accelerator IPs
```

while AWS changes which healthy regional endpoint receives traffic behind those addresses. Global Accelerator's static anycast addressing therefore avoids requiring clients to learn a different public IP just because your backend Region changes. ([AWS Documentation][16])

This is useful when clients:

```text
cache DNS aggressively

use IP allowlists

need stable public IP addresses
```

or when faster network-layer traffic steering is desirable.

---

# 37.301 Global Accelerator endpoint groups

Conceptually:

```text
Accelerator
    │
    ├── Endpoint Group
    │      Mumbai
    │       │
    │       └── Mumbai ALB
    │
    └── Endpoint Group
           Singapore
            │
            └── Singapore ALB
```

Global Accelerator routes users based on factors including client location and endpoint-group/endpoint health. ([AWS Documentation][17])

---

# 37.302 Global Accelerator health behavior

Global Accelerator continuously monitors endpoints and normally directs traffic to healthy active endpoints. ([AWS Documentation][18])

So:

```text
Mumbai unhealthy
        │
        ▼
Global Accelerator
        │
        ▼
healthy endpoint elsewhere
```

can be an alternative to DNS-based regional failover for supported public application architectures.

---

# 37.303 Traffic Dial

Global Accelerator endpoint groups have a:

# Traffic Dial

which lets you control the percentage of traffic that an endpoint group accepts from traffic that Global Accelerator would otherwise direct to that group. ([AWS Documentation][19])

Conceptually:

```text
Mumbai Group
Traffic Dial 100%


Singapore Group
Traffic Dial 0%
```

Then during a migration or controlled recovery:

```text
Singapore
0%
 ↓
10%
 ↓
50%
 ↓
100%
```

depending on architecture and routing behavior.

---

# 37.304 Route 53 vs Global Accelerator

| Characteristic                      | Route 53 Failover                                  | Global Accelerator                                |
| ----------------------------------- | -------------------------------------------------- | ------------------------------------------------- |
| Traffic decision                    | DNS                                                | Network edge/accelerator                          |
| Client entry point                  | DNS answer may lead to different regional endpoint | Static anycast IPs                                |
| DNS caching affects endpoint change | Yes                                                | Backend changes don't require new accelerator IPs |
| Health routing                      | Yes                                                | Yes                                               |
| Weighted/canary options             | Route 53 weighted policies                         | Traffic dials / endpoint weights                  |
| Useful for                          | DNS-based global routing                           | Static-IP, global TCP/UDP acceleration/failover   |

Global Accelerator provides static anycast entry addresses and health-based endpoint routing, while Route 53 provides DNS routing policies such as failover and weighted routing. ([AWS Documentation][20])

Do not memorize:

```text
Global Accelerator > Route 53
```

or vice versa.

They solve overlapping but different traffic-management problems.

---

# 37.305 CloudFront is yet another layer

For HTTP content/application delivery, you may also have:

```text
Users
  │
CloudFront
  │
  ▼
Origin
```

Multi-Region architecture can involve:

```text
CloudFront
Route 53
Global Accelerator
ALB
```

depending on the workload.

Do not select a service merely because it says "global."

Ask:

```text
Are we routing DNS?

Accelerating TCP/UDP?

Serving cached HTTP content?

Controlling application recovery?
```

Different layers, different tools.

---

# 37.306 Failover should not be based on one metric alone

Imagine:

```text
HTTP health check = failing
```

but:

```text
application traffic successful
```

Maybe the health endpoint itself is broken.

Or:

```text
CPU = 100%
```

but autoscaling is successfully absorbing load.

A Regional disaster signal should ideally use multiple pieces of evidence.

Possible evidence:

```text
synthetic transaction

ALB target health

5xx rate

latency

database health

critical dependency health

regional synthetic checks
```

The exact policy is workload-specific.

---

# 37.307 Synthetic transaction

A stronger health probe for an e-commerce API might execute:

```text
DNS resolve
   ↓
TLS
   ↓
GET /catalog/test
   ↓
read database
   ↓
expected response
```

rather than:

```text
is port 443 open?
```

This validates more of the critical customer path.

But again:

```text
do not create side effects
```

such as making real payments every 10 seconds.

---

# 37.308 Health check design rule

Good health check:

```text
fast
safe
cheap
deterministic
representative
```

Bad health check:

```text
slow
performs real transaction
depends on 15 optional systems
creates side effects
fails randomly
```

Monitoring can itself become a source of instability if poorly designed.

---

# 37.309 Regional health vs instance health

Suppose:

```text
10 ECS tasks
```

and:

```text
1 task fails
```

That's not necessarily a:

```text
REGIONAL DISASTER.
```

ALB and ECS should handle task-level failure locally.

Failing over an entire Region because:

```text
one container died
```

would be poor architecture.

Remember our hierarchy:

```text
Task failure
→ container orchestration


Instance failure
→ Auto Scaling


AZ failure
→ Multi-AZ


Regional service/workload failure
→ Multi-Region DR
```

Use the correct resilience layer.

---

# 37.310 Avoid failover flapping

Suppose:

```text
Mumbai unhealthy
   ↓
Singapore

30 sec later

Mumbai healthy
   ↓
Mumbai

30 sec later

Mumbai unhealthy
   ↓
Singapore
```

That's:

# Flapping.

Possible consequences:

```text
session disruption

data complications

operational confusion

cache churn

repeated scale events
```

Failback should therefore usually be more conservative than failover.

---

# 37.311 Failover and failback can have different thresholds

Conceptually:

```text
FAILOVER

Require strong evidence that
primary is unavailable.


FAILBACK

Require even stronger evidence that
primary is stable again.
```

For example:

```text
Primary healthy for
a sustained observation period
       +
data synchronized
       +
capacity validated
       +
manual approval
```

before returning traffic.

Don't automatically fail back just because one green health check appears.

---

# 37.312 Recovery state machine

Think of DR as states:

```text
NORMAL_PRIMARY
      │
      ▼
PRIMARY_DEGRADED
      │
      ▼
FAILOVER_PENDING
      │
      ▼
DR_PROMOTING
      │
      ▼
DR_ACTIVE
      │
      ▼
PRIMARY_RECOVERING
      │
      ▼
FAILBACK_READY
      │
      ▼
NORMAL_PRIMARY
```

This is much safer than thinking:

```text
Mumbai
↔
Singapore
```

as one binary switch.

---

# 37.313 Runbook example

### Phase 1 — Detection

```text
Primary health alarms
        ↓
confirm scope
```

### Phase 2 — Data safety

```text
Check writer state
Check replication lag
Fence old writer
Promote DR if required
```

### Phase 3 — Capacity

```text
Scale Singapore
```

### Phase 4 — Validation

```text
/health
synthetic transaction
critical dependency tests
```

### Phase 5 — Traffic

```text
Route 53 / ARC / GA shift
```

### Phase 6 — Monitoring

```text
5xx
latency
DB load
queue backlog
customer transactions
```

### Phase 7 — Stabilization

```text
declare DR active
```

That's a real recovery workflow.

---

# 37.314 DNS cutover should be late in the sequence

One strong operational principle:

```text
PREPARE DESTINATION
       ↓
VALIDATE DESTINATION
       ↓
THEN
SHIFT TRAFFIC
```

not:

```text
shift traffic
       ↓
hope Singapore becomes ready.
```

For Warm Standby:

```text
scale
promote
validate
traffic
```

is generally safer than:

```text
traffic
scale
promote
```

especially for stateful systems.

---

# 37.315 The "ready before traffic" rule

Memorize:

> **Traffic shifting is the last visible step of recovery, not the first step.**

Before traffic moves, verify:

```text
data ready
compute ready
secrets ready
certificate ready
dependencies ready
capacity ready
```

Then:

```text
users
 ↓
DR
```

---

# 37.316 Route 53 alone is not DR

This is one of the biggest misconceptions.

You could configure:

```text
PRIMARY → Mumbai
SECONDARY → Singapore
```

perfectly.

But Singapore has:

```text
no images
no secret
DB stale
certificate expired
```

DNS successfully routes users to:

```text
a broken DR environment.
```

Route 53 solves:

```text
WHERE USERS GO
```

not:

```text
WHETHER DR IS ACTUALLY READY.
```

---

# 37.317 Health check alone is not DR

Similarly:

```text
health check says green
```

doesn't prove:

```text
full load capacity
write safety
failback readiness
data correctness
```

Health signals are one part of:

```text
Recovery control plane.
```

---

# 37.318 Route 53 failover exam scenario

Question:

> An application runs primarily behind an ALB in `ap-south-1` and has a standby ALB in `ap-southeast-1`. DNS should normally resolve to Mumbai and switch to Singapore if the primary becomes unhealthy.

Think:

```text
Route 53
Failover Routing Policy
     │
     ├── PRIMARY alias → Mumbai ALB
     └── SECONDARY alias → Singapore ALB
```

with appropriate target-health evaluation/health-check design. Route 53 explicitly supports this active-passive model. ([AWS Documentation][1])

---

# 37.319 Interview trap — "TTL is 60, so RTO is 60 seconds."

Wrong.

RTO may include:

```text
failure detection
data promotion
standby scaling
application validation
Route 53 health-state change
DNS caching
client reconnect
```

TTL is only one component.

---

# 37.320 Interview trap — "Route 53 health checks replace ALB health checks."

No.

ALB health checks determine which registered targets should receive traffic.

Route 53 health behavior decides which DNS record/resource branch should be returned.

For Route 53 alias records targeting ELB, Evaluate Target Health can leverage the load balancer's target-group health rather than creating Route 53 health checks for each registered EC2 instance. ([AWS Documentation][4])

---

# 37.321 Interview trap — "Secondary doesn't need testing because it receives no users."

Wrong.

That's exactly why it needs deliberate testing.

Otherwise:

```text
Mumbai X
     ↓
Singapore selected
     ↓
first real customer traffic
becomes your DR test.
```

Terrible strategy.

Warm Standby should be continuously or regularly validated.

---

# 37.322 Interview trap — "Route 53 stops returning records if both Regions fail."

Not necessarily.

In the documented failover behavior, when both monitored primary and secondary failover records are unhealthy, Route 53 returns the primary record as the fail-open/last-resort result. ([AWS Documentation][11])

This is a particularly good advanced Route 53 question.

---

# 37.323 Interview trap — "A DNS change instantly moves existing sessions."

No.

DNS affects name resolution.

Existing established connections have their own lifecycle.

The application/client must reconnect and may need to perform a new DNS lookup before receiving the new endpoint.

---

# 37.324 Route 53 vs Global Accelerator interview answer

A strong answer:

> **Route 53 provides DNS-based routing policies such as failover and weighted routing, so changes are subject to DNS resolution and caching behavior. Global Accelerator gives clients stable anycast IP entry points and routes traffic through AWS's edge/network toward healthy regional endpoints, which is useful when static IPs or network-layer global failover are important.**

Global Accelerator's static anycast addresses and health-based endpoint routing are current documented capabilities. ([AWS Documentation][16])

---

# 37.325 Architecture selection example

### Public REST application

Requirements:

```text
normal DR
DNS acceptable
RTO tens of minutes
```

Possible:

```text
Route 53 failover
+
Warm Standby
```

### TCP application with customer firewall allowlists

Requirements:

```text
stable ingress IP addresses
regional failover
```

Strong candidate to evaluate:

```text
Global Accelerator
```

because its accelerator exposes stable anycast addresses. ([AWS Documentation][15])

### CDN website

Think:

```text
CloudFront
+
origin resilience strategy
```

Different problem again.

---

# 37.326 Final production architecture

Now our Warm Standby looks much more complete:

```text
                         GLOBAL USERS
                              │
                 ┌────────────┴────────────┐
                 │                         │
             Route 53                or Global
             Failover                 Accelerator
                 │                         │
                 └────────────┬────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼

           ap-south-1                 ap-southeast-1
              MUMBAI                     SINGAPORE

            PRIMARY                      STANDBY
               │                            │
              ALB                          ALB
               │                            │
           ECS × 20                      ECS × 2
               │                            │
               ▼                            ▼
            WRITER DB ───── replicate ─→ DR DATA

             ECR ─────────── replicate ─→ ECR

           Secrets ───────── replicate ─→ Secrets

             ACM                         ACM
            Regional                    Regional

                 │                         │
                 └──────── monitoring ─────┘

                           RECOVERY FLOW

                         detect failure
                              │
                         validate state
                              │
                         promote data
                              │
                          scale DR
                              │
                         smoke test
                              │
                       SHIFT TRAFFIC
                              │
                           monitor
```

That is a much closer representation of real Multi-Region Active/Passive DR.

---

# 37.327 The complete failover timing equation

Conceptually:

```text
RTO ≈

Detection Time
      +
Decision Time
      +
Data Promotion Time
      +
DR Scaling Time
      +
Validation Time
      +
Traffic Shift Time
      +
Client Recovery Time
```

Not every application has all of those stages, but this framework is extremely useful when challenging an RTO target.

Business:

```text
RTO = 10 minutes
```

Engineer:

```text
DB promotion         6 min
App scaling          4 min
Validation           3 min
DNS/client recovery  ? min
```

Already impossible.

Architecture must change.

---

# 37.328 Never-forget Part 4 rules

```text
1.

Route 53 failover uses:
PRIMARY + SECONDARY.


2.

Evaluate Target Health lets
alias records consider the
health of supported AWS targets.


3.

A health check should represent
whether the Region can safely
serve the critical workload.


4.

Health interval
≠
RTO.


5.

TTL
≠
exact failover time.


6.

DNS changes do not move
existing TCP sessions.


7.

Promote/prepare stateful data
before sending users there.


8.

Both Regions need health/readiness
validation.


9.

Route 53 can fail open when
all failover destinations are unhealthy.


10.

Traffic shift should happen
AFTER the DR stack is ready.


11.

Failover is not complete
until failback is planned.


12.

DNS failover is only one piece
of Disaster Recovery.
```

---

# 37.329 One diagram to remember forever

```text
                    ACTIVE/PASSIVE DR

                         USERS
                           │
                           ▼
                      TRAFFIC LAYER
                 Route53 / Accelerator
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼

        PRIMARY REGION               DR REGION
          MUMBAI                    SINGAPORE

           FULL                        SMALL
            │                           │
         App/Data      replication    App/Data
            │ ────────────────────────→ │
            │                           │
            │                        READY?
            │                           │
          HEALTH                        │
            │                           │
            X                           │
                                        ▼
                                    PROMOTE
                                        │
                                      SCALE
                                        │
                                    VALIDATE
                                        │
                                  SHIFT TRAFFIC
                                        │
                                        ▼
                                    DR ACTIVE
```

---

# 37.330 Part 4 complete

Lesson 37 now stands at:

```text
Part 1
HA vs DR + RTO/RPO               ✓

Part 2
Backup & Restore                 ✓

Part 3
Pilot Light + Warm Standby       ✓

Part 4
Active/Passive Multi-Region      ✓

Part 5
Active/Active Multi-Region       NEXT

Part 6
Multi-Region Data Layer

Part 7
Application Recovery Controller

Part 8
DR Automation / Testing / Chaos

Part 9
Multi-Region Capstone

Part 10
Final Revision
```

# Next — Lesson 37, Part 5

## Multi-Region Active/Active — The Distributed-Systems Problem

Now things become considerably more advanced.

We'll change:

```text
Mumbai
ACTIVE

Singapore
PASSIVE
```

into:

```text
Mumbai
ACTIVE
   +
Singapore
ACTIVE
```

and then answer the difficult questions:

```text
How are users distributed?

Where do writes go?

Can both Regions write?

What happens during replication lag?

What happens during a network partition?

What is split brain?

How do we handle idempotency?

What happens to sessions?

How do DynamoDB Global Tables behave?

How does Aurora Global Database differ?

What is active/active vs active/read-local?

How do we design conflict resolution?

How do queues/events work across Regions?

Can we really claim RPO = 0?

What happens when one Region returns?

How do we stop a global bad deployment?

How do we prevent a logical corruption
from immediately spreading everywhere?
```

That will take us from **AWS DR architecture into real distributed-systems engineering**.

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-types.html?utm_source=chatgpt.com "Active-active and active-passive failover - Amazon Route 53"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-failover.html?utm_source=chatgpt.com "Failover routing"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html?utm_source=chatgpt.com "Routing traffic to an ELB load balancer - Amazon Route 53"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-failover-alias.html?utm_source=chatgpt.com "Values specific for failover alias records - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-creating-values.html?utm_source=chatgpt.com "Values that you specify when you create or update health checks"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-determining-health-of-endpoints.html?utm_source=chatgpt.com "How Amazon Route 53 determines whether a health check ..."
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-dns.html?utm_source=chatgpt.com "Best practices for Amazon Route 53 DNS"
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-failover.html?utm_source=chatgpt.com "Values specific for failover records - Amazon Route 53"
[9]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html?utm_source=chatgpt.com "Choosing between alias and non-alias records"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-editing.html?utm_source=chatgpt.com "Editing records - Amazon Route 53 - AWS Documentation"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html?utm_source=chatgpt.com "How Amazon Route 53 chooses records when health ..."
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-problems.html?utm_source=chatgpt.com "How Amazon Route 53 averts failover problems"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-types.html?utm_source=chatgpt.com "Types of Amazon Route 53 health checks"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html?utm_source=chatgpt.com "Values specific for weighted records - Amazon Route 53"
[15]: https://docs.aws.amazon.com/global-accelerator/latest/dg/introduction-components.html?utm_source=chatgpt.com "AWS Global Accelerator components"
[16]: https://docs.aws.amazon.com/global-accelerator/latest/dg/introduction-how-it-works.html?utm_source=chatgpt.com "How AWS Global Accelerator works"
[17]: https://docs.aws.amazon.com/global-accelerator/latest/dg/about-endpoint-groups.html?utm_source=chatgpt.com "Endpoint groups for standard accelerators in AWS Global ..."
[18]: https://docs.aws.amazon.com/global-accelerator/latest/dg/about-endpoints.html?utm_source=chatgpt.com "Endpoints for standard accelerators in AWS Global ..."
[19]: https://docs.aws.amazon.com/global-accelerator/latest/dg/about-endpoint-groups-traffic-dial.html?utm_source=chatgpt.com "Use traffic dials to adjust traffic flow to Regions"
[20]: https://docs.aws.amazon.com/global-accelerator/latest/dg/what-is-global-accelerator.html?utm_source=chatgpt.com "What is AWS Global Accelerator?"
