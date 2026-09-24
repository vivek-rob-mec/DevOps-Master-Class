# Module 20 — Final Mega Capstone Project

## Lesson 3: AWS Landing Zone, Network and Identity

# 20.3.1 Account topology

```text
organization management
├── security/log archive
├── shared services/network
├── tooling (CI, registry, GitOps management)
├── non-production workloads
├── production workloads
└── disaster-recovery workloads
```

Use organizational guardrails and separate billing/ownership. Do not run ordinary workloads in the management account.

# 20.3.2 Regional network

```text
VPC across 3 Availability Zones
├── public subnets: edge load balancers/NAT only as designed
├── private application subnets: EKS nodes
└── isolated data subnets: databases/caches
```

Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private endpoints for cloud APIs where justified; centralize egress only after modeling availability and cost. Flow logs and DNS query evidence support investigation.

# 20.3.3 Identity chain

```text
human → enterprise IdP/MFA → Identity Center/federation → role
CI → OIDC token → scoped build/promotion role
pod → service account/workload identity → scoped AWS role
Argo → management identity → target role → EKS access → Kubernetes RBAC
```

No shared long-lived IAM users. Restrict trust policy subject, audience, repository/ref/environment, account, and session. Separate build, infrastructure, deploy, and read-only response roles.

# 20.3.4 Encryption and audit

Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role assumption.

# 20.3.5 Terraform gate

Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and recoverable.

# 20.3.6 Failure tests

```text
deny an expected IAM action and diagnose the chain
remove one NAT/path and observe bounded impact
attempt public database access and prove prevention
assume CI role from untrusted branch and prove denial
restore Terraform state in a clean exercise environment
```

# 20.3.7 Evidence

Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.

# 20.3.8 Beginner mental model: separate buildings with guarded roads

An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.

# 20.3.9 Account/OU topology

Example:

```text
Organization root
├── Security OU: log archive, security tooling
├── Infrastructure OU: network/shared services
├── Workloads-NonProd OU: dev/test accounts
├── Workloads-Prod OU: production accounts
└── Sandbox OU: restricted learning accounts
```

Use organization policies/guardrails carefully. An SCP limits maximum permissions; it does not grant access and does not replace IAM/resource policies.

# 20.3.10 Identity chain

```text
human -> corporate identity center/federation + MFA -> permission set/role
CI -> OIDC federation -> scoped build role
Kubernetes workload -> EKS-supported workload identity mechanism -> service role
platform controller -> dedicated scoped provider roles
break-glass -> separately protected time-bound audited role
```

No shared IAM users or long-lived access keys for normal operations.

# 20.3.11 Network design

For each region:

```text
VPC
├── public subnets: only required internet-facing load balancers/NAT
├── private application subnets: EKS nodes/pods as designed
├── isolated data subnets: databases/caches where appropriate
├── endpoints/private service access
└── controlled egress, DNS, flow evidence
```

Plan CIDR for pods/nodes/growth/peering and avoid overlap. Multi-AZ placement requires routing/NAT/endpoints and data services in intended zones.

# 20.3.12 Ingress and egress

Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, telemetry, provider, and update paths.

High availability versus NAT/endpoints cost is an explicit decision.

# 20.3.13 Encryption and keys

Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.

Encryption is not authorization. Least-privilege data/resource policies remain necessary.

# 20.3.14 Logging and detection

Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.

Keep sensitive data out of broad logs and account for logging cost.

# 20.3.15 Terraform module structure

```text
modules/
  organization-account-baseline/
  regional-network/
  identity-role/
  audit-logging/
live/
  security/log-archive/
  infrastructure/network/
  nonprod/region/
  prod/region/
```

Use small clear state boundaries, remote encrypted state/locking/versioning, pinned providers/modules, plans, policy, and separate deployment identities.

# 20.3.16 Real hands-on: sandbox landing zone

In an approved sandbox or through plans only:

