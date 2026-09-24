# AWS Masterclass — Lesson 29 Part 2

# Route 53 Routing Policies, Health Checks & DNS Failover

In Part 1, Route 53 was basically:

```text
DNS name
   │
   ▼
Route 53
   │
   ▼
one destination
```

Now we make Route 53 capable of answering questions such as:

```text
Should this user go to Mumbai or Singapore?

Should 10% of users receive the new release?

Should traffic stop going to a failed Region?

Should European users stay in Europe?

Can DNS return several healthy web servers?

Can I shift traffic gradually during migration?
```

Current Route 53 supports these routing policies:

```text
Simple
Weighted
Failover
Latency
Geolocation
Geoproximity
IP-based
Multivalue answer
```

Each solves a **different traffic-management problem**. ([AWS Documentation][1])

---

# 1. First Rule — Route 53 Does Not Forward Traffic

This is critical.

Route 53 does:

```text
DNS Query

"Where is app.example.com?"
```

It does **not** sit in the packet path like:

```text
ALB
NAT Gateway
router
proxy
CloudFront
```

Route 53 returns an answer:

```text
app.example.com
      │
      ▼
ALB-A
```

Then the client connects directly to that destination.

So:

```text
Route 53 routing
=
DNS ANSWER SELECTION
```

not:

```text
packet forwarding
```

---

# 2. Master Routing Policy Decision Tree

Memorize this:

```text
                         Route 53
                            │
                What is the requirement?
                            │
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼

   ONE TARGET          TRAFFIC SPLIT          DR
       │                    │                    │
       ▼                    ▼                    ▼
    SIMPLE              WEIGHTED             FAILOVER


       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼

 BEST AWS            USER LOCATION       RESOURCE LOCATION
 LATENCY                                      + BIAS
       │                    │                    │
       ▼                    ▼                    ▼
    LATENCY            GEOLOCATION        GEOPROXIMITY


       ┌────────────────────┼────────────────────┐
       ▼                    ▼
 SOURCE CIDR          MULTIPLE HEALTHY
       │                DNS ANSWERS
       ▼                    ▼
   IP-BASED            MULTIVALUE
```

---

# 3. Simple Routing

Simple routing answers:

> “For this DNS name, where should traffic go?”

Example:

```text
api.example.com
       │
       ▼
Route 53
       │
       ▼
ALB
```

Typical usage:

```text
one CloudFront distribution
one ALB
one API Gateway endpoint
one website
```

This should be your default mental model when no special routing behavior is required.

---

# 4. Weighted Routing

Suppose we have:

```text
BLUE
old production version
```

and:

```text
GREEN
new production version
```

You don't want:

```text
0% → 100%
```

immediately.

Instead:

```text
                Route 53
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
       BLUE                 GREEN
       90                    10
```

Weighted routing lets Route 53 return records in proportions determined by their configured relative weights. ([AWS Documentation][2])

---

# 5. Weight Is Relative — Not Necessarily Percentage

You might configure:

```text
Blue  = 90
Green = 10
```

approximately representing:

```text
90%
10%
```

But:

```text
9
1
```

produces the same relative ratio.

Route 53 weights are integers from:

```text
0–255
```

and selection depends on:

```text
record weight
──────────────
sum of weights
```

roughly over DNS responses. ([AWS Documentation][3])

---

# 6. Weighted Routing Is NOT Exact HTTP Request Splitting

This matters enormously.

Suppose:

```text
Blue = 90
Green = 10
```

Route 53 does **not** inspect every HTTP request and send:

```text
Request 1  → Blue
Request 2  → Blue
...
Request 10 → Green
```

DNS resolvers cache responses.

One resolver may serve:

```text
thousands of users
```

from one cached DNS answer.

Therefore actual application traffic might temporarily look like:

```text
87% / 13%
93% / 7%
```

rather than exactly:

```text
90% / 10%
```

Weighted routing is best understood as:

```text
probabilistic DNS response distribution
```

not an L7 request splitter.

---

# 7. Great Weighted Routing Use Cases

```text
Canary release
```

```text
Blue/Green rollout
```

```text
Vendor migration
```

```text
Regional traffic migration
```

```text
Capacity testing
```

Example:

```text
Step 1

Blue  = 99
Green = 1


Step 2

Blue  = 90
Green = 10


Step 3

Blue  = 50
Green = 50


Step 4

Blue  = 0
Green = 100
```

---

# 8. Weight Zero

Suppose:

```text
Blue  = 100
Green = 0
```

Normally Route 53 stops choosing Green while a non-zero record is available.

But there is an important health-check exception:

```text
if all non-zero-weight records
become unhealthy
```

Route 53 begins considering healthy zero-weight records. ([AWS Documentation][2])

That means you can sometimes use:

```text
Weight = 0
```

as a standby-like mechanism.

But AWS recommends understanding the caveats before using weighted records as a substitute for explicit failover routing. ([AWS Documentation][4])

---

# 9. Another Weight-Zero Trap

If you configure:

```text
A = 0
B = 0
C = 0
```

Route 53 does **not** stop answering completely.

It routes among them with equal probability. ([AWS Documentation][3])

So:

```text
all weights = 0
```

