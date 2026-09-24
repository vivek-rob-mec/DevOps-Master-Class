# Module 14 — GitOps with Argo CD

## Lesson 15: High Availability, Backup, Disaster Recovery, Scaling & Security Hardening

After Lesson 14, one Argo CD control plane may manage many clusters.

That makes it part of the delivery control plane.

```text
Git unavailable
→ desired changes cannot be read

Argo unavailable
→ desired changes cannot be reconciled

target API unavailable
→ one cluster cannot be reconciled
```

High availability, backup, and disaster recovery are related but different:

```text
HA
= survive component failure with limited interruption

BACKUP
= retain recoverable state

DR
= rebuild service after major loss
```

Argo CD is largely stateless: durable Argo data is stored as Kubernetes objects in the cluster's etcd, while Redis is a disposable cache that can be rebuilt. The project provides HA manifests with additional replicas and Redis HA; the documented HA topology requires at least three nodes because of anti-affinity. ([Argo CD][1])

---

# 14.1725 First define the service objective

Ask:

```text
How long may deployment reconciliation stop?

How much Argo configuration may be lost?

Must the UI remain available during upgrades?

How quickly must a new management cluster take over?
```

Write:

```text
RTO = recovery time objective

RPO = recovery point objective
```

before choosing replicas and backups.

---

# 14.1726 Runtime availability is different

If Argo CD is down:

```text
existing Deployments
Services
Pods
Ingresses
```

normally continue to run.

But:

```text
new Git changes do not reconcile

drift may not self-heal

Application visibility is lost

GitOps-managed recovery is delayed
```

Argo availability protects change and recovery capability, not every application request directly.

---

# 14.1727 Durable Argo state

Important Kubernetes objects include:

```text
Applications

ApplicationSets

AppProjects

cluster Secrets

repository Secrets

argocd-cm

argocd-rbac-cm

argocd-secret

TLS/known-host ConfigMaps

notification configuration and secrets
```

Some should be reconstructed from Git/external secret systems; others still require backup or deterministic regeneration.

---

# 14.1728 Redis is not the source of truth

Redis caches data such as:

```text
generated manifests

application tree/cache information

temporary operational state
```

Do not build DR around restoring Redis data.

Argo documentation states Redis is disposable and can be rebuilt. ([Argo CD][1])

If Redis fails, investigate service impact, restore availability, and allow caches to repopulate.

---

# 14.1729 Component failure map

```text
argocd-server failure
→ UI/API/CLI access affected

application-controller failure
→ comparison and sync affected

repo-server failure
→ Git fetch/render affected

ApplicationSet controller failure
→ generated Application reconciliation affected

notifications controller failure
→ delivery of notifications affected

Redis failure
→ cache/coordination disruption

Dex/IdP failure
→ interactive SSO affected
```

This map drives alerts and scaling.

---

# 14.1730 HA is component-specific

Adding three replicas to every Deployment is not an HA strategy.

Each component has different behavior:

```text
stateless request serving

leader election

cluster sharding

cache quorum

in-memory identity state
```

Use upstream HA manifests or the supported Helm chart settings as a baseline, then validate the exact version.

---

# 14.1731 argocd-server

The API server is stateless and can be horizontally replicated behind a Service/Ingress.

Argo's scaling guidance recommends multiple replicas—three or more for upgrade continuity—and aligning `ARGOCD_API_SERVER_REPLICAS` with the replica count because it participates in concurrent-login limit calculation. ([Argo CD][1])

Test:

```text
readiness

Ingress health checks

gRPC behavior

session/SSO redirects

Pod disruption
```

---

# 14.1732 application-controller

This component:

```text
loads desired manifests through repo-server

watches target cluster state

computes sync/health

executes operations
```

It is usually the major fleet-scaling component.

Scale it based on:

```text
Application count

managed resource count

cluster count

event rate

reconciliation latency

memory
```

---

# 14.1733 Controller processors

Important controls include:

```text
--status-processors

--operation-processors
```

Status processors handle reconciliation work.

Operation processors handle sync operations.

Do not raise them blindly.

Higher concurrency increases pressure on:

```text
repo-server

Redis

target Kubernetes APIs

CPU and memory
```

Argo publishes example processor sizing, but your manifests and clusters must be benchmarked. ([Argo CD][1])

---

# 14.1734 Controller sharding

For many clusters, application-controller replicas can shard cluster ownership.

```text
controller-0
  ├── clusters A, D

controller-1
  ├── clusters B, E

controller-2
  └── clusters C, F
```

The replica count and `ARGOCD_CONTROLLER_REPLICAS` must agree in the documented static setup. Supported algorithms include legacy, round-robin, and consistent hashing with bounded loads. ([Argo CD][1])

---

# 14.1735 Dynamic cluster distribution

Static sharding ties the expected controller replica count to configuration.

Dynamic distribution can rebalance cluster assignments as controller replicas change, depending on the current Argo version and configuration.

Use it only after understanding:

```text
heartbeat behavior

redis dependency

rebalance interval

temporary cache warm-up

failure movement
```

and following the version-specific operator documentation. ([Argo CD][2])

---

# 14.1736 repo-server

repo-server performs:

```text
Git clone/fetch

Helm rendering

Kustomize build

config-management plugins

manifest caching
```

It is often CPU-, memory-, disk-, or network-bound.

Scale replicas for throughput, but first identify whether the bottleneck is:

```text
one expensive application

monorepo invalidation

plugin serialization

Git latency

temporary disk
```

---

# 14.1737 repo-server parallelism

The `--parallelismlimit` setting bounds concurrent manifest generation per repo-server.

Too high:

```text
OOMKilled

thread/process exhaustion

CPU contention
```

Too low:

```text
render queue grows

reconciliation slows
```

Tune from observed render duration, queue pressure, and memory peaks. ([Argo CD][1])

---

# 14.1738 repo-server temporary disk

Repositories are cloned under `/tmp` by default.

Large repositories and many sources can cause:

```text
ephemeral-storage eviction

disk full

slow clone/render
```

Set:

```text
resource requests/limits for ephemeral-storage

appropriate volume strategy

repository size controls
```

and alert on disk pressure.

---

# 14.1739 Manifest-generation timeouts

Key timeout categories include:

```text
repo-server tool execution timeout

controller to repo-server timeout

Git request retry behavior
```

Raising a timeout may hide:

```text
pathological Helm chart

network failure

plugin hang

repository explosion
```

Profile before increasing.

---

# 14.1740 Monorepo invalidation

In a large monorepo:

```text
one commit
  ↓
many Applications see new repository revision
  ↓
many manifests may regenerate
```

Possible controls:

```text
manifest-generate-paths annotation

fully qualified Git refs

webhook path filtering

repository decomposition

side-effect-free render concurrency
```

Use these only with the documented limitations. ([Argo CD][1])

---

# 14.1741 Reconciliation jitter

If thousands of Applications refresh on the same fixed interval:

```text
thundering herd
      │
      ▼
repo-server and controller spike
```

Configure reconciliation jitter so work spreads over time.

Webhooks improve responsiveness but do not remove the need for periodic reconciliation and sane load control.

---

# 14.1742 Target API protection

Argo maintains watches and makes Kubernetes requests across managed clusters.

Protect targets by monitoring:

```text
request rate

429 responses

latency

watch reconnects

cache age
```

Aggressive Argo concurrency can become a control-plane load incident.

---

# 14.1743 Namespace restriction cost

A cluster registration may list accessible namespaces.

Argo warns that each namespace can produce separate list/watch activity and may exhaust idle connections unless client settings are tuned. ([Argo CD][3])

Namespace restriction is useful, but hundreds of listed namespaces have a scaling cost.

Benchmark the exact fleet shape.

---

# 14.1744 Redis HA

The upstream HA topology runs Redis in HA mode.

But remember:

```text
Redis HA
= reduce cache/control interruption

Redis backup
≠ required source-of-truth backup
```

Place Redis Pods across failure domains and monitor quorum, memory, latency, and failover.

Do not expose Redis outside the necessary network boundary.

---

# 14.1745 Pod topology

Production Argo components need:

```text
pod anti-affinity or topology spread

multiple Availability Zones

PodDisruptionBudgets

resource requests

priority classes where justified

node capacity during upgrades
```

Three replicas on one node are not high availability.

---

# 14.1746 PodDisruptionBudget trap

A PDB that is too strict can block:

```text
node upgrades

voluntary maintenance

cluster autoscaling
```

A PDB that is too weak allows too many simultaneous evictions.

Test:

```text
node drain

AZ loss simulation

rolling upgrade
```

