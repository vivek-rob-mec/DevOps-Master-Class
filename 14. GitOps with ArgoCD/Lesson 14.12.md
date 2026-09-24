# Module 14 — GitOps with Argo CD

## Lesson 12: Sync Waves, Resource Hooks, Database Migrations & Dependency Ordering

Our Git repository now contains the complete desired state.

But a production release is not always safe to apply as one unordered group.

The Todo platform may require:

```text
Namespace
   ↓
ExternalSecret
   ↓
database migration
   ↓
backend
   ↓
frontend
   ↓
smoke test
```

Argo CD gives us two related ordering tools:

```text
SYNC PHASES
= lifecycle stage

SYNC WAVES
= order inside a stage
```

The production goal is not merely:

```text
all objects were submitted to Kubernetes
```

It is:

```text
each dependency became ready
before its consumer progressed.
```

Argo CD documents hook phases for work before, during, after, or on failure of a sync, and sync waves for integer-based ordering. It orders by phase, then wave, then kind, then name, and proceeds from the first out-of-sync or unhealthy wave until the Application is synchronized and healthy. ([Argo CD][1])

---

# 14.1536 Why Kubernetes apply order is not enough

Imagine these resources are rendered together:

```text
CustomResourceDefinition
Controller Deployment
Custom Resource
Application Deployment
Migration Job
Service
```

Kubernetes accepts many independent API requests quickly.

But API acceptance does not mean runtime readiness.

```text
Deployment created
≠
Pods Ready

CRD created
≠
controller Ready

Secret object requested
≠
secret value available
```

That gap is where ordering failures appear.

---

# 14.1537 Dependency vs ordering

An order is:

```text
A is submitted before B.
```

A dependency is stronger:

```text
B must not proceed
until A has reached a usable state.
```

Production design must ask both:

```text
What must be created first?

What must be healthy first?
```

---

# 14.1538 The two axes

Use this mental model:

```text
PHASE
  │
  ├── PreSync
  ├── Sync
  ├── PostSync
  └── SyncFail

WAVE
  │
  ├── -20
  ├── -10
  ├── 0
  └── 10
```

A phase answers:

> At which lifecycle point does this run?

A wave answers:

> In what relative order does it run within that lifecycle point?

---

# 14.1539 Hook phases

The principal sync hook types are:

```text
PreSync
Sync
PostSync
SyncFail
Skip
```

Application-deletion hooks also exist:

```text
PreDelete
PostDelete
```

`PreDelete` is for deletion of the whole Application, not ordinary pruning during a sync. `PostDelete` runs after Application resources have been deleted. ([Argo CD][1])

---

# 14.1540 PreSync

`PreSync` executes before ordinary synchronization.

Good examples:

```text
schema compatibility check

database migration

backup validation

external dependency preflight

change-ticket verification
```

If a `PreSync` hook fails:

```text
main sync stops
```

This makes it a deployment gate.

---

# 14.1541 Sync

A `Sync` hook runs during the main sync phase.

Most ordinary manifests are not hooks at all; they naturally belong to the Sync phase.

Use a `Sync` hook only when a resource has operation-like lifecycle semantics during the main application step.

Do not annotate everything as a hook.

---

# 14.1542 PostSync

`PostSync` executes only after:

```text
Sync resources succeeded

and

Application resources are Healthy.
```

Good examples:

```text
smoke test

synthetic transaction

post-deployment verification

release notification
```

A Deployment existing is not enough. Health gating is the important property.

---

# 14.1543 SyncFail

`SyncFail` runs when synchronization fails.

Good uses:

```text
capture diagnostics

send failure event

remove temporary test data

record failed release metadata
```

Bad assumption:

```text
SyncFail automatically rolls back everything.
```

It does not.

A rollback must itself be deliberately designed and must respect database and external-system safety.

---

# 14.1544 Skip

`Skip` tells Argo CD not to apply a rendered manifest.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: Skip
```

Use it only for a known render-time artifact that another controller or process must own.

Overusing `Skip` creates invisible ownership gaps.

---

# 14.1545 PreDelete and PostDelete

Deletion can also require workflow behavior.

Examples:

```text
PreDelete
→ verify final backup

PostDelete
→ de-register external DNS entry
→ notify service catalog
```

Be extremely careful.

A failing `PreDelete` hook can intentionally block Application deletion. A failing `PostDelete` hook occurs after managed resources are already gone, so it cannot restore them. ([Argo CD][1])

---

# 14.1546 Hook annotation

Basic form:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
```

Multiple types may be comma-separated, but simple, single-purpose lifecycle design is easier to reason about.

Hooks can technically be many Kubernetes kinds.

Operational hooks are commonly:

```text
Job
Pod
Argo Workflow
```

---

# 14.1547 Why Jobs are normally best

A migration has completion semantics:

```text
start
  ↓
run once
  ↓
succeed or fail
  ↓
terminate
```

That maps naturally to a Kubernetes Job.

A Deployment has steady-state semantics and is therefore a poor fit for most one-time hooks.

---

# 14.1548 Hook naming strategy

Two common patterns exist.

Fixed name:

```yaml
metadata:
  name: todo-db-migrate
```

Generated name:

```yaml
metadata:
  generateName: todo-db-migrate-
```

Fixed names normally pair with:

```text
BeforeHookCreation
```

Generated names create distinct history but require cleanup controls.

---

# 14.1549 Hook deletion policies

Argo CD supports:

```text
HookSucceeded
HookFailed
BeforeHookCreation
```

Example:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Meaning:

```text
delete the hook resource
after successful completion.
```

Without an explicit policy, Argo CD assumes `BeforeHookCreation`. ([Argo CD][1])

---

# 14.1550 Retain failure evidence

This combination is common:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Successful Jobs disappear.

Failed Jobs remain available for:

```bash
kubectl describe job todo-db-migrate -n todo-prod

kubectl logs job/todo-db-migrate -n todo-prod
```

Then Kubernetes TTL or an operational cleanup process can remove old evidence later.

---

# 14.1551 Kubernetes TTL is separate

```yaml
spec:
  ttlSecondsAfterFinished: 3600
```

This is Kubernetes Job cleanup.

```text
Argo hook-delete-policy
= hook lifecycle decision

Job TTL
= Kubernetes cleanup timer
```

They can be used together, but they are not the same controller behavior. ([Kubernetes][2])

---

# 14.1552 Sync wave annotation

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
```

Rules:

```text
integer stored as a string

lower number first

negative values allowed

default wave = 0
```

---

# 14.1553 Production phase and wave map

Our Todo architecture will use two lifecycle boundaries:

```text
FOUNDATION APPLICATION
continuously reconciled before workload releases

-20  namespace and foundational policy

-10  secret references and configuration


WORKLOAD APPLICATION

PreSync wave -5  migration hook

Sync wave 0      backend workload and Service

Sync wave 10     frontend workload and Service

Sync wave 20     ingress

PostSync wave 0  smoke test
```

The exact numbers are less important than a documented, sparse convention.

Leave gaps so future dependencies can be inserted.

---

# 14.1554 Effective ordering algorithm

Argo CD uses this precedence:

```text
1. phase
2. wave
3. Kubernetes kind
4. resource name
```

Therefore:

```text
PreSync wave 100
```

still runs before:

```text
Sync wave -100
```

Phase is the stronger boundary. ([Argo CD][1])

---

# 14.1555 Waves are health-gated

Argo CD finds the first wave containing an out-of-sync or unhealthy resource, applies it, and repeats.

This is powerful:

```text
wave -10 Secret not ready
        │
        ▼
wave 0 backend does not progress
```

It can also deadlock progress:

```text
early wave permanently unhealthy
        │
        ▼
later waves never begin.
```

---

# 14.1556 Wave delay

Argo CD includes a short delay between waves so other controllers can react and health is not assessed against immediately stale state.

It is controlled by:

```text
ARGOCD_SYNC_WAVE_DELAY
```

The documented default is two seconds. Changing it is a control-plane tuning decision, not a substitute for correct readiness and health behavior. ([Argo CD][1])

---

# 14.1557 Build the namespace wave

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: todo-prod
  annotations:
    argocd.argoproj.io/sync-wave: "-20"
  labels:
    environment: production
    owner: todo-team
```

If the Application uses:

```yaml
syncOptions:
  - CreateNamespace=true
```

then Argo may create the destination namespace without a manifest.

Use an explicit Namespace when Git must own labels, policy metadata, or ordering.

---

# 14.1558 Secret intent wave

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: todo-database
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: todo-prod
    kind: SecretStore
  target:
    name: todo-database
  data:
    - secretKey: url
      remoteRef:
        key: /production/todo/database
        property: url