1. Define account/OU and mandatory guardrails.
2. Build regional VPC/subnet/route/endpoints design.
3. Create federated human/CI/workload roles.
4. Enable audit/config/flow evidence.
5. Add budgets/anomaly and ownership tags.
6. Run Terraform validate/format/plan/security/policy checks.
7. Store no secrets in variables/state/output.

If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.

# 20.3.17 Failure/security tests

Attempt in lab:

```text
normal developer assumes production-admin role
CI requests role from untrusted branch/repository
workload reads another service's secret/storage
resource creates public database or open security group
audit trail disabled
unapproved region/resource class
cross-account data access without resource policy
```

Capture prevention and audit evidence. Do not test against unrelated accounts.

# 20.3.18 Network failure tests

Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery.

Validate from actual workload identity/network location, not an admin laptop alone.

# 20.3.19 Cost and quota controls

Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe.

Quota is a capacity dependency; include increase lead time and failure-mode usage.

# 20.3.20 Acceptance checklist

- Account/OU/guardrail choices map to trust and ownership.
- Human, CI, workload, platform, break-glass identities are separate.
- No static cloud credentials are required.
- Network routes, DNS, ingress/egress, endpoints, CIDR growth are documented.
- Multi-AZ/failure paths and remaining capacity are tested.
- Keys/logs/security evidence have independent protection/recovery.
- Terraform state/identity/module lifecycle are controlled.
- Denial/adversarial tests and audit prove boundaries.
- Budget, cost allocation, quota, teardown are active.

# 20.3.21 Certification and interview preparation

This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide.

**Beginner: Why multiple accounts?**  Stronger ownership, billing, quota, policy, and blast-radius boundaries than tags/VPCs alone.

**Intermediate: What does an SCP do?**  Sets an organization-level permission boundary/maximum; it does not itself grant IAM permissions.

**Intermediate: Public versus private subnet?**  Classification depends on routing; a public subnet has a route enabling direct internet gateway path for applicable resources, while private workloads use controlled egress/endpoints.

**Senior: How should CI access AWS?**  Federated short-lived identity such as OIDC with repository/branch/workflow conditions and least-privilege role.

**Senior: How do EKS workloads access AWS?**  Use the current supported workload identity integration to map ServiceAccount/workload identity to scoped role—never node-wide static keys.

**Expert: How do you design cross-account access?**  Trusted principal identity policy plus target resource/trust policy, conditions, encryption key grants, network path, audit, and denial tests.

**Architect: What is the landing-zone exit gate?**  Governed identity/account/network/log/key/state/budget baseline with tested unauthorized and failure paths before workloads.

**Never-forget answer:** establish account, identity, network, key, log, quota, and cost boundaries before workload scale; prove them with denial and failure tests.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 20.3.22 Professional Mastery Workbook

This workbook expands **AWS Landing Zone, Network and Identity** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 21 lesson-specific anchors.
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

### Concept card 1 - Account topology

- Lesson anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Beginner explanation: Restate **Account topology** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Account topology** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Account topology**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Account topology**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Account topology** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Regional network

- Lesson anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Beginner explanation: Restate **Regional network** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Regional network** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Regional network**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Regional network**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Regional network** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Identity chain

- Lesson anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Beginner explanation: Restate **Identity chain** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Identity chain** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Identity chain**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Identity chain**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Identity chain** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Encryption and audit

- Lesson anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Beginner explanation: Restate **Encryption and audit** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Encryption and audit** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Encryption and audit**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Encryption and audit**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Encryption and audit** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Terraform gate

- Lesson anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Beginner explanation: Restate **Terraform gate** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Terraform gate** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Terraform gate**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Terraform gate**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Terraform gate** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Failure tests

- Lesson anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Beginner explanation: Restate **Failure tests** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure tests** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Failure tests**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Failure tests**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Failure tests** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Evidence

- Lesson anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Beginner explanation: Restate **Evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Evidence**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Beginner mental model: separate buildings with guarded roads