not only steady state.

---

# 14.1747 Backup layers

Use several recoverability layers:

```text
Layer 1 — Git
declarative bootstrap and Applications

Layer 2 — external secret manager
repository/cluster/SSO secrets

Layer 3 — argocd admin export
Argo Kubernetes-object state

Layer 4 — Kubernetes/etcd or namespace backup
cluster-level recovery mechanism

Layer 5 — runbooks and tested tooling
human recovery procedure
```

No single layer replaces all others.

---

# 14.1748 What Git can reconstruct

If fully declarative, Git can recreate:

```text
Argo installation values

AppProjects

Applications/ApplicationSets

RBAC ConfigMap

notification templates/triggers

resource customizations
```

But Git should not contain plaintext:

```text
cluster credentials

repo private keys

OIDC client secret

webhook secret
```

---

# 14.1749 What external systems must reconstruct

Recovery also depends on:

```text
Git host

container registries

DNS and certificates

identity provider

AWS IAM roles

EKS access entries

Secrets Manager/Vault

network connectivity
```

An Argo backup cannot restore an unavailable Git provider or revoked IAM trust.

---

# 14.1750 argocd admin export

Argo provides:

```bash
argocd admin export -n argocd > backup.yaml
```

and:

```bash
argocd admin import -n argocd - < backup.yaml
```

The exact invocation can be run with a version-matched Argo image or CLI. The official DR guide emphasizes using the correct namespace; an export may not fail merely because the wrong namespace was selected. ([Argo CD][4])

---

# 14.1751 Protect the export

The export may contain sensitive Kubernetes objects.

Treat it as:

```text
production secret-bearing backup
```

Require:

```text
encryption at rest

restricted storage access

immutable/retained versions

audit logs

secure deletion policy

restore access separation
```

Never commit `backup.yaml` to the config repository.

---

# 14.1752 Backup verification

A successful command exit proves only:

```text
an export command completed.
```

It does not prove:

```text
backup contains expected objects

encryption key is recoverable

storage is readable in disaster

import works

dependencies exist
```

Restore testing is the evidence.

---

# 14.1753 RPO design

If exports run daily:

```text
RPO may approach 24 hours
```

unless Git and external systems reconstruct all intervening changes.

Decide separately for:

```text
declarative config

credentials

signing keys

local accounts

operation history
```

The most sensitive item may need the strongest recovery mechanism.

---

# 14.1754 RTO design

Recovery time includes:

```text
provision management cluster

install Argo version

restore or regenerate secrets

restore configuration

reconnect Git

reconnect target clusters

warm caches

verify Applications

resume safe reconciliation
```

Measure this in a game day.

Do not estimate only the `helm install` duration.

---

# 14.1755 Cold recovery sequence

```text
1. Declare incident and freeze config changes.
2. Establish last known-good Git and backup revisions.
3. Provision/recover management EKS.
4. Install the exact compatible Argo version.
5. Restore foundational secret delivery.
6. Restore/import Argo configuration.
7. Validate SSO, RBAC, and repository access.
8. Validate target cluster authentication.
9. Keep automatic sync constrained initially if needed.
10. Compare fleet before enabling broad reconciliation.
11. Reconcile in risk-ordered groups.
12. Close recovery only after application and audit validation.
```

---

# 14.1756 The double-controller risk

During DR, never allow two independent Argo installations to reconcile the same Applications unknowingly.

```text
old primary recovers
      +
new DR Argo active
      ↓
two control planes mutate targets
```

Use fencing:

```text
revoke credentials

disable cluster reconciliation

network isolation

single active ownership record
```

before failover.

---

# 14.1757 Warm standby Argo

A standby control plane can reduce RTO.

But it introduces synchronization and fencing questions:

```text
Which instance owns target credentials?

Are both reading the same Git?

How is active status declared?

How is split-brain prevented?

How are secrets replicated?
```

Warm standby is not safe simply because Pods are running.

---

# 14.1758 Upgrade strategy

Before upgrading:

```text
read every intermediate upgrade note

check Kubernetes compatibility

check CRD changes

check removed flags/defaults

back up configuration

test in non-production

record rollback boundary
```

Argo's upgrade guide recommends upgrading one minor version at a time and consulting version-specific notes. ([Argo CD][5])

---

# 14.1759 Self-managed Argo upgrade

If Argo manages its own manifests:

```text
Argo changes the controller
that is performing the change.
```

Use:

```text
reviewed pinned chart/manifests

server-side apply settings where required

careful ignore differences

HA capacity

external break-glass access
```

and test recovery when reconciliation is interrupted mid-upgrade.

---

# 14.1760 Security boundary

Argo can often:

```text
read trusted Git

render executable configuration tools

write Kubernetes resources

store cluster/repository connection data

expose a production API/UI
```

Treat it like a privileged platform service.

---

# 14.1761 Authentication hardening

```text
integrate SSO/OIDC

require MFA at IdP

disable local admin after bootstrap where supported by policy

avoid shared accounts

shorten automation-token lifetime

revoke unused tokens

maintain tested break-glass access
```

Break glass must be monitored and rotated, not merely documented.

---

# 14.1762 Authorization hardening

Use:

```text
default read-only or minimal role

group-based RBAC

AppProject boundaries

least-privilege sync permissions

restricted override/action permissions

restricted Application creation
```

An Application that can target the Argo namespace can become administrative. Protect it accordingly.

---

# 14.1763 TLS hardening

Protect:

```text
client → argocd-server

server → repo-server

controller → repo-server

Argo → Git

Argo → target clusters

Argo → Redis where configured
```

The security guide notes Argo component communication is TLS-protected, while Redis transport requires deliberate TLS configuration in applicable setups. ([Argo CD][6])

Use trusted certificates and a defined rotation process. ([Argo CD][7])

---

# 14.1764 Network hardening

```text
private management nodes

restricted Ingress

WAF/reverse proxy where appropriate

NetworkPolicies

restricted egress to approved Git/cluster endpoints

private EKS endpoints

no public Redis/repo-server exposure
```

Be careful: overly strict egress can break Git, Helm, OCI, OIDC, STS, or target APIs.

---

# 14.1765 Repo-server threat model

repo-server renders content from trusted repositories.

Helm, Kustomize, and plugins process repository-controlled input.

Argo warns that malicious trusted-repository content may try to access files through tool behavior, remote bases, dependencies, or plugins. Disable unused config-management tools and treat plugins with extreme care. ([Argo CD][6])

Repository write access is production authority.

---

# 14.1766 Config-management plugins

Plugins may introduce:

```text
custom binaries

network access

decryption material

shell execution

additional filesystem exposure
```

Hardening:

```text
dedicated sidecar

non-root

read-only filesystem

no shared secret mounts unless essential

resource limits

signed/scanned image

minimal network policy
```

Prefer native rendering where it meets the requirement.

---

# 14.1767 Supply-chain hardening

```text
pin Argo image by trusted version/digest

verify release artifacts

scan images

review chart changes

pin Helm chart versions

pin Kustomize remote references

restrict source repositories

protect branches/CODEOWNERS

validate manifests before merge
```

Do not use `stable` or `latest` as a production control-plane version.

---

# 14.1768 Pod security

For each component review:

```text
runAsNonRoot

readOnlyRootFilesystem

allowPrivilegeEscalation=false

drop capabilities

seccompProfile

ServiceAccount token need

resource limits

ephemeral storage
```

Do not paste one identical securityContext if a component needs a writable temporary directory; mount the required writable path explicitly.

---

# 14.1769 Secret hardening

Protect:

```text
argocd-secret

repository credentials

cluster credentials

OIDC client secret

webhook shared secret

notification tokens
```

Use Kubernetes encryption at rest, restricted RBAC, external secret delivery, rotation, audit, and backup protection.

EKS IAM authentication avoids a long-lived external-cluster bearer token but still requires IAM trust control. ([Argo CD][6])

---

# 14.1770 Audit hardening

Git history records desired-state changes.

Argo/Kubernetes records operational actions such as:

```text
who initiated manual sync

who changed an Application

who used a resource action

what operation succeeded or failed
```

Persist:

```text
Argo logs

Kubernetes audit logs

Kubernetes Events

Git audit logs

AWS CloudTrail

Ingress/proxy access logs
```

for the required retention period.

---

# 14.1771 Failure scenario — repo-server OOMKilled

Check:

```bash
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-repo-server

kubectl top pod -n argocd

kubectl logs -n argocd deploy/argocd-repo-server --previous
```

Then inspect:

```text
which Application rendered

manifest size

parallelism

plugin behavior

remote dependencies

memory limit
```

Do not only double memory forever.

---

# 14.1772 Failure scenario — reconciliation backlog

Symptoms:

```text
Git commit merged long ago

Applications update slowly

controller CPU high

repo-server requests queued
```

Check:

```text
reconcile histogram

render duration

processor utilization

Git latency

Redis latency

target API throttling

monorepo invalidation
```

Scale the constrained stage, not the component with the most visible symptom.

---

# 14.1773 Failure scenario — controller shard imbalance

One replica may consume far more memory because cluster sizes differ.

Check cluster distribution and per-replica metrics.

Consider:

```text
round-robin

consistent hashing with bounded loads

manual shard assignment for exceptional clusters

dynamic distribution
```

after validating behavior on the installed version.

---

# 14.1774 Failure scenario — Redis loss

Expected mental model:

```text
cache loss
→ temporary slowdown and repopulation
```

not:

```text
all Applications permanently lost.
```

If Applications are missing, inspect Kubernetes API/namespace state, not only Redis.

---

# 14.1775 Failure scenario — backup imports nothing

Common causes:

```text
export taken from wrong namespace

empty/incomplete artifact

version incompatibility

CRDs not installed before import

permissions insufficient

external secrets not restored
```

This is exactly why restore drills must inspect object counts and critical names.

---

# 14.1776 Failure scenario — two Argo instances fight

Symptoms:

```text
repeated updates

operation churn

unexpected controller identity in events

rapid flip between values
```

Containment:

```text
identify both controllers

fence one by credential or network

pause reconciliation deliberately

establish authoritative desired state

inspect damage before resuming
```

---

# 14.1777 HA validation game day

In a disposable or approved test environment:

```text
□ delete one argocd-server Pod

□ delete one repo-server Pod

□ restart an application-controller shard

□ drain a node hosting Argo Pods

□ simulate Git unavailability

□ block one target cluster endpoint

□ fail Redis leader/quorum according to supported procedure

□ restore from export into fresh cluster

□ validate fencing during DR failover
```

Measure recovery, not just survival.

---

# 14.1778 Production HA/DR checklist

```text
□ RTO and RPO approved

□ HA topology spans nodes and AZs

□ PDBs allow safe maintenance

□ resource requests reflect measured load

□ repo-server disk is sized and monitored

□ controller processor counts are justified

□ cluster sharding is observed

□ reconcile jitter prevents spikes

□ target API rate limits are monitored

□ Redis is treated as disposable cache

□ Git holds reconstructable configuration

□ sensitive configuration is externally recoverable

□ admin export is encrypted and retained

□ export contents are verified

□ restore drill is scheduled

□ exact Argo version is recorded

□ upgrade notes are reviewed per minor version

□ DR fencing prevents split brain

□ SSO and break-glass access are tested

□ repo-server/plugin threat model is reviewed

□ TLS and credential rotation are tested

□ audit logs are retained externally
```

---

# 14.1779 Interview — is Argo CD stateless?

> **Argo CD is largely stateless at the application-service layer. Durable Argo configuration and CR state are Kubernetes objects stored through the cluster's etcd. Redis is a disposable cache. That does not mean no backup is needed: Kubernetes objects, credentials, signing material, and external dependencies still require a tested recovery plan.** ([Argo CD][1])

---

# 14.1780 Interview — HA vs DR

> **HA keeps the service operating through expected component or node failures using replicas, topology, quorum, and failover. DR reconstructs service after a larger loss using Git, protected secrets, exports/backups, infrastructure automation, and runbooks. HA reduces interruption; DR recovers after the HA boundary is exceeded.**

---

# 14.1781 Interview — how do you scale Argo CD?

> **I measure the bottleneck. I scale repo-server for rendering, control its parallelism and temporary disk, tune application-controller status/operation processors, shard clusters across controller replicas, spread reconciliation with jitter, and protect target APIs from excessive concurrency. I validate monorepo cache behavior rather than increasing every replica count blindly.**

---

# 14.1782 Interview — what do you back up?

> **I keep the declarative bootstrap and application definitions in Git, secret values and credentials in a recoverable external secret system, and take protected Argo admin exports or cluster-level backups for Kubernetes-resident state. I also preserve IAM, EKS access, DNS, certificate, and network IaC. The proof is a restore into a clean environment.**

---

# 14.1783 Interview — why not restore Redis?

> **Redis is a rebuildable cache rather than Argo's durable source of truth. I restore the Kubernetes-resident configuration and dependencies, bring Redis back healthy, and allow caches to repopulate.**

---

# 14.1784 Never-forget Lesson 15 rules

```text
1. HA, backup, and DR are different.

2. Define RTO and RPO first.

3. Argo outage does not normally stop existing Pods.

4. It does stop or delay reconciliation.

5. Durable Argo state lives in Kubernetes objects.

6. Redis is disposable cache.

7. Replicas must span failure domains.

8. Server, controller, and repo-server scale differently.

9. Measure before tuning processors.

10. More concurrency pressures target APIs.

11. Controller shards distribute clusters.

12. Repo-server needs CPU, memory, disk, and network.

13. Bound manifest-generation parallelism.

14. Monorepos can amplify every commit.

15. Jitter prevents synchronized refresh spikes.

16. Namespace restrictions add watch connections.

17. Git reconstructs declarations, not plaintext secrets.

18. Admin exports are sensitive backups.

19. Wrong-namespace export may look successful.

20. Restore testing proves backup value.

21. Record the compatible Argo version.

22. Upgrade one supported step at a time.

23. Self-management needs break-glass recovery.

24. Fence the old controller during DR.

25. Two active controllers can create split brain.

26. SSO needs a tested break-glass path.

27. Repo-server processes trusted code-like input.

28. Disable unused rendering tools/plugins.

29. Protect cluster and repository credentials.

30. A game day converts a diagram into evidence.
```

---

# 14.1785 Lesson 15 troubleshooting mnemonic

Memorize:

# **A-C-R-G-K-D**

```text
AVAILABILITY
    ↓
COMPONENT
    ↓
RESOURCE
    ↓
GIT / GENERATION
    ↓
KUBERNETES TARGET
    ↓
DATA / RECOVERY
```

First decide whether the problem is serving, rendering, reconciling, targeting, or recovering.

---

# ✅ Module 14 — Lesson 15 Complete

You now understand:

```text
✓ Argo CD HA objectives

✓ durable state vs Redis cache

✓ component failure boundaries

✓ server and repo-server scaling

✓ controller processors and sharding

✓ monorepo scaling

✓ reconciliation jitter

✓ topology and PDBs

✓ layered backup strategy

✓ argocd admin export/import

✓ RPO and RTO

✓ cold and warm recovery

✓ split-brain fencing

✓ safe upgrades

✓ authentication and RBAC hardening

✓ TLS and network hardening

✓ repo-server/plugin threat model

✓ audit and game-day validation
```

# Next — Module 14, Lesson 16

## Observability, Metrics, Notifications & Systematic Troubleshooting

High availability without visibility is hope.

Next we will build:

```text
Argo metrics
    ↓
Prometheus
    ↓
Grafana + alert rules
    ↓
Notifications
    ↓
runbook-driven diagnosis
```

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.15.1786 Professional Mastery Workbook

This workbook expands **High Availability, Backup, Disaster Recovery, Scaling & Security Hardening** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 61 lesson-specific anchors.
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

### Concept card 1 - First define the service objective

- Lesson anchor: Ask: How long may deployment reconciliation stop? How much Argo configuration may be lost? Must the UI remain available during upgrades? How quickly must a new management cluster take over? Write: RTO = recovery time objective
- Beginner explanation: Restate **First define the service objective** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First define the service objective** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **First define the service objective**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **First define the service objective**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First define the service objective** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Runtime availability is different

- Lesson anchor: If Argo CD is down: existing Deployments Services Pods Ingresses normally continue to run. But: new Git changes do not reconcile drift may not self-heal Application visibility is lost GitOps-managed recovery is delayed Argo availability protects change and...
- Beginner explanation: Restate **Runtime availability is different** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Runtime availability is different** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Runtime availability is different**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Runtime availability is different**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Runtime availability is different** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Durable Argo state

- Lesson anchor: Important Kubernetes objects include: Applications ApplicationSets AppProjects cluster Secrets repository Secrets argocd-cm argocd-rbac-cm argocd-secret TLS/known-host ConfigMaps notification configuration and secrets Some should be reconstructed from Git/e...
- Beginner explanation: Restate **Durable Argo state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Durable Argo state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Durable Argo state**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Durable Argo state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Durable Argo state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Redis is not the source of truth

