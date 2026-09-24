# Module 14 — GitOps with Argo CD

## Lesson 19: Incident Scenarios, Interview Mastery & Never-Forget Revision

This final lesson turns knowledge into reflex.

During an incident, you do not have time to rediscover the architecture.

You need a stable mental model:

```text
Git desired state
      │
      ▼
source access and rendering
      │
      ▼
Argo Application comparison
      │
      ▼
sync phases and waves
      │
      ▼
target Kubernetes API
      │
      ▼
workload controllers
      │
      ▼
traffic and customer behavior
```

Every incident belongs somewhere on that path.

---

# 14.1946 The first five minutes

```text
1. State customer and deployment impact.

2. Stop unsafe progression if necessary.

3. Establish affected Applications/clusters.

4. Capture desired Git revision and Argo operation state.

5. Identify the failing layer before changing anything.
```

Do not begin with random restarts.

---

# 14.1947 Incident command principles

```text
one incident commander

one operations lead

one communications lead

UTC timeline

explicit hypotheses

reversible changes first

one authoritative desired state

evidence preserved
```

GitOps improves auditability only if emergency actions are recorded.

---

# 14.1948 Classification

```text
CONTROL-PLANE INCIDENT
Argo/API/render/cache unavailable

RECONCILIATION INCIDENT
desired state cannot converge

RELEASE INCIDENT
new revision harms service

TARGET-CLUSTER INCIDENT
Kubernetes API or infrastructure fails

DEPENDENCY INCIDENT
Git, registry, secrets, identity, database, metrics fail

SECURITY INCIDENT
unauthorized desired/live change or credential compromise
```

One incident may cross multiple categories.

---

# 14.1949 Universal triage commands

```bash
argocd app get <app> --show-operation

argocd app diff <app>

argocd app history <app>

argocd app resources <app>

kubectl get application <app> -n argocd -o yaml

kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
```

Target workload:

```bash
kubectl get all -n <namespace>

kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

---

# 14.1950 Incident 1 — Argo UI is unavailable

Impact may be:

```text
operators cannot use UI/CLI API
```

while reconciliation continues.

Check:

```text
argocd-server Pods and readiness

Service endpoints

Ingress/load balancer

TLS certificate

SSO/IdP

DNS
```

Confirm application-controller health separately.

Do not declare all deployments stopped merely because the UI is down.

---

# 14.1951 Incident 2 — Application remains OutOfSync

Check exact diff.

Possible causes:

```text
new Git revision awaiting manual sync

sync window denied

auto-sync disabled

manual drift

mutating admission/controller field

shared-resource ownership conflict

apply failure
```

Correct the owner.

Do not add a broad ignore rule before identifying the field manager.

---

# 14.1952 Incident 3 — self-heal loop

Symptoms:

```text
Argo applies field A

another controller changes field A

Argo applies field A again
```

Actions:

```text
identify exact JSON path

inspect managedFields

establish authoritative controller

change Git or add narrow ignore rule

verify stable convergence
```

Common owners:

```text
HPA replicas

Rollouts Service selectors

operators

admission webhooks
```

---

# 14.1953 Incident 4 — comparison error

Symptoms:

```text
ComparisonError

manifest generation error

unable to load target state
```

Trace:

```text
repo URL and revision

repository credential

Git/Helm/OCI reachability

render command

dependency version

plugin logs

timeout/memory/disk
```

Kubernetes may be healthy; desired manifests do not exist for comparison yet.

---

# 14.1954 Incident 5 — repository authentication fails

Check:

```text
credential Secret and project scope

GitHub App installation/repository access

SSH host key

token expiry/revocation

HTTPS/SSH URL match

CA certificate

egress proxy
```

Rotate compromised or expired credentials through the secret system.

Never paste the private key into an incident chat.

---

# 14.1955 Incident 6 — repo-server OOM

Contain:

```text
reduce render concurrency if safe

identify triggering Application/revision

temporarily isolate pathological source

restore sufficient replicas/resources
```

Diagnose:

```text
manifest size

directory recursion

Helm/Kustomize expansion

plugin behavior

monorepo fan-out

ephemeral disk
```

Do not solve malicious/unbounded input with memory alone.

---

# 14.1956 Incident 7 — one cluster is Unknown

Trace:

```text
destination name/server
→ DNS
→ TCP 443
→ TLS
→ AWS role assumption/token
→ EKS access entry
→ Kubernetes RBAC
```

Check cluster connection and cache-age metrics.

Do not delete the cluster registration until you know whether it is a transient target outage.

---

# 14.1957 Incident 8 — target says Forbidden

Meaning:

```text
identity was understood
but action was denied.
```

Inspect:

```text
resource group/kind

verb

namespace

EKS access-entry group/policy

Role/ClusterRole

RoleBinding/ClusterRoleBinding
```

Grant the missing narrow permission.

Never jump directly to cluster-admin.

---

# 14.1958 Incident 9 — sync is stuck Running

Find:

```text
operation phase

current hook phase

earliest incomplete wave

resource health message
```

Common causes:

```text
PreSync Job pending

early wave unhealthy

hook fixed name collision

finalizer

resource deletion waiting

Rollout intentionally paused
```

Later missing waves are often a symptom, not the cause.

---

# 14.1959 Incident 10 — migration hook failed

Immediate actions:

```text
stop further release progression

retain Job and logs

check schema-history table

determine whether transaction committed partially or fully

confirm migration lock

assess old application compatibility
```

Retry only when idempotency and current database state are known.

Do not automatically delete the failed Job and click Sync.

---

# 14.1960 Incident 11 — migration succeeded, new app failed

Decision:

```text
Can old binary run against expanded schema?
```

If yes:

```text
abort/revert application digest
```

If no:

```text
roll forward may be safer than rollback
```

This is why expand-and-contract and explicit migration classification are required.

---

# 14.1961 Incident 12 — Rollout paused unexpectedly

Check:

```bash
kubectl argo rollouts get rollout todo-api -n todo-prod

kubectl describe rollout todo-api -n todo-prod
```

Determine:

```text
intentional indefinite pause?

timed pause still active?

analysis running?

progress deadline issue?

operator abort?
```

Never promote until release evidence is reviewed.

---

# 14.1962 Incident 13 — AnalysisRun failed

Ask:

```text
Was customer behavior actually bad?

Did query isolate canary?

Was there enough traffic?

Was result empty/NaN?

Was Prometheus unavailable?

Did successCondition match result shape?
```

If the metric is correct, treat the failed gate as protection working.

If the metric is broken, fix the gate before future release—not by permanently disabling analysis.

---

# 14.1963 Incident 14 — canary abort did not restore service

Possible reasons:

```text
stable revision also unhealthy

database incompatibility

traffic router not converged

shared dependency failed

cache/message side effect persists

incident is unrelated to release
```

Validate actual traffic and customer requests.

Controller status alone is not recovery proof.

---

# 14.1964 Incident 15 — ExternalSecret not Ready

Trace:

```text
ExternalSecret reference
→ SecretStore readiness
→ workload identity
→ provider endpoint/network
→ IAM authorization
→ secret key/property/version
→ target Kubernetes Secret
```

Do not replace it with a plaintext Secret committed during the incident.

Use an approved break-glass secret-delivery procedure if needed.

---

# 14.1965 Incident 16 — Secret updated, app still fails

Check:

```text
target Secret resourceVersion changed?

Pod consumes env var or mounted volume?

reload controller exists?

Pods restarted?

database/server rotated too?

old credential overlap/revocation timing?
```

Provider rotation, Kubernetes refresh, and application reload are three separate events.

---

# 14.1966 Incident 17 — ApplicationSet wants mass deletion

Contain immediately:

```text
stop generator change from merging if not merged

pause/fence reconciliation according to runbook

preserve ApplicationSet and generated Application state

inspect generator inputs and deletion policy
```

Common causes:

```text
Git directory removed

cluster label changed

selector bug

SCM generator returned empty set

template path error
```

Do not approve a huge deletion diff because it is “generated.”

---

# 14.1967 Incident 18 — workload generated in production accidentally

Actions:

```text
stop unsafe sync/traffic

identify cluster label or generator input change

review AppProject boundary failure

remove desired instance through authoritative generator fix

inspect created resources and data

audit actor and approvals
```

Prevention:

```text
controlled cluster labels

previewed generation

restricted Project destinations

production eligibility gate
```

---

# 14.1968 Incident 19 — resource pruned unexpectedly

Ask:

```text
Was resource removed from Git?

Did Application path change?

Did Kustomize render stop including it?

Did ApplicationSet delete an Application?

Was tracking label/annotation changed?

Who owns the resource?
```

Restore desired declaration and data safely.

Do not recreate manually without correcting Git if auto-sync/prune remains active.

---

# 14.1969 Incident 20 — Application deletion stuck

Inspect:

```text
Application finalizer

PreDelete/PostDelete hook

child resource finalizer

unreachable target cluster

RBAC deletion permission

cloud-controller cleanup
```

Removing a finalizer bypasses controller cleanup guarantees.

Do it only with explicit understanding of orphaned resources and external side effects.

---

# 14.1970 Incident 21 — webhook storm

Symptoms:

```text
high webhook rate

many refreshes

repo-server/Redis load

slow real reconciliation
```

Actions:

```text
validate provider secret/signature configuration

rate-limit at ingress/proxy

identify source IP/provider event

inspect repository filtering

preserve periodic reconciliation
```

Webhook is a refresh hint, not the desired-state source.

---

# 14.1971 Incident 22 — Redis is lost

Expected:

```text
cache disruption and repopulation
```

Actions:

```text
restore supported Redis topology

watch controller/server error rate

allow cache warm-up