does not mean:

```text
disable DNS
```

---

# 10. Failover Routing

Now suppose the requirement is not traffic splitting.

It is:

> Use Mumbai normally. If Mumbai dies, send everyone to Singapore.

Architecture:

```text
                     Route 53
                        │
                 Failover Policy
                        │
           ┌────────────┴────────────┐
           ▼                         ▼
       PRIMARY                   SECONDARY
      ap-south-1             ap-southeast-1
         ALB                       ALB
```

Route 53 failover routing uses:

```text
PRIMARY
```

and:

```text
SECONDARY
```

records. ([AWS Documentation][5])

---

# 11. Active-Passive Architecture

Normal:

```text
Users
  │
  ▼
Route 53
  │
  ▼
PRIMARY
Mumbai
```

Secondary:

```text
Singapore
```

receives little or no production traffic.

Failure:

```text
Mumbai
  X
```

Route 53 health logic sees:

```text
PRIMARY = unhealthy
```

and returns:

```text
SECONDARY
```

instead. ([AWS Documentation][4])

This is:

# Active-Passive

---

# 12. Active-Active Architecture

Different requirement:

> I want all healthy resources serving traffic continuously.

Example:

```text
                    Route 53
                       │
                Latency routing
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
      Mumbai       Singapore       Frankfurt
      ACTIVE         ACTIVE          ACTIVE
```

If Singapore becomes unhealthy:

```text
Singapore
   X
```

Route 53 can stop returning it and continue using healthy resources.

AWS defines active-active Route 53 failover as a configuration in which all records remain active unless health checking determines that a resource is unhealthy. Active-passive instead uses the explicit failover policy. ([AWS Documentation][4])

### Memory trick

```text
ACTIVE-ACTIVE
=
weighted / latency / geo / etc.
+
health
```

```text
ACTIVE-PASSIVE
=
failover routing
```

---

# 13. Health Checks Are What Make DNS Failure-Aware

Without health information:

```text
Route 53
    │
    ▼
record exists
    │
    ▼
return it
```

even if:

```text
application
=
dead
```

With health:

```text
Route 53
    │
    ▼
Is resource healthy?
    │
 ┌──┴───┐
YES    NO
 │      │
 ▼      ▼
use    avoid
```

Route 53 supports health checks for:

```text
endpoint health

calculated health

CloudWatch alarm data

ARC routing controls
```

([AWS Documentation][6])

---

# 14. Endpoint Health Check

Route 53 health checkers distributed around the world can send requests to an endpoint such as:

```text
HTTP
HTTPS
TCP
```

at regular intervals. ([AWS Documentation][7])

Example:

```text
Route 53 Health Checkers
          │
          ▼
https://app.example.com/health
          │
          ▼
Application
```

Your `/health` endpoint might verify:

```text
web server running
critical dependency reachable
application ready
```

depending on your design.

---

# 15. Health Check Intervals

Current endpoint health checks support intervals of:

```text
30 seconds
```

or:

```text
10 seconds
```

The 10-second option is the faster health-check setting and incurs additional Route 53 health-check cost. ([AWS Documentation][8])

Important:

```text
30 seconds
```

does not mean your server receives only one check every 30 seconds.

Multiple Route 53 health-check locations independently send checks, so the endpoint can receive checks much more frequently overall. ([AWS Documentation][8])

---

# 16. Failure Threshold

You also configure:

```text
FailureThreshold
```

Current valid range:

```text
1–10
```

Default:

```text
3
```

Route 53 changes health status after the configured number of consecutive successes or failures according to the health-check logic. ([AWS Documentation][9])

Example:

```text
Interval = 30 sec
FailureThreshold = 3
```

Conceptually:

```text
fail
fail
fail
   │
   ▼
health state changes
```

But remember many distributed checkers participate, so don't simply calculate:

```text
30 × 3 = exact failover time
```

and assume that's your application RTO.

---

# 17. DNS Failover Has Multiple Delays

Suppose primary fails at:

```text
12:00:00
```

Actual user cutover depends on:

```text
Failure detection
      │
      ▼
Route 53 health state change
      │
      ▼
DNS answer change
      │
      ▼
recursive resolver TTL
      │
      ▼
client DNS cache
      │
      ▼
new connection
```

Therefore:

```text
DNS FAILOVER TIME
≠
health-check interval alone
```

This is one of the most important DR lessons in Route 53.

---

# 18. TTL Is Part of RTO

Suppose failover DNS records have:

```text
TTL = 3600 seconds
```

Resolver cached:

```text
Mumbai endpoint
```

five seconds before failure.

Even when Route 53 starts returning Singapore, that resolver can keep returning its cached Mumbai answer until the cached TTL expires.

So for failover-sensitive non-alias DNS records:

```text
smaller TTL
```

can reduce potential resolver-cache delay.

But smaller TTL also means:

```text
more DNS queries
```

and should be selected deliberately.

---

# 19. Route 53 Health Checks Don't Happen Per DNS Request

Another critical misconception:

```text
DNS query arrives
      │
      ▼
Route 53 sends HTTP health check
      │
      ▼
waits
      │
      ▼
answers DNS
```

No.