- Lesson anchor: Redis caches data such as: generated manifests application tree/cache information temporary operational state Do not build DR around restoring Redis data. Argo documentation states Redis is disposable and can be rebuilt. ([Argo CD][1])
- Beginner explanation: Restate **Redis is not the source of truth** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Redis is not the source of truth** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Redis is not the source of truth**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Redis is not the source of truth**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Redis is not the source of truth** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Component failure map

- Lesson anchor: argocd-server failure → UI/API/CLI access affected application-controller failure → comparison and sync affected repo-server failure → Git fetch/render affected ApplicationSet controller failure → generated Application reconciliation affected
- Beginner explanation: Restate **Component failure map** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Component failure map** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Component failure map**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Component failure map**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Component failure map** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - HA is component-specific

- Lesson anchor: Adding three replicas to every Deployment is not an HA strategy. Each component has different behavior: stateless request serving leader election cluster sharding cache quorum in-memory identity state Use upstream HA manifests or the supported Helm chart se...
- Beginner explanation: Restate **HA is component-specific** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **HA is component-specific** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **HA is component-specific**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **HA is component-specific**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **HA is component-specific** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - argocd-server

- Lesson anchor: The API server is stateless and can be horizontally replicated behind a Service/Ingress. Argo's scaling guidance recommends multiple replicas—three or more for upgrade continuity—and aligning ARGOCDAPISERVERREPLICAS with the replica count because it partici...
- Beginner explanation: Restate **argocd-server** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **argocd-server** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **argocd-server**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **argocd-server**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **argocd-server** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - application-controller

- Lesson anchor: This component: loads desired manifests through repo-server watches target cluster state computes sync/health executes operations It is usually the major fleet-scaling component. Scale it based on: Application count managed resource count
- Beginner explanation: Restate **application-controller** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **application-controller** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **application-controller**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **application-controller**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **application-controller** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Controller processors

- Lesson anchor: Important controls include: --status-processors --operation-processors Status processors handle reconciliation work. Operation processors handle sync operations. Do not raise them blindly. Higher concurrency increases pressure on:
- Beginner explanation: Restate **Controller processors** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Controller processors** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Controller processors**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Controller processors**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Controller processors** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Controller sharding

- Lesson anchor: For many clusters, application-controller replicas can shard cluster ownership. controller-0 ├── clusters A, D controller-1 ├── clusters B, E controller-2 └── clusters C, F The replica count and ARGOCDCONTROLLERREPLICAS must agree in the documented static s...
- Beginner explanation: Restate **Controller sharding** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Controller sharding** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Controller sharding**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Controller sharding**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Controller sharding** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Dynamic cluster distribution

- Lesson anchor: Static sharding ties the expected controller replica count to configuration. Dynamic distribution can rebalance cluster assignments as controller replicas change, depending on the current Argo version and configuration. Use it only after understanding:
- Beginner explanation: Restate **Dynamic cluster distribution** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Dynamic cluster distribution** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Dynamic cluster distribution**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Dynamic cluster distribution**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Dynamic cluster distribution** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - repo-server

- Lesson anchor: repo-server performs: Git clone/fetch Helm rendering Kustomize build config-management plugins manifest caching It is often CPU-, memory-, disk-, or network-bound. Scale replicas for throughput, but first identify whether the bottleneck is:
- Beginner explanation: Restate **repo-server** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **repo-server** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **repo-server**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **repo-server**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **repo-server** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - repo-server parallelism

- Lesson anchor: The --parallelismlimit setting bounds concurrent manifest generation per repo-server. Too high: OOMKilled thread/process exhaustion CPU contention Too low: render queue grows reconciliation slows Tune from observed render duration, queue pressure, and memor...
- Beginner explanation: Restate **repo-server parallelism** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **repo-server parallelism** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **repo-server parallelism**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **repo-server parallelism**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **repo-server parallelism** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - repo-server temporary disk

- Lesson anchor: Repositories are cloned under /tmp by default. Large repositories and many sources can cause: ephemeral-storage eviction disk full slow clone/render Set: resource requests/limits for ephemeral-storage appropriate volume strategy
- Beginner explanation: Restate **repo-server temporary disk** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **repo-server temporary disk** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **repo-server temporary disk**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **repo-server temporary disk**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **repo-server temporary disk** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Manifest-generation timeouts

- Lesson anchor: Key timeout categories include: repo-server tool execution timeout controller to repo-server timeout Git request retry behavior Raising a timeout may hide: pathological Helm chart network failure plugin hang repository explosion
- Beginner explanation: Restate **Manifest-generation timeouts** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Manifest-generation timeouts** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Manifest-generation timeouts**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Manifest-generation timeouts**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Manifest-generation timeouts** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Monorepo invalidation

- Lesson anchor: In a large monorepo: one commit ↓ many Applications see new repository revision ↓ many manifests may regenerate Possible controls: manifest-generate-paths annotation fully qualified Git refs webhook path filtering repository decomposition
- Beginner explanation: Restate **Monorepo invalidation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Monorepo invalidation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Monorepo invalidation**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Monorepo invalidation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Monorepo invalidation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Reconciliation jitter

- Lesson anchor: If thousands of Applications refresh on the same fixed interval: thundering herd │ ▼ repo-server and controller spike Configure reconciliation jitter so work spreads over time. Webhooks improve responsiveness but do not remove the need for periodic reconcil...
- Beginner explanation: Restate **Reconciliation jitter** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reconciliation jitter** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Reconciliation jitter**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Reconciliation jitter**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Reconciliation jitter** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Target API protection

- Lesson anchor: Argo maintains watches and makes Kubernetes requests across managed clusters. Protect targets by monitoring: request rate 429 responses latency watch reconnects cache age Aggressive Argo concurrency can become a control-plane load incident.
- Beginner explanation: Restate **Target API protection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Target API protection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Target API protection**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Target API protection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Target API protection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Namespace restriction cost

- Lesson anchor: A cluster registration may list accessible namespaces. Argo warns that each namespace can produce separate list/watch activity and may exhaust idle connections unless client settings are tuned. ([Argo CD][3]) Namespace restriction is useful, but hundreds of...
- Beginner explanation: Restate **Namespace restriction cost** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Namespace restriction cost** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Namespace restriction cost**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Namespace restriction cost**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Namespace restriction cost** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Redis HA

- Lesson anchor: The upstream HA topology runs Redis in HA mode. But remember: Redis HA = reduce cache/control interruption Redis backup ≠ required source-of-truth backup Place Redis Pods across failure domains and monitor quorum, memory, latency, and failover.
- Beginner explanation: Restate **Redis HA** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Redis HA** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Redis HA**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Redis HA**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Redis HA** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Pod topology

- Lesson anchor: Production Argo components need: pod anti-affinity or topology spread multiple Availability Zones PodDisruptionBudgets resource requests priority classes where justified node capacity during upgrades Three replicas on one node are not high availability.
- Beginner explanation: Restate **Pod topology** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Pod topology** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Pod topology**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Pod topology**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Pod topology** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - PodDisruptionBudget trap

- Lesson anchor: A PDB that is too strict can block: node upgrades voluntary maintenance cluster autoscaling A PDB that is too weak allows too many simultaneous evictions. Test: node drain AZ loss simulation rolling upgrade not only steady state.
- Beginner explanation: Restate **PodDisruptionBudget trap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PodDisruptionBudget trap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **PodDisruptionBudget trap**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **PodDisruptionBudget trap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PodDisruptionBudget trap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Backup layers

- Lesson anchor: Use several recoverability layers: Layer 1 — Git declarative bootstrap and Applications Layer 2 — external secret manager repository/cluster/SSO secrets Layer 3 — argocd admin export Argo Kubernetes-object state Layer 4 — Kubernetes/etcd or namespace backup
- Beginner explanation: Restate **Backup layers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backup layers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Backup layers**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Backup layers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backup layers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - What Git can reconstruct

- Lesson anchor: If fully declarative, Git can recreate: Argo installation values AppProjects Applications/ApplicationSets RBAC ConfigMap notification templates/triggers resource customizations But Git should not contain plaintext: cluster credentials
- Beginner explanation: Restate **What Git can reconstruct** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What Git can reconstruct** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **What Git can reconstruct**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **What Git can reconstruct**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What Git can reconstruct** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - What external systems must reconstruct

