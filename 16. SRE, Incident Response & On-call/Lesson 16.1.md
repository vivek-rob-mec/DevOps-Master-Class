# Module 16 — SRE, Incident Response & On-call

## Lesson 1: SRE Operating Model and Service Ownership

Site Reliability Engineering applies software engineering to operations so services can meet explicit user expectations at sustainable cost and human effort.

# 16.1.1 Reliability is a product property

```text
users + business expectations
          ↓
SLIs/SLOs and risk tolerance
          ↓
architecture + delivery + operations
          ↓
measured outcomes and learning
```

An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE supplies reliability engineering, automation, operational standards, and sometimes shared on-call under an explicit engagement model.

# 16.1.2 Service ownership record

Every service needs:

```yaml
service: todo-api
owner: team-todo
tier: 1
repository: https://git.example.com/todo/api
on_call: todo-primary
dashboard: https://grafana.example.com/d/todo
runbook: https://runbooks.example.com/todo
slo: https://slo.example.com/todo-api
dependencies: [postgres-orders, identity-api]
data_classification: confidential
recovery:
  rto: 60m
  rpo: 5m
```

Ownership includes code, production behavior, telemetry, alerts, capacity, dependencies, security response, recovery, cost, and documentation.

# 16.1.3 Engagement boundaries

Define entry criteria before SRE accepts operational responsibility:

```text
service has owner and architecture
critical journeys and SLOs exist
monitoring and runbooks work
release/rollback is controlled
capacity and dependency risks are known
security and DR obligations are documented
toil and pager load are measured
```

If reliability load consumes the team, freeze discretionary changes and return engineering work to service owners according to policy.

# 16.1.4 Lab

Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.

# 16.1.5 Interview answer

> **SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work competes transparently with feature work and is automated where possible.**

# 16.1.6 Beginner mental model: reliability is a shared product feature

Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development.

```text
product decides valuable user journeys and risk tolerance
developers build operable, testable services
SRE applies engineering to reliability and operations
platform teams provide safe reusable capabilities
security/data teams define mandatory controls
leadership funds the agreed tradeoffs
```

SRE is a set of practices and an organizational model. A company can use SRE practices without naming a team “SRE,” while a team named SRE can fail to practice SRE if it only handles tickets manually.

# 16.1.7 Operations, DevOps, and SRE

These terms overlap but answer different questions:

| Concept | Main idea |
|---|---|
| Operations | Run and support systems safely |
| DevOps | Improve collaboration and delivery flow between development and operations |
| SRE | Use software engineering, objectives, and risk budgets to operate reliably at scale |

SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.

# 16.1.8 Reliability versus availability

Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data.

```text
reliability may include
availability + latency + correctness + freshness + durability
+ recoverability + predictable capacity
```

Select properties from user needs. A reporting job may prioritize completion by 06:00 over millisecond latency. A payment API may prioritize correctness above aggressive availability.

# 16.1.9 Service tiering without politics

Tiering determines required controls, not team prestige. Example:

| Criterion | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| User/business impact | Critical journey/revenue/safety | Important degraded capability | Internal or low-impact |
| On-call | 24×7 trained rotation | business hours or shared escalation | owner during working hours |
| SLO/alerts | Formal, paging burn alerts | documented objectives | basic health/ownership |
| DR | Tested stringent RTO/RPO | documented and periodic | rebuild/restore as agreed |
| Change controls | progressive and fast rollback | standard controlled release | proportionate lightweight |

Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.

# 16.1.10 Ownership is an executable contract

A catalog entry becomes useful when other systems can validate it. Required fields should feed:

```text
alerts -> route to team
dashboard -> link SLO and runbook
incident tooling -> page escalation
deployment -> require readiness for tier
cost reports -> allocate service spend
security -> identify data owner
DR tests -> verify RTO/RPO owner
```

Add schema validation for URLs, team IDs, tier, repository, lifecycle, and contacts. Alert on orphaned critical services, not on every minor metadata omission.

# 16.1.11 RACI for a shared SRE engagement

Example for a Tier-1 application:

| Activity | Product team | SRE | Platform | Security |
|---|---|---|---|---|
| Application correctness | A/R | C | I | C |
| SLO design | A/R | R/C | I | I |
| Kubernetes platform | C | C | A/R | C |
| Application on-call | A/R | shared by agreement | escalation | security escalation |
| Reliability automation | R | R | R for platform | C |
| Threat/data controls | R | C | C | A/R |

`A` means accountable, `R` responsible, `C` consulted, and `I` informed. There should be one clear accountable owner for each outcome.

# 16.1.12 SRE engagement models

Common patterns include:

```text
consulting: SRE coaches and reviews; product team operates
embedded: SRE engineers join a product area for a period
shared operations: SRE and developers share on-call under policy
platform SRE: team owns common reliability capabilities
temporary intervention: focused recovery for an unhealthy service
```

Define entry, success, review, and exit criteria. Otherwise temporary help becomes permanent undocumented ownership.

# 16.1.13 Production readiness review

Ask for evidence in these areas:

```text
architecture and dependency failure modes
user journeys, SLIs, SLOs, and error-budget policy
bounded telemetry and actionable alerting
capacity for expected failure and rollout
safe deploy, rollback/revert, and configuration ownership
security, data classification, and access
backup, restore, RTO/RPO, and game-day results
runbooks, escalation, and trained on-call
known risks, toil, cost, and owners
```

A review is not a one-time ceremony. Re-run it after major architecture, traffic, data, tier, or dependency changes.

# 16.1.14 Real hands-on: create a service contract

Choose `todo-api` and create four artifacts:

1. `service.yaml` with schema-validated owner and links.
2. `production-readiness.md` with evidence and unresolved risks.
3. `sre-engagement.md` with responsibilities and exit conditions.
4. `dependency-map.md` with owner, objective, fallback, and escalation per dependency.

Example validation questions:

```text
Does the owner exist in the team directory?
Does the repository contain the deployed source?
Does the dashboard show a user SLI?
Does the runbook contain a verified mitigation?
Can on-call access production before the shift?
Was restore tested within the stated RTO/RPO?
```

# 16.1.15 Failure exercise: orphaned service

Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem.

Remediation should repair the authoritative ownership catalog, connect organizational offboarding to service transfer, and alert before a Tier-1 service becomes orphaned. Adding a name only to the current alert is a local patch.

# 16.1.16 Healthy boundaries and overload

SRE must make capacity for engineering work. Track:

```text
interrupt and ticket hours
pages per shift and night pages
manual task frequency
incident response and follow-up load
planned engineering versus operational work
services per responder and cognitive load
```

When operational work exceeds policy, reduce work through automation, alert repair, service-owner participation, load shedding, or engagement renegotiation. Heroic overtime is not a scaling strategy.

# 16.1.17 Professional decision scenarios

**A product team asks SRE to own a service with no tests or rollback.**  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility.

**A Tier-3 internal tool requests 99.999%.**  Ask for user/business impact and cost. Set a target that reflects need, dependencies, and investment.

**The service exhausted its error budget.**  Apply the pre-agreed policy: tighten releases, prioritize reliability work, and involve accountable product leadership. SRE does not unilaterally punish a team.

# 16.1.18 Certification and learning alignment

There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE programs. Always use the current official objectives for any certification you select.

Completion evidence:

- explain SRE without naming a tool;
- distinguish reliability from availability;
- tier a service using published criteria;
- create an executable ownership record;
- run a production-readiness review;
- define an SRE engagement and exit;
- show how pager/toil overload changes engineering priorities.

# 16.1.19 Interview preparation: beginner to architect

**Beginner: What is SRE?**  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably.

**Intermediate: Who owns production—the developer or SRE?**  Product developers retain service responsibility. SRE responsibilities vary by a documented engagement and may include shared operations, coaching, automation, or platform ownership.

**Intermediate: Why tier services?**  To apply proportionate on-call, SLO, DR, security, and change requirements based on impact.