Route 53 continuously checks endpoints independently and maintains health state. When the DNS query arrives, Route 53 uses the current known state. ([AWS Documentation][10])

---

# 20. `Evaluate Target Health`

When routing an **Alias** to certain AWS resources, you often don't need a separate Route 53 HTTP health check.

Instead:

```text
Alias
  │
  ▼
EvaluateTargetHealth = true
```

Route 53 evaluates the health information of the target AWS resource or referenced records. ([AWS Documentation][11])

Example:

```text
Route 53 Alias
      │
      ▼
Application Load Balancer
      │
      ▼
Target Group
```

---

# 21. ALB `Evaluate Target Health`

For an ALB or NLB alias with:

```text
Evaluate Target Health = true
```

Route 53 considers target-group health.

For each target group containing targets:

```text
at least one target
must be healthy
```

If a target group contains only unhealthy targets:

```text
load balancer considered unhealthy
```

An empty target group is also considered unhealthy for this evaluation. ([AWS Documentation][12])

This is enormously useful.

---

# 22. Don't Create Route 53 Health Checks for Every EC2 Behind an ALB

If architecture is:

```text
Route 53
   │
   ▼
ALB
   │
   ▼
Target Group
   │
 ┌─┼─┐
 ▼ ▼ ▼
EC2 EC2 EC2
```

ALB already has target-group health checks.

Use:

```text
Alias → ALB
Evaluate Target Health = true
```

rather than creating Route 53 health checks against every registered EC2 target.

AWS explicitly recommends this approach. ([AWS Documentation][12])

---

# 23. CloudFront Important Exception

Suppose:

```text
Alias
  │
  ▼
CloudFront
```

You **cannot** set:

```text
EvaluateTargetHealth = true
```

for a CloudFront distribution alias target. ([AWS Documentation][12])

This is a common Terraform/Route 53 misunderstanding.

For CloudFront DR, you need a different health/failover strategy rather than expecting CloudFront alias target health evaluation to work like an ALB.

---

# 24. Calculated Health Checks

Suppose you have:

```text
Web Server A
Web Server B
Web Server C
```

Create child health checks:

```text
HC-A
HC-B
HC-C
```

Then calculated health:

```text
                 Calculated HC
                      │
                Healthy when
                2 of 3 healthy
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
       HC-A          HC-B          HC-C
```

Route 53 calculated health checks can monitor the states of other Route 53 health checks and determine health based on a configured number of healthy children. ([AWS Documentation][6])

Useful for:

```text
service quorum

multi-component application

complex availability rule
```

---

# 25. CloudWatch Alarm Health Check

You can also create:

```text
Route 53 Health Check
        │
        ▼
CloudWatch metric/alarm data
```

Example:

```text
DynamoDB throttles high
```

or:

```text
application custom metric
```

and use that health state as part of DNS failover logic. ([AWS Documentation][6])

This means health doesn't have to mean only:

```text
TCP port responds
```

It can represent a broader application/business condition.

---

# 26. Example Business Health Check

Suppose your application returns HTTP 200 but:

```text
payment dependency broken
```

From a TCP perspective:

```text
server healthy
```

From the business perspective:

```text
checkout unusable
```

You might expose:

```text
/health/checkout
```

or produce a CloudWatch metric representing:

```text
checkout availability
```

Then failover based on meaningful service health.

This is an SRE principle:

```text
check what the USER needs
```

not merely:

```text
is the process alive?
```

---

# 27. Health Check Failure Threshold Too Sensitive

Imagine:

```text
FailureThreshold = 1
```

and one transient network problem occurs.

You may trigger:

```text
DNS failover
```

too aggressively.

That can create:

```text
traffic flapping
```

between Regions.

Higher thresholds reduce sensitivity but increase detection time.

Tradeoff:

```text
FAST FAILURE DETECTION
        ▲
        │
        │
        └──────────────▶ STABILITY
```

Choose according to application behavior.

---

# 28. Fail-Open Behavior — Extremely Important

Here's a surprising Route 53 rule.

Suppose a group contains:

```text
Endpoint A = unhealthy
Endpoint B = unhealthy
Endpoint C = unhealthy
```

If Route 53 determines **none of the records are healthy**, it still needs to return something.

In many health-aware routing configurations Route 53 effectively treats all records as healthy and selects according to the routing policy. ([AWS Documentation][10])

This is often described conceptually as:

# DNS fail-open behavior

Do not assume:

```text
all unhealthy
=
Route 53 returns nothing
```

---

# 29. Failover Policy Special Case

Suppose:

```text
PRIMARY   = unhealthy
SECONDARY = unhealthy
```

and both have health checks.

Route 53 returns:

```text
PRIMARY
```

in that situation. ([AWS Documentation][10])

Why?

Because DNS returning something can be more useful than returning nothing, even though Route 53 has no healthy choice.

This is a famous certification/interview trap.

---

# 30. Secondary Health Check Is Optional

For failover routing:

```text
PRIMARY
```

should normally have health logic.

The secondary health check is optional.

If the primary is unhealthy and the secondary has **no** health check, Route 53 considers the secondary eligible and returns it—even if the secondary itself happens to be broken. ([AWS Documentation][10])