- Lesson anchor: Recovery also depends on: Git host container registries DNS and certificates identity provider AWS IAM roles EKS access entries Secrets Manager/Vault network connectivity An Argo backup cannot restore an unavailable Git provider or revoked IAM trust.
- Beginner explanation: Restate **What external systems must reconstruct** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What external systems must reconstruct** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **What external systems must reconstruct**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **What external systems must reconstruct**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What external systems must reconstruct** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - argocd admin export

- Lesson anchor: Argo provides: argocd admin export -n argocd  backup.yaml and: argocd admin import -n argocd - < backup.yaml The exact invocation can be run with a version-matched Argo image or CLI. The official DR guide emphasizes using the correct namespace; an export ma...
- Beginner explanation: Restate **argocd admin export** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **argocd admin export** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **argocd admin export**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **argocd admin export**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **argocd admin export** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Protect the export

- Lesson anchor: The export may contain sensitive Kubernetes objects. Treat it as: production secret-bearing backup Require: encryption at rest restricted storage access immutable/retained versions audit logs secure deletion policy restore access separation
- Beginner explanation: Restate **Protect the export** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Protect the export** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Protect the export**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Protect the export**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Protect the export** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Backup verification

- Lesson anchor: A successful command exit proves only: an export command completed. It does not prove: backup contains expected objects encryption key is recoverable storage is readable in disaster import works dependencies exist Restore testing is the evidence.
- Beginner explanation: Restate **Backup verification** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backup verification** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Backup verification**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Backup verification**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backup verification** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - RPO design

- Lesson anchor: If exports run daily: RPO may approach 24 hours unless Git and external systems reconstruct all intervening changes. Decide separately for: declarative config credentials signing keys local accounts operation history The most sensitive item may need the str...
- Beginner explanation: Restate **RPO design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RPO design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **RPO design**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **RPO design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RPO design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - RTO design

- Lesson anchor: Recovery time includes: provision management cluster install Argo version restore or regenerate secrets restore configuration reconnect Git reconnect target clusters warm caches verify Applications resume safe reconciliation
- Beginner explanation: Restate **RTO design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RTO design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **RTO design**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **RTO design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RTO design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Cold recovery sequence

- Lesson anchor: ---
- Beginner explanation: Restate **Cold recovery sequence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cold recovery sequence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Cold recovery sequence**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Cold recovery sequence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Cold recovery sequence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - The double-controller risk

- Lesson anchor: During DR, never allow two independent Argo installations to reconcile the same Applications unknowingly. old primary recovers + new DR Argo active ↓ two control planes mutate targets Use fencing: revoke credentials disable cluster reconciliation
- Beginner explanation: Restate **The double-controller risk** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The double-controller risk** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **The double-controller risk**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **The double-controller risk**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The double-controller risk** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Warm standby Argo

- Lesson anchor: A standby control plane can reduce RTO. But it introduces synchronization and fencing questions: Which instance owns target credentials? Are both reading the same Git? How is active status declared? How is split-brain prevented?
- Beginner explanation: Restate **Warm standby Argo** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Warm standby Argo** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Warm standby Argo**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Warm standby Argo**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Warm standby Argo** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Upgrade strategy

- Lesson anchor: Before upgrading: read every intermediate upgrade note check Kubernetes compatibility check CRD changes check removed flags/defaults back up configuration test in non-production record rollback boundary Argo's upgrade guide recommends upgrading one minor ve...
- Beginner explanation: Restate **Upgrade strategy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Upgrade strategy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Upgrade strategy**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Upgrade strategy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Upgrade strategy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Self-managed Argo upgrade

- Lesson anchor: If Argo manages its own manifests: Argo changes the controller that is performing the change. Use: reviewed pinned chart/manifests server-side apply settings where required careful ignore differences HA capacity external break-glass access
- Beginner explanation: Restate **Self-managed Argo upgrade** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Self-managed Argo upgrade** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Self-managed Argo upgrade**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Self-managed Argo upgrade**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Self-managed Argo upgrade** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Security boundary

- Lesson anchor: Argo can often: read trusted Git render executable configuration tools write Kubernetes resources store cluster/repository connection data expose a production API/UI Treat it like a privileged platform service. ---
- Beginner explanation: Restate **Security boundary** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Security boundary** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Security boundary**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Security boundary**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Security boundary** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - Authentication hardening

- Lesson anchor: integrate SSO/OIDC require MFA at IdP disable local admin after bootstrap where supported by policy avoid shared accounts shorten automation-token lifetime revoke unused tokens maintain tested break-glass access Break glass must be monitored and rotated, no...
- Beginner explanation: Restate **Authentication hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Authentication hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Authentication hardening**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Authentication hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Authentication hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Authorization hardening

- Lesson anchor: Use: default read-only or minimal role group-based RBAC AppProject boundaries least-privilege sync permissions restricted override/action permissions restricted Application creation An Application that can target the Argo namespace can become administrative...
- Beginner explanation: Restate **Authorization hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Authorization hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Authorization hardening**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Authorization hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Authorization hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - TLS hardening

- Lesson anchor: Protect: client → argocd-server server → repo-server controller → repo-server Argo → Git Argo → target clusters Argo → Redis where configured The security guide notes Argo component communication is TLS-protected, while Redis transport requires deliberate T...
- Beginner explanation: Restate **TLS hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **TLS hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **TLS hardening**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **TLS hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **TLS hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Network hardening

- Lesson anchor: private management nodes restricted Ingress WAF/reverse proxy where appropriate NetworkPolicies restricted egress to approved Git/cluster endpoints private EKS endpoints no public Redis/repo-server exposure Be careful: overly strict egress can break Git, He...
- Beginner explanation: Restate **Network hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Network hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Network hardening**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Network hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Network hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Repo-server threat model

- Lesson anchor: repo-server renders content from trusted repositories. Helm, Kustomize, and plugins process repository-controlled input. Argo warns that malicious trusted-repository content may try to access files through tool behavior, remote bases, dependencies, or plugi...
- Beginner explanation: Restate **Repo-server threat model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Repo-server threat model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Repo-server threat model**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Repo-server threat model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Repo-server threat model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Config-management plugins

- Lesson anchor: Plugins may introduce: custom binaries network access decryption material shell execution additional filesystem exposure Hardening: dedicated sidecar non-root read-only filesystem no shared secret mounts unless essential
- Beginner explanation: Restate **Config-management plugins** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Config-management plugins** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Config-management plugins**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Config-management plugins**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Config-management plugins** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Supply-chain hardening

- Lesson anchor: pin Argo image by trusted version/digest verify release artifacts scan images review chart changes pin Helm chart versions pin Kustomize remote references restrict source repositories protect branches/CODEOWNERS validate manifests before merge
- Beginner explanation: Restate **Supply-chain hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Supply-chain hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Supply-chain hardening**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Supply-chain hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Supply-chain hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - Pod security

- Lesson anchor: For each component review: runAsNonRoot readOnlyRootFilesystem allowPrivilegeEscalation=false drop capabilities seccompProfile ServiceAccount token need resource limits ephemeral storage Do not paste one identical securityContext if a component needs a writ...
- Beginner explanation: Restate **Pod security** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Pod security** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Pod security**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Pod security**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Pod security** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Secret hardening

- Lesson anchor: Protect: argocd-secret repository credentials cluster credentials OIDC client secret webhook shared secret notification tokens Use Kubernetes encryption at rest, restricted RBAC, external secret delivery, rotation, audit, and backup protection.
- Beginner explanation: Restate **Secret hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Secret hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Secret hardening**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Secret hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Secret hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Audit hardening

- Lesson anchor: Git history records desired-state changes. Argo/Kubernetes records operational actions such as: who initiated manual sync who changed an Application who used a resource action what operation succeeded or failed Persist: Argo logs
- Beginner explanation: Restate **Audit hardening** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Audit hardening** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Audit hardening**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Audit hardening**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Audit hardening** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Failure scenario — repo-server OOMKilled

- Lesson anchor: Check: kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-repo-server kubectl top pod -n argocd kubectl logs -n argocd deploy/argocd-repo-server --previous Then inspect: which Application rendered manifest size
- Beginner explanation: Restate **Failure scenario — repo-server OOMKilled** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — repo-server OOMKilled** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Failure scenario — repo-server OOMKilled**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Failure scenario — repo-server OOMKilled**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — repo-server OOMKilled** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Failure scenario — reconciliation backlog

- Lesson anchor: Symptoms: Git commit merged long ago Applications update slowly controller CPU high repo-server requests queued Check: reconcile histogram render duration processor utilization Git latency Redis latency target API throttling
- Beginner explanation: Restate **Failure scenario — reconciliation backlog** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — reconciliation backlog** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Failure scenario — reconciliation backlog**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Failure scenario — reconciliation backlog**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — reconciliation backlog** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Failure scenario — controller shard imbalance