```

This belongs naturally in a long-lived foundation Application. If it is an ordinary Sync resource in the same Application as a `PreSync` migration, its negative wave does **not** make it run before that migration; phase precedence still wins.

Important caveat:

```text
ExternalSecret Healthy
```

must accurately represent that the target Secret is ready, or the later migration may start too early.

---

# 14.1559 Complete migration Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: todo-db-migrate
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-5"
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  backoffLimit: 1
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 86400
  template:
    metadata:
      labels:
        app.kubernetes.io/name: todo-db-migrate
    spec:
      restartPolicy: Never
      serviceAccountName: todo-migrator
      containers:
        - name: migrate
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api@sha256:REPLACE_ME
          imagePullPolicy: IfNotPresent
          command: ["/app/todo-api"]
          args: ["migrate", "up"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: todo-database
                  key: url
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop: ["ALL"]
```

This is a realistic starting point, not a universal database recipe.

---

# 14.1560 Read the migration Job as English

```text
Before the main sync:

run the exact release artifact

with the production database reference

retry at most once

time out after ten minutes

delete on success

retain failure long enough to investigate.
```

The migration image should normally be tied to the same immutable release as the application.

---

# 14.1561 Never use `latest` for a migration

Bad:

```yaml
image: todo-api:latest
```

Why?

```text
Git revision says one thing

registry tag later moves

hook retry runs different code
```

Use an immutable digest:

```yaml
image: todo-api@sha256:...
```

or enforce immutable release tags.

---

# 14.1562 Idempotency

A migration may be retried because of:

```text
controller restart

network timeout

operator retry

uncertain client response
```

Therefore migration execution must tolerate repetition.

Good migration systems record applied versions in a schema-history table.

Permanent rule:

> **A retry must not corrupt a database that already accepted the first attempt.**

---

# 14.1563 Expand-and-contract schema changes

The safest database release pattern is:

```text
Release A
EXPAND schema
add new nullable column / table / index
        │
        ▼
Release B
application reads/writes compatible forms
        │
        ▼
backfill
        │
        ▼
Release C
CONTRACT
remove obsolete schema only after old code is gone
```

This avoids making rollback impossible the moment the migration runs.

---

# 14.1564 The destructive migration trap

Suppose version 42 immediately runs:

```sql
ALTER TABLE todos DROP COLUMN legacy_status;
```

Then the application fails and you restore version 41.

Version 41 still expects:

```text
legacy_status
```

The container rollback succeeds.

The service still fails.

Therefore:

```text
application rollback
≠
database rollback.
```

---

# 14.1565 Backward compatibility window

During a progressive or rolling release, old and new Pods may coexist.

The schema must support:

```text
old application version

and

new application version
```

for the entire overlap window.

This is why expand-and-contract is part of deployment engineering, not merely database administration.

---

# 14.1566 Migration lock

Multiple Argo instances, manual jobs, or retried workflows could attempt the same migration.

Use the migration framework or database to provide:

```text
advisory lock

schema-history lock

single-writer guarantee
```

GitOps ordering inside one Application cannot prevent every external actor from running the same command.

---

# 14.1567 Migration identity

The normal application may need:

```text
SELECT
INSERT
UPDATE
DELETE
```

The migrator may need:

```text
ALTER
CREATE INDEX
CREATE TABLE
```

Do not automatically give normal runtime Pods schema-owner privileges.

Use a separate database identity and separate Kubernetes Secret where possible.

---

# 14.1568 Backend wave

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-api
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: todo-api
  template:
    metadata:
      labels:
        app: todo-api
    spec:
      containers:
        - name: api
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api@sha256:REPLACE_ME
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            failureThreshold: 6
```

Wave progression depends on meaningful health.

Readiness must test whether the Pod can safely receive traffic.

---

# 14.1569 Frontend wave

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-web
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: todo-web
  template:
    metadata:
      labels:
        app: todo-web
    spec:
      containers:
        - name: web
          image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-web@sha256:REPLACE_ME
          ports:
            - name: http
              containerPort: 8080
```

This is useful only if frontend deployment genuinely depends on backend health.

Do not create ceremonial waves with no operational meaning.

---

# 14.1570 PostSync smoke test

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: todo-smoke-
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  backoffLimit: 2
  activeDeadlineSeconds: 180
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: smoke
          image: curlimages/curl:8.14.1
          args:
            - --fail
            - --silent
            - --show-error
            - --retry
            - "5"
            - http://todo-api.todo-prod.svc.cluster.local:8080/health
```

For a reproducible production system, pin even small operational images to a verified digest.

---

# 14.1571 What a smoke test should prove

Weak:

```text
TCP port opened.
```

Stronger:

```text
service discovery works

request reaches a ready Pod

application handler executes

critical dependency is reachable

response satisfies expected contract
```

Do not make a smoke test destructive unless it creates and cleans isolated test data safely.

---

# 14.1572 What PostSync failure means

If the smoke test fails:

```text
sync operation = Failed
```

But ordinary resources may already be deployed.

Therefore a PostSync hook is:

```text
detection and release gating
```

not guaranteed transactional rollback.

Kubernetes and Argo CD do not provide a database-and-cluster ACID transaction.

---

# 14.1573 SyncFail diagnostic hook

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: todo-sync-failure-
  namespace: todo-prod
  annotations:
    argocd.argoproj.io/hook: SyncFail
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: release-diagnostics
      containers:
        - name: recorder
          image: registry.example.com/platform/release-recorder@sha256:REPLACE_ME
          args: ["record", "--application=todo-prod", "--result=failed"]
```

Give this ServiceAccount only the access it actually requires.

Do not make a failure hook a hidden cluster-admin shell.

---

# 14.1574 CRD ordering

Typical dependency:

```text
CRD
 ↓
controller
 ↓
custom resource
```

Argo has built-in kind ordering that helps create namespaces and CRDs before many dependent objects.

But:

```text
CRD accepted
≠
controller ready to reconcile custom resource.
```

For platform add-ons, separate Applications and health-aware orchestration can be clearer than hundreds of waves in one Application.

---

# 14.1575 The CRD upgrade problem

CRDs are cluster-scoped APIs shared by all consumers.

An upgrade can affect:

```text
every namespace

every custom resource

every team using the API
```

Treat CRD changes as platform changes.

Validate:

```text
storedVersions

conversion webhooks

backward compatibility

controller version skew

rollback procedure
```

---

# 14.1576 Helm hooks under Argo CD

Argo CD renders Helm charts with `helm template`; it does not use Helm as the release controller.

Argo maps supported Helm hook annotations to Argo hook behavior—for example `pre-install` and `pre-upgrade` map to `PreSync`, while `post-install` and `post-upgrade` map to `PostSync`. Argo's documentation also warns that if you define Argo CD hooks, Helm hooks are ignored. ([Argo CD][3])

Permanent rule:

```text
When Argo deploys a Helm chart,
reason about the Argo sync operation.
```

---

# 14.1577 Helm install vs upgrade ambiguity

Argo CD does not preserve Helm's release-state model.

Therefore Argo cannot reliably distinguish:

```text
first install
```

from:

```text
upgrade
```

in the way a normal `helm install` / `helm upgrade` workflow does.

Design chart hooks to be idempotent and compatible with both situations.

---

# 14.1578 Selective sync danger

Argo CD documents that hooks do not run during selective sync. ([Argo CD][1])

Suppose an operator selectively syncs only:

```text
Deployment/todo-api
```

The required migration hook may be bypassed.

Production rule:

> **Do not use selective sync to bypass a release dependency graph.**

Use it as an exceptional repair tool with explicit understanding of skipped hooks and resources.

---

# 14.1579 ApplyOutOfSyncOnly interaction

`ApplyOutOfSyncOnly=true` reduces unnecessary applies.

But release workflow design must not depend on a hook re-running for every reconciliation.

Ask:

```text
Should this job run once per new revision?

once per explicit sync?

only if its manifest differs?
```

Those are different requirements.

Test the exact sync options used by the Application. ([Argo CD][4])

---

# 14.1580 Prune ordering

Creation proceeds from lower waves to higher waves.

Pruning reverses wave order:

```text
higher waves prune first

lower waves prune later
```

This supports dependency-safe teardown:

```text
frontend removed
before
backend foundation removed.
```

If pruning a wave fails, lower waves do not continue. ([Argo CD][1])

---

# 14.1581 PruneLast

For some releases, pruning should happen only after new resources are healthy.

Application sync option:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - PruneLast=true
```

This creates an implicit final pruning wave after other resources reach Healthy. ([Argo CD][4])

This is especially useful during safe resource replacement.

---

# 14.1582 Deletion is not migration

Do not use pruning as a substitute for application-level data migration.

Example:

```text
old StatefulSet pruned
```

does not mean:

```text
data safely moved