Production lesson:

```text
standby
must actually be tested.
```

DNS configuration alone does not prove DR readiness.

---

# 31. Latency Routing

Now suppose you don't want primary/secondary.

You want:

> Send users to the AWS Region expected to give them the lowest network latency.

Architecture:

```text
                   Route 53
                      │
              latency policy
                      │
       ┌──────────────┼──────────────┐
       ▼              ▼              ▼
   ap-south-1   ap-southeast-1   eu-central-1
      Mumbai        Singapore       Frankfurt
```

Route 53 latency routing chooses among configured AWS Regions based on its latency data for the source of the DNS query. ([AWS Documentation][13])

---

# 32. Latency Routing Is NOT Geography Routing

This distinction is important.

User in:

```text
London
```

might geographically appear closer to:

```text
Frankfurt
```

but Route 53 latency data could determine another AWS Region provides better network latency under its routing model.

Latency routing asks:

```text
Which AWS Region is expected
to provide better latency?
```

Geolocation asks:

```text
Where is the user?
```

Different problem.

---

# 33. Latency Routing Example

```text
India user
     │
     ▼
Route 53
     │
     ▼
Mumbai ALB


Australia user
     │
     ▼
Route 53
     │
     ▼
Singapore ALB


European user
     │
     ▼
Route 53
     │
     ▼
Frankfurt ALB
```

Provided those Regions are configured as latency records and healthy.

---

# 34. Latency + Health = Active-Active

Example:

```text
Mumbai     healthy
Singapore  healthy
Frankfurt  healthy
```

Route 53 chooses according to latency.

Singapore fails:

```text
Singapore
   X
```

With appropriate health configuration:

```text
Route 53 stops considering it
```

and users that would otherwise have been sent to Singapore receive another healthy latency-based destination.

This is classic:

```text
ACTIVE-ACTIVE
+
FAILURE AWARENESS
```

([AWS Documentation][4])

---

# 35. Geolocation Routing

Geolocation routing says:

> Route users based on their geographic origin.

You can configure:

```text
continent

country

US state
```

and Route 53 selects the most specific applicable geographic rule. ([AWS Documentation][14])

Example:

```text
India
   │
   ▼
Mumbai


Germany
   │
   ▼
Frankfurt


United States
   │
   ▼
Virginia
```

---

# 36. Geolocation Use Cases

### Content localization

```text
India
→ Indian version
```

### Licensing

```text
Germany
→ EU-approved content
```

### Regulatory requirements

```text
EU users
→ EU endpoint
```

### Language

```text
Japan
→ Japanese frontend
```

Geolocation is about:

```text
USER ORIGIN
```

not inherently best latency. ([AWS Documentation][14])

---

# 37. Always Think About Geolocation Default Record

Not every DNS source IP can be mapped perfectly to a geographic location.

Route 53 allows:

```text
Default
```

geolocation record.

If no matching or identifiable location exists:

```text
Default
```

handles the query.

Without a default, Route 53 can return no answer for unmatched locations. ([AWS Documentation][14])

### Never forget

```text
GEOLOCATION
+
DEFAULT
```

is usually the safe architecture.

---

# 38. Geolocation Specificity

Suppose you configure:

```text
North America
→ Endpoint A
```

and:

```text
Canada
→ Endpoint B
```

Canadian users get:

```text
Endpoint B
```

because the more specific geographic rule wins. ([AWS Documentation][14])

Think:

```text
country
beats
continent
```

when both match.

---

# 39. Geoproximity Routing

Geoproximity sounds similar but solves a different problem.

It considers:

```text
user location
+
resource location
```

and normally sends traffic toward the closest resource.

You can then manipulate the geographic boundary using:

```text
BIAS
```

([AWS Documentation][15])

---

# 40. Geoproximity Example

Resources:

```text
Mumbai
Singapore
Frankfurt
```

Route 53 determines geographic proximity.

Conceptually:

```text
users near India
   │
   ▼
Mumbai


users in Southeast Asia
   │
   ▼
Singapore


users near Europe
   │
   ▼
Frankfurt
```

But then you can influence the boundaries.

---

# 41. Positive Bias

Suppose Mumbai has:

```text
bias = +25
```

Positive bias expands the geographic area from which Route 53 sends traffic to that resource. ([AWS Documentation][15])

Conceptually:

```text
Before

Mumbai territory:
██████


After +25

Mumbai territory:
████████████
```

Useful when:

```text
Mumbai has more capacity
```

and you want it to absorb more traffic.

---

# 42. Negative Bias

Suppose:

```text
Mumbai bias = -25
```

Route 53 shrinks its geographic catchment area, effectively shifting more traffic toward neighboring resources. ([AWS Documentation][15])

Useful when:

```text
Mumbai capacity constrained
```

or during migration.

Current bias range is:

```text
-99 to +99
```

excluding the implicit neutral `0` behavior. ([AWS Documentation][15])

---

# 43. Geolocation vs Geoproximity

Burn this into memory:

```text
GEOLOCATION
=
WHERE IS THE USER?
```

```text
GEOPROXIMITY
=
HOW CLOSE IS USER
TO EACH RESOURCE?
+
OPTIONAL BIAS
```

