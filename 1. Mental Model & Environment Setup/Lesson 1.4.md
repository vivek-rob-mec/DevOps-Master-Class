Perfect. Let’s start.

# Lesson 1.4 — Uptime, SLA, SLO, SLI, and Error Budget

This is where you stop thinking only like a developer and start thinking like a **DevOps/SRE engineer**.

Your curriculum already mentions uptime and asks what 99.9% SLA means in real minutes, so this lesson is part of the foundation before observability and production operations. 

---

# 1. What is Uptime?

**Uptime** means how long a system is available and working.

Example:

```text
If your app is working for users, it is up.
If users cannot open it, login, call APIs, or complete important actions, it may be down.
```

But real uptime is not just:

```text
Server is running
```

A server can be running, but the application can still be broken.

Example:

```text
EC2 instance is running
Nginx is running
Node.js process is running
But database connection is failing
Users cannot save todos
```

So from a production view:

```text
Uptime = users can successfully use the service
```

---

# 2. What does 99.9% uptime mean?

Availability is usually written like this:

```text
99%
99.9%
99.95%
99.99%
99.999%
```

These numbers look small, but the difference is huge.

| Availability | Allowed downtime per month | Meaning                 |
| ------------ | -------------------------: | ----------------------- |
| 99%          |        ~7 hours 18 minutes | Basic availability      |
| 99.9%        |                ~43 minutes | Common target           |
| 99.95%       |                ~21 minutes | Stronger target         |
| 99.99%       |      ~4 minutes 23 seconds | High availability       |
| 99.999%      |                ~26 seconds | Very hard and expensive |

So when someone says:

```text
We need 99.99% uptime
```

They are saying:

```text
This system can only be down for around 4.3 minutes per month.
```

That affects architecture.

You cannot achieve that with one server, no monitoring, no rollback, and manual deployment.

---

# 3. Why “More 9s” Cost More Money

Higher availability requires:

```text
Multiple servers
Load balancer
Multiple availability zones
Database replication
Automated failover
Monitoring
Alerting
Backups
Disaster recovery
Zero-downtime deployment
On-call process
```

So this is wrong thinking:

```text
Let’s make everything 99.999%.
```

Better thinking:

```text
How reliable does this service actually need to be?
How much downtime can the business tolerate?
How much are we willing to pay?
```

Example:

| System                     | Availability target  |
| -------------------------- | -------------------- |
| Personal blog              | 99% may be enough    |
| Internal admin dashboard   | 99% or 99.5%         |
| Todo app portfolio project | 99.9% target is good |
| Payment system             | 99.99% or higher     |
| Hospital/emergency system  | Extremely high       |

---

# 4. What is SLA?

**SLA = Service Level Agreement**

This is a formal promise to customers.

Example:

```text
We guarantee 99.9% monthly uptime.
If we fail, customer gets service credit or compensation.
```

SLA is usually legal/business-facing.

Important:

```text
SLA is what you promise externally.
```

Example:

```text
AWS, Cloudflare, hosting companies, SaaS companies all publish SLAs.
```

If SLA is broken, there may be business consequences.

---

# 5. What is SLO?

**SLO = Service Level Objective**

This is an internal reliability target.

Example:

```text
99.9% of API requests should succeed over 30 days.
95% of API requests should complete under 500ms.
```

SLO is usually engineering-facing.

Important:

```text
SLO is what your team aims to maintain.
```

A company should usually make SLO stricter than SLA.

Example:

```text
External SLA: 99.9%
Internal SLO: 99.95%
```

Why?

Because if your internal target is higher, you have buffer before breaking the customer promise.

---

# 6. What is SLI?

**SLI = Service Level Indicator**

This is the actual measurement.

Example:

```text
Request success rate
Latency
Error rate
Availability
Throughput
Saturation
```

Simple difference:

```text
SLI = measurement
SLO = target
SLA = promise
```

Example:

```text
SLI: 99.92% requests succeeded this month
SLO: 99.9% requests should succeed
SLA: 99.5% uptime promised to customers
```

In this example:

```text
SLI is above SLO.
System is healthy.
```

---

# 7. SLA vs SLO vs SLI

Remember this table:

| Term | Meaning                   | Used by             |
| ---- | ------------------------- | ------------------- |
| SLI  | What we measure           | Engineering/SRE     |
| SLO  | What target we want       | Engineering/Product |
| SLA  | What we promise customers | Business/Legal      |

Example:

```text
SLI:
Current API success rate is 99.94%.

SLO:
API success rate should be at least 99.9% over 30 days.

SLA:
Customer contract promises 99.5% monthly availability.
```

---

# 8. What is Error Budget?

An **error budget** is the amount of unreliability you are allowed.

If your SLO is 99.9%, then your error budget is:

```text
0.1% failure allowed
```

For a 30-day month:

```text
99.9% uptime allows around 43 minutes downtime per month.
```

That 43 minutes is your monthly error budget.

If you spend it carefully, you can move fast.

If you burn it too quickly, you must slow down and focus on reliability.

---

# 9. Error Budget Example

Suppose your API SLO is:

```text
99.9% of requests should return successful response over 30 days.
```

That means:

```text
Allowed failure = 0.1%
```

If your API receives:

```text
1,000,000 requests per month
```

Then allowed failed requests:

```text
1,000,000 × 0.1% = 1,000 failed requests
```

So:

```text
Error budget = 1,000 failed requests/month
```

If your app already had 900 failed requests in the first week, your team is burning the budget too fast.

Correct decision:

```text
Pause risky deployments.
Fix reliability.
Improve tests.
Improve monitoring.
```

---

# 10. Why Error Budget is Powerful

Without error budget, teams fight like this:

```text
Product team: Ship features faster.
Ops team: Stop breaking production.
```

With error budget:

```text
If budget is healthy → ship faster.
If budget is almost gone → focus on reliability.
```

It turns emotional arguments into data-based decisions.

---

# 11. Real-World Example for Your Todo App

Your Todo app can have these SLIs:

```text
API availability
API latency
Error rate
Database connection success
Frontend availability
```

Example SLOs:

```text
99.9% of API requests should return non-5xx response over 30 days.

95% of /api/get-todo requests should complete under 500ms.

99% of frontend page loads should complete successfully.
```

Example SLA:

```text
No public SLA needed for portfolio project.
```

But internally, you can define SLOs to show real SRE thinking.

That looks very strong in a portfolio.

---

# 12. Good vs Bad SLO

Bad SLO:

```text
The app should be fast.
```

Why bad?

```text
Fast is not measurable.
```

Good SLO:

```text
95% of API requests should complete under 500ms over a rolling 30-day window.
```

Bad SLO:

```text
The app should never go down.
```

Why bad?

```text
Impossible and unrealistic.
```

Good SLO:

```text
99.9% of API requests should succeed over 30 days.
```

---

# 13. The Four Golden Signals

Google SRE popularized four important signals:

```text
Latency
Traffic
Errors
Saturation
```

## Latency

How long requests take.

Example:

```text
p95 latency = 700ms
```

Meaning:

```text
95% of requests are faster than 700ms.
```

## Traffic

How much demand the system is receiving.

Example:

```text
Requests per second = 250
```

## Errors

How many requests are failing.

Example:

```text
HTTP 5xx rate = 3%
```

## Saturation

How full the system is.

Example:

```text
CPU = 90%
Memory = 85%
Database connections = 95% used
```

These four signals become the base of monitoring.

---

# 14. Production Alerting Mindset

Bad alert:

```text
CPU is above 80%.
```

Why bad?

Maybe CPU is high but users are fine.

Better alert:

```text
API error rate is above 5% for 5 minutes.
```

Best alert:

```text
The service is burning error budget too fast.
```

Production rule:

```text
Alert on user impact, not only machine symptoms.
```

CPU, RAM, and disk are useful, but user-facing symptoms matter more.

---

# 15. Mini Architecture Thinking

If your target is 99.9%, you may need:

```text
1 Load Balancer
2 app instances
Health checks
Automated rollback
Database backups
Monitoring and alerts
Basic incident response
```

If your target is 99.99%, you may need:

```text
Multiple availability zones
Autoscaling
Managed database with failover
Canary deployment
Strong observability
On-call rotation
Disaster recovery plan
```

So reliability target directly affects architecture.

---

# 16. Mini Lab — Define SLOs for Your Todo App

Add this to your `devops-masterclass-notes.md`:

```markdown
## Lesson 1.4 — SLA, SLO, SLI, Error Budget

### Definitions

SLI:
SLO:
SLA:
Error Budget:

### Todo App SLIs

1.
2.
3.

### Todo App SLOs

1.
2.
3.

### Error Budget

If my SLO is 99.9%, allowed downtime per month is:

### Monitoring Signals

Latency:
Traffic:
Errors:
Saturation:
```

Fill it like this:

```markdown
## Lesson 1.4 — SLA, SLO, SLI, Error Budget

### Definitions

SLI:
A measurement of service reliability, such as request success rate or latency.

SLO:
The reliability target we want to achieve, such as 99.9% success rate.

SLA:
A formal promise to customers, usually with business/legal consequences.

Error Budget:
The amount of failure allowed before we violate the SLO.

### Todo App SLIs

1. API success rate
2. API p95 latency
3. Frontend availability

### Todo App SLOs

1. 99.9% of API requests should not return 5xx over 30 days.
2. 95% of API requests should complete under 500ms.
3. 99.9% of frontend page loads should succeed.

### Error Budget

If my SLO is 99.9%, allowed downtime per month is around 43 minutes.

### Monitoring Signals

Latency:
p95 API response time

Traffic:
Requests per second

Errors:
HTTP 5xx percentage

Saturation:
CPU, memory, disk, DB connections
```

---

# 17. Interview Answer

Question:

```text
What is the difference between SLA, SLO, and SLI?
```

Strong answer:

```text
SLI is the actual measurement, SLO is the internal target, and SLA is the external promise to customers. For example, an SLI could be current API success rate of 99.94%. The SLO could be 99.9% API success rate over 30 days. The SLA could be a contractual promise of 99.5% uptime. Engineering teams use SLIs and SLOs to manage reliability, while SLAs are usually business or legal commitments.
```

Question:

```text
What is an error budget?
```

Strong answer:

```text
An error budget is the amount of unreliability allowed by the SLO. If the SLO is 99.9%, then 0.1% failure is allowed. For a month, that is roughly 43 minutes of downtime. If the error budget is healthy, the team can continue shipping features. If the budget is almost exhausted, the team should slow down risky releases and focus on reliability improvements.
```

---

# Today’s Core Rules

Remember these:

```text
SLI = measurement
SLO = target
SLA = promise
Error budget = allowed failure
Alert on user impact
More 9s cost more money
Reliability target drives architecture
```

Next lesson:

# Lesson 1.5 — Production Architecture: Monolith, Microservices, Load Balancer, Database, Cache, Queue