- Lesson anchor: One replica may consume far more memory because cluster sizes differ. Check cluster distribution and per-replica metrics. Consider: round-robin consistent hashing with bounded loads manual shard assignment for exceptional clusters
- Beginner explanation: Restate **Failure scenario — controller shard imbalance** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — controller shard imbalance** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Failure scenario — controller shard imbalance**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Failure scenario — controller shard imbalance**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — controller shard imbalance** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Failure scenario — Redis loss

- Lesson anchor: Expected mental model: cache loss → temporary slowdown and repopulation not: all Applications permanently lost. If Applications are missing, inspect Kubernetes API/namespace state, not only Redis. ---
- Beginner explanation: Restate **Failure scenario — Redis loss** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — Redis loss** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Failure scenario — Redis loss**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Failure scenario — Redis loss**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — Redis loss** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Failure scenario — backup imports nothing

- Lesson anchor: Common causes: export taken from wrong namespace empty/incomplete artifact version incompatibility CRDs not installed before import permissions insufficient external secrets not restored This is exactly why restore drills must inspect object counts and crit...
- Beginner explanation: Restate **Failure scenario — backup imports nothing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — backup imports nothing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Failure scenario — backup imports nothing**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Failure scenario — backup imports nothing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — backup imports nothing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Failure scenario — two Argo instances fight

- Lesson anchor: Symptoms: repeated updates operation churn unexpected controller identity in events rapid flip between values Containment: identify both controllers fence one by credential or network pause reconciliation deliberately establish authoritative desired state
- Beginner explanation: Restate **Failure scenario — two Argo instances fight** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — two Argo instances fight** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Failure scenario — two Argo instances fight**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Failure scenario — two Argo instances fight**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — two Argo instances fight** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - HA validation game day

- Lesson anchor: In a disposable or approved test environment: □ delete one argocd-server Pod □ delete one repo-server Pod □ restart an application-controller shard □ drain a node hosting Argo Pods □ simulate Git unavailability □ block one target cluster endpoint
- Beginner explanation: Restate **HA validation game day** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **HA validation game day** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **HA validation game day**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **HA validation game day**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **HA validation game day** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Production HA/DR checklist

- Lesson anchor: □ RTO and RPO approved □ HA topology spans nodes and AZs □ PDBs allow safe maintenance □ resource requests reflect measured load □ repo-server disk is sized and monitored □ controller processor counts are justified □ cluster sharding is observed
- Beginner explanation: Restate **Production HA/DR checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production HA/DR checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production HA/DR checklist**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production HA/DR checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production HA/DR checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Interview — is Argo CD stateless?

- Lesson anchor: Argo CD is largely stateless at the application-service layer. Durable Argo configuration and CR state are Kubernetes objects stored through the cluster's etcd. Redis is a disposable cache. That does not mean no backup is needed: Kubernetes objects, credent...
- Beginner explanation: Restate **Interview — is Argo CD stateless?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — is Argo CD stateless?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — is Argo CD stateless?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — is Argo CD stateless?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — is Argo CD stateless?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Interview — HA vs DR

- Lesson anchor: HA keeps the service operating through expected component or node failures using replicas, topology, quorum, and failover. DR reconstructs service after a larger loss using Git, protected secrets, exports/backups, infrastructure automation, and runbooks. HA...
- Beginner explanation: Restate **Interview — HA vs DR** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — HA vs DR** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — HA vs DR**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — HA vs DR**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — HA vs DR** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Interview — how do you scale Argo CD?

- Lesson anchor: I measure the bottleneck. I scale repo-server for rendering, control its parallelism and temporary disk, tune application-controller status/operation processors, shard clusters across controller replicas, spread reconciliation with jitter, and protect targe...
- Beginner explanation: Restate **Interview — how do you scale Argo CD?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — how do you scale Argo CD?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — how do you scale Argo CD?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — how do you scale Argo CD?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — how do you scale Argo CD?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Interview — what do you back up?

- Lesson anchor: I keep the declarative bootstrap and application definitions in Git, secret values and credentials in a recoverable external secret system, and take protected Argo admin exports or cluster-level backups for Kubernetes-resident state. I also preserve IAM, EK...
- Beginner explanation: Restate **Interview — what do you back up?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — what do you back up?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — what do you back up?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — what do you back up?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — what do you back up?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - Interview — why not restore Redis?

- Lesson anchor: Redis is a rebuildable cache rather than Argo's durable source of truth. I restore the Kubernetes-resident configuration and dependencies, bring Redis back healthy, and allow caches to repopulate. ---
- Beginner explanation: Restate **Interview — why not restore Redis?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — why not restore Redis?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — why not restore Redis?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — why not restore Redis?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — why not restore Redis?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Never-forget Lesson 15 rules

- Lesson anchor: ---
- Beginner explanation: Restate **Never-forget Lesson 15 rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget Lesson 15 rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Never-forget Lesson 15 rules**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Never-forget Lesson 15 rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget Lesson 15 rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - Lesson 15 troubleshooting mnemonic

- Lesson anchor: Memorize: AVAILABILITY ↓ COMPONENT ↓ RESOURCE ↓ GIT / GENERATION ↓ KUBERNETES TARGET ↓ DATA / RECOVERY First decide whether the problem is serving, rendering, reconciling, targeting, or recovering. --- You now understand:
- Beginner explanation: Restate **Lesson 15 troubleshooting mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lesson 15 troubleshooting mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Lesson 15 troubleshooting mnemonic**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Lesson 15 troubleshooting mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lesson 15 troubleshooting mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - First define the service objective x dependency failure

- Learning level: Beginner.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **First define the service objective** while a change involving **Redis is not the source of truth** places **dependency failure** at risk.
- Plain-language question: What problem does **First define the service objective** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask: How long may deployment reconciliation stop? How much Argo configuration may be lost? Must the UI remain available during upgrades? How quickly must a new management cluster take over? Write: RTO = recovery time objective
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **First define the service objective** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Runtime availability is different x developer experience

- Learning level: Intermediate.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Runtime availability is different** while a change involving **Dynamic cluster distribution** places **developer experience** at risk.
- Plain-language question: What problem does **Runtime availability is different** solve here, and who notices first when it fails?
- Lesson evidence anchor: If Argo CD is down: existing Deployments Services Pods Ingresses normally continue to run. But: new Git changes do not reconcile drift may not self-heal Application visibility is lost GitOps-managed recovery is delayed Argo availability protects change and...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Runtime availability is different** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Durable Argo state x availability

- Learning level: Expert.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Durable Argo state** while a change involving **Target API protection** places **availability** at risk.
- Plain-language question: What problem does **Durable Argo state** solve here, and who notices first when it fails?
- Lesson evidence anchor: Important Kubernetes objects include: Applications ApplicationSets AppProjects cluster Secrets repository Secrets argocd-cm argocd-rbac-cm argocd-secret TLS/known-host ConfigMaps notification configuration and secrets Some should be reconstructed from Git/e...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Durable Argo state** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Redis is not the source of truth x security

- Learning level: Professional.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Redis is not the source of truth** while a change involving **What external systems must reconstruct** places **security** at risk.
- Plain-language question: What problem does **Redis is not the source of truth** solve here, and who notices first when it fails?
- Lesson evidence anchor: Redis caches data such as: generated manifests application tree/cache information temporary operational state Do not build DR around restoring Redis data. Argo documentation states Redis is disposable and can be rebuilt. ([Argo CD][1])
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Redis is not the source of truth** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Component failure map x delivery safety

- Learning level: Industry-ready.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Component failure map** while a change involving **The double-controller risk** places **delivery safety** at risk.
- Plain-language question: What problem does **Component failure map** solve here, and who notices first when it fails?
- Lesson evidence anchor: argocd-server failure → UI/API/CLI access affected application-controller failure → comparison and sync affected repo-server failure → Git fetch/render affected ApplicationSet controller failure → generated Application reconciliation affected
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Component failure map** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - HA is component-specific x multi-tenancy

- Learning level: Certification review.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **HA is component-specific** while a change involving **TLS hardening** places **multi-tenancy** at risk.
- Plain-language question: What problem does **HA is component-specific** solve here, and who notices first when it fails?
- Lesson evidence anchor: Adding three replicas to every Deployment is not an HA strategy. Each component has different behavior: stateless request serving leader election cluster sharding cache quorum in-memory identity state Use upstream HA manifests or the supported Helm chart se...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **HA is component-specific** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - argocd-server x observability