Example:

```text
All Indian users must go Mumbai
```

→ Geolocation.

```text
Send users to nearest resource,
but make Mumbai handle more territory
```

→ Geoproximity.

---

# 44. IP-Based Routing

Sometimes geography is too vague.

Suppose an enterprise knows:

```text
203.0.113.0/24
=
Corporate ISP A
```

and:

```text
198.51.100.0/24
=
Partner B
```

You can use Route 53 IP-based routing to select DNS responses according to configured source CIDR ranges. Route 53 lists IP-based routing as a policy for routing based on known originating IP ranges. ([AWS Documentation][1])

Use case:

```text
corporate networks
ISP-specific routing
partner traffic
known client CIDRs
```

---

# 45. Multivalue Answer Routing

Suppose you have four independent web servers:

```text
Web1
Web2
Web3
Web4
```

You want DNS to return several healthy addresses.

Architecture:

```text
                 Route 53
                    │
            Multivalue Answer
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
       Web1       Web2        Web3
```

Route 53 can return:

```text
up to 8 healthy records
```

in one DNS response. ([AWS Documentation][16])

---

# 46. Why Multiple DNS Answers Help

Suppose DNS response contains:

```text
203.0.113.10
203.0.113.11
203.0.113.12
```

If the first address fails after the resolver cached the answer, client software may try another address from the same response. ([AWS Documentation][16])

This can provide basic fault tolerance.

---

# 47. Multivalue Is NOT a Replacement for an ALB

Very important.

```text
Route 53 Multivalue
```

does not provide:

```text
Layer 7 routing
HTTP health checks per request
TLS termination
sticky sessions
path-based routing
host-based routing
centralized connection handling
```

like an Application Load Balancer.

Think:

```text
Multivalue
=
DNS-level multiple answers
```

not:

```text
managed load balancer
```

---

# 48. Multivalue All-Unhealthy Behavior

Another surprising behavior:

If all multivalue records are unhealthy, Route 53 can still return:

```text
up to 8 unhealthy records
```

rather than returning no records. ([AWS Documentation][16])

Again:

```text
DNS prefers giving the client
something to try
```

over automatically giving no answer.

---

# 49. Weighted + Health Check Architecture

Now combine features.

```text
                   app.example.com
                         │
                     Route 53
                         │
                  weighted records
                  + health checks
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
          Blue ALB               Green ALB
           90                     10
        healthy                 healthy
```

If Green fails:

```text
Green
  X
```

Route 53 stops choosing that unhealthy record and sends eligible DNS responses to healthy Blue instead. ([AWS Documentation][10])

This is excellent for safer canary deployments.

---

# 50. Canary Deployment Design

Start:

```text
Blue  100
Green 0
```

Deploy new release to Green.

Health validation:

```text
Green health
=
good
```

Shift:

```text
Blue  99
Green 1
```

Observe:

```text
5xx
latency
business metrics
CPU
database pressure
```

Then:

```text
90/10
75/25
50/50
0/100
```

If Green becomes unhealthy:

```text
health-aware weighted routing
```

can exclude it.

---

# 51. But DNS Canary Is Not the Same as ALB Canary

DNS weighted routing acts at:

```text
resolver/client DNS layer
```

ALB listener weighted target groups operate much closer to:

```text
individual HTTP connections/requests
```

depending on application architecture.

If you require extremely precise:

```text
1% of requests
```

DNS weighting may be less deterministic due to caching.

Use the correct layer for the rollout requirement.

---

# 52. Multi-Region Active-Active Architecture

Let's design:

```text
app.example.com
```

in:

```text
ap-south-1
```

and:

```text
ap-southeast-1
```

Architecture:

```text
                         Users
                           │
                           ▼
                        Route 53
                    Latency Routing
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
        ap-south-1                 ap-southeast-1
           Mumbai                    Singapore
             │                           │
            ALB                         ALB
             │                           │
         ASG / ECS                   ASG / ECS
             │                           │
             └──────── shared/global data ───────
```

Both Regions are:

```text
ACTIVE
```

Health-aware latency routing removes unhealthy destinations. ([AWS Documentation][4])

---

# 53. Data Layer Still Matters

DNS active-active is easy to draw:

```text
Region A
Region B
```

But what about:

```text
DATABASE?
```

If using Aurora Global Database:

```text
Region A
WRITE

Region B
READ
```

normal architecture isn't automatically symmetric.

If using DynamoDB Global Tables:

```text
Region A
READ + WRITE

Region B
READ + WRITE
```

is more naturally multi-active.

So:

```text
Route 53 active-active frontend
```

does **not automatically mean**:

```text
entire application stack
is active-active.
```

The data layer must support the design.

---

# 54. Multi-Region Active-Passive Architecture

Requirement:

```text
Mumbai primary
Singapore DR
```

Architecture:

```text
                         Route 53
                        Failover
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
          PRIMARY                    SECONDARY
        ap-south-1               ap-southeast-1
           │                           │
          ALB                         ALB
           │                           │
         App                        Standby App
           │                           │
         DB  ───────── DR ───────────► DB
```

Primary normally serves:

```text
100%
```