- Lesson anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Beginner explanation: Restate **Beginner mental model: separate buildings with guarded roads** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Beginner mental model: separate buildings with guarded roads** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Beginner mental model: separate buildings with guarded roads**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Beginner mental model: separate buildings with guarded roads**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Beginner mental model: separate buildings with guarded roads** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Account/OU topology

- Lesson anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Beginner explanation: Restate **Account/OU topology** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Account/OU topology** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Account/OU topology**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Account/OU topology**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Account/OU topology** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Identity chain

- Lesson anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Beginner explanation: Restate **Identity chain** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Identity chain** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Identity chain**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Identity chain**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Identity chain** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Network design

- Lesson anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Beginner explanation: Restate **Network design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Network design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Network design**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Network design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Network design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Ingress and egress

- Lesson anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Beginner explanation: Restate **Ingress and egress** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Ingress and egress** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Ingress and egress**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Ingress and egress**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Ingress and egress** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Encryption and keys

- Lesson anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Beginner explanation: Restate **Encryption and keys** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Encryption and keys** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Encryption and keys**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Encryption and keys**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Encryption and keys** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Logging and detection

- Lesson anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Beginner explanation: Restate **Logging and detection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Logging and detection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Logging and detection**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Logging and detection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Logging and detection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Terraform module structure

- Lesson anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Beginner explanation: Restate **Terraform module structure** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Terraform module structure** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Terraform module structure**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Terraform module structure**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Terraform module structure** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Real hands-on: sandbox landing zone

- Lesson anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Beginner explanation: Restate **Real hands-on: sandbox landing zone** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real hands-on: sandbox landing zone** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a supply-chain, provenance, admission, and runtime record focused on **Real hands-on: sandbox landing zone**.
- Failure exercise: In an isolated environment, make CI, GitOps, policy, or secret evidence unavailable while observing the boundaries around **Real hands-on: sandbox landing zone**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Real hands-on: sandbox landing zone** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Failure/security tests

- Lesson anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Beginner explanation: Restate **Failure/security tests** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure/security tests** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an SLO investigation, incident, restore, and game-day report focused on **Failure/security tests**.
- Failure exercise: In an isolated environment, introduce a regional data-authority and routing conflict while observing the boundaries around **Failure/security tests**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Failure/security tests** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Network failure tests

- Lesson anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Beginner explanation: Restate **Network failure tests** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Network failure tests** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a platform journey, allocation, unit-cost, and portfolio artifact focused on **Network failure tests**.
- Failure exercise: In an isolated environment, create a cost anomaly while a customer SLO is at risk while observing the boundaries around **Network failure tests**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Network failure tests** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Cost and quota controls

- Lesson anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Beginner explanation: Restate **Cost and quota controls** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cost and quota controls** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a traceable requirement, ADR, implementation, and test record focused on **Cost and quota controls**.
- Failure exercise: In an isolated environment, combine a bad release with a dependency brownout while observing the boundaries around **Cost and quota controls**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Cost and quota controls** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Acceptance checklist

- Lesson anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Beginner explanation: Restate **Acceptance checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Acceptance checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Terraform, EKS, GitOps, and identity validation bundle focused on **Acceptance checklist**.
- Failure exercise: In an isolated environment, remove a zone while capacity or rollout is constrained while observing the boundaries around **Acceptance checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Acceptance checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Certification and interview preparation