monitor repo and target API load spike
```

Do not attempt to reconstruct Applications from Redis.

Durable state belongs in Kubernetes objects and Git/external systems.

---

# 14.1972 Incident 23 — Argo management cluster lost

```text
1. Freeze promotions.
2. Fence old controller credentials.
3. Confirm running workloads remain stable.
4. Provision recovery control plane.
5. Install compatible pinned Argo version.
6. Restore secret delivery and configuration.
7. Validate Git, SSO, and target connectivity.
8. Compare fleet before broad auto-sync.
9. Resume reconciliation by risk group.
10. Measure against RTO/RPO.
```

Never activate a new controller without split-brain protection, and rehearse the documented export/import recovery path before an incident. ([Argo CD][10])

---

# 14.1973 Incident 24 — Git provider unavailable

Expected:

```text
running workloads continue

new desired state unavailable

render/compare errors may increase

self-heal behavior may be limited by cached desired state and operation path
```

Actions:

```text
stop nonessential sync attempts

confirm provider incident

preserve known-good revision/digest records

use approved Git DR/mirror plan if declared authoritative

avoid ad hoc competing repositories
```

---

# 14.1974 Incident 25 — Git credential compromised

Treat Git as production control-plane compromise.

```text
revoke credential

freeze merges/deployments

inspect commits, branches, tags, webhooks, rules, and audit logs

identify every trusted repository

verify live cluster state against last trusted revision

rotate downstream secrets if exposed

restore trusted branch protection

resume with signed/approved known-good state
```

A clean-looking current branch is not enough; inspect history and rules.

---

# 14.1975 Incident 26 — image tag was overwritten

If Git stores a mutable tag:

```text
same desired text
different runtime bytes
```

Actions:

```text
capture running imageID/digest

stop further pulls/rollout

identify overwritten manifest

restore verified digest

rotate/revoke registry writer

enable immutability

change Git to digest
```

This is a supply-chain integrity incident.

---

# 14.1976 Incident 27 — CI bot promotes wrong artifact

Contain:

```text
pause/abort Rollout

revert production config PR

validate database/side effects

revoke bot if compromise suspected

preserve release.json and CI run
```

Root causes may include:

```text
race/lost update

wrong repository mapping

artifact metadata overwrite

untrusted job credential use

manual input error
```

---

# 14.1977 Incident 28 — production drift was intentional hotfix

The hotfix may be valid operationally but is still unrecorded desired state.

Options:

```text
immediately encode the hotfix in Git

or revert live state if the hotfix is no longer required
```

If self-heal would erase a lifesaving temporary change, use a controlled pause with owner and expiry—not silent disabling.

After incident, remove the exceptional path.

---

# 14.1978 Incident 29 — DR cluster is Synced but unusable

Check beyond Argo:

```text
image exists in DR registry

secret and KMS work

database is promotable and within RPO

DNS/traffic failover works

certificates cover DR endpoint

third-party allowlists include DR egress

capacity is available

customer transaction succeeds
```

Synced manifests are only one DR layer.

---

# 14.1979 Incident 30 — alert did not fire

Trace:

```text
metric exists
→ scrape succeeds
→ rule loaded
→ expression returns series
→ `for` duration elapsed
→ Alertmanager route matches
→ inhibition not suppressing incorrectly
→ receiver accepts
→ human receives
```

For Argo Notifications, trace trigger → template → subscription → service separately.

---

# 14.1980 Post-incident GitOps review

Ask:

```text
Did Git show the intended state?

Did live state differ, and why?

Which controller owned each mutation?

Did automation reduce or amplify impact?

Were credentials and boundaries appropriate?

Did alerts detect customer risk early?

Did rollback/DR assumptions hold?

What guardrail prevents recurrence?
```

Update code, policy, tests, alerts, and runbooks—not only the narrative.

---

# 14.1981 Interview answer framework

Use:

```text
DEFINITION
→ define the concept

ARCHITECTURE
→ place it in the system

TRADEOFF
→ state risk/cost

PRODUCTION EXAMPLE
→ show implementation

FAILURE MODE
→ show operational depth
```

This creates answers that sound practiced because they are reasoned.

---

# 14.1982 Interview — What is GitOps?

Strong answer:

> **GitOps is an operating model where system state is declarative, versioned, automatically pulled by software agents, and continuously reconciled against actual state. For Kubernetes, Argo CD can implement that model by comparing manifests from Git with live resources and correcting drift according to policy. GitOps is the model; Argo CD is one implementation.** ([OpenGitOps][1])

---

# 14.1983 Interview — push vs pull delivery

> **In push delivery, CI holds credentials and directly changes the target environment. In pull GitOps, CI builds an artifact and updates the desired configuration in Git; an in-environment or connected controller pulls that declaration and reconciles it. This separates build authority from cluster deployment authority, though the Git repository and controller become critical security boundaries.**

---

# 14.1984 Interview — desired, live, sync, health

```text
desired state
= rendered declaration from Git

live state
= Kubernetes objects observed now

sync status
= desired vs live equality

health status
= operational condition of resources
```

Example:

```text
Synced + Degraded
→ Git matches Kubernetes, but workload is broken.
```

---

# 14.1985 Interview — Argo architecture

> **The API server provides UI/API and authentication; repo-server fetches sources and renders manifests; application-controller compares desired and live state and performs sync; ApplicationSet controller generates Applications; notifications controller evaluates triggers and sends messages; Redis is a disposable cache. Durable Argo objects live in Kubernetes.** ([Argo CD][2])

---

# 14.1986 Interview — Application CRD

> **An Application connects a source to a destination under an AppProject. The source defines repository, revision, and path/chart; the destination defines cluster and namespace; sync policy controls automated behavior, pruning, self-heal, retry, and sync options; status reports comparison, health, conditions, and operation history.**

---

# 14.1987 Interview — auto-sync, prune, self-heal

```text
auto-sync
→ apply new desired revisions automatically

prune
→ remove tracked live resources absent from desired state

self-heal
→ correct live drift even when Git revision did not change
```

Each increases automation and therefore requires stronger Git controls and deletion safety.

---

# 14.1988 Interview — Helm under Argo

> **Argo uses Helm primarily as a manifest renderer through `helm template`; Argo, not Helm, owns the application reconciliation lifecycle. Values precedence, chart pinning, repository credentials, rendered diff, and hook mapping must be understood. I do not rely on Helm release state when Argo is the deployer.**

---

# 14.1989 Interview — Kustomize under Argo

> **Kustomize composes a reusable base with environment overlays without a templating language. Argo runs the build and reconciles its output. I keep bases environment-neutral, overlays small, images immutable, remote references pinned, and validate the final rendered resources per environment.**

---

# 14.1990 Interview — AppProject vs RBAC

> **Argo RBAC controls what users or automation may do through Argo. AppProject constrains an Application's permitted source repositories, destination clusters/namespaces, and resource kinds. Target-cluster Kubernetes RBAC constrains what the Argo identity can actually do. Production uses all three as defense in depth.**

---

# 14.1991 Interview — ApplicationSet vs App-of-Apps

> **ApplicationSet generates multiple Applications from data such as cluster labels, Git directories, lists, or SCM resources. App-of-Apps is a parent Application whose manifests include child Application objects, useful for hierarchical bootstrap. ApplicationSet solves parameterized fleet generation; App-of-Apps expresses a declarative hierarchy. Neither automatically guarantees child workload readiness order.**

---

# 14.1992 Interview — secrets in GitOps

> **Git stores secret intent—the provider reference, target name, and mapping—not plaintext values. A destination-side operator such as External Secrets fetches the value from AWS Secrets Manager or Vault using workload identity and creates or mounts runtime material. I still protect Kubernetes Secrets, operator RBAC, rotation, and application reload.** ([Argo CD][3])

---

# 14.1993 Interview — sync phases and waves

> **Phases place work in PreSync, Sync, PostSync, or failure/deletion lifecycle stages. Waves order resources numerically within a phase. Phase precedence comes first, then wave, kind, and name. Argo waits for earlier wave health before progressing, and prune order is reversed.** ([Argo CD][4])

---

# 14.1994 Interview — safe database migrations

> **I run a bounded, idempotent, locked migration Job using the same immutable release artifact and a separate schema identity. I use expand-and-contract so old and new binaries remain compatible during rollout and rollback. A failed migration blocks deployment; a successful destructive migration cannot be undone merely by reverting the image.**

---

# 14.1995 Interview — Argo Rollouts

> **Argo CD deploys the Rollout CR; Argo Rollouts reconciles it into ReplicaSets, Services/traffic routing, pauses, analysis, promotion, and abort behavior. Canary limits initial blast radius and uses candidate-specific metrics. Blue/green prepares a preview revision then switches traffic, requiring capacity and routing-propagation safety.** ([Argo Rollouts][5])

---

# 14.1996 Interview — multi-cluster EKS

> **I choose central, per-cluster, or hybrid Argo by trust and failure domain. In the documented centralized EKS model, Argo uses a workload identity for a management IAM role, assumes a scoped target-cluster role, and authenticates through EKS; an access entry and Kubernetes RBAC authorize operations. Private endpoint DNS, routing, TLS, and security groups must also work.** ([Argo CD][6])

---

# 14.1997 Interview — Argo HA and DR

> **Argo is largely stateless: durable objects live in Kubernetes and Redis is a disposable cache. HA uses component-appropriate replicas, topology, Redis HA, and controller sharding. DR uses Git, recoverable secrets and IAM/network IaC, protected admin exports or cluster backups, version-pinned reinstall, fencing, and tested restoration against RTO/RPO.** ([Argo CD][7])

---

# 14.1998 Interview — Argo observability

> **I monitor Application sync and health, cluster connection and cache age, reconciliation latency, sync outcomes, repo-server rendering/resources, Redis, API availability, ApplicationSet generation, and notifications. I correlate metrics with Application status, diffs, logs, Events, Git revisions, and audit records, and measure commit-to-Synced-and-Healthy rather than only Pod uptime.** ([Argo CD][8])

---

# 14.1999 Interview — CI with Argo

> **CI builds, tests, scans, signs, and pushes one immutable image, then proposes a config-repository PR containing its digest. The same digest is promoted through environments. After merge, Argo reconciles it, so CI does not need production Kubernetes access and usually does not need Argo API access when auto-sync is enabled.** ([Argo CD][9])

---

# 14.2000 Interview — biggest GitOps risks

Strong answer:

```text
trusted Git compromise