Traffic shifts only when health logic says primary is unusable. ([AWS Documentation][5])

---

# 55. DR Capacity Question

Suppose primary handles:

```text
100,000 req/sec
```

Secondary can handle:

```text
10,000 req/sec
```

Route 53 failover works perfectly.

Result:

```text
Singapore receives 100,000 req/sec
              │
              ▼
          overloaded
```

DNS failover success does not mean:

```text
DR capacity success.
```

Your secondary must meet the DR capacity model:

```text
hot
warm
pilot light
backup/restore
```

according to RTO/RPO requirements.

---

# 56. Terraform — Weighted Routing

Example with two ALBs:

```hcl
resource "aws_route53_record" "blue" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
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
```

Green:

```hcl
resource "aws_route53_record" "green" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
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

Mental model:

```text
same:
name
type

different:
set_identifier
weight
target
```

---

# 57. Terraform — Failover Records

Primary:

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
    name                   = aws_lb.mumbai.dns_name
    zone_id                = aws_lb.mumbai.zone_id
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
    name                   = aws_lb.singapore.dns_name
    zone_id                = aws_lb.singapore.zone_id
    evaluate_target_health = true
  }
}
```

Now:

```text
Mumbai healthy
→ PRIMARY returned

Mumbai unhealthy
→ SECONDARY returned
```

assuming the target-health logic marks the resources appropriately. ([AWS Documentation][10])

---

# 58. Terraform — Latency Records

Mumbai:

```hcl
resource "aws_route53_record" "mumbai" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "global.example.com"
  type    = "A"

  set_identifier = "mumbai"

  latency_routing_policy {
    region = "ap-south-1"
  }

  alias {
    name                   = aws_lb.mumbai.dns_name
    zone_id                = aws_lb.mumbai.zone_id
    evaluate_target_health = true
  }
}
```

Singapore:

```hcl
resource "aws_route53_record" "singapore" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "global.example.com"
  type    = "A"

  set_identifier = "singapore"

  latency_routing_policy {
    region = "ap-southeast-1"
  }

  alias {
    name                   = aws_lb.singapore.dns_name
    zone_id                = aws_lb.singapore.zone_id
    evaluate_target_health = true
  }
}
```

Route 53 chooses based on its latency routing data for the query source and configured AWS Regions. ([AWS Documentation][13])

---

# 59. Terraform — Direct Endpoint Health Check

For a public endpoint:

```hcl
resource "aws_route53_health_check" "api" {
  fqdn = "health.example.com"

  port = 443
  type = "HTTPS"

  resource_path = "/health"

  request_interval  = 30
  failure_threshold = 3
}
```

Then a non-alias Route 53 record can reference:

```hcl
health_check_id = aws_route53_health_check.api.id
```

Current Route 53 endpoint checks support 10- or 30-second intervals and failure thresholds from 1 to 10. ([AWS Documentation][8])

---

# 60. Private Endpoint Health Check Caveat

Route 53 public health checkers are outside your VPC.

Therefore directly checking:

```text
10.0.1.25
```

inside a private subnet isn't the same as checking a public internet endpoint.

For private hosted zone failover, AWS recommends patterns such as CloudWatch-alarm-based health checks for private resources when direct public health checking isn't appropriate. ([AWS Documentation][17])

We'll go deeper into private/hybrid DNS in the next part.

---

# 61. Route 53 Monitoring

Route 53 sends health-check metrics to CloudWatch, typically at one-minute metric intervals, so you can monitor health state and create alerting around it. ([AWS Documentation][18])

Possible pipeline:

```text
Route 53 health
      │
      ▼
CloudWatch
      │
      ▼
Alarm
      │
      ▼
SNS
      │
      ▼
Pager / Email / Automation
```

Do not operate DNS failover silently.

You need to know that:

```text
failover happened.
```

---

# 62. Failover Game Day

Before trusting production DR:

```text
1. Verify primary healthy.

2. Query DNS repeatedly.

3. Confirm primary answer.

4. Induce controlled primary failure.

5. Observe health state.

6. Observe DNS answer change.

7. Test using multiple resolvers.

8. Observe application errors.

9. Measure actual recovery time.

10. Restore primary.

11. Observe recovery/failback behavior.

12. Verify no data corruption.
```

You want actual numbers:

```text
health detection:
X seconds

DNS change:
Y seconds

client recovery:
Z seconds

application RTO:
total
```

not:

> “Route 53 should fail over quickly.”

---

# 63. `dig` Weighted Testing

You can query repeatedly:

```bash
for i in {1..30}; do
  dig +short app.example.com
done
```

But if testing from one resolver:

```text
resolver cache
```

can distort results.

For more realistic weighted-routing validation:

```text
query multiple recursive resolvers

or

query authoritative servers directly
```

while understanding that authoritative testing bypasses normal resolver caching behavior.

---

# 64. `dig` Failover Testing

Check:

```bash
dig app.example.com
```

Then inspect authoritative answer:

```bash
dig @<route53-authoritative-ns> app.example.com
```

Compare:

```text
recursive result
vs
authoritative result
```

If authoritative shows Singapore but recursive still shows Mumbai:

```text
Route 53 failover
=
working

resolver cache
=
still old
```