- Lesson anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Beginner explanation: Restate **Certification and interview preparation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Certification and interview preparation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an idempotency, outbox, migration, and data-integrity report focused on **Certification and interview preparation**.
- Failure exercise: In an isolated environment, break telemetry and the primary page path together while observing the boundaries around **Certification and interview preparation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Explain **Certification and interview preparation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Account topology x capacity

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **capacity** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Regional network x cost efficiency

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **cost efficiency** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Identity chain x recovery

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **recovery** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Encryption and audit x change management

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **change management** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Terraform gate x dependency failure

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **dependency failure** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Failure tests x developer experience

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **developer experience** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Evidence x availability

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **availability** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Beginner mental model: separate buildings with guarded roads x security

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **security** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Account/OU topology x delivery safety

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Identity chain x multi-tenancy

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Network design x observability

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **observability** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Ingress and egress x regional resilience

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **regional resilience** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Encryption and keys x business value

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **business value** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Logging and detection x latency

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **latency** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Terraform module structure x privacy

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **privacy** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Real hands-on: sandbox landing zone x operability

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **operability** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Failure/security tests x data integrity

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **data integrity** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Network failure tests x automation safety

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network failure tests** while a change involving **Cost and quota controls** places **automation safety** at risk.
- Plain-language question: What problem does **Network failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network failure tests** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Cost and quota controls x governance

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Cost and quota controls** while a change involving **Encryption and audit** places **governance** at risk.
- Plain-language question: What problem does **Cost and quota controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost and quota controls** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Acceptance checklist x correctness

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Network design** places **correctness** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Certification and interview preparation x capacity

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Network failure tests** places **capacity** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Account topology x cost efficiency

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **cost efficiency** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Regional network x recovery

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **recovery** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Identity chain x change management

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **change management** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Encryption and audit x dependency failure

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **dependency failure** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Terraform gate x developer experience

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **developer experience** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Failure tests x availability

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **availability** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Evidence x security

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **security** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Beginner mental model: separate buildings with guarded roads x delivery safety

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **delivery safety** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Account/OU topology x multi-tenancy

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Identity chain x observability

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **observability** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Network design x regional resilience

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **regional resilience** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Ingress and egress x business value

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **business value** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Encryption and keys x latency

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **latency** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Logging and detection x privacy

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **privacy** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Terraform module structure x operability

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **operability** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Real hands-on: sandbox landing zone x data integrity

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **data integrity** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Failure/security tests x automation safety

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **automation safety** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Network failure tests x governance

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Network failure tests** while a change involving **Cost and quota controls** places **governance** at risk.
- Plain-language question: What problem does **Network failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network failure tests** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Cost and quota controls x correctness

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Cost and quota controls** while a change involving **Encryption and audit** places **correctness** at risk.
- Plain-language question: What problem does **Cost and quota controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost and quota controls** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Acceptance checklist x capacity

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Network design** places **capacity** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Certification and interview preparation x cost efficiency

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Network failure tests** places **cost efficiency** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Account topology x recovery

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **recovery** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Regional network x change management

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **change management** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Identity chain x dependency failure

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **dependency failure** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Encryption and audit x developer experience

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **developer experience** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Terraform gate x availability

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **availability** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Failure tests x security

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **security** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Evidence x delivery safety

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **delivery safety** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Beginner mental model: separate buildings with guarded roads x multi-tenancy

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Account/OU topology x observability

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **observability** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Identity chain x regional resilience

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **regional resilience** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - Network design x business value

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **business value** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - Ingress and egress x latency

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **latency** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Encryption and keys x privacy

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **privacy** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Logging and detection x operability

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **operability** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Terraform module structure x data integrity

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **data integrity** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 058 - Real hands-on: sandbox landing zone x automation safety

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **automation safety** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 059 - Failure/security tests x governance

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **governance** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 060 - Network failure tests x correctness

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network failure tests** while a change involving **Cost and quota controls** places **correctness** at risk.
- Plain-language question: What problem does **Network failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network failure tests** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 061 - Cost and quota controls x capacity

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Cost and quota controls** while a change involving **Encryption and audit** places **capacity** at risk.
- Plain-language question: What problem does **Cost and quota controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost and quota controls** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 062 - Acceptance checklist x cost efficiency

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Network design** places **cost efficiency** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 063 - Certification and interview preparation x recovery

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Network failure tests** places **recovery** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 064 - Account topology x change management

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **change management** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 065 - Regional network x dependency failure

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **dependency failure** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 066 - Identity chain x developer experience

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **developer experience** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 067 - Encryption and audit x availability

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **availability** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 068 - Terraform gate x security

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **security** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 069 - Failure tests x delivery safety

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **delivery safety** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 070 - Evidence x multi-tenancy

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 071 - Beginner mental model: separate buildings with guarded roads x observability

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **observability** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 072 - Account/OU topology x regional resilience

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **regional resilience** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 073 - Identity chain x business value

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **business value** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 074 - Network design x latency

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **latency** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 075 - Ingress and egress x privacy

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **privacy** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 076 - Encryption and keys x operability

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **operability** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 077 - Logging and detection x data integrity

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **data integrity** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 078 - Terraform module structure x automation safety

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **automation safety** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 079 - Real hands-on: sandbox landing zone x governance

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **governance** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 080 - Failure/security tests x correctness

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **correctness** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 081 - Network failure tests x capacity

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Network failure tests** while a change involving **Cost and quota controls** places **capacity** at risk.
- Plain-language question: What problem does **Network failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network failure tests** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 082 - Cost and quota controls x cost efficiency

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Cost and quota controls** while a change involving **Encryption and audit** places **cost efficiency** at risk.
- Plain-language question: What problem does **Cost and quota controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost and quota controls** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 083 - Acceptance checklist x recovery

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Network design** places **recovery** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 084 - Certification and interview preparation x change management

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Network failure tests** places **change management** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 085 - Account topology x dependency failure

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **dependency failure** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 086 - Regional network x developer experience

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **developer experience** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 087 - Identity chain x availability

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **availability** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 088 - Encryption and audit x security

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **security** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 089 - Terraform gate x delivery safety

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **delivery safety** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 090 - Failure tests x multi-tenancy

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 091 - Evidence x observability

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **observability** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 092 - Beginner mental model: separate buildings with guarded roads x regional resilience

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **regional resilience** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 093 - Account/OU topology x business value

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **business value** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 094 - Identity chain x latency

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **latency** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 095 - Network design x privacy

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **privacy** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 096 - Ingress and egress x operability

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **operability** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 097 - Encryption and keys x data integrity

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **data integrity** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 098 - Logging and detection x automation safety

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **automation safety** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 099 - Terraform module structure x governance

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **governance** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 100 - Real hands-on: sandbox landing zone x correctness

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **correctness** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 101 - Failure/security tests x capacity

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **capacity** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 102 - Network failure tests x cost efficiency

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network failure tests** while a change involving **Cost and quota controls** places **cost efficiency** at risk.
- Plain-language question: What problem does **Network failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Break DNS resolution, one NAT/endpoint route, one Availability Zone path, and a security-group rule in isolation. Observe EKS/API/dependency/telemetry behavior, cost implications, alarms, runbooks, and recovery. Validate from actual workload identity/networ...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network failure tests** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 103 - Cost and quota controls x recovery

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Cost and quota controls** while a change involving **Encryption and audit** places **recovery** at risk.
- Plain-language question: What problem does **Cost and quota controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Set sandbox/prod budgets and anomaly monitors, canonical ownership, approved regions/classes, service quotas, endpoint/NAT/flow-log cost estimates, and automatic TTL for lab resources where safe. Quota is a capacity dependency; include increase lead time an...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Cost and quota controls** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 104 - Acceptance checklist x change management

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Acceptance checklist** while a change involving **Network design** places **change management** at risk.
- Plain-language question: What problem does **Acceptance checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: The lesson establishes Acceptance checklist as a concept that must be explained, implemented, tested, and defended.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Acceptance checklist** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 105 - Certification and interview preparation x dependency failure

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Certification and interview preparation** while a change involving **Network failure tests** places **dependency failure** at risk.
- Plain-language question: What problem does **Certification and interview preparation** solve here, and who notices first when it fails?
- Lesson evidence anchor: This lesson supports AWS security/network/organizations/IAM and architecture competencies. Verify current official service features, limits, and exam guide. Beginner: Why multiple accounts?  Stronger ownership, billing, quota, policy, and blast-radius bound...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Certification and interview preparation** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 106 - Account topology x developer experience

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Account topology** while a change involving **Encryption and audit** places **developer experience** at risk.
- Plain-language question: What problem does **Account topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: organization management ├── security/log archive ├── shared services/network ├── tooling (CI, registry, GitOps management) ├── non-production workloads ├── production workloads └── disaster-recovery workloads Use organizational guardrails and separate billi...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account topology** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 107 - Regional network x availability

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Regional network** while a change involving **Network design** places **availability** at risk.
- Plain-language question: What problem does **Regional network** solve here, and who notices first when it fails?
- Lesson evidence anchor: VPC across 3 Availability Zones ├── public subnets: edge load balancers/NAT only as designed ├── private application subnets: EKS nodes └── isolated data subnets: databases/caches Plan CIDRs for VPC, Pods, services, peering/transit, and growth. Use private...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Regional network** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 108 - Identity chain x security

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Identity chain** while a change involving **Network failure tests** places **security** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human → enterprise IdP/MFA → Identity Center/federation → role CI → OIDC token → scoped build/promotion role pod → service account/workload identity → scoped AWS role Argo → management identity → target role → EKS access → Kubernetes RBAC
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 109 - Encryption and audit x delivery safety

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Encryption and audit** while a change involving **Terraform gate** places **delivery safety** at risk.
- Plain-language question: What problem does **Encryption and audit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use KMS key ownership and policies appropriate to S3, ECR, EBS, database, backups, logs, and secrets. Centralize organization audit with protected retention. Alert on root use, guardrail changes, public exposure, key/secret policy changes, and unusual role...
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and audit** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 110 - Terraform gate x multi-tenancy

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform gate** while a change involving **Network design** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Terraform gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build reusable modules and separate state per environment/failure domain. CI performs format, validate, tests, security/policy, plan artifact, review, controlled apply, and post-apply checks. State is encrypted, locked, versioned, access-controlled, and rec...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform gate** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 111 - Failure tests x observability

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Failure tests** while a change involving **Network failure tests** places **observability** at risk.
- Plain-language question: What problem does **Failure tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: deny an expected IAM action and diagnose the chain remove one NAT/path and observe bounded impact attempt public database access and prove prevention assume CI role from untrusted branch and prove denial restore Terraform state in a clean exercise environment
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure tests** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 112 - Evidence x regional resilience

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Evidence** while a change involving **Encryption and audit** places **regional resilience** at risk.
- Plain-language question: What problem does **Evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deliver account/VPC diagrams, IAM trust matrix, data-flow/threat model, Terraform plans/tests, audit queries, cost estimate, and rollback/cleanup runbook.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Evidence** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 113 - Beginner mental model: separate buildings with guarded roads x business value

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Beginner mental model: separate buildings with guarded roads** while a change involving **Network design** places **business value** at risk.
- Plain-language question: What problem does **Beginner mental model: separate buildings with guarded roads** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AWS landing zone creates governed accounts, identities, networks, logs, and guardrails before application resources. Separate accounts can reduce blast radius and billing ambiguity, but they still need controlled connectivity and centralized governance.
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Beginner mental model: separate buildings with guarded roads** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 114 - Account/OU topology x latency

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Account/OU topology** while a change involving **Network failure tests** places **latency** at risk.
- Plain-language question: What problem does **Account/OU topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: Organization root ├── Security OU: log archive, security tooling ├── Infrastructure OU: network/shared services ├── Workloads-NonProd OU: dev/test accounts ├── Workloads-Prod OU: production accounts └── Sandbox OU: restricted learning accounts
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Account/OU topology** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 115 - Identity chain x privacy

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Identity chain** while a change involving **Encryption and audit** places **privacy** at risk.
- Plain-language question: What problem does **Identity chain** solve here, and who notices first when it fails?
- Lesson evidence anchor: human - corporate identity center/federation + MFA - permission set/role CI - OIDC federation - scoped build role Kubernetes workload - EKS-supported workload identity mechanism - service role platform controller - dedicated scoped provider roles
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Identity chain** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 116 - Network design x operability

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Network design** while a change involving **Ingress and egress** places **operability** at risk.
- Plain-language question: What problem does **Network design** solve here, and who notices first when it fails?
- Lesson evidence anchor: For each region: VPC ├── public subnets: only required internet-facing load balancers/NAT ├── private application subnets: EKS nodes/pods as designed ├── isolated data subnets: databases/caches where appropriate ├── endpoints/private service access
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Network design** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 117 - Ingress and egress x data integrity

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Ingress and egress** while a change involving **Network failure tests** places **data integrity** at risk.
- Plain-language question: What problem does **Ingress and egress** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect public ingress with DNS, certificate, CDN/WAF/load balancer as requirements justify. Restrict security groups and Kubernetes network policy. Control egress to reduce data exfiltration and accidental network cost; document DNS, package/registry, tele...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: combine a bad release with a dependency brownout.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Ingress and egress** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 118 - Encryption and keys x automation safety

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Encryption and keys** while a change involving **Encryption and audit** places **automation safety** at risk.
- Plain-language question: What problem does **Encryption and keys** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define encryption in transit and at rest, key ownership, grants, rotation, deletion protection, audit, regional recovery, and separation of duties. Avoid one key/administrator becoming an untested shared regional dependency.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: create a cost anomaly while a customer SLO is at risk.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Encryption and keys** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 119 - Logging and detection x governance

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Logging and detection** while a change involving **Network design** places **governance** at risk.
- Plain-language question: What problem does **Logging and detection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Centralize organization/account/cloud audit, configuration, network flow, security findings, and identity events according to policy. Protect logs from workload administrators, define retention/access, and test that disabled/tampered logging is detected.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce a regional data-authority and routing conflict.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Logging and detection** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 120 - Terraform module structure x correctness

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Terraform module structure** while a change involving **Network failure tests** places **correctness** at risk.
- Plain-language question: What problem does **Terraform module structure** solve here, and who notices first when it fails?
- Lesson evidence anchor: modules/ organization-account-baseline/ regional-network/ identity-role/ audit-logging/ live/ security/log-archive/ infrastructure/network/ nonprod/region/ prod/region/ Use small clear state boundaries, remote encrypted state/locking/versioning, pinned prov...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Terraform, EKS, GitOps, and identity validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make CI, GitOps, policy, or secret evidence unavailable.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Terraform module structure** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 121 - Real hands-on: sandbox landing zone x capacity

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Real hands-on: sandbox landing zone** while a change involving **Encryption and audit** places **capacity** at risk.
- Plain-language question: What problem does **Real hands-on: sandbox landing zone** solve here, and who notices first when it fails?
- Lesson evidence anchor: In an approved sandbox or through plans only: If real multi-account creation is unavailable, produce reviewed Terraform plans/diagrams and test in one isolated account.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a supply-chain, provenance, admission, and runtime record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break telemetry and the primary page path together.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Real hands-on: sandbox landing zone** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 122 - Failure/security tests x cost efficiency

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Failure/security tests** while a change involving **Network design** places **cost efficiency** at risk.
- Plain-language question: What problem does **Failure/security tests** solve here, and who notices first when it fails?
- Lesson evidence anchor: Attempt in lab: normal developer assumes production-admin role CI requests role from untrusted branch/repository workload reads another service's secret/storage resource creates public database or open security group audit trail disabled
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a platform journey, allocation, unit-cost, and portfolio artifact and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove a zone while capacity or rollout is constrained.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.
- Interview prompt: Defend **Failure/security tests** against an alternative while protecting cost efficiency under this scenario.
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

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html "AWS Organizations"
[2]: https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html "AWS Security Pillar"
[3]: https://docs.aws.amazon.com/eks/latest/userguide/security-iam.html "Amazon EKS IAM"