**Senior: What are entry criteria for SRE support?**  Clear owner/architecture, objectives, telemetry, alert/runbook, controlled delivery, capacity, security/DR, and measurable operational load—or an explicitly funded stabilization plan.

**Expert: How do you stop SRE becoming a ticket queue?**  Publish engagement boundaries, measure toil and pages, require product ownership, prioritize automation/root-cause work, and use error-budget/readiness policy backed by leadership.

**Architect: How does ownership data become reliable?**  Store it as a versioned schema, integrate it with routing/catalog/deployment/governance, validate links and teams automatically, and make service transfer part of organizational change.

**Never-forget answer:** reliability belongs to the product. SRE brings engineering, objectives, and sustainable operations under an explicit ownership contract.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 16.1.20 Professional Mastery Workbook

This workbook expands **SRE Operating Model and Service Ownership** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 19 lesson-specific anchors.
- Progression: beginner, intermediate, expert, professional, industry-ready, certification review, and interview defense.
- Safety: use synthetic data, disposable resources, explicit placeholders, least privilege, and bounded failure experiments.
- Completion: retain commands or configuration, observations, screenshots or query output, decisions, rollback evidence, and a short reflection.
- Quality rule: a passing answer states assumptions, protects a user or business outcome, names ownership, and validates the final result end to end.
- Currency rule: verify current official documentation, versions, limits, pricing, and certification objectives before relying on changing product behavior.

## Seven-stage progression

| Stage | Learner must demonstrate |
|---|---|
| Beginner | Explain the concept in plain language and give one safe example. |
| Intermediate | Connect components, data, control flow, and normal operating behavior. |
| Expert | Analyze trade-offs, edge cases, scaling pressure, and correlated failures. |
| Professional | Make a reviewed decision with owner, evidence, rollout, and rollback. |
| Industry-ready | Operate the design under security, failure, recovery, cost, and compliance constraints. |
| Certification review | Map durable concepts to the latest official objectives without relying on stale wording. |
| Interview defense | Answer concisely, clarify assumptions, draw the model, and defend alternatives. |

## Concept mastery cards

### Concept card 1 - Reliability is a product property

- Lesson anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Beginner explanation: Restate **Reliability is a product property** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reliability is a product property** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an exact SLI/SLO and error-budget decision record focused on **Reliability is a product property**.
- Failure exercise: In an isolated environment, inject a symptom that has two plausible causes while observing the boundaries around **Reliability is a product property**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Reliability is a product property** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Service ownership record

- Lesson anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Beginner explanation: Restate **Service ownership record** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Service ownership record** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an executable runbook and peer-test report focused on **Service ownership record**.
- Failure exercise: In an isolated environment, remove one page-delivery or diagnostic dependency while observing the boundaries around **Service ownership record**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Service ownership record** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Engagement boundaries

- Lesson anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Beginner explanation: Restate **Engagement boundaries** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Engagement boundaries** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an incident timeline, change ledger, and status update focused on **Engagement boundaries**.
- Failure exercise: In an isolated environment, create a retry-amplified dependency brownout while observing the boundaries around **Engagement boundaries**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Engagement boundaries** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Lab

- Lesson anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Beginner explanation: Restate **Lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a toil inventory and bounded automation review focused on **Lab**.
- Failure exercise: In an isolated environment, make a runbook precondition false while observing the boundaries around **Lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Interview answer

- Lesson anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Beginner explanation: Restate **Interview answer** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview answer** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a capacity, risk, and failure-domain model focused on **Interview answer**.
- Failure exercise: In an isolated environment, remove one node, zone, or recovery dependency while observing the boundaries around **Interview answer**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Interview answer** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Beginner mental model: reliability is a shared product feature

- Lesson anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Beginner explanation: Restate **Beginner mental model: reliability is a shared product feature** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Beginner mental model: reliability is a shared product feature** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a restore, RTO, RPO, and integrity report focused on **Beginner mental model: reliability is a shared product feature**.
- Failure exercise: In an isolated environment, introduce a misleading dashboard or incomplete timeline while observing the boundaries around **Beginner mental model: reliability is a shared product feature**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Beginner mental model: reliability is a shared product feature** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Operations, DevOps, and SRE