clients drained

backup verified.
```

Stateful teardown needs an explicit runbook and retention policy.

---

# 14.1583 Health customization matters

If a custom resource represents a dependency, Argo needs meaningful health.

Otherwise Argo may see:

```text
object exists
```

while the controller reports:

```text
Ready=False
```

Custom Lua health checks can map CR status conditions to:

```text
Healthy
Progressing
Degraded
Suspended
```

Use the CRD's documented conditions, not a guess. ([Argo CD][5])

---

# 14.1584 One Application or several?

One Application with waves is useful when resources share:

```text
ownership

release lifecycle

rollback decision

blast radius
```

Several Applications are usually clearer when components have independent:

```text
teams

permissions

release cadence

failure domains
```

Ordering should not erase organizational boundaries.

---

# 14.1585 App-of-Apps is not a readiness workflow engine

A parent Application creating child Applications does not automatically mean:

```text
child A becomes Healthy
before child B starts.
```

Application creation order and workload readiness are different.

Use ApplicationSet progressive syncs, separate promotion gates, or explicit health-aware orchestration when cross-Application sequencing is required.

---

# 14.1586 Sync window interaction

A sync window controls when a sync may occur.

A wave controls order inside an allowed sync.

```text
SYNC WINDOW
= may deployment start now?

SYNC WAVE
= what progresses first?
```

Do not confuse scheduling with dependency management. ([Argo CD][6])

---

# 14.1587 Failure scenario — secret is late

Symptoms:

```text
migration Pod:
CreateContainerConfigError

event:
secret "todo-database" not found
```

Investigation:

```bash
kubectl get externalsecret -n todo-prod

kubectl describe externalsecret todo-database -n todo-prod

kubectl get secret todo-database -n todo-prod
```

Root cause may be:

```text
ExternalSecret health not gating the wave

provider authorization failure

wrong secret name

migration placed in PreSync before ordinary Sync resources are created
```

That final point is subtle: phase precedence beats wave numbering.

---

# 14.1588 Important phase trap

Suppose `ExternalSecret` is an ordinary Sync resource in wave `-10`.

The migration is a `PreSync` hook in wave `-5`.

Effective order:

```text
PreSync migration
        ↓
Sync ExternalSecret
```

not:

```text
-10 ExternalSecret
        ↓
-5 migration
```

Because:

```text
phase comes before wave.
```

---

# 14.1589 Correct the secret/migration design

Options include:

```text
1. Manage stable secret delivery in a separate platform Application.

2. Make the secret intent a PreSync hook only if its lifecycle semantics are safe.

3. Let the migration Job wait with a bounded preflight for the required Secret.

4. Separate secret bootstrap from application release.
```

Preferred production model:

```text
long-lived dependency already reconciled and monitored
before release begins.
```

Do not force every infrastructure dependency into the release hook graph.

---

# 14.1590 Failure scenario — migration timed out

Check:

```bash
argocd app get todo-prod

argocd app history todo-prod

kubectl get job -n todo-prod

kubectl describe job todo-db-migrate -n todo-prod

kubectl logs job/todo-db-migrate -n todo-prod --all-containers
```

Then ask:

```text
Was the database reachable?

Did the Job acquire its migration lock?

Was the SQL blocked on another transaction?

Did activeDeadlineSeconds kill valid work?

Did a previous execution partly succeed?
```

Never retry a schema change blindly.

---

# 14.1591 Failure scenario — early wave unhealthy forever

Symptoms:

```text
sync stays Running

later resources never appear
```

Inspect the first unhealthy wave, not the last missing workload.

```bash
argocd app get todo-prod --show-operation

argocd app resources todo-prod
```

Mental model:

```text
missing later resource
may be expected behavior,
not its own failure.
```

---

# 14.1592 Failure scenario — hook never reruns

Common cause:

```text
fixed Job name

old completed Job still exists

cleanup policy wrong
```

Use:

```yaml
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

or `generateName` plus deliberate retention.

Also verify that a selective sync did not skip hooks.

---

# 14.1593 Failure scenario — smoke test fails after healthy sync

Ask:

```text
Did the test use the correct Service and port?

Was DNS ready?

Does readiness test less than the smoke test?

Is a downstream dependency failing?

Is the test itself flaky?
```

A flaky release gate trains operators to ignore red status.

Treat test reliability as production reliability.

---

# 14.1594 Failure scenario — emergency rollback

Safe sequence:

```text
1. Stop further promotion.
2. Establish current database state.
3. Confirm old binary is schema-compatible.
4. Revert desired image/config in Git.
5. Merge through emergency approval path.
6. Observe sync and workload health.
7. Validate customer behavior.
8. Preserve incident evidence.
```

Do not simply click history rollback when Git still declares the bad revision; automated sync can reapply Git.

---

# 14.1595 Hands-on lab layout

Create this in a practice config repository:

```text
apps/todo/overlays/prod/
│
├── namespace.yaml
├── external-secret.yaml
├── migration-job.yaml
├── backend-deployment.yaml
├── backend-service.yaml
├── frontend-deployment.yaml
├── frontend-service.yaml
├── ingress.yaml
├── smoke-job.yaml
└── kustomization.yaml
```

For the lab, a disposable PostgreSQL instance may replace production RDS.

Never test destructive migrations against a shared database.

---

# 14.1596 Lab validation sequence

```bash
kubectl apply --dry-run=server -k apps/todo/overlays/prod

argocd app diff todo-prod

argocd app sync todo-prod

argocd app wait todo-prod --sync --health --operation --timeout 900
```

Observe:

```bash
kubectl get jobs,pods -n todo-prod -w
```

Then intentionally break the migration command and verify that the main workload does not progress.

---

# 14.1597 Lab success criteria

```text
□ migration runs before workload change

□ failed migration blocks main sync

□ successful hook is cleaned up

□ failed hook evidence is inspectable

□ backend reaches Healthy before later dependent wave

□ smoke test runs after health

□ application reports successful operation

□ Git still represents final desired state
```

---

# 14.1598 Interview — phase vs wave

Strong answer:

> **A phase defines lifecycle placement such as PreSync, Sync, or PostSync. A wave is an integer ordering mechanism within a phase. Argo orders by phase first and wave second, so a PreSync hook in a high-numbered wave still runs before an ordinary Sync resource in a negative wave.** ([Argo CD][1])

---

# 14.1599 Interview — why did the migration run before the Secret?

Strong answer:

> **The migration was a PreSync hook while the ExternalSecret was an ordinary Sync resource. Phase precedence caused all PreSync work to execute before the Sync phase, regardless of their wave numbers. I would move stable secret delivery outside the release operation or redesign the preflight and lifecycle deliberately.**

---

# 14.1600 Interview — does PostSync failure restore the old version?

No.

> **PostSync failure marks the sync operation failed, but resources from the main sync may already be live. Automated rollback requires a separate safe design, and database compatibility must be evaluated before reverting the workload.**

---

# 14.1601 Interview — why idempotent migrations?

> **Distributed controllers and networks produce retries and ambiguous outcomes. A migration may have committed even if the client did not observe success. Version tracking and locking must make another execution safe or clearly reject it without corrupting the schema.**

---

# 14.1602 Interview — sync waves vs init containers

```text
sync wave
= orders Kubernetes resources during Argo sync

init container
= orders initialization inside each Pod
```

An init container can wait for a dependency per Pod, but it is usually a poor way to run a shared schema migration because many replicas may execute it concurrently.

---

# 14.1603 Interview — Argo hook vs Helm hook

> **Argo uses Helm to render manifests, then Argo owns synchronization. It maps supported Helm hook annotations into Argo hook phases, but the lifecycle is Argo's sync lifecycle rather than Helm release state. I prefer explicit Argo annotations when Argo CD is the release controller and test chart behavior under Argo.** ([Argo CD][3])

---

# 14.1604 Production ordering checklist

```text
□ Dependency graph is documented

□ Phase precedence is understood

□ Wave convention is documented

□ Wave numbers have insertion gaps

□ Early-wave health is meaningful

□ Hook Job has bounded retries

□ Hook Job has a deadline

□ Hook cleanup policy is explicit

□ Failed hook evidence is retained

□ Operational images are immutable

□ Migration uses least-privilege identity

□ Migration framework records versions

□ Concurrent execution is locked

□ Schema change is backward compatible

□ Rollback compatibility is tested

□ Selective sync policy is understood

□ Pruning order is reviewed

□ Stateful deletion is protected

□ Smoke test is deterministic

□ SyncFail action is least privilege

□ Alerts exist for stuck operations
```

---

# 14.1605 Never-forget Lesson 12 rules