overly broad Argo or cluster credentials

unsafe automatic pruning

hidden multi-controller ownership

plaintext or generation-time secrets

mutable/unverified images

mass ApplicationSet changes

unobserved stuck reconciliation

untested database rollback

untested DR/split brain
```

Then explain the matching controls.

---

# 14.2001 Architecture decision — central vs decentralized

Good decision statement:

```text
We selected a production-only central Argo control plane
because it provides fleet visibility and consistent policy
within one production trust domain.

We separated non-production and regulated clusters
to contain credential, network, upgrade, and reconciliation blast radius.
```

An architecture answer must name the tradeoff it accepts.

---

# 14.2002 Architecture decision — auto-sync in production

Good answer:

> **We enable auto-sync because the production branch already requires reviewed PRs, policy checks, immutable digests, and change controls, while Argo Rollouts limits traffic exposure. We retain sync windows and an emergency reconciliation pause. Another organization might choose manual sync if regulation requires a separate deployment authorization.**

---

# 14.2003 Architecture decision — one repo vs many

Good answer:

> **We separate application source from deployment configuration so build permissions do not imply production-config merge rights, audit history stays deployment-focused, and CI loops are avoided. We split platform and workload configuration because their privileges and owners differ. We avoid excessive per-app repositories when operational overhead would outweigh isolation.**

---

# 14.2004 Architecture decision — External Secrets

Good answer:

> **We chose destination-side External Secrets because actual values remain in the enterprise secret provider and rotate independently of Argo rendering. We use workload identity, namespaced stores or per-team roles, least-privilege provider ARNs, target Secret RBAC, and an application reload mechanism.**

---

# 14.2005 Architecture decision — canary metrics

Good answer:

> **We gate on minimum candidate request volume, candidate-specific success rate, p95 latency, and a critical business signal. Empty data is not success. Provider failure behavior is explicit, and the stable revision remains schema-compatible during the rollback window.**

---

# 14.2006 Rapid fire — status meanings

```text
Synced
→ desired equals live

OutOfSync
→ desired differs from live

Healthy
→ resource health is good

Degraded
→ resource reports unhealthy failure

Progressing
→ resource is moving toward health or paused workflow state

Missing
→ desired tracked resource absent

Unknown
→ health cannot be reliably assessed
```

---

# 14.2007 Rapid fire — ownership

```text
Git
→ desired declaration

Argo CD
→ Git-to-Kubernetes reconciliation

Kubernetes controller
→ runtime reconciliation

External Secrets
→ secret materialization

HPA
→ replica count when configured

Argo Rollouts
→ progressive ReplicaSets/traffic

CI
→ artifact production

human/policy
→ promotion approval
```

One field should have one authoritative owner.

---

# 14.2008 Rapid fire — security boundaries

```text
branch protection
→ who can change desired state

AppProject
→ what an Application may target/source/create

Argo RBAC
→ what a user may do through Argo

Kubernetes RBAC
→ what Argo may do in cluster

IAM
→ AWS identity and role scope

Network
→ which endpoints are reachable

Admission policy
→ which resources/images are accepted
```

---

# 14.2009 Rapid fire — release safety

```text
immutable digest

reviewed promotion PR

render/policy validation

safe migration

meaningful readiness

canary blast-radius limit

candidate-specific analysis

Git rollback declaration

customer SLO verification
```

No single item is the complete strategy.

---

# 14.2010 Command sheet — Application

```bash
argocd app list

argocd app get <app>

argocd app diff <app>

argocd app sync <app>

argocd app wait <app> --sync --health --operation

argocd app history <app>

argocd app resources <app>

argocd app terminate-op <app>
```

Know what each command mutates before using it in production.

---

# 14.2011 Command sheet — cluster and repository

```bash
argocd cluster list

argocd cluster get <server-or-name>

argocd repo list

argocd repo get <repo-url>

kubectl get secret -n argocd \
  -l argocd.argoproj.io/secret-type=cluster

kubectl get secret -n argocd \
  -l argocd.argoproj.io/secret-type=repository
```

Never dump Secret data into shared output.

---

# 14.2012 Command sheet — Rollouts and secrets

```bash
kubectl argo rollouts get rollout <name> -n <namespace> --watch

kubectl argo rollouts promote <name> -n <namespace>

kubectl argo rollouts abort <name> -n <namespace>

kubectl get analysisrun -n <namespace>

kubectl get externalsecret,secretstore -n <namespace>

kubectl describe externalsecret <name> -n <namespace>
```

Promotion and abort are production mutations.

---

# 14.2013 Command sheet — rendering

```bash
helm template <release> <chart> -f <values>

kustomize build <overlay>

kubectl apply --dry-run=server -f <rendered-file>

argocd app manifests <app>
```

Render exactly the source revision, tool version, values, and environment that Argo uses.

---

# 14.2014 Ten diagrams to remember

```text
1. Git → Argo → Kubernetes

2. Desired vs live → sync

3. Runtime state → health

4. CI → registry + config PR

5. AppProject ∩ Argo RBAC ∩ Kubernetes RBAC

6. ApplicationSet input → generated Applications

7. Secret reference → operator → provider → Secret → Pod

8. Phase → wave → health gate

9. Stable/canary → analysis → promotion/abort

10. Git + secrets + IaC + backup → DR restore
```

If these are clear, most details have a place.

---

# 14.2015 Fifty never-forget rules

```text
1. GitOps is a model, not a product.

2. Desired state must be declarative.

3. Desired state must be versioned.

4. Agents pull it automatically.

5. Reconciliation is continuous.

6. Git is part of the production control plane.

7. CI builds; Argo deploys.

8. CI does not need production kubeconfig.

9. Build once and promote the same digest.

10. A tag is not necessarily immutable.

11. Sync is desired vs live.

12. Health is operational state.

13. Synced can still be Degraded.

14. Self-heal can fight another controller.

15. One field needs one owner.

16. Prune is powerful deletion authority.

17. AppProject restricts application capability.

18. Argo RBAC restricts user capability.

19. Kubernetes RBAC restricts controller capability.

20. ApplicationSet inputs are fleet routing authority.

21. Generated Applications are not hand-owned.

22. App-of-Apps is hierarchy, not automatic readiness sequencing.

23. Base64 is not secret encryption.

24. Git stores secret intent, not value.

25. Secret operator RBAC matters.

26. Secret refresh is not application reload.

27. Phase ordering beats wave numbering.

28. Lower waves create first.

29. Higher waves prune first.

30. Hooks do not run in selective sync.

31. Migration retries must be safe.

32. Expand schema before contracting it.

33. Workload rollback does not undo schema.

34. Argo CD and Argo Rollouts are different controllers.

35. Canary needs candidate-specific evidence.

36. No canary traffic means no canary proof.

37. Abort does not undo external side effects.

38. Central Argo increases credential blast radius.

39. Pull GitOps still needs target API reachability.

40. IAM authentication is not Kubernetes authorization.

41. Redis is a disposable Argo cache.

42. HA does not replace backup.

43. Backup does not replace restore testing.

44. DR requires fencing.

45. Synced DR YAML does not prove recoverable service.

46. Metrics, logs, Events, Git, and audit must correlate.

47. Webhooks accelerate; Git remains authority.

48. Emergency changes must return to Git.

49. Every alert requires a runbook.

50. Production readiness is proven through failure tests.
```

---

# 14.2016 Final production readiness checklist

## Git and source

```text
□ Source and config ownership are explicit

□ Production branch is protected

□ CODEOWNERS is enforced

□ Bots cannot self-approve

□ Audit logs and MFA are enabled

□ Remote chart/base references are pinned
```

## Artifact

```text
□ Image digest is immutable

□ ECR tag immutability is configured

□ SBOM/provenance/signature exist

□ Admission policy validates trusted artifact

□ Primary and DR registries retain release
```

## Argo

```text
□ Version is pinned and supported

□ HA spans nodes/AZs

□ SSO/RBAC/break glass are tested

□ AppProjects are least privilege

□ Cluster credentials are protected

□ repo-server/plugins are hardened

□ admin export/restore is tested
```

## Applications

```text
□ Application source and destination are restricted

□ Auto-sync/prune/self-heal decisions are documented

□ Resource ownership conflicts are resolved

□ Custom health checks are tested

□ Deletion/finalizer behavior is understood
```

## Secrets

```text
□ No plaintext production secret is in Git

□ Workload identity replaces static cloud keys

□ Provider permissions are resource-scoped

□ Target Secret RBAC is restricted

□ Rotation and application reload are tested

□ Bootstrap secrets are recoverable
```

## Release safety

```text
□ Migration is idempotent and locked

□ Schema change is backward compatible

□ Readiness/liveness/startup probes are meaningful

□ Canary metric isolates candidate

□ Minimum traffic volume is required

□ Promotion/abort permissions are restricted

□ Rollback digest and runbook are tested
```

## Fleet and DR

```text
□ Cluster labels are controlled

□ EKS role/access-entry/RBAC chain is least privilege

□ Private endpoint connectivity is tested

□ Cluster onboarding/offboarding is controlled

□ Old control plane can be fenced

□ Data, secret, image, DNS, and certificate DR works

□ Customer transaction meets RTO/RPO in exercise
```

## Observability

```text
□ All component metrics are scraped

□ Sync, health, cluster, and render alerts exist

□ Alerts route by owner/tier/environment

□ Logs and Events are retained

□ Notification path is tested end to end

□ Commit-to-healthy SLO is measured
```

---

# 14.2017 Final troubleshooting mnemonic

For the whole module, memorize:

# **G-R-A-C-E-D**

```text
GIT
  ↓
RENDER
  ↓
APPLICATION
  ↓
CLUSTER
  ↓
EXECUTION
  ↓