- Lesson anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Beginner explanation: Restate **Operations, DevOps, and SRE** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Operations, DevOps, and SRE** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an exact SLI/SLO and error-budget decision record focused on **Operations, DevOps, and SRE**.
- Failure exercise: In an isolated environment, inject a symptom that has two plausible causes while observing the boundaries around **Operations, DevOps, and SRE**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Operations, DevOps, and SRE** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Reliability versus availability

- Lesson anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Beginner explanation: Restate **Reliability versus availability** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reliability versus availability** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an executable runbook and peer-test report focused on **Reliability versus availability**.
- Failure exercise: In an isolated environment, remove one page-delivery or diagnostic dependency while observing the boundaries around **Reliability versus availability**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Reliability versus availability** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Service tiering without politics

- Lesson anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Beginner explanation: Restate **Service tiering without politics** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Service tiering without politics** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an incident timeline, change ledger, and status update focused on **Service tiering without politics**.
- Failure exercise: In an isolated environment, create a retry-amplified dependency brownout while observing the boundaries around **Service tiering without politics**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Service tiering without politics** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Ownership is an executable contract

- Lesson anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Beginner explanation: Restate **Ownership is an executable contract** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Ownership is an executable contract** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a toil inventory and bounded automation review focused on **Ownership is an executable contract**.
- Failure exercise: In an isolated environment, make a runbook precondition false while observing the boundaries around **Ownership is an executable contract**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Ownership is an executable contract** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - RACI for a shared SRE engagement

- Lesson anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Beginner explanation: Restate **RACI for a shared SRE engagement** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RACI for a shared SRE engagement** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a capacity, risk, and failure-domain model focused on **RACI for a shared SRE engagement**.
- Failure exercise: In an isolated environment, remove one node, zone, or recovery dependency while observing the boundaries around **RACI for a shared SRE engagement**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **RACI for a shared SRE engagement** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - SRE engagement models

- Lesson anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Beginner explanation: Restate **SRE engagement models** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SRE engagement models** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a restore, RTO, RPO, and integrity report focused on **SRE engagement models**.
- Failure exercise: In an isolated environment, introduce a misleading dashboard or incomplete timeline while observing the boundaries around **SRE engagement models**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **SRE engagement models** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Production readiness review

- Lesson anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Beginner explanation: Restate **Production readiness review** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production readiness review** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an exact SLI/SLO and error-budget decision record focused on **Production readiness review**.
- Failure exercise: In an isolated environment, inject a symptom that has two plausible causes while observing the boundaries around **Production readiness review**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Production readiness review** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Real hands-on: create a service contract

- Lesson anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Beginner explanation: Restate **Real hands-on: create a service contract** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real hands-on: create a service contract** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an executable runbook and peer-test report focused on **Real hands-on: create a service contract**.
- Failure exercise: In an isolated environment, remove one page-delivery or diagnostic dependency while observing the boundaries around **Real hands-on: create a service contract**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Real hands-on: create a service contract** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Failure exercise: orphaned service

- Lesson anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Beginner explanation: Restate **Failure exercise: orphaned service** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure exercise: orphaned service** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an incident timeline, change ledger, and status update focused on **Failure exercise: orphaned service**.
- Failure exercise: In an isolated environment, create a retry-amplified dependency brownout while observing the boundaries around **Failure exercise: orphaned service**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Failure exercise: orphaned service** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Healthy boundaries and overload

- Lesson anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Beginner explanation: Restate **Healthy boundaries and overload** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Healthy boundaries and overload** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a toil inventory and bounded automation review focused on **Healthy boundaries and overload**.
- Failure exercise: In an isolated environment, make a runbook precondition false while observing the boundaries around **Healthy boundaries and overload**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Healthy boundaries and overload** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Professional decision scenarios