```text
1. Phase before wave.

2. Lower waves create first.

3. Higher waves prune first.

4. Default wave is zero.

5. Negative waves are valid.

6. API creation is not readiness.

7. Early unhealthy waves block later waves.

8. PreSync failure stops the main sync.

9. PostSync begins after main resources are Healthy.

10. PostSync failure is not automatic rollback.

11. SyncFail is cleanup/notification, not magic recovery.

12. Hooks do not run in selective sync.

13. Jobs fit one-time operations.

14. Hook cleanup must be deliberate.

15. Job TTL and hook deletion are separate.

16. Use immutable migration artifacts.

17. Migrations must tolerate retries.

18. Use a migration lock.

19. Runtime DB identity should not own schema.

20. Expand before contract.

21. Old and new binaries may overlap.

22. Workload rollback does not reverse schema.

23. CRD creation does not prove controller readiness.

24. Custom health drives safe progression.

25. PruneLast can defer destructive cleanup.

26. Waves should express real dependencies.

27. Cross-team systems may deserve separate Applications.

28. A flaky gate is an operational defect.

29. Git remains the desired-state authority after failure.

30. Ordering reduces risk; it does not create a transaction.
```

---

# 14.1606 Lesson 12 troubleshooting mnemonic

Memorize:

# **P-W-H-J-D-A**

```text
PHASE
  ↓
WAVE
  ↓
HEALTH
  ↓
JOB
  ↓
DEPENDENCY
  ↓
APPLICATION
```

When a later resource is missing, start at the earliest incomplete phase and wave.

---

# ✅ Module 14 — Lesson 12 Complete

You now understand:

```text
✓ sync phases

✓ PreSync / Sync / PostSync / SyncFail

✓ PreDelete / PostDelete / Skip

✓ sync waves

✓ effective ordering

✓ health-gated progression

✓ reverse prune ordering

✓ hook deletion policies

✓ Job TTL

✓ database migration Jobs

✓ idempotency and locking

✓ expand-and-contract migrations

✓ rollback compatibility

✓ CRD/controller dependencies

✓ Helm hook behavior under Argo

✓ selective-sync risk

✓ PostSync smoke testing

✓ production troubleshooting
```

# Next — Module 14, Lesson 13

## Argo Rollouts — Blue/Green, Canary & Progressive Delivery

Ordering tells us:

```text
when a workload may begin.
```

Progressive delivery tells us:

```text
how much production traffic
the new version should receive
while evidence is collected.
```

We will build:

```text
Git image update
      ↓
Argo CD sync
      ↓
Argo Rollout
      ↓
5% → analysis → 25% → analysis → 50% → 100%
      ↓
automatic promotion or abort
```

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.12.1607 Professional Mastery Workbook

This workbook expands **Sync Waves, Resource Hooks, Database Migrations & Dependency Ordering** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 71 lesson-specific anchors.
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

### Concept card 1 - Why Kubernetes apply order is not enough

- Lesson anchor: Imagine these resources are rendered together: CustomResourceDefinition Controller Deployment Custom Resource Application Deployment Migration Job Service Kubernetes accepts many independent API requests quickly. But API acceptance does not mean runtime rea...
- Beginner explanation: Restate **Why Kubernetes apply order is not enough** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why Kubernetes apply order is not enough** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Why Kubernetes apply order is not enough**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Why Kubernetes apply order is not enough**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why Kubernetes apply order is not enough** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Dependency vs ordering

- Lesson anchor: An order is: A is submitted before B. A dependency is stronger: B must not proceed until A has reached a usable state. Production design must ask both: What must be created first? What must be healthy first? ---
- Beginner explanation: Restate **Dependency vs ordering** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Dependency vs ordering** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Dependency vs ordering**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Dependency vs ordering**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Dependency vs ordering** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - The two axes

- Lesson anchor: Use this mental model: PHASE │ ├── PreSync ├── Sync ├── PostSync └── SyncFail WAVE │ ├── -20 ├── -10 ├── 0 └── 10 A phase answers: At which lifecycle point does this run? A wave answers: In what relative order does it run within that lifecycle point?
- Beginner explanation: Restate **The two axes** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The two axes** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **The two axes**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **The two axes**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The two axes** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Hook phases

- Lesson anchor: The principal sync hook types are: PreSync Sync PostSync SyncFail Skip Application-deletion hooks also exist: PreDelete PostDelete PreDelete is for deletion of the whole Application, not ordinary pruning during a sync. PostDelete runs after Application reso...
- Beginner explanation: Restate **Hook phases** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook phases** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Hook phases**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Hook phases**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook phases** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - PreSync

- Lesson anchor: PreSync executes before ordinary synchronization. Good examples: schema compatibility check database migration backup validation external dependency preflight change-ticket verification If a PreSync hook fails: main sync stops
- Beginner explanation: Restate **PreSync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PreSync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **PreSync**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **PreSync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PreSync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Sync

- Lesson anchor: A Sync hook runs during the main sync phase. Most ordinary manifests are not hooks at all; they naturally belong to the Sync phase. Use a Sync hook only when a resource has operation-like lifecycle semantics during the main application step.
- Beginner explanation: Restate **Sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Sync**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - PostSync

- Lesson anchor: PostSync executes only after: Sync resources succeeded and Application resources are Healthy. Good examples: smoke test synthetic transaction post-deployment verification release notification A Deployment existing is not enough. Health gating is the importa...
- Beginner explanation: Restate **PostSync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PostSync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **PostSync**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **PostSync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PostSync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - SyncFail

- Lesson anchor: SyncFail runs when synchronization fails. Good uses: capture diagnostics send failure event remove temporary test data record failed release metadata Bad assumption: SyncFail automatically rolls back everything. It does not.
- Beginner explanation: Restate **SyncFail** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SyncFail** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **SyncFail**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **SyncFail**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SyncFail** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Skip

- Lesson anchor: Skip tells Argo CD not to apply a rendered manifest. metadata: annotations: argocd.argoproj.io/hook: Skip Use it only for a known render-time artifact that another controller or process must own. Overusing Skip creates invisible ownership gaps.
- Beginner explanation: Restate **Skip** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Skip** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Skip**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Skip**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Skip** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - PreDelete and PostDelete

- Lesson anchor: Deletion can also require workflow behavior. Examples: PreDelete → verify final backup PostDelete → de-register external DNS entry → notify service catalog Be extremely careful. A failing PreDelete hook can intentionally block Application deletion. A failin...
- Beginner explanation: Restate **PreDelete and PostDelete** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PreDelete and PostDelete** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **PreDelete and PostDelete**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **PreDelete and PostDelete**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PreDelete and PostDelete** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Hook annotation

- Lesson anchor: Basic form: metadata: annotations: argocd.argoproj.io/hook: PreSync Multiple types may be comma-separated, but simple, single-purpose lifecycle design is easier to reason about. Hooks can technically be many Kubernetes kinds.
- Beginner explanation: Restate **Hook annotation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook annotation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Hook annotation**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Hook annotation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook annotation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Why Jobs are normally best

- Lesson anchor: A migration has completion semantics: start ↓ run once ↓ succeed or fail ↓ terminate That maps naturally to a Kubernetes Job. A Deployment has steady-state semantics and is therefore a poor fit for most one-time hooks. ---
- Beginner explanation: Restate **Why Jobs are normally best** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why Jobs are normally best** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Why Jobs are normally best**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Why Jobs are normally best**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why Jobs are normally best** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Hook naming strategy

- Lesson anchor: Two common patterns exist. Fixed name: metadata: name: todo-db-migrate Generated name: metadata: generateName: todo-db-migrate- Fixed names normally pair with: BeforeHookCreation Generated names create distinct history but require cleanup controls.
- Beginner explanation: Restate **Hook naming strategy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook naming strategy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Hook naming strategy**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Hook naming strategy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook naming strategy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Hook deletion policies

- Lesson anchor: Argo CD supports: HookSucceeded HookFailed BeforeHookCreation Example: metadata: annotations: argocd.argoproj.io/hook-delete-policy: HookSucceeded Meaning: delete the hook resource after successful completion. Without an explicit policy, Argo CD assumes Bef...
- Beginner explanation: Restate **Hook deletion policies** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook deletion policies** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Hook deletion policies**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Hook deletion policies**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook deletion policies** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Retain failure evidence

- Lesson anchor: This combination is common: metadata: annotations: argocd.argoproj.io/hook-delete-policy: HookSucceeded Successful Jobs disappear. Failed Jobs remain available for: kubectl describe job todo-db-migrate -n todo-prod kubectl logs job/todo-db-migrate -n todo-prod
- Beginner explanation: Restate **Retain failure evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Retain failure evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Retain failure evidence**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Retain failure evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Retain failure evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Kubernetes TTL is separate