- Learning level: Interview defense.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **argocd-server** while a change involving **Audit hardening** places **observability** at risk.
- Plain-language question: What problem does **argocd-server** solve here, and who notices first when it fails?
- Lesson evidence anchor: The API server is stateless and can be horizontally replicated behind a Service/Ingress. Argo's scaling guidance recommends multiple replicas—three or more for upgrade continuity—and aligning ARGOCDAPISERVERREPLICAS with the replica count because it partici...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **argocd-server** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - application-controller x regional resilience

- Learning level: Beginner.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **application-controller** while a change involving **HA validation game day** places **regional resilience** at risk.
- Plain-language question: What problem does **application-controller** solve here, and who notices first when it fails?
- Lesson evidence anchor: This component: loads desired manifests through repo-server watches target cluster state computes sync/health executes operations It is usually the major fleet-scaling component. Scale it based on: Application count managed resource count
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **application-controller** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Controller processors x business value

- Learning level: Intermediate.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Controller processors** while a change involving **Never-forget Lesson 15 rules** places **business value** at risk.
- Plain-language question: What problem does **Controller processors** solve here, and who notices first when it fails?
- Lesson evidence anchor: Important controls include: --status-processors --operation-processors Status processors handle reconciliation work. Operation processors handle sync operations. Do not raise them blindly. Higher concurrency increases pressure on:
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Controller processors** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Controller sharding x latency

- Learning level: Expert.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Controller sharding** while a change involving **HA is component-specific** places **latency** at risk.
- Plain-language question: What problem does **Controller sharding** solve here, and who notices first when it fails?
- Lesson evidence anchor: For many clusters, application-controller replicas can shard cluster ownership. controller-0 ├── clusters A, D controller-1 ├── clusters B, E controller-2 └── clusters C, F The replica count and ARGOCDCONTROLLERREPLICAS must agree in the documented static s...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Controller sharding** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Dynamic cluster distribution x privacy

- Learning level: Professional.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Dynamic cluster distribution** while a change involving **repo-server parallelism** places **privacy** at risk.
- Plain-language question: What problem does **Dynamic cluster distribution** solve here, and who notices first when it fails?
- Lesson evidence anchor: Static sharding ties the expected controller replica count to configuration. Dynamic distribution can rebalance cluster assignments as controller replicas change, depending on the current Argo version and configuration. Use it only after understanding:
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Dynamic cluster distribution** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - repo-server x operability

- Learning level: Industry-ready.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **repo-server** while a change involving **Redis HA** places **operability** at risk.
- Plain-language question: What problem does **repo-server** solve here, and who notices first when it fails?
- Lesson evidence anchor: repo-server performs: Git clone/fetch Helm rendering Kustomize build config-management plugins manifest caching It is often CPU-, memory-, disk-, or network-bound. Scale replicas for throughput, but first identify whether the bottleneck is:
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **repo-server** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - repo-server parallelism x data integrity

- Learning level: Certification review.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **repo-server parallelism** while a change involving **Protect the export** places **data integrity** at risk.
- Plain-language question: What problem does **repo-server parallelism** solve here, and who notices first when it fails?
- Lesson evidence anchor: The --parallelismlimit setting bounds concurrent manifest generation per repo-server. Too high: OOMKilled thread/process exhaustion CPU contention Too low: render queue grows reconciliation slows Tune from observed render duration, queue pressure, and memor...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **repo-server parallelism** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - repo-server temporary disk x automation safety

- Learning level: Interview defense.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **repo-server temporary disk** while a change involving **Upgrade strategy** places **automation safety** at risk.
- Plain-language question: What problem does **repo-server temporary disk** solve here, and who notices first when it fails?
- Lesson evidence anchor: Repositories are cloned under /tmp by default. Large repositories and many sources can cause: ephemeral-storage eviction disk full slow clone/render Set: resource requests/limits for ephemeral-storage appropriate volume strategy
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **repo-server temporary disk** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Manifest-generation timeouts x governance

- Learning level: Beginner.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Manifest-generation timeouts** while a change involving **Repo-server threat model** places **governance** at risk.
- Plain-language question: What problem does **Manifest-generation timeouts** solve here, and who notices first when it fails?
- Lesson evidence anchor: Key timeout categories include: repo-server tool execution timeout controller to repo-server timeout Git request retry behavior Raising a timeout may hide: pathological Helm chart network failure plugin hang repository explosion
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Manifest-generation timeouts** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Monorepo invalidation x correctness

- Learning level: Intermediate.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Monorepo invalidation** while a change involving **Failure scenario — reconciliation backlog** places **correctness** at risk.
- Plain-language question: What problem does **Monorepo invalidation** solve here, and who notices first when it fails?
- Lesson evidence anchor: In a large monorepo: one commit ↓ many Applications see new repository revision ↓ many manifests may regenerate Possible controls: manifest-generate-paths annotation fully qualified Git refs webhook path filtering repository decomposition
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Monorepo invalidation** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Reconciliation jitter x capacity

- Learning level: Expert.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Reconciliation jitter** while a change involving **Interview — is Argo CD stateless?** places **capacity** at risk.
- Plain-language question: What problem does **Reconciliation jitter** solve here, and who notices first when it fails?
- Lesson evidence anchor: If thousands of Applications refresh on the same fixed interval: thundering herd │ ▼ repo-server and controller spike Configure reconciliation jitter so work spreads over time. Webhooks improve responsiveness but do not remove the need for periodic reconcil...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Reconciliation jitter** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Target API protection x cost efficiency

- Learning level: Professional.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Target API protection** while a change involving **First define the service objective** places **cost efficiency** at risk.
- Plain-language question: What problem does **Target API protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo maintains watches and makes Kubernetes requests across managed clusters. Protect targets by monitoring: request rate 429 responses latency watch reconnects cache age Aggressive Argo concurrency can become a control-plane load incident.
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Target API protection** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Namespace restriction cost x recovery

- Learning level: Industry-ready.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Namespace restriction cost** while a change involving **application-controller** places **recovery** at risk.
- Plain-language question: What problem does **Namespace restriction cost** solve here, and who notices first when it fails?
- Lesson evidence anchor: A cluster registration may list accessible namespaces. Argo warns that each namespace can produce separate list/watch activity and may exhaust idle connections unless client settings are tuned. ([Argo CD][3]) Namespace restriction is useful, but hundreds of...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Namespace restriction cost** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Redis HA x change management

- Learning level: Certification review.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Redis HA** while a change involving **Manifest-generation timeouts** places **change management** at risk.
- Plain-language question: What problem does **Redis HA** solve here, and who notices first when it fails?
- Lesson evidence anchor: The upstream HA topology runs Redis in HA mode. But remember: Redis HA = reduce cache/control interruption Redis backup ≠ required source-of-truth backup Place Redis Pods across failure domains and monitor quorum, memory, latency, and failover.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Redis HA** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Pod topology x dependency failure

- Learning level: Interview defense.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Pod topology** while a change involving **PodDisruptionBudget trap** places **dependency failure** at risk.
- Plain-language question: What problem does **Pod topology** solve here, and who notices first when it fails?
- Lesson evidence anchor: Production Argo components need: pod anti-affinity or topology spread multiple Availability Zones PodDisruptionBudgets resource requests priority classes where justified node capacity during upgrades Three replicas on one node are not high availability.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Pod topology** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - PodDisruptionBudget trap x developer experience

- Learning level: Beginner.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **PodDisruptionBudget trap** while a change involving **RPO design** places **developer experience** at risk.
- Plain-language question: What problem does **PodDisruptionBudget trap** solve here, and who notices first when it fails?
- Lesson evidence anchor: A PDB that is too strict can block: node upgrades voluntary maintenance cluster autoscaling A PDB that is too weak allows too many simultaneous evictions. Test: node drain AZ loss simulation rolling upgrade not only steady state.
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PodDisruptionBudget trap** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Backup layers x availability

- Learning level: Intermediate.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Backup layers** while a change involving **Security boundary** places **availability** at risk.
- Plain-language question: What problem does **Backup layers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use several recoverability layers: Layer 1 — Git declarative bootstrap and Applications Layer 2 — external secret manager repository/cluster/SSO secrets Layer 3 — argocd admin export Argo Kubernetes-object state Layer 4 — Kubernetes/etcd or namespace backup
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Backup layers** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - What Git can reconstruct x security