- Lesson anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Beginner explanation: Restate **Professional decision scenarios** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Professional decision scenarios** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a capacity, risk, and failure-domain model focused on **Professional decision scenarios**.
- Failure exercise: In an isolated environment, remove one node, zone, or recovery dependency while observing the boundaries around **Professional decision scenarios**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Professional decision scenarios** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Certification and learning alignment

- Lesson anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Beginner explanation: Restate **Certification and learning alignment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Certification and learning alignment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a restore, RTO, RPO, and integrity report focused on **Certification and learning alignment**.
- Failure exercise: In an isolated environment, introduce a misleading dashboard or incomplete timeline while observing the boundaries around **Certification and learning alignment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Certification and learning alignment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Interview preparation: beginner to architect

- Lesson anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Beginner explanation: Restate **Interview preparation: beginner to architect** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview preparation: beginner to architect** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an exact SLI/SLO and error-budget decision record focused on **Interview preparation: beginner to architect**.
- Failure exercise: In an isolated environment, inject a symptom that has two plausible causes while observing the boundaries around **Interview preparation: beginner to architect**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Explain **Interview preparation: beginner to architect** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Reliability is a product property x availability

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **availability** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Service ownership record x security

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **security** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Engagement boundaries x delivery safety

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **delivery safety** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Lab x multi-tenancy

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Interview answer x observability

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **observability** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Beginner mental model: reliability is a shared product feature x regional resilience

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **regional resilience** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Operations, DevOps, and SRE x business value

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **business value** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Reliability versus availability x latency

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **latency** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Service tiering without politics x privacy

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **privacy** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Ownership is an executable contract x operability

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **operability** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - RACI for a shared SRE engagement x data integrity

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **data integrity** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - SRE engagement models x automation safety

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **automation safety** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Production readiness review x governance

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **governance** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Real hands-on: create a service contract x correctness

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **correctness** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Failure exercise: orphaned service x capacity

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **capacity** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Healthy boundaries and overload x cost efficiency

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **cost efficiency** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Professional decision scenarios x recovery

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **recovery** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Certification and learning alignment x change management

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **change management** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Interview preparation: beginner to architect x dependency failure

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **dependency failure** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Reliability is a product property x developer experience

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **developer experience** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Service ownership record x availability

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **availability** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Engagement boundaries x security

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **security** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Lab x delivery safety

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **delivery safety** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Interview answer x multi-tenancy

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Beginner mental model: reliability is a shared product feature x observability

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **observability** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Operations, DevOps, and SRE x regional resilience

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **regional resilience** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Reliability versus availability x business value

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **business value** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Service tiering without politics x latency

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **latency** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Ownership is an executable contract x privacy

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **privacy** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - RACI for a shared SRE engagement x operability

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **operability** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - SRE engagement models x data integrity

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **data integrity** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Production readiness review x automation safety

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **automation safety** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Real hands-on: create a service contract x governance

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **governance** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Failure exercise: orphaned service x correctness

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **correctness** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Healthy boundaries and overload x capacity

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **capacity** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Professional decision scenarios x cost efficiency

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **cost efficiency** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Certification and learning alignment x recovery

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **recovery** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Interview preparation: beginner to architect x change management

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **change management** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Reliability is a product property x dependency failure

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **dependency failure** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Service ownership record x developer experience

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **developer experience** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Engagement boundaries x availability

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **availability** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Lab x security

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **security** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Interview answer x delivery safety

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **delivery safety** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Beginner mental model: reliability is a shared product feature x multi-tenancy

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Operations, DevOps, and SRE x observability

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **observability** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Reliability versus availability x regional resilience

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **regional resilience** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Service tiering without politics x business value

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **business value** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Ownership is an executable contract x latency

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **latency** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - RACI for a shared SRE engagement x privacy

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **privacy** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - SRE engagement models x operability

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **operability** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Production readiness review x data integrity

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **data integrity** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Real hands-on: create a service contract x automation safety

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **automation safety** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Failure exercise: orphaned service x governance

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **governance** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Healthy boundaries and overload x correctness

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **correctness** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Professional decision scenarios x capacity

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **capacity** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Certification and learning alignment x cost efficiency

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **cost efficiency** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Interview preparation: beginner to architect x recovery

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **recovery** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - Reliability is a product property x change management

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **change management** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Service ownership record x dependency failure

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **dependency failure** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Engagement boundaries x developer experience

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **developer experience** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Lab x availability

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **availability** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Interview answer x security

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **security** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Beginner mental model: reliability is a shared product feature x delivery safety

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **delivery safety** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Operations, DevOps, and SRE x multi-tenancy

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Reliability versus availability x observability

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **observability** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Service tiering without politics x regional resilience

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **regional resilience** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Ownership is an executable contract x business value

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **business value** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - RACI for a shared SRE engagement x latency

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **latency** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - SRE engagement models x privacy

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **privacy** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - Production readiness review x operability

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **operability** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - Real hands-on: create a service contract x data integrity

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **data integrity** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - Failure exercise: orphaned service x automation safety

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **automation safety** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Healthy boundaries and overload x governance

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **governance** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Professional decision scenarios x correctness

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **correctness** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Certification and learning alignment x capacity

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **capacity** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Interview preparation: beginner to architect x cost efficiency

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **cost efficiency** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Reliability is a product property x recovery

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **recovery** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Service ownership record x change management

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **change management** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Engagement boundaries x dependency failure

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **dependency failure** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - Lab x developer experience

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **developer experience** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Interview answer x availability

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **availability** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Beginner mental model: reliability is a shared product feature x security

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **security** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - Operations, DevOps, and SRE x delivery safety

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **delivery safety** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Reliability versus availability x multi-tenancy

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Service tiering without politics x observability

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **observability** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Ownership is an executable contract x regional resilience

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **regional resilience** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - RACI for a shared SRE engagement x business value

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **business value** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - SRE engagement models x latency

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **latency** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Production readiness review x privacy

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **privacy** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Real hands-on: create a service contract x operability

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **operability** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - Failure exercise: orphaned service x data integrity

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **data integrity** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Healthy boundaries and overload x automation safety

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **automation safety** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Professional decision scenarios x governance

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **governance** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Certification and learning alignment x correctness

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **correctness** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - Interview preparation: beginner to architect x capacity

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **capacity** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Reliability is a product property x cost efficiency

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **cost efficiency** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - Service ownership record x recovery

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **recovery** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Engagement boundaries x change management

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **change management** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 099 - Lab x dependency failure

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **dependency failure** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 100 - Interview answer x developer experience

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **developer experience** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 101 - Beginner mental model: reliability is a shared product feature x availability

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **availability** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 102 - Operations, DevOps, and SRE x security

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **security** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 103 - Reliability versus availability x delivery safety

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **delivery safety** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 104 - Service tiering without politics x multi-tenancy

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service tiering without politics** while a change involving **Engagement boundaries** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Service tiering without politics** solve here, and who notices first when it fails?
- Lesson evidence anchor: Tiering determines required controls, not team prestige. Example: Score impact, data criticality, dependency centrality, and legal obligations using published rules. Review when the service changes.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service tiering without politics** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 105 - Ownership is an executable contract x observability

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Ownership is an executable contract** while a change involving **RACI for a shared SRE engagement** places **observability** at risk.
- Plain-language question: What problem does **Ownership is an executable contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: A catalog entry becomes useful when other systems can validate it. Required fields should feed: alerts - route to team dashboard - link SLO and runbook incident tooling - page escalation deployment - require readiness for tier
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Ownership is an executable contract** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 106 - RACI for a shared SRE engagement x regional resilience

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **RACI for a shared SRE engagement** while a change involving **Professional decision scenarios** places **regional resilience** at risk.
- Plain-language question: What problem does **RACI for a shared SRE engagement** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example for a Tier-1 application: A means accountable, R responsible, C consulted, and I informed. There should be one clear accountable owner for each outcome.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **RACI for a shared SRE engagement** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 107 - SRE engagement models x business value

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **SRE engagement models** while a change involving **Interview answer** places **business value** at risk.
- Plain-language question: What problem does **SRE engagement models** solve here, and who notices first when it fails?
- Lesson evidence anchor: Common patterns include: consulting: SRE coaches and reviews; product team operates embedded: SRE engineers join a product area for a period shared operations: SRE and developers share on-call under policy platform SRE: team owns common reliability capabili...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **SRE engagement models** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 108 - Production readiness review x latency

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production readiness review** while a change involving **SRE engagement models** places **latency** at risk.
- Plain-language question: What problem does **Production readiness review** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask for evidence in these areas: architecture and dependency failure modes user journeys, SLIs, SLOs, and error-budget policy bounded telemetry and actionable alerting capacity for expected failure and rollout safe deploy, rollback/revert, and configuration...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Production readiness review** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 109 - Real hands-on: create a service contract x privacy

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Real hands-on: create a service contract** while a change involving **Interview preparation: beginner to architect** places **privacy** at risk.
- Plain-language question: What problem does **Real hands-on: create a service contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose todo-api and create four artifacts: Example validation questions: Does the owner exist in the team directory? Does the repository contain the deployed source? Does the dashboard show a user SLI? Does the runbook contain a verified mitigation?
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Real hands-on: create a service contract** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 110 - Failure exercise: orphaned service x operability

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Failure exercise: orphaned service** while a change involving **Operations, DevOps, and SRE** places **operability** at risk.
- Plain-language question: What problem does **Failure exercise: orphaned service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Simulate a critical alert for a service whose team was reorganized and whose runbook link is dead. Measure time spent finding ownership versus diagnosing the technical problem. Remediation should repair the authoritative ownership catalog, connect organizat...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Failure exercise: orphaned service** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 111 - Healthy boundaries and overload x data integrity

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Healthy boundaries and overload** while a change involving **Real hands-on: create a service contract** places **data integrity** at risk.
- Plain-language question: What problem does **Healthy boundaries and overload** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE must make capacity for engineering work. Track: interrupt and ticket hours pages per shift and night pages manual task frequency incident response and follow-up load planned engineering versus operational work services per responder and cognitive load
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Healthy boundaries and overload** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 112 - Professional decision scenarios x automation safety

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Professional decision scenarios** while a change involving **Service ownership record** places **automation safety** at risk.
- Plain-language question: What problem does **Professional decision scenarios** solve here, and who notices first when it fails?
- Lesson evidence anchor: A product team asks SRE to own a service with no tests or rollback.  Do a risk review, help define a stabilization plan, and make operational acceptance conditional. Do not silently assume permanent responsibility. A Tier-3 internal tool requests 99.999%....
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Professional decision scenarios** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 113 - Certification and learning alignment x governance

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Certification and learning alignment** while a change involving **Service tiering without politics** places **governance** at risk.
- Plain-language question: What problem does **Certification and learning alignment** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is no single universal SRE certification that defines the profession. This lesson supports service ownership, production readiness, reliability objectives, risk, and operational excellence assessed across cloud, Kubernetes, observability, and SRE prog...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Certification and learning alignment** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 114 - Interview preparation: beginner to architect x correctness

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Interview preparation: beginner to architect** while a change involving **Healthy boundaries and overload** places **correctness** at risk.
- Plain-language question: What problem does **Interview preparation: beginner to architect** solve here, and who notices first when it fails?
- Lesson evidence anchor: Beginner: What is SRE?  An engineering approach that uses software, measurement, and explicit risk objectives to operate services reliably and sustainably. Intermediate: Who owns production—the developer or SRE?  Product developers retain service responsibi...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview preparation: beginner to architect** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 115 - Reliability is a product property x capacity

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Reliability is a product property** while a change involving **Lab** places **capacity** at risk.
- Plain-language question: What problem does **Reliability is a product property** solve here, and who notices first when it fails?
- Lesson evidence anchor: users + business expectations ↓ SLIs/SLOs and risk tolerance ↓ architecture + delivery + operations ↓ measured outcomes and learning An SRE team is not a ticket queue or permanent cleanup crew. Product developers remain responsible for production. SRE suppl...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability is a product property** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 116 - Service ownership record x cost efficiency

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Service ownership record** while a change involving **RACI for a shared SRE engagement** places **cost efficiency** at risk.
- Plain-language question: What problem does **Service ownership record** solve here, and who notices first when it fails?
- Lesson evidence anchor: Every service needs: service: todo-api owner: team-todo tier: 1 repository: https://git.example.com/todo/api oncall: todo-primary dashboard: https://grafana.example.com/d/todo runbook: https://runbooks.example.com/todo slo: https://slo.example.com/todo-api
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Service ownership record** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 117 - Engagement boundaries x recovery

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Engagement boundaries** while a change involving **Certification and learning alignment** places **recovery** at risk.
- Plain-language question: What problem does **Engagement boundaries** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define entry criteria before SRE accepts operational responsibility: service has owner and architecture critical journeys and SLOs exist monitoring and runbooks work release/rollback is controlled capacity and dependency risks are known
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a retry-amplified dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Engagement boundaries** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 118 - Lab x change management

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Lab** while a change involving **Beginner mental model: reliability is a shared product feature** places **change management** at risk.
- Plain-language question: What problem does **Lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Choose a production-style service and create its ownership record, tiering rubric, production-readiness checklist, and SRE engagement agreement. Identify three responsibilities that must remain with the development team.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one page-delivery or diagnostic dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Lab** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 119 - Interview answer x dependency failure

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Interview answer** while a change involving **Production readiness review** places **dependency failure** at risk.
- Plain-language question: What problem does **Interview answer** solve here, and who notices first when it fails?
- Lesson evidence anchor: SRE is an engineering approach to achieving agreed reliability, not a renamed operations queue. I establish ownership, user-focused objectives, error-budget policy, production readiness, measurable toil, and shared response expectations. Reliability work co...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: inject a symptom that has two plausible causes.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Interview answer** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 120 - Beginner mental model: reliability is a shared product feature x developer experience

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Beginner mental model: reliability is a shared product feature** while a change involving **Reliability is a product property** places **developer experience** at risk.
- Plain-language question: What problem does **Beginner mental model: reliability is a shared product feature** solve here, and who notices first when it fails?
- Lesson evidence anchor: Customers do not care whether a failure came from application code, Kubernetes, a database, or an operations team. They experience one product. Reliability therefore cannot be thrown over a wall after development. product decides valuable user journeys and...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a restore, RTO, RPO, and integrity report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a misleading dashboard or incomplete timeline.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Beginner mental model: reliability is a shared product feature** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 121 - Operations, DevOps, and SRE x availability

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Operations, DevOps, and SRE** while a change involving **Reliability versus availability** places **availability** at risk.
- Plain-language question: What problem does **Operations, DevOps, and SRE** solve here, and who notices first when it fails?
- Lesson evidence anchor: These terms overlap but answer different questions: SRE is often described as a concrete implementation of DevOps principles, but do not reduce either to a tool list. CI/CD, Kubernetes, and dashboards help; ownership and decision policy make them useful.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an executable runbook and peer-test report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one node, zone, or recovery dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Operations, DevOps, and SRE** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 122 - Reliability versus availability x security

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reliability versus availability** while a change involving **Failure exercise: orphaned service** places **security** at risk.
- Plain-language question: What problem does **Reliability versus availability** solve here, and who notices first when it fails?
- Lesson evidence anchor: Availability is one reliability property. A service can return HTTP 200 and still be unreliable because it is slow, stale, incorrect, insecure, or loses data. reliability may include availability + latency + correctness + freshness + durability
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a toil inventory and bounded automation review and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a runbook precondition false.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.
- Interview prompt: Defend **Reliability versus availability** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 122.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://sre.google/sre-book/introduction/ "Introduction to Site Reliability Engineering"
[2]: https://sre.google/sre-book/service-best-practices/ "Production Services Best Practices"
[3]: https://sre.google/workbook/how-sre-relates/ "How SRE Relates to DevOps"
[4]: https://sre.google/workbook/on-call/ "Google SRE Workbook: Being On-call"