That distinction can save hours during an incident.

---

# 65. Certification Trap — Weighted vs Failover

Requirement:

> Send 90% to A and 10% to B.

Answer:

```text
WEIGHTED
```

Requirement:

> Use A unless it fails, then B.

Answer:

```text
FAILOVER
```

Do not confuse:

```text
traffic distribution
```

with:

```text
standby recovery.
```

---

# 66. Certification Trap — Latency vs Geolocation

Requirement:

> Route users to the AWS Region expected to give them best network latency.

```text
LATENCY
```

Requirement:

> All German users must use Frankfurt.

```text
GEOLOCATION
```

Requirement:

> Send users to nearby resources but make Mumbai absorb a larger geographic area.

```text
GEOPROXIMITY
```

([AWS Documentation][13])

---

# 67. Certification Trap — Multivalue vs ALB

Requirement:

> DNS should return several healthy IP addresses.

```text
MULTIVALUE
```

Requirement:

> HTTP path-based routing, TLS termination and target-group health management.

```text
APPLICATION LOAD BALANCER
```

Multivalue can return up to eight healthy DNS records but isn't a replacement for an ELB load balancer. ([AWS Documentation][16])

---

# 68. Certification Trap — Alias Target Health

Architecture:

```text
Route 53
  │
 Alias
  │
 ALB
```

Need Route 53 to avoid unhealthy ALB environment:

```text
Evaluate Target Health = true
```

Route 53 can derive health from ALB/NLB target-group state. ([AWS Documentation][12])

But:

```text
Route 53 Alias
  │
  ▼
CloudFront
```

does not support:

```text
EvaluateTargetHealth = true
```

([AWS Documentation][19])

---

# 69. Certification Trap — All Endpoints Unhealthy

Question:

> What happens if all health-checked records in a group are unhealthy?

Don't automatically answer:

```text
Route 53 returns NXDOMAIN.
```

Route 53 commonly fails open by treating records as eligible and returning one according to routing rules. ([AWS Documentation][10])

For explicit primary/secondary failover where both are unhealthy:

```text
primary is returned.
```

([AWS Documentation][10])

---

# 70. Production Architecture — Global API

Let's combine everything:

```text
                        api.example.com
                              │
                              ▼
                           Route 53
                       Latency Routing
                              │
                 Health-aware Alias
                              │
          ┌───────────────────┼───────────────────┐
          ▼                                       ▼
      ap-south-1                           ap-southeast-1
        Mumbai                                 Singapore
          │                                       │
         ALB                                     ALB
          │                                       │
       Target                                  Target
       Groups                                  Groups
          │                                       │
        Apps                                    Apps
          │                                       │
          └──────────── data architecture ─────────┘
```

Route 53 selects a healthy Region using latency policy, while each ALB internally handles its healthy application targets. ([AWS Documentation][13])

This is layered health:

```text
Route 53
=
regional endpoint selection


ALB
=
target selection inside Region
```

---

# 71. Never-Forget Routing Policy Table

| Requirement                     | Route 53 policy  |
| ------------------------------- | ---------------- |
| One normal destination          | **Simple**       |
| 90/10 split                     | **Weighted**     |
| Primary → standby               | **Failover**     |
| Best AWS Region latency         | **Latency**      |
| Route based on user country     | **Geolocation**  |
| Nearest resource + traffic bias | **Geoproximity** |
| Route known source CIDRs        | **IP-based**     |
| Return several healthy records  | **Multivalue**   |

These are the current Route 53 routing-policy categories. ([AWS Documentation][1])

---

# 72. The Health Architecture Mental Model

```text
                         Route 53
                            │
                    routing decision
                            │
           ┌────────────────┼─────────────────┐
           │                │                 │
           ▼                ▼                 ▼
      Endpoint HC     Evaluate Target    CloudWatch HC
                           Health
           │                │                 │
           ▼                ▼                 ▼
     HTTP/HTTPS/TCP         ALB             metric
                                             │
                                             ▼
                                          health
```

And:

```text
Calculated HC
     │
     ├── HC-A
     ├── HC-B
     └── HC-C
```

Route 53 supports all these health-check categories. ([AWS Documentation][6])

---

# 73. The 20 Rules to Burn Into Memory

```text
1. Route 53 routing chooses DNS answers;
   it does not forward packets.

2. Simple routing = ordinary DNS destination.

3. Weighted routing = proportional DNS answers.

4. Weights are relative, not literal request percentages.

5. DNS caching means weighted traffic won't be exact.

6. Weight 0 doesn't always mean "never use."

7. Failover routing = Primary + Secondary.

8. Active-passive normally uses Failover policy.

9. Active-active can use latency, weighted, geo, etc.
   with health evaluation.

10. Health checks are performed continuously,
    not when each DNS query arrives.

11. Endpoint health-check intervals are 10 or 30 seconds.

12. Failure threshold defaults to 3
    and supports 1–10.

13. TTL is part of actual DNS failover RTO.

14. Alias → ALB can use Evaluate Target Health.

15. Don't duplicate ALB target health with
    Route 53 checks against every EC2 target.

16. CloudFront aliases can't enable Evaluate Target Health.

17. Latency routing ≠ geolocation routing.

18. Geolocation needs a sensible default record.

19. Multivalue can return up to eight healthy records.

20. If everything is unhealthy,
    Route 53 can fail open instead of returning nothing.
```