- Lesson anchor: spec: ttlSecondsAfterFinished: 3600 This is Kubernetes Job cleanup. Argo hook-delete-policy = hook lifecycle decision Job TTL = Kubernetes cleanup timer They can be used together, but they are not the same controller behavior. ([Kubernetes][2])
- Beginner explanation: Restate **Kubernetes TTL is separate** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes TTL is separate** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Kubernetes TTL is separate**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Kubernetes TTL is separate**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Kubernetes TTL is separate** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Sync wave annotation

- Lesson anchor: metadata: annotations: argocd.argoproj.io/sync-wave: "-10" Rules: integer stored as a string lower number first negative values allowed default wave = 0 ---
- Beginner explanation: Restate **Sync wave annotation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync wave annotation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Sync wave annotation**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Sync wave annotation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync wave annotation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Production phase and wave map

- Lesson anchor: Our Todo architecture will use two lifecycle boundaries: FOUNDATION APPLICATION continuously reconciled before workload releases -20  namespace and foundational policy -10  secret references and configuration WORKLOAD APPLICATION
- Beginner explanation: Restate **Production phase and wave map** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production phase and wave map** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production phase and wave map**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production phase and wave map**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production phase and wave map** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Effective ordering algorithm

- Lesson anchor: Argo CD uses this precedence: Therefore: PreSync wave 100 still runs before: Sync wave -100 Phase is the stronger boundary. ([Argo CD][1]) ---
- Beginner explanation: Restate **Effective ordering algorithm** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Effective ordering algorithm** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Effective ordering algorithm**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Effective ordering algorithm**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Effective ordering algorithm** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Waves are health-gated

- Lesson anchor: Argo CD finds the first wave containing an out-of-sync or unhealthy resource, applies it, and repeats. This is powerful: wave -10 Secret not ready │ ▼ wave 0 backend does not progress It can also deadlock progress: early wave permanently unhealthy
- Beginner explanation: Restate **Waves are health-gated** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Waves are health-gated** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Waves are health-gated**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Waves are health-gated**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Waves are health-gated** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Wave delay

- Lesson anchor: Argo CD includes a short delay between waves so other controllers can react and health is not assessed against immediately stale state. It is controlled by: ARGOCDSYNCWAVEDELAY The documented default is two seconds. Changing it is a control-plane tuning dec...
- Beginner explanation: Restate **Wave delay** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Wave delay** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Wave delay**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Wave delay**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Wave delay** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Build the namespace wave

- Lesson anchor: apiVersion: v1 kind: Namespace metadata: name: todo-prod annotations: argocd.argoproj.io/sync-wave: "-20" labels: environment: production owner: todo-team If the Application uses: syncOptions: then Argo may create the destination namespace without a manifest.
- Beginner explanation: Restate **Build the namespace wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Build the namespace wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Build the namespace wave**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Build the namespace wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Build the namespace wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Secret intent wave

- Lesson anchor: apiVersion: external-secrets.io/v1 kind: ExternalSecret metadata: name: todo-database namespace: todo-prod annotations: argocd.argoproj.io/sync-wave: "-10" spec: refreshInterval: 1h secretStoreRef: name: todo-prod kind: SecretStore
- Beginner explanation: Restate **Secret intent wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Secret intent wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Secret intent wave**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Secret intent wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Secret intent wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Complete migration Job

- Lesson anchor: apiVersion: batch/v1 kind: Job metadata: name: todo-db-migrate namespace: todo-prod annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/sync-wave: "-5" argocd.argoproj.io/hook-delete-policy: HookSucceeded spec:
- Beginner explanation: Restate **Complete migration Job** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Complete migration Job** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Complete migration Job**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Complete migration Job**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Complete migration Job** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Read the migration Job as English

- Lesson anchor: Before the main sync: run the exact release artifact with the production database reference retry at most once time out after ten minutes delete on success retain failure long enough to investigate. The migration image should normally be tied to the same im...
- Beginner explanation: Restate **Read the migration Job as English** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Read the migration Job as English** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Read the migration Job as English**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Read the migration Job as English**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Read the migration Job as English** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Never use `latest` for a migration

- Lesson anchor: Bad: image: todo-api:latest Why? Git revision says one thing registry tag later moves hook retry runs different code Use an immutable digest: image: todo-api@sha256:... or enforce immutable release tags. ---
- Beginner explanation: Restate **Never use `latest` for a migration** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never use `latest` for a migration** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Never use `latest` for a migration**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Never use `latest` for a migration**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never use `latest` for a migration** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Idempotency

- Lesson anchor: A migration may be retried because of: controller restart network timeout operator retry uncertain client response Therefore migration execution must tolerate repetition. Good migration systems record applied versions in a schema-history table.
- Beginner explanation: Restate **Idempotency** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Idempotency** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Idempotency**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Idempotency**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Idempotency** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Expand-and-contract schema changes

- Lesson anchor: The safest database release pattern is: Release A EXPAND schema add new nullable column / table / index │ ▼ Release B application reads/writes compatible forms │ ▼ backfill │ ▼ Release C CONTRACT remove obsolete schema only after old code is gone
- Beginner explanation: Restate **Expand-and-contract schema changes** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Expand-and-contract schema changes** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Expand-and-contract schema changes**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Expand-and-contract schema changes**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Expand-and-contract schema changes** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - The destructive migration trap

- Lesson anchor: Suppose version 42 immediately runs: ALTER TABLE todos DROP COLUMN legacystatus; Then the application fails and you restore version 41. Version 41 still expects: legacystatus The container rollback succeeds. The service still fails.
- Beginner explanation: Restate **The destructive migration trap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The destructive migration trap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **The destructive migration trap**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **The destructive migration trap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The destructive migration trap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Backward compatibility window

- Lesson anchor: During a progressive or rolling release, old and new Pods may coexist. The schema must support: old application version and new application version for the entire overlap window. This is why expand-and-contract is part of deployment engineering, not merely...
- Beginner explanation: Restate **Backward compatibility window** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backward compatibility window** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Backward compatibility window**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Backward compatibility window**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backward compatibility window** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Migration lock

- Lesson anchor: Multiple Argo instances, manual jobs, or retried workflows could attempt the same migration. Use the migration framework or database to provide: advisory lock schema-history lock single-writer guarantee GitOps ordering inside one Application cannot prevent...
- Beginner explanation: Restate **Migration lock** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Migration lock** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Migration lock**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Migration lock**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Migration lock** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Migration identity

- Lesson anchor: The normal application may need: SELECT INSERT UPDATE DELETE The migrator may need: ALTER CREATE INDEX CREATE TABLE Do not automatically give normal runtime Pods schema-owner privileges. Use a separate database identity and separate Kubernetes Secret where...
- Beginner explanation: Restate **Migration identity** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Migration identity** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Migration identity**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Migration identity**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Migration identity** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Backend wave

- Lesson anchor: apiVersion: apps/v1 kind: Deployment metadata: name: todo-api namespace: todo-prod annotations: argocd.argoproj.io/sync-wave: "0" spec: replicas: 3 selector: matchLabels: app: todo-api template: metadata: labels: app: todo-api
- Beginner explanation: Restate **Backend wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backend wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Backend wave**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Backend wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backend wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Frontend wave

- Lesson anchor: apiVersion: apps/v1 kind: Deployment metadata: name: todo-web namespace: todo-prod annotations: argocd.argoproj.io/sync-wave: "10" spec: replicas: 3 selector: matchLabels: app: todo-web template: metadata: labels: app: todo-web
- Beginner explanation: Restate **Frontend wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Frontend wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Frontend wave**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Frontend wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Frontend wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - PostSync smoke test

- Lesson anchor: apiVersion: batch/v1 kind: Job metadata: generateName: todo-smoke- namespace: todo-prod annotations: argocd.argoproj.io/hook: PostSync argocd.argoproj.io/sync-wave: "0" argocd.argoproj.io/hook-delete-policy: HookSucceeded
- Beginner explanation: Restate **PostSync smoke test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PostSync smoke test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **PostSync smoke test**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **PostSync smoke test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PostSync smoke test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - What a smoke test should prove

- Lesson anchor: Weak: TCP port opened. Stronger: service discovery works request reaches a ready Pod application handler executes critical dependency is reachable response satisfies expected contract Do not make a smoke test destructive unless it creates and cleans isolate...
- Beginner explanation: Restate **What a smoke test should prove** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What a smoke test should prove** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **What a smoke test should prove**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **What a smoke test should prove**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What a smoke test should prove** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - What PostSync failure means