DEPENDENCY / DATA
```

Examples:

```text
wrong image digest
→ GIT

Helm template fails
→ RENDER

sync policy/window blocks
→ APPLICATION

EKS API timeout
→ CLUSTER

hook/Rollout stuck
→ EXECUTION

database/secret/registry failure
→ DEPENDENCY / DATA
```

---

# 14.2018 Final interview closing answer

If asked:

> How would you design production GitOps on EKS?

Answer:

> **I separate application source, platform configuration, and workload promotion according to ownership. CI uses short-lived identity to build, test, scan, attest, and publish one immutable ECR digest, then proposes a protected config-repository PR. A highly available Argo CD control plane reaches private EKS APIs through scoped IAM target roles, EKS access entries, Kubernetes RBAC, and restrictive AppProjects. ApplicationSets place instances using controlled cluster metadata. External Secrets delivers values at the destination. PreSync migration Jobs use expand-and-contract, locking, and immutable artifacts. Argo Rollouts limits production exposure and Prometheus analysis gates promotion. I monitor commit-to-Synced-and-Healthy, protect Git and repo-server as supply-chain boundaries, and prove backup, fencing, rollback, and multi-region DR through failure exercises.**

That answer connects architecture, security, delivery, operations, and recovery.

---

# ✅ Module 14 — Lesson 19 Complete

You now have operational mastery of:

```text
✓ incident classification

✓ first-response workflow

✓ Application and diff triage

✓ repository/render failures

✓ target EKS authentication and authorization

✓ hook/migration incidents

✓ Rollout and analysis incidents

✓ secret-delivery incidents

✓ ApplicationSet mass-change containment

✓ prune/finalizer incidents

✓ Argo/Git/Redis/DR failures

✓ supply-chain incidents

✓ interview architecture answers

✓ rapid mental-model revision

✓ final production readiness assessment
```

# 🎓 Module 14 — GitOps with Argo CD Complete

Across Lessons 1–19, you progressed from:

```text
"Git stores Kubernetes YAML"
```

to:

```text
GitOps control-plane architecture

secure multi-cluster delivery

progressive production releases

continuous reconciliation