- Learning level: Expert.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **What Git can reconstruct** while a change involving **Supply-chain hardening** places **security** at risk.
- Plain-language question: What problem does **What Git can reconstruct** solve here, and who notices first when it fails?
- Lesson evidence anchor: If fully declarative, Git can recreate: Argo installation values AppProjects Applications/ApplicationSets RBAC ConfigMap notification templates/triggers resource customizations But Git should not contain plaintext: cluster credentials
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **What Git can reconstruct** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - What external systems must reconstruct x delivery safety

- Learning level: Professional.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **What external systems must reconstruct** while a change involving **Failure scenario — Redis loss** places **delivery safety** at risk.
- Plain-language question: What problem does **What external systems must reconstruct** solve here, and who notices first when it fails?
- Lesson evidence anchor: Recovery also depends on: Git host container registries DNS and certificates identity provider AWS IAM roles EKS access entries Secrets Manager/Vault network connectivity An Argo backup cannot restore an unavailable Git provider or revoked IAM trust.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **What external systems must reconstruct** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - argocd admin export x multi-tenancy

- Learning level: Industry-ready.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **argocd admin export** while a change involving **Interview — how do you scale Argo CD?** places **multi-tenancy** at risk.
- Plain-language question: What problem does **argocd admin export** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo provides: argocd admin export -n argocd  backup.yaml and: argocd admin import -n argocd - < backup.yaml The exact invocation can be run with a version-matched Argo image or CLI. The official DR guide emphasizes using the correct namespace; an export ma...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **argocd admin export** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Protect the export x observability

- Learning level: Certification review.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Protect the export** while a change involving **Durable Argo state** places **observability** at risk.
- Plain-language question: What problem does **Protect the export** solve here, and who notices first when it fails?
- Lesson evidence anchor: The export may contain sensitive Kubernetes objects. Treat it as: production secret-bearing backup Require: encryption at rest restricted storage access immutable/retained versions audit logs secure deletion policy restore access separation
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Protect the export** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Backup verification x regional resilience

- Learning level: Interview defense.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Backup verification** while a change involving **Controller sharding** places **regional resilience** at risk.
- Plain-language question: What problem does **Backup verification** solve here, and who notices first when it fails?
- Lesson evidence anchor: A successful command exit proves only: an export command completed. It does not prove: backup contains expected objects encryption key is recoverable storage is readable in disaster import works dependencies exist Restore testing is the evidence.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Backup verification** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - RPO design x business value

- Learning level: Beginner.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **RPO design** while a change involving **Reconciliation jitter** places **business value** at risk.
- Plain-language question: What problem does **RPO design** solve here, and who notices first when it fails?
- Lesson evidence anchor: If exports run daily: RPO may approach 24 hours unless Git and external systems reconstruct all intervening changes. Decide separately for: declarative config credentials signing keys local accounts operation history The most sensitive item may need the str...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **RPO design** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - RTO design x latency

- Learning level: Intermediate.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **RTO design** while a change involving **What Git can reconstruct** places **latency** at risk.
- Plain-language question: What problem does **RTO design** solve here, and who notices first when it fails?
- Lesson evidence anchor: Recovery time includes: provision management cluster install Argo version restore or regenerate secrets restore configuration reconnect Git reconnect target clusters warm caches verify Applications resume safe reconciliation
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **RTO design** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Cold recovery sequence x privacy

- Learning level: Expert.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Cold recovery sequence** while a change involving **The double-controller risk** places **privacy** at risk.
- Plain-language question: What problem does **Cold recovery sequence** solve here, and who notices first when it fails?
- Lesson evidence anchor: ---
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Cold recovery sequence** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - The double-controller risk x operability

- Learning level: Professional.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **The double-controller risk** while a change involving **Authorization hardening** places **operability** at risk.
- Plain-language question: What problem does **The double-controller risk** solve here, and who notices first when it fails?
- Lesson evidence anchor: During DR, never allow two independent Argo installations to reconcile the same Applications unknowingly. old primary recovers + new DR Argo active ↓ two control planes mutate targets Use fencing: revoke credentials disable cluster reconciliation
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **The double-controller risk** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Warm standby Argo x data integrity

- Learning level: Industry-ready.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Warm standby Argo** while a change involving **Secret hardening** places **data integrity** at risk.
- Plain-language question: What problem does **Warm standby Argo** solve here, and who notices first when it fails?
- Lesson evidence anchor: A standby control plane can reduce RTO. But it introduces synchronization and fencing questions: Which instance owns target credentials? Are both reading the same Git? How is active status declared? How is split-brain prevented?
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Warm standby Argo** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Upgrade strategy x automation safety

- Learning level: Certification review.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Upgrade strategy** while a change involving **Failure scenario — two Argo instances fight** places **automation safety** at risk.
- Plain-language question: What problem does **Upgrade strategy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before upgrading: read every intermediate upgrade note check Kubernetes compatibility check CRD changes check removed flags/defaults back up configuration test in non-production record rollback boundary Argo's upgrade guide recommends upgrading one minor ve...
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Upgrade strategy** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Self-managed Argo upgrade x governance

- Learning level: Interview defense.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Self-managed Argo upgrade** while a change involving **Interview — why not restore Redis?** places **governance** at risk.
- Plain-language question: What problem does **Self-managed Argo upgrade** solve here, and who notices first when it fails?
- Lesson evidence anchor: If Argo manages its own manifests: Argo changes the controller that is performing the change. Use: reviewed pinned chart/manifests server-side apply settings where required careful ignore differences HA capacity external break-glass access
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Self-managed Argo upgrade** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Security boundary x correctness

- Learning level: Beginner.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Security boundary** while a change involving **Component failure map** places **correctness** at risk.
- Plain-language question: What problem does **Security boundary** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo can often: read trusted Git render executable configuration tools write Kubernetes resources store cluster/repository connection data expose a production API/UI Treat it like a privileged platform service. ---
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Security boundary** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Authentication hardening x capacity

- Learning level: Intermediate.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Authentication hardening** while a change involving **repo-server** places **capacity** at risk.
- Plain-language question: What problem does **Authentication hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: integrate SSO/OIDC require MFA at IdP disable local admin after bootstrap where supported by policy avoid shared accounts shorten automation-token lifetime revoke unused tokens maintain tested break-glass access Break glass must be monitored and rotated, no...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Authentication hardening** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Authorization hardening x cost efficiency

- Learning level: Expert.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Authorization hardening** while a change involving **Namespace restriction cost** places **cost efficiency** at risk.
- Plain-language question: What problem does **Authorization hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use: default read-only or minimal role group-based RBAC AppProject boundaries least-privilege sync permissions restricted override/action permissions restricted Application creation An Application that can target the Argo namespace can become administrative...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Authorization hardening** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - TLS hardening x recovery

- Learning level: Professional.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **TLS hardening** while a change involving **argocd admin export** places **recovery** at risk.
- Plain-language question: What problem does **TLS hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: Protect: client → argocd-server server → repo-server controller → repo-server Argo → Git Argo → target clusters Argo → Redis where configured The security guide notes Argo component communication is TLS-protected, while Redis transport requires deliberate T...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **TLS hardening** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Network hardening x change management

- Learning level: Industry-ready.
- Environment: peak traffic with bounded synthetic load.
- Scenario: The team must apply **Network hardening** while a change involving **Warm standby Argo** places **change management** at risk.
- Plain-language question: What problem does **Network hardening** solve here, and who notices first when it fails?
- Lesson evidence anchor: private management nodes restricted Ingress WAF/reverse proxy where appropriate NetworkPolicies restricted egress to approved Git/cluster endpoints private EKS endpoints no public Redis/repo-server exposure Be careful: overly strict egress can break Git, He...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Network hardening** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Repo-server threat model x dependency failure

- Learning level: Certification review.
- Environment: a regional recovery tabletop.
- Scenario: The team must apply **Repo-server threat model** while a change involving **Network hardening** places **dependency failure** at risk.
- Plain-language question: What problem does **Repo-server threat model** solve here, and who notices first when it fails?
- Lesson evidence anchor: repo-server renders content from trusted repositories. Helm, Kustomize, and plugins process repository-controlled input. Argo warns that malicious trusted-repository content may try to access files through tool behavior, remote bases, dependencies, or plugi...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Repo-server threat model** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 41.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/ "High Availability - Argo CD"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/dynamic-cluster-distribution/ "Dynamic Cluster Distribution - Argo CD"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters "Cluster Configuration - Argo CD"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/ "Disaster Recovery - Argo CD"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/ "Upgrading Overview - Argo CD"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/ "Security - Argo CD"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/ "TLS Configuration - Argo CD"