The biggest rule:

```text
DNS FAILOVER
IS NOT JUST:

"HEALTH CHECK FAILED"
```

It is:

```text
FAILURE
   ↓
DETECTION
   ↓
ROUTE 53 HEALTH STATE
   ↓
NEW DNS ANSWER
   ↓
RESOLVER TTL
   ↓
CLIENT CACHE
   ↓
NEW CONNECTION
   ↓
APPLICATION RECOVERY
```

That complete chain determines your real-world RTO.

---

# ✅ Lesson 29 Part 2 Complete

You now understand:

```text
✓ Simple routing
✓ Weighted routing
✓ weights 0–255
✓ 90/10 canary routing
✓ DNS weighting limitations
✓ zero-weight behavior
✓ Failover routing
✓ Primary / Secondary
✓ active-active
✓ active-passive
✓ endpoint health checks
✓ calculated health checks
✓ CloudWatch health checks
✓ health-check intervals
✓ failure thresholds
✓ Evaluate Target Health
✓ ALB/NLB target health
✓ CloudFront health exception
✓ fail-open behavior
✓ secondary-health caveat
✓ TTL impact on failover
✓ Latency routing
✓ Geolocation
✓ Geolocation default
✓ Geoproximity
✓ bias
✓ IP-based routing
✓ Multivalue answers
✓ up to eight records
✓ weighted + health canaries
✓ Multi-Region active-active
✓ Multi-Region active-passive
✓ Terraform weighted records
✓ Terraform failover records
✓ Terraform latency records
✓ Terraform health checks
✓ CloudWatch monitoring
✓ failover game days
✓ SAA-C03 routing scenarios
```

# Next — Lesson 29 Part 3

# **Private DNS, Route 53 VPC Resolver & Hybrid DNS**

Next we'll enter the networking-heavy DNS layer:

```text
                      AWS VPC
                         │
                         ▼
                Route 53 VPC Resolver
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
      Private Hosted   Public DNS   VPC names
          Zone


                    HYBRID NETWORK

 On-Premises                           AWS
     │                                  │
     ▼                                  ▼
Corporate DNS                    Route 53 Resolver
     │                                  │
     └──── Direct Connect / VPN ─────────┘
                       │
              ┌────────┴────────┐
              ▼                 ▼
        Inbound Endpoint   Outbound Endpoint
              │                 │
              ▼                 ▼
        On-prem → AWS       AWS → On-prem
```

We'll cover:

**private hosted zones, AmazonProvidedDNS, VPC DNS attributes, split-horizon DNS, Resolver inbound endpoints, Resolver outbound endpoints, forwarding rules, conditional forwarding, Resolver rule sharing with AWS RAM, Transit Gateway considerations, Direct Connect/VPN hybrid DNS, DNS Firewall, query logging, private ALB/RDS/service discovery patterns, Terraform, and full hybrid DNS troubleshooting.**

That is where Route 53 becomes deeply connected to **VPC architecture, enterprise networking, hybrid cloud, and migrations**.

[1]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html?utm_source=chatgpt.com "Choosing a routing policy"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-weighted.html?utm_source=chatgpt.com "Weighted routing"
[3]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html?utm_source=chatgpt.com "Values specific for weighted records - Amazon Route 53"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-types.html "Active-active and active-passive failover - Amazon Route 53"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-failover.html?utm_source=chatgpt.com "Failover routing"
[6]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-types.html?utm_source=chatgpt.com "Types of Amazon Route 53 health checks"
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-determining-health-of-endpoints.html?utm_source=chatgpt.com "How Amazon Route 53 determines whether a health check ..."
[8]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-creating-values.html?utm_source=chatgpt.com "Values that you specify when you create or update health ..."
[9]: https://docs.aws.amazon.com/Route53/latest/APIReference/API_HealthCheckConfig.html?utm_source=chatgpt.com "HealthCheckConfig - Amazon Route 53"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html "How Amazon Route 53 chooses records when health checking is configured - Amazon Route 53"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-how-route-53-chooses-records.html?utm_source=chatgpt.com "How Amazon Route 53 chooses records when health ..."
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-failover-alias.html?utm_source=chatgpt.com "Values specific for failover alias records - Amazon Route 53"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-latency.html?utm_source=chatgpt.com "Latency-based routing"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geo.html "Geolocation routing - Amazon Route 53"
[15]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geoproximity.html "Geoproximity routing - Amazon Route 53"
[16]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-multivalue.html?utm_source=chatgpt.com "Multivalue answer routing - Amazon Route 53"
[17]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-private-hosted-zones.html?utm_source=chatgpt.com "Configuring failover in a private hosted zone"
[18]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/monitoring-cloudwatch.html?utm_source=chatgpt.com "Monitoring your resources with Amazon Route 53 health ..."
[19]: https://docs.aws.amazon.com/Route53/latest/APIReference/API_AliasTarget.html?utm_source=chatgpt.com "AliasTarget - Amazon Route 53"