observable and recoverable operations
```

The final never-forget sentence is:

> **Git declares the reviewed destination state, Argo continuously reconciles it, Kubernetes realizes it, telemetry proves it, and tested recovery protects it.**

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.19.2019 Professional Mastery Workbook

This workbook expands **Incident Scenarios, Interview Mastery & Never-Forget Revision** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 73 lesson-specific anchors.
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

### Concept card 1 - The first five minutes

- Lesson anchor: Do not begin with random restarts. ---
- Beginner explanation: Restate **The first five minutes** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The first five minutes** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **The first five minutes**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **The first five minutes**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The first five minutes** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Incident command principles

- Lesson anchor: one incident commander one operations lead one communications lead UTC timeline explicit hypotheses reversible changes first one authoritative desired state evidence preserved GitOps improves auditability only if emergency actions are recorded.
- Beginner explanation: Restate **Incident command principles** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident command principles** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident command principles**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident command principles**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident command principles** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Classification

- Lesson anchor: CONTROL-PLANE INCIDENT Argo/API/render/cache unavailable RECONCILIATION INCIDENT desired state cannot converge RELEASE INCIDENT new revision harms service TARGET-CLUSTER INCIDENT Kubernetes API or infrastructure fails DEPENDENCY INCIDENT
- Beginner explanation: Restate **Classification** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Classification** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Classification**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Classification**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Classification** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Universal triage commands

- Lesson anchor: argocd app get <app --show-operation argocd app diff <app argocd app history <app argocd app resources <app kubectl get application <app -n argocd -o yaml kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
- Beginner explanation: Restate **Universal triage commands** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Universal triage commands** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Universal triage commands**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Universal triage commands**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Universal triage commands** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Incident 1 — Argo UI is unavailable

- Lesson anchor: Impact may be: operators cannot use UI/CLI API while reconciliation continues. Check: argocd-server Pods and readiness Service endpoints Ingress/load balancer TLS certificate SSO/IdP DNS Confirm application-controller health separately.
- Beginner explanation: Restate **Incident 1 — Argo UI is unavailable** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 1 — Argo UI is unavailable** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Incident 1 — Argo UI is unavailable**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Incident 1 — Argo UI is unavailable**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 1 — Argo UI is unavailable** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Incident 2 — Application remains OutOfSync

- Lesson anchor: Check exact diff. Possible causes: new Git revision awaiting manual sync sync window denied auto-sync disabled manual drift mutating admission/controller field shared-resource ownership conflict apply failure Correct the owner.
- Beginner explanation: Restate **Incident 2 — Application remains OutOfSync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 2 — Application remains OutOfSync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Incident 2 — Application remains OutOfSync**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Incident 2 — Application remains OutOfSync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 2 — Application remains OutOfSync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Incident 3 — self-heal loop

- Lesson anchor: Symptoms: Argo applies field A another controller changes field A Argo applies field A again Actions: identify exact JSON path inspect managedFields establish authoritative controller change Git or add narrow ignore rule
- Beginner explanation: Restate **Incident 3 — self-heal loop** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 3 — self-heal loop** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Incident 3 — self-heal loop**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Incident 3 — self-heal loop**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 3 — self-heal loop** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Incident 4 — comparison error

- Lesson anchor: Symptoms: ComparisonError manifest generation error unable to load target state Trace: repo URL and revision repository credential Git/Helm/OCI reachability render command dependency version plugin logs timeout/memory/disk
- Beginner explanation: Restate **Incident 4 — comparison error** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 4 — comparison error** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident 4 — comparison error**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident 4 — comparison error**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 4 — comparison error** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Incident 5 — repository authentication fails

- Lesson anchor: Check: credential Secret and project scope GitHub App installation/repository access SSH host key token expiry/revocation HTTPS/SSH URL match CA certificate egress proxy Rotate compromised or expired credentials through the secret system.
- Beginner explanation: Restate **Incident 5 — repository authentication fails** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 5 — repository authentication fails** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Incident 5 — repository authentication fails**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Incident 5 — repository authentication fails**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 5 — repository authentication fails** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Incident 6 — repo-server OOM

- Lesson anchor: Contain: reduce render concurrency if safe identify triggering Application/revision temporarily isolate pathological source restore sufficient replicas/resources Diagnose: manifest size directory recursion Helm/Kustomize expansion
- Beginner explanation: Restate **Incident 6 — repo-server OOM** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 6 — repo-server OOM** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident 6 — repo-server OOM**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident 6 — repo-server OOM**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 6 — repo-server OOM** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Incident 7 — one cluster is Unknown

- Lesson anchor: Trace: destination name/server → DNS → TCP 443 → TLS → AWS role assumption/token → EKS access entry → Kubernetes RBAC Check cluster connection and cache-age metrics. Do not delete the cluster registration until you know whether it is a transient target outage.
- Beginner explanation: Restate **Incident 7 — one cluster is Unknown** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 7 — one cluster is Unknown** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Incident 7 — one cluster is Unknown**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Incident 7 — one cluster is Unknown**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 7 — one cluster is Unknown** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Incident 8 — target says Forbidden

- Lesson anchor: Meaning: identity was understood but action was denied. Inspect: resource group/kind verb namespace EKS access-entry group/policy Role/ClusterRole RoleBinding/ClusterRoleBinding Grant the missing narrow permission. Never jump directly to cluster-admin.
- Beginner explanation: Restate **Incident 8 — target says Forbidden** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 8 — target says Forbidden** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Incident 8 — target says Forbidden**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Incident 8 — target says Forbidden**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 8 — target says Forbidden** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Incident 9 — sync is stuck Running

- Lesson anchor: Find: operation phase current hook phase earliest incomplete wave resource health message Common causes: PreSync Job pending early wave unhealthy hook fixed name collision finalizer resource deletion waiting Rollout intentionally paused
- Beginner explanation: Restate **Incident 9 — sync is stuck Running** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 9 — sync is stuck Running** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Incident 9 — sync is stuck Running**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Incident 9 — sync is stuck Running**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 9 — sync is stuck Running** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Incident 10 — migration hook failed

- Lesson anchor: Immediate actions: stop further release progression retain Job and logs check schema-history table determine whether transaction committed partially or fully confirm migration lock assess old application compatibility Retry only when idempotency and current...
- Beginner explanation: Restate **Incident 10 — migration hook failed** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 10 — migration hook failed** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident 10 — migration hook failed**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident 10 — migration hook failed**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 10 — migration hook failed** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Incident 11 — migration succeeded, new app failed

- Lesson anchor: Decision: Can old binary run against expanded schema? If yes: abort/revert application digest If no: roll forward may be safer than rollback This is why expand-and-contract and explicit migration classification are required.
- Beginner explanation: Restate **Incident 11 — migration succeeded, new app failed** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 11 — migration succeeded, new app failed** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Incident 11 — migration succeeded, new app failed**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Incident 11 — migration succeeded, new app failed**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 11 — migration succeeded, new app failed** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Incident 12 — Rollout paused unexpectedly

- Lesson anchor: Check: kubectl argo rollouts get rollout todo-api -n todo-prod kubectl describe rollout todo-api -n todo-prod Determine: intentional indefinite pause? timed pause still active? analysis running? progress deadline issue? operator abort?
- Beginner explanation: Restate **Incident 12 — Rollout paused unexpectedly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 12 — Rollout paused unexpectedly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident 12 — Rollout paused unexpectedly**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident 12 — Rollout paused unexpectedly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 12 — Rollout paused unexpectedly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Incident 13 — AnalysisRun failed

- Lesson anchor: Ask: Was customer behavior actually bad? Did query isolate canary? Was there enough traffic? Was result empty/NaN? Was Prometheus unavailable? Did successCondition match result shape? If the metric is correct, treat the failed gate as protection working.
- Beginner explanation: Restate **Incident 13 — AnalysisRun failed** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 13 — AnalysisRun failed** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Incident 13 — AnalysisRun failed**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Incident 13 — AnalysisRun failed**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 13 — AnalysisRun failed** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Incident 14 — canary abort did not restore service

- Lesson anchor: Possible reasons: stable revision also unhealthy database incompatibility traffic router not converged shared dependency failed cache/message side effect persists incident is unrelated to release Validate actual traffic and customer requests.
- Beginner explanation: Restate **Incident 14 — canary abort did not restore service** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 14 — canary abort did not restore service** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Incident 14 — canary abort did not restore service**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Incident 14 — canary abort did not restore service**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 14 — canary abort did not restore service** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Incident 15 — ExternalSecret not Ready

- Lesson anchor: Trace: ExternalSecret reference → SecretStore readiness → workload identity → provider endpoint/network → IAM authorization → secret key/property/version → target Kubernetes Secret Do not replace it with a plaintext Secret committed during the incident.
- Beginner explanation: Restate **Incident 15 — ExternalSecret not Ready** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 15 — ExternalSecret not Ready** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Incident 15 — ExternalSecret not Ready**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Incident 15 — ExternalSecret not Ready**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 15 — ExternalSecret not Ready** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Incident 16 — Secret updated, app still fails

- Lesson anchor: Check: target Secret resourceVersion changed? Pod consumes env var or mounted volume? reload controller exists? Pods restarted? database/server rotated too? old credential overlap/revocation timing? Provider rotation, Kubernetes refresh, and application rel...
- Beginner explanation: Restate **Incident 16 — Secret updated, app still fails** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 16 — Secret updated, app still fails** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident 16 — Secret updated, app still fails**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident 16 — Secret updated, app still fails**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 16 — Secret updated, app still fails** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Incident 17 — ApplicationSet wants mass deletion

- Lesson anchor: Contain immediately: stop generator change from merging if not merged pause/fence reconciliation according to runbook preserve ApplicationSet and generated Application state inspect generator inputs and deletion policy Common causes:
- Beginner explanation: Restate **Incident 17 — ApplicationSet wants mass deletion** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 17 — ApplicationSet wants mass deletion** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Incident 17 — ApplicationSet wants mass deletion**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Incident 17 — ApplicationSet wants mass deletion**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 17 — ApplicationSet wants mass deletion** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Incident 18 — workload generated in production accidentally

- Lesson anchor: Actions: stop unsafe sync/traffic identify cluster label or generator input change review AppProject boundary failure remove desired instance through authoritative generator fix inspect created resources and data audit actor and approvals
- Beginner explanation: Restate **Incident 18 — workload generated in production accidentally** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 18 — workload generated in production accidentally** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident 18 — workload generated in production accidentally**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident 18 — workload generated in production accidentally**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 18 — workload generated in production accidentally** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Incident 19 — resource pruned unexpectedly

- Lesson anchor: Ask: Was resource removed from Git? Did Application path change? Did Kustomize render stop including it? Did ApplicationSet delete an Application? Was tracking label/annotation changed? Who owns the resource? Restore desired declaration and data safely.
- Beginner explanation: Restate **Incident 19 — resource pruned unexpectedly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 19 — resource pruned unexpectedly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Incident 19 — resource pruned unexpectedly**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Incident 19 — resource pruned unexpectedly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 19 — resource pruned unexpectedly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Incident 20 — Application deletion stuck

- Lesson anchor: Inspect: Application finalizer PreDelete/PostDelete hook child resource finalizer unreachable target cluster RBAC deletion permission cloud-controller cleanup Removing a finalizer bypasses controller cleanup guarantees. Do it only with explicit understandin...
- Beginner explanation: Restate **Incident 20 — Application deletion stuck** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 20 — Application deletion stuck** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Incident 20 — Application deletion stuck**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Incident 20 — Application deletion stuck**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 20 — Application deletion stuck** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Incident 21 — webhook storm

- Lesson anchor: Symptoms: high webhook rate many refreshes repo-server/Redis load slow real reconciliation Actions: validate provider secret/signature configuration rate-limit at ingress/proxy identify source IP/provider event inspect repository filtering
- Beginner explanation: Restate **Incident 21 — webhook storm** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 21 — webhook storm** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Incident 21 — webhook storm**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Incident 21 — webhook storm**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 21 — webhook storm** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Incident 22 — Redis is lost

- Lesson anchor: Expected: cache disruption and repopulation Actions: restore supported Redis topology watch controller/server error rate allow cache warm-up monitor repo and target API load spike Do not attempt to reconstruct Applications from Redis.
- Beginner explanation: Restate **Incident 22 — Redis is lost** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 22 — Redis is lost** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident 22 — Redis is lost**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident 22 — Redis is lost**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 22 — Redis is lost** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Incident 23 — Argo management cluster lost

- Lesson anchor: Never activate a new controller without split-brain protection, and rehearse the documented export/import recovery path before an incident. ([Argo CD][10]) ---
- Beginner explanation: Restate **Incident 23 — Argo management cluster lost** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 23 — Argo management cluster lost** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Incident 23 — Argo management cluster lost**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Incident 23 — Argo management cluster lost**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 23 — Argo management cluster lost** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Incident 24 — Git provider unavailable

- Lesson anchor: Expected: running workloads continue new desired state unavailable render/compare errors may increase self-heal behavior may be limited by cached desired state and operation path Actions: stop nonessential sync attempts confirm provider incident
- Beginner explanation: Restate **Incident 24 — Git provider unavailable** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 24 — Git provider unavailable** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident 24 — Git provider unavailable**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident 24 — Git provider unavailable**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 24 — Git provider unavailable** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - Incident 25 — Git credential compromised

- Lesson anchor: Treat Git as production control-plane compromise. revoke credential freeze merges/deployments inspect commits, branches, tags, webhooks, rules, and audit logs identify every trusted repository verify live cluster state against last trusted revision
- Beginner explanation: Restate **Incident 25 — Git credential compromised** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 25 — Git credential compromised** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Incident 25 — Git credential compromised**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Incident 25 — Git credential compromised**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 25 — Git credential compromised** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Incident 26 — image tag was overwritten

- Lesson anchor: If Git stores a mutable tag: same desired text different runtime bytes Actions: capture running imageID/digest stop further pulls/rollout identify overwritten manifest restore verified digest rotate/revoke registry writer
- Beginner explanation: Restate **Incident 26 — image tag was overwritten** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 26 — image tag was overwritten** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Incident 26 — image tag was overwritten**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Incident 26 — image tag was overwritten**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 26 — image tag was overwritten** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Incident 27 — CI bot promotes wrong artifact

- Lesson anchor: Contain: pause/abort Rollout revert production config PR validate database/side effects revoke bot if compromise suspected preserve release.json and CI run Root causes may include: race/lost update wrong repository mapping
- Beginner explanation: Restate **Incident 27 — CI bot promotes wrong artifact** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 27 — CI bot promotes wrong artifact** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Incident 27 — CI bot promotes wrong artifact**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Incident 27 — CI bot promotes wrong artifact**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 27 — CI bot promotes wrong artifact** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Incident 28 — production drift was intentional hotfix

- Lesson anchor: The hotfix may be valid operationally but is still unrecorded desired state. Options: immediately encode the hotfix in Git or revert live state if the hotfix is no longer required If self-heal would erase a lifesaving temporary change, use a controlled paus...
- Beginner explanation: Restate **Incident 28 — production drift was intentional hotfix** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 28 — production drift was intentional hotfix** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Incident 28 — production drift was intentional hotfix**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Incident 28 — production drift was intentional hotfix**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 28 — production drift was intentional hotfix** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Incident 29 — DR cluster is Synced but unusable

- Lesson anchor: Check beyond Argo: image exists in DR registry secret and KMS work database is promotable and within RPO DNS/traffic failover works certificates cover DR endpoint third-party allowlists include DR egress capacity is available
- Beginner explanation: Restate **Incident 29 — DR cluster is Synced but unusable** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 29 — DR cluster is Synced but unusable** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Incident 29 — DR cluster is Synced but unusable**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Incident 29 — DR cluster is Synced but unusable**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 29 — DR cluster is Synced but unusable** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Incident 30 — alert did not fire

- Lesson anchor: Trace: metric exists → scrape succeeds → rule loaded → expression returns series → for duration elapsed → Alertmanager route matches → inhibition not suppressing incorrectly → receiver accepts → human receives For Argo Notifications, trace trigger → templat...
- Beginner explanation: Restate **Incident 30 — alert did not fire** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident 30 — alert did not fire** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident 30 — alert did not fire**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident 30 — alert did not fire**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident 30 — alert did not fire** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Post-incident GitOps review

- Lesson anchor: Ask: Did Git show the intended state? Did live state differ, and why? Which controller owned each mutation? Did automation reduce or amplify impact? Were credentials and boundaries appropriate? Did alerts detect customer risk early?
- Beginner explanation: Restate **Post-incident GitOps review** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Post-incident GitOps review** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Post-incident GitOps review**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Post-incident GitOps review**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Post-incident GitOps review** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Interview answer framework

- Lesson anchor: Use: DEFINITION → define the concept ARCHITECTURE → place it in the system TRADEOFF → state risk/cost PRODUCTION EXAMPLE → show implementation FAILURE MODE → show operational depth This creates answers that sound practiced because they are reasoned.
- Beginner explanation: Restate **Interview answer framework** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview answer framework** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview answer framework**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview answer framework**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview answer framework** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - Interview — What is GitOps?

- Lesson anchor: Strong answer: GitOps is an operating model where system state is declarative, versioned, automatically pulled by software agents, and continuously reconciled against actual state. For Kubernetes, Argo CD can implement that model by comparing manifests from...
- Beginner explanation: Restate **Interview — What is GitOps?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What is GitOps?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — What is GitOps?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — What is GitOps?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What is GitOps?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Interview — push vs pull delivery

- Lesson anchor: In push delivery, CI holds credentials and directly changes the target environment. In pull GitOps, CI builds an artifact and updates the desired configuration in Git; an in-environment or connected controller pulls that declaration and reconciles it. This...
- Beginner explanation: Restate **Interview — push vs pull delivery** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — push vs pull delivery** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — push vs pull delivery**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — push vs pull delivery**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — push vs pull delivery** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Interview — desired, live, sync, health

- Lesson anchor: desired state = rendered declaration from Git live state = Kubernetes objects observed now sync status = desired vs live equality health status = operational condition of resources Example: Synced + Degraded → Git matches Kubernetes, but workload is broken.
- Beginner explanation: Restate **Interview — desired, live, sync, health** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — desired, live, sync, health** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — desired, live, sync, health**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — desired, live, sync, health**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — desired, live, sync, health** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Interview — Argo architecture

- Lesson anchor: The API server provides UI/API and authentication; repo-server fetches sources and renders manifests; application-controller compares desired and live state and performs sync; ApplicationSet controller generates Applications; notifications controller evalua...
- Beginner explanation: Restate **Interview — Argo architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Argo architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — Argo architecture**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — Argo architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Argo architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Interview — Application CRD

- Lesson anchor: An Application connects a source to a destination under an AppProject. The source defines repository, revision, and path/chart; the destination defines cluster and namespace; sync policy controls automated behavior, pruning, self-heal, retry, and sync optio...
- Beginner explanation: Restate **Interview — Application CRD** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Application CRD** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — Application CRD**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — Application CRD**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Application CRD** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Interview — auto-sync, prune, self-heal

- Lesson anchor: auto-sync → apply new desired revisions automatically prune → remove tracked live resources absent from desired state self-heal → correct live drift even when Git revision did not change Each increases automation and therefore requires stronger Git controls...
- Beginner explanation: Restate **Interview — auto-sync, prune, self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — auto-sync, prune, self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — auto-sync, prune, self-heal**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — auto-sync, prune, self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — auto-sync, prune, self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Interview — Helm under Argo

- Lesson anchor: Argo uses Helm primarily as a manifest renderer through helm template; Argo, not Helm, owns the application reconciliation lifecycle. Values precedence, chart pinning, repository credentials, rendered diff, and hook mapping must be understood. I do not rely...
- Beginner explanation: Restate **Interview — Helm under Argo** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Helm under Argo** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — Helm under Argo**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — Helm under Argo**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Helm under Argo** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - Interview — Kustomize under Argo

- Lesson anchor: Kustomize composes a reusable base with environment overlays without a templating language. Argo runs the build and reconciles its output. I keep bases environment-neutral, overlays small, images immutable, remote references pinned, and validate the final r...
- Beginner explanation: Restate **Interview — Kustomize under Argo** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Kustomize under Argo** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Kustomize under Argo**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Kustomize under Argo**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Kustomize under Argo** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Interview — AppProject vs RBAC

- Lesson anchor: Argo RBAC controls what users or automation may do through Argo. AppProject constrains an Application's permitted source repositories, destination clusters/namespaces, and resource kinds. Target-cluster Kubernetes RBAC constrains what the Argo identity can...
- Beginner explanation: Restate **Interview — AppProject vs RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — AppProject vs RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — AppProject vs RBAC**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — AppProject vs RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — AppProject vs RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Interview — ApplicationSet vs App-of-Apps

- Lesson anchor: ApplicationSet generates multiple Applications from data such as cluster labels, Git directories, lists, or SCM resources. App-of-Apps is a parent Application whose manifests include child Application objects, useful for hierarchical bootstrap. ApplicationS...
- Beginner explanation: Restate **Interview — ApplicationSet vs App-of-Apps** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — ApplicationSet vs App-of-Apps** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — ApplicationSet vs App-of-Apps**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — ApplicationSet vs App-of-Apps**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — ApplicationSet vs App-of-Apps** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Interview — secrets in GitOps

- Lesson anchor: Git stores secret intent—the provider reference, target name, and mapping—not plaintext values. A destination-side operator such as External Secrets fetches the value from AWS Secrets Manager or Vault using workload identity and creates or mounts runtime ma...
- Beginner explanation: Restate **Interview — secrets in GitOps** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — secrets in GitOps** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — secrets in GitOps**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — secrets in GitOps**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — secrets in GitOps** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Interview — sync phases and waves

- Lesson anchor: Phases place work in PreSync, Sync, PostSync, or failure/deletion lifecycle stages. Waves order resources numerically within a phase. Phase precedence comes first, then wave, kind, and name. Argo waits for earlier wave health before progressing, and prune o...
- Beginner explanation: Restate **Interview — sync phases and waves** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — sync phases and waves** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — sync phases and waves**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — sync phases and waves**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — sync phases and waves** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Interview — safe database migrations

- Lesson anchor: I run a bounded, idempotent, locked migration Job using the same immutable release artifact and a separate schema identity. I use expand-and-contract so old and new binaries remain compatible during rollout and rollback. A failed migration blocks deployment...
- Beginner explanation: Restate **Interview — safe database migrations** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — safe database migrations** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — safe database migrations**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — safe database migrations**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — safe database migrations** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Interview — Argo Rollouts

- Lesson anchor: Argo CD deploys the Rollout CR; Argo Rollouts reconciles it into ReplicaSets, Services/traffic routing, pauses, analysis, promotion, and abort behavior. Canary limits initial blast radius and uses candidate-specific metrics. Blue/green prepares a preview re...
- Beginner explanation: Restate **Interview — Argo Rollouts** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Argo Rollouts** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Argo Rollouts**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Argo Rollouts**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Argo Rollouts** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Interview — multi-cluster EKS

- Lesson anchor: I choose central, per-cluster, or hybrid Argo by trust and failure domain. In the documented centralized EKS model, Argo uses a workload identity for a management IAM role, assumes a scoped target-cluster role, and authenticates through EKS; an access entry...
- Beginner explanation: Restate **Interview — multi-cluster EKS** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — multi-cluster EKS** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — multi-cluster EKS**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — multi-cluster EKS**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — multi-cluster EKS** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Interview — Argo HA and DR

- Lesson anchor: Argo is largely stateless: durable objects live in Kubernetes and Redis is a disposable cache. HA uses component-appropriate replicas, topology, Redis HA, and controller sharding. DR uses Git, recoverable secrets and IAM/network IaC, protected admin exports...
- Beginner explanation: Restate **Interview — Argo HA and DR** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Argo HA and DR** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — Argo HA and DR**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — Argo HA and DR**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Argo HA and DR** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - Interview — Argo observability

- Lesson anchor: I monitor Application sync and health, cluster connection and cache age, reconciliation latency, sync outcomes, repo-server rendering/resources, Redis, API availability, ApplicationSet generation, and notifications. I correlate metrics with Application stat...
- Beginner explanation: Restate **Interview — Argo observability** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Argo observability** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — Argo observability**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — Argo observability**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Argo observability** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Interview — CI with Argo

- Lesson anchor: CI builds, tests, scans, signs, and pushes one immutable image, then proposes a config-repository PR containing its digest. The same digest is promoted through environments. After merge, Argo reconciles it, so CI does not need production Kubernetes access a...
- Beginner explanation: Restate **Interview — CI with Argo** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — CI with Argo** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — CI with Argo**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — CI with Argo**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — CI with Argo** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Interview — biggest GitOps risks

- Lesson anchor: Strong answer: trusted Git compromise overly broad Argo or cluster credentials unsafe automatic pruning hidden multi-controller ownership plaintext or generation-time secrets mutable/unverified images mass ApplicationSet changes
- Beginner explanation: Restate **Interview — biggest GitOps risks** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — biggest GitOps risks** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — biggest GitOps risks**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — biggest GitOps risks**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — biggest GitOps risks** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Architecture decision — central vs decentralized

- Lesson anchor: Good decision statement: We selected a production-only central Argo control plane because it provides fleet visibility and consistent policy within one production trust domain. We separated non-production and regulated clusters
- Beginner explanation: Restate **Architecture decision — central vs decentralized** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture decision — central vs decentralized** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Architecture decision — central vs decentralized**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Architecture decision — central vs decentralized**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture decision — central vs decentralized** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Architecture decision — auto-sync in production

- Lesson anchor: Good answer: We enable auto-sync because the production branch already requires reviewed PRs, policy checks, immutable digests, and change controls, while Argo Rollouts limits traffic exposure. We retain sync windows and an emergency reconciliation pause. A...
- Beginner explanation: Restate **Architecture decision — auto-sync in production** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture decision — auto-sync in production** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Architecture decision — auto-sync in production**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Architecture decision — auto-sync in production**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture decision — auto-sync in production** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Architecture decision — one repo vs many

- Lesson anchor: Good answer: We separate application source from deployment configuration so build permissions do not imply production-config merge rights, audit history stays deployment-focused, and CI loops are avoided. We split platform and workload configuration becaus...
- Beginner explanation: Restate **Architecture decision — one repo vs many** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture decision — one repo vs many** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Architecture decision — one repo vs many**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Architecture decision — one repo vs many**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture decision — one repo vs many** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - Architecture decision — External Secrets

- Lesson anchor: Good answer: We chose destination-side External Secrets because actual values remain in the enterprise secret provider and rotate independently of Argo rendering. We use workload identity, namespaced stores or per-team roles, least-privilege provider ARNs,...
- Beginner explanation: Restate **Architecture decision — External Secrets** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture decision — External Secrets** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Architecture decision — External Secrets**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Architecture decision — External Secrets**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture decision — External Secrets** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Architecture decision — canary metrics

- Lesson anchor: Good answer: We gate on minimum candidate request volume, candidate-specific success rate, p95 latency, and a critical business signal. Empty data is not success. Provider failure behavior is explicit, and the stable revision remains schema-compatible durin...
- Beginner explanation: Restate **Architecture decision — canary metrics** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture decision — canary metrics** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Architecture decision — canary metrics**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Architecture decision — canary metrics**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture decision — canary metrics** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - Rapid fire — status meanings

- Lesson anchor: Synced → desired equals live OutOfSync → desired differs from live Healthy → resource health is good Degraded → resource reports unhealthy failure Progressing → resource is moving toward health or paused workflow state Missing
- Beginner explanation: Restate **Rapid fire — status meanings** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Rapid fire — status meanings** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Rapid fire — status meanings**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Rapid fire — status meanings**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Rapid fire — status meanings** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 62 - Rapid fire — ownership

- Lesson anchor: Git → desired declaration Argo CD → Git-to-Kubernetes reconciliation Kubernetes controller → runtime reconciliation External Secrets → secret materialization HPA → replica count when configured Argo Rollouts → progressive ReplicaSets/traffic
- Beginner explanation: Restate **Rapid fire — ownership** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Rapid fire — ownership** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Rapid fire — ownership**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Rapid fire — ownership**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Rapid fire — ownership** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 63 - Rapid fire — security boundaries

- Lesson anchor: branch protection → who can change desired state AppProject → what an Application may target/source/create Argo RBAC → what a user may do through Argo Kubernetes RBAC → what Argo may do in cluster IAM → AWS identity and role scope
- Beginner explanation: Restate **Rapid fire — security boundaries** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Rapid fire — security boundaries** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Rapid fire — security boundaries**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Rapid fire — security boundaries**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Rapid fire — security boundaries** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 64 - Rapid fire — release safety

- Lesson anchor: immutable digest reviewed promotion PR render/policy validation safe migration meaningful readiness canary blast-radius limit candidate-specific analysis Git rollback declaration customer SLO verification No single item is the complete strategy.
- Beginner explanation: Restate **Rapid fire — release safety** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Rapid fire — release safety** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Rapid fire — release safety**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Rapid fire — release safety**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Rapid fire — release safety** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 65 - Command sheet — Application

- Lesson anchor: argocd app list argocd app get <app argocd app diff <app argocd app sync <app argocd app wait <app --sync --health --operation argocd app history <app argocd app resources <app argocd app terminate-op <app Know what each command mutates before using it in p...
- Beginner explanation: Restate **Command sheet — Application** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Command sheet — Application** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Command sheet — Application**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Command sheet — Application**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Command sheet — Application** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 66 - Command sheet — cluster and repository

- Lesson anchor: argocd cluster list argocd cluster get <server-or-name argocd repo list argocd repo get <repo-url kubectl get secret -n argocd \ -l argocd.argoproj.io/secret-type=cluster kubectl get secret -n argocd \ -l argocd.argoproj.io/secret-type=repository
- Beginner explanation: Restate **Command sheet — cluster and repository** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Command sheet — cluster and repository** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Command sheet — cluster and repository**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Command sheet — cluster and repository**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Command sheet — cluster and repository** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 67 - Command sheet — Rollouts and secrets

- Lesson anchor: kubectl argo rollouts get rollout <name -n <namespace --watch kubectl argo rollouts promote <name -n <namespace kubectl argo rollouts abort <name -n <namespace kubectl get analysisrun -n <namespace kubectl get externalsecret,secretstore -n <namespace
- Beginner explanation: Restate **Command sheet — Rollouts and secrets** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Command sheet — Rollouts and secrets** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Command sheet — Rollouts and secrets**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Command sheet — Rollouts and secrets**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Command sheet — Rollouts and secrets** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 68 - Command sheet — rendering

- Lesson anchor: helm template <release <chart -f <values kustomize build <overlay kubectl apply --dry-run=server -f <rendered-file argocd app manifests <app Render exactly the source revision, tool version, values, and environment that Argo uses.
- Beginner explanation: Restate **Command sheet — rendering** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Command sheet — rendering** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Command sheet — rendering**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Command sheet — rendering**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Command sheet — rendering** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 69 - Ten diagrams to remember

- Lesson anchor: If these are clear, most details have a place. ---
- Beginner explanation: Restate **Ten diagrams to remember** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Ten diagrams to remember** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Ten diagrams to remember**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Ten diagrams to remember**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Ten diagrams to remember** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 70 - Fifty never-forget rules

- Lesson anchor: ---
- Beginner explanation: Restate **Fifty never-forget rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Fifty never-forget rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Fifty never-forget rules**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Fifty never-forget rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Fifty never-forget rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 71 - Final production readiness checklist

- Lesson anchor: □ Source and config ownership are explicit □ Production branch is protected □ CODEOWNERS is enforced □ Bots cannot self-approve □ Audit logs and MFA are enabled □ Remote chart/base references are pinned □ Image digest is immutable
- Beginner explanation: Restate **Final production readiness checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Final production readiness checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Final production readiness checklist**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Final production readiness checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Final production readiness checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 72 - Final troubleshooting mnemonic

- Lesson anchor: For the whole module, memorize: GIT ↓ RENDER ↓ APPLICATION ↓ CLUSTER ↓ EXECUTION ↓ DEPENDENCY / DATA Examples: wrong image digest → GIT Helm template fails → RENDER sync policy/window blocks → APPLICATION EKS API timeout
- Beginner explanation: Restate **Final troubleshooting mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Final troubleshooting mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Final troubleshooting mnemonic**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Final troubleshooting mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Final troubleshooting mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 73 - Final interview closing answer

- Lesson anchor: If asked: How would you design production GitOps on EKS? Answer: I separate application source, platform configuration, and workload promotion according to ownership. CI uses short-lived identity to build, test, scan, attest, and publish one immutable ECR d...
- Beginner explanation: Restate **Final interview closing answer** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Final interview closing answer** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Final interview closing answer**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Final interview closing answer**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Final interview closing answer** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - The first five minutes x business value

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **The first five minutes** while a change involving **Universal triage commands** places **business value** at risk.
- Plain-language question: What problem does **The first five minutes** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not begin with random restarts. ---
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **The first five minutes** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Incident command principles x latency

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident command principles** while a change involving **Incident 7 — one cluster is Unknown** places **latency** at risk.
- Plain-language question: What problem does **Incident command principles** solve here, and who notices first when it fails?
- Lesson evidence anchor: one incident commander one operations lead one communications lead UTC timeline explicit hypotheses reversible changes first one authoritative desired state evidence preserved GitOps improves auditability only if emergency actions are recorded.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident command principles** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Classification x privacy

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Classification** while a change involving **Incident 14 — canary abort did not restore service** places **privacy** at risk.
- Plain-language question: What problem does **Classification** solve here, and who notices first when it fails?
- Lesson evidence anchor: CONTROL-PLANE INCIDENT Argo/API/render/cache unavailable RECONCILIATION INCIDENT desired state cannot converge RELEASE INCIDENT new revision harms service TARGET-CLUSTER INCIDENT Kubernetes API or infrastructure fails DEPENDENCY INCIDENT
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Classification** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Universal triage commands x operability

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Universal triage commands** while a change involving **Incident 21 — webhook storm** places **operability** at risk.
- Plain-language question: What problem does **Universal triage commands** solve here, and who notices first when it fails?
- Lesson evidence anchor: argocd app get <app --show-operation argocd app diff <app argocd app history <app argocd app resources <app kubectl get application <app -n argocd -o yaml kubectl get events -n argocd --sort-by=.metadata.creationTimestamp
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Universal triage commands** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Incident 1 — Argo UI is unavailable x data integrity

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 1 — Argo UI is unavailable** while a change involving **Incident 28 — production drift was intentional hotfix** places **data integrity** at risk.
- Plain-language question: What problem does **Incident 1 — Argo UI is unavailable** solve here, and who notices first when it fails?
- Lesson evidence anchor: Impact may be: operators cannot use UI/CLI API while reconciliation continues. Check: argocd-server Pods and readiness Service endpoints Ingress/load balancer TLS certificate SSO/IdP DNS Confirm application-controller health separately.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 1 — Argo UI is unavailable** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Incident 2 — Application remains OutOfSync x automation safety

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 2 — Application remains OutOfSync** while a change involving **Interview — desired, live, sync, health** places **automation safety** at risk.
- Plain-language question: What problem does **Incident 2 — Application remains OutOfSync** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check exact diff. Possible causes: new Git revision awaiting manual sync sync window denied auto-sync disabled manual drift mutating admission/controller field shared-resource ownership conflict apply failure Correct the owner.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 2 — Application remains OutOfSync** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Incident 3 — self-heal loop x governance

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 3 — self-heal loop** while a change involving **Interview — ApplicationSet vs App-of-Apps** places **governance** at risk.
- Plain-language question: What problem does **Incident 3 — self-heal loop** solve here, and who notices first when it fails?
- Lesson evidence anchor: Symptoms: Argo applies field A another controller changes field A Argo applies field A again Actions: identify exact JSON path inspect managedFields establish authoritative controller change Git or add narrow ignore rule
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 3 — self-heal loop** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Incident 4 — comparison error x correctness

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 4 — comparison error** while a change involving **Interview — Argo observability** places **correctness** at risk.
- Plain-language question: What problem does **Incident 4 — comparison error** solve here, and who notices first when it fails?
- Lesson evidence anchor: Symptoms: ComparisonError manifest generation error unable to load target state Trace: repo URL and revision repository credential Git/Helm/OCI reachability render command dependency version plugin logs timeout/memory/disk
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 4 — comparison error** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Incident 5 — repository authentication fails x capacity

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 5 — repository authentication fails** while a change involving **Architecture decision — canary metrics** places **capacity** at risk.
- Plain-language question: What problem does **Incident 5 — repository authentication fails** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: credential Secret and project scope GitHub App installation/repository access SSH host key token expiry/revocation HTTPS/SSH URL match CA certificate egress proxy Rotate compromised or expired credentials through the secret system.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 5 — repository authentication fails** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Incident 6 — repo-server OOM x cost efficiency

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 6 — repo-server OOM** while a change involving **Command sheet — Rollouts and secrets** places **cost efficiency** at risk.
- Plain-language question: What problem does **Incident 6 — repo-server OOM** solve here, and who notices first when it fails?
- Lesson evidence anchor: Contain: reduce render concurrency if safe identify triggering Application/revision temporarily isolate pathological source restore sufficient replicas/resources Diagnose: manifest size directory recursion Helm/Kustomize expansion
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 6 — repo-server OOM** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Incident 7 — one cluster is Unknown x recovery

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 7 — one cluster is Unknown** while a change involving **The first five minutes** places **recovery** at risk.
- Plain-language question: What problem does **Incident 7 — one cluster is Unknown** solve here, and who notices first when it fails?
- Lesson evidence anchor: Trace: destination name/server → DNS → TCP 443 → TLS → AWS role assumption/token → EKS access entry → Kubernetes RBAC Check cluster connection and cache-age metrics. Do not delete the cluster registration until you know whether it is a transient target outage.
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 7 — one cluster is Unknown** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Incident 8 — target says Forbidden x change management

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 8 — target says Forbidden** while a change involving **Incident 4 — comparison error** places **change management** at risk.
- Plain-language question: What problem does **Incident 8 — target says Forbidden** solve here, and who notices first when it fails?
- Lesson evidence anchor: Meaning: identity was understood but action was denied. Inspect: resource group/kind verb namespace EKS access-entry group/policy Role/ClusterRole RoleBinding/ClusterRoleBinding Grant the missing narrow permission. Never jump directly to cluster-admin.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 8 — target says Forbidden** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Incident 9 — sync is stuck Running x dependency failure

- Learning level: Certification review.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 9 — sync is stuck Running** while a change involving **Incident 11 — migration succeeded, new app failed** places **dependency failure** at risk.
- Plain-language question: What problem does **Incident 9 — sync is stuck Running** solve here, and who notices first when it fails?
- Lesson evidence anchor: Find: operation phase current hook phase earliest incomplete wave resource health message Common causes: PreSync Job pending early wave unhealthy hook fixed name collision finalizer resource deletion waiting Rollout intentionally paused
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 9 — sync is stuck Running** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Incident 10 — migration hook failed x developer experience

- Learning level: Interview defense.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 10 — migration hook failed** while a change involving **Incident 18 — workload generated in production accidentally** places **developer experience** at risk.
- Plain-language question: What problem does **Incident 10 — migration hook failed** solve here, and who notices first when it fails?
- Lesson evidence anchor: Immediate actions: stop further release progression retain Job and logs check schema-history table determine whether transaction committed partially or fully confirm migration lock assess old application compatibility Retry only when idempotency and current...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 10 — migration hook failed** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Incident 11 — migration succeeded, new app failed x availability

- Learning level: Beginner.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 11 — migration succeeded, new app failed** while a change involving **Incident 25 — Git credential compromised** places **availability** at risk.
- Plain-language question: What problem does **Incident 11 — migration succeeded, new app failed** solve here, and who notices first when it fails?
- Lesson evidence anchor: Decision: Can old binary run against expanded schema? If yes: abort/revert application digest If no: roll forward may be safer than rollback This is why expand-and-contract and explicit migration classification are required.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 11 — migration succeeded, new app failed** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Incident 12 — Rollout paused unexpectedly x security

- Learning level: Intermediate.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 12 — Rollout paused unexpectedly** while a change involving **Interview answer framework** places **security** at risk.
- Plain-language question: What problem does **Incident 12 — Rollout paused unexpectedly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: kubectl argo rollouts get rollout todo-api -n todo-prod kubectl describe rollout todo-api -n todo-prod Determine: intentional indefinite pause? timed pause still active? analysis running? progress deadline issue? operator abort?
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 12 — Rollout paused unexpectedly** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Incident 13 — AnalysisRun failed x delivery safety

- Learning level: Expert.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 13 — AnalysisRun failed** while a change involving **Interview — Helm under Argo** places **delivery safety** at risk.
- Plain-language question: What problem does **Incident 13 — AnalysisRun failed** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask: Was customer behavior actually bad? Did query isolate canary? Was there enough traffic? Was result empty/NaN? Was Prometheus unavailable? Did successCondition match result shape? If the metric is correct, treat the failed gate as protection working.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 13 — AnalysisRun failed** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Incident 14 — canary abort did not restore service x multi-tenancy

- Learning level: Professional.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 14 — canary abort did not restore service** while a change involving **Interview — Argo Rollouts** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Incident 14 — canary abort did not restore service** solve here, and who notices first when it fails?
- Lesson evidence anchor: Possible reasons: stable revision also unhealthy database incompatibility traffic router not converged shared dependency failed cache/message side effect persists incident is unrelated to release Validate actual traffic and customer requests.
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 14 — canary abort did not restore service** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Incident 15 — ExternalSecret not Ready x observability

- Learning level: Industry-ready.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 15 — ExternalSecret not Ready** while a change involving **Architecture decision — auto-sync in production** places **observability** at risk.
- Plain-language question: What problem does **Incident 15 — ExternalSecret not Ready** solve here, and who notices first when it fails?
- Lesson evidence anchor: Trace: ExternalSecret reference → SecretStore readiness → workload identity → provider endpoint/network → IAM authorization → secret key/property/version → target Kubernetes Secret Do not replace it with a plaintext Secret committed during the incident.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 15 — ExternalSecret not Ready** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Incident 16 — Secret updated, app still fails x regional resilience

- Learning level: Certification review.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 16 — Secret updated, app still fails** while a change involving **Rapid fire — release safety** places **regional resilience** at risk.
- Plain-language question: What problem does **Incident 16 — Secret updated, app still fails** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: target Secret resourceVersion changed? Pod consumes env var or mounted volume? reload controller exists? Pods restarted? database/server rotated too? old credential overlap/revocation timing? Provider rotation, Kubernetes refresh, and application rel...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 16 — Secret updated, app still fails** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Incident 17 — ApplicationSet wants mass deletion x business value

- Learning level: Interview defense.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 17 — ApplicationSet wants mass deletion** while a change involving **Final production readiness checklist** places **business value** at risk.
- Plain-language question: What problem does **Incident 17 — ApplicationSet wants mass deletion** solve here, and who notices first when it fails?
- Lesson evidence anchor: Contain immediately: stop generator change from merging if not merged pause/fence reconciliation according to runbook preserve ApplicationSet and generated Application state inspect generator inputs and deletion policy Common causes:
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 17 — ApplicationSet wants mass deletion** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Incident 18 — workload generated in production accidentally x latency

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 18 — workload generated in production accidentally** while a change involving **Incident 1 — Argo UI is unavailable** places **latency** at risk.
- Plain-language question: What problem does **Incident 18 — workload generated in production accidentally** solve here, and who notices first when it fails?
- Lesson evidence anchor: Actions: stop unsafe sync/traffic identify cluster label or generator input change review AppProject boundary failure remove desired instance through authoritative generator fix inspect created resources and data audit actor and approvals
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 18 — workload generated in production accidentally** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Incident 19 — resource pruned unexpectedly x privacy

- Learning level: Intermediate.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 19 — resource pruned unexpectedly** while a change involving **Incident 8 — target says Forbidden** places **privacy** at risk.
- Plain-language question: What problem does **Incident 19 — resource pruned unexpectedly** solve here, and who notices first when it fails?
- Lesson evidence anchor: Ask: Was resource removed from Git? Did Application path change? Did Kustomize render stop including it? Did ApplicationSet delete an Application? Was tracking label/annotation changed? Who owns the resource? Restore desired declaration and data safely.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 19 — resource pruned unexpectedly** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Incident 20 — Application deletion stuck x operability

- Learning level: Expert.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 20 — Application deletion stuck** while a change involving **Incident 15 — ExternalSecret not Ready** places **operability** at risk.
- Plain-language question: What problem does **Incident 20 — Application deletion stuck** solve here, and who notices first when it fails?
- Lesson evidence anchor: Inspect: Application finalizer PreDelete/PostDelete hook child resource finalizer unreachable target cluster RBAC deletion permission cloud-controller cleanup Removing a finalizer bypasses controller cleanup guarantees. Do it only with explicit understandin...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 20 — Application deletion stuck** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Incident 21 — webhook storm x data integrity

- Learning level: Professional.
- Environment: a production canary with an approved change window.
- Scenario: The team must apply **Incident 21 — webhook storm** while a change involving **Incident 22 — Redis is lost** places **data integrity** at risk.
- Plain-language question: What problem does **Incident 21 — webhook storm** solve here, and who notices first when it fails?
- Lesson evidence anchor: Symptoms: high webhook rate many refreshes repo-server/Redis load slow real reconciliation Actions: validate provider secret/signature configuration rate-limit at ingress/proxy identify source IP/provider event inspect repository filtering
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 21 — webhook storm** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Incident 22 — Redis is lost x automation safety

- Learning level: Industry-ready.
- Environment: a security and audit review.
- Scenario: The team must apply **Incident 22 — Redis is lost** while a change involving **Incident 29 — DR cluster is Synced but unusable** places **automation safety** at risk.
- Plain-language question: What problem does **Incident 22 — Redis is lost** solve here, and who notices first when it fails?
- Lesson evidence anchor: Expected: cache disruption and repopulation Actions: restore supported Redis topology watch controller/server error rate allow cache warm-up monitor repo and target API load spike Do not attempt to reconstruct Applications from Redis.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
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
- Interview prompt: Defend **Incident 22 — Redis is lost** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 26.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://opengitops.dev/ "OpenGitOps Principles"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/ "Argo CD Architecture"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/ "Secret Management - Argo CD"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ "Sync Phases and Waves - Argo CD"
[5]: https://argo-rollouts.readthedocs.io/en/stable/ "Argo Rollouts"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#eks "EKS Cluster Setup - Argo CD"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/ "High Availability - Argo CD"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/ "Metrics - Argo CD"
[9]: https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/ "Automation from CI Pipelines - Argo CD"
[10]: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/ "Disaster Recovery - Argo CD"