- Lesson anchor: If the smoke test fails: sync operation = Failed But ordinary resources may already be deployed. Therefore a PostSync hook is: detection and release gating not guaranteed transactional rollback. Kubernetes and Argo CD do not provide a database-and-cluster A...
- Beginner explanation: Restate **What PostSync failure means** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What PostSync failure means** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **What PostSync failure means**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **What PostSync failure means**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What PostSync failure means** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - SyncFail diagnostic hook

- Lesson anchor: apiVersion: batch/v1 kind: Job metadata: generateName: todo-sync-failure- namespace: todo-prod annotations: argocd.argoproj.io/hook: SyncFail argocd.argoproj.io/hook-delete-policy: HookSucceeded spec: ttlSecondsAfterFinished: 86400
- Beginner explanation: Restate **SyncFail diagnostic hook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SyncFail diagnostic hook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **SyncFail diagnostic hook**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **SyncFail diagnostic hook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SyncFail diagnostic hook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - CRD ordering

- Lesson anchor: Typical dependency: CRD ↓ controller ↓ custom resource Argo has built-in kind ordering that helps create namespaces and CRDs before many dependent objects. But: CRD accepted ≠ controller ready to reconcile custom resource.
- Beginner explanation: Restate **CRD ordering** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CRD ordering** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **CRD ordering**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **CRD ordering**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CRD ordering** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - The CRD upgrade problem

- Lesson anchor: CRDs are cluster-scoped APIs shared by all consumers. An upgrade can affect: every namespace every custom resource every team using the API Treat CRD changes as platform changes. Validate: storedVersions conversion webhooks
- Beginner explanation: Restate **The CRD upgrade problem** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The CRD upgrade problem** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **The CRD upgrade problem**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **The CRD upgrade problem**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The CRD upgrade problem** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Helm hooks under Argo CD

- Lesson anchor: Argo CD renders Helm charts with helm template; it does not use Helm as the release controller. Argo maps supported Helm hook annotations to Argo hook behavior—for example pre-install and pre-upgrade map to PreSync, while post-install and post-upgrade map t...
- Beginner explanation: Restate **Helm hooks under Argo CD** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Helm hooks under Argo CD** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Helm hooks under Argo CD**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Helm hooks under Argo CD**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Helm hooks under Argo CD** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Helm install vs upgrade ambiguity

- Lesson anchor: Argo CD does not preserve Helm's release-state model. Therefore Argo cannot reliably distinguish: first install from: upgrade in the way a normal helm install / helm upgrade workflow does. Design chart hooks to be idempotent and compatible with both situati...
- Beginner explanation: Restate **Helm install vs upgrade ambiguity** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Helm install vs upgrade ambiguity** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Helm install vs upgrade ambiguity**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Helm install vs upgrade ambiguity**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Helm install vs upgrade ambiguity** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Selective sync danger

- Lesson anchor: Argo CD documents that hooks do not run during selective sync. ([Argo CD][1]) Suppose an operator selectively syncs only: Deployment/todo-api The required migration hook may be bypassed. Production rule: Do not use selective sync to bypass a release depende...
- Beginner explanation: Restate **Selective sync danger** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Selective sync danger** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Selective sync danger**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Selective sync danger**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Selective sync danger** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - ApplyOutOfSyncOnly interaction

- Lesson anchor: ApplyOutOfSyncOnly=true reduces unnecessary applies. But release workflow design must not depend on a hook re-running for every reconciliation. Ask: Should this job run once per new revision? once per explicit sync? only if its manifest differs?
- Beginner explanation: Restate **ApplyOutOfSyncOnly interaction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **ApplyOutOfSyncOnly interaction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **ApplyOutOfSyncOnly interaction**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **ApplyOutOfSyncOnly interaction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **ApplyOutOfSyncOnly interaction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Prune ordering

- Lesson anchor: Creation proceeds from lower waves to higher waves. Pruning reverses wave order: higher waves prune first lower waves prune later This supports dependency-safe teardown: frontend removed before backend foundation removed.
- Beginner explanation: Restate **Prune ordering** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune ordering** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Prune ordering**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Prune ordering**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune ordering** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - PruneLast

- Lesson anchor: For some releases, pruning should happen only after new resources are healthy. Application sync option: spec: syncPolicy: syncOptions: This creates an implicit final pruning wave after other resources reach Healthy. ([Argo CD][4])
- Beginner explanation: Restate **PruneLast** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PruneLast** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **PruneLast**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **PruneLast**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PruneLast** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Deletion is not migration

- Lesson anchor: Do not use pruning as a substitute for application-level data migration. Example: old StatefulSet pruned does not mean: data safely moved clients drained backup verified. Stateful teardown needs an explicit runbook and retention policy.
- Beginner explanation: Restate **Deletion is not migration** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Deletion is not migration** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Deletion is not migration**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Deletion is not migration**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Deletion is not migration** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Health customization matters

- Lesson anchor: If a custom resource represents a dependency, Argo needs meaningful health. Otherwise Argo may see: object exists while the controller reports: Ready=False Custom Lua health checks can map CR status conditions to: Healthy
- Beginner explanation: Restate **Health customization matters** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Health customization matters** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Health customization matters**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Health customization matters**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Health customization matters** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - One Application or several?

- Lesson anchor: One Application with waves is useful when resources share: ownership release lifecycle rollback decision blast radius Several Applications are usually clearer when components have independent: teams permissions release cadence
- Beginner explanation: Restate **One Application or several?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **One Application or several?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **One Application or several?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **One Application or several?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **One Application or several?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - App-of-Apps is not a readiness workflow engine

- Lesson anchor: A parent Application creating child Applications does not automatically mean: child A becomes Healthy before child B starts. Application creation order and workload readiness are different. Use ApplicationSet progressive syncs, separate promotion gates, or...
- Beginner explanation: Restate **App-of-Apps is not a readiness workflow engine** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **App-of-Apps is not a readiness workflow engine** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **App-of-Apps is not a readiness workflow engine**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **App-of-Apps is not a readiness workflow engine**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **App-of-Apps is not a readiness workflow engine** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Sync window interaction

- Lesson anchor: A sync window controls when a sync may occur. A wave controls order inside an allowed sync. SYNC WINDOW = may deployment start now? SYNC WAVE = what progresses first? Do not confuse scheduling with dependency management. ([Argo CD][6])
- Beginner explanation: Restate **Sync window interaction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync window interaction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Sync window interaction**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Sync window interaction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync window interaction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Failure scenario — secret is late

- Lesson anchor: Symptoms: migration Pod: CreateContainerConfigError event: secret "todo-database" not found Investigation: kubectl get externalsecret -n todo-prod kubectl describe externalsecret todo-database -n todo-prod kubectl get secret todo-database -n todo-prod
- Beginner explanation: Restate **Failure scenario — secret is late** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — secret is late** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Failure scenario — secret is late**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Failure scenario — secret is late**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — secret is late** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - Important phase trap

- Lesson anchor: Suppose ExternalSecret is an ordinary Sync resource in wave -10. The migration is a PreSync hook in wave -5. Effective order: PreSync migration ↓ Sync ExternalSecret not: -10 ExternalSecret ↓ -5 migration Because: phase comes before wave.
- Beginner explanation: Restate **Important phase trap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important phase trap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Important phase trap**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Important phase trap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important phase trap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Correct the secret/migration design

- Lesson anchor: Options include: Preferred production model: long-lived dependency already reconciled and monitored before release begins. Do not force every infrastructure dependency into the release hook graph. ---
- Beginner explanation: Restate **Correct the secret/migration design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Correct the secret/migration design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Correct the secret/migration design**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Correct the secret/migration design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Correct the secret/migration design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Failure scenario — migration timed out

- Lesson anchor: Check: argocd app get todo-prod argocd app history todo-prod kubectl get job -n todo-prod kubectl describe job todo-db-migrate -n todo-prod kubectl logs job/todo-db-migrate -n todo-prod --all-containers Then ask: Was the database reachable?
- Beginner explanation: Restate **Failure scenario — migration timed out** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — migration timed out** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Failure scenario — migration timed out**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Failure scenario — migration timed out**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — migration timed out** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Failure scenario — early wave unhealthy forever

- Lesson anchor: Symptoms: sync stays Running later resources never appear Inspect the first unhealthy wave, not the last missing workload. argocd app get todo-prod --show-operation argocd app resources todo-prod Mental model: missing later resource
- Beginner explanation: Restate **Failure scenario — early wave unhealthy forever** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — early wave unhealthy forever** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Failure scenario — early wave unhealthy forever**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Failure scenario — early wave unhealthy forever**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — early wave unhealthy forever** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Failure scenario — hook never reruns

- Lesson anchor: Common cause: fixed Job name old completed Job still exists cleanup policy wrong Use: argocd.argoproj.io/hook-delete-policy: BeforeHookCreation or generateName plus deliberate retention. Also verify that a selective sync did not skip hooks.
- Beginner explanation: Restate **Failure scenario — hook never reruns** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — hook never reruns** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Failure scenario — hook never reruns**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Failure scenario — hook never reruns**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — hook never reruns** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Failure scenario — smoke test fails after healthy sync

- Lesson anchor: Ask: Did the test use the correct Service and port? Was DNS ready? Does readiness test less than the smoke test? Is a downstream dependency failing? Is the test itself flaky? A flaky release gate trains operators to ignore red status.
- Beginner explanation: Restate **Failure scenario — smoke test fails after healthy sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — smoke test fails after healthy sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Failure scenario — smoke test fails after healthy sync**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Failure scenario — smoke test fails after healthy sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — smoke test fails after healthy sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - Failure scenario — emergency rollback

- Lesson anchor: Safe sequence: Do not simply click history rollback when Git still declares the bad revision; automated sync can reapply Git. ---
- Beginner explanation: Restate **Failure scenario — emergency rollback** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — emergency rollback** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Failure scenario — emergency rollback**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Failure scenario — emergency rollback**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — emergency rollback** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Hands-on lab layout

- Lesson anchor: Create this in a practice config repository: apps/todo/overlays/prod/ │ ├── namespace.yaml ├── external-secret.yaml ├── migration-job.yaml ├── backend-deployment.yaml ├── backend-service.yaml ├── frontend-deployment.yaml
- Beginner explanation: Restate **Hands-on lab layout** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hands-on lab layout** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Hands-on lab layout**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Hands-on lab layout**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hands-on lab layout** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - Lab validation sequence

- Lesson anchor: kubectl apply --dry-run=server -k apps/todo/overlays/prod argocd app diff todo-prod argocd app sync todo-prod argocd app wait todo-prod --sync --health --operation --timeout 900 Observe: kubectl get jobs,pods -n todo-prod -w
- Beginner explanation: Restate **Lab validation sequence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab validation sequence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Lab validation sequence**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Lab validation sequence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lab validation sequence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 62 - Lab success criteria

- Lesson anchor: □ migration runs before workload change □ failed migration blocks main sync □ successful hook is cleaned up □ failed hook evidence is inspectable □ backend reaches Healthy before later dependent wave □ smoke test runs after health
- Beginner explanation: Restate **Lab success criteria** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lab success criteria** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Lab success criteria**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Lab success criteria**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lab success criteria** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 63 - Interview — phase vs wave

- Lesson anchor: Strong answer: A phase defines lifecycle placement such as PreSync, Sync, or PostSync. A wave is an integer ordering mechanism within a phase. Argo orders by phase first and wave second, so a PreSync hook in a high-numbered wave still runs before an ordinar...
- Beginner explanation: Restate **Interview — phase vs wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — phase vs wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — phase vs wave**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — phase vs wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — phase vs wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 64 - Interview — why did the migration run before the Secret?

- Lesson anchor: Strong answer: The migration was a PreSync hook while the ExternalSecret was an ordinary Sync resource. Phase precedence caused all PreSync work to execute before the Sync phase, regardless of their wave numbers. I would move stable secret delivery outside...
- Beginner explanation: Restate **Interview — why did the migration run before the Secret?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — why did the migration run before the Secret?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — why did the migration run before the Secret?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — why did the migration run before the Secret?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — why did the migration run before the Secret?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 65 - Interview — does PostSync failure restore the old version?

- Lesson anchor: No. PostSync failure marks the sync operation failed, but resources from the main sync may already be live. Automated rollback requires a separate safe design, and database compatibility must be evaluated before reverting the workload.
- Beginner explanation: Restate **Interview — does PostSync failure restore the old version?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — does PostSync failure restore the old version?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — does PostSync failure restore the old version?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — does PostSync failure restore the old version?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — does PostSync failure restore the old version?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 66 - Interview — why idempotent migrations?

- Lesson anchor: Distributed controllers and networks produce retries and ambiguous outcomes. A migration may have committed even if the client did not observe success. Version tracking and locking must make another execution safe or clearly reject it without corrupting the...
- Beginner explanation: Restate **Interview — why idempotent migrations?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — why idempotent migrations?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — why idempotent migrations?**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — why idempotent migrations?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — why idempotent migrations?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 67 - Interview — sync waves vs init containers

- Lesson anchor: sync wave = orders Kubernetes resources during Argo sync init container = orders initialization inside each Pod An init container can wait for a dependency per Pod, but it is usually a poor way to run a shared schema migration because many replicas may exec...
- Beginner explanation: Restate **Interview — sync waves vs init containers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — sync waves vs init containers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — sync waves vs init containers**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — sync waves vs init containers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — sync waves vs init containers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 68 - Interview — Argo hook vs Helm hook

- Lesson anchor: Argo uses Helm to render manifests, then Argo owns synchronization. It maps supported Helm hook annotations into Argo hook phases, but the lifecycle is Argo's sync lifecycle rather than Helm release state. I prefer explicit Argo annotations when Argo CD is...
- Beginner explanation: Restate **Interview — Argo hook vs Helm hook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Argo hook vs Helm hook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Argo hook vs Helm hook**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Argo hook vs Helm hook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Argo hook vs Helm hook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 69 - Production ordering checklist

- Lesson anchor: □ Dependency graph is documented □ Phase precedence is understood □ Wave convention is documented □ Wave numbers have insertion gaps □ Early-wave health is meaningful □ Hook Job has bounded retries □ Hook Job has a deadline
- Beginner explanation: Restate **Production ordering checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production ordering checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Production ordering checklist**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Production ordering checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production ordering checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 70 - Never-forget Lesson 12 rules

- Lesson anchor: ---
- Beginner explanation: Restate **Never-forget Lesson 12 rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget Lesson 12 rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Never-forget Lesson 12 rules**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Never-forget Lesson 12 rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget Lesson 12 rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 71 - Lesson 12 troubleshooting mnemonic

- Lesson anchor: Memorize: PHASE ↓ WAVE ↓ HEALTH ↓ JOB ↓ DEPENDENCY ↓ APPLICATION When a later resource is missing, start at the earliest incomplete phase and wave. --- You now understand: ✓ sync phases ✓ PreSync / Sync / PostSync / SyncFail
- Beginner explanation: Restate **Lesson 12 troubleshooting mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lesson 12 troubleshooting mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Lesson 12 troubleshooting mnemonic**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Lesson 12 troubleshooting mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lesson 12 troubleshooting mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Why Kubernetes apply order is not enough x change management

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Why Kubernetes apply order is not enough** while a change involving **Hook phases** places **change management** at risk.
- Plain-language question: What problem does **Why Kubernetes apply order is not enough** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine these resources are rendered together: CustomResourceDefinition Controller Deployment Custom Resource Application Deployment Migration Job Service Kubernetes accepts many independent API requests quickly. But API acceptance does not mean runtime rea...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Why Kubernetes apply order is not enough** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Dependency vs ordering x dependency failure

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Dependency vs ordering** while a change involving **Hook annotation** places **dependency failure** at risk.
- Plain-language question: What problem does **Dependency vs ordering** solve here, and who notices first when it fails?
- Lesson evidence anchor: An order is: A is submitted before B. A dependency is stronger: B must not proceed until A has reached a usable state. Production design must ask both: What must be created first? What must be healthy first? ---
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Dependency vs ordering** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - The two axes x developer experience

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **The two axes** while a change involving **Production phase and wave map** places **developer experience** at risk.
- Plain-language question: What problem does **The two axes** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use this mental model: PHASE │ ├── PreSync ├── Sync ├── PostSync └── SyncFail WAVE │ ├── -20 ├── -10 ├── 0 └── 10 A phase answers: At which lifecycle point does this run? A wave answers: In what relative order does it run within that lifecycle point?
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **The two axes** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Hook phases x availability

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Hook phases** while a change involving **Read the migration Job as English** places **availability** at risk.
- Plain-language question: What problem does **Hook phases** solve here, and who notices first when it fails?
- Lesson evidence anchor: The principal sync hook types are: PreSync Sync PostSync SyncFail Skip Application-deletion hooks also exist: PreDelete PostDelete PreDelete is for deletion of the whole Application, not ordinary pruning during a sync. PostDelete runs after Application reso...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Hook phases** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - PreSync x security

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **PreSync** while a change involving **Migration identity** places **security** at risk.
- Plain-language question: What problem does **PreSync** solve here, and who notices first when it fails?
- Lesson evidence anchor: PreSync executes before ordinary synchronization. Good examples: schema compatibility check database migration backup validation external dependency preflight change-ticket verification If a PreSync hook fails: main sync stops
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **PreSync** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Sync x delivery safety

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Sync** while a change involving **CRD ordering** places **delivery safety** at risk.
- Plain-language question: What problem does **Sync** solve here, and who notices first when it fails?
- Lesson evidence anchor: A Sync hook runs during the main sync phase. Most ordinary manifests are not hooks at all; they naturally belong to the Sync phase. Use a Sync hook only when a resource has operation-like lifecycle semantics during the main application step.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Sync** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - PostSync x multi-tenancy

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **PostSync** while a change involving **PruneLast** places **multi-tenancy** at risk.
- Plain-language question: What problem does **PostSync** solve here, and who notices first when it fails?
- Lesson evidence anchor: PostSync executes only after: Sync resources succeeded and Application resources are Healthy. Good examples: smoke test synthetic transaction post-deployment verification release notification A Deployment existing is not enough. Health gating is the importa...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **PostSync** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - SyncFail x observability

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **SyncFail** while a change involving **Important phase trap** places **observability** at risk.
- Plain-language question: What problem does **SyncFail** solve here, and who notices first when it fails?
- Lesson evidence anchor: SyncFail runs when synchronization fails. Good uses: capture diagnostics send failure event remove temporary test data record failed release metadata Bad assumption: SyncFail automatically rolls back everything. It does not.
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **SyncFail** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Skip x regional resilience

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Skip** while a change involving **Hands-on lab layout** places **regional resilience** at risk.
- Plain-language question: What problem does **Skip** solve here, and who notices first when it fails?
- Lesson evidence anchor: Skip tells Argo CD not to apply a rendered manifest. metadata: annotations: argocd.argoproj.io/hook: Skip Use it only for a known render-time artifact that another controller or process must own. Overusing Skip creates invisible ownership gaps.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Skip** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - PreDelete and PostDelete x business value

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **PreDelete and PostDelete** while a change involving **Interview — sync waves vs init containers** places **business value** at risk.
- Plain-language question: What problem does **PreDelete and PostDelete** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deletion can also require workflow behavior. Examples: PreDelete → verify final backup PostDelete → de-register external DNS entry → notify service catalog Be extremely careful. A failing PreDelete hook can intentionally block Application deletion. A failin...
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **PreDelete and PostDelete** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Hook annotation x latency

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Hook annotation** while a change involving **The two axes** places **latency** at risk.
- Plain-language question: What problem does **Hook annotation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Basic form: metadata: annotations: argocd.argoproj.io/hook: PreSync Multiple types may be comma-separated, but simple, single-purpose lifecycle design is easier to reason about. Hooks can technically be many Kubernetes kinds.
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Hook annotation** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Why Jobs are normally best x privacy

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Why Jobs are normally best** while a change involving **PreDelete and PostDelete** places **privacy** at risk.
- Plain-language question: What problem does **Why Jobs are normally best** solve here, and who notices first when it fails?
- Lesson evidence anchor: A migration has completion semantics: start ↓ run once ↓ succeed or fail ↓ terminate That maps naturally to a Kubernetes Job. A Deployment has steady-state semantics and is therefore a poor fit for most one-time hooks. ---
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Why Jobs are normally best** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Hook naming strategy x operability

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Hook naming strategy** while a change involving **Sync wave annotation** places **operability** at risk.
- Plain-language question: What problem does **Hook naming strategy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two common patterns exist. Fixed name: metadata: name: todo-db-migrate Generated name: metadata: generateName: todo-db-migrate- Fixed names normally pair with: BeforeHookCreation Generated names create distinct history but require cleanup controls.
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Hook naming strategy** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Hook deletion policies x data integrity

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Hook deletion policies** while a change involving **Complete migration Job** places **data integrity** at risk.
- Plain-language question: What problem does **Hook deletion policies** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD supports: HookSucceeded HookFailed BeforeHookCreation Example: metadata: annotations: argocd.argoproj.io/hook-delete-policy: HookSucceeded Meaning: delete the hook resource after successful completion. Without an explicit policy, Argo CD assumes Bef...
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Hook deletion policies** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Retain failure evidence x automation safety

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Retain failure evidence** while a change involving **Migration lock** places **automation safety** at risk.
- Plain-language question: What problem does **Retain failure evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: This combination is common: metadata: annotations: argocd.argoproj.io/hook-delete-policy: HookSucceeded Successful Jobs disappear. Failed Jobs remain available for: kubectl describe job todo-db-migrate -n todo-prod kubectl logs job/todo-db-migrate -n todo-prod
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Retain failure evidence** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Kubernetes TTL is separate x governance

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Kubernetes TTL is separate** while a change involving **SyncFail diagnostic hook** places **governance** at risk.
- Plain-language question: What problem does **Kubernetes TTL is separate** solve here, and who notices first when it fails?
- Lesson evidence anchor: spec: ttlSecondsAfterFinished: 3600 This is Kubernetes Job cleanup. Argo hook-delete-policy = hook lifecycle decision Job TTL = Kubernetes cleanup timer They can be used together, but they are not the same controller behavior. ([Kubernetes][2])
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Kubernetes TTL is separate** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Sync wave annotation x correctness

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Sync wave annotation** while a change involving **Prune ordering** places **correctness** at risk.
- Plain-language question: What problem does **Sync wave annotation** solve here, and who notices first when it fails?
- Lesson evidence anchor: metadata: annotations: argocd.argoproj.io/sync-wave: "-10" Rules: integer stored as a string lower number first negative values allowed default wave = 0 ---
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Sync wave annotation** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Production phase and wave map x capacity

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Production phase and wave map** while a change involving **Failure scenario — secret is late** places **capacity** at risk.
- Plain-language question: What problem does **Production phase and wave map** solve here, and who notices first when it fails?
- Lesson evidence anchor: Our Todo architecture will use two lifecycle boundaries: FOUNDATION APPLICATION continuously reconciled before workload releases -20  namespace and foundational policy -10  secret references and configuration WORKLOAD APPLICATION
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Production phase and wave map** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Effective ordering algorithm x cost efficiency

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Effective ordering algorithm** while a change involving **Failure scenario — emergency rollback** places **cost efficiency** at risk.
- Plain-language question: What problem does **Effective ordering algorithm** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD uses this precedence: Therefore: PreSync wave 100 still runs before: Sync wave -100 Phase is the stronger boundary. ([Argo CD][1]) ---
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Effective ordering algorithm** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Waves are health-gated x recovery

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Waves are health-gated** while a change involving **Interview — why idempotent migrations?** places **recovery** at risk.
- Plain-language question: What problem does **Waves are health-gated** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD finds the first wave containing an out-of-sync or unhealthy resource, applies it, and repeats. This is powerful: wave -10 Secret not ready │ ▼ wave 0 backend does not progress It can also deadlock progress: early wave permanently unhealthy
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Waves are health-gated** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Wave delay x change management

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Wave delay** while a change involving **Dependency vs ordering** places **change management** at risk.
- Plain-language question: What problem does **Wave delay** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD includes a short delay between waves so other controllers can react and health is not assessed against immediately stale state. It is controlled by: ARGOCDSYNCWAVEDELAY The documented default is two seconds. Changing it is a control-plane tuning dec...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Wave delay** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Build the namespace wave x dependency failure

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Build the namespace wave** while a change involving **Skip** places **dependency failure** at risk.
- Plain-language question: What problem does **Build the namespace wave** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: v1 kind: Namespace metadata: name: todo-prod annotations: argocd.argoproj.io/sync-wave: "-20" labels: environment: production owner: todo-team If the Application uses: syncOptions: then Argo may create the destination namespace without a manifest.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Build the namespace wave** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Secret intent wave x developer experience

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Secret intent wave** while a change involving **Kubernetes TTL is separate** places **developer experience** at risk.
- Plain-language question: What problem does **Secret intent wave** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: external-secrets.io/v1 kind: ExternalSecret metadata: name: todo-database namespace: todo-prod annotations: argocd.argoproj.io/sync-wave: "-10" spec: refreshInterval: 1h secretStoreRef: name: todo-prod kind: SecretStore
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **Secret intent wave** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Complete migration Job x availability

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Complete migration Job** while a change involving **Secret intent wave** places **availability** at risk.
- Plain-language question: What problem does **Complete migration Job** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: batch/v1 kind: Job metadata: name: todo-db-migrate namespace: todo-prod annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/sync-wave: "-5" argocd.argoproj.io/hook-delete-policy: HookSucceeded spec:
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Complete migration Job** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 24.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ "Sync Phases and Waves - Argo CD"
[2]: https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/ "TTL-after-finished Controller - Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#helm-hooks "Helm Hooks - Argo CD"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/ "Sync Options - Argo CD"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/health/ "Resource Health - Argo CD"
[6]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/ "Sync Windows - Argo CD"
